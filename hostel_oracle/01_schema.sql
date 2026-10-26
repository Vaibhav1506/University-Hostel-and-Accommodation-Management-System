
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
