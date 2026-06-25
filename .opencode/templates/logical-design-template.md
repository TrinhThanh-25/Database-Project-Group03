# Logical Database Design Template - Group 03

Use this template for `outputs/03-logical-design-G03.md`.

## 1. Source Documents and Path Discrepancies

- Project routing contract read: `AGENTS.md`
- Logical designer definition read: `.opencode/agent/logical-database-designer.md`
- Required conceptual input per contract: `outputs/02-erd-design-G03.md`
- Actual conceptual input used: `outputs/02-erd-design-G03.md`
- Traceability input used: `outputs/01-business-req-analysis-G03.md`
- Target DBMS: Microsoft SQL Server
- Path discrepancies: `[None / describe mismatch]`

## 2. Relational Schema

Conventions:
- SQL Server data types are logical recommendations and may be refined during physical implementation.
- `NOT NULL` is used where the upstream conceptual design and business rules require the fact to exist at row creation.
- Nullable columns must be justified as optional, lifecycle-dependent, or unresolved.
- Do not add unsupported unique constraints or allowed-value CHECK constraints.

### 2.1 `[TABLE_NAME]`

[Short explanation of source entity and naming assumption, if any.]

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `[column_name]` | `[SQL Server type]` | `[NOT NULL/NULL]` | `[PK/FK/CHECK/UNIQUE/note]` | `[Conceptual attribute / relationship / BR ref]` |

Primary key:
- `CONSTRAINT [PK_NAME] PRIMARY KEY ([column])`

Foreign keys:
- `CONSTRAINT [FK_NAME] FOREIGN KEY ([column]) REFERENCES [PARENT_TABLE]([parent_column])`

Uniqueness constraints:
- `CONSTRAINT [UQ_NAME] UNIQUE ([column])`

CHECK constraints:
- `CONSTRAINT [CK_NAME] CHECK ([condition])`

Unresolved / implementation rules:
- [Cross-row, cross-table, role, lifecycle, or status-transition rule that cannot be enforced by ordinary PK/FK/UNIQUE/CHECK.]

Repeat this subsection for every logical table.

Required G03 tables expected from the conceptual design:
- `USER_ACCOUNT`
- `SPACE`
- `FACILITY`
- `SPACE_FACILITY`
- `BOOKING_REQUEST`
- `APPROVAL_DECISION`
- `USAGE_SESSION`
- `MAINTENANCE_RECORD`

## 3. Relationship Mapping

| Conceptual Relationship | Cardinality / Participation | Logical Mapping |
|---|---|---|
| `[RELATIONSHIP_NAME]` | `[source cardinality and participation]` | `[FK, unique FK, or junction table mapping]` |

Required mappings:
- `SUBMITS`
- `SELECTS_SPACE`
- `HAS_FACILITY`
- `HAS_APPROVAL_DECISION`
- `MAKES_DECISION`
- `HAS_USAGE_SESSION`
- `CHECKED_IN_BY`
- `COMPLETED_BY`
- `HAS_MAINTENANCE_RECORD`
- `REPORTED_BY`
- `ASSIGNED_TO`

## 4. Traceability from Requirements to Tables and Constraints

| Requirement / Rule | Logical Tables / Columns | Logical Treatment |
|---|---|---|
| `BR-[n]: [rule text]` | `[tables/columns/constraints]` | `[PK / FK / UNIQUE / CHECK / implementation logic / open question]` |

Mandatory business-rule classification:
- No overlapping approved bookings for the same space/time: `[treatment]`
- No booking for spaces under maintenance, temporarily closed, or retired: `[treatment]`
- Approval decision maker role restriction: `[treatment]`
- Check-in and completion role restrictions: `[treatment]`
- Rejected approval must store rejection reason: `[treatment]`
- Maintenance status handling and active-maintenance effect on availability: `[treatment]`
- Participant count versus space capacity: `[treatment]`

## 5. Assumptions Carried Forward

Every assumption must carry a source tag:
- `[upstream]` — carried forward from Step 1 or Step 2.
- `[logical-stage]` — introduced by the logical stage.

- [upstream] [Assumption text and source.]
- [logical-stage] [Logical naming, nullability, surrogate-key, or constraint assumption.]

## 6. Open Questions Carried Forward and Newly Raised

Carry forward unresolved questions individually. Do not merge multiple questions into one generic item.

- [Open question and affected table/rule.]
- [New logical-stage question, if any.]

## 7. Logical Design Self-Check Summary

This section is optional in the user-facing output only if the project owner requests it. Full self-check details must be logged in `.opencode/logging/self-check-log.md`, not in the output file.

- Entity-to-table coverage: `[PASS/FAIL]`
- Attribute coverage: `[PASS/FAIL]`
- Relationship mapping: `[PASS/FAIL]`
- Key and constraint naming: `[PASS/FAIL]`
- Business rule classification: `[PASS/FAIL]`
- Assumptions/open questions: `[PASS/FAIL]`
