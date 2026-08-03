/*
 Phase 2 Analytical Queries - Group 03

 DBMS: Microsoft SQL Server

 Purpose:
   Implements the four required Phase 2 analytical/reporting queries:
     1. Total approved booking hours of each space for a given semester.
     2. Number of approved bookings by weekday and hour for a given semester.
     3. Available spaces satisfying capacity and every required facility for a
        requested interval.
     4. Approved bookings affected by escalation of a maintenance record to
        out-of-service.

 Deployment prerequisites:
   1. Run outputs/05-db-definition-G03.sql.
   2. Run outputs/10-schema-migration-G03.sql.
   3. Run outputs/12-concurrency-implementation-G03.sql for dbo.IntIdList.

 Shared semantics:
   - Approved occupancy status codes: approved, checked_in, completed.
   - Intervals are half-open [start, end).
   - Overlap predicate: A.start < B.end AND A.end > B.start.
   - Semester windows use [semester_start_date, semester_end_date) because the
     Phase 2 generator validation uses that convention.
   - DATETIME2 values are treated as local campus wall-clock timestamps; no time
     zone or daylight-saving conversion is applied.

 Tuning handoff:
   Reports 1 and 2 are the selected non-room-finder workloads for artifact 15.
   This file contains no index DDL and no performance claims.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- ============================================================================
-- 1. Shared parameter/type prerequisites
-- ============================================================================
IF OBJECT_ID(N'dbo.ACADEMIC_SEMESTER', N'U') IS NULL
    THROW 51600, 'Missing dbo.ACADEMIC_SEMESTER. Run artifact 10 first.', 1;
IF OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_EVENT', N'U') IS NULL
    THROW 51600, 'Missing dbo.MAINTENANCE_IMPACT_EVENT. Run artifact 10 first.', 1;
IF OBJECT_ID(N'dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT', N'U') IS NULL
    THROW 51600, 'Missing dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT. Run artifact 10 first.', 1;
IF COL_LENGTH(N'dbo.BOOKING_STATUS', N'status_code') IS NULL
    THROW 51600, 'Missing dbo.BOOKING_STATUS.status_code. Run artifact 10 first.', 1;
IF COL_LENGTH(N'dbo.MAINTENANCE_RECORD', N'impact_level_id') IS NULL
    THROW 51600, 'Missing dbo.MAINTENANCE_RECORD.impact_level_id. Run artifact 10 first.', 1;
IF TYPE_ID(N'dbo.IntIdList') IS NULL
    THROW 51600, 'Missing dbo.IntIdList. Run artifact 12 first; output 16 reuses that table type for facility-list input.', 1;
GO

-- ============================================================================
-- 2. Report 1: approved booking hours by space for a given semester
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ReportApprovedHoursBySpaceSemester
    @semester_code NVARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    IF @semester_code IS NULL OR LEN(LTRIM(RTRIM(@semester_code))) = 0
        THROW 51610, 'VALIDATION_ERROR: @semester_code is required.', 1;

    DECLARE @semester_id INT;
    DECLARE @semester_start DATETIME2(0);
    DECLARE @semester_end DATETIME2(0);

    SELECT
        @semester_id = semester_id,
        @semester_start = CONVERT(DATETIME2(0), semester_start_date),
        @semester_end = CONVERT(DATETIME2(0), semester_end_date)
    FROM dbo.ACADEMIC_SEMESTER
    WHERE semester_code = @semester_code;

    IF @semester_id IS NULL
        THROW 51611, 'SEMESTER_NOT_FOUND: @semester_code does not identify an academic semester.', 1;
    IF @semester_start >= @semester_end
        THROW 51612, 'SEMESTER_INVALID: semester_start_date must be before semester_end_date.', 1;

    /*
      P2-BR-22.
      Includes every space, even when it has zero approved hours.
      Clips booking intervals to the semester window before summing hours.
    */
    WITH approved_clipped AS (
        SELECT
            br.space_id,
            br.booking_request_id,
            clip.clipped_start,
            clip.clipped_end
        FROM dbo.BOOKING_REQUEST AS br
        INNER JOIN dbo.BOOKING_STATUS AS bs
            ON bs.booking_status_id = br.booking_status_id
        CROSS APPLY (
            VALUES (
                CASE WHEN br.requested_start_time > @semester_start THEN br.requested_start_time ELSE @semester_start END,
                CASE WHEN br.requested_end_time < @semester_end THEN br.requested_end_time ELSE @semester_end END
            )
        ) AS clip(clipped_start, clipped_end)
        WHERE bs.status_code IN (N'approved', N'checked_in', N'completed')
          AND br.requested_start_time < @semester_end
          AND br.requested_end_time > @semester_start
          AND clip.clipped_start < clip.clipped_end
    ),
    space_totals AS (
        SELECT
            space_id,
            COUNT(*) AS approved_booking_count,
            CAST(SUM(DATEDIFF(MINUTE, clipped_start, clipped_end)) / 60.0 AS DECIMAL(18, 2)) AS approved_hours
        FROM approved_clipped
        GROUP BY space_id
    )
    SELECT
        sem.semester_code,
        sem.academic_year_label,
        sem.semester_name,
        s.space_id,
        s.unique_space_code,
        s.space_name,
        s.space_type,
        s.building,
        s.floor,
        s.room_number,
        COALESCE(st.approved_booking_count, 0) AS approved_booking_count,
        COALESCE(st.approved_hours, CONVERT(DECIMAL(18, 2), 0.00)) AS approved_hours
    FROM dbo.SPACE AS s
    CROSS JOIN dbo.ACADEMIC_SEMESTER AS sem
    LEFT JOIN space_totals AS st
        ON st.space_id = s.space_id
    WHERE sem.semester_id = @semester_id
    ORDER BY approved_hours DESC, s.unique_space_code;
