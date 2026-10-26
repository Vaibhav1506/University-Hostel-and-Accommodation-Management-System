WHENEVER OSERROR EXIT FAILURE ROLLBACK
WHENEVER SQLERROR EXIT SQL.SQLCODE ROLLBACK
SET SERVEROUTPUT ON
SET ECHO ON
SET FEEDBACK ON
SET PAGESIZE 100
SET LINESIZE 220
SET TRIMSPOOL ON
SET VERIFY OFF
ALTER SESSION SET NLS_DATE_FORMAT='YYYY-MM-DD';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT='YYYY-MM-DD HH24:MI:SS';

DECLARE
    v_objects NUMBER;
    v_conflict VARCHAR2(256);
BEGIN
    IF SYS_CONTEXT('USERENV','SESSION_USER') IN ('SYS','SYSTEM') THEN
        RAISE_APPLICATION_ERROR(-20991,'Connect as your project user, not SYS/SYSTEM.');
    END IF;
    IF SYS_CONTEXT('USERENV','CURRENT_SCHEMA') <> SYS_CONTEXT('USERENV','SESSION_USER') THEN
        RAISE_APPLICATION_ERROR(-20994,'CURRENT_SCHEMA must match the connected project user.');
    END IF;
    SELECT COUNT(*), MIN(object_name || ' (' || object_type || ')')
    INTO v_objects, v_conflict
    FROM user_objects
    WHERE object_name IN (
        'C6_WRITE_LOCK','REPORT_CONFIG','STUDENT','HOSTEL','ROOM','BED',
        'ALLOCATION','FEE_CHARGE','PAYMENT','ATTENDANCE','COMPLAINT',
        'MAINTENANCE_EXPENSE','VISITOR_VISIT','DISCIPLINARY_INCIDENT',
        'IX_ALLOCATION_STUDENT','IX_ALLOCATION_BED','IX_PAYMENT_CHARGE',
        'IX_COMPLAINT_STUDENT','IX_COMPLAINT_ROOM','IX_EXPENSE_COMPLAINT',
        'IX_VISIT_ALLOCATION','IX_INCIDENT_ALLOCATION',
        'TRG_ALLOCATION_GUARD','TRG_ATTENDANCE_GUARD','TRG_PAYMENT_GUARD',
        'TRG_CHARGE_GUARD','TRG_BED_GUARD',
        'V_CURRENT_RESIDENCE','V_FEE_BALANCE','V_HOSTEL_OCCUPANCY',
        'V_STUDENT_SUPPORT_STATS','V_STUDENT_SUPPORT_RISK','V_HOSTEL_PERFORMANCE'
    );
    IF v_objects>0 THEN
        RAISE_APPLICATION_ERROR(-20992,'Hostel object name already in use: ' || v_conflict || '. Installation stopped; existing objects were not replaced.');
    END IF;
    SELECT COUNT(*), MIN(constraint_name)
    INTO v_objects, v_conflict
    FROM user_constraints
    WHERE constraint_name IN (
        'UQ_ROOM_HOSTEL','CK_BED_SERVICE','UQ_BED_ROOM',
        'UQ_FEE_PERIOD','UQ_ATTENDANCE_DAY'
    );
    IF v_objects>0 THEN
        RAISE_APPLICATION_ERROR(-20993,'Hostel constraint name already in use: ' || v_conflict || '. Installation stopped; existing constraints were not replaced.');
    END IF;
    DBMS_OUTPUT.PUT_LINE('Hostel name checks passed. Unrelated existing objects will be preserved.');
END;
/

SPOOL hostel_run.log


CREATE TABLE c6_write_lock (
    lock_name VARCHAR2(20) PRIMARY KEY,
    token NUMBER DEFAULT 0 NOT NULL
);
INSERT INTO c6_write_lock(lock_name) VALUES ('ALLOCATION');
INSERT INTO c6_write_lock(lock_name) VALUES ('FINANCE');

