/*
    Sample Data - Group 03
    Target DBMS: Microsoft SQL Server

    Input Analyzed
    - Authoritative DDL input: outputs/05-db-definition-G03.sql.
    - Implemented tables only: USER_ACCOUNT, SPACE, FACILITY, SPACE_FACILITY, BOOKING_REQUEST, APPROVAL_DECISION, USAGE_SESSION, MAINTENANCE_RECORD.
    - Implemented triggers analyzed: TR_BOOKING_REQUEST_prevent_unavailable_space_booking, TR_BOOKING_REQUEST_prevent_approved_overlap, TR_APPROVAL_DECISION_validate_decision_maker_role, TR_APPROVAL_DECISION_require_rejection_reason, TR_USAGE_SESSION_validate_facility_staff_roles, TR_USAGE_SESSION_completion_consistency.
    - No views are implemented in the current DDL.

    Execution Assumption
    - This script is intended to run after outputs/05-db-definition-G03.sql on a clean database created by that DDL's drop/recreate sequence.
    - Fixed identity values are inserted with SET IDENTITY_INSERT so exceptional cases can be traced to stable IDs.
    - The sample script is not idempotent by itself; rerun the DDL first for repeatable demo execution.

    Assumptions Carried Forward
    - There is no DEPARTMENT table in the DDL, so department values are populated only through USER_ACCOUNT.department.
    - USER_ACCOUNT.account_status has no CHECK constraint; the realistic sample value Active is inserted only as sample text, not as an enforced allowed value.
    - SPACE.space_type has no CHECK constraint; required space examples are inserted as descriptive text.
    - MAINTENANCE_RECORD.status has no CHECK constraint; different maintenance status values are inserted only because the implemented schema allows them.
    - APPROVAL_DECISION has no decision_outcome column in the current DDL; approval/rejection meaning is inferred from BOOKING_REQUEST.booking_status and decision notes.
    - Bookings are not inserted for spaces whose current_status is Under maintenance, Temporarily closed, or Retired.

    Open Questions Carried Forward
    - Allowed USER_ACCOUNT.account_status values remain unresolved.
    - SPACE.usage_policy enforcement remains unresolved.
    - Automatic synchronization between MAINTENANCE_RECORD and SPACE.current_status remains unresolved.
    - Cancellation and no-show transition actors/triggers remain unresolved.
    - Approval-required criteria and approval-bypass rules remain unresolved.
    - Whether a booking can have multiple approval decisions remains unresolved; this script uses one decision per decided booking while the DDL permits more.
    - Allowed MAINTENANCE_RECORD.status values and transitions remain unresolved.
    - Maintenance reporter/assignee role restrictions remain unresolved.
    - Staff-view authorization scope remains unresolved.
    - Participant count versus SPACE.capacity comparison remains unresolved.

    Trigger Compliance
    - TR_BOOKING_REQUEST_prevent_unavailable_space_booking: all BOOKING_REQUEST rows reference Available spaces only; unavailable spaces are inserted as SPACE-UM-701, SPACE-TC-801, and SPACE-RT-901 but are not booked.
    - TR_BOOKING_REQUEST_prevent_approved_overlap: Approved bookings do not overlap for the same space; approved booking IDs 2, 8, and 9 use distinct spaces/times.
    - TR_APPROVAL_DECISION_validate_decision_maker_role: all decision makers are Facility Staff user_account_id 4 or Facility Manager user_account_id 6.
    - TR_APPROVAL_DECISION_require_rejection_reason: rejected booking_id 3 has approval_decision_id 2 with a non-null rejection_reason.
    - TR_USAGE_SESSION_validate_facility_staff_roles: usage_session_id 1 and 2 are checked in by Facility Staff user_account_id 4; completed usage_session_id 2 is also completed by Facility Staff user_account_id 4.
    - TR_USAGE_SESSION_completion_consistency: in-progress usage_session_id 1 leaves all completion fields NULL; completed usage_session_id 2 populates completed_by_user_account_id, actual_end_time, and final_condition_of_space together.

    Sample Coverage / Traceability
    - User roles: Student user_account_id 1 and 7; Lecturer 2 and 8; Teaching Assistant 3; Facility Staff 4; Department Administrator 5; Facility Manager 6.
    - Space examples: classroom SPACE-CLS-101, computer laboratory SPACE-COM-202, project laboratory SPACE-PRJ-303, meeting room SPACE-MTG-404, auditorium SPACE-AUD-501, student workspace SPACE-STW-601.
    - Facilities: projector facility_id 1, whiteboard 2, microphone 3, computer 4, livestreaming equipment 5, air conditioner 6.
    - Booking statuses: Pending booking_id 1; Approved booking_ids 2, 8, 9; Rejected booking_id 3; Cancelled booking_id 4; Checked in booking_id 5; Completed booking_id 6; No-show booking_id 7.
    - Rejected booking with reason: booking_id 3, approval_decision_id 2.
    - Cancelled booking: booking_id 4.
    - No-show booking: booking_id 7.
    - Completed booking with actual start/end: booking_id 6, usage_session_id 2.
    - Checked-in in-progress usage session: booking_id 5, usage_session_id 1.
    - Space under maintenance: SPACE-UM-701 with maintenance_record_id 1.
    - Temporarily closed space: SPACE-TC-801.
    - Retired space: SPACE-RT-901.
    - Varied purposes and participant counts: booking_ids 1-9 cover Lecture, Workshop, Meeting, Seminar, Administrative event, Student activity, and Examination with participant counts from 8 to 220.
*/

