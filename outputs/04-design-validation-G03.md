# Database Design Validation Report - G03

## 1. Metadata

| Item | Value |
|---|---|
| Review date | 2026-06-23 |
| Reviewer | Database Design Reviewer |
| Target system | Campus Space Management System |
| Required DBMS context | Microsoft SQL Server |

Inputs reviewed:

- `req/business-requirement.md`
- `outputs/01-business-req-analysis-G03.md`
- `outputs/02-erd-design-G03.md`
- `outputs/03-logical-design-G03.md`

Review objective:

- Validate that the requirement analysis, conceptual ERD, and logical relational schema are aligned with the business requirements.
- Identify design issues, risks, and recommendations without introducing new business requirements.

## 2. Summary of Findings

| Reviewed Artifact | Grade | Summary |
|---|---|---|
| Business Requirement Analysis | Good | Accurately captures the main actors, entities, relationships, business rules, and open questions from the source requirement. One minor inconsistency exists around the `Staff` role. |
| Conceptual Database Design | Good | Covers all major required entities and relationships. The ERD is clear and preserves the many-to-many `SPACE` to `FACILITY` relationship at the conceptual level. Some business rules are documented but not structurally modeled, which is acceptable at conceptual level but creates implementation risk. |
| Logical Database Design | Good with Conditions | Correctly maps entities to tables, resolves the many-to-many relationship with `SPACE_FACILITY`, and defines primary/foreign keys. Several core business rules require later SQL implementation logic and cannot be guaranteed by the current schema alone. |

Overall assessment:

- The design is broadly aligned with the requirements.
- No blocking conceptual entity or relationship is missing.
- The main risks are enforcement risks for conflict prevention, unavailable-space booking prevention, role authorization, and status-dependent mandatory fields.

## 3. Requirement Analysis Review

| Requirement Area | Review Result | Evidence |
|---|---|---|
| User management | Covered | Source requires user ID, full name, email, phone number, role, department, and account status. Analysis captures these in `User`. |
| Space management | Covered | Source requires unique space code, name, type, building, floor, room number, capacity, status, and usage policy. Analysis captures these in `Space`. |
| Facility tracking | Covered | Source requires facilities per space. Analysis identifies `Facility` and M:N relationship with `Space`. |
| Booking management | Covered | Source requires requests with selected space, requested times, purpose, expected participants, type, and status. Analysis captures these in `Booking Request`. |
| Conflict prevention | Covered as business rule | Analysis explicitly records no overlapping approved bookings for the same space. |
| Approval management | Covered | Analysis records approval decision maker, decision time, note, and rejection reason. |
| Check-in and completion | Covered | Analysis records actual start/end, check-in person, initial/final condition, and usage notes. |
| Maintenance management | Covered | Analysis records related space, reporter, assigned staff member, problem description, start/completion time, status, and result note. |
| Historical reporting | Covered | Analysis identifies booking history, upcoming bookings, spaces under maintenance, and no-show bookings. |

Issue noted:

- The source requirement list of user roles includes student, lecturer, teaching assistant, facility staff, department administrator, and facility manager. The analysis also adds `Staff`, based on the broader source wording that users may include staff. This is reasonable but should be confirmed before enforcing role values.

## 4. Conceptual Design Review

Strengths:

- Includes all major entities required by the business requirements: `USER`, `SPACE`, `FACILITY`, `BOOKING_REQUEST`, `APPROVAL_DECISION`, `USAGE_SESSION`, and `MAINTENANCE_RECORD`.
- Correctly models `SPACE` to `FACILITY` as many-to-many at the conceptual level.
- Separates `APPROVAL_DECISION` from `BOOKING_REQUEST`, which preserves decision history attributes such as decision maker, decision time, decision note, and rejection reason.
- Separates `USAGE_SESSION` from `BOOKING_REQUEST`, which preserves the distinction between requested time and actual use time.
- Separates `MAINTENANCE_RECORD` from `SPACE`, supporting maintenance history.

Conceptual design concerns:

| ID | Severity | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| C-01 | Medium | Role-based authorization is described but not represented beyond `USER.role`. | Source says facility staff/managers approve bookings and facility staff check in/complete sessions. Conceptual design records relationships to `USER` but does not represent allowed role constraints. | Carry this as an implementation rule: approval decision makers should be facility staff or facility managers; check-in and completion users should be facility staff unless the business confirms otherwise. |
| C-02 | Medium | Booking eligibility by usage policy is only represented as free text. | Source says facility staff check whether the requester is allowed to use the room and that bookings must not exceed usage policy. Conceptual design includes `SPACE.usage_policy`, but no structured rule or relationship models eligibility. | Keep `usage_policy` as descriptive data unless the business requires automated eligibility checking. If automated checking is required, add a later design rule or supporting structure after clarification. |
| C-03 | Low | Approval requirement criteria are unresolved. | Source says a booking may require approval. Conceptual design supports decisions but does not identify which booking types require approval. | Keep as open question before final implementation. Do not infer approval criteria without business confirmation. |

## 5. Logical Design Review

Strengths:

- Correctly converts conceptual entities into relational tables.
- Uses `USER_ACCOUNT` instead of `USER`, avoiding SQL Server reserved-word risk.
- Defines primary keys for all tables.
- Defines foreign keys for requester, space, decision maker, check-in user, completion user, reporter, and assigned maintenance staff.
- Correctly resolves the `SPACE` to `FACILITY` many-to-many relationship using `SPACE_FACILITY`.
- Uses unique foreign keys on `APPROVAL_DECISION.booking_request_id` and `USAGE_SESSION.booking_request_id` to enforce the conceptual 1:0..1 relationships.
- Includes check constraints for enumerated roles, space types, space statuses, booking types, booking statuses, and basic time consistency.

Logical design issues:

| ID | Severity | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| L-01 | High | The schema does not enforce the main conflict-prevention rule by itself. | Source says the same space cannot have two approved bookings with overlapping time periods. Logical design notes that this requires implementation logic beyond basic constraints. | Implement this rule in the database definition using SQL Server-compatible logic such as a trigger or controlled stored procedure for approving bookings. Validate by checking overlapping rows for the same `space_code` where `booking_status = 'Approved'`. |
| L-02 | High | The schema does not enforce unavailable-space booking prevention by itself. | Source says spaces under maintenance, closed, or retired cannot be booked. Logical design records `SPACE.current_status` and notes that implementation logic is required. | Implement database logic preventing booking creation or approval when `SPACE.current_status` is `Under maintenance`, `Temporarily closed`, or `Retired`. Include active maintenance records in the check if maintenance status is later standardized. |
| L-03 | Medium | Role-specific action rules are not enforced in the logical schema. | Source limits approvals to facility staff or facility manager and check-in/completion to facility staff. Logical design stores user references but does not constrain referenced users by role. | Add implementation checks for `decision_maker_user_id`, `checked_in_by_user_id`, `completed_by_user_id`, and `assigned_to_user_id` based on allowed roles after role rules are confirmed. |
| L-04 | Medium | Rejection reason requirement is not conditionally enforced. | Source says if a booking is rejected, the rejection reason should be stored. Logical design allows `BOOKING_REQUEST.rejection_reason` and `APPROVAL_DECISION.rejection_reason` to be nullable without a status/outcome-dependent constraint. | Add conditional checks where feasible: rejected bookings or rejected approval decisions should require a non-null rejection reason. Clarify whether the authoritative rejection reason belongs in `BOOKING_REQUEST`, `APPROVAL_DECISION`, or both. |
| L-05 | Medium | Maintenance assignment may be under-enforced. | Source says each maintenance record stores the assigned staff member. Requirement analysis assumes assignment is optional when first reported, and logical design makes `assigned_to_user_id` nullable. | Confirm whether assignment is always required or only required after assignment occurs. If always required, make `assigned_to_user_id` not null. If optional initially, keep nullable and enforce assignment for statuses that represent active work. |
| L-06 | Medium | Maintenance status values are not constrained. | Source requires maintenance status but does not list allowed values. Logical design leaves `maintenance_status` unconstrained. | Confirm allowed maintenance statuses before DDL finalization. Add a check constraint or reference table once values are known. |
| L-07 | Low | `FACILITY.facility_name_or_type` has no uniqueness rule. | Source describes facility types such as projector and whiteboard. Logical design intentionally avoids uniqueness because requirements do not specify it. | Accept as-is unless the business confirms facility type names should be unique. If confirmed, add a unique constraint. |
| L-08 | Low | Participant count is not checked against space capacity. | Source requires expected participants and space capacity, but does not explicitly state that expected participants must be less than or equal to capacity. Requirement analysis records this as an open question. | Keep as open question. If confirmed, enforce in booking approval or submission logic. |
| L-09 | Low | Account status values are not constrained. | Source requires account status but does not define allowed values. Logical design stores the column without an allowed-value check. | Confirm allowed account statuses before implementation. Add a check constraint or reference table after confirmation. |

