/*
Sample Data - Group 03
Target DBMS: Microsoft SQL Server

Input Analyzed:
- outputs/05-db-definition-G03.sql

Execution Assumption:
- Run this script after outputs/05-db-definition-G03.sql has recreated the schema on a clean database.
- The DDL uses IDENTITY(1,1) surrogate keys; because this script is intended for a clean database, inserted identity IDs are deterministic in insert order and are referenced in the coverage map below.
- This script is not idempotent by itself; rerun the DDL first to reset schema and identity values.

Assumptions Carried Forward:
- No DEPARTMENT table exists in the implemented schema; department values are populated only through USER_ACCOUNT.department.
- USER_ACCOUNT.account_status has no CHECK constraint; realistic values such as Active, Suspended, and Inactive are used.
- MAINTENANCE_RECORD.status has no CHECK constraint; realistic values such as Reported, In progress, Completed, and Awaiting parts are used.
- SPACE.space_type and FACILITY.facility_name are open catalogs; sample values follow source examples but are not constrained by CHECK.
- Booking statuses and purpose values exactly match CK_BOOKING_REQUEST_status and CK_BOOKING_REQUEST_purpose_of_use.
- APPROVAL_DECISION.decision_outcome exists in the DDL and must be Approved or Rejected.

Open Questions Carried Forward:
- SPACE.usage_policy enforcement is unresolved; sample text is descriptive only.
- Cancelled and No-show transition triggers are unresolved; sample rows use those statuses without modeling transition history.
- Maintenance status values/transitions and whether maintenance records update SPACE.current_status are unresolved.
- Maintenance reporter/assignee role rules are unresolved; sample uses plausible users without additional constraints.
- Whether APPROVAL_DECISION automatically updates BOOKING_REQUEST.status is unresolved; sample rows keep them consistent by convention.
- Whether expected_number_of_participants must be <= SPACE.capacity is unresolved; sample rows stay within capacity to remain realistic.
- USER_ACCOUNT.account_status allowed values are unresolved.

Trigger Compliance:
- TR_BOOKING_REQUEST_NoOverlap on BOOKING_REQUEST: rejects overlapping Approved bookings for the same space. Approved bookings in this script use different spaces or non-overlapping time periods. Cancelled/Rejected/No-show/Checked in/Completed examples are not inserted as overlapping Approved rows.
- TR_BOOKING_REQUEST_SpaceAvailability on BOOKING_REQUEST: rejects bookings for spaces with current_status Under maintenance, Temporarily closed, or Retired. Bookings reference only SPACE IDs 1-6; unavailable spaces S-PRJ-204, S-CLS-105, and S-AUD-RET are not booked.
- TR_APPROVAL_DECISION_RoleCheck on APPROVAL_DECISION: decision makers must be Facility Staff or Facility Manager. All decisions use USER_ACCOUNT IDs 4, 6, or 7.
- TR_APPROVAL_DECISION_RejectionReason on APPROVAL_DECISION: Rejected decisions require rejection_reason. Decision ID 3 has a non-null rejection reason.
- TR_USAGE_SESSION_CheckInRoleCheck on USAGE_SESSION: checked_in_by_user_account_id must be Facility Staff. Sessions use USER_ACCOUNT IDs 4 or 7 for check-in.
- TR_USAGE_SESSION_CompletionRoleCheck on USAGE_SESSION: completed_by_user_account_id, when present, must be Facility Staff. Completed session uses USER_ACCOUNT ID 7.
- TR_USAGE_SESSION_CompletionConsistency on USAGE_SESSION: completion fields must be all null or all non-null. Session 1 has all completion fields populated; session 2 has all completion fields null.

Sample Coverage / Traceability:
- Roles: Student=USER_ACCOUNT 1, Lecturer=2, Teaching Assistant=3, Facility Staff=4 and 7, Department Administrator=5, Facility Manager=6.
- Departments: populated in USER_ACCOUNT.department only; no DEPARTMENT table is inserted.
- Space types: classroom=S-CLS-101, computer laboratory=S-LAB-201, project laboratory=S-PRJ-203/S-PRJ-204, meeting room=S-MTG-301, auditorium=S-AUD-401/S-AUD-RET, student workspace=S-STU-501.
- Facilities: Projector=1, Whiteboard=2, Microphone=3, Computer=4, Livestreaming equipment=5, Air conditioner=6.
- Pending booking: BOOKING_REQUEST 1.
- Approved booking: BOOKING_REQUEST 2 with APPROVAL_DECISION 1.
- Rejected booking with reason: BOOKING_REQUEST 3 with APPROVAL_DECISION 3.
- Cancelled booking: BOOKING_REQUEST 4.
- Checked-in/in-progress booking: BOOKING_REQUEST 5 with USAGE_SESSION 2.
- Completed booking with actual start/end: BOOKING_REQUEST 6 with USAGE_SESSION 1.
- No-show booking: BOOKING_REQUEST 7.
- Additional approved booking for non-overlap testing: BOOKING_REQUEST 8 with APPROVAL_DECISION 5.
- Space under maintenance: SPACE S-PRJ-204 (space_id 7) and MAINTENANCE_RECORD 2.
- Temporarily closed space: SPACE S-CLS-105 (space_id 8).
- Retired space: SPACE S-AUD-RET (space_id 9).
- Maintenance records: Reported=1, In progress=2, Completed=3, Awaiting parts=4.
*/

