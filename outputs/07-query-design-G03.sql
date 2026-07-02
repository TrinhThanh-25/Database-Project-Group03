/*
================================================================================
 SQL Query Design - Group 03
 Shared Campus Space Booking Database (Phase 1 schema)
================================================================================

 Input Analyzed:
   - outputs/05-db-definition-G03.sql (schema, keys, constraints)
   - outputs/06-sample-data-G03.sql (sample records referenced by example
     literals below, e.g. unique_space_code CR-101, user_id SV2021001)
   - outputs/01-business-req-analysis-G03.md (business questions and BR-*
     references)

 Scope: 20 read-only SELECT queries for students, lecturers, facility staff,
 department administrators, and facility managers. No INSERT/UPDATE/DELETE/
 DDL statements. Example literal values and DECLARE'd parameters are drawn
 from outputs/06-sample-data-G03.sql so every query returns rows against
 the implemented sample data; substitute different literals/parameters for
 other requesters, spaces, or date ranges in real use.
================================================================================
*/

-- ============================================================================
-- Query 1: Upcoming approved bookings for a space
-- Business question: What approved bookings are scheduled for a given space
-- from now onward?
-- Target user(s): Students, lecturers, teaching assistants, facility staff
-- Why this query is useful: Lets anyone checking a room's schedule see
-- confirmed upcoming use before requesting or visiting that space (BR-08).
-- ============================================================================
SELECT
    br.booking_request_id,
    u.full_name              AS requester_name,
    s.unique_space_code,
    s.space_name,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.expected_number_of_participants
FROM dbo.BOOKING_REQUEST br
JOIN dbo.SPACE s           ON s.space_id = br.space_id
JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id = br.booking_status_id
JOIN dbo.USER_ACCOUNT u    ON u.user_account_id = br.requester_user_account_id
WHERE s.unique_space_code = N'CR-101'
  AND bs.status_name = N'Approved'
  AND br.requested_start_time >= '2026-07-02T00:00:00'
ORDER BY br.requested_start_time ASC;
GO

-- ============================================================================
-- Query 2: Available spaces for a requested time range and minimum capacity
-- Business question: Which available spaces have no overlapping approved
-- booking in a requested time window and meet a minimum capacity?
-- Target user(s): Students, lecturers, teaching assistants, department
-- administrators (anyone submitting a booking request)
-- Why this query is useful: Helps a requester pick a viable space before
-- submitting a booking request, reducing rejected/conflicting requests
-- (BR-06, BR-09, BR-10, BR-11).
-- ============================================================================
DECLARE @RequestStart DATETIME2(0) = '2026-07-10T09:00:00';
DECLARE @RequestEnd   DATETIME2(0) = '2026-07-10T11:00:00';
DECLARE @MinCapacity  INT          = 10;

SELECT
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.building,
    s.floor,
    s.room_number,
    s.capacity
FROM dbo.SPACE s
JOIN dbo.SPACE_STATUS ss ON ss.space_status_id = s.space_status_id
WHERE ss.status_name = N'Available'
  AND s.capacity >= @MinCapacity
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.BOOKING_REQUEST br
        JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id = br.booking_status_id
        WHERE br.space_id = s.space_id
          AND bs.status_name = N'Approved'
          AND br.requested_start_time < @RequestEnd
          AND br.requested_end_time > @RequestStart
      )
ORDER BY s.capacity ASC;
GO

-- ============================================================================
-- Query 3: Spaces currently under maintenance
-- Business question: Which spaces are currently marked under maintenance?
-- Target user(s): Facility staff, facility manager
-- Why this query is useful: Supports the required staff view of spaces
-- under maintenance so bookings are not directed to unavailable rooms
-- (BR-04, BR-19, BR-21).
-- ============================================================================
SELECT
    s.unique_space_code,
    s.space_name,
    s.building,
    s.floor,
    s.room_number,
    ss.status_name
FROM dbo.SPACE s
JOIN dbo.SPACE_STATUS ss ON ss.space_status_id = s.space_status_id
WHERE ss.status_name = N'Under maintenance'
ORDER BY s.building, s.room_number;
GO

