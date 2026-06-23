# Business Requirement Analysis - G03

## 1. Source Documents

- Requested input: `req/business-requirements.md`
- Actual input used: `req/business-requirement.md`
- Target system: Campus Space Management System for the School of Computer Science

## 2. Business Context

The School of Computer Science manages shared physical spaces used for teaching, seminars, examinations, workshops, student projects, research activities, meetings, and academic events. The current booking and availability process is manual, relying on email, phone calls, in-person requests, spreadsheets, and shared calendars.

The proposed system will manage space bookings, approvals, usage sessions, maintenance records, incident-like maintenance problems, and facility utilization history. Its main goals are to manage shared spaces fairly, avoid overlapping approved bookings, prevent unavailable spaces from being used, and preserve historical records.

## 3. System Actors

| Actor | Description | Main Responsibilities / Interactions |
|---|---|---|
| Student | University user who may request spaces for student activities or project work. | Submit booking requests; attend booked sessions. |
| Lecturer | University user who may request spaces for lectures, examinations, seminars, or academic activities. | Submit booking requests; use spaces for academic purposes. |
| Teaching Assistant | University user who may request or support use of spaces for teaching activities. | Submit booking requests; assist with teaching-related space usage. |
| Staff | General school staff user. | Submit booking requests for administrative or school activities. |
| Facility Staff | Staff member responsible for operational space management. | Check availability; approve/reject bookings when authorized; check in bookings; complete sessions; report or manage maintenance. |
| Department Administrator | Administrative user associated with a department. | Submit or coordinate administrative bookings. |
| Facility Manager | Manager responsible for facility operations and approval oversight. | Approve/reject bookings when required; monitor utilization, maintenance, and booking history. |

## 4. Main Entities and Attributes

### 4.1 User

Represents a person with a university account who interacts with the system.

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
- Staff

### 4.2 Space

Represents a bookable physical campus space.

Attributes:

- Space code
- Space name
- Space type
- Building
- Floor
- Room number
- Capacity
- Current status
- Usage policy

Possible space types:

- Auditorium
- Classroom
- Computer laboratory
- Project laboratory
- Meeting room
- Student workspace

Possible current statuses:

- Available
- In use
- Under maintenance
- Temporarily closed
- Retired

### 4.3 Facility

Represents equipment or physical facilities available in a space.

Attributes:

- Facility name or type
- Facility description, if needed

Examples:

- Projector
- Whiteboard
- Microphone
- Computer
- Livestreaming equipment
- Air conditioner

### 4.4 Booking Request

Represents a request to reserve and use a space for a specific time period and purpose.

Attributes:

- Booking request identifier
- Requested start time
- Requested end time
- Purpose of use
- Expected number of participants
- Booking type or activity type
- Booking status
- Rejection reason, when rejected

Possible booking types:

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

Represents the decision made on a booking request when approval is required.

Attributes:

- Decision type or outcome
- Decision time
- Decision note
- Rejection reason, when rejected

### 4.6 Usage Session

Represents the actual use of a space after an approved booking is checked in and completed.

Attributes:

- Actual start time
- Initial condition of the space
- Actual end time
- Final condition of the space
- Usage notes

### 4.7 Maintenance Record

Represents maintenance activity or a problem reported for a space.

Attributes:

- Maintenance record identifier
- Problem description
- Start time
- Completion time
- Maintenance status
- Result note

Examples of maintenance problems:

- Broken projector
- Air-conditioning failure
- Damaged furniture
- Cleaning issue
- Network problem

## 5. Relationships and Cardinalities

| Relationship | Cardinality | Description |
|---|---:|---|
| User submits Booking Request | One User to many Booking Requests | A user can submit many booking requests; each booking request is submitted by one requester. |
| Booking Request reserves Space | Many Booking Requests to one Space | A space can have many booking requests over time; each booking request is for one selected space. |
| Space has Facility | Many Spaces to many Facilities | A space may have several facilities; a facility type may exist in many spaces. |
| Booking Request receives Approval Decision | One Booking Request to zero or one Approval Decision | A booking may require approval; a decision is recorded when approved or rejected. |
| User makes Approval Decision | One User to many Approval Decisions | A facility staff member or manager can make many approval decisions; each decision is made by one authorized staff member or manager. |
| Booking Request has Usage Session | One Booking Request to zero or one Usage Session | A checked-in booking has actual usage information; pending, rejected, cancelled, or no-show bookings may not have completed session details. |
| User checks in Booking Request | One User to many checked-in Booking Requests | Facility staff can check in many bookings; each checked-in booking records the staff member who performed check-in. |
| User completes Usage Session | One User to many completed Usage Sessions | Facility staff can complete many sessions; each completed session records completion details. |
| Space has Maintenance Record | One Space to many Maintenance Records | A space can have many maintenance records over time; each maintenance record belongs to one space. |
| User reports Maintenance Record | One User to many Maintenance Records | A user can report many maintenance issues; each maintenance record has one reporter. |
| User is assigned Maintenance Record | One User to many Maintenance Records | A staff member can be assigned to many maintenance records; each maintenance record may have one assigned staff member. |

## 6. Business Rules

### 6.1 User Rules

- Each user must have a university account.
- The system must store basic user information: user ID, full name, email, phone number, role, department, and account status.
- A user role must identify the user's operational category, such as student, lecturer, teaching assistant, facility staff, department administrator, facility manager, or staff.

