# Logical Database Design - Group 03

## 1. Introduction

This document presents the logical database design for the Campus Space Management System project. The design transforms the conceptual schema from `outputs/02-erd-design-G03.md` into a SQL Server-oriented relational schema and uses `outputs/01-business-req-analysis-G03.md` only for traceability checks, assumptions, and open questions.

## 1.1 Source documents and path discrepancies

| Source | Required / expected path | Used? | Notes |
|---|---|---:|---|
| Project routing contract | `AGENTS.md` | Yes | Confirms Step 2 output path as `outputs/02-erd-design-G03.md` and Step 3 output path as `outputs/03-logical-design-G03.md`. |
| Conceptual database design | `outputs/02-erd-design-G03.md` | Yes | Primary input. No path discrepancy found. |
| Business requirement analysis | `outputs/01-business-req-analysis-G03.md` | Yes | Used for traceability checks and carried-forward assumptions/open questions only. |
| Logical design output | `outputs/03-logical-design-G03.md` | Yes | This document. |

No source path discrepancy was found.

## 2. Relational Schema

### 2.0 Design conventions, key policy, and referential-action criteria

**Primary-key standardization.** Every table uses a system-generated surrogate `INT IDENTITY(1,1)` primary key with a named `PK_...` constraint. Natural/business identifiers from the conceptual model, such as `USER.user_id` and `SPACE.unique_space_code`, are demoted to regular attributes and protected by named `UNIQUE` constraints. Surrogate `INT` keys are used for all primary/foreign-key relationships for storage efficiency, join performance, and stability. If a natural key value must be corrected, it is a single-row update on a `UNIQUE` attribute because no foreign key references that natural key.

**Conceptual proposed identifiers.** Conceptual identifiers that were already proposed because the source did not name a business identifier (`booking_id`, `facility_id`, `approval_decision_id`, `usage_session_id`, `maintenance_record_id`) are implemented as the mandatory logical surrogate `INT IDENTITY` primary keys, not duplicated as unsupported separate business-key columns.

**Foreign-key referential actions.** Every FK references the parent surrogate `INT` PK and declares explicit actions:
- `ON DELETE CASCADE` is used only for pure current-state association rows with no independent historical/audit value, specifically `SPACE_FACILITY`.
- `ON DELETE NO ACTION` is used for references to master or historical/audit records where deletion would erase or orphan booking, decision, usage, or maintenance history, consistent with BR-20 historical-record preservation. Optional actor FKs also use `NO ACTION` rather than `SET NULL` because preserving who acted is more important than allowing actor deletion.
- `ON UPDATE NO ACTION` is used uniformly for every FK because all referenced PKs are immutable surrogate `INT` values. Natural-key corrections do not require cascades because natural keys are not FK targets.

**Allowed-value CHECK classification.** Closed control vocabularies with available upstream values get named CHECK constraints: `USER_ACCOUNT.role`, `SPACE.current_status`, `BOOKING_REQUEST.purpose_of_use`, `BOOKING_REQUEST.status`, and `APPROVAL_DECISION.decision_outcome`. Open descriptive catalogs do not get fixed-list CHECKs: `SPACE.space_type` and `FACILITY.facility_name` are expected to grow. `USER_ACCOUNT.account_status` and `MAINTENANCE_RECORD.status` have no upstream value list, so they remain unconstrained and are carried as Open Questions.

### 2.1 `USER_ACCOUNT`

Logical table for conceptual `USER`; table name avoids the reserved/generic word `USER`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `user_account_id` | `INT IDENTITY(1,1)` | `NOT NULL` | Surrogate PK | Logical-stage surrogate key policy |
| `user_id` | `NVARCHAR(50)` | `NOT NULL` | Demoted natural/business identifier; unique | Conceptual `USER.user_id`, BR-1 |
| `full_name` | `NVARCHAR(200)` | `NOT NULL` | Stored user information | Conceptual `full_name`, BR-1 |
| `email` | `NVARCHAR(254)` | `NOT NULL` | Candidate key; unique assumption | Conceptual `email`, BR-1 |
| `phone_number` | `NVARCHAR(30)` | `NULL` | Optional contact detail; source stores it but does not state mandatory strength | Conceptual `phone_number`, BR-1 |
| `role` | `NVARCHAR(40)` | `NOT NULL` | Closed role vocabulary | Conceptual `role`, BR-2 |
| `department` | `NVARCHAR(120)` | `NULL` | Optional organizational detail; mandatory strength not stated | Conceptual `department`, BR-1 |
| `account_status` | `NVARCHAR(40)` | `NOT NULL` | Stored status; no upstream values available for CHECK | Conceptual `account_status`, BR-1 |

