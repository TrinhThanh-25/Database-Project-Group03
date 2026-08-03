:r 00-config.sql
/*
 Generate deterministic large-scale bookings, approval decisions, and usage sessions.

 Trusted-load note:
   This script intentionally uses set-based direct INSERT statements instead of
   artifact 12 row-by-row procedures. It is a benchmark data load path only.
   Run 05-validate-generated-data.sql before using the dataset for reports/tuning.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @run_prefix NVARCHAR(20) = N'$(G03_RUN_PREFIX)';
DECLARE @target_booking_count INT = $(G03_TARGET_BOOKINGS);
DECLARE @base_date DATE = CONVERT(DATE, '$(G03_BASE_DATE)');
DECLARE @slot_hours INT = $(G03_SLOT_HOURS);
DECLARE @slots_per_day INT = $(G03_SLOTS_PER_DAY);
DECLARE @requester_count INT = (SELECT COUNT(*) FROM dbo.USER_ACCOUNT WHERE user_id LIKE @run_prefix + N'-REQ-%');
DECLARE @staff_count INT = (SELECT COUNT(*) FROM dbo.USER_ACCOUNT WHERE user_id LIKE @run_prefix + N'-STAFF-%');
DECLARE @space_count INT = (SELECT COUNT(*) FROM dbo.SPACE WHERE unique_space_code LIKE @run_prefix + N'-SPACE-%');

IF @target_booking_count < 100000
    THROW 51420, 'Generator target must be at least 100000 bookings.', 1;
IF @requester_count = 0 OR @staff_count = 0 OR @space_count = 0
    THROW 51421, 'Reference fixtures missing. Run 01-generate-reference-data.sql first.', 1;

DECLARE @approved_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'approved');
DECLARE @pending_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'pending');
DECLARE @rejected_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'rejected');
DECLARE @cancelled_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'cancelled');
DECLARE @checked_in_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'checked_in');
DECLARE @completed_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'completed');
DECLARE @no_show_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'no_show');
DECLARE @staff_method_id INT = (SELECT approval_method_id FROM dbo.APPROVAL_METHOD WHERE method_code = N'staff_approval');
DECLARE @instant_method_id INT = (SELECT approval_method_id FROM dbo.APPROVAL_METHOD WHERE method_code = N'instant_approval');

IF @approved_status_id IS NULL OR @pending_status_id IS NULL OR @rejected_status_id IS NULL
   OR @cancelled_status_id IS NULL OR @checked_in_status_id IS NULL
   OR @completed_status_id IS NULL OR @no_show_status_id IS NULL
   OR @staff_method_id IS NULL OR @instant_method_id IS NULL
    THROW 51422, 'Required status or method lookup missing.', 1;

BEGIN TRANSACTION;

WITH requesters AS (
    SELECT
        user_account_id,
        ROW_NUMBER() OVER (ORDER BY user_id) AS requester_ordinal
    FROM dbo.USER_ACCOUNT
    WHERE user_id LIKE @run_prefix + N'-REQ-%'
),
staff AS (
    SELECT
        user_account_id,
        ROW_NUMBER() OVER (ORDER BY user_id) AS staff_ordinal
    FROM dbo.USER_ACCOUNT
    WHERE user_id LIKE @run_prefix + N'-STAFF-%'
),
spaces AS (
    SELECT
        space_id,
        capacity,
        space_type,
        ROW_NUMBER() OVER (ORDER BY unique_space_code) AS space_ordinal
    FROM dbo.SPACE
    WHERE unique_space_code LIKE @run_prefix + N'-SPACE-%'
),
n AS (
    SELECT TOP (@target_booking_count)
        ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) AS seq
    FROM sys.all_objects AS a
    CROSS JOIN sys.all_objects AS b
),
mapped AS (
    SELECT
        n.seq,
        r.user_account_id AS requester_user_account_id,
        s.space_id,
        s.capacity,
        s.space_type,
        (n.seq - 1) / @space_count AS slot_ordinal,
        (n.seq - 1) % 100 AS bucket
    FROM n
    INNER JOIN requesters AS r ON r.requester_ordinal = ((n.seq - 1) % @requester_count) + 1
    INNER JOIN spaces AS s ON s.space_ordinal = ((n.seq - 1) % @space_count) + 1
)
INSERT INTO dbo.BOOKING_REQUEST (
    requester_user_account_id,
    space_id,
    booking_status_id,
    requested_start_time,
    requested_end_time,
    purpose_of_use,
    expected_number_of_participants
)
SELECT
    requester_user_account_id,
    space_id,
    CASE
        WHEN bucket < 45 THEN @completed_status_id
        WHEN bucket < 60 THEN @approved_status_id
        WHEN bucket < 65 THEN @checked_in_status_id
        WHEN bucket < 80 THEN @pending_status_id
        WHEN bucket < 88 THEN @cancelled_status_id
        WHEN bucket < 94 THEN @rejected_status_id
        ELSE @no_show_status_id
    END,
        DATEADD(HOUR, CONVERT(INT, 8 + ((slot_ordinal % @slots_per_day) * 3)), DATEADD(DAY, CONVERT(INT, slot_ordinal / @slots_per_day), CONVERT(DATETIME2(0), @base_date))),
        DATEADD(HOUR, CONVERT(INT, 8 + ((slot_ordinal % @slots_per_day) * 3) + @slot_hours), DATEADD(DAY, CONVERT(INT, slot_ordinal / @slots_per_day), CONVERT(DATETIME2(0), @base_date))),
    CASE seq % 7
        WHEN 0 THEN N'lecture'
        WHEN 1 THEN N'examination'
        WHEN 2 THEN N'seminar'
        WHEN 3 THEN N'workshop'
        WHEN 4 THEN N'meeting'
        WHEN 5 THEN N'student activity'
        ELSE N'administrative event'
    END,
    1 + (seq % CASE WHEN capacity > 1 THEN capacity ELSE 1 END)
FROM mapped
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.BOOKING_REQUEST AS existing
    WHERE existing.space_id = mapped.space_id
      AND existing.requested_start_time = DATEADD(HOUR, CONVERT(INT, 8 + ((mapped.slot_ordinal % @slots_per_day) * 3)), DATEADD(DAY, CONVERT(INT, mapped.slot_ordinal / @slots_per_day), CONVERT(DATETIME2(0), @base_date)))
      AND existing.requested_end_time = DATEADD(HOUR, CONVERT(INT, 8 + ((mapped.slot_ordinal % @slots_per_day) * 3) + @slot_hours), DATEADD(DAY, CONVERT(INT, mapped.slot_ordinal / @slots_per_day), CONVERT(DATETIME2(0), @base_date)))
);

/* Approval decisions for generated approved/rejected outcomes. */
WITH generated_bookings AS (
    SELECT
        br.booking_request_id,
        br.space_id,
        br.requested_start_time,
        br.requested_end_time,
        bs.status_code,
        ROW_NUMBER() OVER (ORDER BY br.booking_request_id) AS rn
    FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
    WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
      AND br.requested_start_time >= CONVERT(DATETIME2(0), @base_date)
),
staff AS (
    SELECT
        user_account_id,
        ROW_NUMBER() OVER (ORDER BY user_id) AS staff_ordinal
    FROM dbo.USER_ACCOUNT
    WHERE user_id LIKE @run_prefix + N'-STAFF-%'
)
INSERT INTO dbo.APPROVAL_DECISION (
    booking_request_id,
    decided_by_user_account_id,
    decision_outcome_booking_status_id,
    decision_method_id,
    decision_time,
    decision_note,
    rejection_reason
)
SELECT
    gb.booking_request_id,
    CASE WHEN gb.status_code IN (N'approved', N'checked_in', N'completed') AND gb.rn % 3 = 0 THEN NULL ELSE st.user_account_id END,
    CASE WHEN gb.status_code = N'rejected' THEN @rejected_status_id ELSE @approved_status_id END,
    CASE WHEN gb.status_code IN (N'approved', N'checked_in', N'completed') AND gb.rn % 3 = 0 THEN @instant_method_id ELSE @staff_method_id END,
    DATEADD(DAY, -14 - (gb.rn % 21), gb.requested_start_time),
    CONCAT(N'Generated ', gb.status_code, N' decision for ', @run_prefix, N' benchmark data.'),
    CASE WHEN gb.status_code = N'rejected' THEN N'Generated rejection reason for benchmark distribution.' ELSE NULL END