CREATE TABLE report_config (
    config_id NUMBER PRIMARY KEY CHECK (config_id = 1),
    window_start DATE NOT NULL,
    as_of_date DATE NOT NULL,
    occupancy_benchmark NUMBER(5,2) DEFAULT 90 NOT NULL,
    CHECK (window_start < as_of_date),
    CHECK (window_start = TRUNC(window_start)),
    CHECK (as_of_date = TRUNC(as_of_date)),
    CHECK (occupancy_benchmark BETWEEN 0 AND 100)
);
INSERT INTO report_config VALUES (1, DATE '2026-09-06', DATE '2026-10-06', 90);

CREATE TABLE student (
    student_id NUMBER PRIMARY KEY,
    registration_no VARCHAR2(20) NOT NULL UNIQUE,
    student_name VARCHAR2(100) NOT NULL,
    department VARCHAR2(40) NOT NULL,
    email VARCHAR2(120) NOT NULL UNIQUE,
    phone VARCHAR2(20)
);
ALTER TABLE student ADD emergency_contact VARCHAR2(20);

CREATE TABLE hostel (
    hostel_id NUMBER PRIMARY KEY,
    hostel_name VARCHAR2(60) NOT NULL UNIQUE,
    location VARCHAR2(100) NOT NULL
);

CREATE TABLE room (
    room_id NUMBER PRIMARY KEY,
    hostel_id NUMBER NOT NULL REFERENCES hostel(hostel_id),
    room_no VARCHAR2(10) NOT NULL,
    room_type VARCHAR2(20) NOT NULL CHECK (room_type IN ('AC', 'NON_AC')),
    CONSTRAINT uq_room_hostel UNIQUE (hostel_id, room_no)
);

CREATE TABLE bed (
    bed_id NUMBER PRIMARY KEY,
    room_id NUMBER NOT NULL REFERENCES room(room_id),
    bed_no VARCHAR2(10) NOT NULL,
    service_status VARCHAR2(20) DEFAULT 'AVAILABLE' NOT NULL,
    CONSTRAINT ck_bed_service CHECK (service_status IN ('AVAILABLE', 'OUT_OF_SERVICE')),
    CONSTRAINT uq_bed_room UNIQUE (room_id, bed_no)
);

CREATE TABLE allocation (
    allocation_id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL REFERENCES student(student_id),
    bed_id NUMBER NOT NULL REFERENCES bed(bed_id),
    start_date DATE NOT NULL,
    end_date DATE,
    CHECK (start_date = TRUNC(start_date)),
    CHECK (end_date = TRUNC(end_date)),
    CHECK (end_date IS NULL OR end_date > start_date)
);

CREATE TABLE fee_charge (
    charge_id NUMBER PRIMARY KEY,
    allocation_id NUMBER NOT NULL REFERENCES allocation(allocation_id),
    billing_period VARCHAR2(30) NOT NULL,
    charge_date DATE NOT NULL,
    due_date DATE NOT NULL,
    amount NUMBER(12,2) NOT NULL CHECK (amount > 0),
    CHECK (due_date >= charge_date),
    CONSTRAINT uq_fee_period UNIQUE (allocation_id, billing_period)
);

CREATE TABLE payment (
    payment_id NUMBER PRIMARY KEY,
    charge_id NUMBER NOT NULL REFERENCES fee_charge(charge_id),
    payment_date DATE NOT NULL,
    amount NUMBER(12,2) NOT NULL CHECK (amount > 0),
    payment_mode VARCHAR2(20) NOT NULL,
    receipt_no VARCHAR2(40) NOT NULL UNIQUE,
    CHECK (payment_mode IN ('UPI', 'CARD', 'BANK', 'CASH'))
);

CREATE TABLE attendance (
    attendance_id NUMBER PRIMARY KEY,
    allocation_id NUMBER NOT NULL REFERENCES allocation(allocation_id),
    attendance_date DATE NOT NULL,
    attendance_status VARCHAR2(20) NOT NULL,
    CHECK (attendance_date = TRUNC(attendance_date)),
    CHECK (attendance_status IN ('PRESENT', 'ABSENT', 'APPROVED_LEAVE')),
    CONSTRAINT uq_attendance_day UNIQUE (allocation_id, attendance_date)
);

