# Business Requirement Analysis - G03

## 1. Source Documents

- Requested input: `req/business-requirement.md`
- Actual input used: `req/business-requirement.md`
- Target system: Campus Space Management System

## 2. Business Context

The School of Computer Science manages shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. Current requests are handled manually through the school office or facility staff by email, phone, or in person, with staff checking spreadsheets or shared calendars. As the number of classes, student projects, workshops, seminars, and academic events increases, the manual process has become difficult to manage. The School wants a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization.

## 3. System Actors

| Actor | Description | Main Responsibilities / Interactions |
|---|---|---|
| Student | A user role with a university account. | Can submit booking requests as a listed user role; no student-specific permission beyond general user submission is stated. |
| Lecturer | A user role with a university account. | Can submit booking requests as a listed user role; no lecturer-specific approval, check-in, or maintenance assignment permission is stated. |
| Teaching Assistant | A user role with a university account. | Can submit booking requests under the general user booking capability. |
| Facility Staff | A user role with a university account. | Can approve or reject bookings when approval is required, check in bookings, complete usage sessions, be assigned to maintenance records, and view operational booking and maintenance information. |
| Department Administrator | A user role with a university account. | Can submit booking requests as a listed user role; no department-administrator-specific permission beyond general user submission is stated. |
| Facility Manager | A user role with a university account and the stakeholder providing the requirement summary. | Can approve or reject bookings when approval is required and view operational booking and maintenance information. |

## 4. Main Entities and Attributes

### 4.1 User

A person with a university account who can interact with the system according to their role.

Attributes:

- User ID
- Full name
- Email
- Phone number
- Role
- Department
- Account status

Possible roles:

- Student
- Lecturer
- Teaching assistant
- Facility staff
- Department administrator
- Facility manager

### 4.2 Space

A shared campus space managed by the School and available for booking depending on its status.

Attributes:

- Unique space code
- Space name
- Space type
- Building
- Floor
- Room number
- Capacity
- Current status
- Usage policy

Possible current statuses:

- Available
- In use
- Under maintenance
- Temporarily closed
- Retired

### 4.3 Facility

A facility or equipment item recorded as available in a space.

Attributes:

- Related space
- Facility available in the space

Possible facilities:

- Projector
- Whiteboard
- Microphone
- Computer
- Livestreaming equipment
- Air conditioner

### 4.4 Booking Request

A user request to use a selected space for a requested time period and purpose.

Attributes:

- Requesting user
- Requested space
- Requested start time
- Requested end time
- Purpose of use
- Expected number of participants
- Booking type
- Status

Possible booking types:

- Lecture
- Examination
- Seminar
- Workshop
- Meeting
- Student activity
- Administrative event

Possible statuses:

- Pending
- Approved
- Rejected
- Cancelled
- Checked in
- Completed
- No-show

### 4.5 Approval Decision

A recorded approval or rejection decision for a booking request that requires approval.

Attributes:

- Related booking request
- Decided by staff member or manager
- Decision time
- Decision note
- Rejection reason

### 4.6 Usage Session

The actual use of a booked space from check-in through completion.

Attributes:

- Related booking request
- Actual start time
- Checked in by facility staff member
- Initial condition of the space
- Actual end time
- Completed by facility staff member
- Final condition of the space
- Usage notes

### 4.7 Maintenance Record

A record of a problem, assignment, and resolution activity for a space.

Attributes:

- Related space
- Reporter
- Assigned staff member
- Problem description
- Start time
- Completion time
- Status
- Result note

Possible problem examples:

- Broken projector
- Air-conditioning failure
- Damaged furniture
- Cleaning issue
- Network problem

## 5. Relationships and Cardinalities

