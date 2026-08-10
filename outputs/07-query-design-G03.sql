/*
================================================================================
 SQL Query Design - Group 03
 Shared Campus Space Booking System
================================================================================

 Source documents:
   - outputs/01-business-req-analysis-G03.md (Business Requirement Analysis)
   - outputs/05-db-definition-G03.sql (Phase 1 DDL: 14 tables)
   - outputs/06-sample-data-G03.sql (Phase 1 sample data)

 Scope: 20 read-only SELECT queries for students, lecturers, facility staff,
 department administrators, and facility managers. Each query is a single,
 self-contained statement using literal values (no DECLARE/batch variables,
 no GO separators) so it can be run independently.

 Lookup values used below (from outputs/06-sample-data-G03.sql):
   BOOKING_STATUS: Pending, Approved, Rejected, Cancelled, Checked in,
     Completed, No-show
   SPACE_STATUS: Available, In use, Under maintenance, Temporarily closed,
     Retired
   MAINTENANCE_STATUS: Reported, In progress, Completed
   ROLE: student, lecturer, teaching assistant, facility staff,
     department administrator, facility manager
================================================================================
*/

-- Query 1: Upcoming approved bookings for a specific space
-- Business question: What are the upcoming approved bookings for space CR-101, so staff and requesters know what is scheduled?
-- Target user(s): Facility staff, students, lecturers
-- Why this query is useful: Lets facility staff confirm the schedule for a room and lets requesters verify their booking is confirmed and upcoming.
SELECT
    br.booking_request_id,
    sp.unique_space_code,
    sp.space_name,
    ua.full_name        AS requester_name,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use
FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.SPACE AS sp ON sp.space_id = br.space_id
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.USER_ACCOUNT AS ua ON ua.user_account_id = br.requester_user_account_id
WHERE sp.unique_space_code = N'CR-101'
    AND bs.status_name = N'Approved'
    AND br.requested_start_time >= SYSDATETIME()
ORDER BY br.requested_start_time ASC;

-- Query 2: Available spaces for a requested time range and minimum capacity
-- Business question: Which spaces with at least 30 seats have no overlapping approved or checked-in booking between 2026-07-10 09:00 and 2026-07-10 11:00?
-- Target user(s): Students, lecturers
-- Why this query is useful: Helps a requester quickly find a room that fits their headcount and is free during the time they need it, before submitting a booking request.
SELECT
    sp.space_id,
    sp.unique_space_code,
    sp.space_name,
    sp.space_type,
    sp.building,
    sp.capacity
FROM dbo.SPACE AS sp
    INNER JOIN dbo.SPACE_STATUS AS ss ON ss.space_status_id = sp.space_status_id
WHERE ss.status_name = N'Available'
    AND sp.capacity >= 30
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.BOOKING_REQUEST AS br
            INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
        WHERE br.space_id = sp.space_id
            AND bs.status_name IN (N'Approved', N'Checked in')
            AND br.requested_start_time < N'2026-07-10T11:00:00'
            AND br.requested_end_time > N'2026-07-10T09:00:00'
    )
ORDER BY sp.capacity ASC;

-- Query 3: Spaces currently under maintenance
-- Business question: Which spaces are currently under maintenance, and what is the reported problem?
-- Target user(s): Facility manager, facility staff
-- Why this query is useful: Gives facility management a quick view of rooms that are out of service and why, to prioritize repair work and avoid bookings.
SELECT
    sp.unique_space_code,
    sp.space_name,
    sp.building,
    mr.problem_description,
    mr.start_time,
    ms.status_name AS maintenance_status
FROM dbo.SPACE AS sp
    INNER JOIN dbo.SPACE_STATUS AS ss ON ss.space_status_id = sp.space_status_id
    INNER JOIN dbo.MAINTENANCE_RECORD AS mr ON mr.space_id = sp.space_id
    INNER JOIN dbo.MAINTENANCE_STATUS AS ms ON ms.maintenance_status_id = mr.maintenance_status_id
WHERE ss.status_name = N'Under maintenance'
    AND mr.completion_time IS NULL
ORDER BY mr.start_time ASC;

-- Query 4: No-show bookings
-- Business question: Which bookings were marked as No-show, and who made them?
-- Target user(s): Facility manager, department administrator
-- Why this query is useful: Identifies users who reserve spaces but do not show up, supporting policy decisions such as booking privilege restrictions.
SELECT
    br.booking_request_id,
    ua.user_id,
    ua.full_name        AS requester_name,
    d.department_name,
    sp.unique_space_code,
    br.requested_start_time,
    br.requested_end_time
FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.USER_ACCOUNT AS ua ON ua.user_account_id = br.requester_user_account_id
    INNER JOIN dbo.DEPARTMENT AS d ON d.department_id = ua.department_id
    INNER JOIN dbo.SPACE AS sp ON sp.space_id = br.space_id
