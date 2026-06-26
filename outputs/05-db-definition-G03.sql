/*
    Database Definition Implementation - Group 03
    Target DBMS: Microsoft SQL Server

    Authoritative implementation inputs:
    - outputs/03-logical-design-G03.md
    - outputs/04-design-validation-G03.md

    [upstream] Assumptions carried forward from logical design:
    - Facility ID, Booking ID, Approval Decision ID, Usage Session ID, and Maintenance Record ID were proposed identifiers.
    - Decision note and rejection reason are distinct APPROVAL_DECISION facts.
    - Facility is treated as a reusable facility type/name across spaces.
    - Generic “staff” was not added as a separate actor; staff-view scope remains unresolved.
    - USER is implemented as USER_ACCOUNT.
    - Every table uses a surrogate INT IDENTITY primary key; user_id and unique_space_code are demoted unique business attributes.
    - USER_ACCOUNT.email is treated as a candidate key.
    - Source-optional note/descriptive fields remain nullable.
    - APPROVAL_DECISION.booking_id remains non-unique to preserve decision/audit history.

    [ddl-stage] Assumptions:
    - Surrogate primary key columns are implemented with SQL Server IDENTITY(1,1), as allowed by the implementation agent.
    - Nonclustered indexes are added only for foreign-key columns not already covered by a PK/UQ leading key, as recommended for FK join performance.
    - Trigger names are DDL-stage names because logical design requires implementation logic but does not prescribe trigger names.
    - The script uses a documented drop/recreate sequence for repeatable demo execution.
    - DDL-stage instruction Rule 7 supersedes the logical-design derived decision_outcome column: APPROVAL_DECISION.decision_outcome and its CHECK are not implemented; rejected-booking rejection_reason enforcement is stubbed with cross-table BOOKING_REQUEST.status logic instead.

    OPEN QUESTIONS CARRIED FORWARD:
    - What values are allowed for USER_ACCOUNT.account_status?
    - How is SPACE.usage_policy enforced, if at all?
    - Does creating/starting/completing/changing a MAINTENANCE_RECORD automatically change SPACE.current_status?
    - Which prior status, trigger, and actor cause BOOKING_REQUEST.booking_status to become Cancelled?
    - Which prior status, trigger, and actor cause BOOKING_REQUEST.booking_status to become No-show?
    - Which booking requests require approval, and can any booking bypass approval?
    - Should a booking have at most one APPROVAL_DECISION or preserve multiple approval/audit decisions?
    - What values and transitions are allowed for MAINTENANCE_RECORD.status?
    - Which user roles are allowed to report maintenance issues?
    - Which user roles are allowed to assign maintenance staff?
    - Does staff view access mean Facility Staff only or other staff roles too?
    - Should BOOKING_REQUEST.expected_number_of_participants be compared with SPACE.capacity?
    - What exact mechanism should enforce approved-booking overlap prevention?
    - What exact mechanism should enforce unavailable-space booking prevention?
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* Documented drop/recreate sequence for demo repeatability. */
DROP TRIGGER IF EXISTS dbo.TR_USAGE_SESSION_completion_consistency;
DROP TRIGGER IF EXISTS dbo.TR_USAGE_SESSION_validate_facility_staff_roles;
DROP TRIGGER IF EXISTS dbo.TR_APPROVAL_DECISION_require_rejection_reason;
DROP TRIGGER IF EXISTS dbo.TR_APPROVAL_DECISION_validate_decision_maker_role;
DROP TRIGGER IF EXISTS dbo.TR_BOOKING_REQUEST_prevent_approved_overlap;
DROP TRIGGER IF EXISTS dbo.TR_BOOKING_REQUEST_prevent_unavailable_space_booking;
GO

DROP TABLE IF EXISTS dbo.MAINTENANCE_RECORD;
DROP TABLE IF EXISTS dbo.USAGE_SESSION;
DROP TABLE IF EXISTS dbo.APPROVAL_DECISION;
DROP TABLE IF EXISTS dbo.BOOKING_REQUEST;
DROP TABLE IF EXISTS dbo.SPACE_FACILITY;
DROP TABLE IF EXISTS dbo.FACILITY;
DROP TABLE IF EXISTS dbo.SPACE;
DROP TABLE IF EXISTS dbo.USER_ACCOUNT;
GO

