:r 00-config.sql
/*
 Generate deterministic reference, user, space, facility, and semester data.
 Run after 99-cleanup-generated-data.sql when rerunning the dataset.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @run_prefix NVARCHAR(20) = N'$(G03_RUN_PREFIX)';
DECLARE @requester_count INT = $(G03_REQUESTER_COUNT);
DECLARE @staff_count INT = $(G03_STAFF_COUNT);
DECLARE @space_count INT = $(G03_SPACE_COUNT);
DECLARE @facility_count INT = $(G03_FACILITY_COUNT);

IF OBJECT_ID(N'dbo.ACADEMIC_SEMESTER', N'U') IS NULL
    THROW 51401, 'Missing dbo.ACADEMIC_SEMESTER. Run artifact 10 first.', 1;
IF OBJECT_ID(N'dbo.INSTANT_APPROVAL_SPACE_TYPE', N'U') IS NULL
    THROW 51401, 'Missing dbo.INSTANT_APPROVAL_SPACE_TYPE. Run artifact 10 first.', 1;

BEGIN TRANSACTION;

IF NOT EXISTS (SELECT 1 FROM dbo.ROLE WHERE role_name = N'student')
    INSERT INTO dbo.ROLE (role_name) VALUES (N'student');
IF NOT EXISTS (SELECT 1 FROM dbo.ROLE WHERE role_name = N'faculty')
    INSERT INTO dbo.ROLE (role_name) VALUES (N'faculty');
IF NOT EXISTS (SELECT 1 FROM dbo.ROLE WHERE role_name = N'facility staff')
    INSERT INTO dbo.ROLE (role_name) VALUES (N'facility staff');
IF NOT EXISTS (SELECT 1 FROM dbo.ROLE WHERE role_name = N'facility manager')
    INSERT INTO dbo.ROLE (role_name) VALUES (N'facility manager');

IF NOT EXISTS (SELECT 1 FROM dbo.ACCOUNT_STATUS WHERE status_name = N'Active')
    INSERT INTO dbo.ACCOUNT_STATUS (status_name) VALUES (N'Active');

IF NOT EXISTS (SELECT 1 FROM dbo.SPACE_STATUS WHERE status_name = N'Available')
    INSERT INTO dbo.SPACE_STATUS (status_name) VALUES (N'Available');
IF NOT EXISTS (SELECT 1 FROM dbo.SPACE_STATUS WHERE status_name = N'Under maintenance')
    INSERT INTO dbo.SPACE_STATUS (status_name) VALUES (N'Under maintenance');
IF NOT EXISTS (SELECT 1 FROM dbo.SPACE_STATUS WHERE status_name = N'Temporarily closed')
    INSERT INTO dbo.SPACE_STATUS (status_name) VALUES (N'Temporarily closed');
IF NOT EXISTS (SELECT 1 FROM dbo.SPACE_STATUS WHERE status_name = N'Retired')
    INSERT INTO dbo.SPACE_STATUS (status_name) VALUES (N'Retired');

IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_STATUS WHERE status_name = N'Open')
    INSERT INTO dbo.MAINTENANCE_STATUS (status_name) VALUES (N'Open');
IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_STATUS WHERE status_name = N'Completed')
    INSERT INTO dbo.MAINTENANCE_STATUS (status_name) VALUES (N'Completed');

IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'pending')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Pending', N'pending');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'approved')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Approved', N'approved');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'rejected')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Rejected', N'rejected');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'cancelled')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Cancelled', N'cancelled');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'checked_in')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Checked in', N'checked_in');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'completed')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Completed', N'completed');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'no_show')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'No-show', N'no_show');

IF NOT EXISTS (SELECT 1 FROM dbo.APPROVAL_METHOD WHERE method_code = N'staff_approval')
    INSERT INTO dbo.APPROVAL_METHOD (method_code, method_name) VALUES (N'staff_approval', N'staff approval');
IF NOT EXISTS (SELECT 1 FROM dbo.APPROVAL_METHOD WHERE method_code = N'instant_approval')
    INSERT INTO dbo.APPROVAL_METHOD (method_code, method_name) VALUES (N'instant_approval', N'instant approval');

IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'out_of_service')
    INSERT INTO dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_code, impact_level_name) VALUES (N'out_of_service', N'out-of-service');
IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'advisory')
    INSERT INTO dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_code, impact_level_name) VALUES (N'advisory', N'advisory');

IF NOT EXISTS (SELECT 1 FROM dbo.DEPARTMENT WHERE department_name = @run_prefix + N'-Department')
    INSERT INTO dbo.DEPARTMENT (department_name) VALUES (@run_prefix + N'-Department');

DECLARE @department_id INT = (SELECT department_id FROM dbo.DEPARTMENT WHERE department_name = @run_prefix + N'-Department');
DECLARE @student_role_id INT = (SELECT role_id FROM dbo.ROLE WHERE role_name = N'student');
DECLARE @faculty_role_id INT = (SELECT role_id FROM dbo.ROLE WHERE role_name = N'faculty');
DECLARE @staff_role_id INT = (SELECT role_id FROM dbo.ROLE WHERE role_name = N'facility staff');
DECLARE @active_account_status_id INT = (SELECT account_status_id FROM dbo.ACCOUNT_STATUS WHERE status_name = N'Active');
DECLARE @available_space_status_id INT = (SELECT space_status_id FROM dbo.SPACE_STATUS WHERE status_name = N'Available');

WITH n AS (
    SELECT TOP (@requester_count)
        ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) AS rn
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT INTO dbo.USER_ACCOUNT (user_id, full_name, email, phone_number, department_id, role_id, account_status_id)
SELECT
    CONCAT(@run_prefix, N'-REQ-', FORMAT(rn, '000000')),
    CONCAT(N'Generated Requester ', FORMAT(rn, '000000')),
    CONCAT(LOWER(@run_prefix), N'.req.', FORMAT(rn, '000000'), N'@example.edu'),
    CONCAT(N'09', FORMAT(rn, '00000000')),
    @department_id,
    CASE WHEN rn % 5 = 0 THEN @faculty_role_id ELSE @student_role_id END,
    @active_account_status_id
FROM n
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.USER_ACCOUNT AS ua
    WHERE ua.user_id = CONCAT(@run_prefix, N'-REQ-', FORMAT(n.rn, '000000'))
);

WITH n AS (
    SELECT TOP (@staff_count)
        ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) AS rn
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT INTO dbo.USER_ACCOUNT (user_id, full_name, email, phone_number, department_id, role_id, account_status_id)
SELECT
    CONCAT(@run_prefix, N'-STAFF-', FORMAT(rn, '000000')),
    CONCAT(N'Generated Facility Staff ', FORMAT(rn, '000000')),
    CONCAT(LOWER(@run_prefix), N'.staff.', FORMAT(rn, '000000'), N'@example.edu'),
    CONCAT(N'08', FORMAT(rn, '00000000')),
    @department_id,
    @staff_role_id,
    @active_account_status_id
FROM n
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.USER_ACCOUNT AS ua
    WHERE ua.user_id = CONCAT(@run_prefix, N'-STAFF-', FORMAT(n.rn, '000000'))
);

WITH n AS (
    SELECT TOP (@facility_count)
        ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) AS rn
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT INTO dbo.FACILITY (facility_name)
SELECT CONCAT(@run_prefix, N'-Facility-', FORMAT(rn, '00'))
FROM n
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.FACILITY AS f
    WHERE f.facility_name = CONCAT(@run_prefix, N'-Facility-', FORMAT(n.rn, '00'))
);

WITH n AS (
    SELECT TOP (@space_count)
        ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) AS rn
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
)
INSERT INTO dbo.SPACE (unique_space_code, space_name, space_type, building, floor, room_number, capacity, usage_policy, space_status_id)
SELECT
    CONCAT(@run_prefix, N'-SPACE-', FORMAT(rn, '000')),
    CONCAT(N'Generated Large Scale Space ', FORMAT(rn, '000')),
    CASE WHEN rn <= 16 THEN @run_prefix + N'-InstantType' ELSE @run_prefix + N'-StaffType' END,
    CONCAT(N'Generated Building ', ((rn - 1) / 5) + 1),
    CONVERT(NVARCHAR(50), ((rn - 1) % 5) + 1),
    FORMAT(rn, '000'),
    40 + ((rn - 1) % 6) * 20,
    N'Generated benchmark room; deterministic usage policy fixture.',
    @available_space_status_id
FROM n
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.SPACE AS s
    WHERE s.unique_space_code = CONCAT(@run_prefix, N'-SPACE-', FORMAT(n.rn, '000'))
);

INSERT INTO dbo.SPACE_FACILITY (space_id, facility_id)
SELECT s.space_id, f.facility_id
FROM dbo.SPACE AS s
CROSS JOIN dbo.FACILITY AS f
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND f.facility_name LIKE @run_prefix + N'-Facility-%'
  AND (ABS(CHECKSUM(s.unique_space_code, f.facility_name)) % 4) = 0
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.SPACE_FACILITY AS sf
      WHERE sf.space_id = s.space_id
        AND sf.facility_id = f.facility_id
  );

INSERT INTO dbo.INSTANT_APPROVAL_SPACE_TYPE (space_type, is_active, configured_at, configured_by_user_account_id, configuration_note)
SELECT @run_prefix + N'-InstantType', 1, CONVERT(DATETIME2(0), '2028-08-01T00:00:00'), MIN(ua.user_account_id), N'Generated large-scale instant approval configuration.'
FROM dbo.USER_ACCOUNT AS ua
WHERE ua.user_id LIKE @run_prefix + N'-STAFF-%'
HAVING NOT EXISTS (
    SELECT 1
    FROM dbo.INSTANT_APPROVAL_SPACE_TYPE AS iast
    WHERE iast.space_type = @run_prefix + N'-InstantType'
);

INSERT INTO dbo.ACADEMIC_SEMESTER (semester_code, academic_year_label, semester_name, semester_start_date, semester_end_date)
SELECT v.semester_code, v.academic_year_label, v.semester_name, v.semester_start_date, v.semester_end_date
FROM (VALUES
    (@run_prefix + N'-2028-S1', N'2028-2029', N'Semester 1', CONVERT(DATE, '2028-08-19'), CONVERT(DATE, '2028-12-31')),
    (@run_prefix + N'-2028-S2', N'2028-2029', N'Semester 2', CONVERT(DATE, '2029-01-05'), CONVERT(DATE, '2029-05-31')),
    (@run_prefix + N'-2029-S1', N'2029-2030', N'Semester 1', CONVERT(DATE, '2029-08-18'), CONVERT(DATE, '2029-12-31')),
    (@run_prefix + N'-2029-S2', N'2029-2030', N'Semester 2', CONVERT(DATE, '2030-01-05'), CONVERT(DATE, '2030-05-31')),
    (@run_prefix + N'-2030-S1', N'2030-2031', N'Semester 1', CONVERT(DATE, '2030-08-17'), CONVERT(DATE, '2030-12-31')),
    (@run_prefix + N'-2030-S2', N'2030-2031', N'Semester 2', CONVERT(DATE, '2031-01-05'), CONVERT(DATE, '2031-05-31'))
) AS v(semester_code, academic_year_label, semester_name, semester_start_date, semester_end_date)
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.ACADEMIC_SEMESTER AS sem
    WHERE sem.semester_code = v.semester_code
);

COMMIT TRANSACTION;

SELECT
    @run_prefix AS run_prefix,
    (SELECT COUNT(*) FROM dbo.USER_ACCOUNT WHERE user_id LIKE @run_prefix + N'-REQ-%') AS requester_count,
    (SELECT COUNT(*) FROM dbo.USER_ACCOUNT WHERE user_id LIKE @run_prefix + N'-STAFF-%') AS staff_count,
    (SELECT COUNT(*) FROM dbo.SPACE WHERE unique_space_code LIKE @run_prefix + N'-SPACE-%') AS space_count,
    (SELECT COUNT(*) FROM dbo.FACILITY WHERE facility_name LIKE @run_prefix + N'-Facility-%') AS facility_count,
    (SELECT COUNT(*) FROM dbo.ACADEMIC_SEMESTER WHERE semester_code LIKE @run_prefix + N'-%') AS semester_count;