-- ============================================================================
-- Query 4: No-show bookings
-- Business question: Which bookings were marked as no-show, and by whom
-- and for which space?
-- Target user(s): Facility staff, facility manager
-- Why this query is useful: Supports the required staff view of no-show
-- bookings, useful for following up with requesters or spotting repeat
-- no-shows (BR-08, BR-21).
-- ============================================================================
SELECT
    br.booking_request_id,
    u.full_name AS requester_name,
    s.unique_space_code,
    s.space_name,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use
FROM dbo.BOOKING_REQUEST br
JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id = br.booking_status_id
JOIN dbo.USER_ACCOUNT u    ON u.user_account_id = br.requester_user_account_id
JOIN dbo.SPACE s           ON s.space_id = br.space_id
WHERE bs.status_name = N'No-show'
ORDER BY br.requested_start_time DESC;
GO

-- ============================================================================
-- Query 5: Booking count by space type
-- Business question: How many bookings has each space type (classroom, lab,
-- meeting room, etc.) received in total?
-- Target user(s): Facility manager, department administrators
-- Why this query is useful: Shows which categories of space are in highest
-- demand, informing capacity planning decisions.
-- ============================================================================
SELECT
    s.space_type,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST br
JOIN dbo.SPACE s ON s.space_id = br.space_id
GROUP BY s.space_type
ORDER BY booking_count DESC;
GO

-- ============================================================================
-- Query 6: Booking count by building
-- Business question: How many bookings does each building receive?
-- Target user(s): Facility manager
-- Why this query is useful: Highlights building-level demand imbalances
-- that may justify redistributing spaces or staff coverage.
-- ============================================================================
SELECT
    s.building,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST br
JOIN dbo.SPACE s ON s.space_id = br.space_id
GROUP BY s.building
ORDER BY booking_count DESC;
GO

-- ============================================================================
-- Query 7: Booking count by requester department
-- Business question: How many bookings has each department's users
-- submitted in total?
-- Target user(s): Department administrators, facility manager
-- Why this query is useful: Lets a department administrator or facility
-- manager see which departments make the heaviest use of shared spaces.
-- ============================================================================
SELECT
    d.department_name,
    COUNT(*) AS booking_count
FROM dbo.BOOKING_REQUEST br
JOIN dbo.USER_ACCOUNT u ON u.user_account_id = br.requester_user_account_id
JOIN dbo.DEPARTMENT d   ON d.department_id = u.department_id
GROUP BY d.department_name
ORDER BY booking_count DESC;
GO

-- ============================================================================
-- Query 8: Maintenance history for a room
-- Business question: What is the full maintenance history of a specific
-- space, including reporter, assignee, status, and outcome?
-- Target user(s): Facility staff, facility manager
-- Why this query is useful: Gives facility staff a complete repair/incident
-- history for a room before scheduling further maintenance or bookings
-- (BR-17, BR-18, BR-20).
-- ============================================================================
SELECT
    mr.maintenance_record_id,
    s.unique_space_code,
    s.space_name,
    mr.problem_description,
    mr.start_time,
    mr.completion_time,
    ms.status_name AS maintenance_status,
    reporter.full_name AS reported_by,
    assignee.full_name AS assigned_to,
    mr.result_note
FROM dbo.MAINTENANCE_RECORD mr
JOIN dbo.SPACE s               ON s.space_id = mr.space_id
JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id = mr.maintenance_status_id
JOIN dbo.USER_ACCOUNT reporter ON reporter.user_account_id = mr.reported_by_user_account_id
LEFT JOIN dbo.USER_ACCOUNT assignee ON assignee.user_account_id = mr.assigned_to_user_account_id
WHERE s.unique_space_code = N'LAB-CS-201'
ORDER BY mr.start_time DESC;
GO

-- ============================================================================
-- Query 9: Users with the most bookings
-- Business question: Which users have submitted the most booking requests
-- overall?
-- Target user(s): Facility manager
-- Why this query is useful: Identifies the heaviest space users, useful for
-- capacity planning and spotting potential policy or fairness concerns.
-- ============================================================================
SELECT TOP (10)
    u.user_id,
    u.full_name,
    r.role_name,
    COUNT(br.booking_request_id) AS total_bookings
