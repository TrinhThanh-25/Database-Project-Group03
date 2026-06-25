/*
Database Definition Implementation - Group 03
Target DBMS: Microsoft SQL Server

Authoritative implementation inputs:
- outputs/03-logical-design-G03.md
- outputs/04-design-validation-G03.md

Path note:
- The command requested `.opencode/agent/database-implementation-engineer.md`,
  but the repository agent file available for this stage is
  `.opencode/agent/database-definition-implementation-engineer.md`.

Implementation scope discipline:
- Tables, columns, keys, CHECK constraints, allowed values, triggers, and views
  are based on the logical design and validation report.
- Unresolved rules from the logical design are not converted into unsupported
  constraints. Maintenance status values, account status values, requester
  eligibility, requested equipment, usage-policy validation, approval-required
  workflow, no-show/cancellation transitions, and participant-capacity checks
  remain outside this DDL because the reviewed design leaves them unresolved.
*/

/* ============================================================
   Safety: drop views, triggers, and tables in dependency order
   ============================================================ */

IF OBJECT_ID(N'dbo.VW_UPCOMING_BOOKINGS', N'V') IS NOT NULL DROP VIEW dbo.VW_UPCOMING_BOOKINGS;
GO
IF OBJECT_ID(N'dbo.VW_NO_SHOW_BOOKINGS', N'V') IS NOT NULL DROP VIEW dbo.VW_NO_SHOW_BOOKINGS;
GO
IF OBJECT_ID(N'dbo.VW_SPACES_UNDER_MAINTENANCE', N'V') IS NOT NULL DROP VIEW dbo.VW_SPACES_UNDER_MAINTENANCE;
GO
IF OBJECT_ID(N'dbo.VW_BOOKING_HISTORY', N'V') IS NOT NULL DROP VIEW dbo.VW_BOOKING_HISTORY;
GO

IF OBJECT_ID(N'dbo.TRG_USAGE_SESSION_VALIDATE', N'TR') IS NOT NULL DROP TRIGGER dbo.TRG_USAGE_SESSION_VALIDATE;
GO
IF OBJECT_ID(N'dbo.TRG_APPROVAL_DECISION_VALIDATE', N'TR') IS NOT NULL DROP TRIGGER dbo.TRG_APPROVAL_DECISION_VALIDATE;
GO
IF OBJECT_ID(N'dbo.TRG_BOOKING_REQUEST_VALIDATE', N'TR') IS NOT NULL DROP TRIGGER dbo.TRG_BOOKING_REQUEST_VALIDATE;
GO

IF OBJECT_ID(N'dbo.SPACE_FACILITY', N'U') IS NOT NULL DROP TABLE dbo.SPACE_FACILITY;
IF OBJECT_ID(N'dbo.USAGE_SESSION', N'U') IS NOT NULL DROP TABLE dbo.USAGE_SESSION;
IF OBJECT_ID(N'dbo.APPROVAL_DECISION', N'U') IS NOT NULL DROP TABLE dbo.APPROVAL_DECISION;
IF OBJECT_ID(N'dbo.MAINTENANCE_RECORD', N'U') IS NOT NULL DROP TABLE dbo.MAINTENANCE_RECORD;
IF OBJECT_ID(N'dbo.BOOKING_REQUEST', N'U') IS NOT NULL DROP TABLE dbo.BOOKING_REQUEST;
IF OBJECT_ID(N'dbo.FACILITY', N'U') IS NOT NULL DROP TABLE dbo.FACILITY;
IF OBJECT_ID(N'dbo.SPACE', N'U') IS NOT NULL DROP TABLE dbo.SPACE;
IF OBJECT_ID(N'dbo.USER_ACCOUNT', N'U') IS NOT NULL DROP TABLE dbo.USER_ACCOUNT;
GO

/* ============================================================
   Core tables and constraints
   ============================================================ */

CREATE TABLE dbo.USER_ACCOUNT (
    user_id INT NOT NULL,
    full_name NVARCHAR(200) NOT NULL,
    email NVARCHAR(254) NOT NULL,
    phone_number NVARCHAR(30) NULL,
    role NVARCHAR(50) NOT NULL,
    department NVARCHAR(100) NULL,
    account_status NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY (user_id),
    CONSTRAINT CK_USER_ACCOUNT_role CHECK (
        role IN (
            N'Student',
            N'Lecturer',
            N'Teaching Assistant',
            N'Facility Staff',
            N'Department Administrator',
            N'Facility Manager'
        )
    )
);
GO

