/*
    SQL Query Design - Group 03
    Target DBMS: Microsoft SQL Server

    Source inputs:
    - outputs/01-business-req-analysis-G03.md
    - outputs/05-db-definition-G03.sql
    - outputs/06-sample-data-G03.sql

    All statements below are read-only SELECT queries.
*/

-- Query 1: Upcoming approved bookings by space
-- Business question: Which approved bookings are coming up for each bookable space?
-- Target user(s): Facility Staff, Facility Manager, Lecturers, Department Administrators
-- Why this query is useful: It supports the requirement for staff to view upcoming bookings and helps prevent scheduling confusion before room usage begins.
SELECT
    sp.unique_space_code,
    sp.space_name,
    sp.building,
    sp.floor,
    sp.room_number,
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.expected_number_of_participants,
    ua.user_id AS requester_user_id,
    ua.full_name AS requester_name,
    ua.role AS requester_role
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
WHERE br.booking_status = 'Approved'
  AND br.requested_start_time >= SYSDATETIME()
ORDER BY
    sp.unique_space_code,
    br.requested_start_time;

-- Query 2: Available spaces for requested time and capacity
-- Business question: Which spaces can support a requested time range and participant count without conflicting with approved bookings?
-- Target user(s): Students, Lecturers, Teaching Assistants, Department Administrators
-- Why this query is useful: It helps requesters and staff identify suitable rooms before submitting or approving a booking request.
WITH RequestedTime AS
(
    SELECT
        CAST('2026-07-01T09:00:00' AS DATETIME2(0)) AS requested_start_time,
        CAST('2026-07-01T12:00:00' AS DATETIME2(0)) AS requested_end_time,
        CAST(30 AS INT) AS required_capacity
)
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.building,
    sp.floor,
    sp.room_number,
    sp.capacity,
    sp.current_status
FROM dbo.SPACE AS sp
CROSS JOIN RequestedTime AS rt
WHERE sp.current_status = 'Available'
  AND sp.capacity >= rt.required_capacity
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.BOOKING_REQUEST AS br
      WHERE br.space_id = sp.space_id
        AND br.booking_status = 'Approved'
        AND br.requested_start_time < rt.requested_end_time
        AND rt.requested_start_time < br.requested_end_time
  )
ORDER BY
    sp.capacity,
    sp.unique_space_code;

-- Query 3: Spaces currently under maintenance
-- Business question: Which spaces are currently marked as under maintenance, and what maintenance records are associated with them?
-- Target user(s): Facility Staff, Facility Manager
-- Why this query is useful: It helps staff monitor unavailable rooms and understand the maintenance work affecting booking availability.
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.building,
    sp.room_number,
    mr.maintenance_record_id,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    mr.status AS maintenance_status,
    assigned.full_name AS assigned_staff_name
FROM dbo.SPACE AS sp
LEFT JOIN dbo.MAINTENANCE_RECORD AS mr
    ON mr.space_id = sp.space_id
LEFT JOIN dbo.USER_ACCOUNT AS assigned
    ON assigned.user_account_id = mr.assigned_staff_user_account_id
WHERE sp.current_status = 'Under maintenance'
ORDER BY
    sp.unique_space_code,
    mr.start_time DESC;

-- Query 4: No-show bookings with requester details
-- Business question: Which bookings were marked as no-show, and who submitted them?
-- Target user(s): Facility Staff, Facility Manager, Department Administrators
-- Why this query is useful: It supports monitoring repeated no-shows and helps staff review unused reserved space.
SELECT
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.expected_number_of_participants,
    ua.user_id AS requester_user_id,
    ua.full_name AS requester_name,
    ua.role AS requester_role,
    ua.department,
    sp.unique_space_code,
    sp.space_name
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id
WHERE br.booking_status = 'No-show'
ORDER BY
    br.requested_start_time DESC;

