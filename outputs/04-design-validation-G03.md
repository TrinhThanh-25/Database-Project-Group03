# Database Design Validation Report - G03

## 1. Metadata

| Item | Value |
|------|------|
| Review Date | 2026-06-25 |
| Reviewer | openai/gpt-5.5 database-design-reviewer agent |
| Target System | Campus Space Management System |
| Required DBMS Context | Microsoft SQL Server |

### Inputs Reviewed

Reviewed in the required order:

1. `req/business-requirement.md`
2. `outputs/01-business-req-analysis-G03.md`
3. `outputs/02-erd-design-G03.md`
4. `outputs/03-logical-design-G03.md`

### Template and Rubric Used

- Requested template path: `.opencode/skills/db-design-pipeline/templates/validation-template.md`
- Actual template path used: `.opencode/templates/validation-template.md`
- Validation rubric used: `.opencode/evaluation/validation-rubric.md`
- Template path note: the requested template path was not present in the repository; the available validation template with the same purpose was used.

### Review Objective

Provide an objective validation of the submitted database design by comparing the requirement analysis, conceptual database design, and logical database design against the original business requirements. This review identifies strengths, gaps, implementation risks, and recommendations. It does not modify or redesign the submitted database design.

---

# 2. Summary of Findings

| Reviewed Artifact | Grade | Summary |
|------|------|------|
| Business Requirement Analysis | A- | Accurately captures actors, entities, attributes, relationships, business rules, role permissions, assumptions, and open questions from `req/business-requirement.md`. |
| Conceptual Database Design | A- | Represents the major domain entities, attributes, relationships, cardinalities, participation constraints, and deferred business rules. Multi-role relationships are documented clearly outside the Mermaid visual simplification. |
| Logical Database Design | B+ | Correctly transforms the ERD into relational tables, primary keys, foreign keys, unique constraints, M:N junction table, and SQL Server-oriented data types. Several critical rules are correctly identified as requiring implementation logic rather than ordinary relational constraints. |

### Overall Assessment

The submitted design is mostly complete, traceable, and suitable to proceed toward database implementation. The main remaining risk is not missing structural design, but implementation enforcement of critical business rules: approved-booking overlap prevention, unavailable-space booking prevention, role restrictions, conditional rejection reason, and lifecycle/status consistency. These are already identified in the logical design and must be enforced in the DDL/procedural/application transaction layer.

---

# 3. Requirement Analysis Review

| Requirement Area | Review Result | Evidence |
|------|------|------|
| User Management | Pass | Raw requirement lines 10 and 15-16 identify users and staff actions; analysis §3 lists six roles and §4.1 lists user attributes. |
| Space Management | Pass | Raw requirement line 11 lists space attributes and statuses; analysis §4.2 captures these attributes and statuses. |
| Facility Management | Pass | Raw requirement line 12 lists facilities per space; analysis §4.3 and §5 model Facility and many-to-many Space-Facility. |
| Booking Management | Pass | Raw requirement lines 13-14 define booking requests, types, statuses, conflicts, and unavailable spaces; analysis BR-5 through BR-10 capture these rules. |
| Approval Management | Pass | Raw requirement line 15 defines approval/rejection and decision details; analysis BR-11 through BR-13 and role permissions capture them. |
| Usage Session Management | Pass | Raw requirement line 16 defines check-in/completion facts; analysis BR-14 through BR-17 capture them. |
| Maintenance Management | Pass with open questions | Raw requirement line 17 defines maintenance records; analysis BR-18 through BR-20 captures records and correctly marks maintenance status transitions and assignment authority as unresolved. |
| Historical Data Management | Pass | Raw requirement line 18 requires history and staff views; analysis BR-21 and BR-22 capture these requirements. |

### Requirement Analysis Issues

| ID | Severity | Finding | Evidence | Recommendation |
|------|------|------|------|------|
| RA-01 | Low | Some source details from the manual process are correctly treated as open questions rather than firm Layer B requirements, but they remain potential scope clarifications. | Raw requirement line 4 mentions requester eligibility and special equipment checks; analysis open questions §13 ask whether these should be enforced. | Keep these as open questions for stakeholder confirmation before implementation. Do not implement them as hard rules unless confirmed. |