/* ============================================================
   1. USER_ACCOUNT
   ============================================================ */

SET IDENTITY_INSERT dbo.USER_ACCOUNT ON;

INSERT INTO dbo.USER_ACCOUNT
    (user_account_id, user_id, full_name, email, phone_number, role, department, account_status)
VALUES
    (1, N'STU2026001', N'Nguyen Minh Anh', N'anh.nguyen@student.example.edu', N'+84-90-100-0001', N'Student', N'Computer Science', N'Active'),
    (2, N'LEC2026002', N'Dr. Tran Bao Long', N'long.tran@university.example.edu', N'+84-90-100-0002', N'Lecturer', N'Computer Science', N'Active'),
    (3, N'TA2026003', N'Pham Gia Huy', N'huy.pham@university.example.edu', N'+84-90-100-0003', N'Teaching Assistant', N'Information Systems', N'Active'),
    (4, N'FAC2026004', N'Le Thu Ha', N'ha.le.facilities@university.example.edu', N'+84-90-100-0004', N'Facility Staff', N'Campus Facilities', N'Active'),
    (5, N'ADM2026005', N'Do Quynh Chi', N'chi.do.admin@university.example.edu', N'+84-90-100-0005', N'Department Administrator', N'Business Administration', N'Active'),
    (6, N'MGR2026006', N'Hoang Duc Nam', N'nam.hoang.manager@university.example.edu', N'+84-90-100-0006', N'Facility Manager', N'Campus Facilities', N'Active'),
    (7, N'STU2026007', N'Vo Khanh Linh', N'linh.vo@student.example.edu', N'+84-90-100-0007', N'Student', N'Design and Media', N'Active'),
    (8, N'LEC2026008', N'Dr. Bui Thanh Son', N'son.bui@university.example.edu', N'+84-90-100-0008', N'Lecturer', N'Electrical Engineering', N'Active');

SET IDENTITY_INSERT dbo.USER_ACCOUNT OFF;
GO

/* ============================================================
   2. SPACE
   ============================================================ */

SET IDENTITY_INSERT dbo.SPACE ON;

INSERT INTO dbo.SPACE
    (space_id, unique_space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy)