| Relationship | Cardinality | Description |
|---|---:|---|
| User submits Booking Request | One User to many Booking Requests | Users can submit booking requests. Each booking request has one requesting user. |
| Booking Request selects Space | Many Booking Requests to one Space | Users submit booking requests by selecting a space. Each booking request is for one selected space. |
| Space has Facility | One Space to many Facilities | Each space may have several facilities, and the system stores the list of facilities available in each space. |
| Booking Request has Approval Decision | One Booking Request to zero or one Approval Decision | A booking request may require approval. When approved or rejected, the system records the decision details. |
| Approval Decision is made by User | Many Approval Decisions to one User | The system records the staff member or manager who made an approval or rejection decision. |
| Booking Request has Usage Session | One Booking Request to zero or one Usage Session | When the requester arrives, facility staff can check in the booking; when the session ends, facility staff can complete the booking. |
| Usage Session checked in by User | Many Usage Sessions to one User | Facility staff can check in bookings, and the system records the person who checked in the booking. |
| Usage Session completed by User | Many Usage Sessions to one User | Facility staff can complete bookings; this action is kept separate from check-in because it occurs at session end. |
| Space has Maintenance Record | One Space to many Maintenance Records | A space may have maintenance records. Each maintenance record stores the related space. |
| Maintenance Record reported by User | Many Maintenance Records to one User | Each maintenance record stores the reporter. |
| Maintenance Record assigned to User | Many Maintenance Records to one User | Each maintenance record stores the assigned staff member. |

## 6. Business Rules

### 6.1 User Rules

- Rule 6.1.1: Each user must have a university account.
- Rule 6.1.2: The system stores user ID, full name, email, phone number, role, department, and account status for each user.
- Rule 6.1.3: A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager.

### 6.2 Space and Facility Rules

- Rule 6.2.1: The School manages many bookable spaces.
- Rule 6.2.2: For each space, the system stores a unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy.
- Rule 6.2.3: A space may be available, in use, under maintenance, temporarily closed, or retired.
- Rule 6.2.4: Each space may have several facilities, and the system stores the list of facilities available in each space.

### 6.3 Booking Request Rules

- Rule 6.3.1: Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants.
- Rule 6.3.2: A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event.
- Rule 6.3.3: Each booking request has a status such as pending, approved, rejected, cancelled, checked in, completed, or no-show.
- Rule 6.3.4: The system must prevent conflicting bookings.
- Rule 6.3.5: The same space cannot have two approved bookings with overlapping time periods.
- Rule 6.3.6: A space that is under maintenance, closed, or retired cannot be booked.

### 6.4 Approval Rules

- Rule 6.4.1: A booking request may require approval from a facility staff member or manager.
- Rule 6.4.2: When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note.
- Rule 6.4.3: If the booking is rejected, the rejection reason should be stored.

### 6.5 Usage Session Rules

- Rule 6.5.1: When the requester arrives, facility staff can check in the booking.
- Rule 6.5.2: At check-in, the system records the actual start time, the person who checked in the booking, and the initial condition of the space.
- Rule 6.5.3: When the session ends, facility staff can complete the booking by recording the actual end time, the final condition of the space, and any usage notes.

### 6.6 Maintenance Rules

- Rule 6.6.1: The system supports basic maintenance management.
- Rule 6.6.2: A space may have maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems.
- Rule 6.6.3: Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note.
- Rule 6.6.4: A space under maintenance cannot be booked.

### 6.7 History and Viewing Rules

- Rule 6.7.1: The system should keep historical records of bookings and maintenance activities.
- Rule 6.7.2: Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings.

## 7. State Transitions

### 7.1 Booking Request Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Pending | Approved | A booking that requires approval is approved by a facility staff member or manager. |
| Pending | Rejected | A booking that requires approval is rejected by a facility staff member or manager. |
| Approved | Checked in | The requester arrives and facility staff check in the booking. |
| Checked in | Completed | The session ends and facility staff complete the booking. |

### 7.2 Maintenance Record Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Not specified | Not specified | Layer B states that maintenance records have a status, start time, completion time, and result note, but does not specify status values or exact transitions. |

## 8. Role Permissions

