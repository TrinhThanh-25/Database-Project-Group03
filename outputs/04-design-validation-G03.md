# Database Design Validation Report - G03

## 1. Metadata

| Item | Value |
|------|------|
| Review Date | 2026-06-26 |
| Reviewer | openai/gpt-5.5 database-design-reviewer agent |
| Target System | Campus Space Management System |
| Required DBMS Context | Microsoft SQL Server |

### Inputs Reviewed

Reviewed in the required order:

1. `req/business-requirement.md`
2. `outputs/01-business-req-analysis-G03.md`
3. `outputs/02-erd-design-G03.md`
4. `outputs/03-logical-design-G03.md`

### Review Objective

Provide an objective validation of the submitted database design by comparing the requirement analysis, conceptual database design, and logical database design against the original Facility Manager requirements. This review identifies alignment, gaps, risks, and recommendations only; it does not modify the submitted design.

---

# 2. Summary of Findings

| Reviewed Artifact | Grade | Summary |
|------|------|------|
| Business Requirement Analysis | A- | Accurately captures the Facility Manager summary, identifies actors/entities/attributes/relationships/rules, and correctly treats `Cancelled`/`No-show` triggers as scoped Open Questions rather than asserted transitions. |
| Conceptual Database Design | B+ | Covers all core entities, attributes, and relationships, with complete participation text and uniform A→B cardinality notation. Main weakness is the over-restrictive `HAS_APPROVAL_DECISION` cardinality (`1 to 0..1`) despite no explicit stakeholder rule limiting a booking to one decision. |
| Logical Database Design | A- | Strong logical mapping with surrogate `INT` PK standardization, type-matched FKs, named constraints, in-row CHECK constraints, explicit referential actions, and good implementation-risk classification. The main condition is to resolve/confirm approval-decision history cardinality and implement cross-row/cross-table business rules in DDL. |

### Overall Assessment

The submitted design is structurally sound and substantially satisfies the business requirements. It should proceed to implementation **with conditions**: implementation must enforce cross-row/cross-table rules such as approved-booking overlap prevention, unavailable-space booking prevention, and role restrictions; stakeholders should confirm the approval-decision history cardinality because the conceptual design is stricter than the logical design and stricter than the validation guardrail permits without explicit evidence.

---

# 3. Requirement Analysis Review

| Requirement Area | Review Result | Evidence |
|------|------|------|
| User Management | Complete | The Facility Manager summary requires user ID, full name, email, phone, role, department, and account status; analysis §4.1 and BR-01–BR-03 capture these. |
| Space Management | Complete | The source requires unique space code, name, type, building, floor, room, capacity, status, and usage policy; analysis §4.2 and BR-04–BR-06 capture these. |
| Facility Management | Complete | The source says each space may have several facilities and stores the list; analysis §4.3, relationship “Space has Facility,” and BR-07 capture this. |
| Booking Management | Complete | The source requires booking request space, requested times, purpose, expected participants, status, conflict prevention, and unavailable-space prevention; analysis §4.4 and BR-08–BR-13 capture these. |
| Approval Management | Complete | The source says approval may be required and decisions record staff member, time, note, and rejection reason when rejected; analysis §4.5 and BR-14–BR-16 capture these, including tagged derived `decision_outcome`. |
| Usage Session Management | Complete | The source requires check-in and completion facts; analysis §4.6, §5, and BR-17–BR-19 capture them and keep check-in/completion actors separate. |
| Maintenance Management | Complete with scoped ambiguities | The source requires related space, reporter, assigned staff, problem description, start/completion time, status, and result note; analysis §4.7 and BR-20–BR-23 capture them while leaving status lifecycle and role scope open. |
| Historical Data Management | Complete | The source says historical booking and maintenance records should be kept and staff can view histories/upcoming/maintenance/no-show records; analysis BR-24–BR-25 captures this and scopes authorization ambiguity. |

### Issues

No blocking issue was found in the requirement analysis. The analysis correctly avoided raw line-number citations and treated `Cancelled`/`No-show` transition triggers as scoped Business Workflow Open Questions, which is the expected handling under the reviewer instructions.

---

# 4. Conceptual Database Design Review

## Strengths