CREATE TABLE dbo.SPACE (
    unique_space_code NVARCHAR(50) NOT NULL,
    space_name NVARCHAR(200) NOT NULL,
    space_type NVARCHAR(50) NOT NULL,
    building NVARCHAR(100) NOT NULL,
    floor NVARCHAR(20) NOT NULL,
    room_number NVARCHAR(30) NOT NULL,
    capacity INT NOT NULL,
    current_status NVARCHAR(50) NOT NULL,
    usage_policy NVARCHAR(MAX) NULL,
    CONSTRAINT PK_SPACE PRIMARY KEY (unique_space_code),
    CONSTRAINT CK_SPACE_capacity_positive CHECK (capacity > 0),
    CONSTRAINT CK_SPACE_current_status CHECK (
        current_status IN (
            N'Available',
            N'In use',
            N'Under maintenance',
            N'Temporarily closed',
            N'Retired'
        )
    )
);
GO

CREATE TABLE dbo.FACILITY (
    facility_id INT NOT NULL,
    facility_name NVARCHAR(100) NOT NULL,
    CONSTRAINT PK_FACILITY PRIMARY KEY (facility_id)
);
GO

CREATE TABLE dbo.BOOKING_REQUEST (
    booking_id INT NOT NULL,
    requester_user_id INT NOT NULL,
    unique_space_code NVARCHAR(50) NOT NULL,
    requested_start_time DATETIME2(0) NOT NULL,
    requested_end_time DATETIME2(0) NOT NULL,
    purpose_of_use NVARCHAR(500) NOT NULL,
    expected_number_of_participants INT NOT NULL,
    booking_type NVARCHAR(50) NOT NULL,
    status NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_BOOKING_REQUEST PRIMARY KEY (booking_id),
    CONSTRAINT FK_BOOKING_REQUEST_REQUESTER FOREIGN KEY (requester_user_id)
        REFERENCES dbo.USER_ACCOUNT(user_id),
    CONSTRAINT FK_BOOKING_REQUEST_SPACE FOREIGN KEY (unique_space_code)
        REFERENCES dbo.SPACE(unique_space_code),
    CONSTRAINT CK_BOOKING_REQUEST_time_order CHECK (requested_end_time > requested_start_time),
    CONSTRAINT CK_BOOKING_REQUEST_expected_participants_positive CHECK (expected_number_of_participants > 0),
    CONSTRAINT CK_BOOKING_REQUEST_booking_type CHECK (
        booking_type IN (
            N'Lecture',
            N'Examination',
            N'Seminar',
            N'Workshop',
            N'Meeting',
            N'Student activity',
            N'Administrative event'
        )
    ),
    CONSTRAINT CK_BOOKING_REQUEST_status CHECK (
        status IN (
            N'Pending',
            N'Approved',
            N'Rejected',
            N'Cancelled',
            N'Checked in',
            N'Completed',
            N'No-show'
        )
    )
);
GO

CREATE TABLE dbo.SPACE_FACILITY (
    unique_space_code NVARCHAR(50) NOT NULL,
    facility_id INT NOT NULL,
    CONSTRAINT PK_SPACE_FACILITY PRIMARY KEY (unique_space_code, facility_id),
    CONSTRAINT FK_SPACE_FACILITY_SPACE FOREIGN KEY (unique_space_code)
        REFERENCES dbo.SPACE(unique_space_code),
    CONSTRAINT FK_SPACE_FACILITY_FACILITY FOREIGN KEY (facility_id)
        REFERENCES dbo.FACILITY(facility_id)
);
GO

CREATE TABLE dbo.APPROVAL_DECISION (
    approval_decision_id INT NOT NULL,
    booking_id INT NOT NULL,
    decision_maker_user_id INT NOT NULL,
    decision_time DATETIME2(0) NOT NULL,
    decision_note NVARCHAR(MAX) NOT NULL,
    rejection_reason NVARCHAR(MAX) NULL,
    CONSTRAINT PK_APPROVAL_DECISION PRIMARY KEY (approval_decision_id),
    CONSTRAINT FK_APPROVAL_DECISION_BOOKING FOREIGN KEY (booking_id)
        REFERENCES dbo.BOOKING_REQUEST(booking_id),
    CONSTRAINT FK_APPROVAL_DECISION_DECISION_MAKER FOREIGN KEY (decision_maker_user_id)
        REFERENCES dbo.USER_ACCOUNT(user_id),
    CONSTRAINT UQ_APPROVAL_DECISION_booking_id UNIQUE (booking_id)
);
GO