## 6. Requirement Coverage Matrix

| Requirement | Conceptual Design Coverage | Logical Design Coverage | Validation Result |
|---|---|---|---|
| Store users and university account details | `USER` entity | `USER_ACCOUNT` table | Passed |
| Store bookable spaces and unique space code | `SPACE` entity | `SPACE` table with primary key `space_code` | Passed |
| Store space facilities | `SPACE` M:N `FACILITY` | `FACILITY` and `SPACE_FACILITY` | Passed |
| Submit booking requests for selected space and time | `BOOKING_REQUEST` with `USER` and `SPACE` relationships | `BOOKING_REQUEST` with requester and space foreign keys | Passed |
| Prevent overlapping approved bookings | Captured as business rule | Not enforceable by current table constraints alone | Passed with high implementation risk |
| Prevent booking unavailable spaces | Captured through `SPACE.current_status` and maintenance relationship | Not enforceable by current table constraints alone | Passed with high implementation risk |
| Record approval/rejection decision details | `APPROVAL_DECISION` entity and relationships | `APPROVAL_DECISION` table with decision maker and booking foreign keys | Passed with medium conditional-rule risk |
| Record check-in and completion details | `USAGE_SESSION` entity and relationships | `USAGE_SESSION` table with staff references and actual time fields | Passed with medium role-rule risk |
| Store maintenance records | `MAINTENANCE_RECORD` entity and relationships | `MAINTENANCE_RECORD` table with space and user foreign keys | Passed with medium assignment/status risk |
| Preserve historical booking and maintenance records | Historical entities retained | Event tables retained rather than overwritten | Passed |
| Support reporting for history, upcoming bookings, maintenance spaces, and no-shows | Covered by retained entities and statuses | Queryable through `BOOKING_REQUEST`, `SPACE`, and `MAINTENANCE_RECORD` | Passed |

## 7. Recommendations Before Database Implementation

| Priority | Recommendation | Related Issues |
|---|---|---|
| High | Implement database-level or controlled transaction logic to prevent overlapping approved bookings for the same space. | L-01 |
| High | Implement database-level or controlled transaction logic to prevent booking or approving unavailable spaces. | L-02 |
| Medium | Confirm role permissions and enforce them for approvals, check-in, completion, and maintenance assignment. | C-01, L-03 |
| Medium | Confirm where rejection reason should be stored and enforce it when a booking or decision is rejected. | L-04 |
| Medium | Confirm maintenance assignment timing and allowed maintenance statuses. | L-05, L-06 |
| Low | Confirm whether user email, facility names, account statuses, and participant-capacity checks should be constrained. | L-07, L-08, L-09 |

## 8. Final Conclusion

Final decision: **ACCEPTED WITH CONDITIONS**.

The conceptual and logical database designs meet the core business requirements and follow appropriate relational design practices. The design includes the required entities, relationships, keys, and traceability. However, the design should not proceed to final database implementation without addressing the high-priority enforcement items for overlapping approved bookings and unavailable-space booking prevention.

The design is accepted for progression to database implementation only if the implementation step explicitly handles the identified high and medium severity rules.