WHERE bs.status_name = N'No-show'
ORDER BY br.requested_start_time DESC;

-- Query 5: Booking count by space type
-- Business question: How many bookings has each space type (classroom, meeting room, etc.) received in total?
-- Target user(s): Facility manager, department administrator
-- Why this query is useful: Reveals which categories of space are in the highest demand, informing capacity planning and future space allocation.
SELECT
    sp.space_type,
    COUNT(br.booking_request_id) AS total_bookings
FROM dbo.SPACE AS sp
    LEFT JOIN dbo.BOOKING_REQUEST AS br ON br.space_id = sp.space_id
GROUP BY sp.space_type
ORDER BY total_bookings DESC;

-- Query 6: Booking count by building
-- Business question: How many bookings has each building received in total?
-- Target user(s): Facility manager
-- Why this query is useful: Shows which buildings are the busiest, helping facility managers plan staffing and maintenance schedules by location.
SELECT
    sp.building,
    COUNT(br.booking_request_id) AS total_bookings
FROM dbo.SPACE AS sp
    LEFT JOIN dbo.BOOKING_REQUEST AS br ON br.space_id = sp.space_id
GROUP BY sp.building
ORDER BY total_bookings DESC;

-- Query 7: Booking count by department
-- Business question: How many booking requests has each department's members submitted in total?
-- Target user(s): Department administrator, facility manager
-- Why this query is useful: Lets department administrators and facility managers compare booking activity across departments for budgeting or fairness reviews.
SELECT
    d.department_name,
    COUNT(br.booking_request_id) AS total_bookings
FROM dbo.DEPARTMENT AS d
    LEFT JOIN dbo.USER_ACCOUNT AS ua ON ua.department_id = d.department_id
    LEFT JOIN dbo.BOOKING_REQUEST AS br ON br.requester_user_account_id = ua.user_account_id
GROUP BY d.department_name
ORDER BY total_bookings DESC;

-- Query 8: Maintenance history for a specific room
-- Business question: What is the full maintenance history for room CR-102, including who reported and resolved each issue?
-- Target user(s): Facility staff, facility manager
-- Why this query is useful: Gives facility staff a complete repair history for a room, useful for diagnosing recurring problems or verifying warranty work.
SELECT
    mr.maintenance_record_id,
    reporter.full_name  AS reported_by,
    assignee.full_name  AS assigned_to,
    ms.status_name      AS maintenance_status,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    mr.result_note
FROM dbo.MAINTENANCE_RECORD AS mr
    INNER JOIN dbo.SPACE AS sp ON sp.space_id = mr.space_id
    INNER JOIN dbo.MAINTENANCE_STATUS AS ms ON ms.maintenance_status_id = mr.maintenance_status_id
    INNER JOIN dbo.USER_ACCOUNT AS reporter ON reporter.user_account_id = mr.reported_by_user_account_id
    LEFT JOIN dbo.USER_ACCOUNT AS assignee ON assignee.user_account_id = mr.assigned_to_user_account_id
WHERE sp.unique_space_code = N'CR-102'
ORDER BY mr.start_time DESC;

-- Query 9: Users with the most bookings
-- Business question: Which users have submitted the most booking requests overall?
-- Target user(s): Facility manager, department administrator
-- Why this query is useful: Highlights the heaviest users of shared spaces, useful for usage audits or identifying power users for feedback.
SELECT TOP (10)
    ua.user_id,
    ua.full_name,
    r.role_name,
    COUNT(br.booking_request_id) AS total_bookings
FROM dbo.USER_ACCOUNT AS ua
    INNER JOIN dbo.ROLE AS r ON r.role_id = ua.role_id
    INNER JOIN dbo.BOOKING_REQUEST AS br ON br.requester_user_account_id = ua.user_account_id
GROUP BY ua.user_id, ua.full_name, r.role_name
ORDER BY total_bookings DESC;

-- Query 10: Rejected bookings and rejection reasons
-- Business question: Which bookings were rejected, and what reason and decision maker were recorded for each?
-- Target user(s): Students, lecturers, department administrator
-- Why this query is useful: Lets requesters and administrators review why specific bookings were denied, supporting transparency and appeal decisions.
SELECT
    br.booking_request_id,
    requester.full_name AS requester_name,
    sp.unique_space_code,
    br.requested_start_time,
    br.requested_end_time,
    decider.full_name   AS decided_by,
    ad.decision_time,
    ad.rejection_reason
FROM dbo.APPROVAL_DECISION AS ad
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = ad.decision_outcome_booking_status_id
    INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = ad.booking_request_id
    INNER JOIN dbo.SPACE AS sp ON sp.space_id = br.space_id
    INNER JOIN dbo.USER_ACCOUNT AS requester ON requester.user_account_id = br.requester_user_account_id
    INNER JOIN dbo.USER_ACCOUNT AS decider ON decider.user_account_id = ad.decided_by_user_account_id
