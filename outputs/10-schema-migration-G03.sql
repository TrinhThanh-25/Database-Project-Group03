/*
================================================================================
 Phase 2 Schema Migration - Group 03
 Microsoft SQL Server additive migration from Phase 1 to Phase 2
================================================================================

 Authoritative inputs:
   - AGENTS.md
   - outputs/09-updated-erd-and-logical-design-G03.md
   - outputs/05-db-definition-G03.sql
   - outputs/06-sample-data-G03.sql
   - outputs/04-design-validation-G03.md

 Target version:
   - Phase 1 schema plus Phase 2 design from artifact 09.

 Migration safety:
   - This script is additive and data-preserving.
   - It does not copy the Phase 1 DROP/recreate block.
   - It does not implement concurrency procedures, analytical SQL, generated
     data, or performance indexes; later Phase 2 artifacts own those.
   - It stops with an "already migrated" result if the full target shape is
     detected, and fails on partial Phase 2 schema to avoid guessing recovery.
   - SET XACT_ABORT ON and TRY/CATCH wrap all mutating migration work.

 Legacy maintenance backfill:
   - Source rows affected: every existing row in dbo.MAINTENANCE_RECORD.
   - Mapping: current impact level is backfilled to out_of_service
     [proposed — not stated in source; inferred from artifact 09, because Phase 1 treated all
     maintenance as blocking and Phase 2 says out-of-service works exactly
     as in Phase 1].
   - Completed and open maintenance records receive the same current impact
     mapping because Phase 1 did not store impact level.
   - Unknown historical impact changes are not fabricated. The migration
     inserts one MAINTENANCE_IMPACT_EVENT per legacy maintenance row as a
     "migration baseline current-state import", with old_impact_level_id NULL
     and new_impact_level_id = out_of_service.
   - Post-backfill validation checks that every maintenance record has a
     current impact and every legacy maintenance row has one baseline event.

 Open questions preserved:
   - Which space types are selected for instant approval?
   - What executable predicate determines that a request satisfies
     SPACE.usage_policy?
   - What maintenance status values mean active/still open?
   - Do checked-in and completed bookings count as approved bookings for
     reports?
   - What are the authoritative semester calendars?
   - Does opening maintenance automatically change SPACE.space_status_id?

 Rollback/recovery guidance:
   - If this script fails before COMMIT, TRY/CATCH rolls back the transaction.
   - If it commits successfully, rollback requires a reviewed forward
     migration or restoring from a database backup. This script intentionally
     does not drop Phase 2 objects after commit.
================================================================================
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @HasAllPhase2 BIT = 0;
DECLARE @HasAnyPhase2 BIT = 0;

IF OBJECT_ID(N'dbo.APPROVAL_METHOD', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_LEVEL', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_EVENT', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.INSTANT_APPROVAL_SPACE_TYPE', N'U') IS NOT NULL
   AND OBJECT_ID(N'dbo.ACADEMIC_SEMESTER', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.BOOKING_STATUS', N'status_code') IS NOT NULL
   AND COL_LENGTH(N'dbo.APPROVAL_DECISION', N'decision_method_id') IS NOT NULL
   AND COL_LENGTH(N'dbo.MAINTENANCE_RECORD', N'impact_level_id') IS NOT NULL
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_BOOKING_STATUS_status_code' AND type = N'UQ')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_APPROVAL_DECISION_decision_method_id' AND type = N'F')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'FK_MAINTENANCE_RECORD_impact_level_id' AND type = N'F')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_APPROVAL_METHOD' AND type = N'PK')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_APPROVAL_METHOD_method_code' AND type = N'UQ')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_MAINTENANCE_IMPACT_LEVEL' AND type = N'PK')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_MAINTENANCE_IMPACT_LEVEL_impact_level_code' AND type = N'UQ')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_MAINTENANCE_IMPACT_EVENT' AND type = N'PK')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_MAINTENANCE_IMPACT_EVENT_distinct_levels' AND type = N'C')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_BOOKING_ADVISORY_ACKNOWLEDGEMENT' AND type = N'PK')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'UQ_BOOKING_ADVISORY_ACKNOWLEDGEMENT_booking_maintenance' AND type = N'UQ')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_INSTANT_APPROVAL_SPACE_TYPE' AND type = N'PK')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'PK_ACADEMIC_SEMESTER' AND type = N'PK')
   AND EXISTS (SELECT 1 FROM sys.objects WHERE name = N'CK_ACADEMIC_SEMESTER_date_order' AND type = N'C')
BEGIN
    SET @HasAllPhase2 = 1;
END;

IF OBJECT_ID(N'dbo.APPROVAL_METHOD', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_LEVEL', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_EVENT', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.INSTANT_APPROVAL_SPACE_TYPE', N'U') IS NOT NULL
   OR OBJECT_ID(N'dbo.ACADEMIC_SEMESTER', N'U') IS NOT NULL
   OR COL_LENGTH(N'dbo.BOOKING_STATUS', N'status_code') IS NOT NULL
   OR COL_LENGTH(N'dbo.APPROVAL_DECISION', N'decision_method_id') IS NOT NULL
   OR COL_LENGTH(N'dbo.MAINTENANCE_RECORD', N'impact_level_id') IS NOT NULL
BEGIN
    SET @HasAnyPhase2 = 1;
END;

IF @HasAllPhase2 = 1
BEGIN
    PRINT N'Phase 2 migration already appears complete. No changes were applied.';
    RETURN;
END;

IF @HasAnyPhase2 = 1
BEGIN
    THROW 51010, 'Partial Phase 2 schema detected. Stop and review/recover before rerunning this migration.', 1;
END;

-- ============================================================================
-- Preflight source-schema checks
-- ============================================================================
DECLARE @RequiredTables TABLE (table_name SYSNAME NOT NULL PRIMARY KEY);
INSERT INTO @RequiredTables (table_name) VALUES
    (N'ROLE'), (N'ACCOUNT_STATUS'), (N'DEPARTMENT'), (N'USER_ACCOUNT'),
    (N'SPACE_STATUS'), (N'SPACE'), (N'FACILITY'), (N'SPACE_FACILITY'),
    (N'BOOKING_STATUS'), (N'BOOKING_REQUEST'), (N'APPROVAL_DECISION'),
    (N'USAGE_SESSION'), (N'MAINTENANCE_STATUS'), (N'MAINTENANCE_RECORD');

IF EXISTS (
    SELECT 1
    FROM @RequiredTables AS rt
    WHERE OBJECT_ID(N'dbo.' + rt.table_name, N'U') IS NULL
)
BEGIN
    THROW 51011, 'Preflight failed: one or more required Phase 1 tables is missing.', 1;
END;

DECLARE @RequiredColumns TABLE (
    table_name SYSNAME NOT NULL,
    column_name SYSNAME NOT NULL,
    PRIMARY KEY (table_name, column_name)
);

INSERT INTO @RequiredColumns (table_name, column_name) VALUES
    (N'ROLE', N'role_id'), (N'ROLE', N'role_name'),
    (N'ACCOUNT_STATUS', N'account_status_id'), (N'ACCOUNT_STATUS', N'status_name'),
    (N'DEPARTMENT', N'department_id'), (N'DEPARTMENT', N'department_name'), (N'DEPARTMENT', N'head_user_account_id'),
    (N'USER_ACCOUNT', N'user_account_id'), (N'USER_ACCOUNT', N'user_id'), (N'USER_ACCOUNT', N'full_name'), (N'USER_ACCOUNT', N'email'), (N'USER_ACCOUNT', N'phone_number'), (N'USER_ACCOUNT', N'department_id'), (N'USER_ACCOUNT', N'role_id'), (N'USER_ACCOUNT', N'account_status_id'),
    (N'SPACE_STATUS', N'space_status_id'), (N'SPACE_STATUS', N'status_name'),
    (N'SPACE', N'space_id'), (N'SPACE', N'unique_space_code'), (N'SPACE', N'space_name'), (N'SPACE', N'space_type'), (N'SPACE', N'building'), (N'SPACE', N'floor'), (N'SPACE', N'room_number'), (N'SPACE', N'capacity'), (N'SPACE', N'usage_policy'), (N'SPACE', N'space_status_id'),
    (N'FACILITY', N'facility_id'), (N'FACILITY', N'facility_name'),
    (N'SPACE_FACILITY', N'space_facility_id'), (N'SPACE_FACILITY', N'space_id'), (N'SPACE_FACILITY', N'facility_id'),
    (N'BOOKING_STATUS', N'booking_status_id'), (N'BOOKING_STATUS', N'status_name'),
    (N'BOOKING_REQUEST', N'booking_request_id'), (N'BOOKING_REQUEST', N'requester_user_account_id'), (N'BOOKING_REQUEST', N'space_id'), (N'BOOKING_REQUEST', N'booking_status_id'), (N'BOOKING_REQUEST', N'requested_start_time'), (N'BOOKING_REQUEST', N'requested_end_time'), (N'BOOKING_REQUEST', N'purpose_of_use'), (N'BOOKING_REQUEST', N'expected_number_of_participants'),
    (N'APPROVAL_DECISION', N'approval_decision_id'), (N'APPROVAL_DECISION', N'booking_request_id'), (N'APPROVAL_DECISION', N'decided_by_user_account_id'), (N'APPROVAL_DECISION', N'decision_outcome_booking_status_id'), (N'APPROVAL_DECISION', N'decision_time'), (N'APPROVAL_DECISION', N'decision_note'), (N'APPROVAL_DECISION', N'rejection_reason'),
    (N'USAGE_SESSION', N'usage_session_id'), (N'USAGE_SESSION', N'booking_request_id'), (N'USAGE_SESSION', N'checked_in_by_user_account_id'), (N'USAGE_SESSION', N'completed_by_user_account_id'), (N'USAGE_SESSION', N'actual_start_time'), (N'USAGE_SESSION', N'initial_condition_of_space'), (N'USAGE_SESSION', N'actual_end_time'), (N'USAGE_SESSION', N'final_condition_of_space'), (N'USAGE_SESSION', N'usage_notes'),
    (N'MAINTENANCE_STATUS', N'maintenance_status_id'), (N'MAINTENANCE_STATUS', N'status_name'),
    (N'MAINTENANCE_RECORD', N'maintenance_record_id'), (N'MAINTENANCE_RECORD', N'space_id'), (N'MAINTENANCE_RECORD', N'reported_by_user_account_id'), (N'MAINTENANCE_RECORD', N'assigned_to_user_account_id'), (N'MAINTENANCE_RECORD', N'maintenance_status_id'), (N'MAINTENANCE_RECORD', N'problem_description'), (N'MAINTENANCE_RECORD', N'start_time'), (N'MAINTENANCE_RECORD', N'completion_time'), (N'MAINTENANCE_RECORD', N'result_note');

IF EXISTS (
    SELECT 1
    FROM @RequiredColumns AS rc
    WHERE COL_LENGTH(N'dbo.' + rc.table_name, rc.column_name) IS NULL
)
BEGIN
    THROW 51012, 'Preflight failed: one or more required Phase 1 columns is missing.', 1;
END;

DECLARE @RequiredConstraints TABLE (constraint_name SYSNAME NOT NULL PRIMARY KEY);
INSERT INTO @RequiredConstraints (constraint_name) VALUES
    (N'PK_ROLE'), (N'UQ_ROLE_role_name'),
    (N'PK_ACCOUNT_STATUS'), (N'UQ_ACCOUNT_STATUS_status_name'),
    (N'PK_DEPARTMENT'), (N'UQ_DEPARTMENT_department_name'), (N'FK_DEPARTMENT_head_user_account_id'),
    (N'PK_USER_ACCOUNT'), (N'UQ_USER_ACCOUNT_user_id'), (N'UQ_USER_ACCOUNT_email'), (N'FK_USER_ACCOUNT_department_id'), (N'FK_USER_ACCOUNT_role_id'), (N'FK_USER_ACCOUNT_account_status_id'),
    (N'PK_SPACE_STATUS'), (N'UQ_SPACE_STATUS_status_name'),
    (N'PK_SPACE'), (N'UQ_SPACE_unique_space_code'), (N'CK_SPACE_capacity_positive'), (N'FK_SPACE_space_status_id'),
    (N'PK_FACILITY'),
    (N'PK_SPACE_FACILITY'), (N'UQ_SPACE_FACILITY_space_id_facility_id'), (N'FK_SPACE_FACILITY_space_id'), (N'FK_SPACE_FACILITY_facility_id'),
    (N'PK_BOOKING_STATUS'), (N'UQ_BOOKING_STATUS_status_name'),
    (N'PK_BOOKING_REQUEST'), (N'FK_BOOKING_REQUEST_requester_user_account_id'), (N'FK_BOOKING_REQUEST_space_id'), (N'FK_BOOKING_REQUEST_booking_status_id'), (N'CK_BOOKING_REQUEST_requested_time_order'), (N'CK_BOOKING_REQUEST_expected_participants_positive'), (N'CK_BOOKING_REQUEST_purpose_of_use'),
    (N'PK_APPROVAL_DECISION'), (N'FK_APPROVAL_DECISION_booking_request_id'), (N'FK_APPROVAL_DECISION_decided_by_user_account_id'), (N'FK_APPROVAL_DECISION_decision_outcome_booking_status_id'),
    (N'PK_USAGE_SESSION'), (N'UQ_USAGE_SESSION_booking_request_id'), (N'FK_USAGE_SESSION_booking_request_id'), (N'FK_USAGE_SESSION_checked_in_by_user_account_id'), (N'FK_USAGE_SESSION_completed_by_user_account_id'), (N'CK_USAGE_SESSION_actual_time_order'),
    (N'PK_MAINTENANCE_STATUS'), (N'UQ_MAINTENANCE_STATUS_status_name'),
    (N'PK_MAINTENANCE_RECORD'), (N'FK_MAINTENANCE_RECORD_space_id'), (N'FK_MAINTENANCE_RECORD_reported_by_user_account_id'), (N'FK_MAINTENANCE_RECORD_assigned_to_user_account_id'), (N'FK_MAINTENANCE_RECORD_maintenance_status_id'), (N'CK_MAINTENANCE_RECORD_time_order');

IF EXISTS (
    SELECT 1
    FROM @RequiredConstraints AS rc
    WHERE NOT EXISTS (
        SELECT 1
        FROM sys.objects AS o
        WHERE o.name = rc.constraint_name
          AND o.type IN (N'PK', N'UQ', N'F', N'C')
    )
)
BEGIN
    THROW 51013, 'Preflight failed: one or more required Phase 1 constraints is missing.', 1;
END;

IF OBJECT_ID(N'tempdb..#phase2_baseline_counts', N'U') IS NOT NULL
BEGIN
    DROP TABLE #phase2_baseline_counts;
END;

CREATE TABLE #phase2_baseline_counts (
    table_name SYSNAME NOT NULL PRIMARY KEY,
    row_count BIGINT NOT NULL
);

INSERT INTO #phase2_baseline_counts (table_name, row_count)
SELECT N'ROLE', COUNT_BIG(*) FROM dbo.ROLE UNION ALL
SELECT N'ACCOUNT_STATUS', COUNT_BIG(*) FROM dbo.ACCOUNT_STATUS UNION ALL
SELECT N'DEPARTMENT', COUNT_BIG(*) FROM dbo.DEPARTMENT UNION ALL
SELECT N'USER_ACCOUNT', COUNT_BIG(*) FROM dbo.USER_ACCOUNT UNION ALL
SELECT N'SPACE_STATUS', COUNT_BIG(*) FROM dbo.SPACE_STATUS UNION ALL
SELECT N'SPACE', COUNT_BIG(*) FROM dbo.SPACE UNION ALL
SELECT N'FACILITY', COUNT_BIG(*) FROM dbo.FACILITY UNION ALL
SELECT N'SPACE_FACILITY', COUNT_BIG(*) FROM dbo.SPACE_FACILITY UNION ALL
SELECT N'BOOKING_STATUS', COUNT_BIG(*) FROM dbo.BOOKING_STATUS UNION ALL
SELECT N'BOOKING_REQUEST', COUNT_BIG(*) FROM dbo.BOOKING_REQUEST UNION ALL
SELECT N'APPROVAL_DECISION', COUNT_BIG(*) FROM dbo.APPROVAL_DECISION UNION ALL
SELECT N'USAGE_SESSION', COUNT_BIG(*) FROM dbo.USAGE_SESSION UNION ALL
SELECT N'MAINTENANCE_STATUS', COUNT_BIG(*) FROM dbo.MAINTENANCE_STATUS UNION ALL
SELECT N'MAINTENANCE_RECORD', COUNT_BIG(*) FROM dbo.MAINTENANCE_RECORD;

DECLARE @LegacyMaintenanceCount BIGINT =
    (SELECT row_count FROM #phase2_baseline_counts WHERE table_name = N'MAINTENANCE_RECORD');

-- ============================================================================
-- Transactional migration
-- ============================================================================
BEGIN TRY
    BEGIN TRANSACTION;

    -- New lookup/reference tables and seed data.
    CREATE TABLE dbo.APPROVAL_METHOD (
        approval_method_id INT IDENTITY(1,1) NOT NULL,
        method_code        NVARCHAR(40)      NOT NULL,
        method_name        NVARCHAR(80)      NOT NULL,
        CONSTRAINT PK_APPROVAL_METHOD PRIMARY KEY (approval_method_id),
        CONSTRAINT UQ_APPROVAL_METHOD_method_code UNIQUE (method_code),
        CONSTRAINT UQ_APPROVAL_METHOD_method_name UNIQUE (method_name)
    );

    INSERT INTO dbo.APPROVAL_METHOD (method_code, method_name)
    SELECT N'staff_approval', N'staff approval'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.APPROVAL_METHOD WHERE method_code = N'staff_approval');

    INSERT INTO dbo.APPROVAL_METHOD (method_code, method_name)
    SELECT N'instant_approval', N'instant approval'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.APPROVAL_METHOD WHERE method_code = N'instant_approval');

    CREATE TABLE dbo.MAINTENANCE_IMPACT_LEVEL (
        impact_level_id   INT IDENTITY(1,1) NOT NULL,
        impact_level_code NVARCHAR(40)      NOT NULL,
        impact_level_name NVARCHAR(80)      NOT NULL,
        CONSTRAINT PK_MAINTENANCE_IMPACT_LEVEL PRIMARY KEY (impact_level_id),
        CONSTRAINT UQ_MAINTENANCE_IMPACT_LEVEL_impact_level_code UNIQUE (impact_level_code),
        CONSTRAINT UQ_MAINTENANCE_IMPACT_LEVEL_impact_level_name UNIQUE (impact_level_name)
    );

    INSERT INTO dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_code, impact_level_name)
    SELECT N'out_of_service', N'out-of-service'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'out_of_service');

    INSERT INTO dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_code, impact_level_name)
    SELECT N'advisory', N'advisory'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'advisory');

    -- New entity/history/association tables.
    CREATE TABLE dbo.ACADEMIC_SEMESTER (
        semester_id         INT IDENTITY(1,1) NOT NULL,
        semester_code       NVARCHAR(40)      NOT NULL,
        academic_year_label NVARCHAR(20)      NOT NULL,
        semester_name       NVARCHAR(80)      NOT NULL,
        semester_start_date DATE              NOT NULL,
        semester_end_date   DATE              NOT NULL,
        CONSTRAINT PK_ACADEMIC_SEMESTER PRIMARY KEY (semester_id),
        CONSTRAINT UQ_ACADEMIC_SEMESTER_semester_code UNIQUE (semester_code),
        CONSTRAINT UQ_ACADEMIC_SEMESTER_academic_year_label_semester_name UNIQUE (academic_year_label, semester_name),
        CONSTRAINT CK_ACADEMIC_SEMESTER_date_order CHECK (semester_end_date > semester_start_date)
    );

    CREATE TABLE dbo.INSTANT_APPROVAL_SPACE_TYPE (
        instant_approval_space_type_id INT IDENTITY(1,1) NOT NULL,
        space_type                     NVARCHAR(100)     NOT NULL,
        is_active                      BIT               NOT NULL,
        configured_at                  DATETIME2(0)      NULL,
        configured_by_user_account_id  INT               NULL,
        configuration_note             NVARCHAR(1000)    NULL,
        CONSTRAINT PK_INSTANT_APPROVAL_SPACE_TYPE PRIMARY KEY (instant_approval_space_type_id),
        CONSTRAINT UQ_INSTANT_APPROVAL_SPACE_TYPE_space_type UNIQUE (space_type),
        CONSTRAINT FK_INSTANT_APPROVAL_SPACE_TYPE_configured_by_user_account_id FOREIGN KEY (configured_by_user_account_id)
            REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION
    );

    CREATE TABLE dbo.MAINTENANCE_IMPACT_EVENT (
        maintenance_impact_event_id INT IDENTITY(1,1) NOT NULL,
        maintenance_record_id       INT               NOT NULL,
        old_impact_level_id         INT               NULL,
        new_impact_level_id         INT               NOT NULL,
        changed_by_user_account_id  INT               NULL,
        changed_at                  DATETIME2(0)      NOT NULL,
        change_note                 NVARCHAR(1000)    NULL,
        CONSTRAINT PK_MAINTENANCE_IMPACT_EVENT PRIMARY KEY (maintenance_impact_event_id),
        CONSTRAINT FK_MAINTENANCE_IMPACT_EVENT_maintenance_record_id FOREIGN KEY (maintenance_record_id)
            REFERENCES dbo.MAINTENANCE_RECORD (maintenance_record_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_MAINTENANCE_IMPACT_EVENT_old_impact_level_id FOREIGN KEY (old_impact_level_id)
            REFERENCES dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_MAINTENANCE_IMPACT_EVENT_new_impact_level_id FOREIGN KEY (new_impact_level_id)
            REFERENCES dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_MAINTENANCE_IMPACT_EVENT_changed_by_user_account_id FOREIGN KEY (changed_by_user_account_id)
            REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT CK_MAINTENANCE_IMPACT_EVENT_distinct_levels CHECK (old_impact_level_id IS NULL OR old_impact_level_id <> new_impact_level_id)
    );

    CREATE TABLE dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT (
        advisory_acknowledgement_id INT IDENTITY(1,1) NOT NULL,
        booking_request_id          INT               NOT NULL,
        maintenance_record_id       INT               NOT NULL,
        acknowledged_impact_level_id INT              NOT NULL,
        acknowledged_at             DATETIME2(0)      NOT NULL,
        advisory_message_snapshot   NVARCHAR(1000)    NULL,
        CONSTRAINT PK_BOOKING_ADVISORY_ACKNOWLEDGEMENT PRIMARY KEY (advisory_acknowledgement_id),
        CONSTRAINT UQ_BOOKING_ADVISORY_ACKNOWLEDGEMENT_booking_maintenance UNIQUE (booking_request_id, maintenance_record_id),
        CONSTRAINT FK_BOOKING_ADVISORY_ACKNOWLEDGEMENT_booking_request_id FOREIGN KEY (booking_request_id)
            REFERENCES dbo.BOOKING_REQUEST (booking_request_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_BOOKING_ADVISORY_ACKNOWLEDGEMENT_maintenance_record_id FOREIGN KEY (maintenance_record_id)
            REFERENCES dbo.MAINTENANCE_RECORD (maintenance_record_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
        CONSTRAINT FK_BOOKING_ADVISORY_ACKNOWLEDGEMENT_acknowledged_impact_level_id FOREIGN KEY (acknowledged_impact_level_id)
            REFERENCES dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_id) ON DELETE NO ACTION ON UPDATE NO ACTION
    );

    -- Additive columns on existing tables.
    ALTER TABLE dbo.BOOKING_STATUS
        ADD status_code NVARCHAR(40) NULL;

    UPDATE dbo.BOOKING_STATUS
        SET status_code = CASE UPPER(LTRIM(RTRIM(status_name)))
            WHEN N'PENDING' THEN N'pending'
            WHEN N'APPROVED' THEN N'approved'
            WHEN N'REJECTED' THEN N'rejected'
            WHEN N'CANCELLED' THEN N'cancelled'
            WHEN N'CHECKED IN' THEN N'checked_in'
            WHEN N'COMPLETED' THEN N'completed'
            WHEN N'NO-SHOW' THEN N'no_show'
            WHEN N'NO SHOW' THEN N'no_show'
            ELSE NULL
        END;

    IF EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code IS NULL)
    BEGIN
        THROW 51020, 'Backfill failed: BOOKING_STATUS contains a status_name not mapped to a Phase 2 status_code.', 1;
    END;

    ALTER TABLE dbo.BOOKING_STATUS
        ALTER COLUMN status_code NVARCHAR(40) NOT NULL;

    ALTER TABLE dbo.BOOKING_STATUS
        ADD CONSTRAINT UQ_BOOKING_STATUS_status_code UNIQUE (status_code);

    ALTER TABLE dbo.APPROVAL_DECISION
        ADD decision_method_id INT NULL;

    UPDATE dbo.APPROVAL_DECISION
        SET decision_method_id = (
            SELECT approval_method_id
            FROM dbo.APPROVAL_METHOD
            WHERE method_code = N'staff_approval'
        );

    IF EXISTS (SELECT 1 FROM dbo.APPROVAL_DECISION WHERE decision_method_id IS NULL)
    BEGIN
        THROW 51021, 'Backfill failed: APPROVAL_DECISION.decision_method_id could not be populated.', 1;
    END;

    ALTER TABLE dbo.APPROVAL_DECISION
        ALTER COLUMN decision_method_id INT NOT NULL;

    ALTER TABLE dbo.APPROVAL_DECISION WITH CHECK
        ADD CONSTRAINT FK_APPROVAL_DECISION_decision_method_id FOREIGN KEY (decision_method_id)
            REFERENCES dbo.APPROVAL_METHOD (approval_method_id) ON DELETE NO ACTION ON UPDATE NO ACTION;

    -- Temporary FK removal is required only to relax nullability; no data is dropped.
    ALTER TABLE dbo.APPROVAL_DECISION
        DROP CONSTRAINT FK_APPROVAL_DECISION_decided_by_user_account_id;

    ALTER TABLE dbo.APPROVAL_DECISION
        ALTER COLUMN decided_by_user_account_id INT NULL;

    ALTER TABLE dbo.APPROVAL_DECISION WITH CHECK
        ADD CONSTRAINT FK_APPROVAL_DECISION_decided_by_user_account_id FOREIGN KEY (decided_by_user_account_id)
            REFERENCES dbo.USER_ACCOUNT (user_account_id) ON DELETE NO ACTION ON UPDATE NO ACTION;

    ALTER TABLE dbo.MAINTENANCE_RECORD
        ADD impact_level_id INT NULL;

    UPDATE dbo.MAINTENANCE_RECORD
        SET impact_level_id = (
            SELECT impact_level_id
            FROM dbo.MAINTENANCE_IMPACT_LEVEL
            WHERE impact_level_code = N'out_of_service'
        );

    IF EXISTS (SELECT 1 FROM dbo.MAINTENANCE_RECORD WHERE impact_level_id IS NULL)
    BEGIN
        THROW 51022, 'Backfill failed: MAINTENANCE_RECORD.impact_level_id could not be populated.', 1;
    END;

    ALTER TABLE dbo.MAINTENANCE_RECORD
        ALTER COLUMN impact_level_id INT NOT NULL;

    ALTER TABLE dbo.MAINTENANCE_RECORD WITH CHECK
        ADD CONSTRAINT FK_MAINTENANCE_RECORD_impact_level_id FOREIGN KEY (impact_level_id)
            REFERENCES dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_id) ON DELETE NO ACTION ON UPDATE NO ACTION;

    -- Legacy-data backfill: migration baseline current-state import only.
    INSERT INTO dbo.MAINTENANCE_IMPACT_EVENT (
        maintenance_record_id,
        old_impact_level_id,
        new_impact_level_id,
        changed_by_user_account_id,
        changed_at,
        change_note
    )
    SELECT
        mr.maintenance_record_id,
        NULL,
        mr.impact_level_id,
        NULL,
        mr.start_time,
        N'Migration baseline current-state import; not a historical escalation.'
    FROM dbo.MAINTENANCE_RECORD AS mr;

    -- Post-migration integrity checks.
    IF EXISTS (
        SELECT bc.table_name, bc.row_count AS before_count, ca.current_count
        FROM #phase2_baseline_counts AS bc
        CROSS APPLY (
            SELECT current_count = CASE bc.table_name
                WHEN N'ROLE' THEN (SELECT COUNT_BIG(*) FROM dbo.ROLE)
                WHEN N'ACCOUNT_STATUS' THEN (SELECT COUNT_BIG(*) FROM dbo.ACCOUNT_STATUS)
                WHEN N'DEPARTMENT' THEN (SELECT COUNT_BIG(*) FROM dbo.DEPARTMENT)
                WHEN N'USER_ACCOUNT' THEN (SELECT COUNT_BIG(*) FROM dbo.USER_ACCOUNT)
                WHEN N'SPACE_STATUS' THEN (SELECT COUNT_BIG(*) FROM dbo.SPACE_STATUS)
                WHEN N'SPACE' THEN (SELECT COUNT_BIG(*) FROM dbo.SPACE)
                WHEN N'FACILITY' THEN (SELECT COUNT_BIG(*) FROM dbo.FACILITY)
                WHEN N'SPACE_FACILITY' THEN (SELECT COUNT_BIG(*) FROM dbo.SPACE_FACILITY)
                WHEN N'BOOKING_STATUS' THEN (SELECT COUNT_BIG(*) FROM dbo.BOOKING_STATUS)
                WHEN N'BOOKING_REQUEST' THEN (SELECT COUNT_BIG(*) FROM dbo.BOOKING_REQUEST)
                WHEN N'APPROVAL_DECISION' THEN (SELECT COUNT_BIG(*) FROM dbo.APPROVAL_DECISION)
                WHEN N'USAGE_SESSION' THEN (SELECT COUNT_BIG(*) FROM dbo.USAGE_SESSION)
                WHEN N'MAINTENANCE_STATUS' THEN (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_STATUS)
                WHEN N'MAINTENANCE_RECORD' THEN (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_RECORD)
            END
        ) AS ca
        WHERE ca.current_count <> bc.row_count
    )
    BEGIN
        THROW 51030, 'Postflight failed: one or more Phase 1 table row counts changed.', 1;
    END;

    IF (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_IMPACT_EVENT) <> @LegacyMaintenanceCount
    BEGIN
        THROW 51031, 'Postflight failed: legacy maintenance baseline event count does not match legacy maintenance row count.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.APPROVAL_DECISION AS ad
        LEFT JOIN dbo.APPROVAL_METHOD AS am
            ON am.approval_method_id = ad.decision_method_id
        WHERE am.approval_method_id IS NULL
    )
    BEGIN
        THROW 51032, 'Postflight failed: orphan decision_method_id detected.', 1;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.MAINTENANCE_RECORD AS mr
        LEFT JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil
            ON mil.impact_level_id = mr.impact_level_id
        WHERE mil.impact_level_id IS NULL
    )
    BEGIN
        THROW 51033, 'Postflight failed: orphan maintenance impact_level_id detected.', 1;
    END;

    IF EXISTS (
        SELECT booking_request_id, maintenance_record_id
        FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT
        GROUP BY booking_request_id, maintenance_record_id
        HAVING COUNT_BIG(*) > 1
    )
    BEGIN
        THROW 51034, 'Postflight failed: duplicate booking/advisory acknowledgements detected.', 1;
    END;

    IF OBJECT_ID(N'tempdb..#phase2_constraint_violations', N'U') IS NOT NULL
    BEGIN
        DROP TABLE #phase2_constraint_violations;
    END;

    CREATE TABLE #phase2_constraint_violations (
        [Table] NVARCHAR(512) NULL,
        [Constraint] NVARCHAR(512) NULL,
        [Where] NVARCHAR(MAX) NULL
    );

    INSERT INTO #phase2_constraint_violations
    EXEC (N'DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS');

    IF EXISTS (SELECT 1 FROM #phase2_constraint_violations)
    BEGIN
        THROW 51035, 'Postflight failed: DBCC CHECKCONSTRAINTS reported constraint violations.', 1;
    END;

    COMMIT TRANSACTION;
    PRINT N'Phase 2 schema migration completed successfully.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();

    RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
END CATCH;

-- ============================================================================
-- Rerun behavior
-- ============================================================================
-- A clean rerun after successful migration stops at the already-migrated check.
-- A rerun after a failed transaction should see no Phase 2 objects because the
-- transaction is rolled back. If external manual edits leave a partial schema,
-- the partial-schema preflight THROW stops the script before more changes.

-- ============================================================================
-- End of Phase 2 schema migration.
-- ============================================================================
