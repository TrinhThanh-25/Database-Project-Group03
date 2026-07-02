# Database Design Validation Report - G03

## 1. Introduction

**Review date:** 2026-07-02  
**Reviewer:** gpt-5.5 database-design-reviewer agent  
**Final decision:** **ACCEPTED WITH CONDITIONS**

### Inputs Reviewed

Reviewed in the required order:

1. `req/business-requirement.md`
2. `outputs/01-business-req-analysis-G03.md`
3. `outputs/02-erd-design-G03.md`
4. `outputs/03-logical-design-G03.md`

### Review Objective

Provide an objective validation of the submitted database design by comparing the requirement analysis, conceptual database design, and logical database design against the original business requirements. This review identifies strengths, gaps, risks, and recommendations without modifying the submitted design.

---

## 2. Summary of Findings

| Reviewed Artifact | Grade | Summary |
|---|---:|---|
| Business Requirement Analysis | A- | Correctly separates Layer A context from the Facility Manager requirement summary, captures major actors, entities, relationships, business rules, assumptions, and open questions. Cancelled/no-show transitions are correctly scoped as open questions, and no fabricated booking type/category attribute is present. |
| Conceptual Database Design | A- | Covers all analysis entities and 19 conceptual relationships, including the `HAS_DECISION_OUTCOME` relationship to `BOOKING_STATUS`. Cardinality notation is uniformly A→B, single-actor relationships cap each event at one actor, and the singleton `BOOKING_REQUEST` → `USAGE_SESSION` decision is consistently carried forward. |
| Logical Database Design | B+ | Strong surrogate-`INT` PK standardization, named constraints, type-matched FKs, explicit referential actions, lookup-table normalization, and correct distinction between non-unique approval decisions and unique usage sessions. The main condition is to resolve the placeholder in `CK_APPROVAL_DECISION_rejection_reason` before implementation. |

### Overall Assessment

The design is mostly correct, traceable, and suitable to proceed to implementation planning. Important implementation conditions remain for Phase 2 rules: overlapping approved booking prevention, unavailable-space booking prevention, role restrictions, maintenance status synchronization, and rejected-decision reason enforcement. The only material logical-design issue found is that the rejected-decision CHECK is named and conceptually present, but contains a placeholder that cannot be implemented as-is until the rejected status lookup value is resolved.

---

## 3. Requirement Analysis Review

| Requirement Area | Review Result | Evidence |
|---|---|---|
| User Management | Covered | The source says each user must have a university account and stores user ID, name, email, phone, role, department, and account status. The analysis captures `USER_ACCOUNT`, `ROLE`, `ACCOUNT_STATUS`, `DEPARTMENT`, BR-01, and BR-02. |
| Space Management | Covered | The source stores unique space code, name, type, building, floor, room number, capacity, current status, and usage policy. The analysis captures `SPACE`, `SPACE_STATUS`, BR-03, and BR-04. |
| Facility Management | Covered | The source says each space may have several facilities and stores the list. The analysis captures `FACILITY` and `SPACE has FACILITY` with `0..* — 0..*`. |
| Booking Management | Covered | The source states users submit booking requests with selected space, requested start/end, purpose of use, and expected participants; the analysis captures these in `BOOKING_REQUEST`, BR-06, and BR-07. |
| Approval Management | Covered | The source says approval may be by facility staff or manager and records decision maker, time, note, and rejection reason if rejected. The analysis captures `APPROVAL_DECISION`, decision maker, decision outcome, note, time, and rejection reason. |
| Usage Session Management | Covered | The source states facility staff check in and complete bookings, recording actual times, conditions, and notes. The analysis captures `USAGE_SESSION`, `checks_in`, and `completes`. |
| Maintenance Management | Covered | The source says a space may have maintenance records storing related space, reporter, assigned staff, description, times, status, and result note. The analysis captures `MAINTENANCE_RECORD` and `MAINTENANCE_STATUS`. |
| Historical Data Management | Covered | The source says historical records of bookings and maintenance should be kept; analysis BR-20 captures this, and later logical FKs use restrictive delete actions. |

### Required Analysis Checks

- **Cancelled/no-show transitions:** Accepted handling. The analysis lists cancelled/no-show as status values but does not assert unsupported transitions; it carries both as scoped Business Workflow open questions.
- **Duplicate value-list/fabricated attribute scan:** Passed. `BOOKING_REQUEST` has exactly `purpose of use` with lecture/examination/seminar/workshop/meeting/student activity/administrative event values; no booking type/category attribute appears.
- **Inferred/proposed labeling:** Passed. Proposed identifiers, design directives, singleton usage-session cardinality, and derived `decision_outcome` are visibly labeled and recorded as assumptions.

