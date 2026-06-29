# Database Design Validation Report - G03

## 1. Introduction

Review date: 2026-06-29 16:45:57 +07  
Reviewer: openai/gpt-5.5 database-design-reviewer  
Final output: `outputs/04-design-validation-G03.md`

### Review Objective

Provide an objective validation of the submitted database design by comparing the requirement analysis, conceptual database design, and logical database design against the original business requirements. This review does not modify the submitted designs.

### Inputs Reviewed

Reviewed in the required order:

1. Business Requirements: `req/business-requirement.md`
2. Requirement Analysis: `outputs/01-business-req-analysis-G03.md`
3. Conceptual Design: `outputs/02-erd-design-G03.md`
4. Logical Design: `outputs/03-logical-design-G03.md`

---

## 2. Summary of Findings

| Reviewed Artifact | Grade | Summary |
|------|------|------|
| Business Requirement Analysis | A- | Accurately captures the Facility Manager summary, entities, attributes, workflows, assumptions, and scoped open questions. It correctly avoids inventing booking type/category and correctly treats Cancelled/No-show transition triggers as open workflow questions. |
| Conceptual Database Design | A- | Represents all major entities, attributes, and relationships. Cardinality notation is uniform in §4, single-actor relationships are at-most-one actor per event, and Booking Request → Usage Session is correctly resolved as a singleton `0..1`. |
| Logical Database Design | A- | Strong logical transformation with surrogate `INT` PKs, demoted natural keys, named constraints, FK actions, in-row CHECKs, and correct non-unique approval-decision history. Remaining risks are implementation conditions for cross-row/cross-table and authorization rules. |

### Overall Assessment

The submitted design is consistent and implementation-ready with conditions. Core entities and relationships are covered, and the logical schema handles key constraints, FK type matching, referential actions, and single-row CHECK constraints well. The main remaining work is implementation of rules that ordinary relational constraints cannot enforce, especially overlapping approved bookings, unavailable-space booking prevention, and role-based action restrictions.

---

## 3. Requirement Analysis Review

| Requirement Area | Review Result | Evidence |
|------|------|------|
| User Management | Covered | Source says each user has a university account and stores user ID, full name, email, phone, role, department, and account status. Analysis BR-1/BR-2 and User entity cover these facts. |
| Space Management | Covered | Source says spaces store unique space code, name, type, building, floor, room, capacity, current status, and usage policy. Analysis Space entity and BR-3/BR-4 cover these. |
| Facility Management | Covered | Source says each space may have several facilities and stores the list. Analysis Facility entity and Space–Facility relationship cover this. |
| Booking Management | Covered | Source says users submit booking requests by selecting a space, requested times, purpose of use, and expected participants. Analysis Booking Request entity and BR-6/BR-7/BR-8 cover this without adding a fabricated booking type/category. |
| Approval Management | Covered | Source approval paragraph says approval may be by facility staff/manager and records staff member, time, note, and rejection reason if rejected. Analysis Approval Decision entity and BR-11 to BR-13 cover this. |
| Usage Session Management | Covered | Source says facility staff check in and complete bookings, recording actual times, conditions, and notes. Analysis Usage Session entity and BR-14 to BR-16 cover this. |
| Maintenance Management | Covered | Source says spaces may have maintenance records storing related space, reporter, assigned staff, problem, times, status, and result note. Analysis Maintenance Record entity and BR-17 to BR-19 cover this. |
| Historical Data Management | Covered | Source says the system should keep historical booking and maintenance records. Analysis BR-20 and traceability matrix cover this. |

### Issues

No requirement-analysis defect requiring redesign was found. The following important checks were performed and passed:

- Duplicate value-list scan: `Booking Request` carries `Purpose of use` only; there is no fabricated booking type/category attribute.
- Cancelled/No-show classification: analysis lists them as status values but does not assert ungrounded transitions; missing trigger/role is scoped under Open Questions.
- Inference labeling: proposed identifiers and derived `decision_outcome` are visibly labeled and recorded in assumptions.

---

## 4. Conceptual Database Design Review

### Strengths