| Action | Allowed Role(s) per source text | Source basis |
|---|---|---|
| Submit booking request | Users: student, lecturer, teaching assistant, facility staff, department administrator, facility manager | Layer B says users can submit booking requests and lists these possible user roles. |
| Approve / reject booking | Facility staff member or facility manager | Layer B says a booking request may require approval from a facility staff member or manager. |
| Check in booking | Facility staff | Layer B says facility staff can check in the booking when the requester arrives. |
| Complete usage session | Facility staff | Layer B says facility staff can complete the booking when the session ends. |
| Report maintenance issue | Reporter not restricted by role in Layer B | Layer B says each maintenance record stores the reporter, but does not specify which roles may report. |
| Assign maintenance staff | Not specified in Layer B | Layer B says each maintenance record stores an assigned staff member, but does not state which role performs assignment. |
| View booking history, upcoming bookings, spaces under maintenance, and no-show bookings | Staff | Layer B says staff should be able to view these items. |

## 9. Workflow Narratives

### 9.1 Booking Lifecycle (request -> approval -> check-in -> completion)

A user submits a booking request by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants, per Rule 6.3.1. The system records the booking type and status, per Rules 6.3.2 and 6.3.3, and must prevent conflicting approved bookings and bookings for spaces that are under maintenance, closed, or retired, per Rules 6.3.4, 6.3.5, and 6.3.6. If the booking requires approval, a facility staff member or manager approves or rejects it and the system records the decision details, per Rules 6.4.1, 6.4.2, and 6.4.3. When the requester arrives, facility staff check in the booking and record actual start details, per Rules 6.5.1 and 6.5.2; when the session ends, facility staff complete the booking and record actual end details, per Rule 6.5.3.

### 9.2 Maintenance Lifecycle (report -> assignment -> resolution)

The system supports maintenance records for space problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems, per Rules 6.6.1 and 6.6.2. Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note, per Rule 6.6.3. While a space is under maintenance, it cannot be booked, per Rule 6.6.4. Layer B does not specify who creates maintenance records, who assigns staff members, the allowed maintenance statuses, or the exact transition from start to completion.

## 10. Cross-Entity Constraints

- Booking Request and Space: The same space cannot have two approved bookings with overlapping time periods. The grounded direction is from approved Booking Requests to availability conflict prevention for the related Space.
- Booking Request and Space: A space that is under maintenance, closed, or retired cannot be booked. The grounded direction is from Space current status to whether a Booking Request may be made for that Space.
- Maintenance Record and Space: A space under maintenance cannot be booked. Layer B also says spaces have a current status and maintenance records have statuses, but it does not specify whether an active Maintenance Record automatically changes the Space current status to under maintenance or whether the Space status is managed separately.
- Booking Request and Approval Decision: If a booking is approved or rejected, the system records the staff member who made the decision, the decision time, decision note, and rejection reason when rejected. The grounded direction is from an approval/rejection event to an Approval Decision record linked to the Booking Request.
- Booking Request and Usage Session: Check-in and completion create actual usage details for the related Booking Request. The grounded direction is from check-in and completion actions to recorded Usage Session details.

## 11. Traceability Matrix

