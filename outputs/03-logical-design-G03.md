# Logical Database Design - Group 03

## 1. Source Documents and Path Discrepancies

- Project routing contract read: `AGENTS.md`
- Logical designer definition read: `.opencode/agent/logical-database-designer.md`
- Required conceptual input per contract: `outputs/02-erd-design-G03.md`
- Actual conceptual input used: `outputs/02-erd-design-G03.md`
- Traceability input used: `outputs/01-business-req-analysis-G03.md`
- Target DBMS: Microsoft SQL Server
- Path discrepancies: None identified for the required Step 2 conceptual input.

## 2. Relational Schema

Conventions:
- SQL Server data types are logical recommendations and may be refined during physical implementation.
- `NOT NULL` is used where the conceptual attribute or relationship participation requires the fact to exist at row creation. Nullable columns represent optional or lifecycle-dependent facts from the upstream documents.
- No uniqueness constraint is added for email, facility name, space name, or room location because upstream documents do not state those values are unique, except for `SPACE.unique_space_code` as the identifier.

### 2.1 `USER_ACCOUNT`

Logical table name avoids the reserved/generic SQL term `USER`; this is a logical-stage naming assumption.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `user_id` | `INT` | `NOT NULL` | `PK_USER_ACCOUNT` | Conceptual `USER.user_id`; BR-1, BR-2 |
| `full_name` | `NVARCHAR(200)` | `NOT NULL` |  | BR-2 |
| `email` | `NVARCHAR(254)` | `NOT NULL` | No unique constraint asserted | BR-2 |
| `phone_number` | `NVARCHAR(30)` | `NULL` |  | BR-2 |
| `role` | `NVARCHAR(50)` | `NOT NULL` | `CK_USER_ACCOUNT_role` IN (`Student`, `Lecturer`, `Teaching Assistant`, `Facility Staff`, `Department Administrator`, `Facility Manager`) | Step 1 possible roles |
| `department` | `NVARCHAR(100)` | `NULL` |  | BR-2 |
| `account_status` | `NVARCHAR(50)` | `NOT NULL` | No allowed-value check; values not listed upstream | BR-2 |

Primary key:
- `CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY (user_id)`

### 2.2 `SPACE`

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `unique_space_code` | `NVARCHAR(50)` | `NOT NULL` | `PK_SPACE` | Conceptual `SPACE.unique_space_code`; BR-3 |
| `space_name` | `NVARCHAR(200)` | `NOT NULL` | No unique constraint asserted | BR-3 |
| `space_type` | `NVARCHAR(50)` | `NOT NULL` | No allowed-value check; values not listed upstream | BR-3 |
| `building` | `NVARCHAR(100)` | `NOT NULL` |  | BR-3 |
| `floor` | `NVARCHAR(20)` | `NOT NULL` |  | BR-3 |
| `room_number` | `NVARCHAR(30)` | `NOT NULL` |  | BR-3 |
| `capacity` | `INT` | `NOT NULL` | `CK_SPACE_capacity_positive` CHECK (`capacity` > 0) | BR-3; capacity count |
| `current_status` | `NVARCHAR(50)` | `NOT NULL` | `CK_SPACE_current_status` IN (`Available`, `In use`, `Under maintenance`, `Temporarily closed`, `Retired`) | Step 1 possible current statuses; BR-3, BR-10, BR-20 |
| `usage_policy` | `NVARCHAR(MAX)` | `NULL` | Enforcement unresolved | BR-3 |

Primary key:
- `CONSTRAINT PK_SPACE PRIMARY KEY (unique_space_code)`

### 2.3 `FACILITY`

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `facility_id` | `INT` | `NOT NULL` | `PK_FACILITY`; proposed identifier carried forward | Conceptual `FACILITY.facility_id`; upstream assumption |
| `facility_name` | `NVARCHAR(100)` | `NOT NULL` | No unique constraint asserted | BR-4 |

Primary key:
- `CONSTRAINT PK_FACILITY PRIMARY KEY (facility_id)`

### 2.4 `SPACE_FACILITY`

Associative table resolving conceptual M:N relationship `HAS_FACILITY`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `unique_space_code` | `NVARCHAR(50)` | `NOT NULL` | `FK_SPACE_FACILITY_SPACE` | `SPACE` side of `HAS_FACILITY`; BR-4 |
| `facility_id` | `INT` | `NOT NULL` | `FK_SPACE_FACILITY_FACILITY` | `FACILITY` side of `HAS_FACILITY`; BR-4 |