---

# 4. Conceptual Database Design Review

## Strengths

- Covers all seven main entities from the analysis: User, Space, Facility, Booking Request, Approval Decision, Usage Session, and Maintenance Record.
- Captures all important non-relationship attributes from the analysis.
- Correctly separates decision facts into `APPROVAL_DECISION` and usage facts into `USAGE_SESSION`.
- Correctly models Space-Facility as M:N based on the requirement that spaces may have several facilities and no evidence that facility types belong to only one space.
- Documents distinct role-playing relationships for check-in/completion and reporter/assigned staff, even though the Mermaid diagram uses representative visual lines.

## Issues

| ID | Severity | Finding | Evidence | Recommendation |
|------|------|------|------|------|
| C-01 | Low | The Mermaid ERD visually merges distinct relationships between the same entity pairs, which could confuse implementers if they rely only on the diagram. | Conceptual design lines 85-86 state that `USER`-`USAGE_SESSION` and `USER`-`MAINTENANCE_RECORD` represent multiple roles, and §4 is authoritative. | Keep the textual relationship table as the authoritative source during implementation; if possible in later documentation, add clearer role-specific diagram annotations. |
| C-02 | Medium | Critical cross-entity rules are represented conceptually but cannot be enforced at the ERD level. | Conceptual design BR-8 through BR-10 and BR-20 coverage lines 218-230 defer conflict and unavailable-space enforcement. | Ensure the logical/physical implementation explicitly enforces these rules using SQL Server constraints plus triggers/procedures/transactions where needed. |

---

# 5. Logical Database Design Review

## Strengths

- Every conceptual entity maps to a logical table: `USER_ACCOUNT`, `SPACE`, `FACILITY`, `BOOKING_REQUEST`, `APPROVAL_DECISION`, `USAGE_SESSION`, and `MAINTENANCE_RECORD`.
- The M:N `HAS_FACILITY` relationship is correctly resolved with `SPACE_FACILITY` and composite primary key.
- Optional 1:0..1 relationships are represented with unique foreign keys on `APPROVAL_DECISION.booking_id` and `USAGE_SESSION.booking_id`.
- Role-playing relationships use clear role-specific foreign key names such as `checked_in_by_user_id`, `completed_by_user_id`, `reported_by_user_id`, and `assigned_to_user_id`.
- CHECK constraints use only upstream-listed allowed values for user roles, space current statuses, booking types, and booking statuses.
- The logical design avoids unsupported uniqueness assumptions for email, facility name, and space name.

## Issues

