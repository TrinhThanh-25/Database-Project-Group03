/*
    Database Definition Implementation - Group 03
    Target DBMS: Microsoft SQL Server

    Authoritative inputs:
    - outputs/03-logical-design-G03.md
    - outputs/04-design-validation-G03.md

    Source discipline notes:
    - Implements only tables, columns, constraints, allowed values, implementation logic, indexes,
      and views documented in the logical design and validation report.
    - Does not add CHECK constraints for unresolved values such as USER_ACCOUNT.account_status
      or MAINTENANCE_RECORD.status.
    - Keeps APPROVAL_DECISION.booking_id non-unique to preserve decision/audit history as required
      by the logical design and validation report.
*/

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ============================================================
   1. Core master tables
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

CREATE TABLE dbo.FACILITY
(
    facility_id INT IDENTITY(1,1) NOT NULL,
    facility_name NVARCHAR(120) NOT NULL,

    CONSTRAINT PK_FACILITY PRIMARY KEY (facility_id)
);
GO

/* ============================================================
   2. Association table
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

/* ============================================================
   3. Booking, approval, usage, and maintenance history tables
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

CREATE TABLE dbo.APPROVAL_DECISION
(
    approval_decision_id INT IDENTITY(1,1) NOT NULL,
    booking_id INT NOT NULL,
    decision_maker_user_account_id INT NOT NULL,
    decision_outcome NVARCHAR(20) NOT NULL,
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
        ON UPDATE NO ACTION,
    CONSTRAINT CK_APPROVAL_DECISION_decision_outcome CHECK (decision_outcome IN ('Approved', 'Rejected')),
    CONSTRAINT CK_APPROVAL_DECISION_rejection_reason CHECK
    (
        decision_outcome <> 'Rejected'
        OR rejection_reason IS NOT NULL
    )
);
GO

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

/* ============================================================
   4. Indexes for foreign keys, joins, status/time filters, and views
   ============================================================ */

CREATE INDEX IX_SPACE_current_status
    ON dbo.SPACE (current_status);
GO

CREATE INDEX IX_SPACE_FACILITY_facility_id
    ON dbo.SPACE_FACILITY (facility_id);
GO

CREATE INDEX IX_BOOKING_REQUEST_requester_user_account_id
    ON dbo.BOOKING_REQUEST (requester_user_account_id);
GO

CREATE INDEX IX_BOOKING_REQUEST_space_status_time
    ON dbo.BOOKING_REQUEST (space_id, booking_status, requested_start_time, requested_end_time);
GO

CREATE INDEX IX_BOOKING_REQUEST_status_time
    ON dbo.BOOKING_REQUEST (booking_status, requested_start_time, requested_end_time);
GO

CREATE INDEX IX_APPROVAL_DECISION_booking_id
    ON dbo.APPROVAL_DECISION (booking_id);
GO

CREATE INDEX IX_APPROVAL_DECISION_decision_maker_user_account_id
    ON dbo.APPROVAL_DECISION (decision_maker_user_account_id);
GO

CREATE INDEX IX_USAGE_SESSION_checked_in_by_user_account_id
    ON dbo.USAGE_SESSION (checked_in_by_user_account_id);
GO

CREATE INDEX IX_USAGE_SESSION_completed_by_user_account_id
    ON dbo.USAGE_SESSION (completed_by_user_account_id);
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

CREATE INDEX IX_MAINTENANCE_RECORD_status_start_time
    ON dbo.MAINTENANCE_RECORD (status, start_time);
GO

/* ============================================================
   5. Triggers for validated cross-row and cross-table rules
   ============================================================ */

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

/* ============================================================
   6. Views supporting validated staff information needs (BR-25)
   ============================================================ */

CREATE VIEW dbo.VW_BOOKING_HISTORY
AS
SELECT
    br.booking_id,
    br.booking_status,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.expected_number_of_participants,
    ua.user_account_id AS requester_user_account_id,
    ua.user_id AS requester_user_id,
    ua.full_name AS requester_full_name,
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.current_status AS space_current_status
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id;
GO

CREATE VIEW dbo.VW_UPCOMING_BOOKINGS
AS
SELECT
    br.booking_id,
    br.booking_status,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    ua.user_id AS requester_user_id,
    ua.full_name AS requester_full_name,
    sp.unique_space_code,
    sp.space_name
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id
WHERE br.requested_start_time >= SYSDATETIME();
GO

CREATE VIEW dbo.VW_SPACES_UNDER_MAINTENANCE
AS
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.building,
    sp.floor,
    sp.room_number,
    sp.current_status
FROM dbo.SPACE AS sp
WHERE sp.current_status = 'Under maintenance';
GO

CREATE VIEW dbo.VW_NO_SHOW_BOOKINGS
AS
SELECT
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    ua.user_id AS requester_user_id,
    ua.full_name AS requester_full_name,
    sp.unique_space_code,
    sp.space_name
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id
WHERE br.booking_status = 'No-show';
GO
