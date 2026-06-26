# Business Requirement Analysis - Group 03

## 1. Source Documents

- Requested input: `req/business-requirement.md`
- Actual input used: `req/business-requirement.md`
- Target system: Campus Space Management System

## 2. Business Context

The School of Computer Science manages shared physical spaces for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. Requests are currently handled manually through the school office or facility staff, and facility staff check spreadsheets or shared calendars for availability, requester eligibility, special equipment needs, and maintenance status. As classes, projects, workshops, seminars, and academic events increase, the School wants a database system for space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization.

## 3. System Actors

| Actor | Description | Main Responsibilities / Interactions |
|---|---|---|
| Student | A user role listed in the Facility Manager requirement summary. | Can submit booking requests as a system user; has Student stored as the user's role value. |
| Lecturer | A user role listed in the Facility Manager requirement summary. | Can submit booking requests as a system user; has Lecturer stored as the user's role value. |
| Teaching Assistant | A user role listed in the Facility Manager requirement summary. | Can submit booking requests as a system user; has Teaching Assistant stored as the user's role value. |
| Facility Staff | A user role listed in the Facility Manager requirement summary. | Can submit booking requests as a system user; may approve or reject booking requests; can check in bookings; can complete bookings; may be recorded as staff involved in maintenance management. |
| Department Administrator | A user role listed in the Facility Manager requirement summary. | Can submit booking requests as a system user; has Department Administrator stored as the user's role value. |
| Facility Manager | A user role listed in the Facility Manager requirement summary and the stakeholder providing the authoritative requirement summary. | Can submit booking requests as a system user; may approve or reject booking requests; is concerned with managing shared campus spaces fairly, avoiding overlapping bookings, preventing unavailable-space use, and preserving usage history. |

## 4. Main Entities and Attributes

### 4.1 User

A person with a university account whose basic information is stored by the system.

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

A facility type available in one or more spaces, such as the examples listed in the source.

Attributes:

- Facility ID [proposed identifier — not stated in source]
- Facility name

Possible facility names include:

- Projector
- Whiteboard
- Microphone
- Computer
- Livestreaming equipment
- Air conditioner

### 4.4 Booking Request

A request submitted by a user to use a selected space for a requested time period and purpose.

Attributes:

- Booking ID [proposed identifier — not stated in source]
- Requested start time
- Requested end time
- Purpose of use
- Expected number of participants
- Booking status

Possible purpose of use values:

- Lecture
- Examination
- Seminar
- Workshop
- Meeting
- Student activity
- Administrative event

Possible booking statuses:

- Pending
- Approved
- Rejected
- Cancelled
- Checked in
- Completed
- No-show

### 4.5 Approval Decision

The record created when a booking request is approved or rejected.

Attributes:

- Approval Decision ID [proposed identifier — not stated in source]
- Decision outcome [proposed — derived from the source's “approved or rejected” conditional, not stated as a separately stored fact]
- Decision time
- Decision note
- Rejection reason

Possible decision outcomes:

- Approved
- Rejected

### 4.6 Usage Session

The usage record for a booking after facility staff check in the requester and later complete the booking.

Attributes:

- Usage Session ID [proposed identifier — not stated in source]
- Actual start time
- Initial condition of the space
- Actual end time
- Final condition of the space
- Usage notes

### 4.7 Maintenance Record

A record of a maintenance problem or activity for a space.

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
| User submits Booking Request | 1:M | The source says users can submit booking requests, so one user may submit many booking requests, while each booking request is submitted by a user. |
| Booking Request selects Space | M:1 | The source says users submit booking requests by selecting a space, so many booking requests may select the same space, while each booking request selects one space. |
| Space has Facility | M:N | The source says each space may have several facilities and does not state that a facility type is unique to one space, so a space can have many facilities and a facility type can be available in many spaces. |
| Booking Request has Approval Decision | 1:0..1 | The source says a booking request may require approval and records a decision when approved or rejected, so a booking request can have no decision yet or one recorded approval/rejection decision. |
| User makes Approval Decision | 1:M | The source says the system records the staff member who made the approval or rejection decision, so one staff user may make many decisions, while each decision records one decision maker. |
| Booking Request has Usage Session | 1:0..1 | The source describes check-in and completion details for a booking when the requester arrives and when the session ends, so a booking may have no usage session yet or one usage session record. |
| User checks in Usage Session | 1:M | The source says facility staff can check in the booking and the system records the person who checked in the booking, so one staff user may check in many sessions, while each checked-in session records one check-in person. |
| User completes Usage Session | 1:M | The source separately says facility staff can complete the booking and records completion details, so one staff user may complete many sessions, while each completed session records the completion action separately from check-in. |
| Space has Maintenance Record | 1:M | The source says a space may have maintenance records, so one space may have many maintenance records, while each maintenance record relates to one space. |
| User reports Maintenance Record | 1:M | The source says each maintenance record stores the reporter, so one user may report many maintenance records, while each maintenance record has one reporter. |
| User is assigned to Maintenance Record | 1:M | The source says each maintenance record stores the assigned staff member, so one staff user may be assigned to many maintenance records, while each maintenance record has one assigned staff member. |

## 6. Business Rules

### 6.1 User Rules

- BR-01: Each user must have a university account, based on the Facility Manager summary statement that “Each user must have a university account.”
- BR-02: The system stores user ID, full name, email, phone number, role, department, and account status for each user, based on the Facility Manager summary user-information sentence.
- BR-03: A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager, based on the Facility Manager summary role list.

### 6.2 Space and Facility Rules

- BR-04: The School manages many bookable spaces, based on the Facility Manager summary space-management sentence.
- BR-05: For each space, the system stores unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy, based on the Facility Manager summary space-attribute sentence.
- BR-06: A space may be available, in use, under maintenance, temporarily closed, or retired, based on the Facility Manager summary space-status sentence.
- BR-07: Each space may have several facilities, and the system stores the list of facilities available in each space, based on the Facility Manager summary facilities sentence.

### 6.3 Booking Request Rules

- BR-08: Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants, based on the Facility Manager summary booking-submission sentence.
- BR-09: A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event, based on the Facility Manager summary booking-purpose sentence.
- BR-10: Each booking request has a status such as pending, approved, rejected, cancelled, checked in, completed, or no-show, based on the Facility Manager summary booking-status sentence.
- BR-11: The system must prevent conflicting bookings, based on the Facility Manager summary conflict-prevention sentence.
- BR-12: The same space cannot have two approved bookings with overlapping time periods, based on the Facility Manager summary approved-overlap sentence.
- BR-13: A space that is under maintenance, temporarily closed, or retired cannot be booked, based on the Facility Manager summary unavailable-space sentence.

### 6.4 Approval Rules

- BR-14: A booking request may require approval from a facility staff member or manager, based on the Facility Manager summary approval-requirement sentence.
- BR-15: When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note, based on the Facility Manager summary decision-recording sentence.
- BR-16: If the booking is rejected, the rejection reason should be stored, based on the Facility Manager summary rejection-reason sentence.

### 6.5 Usage Session Rules

- BR-17: When the requester arrives, facility staff can check in the booking, based on the Facility Manager summary check-in sentence.
- BR-18: During check-in, the system records the actual start time, the person who checked in the booking, and the initial condition of the space, based on the Facility Manager summary check-in recording sentence.
- BR-19: When the session ends, facility staff can complete the booking by recording the actual end time, final condition of the space, and any usage notes, based on the Facility Manager summary completion sentence.

### 6.6 Maintenance and History Rules

- BR-20: The system supports basic maintenance management for spaces, based on the Facility Manager summary maintenance-management sentence.
- BR-21: A space may have maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems, based on the Facility Manager summary maintenance-problem examples.
- BR-22: Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note, based on the Facility Manager summary maintenance-record sentence.
- BR-23: A space under maintenance cannot be booked, based on the Facility Manager summary maintenance-booking sentence.
- BR-24: The system should keep historical records of bookings and maintenance activities, based on the Facility Manager summary history sentence.
- BR-25: Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings, based on the Facility Manager summary staff-view sentence.

## 7. State Transitions

> List only transitions clearly implied by Layer B. Status values whose transition trigger/role the source does not state — e.g. `Cancelled` and `No-show` — stay in the allowed-values list but are NOT asserted as transitions here; carry their missing trigger/role as scoped Open Questions (application/backend-layer), and note that this is intentional, not a data-modeling gap.

### 7.1 Booking Request Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Pending | Approved | A booking is approved and the system records the staff decision, decision time, and decision note per BR-15. |
| Pending | Rejected | A booking is rejected and the system records the staff decision, decision time, decision note, and rejection reason per BR-15 and BR-16. |
| Approved | Checked in | The requester arrives and facility staff check in the booking per BR-17 and BR-18. |
| Checked in | Completed | The session ends and facility staff complete the booking per BR-19. |

Cancelled and no-show are allowed booking status values in BR-10, but their triggers, responsible roles, and prior statuses are not stated in Layer B; these transitions are intentionally left as Open Questions rather than asserted here.

### 7.2 Maintenance Record Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Not specified in source | Not specified in source | Layer B states that each maintenance record stores a status, start time, completion time, and result note, but it does not list maintenance status values or definite status transitions. |

## 8. Role Permissions

| Action | Allowed Role(s) per source text | Source basis |
|---|---|---|
| Submit booking request | User roles: Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager | Layer B says users can submit booking requests, and lists these possible user roles. |
| Approve / reject booking | Facility Staff, Facility Manager | Layer B says a booking request may require approval from a facility staff member or manager and records the staff member who made the decision. |
| Check in booking | Facility Staff | Layer B says facility staff can check in the booking. |
| Complete usage session | Facility Staff | Layer B says facility staff can complete the booking when the session ends. |
| Report maintenance issue | Not fully specified; reporter is stored | Layer B says each maintenance record stores the reporter but does not state which roles may report. |
| Assign maintenance staff | Not fully specified; assigned staff member is stored | Layer B says each maintenance record stores the assigned staff member but does not state who performs assignment. |
| View booking history, upcoming bookings, spaces under maintenance, and no-show bookings | Staff | Layer B says staff should be able to view these items, but it does not define whether “staff” means facility staff only or a broader set of staff roles. |

## 9. Workflow Narratives

### 9.1 Booking Lifecycle (request → approval → check-in → completion)

A user submits a booking request by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants per BR-08. The booking request carries one of the stated status values per BR-10, and the system must prevent conflicting bookings and approved overlaps for the same space per BR-11 and BR-12. If approval is required, a facility staff member or facility manager approves or rejects the booking per BR-14; the decision record stores the decision maker, time, note, and rejection reason when rejected per BR-15 and BR-16. When the requester arrives for an approved booking, facility staff check in the booking and record actual start time, check-in person, and initial space condition per BR-17 and BR-18. When the session ends, facility staff complete the booking by recording actual end time, final space condition, and usage notes per BR-19.

### 9.2 Maintenance Lifecycle (report → assignment → resolution)

The system supports maintenance management for spaces per BR-20, and a space may have maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems per BR-21. Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note per BR-22. A space under maintenance cannot be booked per BR-23. Layer B does not specify maintenance status values, assignment workflow, or exact resolution transitions, so those workflow details are listed as Open Questions rather than asserted as rules.

## 10. Cross-Entity Constraints

- The same Space cannot have two approved Booking Requests with overlapping time periods; the direction grounded in Layer B is from approved booking time periods for the same space to conflict prevention, per BR-11 and BR-12.
- A Space whose current status is under maintenance, temporarily closed, or retired cannot be booked; the direction grounded in Layer B is from Space current status to Booking Request eligibility, per BR-13 and BR-23.
- Booking and maintenance history must be preserved; the direction grounded in Layer B is that Booking Request, Usage Session, Approval Decision, and Maintenance Record facts support historical records, per BR-24.
- The source mentions both Space current status “under maintenance” and Maintenance Record status, but it does not state whether creating or updating a Maintenance Record automatically changes Space current status; that causality is not asserted here and is listed in Open Questions.

## 11. Traceability Matrix

| Requirement Area | Source Requirement | Related Entities | Related Relationships | Related Business Rules |
|---|---|---|---|---|
| User accounts and roles | Facility Manager summary: each user has a university account; user information and possible roles are stored. | User | User submits Booking Request; User makes Approval Decision; User checks in Usage Session; User completes Usage Session; User reports Maintenance Record; User is assigned to Maintenance Record | BR-01, BR-02, BR-03 |
| Space data | Facility Manager summary: the School manages many bookable spaces and stores space details, status, and usage policy. | Space | Booking Request selects Space; Space has Maintenance Record; Space has Facility | BR-04, BR-05, BR-06 |
| Facilities in spaces | Facility Manager summary: each space may have several facilities and the system stores the list available in each space. | Space, Facility | Space has Facility | BR-07 |
| Booking submission and purpose | Facility Manager summary: users submit booking requests with selected space, requested times, purpose, and expected participants; booking purposes are listed. | User, Booking Request, Space | User submits Booking Request; Booking Request selects Space | BR-08, BR-09 |
| Booking status and conflict prevention | Facility Manager summary: booking statuses are listed; conflicting bookings must be prevented; same space cannot have overlapping approved bookings; unavailable spaces cannot be booked. | Booking Request, Space | Booking Request selects Space | BR-10, BR-11, BR-12, BR-13 |
| Approval decision | Facility Manager summary: booking may require approval from facility staff or manager; approved/rejected decisions record staff member, time, note, and rejection reason if rejected. | Booking Request, Approval Decision, User | Booking Request has Approval Decision; User makes Approval Decision | BR-14, BR-15, BR-16 |
| Check-in and completion | Facility Manager summary: facility staff check in the booking and later complete it, recording actual times, conditions, people, and notes. | Booking Request, Usage Session, User | Booking Request has Usage Session; User checks in Usage Session; User completes Usage Session | BR-17, BR-18, BR-19 |
| Maintenance management | Facility Manager summary: spaces may have maintenance records storing related space, reporter, assigned staff member, problem details, timing, status, and result note; spaces under maintenance cannot be booked. | Space, Maintenance Record, User | Space has Maintenance Record; User reports Maintenance Record; User is assigned to Maintenance Record | BR-20, BR-21, BR-22, BR-23 |
| History and staff views | Facility Manager summary: system keeps historical booking and maintenance records; staff view booking history, upcoming bookings, spaces under maintenance, and no-show bookings. | Booking Request, Approval Decision, Usage Session, Maintenance Record, Space | Relationships supporting booking, usage, approval, and maintenance history | BR-24, BR-25 |

## 12. Assumptions

- Assumption: Facility ID is a proposed identifier for Facility because the source lists facilities but does not state a facility identifier.
- Assumption: Booking ID is a proposed identifier for Booking Request because the source does not state a booking identifier.
- Assumption: Approval Decision ID is a proposed identifier for Approval Decision because the source does not state a decision identifier.
- Assumption: Decision outcome is included as a derived attribute on Approval Decision because the source describes the decision event as “approved or rejected,” but does not list outcome as a separately stored fact.
- Assumption: Usage Session ID is a proposed identifier for Usage Session because the source does not state a usage-session identifier.
- Assumption: Maintenance Record ID is a proposed identifier for Maintenance Record because the source does not state a maintenance-record identifier.
- Assumption: Decision note and rejection reason are kept as distinct Approval Decision attributes because the source states both a decision note for approved/rejected bookings and a rejection reason specifically if the booking is rejected.
- Assumption: Facility is treated as a reusable facility type/name across spaces because the source says each space may have several facilities and does not state that each listed facility item is unique to exactly one space.
- Assumption: The Layer A role “staff” was not added as a separate actor because Layer B lists specific user roles and includes Facility Staff; the ambiguous scope of generic “staff” for viewing remains an Open Question.

## 13. Open Questions

- Question: How is Space usage policy enforced, if at all, during booking submission or approval? — Scope: Business Workflow
- Question: Which prior status, trigger, and actor cause a Booking Request to become Cancelled? — Scope: Business Workflow
- Question: Which prior status, trigger, and actor cause a Booking Request to become No-show? — Scope: Business Workflow
- Question: Which booking requests require approval, and can any booking bypass approval? — Scope: Business Workflow
- Question: What are the allowed status values and lifecycle transitions for Maintenance Record status? — Scope: Business Workflow
- Question: Which user roles are allowed to report maintenance issues? — Scope: Authorization
- Question: Which user roles are allowed to assign the assigned staff member on a Maintenance Record? — Scope: Authorization
- Question: Does “staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings” mean Facility Staff only, or does it include other staff roles such as Teaching Assistant, Department Administrator, or Facility Manager? — Scope: Authorization
- Question: Does creating, starting, completing, or changing a Maintenance Record automatically change the related Space current status to or from Under maintenance? — Scope: Mixed
- Question: Are booking requested start/end time ordering and maintenance start/completion time ordering required constraints, or only recorded values? — Scope: Database
- Question: Is expected number of participants only recorded, or must it be compared with Space capacity during booking or approval? — Scope: Business Workflow
- Question: What values are allowed for User account status? — Scope: Database