CREATE TABLE complaint (
    complaint_id NUMBER PRIMARY KEY,
    student_id NUMBER NOT NULL REFERENCES student(student_id),
    room_id NUMBER NOT NULL REFERENCES room(room_id),
    category VARCHAR2(30) NOT NULL,
    description VARCHAR2(500) NOT NULL,
    raised_date DATE NOT NULL,
    status VARCHAR2(20) DEFAULT 'OPEN' NOT NULL,
    resolved_date DATE,
    CHECK (category IN ('PLUMBING', 'ELECTRICAL', 'FURNITURE', 'CLEANING', 'NETWORK')),
    CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED')),
    CHECK (resolved_date IS NULL OR resolved_date >= raised_date),
    CHECK ((status = 'RESOLVED' AND resolved_date IS NOT NULL)
        OR (status IN ('OPEN', 'IN_PROGRESS') AND resolved_date IS NULL))
);

CREATE TABLE maintenance_expense (
    expense_id NUMBER PRIMARY KEY,
    complaint_id NUMBER NOT NULL REFERENCES complaint(complaint_id),
    expense_date DATE NOT NULL,
    amount NUMBER(12,2) NOT NULL CHECK (amount >= 0),
    description VARCHAR2(200) NOT NULL
);

CREATE TABLE visitor_visit (
    visit_id NUMBER PRIMARY KEY,
    allocation_id NUMBER NOT NULL REFERENCES allocation(allocation_id),
    visitor_name VARCHAR2(100) NOT NULL,
    relationship VARCHAR2(30) NOT NULL,
    entry_time TIMESTAMP NOT NULL,
    exit_time TIMESTAMP,
    CHECK (exit_time IS NULL OR exit_time >= entry_time)
);

CREATE TABLE disciplinary_incident (
    incident_id NUMBER PRIMARY KEY,
    allocation_id NUMBER NOT NULL REFERENCES allocation(allocation_id),
    incident_date DATE NOT NULL,
    incident_type VARCHAR2(60) NOT NULL,
    severity VARCHAR2(10) NOT NULL CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    action_taken VARCHAR2(200) NOT NULL
);

CREATE INDEX ix_allocation_student ON allocation(student_id, start_date, end_date);
CREATE INDEX ix_allocation_bed ON allocation(bed_id, start_date, end_date);
CREATE INDEX ix_payment_charge ON payment(charge_id);
CREATE INDEX ix_complaint_student ON complaint(student_id, raised_date);
CREATE INDEX ix_complaint_room ON complaint(room_id);
CREATE INDEX ix_expense_complaint ON maintenance_expense(complaint_id);
CREATE INDEX ix_visit_allocation ON visitor_visit(allocation_id);
CREATE INDEX ix_incident_allocation ON disciplinary_incident(allocation_id);

CREATE OR REPLACE TRIGGER trg_allocation_guard
FOR INSERT OR UPDATE OR DELETE ON allocation
COMPOUND TRIGGER
    v_token NUMBER;
    v_count NUMBER;
    v_service bed.service_status%TYPE;
    BEFORE STATEMENT IS
    BEGIN
        SELECT token INTO v_token FROM c6_write_lock
        WHERE lock_name = 'ALLOCATION' FOR UPDATE;
    END BEFORE STATEMENT;
    BEFORE EACH ROW IS
    BEGIN
        IF INSERTING OR UPDATING THEN
            SELECT service_status INTO v_service FROM bed WHERE bed_id = :NEW.bed_id;
            IF v_service <> 'AVAILABLE' AND
               (INSERTING OR :NEW.bed_id <> :OLD.bed_id) THEN
                RAISE_APPLICATION_ERROR(-20001, 'Cannot allocate an out-of-service bed.');
            END IF;
            IF UPDATING AND (:NEW.student_id <> :OLD.student_id OR
                            :NEW.bed_id <> :OLD.bed_id) THEN
                RAISE_APPLICATION_ERROR(-20002, 'Preserve history: close allocation and create a new one.');
            END IF;
        END IF;
    END BEFORE EACH ROW;
    AFTER STATEMENT IS
    BEGIN
        SELECT COUNT(*) INTO v_count
        FROM allocation a JOIN allocation b
          ON a.allocation_id < b.allocation_id
         AND (a.student_id = b.student_id OR a.bed_id = b.bed_id)
         AND a.start_date < NVL(b.end_date, DATE '9999-12-31')
         AND b.start_date < NVL(a.end_date, DATE '9999-12-31');
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20003, 'Overlapping student or bed allocation.');
        END IF;
        SELECT COUNT(*) INTO v_count FROM attendance t JOIN allocation a
          ON a.allocation_id = t.allocation_id
        WHERE t.attendance_date < a.start_date OR t.attendance_date >= NVL(a.end_date, DATE '9999-12-31');
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Allocation dates would invalidate attendance.');
        END IF;
    END AFTER STATEMENT;
