/*
 Rollback release regression - Session B.
 Start while 10-rollback-session-a.sql is holding the same-space app lock.
 Expected: succeeds after Session A rolls back.
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

WAITFOR DELAY '00:00:02';

DECLARE @ack dbo.IntIdList;
DECLARE @booking_id INT;
DECLARE @status_code NVARCHAR(40);
DECLARE @space_id INT = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-ROLLBACK');
DECLARE @requester_id INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-B');

BEGIN TRY
    EXEC dbo.usp_SubmitBookingRequest
        @requester_user_account_id = @requester_id,
        @space_id = @space_id,
        @requested_start_time = '2031-04-02T10:30:00',
        @requested_end_time = '2031-04-02T11:30:00',
        @purpose_of_use = N'meeting',
        @expected_number_of_participants = 5,
        @acknowledged_advisory_maintenance_ids = @ack,
        @booking_request_id = @booking_id OUTPUT,
        @final_status_code = @status_code OUTPUT,
        @request_instant_approval = 1,
        @usage_policy_satisfied = 1;
    SELECT N'Rollback Session B expected success' AS result, @booking_id AS booking_request_id, @status_code AS final_status_code;
END TRY
BEGIN CATCH
    SELECT N'Rollback Session B unexpected error' AS result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;
