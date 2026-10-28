# University Hostel and Accommodation Management System

An Oracle SQL and PL/SQL database project for managing university hostel accommodation, fees, attendance, maintenance complaints, visitors, and disciplinary records.

This is an academic design for the supplied case study. Entities, business rules, and support-priority thresholds are project design choices that should be reviewed and justified during evaluation.

The implementation includes **14 tables** (12 business tables and 2 technical helpers), **6 views**, **5 integrity triggers**, **21 analytical reports**, and **33 automated SQL assertions**. The sample data is synthetic.

For the written answers to all five sections of the assignment, see [Case study questions and answers](#case-study-questions-and-answers).

![Hostel accommodation ER diagram in Chen notation](hostel_oracle/er_diagram.png)

## Project files

| File or section | Purpose |
|---|---|
| [01_schema.sql](hostel_oracle/01_schema.sql) | Tables, constraints, indexes, and PL/SQL triggers |
| [02_sample_data.sql](hostel_oracle/02_sample_data.sql) | Reproducible synthetic hostel data |
| [03_views.sql](hostel_oracle/03_views.sql) | Occupancy, fee balances, attendance, student support, and hostel performance |
| [04_reports.sql](hostel_oracle/04_reports.sql) | All 21 reports, including joins, subqueries, and a correlated subquery |
| [05_verify.sql](hostel_oracle/05_verify.sql) | 33 assertions and reversible INSERT/UPDATE/DELETE demonstrations |
| [run_all.sql](hostel_oracle/run_all.sql) | Modular installer |
| [hostel_complete.sql](hostel_oracle/hostel_complete.sql) | Standalone installer with all SQL included |
| [ER diagram](hostel_oracle/er_diagram.png) | Chen notation with entity rectangles, attribute ovals, underlined primary keys, relationship diamonds, and cardinalities |
| [ER diagram details](#entities-attributes-and-relational-schema) | Full attributes and key labels in this README; relationships follow in the next section |

The [assignment problem statement](Problem%20Statement.pdf) contains only Case Study 6, extracted from original pages 12-13. The SQL installers run directly in the Oracle tools listed below. The PNG ER diagram uses Chen notation for the 12 business entities, with 52 attribute ovals and 12 foreign-key links represented by relationships. The full list of 64 schema attributes is included in [Entities, attributes and relational schema](#entities-attributes-and-relational-schema); Oracle data types and integrity constraints are defined in `hostel_oracle/01_schema.sql`. Local environments and credentials are excluded from Git.

## Requirements

- Oracle Database 19c or later, with SQL*Plus, SQLcl, or Oracle SQL Developer.
- A project user with CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE TRIGGER, CREATE PROCEDURE, and a tablespace quota.
- The project object and named-constraint names must be unused. Unrelated existing lab objects are allowed. CURRENT_SCHEMA must match the connected user.

Use a project account with the required privileges. SYS and SYSTEM are deliberately rejected by the installer.

The scripts use Oracle SQL and PL/SQL. IDs are explicit numeric keys for reproducible lab data; there is no sequence or automatic ID generator. Choose new IDs when adding records.

## Install once

Start SQL*Plus or SQLcl from the repository root and connect with your own database details. Enter the password at the prompt:

```sql
CONNECT your_user@localhost:1521/your_service
@hostel_oracle/run_all.sql
```

For Oracle SQL Developer, open `hostel_oracle/hostel_complete.sql` using the project connection and select **Run Script (F5)**. Choose one installer; do not run both in the same schema.

The installer checks for conflicting names, creates the database objects, commits the sample data, runs the assertions, and displays the reports. Expected completion messages are:

```text
ALL ASSERTIONS PASSED. Baseline data preserved.
Installation, assertions, and reports completed.
```

Before creating any objects, the installer checks all 33 explicitly named hostel tables, indexes, triggers, and views, plus the five named constraints. If a required name is already in use, installation stops without replacing existing objects. Unrelated lab objects are preserved, and compilation checks cover only this project's views and triggers. Run one installer once; an existing hostel installation will be rejected by the name checks.

Finish unrelated transactions before installation: Oracle DDL commits automatically, and the installer also commits its sample data. A partial failure can leave created project objects behind. Existing project objects are never automatically dropped or replaced by the installer. Output is displayed in the SQL client without creating a log file.

## Run the demonstration

After installation, connect to the project schema and run the reports without reinstalling:

```sql
@hostel_oracle/04_reports.sql
```

To demonstrate integrity rules and reversible data changes:

```sql
@hostel_oracle/05_verify.sql
```

The verification script assumes the original sample data and reporting configuration. Its demonstration changes are rolled back. Review the ER diagram and explain the SQL alongside its output during the presentation.

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

## Case study questions and answers

The following answers follow the five sections of [Case Study 6 in the problem statement](Problem%20Statement.pdf). They describe the database implemented in this repository. Numerical examples are expected results derived from the supplied sample data and default reporting window; they are not a record of an Oracle execution. Execution evidence should be captured when the scripts are run.

### 1. Requirement Analysis and Database Design

**Problem statement:** Identify functional requirements, business rules, entities, attributes, relationships and cardinalities; design an ER diagram; convert it into a relational schema with suitable primary and foreign keys.

#### Functional requirements

The system must:

1. Store student registration, department, contact and emergency-contact information.
2. Maintain hostels, rooms, individual beds and bed serviceability.
3. Allocate beds to students, retain allocation history and prevent overlapping bookings for either a student or a bed.
4. Record hostel fee charges, installment payments, receipts, outstanding balances and overdue balances.
5. Record daily attendance against an allocation and distinguish presence, absence, approved leave and missing records.
6. Track room maintenance complaints, their resolution and associated maintenance expenses.
7. Record visitors and disciplinary incidents against the relevant allocation.
8. Generate occupancy, utilization, finance, attendance, maintenance and student-support reports for administration.

#### Business rules

A room belongs to one hostel, a bed belongs to one room, and an allocation references one student and one bed. Allocation dates use an inclusive start and exclusive end, so a transfer can occur on the day the preceding allocation ends. A student and a bed must each have no overlapping allocations. An out-of-service bed cannot receive a new allocation.

Attendance must occur within the allocation period, and each allocation can have only one attendance record per date. Each allocation can have only one fee charge per billing period. Payments must be positive, cannot precede their charge, and cannot exceed the amount charged in total. A resolved complaint must have a resolution date on or after its raised date. Foreign keys prevent orphan records and deletion of referenced parents.

Room numbers are unique within a hostel, and bed numbers are unique within a room. The [Business rules and implementation boundaries](#business-rules-and-implementation-boundaries) section distinguishes rules enforced by the database from policies outside the implementation.

#### Entities, attributes and relational schema

Each row below defines one business relation. PK means primary key, FK means foreign key, and UK means unique key. The primary key is shown separately; every remaining attribute is listed in the third column, with foreign keys marked `FK` and individual unique keys marked `UK`. Compound unique keys are listed in [Design and cardinalities](#design-and-cardinalities).

| Relation | Primary key (PK) | Other attributes | Foreign-key references |
|---|---|---|---|
| `STUDENT` | `student_id` | `registration_no` UK, `student_name`, `department`, `email` UK, `phone`, `emergency_contact` | None |
| `HOSTEL` | `hostel_id` | `hostel_name` UK, `location` | None |
| `ROOM` | `room_id` | `hostel_id` FK, `room_no`, `room_type` | `hostel_id -> HOSTEL.hostel_id` |
| `BED` | `bed_id` | `room_id` FK, `bed_no`, `service_status` | `room_id -> ROOM.room_id` |
| `ALLOCATION` | `allocation_id` | `student_id` FK, `bed_id` FK, `start_date`, `end_date` | `student_id -> STUDENT.student_id`; `bed_id -> BED.bed_id` |
| `FEE_CHARGE` | `charge_id` | `allocation_id` FK, `billing_period`, `charge_date`, `due_date`, `amount` | `allocation_id -> ALLOCATION.allocation_id` |
| `PAYMENT` | `payment_id` | `charge_id` FK, `payment_date`, `amount`, `payment_mode`, `receipt_no` UK | `charge_id -> FEE_CHARGE.charge_id` |
| `ATTENDANCE` | `attendance_id` | `allocation_id` FK, `attendance_date`, `attendance_status` | `allocation_id -> ALLOCATION.allocation_id` |
| `COMPLAINT` | `complaint_id` | `student_id` FK, `room_id` FK, `category`, `description`, `raised_date`, `status`, `resolved_date` | `student_id -> STUDENT.student_id`; `room_id -> ROOM.room_id` |
| `MAINTENANCE_EXPENSE` | `expense_id` | `complaint_id` FK, `expense_date`, `amount`, `description` | `complaint_id -> COMPLAINT.complaint_id` |
| `VISITOR_VISIT` | `visit_id` | `allocation_id` FK, `visitor_name`, `relationship`, `entry_time`, `exit_time` | `allocation_id -> ALLOCATION.allocation_id` |
| `DISCIPLINARY_INCIDENT` | `incident_id` | `allocation_id` FK, `incident_date`, `incident_type`, `severity`, `action_taken` | `allocation_id -> ALLOCATION.allocation_id` |

Two technical relations support the implementation: `REPORT_CONFIG(config_id PK, window_start, as_of_date, occupancy_benchmark)` stores one reporting configuration, and `C6_WRITE_LOCK(lock_name PK, token)` stores the allocation and finance lock rows. Neither has a foreign key.

Numeric primary keys provide stable identifiers even when descriptive information changes. Additional unique keys protect student registration numbers, student emails, hostel names and payment receipt numbers. The four compound unique keys listed in [Design and cardinalities](#design-and-cardinalities) protect business identities that depend on more than one attribute. Exact Oracle data types, nullability and constraints are defined in [01_schema.sql](hostel_oracle/01_schema.sql).

#### Relationships, cardinalities and ER conversion

| Parent | Child | Cardinality |
|---|---|---|
| `HOSTEL` | `ROOM` | One to many |
| `ROOM` | `BED` | One to many |
| `STUDENT` | `ALLOCATION` | One to many over time |
| `BED` | `ALLOCATION` | One to many over time |
| `ALLOCATION` | `FEE_CHARGE`, `ATTENDANCE`, `VISITOR_VISIT`, `DISCIPLINARY_INCIDENT` | One to many for each child relation |
| `FEE_CHARGE` | `PAYMENT` | One to many |
| `STUDENT` | `COMPLAINT` | One to many |
| `ROOM` | `COMPLAINT` | One to many |
| `COMPLAINT` | `MAINTENANCE_EXPENSE` | One to many |

A parent may have zero children; each child has exactly one parent for each listed foreign key. The [Chen ER diagram](hostel_oracle/er_diagram.png), shown at the beginning of this README, uses rectangles for entities, ovals for attributes, underlining for primary keys and diamonds for relationships. Its complete attribute inventory and key labels appear in [Entities, attributes and relational schema](#entities-attributes-and-relational-schema).

The ER model becomes a relational schema by creating a table for each entity and placing the parent's key in the child table for each one-to-many relationship. `ALLOCATION` connects students and beds with dates, resolving their many-to-many relationship over time. Its own primary key lets charges, attendance, visits and incidents refer to a particular stay. Complaint records reference the student and affected room directly, so a complaint can remain associated with that room after a transfer.

The design reduces redundancy by keeping student details in `STUDENT`, hostel details in `HOSTEL`, and room details in `ROOM`. Atomic attributes and separate rows for payments, visits and expenses avoid repeating groups. These separations also avoid copying parent descriptions into transaction tables. Occupancy, attendance percentages, outstanding fees and risk scores are calculated through views, avoiding inconsistent stored totals.

### 2. Database Implementation and Data Management

**Problem statement:** Demonstrate database creation and modification, integrity constraints, realistic interrelated data, record modification and deletion, consistency and referential integrity, and management of room and bed availability.

| Requirement | Answer and implementation |
|---|---|
| Structure creation and modification | [01_schema.sql](hostel_oracle/01_schema.sql) creates 14 tables, eight explicit indexes and five triggers. `ALTER TABLE student ADD emergency_contact VARCHAR2(20)` demonstrates modification after table creation. |
| Integrity constraints | Primary keys identify rows; foreign keys enforce parent references; `NOT NULL` protects required fields; unique constraints prevent duplicate business identifiers; `CHECK` constraints restrict statuses, dates and amounts. |
| Interrelated sample data | [02_sample_data.sql](hostel_oracle/02_sample_data.sql) inserts three hostels, nine rooms, 27 beds, 19 students, 19 allocations including a historical stay, 18 charges, 34 installment payments, 538 attendance records, 12 complaints, five expenses, 18 visits and five incidents. |
| Modification and deletion | [05_verify.sql](hostel_oracle/05_verify.sql) inserts a visitor, updates the exit time, selects the changed row, deletes it and checks that no matching row remains. Savepoints make the demonstration reversible. |
| Data consistency and referential integrity | Five triggers enforce allocation overlap, allocation dates for attendance, payment totals and chronology, charge changes, and bed changes. Verification cases deliberately attempt invalid writes and check the expected Oracle errors, including invalid foreign keys and deletion of a referenced hostel. |
| Room and bed availability | The bed service status records whether a bed is usable. An allocation active at the cutoff determines whether it is occupied. Q01 and Q02 summarize hostel and room capacity; Q18 lists serviceable beds with no current allocation. |

The sample records use fictional students and contacts, varied payments, attendance, complaint categories and incident histories. Fully paid and unpaid accounts, partial payments, a resolved complaint with multiple expenses, an out-of-service bed, a historical allocation and an unallocated student support meaningful comparisons and integrity demonstrations.

The modification/deletion sequence already included in `05_verify.sql` is:

```sql
SAVEPOINT dml_demo;
INSERT INTO visitor_visit
VALUES (9999,101,'Demo Visitor','GUARDIAN',
        TIMESTAMP '2026-10-05 10:00:00',NULL);
UPDATE visitor_visit
SET exit_time=TIMESTAMP '2026-10-05 11:00:00'
WHERE visit_id=9999;
SELECT visit_id,visitor_name,entry_time,exit_time
FROM visitor_visit WHERE visit_id=9999;
DELETE FROM visitor_visit WHERE visit_id=9999;
SELECT COUNT(*) AS demo_rows_after_delete
FROM visitor_visit WHERE visit_id=9999;
ROLLBACK TO dml_demo;
```

The expected final count is zero. Successful transfers are also demonstrated with adjacent allocation periods. Invalid operations such as overlapping bookings, negative payments, overpayments and duplicate daily attendance are checked separately. The 33 assertions are executable checks; their presence does not by itself establish that an Oracle run has passed.

### 3. SQL-Based Data Processing and Analysis

**Problem statement:** Generate information about occupancy, room use, attendance, fee collection and dues, complaints, hostel student statistics, frequent maintenance problems, disciplinary incidents and students requiring attention. Demonstrate filtering, transformation, calculation, grouping and summarization.

All queries below are implemented in [04_reports.sql](hostel_oracle/04_reports.sql), using the derived information in [03_views.sql](hostel_oracle/03_views.sql).

| Case study question | Report | Answer and SQL approach |
|---|---|---|
| What is each hostel's occupancy? | Q01 | Shows physical, serviceable, occupied and vacant beds, plus occupied beds / serviceable beds x 100. The occupancy view aggregates capacity and allocations separately and retains hostels without residents. |
| How well is each room utilized? | Q02 | Joins hostels and rooms, then left-joins beds and current allocations. `COUNT`, conditional `SUM` and `GROUP BY` calculate room utilization while retaining empty rooms. |
| What is each student's attendance? | Q03 | Shows present, absent, approved-leave and missing days, with present / (present + absent) x 100. Missing records are reported separately from absence. |
| How much hostel fee was collected? | Q04 | Joins payments through charges, allocations, beds and rooms; filters payment dates to the reporting window and sums by hostel. A left join and `NVL` retain zero-collection hostels. |
| Who has outstanding hostel fees? | Q05 | Filters student balances above zero and displays outstanding and overdue amounts, ordered by outstanding balance. Payments are deducted only if received before the cutoff. |
| What maintenance complaints were raised? | Q06 | Joins complaints to students, rooms and hostels. `CASE` determines resolution status at the cutoff, and date calculations show days open for complaints raised in the window. |
| What are the hostel-wise student statistics? | Q07 | Groups current residents by hostel and department and counts students in each represented group. |
| Which maintenance problems recur most often? | Q08 | Filters complaints to the window, groups by category and orders counts from highest to lowest to support maintenance planning. |
| What disciplinary incidents occurred? | Q09 | Attributes incidents to their allocation's hostel, filters incident dates and groups counts by hostel and severity. |
| Which students require administrative attention? | Q10 | Combines attendance, balances, complaints and incidents into one current-resident report with score, data quality and risk status. Q21 provides the filtered attention queue. |

`WHERE` performs date and threshold filtering; `CASE` transforms statuses and assigns points; `COUNT`, `SUM`, `AVG` and `GROUP BY` summarize records. `ROUND` formats calculated percentages, `NVL` supplies zero for absent counts or sums, and `NULLIF` prevents division by zero. `ORDER BY` makes priorities and frequent problems easier to identify. All date and denominator choices follow [Reporting definitions](#reporting-definitions).

### 4. Advanced SQL Joins, Subqueries and Views

**Problem statement:** Use joins across multiple relations, subqueries, at least one correlated subquery and at least two meaningful views. Answer the specified advanced questions and explain and justify each query's purpose.

#### Advanced questions and justification

| Question or insight | Report and method | Purpose and justification |
|---|---|---|
| Students with outstanding fees above the average outstanding amount | Q11 compares each current resident's balance with a scalar `AVG(outstanding_fee)` subquery over current residents, including zero balances. | Identifies balances above the resident-wide benchmark so accounts can be reviewed for payment support or follow-up. Including zero balances makes the comparison population explicit. |
| Hostels with occupancy above their capacity benchmark | Q12 joins occupancy to `REPORT_CONFIG` and filters above the configured 90 percent benchmark. | Flags hostels with little spare accommodation for planning. The 90 percent project benchmark reserves a planning margin; it does not authorize occupancy above physical capacity. |
| Students with repeated maintenance complaints | Q13 filters student complaint totals to at least two complaints raised in the window. | Identifies recurring facility problems affecting a student and supports coordinated maintenance follow-up. Both total and unresolved counts are shown so repetition and pending work can be distinguished. |
| Students with attendance below their hostel average | Q14 uses a correlated subquery matching the outer student's `hostel_id`; both the student and comparison peers must have no missing days. | Compares attendance within the same hostel and avoids using incomplete attendance as a reliable benchmark. This is the required correlated subquery. |
| Hostels with higher-than-average maintenance expenditure | Q15 compares hostel maintenance cost with a scalar average over `V_HOSTEL_PERFORMANCE`, including zero-cost hostels. | Identifies hostels needing cost review, preventive maintenance or budget attention. The calculation sums expense rows, allowing multiple costs per complaint. |
| Students with repeated disciplinary incidents | Q16 selects students with at least two incidents in the window. | Produces a list for human review and counselling. It counts recorded incidents without treating the count as an automatic finding or penalty. |
| Hostel-level performance | Q17 selects the integrated hostel performance view. | Presents occupancy, resident count, average attendance, outstanding fees, high-priority count and maintenance cost together so administrators can assess several operational measures. |
| Beds available for allocation | Q18 uses a correlated `NOT EXISTS` subquery against current residence and restricts beds to `AVAILABLE` service status. | Identifies individual usable vacancies rather than inferring vacancy from bed service status alone. |
| Visitor history | Q19 joins visits, allocations, students, beds, rooms and hostels and filters entry timestamps to the window. | Displays visit details and actual entry/exit times with the hostel associated with the stay. |
| Allocation and transfer history | Q20 joins allocations to students and accommodation and orders by student and start date. | Makes previous stays and transfers visible without replacing historical allocation records. |
| Administrative attention queue | Q21 filters out `NORMAL` residents and orders high-priority cases first, then by score. | Gives administrators a focused review list including missing attendance and unresolved maintenance needs. |

The correlated comparison in Q14 is:

```sql
SELECT s.student_id,s.student_name,s.hostel_name,s.attendance_pct
FROM v_student_support_stats s
WHERE s.hostel_id IS NOT NULL AND s.missing_days=0
AND s.attendance_pct < (
    SELECT AVG(peer.attendance_pct)
    FROM v_student_support_stats peer
    WHERE peer.hostel_id=s.hostel_id AND peer.missing_days=0
)
ORDER BY s.hostel_id,s.attendance_pct;
```

The reference to `s.hostel_id` inside the subquery connects its comparison group to each outer row. The average includes the student being compared and uses the attendance percentages exposed by the view.

#### Meaningful views

| View | Derived information and reason for use |
|---|---|
| `V_CURRENT_RESIDENCE` | Resolves allocations active at the cutoff into student, bed, room and hostel identifiers; keeps residence logic consistent across reports. |
| `V_FEE_BALANCE` | Aggregates payments per charge before the cutoff and derives outstanding and overdue amounts; supports installment payments without duplicating charge amounts. |
| `V_HOSTEL_OCCUPANCY` | Combines separately aggregated bed capacity and current allocations; provides consistent hostel occupancy and vacancy calculations. |
| `V_STUDENT_SUPPORT_STATS` | Aggregates attendance, fees, complaints and incidents per student and combines them with current residence; supplies the evidence used by the risk model. |
| `V_STUDENT_SUPPORT_RISK` | Converts the student indicators into component points, a total score, a data-quality flag and one of the three priority statuses. |
| `V_HOSTEL_PERFORMANCE` | Summarizes student-support measures by hostel and joins them to occupancy and maintenance expenditure for administrative comparison. |

Inner joins connect records that require matching parents. Left joins preserve students, rooms or hostels when a related aggregate is absent. `CROSS JOIN report_config` supplies the single reporting window consistently. The implementation therefore exceeds the requirement for two meaningful views and uses joins and subqueries for distinct reporting needs.

### 5. Student Hostel Support Risk Identification

**Problem statement:** Integrate attendance, outstanding hostel fees, maintenance complaints and disciplinary history, compare them with administrative benchmarks, and generate a report classifying students as `HIGH PRIORITY`, `NEEDS ATTENTION` or `NORMAL`. Define and justify the criteria.

#### Integration and calculation

`V_STUDENT_SUPPORT_STATS` combines five sources: student/current-allocation data for identity and hostel, attendance for participation, fee charges and payments for balances, complaints for maintenance needs, and disciplinary incidents for administrative history. Attendance and incident records are linked through allocations. Complaint totals use the student reference, while the affected room remains available for maintenance reporting.

Each source is aggregated before it is joined to the student row. Joining raw attendance, payment and complaint rows directly would multiply records: several payments and complaints could repeat the same attendance rows, inflating counts and balances. Separate aggregates preserve one statistics row per student. `V_STUDENT_SUPPORT_RISK` then classifies only students with a current residence.

The score adds the four component values in [Explainable support-priority model](#explainable-support-priority-model). Each component contributes between zero and two points, giving a total from zero to eight. The report displays total complaints as requested in the PDF; the complaint score specifically uses complaints raised in the window that remain unresolved at the cutoff.

#### Criteria and justification

The attendance bands of 85 percent and 75 percent distinguish regular attendance, a moderate concern and a larger attendance concern. A positive outstanding balance contributes one point; an amount above INR 10,000 contributes two. In the sample data, the higher fee threshold exceeds half the INR 18,000 charge and identifies a substantial unpaid amount.

Two or three unresolved complaints contribute one point, while four or more contribute two, directing maintenance support toward recurring pending problems. One incident contributes one point; repeated incidents contribute two to prompt administrative review. Equal maximum contributions keep the four domains comparable and make the decision explainable. These thresholds are illustrative design choices, not university policy or a statistically validated prediction model.

A total of at least five produces `HIGH PRIORITY`, requiring concerns across several domains because one domain can contribute at most two. Scores from two to four produce `NEEDS ATTENTION`, covering an isolated larger concern or several smaller ones. Scores zero or one produce `NORMAL` only when attendance data is complete. Missing attendance or an undefined attendance percentage produces at least `NEEDS ATTENTION`; an existing score of five or more remains `HIGH PRIORITY`.

Complaints represent requests for facility support. The resulting priority should guide maintenance, payment assistance, counselling or data correction according to the underlying indicators. It is not a disciplinary penalty, and staff must review the evidence before deciding what action is appropriate.

#### Expected decision-support report

Q10 returns the integrated report; Q21 returns only residents needing attention. The following selected rows are derived from the baseline sample data. Fees are in INR, complaints are total complaints raised in the window, and percentages use recorded present/absent days.

| Student | Hostel | Attendance percent | Outstanding fee | Complaints | Disciplinary incidents | Risk status |
|---|---|---:|---:|---:|---:|---|
| Student 01 | H01 | 60.00 | 18,000 | 4 | 2 | HIGH PRIORITY |
| Student 02 | H01 | 76.67 | 10,000 | 3 | 1 | NEEDS ATTENTION |
| Student 03 | H01 | 93.33 | 0 | 1 | 0 | NORMAL |
| Student 07 | H02 | 70.00 | 14,000 | 3 | 2 | HIGH PRIORITY |
| Student 18 | H03 | 100.00 | 0 | 0 | 0 | NEEDS ATTENTION |

Student 01 scores `2 + 2 + 2 + 2 = 8`. Student 02 scores `1 + 1 + 1 + 1 = 4`. Student 03's one complaint is resolved and the other indicators contribute no points. Student 18 scores zero but has two missing attendance days, so the data-quality rule requires attention despite 100 percent attendance among the recorded days. Student 19 has no current allocation and is excluded from resident classification. The PDF's Student A and Student B rows illustrate a report format; this implementation uses its own sample records and defined thresholds.

#### Interpretation and evaluation

The expected baseline identifies two high-priority residents, three residents needing attention and 13 normal-priority residents. H01 is fully occupied and exceeds the planning benchmark; H02 and H03 retain usable vacancies. Total outstanding fees of INR 47,000 identify a collection/support need. INR 138,500 collected within the reporting window differs from INR 277,000 paid cumulatively before the cutoff because earlier installments fall outside the window. Maintenance spending is INR 3,800 for H01, INR 900 for H02 and INR 300 for H03, making H01 the only hostel above the three-hostel average.

The database supports consistent allocation, installment tracking, maintenance follow-up and explainable student-support reporting while reducing repeated master data and duplicated aggregates. The verification script checks baseline totals, priority categories, missing attendance and rejection of invalid operations. Actual execution outputs and Oracle compilation diagnostics are needed to establish runtime success; multi-session concurrency and large-data performance remain outside the supplied tests. The implementation boundaries documented earlier also apply to these conclusions.

## Assignment demonstration and execution evidence

1. Use the five answers above to explain requirements, the ER diagram, relational schema, business rules and design choices.
2. Run one installer to demonstrate table creation, `ALTER TABLE`, constraints, sample insertion, views, assertions and reports.
3. Show the reversible UPDATE/DELETE demonstration and rejected invalid operations in `hostel_oracle/05_verify.sql`.
4. Present Q01-Q10, Q11-Q17, the correlated query Q14 and the additional administrative reports Q18-Q21, using the explanations above.
5. Show a high-priority resident, a normal resident and missing-data student 18, explaining their component scores and attendance completeness.
6. Capture actual query outputs, compilation diagnostics and assertion results for the project report. The Word report template still needs to be populated with the hostel case study, relevant screenshots, student details, results and discussion; editing this README does not complete that separate document.
