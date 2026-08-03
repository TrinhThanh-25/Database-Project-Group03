/*
 Safe concurrency tests - Session B.

 Start immediately after 04-safe-session-a.sql prints its start message.
 Expected same-space overlap attempts return 51220 after Session A commits.
 The different-space attempt should succeed while Session A holds SAFE-A.
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

WAITFOR DELAY '00:00:02';

DECLARE @ack dbo.IntIdList;
DECLARE @booking_id INT;
DECLARE @status_code NVARCHAR(40);
DECLARE @requester_id INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-B');
DECLARE @space_id INT;

/* Different-space independence while Session A holds G03-CT-SAFE-A. */
BEGIN TRY
    SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-DIFF');
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
    SELECT N'S0 different-space succeeded' AS result, @booking_id AS booking_request_id, @status_code AS final_status_code;
END TRY
BEGIN CATCH
    SELECT N'S0 unexpected error' AS result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;

/* S1: instant vs instant same-space overlap. */
BEGIN TRY
    SET @booking_id = NULL;
    SET @status_code = NULL;
    SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-A');
    EXEC dbo.usp_SubmitBookingRequest
        @requester_user_account_id = @requester_id,
        @space_id = @space_id,
        @requested_start_time = '2031-02-01T10:30:00',
        @requested_end_time = '2031-02-01T11:30:00',
        @purpose_of_use = N'meeting',
        @expected_number_of_participants = 5,
        @acknowledged_advisory_maintenance_ids = @ack,
        @booking_request_id = @booking_id OUTPUT,
        @final_status_code = @status_code OUTPUT,
        @request_instant_approval = 1,
        @usage_policy_satisfied = 1;
    SELECT N'S1 unexpected success' AS result, @booking_id AS booking_request_id, @status_code AS final_status_code;
END TRY
BEGIN CATCH
    SELECT N'S1 expected same-space conflict' AS result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;

WAITFOR DELAY '00:00:02';

/* S2: staff approval vs instant same-space overlap. */
BEGIN TRY
    SET @booking_id = NULL;
    SET @status_code = NULL;
    SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-B');
    EXEC dbo.usp_SubmitBookingRequest
        @requester_user_account_id = @requester_id,
        @space_id = @space_id,
        @requested_start_time = '2031-02-02T10:30:00',
        @requested_end_time = '2031-02-02T11:30:00',
        @purpose_of_use = N'meeting',
        @expected_number_of_participants = 5,
        @acknowledged_advisory_maintenance_ids = @ack,
        @booking_request_id = @booking_id OUTPUT,
        @final_status_code = @status_code OUTPUT,
        @request_instant_approval = 1,
        @usage_policy_satisfied = 1;
    SELECT N'S2 unexpected success' AS result, @booking_id AS booking_request_id, @status_code AS final_status_code;
END TRY
BEGIN CATCH
    SELECT N'S2 expected same-space conflict' AS result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;

WAITFOR DELAY '00:00:02';

/* S3: staff approval vs staff approval same-space overlap. */
BEGIN TRY
    DECLARE @staff_b_id INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-STAFF-B');
    DECLARE @pending_s3_b_id INT = (
        SELECT br.booking_request_id
        FROM dbo.BOOKING_REQUEST AS br
        INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
        INNER JOIN dbo.USER_ACCOUNT AS ua ON ua.user_account_id = br.requester_user_account_id
        WHERE s.unique_space_code = N'G03-CT-SAFE-C'
          AND ua.user_id = N'G03-CT-REQ-B'
          AND br.requested_start_time = CONVERT(DATETIME2(0), '2031-02-03T10:30:00')
    );
    EXEC dbo.usp_ApproveBookingRequest
        @staff_user_account_id = @staff_b_id,
        @booking_request_id = @pending_s3_b_id,
        @decision_note = N'S3 staff approval by Session B.',
        @acknowledged_advisory_maintenance_ids = @ack;
    SELECT N'S3 unexpected success' AS result, @pending_s3_b_id AS booking_request_id;
END TRY
BEGIN CATCH
    SELECT N'S3 expected same-space conflict' AS result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;
