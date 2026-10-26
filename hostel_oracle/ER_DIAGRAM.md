# Hostel accommodation ER diagram

![Detailed hostel accommodation ER diagram](er_diagram.png)

The detailed PNG shows all 64 attributes of the 12 business entities, their exact Oracle data types, primary/foreign/unique keys, required fields, and relationship cardinalities. An asterisk marks a required (NOT NULL) attribute. Composite unique constraints appear inside the relevant entity boxes. The attribute list is also retained below as text.

Each child has exactly one parent; each parent may have zero or more children. Student and bed allocations are many over time, with overlapping allocations prohibited.

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