Primary key and foreign keys:
- `CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (unique_space_code, facility_id)`
- `CONSTRAINT FK_SPACE_FACILITY_SPACE FOREIGN KEY (unique_space_code) REFERENCES SPACE(unique_space_code)`
- `CONSTRAINT FK_SPACE_FACILITY_FACILITY FOREIGN KEY (facility_id) REFERENCES FACILITY(facility_id)`

### 2.5 `BOOKING_REQUEST`

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `booking_id` | `INT` | `NOT NULL` | `PK_BOOKING_REQUEST`; proposed identifier carried forward | Conceptual `BOOKING_REQUEST.booking_id`; upstream assumption |
| `requester_user_id` | `INT` | `NOT NULL` | `FK_BOOKING_REQUEST_REQUESTER` | `SUBMITS`; BR-5 |
| `unique_space_code` | `NVARCHAR(50)` | `NOT NULL` | `FK_BOOKING_REQUEST_SPACE` | `SELECTS_SPACE`; BR-5 |
| `requested_start_time` | `DATETIME2(0)` | `NOT NULL` |  | BR-5 |
| `requested_end_time` | `DATETIME2(0)` | `NOT NULL` | `CK_BOOKING_REQUEST_time_order` CHECK (`requested_end_time` > `requested_start_time`) | BR-5 |
| `purpose_of_use` | `NVARCHAR(500)` | `NOT NULL` |  | BR-5 |
| `expected_number_of_participants` | `INT` | `NOT NULL` | `CK_BOOKING_REQUEST_expected_participants_positive` CHECK (`expected_number_of_participants` > 0) | BR-5 |
| `booking_type` | `NVARCHAR(50)` | `NOT NULL` | `CK_BOOKING_REQUEST_booking_type` IN (`Lecture`, `Examination`, `Seminar`, `Workshop`, `Meeting`, `Student activity`, `Administrative event`) | BR-6 |
| `status` | `NVARCHAR(50)` | `NOT NULL` | `CK_BOOKING_REQUEST_status` IN (`Pending`, `Approved`, `Rejected`, `Cancelled`, `Checked in`, `Completed`, `No-show`) | BR-7 |

Primary key and foreign keys:
- `CONSTRAINT PK_BOOKING_REQUEST PRIMARY KEY (booking_id)`
- `CONSTRAINT FK_BOOKING_REQUEST_REQUESTER FOREIGN KEY (requester_user_id) REFERENCES USER_ACCOUNT(user_id)`
- `CONSTRAINT FK_BOOKING_REQUEST_SPACE FOREIGN KEY (unique_space_code) REFERENCES SPACE(unique_space_code)`

Unresolved / implementation rules:
- No overlapping approved bookings for the same space and time period requires SQL Server implementation logic because ordinary CHECK/UNIQUE constraints cannot compare intervals across rows.
- No booking for spaces under maintenance, temporarily closed, or retired requires SQL Server implementation logic because the rule depends on the referenced `SPACE.current_status` row.
- Participant count versus `SPACE.capacity` is unresolved upstream as a required rule; if required, it would need implementation logic comparing `expected_number_of_participants` to the selected space capacity.

### 2.6 `APPROVAL_DECISION`

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `approval_decision_id` | `INT` | `NOT NULL` | `PK_APPROVAL_DECISION`; proposed identifier carried forward | Conceptual `APPROVAL_DECISION.approval_decision_id`; upstream assumption |
| `booking_id` | `INT` | `NOT NULL` | `FK_APPROVAL_DECISION_BOOKING`; `UQ_APPROVAL_DECISION_booking_id` | `HAS_APPROVAL_DECISION`; BR-11 to BR-13 |
| `decision_maker_user_id` | `INT` | `NOT NULL` | `FK_APPROVAL_DECISION_DECISION_MAKER` | `MAKES_DECISION`; BR-12 |
| `decision_time` | `DATETIME2(0)` | `NOT NULL` |  | BR-12 |
| `decision_note` | `NVARCHAR(MAX)` | `NOT NULL` |  | BR-12 |
| `rejection_reason` | `NVARCHAR(MAX)` | `NULL` | Required conditionally for rejected bookings; implementation rule below | BR-13 |

