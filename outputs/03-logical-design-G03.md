# Logical Database Design - Group 03

## 1. Source Documents and Path Discrepancies

- Project routing contract read: `AGENTS.md`
- Logical designer definition read: `.opencode/agent/logical-database-designer.md`
- Required conceptual input per contract: `outputs/02-erd-design-G03.md`
- Actual conceptual input used: `outputs/02-erd-design-G03.md`
- Traceability input used: `outputs/01-business-req-analysis-G03.md`
- Target DBMS: Microsoft SQL Server
- Path discrepancies: None.
- Design-stage discrepancy recorded: Conceptual §4 states `HAS_APPROVAL_DECISION` as `Booking Request 1 to Approval Decision 0..1`, while the logical-stage guardrail/rubric requires `APPROVAL_DECISION.booking_id` to remain a non-unique many-side FK unless an explicit stakeholder rule forces one decision per booking. This logical design therefore preserves approval/audit history with a non-unique `APPROVAL_DECISION.booking_id` and carries the one-decision-versus-decision-history issue as an Open Question.

## 2. Relational Schema

### 2.0 Logical conventions, key standardization, and FK action criteria

- SQL Server logical data types are used: `INT`, `NVARCHAR(n)`, and `DATETIME2(0)`.
- Every logical table uses a system-generated surrogate `INT IDENTITY(1,1)` primary key with a named `PK_...` constraint. Conceptual natural identifiers that are business-meaningful (`USER.user_id`, `SPACE.unique_space_code`) are demoted to regular attributes with named `UNIQUE` constraints. Foreign keys always reference parent surrogate `INT` primary keys, never demoted natural keys.
- Surrogate `INT` keys are used for storage efficiency, join performance, and key stability. If a natural identifier such as a student/user code or space code needs correction, the correction affects only the single row containing the unique business attribute; no referencing rows need cascaded updates because no FK references the natural key.
- Conceptual proposed identifiers with no business meaning (`Facility ID`, `Booking ID`, `Approval Decision ID`, `Usage Session ID`, `Maintenance Record ID`) are implemented directly as the required surrogate `INT IDENTITY` primary keys rather than duplicated as separate business columns.
- `ON DELETE CASCADE` is used only for pure dependent current-state association rows with no historical/audit value (`SPACE_FACILITY`). `ON DELETE NO ACTION` is used for references to master data or historical/audit records where deletion would erase or orphan booking, approval, usage, or maintenance history. `SET NULL` is not used because preserving who acted is more important than allowing actor deletion while retaining incomplete history.
- `ON UPDATE NO ACTION` is used uniformly because every referenced primary key is an immutable surrogate `INT`; natural-key corrections occur on non-referenced unique attributes.
- Allowed-value CHECK constraints are included only where upstream values are listed. No CHECK is added for `USER_ACCOUNT.account_status`, `MAINTENANCE_RECORD.status`, or `FACILITY.facility_name` because upstream values are absent or examples are non-exhaustive.
- Source-optional notes (`decision_note`, `usage_notes`, `result_note`) are nullable. Lifecycle-dependent completion fields are nullable until completion occurs.

### 2.1 `USER_ACCOUNT`

Logical table for conceptual `USER`. The table is named `USER_ACCOUNT` to avoid the SQL Server reserved/generic term `USER` while preserving the upstream meaning of a university account user.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `user_account_id` | `INT IDENTITY(1,1)` | NOT NULL | Surrogate PK | Logical-stage surrogate key standardization |
| `user_id` | `NVARCHAR(50)` | NOT NULL | Demoted natural identifier; unique | Conceptual `USER.user_id`; BR-01, BR-02 |
| `full_name` | `NVARCHAR(200)` | NULL | Stored user information; nullable because source says stored, not explicitly required | Conceptual `full_name`; BR-02 |
| `email` | `NVARCHAR(254)` | NOT NULL | Candidate key for university account email; unique | Conceptual `email`; BR-02; logical-stage candidate-key assumption |
| `phone_number` | `NVARCHAR(30)` | NULL | Stored user information | Conceptual `phone_number`; BR-02 |
| `role` | `NVARCHAR(40)` | NOT NULL | Allowed-value CHECK from upstream role list | Conceptual `role`; BR-03 |
| `department` | `NVARCHAR(120)` | NULL | Stored user information | Conceptual `department`; BR-02 |
| `account_status` | `NVARCHAR(50)` | NULL | Stored user information; no allowed-value CHECK because values are open | Conceptual `account_status`; BR-02; Open Question |

Primary key:
- `CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY (user_account_id)`

Foreign keys:
- None.

