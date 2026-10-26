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
