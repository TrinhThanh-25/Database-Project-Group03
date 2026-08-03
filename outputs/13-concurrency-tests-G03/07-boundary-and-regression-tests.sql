/*
 Single-session boundary and regression tests.

 Run after 99-cleanup.sql and 00-setup.sql.
 Expected errors are captured with TRY/CATCH so the script can continue.
*/

SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @ack dbo.IntIdList;
DECLARE @booking_id INT;
DECLARE @status_code NVARCHAR(40);
DECLARE @requester_a INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-A');
DECLARE @requester_b INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-B');
DECLARE @staff_a INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-STAFF-A');
DECLARE @space_id INT;

/* Adjacent intervals: [10:00, 11:00) and [11:00, 12:00) are both allowed. */
BEGIN TRY
    SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-BOUNDARY');
    EXEC dbo.usp_SubmitBookingRequest @requester_a, @space_id, '2031-03-01T10:00:00', '2031-03-01T11:00:00', N'meeting', 5, @ack, @booking_id OUTPUT, @status_code OUTPUT, 1, 1;
    EXEC dbo.usp_SubmitBookingRequest @requester_b, @space_id, '2031-03-01T11:00:00', '2031-03-01T12:00:00', N'meeting', 5, @ack, @booking_id OUTPUT, @status_code OUTPUT, 1, 1;
    SELECT N'Adjacent intervals allowed' AS test_result;
END TRY
BEGIN CATCH
    SELECT N'Adjacent intervals unexpected error' AS test_result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;

/* Same time, different spaces: both allowed. */
BEGIN TRY
    SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-DIFF-A');
    EXEC dbo.usp_SubmitBookingRequest @requester_a, @space_id, '2031-03-02T10:00:00', '2031-03-02T11:00:00', N'meeting', 5, @ack, @booking_id OUTPUT, @status_code OUTPUT, 1, 1;
    SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-DIFF-B');
    EXEC dbo.usp_SubmitBookingRequest @requester_b, @space_id, '2031-03-02T10:00:00', '2031-03-02T11:00:00', N'meeting', 5, @ack, @booking_id OUTPUT, @status_code OUTPUT, 1, 1;
    SELECT N'Different spaces allowed' AS test_result;
END TRY
BEGIN CATCH
    SELECT N'Different spaces unexpected error' AS test_result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;

/* Out-of-service maintenance blocks overlapping approval. */
BEGIN TRY
    SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-MAINT');
    INSERT INTO dbo.MAINTENANCE_RECORD (space_id, reported_by_user_account_id, assigned_to_user_account_id, maintenance_status_id, impact_level_id, problem_description, start_time, completion_time, result_note)
    VALUES (
        @space_id,
        @staff_a,
        @staff_a,
        (SELECT maintenance_status_id FROM dbo.MAINTENANCE_STATUS WHERE status_name = N'Open'),
        (SELECT impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'out_of_service'),
        N'G03-CT out-of-service blocking fixture',
        '2031-03-03T09:00:00',
        '2031-03-03T12:00:00',
        NULL
    );

    EXEC dbo.usp_SubmitBookingRequest @requester_a, @space_id, '2031-03-03T10:00:00', '2031-03-03T11:00:00', N'meeting', 5, @ack, @booking_id OUTPUT, @status_code OUTPUT, 1, 1;
    SELECT N'Out-of-service unexpected success' AS test_result;
END TRY
BEGIN CATCH
    SELECT N'Out-of-service expected error' AS test_result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;

/* Advisory without acknowledgement fails, then succeeds with acknowledgement and writes one ack row. */
BEGIN TRY
    SET @space_id = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-ADVISORY');
    DECLARE @advisory_record_id INT;

    INSERT INTO dbo.MAINTENANCE_RECORD (space_id, reported_by_user_account_id, assigned_to_user_account_id, maintenance_status_id, impact_level_id, problem_description, start_time, completion_time, result_note)
    VALUES (
        @space_id,
        @staff_a,
        @staff_a,
        (SELECT maintenance_status_id FROM dbo.MAINTENANCE_STATUS WHERE status_name = N'Open'),
        (SELECT impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'advisory'),
        N'G03-CT advisory acknowledgement fixture',
        '2031-03-04T09:00:00',
        '2031-03-04T12:00:00',
        NULL
    );

    SET @advisory_record_id = CONVERT(INT, SCOPE_IDENTITY());

    BEGIN TRY
        DELETE FROM @ack;
        EXEC dbo.usp_SubmitBookingRequest @requester_a, @space_id, '2031-03-04T10:00:00', '2031-03-04T11:00:00', N'meeting', 5, @ack, @booking_id OUTPUT, @status_code OUTPUT, 1, 1;
        SELECT N'Advisory missing-ack unexpected success' AS test_result;
    END TRY
    BEGIN CATCH
        SELECT N'Advisory missing-ack expected error' AS test_result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
    END CATCH;

    DELETE FROM @ack;
    INSERT INTO @ack (id) VALUES (@advisory_record_id);
    EXEC dbo.usp_SubmitBookingRequest @requester_b, @space_id, '2031-03-04T10:00:00', '2031-03-04T11:00:00', N'meeting', 5, @ack, @booking_id OUTPUT, @status_code OUTPUT, 1, 1;

    SELECT
        N'Advisory acknowledged success' AS test_result,
        @booking_id AS booking_request_id,
        COUNT(*) AS acknowledgement_rows
    FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT
    WHERE booking_request_id = @booking_id;
END TRY
BEGIN CATCH
    SELECT N'Advisory acknowledged unexpected error' AS test_result, ERROR_NUMBER() AS error_number, ERROR_MESSAGE() AS error_message;
END CATCH;

/* Final invariant check for regression fixture spaces. */
SELECT
    COUNT(*) AS regression_violation_pair_count
FROM dbo.BOOKING_REQUEST AS a
INNER JOIN dbo.BOOKING_STATUS AS ast ON ast.booking_status_id = a.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = a.space_id
INNER JOIN dbo.BOOKING_REQUEST AS b ON b.booking_request_id > a.booking_request_id AND b.space_id = a.space_id
INNER JOIN dbo.BOOKING_STATUS AS bst ON bst.booking_status_id = b.booking_status_id
WHERE s.unique_space_code LIKE N'G03-CT-%'
  AND ast.status_code IN (N'approved', N'checked_in', N'completed')
  AND bst.status_code IN (N'approved', N'checked_in', N'completed')
  AND a.requested_start_time < b.requested_end_time
  AND a.requested_end_time > b.requested_start_time;
