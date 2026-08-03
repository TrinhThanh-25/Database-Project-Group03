/*
 Group 03 Phase 2 concurrency test setup.

 Run after artifacts 05, 10, and 12 are deployed.
 This script creates narrowly identifiable G03-CT-* fixtures.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.usp_SubmitBookingRequest', N'P') IS NULL
    THROW 51300, 'Missing dbo.usp_SubmitBookingRequest. Run artifact 12 first.', 1;
IF OBJECT_ID(N'dbo.usp_ApproveBookingRequest', N'P') IS NULL
    THROW 51300, 'Missing dbo.usp_ApproveBookingRequest. Run artifact 12 first.', 1;
IF TYPE_ID(N'dbo.IntIdList') IS NULL
    THROW 51300, 'Missing dbo.IntIdList. Run artifact 12 first.', 1;

BEGIN TRANSACTION;

/* Narrow cleanup for rerun. */
DELETE baa
FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT AS baa
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = baa.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE ad
FROM dbo.APPROVAL_DECISION AS ad
INNER JOIN dbo.BOOKING_REQUEST AS br ON br.booking_request_id = ad.booking_request_id
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE br
FROM dbo.BOOKING_REQUEST AS br
INNER JOIN dbo.SPACE AS s ON s.space_id = br.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE mie
FROM dbo.MAINTENANCE_IMPACT_EVENT AS mie
INNER JOIN dbo.MAINTENANCE_RECORD AS mr ON mr.maintenance_record_id = mie.maintenance_record_id
INNER JOIN dbo.SPACE AS s ON s.space_id = mr.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE mr
FROM dbo.MAINTENANCE_RECORD AS mr
INNER JOIN dbo.SPACE AS s ON s.space_id = mr.space_id
WHERE s.unique_space_code LIKE N'G03-CT-%';

DELETE FROM dbo.INSTANT_APPROVAL_SPACE_TYPE
WHERE space_type = N'G03-CT-InstantType';

DELETE FROM dbo.SPACE
WHERE unique_space_code LIKE N'G03-CT-%';

DELETE FROM dbo.USER_ACCOUNT
WHERE user_id LIKE N'G03-CT-%';

DELETE FROM dbo.DEPARTMENT
WHERE department_name = N'G03-CT-DEPT';

/* Required lookup values. */
IF NOT EXISTS (SELECT 1 FROM dbo.ROLE WHERE role_name = N'student')
    INSERT INTO dbo.ROLE (role_name) VALUES (N'student');
IF NOT EXISTS (SELECT 1 FROM dbo.ROLE WHERE role_name = N'facility staff')
    INSERT INTO dbo.ROLE (role_name) VALUES (N'facility staff');
IF NOT EXISTS (SELECT 1 FROM dbo.ROLE WHERE role_name = N'facility manager')
    INSERT INTO dbo.ROLE (role_name) VALUES (N'facility manager');

IF NOT EXISTS (SELECT 1 FROM dbo.ACCOUNT_STATUS WHERE status_name = N'Active')
    INSERT INTO dbo.ACCOUNT_STATUS (status_name) VALUES (N'Active');

IF NOT EXISTS (SELECT 1 FROM dbo.SPACE_STATUS WHERE status_name = N'Available')
    INSERT INTO dbo.SPACE_STATUS (status_name) VALUES (N'Available');
IF NOT EXISTS (SELECT 1 FROM dbo.SPACE_STATUS WHERE status_name = N'Under maintenance')
    INSERT INTO dbo.SPACE_STATUS (status_name) VALUES (N'Under maintenance');
IF NOT EXISTS (SELECT 1 FROM dbo.SPACE_STATUS WHERE status_name = N'Temporarily closed')
    INSERT INTO dbo.SPACE_STATUS (status_name) VALUES (N'Temporarily closed');
IF NOT EXISTS (SELECT 1 FROM dbo.SPACE_STATUS WHERE status_name = N'Retired')
    INSERT INTO dbo.SPACE_STATUS (status_name) VALUES (N'Retired');

IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_STATUS WHERE status_name = N'Open')
    INSERT INTO dbo.MAINTENANCE_STATUS (status_name) VALUES (N'Open');

IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'pending')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Pending', N'pending');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'approved')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Approved', N'approved');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'rejected')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Rejected', N'rejected');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'cancelled')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Cancelled', N'cancelled');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'checked_in')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Checked in', N'checked_in');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'completed')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'Completed', N'completed');
IF NOT EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_code = N'no_show')
    INSERT INTO dbo.BOOKING_STATUS (status_name, status_code) VALUES (N'No-show', N'no_show');

IF NOT EXISTS (SELECT 1 FROM dbo.APPROVAL_METHOD WHERE method_code = N'staff_approval')
    INSERT INTO dbo.APPROVAL_METHOD (method_code, method_name) VALUES (N'staff_approval', N'staff approval');
IF NOT EXISTS (SELECT 1 FROM dbo.APPROVAL_METHOD WHERE method_code = N'instant_approval')
    INSERT INTO dbo.APPROVAL_METHOD (method_code, method_name) VALUES (N'instant_approval', N'instant approval');

IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'out_of_service')
    INSERT INTO dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_code, impact_level_name) VALUES (N'out_of_service', N'out-of-service');
IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code = N'advisory')
    INSERT INTO dbo.MAINTENANCE_IMPACT_LEVEL (impact_level_code, impact_level_name) VALUES (N'advisory', N'advisory');