END;
GO

/*
Correctness example, not executed here:

EXEC dbo.usp_ReportApprovedHoursBySpaceSemester
    @semester_code = N'G03-LS-2029-S1';
*/

-- ============================================================================
-- 3. Report 2: approved bookings by deterministic weekday and occupied hour
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ReportApprovedBookingsByWeekdayHourSemester
    @semester_code NVARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON;

    IF @semester_code IS NULL OR LEN(LTRIM(RTRIM(@semester_code))) = 0
        THROW 51610, 'VALIDATION_ERROR: @semester_code is required.', 1;

    DECLARE @semester_id INT;
    DECLARE @semester_start DATETIME2(0);
    DECLARE @semester_end DATETIME2(0);

    SELECT
        @semester_id = semester_id,
        @semester_start = CONVERT(DATETIME2(0), semester_start_date),
        @semester_end = CONVERT(DATETIME2(0), semester_end_date)
    FROM dbo.ACADEMIC_SEMESTER
    WHERE semester_code = @semester_code;

    IF @semester_id IS NULL
        THROW 51611, 'SEMESTER_NOT_FOUND: @semester_code does not identify an academic semester.', 1;
    IF @semester_start >= @semester_end
        THROW 51612, 'SEMESTER_INVALID: semester_start_date must be before semester_end_date.', 1;

    /*
      P2-BR-23.
      Semantics: a booking contributes to every occupied hour bucket that its
      clipped interval touches, not only to its start hour.

      Weekday number is ISO-like and deterministic:
        1 Monday ... 7 Sunday
      It is calculated from 1900-01-01, a Monday, and does not depend on
      SET DATEFIRST or session language.
    */
    WITH tally AS (
        SELECT TOP (10000)
            ROW_NUMBER() OVER (ORDER BY a.object_id, b.object_id) - 1 AS n
        FROM sys.all_objects AS a
        CROSS JOIN sys.all_objects AS b
    ),
    approved_clipped AS (
        SELECT
            br.booking_request_id,
            clip.clipped_start,
            clip.clipped_end,
            DATEADD(HOUR, DATEDIFF(HOUR, CONVERT(DATETIME2(0), '19000101'), clip.clipped_start), CONVERT(DATETIME2(0), '19000101')) AS first_hour_bucket
        FROM dbo.BOOKING_REQUEST AS br
        INNER JOIN dbo.BOOKING_STATUS AS bs
            ON bs.booking_status_id = br.booking_status_id
        CROSS APPLY (
            VALUES (
                CASE WHEN br.requested_start_time > @semester_start THEN br.requested_start_time ELSE @semester_start END,
                CASE WHEN br.requested_end_time < @semester_end THEN br.requested_end_time ELSE @semester_end END
            )
        ) AS clip(clipped_start, clipped_end)
        WHERE bs.status_code IN (N'approved', N'checked_in', N'completed')
          AND br.requested_start_time < @semester_end
          AND br.requested_end_time > @semester_start
          AND clip.clipped_start < clip.clipped_end
    ),
    occupied_hour AS (
        SELECT
            ac.booking_request_id,
            DATEADD(HOUR, t.n, ac.first_hour_bucket) AS hour_bucket_start
        FROM approved_clipped AS ac
        INNER JOIN tally AS t
            ON t.n <= DATEDIFF(HOUR, ac.first_hour_bucket, ac.clipped_end)
        WHERE DATEADD(HOUR, t.n, ac.first_hour_bucket) < ac.clipped_end
          AND DATEADD(HOUR, t.n + 1, ac.first_hour_bucket) > ac.clipped_start
    ),
    bucketed AS (
        SELECT
            ((DATEDIFF(DAY, CONVERT(DATE, '19000101'), CONVERT(DATE, hour_bucket_start)) % 7) + 1) AS iso_weekday_number,
            DATEPART(HOUR, hour_bucket_start) AS hour_of_day,
            COUNT(DISTINCT booking_request_id) AS approved_booking_count
        FROM occupied_hour
        GROUP BY
            ((DATEDIFF(DAY, CONVERT(DATE, '19000101'), CONVERT(DATE, hour_bucket_start)) % 7) + 1),
            DATEPART(HOUR, hour_bucket_start)
    )
    SELECT
        sem.semester_code,
        sem.academic_year_label,
        sem.semester_name,
        b.iso_weekday_number,
        CASE b.iso_weekday_number
            WHEN 1 THEN N'Monday'
            WHEN 2 THEN N'Tuesday'
            WHEN 3 THEN N'Wednesday'
            WHEN 4 THEN N'Thursday'
            WHEN 5 THEN N'Friday'
            WHEN 6 THEN N'Saturday'
            WHEN 7 THEN N'Sunday'
        END AS weekday_name,
        b.hour_of_day,
        b.approved_booking_count
    FROM bucketed AS b
    CROSS JOIN dbo.ACADEMIC_SEMESTER AS sem
    WHERE sem.semester_id = @semester_id
    ORDER BY b.iso_weekday_number, b.hour_of_day;