- Models all seven upstream entities: User, Space, Facility, Booking Request, Approval Decision, Usage Session, and Maintenance Record.
- Represents relationship-reference facts as relationships rather than attributes, including selected space, decision maker, check-in actor, completion actor, maintenance reporter, and assigned staff.
- Keeps distinct role-playing relationships separate: `CHECKED_IN_BY` vs `COMPLETED_BY`, and `REPORTED_BY` vs `ASSIGNED_TO`.
- Uses uniform Entity-A→Entity-B cardinality notation in conceptual §4.
- Carries forward upstream assumptions and Open Questions individually.

## Issues

| ID | Severity | Finding | Evidence | Recommendation |
|------|------|------|------|------|
| C-01 | Medium | `HAS_APPROVAL_DECISION` is over-restricted in the conceptual design as `Booking Request 1 to Approval Decision 0..1`. The source does not explicitly state “at most one decision per booking,” and the reviewer guardrail requires approval-decision history to remain possible unless stakeholders justify one-decision-per-booking. | Requirement evidence: the Facility Manager approval paragraph says “When a booking is approved or rejected, the system records the staff member who made the decision, the decision time, and a decision note,” but does not state only one decision may exist. Conceptual §4 row `HAS_APPROVAL_DECISION` says each Booking Request may have zero or one Approval Decision. Logical §1 records this as a design-stage discrepancy and keeps `APPROVAL_DECISION.booking_id` non-unique. | Before implementation, confirm whether full approval/audit history is required. If no explicit one-decision requirement exists, revise the conceptual cardinality in a future design iteration to allow `Booking Request 1 to Approval Decision 0..*` and keep the logical non-unique FK. |

---

# 5. Logical Database Design Review

## Strengths

- Every conceptual entity maps to a logical table: `USER_ACCOUNT`, `SPACE`, `FACILITY`, `BOOKING_REQUEST`, `APPROVAL_DECISION`, `USAGE_SESSION`, and `MAINTENANCE_RECORD`.
- The M:N `SPACE`–`FACILITY` relationship is resolved by `SPACE_FACILITY` with FKs to both parents and a uniqueness constraint on the pair.
- Every table has a named surrogate `INT IDENTITY` primary key; natural keys `user_id` and `unique_space_code` are demoted and protected with named UNIQUE constraints.
- Every FK column is `INT` and references a surrogate `INT` PK; no FK targets a demoted natural key.
- Candidate keys are handled: `UQ_USER_ACCOUNT_user_id`, `UQ_USER_ACCOUNT_email`, and `UQ_SPACE_unique_space_code` are present.
- In-row CHECK constraints are present for requested booking time order, usage-session time order, maintenance time order, participant non-negativity, and rejected-decision rejection reason.
- Every listed PK/FK/UQ/CK constraint is explicitly named.
- Every FK declares explicit `ON DELETE` and `ON UPDATE` actions with consistent reasoning: `SPACE_FACILITY` cascades, historical/master references use `NO ACTION`, and all updates use `NO ACTION` due to immutable surrogate keys.
- `APPROVAL_DECISION.booking_id` is intentionally non-unique, avoiding an unjustified one-decision-per-booking restriction at the logical level.

## Issues

| ID | Severity | Finding | Evidence | Recommendation |
|------|------|------|------|------|
| L-01 | Medium | The logical design intentionally diverges from conceptual `HAS_APPROVAL_DECISION` cardinality to preserve audit history. This is the right implementation-safe direction, but the discrepancy must be resolved for documentation consistency. | Conceptual §4 states `HAS_APPROVAL_DECISION` as `1 to 0..1`; logical §1 records this discrepancy and §2.6 states `APPROVAL_DECISION.booking_id` is “plain non-unique” and intentionally not unique. | Treat this as a condition before DDL finalization: either update the conceptual design in a later iteration to match decision-history preservation, or obtain explicit stakeholder confirmation that only one decision per booking is permitted and then add a named unique constraint. |
| L-02 | Medium | Several core business rules are not enforceable by ordinary relational constraints and must be implemented in the DDL/application transaction layer. | Requirement evidence: BR-11/BR-12 require preventing conflicting and overlapping approved bookings; BR-13/BR-23 require preventing booking unavailable spaces; BR-15/BR-17/BR-19 constrain staff roles. Logical §4 classifies these as SQL Server implementation logic. | Implement and test triggers, stored procedures, or transaction-safe service logic for overlap prevention, unavailable-space booking prevention, approval-maker role checks, and check-in/completion role checks. |
| L-03 | Low | Some allowed-value and workflow constraints remain intentionally open because the source does not define the values or triggers. This is not a defect, but it is a clarification dependency. | Analysis §13 and logical §6 carry Open Questions for user account status values, maintenance status values/transitions, cancellation/no-show triggers, capacity comparison, and staff-view authorization scope. | Keep these as stakeholder clarification items. Do not add CHECK constraints or transition rules until requirements are confirmed. |