INSERT INTO dbo.DEPARTMENT (department_name)
VALUES (N'G03-CT-DEPT');

DECLARE @department_id INT = (SELECT department_id FROM dbo.DEPARTMENT WHERE department_name = N'G03-CT-DEPT');
DECLARE @student_role_id INT = (SELECT role_id FROM dbo.ROLE WHERE role_name = N'student');
DECLARE @staff_role_id INT = (SELECT role_id FROM dbo.ROLE WHERE role_name = N'facility staff');
DECLARE @active_status_id INT = (SELECT account_status_id FROM dbo.ACCOUNT_STATUS WHERE status_name = N'Active');
DECLARE @available_status_id INT = (SELECT space_status_id FROM dbo.SPACE_STATUS WHERE status_name = N'Available');
DECLARE @pending_status_id INT = (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code = N'pending');

INSERT INTO dbo.USER_ACCOUNT (user_id, full_name, email, phone_number, department_id, role_id, account_status_id)
VALUES
    (N'G03-CT-REQ-A', N'G03 CT Requester A', N'g03.ct.req.a@example.edu', N'0900000001', @department_id, @student_role_id, @active_status_id),
    (N'G03-CT-REQ-B', N'G03 CT Requester B', N'g03.ct.req.b@example.edu', N'0900000002', @department_id, @student_role_id, @active_status_id),
    (N'G03-CT-REQ-C', N'G03 CT Requester C', N'g03.ct.req.c@example.edu', N'0900000003', @department_id, @student_role_id, @active_status_id),
    (N'G03-CT-REQ-D', N'G03 CT Requester D', N'g03.ct.req.d@example.edu', N'0900000004', @department_id, @student_role_id, @active_status_id),
    (N'G03-CT-STAFF-A', N'G03 CT Staff A', N'g03.ct.staff.a@example.edu', N'0900000011', @department_id, @staff_role_id, @active_status_id),
    (N'G03-CT-STAFF-B', N'G03 CT Staff B', N'g03.ct.staff.b@example.edu', N'0900000012', @department_id, @staff_role_id, @active_status_id);

INSERT INTO dbo.SPACE (unique_space_code, space_name, space_type, building, floor, room_number, capacity, usage_policy, space_status_id)
VALUES
    (N'G03-CT-UNSAFE', N'G03 CT Unsafe Space', N'G03-CT-InstantType', N'CT', N'1', N'101', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-SAFE-A', N'G03 CT Safe Instant Space', N'G03-CT-InstantType', N'CT', N'1', N'102', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-SAFE-B', N'G03 CT Safe Staff Instant Space', N'G03-CT-InstantType', N'CT', N'1', N'103', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-SAFE-C', N'G03 CT Safe Staff Staff Space', N'G03-CT-InstantType', N'CT', N'1', N'104', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-SAFE-DIFF', N'G03 CT Safe Different Space', N'G03-CT-InstantType', N'CT', N'1', N'105', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-BOUNDARY', N'G03 CT Boundary Space', N'G03-CT-InstantType', N'CT', N'2', N'201', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-DIFF-A', N'G03 CT Different Space A', N'G03-CT-InstantType', N'CT', N'2', N'202', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-DIFF-B', N'G03 CT Different Space B', N'G03-CT-InstantType', N'CT', N'2', N'203', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-MAINT', N'G03 CT Maintenance Space', N'G03-CT-InstantType', N'CT', N'2', N'204', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-ADVISORY', N'G03 CT Advisory Space', N'G03-CT-InstantType', N'CT', N'2', N'205', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-TIMEOUT', N'G03 CT Timeout Space', N'G03-CT-InstantType', N'CT', N'3', N'301', 30, N'G03 concurrency test fixture.', @available_status_id),
    (N'G03-CT-ROLLBACK', N'G03 CT Rollback Space', N'G03-CT-InstantType', N'CT', N'3', N'302', 30, N'G03 concurrency test fixture.', @available_status_id);

INSERT INTO dbo.INSTANT_APPROVAL_SPACE_TYPE (space_type, is_active, configured_at, configured_by_user_account_id, configuration_note)
VALUES (N'G03-CT-InstantType', 1, SYSDATETIME(), (SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-STAFF-A'), N'G03 concurrency test instant-approval fixture.');

/* Pending requests for staff approval races. */
INSERT INTO dbo.BOOKING_REQUEST (requester_user_account_id, space_id, booking_status_id, requested_start_time, requested_end_time, purpose_of_use, expected_number_of_participants)
VALUES
    ((SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-A'), (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-B'), @pending_status_id, CONVERT(DATETIME2(0), '2031-02-02T10:00:00'), CONVERT(DATETIME2(0), '2031-02-02T11:00:00'), N'meeting', 5),
    ((SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-A'), (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-C'), @pending_status_id, CONVERT(DATETIME2(0), '2031-02-03T10:00:00'), CONVERT(DATETIME2(0), '2031-02-03T11:00:00'), N'meeting', 5),
    ((SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id = N'G03-CT-REQ-B'), (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-SAFE-C'), @pending_status_id, CONVERT(DATETIME2(0), '2031-02-03T10:30:00'), CONVERT(DATETIME2(0), '2031-02-03T11:30:00'), N'meeting', 5);

COMMIT TRANSACTION;

SELECT
    N'G03 concurrency fixture setup complete' AS setup_status,
    COUNT(*) AS fixture_space_count
FROM dbo.SPACE
WHERE unique_space_code LIKE N'G03-CT-%';