Primary key:
- `CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY (user_account_id)`

Uniqueness constraints:
- `CONSTRAINT UQ_USER_ACCOUNT_user_id UNIQUE (user_id)`
- `CONSTRAINT UQ_USER_ACCOUNT_email UNIQUE (email)`

CHECK constraints:
- `CONSTRAINT CK_USER_ACCOUNT_role CHECK (role IN ('Student','Lecturer','Teaching Assistant','Facility Staff','Department Administrator','Facility Manager'))`

Unresolved / implementation rules:
- No CHECK on `account_status`: no upstream account-status value list is available.

### 2.2 `SPACE`

Logical table for conceptual `SPACE`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `space_id` | `INT IDENTITY(1,1)` | `NOT NULL` | Surrogate PK | Logical-stage surrogate key policy |
| `unique_space_code` | `NVARCHAR(50)` | `NOT NULL` | Demoted natural/business identifier; unique | Conceptual `unique_space_code`, BR-3 |
| `space_name` | `NVARCHAR(200)` | `NOT NULL` | Stored space detail | Conceptual `space_name`, BR-3 |
| `space_type` | `NVARCHAR(80)` | `NOT NULL` | Open descriptive catalog; no fixed-list CHECK | Conceptual `space_type`, BR-3 |
| `building` | `NVARCHAR(120)` | `NOT NULL` | Stored space detail | Conceptual `building`, BR-3 |
| `floor` | `NVARCHAR(40)` | `NOT NULL` | Stored space detail | Conceptual `floor`, BR-3 |
| `room_number` | `NVARCHAR(40)` | `NOT NULL` | Stored space detail | Conceptual `room_number`, BR-3 |
| `capacity` | `INT` | `NOT NULL` | Positive-capacity CHECK | Conceptual `capacity`, BR-3 |
| `current_status` | `NVARCHAR(40)` | `NOT NULL` | Closed lifecycle vocabulary | Conceptual `current_status`, BR-4 |
| `usage_policy` | `NVARCHAR(1000)` | `NULL` | Stored policy text; enforcement unspecified upstream | Conceptual `usage_policy`, BR-3; Open Question |

Primary key:
- `CONSTRAINT PK_SPACE PRIMARY KEY (space_id)`

Uniqueness constraints:
- `CONSTRAINT UQ_SPACE_unique_space_code UNIQUE (unique_space_code)`

CHECK constraints:
- `CONSTRAINT CK_SPACE_capacity_positive CHECK (capacity > 0)`
- `CONSTRAINT CK_SPACE_current_status CHECK (current_status IN ('Available','In use','Under maintenance','Temporarily closed','Retired'))`

Unresolved / implementation rules:
- No CHECK on `space_type`: although upstream examples include classrooms, laboratories, meeting rooms, and auditoriums, `space_type` is an open descriptive catalog expected to grow.
- `usage_policy` enforcement is unresolved upstream.

### 2.3 `FACILITY`

Logical table for conceptual `FACILITY`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `facility_id` | `INT IDENTITY(1,1)` | `NOT NULL` | Surrogate PK; implements the upstream proposed identifier | Conceptual `facility_id` proposed identifier |
| `facility_name` | `NVARCHAR(120)` | `NOT NULL` | Open descriptive catalog; no fixed-list CHECK and no unique constraint | Conceptual `facility_name`, BR-5 |

Primary key:
- `CONSTRAINT PK_FACILITY PRIMARY KEY (facility_id)`

Unresolved / implementation rules:
- No CHECK on `facility_name`: source examples are an open equipment catalog expected to grow.
- No `facility_description` column is added because no upstream analysis attribute defines it.

### 2.4 `SPACE_FACILITY`

Junction table resolving conceptual M:N `HAS_FACILITY` between `SPACE` and `FACILITY`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `space_facility_id` | `INT IDENTITY(1,1)` | `NOT NULL` | Surrogate PK required by project-wide logical rule | Logical-stage surrogate key policy |
| `space_id` | `INT` | `NOT NULL` | FK to `SPACE(space_id)` | Conceptual `HAS_FACILITY` |
| `facility_id` | `INT` | `NOT NULL` | FK to `FACILITY(facility_id)` | Conceptual `HAS_FACILITY` |