---

# 6. Required Validation Areas Checklist

| Area | Result | Evidence / Comment |
|---|---|---|
| 1. Requirement coverage | Pass | BR-01–BR-25 cover the Facility Manager summary. |
| 2. Actor coverage | Pass | Student, Lecturer, Teaching Assistant, Facility Staff, Department Administrator, Facility Manager appear in analysis §3 and role CHECK. |
| 3. Entity coverage | Pass | All major source entities are represented through seven conceptual entities and logical tables. |
| 4. Attribute coverage | Pass | Source attributes are mapped to conceptual attributes and logical columns; no `facility_description` or booking-level `rejection_reason` invented. |
| 5. Relationship coverage | Pass | Eleven conceptual relationships are mapped in logical §3. |
| 6. Cardinality correctness | Conditional | Most cardinalities are correct and conceptual notation is uniform A→B; approval-decision cardinality is over-restricted in conceptual design (C-01). |
| 7. Participation constraints | Pass with condition | Participation is documented bidirectionally; approval-decision participation needs confirmation due C-01. |
| 8. Primary keys | Pass | Every logical table has a named surrogate `INT IDENTITY` PK. |
| 9. Foreign keys | Pass | Every FK column is `INT` and references a surrogate `INT` parent PK. |
| 10. Candidate keys | Pass | `user_id`, `email`, and `unique_space_code` have named UNIQUE constraints. |
| 11. Key constraints | Pass | PK/UQ/FK naming is complete; no unsupported uniqueness on facility name, space name, or approval booking FK. |
| 12. Business rule enforcement | Conditional | Ordinary constraints cover keys/enums/in-row rules; cross-row/cross-table rules require implementation logic. |
| 13. SQL implementation risks | Pass | Logical §4 and §6 identify overlap, unavailable-space, role, lifecycle, and capacity risks. |
| 14. Assumptions and unresolved questions | Pass | Assumptions and Open Questions are carried forward individually. |
| 15. Simple in-row CHECK constraints | Pass | `CK_BOOKING_REQUEST_requested_time_order`, `CK_USAGE_SESSION_actual_time_order`, `CK_MAINTENANCE_RECORD_time_order`, and `CK_APPROVAL_DECISION_rejection_reason` are present. |
| 16. Constraint-strength vs source | Pass | Note fields such as `decision_note`, `usage_notes`, and `result_note` are nullable; values are not made stronger than source evidence. |
| 17. Consistent inference labeling | Pass | `decision_outcome` is tagged as derived in analysis/conceptual assumptions and carried consistently. |
| 18. FK referential actions | Pass | All FKs include explicit `ON DELETE`/`ON UPDATE` actions and reasoning. |
| 19. Constraint naming completeness | Pass | All PK/FK/UQ/CK constraints are named; rejected-decision rule is a named CHECK. |
| 20. Approval-decision cardinality | Conditional | Logical design correctly avoids UNIQUE on `APPROVAL_DECISION.booking_id`; conceptual cardinality must be corrected or justified. |
| 21. Cancelled/No-show classification | Pass | Missing triggers are accepted as scoped Open Questions, not reported as a data-modeling defect. |
| 22. Surrogate-INTEGER PK standardization | Pass | Every table uses surrogate `INT` PKs; natural identifiers are demoted and unique; FKs target surrogate PKs. |

---

# 7. Business Rule Enforcement Matrix

