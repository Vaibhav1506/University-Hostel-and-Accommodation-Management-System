# University Hostel and Accommodation Management System

An Oracle SQL and PL/SQL database project for managing university hostel accommodation, fees, attendance, maintenance complaints, visitors, and disciplinary records.

The implementation includes **14 tables** (12 business tables and 2 technical helpers), **6 views**, **5 integrity triggers**, **21 analytical reports**, and **33 automated SQL assertions**. The sample data is synthetic.

![Hostel accommodation ER diagram](hostel_oracle/er_diagram.png)

## Project files

| File | Purpose |
|---|---|
| [01_schema.sql](hostel_oracle/01_schema.sql) | Tables, constraints, indexes, and PL/SQL triggers |
| [02_sample_data.sql](hostel_oracle/02_sample_data.sql) | Reproducible synthetic hostel data |
| [03_views.sql](hostel_oracle/03_views.sql) | Occupancy, fee balances, attendance, student support, and hostel performance |
| [04_reports.sql](hostel_oracle/04_reports.sql) | All 21 reports, including joins, subqueries, and a correlated subquery |
| [05_verify.sql](hostel_oracle/05_verify.sql) | 33 assertions and reversible INSERT/UPDATE/DELETE demonstrations |
| [run_all.sql](hostel_oracle/run_all.sql) | Modular installer |
| [hostel_complete.sql](hostel_oracle/hostel_complete.sql) | Standalone installer with all SQL included |
| [Database guide](hostel_oracle/README.md) | Design decisions, reporting definitions, business rules, and expected results |
| [ER diagram details](hostel_oracle/ER_DIAGRAM.md) | Diagram, relationships, and full attributes |

The [assignment problem statement](Database%20Systems%20Lab%20QP%200.pdf) contains only Case Study 6, extracted from original pages 12-13. The SQL installers run directly in the Oracle tools listed below. The ER diagram is provided as a PNG, with the full attribute list in the ER diagram documentation. Local environments and credentials are excluded from Git.

## Requirements

- Oracle Database 19c or later, with SQL*Plus, SQLcl, or Oracle SQL Developer.
- A project user with CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE TRIGGER, CREATE PROCEDURE, and a tablespace quota.
- The project object and named-constraint names must be unused. Unrelated existing lab objects are allowed. CURRENT_SCHEMA must match the connected user.

Use a project account with the required privileges. SYS and SYSTEM are deliberately rejected by the installer.

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

Finish unrelated transactions before installation: Oracle DDL commits automatically, and the installer also commits its sample data. A partial failure can leave created project objects behind. Existing project objects are never automatically dropped or replaced by the installer.

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

## Expected baseline

| Item | Expected value |
|---|---:|
| Students / current residents | 19 / 18 |
| Hostels / rooms / physical beds | 3 / 9 / 27 |
| Occupied / vacant serviceable beds | 18 / 8 |
| Charges / cumulative payments / outstanding fees | 324,000 / 277,000 / 47,000 |
| HIGH PRIORITY / NEEDS ATTENTION / NORMAL | 2 / 3 / 13 |

The report window begins **6 September 2026** and ends at the exclusive cutoff of **6 October 2026**. Occupancy is measured at the cutoff. Window-only fee collection is **138,500**, which differs from cumulative payments because earlier installments also exist.

Student support thresholds are illustrative project design choices, not university policy. Their definitions, attendance completeness rules, and interpretation are explained in the database guide.
