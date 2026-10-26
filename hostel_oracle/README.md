# Case study 6 — Oracle implementation

This is a proposed design for the University Hostel and Accommodation Management System in the supplied assignment. The assignment requires students to identify and justify their own entities, rules, and priority thresholds. Review and adapt these choices with your team and be ready to explain them.

![Detailed hostel accommodation ER diagram](er_diagram.png)

## Files and execution

| File | Purpose |
|---|---|
| `er_diagram.png` | Detailed ER diagram with all 64 business attributes, Oracle data types, keys, required fields, and cardinalities |
| `ER_DIAGRAM.md` | Full attribute list, keys, and relationship explanation |
| `01_schema.sql` | 12 business tables, 2 configuration/locking tables, constraints, indexes, and PL/SQL triggers |
| `02_sample_data.sql` | Synthetic student, allocation, fee, attendance, complaint, visitor, and discipline data |
| `03_views.sql` | 6 views for occupancy, fees, attendance, support priority, and hostel performance |
| `04_reports.sql` | 21 numbered reports including joins, subqueries, a correlated subquery, and administrative insights |
| `05_verify.sql` | Automated success/error assertions and reversible INSERT/UPDATE/DELETE demonstration |
| `run_all.sql` | Installs everything in order, verifies it, and displays the reports |
| `hostel_complete.sql` | Standalone version of the same installer; no companion SQL files needed |

Use Oracle Database 19c or later, with SQL*Plus, SQLcl, or SQL Developer. The scripts use Oracle SQL and PL/SQL, not MySQL syntax. IDs are explicit numeric keys for clear, reproducible lab data; there is no sequence or automatic ID generator. Choose new IDs when adding records.

1. Connect as your project user (for example, `VAIBHAV`). Existing unrelated lab objects are allowed; the names used by this hostel project must be unused. The user needs CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE TRIGGER, CREATE PROCEDURE, and a tablespace quota. CURRENT_SCHEMA must match the connected user. Do not install into SYS or SYSTEM.
2. In SQL*Plus, change to the `hostel_oracle` directory before starting the client and run `@run_all.sql`. Alternatively, run the installer using its full local path.
3. In SQL Developer, open `hostel_complete.sql` and use **Run Script (F5)** with the student connection. This is an alternative to `run_all.sql`; do not run both installers in the same schema.
4. Read `ALL ASSERTIONS PASSED` and the 21 query outputs. Take your own screenshots during your demonstration.

Before creating any objects, the installer checks all 33 explicitly named hostel tables, indexes, triggers, and views, plus the five named constraints. If a required name is already in use, installation stops without replacing existing objects. Unrelated lab objects are preserved, and compilation checks cover only this project's views and triggers. Run one installer once; an existing hostel installation will be rejected by the name checks.

The installer commits its sample data, and Oracle DDL commits automatically. Finish any unrelated transaction before installing. A later installation failure can leave partially created hostel objects behind; inspect the error and those objects before retrying. No reset/drop script is supplied. To re-run reports on an installed schema, run `04_reports.sql` directly. Output is displayed in the SQL client without creating a log file.

## Design and cardinalities

One hostel has many rooms; one room has many beds. Each allocation belongs to one student and one bed. A student or bed can have many allocations over time, but overlapping periods are forbidden. One allocation has many fee charges, attendance records, visitor visits, and disciplinary incidents. One fee charge can receive multiple payments. A student raises complaints about rooms, and a complaint can incur multiple maintenance expenses.

Each child row has exactly one parent per foreign key; a parent can have zero or many children. `COMPLAINT` refers directly to a student and a room, allowing complaints about a room after a transfer. Visitor and disciplinary records attach to allocations to preserve the associated hostel when a student moves.

Compound unique keys, also enforced in SQL:

- Room: `(hostel_id, room_no)`.
- Bed: `(room_id, bed_no)`.
- Fee charge: `(allocation_id, billing_period)`.
- Attendance: `(allocation_id, attendance_date)`.

`report_config` and `c6_write_lock` are implementation tables and are intentionally omitted from the business ER diagram. The first defines a reproducible reporting window; the second provides transaction locks used by integrity triggers.

Separate fee charges/payments support partial payments. Separate complaints/expenses avoid counting a complaint twice when it has multiple expenses. Bed counts are derived from bed records; attendance percentage, balances, occupancy, and priority are derived through views. The design avoids storing those derived totals redundantly.

## Business rules and implementation boundaries

