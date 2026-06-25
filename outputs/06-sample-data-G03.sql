/*
Sample Data - Group 03
Target DBMS: Microsoft SQL Server

Input analyzed: outputs/05-db-definition-G03.sql

Notes:
- The implemented schema does not contain a separate DEPARTMENT table.
  Department sample values are represented through USER_ACCOUNT.department.
- Inserts are ordered from parent tables to child tables to satisfy foreign keys.
- Booking rows avoid spaces with current_status Under maintenance, Temporarily closed,
  or Retired because TRG_BOOKING_REQUEST_VALIDATE prevents those bookings.
- Approved bookings do not overlap for the same space.
*/

/* ============================================================
   Users and department values
   ============================================================ */

INSERT INTO dbo.USER_ACCOUNT (user_id, full_name, email, phone_number, role, department, account_status) VALUES
(1001, N'Nguyen Minh Anh', N'anh.nguyen@student.university.edu', N'+84-90-111-1001', N'Student', N'Computer Science', N'Active'),
(1002, N'Tran Quoc Bao', N'bao.tran@student.university.edu', N'+84-90-111-1002', N'Student', N'Information Systems', N'Active'),
(1003, N'Dr. Le Thu Ha', N'ha.le@university.edu', N'+84-90-111-1003', N'Lecturer', N'Computer Science', N'Active'),
(1004, N'Pham Duc Long', N'long.pham@university.edu', N'+84-90-111-1004', N'Teaching Assistant', N'Software Engineering', N'Active'),
(1005, N'Vo Thi Mai', N'mai.vo.facility@university.edu', N'+84-90-111-1005', N'Facility Staff', N'Facilities Office', N'Active'),
(1006, N'Hoang Van Khoa', N'khoa.hoang.facility@university.edu', N'+84-90-111-1006', N'Facility Staff', N'Facilities Office', N'Active'),
(1007, N'Bui Thanh Ngan', N'ngan.bui.admin@university.edu', N'+84-90-111-1007', N'Department Administrator', N'School Administration', N'Active'),
(1008, N'Dang Huu Son', N'son.dang.manager@university.edu', N'+84-90-111-1008', N'Facility Manager', N'Facilities Office', N'Active'),
(1009, N'Prof. Do Lan Chi', N'chi.do@university.edu', N'+84-90-111-1009', N'Lecturer', N'Data Science', N'Active'),
(1010, N'Nguyen Hoai Nam', N'nam.nguyen.ta@university.edu', N'+84-90-111-1010', N'Teaching Assistant', N'Computer Science', N'Inactive');
GO

/* ============================================================
   Spaces
   Includes classroom, computer laboratory, project laboratory,
   meeting room, auditorium, and student workspace. Exceptional
   statuses include under maintenance, temporarily closed, and retired.
   ============================================================ */

INSERT INTO dbo.SPACE (unique_space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy) VALUES
(N'CS-A101', N'Algorithms Classroom A101', N'Classroom', N'Computer Science Building', N'1', N'A101', 60, N'Available', N'Priority for lectures and tutorials during teaching weeks.'),
(N'CS-L201', N'Programming Computer Laboratory L201', N'Computer laboratory', N'Computer Science Building', N'2', N'L201', 40, N'Available', N'Food and drinks are not allowed near computers.'),
(N'CS-P301', N'Student Project Laboratory P301', N'Project laboratory', N'Innovation Wing', N'3', N'P301', 25, N'Available', N'Project teams must clean benches after use.'),
(N'CS-M102', N'Faculty Meeting Room M102', N'Meeting room', N'Administration Block', N'1', N'M102', 18, N'Available', N'Bookings should be limited to academic and administrative meetings.'),
(N'CS-AUD1', N'Main Auditorium', N'Auditorium', N'Conference Centre', N'G', N'AUD1', 220, N'Available', N'Large events require facility manager approval.'),
(N'CS-SW01', N'Open Student Workspace', N'Student workspace', N'Learning Commons', N'2', N'SW01', 35, N'In use', N'Open collaboration area; keep noise at moderate level.'),
(N'CS-L202', N'Networking Laboratory L202', N'Computer laboratory', N'Computer Science Building', N'2', N'L202', 36, N'Under maintenance', N'Unavailable while network switches are being replaced.'),
(N'CS-M201', N'Graduate Meeting Room M201', N'Meeting room', N'Administration Block', N'2', N'M201', 12, N'Temporarily closed', N'Closed temporarily for ceiling repair.'),
(N'CS-OLD1', N'Old Seminar Room', N'Classroom', N'Old Annex', N'1', N'O101', 30, N'Retired', N'Retired from booking service.');
GO