Primary key, foreign keys, and uniqueness:
- `CONSTRAINT PK_APPROVAL_DECISION PRIMARY KEY (approval_decision_id)`
- `CONSTRAINT FK_APPROVAL_DECISION_BOOKING FOREIGN KEY (booking_id) REFERENCES BOOKING_REQUEST(booking_id)`
- `CONSTRAINT FK_APPROVAL_DECISION_DECISION_MAKER FOREIGN KEY (decision_maker_user_id) REFERENCES USER_ACCOUNT(user_id)`
- `CONSTRAINT UQ_APPROVAL_DECISION_booking_id UNIQUE (booking_id)`

Unresolved / implementation rules:
- Decision maker role restriction to Facility Staff or Facility Manager requires SQL Server implementation logic because a foreign key alone cannot restrict the referenced user's `role`.
- Rejected approval must store a rejection reason requires SQL Server implementation logic because `APPROVAL_DECISION` has no separate decision outcome attribute in the conceptual model; the rejection condition is represented by related `BOOKING_REQUEST.status = 'Rejected'`.
- Whether every approved or rejected booking must have exactly one approval decision remains an open question from upstream.

### 2.7 `USAGE_SESSION`

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `usage_session_id` | `INT` | `NOT NULL` | `PK_USAGE_SESSION`; proposed identifier carried forward | Conceptual `USAGE_SESSION.usage_session_id`; upstream assumption |
| `booking_id` | `INT` | `NOT NULL` | `FK_USAGE_SESSION_BOOKING`; `UQ_USAGE_SESSION_booking_id` | `HAS_USAGE_SESSION`; BR-14 to BR-17 |
| `checked_in_by_user_id` | `INT` | `NOT NULL` | `FK_USAGE_SESSION_CHECKED_IN_BY` | `CHECKED_IN_BY`; BR-15 |
| `completed_by_user_id` | `INT` | `NULL` | `FK_USAGE_SESSION_COMPLETED_BY`; nullable until session completion | `COMPLETED_BY`; BR-16, BR-17 |
| `actual_start_time` | `DATETIME2(0)` | `NOT NULL` |  | BR-15 |
| `initial_condition_of_the_space` | `NVARCHAR(MAX)` | `NOT NULL` |  | BR-15 |
| `actual_end_time` | `DATETIME2(0)` | `NULL` |  | BR-17 |
| `final_condition_of_the_space` | `NVARCHAR(MAX)` | `NULL` |  | BR-17 |
| `usage_notes` | `NVARCHAR(MAX)` | `NULL` |  | BR-17 |

Primary key, foreign keys, and uniqueness:
- `CONSTRAINT PK_USAGE_SESSION PRIMARY KEY (usage_session_id)`
- `CONSTRAINT FK_USAGE_SESSION_BOOKING FOREIGN KEY (booking_id) REFERENCES BOOKING_REQUEST(booking_id)`
- `CONSTRAINT FK_USAGE_SESSION_CHECKED_IN_BY FOREIGN KEY (checked_in_by_user_id) REFERENCES USER_ACCOUNT(user_id)`
- `CONSTRAINT FK_USAGE_SESSION_COMPLETED_BY FOREIGN KEY (completed_by_user_id) REFERENCES USER_ACCOUNT(user_id)`
- `CONSTRAINT UQ_USAGE_SESSION_booking_id UNIQUE (booking_id)`

Unresolved / implementation rules:
- Check-in and completion role restrictions to Facility Staff require SQL Server implementation logic because foreign keys cannot restrict referenced user roles.
- Completion consistency, such as requiring `completed_by_user_id`, `actual_end_time`, and `final_condition_of_the_space` when the booking/session is completed, requires SQL Server implementation logic because it depends on lifecycle state.

### 2.8 `MAINTENANCE_RECORD`

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `maintenance_record_id` | `INT` | `NOT NULL` | `PK_MAINTENANCE_RECORD`; proposed identifier carried forward | Conceptual `MAINTENANCE_RECORD.maintenance_record_id`; upstream assumption |
| `unique_space_code` | `NVARCHAR(50)` | `NOT NULL` | `FK_MAINTENANCE_RECORD_SPACE` | `HAS_MAINTENANCE_RECORD`; BR-18, BR-19 |
| `reported_by_user_id` | `INT` | `NOT NULL` | `FK_MAINTENANCE_RECORD_REPORTED_BY` | `REPORTED_BY`; BR-19 |
| `assigned_to_user_id` | `INT` | `NOT NULL` | `FK_MAINTENANCE_RECORD_ASSIGNED_TO` | `ASSIGNED_TO`; BR-19 |
| `problem_description` | `NVARCHAR(MAX)` | `NOT NULL` |  | BR-19 |
| `start_time` | `DATETIME2(0)` | `NOT NULL` |  | BR-19 |
| `completion_time` | `DATETIME2(0)` | `NULL` | Nullable until maintenance completion | BR-19 |
| `status` | `NVARCHAR(50)` | `NOT NULL` | No allowed-value check; values not listed upstream | BR-19 |
| `result_note` | `NVARCHAR(MAX)` | `NULL` | Nullable until maintenance completion | BR-19 |

