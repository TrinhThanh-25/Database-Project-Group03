/*
 Verification for timeout and rollback regression scripts.
*/

SET NOCOUNT ON;

SELECT
    s.unique_space_code,
    bs.status_code,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code IN (N'G03-CT-TIMEOUT', N'G03-CT-ROLLBACK')
GROUP BY s.unique_space_code, bs.status_code
ORDER BY s.unique_space_code, bs.status_code;

SELECT
    COUNT(*) AS timeout_partial_booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
INNER JOIN dbo.USER_ACCOUNT AS ua ON ua.user_account_id = br.requester_user_account_id
WHERE s.unique_space_code = N'G03-CT-TIMEOUT'
  AND ua.user_id = N'G03-CT-REQ-C'
  AND br.requested_start_time = CONVERT(DATETIME2(0), '2031-04-01T10:00:00');

SELECT
    COUNT(*) AS rollback_expected_committed_booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
INNER JOIN dbo.USER_ACCOUNT AS ua ON ua.user_account_id = br.requester_user_account_id
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
WHERE s.unique_space_code = N'G03-CT-ROLLBACK'
  AND ua.user_id = N'G03-CT-REQ-B'
  AND bs.status_code = N'approved'
  AND br.requested_start_time = CONVERT(DATETIME2(0), '2031-04-02T10:30:00');