Uniqueness constraints:
- `CONSTRAINT UQ_USER_ACCOUNT_user_id UNIQUE (user_id)`
- `CONSTRAINT UQ_USER_ACCOUNT_email UNIQUE (email)`

CHECK constraints:
- `CONSTRAINT CK_USER_ACCOUNT_role CHECK (role IN ('Student', 'Lecturer', 'Teaching Assistant', 'Facility Staff', 'Department Administrator', 'Facility Manager'))`

Unresolved / implementation rules:
- Allowed values for `account_status` are unresolved.
- Whether generic “staff” view access includes only Facility Staff or more roles is unresolved.

### 2.2 `SPACE`

Logical table for conceptual `SPACE`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `space_id` | `INT IDENTITY(1,1)` | NOT NULL | Surrogate PK | Logical-stage surrogate key standardization |
| `unique_space_code` | `NVARCHAR(50)` | NOT NULL | Demoted natural identifier; unique | Conceptual `unique_space_code`; BR-05 |
| `space_name` | `NVARCHAR(200)` | NULL | Stored space information; no unsupported uniqueness | Conceptual `space_name`; BR-05 |
| `space_type` | `NVARCHAR(80)` | NULL | Stored space information; no allowed-value CHECK because upstream examples are not an explicit exhaustive list | Conceptual `space_type`; BR-05 |
| `building` | `NVARCHAR(120)` | NULL | Stored space information | Conceptual `building`; BR-05 |
| `floor` | `NVARCHAR(30)` | NULL | Stored space information | Conceptual `floor`; BR-05 |
| `room_number` | `NVARCHAR(30)` | NULL | Stored space information; no unsupported uniqueness | Conceptual `room_number`; BR-05 |
| `capacity` | `INT` | NULL | Stored space capacity; non-negative CHECK when present | Conceptual `capacity`; BR-05 |
| `current_status` | `NVARCHAR(40)` | NOT NULL | Allowed-value CHECK from upstream status list | Conceptual `current_status`; BR-06, BR-13 |
| `usage_policy` | `NVARCHAR(1000)` | NULL | Stored policy text; enforcement is unresolved | Conceptual `usage_policy`; BR-05; Open Question |

Primary key:
- `CONSTRAINT PK_SPACE PRIMARY KEY (space_id)`

Foreign keys:
- None.

Uniqueness constraints:
- `CONSTRAINT UQ_SPACE_unique_space_code UNIQUE (unique_space_code)`

CHECK constraints:
- `CONSTRAINT CK_SPACE_current_status CHECK (current_status IN ('Available', 'In use', 'Under maintenance', 'Temporarily closed', 'Retired'))`
- `CONSTRAINT CK_SPACE_capacity_nonnegative CHECK (capacity IS NULL OR capacity >= 0)`

Unresolved / implementation rules:
- Whether active maintenance records automatically set `current_status = 'Under maintenance'` is unresolved and requires cross-table implementation if confirmed.
- Usage-policy enforcement is unresolved.

### 2.3 `FACILITY`

Logical table for conceptual `FACILITY`.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `facility_id` | `INT IDENTITY(1,1)` | NOT NULL | Surrogate PK; conceptual proposed identifier implemented as surrogate | Conceptual `facility_id`; upstream assumption |
| `facility_name` | `NVARCHAR(120)` | NOT NULL | Facility name/type; no UNIQUE because upstream does not state uniqueness | Conceptual `facility_name`; BR-07 |

Primary key:
- `CONSTRAINT PK_FACILITY PRIMARY KEY (facility_id)`

Foreign keys:
- None.

Uniqueness constraints:
- None.

CHECK constraints:
- None; the listed facility names are examples introduced by “such as,” not an exhaustive allowed-value list.

Unresolved / implementation rules:
- None.

### 2.4 `SPACE_FACILITY`

Associative table resolving the conceptual M:N `HAS_FACILITY` relationship.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `space_facility_id` | `INT IDENTITY(1,1)` | NOT NULL | Surrogate PK required for every table | Logical-stage surrogate key standardization |
| `space_id` | `INT` | NOT NULL | FK to `SPACE(space_id)`; `INT` matches parent surrogate PK | Conceptual `HAS_FACILITY`; BR-07 |
| `facility_id` | `INT` | NOT NULL | FK to `FACILITY(facility_id)`; `INT` matches parent surrogate PK | Conceptual `HAS_FACILITY`; BR-07 |

Primary key:
- `CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (space_facility_id)`