/* ============================================================
   1. USER_ACCOUNT
   ============================================================ */

CREATE TABLE dbo.USER_ACCOUNT
(
    user_account_id INT IDENTITY(1,1) NOT NULL,
    user_id NVARCHAR(50) NOT NULL,
    full_name NVARCHAR(200) NULL,
    email NVARCHAR(254) NOT NULL,
    phone_number NVARCHAR(30) NULL,
    role NVARCHAR(40) NOT NULL,
    department NVARCHAR(120) NULL,
    account_status NVARCHAR(50) NULL,

    CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY (user_account_id),
    CONSTRAINT UQ_USER_ACCOUNT_user_id UNIQUE (user_id),
    CONSTRAINT UQ_USER_ACCOUNT_email UNIQUE (email),
    CONSTRAINT CK_USER_ACCOUNT_role CHECK
    (
        role IN
        (
            'Student',
            'Lecturer',
            'Teaching Assistant',
            'Facility Staff',
            'Department Administrator',
            'Facility Manager'
        )
    )
);
GO

-- OPEN QUESTION: What values are allowed for USER_ACCOUNT.account_status?
-- No CHECK constraint is added because logical design §2.1 and §6 leave account_status values unresolved.
-- OPEN QUESTION: Does staff view access mean Facility Staff only, or does it include other staff roles?
-- No authorization table, view permission constraint, or role expansion is added in DDL.
GO

/* ============================================================
   2. SPACE
   ============================================================ */

CREATE TABLE dbo.SPACE
(
    space_id INT IDENTITY(1,1) NOT NULL,
    unique_space_code NVARCHAR(50) NOT NULL,
    space_name NVARCHAR(200) NULL,
    space_type NVARCHAR(80) NULL,
    building NVARCHAR(120) NULL,
    floor NVARCHAR(30) NULL,
    room_number NVARCHAR(30) NULL,
    capacity INT NULL,
    current_status NVARCHAR(40) NOT NULL,
    usage_policy NVARCHAR(1000) NULL,

    CONSTRAINT PK_SPACE PRIMARY KEY (space_id),
    CONSTRAINT UQ_SPACE_unique_space_code UNIQUE (unique_space_code),
    CONSTRAINT CK_SPACE_current_status CHECK
    (
        current_status IN
        (
            'Available',
            'In use',
            'Under maintenance',
            'Temporarily closed',
            'Retired'
        )
    ),
    CONSTRAINT CK_SPACE_capacity_nonnegative CHECK (capacity IS NULL OR capacity >= 0)
);
GO

-- OPEN QUESTION: How is SPACE.usage_policy enforced, if at all, during booking submission or approval?
-- No constraint is added because usage-policy enforcement remains unresolved in logical design §6.
-- OPEN QUESTION: Does creating/starting/completing/changing MAINTENANCE_RECORD automatically update SPACE.current_status?
-- No synchronization trigger is added because logical design §6 leaves this unresolved.
GO

/* ============================================================
   3. FACILITY
   ============================================================ */

CREATE TABLE dbo.FACILITY
(
    facility_id INT IDENTITY(1,1) NOT NULL,
    facility_name NVARCHAR(120) NOT NULL,

    CONSTRAINT PK_FACILITY PRIMARY KEY (facility_id)
);
GO

/* ============================================================
   4. SPACE_FACILITY
   ============================================================ */

CREATE TABLE dbo.SPACE_FACILITY
(
    space_facility_id INT IDENTITY(1,1) NOT NULL,
    space_id INT NOT NULL,
    facility_id INT NOT NULL,

    CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (space_facility_id),
    CONSTRAINT UQ_SPACE_FACILITY_space_id_facility_id UNIQUE (space_id, facility_id),
    CONSTRAINT FK_SPACE_FACILITY_space_id FOREIGN KEY (space_id)
        REFERENCES dbo.SPACE (space_id)
        ON DELETE CASCADE
        ON UPDATE NO ACTION,
    CONSTRAINT FK_SPACE_FACILITY_facility_id FOREIGN KEY (facility_id)
        REFERENCES dbo.FACILITY (facility_id)
        ON DELETE CASCADE
        ON UPDATE NO ACTION
);
GO

CREATE INDEX IX_SPACE_FACILITY_facility_id
    ON dbo.SPACE_FACILITY (facility_id);
GO

