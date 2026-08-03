/*
 Safe concurrency tests - Session A.

 Window order:
   1. Run 99-cleanup.sql and 00-setup.sql.
   2. Start this script in Window A.
   3. When prompted, start 05-safe-session-b.sql in Window B.
   4. After both finish, run 06-safe-verify.sql.

 Session A deliberately wraps production procedure calls in an outer transaction
 and holds the transaction-owned app lock briefly. This is test choreography
 only; production procedures are not altered.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT 'Safe Session A starting. Start 05-safe-session-b.sql in Window B now.';

/* S1: instant vs instant, same space. */
DECLARE @ack dbo.IntIdList;
DECLARE @booking_id INT;
DECLARE @status_code NVARCHAR(40);
DECLARE @space_id INT = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-A');
DECLARE @requester_id INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-A');

BEGIN TRANSACTION;
EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;
EXEC dbo.usp_SubmitBookingRequest
    @requester_user_account_id = @requester_id,
    @space_id = @space_id,
    @requested_start_time = '2031-02-01T10:00:00',
    @requested_end_time = '2031-02-01T11:00:00',
    @purpose_of_use = N'meeting',
    @expected_number_of_participants = 5,
    @acknowledged_advisory_maintenance_ids = @ack,
    @booking_request_id = @booking_id OUTPUT,
    @final_status_code = @status_code OUTPUT,
    @request_instant_approval = 1,
    @usage_policy_satisfied = 1;
PRINT 'S1 Session A approved instant booking and is holding the transaction for 6 seconds.';
WAITFOR DELAY '00:00:06';
COMMIT TRANSACTION;
SELECT N'S1 Session A committed' AS result, @booking_id AS booking_request_id, @status_code AS final_status_code;

WAITFOR DELAY '00:00:02';

/* S2: staff approval vs instant, same space. */
DECLARE @staff_id INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-STAFF-A');
DECLARE @pending_s2_id INT = (
    SELECT br.booking_request_id
    FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
    WHERE s.unique_space_code = N'G03-CT-SAFE-B'
      AND br.requested_start_time = CONVERT(DATETIME2(0), '2031-02-02T10:00:00')
);
SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-B');

BEGIN TRANSACTION;
EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;
EXEC dbo.usp_ApproveBookingRequest
    @staff_user_account_id = @staff_id,
    @booking_request_id = @pending_s2_id,
    @decision_note = N'S2 staff approval by Session A.',
    @acknowledged_advisory_maintenance_ids = @ack;
PRINT 'S2 Session A approved pending booking and is holding the transaction for 6 seconds.';
WAITFOR DELAY '00:00:06';
COMMIT TRANSACTION;
SELECT N'S2 Session A committed' AS result, @pending_s2_id AS booking_request_id;

WAITFOR DELAY '00:00:02';

/* S3: staff approval vs staff approval, same space. */
DECLARE @pending_s3_a_id INT = (
    SELECT br.booking_request_id
    FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
    INNER JOIN dbo.USER_ACCOUNT AS ua ON ua.user_account_id = br.requester_user_account_id
    WHERE s.unique_space_code = N'G03-CT-SAFE-C'
      AND ua.user_id = N'G03-CT-REQ-A'
      AND br.requested_start_time = CONVERT(DATETIME2(0), '2031-02-03T10:00:00')
);
SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-C');

BEGIN TRANSACTION;
EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;
EXEC dbo.usp_ApproveBookingRequest
    @staff_user_account_id = @staff_id,
    @booking_request_id = @pending_s3_a_id,
    @decision_note = N'S3 staff approval by Session A.',
    @acknowledged_advisory_maintenance_ids = @ack;
PRINT 'S3 Session A approved pending booking and is holding the transaction for 6 seconds.';
WAITFOR DELAY '00:00:06';
COMMIT TRANSACTION;
SELECT N'S3 Session A committed' AS result, @pending_s3_a_id AS booking_request_id;
