# Business Requirement Analysis - Group 03

## 1. Source Documents

- Requested input: `req/business-requirement.md`
- Actual input used: `req/business-requirement.md`
- Target system: Campus Space Management System

## 2. Business Context

The School of Computer Science manages shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. Requests are currently handled manually through email, phone, or in-person contact with the school office or facility staff. As activities increase, the manual process has become difficult to manage, and the School wants a database system for space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization. Layer B begins at: “The Facility Manager provides the following requirement summary.”

## 3. System Actors

| Actor | Group | Description | Main Responsibilities / Interactions |
|---|---|---|---|
| Student | Requesters | A student user role named in Layer B. | Submit booking requests in the student user role. |
| Lecturer | Requesters | A lecturer user role named in Layer B. | Submit booking requests in the lecturer user role. |
| Teaching Assistant | Requesters | A teaching assistant user role named in Layer B. | Submit booking requests in the teaching-assistant user role. |
| Facility Staff | Requesters / Operators | A user role named in Layer B; also performs facility operations. | Submit booking requests as a user role; approve or reject booking requests when approval is required; check in bookings; complete bookings; be assigned to maintenance records; view booking history, upcoming bookings, spaces under maintenance, and no-show bookings. |
| Department Administrator | Requesters | A department administrator user role named in Layer B. | Submit booking requests in the department-administrator user role. |
| Facility Manager | Requesters / Operators | A user role named in Layer B; also performs approval operations. | Submit booking requests as a user role; approve or reject booking requests when approval is required. |

## 4. Main Entities and Attributes

### 4.1 User

A university account holder whose basic information and role are stored by the system.

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
- Teaching Assistant
- Facility Staff
- Department Administrator
- Facility Manager

### 4.2 Space

A bookable shared campus space managed by the School.

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

A facility type that can be available in one or more spaces.

Attributes:

- Facility ID [proposed identifier — not stated in source]
- Facility name

Example facility names from the source:

- Projector
- Whiteboard
- Microphone
- Computer
- Livestreaming equipment
- Air conditioner

### 4.4 Booking Request

A user-submitted request to use a selected space for a requested time period and purpose.

Attributes:

- Booking ID [proposed identifier — not stated in source]
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

The recorded approval or rejection decision for a booking request that requires approval.

Attributes:

- Approval Decision ID [proposed identifier — not stated in source]
- Decision time
- Decision note
- Rejection reason

### 4.6 Usage Session

The recorded actual use of a booking from check-in through completion.

Attributes:

- Usage Session ID [proposed identifier — not stated in source]
- Actual start time
- Initial condition of the space
- Actual end time
- Final condition of the space
- Usage notes

### 4.7 Maintenance Record

A record of a maintenance problem and its handling for a space.

Attributes:

- Maintenance Record ID [proposed identifier — not stated in source]
- Problem description
- Start time
- Completion time
- Status
- Result note

## 5. Relationships and Cardinalities

| Relationship | Cardinality | Description |
|---|---:|---|
| User submits Booking Request | User 1 : many Booking Requests | Layer B says users can submit booking requests; one user can submit multiple requests, while each request is submitted by one requester. |
| Booking Request selects Space | Space 1 : many Booking Requests | Layer B says users submit booking requests by selecting a space; one space can be selected by many booking requests over time, while each request selects one space. |
| Space has Facility | many Spaces : many Facilities | Layer B says each space may have several facilities and lists facility types; it does not state that a facility type is unique to one space, so the relationship is many-to-many. |
| Booking Request has Approval Decision | Booking Request 1 : zero or one Approval Decision | Layer B says a booking request may require approval and records details when it is approved or rejected, so a request may have no decision or one recorded decision. |
| User makes Approval Decision | User 1 : many Approval Decisions | Layer B says the system records the staff member who made the approval or rejection decision; one staff member can make many decisions, while each decision is made by one staff member. |
| Booking Request has Usage Session | Booking Request 1 : zero or one Usage Session | Layer B describes check-in and completion for the booking when the requester arrives and when the session ends; a booking may not yet have reached that stage, and one booking corresponds to one actual usage session. |
| User checks in Usage Session | User 1 : many Usage Sessions | Layer B says facility staff can check in the booking and the system records the person who checked in; one facility staff user can check in many sessions, while each check-in has one recorded person. |
| User completes Usage Session | User 1 : many Usage Sessions | Layer B says facility staff can complete the booking and this completion occurs at session end; it is modeled separately from check-in because it is a distinct action that may occur at a different time. |
| Space has Maintenance Record | Space 1 : many Maintenance Records | Layer B says a space may have maintenance records, so one space can have many records, while each maintenance record is for one related space. |
| User reports Maintenance Record | User 1 : many Maintenance Records | Layer B says each maintenance record stores the reporter; one user can report many records, while each record has one reporter. |
| User is assigned to Maintenance Record | User 1 : many Maintenance Records | Layer B says each maintenance record stores the assigned staff member; one staff member can be assigned to many records, while each record has one assigned staff member. |

