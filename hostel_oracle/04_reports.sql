SET LINESIZE 240
SET WRAP ON
COLUMN hostel_name FORMAT A20
COLUMN student_name FORMAT A16
COLUMN visitor_name FORMAT A18
COLUMN relationship FORMAT A12
COLUMN room_no FORMAT A7
COLUMN bed_no FORMAT A7
COLUMN department FORMAT A12
COLUMN category FORMAT A14
COLUMN severity FORMAT A8
COLUMN risk_status FORMAT A16
COLUMN data_quality FORMAT A10
COLUMN status_at_cutoff FORMAT A14
COLUMN entry_time FORMAT A19
COLUMN exit_time FORMAT A19
PROMPT Q01 - Hostel occupancy and vacant serviceable beds
SELECT * FROM v_hostel_occupancy ORDER BY hostel_id;

PROMPT Q02 - Room utilization (including empty rooms)
SELECT h.hostel_name,r.room_no,COUNT(b.bed_id) AS physical_beds,
       SUM(CASE WHEN b.service_status='AVAILABLE' THEN 1 ELSE 0 END) AS serviceable_beds,
       COUNT(c.allocation_id) AS occupied_beds,
       ROUND(100*COUNT(c.allocation_id)/NULLIF(SUM(CASE WHEN b.service_status='AVAILABLE' THEN 1 ELSE 0 END),0),2) AS utilization_pct
FROM hostel h JOIN room r ON r.hostel_id=h.hostel_id
LEFT JOIN bed b ON b.room_id=r.room_id
LEFT JOIN v_current_residence c ON c.bed_id=b.bed_id
GROUP BY h.hostel_name,r.room_no ORDER BY h.hostel_name,r.room_no;

PROMPT Q03 - Student attendance; approved leave excluded and missing days explicit
SELECT student_id,student_name,hostel_name,present_days,absent_days,
       approved_leave_days,missing_days,attendance_pct
FROM v_student_support_stats ORDER BY student_id;

PROMPT Q04 - Hostel fee collection within the reporting window
SELECT h.hostel_name,NVL(x.collected_amount,0) AS collected_amount
FROM hostel h LEFT JOIN (
    SELECT r.hostel_id,SUM(p.amount) AS collected_amount
    FROM payment p JOIN fee_charge f ON f.charge_id=p.charge_id
    JOIN allocation a ON a.allocation_id=f.allocation_id
    JOIN bed b ON b.bed_id=a.bed_id JOIN room r ON r.room_id=b.room_id
    CROSS JOIN report_config c
    WHERE p.payment_date>=c.window_start AND p.payment_date<c.as_of_date
    GROUP BY r.hostel_id
) x ON x.hostel_id=h.hostel_id ORDER BY h.hostel_id;

PROMPT Q05 - Outstanding and overdue fees as of report cutoff
SELECT student_id,student_name,outstanding_fee,overdue_fee
FROM v_student_support_stats WHERE outstanding_fee>0 ORDER BY outstanding_fee DESC;

PROMPT Q06 - Maintenance complaint status at the report cutoff
SELECT p.complaint_id,s.student_name,h.hostel_name,r.room_no,p.category,
       CASE WHEN p.resolved_date<c.as_of_date THEN 'RESOLVED' ELSE 'UNRESOLVED' END AS status_at_cutoff,
       TRUNC(NVL(LEAST(p.resolved_date,c.as_of_date),c.as_of_date))-TRUNC(p.raised_date) AS days_open
FROM complaint p JOIN student s ON s.student_id=p.student_id
JOIN room r ON r.room_id=p.room_id JOIN hostel h ON h.hostel_id=r.hostel_id
CROSS JOIN report_config c
WHERE p.raised_date>=c.window_start AND p.raised_date<c.as_of_date ORDER BY p.complaint_id;

PROMPT Q07 - Hostel-wise department counts
SELECT cr.hostel_name,s.department,COUNT(*) AS students
FROM student s JOIN v_current_residence cr ON cr.student_id=s.student_id
GROUP BY cr.hostel_name,s.department ORDER BY cr.hostel_name,s.department;

PROMPT Q08 - Frequently reported maintenance categories
SELECT p.category,COUNT(*) AS complaint_count
FROM complaint p CROSS JOIN report_config c
WHERE p.raised_date>=c.window_start AND p.raised_date<c.as_of_date
GROUP BY p.category ORDER BY complaint_count DESC,p.category;