/* ============================================================
   Parent data: users, spaces, facilities
   ============================================================ */

INSERT INTO dbo.USER_ACCOUNT (user_id, full_name, email, phone_number, role, department, account_status) VALUES
(N'U2024001', N'An Nguyen Minh', N'an.nguyen@student.university.edu', N'+84-090-100-0001', N'Student', N'School of Computer Science', N'Active'),
(N'L2019002', N'Dr. Binh Tran', N'binh.tran@university.edu', N'+84-090-100-0002', N'Lecturer', N'School of Computer Science', N'Active'),
(N'TA2023003', N'Chi Le Phuong', N'chi.le@university.edu', N'+84-090-100-0003', N'Teaching Assistant', N'School of Computer Science', N'Active'),
(N'FS2018004', N'Duc Pham Van', N'duc.pham.facilities@university.edu', N'+84-090-100-0004', N'Facility Staff', N'Facilities Office', N'Active'),
(N'DA2017005', N'Ha Vu Thu', N'ha.vu.admin@university.edu', N'+84-090-100-0005', N'Department Administrator', N'School Office', N'Active'),
(N'FM2016006', N'Lan Hoang', N'lan.hoang.manager@university.edu', N'+84-090-100-0006', N'Facility Manager', N'Facilities Office', N'Active'),
(N'FS2021007', N'Minh Do Quang', N'minh.do.facilities@university.edu', N'+84-090-100-0007', N'Facility Staff', N'Facilities Office', N'Active'),
(N'U2023008', N'Oanh Pham Mai', N'oanh.pham@student.university.edu', NULL, N'Student', N'School of Computer Science', N'Suspended');
GO

INSERT INTO dbo.SPACE (unique_space_code, space_name, space_type, building, floor, room_number, capacity, current_status, usage_policy) VALUES
(N'S-CLS-101', N'CS Classroom 101', N'Classroom', N'CS Building', N'1', N'101', 60, N'Available', N'General teaching use; return furniture to default layout.'),
(N'S-LAB-201', N'Programming Laboratory 201', N'Computer laboratory', N'CS Building', N'2', N'201', 40, N'Available', N'No food or drink; accounts required for lab computers.'),
(N'S-PRJ-203', N'Project Laboratory 203', N'Project laboratory', N'Innovation Block', N'2', N'203', 24, N'Available', N'Project teams must clean benches after use.'),
(N'S-MTG-301', N'Seminar Meeting Room 301', N'Meeting room', N'Administration Building', N'3', N'301', 18, N'Available', N'Bookings limited to academic meetings and consultations.'),
(N'S-AUD-401', N'Main Auditorium 401', N'Auditorium', N'Learning Center', N'4', N'401', 220, N'Available', N'Events must coordinate AV support in advance.'),
(N'S-STU-501', N'Student Workspace 501', N'Student workspace', N'Library Annex', N'5', N'501', 32, N'In use', N'Collaborative study only; keep noise low.'),
(N'S-PRJ-204', N'Robotics Project Laboratory 204', N'Project laboratory', N'Innovation Block', N'2', N'204', 20, N'Under maintenance', N'Use only after safety inspection is cleared.'),
(N'S-CLS-105', N'Classroom 105', N'Classroom', N'CS Building', N'1', N'105', 55, N'Temporarily closed', N'Temporarily closed for repainting.'),
(N'S-AUD-RET', N'Old Auditorium', N'Auditorium', N'Old Campus', N'1', N'A1', 150, N'Retired', N'Retired from booking inventory.');
GO

INSERT INTO dbo.FACILITY (facility_name) VALUES
(N'Projector'),
(N'Whiteboard'),
(N'Microphone'),
(N'Computer'),
(N'Livestreaming equipment'),
(N'Air conditioner');
GO

