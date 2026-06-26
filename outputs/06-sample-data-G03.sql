/*
    Sample Data - Group 03
    Target DBMS: Microsoft SQL Server

    Source DDL: outputs/05-db-definition-G03.sql

    Notes:
    - Departments are represented by USER_ACCOUNT.department because the implemented schema
      has no standalone DEPARTMENT table.
    - Explicit identity values are used so child rows can reference stable parent IDs.
    - Sample bookings avoid under-maintenance, temporarily closed, and retired spaces so the
      unavailable-space trigger is satisfied.
    - Approved bookings do not overlap for the same space so the approved-overlap trigger is satisfied.
*/

/* ============================================================
   1. Users and departments
   ============================================================ */

SET IDENTITY_INSERT dbo.USER_ACCOUNT ON;

INSERT INTO dbo.USER_ACCOUNT
    (user_account_id, user_id, full_name, email, phone_number, role, department, account_status)
VALUES
    (1,  N'STU2026001', N'Nguyen Minh Anh',       N'minh.anh@student.university.edu',       N'0901001001', N'Student',                  N'Computer Science',        N'Active'),
    (2,  N'STU2026002', N'Tran Bao Long',         N'bao.long@student.university.edu',       N'0901001002', N'Student',                  N'Software Engineering',    N'Active'),
    (3,  N'LEC1001',    N'Dr. Pham Thu Ha',       N'thu.ha@university.edu',                 N'0902001001', N'Lecturer',                 N'Computer Science',        N'Active'),
    (4,  N'TA2001',     N'Le Quang Huy',          N'quang.huy@university.edu',              N'0903001001', N'Teaching Assistant',       N'Computer Science',        N'Active'),
    (5,  N'FAC3001',    N'Hoang Thanh Binh',      N'thanh.binh.facility@university.edu',    N'0904001001', N'Facility Staff',           N'Facilities Office',       N'Active'),
    (6,  N'FAC3002',    N'Vu Thi Lan',            N'thi.lan.facility@university.edu',       N'0904001002', N'Facility Staff',           N'Facilities Office',       N'Active'),
    (7,  N'ADM4001',    N'Dang Ngoc Mai',         N'ngoc.mai.admin@university.edu',         N'0905001001', N'Department Administrator', N'School Office',           N'Active'),
    (8,  N'MGR5001',    N'Assoc. Prof. Do An',    N'an.do.manager@university.edu',          N'0906001001', N'Facility Manager',         N'Facilities Office',       N'Active'),
    (9,  N'LEC1002',    N'Dr. Nguyen Duc Khoa',   N'duc.khoa@university.edu',               N'0902001002', N'Lecturer',                 N'Information Systems',     N'Active'),
    (10, N'TA2002',     N'Pham Minh Chau',        N'minh.chau@university.edu',              N'0903001002', N'Teaching Assistant',       N'Software Engineering',    N'Active'),
    (11, N'STU2026003', N'Vo Gia Han',            N'gia.han@student.university.edu',        N'0901001003', N'Student',                  N'Information Systems',     N'Active'),
    (12, N'ADM4002',    N'Bui Khanh Linh',        N'khanh.linh.admin@university.edu',       N'0905001002', N'Department Administrator', N'Graduate Program Office', N'Inactive');

SET IDENTITY_INSERT dbo.USER_ACCOUNT OFF;
GO

/* ============================================================
   2. Spaces
   Includes classroom, computer laboratory, project laboratory,
   meeting room, auditorium, student workspace, under-maintenance,
   temporarily closed, and retired spaces.
   ============================================================ */

SET IDENTITY_INSERT dbo.SPACE ON;