- All seven analysis entities are represented: User, Space, Facility, Booking Request, Approval Decision, Usage Session, and Maintenance Record.
- Attribute coverage is complete and uses appropriate conceptual types (`int` for counts, `datetime` for time values, `string` for text/status/code values).
- The §4 relationship table uses uniform Entity-A → Entity-B cardinality orientation.
- Single-actor relationships were swept: `MADE_BY`, `CHECKED_IN_BY`, `COMPLETED_BY`, `REPORTED_BY`, and `ASSIGNED_TO` all allow at most one actor per event occurrence; only participation differs where creation timing differs.
- Booking Request → Usage Session is correctly treated as a resolved singleton (`1..1 to 0..1`) and is not left as an unresolved multiplicity.
- Booking Request → Approval Decision remains accumulating (`1..1 to 0..*`), preserving decision history.

### Issues

| ID | Severity | Finding | Evidence | Recommendation |
|------|------|------|------|------|
| C-01 | Low | Conceptual design appropriately defers several rules to logical/implementation stages; this is not a defect but must remain visible. | Conceptual §5 marks BR-9, BR-10, BR-13, and BR-19 as deferred or partly deferred; §8 carries open questions. | Keep these deferred rules traceable into DDL/implementation tasks and test cases. |

---

## 5. Logical Database Design Review

### Strengths

- Every table has a named surrogate `INT IDENTITY` primary key (`PK_...`).
- Natural keys are preserved correctly: `USER_ACCOUNT.user_id` has `UQ_USER_ACCOUNT_user_id`, `SPACE.unique_space_code` has `UQ_SPACE_unique_space_code`, and email has `UQ_USER_ACCOUNT_email`.
- Every FK column is `INT` and references a surrogate `INT` PK, not a demoted natural key.
- Every FK declares explicit `ON DELETE` and `ON UPDATE` actions with consistent reasoning: `SPACE_FACILITY` uses delete cascade; historical/master references use `NO ACTION`; all updates use `NO ACTION` because surrogate PKs are immutable.
- All PK, FK, UNIQUE, and CHECK constraints are named.
- In-row temporal CHECKs are present: `CK_BOOKING_REQUEST_requested_time_order`, `CK_USAGE_SESSION_actual_time_order`, and `CK_MAINTENANCE_RECORD_time_order`.
- The rejected-decision rule is enforced as named in-row CHECK `CK_APPROVAL_DECISION_rejection_reason`.
- `APPROVAL_DECISION.booking_id` is explicitly non-unique, matching conceptual `HAS_APPROVAL_DECISION` `1..1 to 0..*`; `USAGE_SESSION.booking_id` is unique, correctly realizing the resolved singleton session relationship.

### Issues

| ID | Severity | Finding | Evidence | Recommendation |
|------|------|------|------|------|
| L-01 | High | Approved-booking overlap prevention requires implementation logic and must not be missed during DDL/application implementation. | Source says “The same space cannot have two approved bookings with overlapping time periods.” Logical §2.5 and §4 classify BR-9 as trigger/procedure/transaction logic. | Implement and test a SQL Server trigger, stored procedure, or serializable transaction rule that rejects overlapping approved bookings for the same `space_id`. |
| L-02 | High | Booking unavailable spaces requires cross-table implementation logic. | Source says spaces under maintenance, closed, or retired cannot be booked; BR-10/BR-19. Logical §2.5 and §4 classify this as cross-table logic using `SPACE.current_status` and possibly `MAINTENANCE_RECORD`. | Implement a cross-table validation rule preventing bookings when `SPACE.current_status` is `Under maintenance`, `Temporarily closed`, or `Retired`, and clarify how active maintenance records affect space status. |
| L-03 | Medium | Role-based action restrictions require implementation logic beyond FK constraints. | Source says approval may be by facility staff/manager, and facility staff check in and complete bookings. Logical §2.6/§2.7 and §4 classify decision/check-in/completion role restrictions as implementation logic. | Enforce role checks in triggers, stored procedures, service-layer transactions, or authorization policy before inserting/updating decision and usage-session rows. |
| L-04 | Medium | Maintenance status values and maintenance-to-space-status synchronization remain unresolved. | Analysis §13 asks for maintenance status values/transitions and whether maintenance status updates Space current status. Logical §2.8 and §6 carry these as open questions. | Obtain stakeholder clarification before implementing maintenance lifecycle checks or automated space-status synchronization. |
| L-05 | Low | `USER_ACCOUNT.account_status` has no allowed-value CHECK because upstream values are not provided. | Source names account status but gives no values; logical §2.1 and §6 carry this as unresolved. | Ask stakeholders for account-status values if controlled account lifecycle behavior is required. |
| L-06 | Low | Participant count versus capacity is intentionally not enforced because it is not a stated requirement. | Source stores capacity and expected participants but does not say expected participants must not exceed capacity; logical §4 and §6 carry this as an open question. | Do not add this rule unless stakeholders confirm it; if confirmed, enforce with cross-table validation. |