-- Query 5: Rejected bookings and rejection reasons
-- Business question: Which booking requests were rejected, and what reasons were recorded?
-- Target user(s): Facility Staff, Facility Manager, Department Administrators, Requesters
-- Why this query is useful: It provides transparency about rejected bookings and helps identify common rejection causes.
SELECT
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    ua.user_id AS requester_user_id,
    ua.full_name AS requester_name,
    sp.unique_space_code,
    sp.space_name,
    ad.decision_time,
    decision_maker.full_name AS decision_maker_name,
    ad.decision_note,
    ad.rejection_reason
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.APPROVAL_DECISION AS ad
    ON ad.booking_id = br.booking_id
INNER JOIN dbo.USER_ACCOUNT AS decision_maker
    ON decision_maker.user_account_id = ad.decision_maker_user_account_id
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id
WHERE br.booking_status = 'Rejected'
  AND ad.decision_outcome = 'Rejected'
ORDER BY
    ad.decision_time DESC;

-- Query 6: Booking count by department and status
-- Business question: How many bookings has each department submitted, grouped by booking status?
-- Target user(s): Department Administrators, Facility Manager
-- Why this query is useful: It helps administrators understand demand patterns and review departmental usage of shared spaces.
SELECT
    ua.department,
    br.booking_status,
    COUNT(*) AS booking_count,
    SUM(br.expected_number_of_participants) AS total_expected_participants
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
GROUP BY
    ua.department,
    br.booking_status
ORDER BY
    ua.department,
    br.booking_status;

-- Query 7: Most active requesters
-- Business question: Which users have submitted the most booking requests?
-- Target user(s): Facility Manager, Department Administrators
-- Why this query is useful: It identifies high-demand users or groups and supports fair management of shared space usage.
SELECT TOP (10)
    ua.user_account_id,
    ua.user_id,
    ua.full_name,
    ua.role,
    ua.department,
    COUNT(br.booking_id) AS total_bookings,
    SUM(CASE WHEN br.booking_status = 'Approved' THEN 1 ELSE 0 END) AS approved_bookings,
    SUM(CASE WHEN br.booking_status = 'Rejected' THEN 1 ELSE 0 END) AS rejected_bookings,
    SUM(CASE WHEN br.booking_status = 'No-show' THEN 1 ELSE 0 END) AS no_show_bookings
FROM dbo.USER_ACCOUNT AS ua
INNER JOIN dbo.BOOKING_REQUEST AS br
    ON br.requester_user_account_id = ua.user_account_id
GROUP BY
    ua.user_account_id,
    ua.user_id,
    ua.full_name,
    ua.role,
    ua.department
ORDER BY
    total_bookings DESC,
    approved_bookings DESC,
    ua.full_name;

-- Query 8: Space utilization summary by approved and completed bookings
-- Business question: Which spaces have the most approved/completed booking hours and participant demand?
-- Target user(s): Facility Manager, Facility Staff
-- Why this query is useful: It supports facility utilization reporting and helps managers identify heavily used spaces.
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.building,
    COUNT(br.booking_id) AS booking_count,
    SUM(DATEDIFF(MINUTE, br.requested_start_time, br.requested_end_time)) / 60.0 AS booked_hours,
    SUM(br.expected_number_of_participants) AS total_expected_participants,
    AVG(CAST(br.expected_number_of_participants AS DECIMAL(10,2))) AS average_expected_participants
FROM dbo.SPACE AS sp
INNER JOIN dbo.BOOKING_REQUEST AS br
    ON br.space_id = sp.space_id
WHERE br.booking_status IN ('Approved', 'Checked in', 'Completed')
GROUP BY
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.building
ORDER BY
    booked_hours DESC,
    booking_count DESC;

-- Query 9: Maintenance history for a selected room
-- Business question: What maintenance work has been recorded for a specific space?
-- Target user(s): Facility Staff, Facility Manager
-- Why this query is useful: It supports maintenance follow-up, room condition review, and future repair planning.
SELECT
    sp.unique_space_code,
    sp.space_name,
    mr.maintenance_record_id,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    mr.status,
    reporter.full_name AS reporter_name,
    assigned.full_name AS assigned_staff_name,
    mr.result_note