## 6. Business Rules

### 6.1 User and Space Rules

- BR-1: Each user must have a university account.
- BR-2: The system stores user ID, full name, email, phone number, role, department, and account status for each user.
- BR-3: For each space, the system stores a unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy.
- BR-4: The system stores the list of facilities available in each space.

### 6.2 Booking Rules

- BR-5: Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants.
- BR-6: A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event.
- BR-7: Each booking request has a status such as pending, approved, rejected, cancelled, checked in, completed, or no-show.
- BR-8: The system must prevent conflicting bookings.
- BR-9: The same space cannot have two approved bookings with overlapping time periods.
- BR-10: A space that is under maintenance, temporarily closed, or retired cannot be booked.

### 6.3 Approval Decision Rules

- BR-11: A booking request may require approval from a facility staff member or manager.
- BR-12: When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note.
- BR-13: If the booking is rejected, the rejection reason should be stored.

### 6.4 Usage Session Rules

- BR-14: When the requester arrives, facility staff can check in the booking.
- BR-15: At check-in, the system records the actual start time, the person who checked in the booking, and the initial condition of the space.
- BR-16: When the session ends, facility staff can complete the booking.
- BR-17: At completion, the system records the actual end time, the final condition of the space, and any usage notes.

### 6.5 Maintenance and History Rules

- BR-18: A space may have maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems.
- BR-19: Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note.
- BR-20: A space under maintenance cannot be booked.
- BR-21: The system should keep historical records of bookings and maintenance activities.
- BR-22: Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings.

## 7. State Transitions

### 7.1 Booking Request Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Pending | Approved | A booking request that requires approval is approved by a facility staff member or manager. |
| Pending | Rejected | A booking request that requires approval is rejected by a facility staff member or manager. |
| Approved | Checked in | When the requester arrives, facility staff check in the booking. |
| Checked in | Completed | When the session ends, facility staff complete the booking. |

### 7.2 Maintenance Record Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Not specified in Layer B | Not specified in Layer B | Layer B states that maintenance records store status, start time, and completion time, but it does not define status values or allowed transitions. |

## 8. Role Permissions

| Action | Allowed Role(s) per source text | Source basis |
|---|---|---|
| Submit booking request | User roles: student, lecturer, teaching assistant, facility staff, department administrator, facility manager | Layer B says users can submit booking requests and lists these user roles. |
| Approve booking | Facility Staff; Facility Manager | Layer B says a booking request may require approval from a facility staff member or manager. |
| Reject booking | Facility Staff; Facility Manager | Layer B says that when a booking is approved or rejected, the decision staff member, time, note, and rejection reason are recorded. |
| Check in booking | Facility Staff | Layer B says facility staff can check in the booking when the requester arrives. |
| Complete usage session | Facility Staff | Layer B says facility staff can complete the booking when the session ends. |
| Report maintenance issue | Not specified in Layer B | Layer B says each maintenance record stores the reporter, but it does not state which role may report maintenance issues. |
| Assign maintenance staff | Not specified in Layer B | Layer B says each maintenance record stores the assigned staff member, but it does not state who assigns that staff member. |
| View booking history | Staff [interpreted as Facility Staff; see Assumptions] | Layer B says staff should be able to view booking history. |
| View upcoming bookings | Staff [interpreted as Facility Staff; see Assumptions] | Layer B says staff should be able to view upcoming bookings. |
| View spaces under maintenance | Staff [interpreted as Facility Staff; see Assumptions] | Layer B says staff should be able to view spaces under maintenance. |
| View no-show bookings | Staff [interpreted as Facility Staff; see Assumptions] | Layer B says staff should be able to view no-show bookings. |

## 9. Workflow Narratives

### 9.1 Booking Lifecycle (request → approval → check-in → completion)

A user submits a booking request by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants, per BR-5. The system keeps a booking status for the request, per BR-7, and prevents conflicting or unavailable-space bookings, per BR-8, BR-9, and BR-10. If approval is required, a facility staff member or facility manager approves or rejects the request, and the decision details are recorded, per BR-11, BR-12, and BR-13. When the requester arrives, facility staff check in the booking and record the actual start time, checker, and initial condition, per BR-14 and BR-15. When the session ends, facility staff complete the booking and record the actual end time, final condition, and usage notes, per BR-16 and BR-17.

### 9.2 Maintenance Lifecycle (report → assignment → resolution)

The system supports maintenance records for space problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems, per BR-18. Each maintenance record stores its related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note, per BR-19. A space under maintenance cannot be booked, per BR-20. The source does not specify which role reports maintenance issues, which role assigns staff members, or the maintenance status transition sequence.

## 10. Cross-Entity Constraints