| ID | Severity | Finding | Evidence | Recommendation |
|------|------|------|------|------|
| L-01 | High | Approved-booking overlap prevention is not enforceable by the listed ordinary relational constraints and must be implemented separately. | Raw requirement line 14 states that the same space cannot have two approved bookings with overlapping time periods. Logical design lines 97-99 and 201-202 classify this as requiring SQL Server implementation logic. | During DDL/implementation, add a robust SQL Server enforcement mechanism such as trigger/procedure with appropriate transaction isolation or application-controlled serializable transaction. |
| L-02 | High | Unavailable-space booking prevention depends on `SPACE.current_status` and is not enforced by a simple FK or CHECK on `BOOKING_REQUEST`. | Raw requirement lines 14 and 17 state closed/retired/under-maintenance spaces cannot be booked. Logical design lines 97-100 and 203 classify this as cross-table implementation logic. | Enforce booking creation/approval against `SPACE.current_status` and define when validation occurs. Include under maintenance, temporarily closed/closed, and retired statuses. |
| L-03 | Medium | Role restrictions for approval, check-in, and completion are not enforceable by foreign keys alone. | Raw requirement lines 15-16 restrict approval to facility staff or manager and check-in/completion to facility staff. Logical design lines 119-121 and 145-147 classify these role restrictions as implementation logic. | Enforce role checks in implementation logic or controlled database APIs. Validate `decision_maker_user_id`, `checked_in_by_user_id`, and `completed_by_user_id` against `USER_ACCOUNT.role`. |
| L-04 | Medium | Rejected bookings require a rejection reason, but the logical design lacks a separate approval-decision outcome attribute and therefore depends on related booking status. | Raw requirement line 15 says rejection reason should be stored if rejected. Logical design lines 119-122 and 206 classify conditional enforcement as cross-table implementation logic. | Implement a conditional rule that requires `APPROVAL_DECISION.rejection_reason` when the related `BOOKING_REQUEST.status = 'Rejected'`, or clarify the decision outcome representation before DDL. |
| L-05 | Medium | Maintenance status values, transitions, and the active-maintenance effect on space availability remain unresolved. | Raw requirement line 17 stores maintenance `status`; analysis open questions lines 304-305; conceptual open questions lines 273-274; logical design lines 169-172 and 223. | Confirm maintenance status values and whether active maintenance automatically changes or validates `SPACE.current_status` before implementing maintenance workflows. |
| L-06 | Low | Candidate keys beyond primary keys are mostly not identified, but this is justified by lack of source evidence. | Logical design line 18 says no uniqueness is asserted for email, facility name, space name, or room location because upstream does not state uniqueness. | Keep current conservative approach unless stakeholders confirm additional natural uniqueness rules. |

---

# 6. Required Validation Areas

| Validation Area | Result | Evidence / Notes |
|---|---|---|
| Requirement coverage | Pass with conditions | BR-1 through BR-22 are traced in analysis §6, conceptual §5, and logical §4. Conditions apply to implementation rules. |
| Actor coverage | Pass | Analysis §3 covers Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager from raw line 10. |
| Entity coverage | Pass | Conceptual §3 and logical §2 cover User, Space, Facility, Booking Request, Approval Decision, Usage Session, Maintenance Record. |
| Attribute coverage | Pass | Entity attributes from raw lines 10-17 are carried through analysis §4, conceptual §3, and logical §2. |
| Relationship coverage | Pass | Analysis §5, conceptual §4, and logical §3 map submission, space selection, facilities, approval, usage, and maintenance relationships. |
| Cardinality correctness | Pass | Conceptual §4 cardinalities are carried to logical §3; M:N and 1:0..1 cases are handled correctly. |
| Participation constraints | Pass with conditions | Mandatory request-user/space and maintenance relationships use NOT NULL FKs; lifecycle-dependent completion facts are nullable and need implementation checks. |
| Primary keys | Pass | Logical §2 names PKs for all tables. |
| Foreign keys | Pass | Logical §2 and §3 name FKs for all conceptual relationships. |
| Candidate keys | Pass with note | `SPACE.unique_space_code` is the stated identifier. Other possible candidate keys are not asserted due lack of evidence. |
| Key constraints | Pass | M:N composite PK and 1:0..1 unique FKs are correctly represented. |
| Business rule enforcement | Pass with conditions | Critical rules are represented but several require SQL Server implementation logic. |
| SQL implementation risks | Conditions required | Overlap, unavailable-space checks, role restrictions, rejection reason, maintenance synchronization, lifecycle completion require non-trivial implementation logic. |
| Assumptions and unresolved questions | Pass | Assumptions and open questions are carried forward in all stage outputs. |

---

# 7. Business Rule Enforcement Matrix

