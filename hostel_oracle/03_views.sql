
CREATE OR REPLACE VIEW v_current_residence AS
SELECT a.allocation_id, a.student_id, a.bed_id, b.room_id, r.hostel_id,
       h.hostel_name, r.room_no, b.bed_no
FROM allocation a JOIN bed b ON b.bed_id = a.bed_id
JOIN room r ON r.room_id = b.room_id
JOIN hostel h ON h.hostel_id = r.hostel_id
CROSS JOIN report_config cfg
WHERE a.start_date <= cfg.as_of_date
  AND (a.end_date IS NULL OR a.end_date > cfg.as_of_date);

CREATE OR REPLACE VIEW v_fee_balance AS
SELECT f.charge_id, a.student_id, f.allocation_id, f.billing_period,
       f.charge_date, f.due_date, f.amount AS charged_amount,
       NVL(p.paid_amount,0) AS paid_amount,
       f.amount - NVL(p.paid_amount,0) AS outstanding_amount,
       CASE WHEN f.due_date < cfg.as_of_date
            THEN f.amount - NVL(p.paid_amount,0) ELSE 0 END AS overdue_amount
FROM fee_charge f JOIN allocation a ON a.allocation_id = f.allocation_id
CROSS JOIN report_config cfg
LEFT JOIN (
    SELECT p.charge_id, SUM(p.amount) AS paid_amount
    FROM payment p CROSS JOIN report_config c
    WHERE p.payment_date < c.as_of_date GROUP BY p.charge_id
) p ON p.charge_id = f.charge_id
WHERE f.charge_date < cfg.as_of_date;

CREATE OR REPLACE VIEW v_hostel_occupancy AS
SELECT h.hostel_id, h.hostel_name,
       NVL(b.physical_beds,0) AS physical_beds,
       NVL(b.serviceable_beds,0) AS serviceable_beds,
       NVL(a.occupied_beds,0) AS occupied_beds,
       NVL(b.serviceable_beds,0)-NVL(a.occupied_serviceable,0) AS available_beds,
       ROUND(100*NVL(a.occupied_beds,0)/NULLIF(b.serviceable_beds,0),2) AS occupancy_pct
FROM hostel h
LEFT JOIN (
    SELECT r.hostel_id, COUNT(*) AS physical_beds,
           SUM(CASE WHEN b.service_status='AVAILABLE' THEN 1 ELSE 0 END) AS serviceable_beds
    FROM room r JOIN bed b ON b.room_id=r.room_id GROUP BY r.hostel_id
) b ON b.hostel_id=h.hostel_id
LEFT JOIN (
    SELECT c.hostel_id, COUNT(*) AS occupied_beds,
           SUM(CASE WHEN b.service_status='AVAILABLE' THEN 1 ELSE 0 END) AS occupied_serviceable
    FROM v_current_residence c JOIN bed b ON b.bed_id=c.bed_id GROUP BY c.hostel_id
) a ON a.hostel_id=h.hostel_id;

CREATE OR REPLACE VIEW v_student_support_stats AS
WITH expected AS (
    SELECT a.student_id,
           SUM(LEAST(NVL(a.end_date,c.as_of_date),c.as_of_date)
               - GREATEST(a.start_date,c.window_start)) AS expected_days
    FROM allocation a CROSS JOIN report_config c
    WHERE a.start_date < c.as_of_date
      AND NVL(a.end_date,c.as_of_date) > c.window_start
    GROUP BY a.student_id
), att AS (
    SELECT a.student_id, COUNT(*) AS recorded_days,
           SUM(CASE WHEN t.attendance_status='PRESENT' THEN 1 ELSE 0 END) AS present_days,
           SUM(CASE WHEN t.attendance_status='ABSENT' THEN 1 ELSE 0 END) AS absent_days,
           SUM(CASE WHEN t.attendance_status='APPROVED_LEAVE' THEN 1 ELSE 0 END) AS leave_days
    FROM attendance t JOIN allocation a ON a.allocation_id=t.allocation_id
    CROSS JOIN report_config c
    WHERE t.attendance_date >= c.window_start AND t.attendance_date < c.as_of_date
    GROUP BY a.student_id
), fees AS (
    SELECT student_id, SUM(outstanding_amount) AS outstanding_fee,
           SUM(overdue_amount) AS overdue_fee FROM v_fee_balance GROUP BY student_id
), complaints AS (
    SELECT p.student_id, COUNT(*) AS complaint_count,
           SUM(CASE WHEN p.resolved_date IS NULL OR p.resolved_date >= c.as_of_date
                    THEN 1 ELSE 0 END) AS unresolved_complaints
    FROM complaint p CROSS JOIN report_config c
    WHERE p.raised_date >= c.window_start AND p.raised_date < c.as_of_date
    GROUP BY p.student_id
), discipline AS (
    SELECT a.student_id, COUNT(*) AS incident_count
    FROM disciplinary_incident d JOIN allocation a ON a.allocation_id=d.allocation_id
    CROSS JOIN report_config c
    WHERE d.incident_date >= c.window_start AND d.incident_date < c.as_of_date
    GROUP BY a.student_id
)
SELECT s.student_id, s.registration_no, s.student_name, s.department,
       cr.hostel_id, cr.hostel_name,
       NVL(e.expected_days,0) AS expected_days,
       NVL(t.recorded_days,0) AS recorded_days,
       NVL(t.present_days,0) AS present_days,
       NVL(t.absent_days,0) AS absent_days,
       NVL(t.leave_days,0) AS approved_leave_days,
       NVL(e.expected_days,0)-NVL(t.recorded_days,0) AS missing_days,
       ROUND(100*t.present_days/NULLIF(t.present_days+t.absent_days,0),2) AS attendance_pct,
       NVL(f.outstanding_fee,0) AS outstanding_fee, NVL(f.overdue_fee,0) AS overdue_fee,
       NVL(p.complaint_count,0) AS complaint_count,
       NVL(p.unresolved_complaints,0) AS unresolved_complaints,
       NVL(d.incident_count,0) AS disciplinary_incidents