END;
/

CREATE OR REPLACE TRIGGER trg_attendance_guard
BEFORE INSERT OR UPDATE ON attendance
FOR EACH ROW
DECLARE
    v_start DATE;
    v_end DATE;
    v_token NUMBER;
BEGIN
    SELECT token INTO v_token FROM c6_write_lock
    WHERE lock_name = 'ALLOCATION' FOR UPDATE;
    SELECT start_date, end_date INTO v_start, v_end FROM allocation
    WHERE allocation_id = :NEW.allocation_id;
    IF :NEW.attendance_date < v_start OR
       :NEW.attendance_date >= NVL(v_end, DATE '9999-12-31') THEN
        RAISE_APPLICATION_ERROR(-20005, 'Attendance must fall within the allocation period.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_payment_guard
FOR INSERT OR UPDATE OR DELETE ON payment
COMPOUND TRIGGER
    v_token NUMBER;
    v_count NUMBER;
    BEFORE STATEMENT IS
    BEGIN
        SELECT token INTO v_token FROM c6_write_lock
        WHERE lock_name = 'FINANCE' FOR UPDATE;
    END BEFORE STATEMENT;
    AFTER STATEMENT IS
    BEGIN
        SELECT COUNT(*) INTO v_count FROM (
            SELECT p.charge_id FROM payment p JOIN fee_charge f ON f.charge_id = p.charge_id
            GROUP BY p.charge_id, f.amount HAVING SUM(p.amount) > f.amount
        );
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Payments cannot exceed the charge.');
        END IF;
        SELECT COUNT(*) INTO v_count FROM payment p JOIN fee_charge f ON f.charge_id = p.charge_id
        WHERE p.payment_date < f.charge_date;
        IF v_count > 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'Payment cannot precede its charge.');
        END IF;
    END AFTER STATEMENT;
END;
/

CREATE OR REPLACE TRIGGER trg_charge_guard
BEFORE INSERT OR UPDATE OR DELETE ON fee_charge
FOR EACH ROW
DECLARE
    v_token NUMBER;
    v_paid NUMBER;
    v_earliest DATE;
BEGIN
    SELECT token INTO v_token FROM c6_write_lock
    WHERE lock_name = 'FINANCE' FOR UPDATE;
    IF UPDATING THEN
        SELECT NVL(SUM(amount), 0), MIN(payment_date) INTO v_paid, v_earliest
        FROM payment WHERE charge_id = :OLD.charge_id;
        IF :NEW.amount < v_paid OR :NEW.charge_date > v_earliest THEN
            RAISE_APPLICATION_ERROR(-20008, 'Charge change would invalidate existing payments.');
        END IF;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_bed_guard
FOR UPDATE ON bed
COMPOUND TRIGGER
    v_token NUMBER;
    v_count NUMBER;
    BEFORE STATEMENT IS
    BEGIN
        SELECT token INTO v_token FROM c6_write_lock
        WHERE lock_name = 'ALLOCATION' FOR UPDATE;
    END BEFORE STATEMENT;
    BEFORE EACH ROW IS
    BEGIN
        IF :NEW.room_id <> :OLD.room_id THEN
            SELECT COUNT(*) INTO v_count FROM allocation WHERE bed_id = :OLD.bed_id;
            IF v_count > 0 THEN
                RAISE_APPLICATION_ERROR(-20009, 'Cannot relocate a bed with allocation history.');
            END IF;
        END IF;
        IF :NEW.service_status = 'OUT_OF_SERVICE' THEN
            SELECT COUNT(*) INTO v_count FROM allocation WHERE bed_id = :OLD.bed_id
              AND NVL(end_date, DATE '9999-12-31') > TRUNC(SYSDATE);
            IF v_count > 0 THEN
                RAISE_APPLICATION_ERROR(-20010, 'Close or move current/future allocations before disabling a bed.');
            END IF;
        END IF;
    END BEFORE EACH ROW;