| Business Rule | Requirement Evidence | Covered in Analysis | Modeled in ERD | Represented in Logical Schema | Enforced in DDL | Risk Level | Recommendation |
|---|---|---|---|---|---|---|---|
| BR-01 User account required | Facility Manager user paragraph: each user must have a university account. | Yes | User entity | `USER_ACCOUNT` PK, `user_id`, `email` | Not yet; DDL pending | Low | Implement PK/UQ constraints as specified. |
| BR-02 Store user info | Same paragraph lists user ID, name, email, phone, role, department, status. | Yes | User attributes | `USER_ACCOUNT` columns | Not yet | Low | Implement columns and role/account constraints as documented. |
| BR-03 User roles | Same paragraph lists six roles. | Yes | User `role` | `CK_USER_ACCOUNT_role` | Not yet | Low | Implement named CHECK. |
| BR-04 Manage bookable spaces | Facility Manager space paragraph says School manages many bookable spaces. | Yes | Space entity | `SPACE` table | Not yet | Low | Implement table. |
| BR-05 Store space details | Space paragraph lists unique code, name, type, building, floor, room, capacity, status, usage policy. | Yes | Space attributes | `SPACE` columns; `UQ_SPACE_unique_space_code` | Not yet | Low | Implement columns and unique code. |
| BR-06 Space statuses | Space paragraph lists available, in use, under maintenance, temporarily closed, retired. | Yes | Space `current_status` | `CK_SPACE_current_status` | Not yet | Low | Implement named CHECK. |
| BR-07 Space facilities | Facilities paragraph says each space may have several facilities and stores list. | Yes | M:N Space–Facility | `SPACE_FACILITY` with FKs and UQ pair | Not yet | Low | Implement junction table. |
| BR-08 Submit booking | Booking paragraph lists selected space, requested times, purpose, expected participants. | Yes | User–Booking and Space–Booking relationships | `BOOKING_REQUEST` FKs and columns | Not yet | Low | Implement FKs and in-row time CHECK. |
| BR-09 Booking purpose values | Booking paragraph lists lecture, examination, seminar, workshop, meeting, student activity, administrative event. | Yes | Booking attribute | `CK_BOOKING_REQUEST_purpose_of_use` | Not yet | Low | Implement named CHECK. |
| BR-10 Booking statuses | Booking paragraph lists pending, approved, rejected, cancelled, checked in, completed, no-show. | Yes | Booking attribute | `CK_BOOKING_REQUEST_booking_status` | Not yet | Medium | Implement CHECK; do not invent cancelled/no-show transitions. |
| BR-11 Prevent conflicts | Booking paragraph says system must prevent conflicting bookings. | Yes | Booking times + selected Space | Classified as implementation logic | Not yet | High | Implement trigger/procedure/transaction rule. |
| BR-12 No overlapping approved bookings | Booking paragraph says same space cannot have two approved overlapping bookings. | Yes | Space–Booking + requested times/status | Classified as implementation logic | Not yet | High | Enforce with SQL Server trigger/procedure or transaction-safe service logic. |
| BR-13 Cannot book unavailable spaces | Booking paragraph says under maintenance, closed/retired spaces cannot be booked; status list uses temporarily closed. | Yes | Space status + Booking relationship | Classified as cross-table implementation logic | Not yet | High | Enforce during insert/update/approval. |
| BR-14 Approval may be required | Approval paragraph says booking may require approval from facility staff or manager. | Yes | Booking–Approval and User–Decision | Optional `APPROVAL_DECISION`; approval-required criteria open | Not yet | Medium | Clarify approval criteria; implement role check. |
| BR-15 Store decision maker/time/note | Approval paragraph says approved/rejected decisions record staff member, time, note. | Yes | Approval Decision + User makes decision | `APPROVAL_DECISION` columns and FK | Not yet | Medium | Implement columns/FK and role validation. |
| BR-16 Rejection reason if rejected | Approval paragraph says rejection reason should be stored if rejected. | Yes | Approval Decision `rejection_reason` | `CK_APPROVAL_DECISION_rejection_reason` | Not yet | Low | Implement named CHECK exactly. |
| BR-17 Facility staff check in | Usage paragraph says facility staff can check in booking. | Yes | User checks in Usage Session | `USAGE_SESSION.checked_in_by_user_account_id` FK; role logic required | Not yet | Medium | Implement Facility Staff role check. |
| BR-18 Store check-in details | Usage paragraph lists actual start, check-in person, initial condition. | Yes | Usage Session attributes + CHECKED_IN_BY | `USAGE_SESSION` columns/FK | Not yet | Low | Implement columns/FK. |
| BR-19 Store completion details | Usage paragraph lists actual end, final condition, usage notes. | Yes | Usage Session attributes + COMPLETED_BY | nullable completion columns, FK, time CHECK | Not yet | Medium | Implement completion role and consistency checks. |
| BR-20 Maintenance management | Maintenance paragraph says system supports basic maintenance management. | Yes | Maintenance Record entity | `MAINTENANCE_RECORD` table | Not yet | Low | Implement table. |
| BR-21 Maintenance problems | Maintenance paragraph gives problem examples. | Yes | Maintenance Record `problem_description` | `problem_description` column | Not yet | Low | Implement column without over-constraining examples. |
| BR-22 Store maintenance record details | Maintenance paragraph lists related space, reporter, assigned staff, description, times, status, result note. | Yes | Maintenance relationships and attributes | FKs and columns; time CHECK | Not yet | Medium | Implement FKs; clarify status values/role scope. |
| BR-23 Space under maintenance cannot be booked | Maintenance paragraph repeats under-maintenance booking prohibition. | Yes | Space status + Booking | Cross-table implementation logic | Not yet | High | Enforce with BR-13 unavailable-space rule. |
| BR-24 Preserve history | History paragraph says keep booking and maintenance history. | Yes | Booking/Approval/Usage/Maintenance entities | Historical tables; FK `ON DELETE NO ACTION` | Not yet | Medium | Implement deletion restrictions. |
| BR-25 Staff views | History paragraph says staff view booking history, upcoming bookings, spaces under maintenance, no-show bookings. | Yes | Data entities support views | Query/view support possible; authorization scope open | Not yet | Medium | Implement views/queries and clarify staff scope. |

