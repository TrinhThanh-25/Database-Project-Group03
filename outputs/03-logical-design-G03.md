# Logical Database Design - G03

## 1. Source Documents

- Business requirement analysis: `outputs/01-business-req-analysis-G03.md`
- Conceptual database design: `outputs/02-erd-design-G03.md`
- Target DBMS for later implementation: Microsoft SQL Server

This document transforms the conceptual ERD into a relational schema. It does not introduce new business requirements. The many-to-many relationship between `SPACE` and `FACILITY` is resolved with an associative table.

## 2. Relational Schema

### 2.1 USER_ACCOUNT

Stores university account holders who interact with the campus space management system.

| Column | Data Type | Null | Key / Constraint | Source Attribute |
|---|---|---:|---|---|
| `user_id` | `VARCHAR(30)` | No | Primary key | `USER.user_id` |
| `full_name` | `NVARCHAR(100)` | No |  | `USER.full_name` |
| `email` | `VARCHAR(255)` | No |  | `USER.email` |
| `phone_number` | `VARCHAR(30)` | Yes |  | `USER.phone_number` |
| `role` | `VARCHAR(40)` | No | Check allowed values | `USER.role` |
| `department` | `NVARCHAR(100)` | Yes |  | `USER.department` |
| `account_status` | `VARCHAR(30)` | No |  | `USER.account_status` |

Constraints:

- `PK_USER_ACCOUNT`: Primary key on `user_id`.
- `CK_USER_ACCOUNT_role`: `role` should be one of `Student`, `Lecturer`, `Teaching Assistant`, `Facility Staff`, `Department Administrator`, or `Facility Manager`.
- Email uniqueness is not defined because it remains an open question in the business requirement analysis.

### 2.2 SPACE

Stores bookable physical campus spaces.

| Column | Data Type | Null | Key / Constraint | Source Attribute |
|---|---|---:|---|---|
| `space_code` | `VARCHAR(30)` | No | Primary key | `SPACE.space_code` |
| `space_name` | `NVARCHAR(100)` | No |  | `SPACE.space_name` |
| `space_type` | `VARCHAR(40)` | No | Check allowed values | `SPACE.space_type` |
| `building` | `NVARCHAR(100)` | No |  | `SPACE.building` |
| `floor` | `VARCHAR(20)` | Yes |  | `SPACE.floor` |
| `room_number` | `VARCHAR(30)` | Yes |  | `SPACE.room_number` |
| `capacity` | `INT` | No | Check `capacity > 0` | `SPACE.capacity` |
| `current_status` | `VARCHAR(40)` | No | Check allowed values | `SPACE.current_status` |
| `usage_policy` | `NVARCHAR(MAX)` | Yes |  | `SPACE.usage_policy` |

Constraints:

- `PK_SPACE`: Primary key on `space_code`.
- `CK_SPACE_space_type`: `space_type` should be one of `Auditorium`, `Classroom`, `Computer laboratory`, `Project laboratory`, `Meeting room`, or `Student workspace`.
- `CK_SPACE_current_status`: `current_status` should be one of `Available`, `In use`, `Under maintenance`, `Temporarily closed`, or `Retired`.
- `CK_SPACE_capacity`: `capacity > 0`.

### 2.3 FACILITY

Stores equipment or facility types that may be available in spaces.

| Column | Data Type | Null | Key / Constraint | Source Attribute |
|---|---|---:|---|---|
| `facility_id` | `INT` | No | Primary key | Surrogate key for `FACILITY` |
| `facility_name_or_type` | `NVARCHAR(100)` | No |  | `FACILITY.facility_name_or_type` |
| `facility_description` | `NVARCHAR(MAX)` | Yes |  | `FACILITY.facility_description` |

Constraints:

- `PK_FACILITY`: Primary key on `facility_id`.
- No uniqueness constraint is defined for `facility_name_or_type` because uniqueness is not specified in the requirements.

### 2.4 SPACE_FACILITY

Associative table resolving the many-to-many relationship between spaces and facilities.

| Column | Data Type | Null | Key / Constraint | Source Relationship |
|---|---|---:|---|---|
| `space_code` | `VARCHAR(30)` | No | Primary key, foreign key to `SPACE(space_code)` | `SPACE has FACILITY` |
| `facility_id` | `INT` | No | Primary key, foreign key to `FACILITY(facility_id)` | `SPACE has FACILITY` |

Constraints:

- `PK_SPACE_FACILITY`: Composite primary key on (`space_code`, `facility_id`).
- `FK_SPACE_FACILITY_SPACE`: `space_code` references `SPACE(space_code)`.
- `FK_SPACE_FACILITY_FACILITY`: `facility_id` references `FACILITY(facility_id)`.

