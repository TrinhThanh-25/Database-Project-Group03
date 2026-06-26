/*
    SQL Query Design - Group 03
    Target DBMS: Microsoft SQL Server

    Inputs analyzed:
    - outputs/01-business-req-analysis-G03.md
    - outputs/05-db-definition-G03.sql
    - outputs/06-sample-data-G03.sql

    Notes:
    - All queries are read-only SELECT statements.
    - Queries use only implemented tables and columns from outputs/05-db-definition-G03.sql.
    - APPROVAL_DECISION has no separate outcome column in the current DDL; approval/rejection meaning is inferred from BOOKING_REQUEST.booking_status.
*/

-- Query 1: Upcoming approved bookings for a space
-- Business question: What approved bookings are upcoming for a specific campus space?
-- Target user(s): Facility Staff, Facility Manager, Lecturer, Student
-- Why this query is useful: It helps staff and requesters see scheduled use for one room and avoid confusion about future occupancy.
SELECT
    br.booking_id,
    sp.unique_space_code,
    sp.space_name,
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
WHERE br.booking_status = N'Approved'
  AND br.requested_start_time >= SYSDATETIME()
  AND sp.unique_space_code = N'SPACE-CLS-101'
ORDER BY br.requested_start_time;

-- Query 2: Available spaces for requested time and capacity
-- Business question: Which available spaces can fit at least 20 participants and have no approved overlap for a requested time range?
-- Target user(s): Student, Lecturer, Teaching Assistant, Department Administrator
-- Why this query is useful: It supports booking submission by showing realistic candidate rooms before a user requests a space.
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
WHERE sp.current_status = N'Available'
  AND sp.capacity >= 20
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.BOOKING_REQUEST AS br
      WHERE br.space_id = sp.space_id
        AND br.booking_status = N'Approved'
        AND br.requested_start_time < CAST('2026-07-02T12:00:00' AS DATETIME2(0))
        AND CAST('2026-07-02T10:00:00' AS DATETIME2(0)) < br.requested_end_time
  )
ORDER BY sp.building, sp.floor, sp.room_number;

-- Query 3: Spaces currently under maintenance
-- Business question: Which spaces are currently marked under maintenance and what is their latest maintenance context?
-- Target user(s): Facility Staff, Facility Manager
-- Why this query is useful: It helps operations staff track unavailable rooms and understand the most recent maintenance issue affecting each room.
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.building,
    sp.floor,
    sp.room_number,
    sp.current_status,
    latest_mr.maintenance_record_id,
    latest_mr.problem_description,
    latest_mr.start_time,
    latest_mr.status AS maintenance_status,
    latest_mr.result_note,
    assigned.full_name AS assigned_staff_name
FROM dbo.SPACE AS sp
OUTER APPLY
(
    SELECT TOP (1)
        mr.maintenance_record_id,
        mr.problem_description,
        mr.start_time,
        mr.status,
        mr.result_note,
        mr.assigned_staff_user_account_id
    FROM dbo.MAINTENANCE_RECORD AS mr
    WHERE mr.space_id = sp.space_id
    ORDER BY mr.start_time DESC, mr.maintenance_record_id DESC
) AS latest_mr
LEFT JOIN dbo.USER_ACCOUNT AS assigned
    ON assigned.user_account_id = latest_mr.assigned_staff_user_account_id
WHERE sp.current_status = N'Under maintenance'
ORDER BY latest_mr.start_time DESC, sp.unique_space_code;

-- Query 4: No-show booking report
-- Business question: Which bookings were marked as no-show, and who submitted them?
-- Target user(s): Facility Staff, Facility Manager, Department Administrator
-- Why this query is useful: It supports follow-up on missed reservations and helps identify patterns of wasted space usage.
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
WHERE br.booking_status = N'No-show'
ORDER BY br.requested_start_time DESC;

-- Query 5: Rejected bookings and reasons
-- Business question: Which bookings were rejected and what rejection reasons were recorded?
-- Target user(s): Facility Staff, Facility Manager, Department Administrator
-- Why this query is useful: It provides an audit trail for rejected requests and helps departments understand why requests were denied.
SELECT
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    ua.full_name AS requester_name,
    ua.department AS requester_department,
    sp.unique_space_code,
    sp.space_name,
    ad.approval_decision_id,
    dm.full_name AS decision_maker_name,
    dm.role AS decision_maker_role,
    ad.decision_time,
    ad.decision_note,
    ad.rejection_reason
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id
LEFT JOIN dbo.APPROVAL_DECISION AS ad
    ON ad.booking_id = br.booking_id