FROM generated_bookings AS gb
INNER JOIN staff AS st ON st.staff_ordinal = ((gb.rn - 1) % @staff_count) + 1
WHERE gb.status_code IN (N'approved', N'checked_in', N'completed', N'rejected')
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.APPROVAL_DECISION AS ad
      WHERE ad.booking_request_id = gb.booking_request_id
  );

/* Usage sessions for checked-in and completed generated bookings. */
WITH generated_usage_bookings AS (
    SELECT
        br.booking_request_id,
        br.requested_start_time,
        br.requested_end_time,
        bs.status_code,
        ROW_NUMBER() OVER (ORDER BY br.booking_request_id) AS rn
    FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
    WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
      AND bs.status_code IN (N'checked_in', N'completed')
),
staff AS (
    SELECT
        user_account_id,
        ROW_NUMBER() OVER (ORDER BY user_id) AS staff_ordinal
    FROM dbo.USER_ACCOUNT
    WHERE user_id LIKE @run_prefix + N'-STAFF-%'
)
INSERT INTO dbo.USAGE_SESSION (
    booking_request_id,
    checked_in_by_user_account_id,
    completed_by_user_account_id,
    actual_start_time,
    initial_condition_of_space,
    actual_end_time,
    final_condition_of_space,
    usage_notes
)
SELECT
    gub.booking_request_id,
    check_staff.user_account_id,
    CASE WHEN gub.status_code = N'completed' THEN complete_staff.user_account_id ELSE NULL END,
    DATEADD(MINUTE, 5, gub.requested_start_time),
    N'Generated initial condition: acceptable.',
    CASE WHEN gub.status_code = N'completed' THEN DATEADD(MINUTE, -5, gub.requested_end_time) ELSE NULL END,
    CASE WHEN gub.status_code = N'completed' THEN N'Generated final condition: acceptable.' ELSE NULL END,
    CONCAT(N'Generated usage session for ', @run_prefix, N' benchmark data.')
FROM generated_usage_bookings AS gub
INNER JOIN staff AS check_staff ON check_staff.staff_ordinal = ((gub.rn - 1) % @staff_count) + 1
INNER JOIN staff AS complete_staff ON complete_staff.staff_ordinal = ((gub.rn) % @staff_count) + 1
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.USAGE_SESSION AS us
    WHERE us.booking_request_id = gub.booking_request_id
);

COMMIT TRANSACTION;

SELECT
    @target_booking_count AS requested_booking_count,
    COUNT(*) AS actual_generated_booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND br.requested_start_time >= CONVERT(DATETIME2(0), @base_date);

SELECT
    bs.status_code,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
GROUP BY bs.status_code
ORDER BY bs.status_code;