### 6.2 Space Rules

- Each bookable space must have a unique space code.
- A space must have a current status.
- A space may be available, in use, under maintenance, temporarily closed, or retired.
- A space under maintenance cannot be booked.
- A temporarily closed space cannot be booked.
- A retired space cannot be booked.
- A booking request must not exceed the intended use of the space as constrained by its usage policy.

### 6.3 Facility Rules

- The system must store the list of facilities available in each space.
- A space may have several facilities.

### 6.4 Booking Rules

- Users can submit booking requests by selecting a space, requested start time, requested end time, purpose of use, and expected number of participants.
- Each booking request must have a status.
- The system must prevent conflicting bookings.
- The same space cannot have two approved bookings with overlapping time periods.
- A booking request may require approval from a facility staff member or facility manager.
- When a booking is approved or rejected, the system must record the staff member or manager who made the decision.
- When a booking is approved or rejected, the system must record the decision time.
- When a booking is approved or rejected, the system must record a decision note.
- If a booking is rejected, the rejection reason must be stored.

### 6.5 Check-In and Completion Rules

- Facility staff can check in a booking when the requester arrives.
- When a booking is checked in, the system must record the actual start time.
- When a booking is checked in, the system must record the person who checked in the booking.
- When a booking is checked in, the system must record the initial condition of the space.
- When a session ends, facility staff can complete the booking.
- When a booking is completed, the system must record the actual end time.
- When a booking is completed, the system must record the final condition of the space.
- When a booking is completed, the system must record any usage notes.

### 6.6 Maintenance Rules

- A space may have maintenance records.
- Each maintenance record must be related to one space.
- Each maintenance record must store the reporter.
- Each maintenance record must store the assigned staff member when assigned.
- Each maintenance record must store the problem description, start time, completion time, status, and result note.
- A space under maintenance cannot be booked.

### 6.7 History and Reporting Rules

- The system should keep historical records of bookings.
- The system should keep historical records of maintenance activities.
- Staff should be able to view booking history.
- Staff should be able to view upcoming bookings.
- Staff should be able to view spaces under maintenance.
- Staff should be able to view no-show bookings.

## 7. Traceability Matrix

| Requirement Area | Source Requirement | Related Entities | Related Relationships | Related Business Rules |
|---|---|---|---|---|
| User management | Store university account and user details. | User | User submits Booking Request; User reports Maintenance Record; User makes Approval Decision | User Rules |
| Space management | Store bookable spaces and statuses. | Space | Booking Request reserves Space; Space has Maintenance Record | Space Rules |
| Facility tracking | Store facilities available in each space. | Space, Facility | Space has Facility | Facility Rules |
| Booking management | Users submit requests for spaces and time periods. | User, Space, Booking Request | User submits Booking Request; Booking Request reserves Space | Booking Rules |
| Conflict prevention | Prevent overlapping approved bookings for the same space. | Space, Booking Request | Booking Request reserves Space | Booking Rules |
| Availability control | Prevent booking spaces under maintenance, closed, or retired. | Space, Booking Request, Maintenance Record | Booking Request reserves Space; Space has Maintenance Record | Space Rules; Booking Rules; Maintenance Rules |
| Approval management | Record approval/rejection decision details. | Booking Request, Approval Decision, User | Booking Request receives Approval Decision; User makes Approval Decision | Booking Rules |
| Session tracking | Record check-in, actual start/end, space condition, and usage notes. | Booking Request, Usage Session, User | Booking Request has Usage Session; User checks in Booking Request; User completes Usage Session | Check-In and Completion Rules |
| Maintenance management | Track space maintenance problems and resolution. | Space, Maintenance Record, User | Space has Maintenance Record; User reports Maintenance Record; User is assigned Maintenance Record | Maintenance Rules |
| Historical reporting | View booking history, upcoming bookings, maintenance spaces, and no-shows. | Booking Request, Maintenance Record, Space | Related to booking and maintenance relationships | History and Reporting Rules |

## 8. Assumptions

- The requested input filename `req/business-requirements.md` appears to differ from the actual available file `req/business-requirement.md`; this analysis uses the available file.
- Email is assumed to identify a university account contact, but uniqueness is not explicitly stated in the requirements.
- Facility staff and facility managers are assumed to be user roles within the same User entity.
- Booking check-in and completion actions are assumed to be performed by facility staff because the requirements explicitly state that facility staff can perform these actions.
- A usage session is assumed to be created only after a booking is checked in.
- Maintenance assignment is assumed to be optional at the moment a maintenance record is first reported because the requirements mention an assigned staff member but do not state that assignment must happen immediately.
- Facility details beyond a facility name or type are not specified in the requirements.

## 9. Open Questions

- Should user email be unique across all users?
- What account statuses are allowed for users?
- Which user roles are allowed to submit booking requests?
- Which booking types require approval, and which can be automatically approved?
- Can students book all space types, or are some spaces restricted by role, department, or usage policy?
- Should expected number of participants be required to be less than or equal to the space capacity?
- Can a booking be modified after approval, or must it be cancelled and resubmitted?
- How should no-show bookings be determined?
- Can one maintenance record involve multiple assigned staff members?
- Does maintenance status automatically change the related space status to under maintenance, or are these managed separately?