END;
/

COMMIT;



INSERT ALL
 INTO hostel VALUES (1, 'H01 - Kaveri', 'North Campus')
 INTO hostel VALUES (2, 'H02 - Krishna', 'East Campus')
 INTO hostel VALUES (3, 'H03 - Godavari', 'West Campus')
SELECT 1 FROM dual;

DECLARE
    v_bed NUMBER := 0;
    v_room NUMBER;
    v_alloc NUMBER;
    v_paid NUMBER;
    v_present NUMBER;
    v_status VARCHAR2(20);
BEGIN
    FOR h IN 1..3 LOOP
        FOR r IN 1..3 LOOP
            v_room := h * 100 + r;
            INSERT INTO room VALUES (v_room, h, TO_CHAR(r), CASE WHEN r = 1 THEN 'AC' ELSE 'NON_AC' END);
            FOR b IN 1..(h + 1) LOOP
                v_bed := v_bed + 1;
                INSERT INTO bed VALUES (v_bed, v_room, TO_CHAR(b), 'AVAILABLE');
            END LOOP;
        END LOOP;
    END LOOP;

    FOR s IN 1..18 LOOP
        INSERT INTO student VALUES (
            s, '26BCE' || LPAD(s, 4, '0'), 'Student ' || LPAD(s, 2, '0'),
            CASE MOD(s, 3) WHEN 0 THEN 'ECE' WHEN 1 THEN 'CSE' ELSE 'IT' END,
            'student' || s || '@example.edu', '900000' || LPAD(s, 4, '0'),
            '800000' || LPAD(s, 4, '0')
        );
        v_bed := CASE WHEN s <= 12 THEN s ELSE s + 3 END;
        v_alloc := 100 + s;
        INSERT INTO allocation VALUES (v_alloc, s, v_bed, DATE '2026-09-01', NULL);
        INSERT INTO fee_charge VALUES (1000+s, v_alloc, '2026-SEP', DATE '2026-09-01', DATE '2026-09-15', 18000);
        v_paid := CASE s WHEN 1 THEN 0 WHEN 2 THEN 8000 WHEN 7 THEN 4000
                         WHEN 8 THEN 15000 WHEN 13 THEN 16000 ELSE 18000 END;
        IF v_paid > 0 THEN
            INSERT INTO payment VALUES (s*10, 1000+s, DATE '2026-09-05', v_paid/2, 'BANK', 'REC-'||s||'-A');
            INSERT INTO payment VALUES (s*10+1, 1000+s, DATE '2026-09-10', v_paid/2, 'UPI', 'REC-'||s||'-B');
        END IF;
        v_present := CASE s
            WHEN 1 THEN 18 WHEN 2 THEN 23 WHEN 3 THEN 28 WHEN 4 THEN 30
            WHEN 5 THEN 26 WHEN 6 THEN 25 WHEN 7 THEN 21 WHEN 8 THEN 24
            WHEN 9 THEN 29 WHEN 10 THEN 30 WHEN 11 THEN 27 WHEN 12 THEN 28
            WHEN 13 THEN 29 WHEN 14 THEN 30 WHEN 15 THEN 27 WHEN 16 THEN 30
            WHEN 17 THEN 29 ELSE 28 END;
        FOR d IN 0..29 LOOP
            v_status := CASE WHEN d < v_present THEN 'PRESENT' ELSE 'ABSENT' END;
            IF s = 4 AND d < 2 THEN v_status := 'APPROVED_LEAVE'; END IF;
            IF NOT (s = 18 AND d >= 28) THEN
                INSERT INTO attendance VALUES (s*100+d, v_alloc, DATE '2026-09-06'+d, v_status);
            END IF;
        END LOOP;
        INSERT INTO visitor_visit VALUES (
            s, v_alloc, 'Visitor '||s, 'PARENT',
            TIMESTAMP '2026-09-20 10:00:00', TIMESTAMP '2026-09-20 11:00:00'
        );
    END LOOP;