FROM student s
LEFT JOIN v_current_residence cr ON cr.student_id=s.student_id
LEFT JOIN expected e ON e.student_id=s.student_id
LEFT JOIN att t ON t.student_id=s.student_id
LEFT JOIN fees f ON f.student_id=s.student_id
LEFT JOIN complaints p ON p.student_id=s.student_id
LEFT JOIN discipline d ON d.student_id=s.student_id;

CREATE OR REPLACE VIEW v_student_support_risk AS
WITH points AS (
    SELECT s.*,
       CASE WHEN attendance_pct < 75 THEN 2 WHEN attendance_pct < 85 THEN 1 ELSE 0 END AS attendance_points,
       CASE WHEN outstanding_fee > 10000 THEN 2 WHEN outstanding_fee > 0 THEN 1 ELSE 0 END AS fee_points,
       CASE WHEN unresolved_complaints >= 4 THEN 2 WHEN unresolved_complaints >= 2 THEN 1 ELSE 0 END AS complaint_points,
       CASE WHEN disciplinary_incidents >= 2 THEN 2 WHEN disciplinary_incidents = 1 THEN 1 ELSE 0 END AS discipline_points
    FROM v_student_support_stats s WHERE hostel_id IS NOT NULL
), scored AS (
    SELECT p.*, attendance_points+fee_points+complaint_points+discipline_points AS risk_score
    FROM points p
)
SELECT s.*,
       CASE WHEN missing_days > 0 OR attendance_pct IS NULL THEN 'INCOMPLETE' ELSE 'COMPLETE' END AS data_quality,
       CASE WHEN risk_score >= 5 THEN 'HIGH PRIORITY'
            WHEN risk_score >= 2 OR missing_days > 0 OR attendance_pct IS NULL THEN 'NEEDS ATTENTION'
            ELSE 'NORMAL' END AS risk_status
FROM scored s;

CREATE OR REPLACE VIEW v_hostel_performance AS
SELECT o.*, NVL(s.resident_count,0) AS resident_count,
       s.avg_attendance_pct, NVL(s.total_outstanding,0) AS total_outstanding,
       NVL(s.high_priority_count,0) AS high_priority_count,
       NVL(m.maintenance_cost,0) AS maintenance_cost
FROM v_hostel_occupancy o
LEFT JOIN (
    SELECT hostel_id, COUNT(*) AS resident_count,
           ROUND(AVG(CASE WHEN missing_days=0 THEN attendance_pct END),2) AS avg_attendance_pct,
           SUM(outstanding_fee) AS total_outstanding,
           SUM(CASE WHEN risk_status='HIGH PRIORITY' THEN 1 ELSE 0 END) AS high_priority_count
    FROM v_student_support_risk GROUP BY hostel_id
) s ON s.hostel_id=o.hostel_id
LEFT JOIN (
    SELECT r.hostel_id, SUM(e.amount) AS maintenance_cost
    FROM maintenance_expense e JOIN complaint p ON p.complaint_id=e.complaint_id
    JOIN room r ON r.room_id=p.room_id CROSS JOIN report_config c
    WHERE e.expense_date >= c.window_start AND e.expense_date < c.as_of_date
    GROUP BY r.hostel_id
) m ON m.hostel_id=o.hostel_id;
