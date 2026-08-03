/*
 Unsafe race demonstration - Session A.

 Window order:
   1. Run 00-setup.sql.
   2. Start this script in Window A.
   3. When the PRINT message appears, immediately run 02-unsafe-session-b.sql
      in Window B.
   4. After both finish, run 03-unsafe-verify.sql.

 This script intentionally uses naive direct table writes and WAITFOR in test
 code only. It does not modify production procedures.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @space_id INT = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-UNSAFE');
DECLARE @requester_id INT = (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-A');
DECLARE @approved_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'approved');

IF @space_id IS NULL OR @requester_id IS NULL OR @approved_status_id IS NULL
    THROW 51301, 'Unsafe Session A prerequisite missing. Run 00-setup.sql.', 1;

BEGIN TRANSACTION;

SELECT COUNT(*) AS session_a_observed_conflicts_before_write
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
WHERE br.space_id = @space_id
  AND bs.status_code IN (N'approved', N'checked_in', N'completed')
  AND br.requested_start_time < CONVERT(DATETIME2(0), '2031-01-10T11:00:00')
  AND br.requested_end_time > CONVERT(DATETIME2(0), '2031-01-10T10:00:00');

PRINT 'Session A is paused before its naive insert. Start 02-unsafe-session-b.sql in Window B now.';
WAITFOR DELAY '00:00:08';

INSERT INTO dbo.BOOKING_REQUEST (requester_user_account_id, space_id, booking_status_id, requested_start_time, requested_end_time, purpose_of_use, expected_number_of_participants)
VALUES (@requester_id, @space_id, @approved_status_id, CONVERT(DATETIME2(0), '2031-01-10T10:00:00'), CONVERT(DATETIME2(0), '2031-01-10T11:00:00'), N'meeting', 5);

PRINT 'Session A inserted its approved row and is paused before commit.';
WAITFOR DELAY '00:00:08';

COMMIT TRANSACTION;

SELECT N'Unsafe Session A committed' AS session_a_result;