VALUES
    (1, N'SPACE-CLS-101', N'Innovation Classroom 101', N'Classroom', N'Alpha Building', N'1', N'101', 60, N'Available', N'General teaching use; return furniture to default layout.'),
    (2, N'SPACE-COM-202', N'Computer Laboratory 202', N'Computer laboratory', N'Beta Building', N'2', N'202', 40, N'Available', N'No food or drink near workstations.'),
    (3, N'SPACE-PRJ-303', N'Project Laboratory 303', N'Project laboratory', N'Gamma Building', N'3', N'303', 30, N'Available', N'Safety briefing required before equipment use.'),
    (4, N'SPACE-MTG-404', N'Collaboration Meeting Room 404', N'Meeting room', N'Admin Building', N'4', N'404', 16, N'Available', N'Bookings limited to university business meetings.'),
    (5, N'SPACE-AUD-501', N'Main Auditorium 501', N'Auditorium', N'Central Hall', N'5', N'501', 250, N'Available', N'Events with external guests require facility manager review.'),
    (6, N'SPACE-STW-601', N'Open Student Workspace 601', N'Student workspace', N'Library Wing', N'6', N'601', 80, N'Available', N'Keep shared workspace clean and quiet.'),
    (7, N'SPACE-UM-701', N'Robotics Lab 701', N'Project laboratory', N'Engineering Annex', N'7', N'701', 25, N'Under maintenance', N'Unavailable until maintenance is completed.'),
    (8, N'SPACE-TC-801', N'Executive Seminar Room 801', N'Meeting room', N'Admin Building', N'8', N'801', 20, N'Temporarily closed', N'Temporarily closed for inspection.'),
    (9, N'SPACE-RT-901', N'Old Lecture Hall 901', N'Classroom', N'Legacy Block', N'9', N'901', 120, N'Retired', N'Retired from booking inventory.');

SET IDENTITY_INSERT dbo.SPACE OFF;
GO

/* ============================================================
   3. FACILITY
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
   4. SPACE_FACILITY
   ============================================================ */

SET IDENTITY_INSERT dbo.SPACE_FACILITY ON;

INSERT INTO dbo.SPACE_FACILITY
    (space_facility_id, space_id, facility_id)
VALUES
    (1, 1, 1),
    (2, 1, 2),
    (3, 1, 6),
    (4, 2, 1),
    (5, 2, 2),
    (6, 2, 4),
    (7, 2, 6),
    (8, 3, 2),
    (9, 3, 4),
    (10, 3, 6),
    (11, 4, 1),
    (12, 4, 2),
    (13, 4, 6),
    (14, 5, 1),
    (15, 5, 3),
    (16, 5, 5),
    (17, 5, 6),
    (18, 6, 2),
    (19, 6, 6),
    (20, 7, 4),
    (21, 8, 1),
    (22, 9, 2);

SET IDENTITY_INSERT dbo.SPACE_FACILITY OFF;
GO

/* ============================================================
   5. BOOKING_REQUEST
   ============================================================ */

SET IDENTITY_INSERT dbo.BOOKING_REQUEST ON;

INSERT INTO dbo.BOOKING_REQUEST
    (booking_id, requester_user_account_id, space_id, requested_start_time, requested_end_time, purpose_of_use, expected_number_of_participants, booking_status)
VALUES
    (1, 1, 1, '2026-07-01T09:00:00', '2026-07-01T11:00:00', N'Lecture', 45, N'Pending'),
    (2, 2, 2, '2026-07-01T13:00:00', '2026-07-01T15:00:00', N'Workshop', 24, N'Approved'),
    (3, 7, 4, '2026-07-02T10:00:00', '2026-07-02T12:00:00', N'Meeting', 8, N'Rejected'),
    (4, 3, 3, '2026-07-03T14:00:00', '2026-07-03T16:00:00', N'Seminar', 18, N'Cancelled'),
    (5, 2, 5, '2026-07-04T09:00:00', '2026-07-04T12:00:00', N'Seminar', 220, N'Checked in'),
    (6, 5, 4, '2026-06-22T10:00:00', '2026-06-22T11:30:00', N'Administrative event', 12, N'Completed'),
    (7, 1, 6, '2026-06-20T15:00:00', '2026-06-20T17:00:00', N'Student activity', 35, N'No-show'),
    (8, 8, 1, '2026-07-02T09:00:00', '2026-07-02T11:00:00', N'Examination', 55, N'Approved'),
    (9, 5, 5, '2026-07-05T09:00:00', '2026-07-05T12:00:00', N'Administrative event', 180, N'Approved');

