# Evaluation Rubric — Database Definition (DDL) Implementation G03

## Purpose

This rubric is run by the implementation engineer agent as a mandatory self-check before delivering `outputs/05-db-definition-G03.sql` (see agent Workflow step 9), and can also be run by a human reviewer afterward. Every **Blocking** item must pass before delivery; **Advisory** items should be addressed but do not block delivery on their own.

## How to Score

For each check, mark **PASS**, **FAIL**, or **N/A** with a one-line justification. Any **FAIL** on a Blocking check means the output must be fixed and the rubric re-run before delivery.

---

## A. Table, Column, and Constraint Coverage (Blocking)

| # | Check | Pass Criteria |
|---|---|---|
| A1 | All 8 required tables are present and named correctly | `USER_ACCOUNT`, `SPACE`, `FACILITY`, `SPACE_FACILITY`, `BOOKING_REQUEST`, `APPROVAL_DECISION`, `USAGE_SESSION`, `MAINTENANCE_RECORD` all exist with exact names from the logical design. |
| A2 | Every column from the logical design is present on the correct table, with correct name, data type, and nullability | Cross-check each table in logical design §2 line by line; no column silently dropped, renamed, or type-changed; nullability not tightened or loosened without a documented `[ddl-stage]` assumption. |
| A3 | No invented column, table, or constraint is present | Every element in the DDL traces to a specific row in logical design §2 or §3. The only permitted DDL-stage addition is `IDENTITY(1,1)` on surrogate PKs, recorded as a `[ddl-stage]` assumption. |
| A4 | Every named PK, FK, UQ, and CHECK constraint from the logical design is present with the exact constraint name | All `PK_`, `FK_`, `UQ_`, `CK_` names match the logical design exactly. No CHECK added for columns the logical design marks "no allowed-value check; values not listed upstream" (e.g. `account_status`, `maintenance_status`). |
| A5 | Role-playing FK columns are kept separate | `checked_in_by_user_id` / `completed_by_user_id` on `USAGE_SESSION` and `reported_by_user_id` / `assigned_to_user_id` on `MAINTENANCE_RECORD` are distinct FK columns — not merged into one. |

---

## B. Implementation-Logic Stubs and Open Questions (Blocking)

| # | Check | Pass Criteria |
|---|---|---|
| B1 | All 7 mandatory implementation-logic stubs are present | A trigger stub or `-- IMPLEMENTATION REQUIRED` block exists for each rule below, placed immediately after the relevant table DDL. Missing any one stub is a FAIL. Rules: (1) approved-booking overlap BR-8/9 after `BOOKING_REQUEST`; (2) unavailable-space booking BR-10/20 after `BOOKING_REQUEST`; (3) approver role restriction BR-11/12 after `APPROVAL_DECISION`; (4) rejection-reason conditional BR-13 after `APPROVAL_DECISION`; (5) check-in role restriction BR-14 after `USAGE_SESSION`; (6) completion role restriction BR-16 after `USAGE_SESSION`; (7) completion-consistency BR-16/17 after `USAGE_SESSION`. |
| B2 | Every open question from logical design §6 has a `-- OPEN QUESTION` comment block at the relevant table and is listed in the file header | No open question is silently dropped or silently resolved by adding a constraint or trigger not authorised by the logical design. |

---

## C. Assumptions and Traceability (Blocking)

| # | Check | Pass Criteria |
|---|---|---|
| C1 | All upstream assumptions are carried forward and all DDL-stage assumptions are documented in the file header | The SQL file header contains `[upstream]`-tagged and `[ddl-stage]`-tagged assumption comments. No assumption is implicit. |
| C2 | Table creation order respects FK dependencies | Tables are created in dependency order (parents before children): `USER_ACCOUNT` → `SPACE` → `FACILITY` → `SPACE_FACILITY` → `BOOKING_REQUEST` → `APPROVAL_DECISION` → `USAGE_SESSION` → `MAINTENANCE_RECORD`. Any deviation is documented as a `[ddl-stage]` assumption. |

---

## D. SQL Server Syntax (Advisory)

| # | Check | Pass Criteria |
|---|---|---|
| D1 | `GO` batch separators used correctly | `GO` appears after each `CREATE TABLE`, `ALTER TABLE`, trigger, and index block. |
| D2 | Text columns use `NVARCHAR`; date-time columns use `DATETIME2(0)` | No `VARCHAR` without `N` prefix; no deprecated `DATETIME` type. |
| D3 | Trigger stubs are syntactically valid SQL Server shells | Each trigger stub can be parsed by SQL Server without error even if the body is a placeholder `RAISERROR` / `ROLLBACK`. |
| D4 | Script is idempotent or includes a documented drop/recreate sequence | Script checks object existence before creating (`IF NOT EXISTS`) or opens with a documented drop block. |

---

## Self-Check Execution Log

Write the completed self-check to `.opencode/logging/self-check-log.md`.

```text
Run date: [date]
Run time: [time]
Run by: [agent / human reviewer]
Output file: outputs/05-db-definition-G03.sql

A1-A5: [PASS/FAIL each] — [note]
B1-B2: [PASS/FAIL each] — [note]
C1-C2: [PASS/FAIL each] — [note]
D1-D4: [PASS/FAIL/N/A each] — [note]

Blocking failures remaining: [list, or "none"]
Delivery status: [READY / NOT READY]
```