FROM dbo.USER_ACCOUNT u
JOIN dbo.ROLE r             ON r.role_id = u.role_id
JOIN dbo.BOOKING_REQUEST br ON br.requester_user_account_id = u.user_account_id
GROUP BY u.user_id, u.full_name, r.role_name
ORDER BY total_bookings DESC;
GO

-- ============================================================================
-- Query 10: Rejected bookings and rejection reasons
-- Business question: Which bookings were rejected, who rejected them, and
-- why?
-- Target user(s): Facility staff, department administrators, requesters
-- Why this query is useful: Lets staff review rejection consistency and
-- lets requesters understand why a request was declined (BR-13, BR-14).
-- ============================================================================
SELECT
    br.booking_request_id,
    u.full_name AS requester_name,
    s.unique_space_code,
    br.requested_start_time,
    br.requested_end_time,
    ad.decision_time,
    decider.full_name AS decided_by,
    ad.rejection_reason
FROM dbo.BOOKING_REQUEST br
JOIN dbo.USER_ACCOUNT u          ON u.user_account_id = br.requester_user_account_id
JOIN dbo.SPACE s                 ON s.space_id = br.space_id
JOIN dbo.APPROVAL_DECISION ad    ON ad.booking_request_id = br.booking_request_id
JOIN dbo.USER_ACCOUNT decider    ON decider.user_account_id = ad.decided_by_user_account_id
JOIN dbo.BOOKING_STATUS outcome  ON outcome.booking_status_id = ad.decision_outcome_booking_status_id
WHERE outcome.status_name = N'Rejected'
ORDER BY ad.decision_time DESC;
GO

-- ============================================================================
-- Query 11: Facility utilization summary (spaces per facility)
-- Business question: How many spaces are equipped with each facility type?
-- Target user(s): Facility manager
-- Why this query is useful: Shows which facilities (projectors, computers,
-- livestreaming equipment, etc.) are broadly available versus scarce,
-- supporting equipment purchasing decisions (BR-05).
-- ============================================================================
SELECT
    f.facility_name,
    COUNT(sf.space_id) AS space_count
FROM dbo.FACILITY f
LEFT JOIN dbo.SPACE_FACILITY sf ON sf.facility_id = f.facility_id
GROUP BY f.facility_name
ORDER BY space_count DESC;
GO

-- ============================================================================
-- Query 12: Space utilization summary (booked hours per space)
-- Business question: How many bookings and total booked hours has each
-- space accumulated (counting only Approved, Checked in, or Completed
-- bookings)?
-- Target user(s): Facility manager
-- Why this query is useful: Ranks spaces by real usage volume, useful for
-- identifying under-used or over-booked spaces.
-- ============================================================================
SELECT
    s.unique_space_code,
    s.space_name,
    COUNT(br.booking_request_id) AS total_bookings,
    ISNULL(SUM(DATEDIFF(MINUTE, br.requested_start_time, br.requested_end_time)), 0) / 60.0 AS total_booked_hours
FROM dbo.SPACE s
LEFT JOIN dbo.BOOKING_REQUEST br
       ON br.space_id = s.space_id
      AND br.booking_status_id IN (
            SELECT booking_status_id FROM dbo.BOOKING_STATUS
            WHERE status_name IN (N'Approved', N'Checked in', N'Completed')
          )
GROUP BY s.unique_space_code, s.space_name
ORDER BY total_booked_hours DESC;
GO

-- ============================================================================
-- Query 13: My booking history
-- Business question: What is the complete booking history (all statuses)
-- for a specific requester?
-- Target user(s): Students, lecturers, teaching assistants
-- Why this query is useful: Lets a requester review every booking they have
-- ever submitted and its outcome (BR-20, BR-21).
-- ============================================================================
SELECT
    br.booking_request_id,
    s.unique_space_code,
    s.space_name,
    bs.status_name AS booking_status,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use