/* ============================================================
   Space-facility assignments
   ============================================================ */

INSERT INTO dbo.SPACE_FACILITY (space_id, facility_id) VALUES
(1, 1), (1, 2), (1, 6),
(2, 1), (2, 2), (2, 4), (2, 6),
(3, 2), (3, 4), (3, 6),
(4, 1), (4, 2), (4, 6),
(5, 1), (5, 2), (5, 3), (5, 5), (5, 6),
(6, 2), (6, 6),
(7, 2), (7, 4),
(8, 1), (8, 2),
(9, 3);
GO

/* ============================================================
   Booking requests
   ============================================================ */

INSERT INTO dbo.BOOKING_REQUEST (requester_user_account_id, space_id, requested_start_time, requested_end_time, purpose_of_use, expected_number_of_participants, status) VALUES
(1, 1, '2026-07-01T09:00:00', '2026-07-01T10:30:00', N'Student activity', 35, N'Pending'),
(2, 1, '2026-07-02T09:00:00', '2026-07-02T11:00:00', N'Lecture', 55, N'Approved'),
(3, 2, '2026-07-02T13:00:00', '2026-07-02T15:00:00', N'Workshop', 38, N'Rejected'),
(5, 4, '2026-07-03T10:00:00', '2026-07-03T11:00:00', N'Meeting', 12, N'Cancelled'),
(1, 6, '2026-07-03T14:00:00', '2026-07-03T16:00:00', N'Student activity', 20, N'Checked in'),
(2, 5, '2026-06-25T08:00:00', '2026-06-25T12:00:00', N'Seminar', 180, N'Completed'),
(3, 3, '2026-06-26T09:00:00', '2026-06-26T10:00:00', N'Examination', 22, N'No-show'),
(6, 5, '2026-07-04T09:00:00', '2026-07-04T17:00:00', N'Administrative event', 120, N'Approved');
GO

/* ============================================================
   Approval decisions
   ============================================================ */

INSERT INTO dbo.APPROVAL_DECISION (booking_id, decision_maker_user_account_id, decision_outcome, decision_time, decision_note, rejection_reason) VALUES
(2, 6, N'Approved', '2026-06-28T10:15:00', N'Approved for scheduled database lecture.', NULL),
(6, 4, N'Approved', '2026-06-20T16:30:00', N'Approved with auditorium AV support.', NULL),
(3, 4, N'Rejected', '2026-06-29T09:30:00', N'Rejected due to lab preparation conflict.', N'Computer laboratory is reserved for system imaging during the requested time.'),
(5, 7, N'Approved', '2026-07-01T08:45:00', N'Approved for student project showcase.', NULL),
(8, 6, N'Approved', '2026-07-01T11:20:00', N'Approved for school administrative event.', NULL);
GO

/* ============================================================
   Usage sessions
   ============================================================ */

INSERT INTO dbo.USAGE_SESSION (booking_id, checked_in_by_user_account_id, completed_by_user_account_id, actual_start_time, initial_condition_of_space, actual_end_time, final_condition_of_space, usage_notes) VALUES
(6, 4, 7, '2026-06-25T08:05:00', N'Auditorium clean; projector, microphones, and livestreaming equipment operational.', '2026-06-25T11:55:00', N'Auditorium clean; all AV equipment returned and powered down.', N'Seminar completed smoothly with livestream support.'),
(5, 7, NULL, '2026-07-03T14:05:00', N'Student workspace occupied; whiteboard available and air conditioning normal.', NULL, NULL, NULL);
GO

/* ============================================================
   Maintenance records
   ============================================================ */

INSERT INTO dbo.MAINTENANCE_RECORD (space_id, reporter_user_account_id, assigned_staff_user_account_id, problem_description, start_time, completion_time, status, result_note) VALUES
(1, 2, 4, N'Projector image flickers intermittently during lectures.', '2026-06-24T09:00:00', NULL, N'Reported', NULL),
(7, 4, 7, N'Robotics lab air-conditioning failure and safety ventilation warning.', '2026-06-27T08:30:00', NULL, N'In progress', N'Portable ventilation installed; awaiting replacement compressor.'),
(5, 7, 4, N'Microphone battery pack failed during rehearsal.', '2026-06-20T13:00:00', '2026-06-21T15:30:00', N'Completed', N'Replaced battery pack and tested wireless microphone.'),
(2, 3, NULL, N'Two lab computers report network authentication errors.', '2026-07-01T10:00:00', NULL, N'Awaiting parts', NULL);
GO

/* ============================================================
   End of Sample Data - Group 03
   ============================================================ */
