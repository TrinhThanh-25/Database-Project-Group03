# Business Requirement Analysis - Group 03

## 1. Introduction

This document presents the business requirement analysis for the Campus Space Management System project. The analysis is based on `req/business-requirement.md`, using the narrative before “The Facility Manager provides the following requirement summary” as context and the Facility Manager requirement summary as the authoritative requirement source.

## 2. Business Context

### 2.1 System Overview

The School of Computer Science manages shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, and academic events. Current requests are handled manually through email, phone, or in-person contact, and facility staff check spreadsheets or shared calendars. The School wants a database system to manage space booking, approval, usage sessions, maintenance, incident reporting, and facility utilization as activity volume increases.

### 2.2 Term Definition

- Layer A: The narrative/context part of the source before “The Facility Manager provides the following requirement summary”; it explains the current manual process, pain points, and motivation.
- Layer B: The authoritative Facility Manager requirement summary beginning at “The Facility Manager provides the following requirement summary”; it is the source for entities, relationships, and business rules.
- Bookable space: A shared campus physical space managed by the School, such as a classroom, computer laboratory, meeting room, or auditorium.
- Booking request: A user's request to use a selected space for a requested time period and purpose.
- Usage session: The recorded use of an approved booking from check-in through completion.
- Maintenance record: A record of a space problem and its maintenance handling.
- Facility: An item available in a space, such as a projector, whiteboard, microphone, computer, livestreaming equipment, or air conditioner.

## 3. System Actors

| Actor | Description | Main Responsibilities / Interactions |
|---|---|---|
| Booking requester roles: student, lecturer, teaching assistant, department administrator | User roles listed in Layer B as possible university account roles. | Can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants. |
| Facility staff | User role listed in Layer B. | Can approve or reject booking requests when approval is required, check in bookings, complete bookings, and be recorded as assigned staff on maintenance records. |
| Facility manager | User role listed in Layer B. | Can approve or reject booking requests when approval is required; the Facility Manager is the stakeholder who provides the requirement summary. |

## 4. Main Entities and Attributes

### 4.1 USER_ACCOUNT

Represents a university account user whose basic information is stored by the system.

Attributes:

- user ID
- full name
- email
- phone number

### 4.2 DEPARTMENT

Represents the user department normalized from the source's user department attribute under a design directive.

Attributes:

- department identifier [proposed identifier — not stated in source; design directive]
- department_name [design directive — normalized from the source's user department attribute]

### 4.3 ROLE

Represents the controlled list of user role values under a design directive.

Attributes:

- role identifier [proposed identifier — not stated in source; design directive]
- role_name [design directive]

Possible role_name values:

- student
- lecturer
- teaching assistant
- facility staff
- department administrator
- facility manager

### 4.4 ACCOUNT_STATUS

Represents user account status values under a design directive.

Attributes:

- status identifier [proposed identifier — not stated in source; design directive]
- status_name [design directive]

### 4.5 SPACE

Represents a bookable shared campus space managed by the School.

Attributes:

- unique space code
- space name
- space type
- building
- floor
- room number
- capacity
- usage policy

### 4.6 SPACE_STATUS

Represents controlled space status values under a design directive.

Attributes:

- status identifier [proposed identifier — not stated in source; design directive]
- status_name [design directive]

Possible status_name values:

- available
- in use
- under maintenance
- temporarily closed
- retired

### 4.7 FACILITY

Represents a facility item that may be available in a space.

Attributes:

- facility identifier [proposed identifier — not stated in source]
- facility_name

Possible facility_name examples:

- projector
- whiteboard
- microphone
- computer
- livestreaming equipment
- air conditioner

### 4.8 BOOKING_REQUEST

Represents a user's request to use a selected space for a requested period and stated purpose.

Attributes:

- booking request identifier [proposed identifier — not stated in source]
- requested start time
- requested end time
- purpose of use
- expected number of participants

Possible purpose of use values:

- lecture
- examination
- seminar
- workshop
- meeting
- student activity
- administrative event

### 4.9 BOOKING_STATUS

Represents controlled booking request status values under a design directive.

Attributes:

- status identifier [proposed identifier — not stated in source; design directive]
- status_name [design directive]

Possible status_name values:

- pending
- approved
- rejected
- cancelled
- checked in
- completed
- no-show

### 4.10 APPROVAL_DECISION

Represents the recorded decision event when a booking is approved or rejected.

Attributes:

- approval decision identifier [proposed identifier — not stated in source]
- decision_outcome [proposed — derived from the source's “approved or rejected” conditional, not stated as a stored fact]
- decision time
- decision note
- rejection reason

Possible decision_outcome values:

- approved
- rejected

Note: Under the design directive, `decision_outcome` references BOOKING_STATUS instead of creating a separate decision-outcome entity; only approved and rejected are meaningful as approval decision outcomes.

### 4.11 USAGE_SESSION

Represents the recorded use of a booking when facility staff check in and later complete the booking.

Attributes:

- usage session identifier [proposed identifier — not stated in source]
- actual start time
- initial condition of the space
- actual end time
- final condition of the space
- usage notes

### 4.12 MAINTENANCE_RECORD

Represents a maintenance record for a space problem.

Attributes:

- maintenance record identifier [proposed identifier — not stated in source]
- problem description
- start time
- completion time
- result note

### 4.13 MAINTENANCE_STATUS

Represents maintenance record status values under a design directive.

Attributes:

- status identifier [proposed identifier — not stated in source; design directive]
- status_name [design directive]

## 5. Relationships and Cardinalities

| Relationship | Cardinality | Description |
|---|---:|---|
| USER_ACCOUNT belongs_to DEPARTMENT | USER_ACCOUNT `1..1` — DEPARTMENT `0..*` | Design directive: each user belongs to exactly one department; one department may be linked to many or no users. |
| DEPARTMENT is_managed_by USER_ACCOUNT | DEPARTMENT `0..1` — USER_ACCOUNT `0..*` | Design directive: each department has zero or one managing user; a user may manage zero or many departments. |
| USER_ACCOUNT has_role ROLE | USER_ACCOUNT `1..1` — ROLE `0..*` | Design directive replaces the user role attribute; Layer B says each user stores a role and lists possible roles. |
| USER_ACCOUNT has_account_status ACCOUNT_STATUS | USER_ACCOUNT `1..1` — ACCOUNT_STATUS `0..*` | Design directive replaces the user account status attribute; Layer B says account status is stored for each user. |
| SPACE has_space_status SPACE_STATUS | SPACE `1..1` — SPACE_STATUS `0..*` | Design directive replaces current status; Layer B says current status is stored for each space. |
| BOOKING_REQUEST has_booking_status BOOKING_STATUS | BOOKING_REQUEST `1..1` — BOOKING_STATUS `0..*` | Design directive replaces booking status; Layer B says each booking request has a status. |
| APPROVAL_DECISION has_decision_outcome BOOKING_STATUS | APPROVAL_DECISION `1..1` — BOOKING_STATUS `0..*` | Design directive: `decision_outcome` on APPROVAL_DECISION references BOOKING_STATUS to share the same value set as BOOKING_REQUEST status; each decision records one outcome, while a booking status value may be referenced by many or no approval decisions. |
| MAINTENANCE_RECORD has_maintenance_status MAINTENANCE_STATUS | MAINTENANCE_RECORD `1..1` — MAINTENANCE_STATUS `0..*` | Design directive replaces maintenance status; Layer B says each maintenance record stores status. |
| SPACE has FACILITY | SPACE `0..*` — FACILITY `0..*` | Layer B says each space may have several facilities and the system stores the list of facilities available in each space; it does not state a facility item is unique to one space. |
| USER_ACCOUNT submits BOOKING_REQUEST | USER_ACCOUNT `0..*` — BOOKING_REQUEST `1..1` | Layer B says users can submit booking requests; a booking request is created by one submitting user, while a user may submit many or none. |
| BOOKING_REQUEST selects SPACE | BOOKING_REQUEST `1..1` — SPACE `0..*` | Layer B says users submit booking requests by selecting a space; a space may have many or no booking requests. |
| BOOKING_REQUEST has APPROVAL_DECISION | BOOKING_REQUEST `0..*` — APPROVAL_DECISION `1..1` | Layer B says a booking request may require approval and, when approved or rejected, a decision is recorded; multiple decision records are left possible because Layer B does not limit re-decisions. |
| USER_ACCOUNT makes APPROVAL_DECISION | USER_ACCOUNT `0..*` — APPROVAL_DECISION `1..1` | Layer B says the system records the staff member who made the decision; a single decision event has one decision maker, while a user may make many or no decisions. |
| BOOKING_REQUEST has USAGE_SESSION | BOOKING_REQUEST `0..1` — USAGE_SESSION `1..1` | Layer B describes one check-in-to-completion use of the booking; `0..1` usage session per booking is a singleton-by-nature assumption because a usage session records one start-to-end use of one booking. |
| USER_ACCOUNT checks_in USAGE_SESSION | USER_ACCOUNT `0..*` — USAGE_SESSION `1..1` | Layer B says facility staff can check in the booking and the system records the person who checked in the booking; a check-in event has one recorded person. |
| USER_ACCOUNT completes USAGE_SESSION | USER_ACCOUNT `0..*` — USAGE_SESSION `0..1` | Layer B says facility staff can complete the booking; completion occurs after check-in, so a usage session may not yet have a completion person, and a completed session has at most one completion person. |
| SPACE has MAINTENANCE_RECORD | SPACE `0..*` — MAINTENANCE_RECORD `1..1` | Layer B says a space may have maintenance records and each maintenance record stores the related space. |
| USER_ACCOUNT reports MAINTENANCE_RECORD | USER_ACCOUNT `0..*` — MAINTENANCE_RECORD `1..1` | Layer B says each maintenance record stores the reporter; one record has one reporter, while a user may report many or none. |
| USER_ACCOUNT assigned_to MAINTENANCE_RECORD | USER_ACCOUNT `0..*` — MAINTENANCE_RECORD `0..1` | Layer B says each maintenance record stores the assigned staff member; assignment timing is not stated, so the record may exist before assignment, and a record has at most one assigned staff member. |

## 6. Business Rules

### 6.1 User and Space Data Rules

- BR-01: Each user must have a university account, and the system stores user ID, full name, email, phone number, role, department, and account status, per the Facility Manager summary user paragraph.
- BR-02: A user may be a student, lecturer, teaching assistant, facility staff, department administrator, or facility manager, per the Facility Manager summary user paragraph.
- BR-03: For each space, the system stores a unique space code, space name, space type, building, floor, room number, capacity, current status, and usage policy, per the Facility Manager summary space paragraph.
- BR-04: A space may be available, in use, under maintenance, temporarily closed, or retired, per the Facility Manager summary space paragraph.
- BR-05: Each space may have several facilities, and the system stores the list of facilities available in each space, per the Facility Manager summary facilities paragraph.

### 6.2 Booking Rules

- BR-06: Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants, per the Facility Manager summary booking paragraph.
- BR-07: A booking may be for a lecture, examination, seminar, workshop, meeting, student activity, or administrative event, per the Facility Manager summary booking paragraph.
- BR-08: Each booking request has a status such as pending, approved, rejected, cancelled, checked in, completed, or no-show, per the Facility Manager summary booking status paragraph.
- BR-09: The system must prevent conflicting bookings, per the Facility Manager summary booking status paragraph.
- BR-10: The same space cannot have two approved bookings with overlapping time periods, per the Facility Manager summary booking status paragraph.
- BR-11: A space that is under maintenance, temporarily closed, or retired cannot be booked, per the Facility Manager summary booking status paragraph and the source's later “closed” wording.

### 6.3 Approval and Usage Rules

- BR-12: A booking request may require approval from a facility staff member or manager, per the Facility Manager summary approval paragraph.
- BR-13: When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note, per the Facility Manager summary approval paragraph.
- BR-14: If the booking is rejected, the rejection reason should be stored, per the Facility Manager summary approval paragraph.
- BR-15: When the requester arrives, facility staff can check in the booking, and the system records actual start time, the person who checked in the booking, and the initial condition of the space, per the Facility Manager summary usage paragraph.
- BR-16: When the session ends, facility staff can complete the booking by recording actual end time, final condition of the space, and any usage notes, per the Facility Manager summary usage paragraph.

### 6.4 Maintenance and History Rules

- BR-17: A space may have maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems, per the Facility Manager summary maintenance paragraph.
- BR-18: Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note, per the Facility Manager summary maintenance paragraph.
- BR-19: A space under maintenance cannot be booked, per the Facility Manager summary maintenance paragraph.
- BR-20: The system should keep historical records of bookings and maintenance activities, per the Facility Manager summary history paragraph.
- BR-21: Staff should be able to view booking history, upcoming bookings, spaces under maintenance, and no-show bookings, per the Facility Manager summary history paragraph.

## 7. State Transitions

Cancelled and no-show are allowed booking status values from Layer B, but their transition triggers and roles are intentionally left as Open Questions rather than asserted here.

### 7.1 BOOKING_REQUEST Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| pending | approved | A booking request requiring approval is approved by a facility staff member or manager; see BR-12 and BR-13. |
| pending | rejected | A booking request requiring approval is rejected by a facility staff member or manager; see BR-12 through BR-14. |
| approved | checked in | Facility staff check in the booking when the requester arrives; see BR-15. |
| checked in | completed | Facility staff complete the booking when the session ends; see BR-16. |

### 7.2 MAINTENANCE_RECORD Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| Not specified in source | Not specified in source | Layer B states maintenance records store status, start time, completion time, and result note, but it does not name maintenance status values or transition triggers. |

## 8. Role Permissions

| Action | Allowed Role(s) per source text | Source basis |
|---|---|---|
| Submit booking request | Users, including the listed account roles | Layer B says “Users can submit booking requests” and lists possible user roles. |
| Approve / reject booking | Facility staff member or manager | Layer B says a booking request may require approval from a facility staff member or manager. |
| Check in booking | Facility staff | Layer B says facility staff can check in the booking. |
| Complete usage session | Facility staff | Layer B says facility staff can complete the booking. |
| Report maintenance issue | Reporter role not specified | Layer B says each maintenance record stores the reporter but does not state which roles may report. |
| Assign maintenance staff | Assigning role not specified | Layer B says each maintenance record stores the assigned staff member but does not state who assigns that staff member. |
| View booking history, upcoming bookings, spaces under maintenance, and no-show bookings | Staff | Layer B says staff should be able to view these items. |

## 9. Workflow Narratives

### 9.1 Booking Lifecycle (request → approval → check-in → completion)

A user submits a booking request by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants, as stated in BR-06. The request has a booking status from the values in BR-08. If approval is required, a facility staff member or manager approves or rejects it and the decision details are recorded as stated in BR-12 through BR-14. Approved bookings must not overlap for the same space, and unavailable spaces must not be booked, as stated in BR-10 and BR-11. When the requester arrives, facility staff check in the booking and record check-in details per BR-15. When the session ends, facility staff complete the booking and record completion details per BR-16.

### 9.2 Maintenance Lifecycle (report → assignment → resolution)

A space may receive maintenance records for problems such as broken projectors, air-conditioning failure, damaged furniture, cleaning issues, or network problems, as stated in BR-17. Each maintenance record stores the related space, reporter, assigned staff member, problem description, start time, completion time, status, and result note, as stated in BR-18. While a space is under maintenance, it cannot be booked, as stated in BR-19. The source does not define maintenance status values, assignment timing, or transition steps, so those details are kept as Open Questions rather than asserted.

## 10. Cross-Entity Constraints

- CEC-01: For BOOKING_REQUEST and SPACE, the same space cannot have two approved bookings with overlapping time periods; this direction is grounded in Layer B's statement that “The same space cannot have two approved bookings with overlapping time periods.”
- CEC-02: For BOOKING_REQUEST and SPACE_STATUS, a space whose status is under maintenance, temporarily closed, or retired cannot be booked; this direction is grounded in Layer B's statement that such a space cannot be booked.
- CEC-03: For MAINTENANCE_RECORD and SPACE booking availability, Layer B states “A space under maintenance cannot be booked,” but it does not state whether creating or opening a maintenance record automatically changes the space status to under maintenance; that dependency direction is left as an Open Question.

## 11. Traceability Matrix

| Requirement Area | Source Requirement | Related Entities | Related Relationships | Related Business Rules |
|---|---|---|---|---|
| User accounts | Each user must have a university account and stored user information; users may have listed roles. | USER_ACCOUNT, ROLE, ACCOUNT_STATUS, DEPARTMENT | USER_ACCOUNT has_role ROLE; USER_ACCOUNT has_account_status ACCOUNT_STATUS; USER_ACCOUNT belongs_to DEPARTMENT | BR-01, BR-02 |
| Spaces | The School manages many bookable spaces and stores space details and current status. | SPACE, SPACE_STATUS | SPACE has_space_status SPACE_STATUS | BR-03, BR-04 |
| Facilities | Each space may have several facilities and the system stores the list of facilities available in each space. | SPACE, FACILITY | SPACE has FACILITY | BR-05 |
| Booking request submission | Users submit booking requests by selecting space, times, purpose, and expected participants. | USER_ACCOUNT, BOOKING_REQUEST, SPACE, BOOKING_STATUS | USER_ACCOUNT submits BOOKING_REQUEST; BOOKING_REQUEST selects SPACE; BOOKING_REQUEST has_booking_status BOOKING_STATUS | BR-06, BR-07, BR-08 |
| Booking conflict and availability | Prevent conflicting bookings; same space cannot have two approved overlapping bookings; unavailable spaces cannot be booked. | BOOKING_REQUEST, BOOKING_STATUS, SPACE, SPACE_STATUS | BOOKING_REQUEST selects SPACE; BOOKING_REQUEST has_booking_status BOOKING_STATUS; SPACE has_space_status SPACE_STATUS | BR-09, BR-10, BR-11 |
| Approval | Booking request may require approval; approved/rejected decision details and rejection reason are recorded. | BOOKING_REQUEST, APPROVAL_DECISION, USER_ACCOUNT, BOOKING_STATUS | BOOKING_REQUEST has APPROVAL_DECISION; USER_ACCOUNT makes APPROVAL_DECISION; APPROVAL_DECISION has_decision_outcome BOOKING_STATUS | BR-12, BR-13, BR-14 |
| Usage session | Facility staff check in and complete bookings and record actual use details. | BOOKING_REQUEST, USAGE_SESSION, USER_ACCOUNT | BOOKING_REQUEST has USAGE_SESSION; USER_ACCOUNT checks_in USAGE_SESSION; USER_ACCOUNT completes USAGE_SESSION | BR-15, BR-16 |
| Maintenance | A space may have maintenance records, and each record stores related maintenance details. | SPACE, MAINTENANCE_RECORD, MAINTENANCE_STATUS, USER_ACCOUNT | SPACE has MAINTENANCE_RECORD; USER_ACCOUNT reports MAINTENANCE_RECORD; USER_ACCOUNT assigned_to MAINTENANCE_RECORD; MAINTENANCE_RECORD has_maintenance_status MAINTENANCE_STATUS | BR-17, BR-18, BR-19 |
| History and viewing | The system keeps historical booking and maintenance records; staff view histories and selected booking/space lists. | BOOKING_REQUEST, USAGE_SESSION, MAINTENANCE_RECORD, SPACE | Relationships supporting booking, usage, and maintenance history | BR-20, BR-21 |

## 12. Assumptions

- Assumption: The input file used was `req/business-requirement.md`; no filename discrepancy was found.
- Assumption [design directive]: DEPARTMENT is modeled as its own entity with a proposed department identifier and department_name, normalized from the source's user department attribute.
- Assumption [design directive]: USER_ACCOUNT belongs_to DEPARTMENT is mandatory for each user, and DEPARTMENT is_managed_by USER_ACCOUNT has zero or one managing user per department and zero or many managed departments per user.
- Assumption [design directive]: ROLE, ACCOUNT_STATUS, SPACE_STATUS, BOOKING_STATUS, and MAINTENANCE_STATUS are controlled-vocabulary entities with proposed identifiers and name attributes; their source attributes are represented through relationships instead of repeated as plain attributes on owning entities.
- Assumption [design directive]: `decision_outcome` on APPROVAL_DECISION references BOOKING_STATUS to share the same value set as BOOKING_REQUEST status; only approved and rejected are meaningful as decision outcomes, but the domain is not restricted at this stage.
- Assumption: `facility identifier`, `booking request identifier`, `approval decision identifier`, `usage session identifier`, and `maintenance record identifier` are proposed identifiers because the source does not state identifiers for those entities.
- Assumption: `decision_outcome` on APPROVAL_DECISION is proposed and derived from the source's “approved or rejected” conditional so the decision event records which outcome occurred.
- Assumption: `decision note` and `rejection reason` are kept as distinct APPROVAL_DECISION facts because Layer B separately states a decision note is recorded for approved or rejected decisions and a rejection reason is stored if the booking is rejected.
- Assumption: The source word “closed” in “under maintenance, closed, or retired cannot be booked” refers to the earlier listed status “temporarily closed.”
- Assumption: The “manager” who may approve in the approval paragraph is treated as the listed “facility manager” role because Layer B lists facility manager as the manager role.
- Assumption: BOOKING_REQUEST has at most one USAGE_SESSION because a usage session records one start-to-end use of one booking; this singleton-by-nature decision is resolved here and is not reopened as a multiplicity open question.
- Assumption: USER_ACCOUNT assigned_to MAINTENANCE_RECORD is optional on the maintenance-record side because Layer B stores an assigned staff member but does not state whether assignment exists at record creation.

## 13. Open Questions

- Question: How, if at all, should the stored usage policy be enforced against booking requests? — Scope: Business Workflow
- Question: Which listed account roles are included in the generic “Staff” who can view booking history, upcoming bookings, spaces under maintenance, and no-show bookings? — Scope: Authorization
- Question: Which prior booking status, trigger, and actor set a booking request to cancelled? — Scope: Business Workflow
- Question: Which prior booking status, trigger, and actor set a booking request to no-show? — Scope: Business Workflow
- Question: What are the allowed maintenance status values and their status transitions? — Scope: Business Workflow
- Question: Which role is allowed to report a maintenance issue? — Scope: Authorization
- Question: Who assigns the assigned staff member on a maintenance record, and at what point in the workflow is assignment required? — Scope: Business Workflow
- Question: Does creating or opening a maintenance record automatically change the related space status to under maintenance, or is the space status updated independently? — Scope: Business Workflow
- Question: What criteria determine whether a booking request requires approval? — Scope: Business Workflow
- Question: Layer A mentions checking whether the requester is allowed to use a room and whether special equipment is needed, but Layer B does not specify these as new-system rules; should these become explicit system requirements? — Scope: Mixed
