/*
SQL Query Design - Group 03
Target DBMS: Microsoft SQL Server

Inputs reviewed:
- outputs/01-business-req-analysis-G03.md
- outputs/05-db-definition-G03.sql
- outputs/06-sample-data-G03.sql

All statements below are read-only SELECT queries using actual implemented
table and column names from outputs/05-db-definition-G03.sql.
*/

-- Query 1: Upcoming approved bookings by space
-- Business question: Which approved bookings are coming up for each bookable campus space?
-- Target user(s): Facility staff, facility managers, lecturers, department administrators
-- Why this query is useful: It helps staff prepare rooms, avoid manual calendar checks, and inform requesters about confirmed upcoming use.
-- ## Outputs Format
SELECT
    br.booking_id,
    br.unique_space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    br.requested_start_time,
    br.requested_end_time,
    br.booking_type,
    br.purpose_of_use,
    br.expected_number_of_participants,
    requester.full_name AS requester_name,
    requester.role AS requester_role,
    requester.department AS requester_department
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s
    ON s.unique_space_code = br.unique_space_code
INNER JOIN dbo.USER_ACCOUNT AS requester
    ON requester.user_id = br.requester_user_id
WHERE br.status = N'Approved'
  AND br.requested_start_time >= SYSDATETIME()
ORDER BY br.requested_start_time, s.building, s.room_number;
GO

-- Query 2: Available spaces for requested time and capacity
-- Business question: Which spaces can host a requested booking time range and minimum capacity without conflicting with approved bookings?
-- Target user(s): Students, lecturers, teaching assistants, department administrators, facility staff
-- Why this query is useful: It supports self-service room search before submitting a booking request and avoids unavailable or conflicting spaces.
-- ## Outputs Format
SELECT
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status,
    STRING_AGG(f.facility_name, N', ') WITHIN GROUP (ORDER BY f.facility_name) AS available_facilities
FROM dbo.SPACE AS s
LEFT JOIN dbo.SPACE_FACILITY AS sf
    ON sf.unique_space_code = s.unique_space_code
LEFT JOIN dbo.FACILITY AS f
    ON f.facility_id = sf.facility_id
WHERE s.current_status IN (N'Available', N'In use')
  AND s.capacity >= 20
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.BOOKING_REQUEST AS br
      WHERE br.unique_space_code = s.unique_space_code
        AND br.status = N'Approved'
        AND br.requested_start_time < CAST('2026-07-02T12:00:00' AS DATETIME2(0))
        AND CAST('2026-07-02T10:00:00' AS DATETIME2(0)) < br.requested_end_time
  )
GROUP BY
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status
ORDER BY s.capacity, s.building, s.room_number;
GO

-- Query 3: Spaces currently under maintenance
-- Business question: Which spaces are currently marked under maintenance, and what maintenance work is associated with them?
-- Target user(s): Facility staff, facility managers
-- Why this query is useful: It gives operations staff a quick view of unavailable spaces and the assigned maintenance responsibility.
-- ## Outputs Format
SELECT
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.current_status,
    mr.maintenance_record_id,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    mr.status AS maintenance_status,
    assigned.full_name AS assigned_staff_name,
    reporter.full_name AS reporter_name
FROM dbo.SPACE AS s
LEFT JOIN dbo.MAINTENANCE_RECORD AS mr
    ON mr.unique_space_code = s.unique_space_code
LEFT JOIN dbo.USER_ACCOUNT AS assigned
    ON assigned.user_id = mr.assigned_to_user_id
LEFT JOIN dbo.USER_ACCOUNT AS reporter
    ON reporter.user_id = mr.reported_by_user_id
WHERE s.current_status = N'Under maintenance'
ORDER BY mr.start_time DESC, s.unique_space_code;
GO

-- Query 4: No-show bookings
-- Business question: Which bookings were marked as no-show, and who submitted them?
-- Target user(s): Facility staff, facility managers, department administrators
-- Why this query is useful: It supports follow-up with requesters and helps identify patterns of unused reserved spaces.
-- ## Outputs Format
SELECT
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.booking_type,
    br.expected_number_of_participants,
    s.unique_space_code,
    s.space_name,
    requester.user_id AS requester_user_id,
    requester.full_name AS requester_name,
    requester.role AS requester_role,
    requester.department AS requester_department
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s
    ON s.unique_space_code = br.unique_space_code
INNER JOIN dbo.USER_ACCOUNT AS requester
    ON requester.user_id = br.requester_user_id
WHERE br.status = N'No-show'
ORDER BY br.requested_start_time DESC;
GO

-- Query 5: Rejected bookings and rejection reasons
-- Business question: Which booking requests were rejected, what reasons were recorded, and who made the decision?
-- Target user(s): Facility managers, facility staff, department administrators, requesters
-- Why this query is useful: It provides transparency about rejected requests and helps departments improve future booking submissions.
-- ## Outputs Format
SELECT
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.booking_type,
    requester.full_name AS requester_name,
    requester.department AS requester_department,
    s.space_name,
    ad.decision_time,
    decision_maker.full_name AS decision_maker_name,
    decision_maker.role AS decision_maker_role,
    ad.decision_note,
    ad.rejection_reason
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS requester
    ON requester.user_id = br.requester_user_id
INNER JOIN dbo.SPACE AS s
    ON s.unique_space_code = br.unique_space_code
LEFT JOIN dbo.APPROVAL_DECISION AS ad
    ON ad.booking_id = br.booking_id
