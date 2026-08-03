/*
 Safe verification.
 Expected after 04/05: no overlapping committed approved pairs for SAFE-* same-space fixtures.
*/

SET NOCOUNT ON;

SELECT
    s.unique_space_code,
    bs.status_code,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE N'G03-CT-SAFE%'
GROUP BY s.unique_space_code, bs.status_code
ORDER BY s.unique_space_code, bs.status_code;

SELECT
    COUNT(*) AS safe_violation_pair_count
FROM dbo.BOOKING_REQUEST AS a
INNER JOIN dbo.BOOKING_STATUS AS ast ON ast.booking_status_id = a.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = a.space_id
INNER JOIN dbo.BOOKING_REQUEST AS b ON b.booking_request_id > a.booking_request_id AND b.space_id = a.space_id
INNER JOIN dbo.BOOKING_STATUS AS bst ON bst.booking_status_id = b.booking_status_id
WHERE s.unique_space_code LIKE N'G03-CT-SAFE%'
  AND ast.status_code IN (N'approved', N'checked_in', N'completed')
  AND bst.status_code IN (N'approved', N'checked_in', N'completed')
  AND a.requested_start_time < b.requested_end_time
  AND a.requested_end_time > b.requested_start_time;

SELECT
    s.unique_space_code,
    br.booking_request_id,
    bs.status_code,
    br.requested_start_time,
    br.requested_end_time
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE N'G03-CT-SAFE%'
ORDER BY s.unique_space_code, br.requested_start_time, br.booking_request_id;
