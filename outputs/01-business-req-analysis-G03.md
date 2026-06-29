# Business Requirement Analysis - Group 03

## 1. Introduction

This document presents the business requirement analysis for the Campus Space Management System project. The analysis is based on `req/business-requirement.md`, especially the Facility Manager requirement summary.

## 2. Business Context

### 2.1 System Overview

The School of Computer Science manages shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. Requests are currently handled manually through the school office or facility staff by email, phone, or in person, and facility staff check spreadsheets or shared calendars. The School wants a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization as demand increases.

### 2.2 Term Definition

- Layer A: The narrative/context part of the source before “The Facility Manager provides the following requirement summary”; it describes the current manual process and why the system is needed.
- Layer B: The authoritative requirement summary beginning with “The Facility Manager provides the following requirement summary”; it is the source used for entities, attributes, relationships, business rules, and process details.
- University account: The account every user must have in the required system.
- Shared campus space / bookable space: A managed physical space such as a classroom, computer laboratory, meeting room, or auditorium.
- Facility: An item available in a space, such as a projector, whiteboard, microphone, computer, livestreaming equipment, or air conditioner.
- Booking request: A user request to use a selected space for a requested time period and purpose.
- Usage session: The actual use of a booking after facility staff check in the booking and later complete it.
- Maintenance record: A record of a space problem or maintenance activity.
- No-show: A booking request status value named in Layer B; its trigger is not defined in the source.

## 3. System Actors

| Actor | Description | Main Responsibilities / Interactions |
|---|---|---|
| Requester User Roles | Student, lecturer, teaching assistant, and department administrator are user roles listed in the Facility Manager summary. | May submit booking requests; may be a requester who arrives for a booking. |
| Facility Staff | A user role listed in the Facility Manager summary. | May submit booking requests; may approve or reject bookings when approval is required; can check in bookings; can complete bookings; is referenced as maintenance assigned staff; staff can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings. |
| Facility Manager | A user role listed in the Facility Manager summary. | May submit booking requests; may approve or reject bookings when approval is required. |

## 4. Main Entities and Attributes

### 4.1 User

A person with a university account who can interact with the system according to the role stored for that user.

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

An available item or equipment that may be listed for one or more spaces.

Attributes:

- Facility ID [proposed identifier — not stated in source]
- Facility name

Possible facility names from source examples:

- Projector
- Whiteboard
- Microphone
- Computer
- Livestreaming equipment
- Air conditioner

### 4.4 Booking Request

A request submitted by a user to use a selected space for a requested time and purpose.

Attributes:

- Booking ID [proposed identifier — not stated in source]
- Requested start time
- Requested end time
- Purpose of use
- Expected number of participants
- Status

Possible purpose of use values:

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

A record of a facility staff member or manager approving or rejecting a booking request.

Attributes:

- Approval Decision ID [proposed identifier — not stated in source]
- Decision outcome [proposed — derived from the source's “approved or rejected” conditional, not stated as a stored fact]
- Decision time
- Decision note
- Rejection reason

Possible decision outcomes:

- Approved
- Rejected

### 4.6 Usage Session

A record of the actual checked-in and completed use of a booking.

Attributes:

- Usage Session ID [proposed identifier — not stated in source]
- Actual start time
- Initial condition of the space
- Actual end time
- Final condition of the space
- Usage notes

### 4.7 Maintenance Record

A record of maintenance activity or a problem for a space.

Attributes:

- Maintenance Record ID [proposed identifier — not stated in source]
- Problem description
- Start time
- Completion time
- Status
- Result note

Problem examples stated in the source:

- Broken projectors
- Air-conditioning failure
- Damaged furniture
- Cleaning issues
- Network problems

## 5. Relationships and Cardinalities

| Relationship | Cardinality | Description |
|---|---:|---|
| User submits Booking Request | User `0..*` ↔ Booking Request `1..1` | Layer B says users can submit booking requests; the request has one requester by creation context, while one user may submit many requests because the source does not limit the maximum. |
| Booking Request selects Space | Booking Request `1..1` ↔ Space `0..*` | Layer B says users submit booking requests by selecting a space; a space may have many booking requests because no maximum is stated. |
| Space has Facility | Space `0..*` ↔ Facility `0..*` | Layer B says each space may have several facilities and the system stores the list available in each space; the source does not state a facility item is unique to one space. |
| Booking Request has Approval Decision | Booking Request `0..*` ↔ Approval Decision `1..1` | Layer B says a booking may require approval and records a decision when approved or rejected; multiple decision records are allowed because the source does not restrict one decision per booking. Each decision concerns one booking event. |
| User makes Approval Decision | User `0..*` ↔ Approval Decision `1..1` | Layer B records the staff member who made the decision and says approval may come from a facility staff member or manager; the actor per decision event is one decision maker, and one user may make many decisions. |
| Booking Request has Usage Session | Booking Request `0..1` ↔ Usage Session `1..1` | Layer B describes one check-in and completion flow for a booking. The `0..1` child maximum is an inferred singleton-by-nature restriction [proposed cardinality — not explicitly stated in source], because one usage session records one start-to-end use of one booking. |
| User checks in Usage Session | User `0..*` ↔ Usage Session `1..1` | Layer B says the system records the person who checked in the booking; check-in creates the usage session record, and one user may check in many sessions. |
| User completes Usage Session | User `0..*` ↔ Usage Session `0..1` | Layer B says facility staff can complete the booking; completion occurs after check-in, so the completing person may be absent until completion, and a single completion event has at most one completing person. |
| Space has Maintenance Record | Space `0..*` ↔ Maintenance Record `1..1` | Layer B says a space may have maintenance records and each maintenance record stores the related space; a space may have many records. |
| User reports Maintenance Record | User `0..*` ↔ Maintenance Record `1..1` | Layer B says each maintenance record stores the reporter; one reporter is recorded for a maintenance record, and one user may report many records. |
| User is assigned to Maintenance Record | User `0..*` ↔ Maintenance Record `0..1` | Layer B says each maintenance record stores the assigned staff member, but the source does not state whether assignment exists at reporting time; assignment is therefore optional until clarified, and one assigned staff member is recorded per maintenance record. |

## 6. Business Rules

### 6.1 User Rules

- BR-1: Each user must have a university account, and the system stores user ID, full name, email, phone number, role, department, and account status.
- BR-2: A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager.

### 6.2 Space and Facility Rules

- BR-3: For each space, the system stores unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy.
- BR-4: A space may be available, in use, under maintenance, temporarily closed, or retired.
- BR-5: Each space may have several facilities, and the system stores the list of facilities available in each space.

### 6.3 Booking and Approval Rules

- BR-6: Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants.
- BR-7: A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event.
- BR-8: Each booking request has a status such as pending, approved, rejected, cancelled, checked in, completed, or no-show.
- BR-9: The system must prevent conflicting bookings: the same space cannot have two approved bookings with overlapping time periods.
- BR-10: A space that is under maintenance, closed, or retired cannot be booked.
- BR-11: A booking request may require approval from a facility staff member or manager.
- BR-12: When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note.
- BR-13: If the booking is rejected, the rejection reason should be stored.

### 6.4 Usage Session Rules

- BR-14: When the requester arrives, facility staff can check in the booking.
- BR-15: At check-in, the system records the actual start time, the person who checked in the booking, and the initial condition of the space.
- BR-16: When the session ends, facility staff can complete the booking by recording actual end time, final condition of the space, and any usage notes.

### 6.5 Maintenance and History Rules

- BR-17: A space may have maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems.
- BR-18: Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note.
- BR-19: A space under maintenance cannot be booked.
- BR-20: The system should keep historical records of bookings and maintenance activities.
- BR-21: Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings.

## 7. State Transitions

> Cancelled and No-show are valid Booking Request status values from Layer B, but the source does not state their trigger, prior status, or responsible role. They are intentionally not asserted as definite transitions here and are listed in Open Questions.

### 7.1 Booking Request Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Pending | Approved | A booking request may require approval; when approved, the system records the decision details (BR-11, BR-12). |
| Pending | Rejected | A booking request may require approval; when rejected, the system records the decision details and rejection reason (BR-11, BR-12, BR-13). |
| Approved | Checked in | When the requester arrives, facility staff can check in the booking (BR-14, BR-15). |
| Checked in | Completed | When the session ends, facility staff can complete the booking (BR-16). |

### 7.2 Maintenance Record Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Not specified in source | Not specified in source | Layer B states that maintenance records have a status, start time, completion time, and result note, but it does not define allowed maintenance status values or transitions. |

## 8. Role Permissions

| Action | Allowed Role(s) per source text | Source basis |
|---|---|---|
| Submit booking request | Users; specific listed roles include student, lecturer, teaching assistant, facility staff, department administrator, and facility manager | “Users can submit booking requests...” and Layer B lists possible user roles. |
| Approve / reject booking | Facility staff member or manager | “A booking request may require approval from a facility staff member or manager.” |
| Check in booking | Facility staff | “When the requester arrives, facility staff can check in the booking.” |
| Complete usage session | Facility staff | “When the session ends, facility staff can complete the booking...” |
| Report maintenance issue | Not specified by role | Layer B states maintenance records store the reporter, but does not state which roles may report. |
| Assign maintenance staff | Not specified by role | Layer B states maintenance records store the assigned staff member, but does not state who assigns that staff member. |
| View booking history, upcoming bookings, spaces under maintenance, and no-show bookings | Staff | “Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings.” |

## 9. Workflow Narratives

### 9.1 Booking Lifecycle (request → approval → check-in → completion)

A user submits a booking request by selecting a space, requested times, purpose of use, and expected participant count (BR-6, BR-7). The request receives one of the stated booking statuses (BR-8), and approved bookings must not overlap for the same space (BR-9). If approval is required, a facility staff member or manager approves or rejects the request and the system records decision details, including a rejection reason when rejected (BR-11, BR-12, BR-13). When the requester arrives, facility staff check in the booking and record actual start and initial condition (BR-14, BR-15); when the session ends, facility staff complete the booking and record actual end, final condition, and usage notes (BR-16).

### 9.2 Maintenance Lifecycle (report → assignment → resolution)

A space may have maintenance records for stated problem examples such as broken projectors or network problems (BR-17). Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note (BR-18). While a space is under maintenance, it cannot be booked (BR-19). The source supports keeping historical maintenance records, but it does not specify maintenance status values or a detailed maintenance transition sequence (BR-20).

## 10. Cross-Entity Constraints

- The same space cannot have two approved booking requests with overlapping requested time periods; this direction is grounded in Layer B because the rule is stated for approved bookings of the same space.
- A space that is under maintenance, closed, or retired cannot be booked; Layer B directly states this booking restriction. “Closed” is treated consistently with “temporarily closed” from the stated Space status list under Assumptions.
- A space under maintenance cannot be booked; Layer B repeats this in the maintenance paragraph.
- Approval Decision and Booking Request status both involve approved/rejected outcomes, but the source does not define whether decision recording automatically changes the booking status; see Open Questions.
- Maintenance Record and Space current status both involve “under maintenance,” but Layer B does not state whether creating/updating a maintenance record automatically changes Space current status or whether Space current status controls maintenance records; see Open Questions.

## 11. Traceability Matrix

| Requirement Area | Source Requirement | Related Entities | Related Relationships | Related Business Rules |
|---|---|---|---|---|
| User management | Each user has a university account and stored user information; users have listed roles. | User | User submits Booking Request; User makes Approval Decision; User checks in Usage Session; User completes Usage Session; User reports Maintenance Record; User is assigned to Maintenance Record | BR-1, BR-2 |
| Space management | The School manages many bookable spaces and stores space details and statuses. | Space | Booking Request selects Space; Space has Maintenance Record; Space has Facility | BR-3, BR-4 |
| Facility listing | Each space may have several facilities and the system stores the list available in each space. | Space, Facility | Space has Facility | BR-5 |
| Booking submission | Users submit booking requests by selecting space, times, purpose, and expected participants. | User, Booking Request, Space | User submits Booking Request; Booking Request selects Space | BR-6, BR-7, BR-8 |
| Booking conflict prevention | Same space cannot have two approved overlapping bookings; unavailable spaces cannot be booked. | Booking Request, Space | Booking Request selects Space | BR-9, BR-10 |
| Approval decision | Booking may require approval by facility staff or manager; decision details and rejection reason are stored. | Booking Request, Approval Decision, User | Booking Request has Approval Decision; User makes Approval Decision | BR-11, BR-12, BR-13 |
| Usage session | Facility staff check in and complete bookings, recording actual times, conditions, and notes. | Booking Request, Usage Session, User | Booking Request has Usage Session; User checks in Usage Session; User completes Usage Session | BR-14, BR-15, BR-16 |
| Maintenance management | Spaces may have maintenance records with stated stored details; under-maintenance spaces cannot be booked. | Space, Maintenance Record, User | Space has Maintenance Record; User reports Maintenance Record; User is assigned to Maintenance Record | BR-17, BR-18, BR-19 |
| History and staff views | System keeps historical booking and maintenance records; staff view history, upcoming bookings, spaces under maintenance, and no-show bookings. | Booking Request, Maintenance Record, Space | Related to booking and maintenance relationships | BR-20, BR-21 |

## 12. Assumptions

- Assumption: Facility ID is a proposed identifier for Facility because the source does not state a facility identifier.
- Assumption: Booking ID is a proposed identifier for Booking Request because the source does not state a booking identifier.
- Assumption: Approval Decision ID is a proposed identifier for Approval Decision because the source does not state a decision identifier.
- Assumption: Usage Session ID is a proposed identifier for Usage Session because the source does not state a usage session identifier.
- Assumption: Maintenance Record ID is a proposed identifier for Maintenance Record because the source does not state a maintenance record identifier.
- Assumption: Decision outcome is included on Approval Decision as a derived attribute because the source names two decision outcomes, “approved or rejected,” but does not list outcome as a stored fact.
- Assumption: The Booking Request to Usage Session child maximum is resolved as `0..1` because a usage session records one indivisible start-to-end use of one booking; this is inferred from the workflow and not explicitly stated as a multiplicity in the source.
- Assumption: “Closed” in the booking restriction is treated as the same unavailable space condition as the Space status “temporarily closed,” because Layer B lists “temporarily closed” as the status value but later says a space that is “closed” cannot be booked.
- Assumption: Generic “staff” viewing permissions are not split into separate user roles because Layer B does not identify which listed staff-related roles are included beyond the word “Staff.”
- Assumption: No separate booking type or booking category attribute was created; the source-named fact is “purpose of use,” and the listed booking purposes are treated as possible purpose of use values.
- Assumption: Student, lecturer, teaching assistant, and department administrator are grouped as Requester User Roles in the actor table because Layer B gives them the same stated booking-request interaction and does not give them distinct additional responsibilities.

## 13. Open Questions

- Question: How is Space usage policy enforced, if at all, when evaluating a booking request? — Scope: Business Workflow
- Question: From which prior status can a Booking Request become Cancelled, who can set it, and under what condition? — Scope: Business Workflow
- Question: From which prior status can a Booking Request become No-show, who can set it, and under what condition? — Scope: Business Workflow
- Question: Which listed user roles are included in the generic “Staff” who can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings? — Scope: Authorization
- Question: Which roles may report maintenance issues? — Scope: Authorization
- Question: Which roles may assign the assigned staff member on a maintenance record? — Scope: Authorization
- Question: What are the allowed status values and transitions for Maintenance Record status? — Scope: Business Workflow
- Question: Does recording an Approval Decision automatically update Booking Request status, or is the status update handled separately? — Scope: Business Workflow
- Question: Does a Maintenance Record status automatically update Space current status to under maintenance, or is Space current status maintained independently? — Scope: Mixed
- Question: Are department administrators intended to have responsibilities beyond submitting booking requests as users? — Scope: Authorization
