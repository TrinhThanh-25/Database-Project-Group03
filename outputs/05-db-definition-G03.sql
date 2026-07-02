/*
================================================================================
 Database Implementation (DDL) - Group 03
 Phase 1 - SQL Server schema definition
================================================================================

 Source documents (sole authoritative implementation inputs):
   - outputs/03-logical-design-G03.md  (Logical Database Design)
   - outputs/04-design-validation-G03.md (Design Review Report - ACCEPTED WITH CONDITIONS)

 Scope: table definitions, PK/FK/UNIQUE/CHECK constraints only. No triggers,
 no stored procedures, no manually created indexes in Phase 1 (Rules 3 and 5
 of database-definition-implementation-engineer.md). Deferred implementation
 logic is recorded as "-- PHASE 2" comment blocks; unresolved upstream
 questions are recorded as "-- OPEN QUESTION" comment blocks. Neither is
 implemented in this script.

--------------------------------------------------------------------------------
 [upstream] assumptions carried forward from the logical design (Section 5):
--------------------------------------------------------------------------------
 - DEPARTMENT and lookup entities (ROLE, ACCOUNT_STATUS, SPACE_STATUS,
   BOOKING_STATUS, MAINTENANCE_STATUS) are modeled as separate tables.
 - APPROVAL_DECISION.decision_outcome_booking_status_id references
   BOOKING_STATUS; only 'approved' and 'rejected' are meaningful decision
   outcomes, but the domain is not further restricted at this stage.
 - decision_note and rejection_reason are distinct facts on APPROVAL_DECISION.
 - The source word "closed" maps to the listed status "temporarily closed".
 - "manager" in approval is treated as the "facility manager" role.
 - BOOKING_REQUEST has at most one USAGE_SESSION because a session records
   one start-to-end use.
 - ASSIGNED_TO is optional on MAINTENANCE_RECORD because assignment timing
   is not stated upstream.

--------------------------------------------------------------------------------
 [logical-stage] assumptions carried forward from the logical design:
--------------------------------------------------------------------------------
 - Every table uses a surrogate INT IDENTITY primary key; natural/business
   identifiers are demoted to named UNIQUE attributes.
 - USER_ACCOUNT.email is treated as a candidate key and constrained UNIQUE;
   the source stores email but does not explicitly say it is unique.
 - SPACE_FACILITY uses a surrogate space_facility_id PK plus
   UQ_SPACE_FACILITY_space_id_facility_id to satisfy the surrogate-PK
   standard while preventing duplicate associations.
 - decision_note, usage_notes, actual_end_time, final_condition_of_space,
   completion_time, and result_note are nullable because they are optional
   or lifecycle-dependent in the upstream workflow.
 - Full enforcement of the rejected-decision reason rule depends on seeded
   lookup IDs or a later code pattern; only the FK and table structure are
   implemented in Phase 1 (see PHASE 2 block on APPROVAL_DECISION).

--------------------------------------------------------------------------------
 [ddl-stage] assumptions introduced at this implementation stage:
--------------------------------------------------------------------------------
 - IDENTITY(1,1) is used for every surrogate INT primary key (logical design
   leaves IDENTITY vs. application-generated as a DDL-stage choice).
 - Table roster: 14 tables are implemented in the FK-dependency order of
   Rule 6 of the engineer agent, which includes the 6 lookup/reference
   tables (ROLE, ACCOUNT_STATUS, DEPARTMENT, SPACE_STATUS, BOOKING_STATUS,
   MAINTENANCE_STATUS) defined by the logical design (03-logical-design-G03.md
   Section 2) in addition to the 8 core entity tables.
 - DEPARTMENT.head_user_account_id -> USER_ACCOUNT and
   USER_ACCOUNT.department_id -> DEPARTMENT form a circular FK dependency.
   Resolved per Rule 6 by creating DEPARTMENT first without the
   FK_DEPARTMENT_head_user_account_id constraint, creating USER_ACCOUNT
   next, then adding FK_DEPARTMENT_head_user_account_id via a deferred
   ALTER TABLE.
 - CK_APPROVAL_DECISION_rejection_reason, named in the logical design with a
   <BOOKING_STATUS_ID_FOR_REJECTED> placeholder, is NOT created in Phase 1.
   Engineer agent Rule 7 explicitly forbids resolving this by guessing a
   decision_outcome column or trigger in Phase 1; validation report L-01
   requires the placeholder be resolved before implementation, which
   requires seeded BOOKING_STATUS rows that do not exist yet. The full rule
   is carried forward as a PHASE 2 comment block on APPROVAL_DECISION
   instead.
 - Drop statements at the top of this script are guarded with
   IF OBJECT_ID(...) IS NOT NULL for idempotent re-run (rubric D4), dropped
   in reverse dependency order.

--------------------------------------------------------------------------------
 Open questions carried forward from the logical design (Section 6) and the
 engineer agent's mandatory list (Rule 4) - none are resolved in this script.
 Each is also placed as an "-- OPEN QUESTION" block at its most relevant
 table below:
--------------------------------------------------------------------------------
 1. How, if at all, should the stored usage policy (SPACE.usage_policy) be
    enforced against booking requests?
 2. Which listed account roles are included in generic "Staff" viewing
    permissions?
 3. What is the account_status allowed-value set? (ACCOUNT_STATUS.status_name
    has no CHECK constraint until this is confirmed.)
 4. Which prior booking status, trigger, and actor set a booking request to
    Cancelled?
 5. Which prior booking status, trigger, and actor set a booking request to
    No-show?
 6. What are the allowed maintenance status values and transitions?
    (MAINTENANCE_STATUS.status_name has no CHECK constraint until this is
    confirmed.)
 7. Which role is allowed to report a maintenance issue?
 8. Who assigns the assigned staff member on a maintenance record, and when
    is assignment required?
 9. Does creating/opening a maintenance record automatically set
    SPACE.current_status to "Under maintenance"?
10. What criteria determine whether a booking request requires approval?
    Are any bookings exempt from the approval workflow (Pending -> Checked
    in directly)?
11. Must every approved or rejected booking have exactly one
    APPROVAL_DECISION row?
12. Should expected_number_of_participants be constrained to <= SPACE.capacity?
13. Should BOOKING_STATUS carry a stable machine-readable status_code so
    APPROVAL_DECISION can enforce rejected => rejection_reason deterministically?
14. Should Layer-A-only requester eligibility and special-equipment checks
    become explicit requirements?
================================================================================
*/