| Business Rule | Requirement Evidence | Covered in Analysis | Modeled in ERD | Represented in Logical Schema | Enforced in DDL | Risk Level | Recommendation |
|---|---|---|---|---|---|---|---|
| BR-1: Each user must have a university account. | Raw line 10 | Yes, BR-1 | Yes, User entity | Yes, `USER_ACCOUNT.user_id` PK | Not reviewed; DDL not produced yet | Low | Implement PK and NOT NULL as specified. |
| BR-2: Store user details and role. | Raw line 10 | Yes, §4.1 and BR-2 | Yes, User attributes | Yes, `USER_ACCOUNT` columns and role CHECK | Not reviewed | Low | Implement listed columns and role CHECK. |
| BR-3: Store space details, status, capacity, policy. | Raw line 11 | Yes, §4.2 and BR-3 | Yes, Space attributes | Yes, `SPACE` table and status CHECK | Not reviewed | Low | Implement PK, status CHECK, and capacity CHECK. |
| BR-4: Store facilities available in each space. | Raw line 12 | Yes, BR-4 | Yes, `HAS_FACILITY` M:N | Yes, `SPACE_FACILITY` junction table | Not reviewed | Low | Implement composite PK and both FKs. |
| BR-5: Users submit booking requests selecting space/time/purpose/participants. | Raw line 13 | Yes, BR-5 | Yes, `SUBMITS` and `SELECTS_SPACE` | Yes, `BOOKING_REQUEST` FKs and columns | Not reviewed | Low | Implement requester and space FKs as NOT NULL. |
| BR-6: Booking type values. | Raw line 13 | Yes, BR-6 | Yes, booking type attribute | Yes, booking type CHECK | Not reviewed | Low | Implement CHECK exactly from listed values. |
| BR-7: Booking status values. | Raw line 14 | Yes, BR-7 and transition section | Yes, status attribute | Yes, status CHECK; transitions deferred | Not reviewed | Medium | Implement status CHECK and controlled transition logic. |
| BR-8: Prevent conflicting bookings. | Raw line 14 | Yes, BR-8 | Represented as cross-entity constraint | Logical design identifies implementation logic | Not reviewed | High | Implement robust overlap/conflict prevention. |
| BR-9: Same space cannot have two approved overlapping bookings. | Raw line 14 | Yes, BR-9 | Represented by request times/status/space | Logical design identifies implementation logic | Not reviewed | High | Use trigger/procedure/transaction rule to enforce approved interval exclusion. |
| BR-10: Under-maintenance, closed, or retired space cannot be booked. | Raw line 14 | Yes, BR-10 | Represented via Space status and selection | Logical design identifies cross-table implementation logic | Not reviewed | High | Enforce status validation during booking creation/approval. |
| BR-11: Booking may require approval from staff/manager. | Raw line 15 | Yes, BR-11 | Optional Approval Decision | Unique FK supports optional 1:0..1; role logic deferred | Not reviewed | Medium | Enforce approval-required workflow and approver role. |
| BR-12: Record decision maker, time, note. | Raw line 15 | Yes, BR-12 | Approval Decision + User relationship | `APPROVAL_DECISION` columns and FK | Not reviewed | Medium | Implement FK and role check for decision maker. |
| BR-13: Rejected booking stores rejection reason. | Raw line 15 | Yes, BR-13 | Rejection reason attribute | Nullable column; conditional rule deferred | Not reviewed | Medium | Implement conditional rule tied to rejected status. |
| BR-14: Facility staff can check in booking. | Raw line 16 | Yes, BR-14 | Usage Session and checked-in-by relationship | `USAGE_SESSION` with check-in FK | Not reviewed | Medium | Enforce Facility Staff role and eligible booking state. |
| BR-15: Store actual start, checker, initial condition. | Raw line 16 | Yes, BR-15 | Usage Session attributes and relationship | NOT NULL usage-session columns and FK | Not reviewed | Low | Implement columns and FK as specified. |
| BR-16: Facility staff can complete session. | Raw line 16 | Yes, BR-16 | Completed-by relationship | Nullable completion FK; lifecycle logic deferred | Not reviewed | Medium | Enforce completion role and valid state transition. |
| BR-17: Store actual end, final condition, usage notes. | Raw line 16 | Yes, BR-17 | Usage Session attributes | Nullable lifecycle columns; completion consistency deferred | Not reviewed | Medium | Require completion facts when session is completed. |
| BR-18: Space may have maintenance records. | Raw line 17 | Yes, BR-18 | Space-Maintenance relationship | `MAINTENANCE_RECORD` FK to `SPACE` | Not reviewed | Low | Implement FK. |
| BR-19: Maintenance record stores space, reporter, assigned staff, problem, timing, status, result. | Raw line 17 | Yes, BR-19 | Maintenance Record attributes and User relationships | Columns and FKs represented; status values unresolved | Not reviewed | Medium | Confirm maintenance statuses and role rules before DDL. |
| BR-20: Space under maintenance cannot be booked. | Raw line 17 | Yes, BR-20 | Space status and maintenance relationship | Implementation logic/open question | Not reviewed | High | Define active maintenance synchronization and enforce booking prevention. |
| BR-21: Keep historical booking and maintenance records. | Raw line 18 | Yes, BR-21 | Event/history entities retained | Persistent tables represented | Not reviewed | Low | Avoid destructive deletes or define archival policy during implementation. |
| BR-22: Staff view booking history, upcoming bookings, maintenance spaces, no-shows. | Raw line 18 | Yes, BR-22 | Information represented; access deferred | Query/view support possible; access control deferred | Not reviewed | Medium | Implement views/queries and access control in later stages. |

