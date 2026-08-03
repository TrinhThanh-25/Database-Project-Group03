/*
 Phase 2 Concurrency Implementation - Group 03

 DBMS: Microsoft SQL Server

 Purpose:
   Implements the reviewed artifact 11 protocol for P2-BR-18 through P2-BR-21:
   all approval-producing paths serialize by target space with transaction-owned
   sys.sp_getapplock, then recheck approved-booking overlap, out-of-service
   maintenance, and advisory acknowledgements before writing approval state.

 Deployment prerequisites:
   1. Run outputs/05-db-definition-G03.sql.
   2. Run outputs/10-schema-migration-G03.sql.
   3. Then run this file.

 Procedure contract for artifact 13:
   - dbo.usp_SubmitBookingRequest
       Creates a pending request, or instantly approves it when the selected
       space type and caller-confirmed usage policy allow instant approval.
       Uses the app-lock protocol only when the request becomes approved.
   - dbo.usp_ApproveBookingRequest
       Staff approval for an existing pending request. Always uses the same
       app-lock protocol before checking conflicts and approving.
   - dbo.usp_RejectBookingRequest
       Staff rejection for an existing pending request. Does not create
       approved occupancy and therefore does not take the app lock.
   - dbo.usp_CancelBookingRequest
       Cancels pending or occupancy-counting requests. Takes the app lock when
       the current status counts as approved occupancy.
   - dbo.usp_RecordMaintenanceImpactChange
       Changes maintenance impact and, when escalating to out_of_service,
       returns overlapping approved bookings for staff contact.

 Shared protocol:
   Resource: G03CampusBooking:ApprovedOccupancy:space_id:{space_id}
   Mode: Exclusive
   Owner: Transaction
   Timeout: 10000 ms
   Approved occupancy status codes: approved, checked_in, completed
   Overlap predicate: existing.start < requested.end
                      AND existing.end > requested.start

 Error-number/result contract:
   51201  APP_LOCK_REQUIRES_TRANSACTION
   51202  CONCURRENCY_TIMEOUT
   51203  CONCURRENCY_CANCELLED
   51204  CONCURRENCY_DEADLOCK
   51205  CONCURRENCY_LOCK_ERROR
   51210  VALIDATION_ERROR
   51211  REQUIRED_LOOKUP_MISSING
   51212  REQUESTER_NOT_FOUND
   51213  SPACE_NOT_BOOKABLE
   51220  BOOKING_CONFLICT
   51221  SPACE_OUT_OF_SERVICE
   51222  ADVISORY_SET_CHANGED
   51223  ADVISORY_ACK_REQUIRED
   51230  BOOKING_NOT_PENDING
   51231  STAFF_NOT_AUTHORIZED
   51232  REJECTION_REASON_REQUIRED
   51240  INVALID_STATUS_TRANSITION
   51250  MAINTENANCE_NOT_FOUND
   51251  MAINTENANCE_IMPACT_UNCHANGED

 Assumptions and open questions carried from artifacts 08-11:
   - Instant usage-policy evaluation is unresolved. This implementation accepts
     @usage_policy_satisfied as a caller assertion and still rechecks selected
     space type from dbo.INSTANT_APPROVAL_SPACE_TYPE inside the transaction.
   - Active/open maintenance is represented conservatively by interval overlap
     and completion_time. The exact MAINTENANCE_STATUS values remain open.
   - Staff decision maker roles are role_name in ('facility staff',
     'facility manager'), matching Phase 1 notes and output 09.
   - Security statements create/use database role G03BookingAppRole for normal
     app execution. Administrative and migration principals remain outside this
     role.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ============================================================================
-- 1. Header and deployment prerequisites
-- ============================================================================
IF OBJECT_ID(N'dbo.BOOKING_REQUEST', N'U') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.BOOKING_REQUEST.', 1;
IF OBJECT_ID(N'dbo.APPROVAL_DECISION', N'U') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.APPROVAL_DECISION.', 1;
IF OBJECT_ID(N'dbo.MAINTENANCE_RECORD', N'U') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.MAINTENANCE_RECORD.', 1;
IF OBJECT_ID(N'dbo.APPROVAL_METHOD', N'U') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.APPROVAL_METHOD. Run artifact 10 first.', 1;
IF OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_LEVEL', N'U') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.MAINTENANCE_IMPACT_LEVEL. Run artifact 10 first.', 1;
IF OBJECT_ID(N'dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT', N'U') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT. Run artifact 10 first.', 1;
IF OBJECT_ID(N'dbo.INSTANT_APPROVAL_SPACE_TYPE', N'U') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.INSTANT_APPROVAL_SPACE_TYPE. Run artifact 10 first.', 1;
IF COL_LENGTH(N'dbo.BOOKING_STATUS', N'status_code') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.BOOKING_STATUS.status_code. Run artifact 10 first.', 1;
IF COL_LENGTH(N'dbo.APPROVAL_DECISION', N'decision_method_id') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.APPROVAL_DECISION.decision_method_id. Run artifact 10 first.', 1;
IF COL_LENGTH(N'dbo.MAINTENANCE_RECORD', N'impact_level_id') IS NULL
    THROW 51210, 'Deployment prerequisite missing: dbo.MAINTENANCE_RECORD.impact_level_id. Run artifact 10 first.', 1;
GO

-- CREATE TYPE has no CREATE OR ALTER form; dynamic DDL is used only for safe rerun.
IF TYPE_ID(N'dbo.IntIdList') IS NULL
BEGIN
    EXEC(N'CREATE TYPE dbo.IntIdList AS TABLE (
        id INT NOT NULL PRIMARY KEY
    );');
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'G03BookingAppRole' AND type = N'R')
BEGIN
    EXEC(N'CREATE ROLE G03BookingAppRole AUTHORIZATION dbo;');
END;
GO

-- ============================================================================
-- 2. Shared supporting routine: transaction-owned app lock
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_G03_AcquireSpaceApprovalLock
    @space_id INT,
    @lock_timeout_ms INT = 10000
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @@TRANCOUNT = 0
        THROW 51201, 'APP_LOCK_REQUIRES_TRANSACTION: begin the transaction before acquiring a transaction-owned app lock.', 1;

    IF @space_id IS NULL OR @space_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @space_id must be a positive integer.', 1;

    DECLARE @lock_result INT;
    DECLARE @resource NVARCHAR(255) =
        CONCAT(N'G03CampusBooking:ApprovedOccupancy:space_id:', CONVERT(NVARCHAR(20), @space_id));

    EXEC @lock_result = sys.sp_getapplock
        @Resource = @resource,
        @LockMode = N'Exclusive',
        @LockOwner = N'Transaction',
        @LockTimeout = @lock_timeout_ms;

    IF @lock_result >= 0
        RETURN 0;

    IF @lock_result = -1
        THROW 51202, 'CONCURRENCY_TIMEOUT: could not acquire same-space approval lock before timeout.', 1;
    IF @lock_result = -2
        THROW 51203, 'CONCURRENCY_CANCELLED: same-space approval lock request was cancelled.', 1;
    IF @lock_result = -3
        THROW 51204, 'CONCURRENCY_DEADLOCK: same-space approval lock deadlock victim.', 1;

    THROW 51205, 'CONCURRENCY_LOCK_ERROR: same-space approval lock failed.', 1;
END;
GO

-- ============================================================================
-- 3. Instant or pending submission procedure
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_SubmitBookingRequest
    @requester_user_account_id INT,
    @space_id INT,
    @requested_start_time DATETIME2(0),
    @requested_end_time DATETIME2(0),
    @purpose_of_use NVARCHAR(80),
    @expected_number_of_participants INT,
    @acknowledged_advisory_maintenance_ids dbo.IntIdList READONLY,
    @booking_request_id INT OUTPUT,
    @final_status_code NVARCHAR(40) OUTPUT,
    @request_instant_approval BIT = 1,
    @usage_policy_satisfied BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @attempt INT = 1;
    DECLARE @completed BIT = 0;
    DECLARE @now DATETIME2(0);
    DECLARE @pending_status_id INT;
    DECLARE @approved_status_id INT;
    DECLARE @instant_method_id INT;
    DECLARE @advisory_impact_id INT;
    DECLARE @is_instant BIT = 0;

    SET @booking_request_id = NULL;
    SET @final_status_code = NULL;

    IF @requester_user_account_id IS NULL OR @requester_user_account_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @requester_user_account_id must be a positive integer.', 1;
    IF @space_id IS NULL OR @space_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @space_id must be a positive integer.', 1;
    IF @requested_start_time IS NULL OR @requested_end_time IS NULL OR @requested_start_time >= @requested_end_time
        THROW 51210, 'VALIDATION_ERROR: requested interval must satisfy start < end.', 1;
    IF @purpose_of_use IS NULL OR LEN(LTRIM(RTRIM(@purpose_of_use))) = 0
        THROW 51210, 'VALIDATION_ERROR: @purpose_of_use is required.', 1;
    IF @expected_number_of_participants IS NULL OR @expected_number_of_participants <= 0
        THROW 51210, 'VALIDATION_ERROR: @expected_number_of_participants must be positive.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.USER_ACCOUNT WHERE user_account_id = @requester_user_account_id)
        THROW 51212, 'REQUESTER_NOT_FOUND: requester user account does not exist.', 1;

    WHILE @attempt <= 3 AND @completed = 0
    BEGIN
        BEGIN TRY
            SET @now = SYSDATETIME();

            SELECT @pending_status_id = booking_status_id
            FROM dbo.BOOKING_STATUS
            WHERE status_code = N'pending';

            SELECT @approved_status_id = booking_status_id
            FROM dbo.BOOKING_STATUS
            WHERE status_code = N'approved';

            SELECT @instant_method_id = approval_method_id
            FROM dbo.APPROVAL_METHOD
            WHERE method_code = N'instant_approval';

            SELECT @advisory_impact_id = impact_level_id
            FROM dbo.MAINTENANCE_IMPACT_LEVEL
            WHERE impact_level_code = N'advisory';

            IF @pending_status_id IS NULL OR @approved_status_id IS NULL
                THROW 51211, 'REQUIRED_LOOKUP_MISSING: pending/approved booking status code is missing.', 1;
            IF @instant_method_id IS NULL
                THROW 51211, 'REQUIRED_LOOKUP_MISSING: instant approval method code is missing.', 1;
            IF @advisory_impact_id IS NULL
                THROW 51211, 'REQUIRED_LOOKUP_MISSING: advisory maintenance impact code is missing.', 1;

            BEGIN TRANSACTION;

            IF NOT EXISTS (
                SELECT 1
                FROM dbo.SPACE AS s
                INNER JOIN dbo.SPACE_STATUS AS ss ON ss.space_status_id = s.space_status_id
                WHERE s.space_id = @space_id
                  AND ss.status_name NOT IN (N'Under maintenance', N'Temporarily closed', N'Retired')
            )
                THROW 51213, 'SPACE_NOT_BOOKABLE: target space does not exist or has an unavailable current status.', 1;

            IF @request_instant_approval = 1
               AND @usage_policy_satisfied = 1
               AND EXISTS (
                    SELECT 1
                    FROM dbo.SPACE AS s
                    INNER JOIN dbo.INSTANT_APPROVAL_SPACE_TYPE AS iast
                        ON iast.space_type = s.space_type
                       AND iast.is_active = 1
                    WHERE s.space_id = @space_id
               )
            BEGIN
                SET @is_instant = 1;
            END
            ELSE
            BEGIN
                SET @is_instant = 0;
            END;

            IF @is_instant = 1
            BEGIN
                EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;

                -- P2-BR-19 through P2-BR-21: approved occupancy conflict check after app lock.
                IF EXISTS (
                    SELECT 1
                    FROM dbo.BOOKING_REQUEST AS br
                    INNER JOIN dbo.BOOKING_STATUS AS bs
                        ON bs.booking_status_id = br.booking_status_id
                    WHERE br.space_id = @space_id
                      AND bs.status_code IN (N'approved', N'checked_in', N'completed')
                      AND br.requested_start_time < @requested_end_time
                      AND br.requested_end_time > @requested_start_time
                )
                    THROW 51220, 'BOOKING_CONFLICT: overlapping approved occupancy exists for the target space.', 1;

                -- P2-BR-03 through P2-BR-04: out-of-service maintenance blocks approval.
                IF EXISTS (
                    SELECT 1
                    FROM dbo.MAINTENANCE_RECORD AS mr
                    INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil
                        ON mil.impact_level_id = mr.impact_level_id
                    WHERE mr.space_id = @space_id
                      AND mil.impact_level_code = N'out_of_service'
                      AND mr.start_time < @requested_end_time
                      AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > @requested_start_time
                )
                    THROW 51221, 'SPACE_OUT_OF_SERVICE: active out-of-service maintenance overlaps the requested interval.', 1;

                DECLARE @current_advisory TABLE (
                    maintenance_record_id INT NOT NULL PRIMARY KEY,
                    advisory_message_snapshot NVARCHAR(1000) NULL
                );

                INSERT INTO @current_advisory (maintenance_record_id, advisory_message_snapshot)
                SELECT mr.maintenance_record_id, mr.problem_description
                FROM dbo.MAINTENANCE_RECORD AS mr
                INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil
                    ON mil.impact_level_id = mr.impact_level_id
                WHERE mr.space_id = @space_id
                  AND mil.impact_level_code = N'advisory'
                  AND mr.start_time < @requested_end_time
                  AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > @requested_start_time;

                IF EXISTS (SELECT maintenance_record_id FROM @current_advisory EXCEPT SELECT id FROM @acknowledged_advisory_maintenance_ids)
                    THROW 51223, 'ADVISORY_ACK_REQUIRED: current advisory maintenance must be acknowledged before instant approval.', 1;

                IF EXISTS (SELECT id FROM @acknowledged_advisory_maintenance_ids EXCEPT SELECT maintenance_record_id FROM @current_advisory)
                    THROW 51222, 'ADVISORY_SET_CHANGED: acknowledged advisory set does not match current advisory maintenance.', 1;

                INSERT INTO dbo.BOOKING_REQUEST (
                    requester_user_account_id,
                    space_id,
                    booking_status_id,
                    requested_start_time,
                    requested_end_time,
                    purpose_of_use,
                    expected_number_of_participants
                )
                VALUES (
                    @requester_user_account_id,
                    @space_id,
                    @approved_status_id,
                    @requested_start_time,
                    @requested_end_time,
                    @purpose_of_use,
                    @expected_number_of_participants
                );

                SET @booking_request_id = CONVERT(INT, SCOPE_IDENTITY());

                INSERT INTO dbo.APPROVAL_DECISION (
                    booking_request_id,
                    decided_by_user_account_id,
                    decision_outcome_booking_status_id,
                    decision_method_id,
                    decision_time,
                    decision_note,
                    rejection_reason
                )
                VALUES (
                    @booking_request_id,
                    NULL,
                    @approved_status_id,
                    @instant_method_id,
                    @now,
                    N'Instant approval recorded by reviewed concurrency procedure.',
                    NULL
                );

                INSERT INTO dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT (
                    booking_request_id,
                    maintenance_record_id,
                    acknowledged_impact_level_id,
                    acknowledged_at,
                    advisory_message_snapshot
                )
                SELECT
                    @booking_request_id,
                    ca.maintenance_record_id,
                    @advisory_impact_id,
                    @now,
                    ca.advisory_message_snapshot
                FROM @current_advisory AS ca;

                SET @final_status_code = N'approved';
            END
            ELSE
            BEGIN
                INSERT INTO dbo.BOOKING_REQUEST (
                    requester_user_account_id,
                    space_id,
                    booking_status_id,
                    requested_start_time,
                    requested_end_time,
                    purpose_of_use,
                    expected_number_of_participants
                )
                VALUES (
                    @requester_user_account_id,
                    @space_id,
                    @pending_status_id,
                    @requested_start_time,
                    @requested_end_time,
                    @purpose_of_use,
                    @expected_number_of_participants
                );

                SET @booking_request_id = CONVERT(INT, SCOPE_IDENTITY());
                SET @final_status_code = N'pending';
            END;

            COMMIT TRANSACTION;
            SET @completed = 1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;

            IF ERROR_NUMBER() IN (1205, 51204) AND @attempt < 3
            BEGIN
                SET @attempt += 1;
                CONTINUE;
            END;

            THROW;
        END CATCH;
    END;

    SELECT
        @booking_request_id AS booking_request_id,
        @final_status_code AS final_status_code;
END;
GO

-- ============================================================================
-- 4. Staff approval procedure
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ApproveBookingRequest
    @staff_user_account_id INT,
    @booking_request_id INT,
    @decision_note NVARCHAR(1000) = NULL,
    @acknowledged_advisory_maintenance_ids dbo.IntIdList READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @attempt INT = 1;
    DECLARE @completed BIT = 0;
    DECLARE @now DATETIME2(0);
    DECLARE @space_id INT;
    DECLARE @requested_start_time DATETIME2(0);
    DECLARE @requested_end_time DATETIME2(0);
    DECLARE @pending_status_id INT;
    DECLARE @approved_status_id INT;
    DECLARE @staff_method_id INT;
    DECLARE @advisory_impact_id INT;

    IF @staff_user_account_id IS NULL OR @staff_user_account_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @staff_user_account_id must be a positive integer.', 1;
    IF @booking_request_id IS NULL OR @booking_request_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @booking_request_id must be a positive integer.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.USER_ACCOUNT AS ua
        INNER JOIN dbo.ROLE AS r ON r.role_id = ua.role_id
        WHERE ua.user_account_id = @staff_user_account_id
          AND r.role_name IN (N'facility staff', N'facility manager')
    )
        THROW 51231, 'STAFF_NOT_AUTHORIZED: staff decision maker must be facility staff or facility manager.', 1;

    WHILE @attempt <= 3 AND @completed = 0
    BEGIN
        BEGIN TRY
            SET @now = SYSDATETIME();

            SELECT @pending_status_id = booking_status_id
            FROM dbo.BOOKING_STATUS
            WHERE status_code = N'pending';

            SELECT @approved_status_id = booking_status_id
            FROM dbo.BOOKING_STATUS
            WHERE status_code = N'approved';

            SELECT @staff_method_id = approval_method_id
            FROM dbo.APPROVAL_METHOD
            WHERE method_code = N'staff_approval';

            SELECT @advisory_impact_id = impact_level_id
            FROM dbo.MAINTENANCE_IMPACT_LEVEL
            WHERE impact_level_code = N'advisory';

            IF @pending_status_id IS NULL OR @approved_status_id IS NULL
                THROW 51211, 'REQUIRED_LOOKUP_MISSING: pending/approved booking status code is missing.', 1;
            IF @staff_method_id IS NULL
                THROW 51211, 'REQUIRED_LOOKUP_MISSING: staff approval method code is missing.', 1;
            IF @advisory_impact_id IS NULL
                THROW 51211, 'REQUIRED_LOOKUP_MISSING: advisory maintenance impact code is missing.', 1;

            BEGIN TRANSACTION;

            SELECT
                @space_id = br.space_id,
                @requested_start_time = br.requested_start_time,
                @requested_end_time = br.requested_end_time
            FROM dbo.BOOKING_REQUEST AS br WITH (UPDLOCK, HOLDLOCK)
            WHERE br.booking_request_id = @booking_request_id
              AND br.booking_status_id = @pending_status_id;

            IF @space_id IS NULL
                THROW 51230, 'BOOKING_NOT_PENDING: booking request does not exist or is not pending.', 1;

            EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;

            IF NOT EXISTS (
                SELECT 1
                FROM dbo.SPACE AS s
                INNER JOIN dbo.SPACE_STATUS AS ss ON ss.space_status_id = s.space_status_id
                WHERE s.space_id = @space_id
                  AND ss.status_name NOT IN (N'Under maintenance', N'Temporarily closed', N'Retired')
            )
                THROW 51213, 'SPACE_NOT_BOOKABLE: target space has an unavailable current status.', 1;

            -- P2-BR-19 through P2-BR-21: exclude the current pending row only.
            IF EXISTS (
                SELECT 1
                FROM dbo.BOOKING_REQUEST AS br
                INNER JOIN dbo.BOOKING_STATUS AS bs
                    ON bs.booking_status_id = br.booking_status_id
                WHERE br.booking_request_id <> @booking_request_id
                  AND br.space_id = @space_id
                  AND bs.status_code IN (N'approved', N'checked_in', N'completed')
                  AND br.requested_start_time < @requested_end_time
                  AND br.requested_end_time > @requested_start_time
            )
                THROW 51220, 'BOOKING_CONFLICT: overlapping approved occupancy exists for the target space.', 1;

            IF EXISTS (
                SELECT 1
                FROM dbo.MAINTENANCE_RECORD AS mr
                INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil
                    ON mil.impact_level_id = mr.impact_level_id
                WHERE mr.space_id = @space_id
                  AND mil.impact_level_code = N'out_of_service'
                  AND mr.start_time < @requested_end_time
                  AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > @requested_start_time
            )
                THROW 51221, 'SPACE_OUT_OF_SERVICE: active out-of-service maintenance overlaps the requested interval.', 1;

            DECLARE @current_advisory TABLE (
                maintenance_record_id INT NOT NULL PRIMARY KEY,
                advisory_message_snapshot NVARCHAR(1000) NULL
            );

            INSERT INTO @current_advisory (maintenance_record_id, advisory_message_snapshot)
            SELECT mr.maintenance_record_id, mr.problem_description
            FROM dbo.MAINTENANCE_RECORD AS mr
            INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil
                ON mil.impact_level_id = mr.impact_level_id
            WHERE mr.space_id = @space_id
              AND mil.impact_level_code = N'advisory'
              AND mr.start_time < @requested_end_time
              AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > @requested_start_time;

            IF EXISTS (SELECT maintenance_record_id FROM @current_advisory EXCEPT SELECT id FROM @acknowledged_advisory_maintenance_ids)
                THROW 51223, 'ADVISORY_ACK_REQUIRED: current advisory maintenance must be acknowledged before staff approval.', 1;

            IF EXISTS (SELECT id FROM @acknowledged_advisory_maintenance_ids EXCEPT SELECT maintenance_record_id FROM @current_advisory)
                THROW 51222, 'ADVISORY_SET_CHANGED: acknowledged advisory set does not match current advisory maintenance.', 1;

            UPDATE dbo.BOOKING_REQUEST
                SET booking_status_id = @approved_status_id
            WHERE booking_request_id = @booking_request_id;

            INSERT INTO dbo.APPROVAL_DECISION (
                booking_request_id,
                decided_by_user_account_id,
                decision_outcome_booking_status_id,
                decision_method_id,
                decision_time,
                decision_note,
                rejection_reason
            )
            VALUES (
                @booking_request_id,
                @staff_user_account_id,
                @approved_status_id,
                @staff_method_id,
                @now,
                @decision_note,
                NULL
            );

            INSERT INTO dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT (
                booking_request_id,
                maintenance_record_id,
                acknowledged_impact_level_id,
                acknowledged_at,
                advisory_message_snapshot
            )
            SELECT
                @booking_request_id,
                ca.maintenance_record_id,
                @advisory_impact_id,
                @now,
                ca.advisory_message_snapshot
            FROM @current_advisory AS ca
            WHERE NOT EXISTS (
                SELECT 1
                FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
                WHERE baa.booking_request_id = @booking_request_id
                  AND baa.maintenance_record_id = ca.maintenance_record_id
            );

            COMMIT TRANSACTION;
            SET @completed = 1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;

            IF ERROR_NUMBER() IN (1205, 51204) AND @attempt < 3
            BEGIN
                SET @attempt += 1;
                SET @space_id = NULL;
                SET @requested_start_time = NULL;
                SET @requested_end_time = NULL;
                CONTINUE;
            END;

            THROW;
        END CATCH;
    END;

    SELECT
        @booking_request_id AS booking_request_id,
        N'approved' AS final_status_code;
END;
GO

-- ============================================================================
-- 5. Staff rejection procedure
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_RejectBookingRequest
    @staff_user_account_id INT,
    @booking_request_id INT,
    @rejection_reason NVARCHAR(1000),
    @decision_note NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @now DATETIME2(0) = SYSDATETIME();
    DECLARE @pending_status_id INT;
    DECLARE @rejected_status_id INT;
    DECLARE @staff_method_id INT;

    IF @staff_user_account_id IS NULL OR @staff_user_account_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @staff_user_account_id must be a positive integer.', 1;
    IF @booking_request_id IS NULL OR @booking_request_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @booking_request_id must be a positive integer.', 1;
    IF @rejection_reason IS NULL OR LEN(LTRIM(RTRIM(@rejection_reason))) = 0
        THROW 51232, 'REJECTION_REASON_REQUIRED: rejected decisions require a nonblank reason.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.USER_ACCOUNT AS ua
        INNER JOIN dbo.ROLE AS r ON r.role_id = ua.role_id
        WHERE ua.user_account_id = @staff_user_account_id
          AND r.role_name IN (N'facility staff', N'facility manager')
    )
        THROW 51231, 'STAFF_NOT_AUTHORIZED: staff decision maker must be facility staff or facility manager.', 1;

    BEGIN TRY
        SELECT @pending_status_id = booking_status_id
        FROM dbo.BOOKING_STATUS
        WHERE status_code = N'pending';

        SELECT @rejected_status_id = booking_status_id
        FROM dbo.BOOKING_STATUS
        WHERE status_code = N'rejected';

        SELECT @staff_method_id = approval_method_id
        FROM dbo.APPROVAL_METHOD
        WHERE method_code = N'staff_approval';

        IF @pending_status_id IS NULL OR @rejected_status_id IS NULL
            THROW 51211, 'REQUIRED_LOOKUP_MISSING: pending/rejected booking status code is missing.', 1;
        IF @staff_method_id IS NULL
            THROW 51211, 'REQUIRED_LOOKUP_MISSING: staff approval method code is missing.', 1;

        BEGIN TRANSACTION;

        UPDATE br
            SET booking_status_id = @rejected_status_id
        FROM dbo.BOOKING_REQUEST AS br WITH (UPDLOCK, HOLDLOCK)
        WHERE br.booking_request_id = @booking_request_id
          AND br.booking_status_id = @pending_status_id;

        IF @@ROWCOUNT <> 1
            THROW 51230, 'BOOKING_NOT_PENDING: booking request does not exist or is not pending.', 1;

        INSERT INTO dbo.APPROVAL_DECISION (
            booking_request_id,
            decided_by_user_account_id,
            decision_outcome_booking_status_id,
            decision_method_id,
            decision_time,
            decision_note,
            rejection_reason
        )
        VALUES (
            @booking_request_id,
            @staff_user_account_id,
            @rejected_status_id,
            @staff_method_id,
            @now,
            @decision_note,
            @rejection_reason
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;

    SELECT
        @booking_request_id AS booking_request_id,
        N'rejected' AS final_status_code;
END;
GO

-- ============================================================================
-- 6. Cancellation procedure
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_CancelBookingRequest
    @actor_user_account_id INT,
    @booking_request_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @attempt INT = 1;
    DECLARE @completed BIT = 0;
    DECLARE @space_id INT;
    DECLARE @current_status_code NVARCHAR(40);
    DECLARE @cancelled_status_id INT;

    IF @actor_user_account_id IS NULL OR @actor_user_account_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @actor_user_account_id must be a positive integer.', 1;
    IF @booking_request_id IS NULL OR @booking_request_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @booking_request_id must be a positive integer.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.USER_ACCOUNT WHERE user_account_id = @actor_user_account_id)
        THROW 51210, 'VALIDATION_ERROR: cancellation actor user account does not exist.', 1;

    WHILE @attempt <= 3 AND @completed = 0
    BEGIN
        BEGIN TRY
            SELECT @cancelled_status_id = booking_status_id
            FROM dbo.BOOKING_STATUS
            WHERE status_code = N'cancelled';

            IF @cancelled_status_id IS NULL
                THROW 51211, 'REQUIRED_LOOKUP_MISSING: cancelled booking status code is missing.', 1;

            BEGIN TRANSACTION;

            SELECT
                @space_id = br.space_id,
                @current_status_code = bs.status_code
            FROM dbo.BOOKING_REQUEST AS br WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN dbo.BOOKING_STATUS AS bs
                ON bs.booking_status_id = br.booking_status_id
            WHERE br.booking_request_id = @booking_request_id;

            IF @space_id IS NULL
                THROW 51240, 'INVALID_STATUS_TRANSITION: booking request does not exist.', 1;

            IF @current_status_code IN (N'approved', N'checked_in', N'completed')
                EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;

            IF @current_status_code IN (N'cancelled', N'rejected', N'no_show')
                THROW 51240, 'INVALID_STATUS_TRANSITION: booking is already in a terminal non-cancellable status.', 1;

            UPDATE dbo.BOOKING_REQUEST
                SET booking_status_id = @cancelled_status_id
            WHERE booking_request_id = @booking_request_id;

            COMMIT TRANSACTION;
            SET @completed = 1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;

            IF ERROR_NUMBER() IN (1205, 51204) AND @attempt < 3
            BEGIN
                SET @attempt += 1;
                SET @space_id = NULL;
                SET @current_status_code = NULL;
                CONTINUE;
            END;

            THROW;
        END CATCH;
    END;

    SELECT
        @booking_request_id AS booking_request_id,
        N'cancelled' AS final_status_code;
END;
GO

-- ============================================================================
-- 7. Maintenance impact change procedure
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_RecordMaintenanceImpactChange
    @staff_user_account_id INT,
    @maintenance_record_id INT,
    @new_impact_level_code NVARCHAR(40),
    @change_note NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @attempt INT = 1;
    DECLARE @completed BIT = 0;
    DECLARE @now DATETIME2(0);
    DECLARE @space_id INT;
    DECLARE @start_time DATETIME2(0);
    DECLARE @completion_time DATETIME2(0);
    DECLARE @old_impact_level_id INT;
    DECLARE @new_impact_level_id INT;

    DECLARE @affected TABLE (
        booking_request_id INT NOT NULL PRIMARY KEY,
        requester_user_account_id INT NOT NULL,
        requested_start_time DATETIME2(0) NOT NULL,
        requested_end_time DATETIME2(0) NOT NULL,
        status_code NVARCHAR(40) NOT NULL
    );

    IF @staff_user_account_id IS NULL OR @staff_user_account_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @staff_user_account_id must be a positive integer.', 1;
    IF @maintenance_record_id IS NULL OR @maintenance_record_id <= 0
        THROW 51210, 'VALIDATION_ERROR: @maintenance_record_id must be a positive integer.', 1;
    IF @new_impact_level_code IS NULL OR LEN(LTRIM(RTRIM(@new_impact_level_code))) = 0
        THROW 51210, 'VALIDATION_ERROR: @new_impact_level_code is required.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.USER_ACCOUNT AS ua
        INNER JOIN dbo.ROLE AS r ON r.role_id = ua.role_id
        WHERE ua.user_account_id = @staff_user_account_id
          AND r.role_name IN (N'facility staff', N'facility manager')
    )
        THROW 51231, 'STAFF_NOT_AUTHORIZED: maintenance impact changes require facility staff or facility manager.', 1;

    WHILE @attempt <= 3 AND @completed = 0
    BEGIN
        BEGIN TRY
            SET @now = SYSDATETIME();

            SELECT @new_impact_level_id = impact_level_id
            FROM dbo.MAINTENANCE_IMPACT_LEVEL
            WHERE impact_level_code = @new_impact_level_code;

            IF @new_impact_level_id IS NULL
                THROW 51211, 'REQUIRED_LOOKUP_MISSING: requested maintenance impact level code is missing.', 1;

            BEGIN TRANSACTION;

            SELECT
                @space_id = mr.space_id,
                @start_time = mr.start_time,
                @completion_time = mr.completion_time,
                @old_impact_level_id = mr.impact_level_id
            FROM dbo.MAINTENANCE_RECORD AS mr WITH (UPDLOCK, HOLDLOCK)
            WHERE mr.maintenance_record_id = @maintenance_record_id;

            IF @space_id IS NULL
                THROW 51250, 'MAINTENANCE_NOT_FOUND: maintenance record does not exist.', 1;

            EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;

            IF @old_impact_level_id = @new_impact_level_id
                THROW 51251, 'MAINTENANCE_IMPACT_UNCHANGED: requested impact level already matches current impact level.', 1;

            UPDATE dbo.MAINTENANCE_RECORD
                SET impact_level_id = @new_impact_level_id
            WHERE maintenance_record_id = @maintenance_record_id;

            INSERT INTO dbo.MAINTENANCE_IMPACT_EVENT (
                maintenance_record_id,
                old_impact_level_id,
                new_impact_level_id,
                changed_by_user_account_id,
                changed_at,
                change_note
            )
            VALUES (
                @maintenance_record_id,
                @old_impact_level_id,
                @new_impact_level_id,
                @staff_user_account_id,
                @now,
                @change_note
            );

            DELETE FROM @affected;

            IF @new_impact_level_code = N'out_of_service'
            BEGIN
                INSERT INTO @affected (
                    booking_request_id,
                    requester_user_account_id,
                    requested_start_time,
                    requested_end_time,
                    status_code
                )
                SELECT
                    br.booking_request_id,
                    br.requester_user_account_id,
                    br.requested_start_time,
                    br.requested_end_time,
                    bs.status_code
                FROM dbo.BOOKING_REQUEST AS br
                INNER JOIN dbo.BOOKING_STATUS AS bs
                    ON bs.booking_status_id = br.booking_status_id
                WHERE br.space_id = @space_id
                  AND bs.status_code IN (N'approved', N'checked_in', N'completed')
                  AND br.requested_start_time < ISNULL(@completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59'))
                  AND br.requested_end_time > @start_time;
            END;

            COMMIT TRANSACTION;
            SET @completed = 1;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0
                ROLLBACK TRANSACTION;

            IF ERROR_NUMBER() IN (1205, 51204) AND @attempt < 3
            BEGIN
                SET @attempt += 1;
                SET @space_id = NULL;
                SET @start_time = NULL;
                SET @completion_time = NULL;
                SET @old_impact_level_id = NULL;
                CONTINUE;
            END;

            THROW;
        END CATCH;
    END;

    SELECT
        booking_request_id,
        requester_user_account_id,
        requested_start_time,
        requested_end_time,
        status_code
    FROM @affected
    ORDER BY requested_start_time, booking_request_id;
END;
GO

-- ============================================================================
-- 8. Permission and bypass-control statements
-- ============================================================================
DENY INSERT, UPDATE, DELETE ON dbo.BOOKING_REQUEST TO G03BookingAppRole;
DENY INSERT, UPDATE, DELETE ON dbo.APPROVAL_DECISION TO G03BookingAppRole;
DENY INSERT, UPDATE, DELETE ON dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT TO G03BookingAppRole;
DENY INSERT, UPDATE, DELETE ON dbo.MAINTENANCE_RECORD TO G03BookingAppRole;
DENY INSERT, UPDATE, DELETE ON dbo.MAINTENANCE_IMPACT_EVENT TO G03BookingAppRole;

GRANT EXECUTE ON dbo.usp_G03_AcquireSpaceApprovalLock TO G03BookingAppRole;
GRANT EXECUTE ON dbo.usp_SubmitBookingRequest TO G03BookingAppRole;
GRANT EXECUTE ON dbo.usp_ApproveBookingRequest TO G03BookingAppRole;
GRANT EXECUTE ON dbo.usp_RejectBookingRequest TO G03BookingAppRole;
GRANT EXECUTE ON dbo.usp_CancelBookingRequest TO G03BookingAppRole;
GRANT EXECUTE ON dbo.usp_RecordMaintenanceImpactChange TO G03BookingAppRole;
GRANT REFERENCES ON TYPE::dbo.IntIdList TO G03BookingAppRole;
GO

-- ============================================================================
-- 9. Deployment verification queries
-- ============================================================================
SELECT
    p.name AS deployed_procedure
FROM sys.procedures AS p
WHERE p.schema_id = SCHEMA_ID(N'dbo')
  AND p.name IN (
      N'usp_G03_AcquireSpaceApprovalLock',
      N'usp_SubmitBookingRequest',
      N'usp_ApproveBookingRequest',
      N'usp_RejectBookingRequest',
      N'usp_CancelBookingRequest',
      N'usp_RecordMaintenanceImpactChange'
  )
ORDER BY p.name;

SELECT
    TYPE_NAME(TYPE_ID(N'dbo.IntIdList')) AS deployed_table_type,
    DATABASE_PRINCIPAL_ID(N'G03BookingAppRole') AS app_role_principal_id;

SELECT
    N'Artifact 12 deployment script loaded. Run artifact 13 two-session tests for concurrency evidence.' AS deployment_note;
GO
