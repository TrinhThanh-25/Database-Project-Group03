:r 00-config.sql
/*
 Validate the generated large-scale dataset.
 Expected generated-data invariant failures are zero unless labelled otherwise.
*/

SET NOCOUNT ON;

DECLARE @run_prefix NVARCHAR(20) = N'$(G03_RUN_PREFIX)';
DECLARE @target_booking_count INT = $(G03_TARGET_BOOKINGS);
DECLARE @base_date DATE = CONVERT(DATE, '$(G03_BASE_DATE)');

PRINT 'Validation 1: target booking count and academic-year coverage.';
SELECT
    @target_booking_count AS requested_booking_count,
    COUNT(*) AS actual_booking_count,
    MIN(br.requested_start_time) AS min_requested_start_time,
    MAX(br.requested_start_time) AS max_requested_start_time,
    COUNT(DISTINCT sem.academic_year_label) AS academic_years_covered
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
LEFT JOIN dbo.ACADEMIC_SEMESTER AS sem
    ON CONVERT(DATE, br.requested_start_time) >= sem.semester_start_date
   AND CONVERT(DATE, br.requested_start_time) < sem.semester_end_date
   AND sem.semester_code LIKE @run_prefix + N'-%'
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND br.requested_start_time >= CONVERT(DATETIME2(0), @base_date);

PRINT 'Validation 2: booking counts by status.';
SELECT
    bs.status_code,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
GROUP BY bs.status_code
ORDER BY bs.status_code;

PRINT 'Validation 3: booking counts by generated semester.';
SELECT
    sem.academic_year_label,
    sem.semester_name,
    COUNT(br.booking_request_id) AS booking_count
FROM dbo.ACADEMIC_SEMESTER AS sem
LEFT JOIN dbo.BOOKING_REQUEST AS br
    ON CONVERT(DATE, br.requested_start_time) >= sem.semester_start_date
   AND CONVERT(DATE, br.requested_start_time) < sem.semester_end_date
LEFT JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE sem.semester_code LIKE @run_prefix + N'-%'
  AND (s.unique_space_code LIKE @run_prefix + N'-SPACE-%' OR br.booking_request_id IS NULL)
GROUP BY sem.academic_year_label, sem.semester_name, sem.semester_start_date
ORDER BY sem.semester_start_date;

PRINT 'Validation 4: booking counts by purpose.';
SELECT
    br.purpose_of_use,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
GROUP BY br.purpose_of_use
ORDER BY br.purpose_of_use;

PRINT 'Validation 5: booking counts by space.';
SELECT
    s.unique_space_code,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
GROUP BY s.unique_space_code
ORDER BY s.unique_space_code;

PRINT 'Validation 6: generated relation orphan checks. Expected orphan_count = 0 for all rows.';
SELECT N'BOOKING_REQUEST.requester_user_account_id' AS check_name, COUNT(*) AS orphan_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
LEFT JOIN dbo.USER_ACCOUNT AS ua ON ua.user_account_id = br.requester_user_account_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND ua.user_account_id IS NULL
UNION ALL
SELECT N'APPROVAL_DECISION.booking_request_id', COUNT(*)
FROM dbo.APPROVAL_DECISION AS ad
LEFT JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = ad.booking_request_id
LEFT JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND br.booking_request_id IS NULL
UNION ALL
SELECT N'USAGE_SESSION.booking_request_id', COUNT(*)
FROM dbo.USAGE_SESSION AS us
LEFT JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = us.booking_request_id
LEFT JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND br.booking_request_id IS NULL
UNION ALL
SELECT N'MAINTENANCE_RECORD.space_id', COUNT(*)
FROM dbo.MAINTENANCE_RECORD AS mr
LEFT JOIN dbo.SPACE AS s ON s.space_id = mr.space_id
WHERE mr.problem_description LIKE @run_prefix + N'%'
  AND s.space_id IS NULL