### Requirement Analysis Issues

No blocking issue was found in the requirement analysis.

---

## 4. Conceptual Database Design Review

### Strengths

- Models all 13 analysis entities: user, department, lookup entities, space, facility, booking, approval decision, usage session, and maintenance record.
- Uses Chen-style Mermaid flowchart notation split into overview and per-entity diagrams as required by the conceptual agent.
- Represents all 19 conceptual relationships, including separate role-playing relationships: `CHECKS_IN`, `COMPLETES`, `REPORTS`, `ASSIGNED_TO`, and `MAKES_DECISION`.
- Correctly keeps `APPROVAL_DECISION` accumulating (`BOOKING_REQUEST 0..* — APPROVAL_DECISION 1..1`) and keeps `USAGE_SESSION` singleton (`BOOKING_REQUEST 0..1 — USAGE_SESSION 1..1`).
- Applies the authorized design directive for `DEPARTMENT` and controlled-vocabulary entities, including `APPROVAL_DECISION has_decision_outcome BOOKING_STATUS`.

### Conceptual Required Validation Areas

| Area | Result | Evidence |
|---|---|---|
| Entity coverage | Pass | §3 lists all analysis entities and diagrams show the same set. |
| Attribute coverage | Pass | Per-entity definitions preserve source attributes; relationship-reference facts are modeled as relationships. |
| Relationship coverage | Pass | §4 has 19 relationship rows matching analysis §5. |
| Cardinality correctness / A→B order | Pass | Conceptual §4 states Entity A and Entity B then uses the same A→B order in each cardinality. |
| Participation constraints | Pass | Optional vs mandatory participation is explicitly stated in §4 participation text. |
| Single-actor cardinality sweep | Pass | Decision maker, check-in, completion, reporter, and assignee relationships all have at most one actor per event occurrence. |
| Singleton-by-nature consistency | Pass | Usage session is `0..1` per booking and is carried forward as an assumption; this must be realized as a unique FK downstream. |

### Conceptual Issues

No blocking issue was found in the conceptual design.

---

## 5. Logical Database Design Review

### Strengths

- Every table uses a named surrogate `INT IDENTITY` primary key, and every FK is an `INT` targeting a surrogate `INT` PK.
- `user_id` and `unique_space_code` are preserved as demoted natural keys with named `UNIQUE` constraints; `email` is also treated as a named candidate key.
- `SPACE_FACILITY` resolves the conceptual M:N relationship with two FKs and a named uniqueness constraint for the pair.
- `APPROVAL_DECISION.booking_request_id` is deliberately non-unique, preserving decision history as required by the conceptual `0..*` cardinality.
- `USAGE_SESSION.booking_request_id` is unique, correctly realizing the resolved singleton usage-session relationship.
- Start/end time pairs have named ordering checks: requested booking time, actual session time, and maintenance time.
- Foreign keys include explicit `ON DELETE` and `ON UPDATE` actions with a consistent criterion.
- Closed vocabularies are implemented as lookup tables, and open descriptive catalogs are left unconstrained with a stated reason.

### Logical Required Validation Areas

| Area | Result | Evidence |
|---|---|---|
| Primary keys | Pass | Every table section lists `PK_...` over an `INT IDENTITY(1,1)` key. |
| Foreign keys and FK type matching | Pass | Each FK column is `INT` and references a surrogate `INT` PK; no FK targets `user_id` or `unique_space_code`. |
| Candidate keys | Pass | `UQ_USER_ACCOUNT_user_id`, `UQ_USER_ACCOUNT_email`, and `UQ_SPACE_unique_space_code` are present. |
| Key constraints | Pass | PK, FK, UQ, and CK constraints are named throughout. |
| In-row CHECK constraints | Pass | `CK_BOOKING_REQUEST_requested_time_order`, `CK_USAGE_SESSION_actual_time_order`, and `CK_MAINTENANCE_RECORD_time_order` are present. |
| Constraint strength vs source | Mostly pass | Optional/lifecycle notes such as `decision_note`, `usage_notes`, `result_note`, and completion fields are nullable. The email uniqueness is explicitly recorded as a logical-stage assumption. |
| FK referential actions | Pass | Each FK lists explicit `ON DELETE` and `ON UPDATE`; the criteria are documented in §2.0. |
| Approval-decision cardinality | Pass | `APPROVAL_DECISION.booking_request_id` is explicitly non-unique. |
| Singleton usage-session realization | Pass | `UQ_USAGE_SESSION_booking_request_id` correctly implements one usage session per booking. |
| Authorized directives | Pass | `DEPARTMENT`, `ROLE`, `ACCOUNT_STATUS`, `SPACE_STATUS`, `BOOKING_STATUS`, and `MAINTENANCE_STATUS` exist with owning-table `INT` FKs. |

