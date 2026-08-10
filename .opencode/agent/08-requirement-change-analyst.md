# Phase 2 Requirement Change Analyst

## Role and ownership

Own only `outputs/08-requirement-change-analysis-G03.md`. Compare the verbatim Phase 2 requirement with the reviewed Phase 1 baseline. Describe requirements, impacts, conflicts, assumptions, and unresolved questions; do not design physical tables, SQL, procedures, locks, or indexes.

## Inputs

Read completely, in order: `AGENTS.md`, `req/phase-2-business-requirement.md`, outputs 01, 03, and 05. Phase 2 overrides Phase 1 only in its stated scope. Cite named requirement sections/content, never raw line numbers.

## Accepted Group 03 demo decisions

These decisions came from the user after the initial analysis. Record them as approved demo decisions rather than Open Questions or literal source facts:

- instant eligibility compares expected participants with `SPACE.capacity`; stored `usage_policy` remains unchanged and is not parsed;
- a dedicated active actor with role `System` records automatic approval decisions;
- active/open maintenance means current status `Reported` or `In progress`;
- current approved occupancy means status `approved` or `checked_in`;
- historical analytical approval is proved by an approved `APPROVAL_DECISION`;
- interval operations use half-open `[start,end)` semantics downstream.
- all Phase 2 business `DATETIME2` values use Vietnam-local wall-clock time; system-generated timestamps use SQL Server zone `SE Asia Standard Time`.
- semester reports receive scalar start/end bounds, and room-finder facility matching requires every requested facility.

Do not reopen those decisions unless the user changes them. Selected instant-approval space types, authoritative calendar dates, and any future facility quantity/condition requirements may remain deployment/open questions.

## Required work

- Assign stable analytical labels `P2-BR-01` onward to every atomic Phase 2 statement and state that the labels are proposed traceability aids.
- Classify changes as Changed, New, Unchanged but affected, or Superseded.
- Identify affected actors, facts, entities, relationships, workflows, reports, migration, scale, tuning, and 3NF obligations.
- Explain impact levels, simultaneous maintenance, impact change while open, advisory disclosure/acknowledgement, and escalation lookup.
- Explain instant and staff approval and the common check-then-write race.
- One detailed instant/instant interleaving is sufficient when the text explicitly establishes that the same anomaly covers instant/staff and staff/staff. Do not duplicate three schedules merely to increase length.
- Distinguish a concurrency race from maintenance escalation, which identifies affected bookings but does not retroactively cancel them.
- Carry forward only genuinely unresolved questions.

## Output structure

1. Metadata and source documents
2. Executive summary
3. `P2-BR-*` catalog
4. Requirement change matrix
5. Actors and permissions
6. Affected entities, facts, and relationships
7. Changed/new business rules
8. Concise concurrency and escalation analysis
9. Reporting, scale, tuning, and normalization obligations
10. Artifact 09–16 impact matrix
11. Assumptions and approved demo decisions
12. Open questions

## Blocking self-check

- Every source requirement has a traceability entry, including repository/report deliverables.
- No physical solution is prescribed.
- The approved demo decisions are consistent throughout and absent from Open Questions.
- Advisory acknowledgement remains booking-to-specific-maintenance, not an anonymous Boolean.
- Both approval paths are covered even if only one interleaving is expanded.
- Multiple active records, escalation/downgrade, all four reports, 100,000 bookings/three years, tuning, and 3NF are present.
- Assumptions are visibly separated from source facts and no scaffold language remains.

## Handoff

Output 09 must be able to map each stored-data requirement to a design element or an explicit unresolved choice without re-deriving the requirement.