UNION ALL
SELECT N'BOOKING_ADVISORY_ACKNOWLEDGEMENT.booking_or_maintenance', COUNT(*)
FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
LEFT JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = baa.booking_request_id
LEFT JOIN dbo.MAINTENANCE_RECORD AS mr ON mr.maintenance_record_id = baa.maintenance_record_id
LEFT JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE (s.unique_space_code LIKE @run_prefix + N'-SPACE-%' OR mr.problem_description LIKE @run_prefix + N'%')
  AND (br.booking_request_id IS NULL OR mr.maintenance_record_id IS NULL);

PRINT 'Validation 7: duplicate generated natural/business keys. Expected duplicate_count = 0.';
SELECT N'USER_ACCOUNT.user_id' AS check_name, COUNT(*) AS duplicate_count
FROM (
    SELECT user_id
    FROM dbo.USER_ACCOUNT
    WHERE user_id LIKE @run_prefix + N'-%'
    GROUP BY user_id
    HAVING COUNT(*) > 1
) AS d
UNION ALL
SELECT N'SPACE.unique_space_code', COUNT(*)
FROM (
    SELECT unique_space_code
    FROM dbo.SPACE
    WHERE unique_space_code LIKE @run_prefix + N'-%'
    GROUP BY unique_space_code
    HAVING COUNT(*) > 1
) AS d
UNION ALL
SELECT N'BOOKING_ADVISORY_ACKNOWLEDGEMENT.booking_maintenance', COUNT(*)
FROM (
    SELECT booking_request_id, maintenance_record_id
    FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT
    GROUP BY booking_request_id, maintenance_record_id
    HAVING COUNT(*) > 1
) AS d;

PRINT 'Validation 8: time-order checks. Expected invalid_count = 0.';
SELECT N'BOOKING_REQUEST requested interval' AS check_name, COUNT(*) AS invalid_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND br.requested_end_time <= br.requested_start_time
UNION ALL
SELECT N'USAGE_SESSION actual interval', COUNT(*)
FROM dbo.USAGE_SESSION AS us
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = us.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND us.actual_end_time IS NOT NULL
  AND us.actual_end_time <= us.actual_start_time
UNION ALL
SELECT N'MAINTENANCE_RECORD interval', COUNT(*)
FROM dbo.MAINTENANCE_RECORD AS mr
WHERE mr.problem_description LIKE @run_prefix + N'%'
  AND mr.completion_time IS NOT NULL
  AND mr.completion_time <= mr.start_time;

PRINT 'Validation 9: approved booking overlap. Expected approved_overlap_pair_count = 0.';
SELECT
    COUNT(*) AS approved_overlap_pair_count
FROM dbo.BOOKING_REQUEST AS a
INNER JOIN dbo.BOOKING_STATUS AS ast ON ast.booking_status_id = a.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = a.space_id
INNER JOIN dbo.BOOKING_REQUEST AS b ON b.booking_request_id > a.booking_request_id AND b.space_id = a.space_id
INNER JOIN dbo.BOOKING_STATUS AS bst ON bst.booking_status_id = b.booking_status_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND ast.status_code IN (N'approved', N'checked_in', N'completed')
  AND bst.status_code IN (N'approved', N'checked_in', N'completed')
  AND a.requested_start_time < b.requested_end_time
  AND a.requested_end_time > b.requested_start_time;

