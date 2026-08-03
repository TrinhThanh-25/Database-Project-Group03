/*
 Unsafe race demonstration - Session B.

 Start this while 01-unsafe-session-a.sql is waiting before its naive insert.
 Expected result: Session B observes no committed conflict and commits its own
 overlapping approved row.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

WAITFOR DELAY '00:00:03';

DECLARE @space_id INT = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-UNSAFE');
DECLARE @requester_id INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-B');
DECLARE @approved_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'approved');

IF @space_id IS NULL OR @requester_id IS NULL OR @approved_status_id IS NULL
    THROW 51302, 'Unsafe Session B prerequisite missing. Run 00-setup.sql.', 1;

BEGIN TRANSACTION;

SELECT COUNT(*) AS session_b_observed_committed_conflicts_before_write
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
WHERE br.space_id = @space_id
  AND bs.status_code IN (N'approved', N'checked_in', N'completed')
  AND br.requested_start_time < CONVERT(DATETIME2(0), '2031-01-10T11:30:00')
  AND br.requested_end_time > CONVERT(DATETIME2(0), '2031-01-10T10:30:00');

INSERT INTO dbo.BOOKING_REQUEST (requester_user_account_id, space_id, booking_status_id, requested_start_time, requested_end_time, purpose_of_use, expected_number_of_participants)
VALUES (@requester_id, @space_id, @approved_status_id, CONVERT(DATETIME2(0), '2031-01-10T10:30:00'), CONVERT(DATETIME2(0), '2031-01-10T11:30:00'), N'meeting', 5);

COMMIT TRANSACTION;

SELECT N'Unsafe Session B committed' AS session_b_result;