### 2.5 BOOKING_REQUEST

Stores user requests to reserve and use a selected space for a requested time period.

| Column | Data Type | Null | Key / Constraint | Source Attribute / Relationship |
|---|---|---:|---|---|
| `booking_request_id` | `VARCHAR(30)` | No | Primary key | `BOOKING_REQUEST.booking_request_id` |
| `requester_user_id` | `VARCHAR(30)` | No | Foreign key to `USER_ACCOUNT(user_id)` | `USER submits BOOKING_REQUEST` |
| `space_code` | `VARCHAR(30)` | No | Foreign key to `SPACE(space_code)` | `SPACE is_requested_for BOOKING_REQUEST` |
| `requested_start_time` | `DATETIME2` | No |  | `BOOKING_REQUEST.requested_start_time` |
| `requested_end_time` | `DATETIME2` | No | Check end after start | `BOOKING_REQUEST.requested_end_time` |
| `purpose_of_use` | `NVARCHAR(MAX)` | No |  | `BOOKING_REQUEST.purpose_of_use` |
| `expected_number_of_participants` | `INT` | No | Check `> 0` | `BOOKING_REQUEST.expected_number_of_participants` |
| `booking_type` | `VARCHAR(40)` | No | Check allowed values | `BOOKING_REQUEST.booking_type` |
| `booking_status` | `VARCHAR(30)` | No | Check allowed values | `BOOKING_REQUEST.booking_status` |
| `rejection_reason` | `NVARCHAR(MAX)` | Yes |  | `BOOKING_REQUEST.rejection_reason` |

Constraints:

- `PK_BOOKING_REQUEST`: Primary key on `booking_request_id`.
- `FK_BOOKING_REQUEST_USER`: `requester_user_id` references `USER_ACCOUNT(user_id)`.
- `FK_BOOKING_REQUEST_SPACE`: `space_code` references `SPACE(space_code)`.
- `CK_BOOKING_REQUEST_time`: `requested_end_time > requested_start_time`.
- `CK_BOOKING_REQUEST_participants`: `expected_number_of_participants > 0`.
- `CK_BOOKING_REQUEST_booking_type`: `booking_type` should be one of `Lecture`, `Examination`, `Seminar`, `Workshop`, `Meeting`, `Student activity`, or `Administrative event`.
- `CK_BOOKING_REQUEST_booking_status`: `booking_status` should be one of `Pending`, `Approved`, `Rejected`, `Cancelled`, `Checked in`, `Completed`, or `No-show`.
- The no-overlapping-approved-bookings rule requires implementation logic beyond a basic relational key because SQL Server check constraints cannot compare rows in the same table.
- The rule that unavailable spaces cannot be booked requires implementation logic that checks `SPACE.current_status` when creating or approving a booking.

### 2.6 APPROVAL_DECISION

Stores approval or rejection decisions recorded for booking requests.

| Column | Data Type | Null | Key / Constraint | Source Attribute / Relationship |
|---|---|---:|---|---|
| `approval_decision_id` | `INT` | No | Primary key | Surrogate key for `APPROVAL_DECISION` |
| `booking_request_id` | `VARCHAR(30)` | No | Unique foreign key to `BOOKING_REQUEST(booking_request_id)` | `BOOKING_REQUEST receives APPROVAL_DECISION` |
| `decision_maker_user_id` | `VARCHAR(30)` | No | Foreign key to `USER_ACCOUNT(user_id)` | `USER makes APPROVAL_DECISION` |
| `decision_outcome` | `VARCHAR(20)` | No | Check allowed values | `APPROVAL_DECISION.decision_outcome` |
| `decision_time` | `DATETIME2` | No |  | `APPROVAL_DECISION.decision_time` |
| `decision_note` | `NVARCHAR(MAX)` | Yes |  | `APPROVAL_DECISION.decision_note` |
| `rejection_reason` | `NVARCHAR(MAX)` | Yes |  | `APPROVAL_DECISION.rejection_reason` |

Constraints:

- `PK_APPROVAL_DECISION`: Primary key on `approval_decision_id`.
- `FK_APPROVAL_DECISION_BOOKING`: `booking_request_id` references `BOOKING_REQUEST(booking_request_id)`.
- `UQ_APPROVAL_DECISION_booking_request_id`: Unique constraint on `booking_request_id` to enforce at most one approval decision per booking request.
- `FK_APPROVAL_DECISION_USER`: `decision_maker_user_id` references `USER_ACCOUNT(user_id)`.
- `CK_APPROVAL_DECISION_outcome`: `decision_outcome` should be one of `Approved` or `Rejected`.

### 2.7 USAGE_SESSION