LEFT JOIN dbo.USER_ACCOUNT AS dm
    ON dm.user_account_id = ad.decision_maker_user_account_id
WHERE br.booking_status = N'Rejected'
ORDER BY ad.decision_time DESC, br.booking_id;

-- Query 6: Booking counts by department and status
-- Business question: How many bookings has each department submitted by booking status?
-- Target user(s): Department Administrator, Facility Manager
-- Why this query is useful: It shows demand and outcomes by department, supporting planning and fairness monitoring.
SELECT
    ua.department,
    br.booking_status,
    COUNT(*) AS booking_count,
    SUM(br.expected_number_of_participants) AS total_expected_participants
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
GROUP BY ua.department, br.booking_status
ORDER BY ua.department, br.booking_status;

-- Query 7: Users with the most bookings
-- Business question: Which users submit the highest number of booking requests?
-- Target user(s): Facility Manager, Department Administrator
-- Why this query is useful: It identifies high-demand users or teams and helps managers understand booking workload patterns.
SELECT TOP (10)
    ua.user_account_id,
    ua.user_id,
    ua.full_name,
    ua.role,
    ua.department,
    COUNT(br.booking_id) AS total_bookings,
    SUM(CASE WHEN br.booking_status = N'Approved' THEN 1 ELSE 0 END) AS approved_bookings,
    SUM(CASE WHEN br.booking_status = N'Rejected' THEN 1 ELSE 0 END) AS rejected_bookings,
    SUM(CASE WHEN br.booking_status = N'No-show' THEN 1 ELSE 0 END) AS no_show_bookings
FROM dbo.USER_ACCOUNT AS ua
LEFT JOIN dbo.BOOKING_REQUEST AS br
    ON br.requester_user_account_id = ua.user_account_id
GROUP BY ua.user_account_id, ua.user_id, ua.full_name, ua.role, ua.department
ORDER BY total_bookings DESC, ua.full_name;

-- Query 8: Space utilization summary
-- Business question: Which spaces are most used based on booking counts and completed usage hours?
-- Target user(s): Facility Manager, Facility Staff
-- Why this query is useful: It supports utilization review, capacity planning, and decisions about room maintenance or upgrades.
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.building,
    sp.capacity,
    COUNT(br.booking_id) AS total_bookings,
    SUM(CASE WHEN br.booking_status IN (N'Approved', N'Checked in', N'Completed') THEN 1 ELSE 0 END) AS active_or_successful_bookings,
    SUM(CASE WHEN br.booking_status = N'No-show' THEN 1 ELSE 0 END) AS no_show_bookings,
    CAST(COALESCE(SUM(CASE
        WHEN us.actual_end_time IS NOT NULL THEN DATEDIFF(MINUTE, us.actual_start_time, us.actual_end_time)
        ELSE 0
    END), 0) / 60.0 AS DECIMAL(10,2)) AS completed_usage_hours
FROM dbo.SPACE AS sp
LEFT JOIN dbo.BOOKING_REQUEST AS br
    ON br.space_id = sp.space_id
LEFT JOIN dbo.USAGE_SESSION AS us
    ON us.booking_id = br.booking_id
GROUP BY sp.space_id, sp.unique_space_code, sp.space_name, sp.space_type, sp.building, sp.capacity
ORDER BY total_bookings DESC, completed_usage_hours DESC, sp.unique_space_code;

-- Query 9: Facilities available in each bookable space
-- Business question: What facilities are available in each available space?
-- Target user(s): Student, Lecturer, Teaching Assistant, Department Administrator
-- Why this query is useful: It helps requesters choose a room that has the equipment needed for their booking purpose.
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.capacity,
    STRING_AGG(f.facility_name, N', ') WITHIN GROUP (ORDER BY f.facility_name) AS available_facilities
FROM dbo.SPACE AS sp
LEFT JOIN dbo.SPACE_FACILITY AS sf
    ON sf.space_id = sp.space_id