### Logical Issues

| ID | Severity | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| L-01 | Medium | The rejected-decision reason rule is named, but the logical CHECK contains an unresolved placeholder and is not directly implementable as written. | Logical §2.11 defines `CONSTRAINT CK_APPROVAL_DECISION_rejection_reason CHECK (decision_outcome_booking_status_id <> <BOOKING_STATUS_ID_FOR_REJECTED> OR ...)`. Logical §2.11 also states the placeholder must be resolved after lookup seed values are fixed. The source approval paragraph / BR-14 requires storing a rejection reason if rejected. | Before DDL implementation, replace the placeholder with a deterministic implementation: fixed seeded ID, stable `status_code`, filtered/persisted-code pattern, or Phase 2 trigger. Keep the named constraint or a Phase 2 comment block so the rejected⇒reason rule remains traceable. |

---

## 6. Business Rule Enforcement Matrix

| Business Rule | Requirement Evidence | Covered in Analysis | Modeled in ERD | Represented in Logical Schema | Enforced in DDL | Risk Level | Recommendation |
|---|---|---|---|---|---|---|---|
| User account and basic user information | Facility Manager user paragraph; BR-01 | Yes | `USER_ACCOUNT`, `ROLE`, `ACCOUNT_STATUS`, `DEPARTMENT` | Tables, FKs, `UQ_USER_ACCOUNT_user_id`, `UQ_USER_ACCOUNT_email` | DDL pending | Low | Seed lookup values and verify email uniqueness assumption with stakeholders. |
| User role values | Facility Manager user paragraph; BR-02 | Yes | `ROLE`, `HAS_ROLE` | `ROLE` table and FK | DDL pending | Low | Seed listed roles. |
| Space data and statuses | Facility Manager space paragraph; BR-03/BR-04 | Yes | `SPACE`, `SPACE_STATUS` | `SPACE`, `SPACE_STATUS`, FK, `UQ_SPACE_unique_space_code` | DDL pending | Low | Seed listed statuses. |
| Facility list per space | Facility paragraph; BR-05 | Yes | M:N `HAS_FACILITY` | `SPACE_FACILITY` junction | DDL pending | Low | Use cascade delete only for association rows as designed. |
| Booking submission details | Booking paragraph; BR-06/BR-07 | Yes | `BOOKING_REQUEST`, `SUBMITS`, `SELECTS` | Booking columns, FKs, purpose CHECK, time CHECK | DDL pending | Low | Implement as designed. |
| Booking status values | Booking status paragraph; BR-08 | Yes | `BOOKING_STATUS` | `BOOKING_STATUS` FK | DDL pending | Low | Seed statuses including cancelled and no-show; do not invent transitions. |
| Prevent conflicting approved bookings | Booking status paragraph; BR-09/BR-10 | Yes | Represented through booking-space-status-time relationships | Classified as implementation logic | Deferred to Phase 2 | High | Implement trigger/procedure/transaction rule for same-space approved booking overlap. |
| Do not book unavailable spaces | Booking status and maintenance paragraphs; BR-11/BR-19 | Yes | `SPACE_STATUS` and booking-space relationship | Classified as cross-table implementation logic | Deferred to Phase 2 | High | Enforce at booking creation/approval by checking current space status. |
| Approval required / approval decision history | Approval paragraph; BR-12/BR-13 | Yes | `HAS_APPROVAL_DECISION`, `MAKES_DECISION` | Non-unique FK from decisions to bookings; decision maker and outcome FKs | DDL pending | Medium | Preserve non-unique booking FK; clarify approval criteria. |
| Rejected booking stores rejection reason | Approval paragraph; BR-14 | Yes | `APPROVAL_DECISION.rejection_reason` | Named CHECK with unresolved rejected-status placeholder | Deferred / condition before DDL | Medium | Resolve L-01 before implementation. |
| Check-in details | Usage paragraph; BR-15 | Yes | `USAGE_SESSION`, `CHECKS_IN` | Mandatory check-in user FK and actual start/condition columns | DDL pending plus Phase 2 role check | Medium | Enforce facility-staff role in Phase 2 logic. |
| Completion details | Usage paragraph; BR-16 | Yes | `COMPLETES` | Optional completion user and completion columns; time CHECK | DDL pending plus Phase 2 role check | Medium | Enforce role and completion consistency in Phase 2. |
| Maintenance records | Maintenance paragraph; BR-17/BR-18 | Yes | `MAINTENANCE_RECORD`, status, reporter, assignee | Maintenance table, FKs, time CHECK | DDL pending | Medium | Clarify maintenance status values and assignment workflow. |
| Historical records | History paragraph; BR-20 | Yes | Historical entities retained | Restrictive `ON DELETE NO ACTION` on historical references | DDL pending | Low | Keep restrictive delete behavior. |
| Staff views of history/upcoming/maintenance/no-show | History paragraph; BR-21 | Yes | Data entities support views | Data supports queries; authorization scope open | Deferred to queries/authorization | Medium | Clarify which roles count as “Staff.” |