Stores actual check-in and completion information for a booking.

| Column | Data Type | Null | Key / Constraint | Source Attribute / Relationship |
|---|---|---:|---|---|
| `usage_session_id` | `INT` | No | Primary key | Surrogate key for `USAGE_SESSION` |
| `booking_request_id` | `VARCHAR(30)` | No | Unique foreign key to `BOOKING_REQUEST(booking_request_id)` | `BOOKING_REQUEST has USAGE_SESSION` |
| `checked_in_by_user_id` | `VARCHAR(30)` | No | Foreign key to `USER_ACCOUNT(user_id)` | `USER checks_in USAGE_SESSION` |
| `completed_by_user_id` | `VARCHAR(30)` | Yes | Foreign key to `USER_ACCOUNT(user_id)` | `USER completes USAGE_SESSION` |
| `actual_start_time` | `DATETIME2` | No |  | `USAGE_SESSION.actual_start_time` |
| `initial_condition` | `NVARCHAR(MAX)` | No |  | `USAGE_SESSION.initial_condition` |
| `actual_end_time` | `DATETIME2` | Yes | Check end after start when present | `USAGE_SESSION.actual_end_time` |
| `final_condition` | `NVARCHAR(MAX)` | Yes |  | `USAGE_SESSION.final_condition` |
| `usage_notes` | `NVARCHAR(MAX)` | Yes |  | `USAGE_SESSION.usage_notes` |

Constraints:

- `PK_USAGE_SESSION`: Primary key on `usage_session_id`.
- `FK_USAGE_SESSION_BOOKING`: `booking_request_id` references `BOOKING_REQUEST(booking_request_id)`.
- `UQ_USAGE_SESSION_booking_request_id`: Unique constraint on `booking_request_id` to enforce at most one usage session per booking request.
- `FK_USAGE_SESSION_CHECKED_IN_BY`: `checked_in_by_user_id` references `USER_ACCOUNT(user_id)`.
- `FK_USAGE_SESSION_COMPLETED_BY`: `completed_by_user_id` references `USER_ACCOUNT(user_id)`.
- `CK_USAGE_SESSION_time`: `actual_end_time IS NULL OR actual_end_time > actual_start_time`.

### 2.8 MAINTENANCE_RECORD

Stores maintenance activity or problem reports for spaces.

| Column | Data Type | Null | Key / Constraint | Source Attribute / Relationship |
|---|---|---:|---|---|
| `maintenance_record_id` | `VARCHAR(30)` | No | Primary key | `MAINTENANCE_RECORD.maintenance_record_id` |
| `space_code` | `VARCHAR(30)` | No | Foreign key to `SPACE(space_code)` | `SPACE has MAINTENANCE_RECORD` |
| `reported_by_user_id` | `VARCHAR(30)` | No | Foreign key to `USER_ACCOUNT(user_id)` | `USER reports MAINTENANCE_RECORD` |
| `assigned_to_user_id` | `VARCHAR(30)` | Yes | Foreign key to `USER_ACCOUNT(user_id)` | `USER is_assigned_to MAINTENANCE_RECORD` |
| `problem_description` | `NVARCHAR(MAX)` | No |  | `MAINTENANCE_RECORD.problem_description` |
| `start_time` | `DATETIME2` | No |  | `MAINTENANCE_RECORD.start_time` |
| `completion_time` | `DATETIME2` | Yes | Check completion after start when present | `MAINTENANCE_RECORD.completion_time` |
| `maintenance_status` | `VARCHAR(40)` | No |  | `MAINTENANCE_RECORD.maintenance_status` |
| `result_note` | `NVARCHAR(MAX)` | Yes |  | `MAINTENANCE_RECORD.result_note` |

Constraints:

- `PK_MAINTENANCE_RECORD`: Primary key on `maintenance_record_id`.
- `FK_MAINTENANCE_RECORD_SPACE`: `space_code` references `SPACE(space_code)`.
- `FK_MAINTENANCE_RECORD_REPORTED_BY`: `reported_by_user_id` references `USER_ACCOUNT(user_id)`.
- `FK_MAINTENANCE_RECORD_ASSIGNED_TO`: `assigned_to_user_id` references `USER_ACCOUNT(user_id)`.
- `CK_MAINTENANCE_RECORD_time`: `completion_time IS NULL OR completion_time >= start_time`.
- Allowed `maintenance_status` values are not constrained because the source documents do not define the status list.

## 3. Relationship Mapping

