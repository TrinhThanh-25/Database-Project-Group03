# Phase 2 Database Design Updater

## Role and ownership

Own only `outputs/09-updated-erd-and-logical-design-G03.md`. Integrate the Phase 2 ERD, logical schema, functional dependencies, and 3NF assessment in one artifact. Do not write migration, procedures, tests, generator SQL, analytical SQL, or indexes.

## Inputs

Read `AGENTS.md`, output 08 as the primary change contract, then outputs 02–05 as the Phase 1 conceptual/logical/implementation baseline. The raw Phase 2 requirement is only a traceability cross-check. Stop if output 08 is incomplete.

## Accepted compact design

Preserve all 14 Phase 1 relations. The current reviewed delta is intentionally small:

- add `BOOKING_STATUS.status_code`;
- add current `MAINTENANCE_RECORD.impact_level_id`;
- add `MAINTENANCE_IMPACT_LEVEL`, `MAINTENANCE_IMPACT_EVENT`, `BOOKING_ADVISORY_ACKNOWLEDGEMENT`, and `INSTANT_APPROVAL_SPACE_TYPE`;
- seed role `System` and one dedicated active system user, while preserving `APPROVAL_DECISION` as the approval-history relation.

Do not add `APPROVAL_METHOD`, semester master data, acknowledgement timestamps/messages/snapshots, configuration audit columns, retry tables, or lock tables unless a later user requirement explicitly requires them. Semester reports accept start/end parameters. Instant versus staff decisions are distinguished by the decision actor.

## Design semantics

- Current occupancy: `approved` and `checked_in`.
- Historical approval: existence of an approved `APPROVAL_DECISION`.
- Active/open maintenance: `Reported` or `In progress`; advisory additionally has current impact `advisory`.
- Half-open overlap: `existing.start < requested.end AND existing.end > requested.start`.
- Business `DATETIME2` values are Vietnam-local wall-clock values; defaults for system-generated values convert through `SE Asia Standard Time` and never store raw UTC in the same columns.
- Instant demo rule: configured text `SPACE.space_type` plus participants not exceeding capacity; never parse `usage_policy`.
- A booking acknowledges zero or many specific maintenance records; the pair is unique.
- Semester reports use scalar bounds, and a room must contain every requested facility; no semester or facility-condition extension is inferred.
- Impact events preserve baseline/current transitions and escalation time; a baseline event is not fabricated as a historical escalation.
- Approved non-overlap and cross-table temporal rules are implementation logic, never ordinary row `CHECK` claims.

## Required work and structure

Use the existing 15-section structure: metadata; conventions; Phase 1 inventory; updated entities; relationships; one canonical Mermaid `erDiagram`; complete relational definitions; named constraints/FKs; enforcement classification; FDs; 3NF proof; traceability; migration impact; assumptions; open questions; blocking checklist.

The ERD must contain every retained/new table and every physical FK. Logical matching from `SPACE.space_type` to the configuration table has no fabricated FK. For every relation, consider alternate keys and business FDs; do not use “surrogate PK therefore 3NF” as the proof.

## Blocking self-check

- Every Phase 1 relation is preserved and every new physical element is represented consistently in ERD, schema, constraints, FDs, and migration matrix.
- Output 09 contains only the compact delta above unless additional source evidence is cited.
- The design can reconstruct escalation time and individual advisory acknowledgement.
- Nullability/uniqueness/closed domains are not stronger than evidence.
- Every relation is assessed through 3NF and no cross-row rule is misrepresented as a row constraint.
- Accepted decisions are not left in Open Questions; genuine unknowns remain visible.

## Handoff

Output 10 must be able to implement the exact delta without inventing a structure, mapping, or lookup meaning.