END;
GO

/*
Correctness example, not executed here:

EXEC dbo.usp_ReportApprovedBookingsByWeekdayHourSemester
    @semester_code = N'G03-LS-2029-S1';
*/

-- ============================================================================
-- 4. Report 3: room finder with capacity, all facilities, and availability
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ReportAvailableSpacesForInterval
    @requested_start_time DATETIME2(0),
    @requested_end_time DATETIME2(0),
    @minimum_capacity INT,
    @required_facility_ids dbo.IntIdList READONLY
AS
BEGIN
    SET NOCOUNT ON;

    IF @requested_start_time IS NULL OR @requested_end_time IS NULL OR @requested_start_time >= @requested_end_time
        THROW 51620, 'VALIDATION_ERROR: requested interval must satisfy start < end.', 1;
    IF @minimum_capacity IS NULL OR @minimum_capacity <= 0
        THROW 51621, 'VALIDATION_ERROR: @minimum_capacity must be positive.', 1;

    IF EXISTS (
        SELECT 1
        FROM @required_facility_ids AS rf
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.FACILITY AS f
            WHERE f.facility_id = rf.id
        )
    )
        THROW 51622, 'FACILITY_NOT_FOUND: at least one requested facility id does not exist.', 1;

    /*
      P2-BR-24.
      Facility semantics: the returned space must contain every facility id in
      @required_facility_ids. An empty facility set is allowed and means capacity
      plus time availability only.

      Advisory maintenance is reported but does not make the room unavailable.
    */
    SELECT
        s.space_id,
        s.unique_space_code,
        s.space_name,
        s.space_type,
        s.building,
        s.floor,
        s.room_number,
        s.capacity,
        COALESCE(adv.advisory_count, 0) AS overlapping_advisory_count,
        adv.advisory_maintenance_ids
    FROM dbo.SPACE AS s
    INNER JOIN dbo.SPACE_STATUS AS ss
        ON ss.space_status_id = s.space_status_id
    OUTER APPLY (
        SELECT
            COUNT(*) AS advisory_count,
            STRING_AGG(CONVERT(NVARCHAR(20), mr.maintenance_record_id), N',') AS advisory_maintenance_ids
        FROM dbo.MAINTENANCE_RECORD AS mr
        INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil
            ON mil.impact_level_id = mr.impact_level_id
        WHERE mr.space_id = s.space_id
          AND mil.impact_level_code = N'advisory'
          AND mr.start_time < @requested_end_time
          AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > @requested_start_time
    ) AS adv
    WHERE s.capacity >= @minimum_capacity
      AND ss.status_name NOT IN (N'Under maintenance', N'Temporarily closed', N'Retired')
      AND NOT EXISTS (
          SELECT rf.id
          FROM @required_facility_ids AS rf
          EXCEPT
          SELECT sf.facility_id
          FROM dbo.SPACE_FACILITY AS sf
          WHERE sf.space_id = s.space_id
      )
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.BOOKING_REQUEST AS br
          INNER JOIN dbo.BOOKING_STATUS AS bs
              ON bs.booking_status_id = br.booking_status_id
          WHERE br.space_id = s.space_id
            AND bs.status_code IN (N'approved', N'checked_in', N'completed')
            AND br.requested_start_time < @requested_end_time
            AND br.requested_end_time > @requested_start_time
      )
      AND NOT EXISTS (
          SELECT 1
          FROM dbo.MAINTENANCE_RECORD AS mr
          INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS mil
              ON mil.impact_level_id = mr.impact_level_id
          WHERE mr.space_id = s.space_id
            AND mil.impact_level_code = N'out_of_service'
            AND mr.start_time < @requested_end_time
            AND ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59')) > @requested_start_time
      )
    ORDER BY s.capacity ASC, s.unique_space_code;