Foreign keys:
- `CONSTRAINT FK_SPACE_FACILITY_space_id FOREIGN KEY (space_id) REFERENCES SPACE(space_id) ON DELETE CASCADE ON UPDATE NO ACTION` — `ON DELETE CASCADE` because this row is a pure current-state association that is meaningless without its parent Space; `ON UPDATE NO ACTION` because `SPACE.space_id` is immutable.
- `CONSTRAINT FK_SPACE_FACILITY_facility_id FOREIGN KEY (facility_id) REFERENCES FACILITY(facility_id) ON DELETE CASCADE ON UPDATE NO ACTION` — `ON DELETE CASCADE` because this row is a pure current-state association that is meaningless without its parent Facility; `ON UPDATE NO ACTION` because `FACILITY.facility_id` is immutable.

Uniqueness constraints:
- `CONSTRAINT UQ_SPACE_FACILITY_space_id_facility_id UNIQUE (space_id, facility_id)` — prevents duplicate association rows while keeping the required surrogate PK.

CHECK constraints:
- None.

Unresolved / implementation rules:
- None.

### 2.5 `BOOKING_REQUEST`

Logical table for conceptual `BOOKING_REQUEST`, including FKs for the submitting user and selected space.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `booking_id` | `INT IDENTITY(1,1)` | NOT NULL | Surrogate PK; conceptual proposed Booking ID implemented as surrogate | Conceptual `booking_id`; upstream assumption |
| `requester_user_account_id` | `INT` | NOT NULL | FK to `USER_ACCOUNT(user_account_id)`; `INT` matches parent surrogate PK | Conceptual `SUBMITS`; BR-08 |
| `space_id` | `INT` | NOT NULL | FK to `SPACE(space_id)`; `INT` matches parent surrogate PK | Conceptual `SELECTS_SPACE`; BR-08 |
| `requested_start_time` | `DATETIME2(0)` | NOT NULL | Requested time; in-row ordering CHECK with end time | Conceptual `requested_start_time`; BR-08, BR-12 |
| `requested_end_time` | `DATETIME2(0)` | NOT NULL | Requested time; in-row ordering CHECK with start time | Conceptual `requested_end_time`; BR-08, BR-12 |
| `purpose_of_use` | `NVARCHAR(40)` | NOT NULL | Allowed-value CHECK from upstream purpose list | Conceptual `purpose_of_use`; BR-09 |
| `expected_number_of_participants` | `INT` | NOT NULL | Non-negative CHECK; capacity comparison unresolved | Conceptual `expected_number_of_participants`; BR-08 |
| `booking_status` | `NVARCHAR(30)` | NOT NULL | Allowed-value CHECK from upstream booking status list | Conceptual `booking_status`; BR-10 |

Primary key:
- `CONSTRAINT PK_BOOKING_REQUEST PRIMARY KEY (booking_id)`