Primary key:
- `CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (space_facility_id)`

Foreign keys:
- `CONSTRAINT FK_SPACE_FACILITY_space_id FOREIGN KEY (space_id) REFERENCES SPACE(space_id) ON DELETE CASCADE ON UPDATE NO ACTION` — pure current-state association row; delete cascades only for this junction; update is no action because PKs are immutable surrogates.
- `CONSTRAINT FK_SPACE_FACILITY_facility_id FOREIGN KEY (facility_id) REFERENCES FACILITY(facility_id) ON DELETE CASCADE ON UPDATE NO ACTION` — pure current-state association row; delete cascades only for this junction; update is no action because PKs are immutable surrogates.

Uniqueness constraints:
- `CONSTRAINT UQ_SPACE_FACILITY_space_id_facility_id UNIQUE (space_id, facility_id)` — prevents duplicate association rows while preserving surrogate PK standardization.

### 2.5 `BOOKING_REQUEST`

Logical table for conceptual `BOOKING_REQUEST`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `booking_id` | `INT IDENTITY(1,1)` | `NOT NULL` | Surrogate PK; implements upstream proposed booking identifier | Conceptual `booking_id` proposed identifier |
| `requester_user_account_id` | `INT` | `NOT NULL` | FK to `USER_ACCOUNT(user_account_id)` | Conceptual `SUBMITS`, BR-6 |
| `space_id` | `INT` | `NOT NULL` | FK to `SPACE(space_id)` | Conceptual `SELECTS_SPACE`, BR-6 |
| `requested_start_time` | `DATETIME2(0)` | `NOT NULL` | Start of requested period | Conceptual `requested_start_time`, BR-6 |
| `requested_end_time` | `DATETIME2(0)` | `NOT NULL` | End of requested period; ordered by CHECK | Conceptual `requested_end_time`, BR-6 |
| `purpose_of_use` | `NVARCHAR(40)` | `NOT NULL` | Closed process-category vocabulary | Conceptual `purpose_of_use`, BR-7 |
| `expected_number_of_participants` | `INT` | `NOT NULL` | Positive count | Conceptual `expected_number_of_participants`, BR-6 |
| `status` | `NVARCHAR(40)` | `NOT NULL` | Closed booking lifecycle vocabulary | Conceptual `status`, BR-8 |

Primary key:
- `CONSTRAINT PK_BOOKING_REQUEST PRIMARY KEY (booking_id)`