END;
/

INSERT INTO allocation VALUES (1, 1, 3, DATE '2026-08-01', DATE '2026-09-01');
INSERT INTO student VALUES (19, '26BCE0019', 'Student 19', 'CSE', 'student19@example.edu', NULL, NULL);
UPDATE bed SET service_status = 'OUT_OF_SERVICE' WHERE bed_id = 27;

INSERT ALL
 INTO complaint VALUES (1,1,101,'PLUMBING','Leaking tap',DATE '2026-09-08','OPEN',NULL)
 INTO complaint VALUES (2,1,101,'ELECTRICAL','Light not working',DATE '2026-09-10','IN_PROGRESS',NULL)
 INTO complaint VALUES (3,1,101,'NETWORK','Network outage',DATE '2026-09-15','OPEN',NULL)
 INTO complaint VALUES (4,1,101,'FURNITURE','Damaged desk',DATE '2026-09-18','OPEN',NULL)
 INTO complaint VALUES (5,2,101,'PLUMBING','Drain blockage',DATE '2026-09-09','OPEN',NULL)
 INTO complaint VALUES (6,2,101,'CLEANING','Cleaning request',DATE '2026-09-14','OPEN',NULL)
 INTO complaint VALUES (7,2,101,'NETWORK','Weak connection',DATE '2026-09-19','IN_PROGRESS',NULL)
 INTO complaint VALUES (8,3,102,'ELECTRICAL','Fan repair',DATE '2026-09-07','RESOLVED',DATE '2026-09-11')
 INTO complaint VALUES (9,7,201,'PLUMBING','Pipe leak',DATE '2026-09-12','OPEN',NULL)
 INTO complaint VALUES (10,7,201,'NETWORK','Network outage',DATE '2026-09-17','OPEN',NULL)
 INTO complaint VALUES (11,7,201,'FURNITURE','Wardrobe repair',DATE '2026-09-21','IN_PROGRESS',NULL)
 INTO complaint VALUES (12,13,301,'CLEANING','Cleaning request',DATE '2026-09-22','RESOLVED',DATE '2026-09-23')
SELECT 1 FROM dual;

INSERT ALL
 INTO maintenance_expense VALUES (1,2,DATE '2026-09-12',800,'Inspection and materials')
 INTO maintenance_expense VALUES (2,8,DATE '2026-09-11',2500,'Fan replacement')
 INTO maintenance_expense VALUES (3,8,DATE '2026-09-11',500,'Installation labor')
 INTO maintenance_expense VALUES (4,11,DATE '2026-09-24',900,'Repair materials')
 INTO maintenance_expense VALUES (5,12,DATE '2026-09-23',300,'Cleaning supplies')
SELECT 1 FROM dual;

INSERT ALL
 INTO disciplinary_incident VALUES (1,101,DATE '2026-09-13','QUIET_HOURS','LOW','Counselling')
 INTO disciplinary_incident VALUES (2,101,DATE '2026-09-25','QUIET_HOURS','LOW','Written warning')
 INTO disciplinary_incident VALUES (3,102,DATE '2026-09-16','VISITOR_RULE','MEDIUM','Counselling')
 INTO disciplinary_incident VALUES (4,107,DATE '2026-09-10','QUIET_HOURS','LOW','Counselling')
 INTO disciplinary_incident VALUES (5,107,DATE '2026-09-28','PROPERTY_DAMAGE','HIGH','Administrative review')
SELECT 1 FROM dual;
COMMIT;




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



