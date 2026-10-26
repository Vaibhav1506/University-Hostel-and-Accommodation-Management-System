# Hostel accommodation ER diagram

![Hostel accommodation ER diagram in Chen notation](er_diagram.png)

The PNG uses Chen notation for the 12 business entities: rectangles for entities, ovals for attributes, diamonds for relationships, and underlined primary-key attributes. It shows 52 attribute ovals; the 12 foreign-key fields are represented by relationships. The complete list of 64 schema attributes, including foreign keys, is retained below. Oracle data types and integrity constraints are defined in `01_schema.sql`.

Relationships use 1:N cardinalities. A single connecting line marks partial participation, and a double line marks total participation: each child has exactly one parent per relationship, while each parent may have zero or more children. Student and bed allocations are many over time, with overlapping allocations prohibited by SQL integrity rules.

## Attributes

| Entity | Attributes |
|---|---|
| HOSTEL | `hostel_id` (PK), `hostel_name` (UK), `location` |
| ROOM | `room_id` (PK), `hostel_id` (FK), `room_no`, `room_type` |
| BED | `bed_id` (PK), `room_id` (FK), `bed_no`, `service_status` |
| STUDENT | `student_id` (PK), `registration_no` (UK), `student_name`, `department`, `email` (UK), `phone`, `emergency_contact` |
| ALLOCATION | `allocation_id` (PK), `student_id` (FK), `bed_id` (FK), `start_date`, `end_date` |
| FEE_CHARGE | `charge_id` (PK), `allocation_id` (FK), `billing_period`, `charge_date`, `due_date`, `amount` |
| PAYMENT | `payment_id` (PK), `charge_id` (FK), `payment_date`, `amount`, `payment_mode`, `receipt_no` (UK) |
| ATTENDANCE | `attendance_id` (PK), `allocation_id` (FK), `attendance_date`, `attendance_status` |
| COMPLAINT | `complaint_id` (PK), `student_id` (FK), `room_id` (FK), `category`, `description`, `raised_date`, `status`, `resolved_date` |
| MAINTENANCE_EXPENSE | `expense_id` (PK), `complaint_id` (FK), `expense_date`, `amount`, `description` |
| VISITOR_VISIT | `visit_id` (PK), `allocation_id` (FK), `visitor_name`, `relationship`, `entry_time`, `exit_time` |
| DISCIPLINARY_INCIDENT | `incident_id` (PK), `allocation_id` (FK), `incident_date`, `incident_type`, `severity`, `action_taken` |

PK = primary key; FK = foreign key; UK = unique key. Compound unique keys: Room(hostel_id, room_no), Bed(room_id, bed_no), FeeCharge(allocation_id, billing_period), Attendance(allocation_id, attendance_date). Reporting configuration and transaction lock tables are technical helpers and are omitted.