END;
GO

/*
Correctness example, not executed here:

DECLARE @required_facilities dbo.IntIdList;
INSERT INTO @required_facilities (id)
SELECT TOP (2) facility_id
FROM dbo.FACILITY
ORDER BY facility_id;

EXEC dbo.usp_ReportAvailableSpacesForInterval
    @requested_start_time = '2029-02-10T10:00:00',
    @requested_end_time = '2029-02-10T12:00:00',
    @minimum_capacity = 20,
    @required_facility_ids = @required_facilities;
*/

-- ============================================================================
-- 5. Report 4: approved bookings affected by out-of-service escalation
-- ============================================================================
CREATE OR ALTER PROCEDURE dbo.usp_ReportApprovedBookingsAffectedByMaintenanceEscalation
    @maintenance_record_id INT,
    @maintenance_impact_event_id INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @maintenance_record_id IS NULL OR @maintenance_record_id <= 0
        THROW 51630, 'VALIDATION_ERROR: @maintenance_record_id must be positive.', 1;
    IF @maintenance_impact_event_id IS NOT NULL AND @maintenance_impact_event_id <= 0
        THROW 51631, 'VALIDATION_ERROR: @maintenance_impact_event_id must be positive when supplied.', 1;

    /*
      P2-BR-25.
      Uses actual impact history. If @maintenance_impact_event_id is NULL, the
      latest advisory -> out_of_service event for the maintenance record is used.
      Only bookings approved on or before the escalation event are returned.
      Approved bookings with no approved decision timestamp are excluded because
      their approval order relative to the escalation cannot be proven.
    */
    ;WITH escalation_event AS (
        SELECT TOP (1)
            mie.maintenance_impact_event_id,
            mie.maintenance_record_id,
            mie.changed_at AS escalation_time,
            mie.change_note,
            oldmil.impact_level_code AS old_impact_level_code,
            newmil.impact_level_code AS new_impact_level_code
        FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
        INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS oldmil
            ON oldmil.impact_level_id = mie.old_impact_level_id
        INNER JOIN dbo.MAINTENANCE_IMPACT_LEVEL AS newmil
            ON newmil.impact_level_id = mie.new_impact_level_id
        WHERE mie.maintenance_record_id = @maintenance_record_id
          AND (@maintenance_impact_event_id IS NULL OR mie.maintenance_impact_event_id = @maintenance_impact_event_id)
          AND oldmil.impact_level_code = N'advisory'
          AND newmil.impact_level_code = N'out_of_service'
        ORDER BY mie.changed_at DESC, mie.maintenance_impact_event_id DESC
    ),
    approved_decision_time AS (
        SELECT
            ad.booking_request_id,
            MIN(ad.decision_time) AS approved_decision_time
        FROM dbo.APPROVAL_DECISION AS ad
        INNER JOIN dbo.BOOKING_STATUS AS outcome
            ON outcome.booking_status_id = ad.decision_outcome_booking_status_id
        WHERE outcome.status_code = N'approved'
        GROUP BY ad.booking_request_id
    )
    SELECT
        ee.maintenance_impact_event_id,
        ee.escalation_time,
        ee.old_impact_level_code,
        ee.new_impact_level_code,
        mr.maintenance_record_id,
        mr.problem_description,
        mr.start_time AS maintenance_start_time,
        mr.completion_time AS maintenance_completion_time,
        s.space_id,
        s.unique_space_code,
        s.space_name,
        br.booking_request_id,
        bs.status_code AS booking_status_code,
        br.requested_start_time,
        br.requested_end_time,
        adt.approved_decision_time,
        requester.user_account_id AS requester_user_account_id,
        requester.user_id AS requester_user_id,
        requester.full_name AS requester_full_name,
        requester.email AS requester_email,
        requester.phone_number AS requester_phone_number
    FROM escalation_event AS ee
    INNER JOIN dbo.MAINTENANCE_RECORD AS mr
        ON mr.maintenance_record_id = ee.maintenance_record_id
    INNER JOIN dbo.SPACE AS s
        ON s.space_id = mr.space_id
    INNER JOIN dbo.BOOKING_REQUEST AS br
        ON br.space_id = mr.space_id
       AND br.requested_start_time < ISNULL(mr.completion_time, CONVERT(DATETIME2(0), '9999-12-31T23:59:59'))
       AND br.requested_end_time > mr.start_time
    INNER JOIN dbo.BOOKING_STATUS AS bs
        ON bs.booking_status_id = br.booking_status_id
    INNER JOIN approved_decision_time AS adt
        ON adt.booking_request_id = br.booking_request_id
       AND adt.approved_decision_time <= ee.escalation_time
    INNER JOIN dbo.USER_ACCOUNT AS requester
        ON requester.user_account_id = br.requester_user_account_id
    WHERE bs.status_code IN (N'approved', N'checked_in', N'completed')
    ORDER BY br.requested_start_time, br.booking_request_id;

    IF @@ROWCOUNT = 0
    BEGIN
        SELECT
            @maintenance_record_id AS maintenance_record_id,
            @maintenance_impact_event_id AS requested_maintenance_impact_event_id,
            N'No matching advisory-to-out-of-service escalation event with affected approved bookings was found.' AS result_note;
    END;