WHERE bs.status_name = N'Rejected'
ORDER BY ad.decision_time DESC;

-- Query 11: Utilization summary for spaces (approved/checked-in/completed bookings only)
-- Business question: For each space, how many bookings actually resulted in confirmed use (Approved, Checked in, or Completed)?
-- Target user(s): Facility manager
-- Why this query is useful: Measures real utilization per space (excluding pending, rejected, cancelled, no-show), helping facility managers identify under-used or over-booked spaces.
SELECT
    sp.unique_space_code,
    sp.space_name,
    sp.building,
    COUNT(bs.booking_status_id) AS confirmed_bookings
FROM dbo.SPACE AS sp
    LEFT JOIN dbo.BOOKING_REQUEST AS br ON br.space_id = sp.space_id
    LEFT JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
        AND bs.status_name IN (N'Approved', N'Checked in', N'Completed')
GROUP BY sp.unique_space_code, sp.space_name, sp.building
ORDER BY confirmed_bookings DESC;

-- Query 12: Pending bookings awaiting approval
-- Business question: Which booking requests are currently pending and need a decision, ordered by the earliest requested start time?
-- Target user(s): Facility staff, facility manager
-- Why this query is useful: Gives approvers a worklist prioritized by the nearest scheduled use; the schema has no request-submission timestamp, so waiting duration cannot be calculated.
SELECT
    br.booking_request_id,
    requester.full_name AS requester_name,
    sp.unique_space_code,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use
FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.USER_ACCOUNT AS requester ON requester.user_account_id = br.requester_user_account_id
    INNER JOIN dbo.SPACE AS sp ON sp.space_id = br.space_id
WHERE bs.status_name = N'Pending'
ORDER BY br.requested_start_time ASC;

-- Query 13: A student's or lecturer's own booking history
-- Business question: What is the full booking history, with current status, for the user with user_id 'SV2021001'?
-- Target user(s): Students, lecturers
-- Why this query is useful: Lets a requester see all of their own bookings across time and status without needing staff assistance.
SELECT
    br.booking_request_id,
    sp.unique_space_code,
    sp.space_name,
    bs.status_name       AS booking_status,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use
FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.USER_ACCOUNT AS ua ON ua.user_account_id = br.requester_user_account_id
    INNER JOIN dbo.SPACE AS sp ON sp.space_id = br.space_id
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
WHERE ua.user_id = N'SV2021001'
ORDER BY br.requested_start_time DESC;

-- Query 14: Currently active usage sessions (checked in, not yet completed)
-- Business question: Which spaces are currently occupied by a checked-in session that has not been completed yet?
-- Target user(s): Facility staff
-- Why this query is useful: Gives facility staff real-time visibility into which rooms are in active use right now, useful for walk-through checks and handling walk-in requests.
SELECT
    sp.unique_space_code,
    sp.space_name,
    us.usage_session_id,
    checkin.full_name AS checked_in_by,
    us.actual_start_time,
    us.initial_condition_of_space
FROM dbo.USAGE_SESSION AS us
    INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = us.booking_request_id
    INNER JOIN dbo.SPACE AS sp ON sp.space_id = br.space_id
    INNER JOIN dbo.USER_ACCOUNT AS checkin ON checkin.user_account_id = us.checked_in_by_user_account_id
WHERE us.actual_end_time IS NULL
ORDER BY us.actual_start_time ASC;

-- Query 15: Facilities/equipment available in a specific space
-- Business question: What equipment and facilities are available in the meeting room MR-405?
-- Target user(s): Students, lecturers, facility staff
-- Why this query is useful: Lets a requester confirm a space has the equipment (e.g. projector, microphone) needed before booking it.
SELECT
    sp.unique_space_code,
    sp.space_name,
    f.facility_name
FROM dbo.SPACE AS sp
    INNER JOIN dbo.SPACE_FACILITY AS sf ON sf.space_id = sp.space_id
    INNER JOIN dbo.FACILITY AS f ON f.facility_id = sf.facility_id
WHERE sp.unique_space_code = N'MR-405'
ORDER BY f.facility_name ASC;

-- Query 16: Cancelled bookings in a given period
-- Business question: Which bookings scheduled in calendar year 2026 were cancelled, and for spaces in which buildings?
-- Target user(s): Facility manager
-- Why this query is useful: Tracks cancellation patterns by building/space, which can reveal scheduling friction or spaces that are frequently over-reserved and dropped.
SELECT
    br.booking_request_id,
    requester.full_name AS requester_name,
    sp.unique_space_code,
    sp.building,
    br.requested_start_time,
    br.requested_end_time
