/*
 Group 03 Phase 2 concurrency test cleanup.
 Deletes only G03-CT-* fixture rows in FK-safe order.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRANSACTION;

DELETE baa
FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = baa.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE ad
FROM dbo.APPROVAL_DECISION AS ad
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = ad.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE br
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE mie
FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
INNER JOIN dbo.MAINTENANCE_RECORD AS mr ON mr.maintenance_record_id = mie.maintenance_record_id
INNER JOIN dbo.SPACE AS s ON s.space_id = mr.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE mr
FROM dbo.MAINTENANCE_RECORD AS mr
INNER JOIN dbo.SPACE AS s ON s.space_id = mr.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE FROM dbo.INSTANT_APPROVAL_SPACE_TYPE
WHERE space_type = N'G03-CT-InstantType';

DELETE FROM dbo.SPACE
WHERE unique_space_code LIKE N'G03-CT-%';

DELETE FROM dbo.USER_ACCOUNT
WHERE user_id LIKE N'G03-CT-%';

DELETE FROM dbo.DEPARTMENT
WHERE department_name = N'G03-CT-DEPT';

COMMIT TRANSACTION;

SELECT N'G03 concurrency fixture cleanup complete' AS cleanup_status;