-- ============================================================================
-- Drop block (idempotent re-run), reverse dependency order
-- ============================================================================
IF OBJECT_ID(N'dbo.MAINTENANCE_RECORD', N'U') IS NOT NULL DROP TABLE dbo.MAINTENANCE_RECORD;
IF OBJECT_ID(N'dbo.MAINTENANCE_STATUS', N'U') IS NOT NULL DROP TABLE dbo.MAINTENANCE_STATUS;
IF OBJECT_ID(N'dbo.USAGE_SESSION', N'U') IS NOT NULL DROP TABLE dbo.USAGE_SESSION;
IF OBJECT_ID(N'dbo.APPROVAL_DECISION', N'U') IS NOT NULL DROP TABLE dbo.APPROVAL_DECISION;
IF OBJECT_ID(N'dbo.BOOKING_REQUEST', N'U') IS NOT NULL DROP TABLE dbo.BOOKING_REQUEST;
IF OBJECT_ID(N'dbo.BOOKING_STATUS', N'U') IS NOT NULL DROP TABLE dbo.BOOKING_STATUS;
IF OBJECT_ID(N'dbo.SPACE_FACILITY', N'U') IS NOT NULL DROP TABLE dbo.SPACE_FACILITY;
IF OBJECT_ID(N'dbo.FACILITY', N'U') IS NOT NULL DROP TABLE dbo.FACILITY;
IF OBJECT_ID(N'dbo.SPACE', N'U') IS NOT NULL DROP TABLE dbo.SPACE;
IF OBJECT_ID(N'dbo.SPACE_STATUS', N'U') IS NOT NULL DROP TABLE dbo.SPACE_STATUS;
IF OBJECT_ID(N'dbo.USER_ACCOUNT', N'U') IS NOT NULL DROP TABLE dbo.USER_ACCOUNT;
IF OBJECT_ID(N'dbo.DEPARTMENT', N'U') IS NOT NULL DROP TABLE dbo.DEPARTMENT;
IF OBJECT_ID(N'dbo.ACCOUNT_STATUS', N'U') IS NOT NULL DROP TABLE dbo.ACCOUNT_STATUS;
IF OBJECT_ID(N'dbo.ROLE', N'U') IS NOT NULL DROP TABLE dbo.ROLE;
GO