- Booking Request and Space: A space that is under maintenance, temporarily closed, or retired cannot be booked; Layer B directly states this unavailable-space rule.
- Booking Request and Space: The same space cannot have two approved bookings with overlapping time periods; Layer B directly states this conflict rule for approved bookings.
- Maintenance Record and Space: Layer B states that a space under maintenance cannot be booked, but it does not explicitly state whether an active maintenance record automatically changes the related space's current status to under maintenance; the direction of this dependency remains an open question.
- Approval Decision and Booking Request: Layer B states that approval or rejection records the staff member, decision time, decision note, and rejection reason when applicable; it does not specify whether every status change to approved or rejected must have exactly one approval decision record.

## 11. Traceability Matrix

| Requirement Area | Source Requirement | Related Entities | Related Relationships | Related Business Rules |
|---|---|---|---|---|
| User management | “Each user must have a university account” and the system stores basic user information and role. | User | User submits Booking Request; User makes Approval Decision; User checks in Usage Session; User completes Usage Session; User reports Maintenance Record; User is assigned to Maintenance Record | BR-1, BR-2 |
| Space management | The School manages many bookable spaces and stores space code, name, type, location, capacity, status, and usage policy. | Space | Booking Request selects Space; Space has Maintenance Record | BR-3 |
| Space facilities | Each space may have several facilities and the system stores the list available in each space. | Space, Facility | Space has Facility | BR-4 |
| Booking submission | Users submit booking requests by selecting a space, time range, purpose, and expected participants. | User, Booking Request, Space | User submits Booking Request; Booking Request selects Space | BR-5, BR-6, BR-7 |
| Booking conflict prevention | The system prevents conflicting bookings and disallows overlapping approved bookings for the same space. | Booking Request, Space | Booking Request selects Space | BR-8, BR-9 |
| Unavailable-space prevention | A space under maintenance, temporarily closed, or retired cannot be booked. | Space, Booking Request, Maintenance Record | Booking Request selects Space; Space has Maintenance Record | BR-10, BR-20 |
| Approval handling | A booking may require approval from facility staff or manager and decision details are recorded. | Booking Request, Approval Decision, User | Booking Request has Approval Decision; User makes Approval Decision | BR-11, BR-12, BR-13 |
| Usage session handling | Facility staff check in and complete bookings and record actual times, conditions, and notes. | Booking Request, Usage Session, User | Booking Request has Usage Session; User checks in Usage Session; User completes Usage Session | BR-14, BR-15, BR-16, BR-17 |
| Maintenance management | The system supports maintenance records with space, reporter, assigned staff, problem, timing, status, and result note. | Maintenance Record, Space, User | Space has Maintenance Record; User reports Maintenance Record; User is assigned to Maintenance Record | BR-18, BR-19 |
| History and staff views | The system keeps booking and maintenance history, and staff can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings. | Booking Request, Maintenance Record, Space, User | Space has Maintenance Record; Booking Request selects Space | BR-21, BR-22 |

## 12. Assumptions

- Assumption: `Facility ID` is a proposed identifier for Facility because Layer B lists facility examples and says to store the list of facilities available in each space, but does not name a facility identifier.
- Assumption: `Booking ID` is a proposed identifier for Booking Request because Layer B describes booking requests but does not name a booking identifier.
- Assumption: `Approval Decision ID` is a proposed identifier for Approval Decision because Layer B describes recorded approval or rejection details but does not name a decision identifier.
- Assumption: `Usage Session ID` is a proposed identifier for Usage Session because Layer B describes check-in and completion records but does not name a usage-session identifier.
- Assumption: `Maintenance Record ID` is a proposed identifier for Maintenance Record because Layer B describes maintenance records but does not name a maintenance-record identifier.
- Assumption: Approval Decision is modeled as a separate entity because Layer B records decision-specific facts: decision maker, decision time, decision note, and rejection reason.
- Assumption: Usage Session is modeled as a separate entity because Layer B records actual usage facts at check-in and completion that are distinct from the requested booking facts.
- Assumption: `Decision note` and `rejection reason` are retained as distinct Approval Decision attributes because Layer B names both; rejection reason applies when the booking is rejected.
- Assumption: The generic word “Staff” in the staff-view requirement is interpreted as Facility Staff because Layer B lists Facility Staff as a user role and does not list a separate generic Staff role.

## 13. Open Questions

- Layer A mentions checking whether a requester is allowed to use a room; should the new system enforce requester eligibility, or was this only part of the old manual process?
- Layer A mentions checking whether special equipment is needed; should the new system record or validate requested equipment needs, or only store facilities available in each space as stated in Layer B?
- Layer B stores a space usage policy, but does not say how it is enforced; should booking requests be validated against usage policy?
- What action and role create the `cancelled` booking status, and from which statuses can cancellation occur?
- What action and role create the `no-show` booking status, and from which status can a booking become no-show?
- Can a booking move from pending directly to checked in if approval is not required, or does every checked-in booking first become approved?
- Which user roles are allowed to report maintenance issues?
- Which user roles are allowed to assign maintenance staff members?
- What maintenance status values are allowed, and what transitions are permitted from start time to completion time?
- Does creating an active maintenance record automatically set the related space status to under maintenance, or is the space status managed separately?
- Does every approved or rejected booking require exactly one Approval Decision record, including bookings that do not require approval?
