-- ============================================================
-- SQL QUERY DESIGN - G03
-- Campus Space Management System
-- Target DBMS: Microsoft SQL Server
-- Inputs analyzed:
--   - outputs/01-business-req-analysis-G03.md
--   - outputs/05-db-definition-G03.sql
--   - outputs/06-sample-data-G03.sql
-- Notes:
--   - All statements are read-only SELECT queries.
--   - Queries use actual table and column names from outputs/05-db-definition-G03.sql.
-- ============================================================

-- Query 1: Upcoming approved bookings by space
-- Business question:
-- Which approved bookings are scheduled for a selected space from now onward?
-- Target user(s):
-- Facility staff, lecturers, students, department administrators
-- Why this query is useful:
-- It helps staff and requesters see future confirmed usage for a room and avoid schedule confusion.
-- ## Outputs Format
SELECT
    br.booking_id,
    s.unique_space_code,
    s.space_name,
    s.space_type,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.expected_number_of_participants,
    ua.full_name AS requester_name,
    ua.role AS requester_role
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s
    ON s.space_id = br.space_id
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
WHERE br.status = N'Approved'
  AND br.requested_start_time >= GETDATE()
  AND s.unique_space_code = N'S-CLS-101'
ORDER BY br.requested_start_time;

-- Query 2: Available spaces for requested time and capacity
-- Business question:
-- Which available spaces can support a requested time range and minimum participant count?
-- Target user(s):
-- Students, lecturers, teaching assistants, department administrators
-- Why this query is useful:
-- It supports booking request preparation by finding rooms that are available, large enough, and not already approved for an overlapping booking.
-- ## Outputs Format
SELECT
    s.space_id,
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity,
    s.current_status
FROM dbo.SPACE AS s
WHERE s.current_status = N'Available'
  AND s.capacity >= 30
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.BOOKING_REQUEST AS br
      WHERE br.space_id = s.space_id
        AND br.status = N'Approved'
        AND CAST('2026-07-02T10:00:00' AS DATETIME2(0)) < br.requested_end_time
        AND CAST('2026-07-02T12:00:00' AS DATETIME2(0)) > br.requested_start_time
  )
ORDER BY s.capacity ASC, s.building, s.room_number;

-- Query 3: Spaces currently unavailable for booking
-- Business question:
-- Which spaces are currently under maintenance, temporarily closed, or retired, and what maintenance context is available?
-- Target user(s):
-- Facility staff, facility managers
-- Why this query is useful:
-- It helps facility teams monitor unavailable spaces and communicate why a room cannot be booked.
-- ## Outputs Format
SELECT
    s.space_id,
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.current_status,
    mr.maintenance_record_id,
    mr.status AS maintenance_status,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    reporter.full_name AS reported_by,
    assigned.full_name AS assigned_staff
FROM dbo.SPACE AS s
LEFT JOIN dbo.MAINTENANCE_RECORD AS mr
    ON mr.space_id = s.space_id
LEFT JOIN dbo.USER_ACCOUNT AS reporter
    ON reporter.user_account_id = mr.reporter_user_account_id
LEFT JOIN dbo.USER_ACCOUNT AS assigned
    ON assigned.user_account_id = mr.assigned_staff_user_account_id
WHERE s.current_status IN (N'Under maintenance', N'Temporarily closed', N'Retired')
ORDER BY s.current_status, s.unique_space_code, mr.start_time DESC;

-- Query 4: No-show booking report
-- Business question:
-- Which bookings were marked as no-show, and who requested them?
-- Target user(s):
-- Facility staff, facility managers, department administrators
-- Why this query is useful:
-- It supports follow-up with requesters and helps identify repeated non-use of booked resources.
-- ## Outputs Format
SELECT
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.expected_number_of_participants,
    ua.user_id,
    ua.full_name AS requester_name,
    ua.role AS requester_role,
    ua.department,
    s.unique_space_code,
    s.space_name
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
INNER JOIN dbo.SPACE AS s
    ON s.space_id = br.space_id
WHERE br.status = N'No-show'
ORDER BY br.requested_start_time DESC;

-- Query 5: Rejected bookings and reasons
-- Business question:
-- Which booking requests were rejected, why were they rejected, and who made the decision?
-- Target user(s):
-- Facility managers, facility staff, department administrators
-- Why this query is useful:
-- It provides accountability for approval decisions and helps analyze common rejection reasons.
-- ## Outputs Format
SELECT
    br.booking_id,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    requester.full_name AS requester_name,
    s.unique_space_code,
    s.space_name,
    ad.approval_decision_id,
    ad.decision_time,
    ad.decision_note,
    ad.rejection_reason,
    decision_maker.full_name AS decision_maker_name,
    decision_maker.role AS decision_maker_role
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.APPROVAL_DECISION AS ad
    ON ad.booking_id = br.booking_id
INNER JOIN dbo.USER_ACCOUNT AS requester
    ON requester.user_account_id = br.requester_user_account_id
INNER JOIN dbo.USER_ACCOUNT AS decision_maker
    ON decision_maker.user_account_id = ad.decision_maker_user_account_id
INNER JOIN dbo.SPACE AS s
    ON s.space_id = br.space_id
WHERE br.status = N'Rejected'
  AND ad.decision_outcome = N'Rejected'