-- ============================================================================
-- 1. ROLE
-- ============================================================================
CREATE TABLE dbo.ROLE (
    role_id     INT IDENTITY(1,1) NOT NULL,
    role_name   NVARCHAR(80)      NOT NULL,
    CONSTRAINT PK_ROLE PRIMARY KEY (role_id),
    CONSTRAINT UQ_ROLE_role_name UNIQUE (role_name)
);
GO

-- ============================================================================
-- 2. ACCOUNT_STATUS
-- ============================================================================
CREATE TABLE dbo.ACCOUNT_STATUS (
    account_status_id  INT IDENTITY(1,1) NOT NULL,
    status_name         NVARCHAR(80)      NOT NULL,
    CONSTRAINT PK_ACCOUNT_STATUS PRIMARY KEY (account_status_id),
    CONSTRAINT UQ_ACCOUNT_STATUS_status_name UNIQUE (status_name)
);
GO

-- OPEN QUESTION (logical design Section 6 / engineer agent Rule 4):
-- What is the account_status allowed-value set? No CHECK constraint is
-- added to ACCOUNT_STATUS.status_name until this is confirmed upstream.

-- ============================================================================
-- 3. DEPARTMENT
-- Note: FK_DEPARTMENT_head_user_account_id is added later via ALTER TABLE
-- (deferred FK, see [ddl-stage] assumption in the header) because it
-- references USER_ACCOUNT, which references DEPARTMENT (circular FK).
-- ============================================================================
CREATE TABLE dbo.DEPARTMENT (
    department_id           INT IDENTITY(1,1) NOT NULL,
    department_name         NVARCHAR(150)      NOT NULL,
    head_user_account_id    INT                NULL,
    CONSTRAINT PK_DEPARTMENT PRIMARY KEY (department_id),
    CONSTRAINT UQ_DEPARTMENT_department_name UNIQUE (department_name)
);
GO