LEFT JOIN dbo.USER_ACCOUNT AS decision_maker
    ON decision_maker.user_id = ad.decision_maker_user_id
WHERE br.status = N'Rejected'
ORDER BY ad.decision_time DESC, br.booking_id;
GO

-- Query 6: Booking count by department and booking status
-- Business question: How many booking requests has each department submitted by status?
-- Target user(s): Department administrators, facility managers
-- Why this query is useful: It summarizes demand, cancellations, no-shows, approvals, and rejections by department for planning and governance.
-- ## Outputs Format
SELECT
    requester.department,
    br.status,
    COUNT(*) AS booking_count,
    SUM(br.expected_number_of_participants) AS total_expected_participants,
    MIN(br.requested_start_time) AS earliest_request_time,
    MAX(br.requested_start_time) AS latest_request_time
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS requester
    ON requester.user_id = br.requester_user_id
GROUP BY requester.department, br.status
ORDER BY requester.department, br.status;
GO

-- Query 7: Users with the most booking requests
-- Business question: Which users submit the most booking requests, and what is their booking-status mix?
-- Target user(s): Facility managers, department administrators
-- Why this query is useful: It identifies high-demand users and helps managers understand recurring requester behavior.
-- ## Outputs Format
SELECT
    requester.user_id,
    requester.full_name,
    requester.role,
    requester.department,
    COUNT(*) AS total_bookings,
    SUM(CASE WHEN br.status = N'Approved' THEN 1 ELSE 0 END) AS approved_bookings,
    SUM(CASE WHEN br.status = N'Rejected' THEN 1 ELSE 0 END) AS rejected_bookings,
    SUM(CASE WHEN br.status = N'Cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings,
    SUM(CASE WHEN br.status = N'No-show' THEN 1 ELSE 0 END) AS no_show_bookings
FROM dbo.USER_ACCOUNT AS requester
INNER JOIN dbo.BOOKING_REQUEST AS br
    ON br.requester_user_id = requester.user_id
GROUP BY
    requester.user_id,
    requester.full_name,
    requester.role,
    requester.department
ORDER BY total_bookings DESC, requester.full_name;
GO

-- Query 8: Maintenance history for each room
-- Business question: What maintenance issues have been reported for each room, and who reported and handled them?
-- Target user(s): Facility staff, facility managers
-- Why this query is useful: It preserves maintenance history for operational follow-up, recurring problem analysis, and room-readiness checks.
-- ## Outputs Format
SELECT
    s.unique_space_code,
    s.space_name,
    s.current_status AS space_status,
    mr.maintenance_record_id,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    mr.status AS maintenance_status,
    mr.result_note,
    reporter.full_name AS reported_by_name,
    assigned.full_name AS assigned_to_name
FROM dbo.MAINTENANCE_RECORD AS mr
INNER JOIN dbo.SPACE AS s
    ON s.unique_space_code = mr.unique_space_code
INNER JOIN dbo.USER_ACCOUNT AS reporter
    ON reporter.user_id = mr.reported_by_user_id
INNER JOIN dbo.USER_ACCOUNT AS assigned
    ON assigned.user_id = mr.assigned_to_user_id
ORDER BY s.unique_space_code, mr.start_time DESC;
GO

-- Query 9: Space utilization summary by building and space type
-- Business question: How much requested booking time is associated with each building and space type?
-- Target user(s): Facility managers, department administrators
-- Why this query is useful: It supports facility utilization reporting and helps identify heavily requested categories of spaces.
-- ## Outputs Format
SELECT
    s.building,
    s.space_type,
    COUNT(br.booking_id) AS booking_count,
    SUM(CASE WHEN br.status IN (N'Approved', N'Checked in', N'Completed') THEN 1 ELSE 0 END) AS active_or_completed_booking_count,
    CAST(SUM(DATEDIFF(MINUTE, br.requested_start_time, br.requested_end_time)) / 60.0 AS DECIMAL(10, 2)) AS requested_hours,
    AVG(CAST(br.expected_number_of_participants AS DECIMAL(10, 2))) AS average_expected_participants
FROM dbo.SPACE AS s
INNER JOIN dbo.BOOKING_REQUEST AS br
    ON br.unique_space_code = s.unique_space_code
GROUP BY s.building, s.space_type
ORDER BY requested_hours DESC, booking_count DESC;
GO

-- Query 10: Facility-equipped spaces for teaching and events
-- Business question: Which available spaces have key facilities such as projector, microphone, or livestreaming equipment?
-- Target user(s): Lecturers, department administrators, facility staff, facility managers
-- Why this query is useful: It helps requesters and staff find rooms suitable for lectures, seminars, workshops, and large academic events.
-- ## Outputs Format
SELECT
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.room_number,
    s.capacity,
    STRING_AGG(f.facility_name, N', ') WITHIN GROUP (ORDER BY f.facility_name) AS matching_facilities
FROM dbo.SPACE AS s
INNER JOIN dbo.SPACE_FACILITY AS sf
    ON sf.unique_space_code = s.unique_space_code
INNER JOIN dbo.FACILITY AS f
    ON f.facility_id = sf.facility_id
WHERE s.current_status IN (N'Available', N'In use')
  AND f.facility_name IN (N'Projector', N'Microphone', N'Livestreaming equipment')
GROUP BY
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.room_number,
    s.capacity
ORDER BY s.capacity DESC, s.space_name;
GO