Foreign keys:
- `CONSTRAINT FK_BOOKING_REQUEST_requester_user_account_id FOREIGN KEY (requester_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — preserves booking history rather than deleting when master user data is deleted; update is no action because PKs are immutable surrogates.
- `CONSTRAINT FK_BOOKING_REQUEST_space_id FOREIGN KEY (space_id) REFERENCES SPACE(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — preserves booking history and prevents orphaned bookings if master space data is deleted; update is no action because PKs are immutable surrogates.

CHECK constraints:
- `CONSTRAINT CK_BOOKING_REQUEST_requested_time_order CHECK (requested_end_time > requested_start_time)`
- `CONSTRAINT CK_BOOKING_REQUEST_expected_participants_positive CHECK (expected_number_of_participants > 0)`
- `CONSTRAINT CK_BOOKING_REQUEST_purpose_of_use CHECK (purpose_of_use IN ('Lecture','Examination','Seminar','Workshop','Meeting','Student activity','Administrative event'))`
- `CONSTRAINT CK_BOOKING_REQUEST_status CHECK (status IN ('Pending','Approved','Rejected','Cancelled','Checked in','Completed','No-show'))`

Unresolved / implementation rules:
- BR-9 no overlapping approved bookings for the same space/time requires SQL Server implementation logic such as a trigger or transaction-controlled stored procedure because SQL Server ordinary CHECK constraints cannot compare against other rows.
- BR-10/BR-19 no booking for under-maintenance, temporarily closed/closed, or retired spaces requires cross-table implementation logic because it depends on `SPACE.current_status` and/or maintenance activity.
- Participant count versus `SPACE.capacity` is not enforced because upstream did not require the comparison; carried as an Open Question.

### 2.6 `APPROVAL_DECISION`

Logical table for conceptual `APPROVAL_DECISION`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `approval_decision_id` | `INT IDENTITY(1,1)` | `NOT NULL` | Surrogate PK; implements upstream proposed identifier | Conceptual `approval_decision_id` |
| `booking_id` | `INT` | `NOT NULL` | Non-unique FK to `BOOKING_REQUEST(booking_id)`; preserves 0..* decision history | Conceptual `HAS_APPROVAL_DECISION`, BR-11 to BR-13 |
| `decision_maker_user_account_id` | `INT` | `NOT NULL` | FK to `USER_ACCOUNT(user_account_id)` | Conceptual `MADE_BY`, BR-12 |
| `decision_outcome` | `NVARCHAR(20)` | `NOT NULL` | Closed decision outcome vocabulary | Conceptual `decision_outcome`, BR-12/BR-13 |
| `decision_time` | `DATETIME2(0)` | `NOT NULL` | Decision event time | Conceptual `decision_time`, BR-12 |
| `decision_note` | `NVARCHAR(1000)` | `NULL` | Optional note; source records it but does not state mandatory content | Conceptual `decision_note`, BR-12 |
| `rejection_reason` | `NVARCHAR(1000)` | `NULL` | Required by CHECK only when rejected | Conceptual `rejection_reason`, BR-13 |

Primary key:
- `CONSTRAINT PK_APPROVAL_DECISION PRIMARY KEY (approval_decision_id)`

Foreign keys:
- `CONSTRAINT FK_APPROVAL_DECISION_booking_id FOREIGN KEY (booking_id) REFERENCES BOOKING_REQUEST(booking_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — approval decisions are historical/audit records; no delete cascade; update is no action because PKs are immutable surrogates.
- `CONSTRAINT FK_APPROVAL_DECISION_decision_maker_user_account_id FOREIGN KEY (decision_maker_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — preserves who made the decision; update is no action because PKs are immutable surrogates.

CHECK constraints:
- `CONSTRAINT CK_APPROVAL_DECISION_decision_outcome CHECK (decision_outcome IN ('Approved','Rejected'))`
- `CONSTRAINT CK_APPROVAL_DECISION_rejection_reason CHECK (decision_outcome <> 'Rejected' OR rejection_reason IS NOT NULL)`

Unresolved / implementation rules:
- Role restriction that the decision maker must be facility staff or facility manager requires SQL Server implementation logic (trigger/procedure) because it checks `USER_ACCOUNT.role` across tables.
- No unique constraint on `booking_id`; conceptual cardinality is Booking Request `1` to Approval Decision `0..*`.

### 2.7 `USAGE_SESSION`

Logical table for conceptual `USAGE_SESSION`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `usage_session_id` | `INT IDENTITY(1,1)` | `NOT NULL` | Surrogate PK; implements upstream proposed identifier | Conceptual `usage_session_id` |
| `booking_id` | `INT` | `NOT NULL` | FK to `BOOKING_REQUEST(booking_id)`; unique because a booking has 0..1 usage session | Conceptual `HAS_USAGE_SESSION`, BR-14 to BR-16 |
| `checked_in_by_user_account_id` | `INT` | `NOT NULL` | FK to `USER_ACCOUNT(user_account_id)` | Conceptual `CHECKED_IN_BY`, BR-15 |
| `completed_by_user_account_id` | `INT` | `NULL` | Optional role FK to `USER_ACCOUNT(user_account_id)` | Conceptual `COMPLETED_BY`, BR-16 |
| `actual_start_time` | `DATETIME2(0)` | `NOT NULL` | Check-in actual start time | Conceptual `actual_start_time`, BR-15 |
| `initial_condition_of_space` | `NVARCHAR(1000)` | `NOT NULL` | Recorded at check-in | Conceptual `initial_condition_of_space`, BR-15 |
| `actual_end_time` | `DATETIME2(0)` | `NULL` | Completion-dependent | Conceptual `actual_end_time`, BR-16 |
| `final_condition_of_space` | `NVARCHAR(1000)` | `NULL` | Completion-dependent | Conceptual `final_condition_of_space`, BR-16 |
| `usage_notes` | `NVARCHAR(1000)` | `NULL` | Optional usage notes | Conceptual `usage_notes`, BR-16 |

Primary key:
- `CONSTRAINT PK_USAGE_SESSION PRIMARY KEY (usage_session_id)`

Foreign keys:
- `CONSTRAINT FK_USAGE_SESSION_booking_id FOREIGN KEY (booking_id) REFERENCES BOOKING_REQUEST(booking_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — preserves usage history tied to historical booking; update is no action because PKs are immutable surrogates.
- `CONSTRAINT FK_USAGE_SESSION_checked_in_by_user_account_id FOREIGN KEY (checked_in_by_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — preserves check-in actor; update is no action because PKs are immutable surrogates.
- `CONSTRAINT FK_USAGE_SESSION_completed_by_user_account_id FOREIGN KEY (completed_by_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — optional actor FK is not SET NULL because preserving who completed the session supports history; update is no action because PKs are immutable surrogates.

Uniqueness constraints:
- `CONSTRAINT UQ_USAGE_SESSION_booking_id UNIQUE (booking_id)`

CHECK constraints:
- `CONSTRAINT CK_USAGE_SESSION_actual_time_order CHECK (actual_end_time IS NULL OR actual_end_time > actual_start_time)`
- `CONSTRAINT CK_USAGE_SESSION_completion_fields CHECK ((actual_end_time IS NULL AND completed_by_user_account_id IS NULL AND final_condition_of_space IS NULL) OR (actual_end_time IS NOT NULL AND completed_by_user_account_id IS NOT NULL AND final_condition_of_space IS NOT NULL))`

Unresolved / implementation rules:
- Role restrictions for check-in and completion requiring facility staff require SQL Server implementation logic because they check `USER_ACCOUNT.role` across tables.

### 2.8 `MAINTENANCE_RECORD`

Logical table for conceptual `MAINTENANCE_RECORD`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `maintenance_record_id` | `INT IDENTITY(1,1)` | `NOT NULL` | Surrogate PK; implements upstream proposed identifier | Conceptual `maintenance_record_id` |
| `space_id` | `INT` | `NOT NULL` | FK to `SPACE(space_id)` | Conceptual `HAS_MAINTENANCE_RECORD`, BR-17/BR-18 |
| `reporter_user_account_id` | `INT` | `NOT NULL` | FK to `USER_ACCOUNT(user_account_id)` | Conceptual `REPORTED_BY`, BR-18 |
| `assigned_staff_user_account_id` | `INT` | `NULL` | Optional role FK to `USER_ACCOUNT(user_account_id)` | Conceptual `ASSIGNED_TO`; assignment timing unresolved |
| `problem_description` | `NVARCHAR(1000)` | `NOT NULL` | Stored problem detail | Conceptual `problem_description`, BR-17/BR-18 |
| `start_time` | `DATETIME2(0)` | `NOT NULL` | Maintenance start time | Conceptual `start_time`, BR-18 |
| `completion_time` | `DATETIME2(0)` | `NULL` | Completion-dependent | Conceptual `completion_time`, BR-18 |
| `status` | `NVARCHAR(40)` | `NOT NULL` | Stored status; no upstream values available for CHECK | Conceptual `status`, BR-18 |
| `result_note` | `NVARCHAR(1000)` | `NULL` | Completion/result-dependent note | Conceptual `result_note`, BR-18 |

Primary key:
- `CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (maintenance_record_id)`

Foreign keys:
- `CONSTRAINT FK_MAINTENANCE_RECORD_space_id FOREIGN KEY (space_id) REFERENCES SPACE(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — preserves maintenance history for a space; update is no action because PKs are immutable surrogates.
- `CONSTRAINT FK_MAINTENANCE_RECORD_reporter_user_account_id FOREIGN KEY (reporter_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — preserves reporter history; update is no action because PKs are immutable surrogates.
- `CONSTRAINT FK_MAINTENANCE_RECORD_assigned_staff_user_account_id FOREIGN KEY (assigned_staff_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — optional actor FK is not SET NULL because preserving assignment history is valuable; update is no action because PKs are immutable surrogates.

CHECK constraints:
- `CONSTRAINT CK_MAINTENANCE_RECORD_time_order CHECK (completion_time IS NULL OR completion_time > start_time)`

Unresolved / implementation rules:
- No CHECK on `status`: no upstream maintenance-status value list is available.
- Role eligibility for reporter and assigned staff is unresolved/implementation logic.
- Active-maintenance effect on `SPACE.current_status` and availability is unresolved/cross-table implementation logic.

## 3. Relationship Mapping

| Conceptual Relationship | Cardinality / Participation | Logical Mapping |
|---|---|---|
| `SUBMITS` | User `1..1` to Booking Request `0..*`; each booking has one requester | `BOOKING_REQUEST.requester_user_account_id INT NOT NULL` FK to `USER_ACCOUNT(user_account_id)`; no UNIQUE. |
| `SELECTS_SPACE` | Booking Request `0..*` to Space `1..1`; each booking selects one space | `BOOKING_REQUEST.space_id INT NOT NULL` FK to `SPACE(space_id)`; no UNIQUE. |
| `HAS_FACILITY` | Space `0..*` to Facility `0..*` | Junction `SPACE_FACILITY` with `space_id` and `facility_id` FKs plus `UQ_SPACE_FACILITY_space_id_facility_id`. |
| `HAS_APPROVAL_DECISION` | Booking Request `1..1` to Approval Decision `0..*` | `APPROVAL_DECISION.booking_id INT NOT NULL` FK to `BOOKING_REQUEST(booking_id)`; no UNIQUE to preserve decision history. |
| `MADE_BY` | User `1..1` to Approval Decision `0..*` | `APPROVAL_DECISION.decision_maker_user_account_id INT NOT NULL` FK to `USER_ACCOUNT(user_account_id)`. |
| `HAS_USAGE_SESSION` | Booking Request `1..1` to Usage Session `0..1` | `USAGE_SESSION.booking_id INT NOT NULL` FK to `BOOKING_REQUEST(booking_id)` with `UQ_USAGE_SESSION_booking_id`. |
| `CHECKED_IN_BY` | User `1..1` to Usage Session `0..*`; each session has one check-in actor | `USAGE_SESSION.checked_in_by_user_account_id INT NOT NULL` FK to `USER_ACCOUNT(user_account_id)`. |
| `COMPLETED_BY` | User `0..1` to Usage Session `0..*`; completion actor optional per session | `USAGE_SESSION.completed_by_user_account_id INT NULL` FK to `USER_ACCOUNT(user_account_id)`. |
| `HAS_MAINTENANCE_RECORD` | Space `1..1` to Maintenance Record `0..*` | `MAINTENANCE_RECORD.space_id INT NOT NULL` FK to `SPACE(space_id)`. |
| `REPORTED_BY` | User `1..1` to Maintenance Record `0..*`; each record has one reporter | `MAINTENANCE_RECORD.reporter_user_account_id INT NOT NULL` FK to `USER_ACCOUNT(user_account_id)`. |
| `ASSIGNED_TO` | User `0..1` to Maintenance Record `0..*`; assignment optional per record | `MAINTENANCE_RECORD.assigned_staff_user_account_id INT NULL` FK to `USER_ACCOUNT(user_account_id)`. |

## 4. Traceability from Requirements to Tables and Constraints

Upstream business requirement analysis defines BR-1 through BR-21; no BR-22 is present in the Step 1 document.

| Requirement / Rule | Logical Tables / Columns | Logical Treatment |
|---|---|---|
| BR-1: User account and stored user information | `USER_ACCOUNT` columns | Enforced by table structure, `PK_USER_ACCOUNT`, `UQ_USER_ACCOUNT_user_id`, `UQ_USER_ACCOUNT_email`; account status values unresolved. |
| BR-2: User role values | `USER_ACCOUNT.role` | Enforced by `CK_USER_ACCOUNT_role`. |
| BR-3: Stored space details | `SPACE` columns | Enforced by table structure, `PK_SPACE`, `UQ_SPACE_unique_space_code`, `CK_SPACE_capacity_positive`. |
| BR-4: Space current status values | `SPACE.current_status` | Enforced by `CK_SPACE_current_status`. |
| BR-5: Facilities available in each space | `FACILITY`, `SPACE_FACILITY` | Enforced by FKs and `UQ_SPACE_FACILITY_space_id_facility_id`. |
| BR-6: Submit booking by selecting space, times, purpose, participants | `BOOKING_REQUEST` columns and FKs | Enforced by `FK_BOOKING_REQUEST_requester_user_account_id`, `FK_BOOKING_REQUEST_space_id`, `CK_BOOKING_REQUEST_requested_time_order`, `CK_BOOKING_REQUEST_expected_participants_positive`. |
| BR-7: Booking purpose values | `BOOKING_REQUEST.purpose_of_use` | Enforced by `CK_BOOKING_REQUEST_purpose_of_use`. |
| BR-8: Booking status values | `BOOKING_REQUEST.status` | Enforced by `CK_BOOKING_REQUEST_status`; lifecycle transitions for Cancelled/No-show remain open. |
| BR-9: No overlapping approved bookings for same space/time | `BOOKING_REQUEST.space_id`, `requested_start_time`, `requested_end_time`, `status` | Requires SQL Server implementation logic such as trigger/stored procedure/transaction rule; ordinary CHECK cannot compare rows. |
| BR-10: Under-maintenance, closed, retired spaces cannot be booked | `BOOKING_REQUEST.space_id`, `SPACE.current_status` | Requires cross-table implementation logic; `SPACE.current_status` CHECK supplies controlled values. |
| BR-11: Booking may require approval from facility staff/manager | `APPROVAL_DECISION`, `USER_ACCOUNT.role` | FKs capture decision-maker; role restriction requires implementation logic. |
| BR-12: Record decision maker, time, note | `APPROVAL_DECISION` columns and FKs | Enforced by `FK_APPROVAL_DECISION_decision_maker_user_account_id`; decision note nullable due source-strength rule. |
| BR-13: Rejected approval stores rejection reason | `APPROVAL_DECISION.decision_outcome`, `rejection_reason` | Enforced by `CK_APPROVAL_DECISION_rejection_reason`. |
| BR-14: Facility staff can check in booking | `USAGE_SESSION`, `checked_in_by_user_account_id` | FK captures actor; role restriction requires implementation logic. |
| BR-15: Check-in actual start/person/initial condition | `USAGE_SESSION` columns | Enforced by `FK_USAGE_SESSION_checked_in_by_user_account_id`; required fields are NOT NULL. |
| BR-16: Complete booking with actual end/final condition/notes | `USAGE_SESSION` columns | Completion fields are nullable until completion; `CK_USAGE_SESSION_actual_time_order` and `CK_USAGE_SESSION_completion_fields` enforce in-row consistency. |
| BR-17: Space maintenance records for problems | `MAINTENANCE_RECORD`, `SPACE` | Enforced by `FK_MAINTENANCE_RECORD_space_id`. |
| BR-18: Maintenance record details | `MAINTENANCE_RECORD` columns and FKs | FKs capture related space, reporter, assigned staff; `CK_MAINTENANCE_RECORD_time_order` enforces chronological order; status values unresolved. |
| BR-19: Space under maintenance cannot be booked | `SPACE.current_status`, `MAINTENANCE_RECORD.status`, `BOOKING_REQUEST` | Requires cross-table implementation logic; active-maintenance synchronization is unresolved. |
| BR-20: Keep historical records | `BOOKING_REQUEST`, `APPROVAL_DECISION`, `USAGE_SESSION`, `MAINTENANCE_RECORD` | Enforced by separate history tables and `ON DELETE NO ACTION` on historical/master references. |
| BR-21: Staff view history/upcoming/maintenance/no-show | Relevant tables and status columns | Data is available for queries; authorization/view logic deferred. |

Mandatory business-rule classification:
- No overlapping approved bookings for the same space/time: requires SQL Server implementation logic (trigger, stored procedure, or serializable transaction/application-controlled transaction).
- No booking for spaces under maintenance, temporarily closed, or retired: requires cross-table SQL Server implementation logic using `SPACE.current_status` and possibly `MAINTENANCE_RECORD`; ordinary FK/CHECK cannot enforce it.
- Approval decision maker role restriction: requires SQL Server implementation logic checking `USER_ACCOUNT.role IN ('Facility Staff','Facility Manager')`.
- Check-in and completion role restrictions: require SQL Server implementation logic checking `USER_ACCOUNT.role = 'Facility Staff'` for check-in/completion actors.
- Rejected approval must store rejection reason: enforced by named CHECK `CK_APPROVAL_DECISION_rejection_reason`.
- Maintenance status handling and active-maintenance effect on availability: unresolved Open Question; any synchronization requires implementation logic after status vocabulary is clarified.
- Participant count versus space capacity: unresolved Open Question; no upstream requirement says expected participants must be `<= SPACE.capacity`.

## 5. Assumptions Carried Forward

- [upstream] Facility ID, Booking ID, Approval Decision ID, Usage Session ID, and Maintenance Record ID were proposed upstream because the source did not state identifiers. At logical stage these proposed identifiers are implemented as surrogate `INT IDENTITY` primary keys rather than duplicated as unsupported natural-key columns.
- [upstream] Decision outcome is included on `APPROVAL_DECISION` as a derived attribute because the source names approved/rejected outcomes.
- [upstream] `HAS_USAGE_SESSION` remains `1 to 0..1`; `USAGE_SESSION.booking_id` is therefore unique.
- [upstream] “Closed” in the booking restriction is treated as `SPACE.current_status = 'Temporarily closed'` for allowed-value naming.
- [upstream] Generic “staff” viewing permissions are not split into separate roles because the source does not identify which staff-related roles are included.
- [upstream] No separate booking type/category is introduced; `purpose_of_use` is the source-named fact.
- [logical-stage] All tables use surrogate `INT IDENTITY` PKs and all FKs reference surrogate PKs; natural identifiers `user_id` and `unique_space_code` are demoted to named UNIQUE attributes.
- [logical-stage] `USER_ACCOUNT.email` is treated as a candidate key and constrained by `UQ_USER_ACCOUNT_email`; this follows the rubric/candidate-key expectation although upstream only lists email as stored user information.
- [logical-stage] Nullable notes/details (`decision_note`, `usage_notes`, completion-dependent fields, assignment-dependent fields) are nullable where the source does not prove mandatory value at row creation.
- [logical-stage] `SPACE_FACILITY` has a surrogate `space_facility_id` PK to satisfy the project-wide “every table surrogate INT PK” rule, plus a unique pair constraint to preserve association uniqueness.

## 6. Open Questions Carried Forward and Newly Raised

- Question: How is Space usage policy enforced, if at all, when evaluating a booking request? — Affects `SPACE.usage_policy`; no logical enforcement added.
- Question: How should the same-space overlapping approved bookings rule be enforced after conceptual design? — Affects `BOOKING_REQUEST`; proposed implementation options are trigger/procedure/transaction logic.
- Question: How should the rule that under-maintenance, closed, or retired spaces cannot be booked be enforced after conceptual design? — Affects `BOOKING_REQUEST`, `SPACE`, and possibly `MAINTENANCE_RECORD`; requires cross-table implementation logic.
- Question: From which prior status can a Booking Request become Cancelled, who can set it, and under what condition? — Affects booking status lifecycle; no transition CHECK added beyond allowed values.
- Question: From which prior status can a Booking Request become No-show, who can set it, and under what condition? — Affects booking status lifecycle; no transition CHECK added beyond allowed values.
- Question: Which listed user roles are included in the generic “Staff” who can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings? — Affects authorization outside ordinary relational constraints.
- Question: Which roles may report maintenance issues? — Affects `MAINTENANCE_RECORD.reporter_user_account_id`; role restriction unresolved.
- Question: Which roles may assign the assigned staff member on a maintenance record? — Affects assignment workflow and authorization; role restriction unresolved.
- Question: What are the allowed status values and transitions for Maintenance Record status? — Affects `MAINTENANCE_RECORD.status`; no CHECK added.
- Question: Does recording an Approval Decision automatically update Booking Request status, or is the status update handled separately? — Affects consistency between `APPROVAL_DECISION.decision_outcome` and `BOOKING_REQUEST.status`; no automatic rule asserted.
- Question: Does a Maintenance Record status automatically update Space current status to under maintenance, or is Space current status maintained independently? — Affects `MAINTENANCE_RECORD.status` and `SPACE.current_status`; no synchronization rule asserted.
- Question: Are department administrators intended to have responsibilities beyond submitting booking requests as users? — Affects authorization only; no additional table/relationship added.
- Question: What are the allowed values for `USER_ACCOUNT.account_status`? — Newly raised at logical stage because upstream names the attribute but gives no values, so no CHECK can be added.
- Question: Must `BOOKING_REQUEST.expected_number_of_participants` be less than or equal to `SPACE.capacity`? — Newly raised/explicitly carried as a logical integrity question because upstream provides both facts but does not require the comparison.

## 7. Logical Design Self-Check Summary

Full self-check details are logged in `.opencode/logging/self-check-log.md`.

- Entity-to-table coverage: PASS
- Attribute coverage: PASS
- Surrogate `INT` PK standardization (natural keys demoted to named UNIQUE; FKs reference surrogate): PASS
- Relationship mapping (many-side FKs left non-unique): PASS
- Key and constraint naming (no prose-only in-row rule): PASS
- FK referential actions (explicit, consistently reasoned): PASS
- Business rule classification: PASS
- Assumptions/open questions: PASS
