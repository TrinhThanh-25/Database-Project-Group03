:r 00-config.sql
/*
 Generate advisory acknowledgements for current advisory maintenance disclosed
 to generated approved occupancy bookings.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @run_prefix NVARCHAR(20) = N'$(G03_RUN_PREFIX)';
DECLARE @advisory_impact_id INT = (SELECT impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'advisory');

IF @advisory_impact_id IS NULL
    THROW 51440, 'Advisory impact lookup missing. Run 01-generate-reference-data.sql first.', 1;

BEGIN TRANSACTION;

INSERT INTO dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT (
    booking_request_id,
    maintenance_record_id,
    acknowledged_impact_level_id,
    acknowledged_at,
    advisory_message_snapshot
)
SELECT
    br.booking_request_id,
    mr.maintenance_record_id,
    @advisory_impact_id,
    DATEADD(DAY, -10, br.requested_start_time),
    mr.problem_description
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
INNER JOIN dbo.MAINTENANCE_RECORD AS mr
    ON mr.space_id = br.space_id
   AND mr.start_time < br.requested_end_time
   AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > br.requested_start_time
INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil ON mil.impact_level_id = mr.impact_level_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%'
  AND mr.problem_description LIKE @run_prefix + N' advisory maintenance %'
  AND bs.status_code IN (N'approved', N'checked_in', N'completed')
  AND mil.impact_level_code = N'advisory'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
      WHERE baa.booking_request_id = br.booking_request_id
        AND baa.maintenance_record_id = mr.maintenance_record_id
  );

COMMIT TRANSACTION;

SELECT
    COUNT(*) AS generated_advisory_acknowledgement_count
FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = baa.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE @run_prefix + N'-SPACE-%';