Primary key and foreign keys:
- `CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (maintenance_record_id)`
- `CONSTRAINT FK_MAINTENANCE_RECORD_SPACE FOREIGN KEY (unique_space_code) REFERENCES SPACE(unique_space_code)`
- `CONSTRAINT FK_MAINTENANCE_RECORD_REPORTED_BY FOREIGN KEY (reported_by_user_id) REFERENCES USER_ACCOUNT(user_id)`
- `CONSTRAINT FK_MAINTENANCE_RECORD_ASSIGNED_TO FOREIGN KEY (assigned_to_user_id) REFERENCES USER_ACCOUNT(user_id)`

Unresolved / implementation rules:
- Which roles may report maintenance and assign maintenance staff remains unresolved upstream.
- Maintenance status handling cannot be enforced by allowed-value CHECK constraints because upstream does not list allowed maintenance statuses.
- Active-maintenance effect on space availability remains unresolved: upstream states a space under maintenance cannot be booked, but does not state whether an active maintenance record automatically changes `SPACE.current_status`.

## 3. Relationship Mapping

| Conceptual Relationship | Cardinality / Participation | Logical Mapping |
|---|---|---|
| `SUBMITS` (`User` → `Booking Request`) | User 1 to Booking Request 0..*; each booking request must have one user | `BOOKING_REQUEST.requester_user_id` NOT NULL FK to `USER_ACCOUNT.user_id` |
| `SELECTS_SPACE` (`Space` → `Booking Request`) | Space 1 to Booking Request 0..*; each booking request must select one space | `BOOKING_REQUEST.unique_space_code` NOT NULL FK to `SPACE.unique_space_code` |
| `HAS_FACILITY` (`Space` ↔ `Facility`) | M:N optional on both sides | Junction table `SPACE_FACILITY` with composite PK (`unique_space_code`, `facility_id`) |
| `HAS_APPROVAL_DECISION` (`Booking Request` → `Approval Decision`) | Booking Request 1 to Approval Decision 0..1; each decision must belong to one request | `APPROVAL_DECISION.booking_id` NOT NULL FK plus UNIQUE |
| `MAKES_DECISION` (`User` → `Approval Decision`) | User 1 to Approval Decision 0..*; each decision must be made by one user | `APPROVAL_DECISION.decision_maker_user_id` NOT NULL FK to `USER_ACCOUNT.user_id` |
| `HAS_USAGE_SESSION` (`Booking Request` → `Usage Session`) | Booking Request 1 to Usage Session 0..1; each session must belong to one request | `USAGE_SESSION.booking_id` NOT NULL FK plus UNIQUE |
| `CHECKED_IN_BY` (`User` → `Usage Session`) | User 1 to Usage Session 0..*; each session must be checked in by one user | `USAGE_SESSION.checked_in_by_user_id` NOT NULL FK to `USER_ACCOUNT.user_id` |
| `COMPLETED_BY` (`User` → `Usage Session`) | User 1 to Usage Session 0..*; completion user optional until completion | `USAGE_SESSION.completed_by_user_id` nullable FK to `USER_ACCOUNT.user_id` |
| `HAS_MAINTENANCE_RECORD` (`Space` → `Maintenance Record`) | Space 1 to Maintenance Record 0..*; each record must relate to one space | `MAINTENANCE_RECORD.unique_space_code` NOT NULL FK to `SPACE.unique_space_code` |
| `REPORTED_BY` (`User` → `Maintenance Record`) | User 1 to Maintenance Record 0..*; each record must have one reporter | `MAINTENANCE_RECORD.reported_by_user_id` NOT NULL FK to `USER_ACCOUNT.user_id` |
| `ASSIGNED_TO` (`User` → `Maintenance Record`) | User 1 to Maintenance Record 0..*; each record must have one assigned staff user | `MAINTENANCE_RECORD.assigned_to_user_id` NOT NULL FK to `USER_ACCOUNT.user_id` |