- Allocation intervals are **[start_date, end_date)**. End date is the first unoccupied day; NULL means open-ended. Dates have no time component. A transfer can end one allocation and begin the next on the same date.
- Allocation triggers reject overlapping student or bed bookings, including future bookings. An allocation's student and bed cannot be reassigned; close it and insert a new allocation instead.
- Bed `AVAILABLE` means serviceable, not vacant. Vacancy additionally requires no allocation active at the report cutoff. Out-of-service beds cannot receive new bookings. An occupied or future-booked bed cannot be disabled until its allocations are closed/moved.
- Attendance must fall inside an allocation, and closing an allocation cannot invalidate its recorded attendance.
- Positive charges/payments are required. Total payments cannot exceed a charge and cannot precede it. Lowering a charge below its existing payments is rejected. Refunds, credit balances, and fee waivers are outside this lab model.
- Primary/foreign keys, positive-value checks, allowed-status checks, date checks, and compound unique constraints enforce row-level consistency. Referenced parents cannot be deleted.
- Shared transaction-lock rows serialize allocation and finance writes. This is suitable for a small lab demonstration; a large deployment should use more granular locking. The test suite checks behavior in one session; multi-session race tests are not included.
- Student, room, hostel, and bed identities are treated as stable master data. The model is not a full temporal audit database. Bed serviceability is current state, so old occupancy reports do not reconstruct historical maintenance closures.
- Visitor and disciplinary foreign keys identify the relevant allocation; only attendance currently has a trigger enforcing dates within that allocation. Complaint-room residency, maintenance expense chronology, billing proration, and eligibility policies are not inferred or automatically enforced.

## Reporting definitions

Default report window: **6 September 2026 through 5 October 2026**, with cutoff **6 October 2026 at 00:00**. Transactions/events use `>= window_start AND < as_of_date`. Occupancy uses the allocation active at the cutoff.

Change dates with:

```sql
UPDATE report_config
SET window_start=DATE '2026-09-06', as_of_date=DATE '2026-10-06'
WHERE config_id=1;
COMMIT;
```

Run the baseline assertions only with the original data/configuration. New report dates can correctly produce different results.

- Attendance = present / (present + absent) × 100. Approved leave is excluded. Expected days are derived from overlap between allocation dates and the reporting window. Missing attendance is reported separately and is not silently converted to absence.
- Incomplete attendance cannot produce NORMAL priority: it leads to at least NEEDS ATTENTION. A null attendance percentage is not treated as zero attendance. Hostel-average attendance comparisons exclude incomplete data and use a mean of student percentages.
- Outstanding balance includes all charges raised before the cutoff, less payments before the cutoff. Overdue balance additionally requires the due date to be before the cutoff.
- Fee collection Q04 includes only payments within the window. It is therefore **138,500**, whereas cumulative payments before the cutoff total **277,000**. Earlier installments explain the difference.
- Financial hostel collection is attributed to the allocation billed. Student-support outstanding totals are associated with a student's current hostel.
- Complaint counts use complaints raised during the window. An unresolved complaint is one unresolved at the cutoff; the priority score uses this unresolved subset. Old complaints raised before the window are not included in that score.
- Disciplinary counts use incidents during the window. An incident is an administrative record, not an automated finding of wrongdoing.
- Occupancy = occupied beds / serviceable beds × 100. Zero capacity produces NULL, not a divide-by-zero error. The planning benchmark is 90%; actual overbooking remains prohibited.

## Explainable support-priority model

These are illustrative project thresholds, not official university policy. Complaints indicate a need for maintenance support and should not penalize students for reporting problems.

| Indicator | 0 points | 1 point | 2 points |
|---|---|---|---|
| Attendance | >=85% | >=75% and <85% | <75% |
| Outstanding fee | 0 | >0 and <=10,000 | >10,000 |
| Unresolved complaints in window | 0–1 | 2–3 | >=4 |
| Disciplinary incidents in window | 0 | 1 | >=2 |

Score >=5: HIGH PRIORITY. Score 2–4: NEEDS ATTENTION. Score 0–1: NORMAL, unless attendance is incomplete, which requires NEEDS ATTENTION. A student already scoring >=5 stays HIGH PRIORITY when data is incomplete. Only current residents are classified. The high threshold identifies several concurrent support concerns; the middle band flags an isolated severe or several mild concerns. Human review remains necessary.

## Expected baseline results

| Item | Expected |
|---|---:|
| Students / current residents | 19 / 18 |
| Hostels / rooms / beds | 3 / 9 / 27 |
| Allocations including historical transfer | 19 |
| Attendance records / missing attendance days | 538 / 2 |
| Payments / complaints / maintenance expenses | 34 / 12 / 5 |
| Visitor records / disciplinary incidents | 18 / 5 |
| Serviceable / occupied / vacant beds | 26 / 18 / 8 |
| Total charges / cumulative payments / outstanding | 324,000 / 277,000 / 47,000 |
| Maintenance expenditure | 5,000 |
| HIGH PRIORITY / NEEDS ATTENTION / NORMAL | 2 / 3 / 13 |

High priority: students 1 and 7. Needs attention: students 2, 8, and 18. Student 18 is flagged for missing attendance even though recorded attendance is 100%. Student 19 is unallocated and excluded from resident classification.

H01 occupancy is 100%; H02 is 66.67%; H03 is 54.55% (6 occupied out of 11 serviceable beds).

## Assignment coverage and demonstration

1. Explain the ER model, PK/FK choices, compound keys, history, and normalization.
2. Show schema creation, ALTER TABLE, constraints, and sample INSERTs.
3. Show the reversible UPDATE/DELETE demonstration and rejected invalid operations in `05_verify.sql`.
4. Show reports Q01–Q10, advanced reports Q11–Q17, and the correlated query Q14.
5. Explain why the risk report aggregates each data source before joining it. Show a high-priority student, a normal student, and missing-data student 18.
6. Add execution screenshots, query explanations, contribution details, and design assumptions to your project report. The report and screenshots are not generated by these SQL files.