CREATE TABLE dbo.USAGE_SESSION (
    usage_session_id INT NOT NULL,
    booking_id INT NOT NULL,
    checked_in_by_user_id INT NOT NULL,
    completed_by_user_id INT NULL,
    actual_start_time DATETIME2(0) NOT NULL,
    initial_condition_of_the_space NVARCHAR(MAX) NOT NULL,
    actual_end_time DATETIME2(0) NULL,
    final_condition_of_the_space NVARCHAR(MAX) NULL,
    usage_notes NVARCHAR(MAX) NULL,
    CONSTRAINT PK_USAGE_SESSION PRIMARY KEY (usage_session_id),
    CONSTRAINT FK_USAGE_SESSION_BOOKING FOREIGN KEY (booking_id)
        REFERENCES dbo.BOOKING_REQUEST(booking_id),
    CONSTRAINT FK_USAGE_SESSION_CHECKED_IN_BY FOREIGN KEY (checked_in_by_user_id)
        REFERENCES dbo.USER_ACCOUNT(user_id),
    CONSTRAINT FK_USAGE_SESSION_COMPLETED_BY FOREIGN KEY (completed_by_user_id)
        REFERENCES dbo.USER_ACCOUNT(user_id),
    CONSTRAINT UQ_USAGE_SESSION_booking_id UNIQUE (booking_id)
);
GO

CREATE TABLE dbo.MAINTENANCE_RECORD (
    maintenance_record_id INT NOT NULL,
    unique_space_code NVARCHAR(50) NOT NULL,
    reported_by_user_id INT NOT NULL,
    assigned_to_user_id INT NOT NULL,
    problem_description NVARCHAR(MAX) NOT NULL,
    start_time DATETIME2(0) NOT NULL,
    completion_time DATETIME2(0) NULL,
    status NVARCHAR(50) NOT NULL,
    result_note NVARCHAR(MAX) NULL,
    CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (maintenance_record_id),
    CONSTRAINT FK_MAINTENANCE_RECORD_SPACE FOREIGN KEY (unique_space_code)
        REFERENCES dbo.SPACE(unique_space_code),
    CONSTRAINT FK_MAINTENANCE_RECORD_REPORTED_BY FOREIGN KEY (reported_by_user_id)
        REFERENCES dbo.USER_ACCOUNT(user_id),
    CONSTRAINT FK_MAINTENANCE_RECORD_ASSIGNED_TO FOREIGN KEY (assigned_to_user_id)
        REFERENCES dbo.USER_ACCOUNT(user_id)
);
GO

/* ============================================================
   Indexes for foreign keys, joins, and implementation checks
   ============================================================ */

CREATE INDEX IX_BOOKING_REQUEST_requester_user_id
    ON dbo.BOOKING_REQUEST(requester_user_id);
GO
CREATE INDEX IX_BOOKING_REQUEST_unique_space_code
    ON dbo.BOOKING_REQUEST(unique_space_code);
GO
CREATE INDEX IX_BOOKING_REQUEST_space_status_time
    ON dbo.BOOKING_REQUEST(unique_space_code, status, requested_start_time, requested_end_time);
GO
CREATE INDEX IX_SPACE_FACILITY_facility_id
    ON dbo.SPACE_FACILITY(facility_id);
GO
CREATE INDEX IX_APPROVAL_DECISION_decision_maker_user_id
    ON dbo.APPROVAL_DECISION(decision_maker_user_id);
GO
CREATE INDEX IX_USAGE_SESSION_checked_in_by_user_id
    ON dbo.USAGE_SESSION(checked_in_by_user_id);
GO
CREATE INDEX IX_USAGE_SESSION_completed_by_user_id
    ON dbo.USAGE_SESSION(completed_by_user_id)
    WHERE completed_by_user_id IS NOT NULL;
GO
CREATE INDEX IX_MAINTENANCE_RECORD_unique_space_code
    ON dbo.MAINTENANCE_RECORD(unique_space_code);
GO
CREATE INDEX IX_MAINTENANCE_RECORD_reported_by_user_id
    ON dbo.MAINTENANCE_RECORD(reported_by_user_id);
GO
CREATE INDEX IX_MAINTENANCE_RECORD_assigned_to_user_id
    ON dbo.MAINTENANCE_RECORD(assigned_to_user_id);
GO

/* ============================================================
   Triggers for validated implementation conditions
   ============================================================ */

