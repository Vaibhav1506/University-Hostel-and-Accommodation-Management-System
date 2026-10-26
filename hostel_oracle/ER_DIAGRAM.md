# Hostel accommodation ER diagram

The rendered [PNG](er_diagram.png), [SVG](er_diagram.svg), and [detailed Mermaid source](er_diagram_detailed.mmd) are in this folder.

Each child has exactly one parent; each parent may have zero or more children. Student and bed allocations are many over time, with overlapping allocations prohibited.

```mermaid
erDiagram
    HOSTEL ||--o{ ROOM : contains
    ROOM ||--o{ BED : contains
    STUDENT ||--o{ ALLOCATION : receives
    BED ||--o{ ALLOCATION : has_history
    ALLOCATION ||--o{ FEE_CHARGE : incurs
    FEE_CHARGE ||--o{ PAYMENT : receives
    ALLOCATION ||--o{ ATTENDANCE : records
    STUDENT ||--o{ COMPLAINT : raises
    ROOM ||--o{ COMPLAINT : concerns
    COMPLAINT ||--o{ MAINTENANCE_EXPENSE : incurs
    ALLOCATION ||--o{ VISITOR_VISIT : receives
    ALLOCATION ||--o{ DISCIPLINARY_INCIDENT : records
    HOSTEL {
        NUMBER hostel_id PK
        VARCHAR2 hostel_name UK
        VARCHAR2 location
    }
    ROOM {
        NUMBER room_id PK
        NUMBER hostel_id FK
        VARCHAR2 room_no
        VARCHAR2 room_type
    }
    BED {
        NUMBER bed_id PK
        NUMBER room_id FK
        VARCHAR2 bed_no
        VARCHAR2 service_status
    }
    STUDENT {
        NUMBER student_id PK
        VARCHAR2 registration_no UK
        VARCHAR2 student_name
        VARCHAR2 department
        VARCHAR2 email UK
        VARCHAR2 phone
        VARCHAR2 emergency_contact
    }
    ALLOCATION {
        NUMBER allocation_id PK
        NUMBER student_id FK
        NUMBER bed_id FK
        DATE start_date
        DATE end_date
    }
    FEE_CHARGE {
        NUMBER charge_id PK
        NUMBER allocation_id FK
        VARCHAR2 billing_period
        DATE charge_date
        DATE due_date
        NUMBER amount
    }
    PAYMENT {
        NUMBER payment_id PK
        NUMBER charge_id FK
        DATE payment_date
        NUMBER amount
        VARCHAR2 payment_mode
        VARCHAR2 receipt_no UK
    }
    ATTENDANCE {
        NUMBER attendance_id PK
        NUMBER allocation_id FK
        DATE attendance_date
        VARCHAR2 attendance_status
    }
    COMPLAINT {
        NUMBER complaint_id PK
        NUMBER student_id FK
        NUMBER room_id FK
        VARCHAR2 category
        VARCHAR2 description
        DATE raised_date
        VARCHAR2 status
        DATE resolved_date
    }
    MAINTENANCE_EXPENSE {
        NUMBER expense_id PK
        NUMBER complaint_id FK
        DATE expense_date
        NUMBER amount
        VARCHAR2 description
    }
    VISITOR_VISIT {
        NUMBER visit_id PK
        NUMBER allocation_id FK
        VARCHAR2 visitor_name
        VARCHAR2 relationship
        TIMESTAMP entry_time
        TIMESTAMP exit_time
    }
    DISCIPLINARY_INCIDENT {
        NUMBER incident_id PK
        NUMBER allocation_id FK
        DATE incident_date
        VARCHAR2 incident_type
        VARCHAR2 severity
        VARCHAR2 action_taken
    }
```

PK = primary key; FK = foreign key; UK = unique key. Compound unique keys: Room(hostel_id, room_no), Bed(room_id, bed_no), FeeCharge(allocation_id, billing_period), Attendance(allocation_id, attendance_date). Reporting configuration and transaction lock tables are technical helpers and are omitted.