FROM dbo.BOOKING_REQUEST AS br
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = br.booking_status_id
    INNER JOIN dbo.USER_ACCOUNT AS requester ON requester.user_account_id = br.requester_user_account_id
    INNER JOIN dbo.SPACE AS sp ON sp.space_id = br.space_id
WHERE bs.status_name = N'Cancelled'
  AND br.requested_start_time >= '2026-01-01T00:00:00'
  AND br.requested_start_time <  '2027-01-01T00:00:00'
ORDER BY br.requested_start_time DESC;

-- Query 17: Department administrator view of active departmental headcount
-- Business question: How many active user accounts, broken down by role, does each department currently have?
-- Target user(s): Department administrator
-- Why this query is useful: Gives a department administrator a quick roster summary by role, useful for planning department-wide space needs and verifying account status hygiene.
SELECT
    d.department_name,
    r.role_name,
    COUNT(ua.user_account_id) AS active_user_count
FROM dbo.DEPARTMENT AS d
    INNER JOIN dbo.USER_ACCOUNT AS ua ON ua.department_id = d.department_id
    INNER JOIN dbo.ROLE AS r ON r.role_id = ua.role_id
    INNER JOIN dbo.ACCOUNT_STATUS AS acs ON acs.account_status_id = ua.account_status_id
WHERE acs.status_name = N'Active'
GROUP BY d.department_name, r.role_name
ORDER BY d.department_name ASC, active_user_count DESC;

-- Query 18: Average booking duration by purpose of use
-- Business question: What is the average requested duration, in minutes, of bookings for each purpose of use (lecture, meeting, exam, etc.)?
-- Target user(s): Facility manager, department administrator
-- Why this query is useful: Helps facility managers understand how long different activity types typically occupy a space, useful for scheduling buffer time and capacity forecasting.
SELECT
    br.purpose_of_use,
    COUNT(*)                                                            AS booking_count,
    AVG(DATEDIFF(MINUTE, br.requested_start_time, br.requested_end_time)) AS avg_duration_minutes
FROM dbo.BOOKING_REQUEST AS br
GROUP BY br.purpose_of_use
ORDER BY avg_duration_minutes DESC;

-- Query 19: Spaces with completed maintenance and no unresolved issues
-- Business question: Which spaces have at least one completed maintenance record and currently have no open (unresolved) maintenance record?
-- Target user(s): Facility manager
-- Why this query is useful: Confirms which previously-repaired spaces are fully cleared for use, supporting decisions about reopening a space for booking.
SELECT DISTINCT
    sp.unique_space_code,
    sp.space_name,
    ss.status_name AS current_space_status
FROM dbo.SPACE AS sp
    INNER JOIN dbo.SPACE_STATUS AS ss ON ss.space_status_id = sp.space_status_id
    INNER JOIN dbo.MAINTENANCE_RECORD AS mr ON mr.space_id = sp.space_id
    INNER JOIN dbo.MAINTENANCE_STATUS AS ms ON ms.maintenance_status_id = mr.maintenance_status_id
WHERE ms.status_name = N'Completed'
    AND NOT EXISTS (
        SELECT 1
        FROM dbo.MAINTENANCE_RECORD AS mr2
            INNER JOIN dbo.MAINTENANCE_STATUS AS ms2 ON ms2.maintenance_status_id = mr2.maintenance_status_id
        WHERE mr2.space_id = sp.space_id
            AND ms2.status_name IN (N'Reported', N'In progress')
    )
ORDER BY sp.unique_space_code ASC;

-- Query 20: Facility staff and facility manager decision workload
-- Business question: How many approval decisions has each facility staff or facility manager made, broken down by approved vs. rejected outcome?
-- Target user(s): Facility manager
-- Why this query is useful: Lets a facility manager review how much approval workload each staff member is handling and compare approval vs. rejection rates across decision makers.
SELECT
    decider.full_name AS decision_maker,
    r.role_name,
    SUM(CASE WHEN bs.status_name = N'Approved' THEN 1 ELSE 0 END) AS approved_count,
    SUM(CASE WHEN bs.status_name = N'Rejected' THEN 1 ELSE 0 END) AS rejected_count,
    COUNT(*)                                                       AS total_decisions
FROM dbo.APPROVAL_DECISION AS ad
    INNER JOIN dbo.USER_ACCOUNT AS decider ON decider.user_account_id = ad.decided_by_user_account_id
    INNER JOIN dbo.ROLE AS r ON r.role_id = decider.role_id
    INNER JOIN dbo.BOOKING_STATUS AS bs ON bs.booking_status_id = ad.decision_outcome_booking_status_id
GROUP BY decider.full_name, r.role_name
ORDER BY total_decisions DESC;

-- ============================================================================
-- End of SQL Query Design script.
-- ============================================================================