---

## 7. Requirement Coverage Matrix

| Requirement | Conceptual Coverage | Logical Coverage | Validation Result |
|---|---|---|---|
| User accounts, roles, departments, account status | `USER_ACCOUNT`, `ROLE`, `ACCOUNT_STATUS`, `DEPARTMENT` | Tables and FKs with candidate keys | Covered |
| Spaces and statuses | `SPACE`, `SPACE_STATUS` | Tables, FK, unique space code | Covered |
| Facilities in spaces | `SPACE`–`FACILITY` M:N | `SPACE_FACILITY` | Covered |
| Booking request data | `BOOKING_REQUEST`, `SUBMITS`, `SELECTS` | Booking table with FKs and checks | Covered |
| Booking conflict prevention | Relationships supply required data | Implementation logic identified | Covered with Phase 2 condition |
| Space unavailable booking prevention | Space status and booking relationship | Implementation logic identified | Covered with Phase 2 condition |
| Approval decisions | Approval decision, maker, outcome relationships | Decision table with non-unique booking FK | Covered with L-01 condition for rejection reason |
| Usage sessions | `USAGE_SESSION`, `CHECKS_IN`, `COMPLETES` | Usage table, unique booking FK, actor FKs | Covered |
| Maintenance records | `MAINTENANCE_RECORD`, status/reporter/assignee relationships | Maintenance table and FKs | Covered with open maintenance workflow questions |
| Historical data | Historical entities retained | Restrictive FK actions preserve history | Covered |
| Staff viewing needs | Data entities support required views | Query/authorization design deferred | Covered with authorization open question |

---

## 8. Recommendations

| Priority | Recommendation | Related Issue(s) |
|---|---|---|
| High | Implement Phase 2 logic for approved-booking overlap prevention and unavailable-space booking prevention before production use. | Business rules BR-09, BR-10, BR-11, BR-19 |
| Medium | Resolve `CK_APPROVAL_DECISION_rejection_reason` before DDL execution by fixing the rejected-status reference strategy. | L-01 |
| Medium | Clarify approval criteria, maintenance status values/transitions, maintenance assignment workflow, and generic “Staff” authorization scope. | Open Questions |
| Medium | Implement role checks for approval, check-in, completion, reporting, and assignment operations in triggers/procedures/application services as appropriate. | Role-permission rules |
| Low | Keep current naming and traceability conventions through DDL and sample data so validation remains easy. | General implementation readiness |

---

## 9. Final Conclusion

### Final Decision

**ACCEPTED WITH CONDITIONS**

### Conclusion

The submitted database design satisfies the business requirements at the analysis, conceptual, and logical levels with good traceability and generally strong relational design discipline. The design correctly preserves history, avoids fabricated booking type/category attributes, handles cancelled/no-show transitions as scoped open questions, applies authorized lookup-table directives, standardizes surrogate `INT` keys, and distinguishes the accumulating approval-decision relationship from the singleton usage-session relationship.

The design should proceed only with conditions: resolve the rejected-decision reason CHECK placeholder before DDL execution, and implement Phase 2 logic for overlap prevention, unavailable-space booking prevention, role restrictions, and workflow-dependent maintenance/booking rules.