## 4. Traceability from Requirements to Tables and Constraints

| Requirement / Rule | Logical Tables / Columns | Logical Treatment |
|---|---|---|
| BR-1: Each user must have a university account. | `USER_ACCOUNT.user_id` | Enforced by primary key. |
| BR-2: Store user ID, full name, email, phone number, role, department, account status. | `USER_ACCOUNT` columns | Enforced by table columns; role allowed values enforced by CHECK. Account-status allowed values unresolved. |
| BR-3: Store unique space code, name, type, building, floor, room, capacity, status, usage policy. | `SPACE` columns | Unique space code enforced by primary key; capacity positivity and current-status values enforced by CHECK. |
| BR-4: Store facilities available in each space. | `FACILITY`, `SPACE_FACILITY` | M:N enforced by junction-table composite primary key and foreign keys. |
| BR-5: Users submit booking requests selecting space, time range, purpose, participants. | `BOOKING_REQUEST` with requester and space FKs | Required relationships enforced by foreign keys; positive participants and valid time order enforced by CHECK. |
| BR-6: Booking type allowed values. | `BOOKING_REQUEST.booking_type` | Enforced by CHECK using upstream listed values. |
| BR-7: Booking status allowed values. | `BOOKING_REQUEST.status` | Enforced by CHECK using upstream listed values; full status-transition rules require implementation logic / remain partially open. |
| BR-8: Prevent conflicting bookings. | `BOOKING_REQUEST.unique_space_code`, requested times, status | Requires SQL Server implementation logic. |
| BR-9: Same space cannot have two approved overlapping bookings. | `BOOKING_REQUEST` | Requires SQL Server trigger, stored procedure, serializable transaction rule, or equivalent application-controlled transaction. |
| BR-10: Under-maintenance, temporarily closed, or retired space cannot be booked. | `SPACE.current_status`, `BOOKING_REQUEST.unique_space_code` | Status values enforced by CHECK; cross-table availability rule requires implementation logic. |
| BR-11: Booking may require approval from facility staff or manager. | `APPROVAL_DECISION`, `decision_maker_user_id` | Optional decision enforced by unique FK; role restriction requires implementation logic; approval-required trigger condition remains open. |
| BR-12: Record decision staff member, decision time, decision note. | `APPROVAL_DECISION` columns and FK | Columns and maker FK enforce existence on decision row; role restriction requires implementation logic. |
| BR-13: Rejected booking should store rejection reason. | `APPROVAL_DECISION.rejection_reason`; related `BOOKING_REQUEST.status` | Requires SQL Server implementation logic due cross-table conditional rule. |
| BR-14: Facility staff check in booking. | `USAGE_SESSION`, `checked_in_by_user_id` | Session row and FK represent check-in; Facility Staff role restriction requires implementation logic. |
| BR-15: Record actual start, checker, initial condition. | `USAGE_SESSION` columns | Required by NOT NULL columns and FK. |
| BR-16: Facility staff complete booking. | `USAGE_SESSION.completed_by_user_id` | Nullable FK supports not-yet-completed sessions; Facility Staff role and completion consistency require implementation logic. |
| BR-17: Record actual end, final condition, usage notes. | `USAGE_SESSION` columns | Nullable lifecycle columns; completion-required values require implementation logic. |
| BR-18: Space may have maintenance records for problems. | `MAINTENANCE_RECORD`, `SPACE` FK | Enforced by foreign key from maintenance record to space. |
| BR-19: Maintenance record stores related space, reporter, assigned staff, problem, timing, status, result. | `MAINTENANCE_RECORD` columns and FKs | Required relationships enforced by FKs; maintenance status values unresolved. |
| BR-20: Space under maintenance cannot be booked. | `SPACE.current_status`; `BOOKING_REQUEST` | Requires implementation logic; active-maintenance synchronization remains open. |
| BR-21: Keep historical records of bookings and maintenance. | `BOOKING_REQUEST`, `APPROVAL_DECISION`, `USAGE_SESSION`, `MAINTENANCE_RECORD` | Supported by persistent event/history tables; retention policy not specified. |
| BR-22: Staff view histories, upcoming bookings, maintenance spaces, no-show bookings. | `BOOKING_REQUEST`, `SPACE`, `MAINTENANCE_RECORD` | Query/view support possible; access-control enforcement deferred to implementation logic. |