---

# 8. Requirement Coverage Matrix

| Requirement | Conceptual Coverage | Logical Coverage | Validation Result |
|------|------|------|------|
| User accounts and roles | User entity and attributes | `USER_ACCOUNT`, role CHECK, user/email UQ | Covered |
| Space details and status | Space entity and attributes | `SPACE`, status CHECK, unique space code | Covered |
| Facilities in spaces | Space–Facility M:N | `SPACE_FACILITY` junction | Covered |
| Booking requests | User–Booking and Space–Booking relationships | `BOOKING_REQUEST` with requester/space FKs | Covered |
| Booking conflicts and unavailable spaces | Represented conceptually by Space/Booking/time/status | Classified as implementation logic | Covered with implementation condition |
| Approval decisions | Approval Decision entity and relationships | `APPROVAL_DECISION` with decision-maker FK and checks | Covered with cardinality clarification condition |
| Usage sessions | Usage Session entity and distinct role relationships | `USAGE_SESSION` with distinct check-in/completion FKs | Covered |
| Maintenance records | Maintenance Record entity and relationships | `MAINTENANCE_RECORD` with space/reporter/assignee FKs | Covered with status/role open questions |
| Historical records and staff views | Historical entities retained | `ON DELETE NO ACTION` choices; views deferred | Covered with implementation condition |

---

# 9. Recommendations

| Priority | Recommendation | Related Issue(s) |
|------|------|------|
| High | In the DDL stage, implement and test cross-row/cross-table rules: approved booking overlap prevention, unavailable-space booking prevention, approval-maker role restriction, and check-in/completion role restriction. | L-02 |
| Medium | Resolve approval-decision cardinality. Unless stakeholders explicitly require one decision per booking, keep logical `APPROVAL_DECISION.booking_id` non-unique and update future conceptual documentation to `1 to 0..*`. | C-01, L-01 |
| Medium | Clarify maintenance status values/transitions, active maintenance-to-space-status synchronization, capacity comparison, account status values, and staff-view authorization scope before adding further constraints. | L-03 |
| Low | Preserve the current constraint naming, surrogate-key, FK action, and nullable-note discipline during DDL implementation. | General |

---

# 10. Final Conclusion

## Final Decision

**ACCEPTED WITH CONDITIONS**

### Conclusion

The submitted requirement analysis, conceptual design, and logical design cover the core business requirements for campus space booking, approval, usage, maintenance, facilities, and history. The logical design is implementation-ready in structure: it uses surrogate `INT` keys, type-matched FKs, named constraints, in-row CHECK constraints, evidence-based uniqueness, and explicit referential actions. The design should proceed to database implementation only with the conditions that cross-row/cross-table rules are implemented in SQL Server or transaction-safe application logic, and the approval-decision history cardinality is clarified or corrected in documentation.
