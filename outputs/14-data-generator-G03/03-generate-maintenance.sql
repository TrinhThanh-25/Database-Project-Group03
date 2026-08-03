:r 00-config.sql
/*
 Generate deterministic maintenance records and impact history.
 Includes advisory, out-of-service off-hour, and labelled later escalation cases.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @run_prefix NVARCHAR(20) = N'$(G03_RUN_PREFIX)';
DECLARE @base_date DATE = CONVERT(DATE, '$(G03_BASE_DATE)');

DECLARE @staff_id INT = (
    SELECT MIN(user_account_id)
    FROM dbo.USER_ACCOUNT
    WHERE user_id LIKE @run_prefix + N'-STAFF-%'
);
DECLARE @open_status_id INT = (SELECT maintenance_status_id FROM dbo.MAINTENANCE_STATUS WHERE status_name = N'Open');
DECLARE @advisory_impact_id INT = (SELECT impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'advisory');
DECLARE @out_impact_id INT = (SELECT impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'out_of_service');

IF @staff_id IS NULL OR @open_status_id IS NULL OR @advisory_impact_id IS NULL OR @out_impact_id IS NULL
    THROW 51430, 'Maintenance generator prerequisites missing. Run 01 and 02 first.', 1;

BEGIN TRANSACTION;

/* Current advisory records overlapping generated booking slots. */
WITH approved_bookings AS (
    SELECT TOP (300)
        br.booking_request_id,
        br.space_id,
        br.requested_start_time,
        br.requested_end_time,
        ROW_NUMBER() OVER (ORDER BY br.booking_request_id) AS rn
    FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
    WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
      AND bs.status_code IN (N'approved', N'checked_in', N'completed')
    ORDER BY br.booking_request_id
)
INSERT INTO dbo.MAINTENANCE_RECORD (
    space_id,
    reported_by_user_account_id,
    assigned_to_user_account_id,
    maintenance_status_id,
    impact_level_id,
    problem_description,
    start_time,
    completion_time,
    result_note
)
SELECT
    ab.space_id,
    @staff_id,
    @staff_id,
    @open_status_id,
    @advisory_impact_id,
    CONCAT(@run_prefix, N' advisory maintenance ', FORMAT(ab.rn, '000000')),
    ab.requested_start_time,
    ab.requested_end_time,
    N'Generated advisory fixture; booking permitted with acknowledgement.'
FROM approved_bookings AS ab
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.MAINTENANCE_RECORD AS mr
    WHERE mr.problem_description = CONCAT(@run_prefix, N' advisory maintenance ', FORMAT(ab.rn, '000000'))
);

/* Current out-of-service records in off-hour windows, not overlapping generated booking slots. */
WITH n AS (
    SELECT TOP (200)
        ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) AS rn
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
),
spaces AS (
    SELECT
        space_id,
        ROW_NUMBER() OVER (ORDER BY unique_space_code) AS space_ordinal,
        COUNT(*) OVER () AS space_count
    FROM dbo.SPACE
    WHERE unique_space_code LIKE @run_prefix + N'-SPACE-%'
)
INSERT INTO dbo.MAINTENANCE_RECORD (
    space_id,
    reported_by_user_account_id,
    assigned_to_user_account_id,
    maintenance_status_id,
    impact_level_id,
    problem_description,
    start_time,
    completion_time,
    result_note
)
SELECT
    s.space_id,
    @staff_id,
    @staff_id,
    @open_status_id,
    @out_impact_id,
    CONCAT(@run_prefix, N' off-hour out-of-service maintenance ', FORMAT(n.rn, '000000')),
    DATEADD(HOUR, 0, DATEADD(DAY, n.rn * 3, CONVERT(DATETIME2(0), @base_date))),
    DATEADD(HOUR, 6, DATEADD(DAY, n.rn * 3, CONVERT(DATETIME2(0), @base_date))),
    N'Generated out-of-service fixture outside booking hours.'
FROM n
INNER JOIN spaces AS s ON s.space_ordinal = ((n.rn - 1) % s.space_count) + 1
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.MAINTENANCE_RECORD AS mr
    WHERE mr.problem_description = CONCAT(@run_prefix, N' off-hour out-of-service maintenance ', FORMAT(n.rn, '000000'))
);