/* ============================================================
   5. BOOKING_REQUEST
   ============================================================ */

CREATE TABLE dbo.BOOKING_REQUEST
(
    booking_id INT IDENTITY(1,1) NOT NULL,
    requester_user_account_id INT NOT NULL,
    space_id INT NOT NULL,
    requested_start_time DATETIME2(0) NOT NULL,
    requested_end_time DATETIME2(0) NOT NULL,
    purpose_of_use NVARCHAR(40) NOT NULL,
    expected_number_of_participants INT NOT NULL,
    booking_status NVARCHAR(30) NOT NULL,

    CONSTRAINT PK_BOOKING_REQUEST PRIMARY KEY (booking_id),
    CONSTRAINT FK_BOOKING_REQUEST_requester_user_account_id FOREIGN KEY (requester_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FK_BOOKING_REQUEST_space_id FOREIGN KEY (space_id)
        REFERENCES dbo.SPACE (space_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT CK_BOOKING_REQUEST_requested_time_order CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CK_BOOKING_REQUEST_expected_participants_nonnegative CHECK (expected_number_of_participants >= 0),
    CONSTRAINT CK_BOOKING_REQUEST_purpose_of_use CHECK
    (
        purpose_of_use IN
        (
            'Lecture',
            'Examination',
            'Seminar',
            'Workshop',
            'Meeting',
            'Student activity',
            'Administrative event'
        )
    ),
    CONSTRAINT CK_BOOKING_REQUEST_booking_status CHECK
    (
        booking_status IN
        (
            'Pending',
            'Approved',
            'Rejected',
            'Cancelled',
            'Checked in',
            'Completed',
            'No-show'
        )
    )
);
GO

CREATE INDEX IX_BOOKING_REQUEST_requester_user_account_id
    ON dbo.BOOKING_REQUEST (requester_user_account_id);
GO

CREATE INDEX IX_BOOKING_REQUEST_space_id
    ON dbo.BOOKING_REQUEST (space_id);
GO

CREATE TRIGGER dbo.TR_BOOKING_REQUEST_prevent_unavailable_space_booking
ON dbo.BOOKING_REQUEST
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.SPACE AS s
            ON s.space_id = i.space_id
        WHERE s.current_status IN ('Under maintenance', 'Temporarily closed', 'Retired')
    )
    BEGIN
        THROW 51001, 'A space that is under maintenance, temporarily closed, or retired cannot be booked.', 1;
    END;
END;
GO

CREATE TRIGGER dbo.TR_BOOKING_REQUEST_prevent_approved_overlap
ON dbo.BOOKING_REQUEST
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.BOOKING_REQUEST AS b
            ON b.space_id = i.space_id
           AND b.booking_id <> i.booking_id
           AND b.booking_status = 'Approved'
           AND i.booking_status = 'Approved'
           AND b.requested_start_time < i.requested_end_time
           AND i.requested_start_time < b.requested_end_time
    )
    BEGIN
        THROW 51002, 'The same space cannot have two approved bookings with overlapping time periods.', 1;
    END;
END;
GO

-- OPEN QUESTION: Which prior status, trigger, and actor cause BOOKING_REQUEST.booking_status to become Cancelled?
-- OPEN QUESTION: Which prior status, trigger, and actor cause BOOKING_REQUEST.booking_status to become No-show?
-- No lifecycle transition trigger is added because logical design §6 leaves these unresolved.
-- OPEN QUESTION: Which booking requests require approval, and can any booking bypass approval?
-- No required-approval trigger is added because logical design §6 leaves this unresolved.
-- OPEN QUESTION: Should BOOKING_REQUEST.expected_number_of_participants be compared with SPACE.capacity?
-- No cross-table capacity trigger is added; only CK_BOOKING_REQUEST_expected_participants_nonnegative is implemented.
GO

/* ============================================================
   6. APPROVAL_DECISION
   ============================================================ */