LEFT JOIN dbo.FACILITY AS f
    ON f.facility_id = sf.facility_id
WHERE sp.current_status = N'Available'
GROUP BY sp.space_id, sp.unique_space_code, sp.space_name, sp.space_type, sp.capacity
ORDER BY sp.space_type, sp.capacity DESC, sp.unique_space_code;

-- Query 10: Maintenance history for a room
-- Business question: What maintenance records exist for a specific room?
-- Target user(s): Facility Staff, Facility Manager
-- Why this query is useful: It provides the historical maintenance context needed before approving events or planning repairs.
SELECT
    mr.maintenance_record_id,
    sp.unique_space_code,
    sp.space_name,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    mr.status,
    mr.result_note,
    reporter.full_name AS reporter_name,
    assigned.full_name AS assigned_staff_name
FROM dbo.MAINTENANCE_RECORD AS mr
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = mr.space_id
INNER JOIN dbo.USER_ACCOUNT AS reporter
    ON reporter.user_account_id = mr.reporter_user_account_id
INNER JOIN dbo.USER_ACCOUNT AS assigned
    ON assigned.user_account_id = mr.assigned_staff_user_account_id
WHERE sp.unique_space_code = N'SPACE-CLS-101'
ORDER BY mr.start_time DESC, mr.maintenance_record_id DESC;

-- Query 11: Approval workload by decision maker
-- Business question: How many approval decisions has each facility staff member or manager made, and how many related bookings were rejected?
-- Target user(s): Facility Manager
-- Why this query is useful: It helps monitor approval workload distribution and rejection volume among authorized approvers.
SELECT
    dm.user_account_id AS decision_maker_user_account_id,
    dm.user_id AS decision_maker_user_id,
    dm.full_name AS decision_maker_name,
    dm.role AS decision_maker_role,
    COUNT(ad.approval_decision_id) AS total_decisions,
    SUM(CASE WHEN br.booking_status = N'Approved' THEN 1 ELSE 0 END) AS approved_related_bookings,
    SUM(CASE WHEN br.booking_status = N'Rejected' THEN 1 ELSE 0 END) AS rejected_related_bookings,
    MIN(ad.decision_time) AS first_decision_time,
    MAX(ad.decision_time) AS latest_decision_time
FROM dbo.APPROVAL_DECISION AS ad
INNER JOIN dbo.USER_ACCOUNT AS dm
    ON dm.user_account_id = ad.decision_maker_user_account_id
INNER JOIN dbo.BOOKING_REQUEST AS br
    ON br.booking_id = ad.booking_id
GROUP BY dm.user_account_id, dm.user_id, dm.full_name, dm.role
ORDER BY total_decisions DESC, dm.full_name;

-- Query 12: Usage session completion details
-- Business question: Which checked-in or completed sessions have actual usage details and staff action records?
-- Target user(s): Facility Staff, Facility Manager
-- Why this query is useful: It supports operational handover by showing in-progress and completed sessions with condition notes and responsible staff.
SELECT
    us.usage_session_id,
    br.booking_id,
    br.booking_status,
    sp.unique_space_code,
    sp.space_name,
    requester.full_name AS requester_name,
    us.actual_start_time,
    us.actual_end_time,
    CASE
        WHEN us.actual_end_time IS NULL THEN N'In progress'
        ELSE N'Completed'
    END AS usage_session_state,
    checkin_staff.full_name AS checked_in_by,
    completion_staff.full_name AS completed_by,
    us.initial_condition_of_space,
    us.final_condition_of_space,
    us.usage_notes
FROM dbo.USAGE_SESSION AS us
INNER JOIN dbo.BOOKING_REQUEST AS br
    ON br.booking_id = us.booking_id
INNER JOIN dbo.SPACE AS sp
    ON sp.space_id = br.space_id
INNER JOIN dbo.USER_ACCOUNT AS requester
    ON requester.user_account_id = br.requester_user_account_id
INNER JOIN dbo.USER_ACCOUNT AS checkin_staff
    ON checkin_staff.user_account_id = us.checked_in_by_user_account_id
LEFT JOIN dbo.USER_ACCOUNT AS completion_staff
    ON completion_staff.user_account_id = us.completed_by_user_account_id
ORDER BY us.actual_start_time DESC, us.usage_session_id DESC;