FROM dbo.BOOKING_REQUEST br
JOIN dbo.USER_ACCOUNT u    ON u.user_account_id = br.requester_user_account_id
JOIN dbo.SPACE s           ON s.space_id = br.space_id
JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id = br.booking_status_id
WHERE u.user_id = N'SV2021001'
ORDER BY br.requested_start_time DESC;
GO

-- ============================================================================
-- Query 14: My upcoming bookings
-- Business question: What bookings does a specific requester still have
-- scheduled from today onward, excluding rejected, cancelled, or no-show
-- requests?
-- Target user(s): Students, lecturers, teaching assistants
-- Why this query is useful: Gives a requester a quick view of their active
-- future commitments (BR-21).
-- ============================================================================
DECLARE @AsOf DATETIME2(0) = '2026-07-02T00:00:00';

SELECT
    br.booking_request_id,
    s.unique_space_code,
    s.space_name,
    bs.status_name AS booking_status,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use
FROM dbo.BOOKING_REQUEST br
JOIN dbo.USER_ACCOUNT u    ON u.user_account_id = br.requester_user_account_id
JOIN dbo.SPACE s           ON s.space_id = br.space_id
JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id = br.booking_status_id
WHERE u.user_id = N'GV001'
  AND br.requested_start_time >= @AsOf
  AND bs.status_name NOT IN (N'Rejected', N'Cancelled', N'No-show')
ORDER BY br.requested_start_time ASC;
GO

-- ============================================================================
-- Query 15: Pending bookings awaiting approval
-- Business question: Which booking requests are still pending a decision,
-- oldest first?
-- Target user(s): Facility staff, facility manager
-- Why this query is useful: Serves as the approval work queue for staff
-- who approve or reject bookings (BR-12, BR-13).
-- ============================================================================
SELECT
    br.booking_request_id,
    u.full_name AS requester_name,
    r.role_name AS requester_role,
    s.unique_space_code,
    s.space_name,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use,
    br.expected_number_of_participants
FROM dbo.BOOKING_REQUEST br
JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id = br.booking_status_id
JOIN dbo.USER_ACCOUNT u    ON u.user_account_id = br.requester_user_account_id
JOIN dbo.ROLE r            ON r.role_id = u.role_id
JOIN dbo.SPACE s           ON s.space_id = br.space_id
WHERE bs.status_name = N'Pending'
ORDER BY br.requested_start_time ASC;
GO

-- ============================================================================
-- Query 16: Cancelled bookings list
-- Business question: Which bookings were cancelled, for which spaces and
-- requesters?
-- Target user(s): Facility staff, facility manager
-- Why this query is useful: Supports historical review of cancellations,
-- useful for spotting patterns tied to specific spaces or requesters
-- (BR-08, BR-20).
-- ============================================================================
SELECT
    br.booking_request_id,
    u.full_name AS requester_name,
    s.unique_space_code,
    br.requested_start_time,
    br.requested_end_time,
    br.purpose_of_use
FROM dbo.BOOKING_REQUEST br
JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id = br.booking_status_id
JOIN dbo.USER_ACCOUNT u    ON u.user_account_id = br.requester_user_account_id
JOIN dbo.SPACE s           ON s.space_id = br.space_id
WHERE bs.status_name = N'Cancelled'
ORDER BY br.requested_start_time DESC;
GO

-- ============================================================================
-- Query 17: Completed usage sessions with actual vs. requested duration
-- Business question: For completed bookings, how does the actual usage
-- duration compare with the originally requested duration?
-- Target user(s): Facility manager
-- Why this query is useful: Surfaces sessions that ran much shorter or
-- longer than requested, useful for reviewing booking accuracy and space
-- scheduling buffers (BR-15, BR-16).
-- ============================================================================
SELECT
    br.booking_request_id,
    s.unique_space_code,
    s.space_name,
    br.requested_start_time,
    br.requested_end_time,
    us.actual_start_time,
    us.actual_end_time,
    DATEDIFF(MINUTE, br.requested_start_time, br.requested_end_time) AS requested_minutes,
    DATEDIFF(MINUTE, us.actual_start_time, us.actual_end_time) AS actual_minutes,
    checkin.full_name AS checked_in_by,
    completedby.full_name AS completed_by