END;
GO

/*
Correctness example, not executed here:

DECLARE @maintenance_record_id INT = (
    SELECT TOP (1) mr.maintenance_record_id
    FROM dbo.MAINTENANCE_RECORD AS mr
    WHERE mr.problem_description LIKE N'G03-LS later escalation out-of-service maintenance %'
    ORDER BY mr.maintenance_record_id
);

EXEC dbo.usp_ReportApprovedBookingsAffectedByMaintenanceEscalation
    @maintenance_record_id = @maintenance_record_id;
*/

-- ============================================================================
-- 6. Result-schema summary and tuning handoff
-- ============================================================================
SELECT
    N'dbo.usp_ReportApprovedHoursBySpaceSemester' AS report_procedure,
    N'@semester_code NVARCHAR(40)' AS parameter_contract,
    N'One row per SPACE with approved_booking_count and DECIMAL(18,2) approved_hours. Tuning workload 3.' AS result_contract
UNION ALL
SELECT
    N'dbo.usp_ReportApprovedBookingsByWeekdayHourSemester',
    N'@semester_code NVARCHAR(40)',
    N'One row per occupied ISO weekday/hour bucket with approved_booking_count. Tuning workload 4.'
UNION ALL
SELECT
    N'dbo.usp_ReportAvailableSpacesForInterval',
    N'@requested_start_time DATETIME2(0), @requested_end_time DATETIME2(0), @minimum_capacity INT, @required_facility_ids dbo.IntIdList READONLY',
    N'One row per available SPACE satisfying capacity, every requested facility, no approved conflict, and no out-of-service overlap. Tuning workload 2.'
UNION ALL
SELECT
    N'dbo.usp_ReportApprovedBookingsAffectedByMaintenanceEscalation',
    N'@maintenance_record_id INT, @maintenance_impact_event_id INT = NULL',
    N'One row per affected approved booking for an actual advisory-to-out-of-service escalation. Reporting workload for P2-BR-25.';
GO