---

## 6. Business Rule Enforcement Matrix

| Business Rule | Requirement Evidence | Covered in Analysis | Modeled in ERD | Represented in Logical Schema | Enforced in DDL | Risk Level | Recommendation |
|---|---|---|---|---|---|---|---|
| BR-1 User account and stored user info | Facility Manager summary: each user has a university account; stores user ID, full name, email, phone, role, department, account status. | Yes, BR-1/User entity | Yes, `USER` | Yes, `USER_ACCOUNT` | DDL-ready via columns, PK/UQ; account-status value list unresolved | Low | Clarify account-status values if a controlled status domain is needed. |
| BR-2 User roles | Facility Manager summary lists student, lecturer, teaching assistant, facility staff, department administrator, facility manager. | Yes, BR-2 | Yes, `USER.role` | Yes, `CK_USER_ACCOUNT_role` | Yes | Low | Implement authorization using the stored role. |
| BR-3 Space details | Facility Manager summary stores unique code, name, type, building, floor, room, capacity, current status, usage policy. | Yes, BR-3/Space | Yes, `SPACE` | Yes, `SPACE`, `UQ_SPACE_unique_space_code`, capacity CHECK | Mostly yes; usage-policy enforcement unresolved | Low | Keep `space_type` open; clarify usage-policy enforcement if needed. |
| BR-4 Space status values | Summary lists available, in use, under maintenance, temporarily closed, retired. | Yes, BR-4 | Yes, `SPACE.current_status` | Yes, `CK_SPACE_current_status` | Yes | Low | None beyond implementation use of status. |
| BR-5 Space facilities | Summary says each space may have several facilities and stores the list. | Yes, BR-5 | Yes, M:N `HAS_FACILITY` | Yes, `SPACE_FACILITY` | Yes via FKs/UQ | Low | Preserve open facility catalog. |
| BR-6 Booking submission facts | Summary says users select space, requested start/end, purpose, participants. | Yes, BR-6 | Yes, `BOOKING_REQUEST`, `SUBMITS`, `SELECTS_SPACE` | Yes, FKs and columns | Yes for structure and time order | Low | None. |
| BR-7 Purpose of use values | Summary lists lecture, examination, seminar, workshop, meeting, student activity, administrative event. | Yes, BR-7 | Yes, `purpose_of_use` only | Yes, `CK_BOOKING_REQUEST_purpose_of_use` | Yes | Low | Do not add duplicate booking type/category. |
| BR-8 Booking status values | Summary lists pending, approved, rejected, cancelled, checked in, completed, no-show. | Yes, BR-8; transition gaps scoped | Yes, `status` | Yes, `CK_BOOKING_REQUEST_status` | Values yes; transitions partial | Medium | Implement only supported transitions; keep Cancelled/No-show triggers as workflow clarification. |
| BR-9 Prevent overlapping approved bookings | Summary: same space cannot have two approved overlapping bookings. | Yes, BR-9 | Represented by booking time/status/space | Represented by columns | Not by ordinary DDL; requires trigger/procedure/transaction | High | Implement overlap validation and concurrency-safe tests. |
| BR-10 Cannot book unavailable spaces | Summary: under maintenance, closed, retired spaces cannot be booked. | Yes, BR-10 | Represented by Space status and booking-space relationship | Represented by FK and status column | Requires cross-table logic | High | Implement status-based booking validation. |
| BR-11 Approval by facility staff/manager | Summary: booking may require approval from facility staff member or manager. | Yes, BR-11 | Yes, `HAS_APPROVAL_DECISION`, `MADE_BY` | Yes, decision-maker FK | Role restriction requires implementation logic | Medium | Enforce permitted decision-maker roles. |
| BR-12 Decision details | Summary records staff member, decision time, decision note. | Yes, BR-12 | Yes, Approval Decision attributes and `MADE_BY` | Yes, `APPROVAL_DECISION` | Mostly yes; role via implementation | Medium | Keep decision note nullable unless mandatory content is clarified. |
| BR-13 Rejection reason | Summary: if rejected, rejection reason should be stored. | Yes, BR-13 | Yes, `rejection_reason` | Yes, `CK_APPROVAL_DECISION_rejection_reason` | Yes | Low | Confirm physical DDL keeps the named CHECK. |
| BR-14 Check-in action | Summary: facility staff can check in booking. | Yes, BR-14 | Yes, `HAS_USAGE_SESSION`, `CHECKED_IN_BY` | Yes, usage-session row and FK | Role restriction requires implementation logic | Medium | Enforce facility-staff check-in role. |
| BR-15 Check-in details | Summary records actual start, person, initial condition. | Yes, BR-15 | Yes, Usage Session attributes | Yes, NOT NULL fields and FK | Yes, plus role logic | Medium | Keep role validation in implementation. |
| BR-16 Completion details | Summary records actual end, final condition, usage notes. | Yes, BR-16 | Yes, Usage Session attributes and `COMPLETED_BY` | Yes, nullable lifecycle fields and CHECKs | In-row yes; role via implementation | Medium | Ensure completion updates set completion fields consistently. |
| BR-17 Maintenance problem records | Summary lists maintenance problem examples. | Yes, BR-17 | Yes, Maintenance Record | Yes, `MAINTENANCE_RECORD` | Yes structurally | Low | Keep problem descriptions flexible. |
| BR-18 Maintenance record details | Summary stores related space, reporter, assigned staff, problem, times, status, result note. | Yes, BR-18 | Yes, relationships and attributes | Yes, FKs/columns and time CHECK | Partial; status values unresolved | Medium | Clarify status vocabulary and role eligibility. |
| BR-19 Space under maintenance cannot be booked | Summary repeats this rule. | Yes, BR-19 | Represented by Space/Maintenance/Booking relationships | Represented by status and FKs | Requires cross-table logic | High | Coordinate with BR-10 validation and maintenance synchronization. |
| BR-20 Historical records | Summary says keep historical bookings and maintenance activities. | Yes, BR-20 | Yes, event/record entities | Yes, separate history tables and `ON DELETE NO ACTION` | Yes by referential actions | Low | Avoid destructive deletes of historical parents. |
| BR-21 Staff views | Summary says staff should view history, upcoming bookings, spaces under maintenance, no-show bookings. | Yes, BR-21 | Data is modeled | Data is queryable | Query/authorization implementation required | Low | Implement views/queries and authorization later. |