FROM dbo.MAINTENANCE_RECORD AS mr
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = mr.space_id
INNER JOIN dbo.USER_ACCOUNT AS reporter
    ON reporter.user_account_id = mr.reporter_user_account_id
INNER JOIN dbo.USER_ACCOUNT AS assigned
    ON assigned.user_account_id = mr.assigned_staff_user_account_id
WHERE sp.unique_space_code = 'CS-B202'
ORDER BY
    mr.start_time DESC;

-- Query 10: Spaces with selected facilities
-- Business question: Which spaces provide the facilities needed for a class, workshop, or event?
-- Target user(s): Students, Lecturers, Teaching Assistants, Facility Staff
-- Why this query is useful: It helps users find rooms with required equipment such as projectors, computers, microphones, or livestreaming equipment.
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.capacity,
    sp.current_status,
    STRING_AGG(f.facility_name, ', ') WITHIN GROUP (ORDER BY f.facility_name) AS available_facilities
FROM dbo.SPACE AS sp
INNER JOIN dbo.SPACE_FACILITY AS sf
    ON sf.space_id = sp.space_id
INNER JOIN dbo.FACILITY AS f
    ON f.facility_id = sf.facility_id
WHERE f.facility_name IN ('Projector', 'Computer', 'Livestreaming equipment')
GROUP BY
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.capacity,
    sp.current_status
HAVING COUNT(DISTINCT f.facility_name) >= 2
ORDER BY
    sp.current_status,
    sp.capacity DESC;

-- Query 11: Usage session completion details
-- Business question: Which completed sessions have actual usage times, space conditions, and staff completion records?
-- Target user(s): Facility Staff, Facility Manager
-- Why this query is useful: It supports review of completed room usage and checks whether space condition notes were captured.
SELECT
    br.booking_id,
    br.purpose_of_use,
    sp.unique_space_code,
    sp.space_name,
    us.actual_start_time,
    us.actual_end_time,
    DATEDIFF(MINUTE, us.actual_start_time, us.actual_end_time) AS actual_duration_minutes,
    us.initial_condition_of_space,
    us.final_condition_of_space,
    checkin_user.full_name AS checked_in_by,
    completion_user.full_name AS completed_by,
    us.usage_notes
FROM dbo.USAGE_SESSION AS us
INNER JOIN dbo.BOOKING_REQUEST AS br
    ON br.booking_id = us.booking_id
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id
INNER JOIN dbo.USER_ACCOUNT AS checkin_user
    ON checkin_user.user_account_id = us.checked_in_by_user_account_id
LEFT JOIN dbo.USER_ACCOUNT AS completion_user
    ON completion_user.user_account_id = us.completed_by_user_account_id
WHERE us.actual_end_time IS NOT NULL
ORDER BY
    us.actual_end_time DESC;

-- Query 12: Booking approval workload by decision maker
-- Business question: How many approval or rejection decisions has each facility staff member or manager made?
-- Target user(s): Facility Manager
-- Why this query is useful: It helps monitor approval workload and review decision outcomes by staff member.
SELECT
    ua.user_account_id,
    ua.user_id,
    ua.full_name AS decision_maker_name,
    ua.role,
    COUNT(ad.approval_decision_id) AS total_decisions,
    SUM(CASE WHEN ad.decision_outcome = 'Approved' THEN 1 ELSE 0 END) AS approved_decisions,
    SUM(CASE WHEN ad.decision_outcome = 'Rejected' THEN 1 ELSE 0 END) AS rejected_decisions,
    MIN(ad.decision_time) AS first_decision_time,
    MAX(ad.decision_time) AS latest_decision_time
FROM dbo.APPROVAL_DECISION AS ad
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = ad.decision_maker_user_account_id
GROUP BY
    ua.user_account_id,
    ua.user_id,
    ua.full_name,
    ua.role
ORDER BY
    total_decisions DESC,
    ua.full_name;
