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
