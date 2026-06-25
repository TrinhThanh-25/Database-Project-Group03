# Evaluation Rubric - Logical Database Design G03

Use this rubric to evaluate `outputs/03-logical-design-G03.md`.

## Purpose

This rubric is a mandatory self-check for the logical database design stage and can also be used by a human reviewer. Every Blocking item must pass before the logical design is considered ready for implementation.

## How to Score

For each check, mark **PASS**, **FAIL**, or **N/A** with a short justification. Any **FAIL** on a Blocking check means the output must be fixed before proceeding to `outputs/04-design-validation-G03.md` or `outputs/05-db-definition-G03.sql`.

## A. Source and Workflow Discipline (Blocking)

| # | Check | Pass Criteria |
|---|---|---|
| A1 | Repository discovery was performed first | `ls -la` was run from the project root before assuming files exist. |
| A2 | Correct primary input was used | Logical design uses `outputs/02-erd-design-G03.md` as the primary input. |
| A3 | Traceability input was used only for checks | `outputs/01-business-req-analysis-G03.md` is used for traceability, assumptions, and open questions, not to redesign from scratch. |
| A4 | Path discrepancies are documented | Any missing or mismatched expected path is explicitly recorded. |
| A5 | Output path is correct | Final logical design is saved as `outputs/03-logical-design-G03.md`. |

## B. Entity, Attribute, and Table Coverage (Blocking)

| # | Check | Pass Criteria |
|---|---|---|
| B1 | Every conceptual entity has a table | User, Space, Facility, Booking Request, Approval Decision, Usage Session, and Maintenance Record are mapped to logical tables. |
| B2 | M:N relationships are resolved | `SPACE` to `FACILITY` is resolved through `SPACE_FACILITY` or another justified associative table. |
| B3 | Every conceptual attribute is represented exactly once where appropriate | Attributes appear as columns on the correct table unless intentionally omitted with an explicit upstream issue. |
| B4 | No unsupported attributes are invented | Columns are traceable to conceptual attributes, relationship FKs, surrogate identifiers, or justified implementation support. |
| B5 | Relationship-reference facts are modeled as FKs | Requester, selected space, decision maker, check-in user, completion user, maintenance reporter, and assigned staff are modeled as FKs. |

## C. Keys, Relationships, and Constraints (Blocking)

| # | Check | Pass Criteria |
|---|---|---|
| C1 | Every table has a named primary key | Each table lists a `PK_...` constraint. |
| C2 | Every relationship has a named FK, unique FK, or junction mapping | All conceptual relationships are represented in Section 3. |
| C3 | Optional 1:0..1 relationships use unique FKs | Approval Decision and Usage Session mappings enforce at most one row per booking. |
| C4 | Role-playing relationships use distinct columns | Check-in/completion and reporter/assignee roles are not collapsed into one FK. |
| C5 | Allowed-value CHECK constraints are evidence-based | CHECK values are used only when listed upstream. |
| C6 | Unsupported uniqueness is not invented | Email, facility name, space name, and room location are not unique unless source evidence supports it. |
| C7 | Nullability is justified | Nullable columns are optional, lifecycle-dependent, or explicitly open questions. |

## D. Business Rule Classification (Blocking)

| # | Check | Pass Criteria |
|---|---|---|
| D1 | Approved-booking overlap rule is classified | The design states that same-space overlapping approved bookings require SQL Server implementation logic. |
| D2 | Unavailable-space booking rule is classified | The design states that under-maintenance, temporarily closed/closed, and retired spaces require cross-table implementation logic. |
| D3 | Role restrictions are classified | Approval, check-in, completion, and maintenance role rules are classified as implementation logic or open questions. |
| D4 | Rejection reason rule is classified | Rejection reason is conditionally required and the enforcement method is documented. |
| D5 | Maintenance status ambiguity is preserved | Maintenance status values/transitions and active-maintenance synchronization are open questions if not specified upstream. |
| D6 | Capacity comparison is not invented | Participant count versus space capacity is an open question unless the source explicitly requires enforcement. |
| D7 | Status lifecycle rules are not overclaimed | Booking status transitions beyond upstream evidence are open questions or implementation rules. |

## E. Traceability, Assumptions, and Open Questions (Blocking)

| # | Check | Pass Criteria |
|---|---|---|
| E1 | BR-1 through BR-22 are traced | Each business rule maps to table/column/constraint/implementation/open-question treatment. |
| E2 | Assumptions are explicit | Upstream and logical-stage assumptions are listed separately or tagged clearly. |
| E3 | Open questions are carried forward | Unresolved questions from Step 1 and Step 2 are not silently dropped. |
| E4 | No unsupported business rule is asserted | Ambiguous requirements are not converted into hard constraints without source evidence. |

## F. SQL Server Readiness (Advisory)

| # | Check | Pass Criteria |
|---|---|---|
| F1 | Data types are SQL Server compatible | Uses `INT`, `NVARCHAR`, `DATETIME2`, etc. |
| F2 | Implementation risks are actionable | Trigger/procedure/transaction/API enforcement needs are concrete enough for DDL stage. |
| F3 | Naming is consistent | Table, column, PK, FK, UQ, and CK names follow a consistent convention. |

## Self-Check Execution Log

Write the completed self-check to `.opencode/logging/self-check-log.md`, not inside the final output file.

```text
Run date: [date]
Run time: [time]
Run by: [agent / human reviewer]

A1-A5: [PASS/FAIL each] — [note]
B1-B5: [PASS/FAIL each] — [note]
C1-C7: [PASS/FAIL each] — [note]
D1-D7: [PASS/FAIL each] — [note]
E1-E4: [PASS/FAIL each] — [note]
F1-F3: [PASS/FAIL/N/A each] — [note]

Blocking failures remaining: [list, or "none"]
Delivery status: [READY / NOT READY]
```