CREATE TABLE dbo.APPROVAL_DECISION
(
    approval_decision_id INT IDENTITY(1,1) NOT NULL,
    booking_id INT NOT NULL,
    decision_maker_user_account_id INT NOT NULL,
    decision_time DATETIME2(0) NOT NULL,
    decision_note NVARCHAR(1000) NULL,
    rejection_reason NVARCHAR(1000) NULL,

    CONSTRAINT PK_APPROVAL_DECISION PRIMARY KEY (approval_decision_id),
    CONSTRAINT FK_APPROVAL_DECISION_booking_id FOREIGN KEY (booking_id)
        REFERENCES dbo.BOOKING_REQUEST (booking_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FK_APPROVAL_DECISION_decision_maker_user_account_id FOREIGN KEY (decision_maker_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION
);
GO

CREATE INDEX IX_APPROVAL_DECISION_booking_id
    ON dbo.APPROVAL_DECISION (booking_id);
GO

CREATE INDEX IX_APPROVAL_DECISION_decision_maker_user_account_id
    ON dbo.APPROVAL_DECISION (decision_maker_user_account_id);
GO

CREATE TRIGGER dbo.TR_APPROVAL_DECISION_validate_decision_maker_role
ON dbo.APPROVAL_DECISION
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.USER_ACCOUNT AS u
            ON u.user_account_id = i.decision_maker_user_account_id
        WHERE u.role NOT IN ('Facility Staff', 'Facility Manager')
    )
    BEGIN
        THROW 51003, 'Approval decisions must be made by a Facility Staff user or Facility Manager user.', 1;
    END;
END;
GO

CREATE TRIGGER dbo.TR_APPROVAL_DECISION_require_rejection_reason
ON dbo.APPROVAL_DECISION
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- IMPLEMENTATION REQUIRED / STUB for BR-13 / BR-16 under DDL-stage Rule 7:
    -- Check: if related BOOKING_REQUEST.booking_status = 'Rejected',
    --        then APPROVAL_DECISION.rejection_reason must be NOT NULL.
    -- This enforces the rule without adding an APPROVAL_DECISION.decision_outcome column.
    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.BOOKING_REQUEST AS br
            ON br.booking_id = i.booking_id
        WHERE br.booking_status = 'Rejected'
          AND i.rejection_reason IS NULL
    )
    BEGIN
        THROW 51007, 'A rejected booking must have a non-null approval rejection reason.', 1;
    END;
END;
GO

-- OPEN QUESTION: The logical design carried a derived APPROVAL_DECISION.decision_outcome column, but DDL-stage Rule 7 identifies a decision-outcome gap and requires rejection status to be inferred from BOOKING_REQUEST.booking_status.
-- Therefore no decision_outcome column is added and no CK_APPROVAL_DECISION_decision_outcome / CK_APPROVAL_DECISION_rejection_reason CHECK can be implemented as an in-row CHECK in this script.
-- OPEN QUESTION: Should a booking have at most one APPROVAL_DECISION or preserve multiple approval/audit decisions?
-- APPROVAL_DECISION.booking_id is intentionally not UNIQUE, as required by logical design and validation report.
GO

/* ============================================================
   7. USAGE_SESSION
   ============================================================ */

CREATE TABLE dbo.USAGE_SESSION
(
    usage_session_id INT IDENTITY(1,1) NOT NULL,
    booking_id INT NOT NULL,
    checked_in_by_user_account_id INT NOT NULL,
    completed_by_user_account_id INT NULL,
    actual_start_time DATETIME2(0) NOT NULL,
    initial_condition_of_space NVARCHAR(1000) NULL,
    actual_end_time DATETIME2(0) NULL,
    final_condition_of_space NVARCHAR(1000) NULL,
    usage_notes NVARCHAR(1000) NULL,

    CONSTRAINT PK_USAGE_SESSION PRIMARY KEY (usage_session_id),
    CONSTRAINT UQ_USAGE_SESSION_booking_id UNIQUE (booking_id),
    CONSTRAINT FK_USAGE_SESSION_booking_id FOREIGN KEY (booking_id)
        REFERENCES dbo.BOOKING_REQUEST (booking_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FK_USAGE_SESSION_checked_in_by_user_account_id FOREIGN KEY (checked_in_by_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FK_USAGE_SESSION_completed_by_user_account_id FOREIGN KEY (completed_by_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT CK_USAGE_SESSION_actual_time_order CHECK
    (
        actual_end_time IS NULL
        OR actual_end_time > actual_start_time
    )
);
GO

CREATE INDEX IX_USAGE_SESSION_checked_in_by_user_account_id
    ON dbo.USAGE_SESSION (checked_in_by_user_account_id);
GO

CREATE INDEX IX_USAGE_SESSION_completed_by_user_account_id
    ON dbo.USAGE_SESSION (completed_by_user_account_id);
GO

CREATE TRIGGER dbo.TR_USAGE_SESSION_validate_facility_staff_roles
ON dbo.USAGE_SESSION
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.USER_ACCOUNT AS u
            ON u.user_account_id = i.checked_in_by_user_account_id
        WHERE u.role <> 'Facility Staff'
    )
    BEGIN
        THROW 51004, 'A booking check-in must be recorded by a Facility Staff user.', 1;
    END;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.USER_ACCOUNT AS u
            ON u.user_account_id = i.completed_by_user_account_id
        WHERE i.completed_by_user_account_id IS NOT NULL
          AND u.role <> 'Facility Staff'
    )
    BEGIN
        THROW 51005, 'A booking completion must be recorded by a Facility Staff user.', 1;
    END;
END;
GO

CREATE TRIGGER dbo.TR_USAGE_SESSION_completion_consistency
ON dbo.USAGE_SESSION
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS i
        WHERE
            (
                i.completed_by_user_account_id IS NOT NULL
                OR i.actual_end_time IS NOT NULL
                OR i.final_condition_of_space IS NOT NULL
            )
            AND NOT
            (
                i.completed_by_user_account_id IS NOT NULL
                AND i.actual_end_time IS NOT NULL
                AND i.final_condition_of_space IS NOT NULL
            )
    )
    BEGIN
        THROW 51006, 'Completion fields completed_by_user_account_id, actual_end_time, and final_condition_of_space must be populated together.', 1;
    END;
