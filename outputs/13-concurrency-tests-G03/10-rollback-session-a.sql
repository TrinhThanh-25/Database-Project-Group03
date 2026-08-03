/*
 Rollback release regression - Session A.
 Start this first, then run 11-rollback-session-b.sql in Window B.
 Expected: Session B waits while this transaction is open, then succeeds after rollback.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @ack dbo.IntIdList;
DECLARE @booking_id INT;
DECLARE @status_code NVARCHAR(40);
DECLARE @space_id INT = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-ROLLBACK');
DECLARE @requester_id INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-A');

IF @space_id IS NULL OR @requester_id IS NULL
    THROW 51310, 'Rollback Session A prerequisite missing. Run 00-setup.sql.', 1;

BEGIN TRANSACTION;
EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;
EXEC dbo.usp_SubmitBookingRequest
    @requester_user_account_id = @requester_id,
    @space_id = @space_id,
    @requested_start_time = '2031-04-02T10:00:00',
    @requested_end_time = '2031-04-02T11:00:00',
    @purpose_of_use = N'meeting',
    @expected_number_of_participants = 5,
    @acknowledged_advisory_maintenance_ids = @ack,
    @booking_request_id = @booking_id OUTPUT,
    @final_status_code = @status_code OUTPUT,
    @request_instant_approval = 1,
    @usage_policy_satisfied = 1;
PRINT 'Rollback Session A inserted inside an outer transaction and will roll back after 6 seconds. Start 11-rollback-session-b.sql now.';
WAITFOR DELAY '00:00:06';
ROLLBACK TRANSACTION;

SELECT N'Rollback Session A rolled back' AS result, @booking_id AS rolled_back_booking_request_id;
