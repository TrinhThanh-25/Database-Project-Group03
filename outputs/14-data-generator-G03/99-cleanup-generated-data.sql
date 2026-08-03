:r 00-config.sql
/*
 Cleanup generated large-scale data.
 Targets only rows identifiable by the configured G03-LS run prefix.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @run_prefix NVARCHAR(20) = N'$(G03_RUN_PREFIX)';
DECLARE @base_date DATE = CONVERT(DATE, '$(G03_BASE_DATE)');

BEGIN TRANSACTION;

DELETE baa
FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = baa.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%';

DELETE baa
FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
INNER JOIN dbo.MAINTENANCE_RECORD AS mr ON mr.maintenance_record_id = baa.maintenance_record_id
WHERE mr.problem_description LIKE @run_prefix + N'%';

DELETE us
FROM dbo.USAGE_SESSION AS us
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = us.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%';

DELETE ad
FROM dbo.APPROVAL_DECISION AS ad
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = ad.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%';

DELETE br
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%';

DELETE mie
FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
INNER JOIN dbo.MAINTENANCE_RECORD AS mr ON mr.maintenance_record_id = mie.maintenance_record_id
WHERE mr.problem_description LIKE @run_prefix + N'%';

DELETE mr
FROM dbo.MAINTENANCE_RECORD AS mr
WHERE mr.problem_description LIKE @run_prefix + N'%';

DELETE sf
FROM dbo.SPACE_FACILITY AS sf
INNER JOIN dbo.SPACE AS s ON s.space_id = sf.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%';

DELETE FROM dbo.INSTANT_APPROVAL_SPACE_TYPE
WHERE space_type IN (@run_prefix + N'-InstantType', @run_prefix + N'-StaffType');

DELETE FROM dbo.SPACE
WHERE unique_space_code LIKE @run_prefix + N'-SPACE-%';

DELETE FROM dbo.FACILITY
WHERE facility_name LIKE @run_prefix + N'-Facility-%';

DELETE FROM dbo.USER_ACCOUNT
WHERE user_id LIKE @run_prefix + N'-REQ-%'
   OR user_id LIKE @run_prefix + N'-STAFF-%';

DELETE FROM dbo.DEPARTMENT
WHERE department_name = @run_prefix + N'-Department';

DELETE FROM dbo.ACADEMIC_SEMESTER
WHERE semester_code LIKE @run_prefix + N'-%';

COMMIT TRANSACTION;

SELECT @run_prefix AS cleaned_run_prefix, N'Generated large-scale data cleanup complete' AS cleanup_status;
