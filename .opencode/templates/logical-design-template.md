# Logical Database Design Template - Group 03

Use this template for `outputs/03-logical-design-G03.md`.

## 1. Introduction

This document presents the logical database design for the [System Name] project. The design is based on the conceptual schema and business requirements analyzed in the previous phase.

## 2. Relational Schema

Conventions:
- SQL Server data types are logical recommendations and may be refined during physical implementation.
- `NOT NULL` is used where the upstream conceptual design and business rules require the fact to exist at row creation.
- Nullable columns must be justified as optional, lifecycle-dependent, or unresolved.
- Do not add unsupported unique constraints or allowed-value CHECK constraints. In particular, do not add UNIQUE to a many-side (`0..*`) FK such as `APPROVAL_DECISION.booking_id` unless an explicit requirement forces one row per parent.
- Every table's primary key is a surrogate `INT` (`INT IDENTITY`). Any conceptual natural identifier (e.g. `user_id` student code, `unique_space_code`) is demoted to a regular attribute protected by a named `UNIQUE` constraint, and every foreign key references the parent's surrogate `INT` PK. State the surrogate-key reasoning once (storage/join efficiency and stability — natural-key corrections need no cascade because nothing FK-references them).
- Every `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, and `CHECK` constraint is named. Any conditional rule that is expressible as a single-row CHECK is written as a named CHECK (e.g. the rejected-reason rule), not left in prose.
- Every `FOREIGN KEY` declares an explicit `ON DELETE` and `ON UPDATE` action chosen by a consistent, documented criterion (state the criteria once, e.g. in a §2.0 subsection: junction associations `CASCADE` on delete; references to historical/master data `NO ACTION`/RESTRICT on delete; `ON UPDATE NO ACTION` uniformly, since all PKs are immutable `INT` surrogates).

### 2.1 `[TABLE_NAME]`

[Short explanation of source entity and naming assumption, if any.]

| Column | Data Type | Nullability | Constraints / Notes | Source |
|---|---:|---:|---|---|
| `[column_name]` | `[SQL Server type]` | `[NOT NULL/NULL]` | `[PK/FK/CHECK/UNIQUE/note]` | `[Conceptual attribute / relationship / BR ref]` |

Primary key (surrogate `INT IDENTITY`):
- `CONSTRAINT [PK_NAME] PRIMARY KEY ([surrogate_int_id_column])`

Foreign keys:
- `CONSTRAINT [FK_NAME] FOREIGN KEY ([column]) REFERENCES [PARENT_TABLE]([parent_column]) ON DELETE [action] ON UPDATE [action]` — `[criterion/reasoning for the chosen actions]`

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
- Surrogate `INT` PK standardization (natural keys demoted to named UNIQUE; FKs reference surrogate): `[PASS/FAIL]`
- Relationship mapping (many-side FKs left non-unique): `[PASS/FAIL]`
- Key and constraint naming (no prose-only in-row rule): `[PASS/FAIL]`
- FK referential actions (explicit, consistently reasoned): `[PASS/FAIL]`
- Business rule classification: `[PASS/FAIL]`
- Assumptions/open questions: `[PASS/FAIL]`