PROMPT Q09 - Disciplinary incident statistics by hostel and severity
SELECT h.hostel_name,d.severity,COUNT(*) AS incident_count
FROM disciplinary_incident d JOIN allocation a ON a.allocation_id=d.allocation_id
JOIN bed b ON b.bed_id=a.bed_id JOIN room r ON r.room_id=b.room_id
JOIN hostel h ON h.hostel_id=r.hostel_id CROSS JOIN report_config c
WHERE d.incident_date>=c.window_start AND d.incident_date<c.as_of_date
GROUP BY h.hostel_name,d.severity ORDER BY h.hostel_name,d.severity;

PROMPT Q10 - Student support decision report (all current residents)
SELECT student_id,hostel_name,attendance_pct,outstanding_fee,
       complaint_count,unresolved_complaints,disciplinary_incidents,
       risk_score,data_quality,risk_status
FROM v_student_support_risk ORDER BY risk_score DESC,student_id;

PROMPT Q11 - Above-average outstanding fees (benchmark includes all current residents, including zero balances)
SELECT student_id,student_name,outstanding_fee
FROM v_student_support_risk
WHERE outstanding_fee>(SELECT AVG(outstanding_fee) FROM v_student_support_risk)
ORDER BY outstanding_fee DESC;

PROMPT Q12 - Occupancy above the operational capacity benchmark (90 percent)
SELECT o.hostel_name,o.occupancy_pct,c.occupancy_benchmark
FROM v_hostel_occupancy o CROSS JOIN report_config c
WHERE o.occupancy_pct>c.occupancy_benchmark;

PROMPT Q13 - Students with repeated complaints (at least two in the window)
SELECT student_id,student_name,complaint_count,unresolved_complaints
FROM v_student_support_stats WHERE complaint_count>=2 ORDER BY complaint_count DESC;

PROMPT Q14 - attendance below the students own hostel average
SELECT s.student_id,s.student_name,s.hostel_name,s.attendance_pct
FROM v_student_support_stats s
WHERE s.hostel_id IS NOT NULL AND s.missing_days=0
AND s.attendance_pct < (
    SELECT AVG(peer.attendance_pct) FROM v_student_support_stats peer
    WHERE peer.hostel_id=s.hostel_id AND peer.missing_days=0
)
ORDER BY s.hostel_id,s.attendance_pct;

PROMPT Q15 - Above-average maintenance expenditure (includes zero-cost hostels)
SELECT hostel_name,maintenance_cost FROM v_hostel_performance
WHERE maintenance_cost > (SELECT AVG(maintenance_cost) FROM v_hostel_performance);

PROMPT Q16 - Repeated disciplinary incidents (at least two in the window)
SELECT student_id,student_name,disciplinary_incidents
FROM v_student_support_stats WHERE disciplinary_incidents>=2;

PROMPT Q17 - Integrated hostel performance
SELECT * FROM v_hostel_performance ORDER BY hostel_id;

PROMPT Q18 - Bed vacancies: NOT EXISTS subquery
SELECT h.hostel_name,r.room_no,b.bed_no
FROM bed b JOIN room r ON r.room_id=b.room_id JOIN hostel h ON h.hostel_id=r.hostel_id
WHERE b.service_status='AVAILABLE'
AND NOT EXISTS (SELECT 1 FROM v_current_residence c WHERE c.bed_id=b.bed_id)
ORDER BY h.hostel_id,r.room_no,b.bed_no;

PROMPT Q19 - Visitor history (including actual entry and exit times)
SELECT s.student_name,h.hostel_name,v.visitor_name,v.relationship,v.entry_time,v.exit_time
FROM visitor_visit v JOIN allocation a ON a.allocation_id=v.allocation_id
JOIN student s ON s.student_id=a.student_id
JOIN bed b ON b.bed_id=a.bed_id JOIN room r ON r.room_id=b.room_id
JOIN hostel h ON h.hostel_id=r.hostel_id CROSS JOIN report_config c
WHERE v.entry_time>=CAST(c.window_start AS TIMESTAMP) AND v.entry_time<CAST(c.as_of_date AS TIMESTAMP)
ORDER BY v.entry_time,s.student_id;

PROMPT Q20 - Allocation and transfer history
SELECT s.student_name,h.hostel_name,r.room_no,b.bed_no,a.start_date,a.end_date
FROM allocation a JOIN student s ON s.student_id=a.student_id
JOIN bed b ON b.bed_id=a.bed_id JOIN room r ON r.room_id=b.room_id
JOIN hostel h ON h.hostel_id=r.hostel_id ORDER BY s.student_id,a.start_date;

PROMPT Q21 - Administrative attention queue
SELECT student_id,student_name,hostel_name,risk_status,data_quality,
       missing_days,outstanding_fee,unresolved_complaints
FROM v_student_support_risk WHERE risk_status<>'NORMAL'
ORDER BY CASE risk_status WHEN 'HIGH PRIORITY' THEN 1 ELSE 2 END,risk_score DESC,student_id;