---

## 7. Requirement Coverage Matrix

| Requirement | Conceptual Coverage | Logical Coverage | Validation Result |
|------|------|------|------|
| User and roles | `USER` entity and role values | `USER_ACCOUNT`, role CHECK, user/email UNIQUE | Covered |
| Space and status | `SPACE` entity | `SPACE`, current-status CHECK, unique space code | Covered |
| Facilities per space | M:N `HAS_FACILITY` | `SPACE_FACILITY` junction | Covered |
| Booking request | `BOOKING_REQUEST`, `SUBMITS`, `SELECTS_SPACE` | `BOOKING_REQUEST` FKs and time/purpose/status checks | Covered |
| Approval decision history | `APPROVAL_DECISION`, `HAS_APPROVAL_DECISION`, `MADE_BY` | `APPROVAL_DECISION` with non-unique `booking_id` | Covered |
| Usage session | `USAGE_SESSION`, `HAS_USAGE_SESSION`, role relationships | `USAGE_SESSION` with unique `booking_id` and role FKs | Covered |
| Maintenance records | `MAINTENANCE_RECORD`, space/user relationships | `MAINTENANCE_RECORD` FKs and time CHECK | Covered with open status questions |
| Historical preservation | Separate event/record entities | `ON DELETE NO ACTION` on historical/master references | Covered |
| Cross-row/cross-table restrictions | Identified and deferred | Classified as implementation logic | Covered with conditions |