Mandatory business-rule classification:
- No overlapping approved bookings for the same space/time: requires SQL Server implementation logic.
- No booking for spaces under maintenance, temporarily closed, or retired: status values partly enforced by CHECK; booking prevention requires SQL Server implementation logic.
- Approval decision maker role restriction: requires SQL Server implementation logic.
- Check-in and completion role restrictions: require SQL Server implementation logic.
- Rejected approval must store rejection reason: requires SQL Server implementation logic because condition depends on related booking status.
- Maintenance status handling and active-maintenance effect on availability: maintenance status values and active-maintenance synchronization are unresolved open questions; current `SPACE.current_status` availability check requires implementation logic.
- Participant count versus space capacity: unresolved open question; if required, would require SQL Server implementation logic.

## 5. Assumptions Carried Forward

- [upstream] `Facility ID` is a proposed identifier for Facility because the source lists facility examples but does not name a facility identifier.
- [upstream] `Booking ID` is a proposed identifier for Booking Request because the source describes booking requests but does not name a booking identifier.
- [upstream] `Approval Decision ID` is a proposed identifier for Approval Decision because the source describes approval/rejection details but does not name a decision identifier.
- [upstream] `Usage Session ID` is a proposed identifier for Usage Session because the source describes check-in and completion records but does not name a usage-session identifier.
- [upstream] `Maintenance Record ID` is a proposed identifier for Maintenance Record because the source describes maintenance records but does not name a maintenance-record identifier.
- [upstream] Approval Decision remains separate from Booking Request because decision time, decision note, and rejection reason are decision-event facts.
- [upstream] Usage Session remains separate from Booking Request because actual usage facts are distinct from requested booking facts.
- [upstream] `Decision note` and `rejection_reason` remain distinct Approval Decision attributes; no duplicate booking-level rejection reason is added.
- [upstream] The generic word “Staff” in staff-view requirements is interpreted as Facility Staff.
- [logical-stage] The conceptual entity `USER` is mapped to table `USER_ACCOUNT` to avoid the reserved/generic SQL term `USER`.
- [logical-stage] Lifecycle completion facts (`completed_by_user_id`, `actual_end_time`, `final_condition_of_the_space`, `usage_notes`, `completion_time`, `result_note`) are nullable because upstream describes them as occurring at completion rather than necessarily at initial row creation.
- [logical-stage] `SPACE.capacity` and `BOOKING_REQUEST.expected_number_of_participants` use positive integer CHECK constraints because the attributes are counts.

## 6. Open Questions Carried Forward and Newly Raised

- Layer A mentions checking whether a requester is allowed to use a room; should the new system enforce requester eligibility? This could affect `BOOKING_REQUEST` validation.
- Layer A mentions checking whether special equipment is needed; should the new system record or validate requested equipment needs? This could require a `BOOKING_REQUEST` to `FACILITY` relationship not present in the conceptual model.
- Layer B stores a space usage policy, but does not say how it is enforced; should booking requests be validated against usage policy?
- What action and role create the `cancelled` booking status, and from which statuses can cancellation occur?
- What action and role create the `no-show` booking status, and from which status can a booking become no-show?
- Can a booking move from pending directly to checked in if approval is not required, or does every checked-in booking first become approved?
- Which user roles are allowed to report maintenance issues?
- Which user roles are allowed to assign maintenance staff members?
- What maintenance status values are allowed, and what transitions are permitted from start time to completion time?
- Does creating an active maintenance record automatically set the related space status to under maintenance, or is the space status managed separately?
- Does every approved or rejected booking require exactly one Approval Decision record, including bookings that do not require approval?
- BR-7 status-transition enforcement remains unresolved beyond the listed values and the few transitions stated upstream.
- BR-8 and BR-9 booking conflict/overlap enforcement requires implementation logic; the exact physical mechanism is deferred.
- BR-10 and BR-20 unavailable-space booking enforcement requires implementation logic; the exact timing of validation for request creation versus approval remains unresolved.
- BR-13 conditional rejection-reason enforcement requires implementation logic because the conceptual model does not include a decision outcome column separate from booking status.
- BR-22 staff view/access enforcement is deferred because the logical schema represents the information but not access-control behavior.
- [logical-stage] Should `expected_number_of_participants` be constrained to be less than or equal to `SPACE.capacity`? Upstream stores both facts but does not state the rule explicitly.