INSERT INTO dbo.SPACE
    (space_id, unique_space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES
    (1, N'CS-A101', N'Algorithms Classroom',          N'Classroom',            N'Alpha Building', N'1', N'A101',  60,  N'Available',          N'Priority for lectures and examinations.'),
    (2, N'CS-B201', N'Programming Computer Lab',      N'Computer Laboratory',  N'Beta Building',  N'2', N'B201',  45,  N'Available',          N'Computer-based classes and examinations only.'),
    (3, N'CS-C305', N'Capstone Project Laboratory',   N'Project Laboratory',   N'Gamma Building', N'3', N'C305',  30,  N'In use',             N'Project teams must keep equipment in assigned benches.'),
    (4, N'CS-A210', N'School Meeting Room',           N'Meeting Room',         N'Alpha Building', N'2', N'A210',  20,  N'Available',          N'Meetings and small seminars only.'),
    (5, N'CS-D001', N'Main Auditorium',               N'Auditorium',           N'Delta Hall',     N'G', N'D001', 250,  N'Available',          N'Large academic events require facility staff support.'),
    (6, N'CS-L110', N'Student Collaboration Workspace', N'Student Workspace',  N'Library Wing',   N'1', N'L110',  40,  N'Available',          N'Open for supervised student activities.'),
    (7, N'CS-B202', N'Networks Laboratory',           N'Computer Laboratory',  N'Beta Building',  N'2', N'B202',  35,  N'Under maintenance',  N'Unavailable while network switches are being replaced.'),
    (8, N'CS-A315', N'Temporary Faculty Meeting Room', N'Meeting Room',        N'Alpha Building', N'3', N'A315',  16,  N'Temporarily closed', N'Closed for renovation work.'),
    (9, N'CS-OLD1', N'Legacy Hardware Lab',           N'Computer Laboratory',  N'Old Block',      N'1', N'O101',  25,  N'Retired',            N'Retired from booking service.');

SET IDENTITY_INSERT dbo.SPACE OFF;
GO

/* ============================================================
   3. Facilities
   ============================================================ */

SET IDENTITY_INSERT dbo.FACILITY ON;

INSERT INTO dbo.FACILITY
    (facility_id, facility_name)
VALUES
    (1, N'Projector'),
    (2, N'Whiteboard'),
    (3, N'Microphone'),
    (4, N'Computer'),
    (5, N'Livestreaming equipment'),
    (6, N'Air conditioner');

SET IDENTITY_INSERT dbo.FACILITY OFF;
GO

/* ============================================================
   4. Space-facility assignments
   ============================================================ */

SET IDENTITY_INSERT dbo.SPACE_FACILITY ON;

INSERT INTO dbo.SPACE_FACILITY
    (space_facility_id, space_id, facility_id)
VALUES
    (1, 1, 1), (2, 1, 2), (3, 1, 6),
    (4, 2, 1), (5, 2, 2), (6, 2, 4), (7, 2, 6),
    (8, 3, 2), (9, 3, 4), (10, 3, 6),
    (11, 4, 1), (12, 4, 2), (13, 4, 6),
    (14, 5, 1), (15, 5, 2), (16, 5, 3), (17, 5, 5), (18, 5, 6),
    (19, 6, 2), (20, 6, 6),
    (21, 7, 4), (22, 7, 6),
    (23, 8, 2), (24, 8, 6),
    (25, 9, 4);

SET IDENTITY_INSERT dbo.SPACE_FACILITY OFF;
GO

/* ============================================================
   5. Booking requests
   Includes pending, approved, rejected, cancelled, checked in,
   completed, and no-show statuses with different purposes and
   participant counts.
   ============================================================ */

SET IDENTITY_INSERT dbo.BOOKING_REQUEST ON;

INSERT INTO dbo.BOOKING_REQUEST
    (booking_id, requester_user_account_id, space_id, requested_start_time, requested_end_time, purpose_of_use, expected_number_of_participants, booking_status)
VALUES
    (1,  3, 1, '2026-07-01T09:00:00', '2026-07-01T11:00:00', N'Lecture',              55,  N'Pending'),
    (2,  9, 1, '2026-07-01T13:00:00', '2026-07-01T15:00:00', N'Seminar',              45,  N'Approved'),
    (3,  7, 4, '2026-07-02T10:00:00', '2026-07-02T11:00:00', N'Meeting',              12,  N'Rejected'),
    (4,  4, 2, '2026-07-03T09:00:00', '2026-07-03T12:00:00', N'Workshop',             32,  N'Cancelled'),
    (5,  1, 3, '2026-06-26T13:00:00', '2026-06-26T17:00:00', N'Student activity',     18,  N'Checked in'),
    (6,  3, 2, '2026-06-20T08:00:00', '2026-06-20T10:00:00', N'Examination',          40,  N'Completed'),
    (7,  12, 5, '2026-06-21T14:00:00', '2026-06-21T16:00:00', N'Administrative event', 80,  N'No-show'),
    (8,  2, 6, '2026-07-04T10:00:00', '2026-07-04T12:00:00', N'Student activity',     25,  N'Approved'),
    (9,  8, 5, '2026-07-05T09:00:00', '2026-07-05T12:00:00', N'Workshop',             120, N'Approved'),
    (10, 10, 4, '2026-07-05T13:00:00', '2026-07-05T14:00:00', N'Meeting',              10,  N'Pending');

SET IDENTITY_INSERT dbo.BOOKING_REQUEST OFF;
GO

/* ============================================================
   6. Approval and rejection details
   Approval makers are Facility Staff or Facility Manager to satisfy triggers.
   Rejected decisions include rejection reasons to satisfy CHECK constraint.
   ============================================================ */

SET IDENTITY_INSERT dbo.APPROVAL_DECISION ON;

INSERT INTO dbo.APPROVAL_DECISION
    (approval_decision_id, booking_id, decision_maker_user_account_id, decision_outcome, decision_time, decision_note, rejection_reason)
VALUES
    (1, 2, 8, N'Approved', '2026-06-24T09:15:00', N'Approved for weekly research seminar.', NULL),
    (2, 3, 5, N'Rejected', '2026-06-24T10:30:00', N'Rejected due to scheduling priority for school board preparation.', N'Meeting room reserved for school board preparation.'),
    (3, 5, 5, N'Approved', '2026-06-25T15:00:00', N'Approved for supervised capstone team activity.', NULL),
    (4, 6, 6, N'Approved', '2026-06-15T11:00:00', N'Approved for midterm practical examination.', NULL),
    (5, 7, 8, N'Approved', '2026-06-18T14:10:00', N'Approved for school office orientation event.', NULL),
    (6, 8, 5, N'Approved', '2026-06-25T16:20:00', N'Approved for weekend student club activity.', NULL),
    (7, 9, 8, N'Approved', '2026-06-25T17:00:00', N'Approved for faculty-wide workshop with livestreaming.', NULL);

SET IDENTITY_INSERT dbo.APPROVAL_DECISION OFF;
GO

/* ============================================================
   7. Check-in and completion usage session details
   Check-in and completion users are Facility Staff to satisfy triggers.
   ============================================================ */

SET IDENTITY_INSERT dbo.USAGE_SESSION ON;

INSERT INTO dbo.USAGE_SESSION
    (usage_session_id, booking_id, checked_in_by_user_account_id, completed_by_user_account_id, actual_start_time, initial_condition_of_space, actual_end_time, final_condition_of_space, usage_notes)
VALUES
    (1, 5, 5, NULL, '2026-06-26T13:05:00', N'Project benches clean; projector not required.', NULL, NULL, N'Session currently checked in for capstone prototype work.'),
    (2, 6, 6, 5,    '2026-06-20T08:05:00', N'All lab computers operational before examination.', '2026-06-20T10:10:00', N'Lab returned in good condition; two keyboards reported sticky.', N'Completed examination session with minor equipment note.');

SET IDENTITY_INSERT dbo.USAGE_SESSION OFF;
GO

/* ============================================================
   8. Maintenance records with different statuses
   ============================================================ */

SET IDENTITY_INSERT dbo.MAINTENANCE_RECORD ON;

INSERT INTO dbo.MAINTENANCE_RECORD
    (maintenance_record_id, space_id, reporter_user_account_id, assigned_staff_user_account_id, problem_description, start_time, completion_time, status, result_note)
VALUES
    (1, 7, 5, 6, N'Network switches failed during lab diagnostics; replacement scheduled.', '2026-06-24T08:30:00', NULL,                  N'In progress', N'Awaiting replacement switches from vendor.'),
    (2, 1, 3, 5, N'Classroom projector image was dim during lecture.',                  '2026-06-10T09:00:00', '2026-06-10T15:30:00', N'Completed',   N'Projector lamp replaced and tested.'),
    (3, 2, 6, 6, N'Cleaning issue reported after programming contest practice.',         '2026-06-18T17:30:00', '2026-06-18T19:00:00', N'Resolved',    N'Room cleaned and waste bins replaced.'),
    (4, 5, 8, 5, N'Wireless microphone battery compartment cover is loose.',             '2026-06-22T10:00:00', NULL,                  N'Open',        N'Inspection scheduled before next auditorium event.'),
    (5, 4, 7, 5, N'Air conditioner cooling is weaker than expected.',                    '2026-06-23T13:15:00', NULL,                  N'Assigned',    N'Assigned to facility staff for HVAC vendor follow-up.');

SET IDENTITY_INSERT dbo.MAINTENANCE_RECORD OFF;
GO