/* ============================================================
   Facilities
   ============================================================ */

INSERT INTO dbo.FACILITY (facility_id, facility_name) VALUES
(1, N'Projector'),
(2, N'Whiteboard'),
(3, N'Microphone'),
(4, N'Computer'),
(5, N'Livestreaming equipment'),
(6, N'Air conditioner'),
(7, N'Network switch'),
(8, N'Flexible furniture');
GO

/* ============================================================
   Space-facility assignments
   ============================================================ */

INSERT INTO dbo.SPACE_FACILITY (unique_space_code, facility_id) VALUES
(N'CS-A101', 1), (N'CS-A101', 2), (N'CS-A101', 6),
(N'CS-L201', 1), (N'CS-L201', 2), (N'CS-L201', 4), (N'CS-L201', 6), (N'CS-L201', 7),
(N'CS-P301', 2), (N'CS-P301', 4), (N'CS-P301', 6), (N'CS-P301', 8),
(N'CS-M102', 1), (N'CS-M102', 2), (N'CS-M102', 6),
(N'CS-AUD1', 1), (N'CS-AUD1', 2), (N'CS-AUD1', 3), (N'CS-AUD1', 5), (N'CS-AUD1', 6),
(N'CS-SW01', 2), (N'CS-SW01', 6), (N'CS-SW01', 8),
(N'CS-L202', 1), (N'CS-L202', 4), (N'CS-L202', 6), (N'CS-L202', 7),
(N'CS-M201', 1), (N'CS-M201', 2), (N'CS-M201', 6),
(N'CS-OLD1', 2);
GO

/* ============================================================
   Booking requests
   Covers pending, approved, rejected, cancelled, checked in,
   completed, and no-show statuses with varied purposes and counts.
   ============================================================ */

INSERT INTO dbo.BOOKING_REQUEST (booking_id, requester_user_id, unique_space_code, requested_start_time, requested_end_time, purpose_of_use, expected_number_of_participants, booking_type, status) VALUES
(2001, 1003, N'CS-A101', CAST('2026-07-01T09:00:00' AS DATETIME2(0)), CAST('2026-07-01T11:00:00' AS DATETIME2(0)), N'Undergraduate database systems lecture', 55, N'Lecture', N'Approved'),
(2002, 1009, N'CS-L201', CAST('2026-07-01T13:00:00' AS DATETIME2(0)), CAST('2026-07-01T16:00:00' AS DATETIME2(0)), N'Machine learning practical examination', 38, N'Examination', N'Approved'),
(2003, 1001, N'CS-P301', CAST('2026-07-02T10:00:00' AS DATETIME2(0)), CAST('2026-07-02T12:00:00' AS DATETIME2(0)), N'Capstone project sprint planning session', 12, N'Student activity', N'Pending'),
(2004, 1004, N'CS-M102', CAST('2026-07-03T09:00:00' AS DATETIME2(0)), CAST('2026-07-03T10:30:00' AS DATETIME2(0)), N'Teaching assistant coordination meeting', 10, N'Meeting', N'Rejected'),
(2005, 1007, N'CS-AUD1', CAST('2026-07-04T14:00:00' AS DATETIME2(0)), CAST('2026-07-04T17:00:00' AS DATETIME2(0)), N'School administrative town hall', 150, N'Administrative event', N'Cancelled'),
(2006, 1003, N'CS-A101', CAST('2026-06-24T09:00:00' AS DATETIME2(0)), CAST('2026-06-24T11:00:00' AS DATETIME2(0)), N'Software engineering workshop with industry mentor', 48, N'Workshop', N'Completed'),
(2007, 1002, N'CS-SW01', CAST('2026-06-25T13:00:00' AS DATETIME2(0)), CAST('2026-06-25T15:00:00' AS DATETIME2(0)), N'Robotics club weekly build session', 20, N'Student activity', N'Checked in'),
(2008, 1009, N'CS-M102', CAST('2026-06-20T10:00:00' AS DATETIME2(0)), CAST('2026-06-20T11:30:00' AS DATETIME2(0)), N'Research seminar planning meeting', 8, N'Seminar', N'No-show'),
(2009, 1008, N'CS-AUD1', CAST('2026-07-06T09:00:00' AS DATETIME2(0)), CAST('2026-07-06T12:00:00' AS DATETIME2(0)), N'Facility safety briefing for laboratory users', 180, N'Seminar', N'Approved'),
(2010, 1005, N'CS-P301', CAST('2026-07-07T13:30:00' AS DATETIME2(0)), CAST('2026-07-07T15:00:00' AS DATETIME2(0)), N'Facilities team planning workshop', 16, N'Workshop', N'Pending');
GO