/*
Enforces validated booking conditions:
- A booking cannot be created/updated for a space whose current status is
  Under maintenance, Temporarily closed, or Retired.
- Approved bookings for the same space must not overlap in requested time.

Notes:
- Participant count versus capacity is unresolved in the logical design and is
  intentionally not enforced here.
- Cancelled/no-show and complete status transitions are unresolved and are
  intentionally not enforced here.
*/
CREATE TRIGGER dbo.TRG_BOOKING_REQUEST_VALIDATE
ON dbo.BOOKING_REQUEST
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.SPACE AS s
            ON s.unique_space_code = i.unique_space_code
        WHERE s.current_status IN (N'Under maintenance', N'Temporarily closed', N'Retired')
    )
    BEGIN
        THROW 50001, 'Booking request cannot reference a space that is under maintenance, temporarily closed, or retired.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.BOOKING_REQUEST AS b WITH (UPDLOCK, HOLDLOCK)
            ON b.unique_space_code = i.unique_space_code
           AND b.booking_id <> i.booking_id
           AND b.status = N'Approved'
           AND i.status = N'Approved'
           AND b.requested_start_time < i.requested_end_time
           AND i.requested_start_time < b.requested_end_time
    )
    BEGIN
        THROW 50002, 'Approved bookings for the same space cannot have overlapping requested time periods.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.APPROVAL_DECISION AS ad
            ON ad.booking_id = i.booking_id
        WHERE i.status = N'Rejected'
          AND NULLIF(LTRIM(RTRIM(ad.rejection_reason)), N'') IS NULL
    )
    BEGIN
        THROW 50008, 'Rejected bookings with an approval decision must store a rejection reason.', 1;
    END;
END;
GO

/*
Enforces validated approval-decision conditions:
- Decision maker must be Facility Staff or Facility Manager.
- If the related booking is Rejected, rejection_reason must be present.

The open question about whether every approved/rejected booking must have an
approval decision remains unresolved and is intentionally not enforced here.
*/
CREATE TRIGGER dbo.TRG_APPROVAL_DECISION_VALIDATE
ON dbo.APPROVAL_DECISION
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.USER_ACCOUNT AS u
            ON u.user_id = i.decision_maker_user_id
        WHERE u.role NOT IN (N'Facility Staff', N'Facility Manager')
    )
    BEGIN
        THROW 50003, 'Approval decision maker must have role Facility Staff or Facility Manager.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.BOOKING_REQUEST AS b
            ON b.booking_id = i.booking_id
        WHERE b.status = N'Rejected'
          AND NULLIF(LTRIM(RTRIM(i.rejection_reason)), N'') IS NULL
    )
    BEGIN
        THROW 50004, 'Rejected bookings with an approval decision must store a rejection reason.', 1;
    END;
END;
GO

/*
Enforces validated usage-session conditions:
- Check-in user must be Facility Staff.
- Completion user, when present, must be Facility Staff.
- Completion-specific fields must be present when completed_by_user_id is present.
*/
CREATE TRIGGER dbo.TRG_USAGE_SESSION_VALIDATE
ON dbo.USAGE_SESSION
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.USER_ACCOUNT AS u
            ON u.user_id = i.checked_in_by_user_id
        WHERE u.role <> N'Facility Staff'
    )
    BEGIN
        THROW 50005, 'Usage-session check-in user must have role Facility Staff.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        INNER JOIN dbo.USER_ACCOUNT AS u
            ON u.user_id = i.completed_by_user_id
        WHERE i.completed_by_user_id IS NOT NULL
          AND u.role <> N'Facility Staff'
    )
    BEGIN
        THROW 50006, 'Usage-session completion user must have role Facility Staff.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM inserted AS i
        WHERE i.completed_by_user_id IS NOT NULL
          AND (
              i.actual_end_time IS NULL
              OR NULLIF(LTRIM(RTRIM(i.final_condition_of_the_space)), N'') IS NULL
          )
    )
    BEGIN
        THROW 50007, 'Completed usage sessions must store actual end time and final condition of the space.', 1;
    END;
END;
GO

/* ============================================================
   Views supporting validated staff information needs
   ============================================================ */

CREATE VIEW dbo.VW_BOOKING_HISTORY
AS
SELECT
    br.booking_id,
    br.requester_user_id,
    br.unique_space_code,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.expected_number_of_participants,
    br.booking_type,
    br.status
FROM dbo.BOOKING_REQUEST AS br;
GO

CREATE VIEW dbo.VW_UPCOMING_BOOKINGS
AS
SELECT
    booking_id,
    requester_user_id,
    unique_space_code,
    requested_start_time,
    requested_end_time,
    purpose_of_use,
    expected_number_of_participants,
    booking_type,
    status
FROM dbo.BOOKING_REQUEST
WHERE requested_start_time >= SYSDATETIME();
GO

CREATE VIEW dbo.VW_SPACES_UNDER_MAINTENANCE
AS
SELECT
    unique_space_code,
    space_name,
    space_type,
    building,
    floor,
    room_number,
    capacity,
    current_status,
    usage_policy
FROM dbo.SPACE
WHERE current_status = N'Under maintenance';
GO

CREATE VIEW dbo.VW_NO_SHOW_BOOKINGS
AS
SELECT
    booking_id,
    requester_user_id,
    unique_space_code,
    requested_start_time,
    requested_end_time,
    purpose_of_use,
    expected_number_of_participants,
    booking_type,
    status
FROM dbo.BOOKING_REQUEST
WHERE status = N'No-show';
GO