---

# 8. Requirement Coverage Matrix

| Requirement | Conceptual Coverage | Logical Coverage | Validation Result |
|------|------|------|------|
| User and role management | User entity and role attribute | `USER_ACCOUNT` table with role CHECK | Covered |
| Space management | Space entity with status, capacity, policy | `SPACE` table with PK, status CHECK, capacity CHECK | Covered |
| Facilities per space | Facility entity and M:N relationship | `FACILITY` and `SPACE_FACILITY` | Covered |
| Booking requests | Booking Request entity plus User/Space relationships | `BOOKING_REQUEST` with FKs and CHECK constraints | Covered |
| Booking conflict prevention | Cross-entity rule identified | Implementation logic required | Covered with implementation condition |
| Unavailable-space prevention | Space status plus booking relationship | Implementation logic required | Covered with implementation condition |
| Approval handling | Approval Decision entity and maker relationship | `APPROVAL_DECISION` with unique booking FK and maker FK | Covered with role/conditional-rule condition |
| Usage session handling | Usage Session entity and role relationships | `USAGE_SESSION` with booking, check-in, completion FKs | Covered with lifecycle-condition rule |
| Maintenance handling | Maintenance Record entity and relationships | `MAINTENANCE_RECORD` with space/user FKs | Covered with status/role open questions |
| History and staff views | Historical entities retained | Tables support query/view design | Covered; access implementation deferred |

---

# 9. Recommendations

| Priority | Recommendation | Related Issue(s) |
|------|------|------|
| High | In the DDL/implementation stage, enforce approved-booking interval exclusion for the same space using SQL Server implementation logic with concurrency safety. | L-01, BR-8, BR-9 |
| High | Enforce unavailable-space booking prevention against `SPACE.current_status`, including under maintenance, temporarily closed/closed, and retired. | L-02, BR-10, BR-20 |
| Medium | Enforce role-based restrictions for approval, check-in, completion, and any confirmed maintenance role rules. | L-03, L-05 |
| Medium | Clarify and implement conditional rejection-reason and approval-decision requirements for approved/rejected bookings. | L-04 |
| Medium | Resolve maintenance status values and active-maintenance synchronization before final DDL or workflow implementation. | L-05 |
| Low | Preserve the textual relationship mapping as authoritative where the Mermaid ERD visually merges role-playing relationships. | C-01 |

---

# 10. Final Conclusion

## Final Decision

**ACCEPTED WITH CONDITIONS**

### Conclusion

The database design is structurally sound and traceable from the original business requirements through analysis, conceptual ERD, and logical schema. It should proceed to database implementation, provided that the implementation stage explicitly enforces the critical business rules that cannot be guaranteed by ordinary primary key, foreign key, unique, and CHECK constraints alone. The most important conditions are overlap prevention, unavailable-space booking prevention, role restrictions, conditional rejection reason enforcement, and maintenance/status lifecycle clarification.
