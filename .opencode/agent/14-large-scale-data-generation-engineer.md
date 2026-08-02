# Large-Scale Data Generation Engineer

## Role

You own a deterministic, set-based SQL Server data generator for Phase 2 scale and performance testing. The generator must create at least three academic years and at least 100,000 booking rows while preserving every implemented integrity invariant.

## Owned Output Directory

- `outputs/14-data-generator-G03/`

Required files:

- `README.md`
- `00-config.sql`
- `01-generate-reference-data.sql`
- `02-generate-bookings.sql`
- `03-generate-maintenance.sql`
- `04-generate-acknowledgements.sql`
- `05-validate-generated-data.sql`
- `99-cleanup-generated-data.sql`

The exact split may be extended, but one documented execution order is mandatory.

## Authoritative Inputs

1. `AGENTS.md`.
2. `outputs/10-schema-migration-G03.sql` — exact Phase 2 schema.
3. `outputs/12-concurrency-implementation-G03.sql` — approved-write invariant and interfaces.
4. `outputs/13-concurrency-tests-G03/README.md` — confirmed behavior/error contract when executed.
5. `outputs/09-updated-erd-and-logical-design-G03.md` — coverage and assumption cross-check.

## Responsibilities

- Generate deterministic reference, user, space, facility, semester, booking, approval, usage, maintenance, impact-history, and acknowledgement data supported by the schema.
- Provide configurable targets of at least 100,000 and optionally 500,000 bookings.
- Cover at least three academic years/six semesters under the accepted semester model.
- Use realistic status, purpose, capacity, time, cancellation, no-show, maintenance, and advisory distributions.
- Guarantee no overlapping approved occupancy for the same space.
- Guarantee no approved booking initially created over out-of-service maintenance unless the dataset intentionally represents a later escalation and labels it accordingly.
- Generate advisory acknowledgements only when the modeled disclosure conditions hold.
- Provide row-count, FK, temporal, overlap, maintenance, and acknowledgement validation.
- Make generated rows identifiable and safely cleanable.

## Non-Responsibilities

- Do not alter schema, production procedures, or indexes.
- Do not emit 100,000 hand-written `INSERT` statements.
- Do not fabricate performance results.
- Do not intentionally insert invalid negative cases into the main generated dataset.
- Do not use nondeterministic current dates or unseeded randomness that prevents reproducing the same benchmark.

## Generation Rules

1. Use set-based construction from a documented tally/numbers source.
2. Configuration must include target booking count, deterministic seed or deterministic formula, academic-year range, generator run ID/prefix, and optional batch size.
3. Explicitly define status distributions and ensure at least one meaningful population for Pending, Approved, Rejected, Cancelled, Checked in, Completed, and No-show when those statuses exist.
4. Generate approved occupancy using deterministic non-overlapping slots per space; conflicting requests may exist only in non-approved states.
5. Respect capacity, purpose-domain, time-order, FK, unique, and role constraints.
6. If direct bulk inserts bypass output-12 procedures for speed, document the trusted-load assumption and run the complete invariant validation before the dataset may be used. Do not present this as an application write path.
7. Generate escalation events whose affected bookings are logically explainable: bookings may predate an escalation from Advisory to Out-of-service.
8. An acknowledgement must identify the booking and each applicable advisory according to output 09 semantics; duplicate pairs/events are forbidden unless explicitly modeled.
9. Use batches where necessary to control transaction-log growth, and document expected recovery-model/log considerations.
10. Cleanup targets only rows marked with the generator run identifier or documented reserved ID/code range.

## Scale and Distribution Contract

The README must declare:

- requested and actual booking count;
- academic-year/semester coverage;
- users, spaces, facilities, bookings, decisions, sessions, maintenance records, impact changes, and acknowledgement counts;
- status distribution;
- approved/non-approved distribution;
- maintenance impact distribution;
- generation duration when executed;
- deterministic reproduction parameters.

## Workflow

1. Confirm migrated schema and concurrency interfaces are complete.
2. Extract dependency order and all constraints.
3. Define deterministic configuration and owned-row markers.
4. Design non-overlapping schedule slots and realistic distributions.
5. Generate parent/reference data.
6. Generate bookings/decisions/sessions.
7. Generate maintenance/impact history.
8. Generate advisory acknowledgements.
9. Run validation suite and capture actual counts when executable.
10. Write safe cleanup and complete README.

## Validation Requirements

`05-validate-generated-data.sql` must return clearly labelled result sets for:

- target booking count and three-academic-year coverage;
- counts by status, semester, purpose, and space;
- FK/orphan checks for generated relations;
- duplicate natural/business key checks;
- invalid time-order checks;
- approved overlap self-join — expected zero;
- approved booking versus out-of-service overlap, distinguishing later escalation cases;
- advisories requiring acknowledgement versus stored acknowledgement coverage;
- duplicated acknowledgement pairs/events;
- maintenance impact history ordering/current-state consistency;
- `DBCC CHECKCONSTRAINTS` result guidance.

## Blocking Self-Check

- Generator target is configurable and defaults to at least 100,000.
- Data spans at least three academic years.
- Generation is set-based and reproducible.
- Approved overlap validation is present and expected zero.
- Required cancellations, no-shows, maintenance, escalation, and acknowledgements are present.
- Direct-load bypass, if used, is explicitly restricted to trusted generation and followed by validation.
- Cleanup is narrowly scoped and dependency safe.
- Expected results are not labelled actual unless executed.
- README no longer describes the directory as scaffold-only.

## Handoff Contract

`analytical-query-designer.md` receives documented semester/status distributions and correctness fixtures. `database-performance-tuning-engineer.md` receives a fixed generator configuration and validation proof so before/after measurements use identical data.
