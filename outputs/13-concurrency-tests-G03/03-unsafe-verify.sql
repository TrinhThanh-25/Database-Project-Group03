/*
 Unsafe verification.
 Expected after 01/02: violation_pair_count >= 1.
*/

SET NOCOUNT ON;

DECLARE @space_id INT = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-UNSAFE');

IF @space_id IS NULL
    THROW 51303, 'Unsafe verification prerequisite missing. Run 00-setup.sql.', 1;

SELECT
    COUNT(*) AS approved_fixture_rows
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
WHERE br.space_id = @space_id
  AND bs.status_code IN (N'approved', N'checked_in', N'completed');

SELECT
    COUNT(*) AS violation_pair_count
FROM dbo.BOOKING_REQUEST AS a
INNER JOIN dbo.BOOKING_STATUS AS ast ON ast.booking_status_id = a.booking_status_id
INNER JOIN dbo.BOOKING_REQUEST AS b ON b.booking_request_id > a.booking_request_id
INNER JOIN dbo.BOOKING_STATUS AS bst ON bst.booking_status_id = b.booking_status_id
WHERE a.space_id = @space_id
  AND b.space_id = @space_id
  AND ast.status_code IN (N'approved', N'checked_in', N'completed')
  AND bst.status_code IN (N'approved', N'checked_in', N'completed')
  AND a.requested_start_time < b.requested_end_time
  AND a.requested_end_time > b.requested_start_time;

SELECT
    a.booking_request_id AS booking_a,
    b.booking_request_id AS booking_b,
    a.requested_start_time AS a_start,
    a.requested_end_time AS a_end,
    b.requested_start_time AS b_start,
    b.requested_end_time AS b_end
FROM dbo.BOOKING_REQUEST AS a
INNER JOIN dbo.BOOKING_REQUEST AS b ON b.booking_request_id > a.booking_request_id
WHERE a.space_id = @space_id
  AND b.space_id = @space_id
  AND a.requested_start_time < b.requested_end_time
  AND a.requested_end_time > b.requested_start_time;