SET IDENTITY_INSERT dbo.BOOKING_REQUEST OFF;
GO

/* ============================================================
   6. APPROVAL_DECISION
   ============================================================ */

SET IDENTITY_INSERT dbo.APPROVAL_DECISION ON;

INSERT INTO dbo.APPROVAL_DECISION
    (approval_decision_id, booking_id, decision_maker_user_account_id, decision_time, decision_note, rejection_reason)
VALUES
    (1, 2, 4, '2026-06-26T09:15:00', N'Approved because the computer lab is available and the workshop fits the capacity.', NULL),
    (2, 3, 6, '2026-06-26T10:05:00', N'Rejected after facility manager review.', N'Request conflicts with a reserved administrative preparation window.'),
    (3, 4, 4, '2026-06-26T11:20:00', N'Initially approved; requester later cancelled due to schedule change.', NULL),
    (4, 5, 6, '2026-06-27T08:30:00', N'Approved for auditorium seminar with livestreaming support.', NULL),
    (5, 6, 4, '2026-06-18T14:00:00', N'Approved for department coordination meeting.', NULL),
    (6, 7, 4, '2026-06-18T15:30:00', N'Approved for student workspace activity; requester did not attend.', NULL),
    (7, 8, 6, '2026-06-27T13:45:00', N'Approved for examination session.', NULL),
    (8, 9, 6, '2026-06-27T16:10:00', N'Approved for administrative town hall in the auditorium.', NULL);

SET IDENTITY_INSERT dbo.APPROVAL_DECISION OFF;
GO

/* ============================================================
   7. USAGE_SESSION
   ============================================================ */

SET IDENTITY_INSERT dbo.USAGE_SESSION ON;

INSERT INTO dbo.USAGE_SESSION
    (usage_session_id, booking_id, checked_in_by_user_account_id, completed_by_user_account_id, actual_start_time, initial_condition_of_space, actual_end_time, final_condition_of_space, usage_notes)
VALUES
    (1, 5, 4, NULL, '2026-07-04T08:55:00', N'Auditorium opened, microphones tested, livestreaming console powered on.', NULL, NULL, N'In-progress seminar session.'),
    (2, 6, 4, 4, '2026-06-22T09:55:00', N'Meeting room clean and ready; projector functional.', '2026-06-22T11:25:00', N'Room returned clean; chairs reset; no damage observed.', N'Completed without incident.');

SET IDENTITY_INSERT dbo.USAGE_SESSION OFF;
GO

/* ============================================================
   8. MAINTENANCE_RECORD
   ============================================================ */

SET IDENTITY_INSERT dbo.MAINTENANCE_RECORD ON;

INSERT INTO dbo.MAINTENANCE_RECORD
    (maintenance_record_id, space_id, reporter_user_account_id, assigned_staff_user_account_id, problem_description, start_time, completion_time, status, result_note)
VALUES
    (1, 7, 4, 4, N'Robotics lab power bench fault reported during weekly inspection.', '2026-06-24T08:00:00', NULL, N'In progress', N'Electrical contractor scheduled; space remains under maintenance.'),
    (2, 1, 2, 4, N'Classroom projector intermittently loses HDMI signal.', '2026-06-19T09:00:00', '2026-06-19T11:30:00', N'Completed', N'HDMI wall plate replaced and projector tested successfully.'),
    (3, 8, 6, 4, N'Inspection required after ceiling water stain was discovered.', '2026-06-23T13:00:00', NULL, N'Pending inspection', N'Room temporarily closed while facilities investigates.'),
    (4, 5, 5, 4, N'Auditorium microphone battery charging dock needed replacement.', '2026-06-17T10:00:00', '2026-06-17T15:00:00', N'Completed', N'Charging dock replaced before next scheduled event.');

SET IDENTITY_INSERT dbo.MAINTENANCE_RECORD OFF;
GO

/* End of sample data script. */