| Conceptual Relationship | Logical Implementation | Cardinality Enforcement |
|---|---|---|
| `USER` submits `BOOKING_REQUEST` | `BOOKING_REQUEST.requester_user_id` foreign key | Each booking request has exactly one requester; a user can have many booking requests. |
| `SPACE` is requested for `BOOKING_REQUEST` | `BOOKING_REQUEST.space_code` foreign key | Each booking request is for exactly one space; a space can have many booking requests. |
| `SPACE` has `FACILITY` | `SPACE_FACILITY` junction table | Many-to-many resolved by composite primary key. |
| `BOOKING_REQUEST` receives `APPROVAL_DECISION` | `APPROVAL_DECISION.booking_request_id` unique foreign key | A booking request can have zero or one approval decision. |
| `USER` makes `APPROVAL_DECISION` | `APPROVAL_DECISION.decision_maker_user_id` foreign key | Each approval decision has exactly one decision maker; a user can make many decisions. |
| `BOOKING_REQUEST` has `USAGE_SESSION` | `USAGE_SESSION.booking_request_id` unique foreign key | A booking request can have zero or one usage session. |
| `USER` checks in `USAGE_SESSION` | `USAGE_SESSION.checked_in_by_user_id` foreign key | Each usage session has exactly one check-in staff user. |
| `USER` completes `USAGE_SESSION` | `USAGE_SESSION.completed_by_user_id` nullable foreign key | Completion staff is stored when the session is completed. |
| `SPACE` has `MAINTENANCE_RECORD` | `MAINTENANCE_RECORD.space_code` foreign key | Each maintenance record belongs to one space; a space can have many maintenance records. |
| `USER` reports `MAINTENANCE_RECORD` | `MAINTENANCE_RECORD.reported_by_user_id` foreign key | Each maintenance record has exactly one reporter. |
| `USER` is assigned to `MAINTENANCE_RECORD` | `MAINTENANCE_RECORD.assigned_to_user_id` nullable foreign key | Assignment is optional; a user can be assigned many records. |

## 4. Traceability From Requirements to Tables

| Requirement Area | Tables | Key Constraints / Columns |
|---|---|---|
| User management | `USER_ACCOUNT` | `user_id`, `role`, `account_status` |
| Space management | `SPACE` | `space_code`, `space_type`, `current_status`, `capacity`, `usage_policy` |
| Facility tracking | `FACILITY`, `SPACE_FACILITY` | `facility_id`, composite key (`space_code`, `facility_id`) |
| Booking management | `BOOKING_REQUEST` | `requester_user_id`, `space_code`, requested time columns, `booking_status` |
| Conflict prevention | `BOOKING_REQUEST` | Requires implementation logic for overlapping approved bookings by `space_code` and requested time range. |
| Availability control | `SPACE`, `BOOKING_REQUEST`, `MAINTENANCE_RECORD` | Requires implementation logic using `SPACE.current_status` and active maintenance records. |
| Approval management | `APPROVAL_DECISION`, `BOOKING_REQUEST`, `USER_ACCOUNT` | Unique `booking_request_id`, `decision_maker_user_id`, `decision_time`, `decision_outcome` |
| Session tracking | `USAGE_SESSION`, `BOOKING_REQUEST`, `USER_ACCOUNT` | Unique `booking_request_id`, actual time columns, check-in and completion user references |
| Maintenance management | `MAINTENANCE_RECORD`, `SPACE`, `USER_ACCOUNT` | `space_code`, `reported_by_user_id`, `assigned_to_user_id`, status and time columns |
| Historical reporting | `BOOKING_REQUEST`, `USAGE_SESSION`, `APPROVAL_DECISION`, `MAINTENANCE_RECORD` | Historical rows retained as event records. |

## 5. Assumptions Carried Forward

- Facility staff and facility managers are represented as roles in `USER_ACCOUNT`.
- A usage session exists only after a booking is checked in.
- Maintenance assignment is optional when a maintenance record is first reported.
- Facility details beyond name or type remain unspecified.
- Surrogate keys are added for `FACILITY`, `APPROVAL_DECISION`, and `USAGE_SESSION` because the conceptual design does not define natural identifiers for those entities.
- SQL Server reserved-word risk is avoided by naming the user table `USER_ACCOUNT` instead of `USER`.

## 6. Open Questions

- Should `USER_ACCOUNT.email` be unique?
- What exact values are allowed for `account_status` and `maintenance_status`?
- Which roles are allowed to submit booking requests, approve bookings, check in sessions, complete sessions, report maintenance, or be assigned maintenance?
- Which booking types require approval?
- Should `expected_number_of_participants` be constrained to be less than or equal to `SPACE.capacity`?
- Should rejected bookings require `rejection_reason` in `BOOKING_REQUEST`, `APPROVAL_DECISION`, or both?
- Should active maintenance records automatically update `SPACE.current_status` to `Under maintenance`?
