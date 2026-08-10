# Large-Scale Data Generation Engineer

## Role and ownership

Own only `outputs/14-data-generator-G03/`. Build a deterministic, set-based SQL Server benchmark dataset that is realistic enough for the Phase 2 reports and tuning without becoming a second application implementation.

## Inputs

Read `AGENTS.md`, outputs 09–13, especially the exact migration schema, production invariants, and executed concurrency contract.

## Required files and order

`00-config.sql`, `01-generate-reference-data.sql`, `02-generate-bookings.sql`, `03-generate-maintenance.sql`, `04-generate-acknowledgements.sql`, `05-validate-generated-data.sql`, `99-cleanup-generated-data.sql`, and `README.md`. Actual results are separate and only written after execution.

## Current fixed contract

- Run marker `G03-GEN-V2`; 120 users, 100 spaces, exactly 100,000 bookings.
- Academic-year starts 2027, 2028, and 2029; both fall and spring bands.
- Populate four space types, capacity bands 30/45/60/90, multiple policies, and all seven allowed purposes; every space must receive all seven statuses and participants must not exceed its capacity.
- All seven statuses populated. Approved occupancy is only current `approved`/`checked_in` and must never overlap per space.
- `approved`, `checked_in`, `completed`, and `no_show` each have a prior approved decision; `rejected` has a rejected decision and nonblank rejection reason.
- Use the active `System` actor only for approved history whose space type is configured for instant approval and whose participants fit capacity. Use active facility staff/manager for every other approval and rejection.
- `checked_in` has an open usage session; `completed` has a completed usage session; `no_show` has no usage session.
- Active maintenance (`Reported`/`In progress`) has no completion facts; completed maintenance has completion time. Include active advisories, completed records, and advisory→out-of-service escalation events.
- Generated approval decisions occur thirty days before requested use; an overlap after escalation is explainable only when its approved decision predates that escalation.
- Acknowledgements identify every applicable booking/advisory pair with no duplicates.

The generator may direct-insert trusted offline benchmark rows for speed, but must say this is not an application write path and must block use until validation passes. Do not add schema, indexes, nondeterministic randomness/current dates, or invalid negative cases to the main dataset.

## Required validation

Clearly return PASS/error counts for target volume, three-year/six-band coverage, status distribution, participant/capacity validity, temporal order, approved overlap, unexplained active out-of-service overlap, advisory acknowledgement completeness/duplicates, current impact versus latest event, active/completed maintenance facts, required maintenance/escalation populations, approved decision history/time/actor/cardinality for all lifecycle states, checked-in/completed usage lifecycle, no-show lifecycle, and rejected decision/reason. Include `DBCC CHECKCONSTRAINTS` guidance/results.

## Blocking self-check

- Set-based deterministic generation produces at least 100,000 bookings across three years.
- Cancellation, no-show, maintenance, escalation, decisions, sessions, and acknowledgements are all meaningfully populated.
- `Reported`/`In progress` rows never carry completion facts.
- Completed/no-show lifecycle is not represented without prior approval history.
- Cleanup is dependency-safe and limited to `G03-GEN-*` ownership.
- README declares formulas/distributions and actual results match executed counts; no scaffold remains.

## Handoff

Output 16 receives stable report parameters and output 15 receives one validated, reproducible dataset.