PRINT 'Validation 10: approved booking versus out-of-service maintenance overlap. Unlabelled overlap expected 0.';
WITH oos_overlaps AS (
    SELECT
        br.booking_request_id,
        mr.maintenance_record_id,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
                INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS oldmil ON oldmil.impact_level_id = mie.old_impact_level_id
                INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS newmil ON newmil.impact_level_id = mie.new_impact_level_id
                WHERE mie.maintenance_record_id = mr.maintenance_record_id
                  AND oldmil.impact_level_code = N'advisory'
                  AND newmil.impact_level_code = N'out_of_service'
                  AND mie.change_note LIKE N'Generated advisory-to-out-of-service later escalation%'
            )
            THEN 1 ELSE 0
        END AS is_labelled_later_escalation
    FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
    INNER JOIN dbo.MAINTENANCE_RECORD AS mr
        ON mr.space_id = br.space_id
       AND mr.start_time < br.requested_end_time
       AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > br.requested_start_time
    INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil ON mil.impact_level_id = mr.impact_level_id
    WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
      AND mr.problem_description LIKE @run_prefix + N'%'
      AND bs.status_code IN (N'approved', N'checked_in', N'completed')
      AND mil.impact_level_code = N'out_of_service'
)
SELECT
    is_labelled_later_escalation,
    COUNT(*) AS approved_oos_overlap_count
FROM oos_overlaps
GROUP BY is_labelled_later_escalation
ORDER BY is_labelled_later_escalation;

PRINT 'Validation 11: advisory acknowledgement coverage. Expected missing_acknowledgement_count = 0.';
SELECT
    COUNT(*) AS missing_acknowledgement_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
INNER JOIN dbo.MAINTENANCE_RECORD AS mr
    ON mr.space_id = br.space_id
   AND mr.start_time < br.requested_end_time
   AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > br.requested_start_time
INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil ON mil.impact_level_id = mr.impact_level_id
LEFT JOIN dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
    ON baa.booking_request_id = br.booking_request_id
   AND baa.maintenance_record_id = mr.maintenance_record_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND mr.problem_description LIKE @run_prefix + N' advisory maintenance %'
  AND bs.status_code IN (N'approved', N'checked_in', N'completed')
  AND mil.impact_level_code = N'advisory'
  AND baa.advisory_acknowledgement_id IS NULL;

PRINT 'Validation 12: duplicate acknowledgement pairs/events. Expected duplicate_count = 0.';
SELECT N'acknowledgement pair duplicates' AS check_name, COUNT(*) AS duplicate_count
FROM (
    SELECT baa.booking_request_id, baa.maintenance_record_id
    FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
    INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = baa.booking_request_id
    INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
    WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
    GROUP BY baa.booking_request_id, baa.maintenance_record_id
    HAVING COUNT(*) > 1
) AS d
UNION ALL
SELECT N'impact event exact duplicates', COUNT(*)
FROM (
    SELECT maintenance_record_id, old_impact_level_id, new_impact_level_id, changed_at
    FROM dbo.MAINTENANCE_IMPACT_EVENT
    GROUP BY maintenance_record_id, old_impact_level_id, new_impact_level_id, changed_at
    HAVING COUNT(*) > 1
) AS d;

PRINT 'Validation 13: maintenance impact current-state consistency. Expected mismatch_count = 0.';
WITH latest_event AS (
    SELECT
        mie.maintenance_record_id,
        mie.new_impact_level_id,
        ROW_NUMBER() OVER (
            PARTITION BY mie.maintenance_record_id
            ORDER BY mie.changed_at DESC, mie.maintenance_impact_event_id DESC
        ) AS rn
    FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
    INNER JOIN dbo.MAINTENANCE_RECORD AS mr ON mr.maintenance_record_id = mie.maintenance_record_id
    WHERE mr.problem_description LIKE @run_prefix + N'%'
)
SELECT
    COUNT(*) AS mismatch_count
FROM dbo.MAINTENANCE_RECORD AS mr
LEFT JOIN latest_event AS le
    ON le.maintenance_record_id = mr.maintenance_record_id
   AND le.rn = 1
WHERE mr.problem_description LIKE @run_prefix + N'%'
  AND (le.maintenance_record_id IS NULL OR le.new_impact_level_id <> mr.impact_level_id);

PRINT 'Validation 14: DBCC CHECKCONSTRAINTS for generated tables. Empty result set means no reported constraint violations.';
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