-- ============================================================================
-- 4. USER_ACCOUNT
-- ============================================================================
CREATE TABLE dbo.USER_ACCOUNT (
    user_account_id     INT IDENTITY(1,1) NOT NULL,
    user_id              NVARCHAR(50)       NOT NULL,
    full_name            NVARCHAR(200)      NOT NULL,
    email                NVARCHAR(254)      NOT NULL,
    phone_number         NVARCHAR(40)       NOT NULL,
    department_id        INT                NOT NULL,
    role_id              INT                NOT NULL,
    account_status_id    INT                NOT NULL,
    CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY (user_account_id),
    CONSTRAINT FK_USER_ACCOUNT_department_id FOREIGN KEY (department_id)
        REFERENCES dbo.DEPARTMENT (department_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_USER_ACCOUNT_role_id FOREIGN KEY (role_id)
        REFERENCES dbo.ROLE (role_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_USER_ACCOUNT_account_status_id FOREIGN KEY (account_status_id)
        REFERENCES dbo.ACCOUNT_STATUS (account_status_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_USER_ACCOUNT_user_id UNIQUE (user_id),
    CONSTRAINT UQ_USER_ACCOUNT_email UNIQUE (email)
);
GO

-- OPEN QUESTION (logical design Section 6):
-- Which listed account roles are included in generic "Staff" viewing
-- permissions (BR-21)? Does not affect USER_ACCOUNT/ROLE table structure.
--
-- OPEN QUESTION (logical design Section 6):
-- Should Layer-A-only requester eligibility and special-equipment checks
-- become explicit requirements? No column or constraint is added for this.

-- ============================================================================
-- Deferred FK: DEPARTMENT.head_user_account_id -> USER_ACCOUNT
-- (resolves the DEPARTMENT / USER_ACCOUNT circular dependency; see
-- [ddl-stage] assumption in the header.)
-- ============================================================================
ALTER TABLE dbo.DEPARTMENT
    ADD CONSTRAINT FK_DEPARTMENT_head_user_account_id FOREIGN KEY (head_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION;
GO

-- ============================================================================
-- 5. SPACE_STATUS
-- ============================================================================
CREATE TABLE dbo.SPACE_STATUS (
    space_status_id  INT IDENTITY(1,1) NOT NULL,
    status_name       NVARCHAR(80)      NOT NULL,
    CONSTRAINT PK_SPACE_STATUS PRIMARY KEY (space_status_id),
    CONSTRAINT UQ_SPACE_STATUS_status_name UNIQUE (status_name)
);
GO

-- ============================================================================
-- 6. SPACE
-- ============================================================================
CREATE TABLE dbo.SPACE (
    space_id            INT IDENTITY(1,1) NOT NULL,
    unique_space_code   NVARCHAR(50)       NOT NULL,
    space_name          NVARCHAR(200)      NOT NULL,
    space_type          NVARCHAR(100)      NOT NULL,
    building             NVARCHAR(100)      NOT NULL,
    floor                NVARCHAR(50)       NOT NULL,
    room_number          NVARCHAR(50)       NOT NULL,
    capacity             INT                NOT NULL,
    usage_policy         NVARCHAR(1000)     NOT NULL,
    space_status_id      INT                NOT NULL,
    CONSTRAINT PK_SPACE PRIMARY KEY (space_id),
    CONSTRAINT FK_SPACE_space_status_id FOREIGN KEY (space_status_id)
        REFERENCES dbo.SPACE_STATUS (space_status_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_SPACE_unique_space_code UNIQUE (unique_space_code),
    CONSTRAINT CK_SPACE_capacity_positive CHECK (capacity > 0)
);
GO

-- OPEN QUESTION (logical design Section 6):
-- How, if at all, should the stored usage policy (SPACE.usage_policy) be
-- enforced against booking requests? No enforcement logic is added.

-- ============================================================================
-- 7. FACILITY
-- ============================================================================
CREATE TABLE dbo.FACILITY (
    facility_id     INT IDENTITY(1,1) NOT NULL,
    facility_name    NVARCHAR(150)     NOT NULL,
    CONSTRAINT PK_FACILITY PRIMARY KEY (facility_id)
);
GO

-- ============================================================================
-- 8. SPACE_FACILITY
-- ============================================================================
CREATE TABLE dbo.SPACE_FACILITY (
    space_facility_id  INT IDENTITY(1,1) NOT NULL,
    space_id            INT                NOT NULL,
    facility_id         INT                NOT NULL,
    CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (space_facility_id),
    CONSTRAINT FK_SPACE_FACILITY_space_id FOREIGN KEY (space_id)
        REFERENCES dbo.SPACE (space_id) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT FK_SPACE_FACILITY_facility_id FOREIGN KEY (facility_id)
        REFERENCES dbo.FACILITY (facility_id) ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT UQ_SPACE_FACILITY_space_id_facility_id UNIQUE (space_id, facility_id)
);
GO

-- ============================================================================
-- 9. BOOKING_STATUS
-- ============================================================================
CREATE TABLE dbo.BOOKING_STATUS (
    booking_status_id  INT IDENTITY(1,1) NOT NULL,
    status_name          NVARCHAR(80)      NOT NULL,
    CONSTRAINT PK_BOOKING_STATUS PRIMARY KEY (booking_status_id),
    CONSTRAINT UQ_BOOKING_STATUS_status_name UNIQUE (status_name)
);
GO

-- ============================================================================
-- 10. BOOKING_REQUEST
-- ============================================================================
CREATE TABLE dbo.BOOKING_REQUEST (
    booking_request_id             INT IDENTITY(1,1) NOT NULL,
    requester_user_account_id      INT                NOT NULL,
    space_id                       INT                NOT NULL,
    booking_status_id              INT                NOT NULL,
    requested_start_time           DATETIME2(0)       NOT NULL,
    requested_end_time             DATETIME2(0)       NOT NULL,
    purpose_of_use                 NVARCHAR(80)       NOT NULL,
    expected_number_of_participants INT               NOT NULL,
    CONSTRAINT PK_BOOKING_REQUEST PRIMARY KEY (booking_request_id),
    CONSTRAINT FK_BOOKING_REQUEST_requester_user_account_id FOREIGN KEY (requester_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_BOOKING_REQUEST_space_id FOREIGN KEY (space_id)
        REFERENCES dbo.SPACE (space_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_BOOKING_REQUEST_booking_status_id FOREIGN KEY (booking_status_id)
        REFERENCES dbo.BOOKING_STATUS (booking_status_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_BOOKING_REQUEST_requested_time_order CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CK_BOOKING_REQUEST_expected_participants_positive CHECK (expected_number_of_participants > 0),
    CONSTRAINT CK_BOOKING_REQUEST_purpose_of_use CHECK (purpose_of_use IN (
        N'lecture', N'examination', N'seminar', N'workshop', N'meeting',
        N'student activity', N'administrative event'))
);
GO

-- PHASE 2: No overlapping approved bookings for the same space and time
-- period (BR-09, BR-10). Table/columns: BOOKING_REQUEST(space_id,
-- booking_status_id, requested_start_time, requested_end_time). A future
-- trigger, stored procedure, or serialized-transaction rule must reject an
-- INSERT/UPDATE that would create two rows for the same space_id, both with
-- an "approved" booking_status_id, whose [requested_start_time,
-- requested_end_time) intervals overlap.
--
-- PHASE 2: No booking for spaces with unavailable current_status
-- (BR-11, BR-19). Tables/columns: BOOKING_REQUEST(space_id), SPACE
-- (space_status_id). A future trigger or stored procedure must reject an
-- INSERT/UPDATE on BOOKING_REQUEST when the referenced SPACE's current
-- space_status_id resolves to "Under maintenance", "Temporarily closed", or
-- "Retired".
--
-- OPEN QUESTION (logical design Section 6 / engineer agent Rule 4):
-- Should expected_number_of_participants be constrained to <=
-- SPACE.capacity? Not enforced because upstream did not require the
-- comparison.
--
-- OPEN QUESTION (logical design Section 6 / engineer agent Rule 4):
-- Which prior booking status, trigger, and actor set a booking request to
-- Cancelled, and from which status(es) can this transition occur?
--
-- OPEN QUESTION (logical design Section 6 / engineer agent Rule 4):
-- Which prior booking status, trigger, and actor set a booking request to
-- No-show, and from which status(es) can this transition occur?
--
-- OPEN QUESTION (engineer agent Rule 4):
-- Are any bookings exempt from the approval workflow (i.e. can a booking
-- move Pending -> Checked in directly)? No such exemption logic is added.

-- ============================================================================
-- 11. APPROVAL_DECISION
-- ============================================================================
CREATE TABLE dbo.APPROVAL_DECISION (
    approval_decision_id               INT IDENTITY(1,1) NOT NULL,
    booking_request_id                 INT                NOT NULL,
    decided_by_user_account_id         INT                NOT NULL,
    decision_outcome_booking_status_id INT                NOT NULL,
    decision_time                      DATETIME2(0)       NOT NULL,
    decision_note                      NVARCHAR(1000)     NULL,
    rejection_reason                   NVARCHAR(1000)     NULL,
    CONSTRAINT PK_APPROVAL_DECISION PRIMARY KEY (approval_decision_id),
    -- Deliberately NOT UNIQUE: conceptual cardinality is
    -- BOOKING_REQUEST 0..* -- APPROVAL_DECISION 1..1 (accumulating decision history).
    CONSTRAINT FK_APPROVAL_DECISION_booking_request_id FOREIGN KEY (booking_request_id)
        REFERENCES dbo.BOOKING_REQUEST (booking_request_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_APPROVAL_DECISION_decided_by_user_account_id FOREIGN KEY (decided_by_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_APPROVAL_DECISION_decision_outcome_booking_status_id FOREIGN KEY (decision_outcome_booking_status_id)
        REFERENCES dbo.BOOKING_STATUS (booking_status_id) ON DELETE NO ACTION ON UPDATE NO ACTION
);
GO

-- PHASE 2: Approval decision maker role restriction (BR-12).
-- Tables/columns: APPROVAL_DECISION(decided_by_user_account_id),
-- USER_ACCOUNT(role_id), ROLE(role_name). A future trigger or stored
-- procedure must reject an INSERT on APPROVAL_DECISION unless the
-- referenced decided_by_user_account_id's role resolves to "facility
-- staff" or "facility manager".
--
-- PHASE 2: Rejected booking must have non-null rejection_reason (BR-14).
-- Tables/columns: APPROVAL_DECISION(decision_outcome_booking_status_id,
-- rejection_reason), BOOKING_REQUEST(status). A future trigger or
-- stored procedure must enforce: if decision_outcome_booking_status_id
-- resolves to "rejected" then rejection_reason IS NOT NULL and non-blank.
-- The logical design's named CK_APPROVAL_DECISION_rejection_reason
-- contains an unresolved <BOOKING_STATUS_ID_FOR_REJECTED> placeholder
-- (see design validation report L-01) and is intentionally NOT created in
-- Phase 1; it is deferred here in full per engineer agent Rule 7.
--
-- OPEN QUESTION (engineer agent Rule 4):
-- Must every approved or rejected booking have exactly one
-- APPROVAL_DECISION row? Not enforced; multiple or zero decision rows per
-- booking remain structurally possible.
--
-- OPEN QUESTION (logical design Section 6):
-- What criteria determine whether a booking request requires approval
-- (BR-12)? Affects approval workflow rules, not table structure.
--
-- OPEN QUESTION (logical design Section 6, [logical-stage]):
-- Should BOOKING_STATUS include a stable machine-readable status_code in
-- addition to status_name so APPROVAL_DECISION can enforce rejected =>
-- rejection_reason with a deterministic persisted-code pattern? Affects
-- the eventual Phase 2 implementation of BR-14; no status_code column is
-- added because it is not in the logical design.

-- ============================================================================
-- 12. USAGE_SESSION
-- ============================================================================
CREATE TABLE dbo.USAGE_SESSION (
    usage_session_id             INT IDENTITY(1,1) NOT NULL,
    booking_request_id           INT                NOT NULL,
    checked_in_by_user_account_id INT               NOT NULL,
    completed_by_user_account_id  INT               NULL,
    actual_start_time             DATETIME2(0)      NOT NULL,
    initial_condition_of_space    NVARCHAR(1000)    NOT NULL,
    actual_end_time                DATETIME2(0)      NULL,
    final_condition_of_space       NVARCHAR(1000)    NULL,
    usage_notes                    NVARCHAR(1000)    NULL,
    CONSTRAINT PK_USAGE_SESSION PRIMARY KEY (usage_session_id),
    CONSTRAINT FK_USAGE_SESSION_booking_request_id FOREIGN KEY (booking_request_id)
        REFERENCES dbo.BOOKING_REQUEST (booking_request_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_USAGE_SESSION_checked_in_by_user_account_id FOREIGN KEY (checked_in_by_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_USAGE_SESSION_completed_by_user_account_id FOREIGN KEY (completed_by_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT UQ_USAGE_SESSION_booking_request_id UNIQUE (booking_request_id),
    CONSTRAINT CK_USAGE_SESSION_actual_time_order CHECK (actual_end_time IS NULL OR actual_end_time > actual_start_time)
);
GO

-- PHASE 2: Check-in user role restriction (BR-15).
-- Tables/columns: USAGE_SESSION(checked_in_by_user_account_id),
-- USER_ACCOUNT(role_id). A future trigger or stored procedure must reject
-- an INSERT on USAGE_SESSION unless the referenced
-- checked_in_by_user_account_id's role resolves to "facility staff".
--
-- PHASE 2: Completion user role restriction (BR-16).
-- Tables/columns: USAGE_SESSION(completed_by_user_account_id),
-- USER_ACCOUNT(role_id). A future trigger or stored procedure must reject
-- an UPDATE that sets completed_by_user_account_id unless the referenced
-- user's role resolves to "facility staff".
--
-- PHASE 2: Completion consistency of usage-session fields (BR-16).
-- Table/columns: USAGE_SESSION(completed_by_user_account_id,
-- actual_end_time, final_condition_of_space). A future trigger or stored
-- procedure must enforce that completed_by_user_account_id,
-- actual_end_time, and final_condition_of_space are set together (all
-- NULL until completion, all NOT NULL once completed) rather than
-- independently.

-- ============================================================================
-- 13. MAINTENANCE_STATUS
-- ============================================================================
CREATE TABLE dbo.MAINTENANCE_STATUS (
    maintenance_status_id  INT IDENTITY(1,1) NOT NULL,
    status_name              NVARCHAR(80)      NOT NULL,
    CONSTRAINT PK_MAINTENANCE_STATUS PRIMARY KEY (maintenance_status_id),
    CONSTRAINT UQ_MAINTENANCE_STATUS_status_name UNIQUE (status_name)
);
GO

-- OPEN QUESTION (logical design Section 6 / engineer agent Rule 4):
-- What maintenance status values are allowed, and what are the valid
-- transitions between them? No CHECK constraint is added to
-- MAINTENANCE_STATUS.status_name until this is confirmed upstream.

-- ============================================================================
-- 14. MAINTENANCE_RECORD
-- ============================================================================
CREATE TABLE dbo.MAINTENANCE_RECORD (
    maintenance_record_id          INT IDENTITY(1,1) NOT NULL,
    space_id                       INT                NOT NULL,
    reported_by_user_account_id    INT                NOT NULL,
    assigned_to_user_account_id    INT                NULL,
    maintenance_status_id          INT                NOT NULL,
    problem_description             NVARCHAR(1000)     NOT NULL,
    start_time                      DATETIME2(0)       NOT NULL,
    completion_time                 DATETIME2(0)       NULL,
    result_note                     NVARCHAR(1000)     NULL,
    CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (maintenance_record_id),
    CONSTRAINT FK_MAINTENANCE_RECORD_space_id FOREIGN KEY (space_id)
        REFERENCES dbo.SPACE (space_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_MAINTENANCE_RECORD_reported_by_user_account_id FOREIGN KEY (reported_by_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_MAINTENANCE_RECORD_assigned_to_user_account_id FOREIGN KEY (assigned_to_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_MAINTENANCE_RECORD_maintenance_status_id FOREIGN KEY (maintenance_status_id)
        REFERENCES dbo.MAINTENANCE_STATUS (maintenance_status_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_MAINTENANCE_RECORD_time_order CHECK (completion_time IS NULL OR completion_time > start_time)
);
GO

-- OPEN QUESTION (logical design Section 6):
-- Does creating/opening a maintenance record automatically set
-- SPACE.current_status (space_status_id) to "Under maintenance", or is
-- space status updated independently? No synchronization logic is added.
--
-- OPEN QUESTION (logical design Section 6 / engineer agent Rule 4):
-- Which role is allowed to report a maintenance issue
-- (reported_by_user_account_id)? No role-restriction logic is added.
--
-- OPEN QUESTION (logical design Section 6 / engineer agent Rule 4):
-- Who assigns the assigned staff member (assigned_to_user_account_id) on a
-- maintenance record, and when is assignment required? No workflow logic
-- is added; the column remains optional per the logical design.

-- ============================================================================
-- End of Phase 1 DDL script.
-- ============================================================================