SET SERVEROUTPUT ON
PROMPT Automated assertions: failure stops the script
DECLARE
    v_n NUMBER;
    PROCEDURE assert_eq(p_label VARCHAR2,p_actual NUMBER,p_expected NUMBER) IS
    BEGIN
        IF p_actual IS NULL OR p_actual<>p_expected THEN
            RAISE_APPLICATION_ERROR(-20990,p_label||': expected '||p_expected||', got '||NVL(TO_CHAR(p_actual),'NULL'));
        END IF;
        DBMS_OUTPUT.PUT_LINE('PASS: '||p_label);
    END;
    PROCEDURE rejects(p_label VARCHAR2,p_sql VARCHAR2,p_expected_code NUMBER) IS
        v_code NUMBER := 0;
    BEGIN
        SAVEPOINT reject_test;
        BEGIN
            EXECUTE IMMEDIATE p_sql;
        EXCEPTION WHEN OTHERS THEN v_code := SQLCODE;
        END;
        ROLLBACK TO reject_test;
        assert_eq(p_label,v_code,p_expected_code);
    END;
BEGIN
    SELECT COUNT(*) INTO v_n FROM user_errors
    WHERE name IN (
        'TRG_ALLOCATION_GUARD','TRG_ATTENDANCE_GUARD','TRG_PAYMENT_GUARD',
        'TRG_CHARGE_GUARD','TRG_BED_GUARD','V_CURRENT_RESIDENCE',
        'V_FEE_BALANCE','V_HOSTEL_OCCUPANCY','V_STUDENT_SUPPORT_STATS',
        'V_STUDENT_SUPPORT_RISK','V_HOSTEL_PERFORMANCE'
    );
    assert_eq('No hostel object compilation errors',v_n,0);
    SELECT COUNT(*) INTO v_n FROM student; assert_eq('19 students',v_n,19);
    SELECT COUNT(*) INTO v_n FROM bed; assert_eq('27 physical beds',v_n,27);
    SELECT COUNT(*) INTO v_n FROM allocation; assert_eq('19 allocations including history',v_n,19);
    SELECT COUNT(*) INTO v_n FROM attendance; assert_eq('538 attendance records',v_n,538);
    SELECT COUNT(*) INTO v_n FROM v_current_residence; assert_eq('18 current residents',v_n,18);
    SELECT SUM(available_beds) INTO v_n FROM v_hostel_occupancy; assert_eq('8 vacant serviceable beds',v_n,8);
    SELECT SUM(charged_amount) INTO v_n FROM v_fee_balance; assert_eq('Charges total 324000',v_n,324000);
    SELECT SUM(paid_amount) INTO v_n FROM v_fee_balance; assert_eq('Payments total 277000',v_n,277000);
    SELECT SUM(outstanding_amount) INTO v_n FROM v_fee_balance; assert_eq('Outstanding total 47000',v_n,47000);
    SELECT SUM(maintenance_cost) INTO v_n FROM v_hostel_performance; assert_eq('Maintenance total 5000',v_n,5000);
    SELECT COUNT(*) INTO v_n FROM v_student_support_risk WHERE risk_status='HIGH PRIORITY';
    assert_eq('2 high-priority students',v_n,2);
    SELECT COUNT(*) INTO v_n FROM v_student_support_risk WHERE risk_status='NEEDS ATTENTION';
    assert_eq('3 students needing attention',v_n,3);
    SELECT COUNT(*) INTO v_n FROM v_student_support_risk WHERE risk_status='NORMAL';
    assert_eq('13 normal-priority students',v_n,13);
    SELECT risk_score INTO v_n FROM v_student_support_risk WHERE student_id=1;
    assert_eq('Student 1 score is 8 (no join multiplication)',v_n,8);
    SELECT attendance_pct INTO v_n FROM v_student_support_stats WHERE student_id=4;
    assert_eq('Approved leave excluded from attendance denominator',v_n,100);
    SELECT missing_days INTO v_n FROM v_student_support_stats WHERE student_id=18;
    assert_eq('Missing attendance detected',v_n,2);
    SELECT COUNT(*) INTO v_n FROM v_student_support_risk WHERE student_id=19;
    assert_eq('Unallocated student excluded from resident risk report',v_n,0);

    rejects('Reject overlapping bed allocations',q'[INSERT INTO allocation VALUES (9001,19,1,DATE '2026-10-06',NULL)]',-20003);
    rejects('Reject overlapping student allocations',q'[INSERT INTO allocation VALUES (9002,1,13,DATE '2026-10-06',NULL)]',-20003);
    rejects('Reject out-of-service bed',q'[INSERT INTO allocation VALUES (9003,19,27,DATE '2026-10-06',NULL)]',-20001);
    rejects('Reject invalid foreign key',q'[INSERT INTO allocation VALUES (9004,999,13,DATE '2026-10-06',NULL)]',-2291);
    rejects('Reject negative payment',q'[INSERT INTO payment VALUES (9001,1001,DATE '2026-10-01',-1,'CASH','TEST-NEG')]',-2290);
    rejects('Reject overpayment',q'[INSERT INTO payment VALUES (9002,1003,DATE '2026-10-01',1,'CASH','TEST-OVER')]',-20006);
    rejects('Reject payment before charge',q'[INSERT INTO payment VALUES (9003,1001,DATE '2026-08-01',1,'CASH','TEST-DATE')]',-20007);
    rejects('Reject charge smaller than existing payments','UPDATE fee_charge SET amount=1 WHERE charge_id=1003',-20008);
    rejects('Reject attendance outside allocation',q'[INSERT INTO attendance VALUES (9001,101,DATE '2026-08-31','PRESENT')]',-20005);
    rejects('Reject duplicate daily attendance',q'[INSERT INTO attendance VALUES (9002,101,DATE '2026-09-06','PRESENT')]',-1);
    rejects('Reject closing allocation before recorded attendance',q'[UPDATE allocation SET end_date=DATE '2026-09-20' WHERE allocation_id=101]',-20004);
    rejects('Reject alteration of historical bed assignment','UPDATE allocation SET bed_id=13 WHERE allocation_id=101',-20002);
    rejects('Reject disabling an occupied bed',q'[UPDATE bed SET service_status='OUT_OF_SERVICE' WHERE bed_id=1]',-20010);
    rejects('Reject deletion of referenced hostel','DELETE FROM hostel WHERE hostel_id=1',-2292);

    SAVEPOINT transfer_test;
    INSERT INTO allocation VALUES (9101,19,13,DATE '2026-10-06',DATE '2026-10-07');
    INSERT INTO allocation VALUES (9102,19,14,DATE '2026-10-07',NULL);
    SELECT COUNT(*) INTO v_n FROM allocation WHERE student_id=19;
    assert_eq('Back-to-back allocations are accepted',v_n,2);
    ROLLBACK TO transfer_test;
    DBMS_OUTPUT.PUT_LINE('ALL ASSERTIONS PASSED. Baseline data preserved.');