ORDER BY ad.decision_time DESC;

-- Query 6: Booking counts by department and status
-- Business question:
-- How many booking requests does each department submit by booking status?
-- Target user(s):
-- Department administrators, facility managers
-- Why this query is useful:
-- It helps compare demand and outcomes across departments and identify departments with many pending, rejected, or no-show bookings.
-- ## Outputs Format
SELECT
    COALESCE(ua.department, N'(No department recorded)') AS department,
    br.status,
    COUNT(*) AS booking_count,
    SUM(br.expected_number_of_participants) AS total_expected_participants
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.USER_ACCOUNT AS ua
    ON ua.user_account_id = br.requester_user_account_id
GROUP BY COALESCE(ua.department, N'(No department recorded)'), br.status
ORDER BY department, br.status;

-- Query 7: Space utilization from completed sessions
-- Business question:
-- Which spaces have the most completed usage time based on recorded actual sessions?
-- Target user(s):
-- Facility managers, facility staff
-- Why this query is useful:
-- It summarizes actual room utilization and supports planning for cleaning, maintenance, and capacity management.
-- ## Outputs Format
SELECT
    s.space_id,
    s.unique_space_code,
    s.space_name,
    s.space_type,
    COUNT(us.usage_session_id) AS completed_session_count,
    SUM(DATEDIFF(MINUTE, us.actual_start_time, us.actual_end_time)) AS total_used_minutes,
    CAST(SUM(DATEDIFF(MINUTE, us.actual_start_time, us.actual_end_time)) / 60.0 AS DECIMAL(10,2)) AS total_used_hours
FROM dbo.USAGE_SESSION AS us
INNER JOIN dbo.BOOKING_REQUEST AS br
    ON br.booking_id = us.booking_id
INNER JOIN dbo.SPACE AS s
    ON s.space_id = br.space_id
WHERE us.actual_end_time IS NOT NULL
GROUP BY s.space_id, s.unique_space_code, s.space_name, s.space_type
ORDER BY total_used_minutes DESC, s.unique_space_code;

-- Query 8: Users with the most booking requests
-- Business question:
-- Which users submit the most booking requests, and what are their approval outcomes?
-- Target user(s):
-- Facility managers, department administrators
-- Why this query is useful:
-- It identifies high-demand users and summarizes their booking outcomes for support or policy review.
-- ## Outputs Format
SELECT
    ua.user_account_id,
    ua.user_id,
    ua.full_name,
    ua.role,
    ua.department,
    COUNT(br.booking_id) AS total_bookings,
    SUM(CASE WHEN br.status = N'Approved' THEN 1 ELSE 0 END) AS approved_bookings,
    SUM(CASE WHEN br.status = N'Rejected' THEN 1 ELSE 0 END) AS rejected_bookings,
    SUM(CASE WHEN br.status = N'No-show' THEN 1 ELSE 0 END) AS no_show_bookings,
    SUM(CASE WHEN br.status = N'Cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings
FROM dbo.USER_ACCOUNT AS ua
LEFT JOIN dbo.BOOKING_REQUEST AS br
    ON br.requester_user_account_id = ua.user_account_id
GROUP BY ua.user_account_id, ua.user_id, ua.full_name, ua.role, ua.department
HAVING COUNT(br.booking_id) > 0
ORDER BY total_bookings DESC, ua.full_name;

-- Query 9: Facility inventory by space
-- Business question:
-- What facilities are available in each space?
-- Target user(s):
-- Students, lecturers, facility staff, department administrators
-- Why this query is useful:
-- It helps requesters choose suitable rooms and helps staff verify facility availability before approving bookings.
-- ## Outputs Format
SELECT
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.capacity,
    s.current_status,
    STRING_AGG(f.facility_name, N', ') WITHIN GROUP (ORDER BY f.facility_name) AS facilities
FROM dbo.SPACE AS s
LEFT JOIN dbo.SPACE_FACILITY AS sf
    ON sf.space_id = s.space_id
LEFT JOIN dbo.FACILITY AS f
    ON f.facility_id = sf.facility_id
GROUP BY s.unique_space_code, s.space_name, s.space_type, s.capacity, s.current_status
ORDER BY s.unique_space_code;

-- Query 10: Maintenance history for a room
-- Business question:
-- What maintenance records exist for a selected room, and who reported or was assigned to them?
-- Target user(s):
-- Facility staff, facility managers
-- Why this query is useful:
-- It supports room maintenance review, recurring problem analysis, and follow-up with assigned staff.
-- ## Outputs Format
SELECT
    mr.maintenance_record_id,
    s.unique_space_code,
    s.space_name,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    mr.status AS maintenance_status,
    mr.result_note,
    reporter.full_name AS reporter_name,
    assigned.full_name AS assigned_staff_name
FROM dbo.MAINTENANCE_RECORD AS mr
INNER JOIN dbo.SPACE AS s
    ON s.space_id = mr.space_id
INNER JOIN dbo.USER_ACCOUNT AS reporter
    ON reporter.user_account_id = mr.reporter_user_account_id
LEFT JOIN dbo.USER_ACCOUNT AS assigned
    ON assigned.user_account_id = mr.assigned_staff_user_account_id
WHERE s.unique_space_code = N'S-PRJ-204'
ORDER BY mr.start_time DESC;