Foreign keys:
- `CONSTRAINT FK_BOOKING_REQUEST_requester_user_account_id FOREIGN KEY (requester_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves booking history and prevents deleting a user referenced by a historical request; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.
- `CONSTRAINT FK_BOOKING_REQUEST_space_id FOREIGN KEY (space_id) REFERENCES SPACE(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves booking history and prevents deleting a space referenced by historical requests; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.

Uniqueness constraints:
- None. No uniqueness is added to `requester_user_account_id`, `space_id`, or time columns because many bookings per user/space are expected.

CHECK constraints:
- `CONSTRAINT CK_BOOKING_REQUEST_requested_time_order CHECK (requested_end_time > requested_start_time)`
- `CONSTRAINT CK_BOOKING_REQUEST_expected_participants_nonnegative CHECK (expected_number_of_participants >= 0)`
- `CONSTRAINT CK_BOOKING_REQUEST_purpose_of_use CHECK (purpose_of_use IN ('Lecture', 'Examination', 'Seminar', 'Workshop', 'Meeting', 'Student activity', 'Administrative event'))`
- `CONSTRAINT CK_BOOKING_REQUEST_booking_status CHECK (booking_status IN ('Pending', 'Approved', 'Rejected', 'Cancelled', 'Checked in', 'Completed', 'No-show'))`

Unresolved / implementation rules:
- Approved-booking overlap prevention for the same space/time requires SQL Server implementation logic because it compares multiple rows.
- Booking prevention for spaces under maintenance, temporarily closed, or retired requires cross-table implementation logic because it compares Booking Request against Space current status.
- Cancellation and no-show triggers/transitions are unresolved.
- Participant count versus space capacity is unresolved and is not enforced beyond non-negative participant count.

### 2.6 `APPROVAL_DECISION`

Logical table for conceptual `APPROVAL_DECISION`, including FKs for the booking being decided and the user who made the decision.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `approval_decision_id` | `INT IDENTITY(1,1)` | NOT NULL | Surrogate PK; conceptual proposed Approval Decision ID implemented as surrogate | Conceptual `approval_decision_id`; upstream assumption |
| `booking_id` | `INT` | NOT NULL | Plain non-unique FK to `BOOKING_REQUEST(booking_id)`; preserves decision/audit history | Conceptual `HAS_APPROVAL_DECISION`; logical-stage guardrail/open issue |
| `decision_maker_user_account_id` | `INT` | NOT NULL | FK to `USER_ACCOUNT(user_account_id)`; `INT` matches parent surrogate PK | Conceptual `MAKES_DECISION`; BR-15 |
| `decision_outcome` | `NVARCHAR(20)` | NOT NULL | Allowed-value CHECK from upstream derived outcome list | Conceptual `decision_outcome`; BR-15 |
| `decision_time` | `DATETIME2(0)` | NOT NULL | Decision event time | Conceptual `decision_time`; BR-15 |
| `decision_note` | `NVARCHAR(1000)` | NULL | Source note field; nullable under constraint-strength rule | Conceptual `decision_note`; BR-15 |
| `rejection_reason` | `NVARCHAR(1000)` | NULL | Required by CHECK when outcome is Rejected | Conceptual `rejection_reason`; BR-16 |

Primary key:
- `CONSTRAINT PK_APPROVAL_DECISION PRIMARY KEY (approval_decision_id)`

Foreign keys:
- `CONSTRAINT FK_APPROVAL_DECISION_booking_id FOREIGN KEY (booking_id) REFERENCES BOOKING_REQUEST(booking_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves decision/audit history and prevents deleting a booking referenced by decisions; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable. This FK is intentionally not unique to preserve decision history unless stakeholders confirm one decision per booking.
- `CONSTRAINT FK_APPROVAL_DECISION_decision_maker_user_account_id FOREIGN KEY (decision_maker_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves who made the historical decision; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.

Uniqueness constraints:
- None. `booking_id` is intentionally not unique to avoid collapsing the approval history cardinality to 1:0..1.

CHECK constraints:
- `CONSTRAINT CK_APPROVAL_DECISION_decision_outcome CHECK (decision_outcome IN ('Approved', 'Rejected'))`
- `CONSTRAINT CK_APPROVAL_DECISION_rejection_reason CHECK (decision_outcome <> 'Rejected' OR rejection_reason IS NOT NULL)`

Unresolved / implementation rules:
- Approval decision maker role restriction to Facility Staff or Facility Manager requires cross-table implementation logic against `USER_ACCOUNT.role`.
- Criteria for which bookings require approval remain unresolved.
- The upstream conceptual one-decision versus logical audit-history discrepancy remains an Open Question.

### 2.7 `USAGE_SESSION`

Logical table for conceptual `USAGE_SESSION`, including distinct FKs for check-in and completion actors.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `usage_session_id` | `INT IDENTITY(1,1)` | NOT NULL | Surrogate PK; conceptual proposed Usage Session ID implemented as surrogate | Conceptual `usage_session_id`; upstream assumption |
| `booking_id` | `INT` | NOT NULL | FK to `BOOKING_REQUEST(booking_id)` with UNIQUE to represent one usage session per booking | Conceptual `HAS_USAGE_SESSION`; BR-17-BR-19 |
| `checked_in_by_user_account_id` | `INT` | NOT NULL | FK to `USER_ACCOUNT(user_account_id)`; distinct check-in role | Conceptual `CHECKED_IN_BY`; BR-18 |
| `completed_by_user_account_id` | `INT` | NULL | Nullable FK to `USER_ACCOUNT(user_account_id)`; distinct completion role, lifecycle-dependent | Conceptual `COMPLETED_BY`; BR-19 |
| `actual_start_time` | `DATETIME2(0)` | NOT NULL | Check-in event time | Conceptual `actual_start_time`; BR-18 |
| `initial_condition_of_space` | `NVARCHAR(1000)` | NULL | Recorded condition; nullable under constraint-strength rule | Conceptual `initial_condition_of_space`; BR-18 |
| `actual_end_time` | `DATETIME2(0)` | NULL | Completion time, nullable until session completion | Conceptual `actual_end_time`; BR-19 |
| `final_condition_of_space` | `NVARCHAR(1000)` | NULL | Completion condition, nullable until completion | Conceptual `final_condition_of_space`; BR-19 |
| `usage_notes` | `NVARCHAR(1000)` | NULL | Source says “any usage notes”; optional | Conceptual `usage_notes`; BR-19 |

Primary key:
- `CONSTRAINT PK_USAGE_SESSION PRIMARY KEY (usage_session_id)`

Foreign keys:
- `CONSTRAINT FK_USAGE_SESSION_booking_id FOREIGN KEY (booking_id) REFERENCES BOOKING_REQUEST(booking_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves usage history and prevents deleting a booking referenced by a usage session; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.
- `CONSTRAINT FK_USAGE_SESSION_checked_in_by_user_account_id FOREIGN KEY (checked_in_by_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves who checked in the historical session; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.
- `CONSTRAINT FK_USAGE_SESSION_completed_by_user_account_id FOREIGN KEY (completed_by_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — nullable role FK but `ON DELETE NO ACTION` is chosen instead of `SET NULL` to preserve who completed the historical session; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.

Uniqueness constraints:
- `CONSTRAINT UQ_USAGE_SESSION_booking_id UNIQUE (booking_id)` — represents conceptual `Booking Request 1 to Usage Session 0..1`.

CHECK constraints:
- `CONSTRAINT CK_USAGE_SESSION_actual_time_order CHECK (actual_end_time IS NULL OR actual_end_time > actual_start_time)`

Unresolved / implementation rules:
- Check-in and completion role restrictions to Facility Staff require cross-table implementation logic against `USER_ACCOUNT.role`.
- Completion consistency beyond the in-row chronological ordering may require implementation logic if stakeholders require all completion fields together.

### 2.8 `MAINTENANCE_RECORD`

Logical table for conceptual `MAINTENANCE_RECORD`, including related space, reporter, and assigned staff relationships.

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `maintenance_record_id` | `INT IDENTITY(1,1)` | NOT NULL | Surrogate PK; conceptual proposed Maintenance Record ID implemented as surrogate | Conceptual `maintenance_record_id`; upstream assumption |
| `space_id` | `INT` | NOT NULL | FK to `SPACE(space_id)`; `INT` matches parent surrogate PK | Conceptual `HAS_MAINTENANCE_RECORD`; BR-22 |
| `reporter_user_account_id` | `INT` | NOT NULL | FK to `USER_ACCOUNT(user_account_id)`; distinct reporter role | Conceptual `REPORTED_BY`; BR-22 |
| `assigned_staff_user_account_id` | `INT` | NOT NULL | FK to `USER_ACCOUNT(user_account_id)`; distinct assignee role | Conceptual `ASSIGNED_TO`; BR-22 |
| `problem_description` | `NVARCHAR(1000)` | NOT NULL | Maintenance problem text | Conceptual `problem_description`; BR-21, BR-22 |
| `start_time` | `DATETIME2(0)` | NOT NULL | Maintenance start time | Conceptual `start_time`; BR-22 |
| `completion_time` | `DATETIME2(0)` | NULL | Nullable until maintenance completion; ordering CHECK with start time | Conceptual `completion_time`; BR-22 |
| `status` | `NVARCHAR(50)` | NULL | Stored status; no CHECK because upstream values are unresolved | Conceptual `status`; BR-22; Open Question |
| `result_note` | `NVARCHAR(1000)` | NULL | Source note field; nullable under constraint-strength rule | Conceptual `result_note`; BR-22 |

Primary key:
- `CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (maintenance_record_id)`

Foreign keys:
- `CONSTRAINT FK_MAINTENANCE_RECORD_space_id FOREIGN KEY (space_id) REFERENCES SPACE(space_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves maintenance history and prevents deleting a referenced space; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.
- `CONSTRAINT FK_MAINTENANCE_RECORD_reporter_user_account_id FOREIGN KEY (reporter_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves who reported the maintenance record; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.
- `CONSTRAINT FK_MAINTENANCE_RECORD_assigned_staff_user_account_id FOREIGN KEY (assigned_staff_user_account_id) REFERENCES USER_ACCOUNT(user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION` — `ON DELETE NO ACTION` preserves who was assigned to the maintenance record; `ON UPDATE NO ACTION` because the parent surrogate PK is immutable.

Uniqueness constraints:
- None. Many maintenance records per space, reporter, and assigned staff member are permitted.

CHECK constraints:
- `CONSTRAINT CK_MAINTENANCE_RECORD_time_order CHECK (completion_time IS NULL OR completion_time > start_time)`

Unresolved / implementation rules:
- Allowed maintenance status values and lifecycle transitions are unresolved.
- Maintenance role restrictions for reporter/assignee are unresolved or require cross-table implementation if confirmed.
- Active maintenance effect on `SPACE.current_status` requires cross-table implementation if confirmed.

## 3. Relationship Mapping

| Conceptual Relationship | Cardinality / Participation | Logical Mapping |
|---|---|---|
| `SUBMITS` | User `1` to Booking Request `0..*`; each Booking Request has exactly one User | `BOOKING_REQUEST.requester_user_account_id INT NOT NULL` → `USER_ACCOUNT.user_account_id`; FK `FK_BOOKING_REQUEST_requester_user_account_id`; non-unique many-side FK. |
| `SELECTS_SPACE` | Space `1` to Booking Request `0..*`; each Booking Request selects exactly one Space | `BOOKING_REQUEST.space_id INT NOT NULL` → `SPACE.space_id`; FK `FK_BOOKING_REQUEST_space_id`; non-unique many-side FK. |
| `HAS_FACILITY` | Space `0..*` to Facility `0..*` | Junction table `SPACE_FACILITY` with FKs to `SPACE.space_id` and `FACILITY.facility_id`; pair uniqueness prevents duplicate associations. |
| `HAS_APPROVAL_DECISION` | Conceptual file states Booking Request `1` to Approval Decision `0..1`; logical guardrail preserves audit history as `0..*` unless one-decision requirement is confirmed | `APPROVAL_DECISION.booking_id INT NOT NULL` → `BOOKING_REQUEST.booking_id`; FK `FK_APPROVAL_DECISION_booking_id`; intentionally non-unique pending stakeholder confirmation. |
| `MAKES_DECISION` | User `1` to Approval Decision `0..*`; each Approval Decision has exactly one decision maker | `APPROVAL_DECISION.decision_maker_user_account_id INT NOT NULL` → `USER_ACCOUNT.user_account_id`; FK `FK_APPROVAL_DECISION_decision_maker_user_account_id`; non-unique many-side FK. |
| `HAS_USAGE_SESSION` | Booking Request `1` to Usage Session `0..1`; each Usage Session belongs to exactly one Booking Request | `USAGE_SESSION.booking_id INT NOT NULL` → `BOOKING_REQUEST.booking_id`; FK `FK_USAGE_SESSION_booking_id`; unique constraint `UQ_USAGE_SESSION_booking_id`. |
| `CHECKED_IN_BY` | User `1` to Usage Session `0..*`; each Usage Session has exactly one check-in User | `USAGE_SESSION.checked_in_by_user_account_id INT NOT NULL` → `USER_ACCOUNT.user_account_id`; FK `FK_USAGE_SESSION_checked_in_by_user_account_id`; non-unique many-side FK. |
| `COMPLETED_BY` | User `0..1` to Usage Session `0..*` in conceptual row; each Usage Session may have zero or one completing User until completion | `USAGE_SESSION.completed_by_user_account_id INT NULL` → `USER_ACCOUNT.user_account_id`; FK `FK_USAGE_SESSION_completed_by_user_account_id`; nullable, non-unique role FK. |
| `HAS_MAINTENANCE_RECORD` | Space `1` to Maintenance Record `0..*`; each Maintenance Record relates to exactly one Space | `MAINTENANCE_RECORD.space_id INT NOT NULL` → `SPACE.space_id`; FK `FK_MAINTENANCE_RECORD_space_id`; non-unique many-side FK. |
| `REPORTED_BY` | User `1` to Maintenance Record `0..*`; each Maintenance Record has exactly one reporter | `MAINTENANCE_RECORD.reporter_user_account_id INT NOT NULL` → `USER_ACCOUNT.user_account_id`; FK `FK_MAINTENANCE_RECORD_reporter_user_account_id`; non-unique many-side FK. |
| `ASSIGNED_TO` | User `1` to Maintenance Record `0..*`; each Maintenance Record has exactly one assigned staff member | `MAINTENANCE_RECORD.assigned_staff_user_account_id INT NOT NULL` → `USER_ACCOUNT.user_account_id`; FK `FK_MAINTENANCE_RECORD_assigned_staff_user_account_id`; non-unique many-side FK. |

## 4. Traceability from Requirements to Tables and Constraints

| Requirement / Rule | Logical Tables / Columns | Logical Treatment |
|---|---|---|
| BR-01: Each user must have a university account. | `USER_ACCOUNT.user_account_id`, `USER_ACCOUNT.user_id`, `USER_ACCOUNT.email` | Enforced by PK plus `UQ_USER_ACCOUNT_user_id`; email candidate key enforced by `UQ_USER_ACCOUNT_email`. |
| BR-02: Store user ID, full name, email, phone number, role, department, account status. | `USER_ACCOUNT` columns | Enforced by table/columns; role CHECK; account-status values unresolved. |
| BR-03: User roles are Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager. | `USER_ACCOUNT.role` | Enforced by `CK_USER_ACCOUNT_role`. |
| BR-04: School manages many bookable spaces. | `SPACE` | Enforced by table and `PK_SPACE`. |
| BR-05: Store space details. | `SPACE` columns | Natural code uniqueness enforced by `UQ_SPACE_unique_space_code`; other attributes stored without unsupported uniqueness. |
| BR-06: Space status values. | `SPACE.current_status` | Enforced by `CK_SPACE_current_status`. |
| BR-07: Spaces have several facilities; store facilities available in each space. | `FACILITY`, `SPACE_FACILITY` | Enforced by FKs and `UQ_SPACE_FACILITY_space_id_facility_id`. |
| BR-08: Users submit booking requests selecting space, times, purpose, expected participants. | `BOOKING_REQUEST` columns and FKs | Enforced by FKs to `USER_ACCOUNT` and `SPACE`; time order and non-negative participant CHECKs. |
| BR-09: Booking purpose values. | `BOOKING_REQUEST.purpose_of_use` | Enforced by `CK_BOOKING_REQUEST_purpose_of_use`. |
| BR-10: Booking status values. | `BOOKING_REQUEST.booking_status` | Enforced by `CK_BOOKING_REQUEST_booking_status`; lifecycle transitions beyond upstream evidence remain open/implementation logic. |
| BR-11: Prevent conflicting bookings. | `BOOKING_REQUEST.space_id`, requested times, status | Requires SQL Server implementation logic; cross-row overlap cannot be enforced by ordinary CHECK. |
| BR-12: Same space cannot have two approved overlapping bookings. | `BOOKING_REQUEST.space_id`, `requested_start_time`, `requested_end_time`, `booking_status` | Requires SQL Server trigger/procedure/transaction rule or indexed-view pattern. |
| BR-13: Under-maintenance, temporarily closed, retired spaces cannot be booked. | `BOOKING_REQUEST.space_id`, `SPACE.current_status` | Requires cross-table SQL Server implementation logic. |
| BR-14: Booking may require approval from facility staff or manager. | `APPROVAL_DECISION`, `USER_ACCOUNT.role` | Optional approval represented by relationship; approval-required criteria unresolved; decision-maker role restriction requires cross-table implementation logic. |
| BR-15: Store decision maker, decision time, decision note for approval/rejection. | `APPROVAL_DECISION.decision_maker_user_account_id`, `decision_time`, `decision_note`, `decision_outcome` | FK and columns; outcome CHECK; role restriction requires implementation logic. |
| BR-16: Rejected booking should store rejection reason. | `APPROVAL_DECISION.decision_outcome`, `rejection_reason` | Enforced by named in-row CHECK `CK_APPROVAL_DECISION_rejection_reason`. |
| BR-17: Facility staff can check in booking. | `USAGE_SESSION`, `checked_in_by_user_account_id` | FK stores check-in actor; Facility Staff role restriction requires cross-table implementation logic. |
| BR-18: Store actual start time, check-in person, initial condition. | `USAGE_SESSION.actual_start_time`, `checked_in_by_user_account_id`, `initial_condition_of_space` | Columns and FK; check-in actor role restriction requires implementation logic. |
| BR-19: Complete booking by recording actual end time, final condition, usage notes. | `USAGE_SESSION.actual_end_time`, `completed_by_user_account_id`, `final_condition_of_space`, `usage_notes` | Columns and FK; chronological order enforced by `CK_USAGE_SESSION_actual_time_order`; completion actor role restriction requires implementation logic. |
| BR-20: Support maintenance management. | `MAINTENANCE_RECORD` | Enforced by table and PK. |
| BR-21: Spaces may have maintenance records for problems. | `MAINTENANCE_RECORD.problem_description`, `space_id` | FK to `SPACE` and problem description column. |
| BR-22: Store related space, reporter, assigned staff member, problem description, start/completion time, status, result note. | `MAINTENANCE_RECORD` columns and FKs | FKs enforce related space/reporter/assignee existence; time order CHECK; status values unresolved. |
| BR-23: Space under maintenance cannot be booked. | `SPACE.current_status`, `BOOKING_REQUEST.space_id` | Requires cross-table SQL Server implementation logic; active-maintenance synchronization unresolved. |
| BR-24: Keep historical records of bookings and maintenance activities. | Booking, approval, usage, maintenance tables and FK `ON DELETE NO ACTION` choices | Enforced structurally by historical tables and deletion restrictions. |
| BR-25: Staff view booking history, upcoming bookings, spaces under maintenance, no-show bookings. | `BOOKING_REQUEST`, `SPACE`, `MAINTENANCE_RECORD`, `USAGE_SESSION`, `APPROVAL_DECISION` | Data supports views/queries; authorization scope and view implementation deferred. |

Mandatory classification summary:
- No overlapping approved bookings for the same space/time: requires SQL Server implementation logic (cross-row).
- No booking for spaces under maintenance, temporarily closed, or retired: requires SQL Server implementation logic (cross-table).
- Approval decision maker role restriction: requires SQL Server implementation logic against `USER_ACCOUNT.role`.
- Check-in and completion role restrictions: require SQL Server implementation logic against `USER_ACCOUNT.role`.
- Rejected approval must store rejection reason: enforced by CHECK constraint `CK_APPROVAL_DECISION_rejection_reason`.
- Maintenance status handling and active-maintenance effect on availability: unresolved Open Questions; would require implementation logic if confirmed.
- Participant count versus space capacity: unresolved Open Question; only non-negative participant count is enforced.

## 5. Assumptions Carried Forward

- [upstream] Facility ID, Booking ID, Approval Decision ID, Usage Session ID, and Maintenance Record ID were proposed identifiers because the source did not state identifiers for those entities.
- [upstream] Decision outcome is included on Approval Decision because the source describes approval/rejection outcomes, although it was derived rather than listed as a separately stored fact.
- [upstream] Decision note and rejection reason are distinct Approval Decision facts.
- [upstream] Facility is treated as a reusable facility type/name across spaces.
- [upstream] Generic “staff” was not added as a separate actor; staff-view scope remains unresolved.
- [logical-stage] The conceptual entity `USER` is implemented as `USER_ACCOUNT` to avoid reserved/generic SQL Server naming and to reflect the upstream university-account requirement.
- [logical-stage] Every table uses a surrogate `INT IDENTITY` primary key; natural/business identifiers `user_id` and `unique_space_code` are demoted to unique business attributes.
- [logical-stage] Conceptual proposed non-business identifiers (`facility_id`, `booking_id`, `approval_decision_id`, `usage_session_id`, `maintenance_record_id`) are implemented as surrogate `INT IDENTITY` primary keys rather than duplicated as separate natural-key columns.
- [logical-stage] `USER_ACCOUNT.email` is treated as a candidate key because a university account email is assumed to map to exactly one user account.
- [logical-stage] Note fields and descriptive fields whose source only says “stored” or “recorded” are nullable unless the workflow clearly requires them at row creation.
- [logical-stage] `APPROVAL_DECISION.booking_id` is non-unique to preserve decision/audit history according to the logical-stage guardrail; the conceptual 1:0..1 wording is carried as an open discrepancy for stakeholder confirmation.

## 6. Open Questions Carried Forward and Newly Raised

- Question: How is Space usage policy enforced, if at all, during booking submission or approval? — Affects `SPACE.usage_policy` and `BOOKING_REQUEST.purpose_of_use`; no constraint added.
- Question: Which prior status, trigger, and actor cause a Booking Request to become Cancelled? — Affects `BOOKING_REQUEST.booking_status`; no transition constraint added.
- Question: Which prior status, trigger, and actor cause a Booking Request to become No-show? — Affects `BOOKING_REQUEST.booking_status`; no transition constraint added.
- Question: Which booking requests require approval, and can any booking bypass approval? — Affects optional approval workflow and `APPROVAL_DECISION`; no required-approval constraint added.
- Question: Should a booking have at most one Approval Decision or should multiple decisions be preserved as approval/audit history? — Affects whether `APPROVAL_DECISION.booking_id` should become unique in the future; current logical design keeps it non-unique.
- Question: What are the allowed status values and lifecycle transitions for Maintenance Record status? — Affects `MAINTENANCE_RECORD.status`; no allowed-value CHECK added.
- Question: Which user roles are allowed to report maintenance issues? — Affects `MAINTENANCE_RECORD.reporter_user_account_id`; no role CHECK added.
- Question: Which user roles are allowed to assign the assigned staff member on a Maintenance Record? — Affects maintenance assignment workflow; no assigning-actor relationship added.
- Question: Does staff view access mean Facility Staff only, or does it include other staff roles? — Affects authorization/views, not base relational schema.
- Question: Does creating, starting, completing, or changing a Maintenance Record automatically change related `SPACE.current_status` to or from Under maintenance? — Affects cross-table synchronization; no automatic constraint added.
- Question: Is expected number of participants only recorded, or must it be compared with Space capacity during booking or approval? — Affects `BOOKING_REQUEST.expected_number_of_participants` and `SPACE.capacity`; no capacity comparison added.
- Question: What values are allowed for User account status? — Affects `USER_ACCOUNT.account_status`; no CHECK added.
- Question: What exact implementation mechanism should enforce approved-booking overlap prevention in SQL Server? — Affects future trigger/procedure/transaction design.
- Question: What exact implementation mechanism should enforce unavailable-space booking prevention in SQL Server? — Affects future trigger/procedure/transaction design.