FROM dbo.USAGE_SESSION us
JOIN dbo.BOOKING_REQUEST br ON br.booking_request_id = us.booking_request_id
JOIN dbo.SPACE s            ON s.space_id = br.space_id
JOIN dbo.USER_ACCOUNT checkin ON checkin.user_account_id = us.checked_in_by_user_account_id
LEFT JOIN dbo.USER_ACCOUNT completedby ON completedby.user_account_id = us.completed_by_user_account_id
WHERE us.actual_end_time IS NOT NULL
ORDER BY us.actual_start_time DESC;
GO

-- ============================================================================
-- Query 18: Currently checked-in (in-progress) sessions
-- Business question: Which usage sessions have been checked in but not yet
-- completed?
-- Target user(s): Facility staff
-- Why this query is useful: Gives facility staff a live view of spaces
-- currently in active use so they know which sessions still need
-- completion (BR-15, BR-16).
-- ============================================================================
SELECT
    br.booking_request_id,
    s.unique_space_code,
    s.space_name,
    u.full_name AS requester_name,
    us.actual_start_time,
    us.initial_condition_of_space,
    checkin.full_name AS checked_in_by
FROM dbo.USAGE_SESSION us
JOIN dbo.BOOKING_REQUEST br ON br.booking_request_id = us.booking_request_id
JOIN dbo.SPACE s            ON s.space_id = br.space_id
JOIN dbo.USER_ACCOUNT u     ON u.user_account_id = br.requester_user_account_id
JOIN dbo.USER_ACCOUNT checkin ON checkin.user_account_id = us.checked_in_by_user_account_id
WHERE us.actual_end_time IS NULL
ORDER BY us.actual_start_time ASC;
GO

-- ============================================================================
-- Query 19: Spaces and their assigned facilities
-- Business question: What facilities are available in each space?
-- Target user(s): Students, lecturers, teaching assistants, department
-- administrators
-- Why this query is useful: Helps a requester choose a suitable space when
-- a booking needs specific equipment such as a projector or livestreaming
-- setup (BR-05, BR-06).
-- ============================================================================
SELECT
    s.unique_space_code,
    s.space_name,
    s.space_type,
    s.capacity,
    STRING_AGG(f.facility_name, N', ') WITHIN GROUP (ORDER BY f.facility_name) AS facilities
FROM dbo.SPACE s
LEFT JOIN dbo.SPACE_FACILITY sf ON sf.space_id = s.space_id
LEFT JOIN dbo.FACILITY f        ON f.facility_id = sf.facility_id
GROUP BY s.unique_space_code, s.space_name, s.space_type, s.capacity
ORDER BY s.unique_space_code;
GO

-- ============================================================================
-- Query 20: Long-outstanding (unresolved) maintenance records
-- Business question: Which maintenance records are still open, and how many
-- days have they been open?
-- Target user(s): Facility manager, facility staff
-- Why this query is useful: Surfaces aging, unresolved maintenance issues
-- that need follow-up or reassignment (BR-17, BR-18, BR-19).
-- ============================================================================
DECLARE @AsOfMaintenance DATETIME2(0) = '2026-07-02T00:00:00';

SELECT
    mr.maintenance_record_id,
    s.unique_space_code,
    s.space_name,
    ms.status_name AS maintenance_status,
    mr.problem_description,
    mr.start_time,
    DATEDIFF(DAY, mr.start_time, @AsOfMaintenance) AS days_open,
    reporter.full_name AS reported_by,
    assignee.full_name AS assigned_to
FROM dbo.MAINTENANCE_RECORD mr
JOIN dbo.SPACE s               ON s.space_id = mr.space_id
JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id = mr.maintenance_status_id
JOIN dbo.USER_ACCOUNT reporter ON reporter.user_account_id = mr.reported_by_user_account_id
LEFT JOIN dbo.USER_ACCOUNT assignee ON assignee.user_account_id = mr.assigned_to_user_account_id
WHERE mr.completion_time IS NULL
ORDER BY days_open DESC;
GO

-- ============================================================================
-- End of query design script.
-- ============================================================================