| Requirement Area | Source Requirement | Related Entities | Related Relationships | Related Business Rules |
|---|---|---|---|---|
| User management | Each user must have a university account and the system stores user ID, full name, email, phone number, role, department, and account status. | User | User submits Booking Request; Approval Decision is made by User; Usage Session checked in by User; Usage Session completed by User; Maintenance Record reported by User; Maintenance Record assigned to User | Rules 6.1.1, 6.1.2, 6.1.3 |
| Space management | The School manages many bookable spaces and stores unique space code, name, type, building, floor, room number, capacity, current status, and usage policy. | Space | Booking Request selects Space; Space has Facility; Space has Maintenance Record | Rules 6.2.1, 6.2.2, 6.2.3 |
| Facility listing | Each space may have several facilities and the system stores the list of facilities available in each space. | Space, Facility | Space has Facility | Rule 6.2.4 |
| Booking submission | Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants. | User, Space, Booking Request | User submits Booking Request; Booking Request selects Space | Rules 6.3.1, 6.3.2, 6.3.3 |
| Booking conflict prevention | The system must prevent conflicting bookings; the same space cannot have two approved bookings with overlapping time periods. | Space, Booking Request | Booking Request selects Space | Rules 6.3.4, 6.3.5 |
| Unavailable space prevention | A space that is under maintenance, closed, or retired cannot be booked; a space under maintenance cannot be booked. | Space, Booking Request, Maintenance Record | Booking Request selects Space; Space has Maintenance Record | Rules 6.3.6, 6.6.4 |
| Booking approval | A booking may require approval from a facility staff member or manager, and approval/rejection records the decision maker, time, note, and rejection reason if rejected. | Booking Request, Approval Decision, User | Booking Request has Approval Decision; Approval Decision is made by User | Rules 6.4.1, 6.4.2, 6.4.3 |
| Usage session | Facility staff can check in a booking and later complete it, recording actual start/end details and condition/usage notes. | Booking Request, Usage Session, User | Booking Request has Usage Session; Usage Session checked in by User; Usage Session completed by User | Rules 6.5.1, 6.5.2, 6.5.3 |
| Maintenance management | A space may have maintenance records for listed problem examples, and each record stores related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note. | Space, Maintenance Record, User | Space has Maintenance Record; Maintenance Record reported by User; Maintenance Record assigned to User | Rules 6.6.1, 6.6.2, 6.6.3 |
| History and staff views | The system keeps historical records of bookings and maintenance activities, and staff can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings. | Booking Request, Maintenance Record, Space, User | User submits Booking Request; Space has Maintenance Record | Rules 6.7.1, 6.7.2 |

## 12. Assumptions

- The requested file `req/business-requirement.md` exists and was used as the actual input file; no filename discrepancy was found in `req/`.
- Layer A is treated as lines 1-7 of the source document, and Layer B is treated as the Facility Manager requirement summary starting at line 8.
- The word "manager" in the approval requirement is treated as the facility manager role because Layer B lists "facility manager" as a user role and the requirement summary is provided by the Facility Manager.
- Department administrators are listed as actors because Layer B lists them as a possible user role; their definite interaction is limited to actions available to users unless Layer B gives a more specific responsibility.
- The Usage Session entity separates check-in and completion details so that actual start, initial condition, actual end, final condition, and usage notes are not duplicated on the Booking Request.
- The Approval Decision entity owns the rejection reason because the source describes the rejection reason as part of the approval/rejection decision event.

## 13. Open Questions

- Layer A mentions checking whether the requester is allowed to use a room and whether special equipment is needed, but Layer B does not state automated eligibility or equipment-checking rules. Should the new system enforce requester eligibility or special-equipment requirements?
- Layer B lists `cancelled` as a booking status, but does not state who can cancel a booking, from which statuses cancellation is allowed, or what cancellation details should be stored.
- Layer B lists `no-show` as a booking status and says staff can view no-show bookings, but does not state when or by whom a booking becomes no-show.
- Layer B says a booking request may require approval, but does not specify which booking types, spaces, roles, or conditions require approval.
- Layer B says spaces have a usage policy, but does not specify how usage policy is enforced.
- Layer B says staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings, but does not clarify whether all staff roles have the same viewing scope.
- Layer B says each maintenance record has a status, but does not list the allowed maintenance status values or exact maintenance state transitions.
- Layer B says each maintenance record stores a reporter and assigned staff member, but does not specify which roles may report maintenance issues or assign maintenance staff.
- Layer B does not specify whether creating or activating a Maintenance Record automatically changes the related Space current status to under maintenance, or whether Space current status is updated separately.
- Layer B refers to spaces that are "closed" in the booking prohibition, while the listed Space status value is "temporarily closed". Should these be treated as the same status label?