/* Current out-of-service records labelled as later advisory-to-out-of-service escalations. */
WITH approved_bookings AS (
    SELECT TOP (100)
        br.booking_request_id,
        br.space_id,
        br.requested_start_time,
        br.requested_end_time,
        ROW_NUMBER() OVER (ORDER BY br.booking_request_id DESC) AS rn
    FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
    WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
      AND bs.status_code IN (N'approved', N'checked_in', N'completed')
    ORDER BY br.booking_request_id DESC
)
INSERT INTO dbo.MAINTENANCE_RECORD (
    space_id,
    reported_by_user_account_id,
    assigned_to_user_account_id,
    maintenance_status_id,
    impact_level_id,
    problem_description,
    start_time,
    completion_time,
    result_note
)
SELECT
    ab.space_id,
    @staff_id,
    @staff_id,
    @open_status_id,
    @out_impact_id,
    CONCAT(@run_prefix, N' later escalation out-of-service maintenance ', FORMAT(ab.rn, '000000')),
    ab.requested_start_time,
    ab.requested_end_time,
    N'Generated later escalation fixture; approved booking predates escalation.'
FROM approved_bookings AS ab
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.MAINTENANCE_RECORD AS mr
    WHERE mr.problem_description = CONCAT(@run_prefix, N' later escalation out-of-service maintenance ', FORMAT(ab.rn, '000000'))
);

/* Impact history for current advisory and off-hour out-of-service records. */
INSERT INTO dbo.MAINTENANCE_IMPACT_EVENT (
    maintenance_record_id,
    old_impact_level_id,
    new_impact_level_id,
    changed_by_user_account_id,
    changed_at,
    change_note
)
SELECT
    mr.maintenance_record_id,
    NULL,
    mr.impact_level_id,
    @staff_id,
    DATEADD(DAY, -7, mr.start_time),
    N'Generated baseline impact event.'
FROM dbo.MAINTENANCE_RECORD AS mr
WHERE (
      mr.problem_description LIKE @run_prefix + N' advisory maintenance %'
   OR mr.problem_description LIKE @run_prefix + N' off-hour out-of-service maintenance %'
)
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
      WHERE mie.maintenance_record_id = mr.maintenance_record_id
  );

/* Two events for labelled later escalations: advisory first, then out_of_service. */
INSERT INTO dbo.MAINTENANCE_IMPACT_EVENT (
    maintenance_record_id,
    old_impact_level_id,
    new_impact_level_id,
    changed_by_user_account_id,
    changed_at,
    change_note
)
SELECT
    mr.maintenance_record_id,
    NULL,
    @advisory_impact_id,
    @staff_id,
    DATEADD(DAY, -14, mr.start_time),
    N'Generated initial advisory state for later escalation.'
FROM dbo.MAINTENANCE_RECORD AS mr
WHERE mr.problem_description LIKE @run_prefix + N' later escalation out-of-service maintenance %'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
      WHERE mie.maintenance_record_id = mr.maintenance_record_id
        AND mie.new_impact_level_id = @advisory_impact_id
  );

INSERT INTO dbo.MAINTENANCE_IMPACT_EVENT (
    maintenance_record_id,
    old_impact_level_id,
    new_impact_level_id,
    changed_by_user_account_id,
    changed_at,
    change_note
)
SELECT
    mr.maintenance_record_id,
    @advisory_impact_id,
    @out_impact_id,
    @staff_id,
    DATEADD(DAY, -1, mr.start_time),
    N'Generated advisory-to-out-of-service later escalation.'
FROM dbo.MAINTENANCE_RECORD AS mr
WHERE mr.problem_description LIKE @run_prefix + N' later escalation out-of-service maintenance %'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
      WHERE mie.maintenance_record_id = mr.maintenance_record_id
        AND mie.old_impact_level_id = @advisory_impact_id
        AND mie.new_impact_level_id = @out_impact_id
  );

COMMIT TRANSACTION;

SELECT
    mil.impact_level_code,
    COUNT(*) AS maintenance_record_count
FROM dbo.MAINTENANCE_RECORD AS mr
INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil ON mil.impact_level_id = mr.impact_level_id
WHERE mr.problem_description LIKE @run_prefix + N'%'
GROUP BY mil.impact_level_code
ORDER BY mil.impact_level_code;