/* ============================================================
   Approval and rejection details
   Decision makers use Facility Staff or Facility Manager roles.
   Rejected booking includes a rejection reason.
   ============================================================ */

INSERT INTO dbo.APPROVAL_DECISION (approval_decision_id, booking_id, decision_maker_user_id, decision_time, decision_note, rejection_reason) VALUES
(3001, 2001, 1008, CAST('2026-06-20T10:15:00' AS DATETIME2(0)), N'Approved for regular lecture delivery.', NULL),
(3002, 2002, 1008, CAST('2026-06-20T10:30:00' AS DATETIME2(0)), N'Approved; laboratory availability confirmed.', NULL),
(3003, 2004, 1005, CAST('2026-06-21T15:45:00' AS DATETIME2(0)), N'Rejected because another internal planning activity needs the room setup period.', N'Room setup buffer is unavailable for the requested time.'),
(3004, 2006, 1005, CAST('2026-06-18T08:45:00' AS DATETIME2(0)), N'Approved for completed workshop.', NULL),
(3005, 2007, 1006, CAST('2026-06-24T17:20:00' AS DATETIME2(0)), N'Approved for student workspace activity.', NULL),
(3006, 2008, 1005, CAST('2026-06-18T14:10:00' AS DATETIME2(0)), N'Approved for small seminar planning meeting.', NULL),
(3007, 2009, 1008, CAST('2026-06-22T09:00:00' AS DATETIME2(0)), N'Approved for auditorium safety briefing.', NULL);
GO

/* ============================================================
   Usage sessions
   Includes checked-in in-progress session and completed session
   with actual start and end time.
   ============================================================ */

INSERT INTO dbo.USAGE_SESSION (usage_session_id, booking_id, checked_in_by_user_id, completed_by_user_id, actual_start_time, initial_condition_of_the_space, actual_end_time, final_condition_of_the_space, usage_notes) VALUES
(4001, 2006, 1005, 1006, CAST('2026-06-24T09:05:00' AS DATETIME2(0)), N'Classroom clean; projector and whiteboard operational.', CAST('2026-06-24T10:55:00' AS DATETIME2(0)), N'Classroom clean; chairs returned to standard layout.', N'Workshop ended five minutes early with no incident.'),
(4002, 2007, 1006, NULL, CAST('2026-06-25T13:05:00' AS DATETIME2(0)), N'Student workspace tidy; movable tables arranged for team work.', NULL, NULL, N'Checked in; session currently in progress.');
GO

/* ============================================================
   Maintenance records
   Status is unconstrained by the DDL, so varied realistic values
   are included. Records reference existing spaces and users.
   ============================================================ */

INSERT INTO dbo.MAINTENANCE_RECORD (maintenance_record_id, unique_space_code, reported_by_user_id, assigned_to_user_id, problem_description, start_time, completion_time, status, result_note) VALUES
(5001, N'CS-L202', 1003, 1006, N'Network switches intermittently disconnect laboratory computers.', CAST('2026-06-23T08:00:00' AS DATETIME2(0)), NULL, N'In progress', N'Replacement switch installation scheduled; space remains under maintenance.'),
(5002, N'CS-M201', 1007, 1005, N'Ceiling panel water stain and loose fixture above meeting table.', CAST('2026-06-22T11:30:00' AS DATETIME2(0)), NULL, N'Waiting for contractor', N'Room temporarily closed until contractor inspection is complete.'),
(5003, N'CS-A101', 1004, 1005, N'Projector image flickered during tutorial.', CAST('2026-06-19T16:00:00' AS DATETIME2(0)), CAST('2026-06-20T09:30:00' AS DATETIME2(0)), N'Completed', N'HDMI cable replaced and projector tested successfully.'),
(5004, N'CS-SW01', 1002, 1006, N'Two chairs damaged near the north window.', CAST('2026-06-25T09:20:00' AS DATETIME2(0)), NULL, N'Reported', N'Chairs tagged and moved aside for repair.'),
(5005, N'CS-OLD1', 1008, 1005, N'Retired room requires inventory removal before handover.', CAST('2026-06-18T10:00:00' AS DATETIME2(0)), NULL, N'Deferred', N'Awaiting confirmation of disposal schedule.');
GO
