# Executed Oracle validation

Validated on the user's local Oracle Database Free installation through SQL*Plus 23.26.0.0.0, in the FREEPDB1 pluggable database.

- A fresh, isolated, randomly named schema was created solely for testing.
- Schema, triggers, sample data, and all six views compiled and loaded successfully.
- All **33 automated assertions passed**.
- All **21 analytical reports executed**.
- Both the modular installer and the final standalone `hostel_complete.sql` were executed in fresh test schemas. The final output has no SQL*Plus column-truncation warnings.
- The INSERT/UPDATE/DELETE demonstration completed and its temporary changes were rolled back.
- The validation schema was removed afterward. The deliverable remains a set of files; no permanent hostel application schema was installed.

Checks include baseline row counts and totals; all three priority classes; approved leave and missing attendance; rejection of overlapping student/bed allocations, unavailable beds, invalid foreign keys, negative payments, overpayments, payments before charges, duplicate/out-of-period attendance, inconsistent allocation changes, occupied-bed closure, and referenced-parent deletion; and acceptance of adjacent, nonoverlapping allocations.

This record describes the historical SQL-only validation. Baseline execution output is retained locally in `hostel_run.log`; generated logs are excluded from the GitHub repository. Redundant historical and administrative logs were removed during earlier cleanup.

Execution on Oracle 19c itself and multi-session concurrency stress tests were not performed. The scripts target Oracle 19c or later. Definitions, deliberate scope limits, and interpretation of the reports are documented in `README.md`.

## Shared-schema installer validation - 26 October 2026

The installer now accepts unrelated existing lab objects and checks the 33 project object names and five named constraints before creating anything. Verification compilation checks are limited to the hostel views and triggers.

Executed on the same local Oracle Free installation using a fresh, isolated temporary test schema:

- A full installation alongside an unrelated table and committed sentinel row passed all **33 SQL assertions** and ran all **21 reports**. The unrelated row was preserved.
- A pre-existing `STUDENT` table stopped installation with **ORA-20992**, preserving its data and the unrelated table.
- A conflicting `UQ_ROOM_HOSTEL` constraint stopped installation with **ORA-20993**, before any hostel table was created.
- A CURRENT_SCHEMA different from the connected user stopped installation with **ORA-20994**.
- Installation as SYS remained blocked with **ORA-20991**.
- Re-running the standalone installer stopped with **ORA-20992** and preserved the already installed sample data.
- The standalone installer was regenerated from the modular source; every planned object and named constraint is covered by the preflight.
- The temporary validation schema was removed afterward. These tests did not install the project into VAIBHAV.