END;
GO

/* ============================================================
   8. MAINTENANCE_RECORD
   ============================================================ */

CREATE TABLE dbo.MAINTENANCE_RECORD
(
    maintenance_record_id INT IDENTITY(1,1) NOT NULL,
    space_id INT NOT NULL,
    reporter_user_account_id INT NOT NULL,
    assigned_staff_user_account_id INT NOT NULL,
    problem_description NVARCHAR(1000) NOT NULL,
    start_time DATETIME2(0) NOT NULL,
    completion_time DATETIME2(0) NULL,
    status NVARCHAR(50) NULL,
    result_note NVARCHAR(1000) NULL,

    CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (maintenance_record_id),
    CONSTRAINT FK_MAINTENANCE_RECORD_space_id FOREIGN KEY (space_id)
        REFERENCES dbo.SPACE (space_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FK_MAINTENANCE_RECORD_reporter_user_account_id FOREIGN KEY (reporter_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT FK_MAINTENANCE_RECORD_assigned_staff_user_account_id FOREIGN KEY (assigned_staff_user_account_id)
        REFERENCES dbo.USER_ACCOUNT (user_account_id)
        ON DELETE NO ACTION
        ON UPDATE NO ACTION,
    CONSTRAINT CK_MAINTENANCE_RECORD_time_order CHECK
    (
        completion_time IS NULL
        OR completion_time > start_time
    )
);
GO

CREATE INDEX IX_MAINTENANCE_RECORD_space_id
    ON dbo.MAINTENANCE_RECORD (space_id);
GO

CREATE INDEX IX_MAINTENANCE_RECORD_reporter_user_account_id
    ON dbo.MAINTENANCE_RECORD (reporter_user_account_id);
GO

CREATE INDEX IX_MAINTENANCE_RECORD_assigned_staff_user_account_id
    ON dbo.MAINTENANCE_RECORD (assigned_staff_user_account_id);
GO

-- OPEN QUESTION: What are the allowed status values and lifecycle transitions for MAINTENANCE_RECORD.status?
-- No CHECK constraint is added because logical design §6 leaves maintenance status values unresolved.
-- OPEN QUESTION: Which user roles are allowed to report maintenance issues?
-- OPEN QUESTION: Which user roles are allowed to assign maintenance staff?
-- No role-restriction trigger is added for maintenance reporter/assignee because logical design §6 leaves these unresolved.
-- OPEN QUESTION: Does creating/starting/completing/changing MAINTENANCE_RECORD automatically change related SPACE.current_status?
-- No synchronization trigger is added because logical design §6 leaves this unresolved.
GO

-- OPEN QUESTION: BR-25 requires staff to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings, but logical design §4 says view implementation and authorization scope are deferred.
-- No view is created because no view name or definition is specified in the logical design or validation report.
GO
