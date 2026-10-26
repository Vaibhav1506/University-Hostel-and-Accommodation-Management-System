-- SQL*Plus, SQLcl, or Oracle SQL Developer (Run Script / F5).
-- Connect as your project user. Unrelated existing objects are allowed.
-- Never run in SYS or SYSTEM; existing hostel objects are never replaced.
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
@@01_schema.sql
@@02_sample_data.sql
@@03_views.sql
@@05_verify.sql
@@04_reports.sql
COMMIT;
SPOOL OFF
PROMPT Installation, assertions, and reports completed.
-- No EXIT: leave the session available for screenshots and exploration.