---

## 8. Required Validation Area Checklist

| Area | Result | Evidence |
|---|---|---|
| Requirement, actor, entity, attribute, relationship coverage | Pass | Analysis §§3-6; conceptual §§3-5; logical §§2-4. |
| Cardinality and participation | Pass | Conceptual §4 uses uniform Entity-A → Entity-B order; logical §3 maps each relationship. |
| Primary keys and surrogate-INT standardization | Pass | Logical §2.0 and per-table `PK_...` constraints. |
| Foreign keys and FK data types | Pass | Logical FK columns are `INT` to surrogate `INT` PKs; no FK targets `user_id` or `unique_space_code`. |
| Candidate keys | Pass | `UQ_USER_ACCOUNT_user_id`, `UQ_USER_ACCOUNT_email`, `UQ_SPACE_unique_space_code`. |
| In-row CHECK constraints | Pass | Time-order checks and `CK_APPROVAL_DECISION_rejection_reason` are present. |
| Constraint-strength vs source | Pass | Optional notes such as `decision_note` and `usage_notes` are nullable; open value lists are not over-constrained. |
| Consistent inference labeling | Pass | Proposed identifiers and derived `decision_outcome` are labeled and assumed upstream; logical carries them forward. |
| FK referential actions | Pass | All FK definitions state `ON DELETE`/`ON UPDATE` and criteria. |
| Constraint naming completeness | Pass | All listed PK/FK/UQ/CK constraints are named. |
| Approval-decision cardinality | Pass | `APPROVAL_DECISION.booking_id` is non-unique; `HAS_APPROVAL_DECISION` remains `1..1 to 0..*`. |
| Cancelled/No-show handling | Pass | Treated as status values with scoped workflow open questions, not asserted transitions. |
| Duplicate value-list scan | Pass | No booking type/category; only `purpose_of_use` holds purpose values. |
| Single-actor role-FK sweep | Pass | Decision maker, check-in, completion, reporter, assignment all have at-most-one actor per event. |
| Singleton-by-nature resolution | Pass | Booking → Usage Session resolved `0..1`; logical `UQ_USAGE_SESSION_booking_id` is correct. |

---

## 9. Recommendations

| Priority | Recommendation | Related Issue(s) |
|------|------|------|
| High | Implement concurrency-safe prevention of overlapping approved bookings for the same space and requested time window. | L-01 |
| High | Implement cross-table validation preventing booking of spaces that are under maintenance, temporarily closed/closed, or retired. | L-02 |
| Medium | Implement role checks for approval, check-in, completion, maintenance reporting, and maintenance assignment where stakeholder rules are known. | L-03, L-06 |
| Medium | Clarify maintenance status vocabulary and whether maintenance records synchronize `SPACE.current_status`. | L-04 |
| Low | Clarify `USER_ACCOUNT.account_status` values before adding an account-status CHECK. | L-05 |
| Low | Do not add participant-count-vs-capacity enforcement unless stakeholders confirm it. | L-06 |

---

## 10. Final Conclusion

### Final Decision

**ACCEPTED WITH CONDITIONS**

### Conclusion

The submitted business analysis, conceptual design, and logical design satisfy the documented business requirements and follow the project rules for traceability, cardinality, surrogate keys, FK typing, constraint naming, and in-row CHECK constraints. The design should proceed to implementation only with the conditions that cross-row/cross-table integrity rules and role-based authorization rules are implemented and tested explicitly. No redesign is required before implementation.