END;
/

PROMPT Successful INSERT / UPDATE / DELETE demonstration
SAVEPOINT dml_demo;
INSERT INTO visitor_visit VALUES (9999,101,'Demo Visitor','GUARDIAN',TIMESTAMP '2026-10-05 10:00:00',NULL);
UPDATE visitor_visit SET exit_time=TIMESTAMP '2026-10-05 11:00:00' WHERE visit_id=9999;
SELECT visit_id,visitor_name,entry_time,exit_time FROM visitor_visit WHERE visit_id=9999;
DELETE FROM visitor_visit WHERE visit_id=9999;
SELECT COUNT(*) AS demo_rows_after_delete FROM visitor_visit WHERE visit_id=9999;
ROLLBACK TO dml_demo;

PROMPT Oracle compilation diagnostics (must return no rows)
SELECT name,type,line,position,text FROM user_errors
WHERE name IN (
    'TRG_ALLOCATION_GUARD','TRG_ATTENDANCE_GUARD','TRG_PAYMENT_GUARD',
    'TRG_CHARGE_GUARD','TRG_BED_GUARD','V_CURRENT_RESIDENCE',
    'V_FEE_BALANCE','V_HOSTEL_OCCUPANCY','V_STUDENT_SUPPORT_STATS',
    'V_STUDENT_SUPPORT_RISK','V_HOSTEL_PERFORMANCE'
)
ORDER BY name,sequence;



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

PROMPT Q14 - CORRELATED SUBQUERY: attendance below the student's own hostel average
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
WHERE maintenance_cost>(SELECT AVG(maintenance_cost) FROM v_hostel_performance);

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


COMMIT;
SPOOL OFF
PROMPT Installation, assertions, and reports completed.
