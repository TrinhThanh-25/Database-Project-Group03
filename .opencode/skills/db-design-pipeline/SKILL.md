---
name: db-design-pipeline
description: Transform campus-space requirements into sequential SQL Server database design, migration, concurrency, test-data, analytical-query, and tuning artifacts for Phases 1 and 2.
compatibility: opencode
---

# Database Design Pipeline Skill

## Discovery

1. Run `ls -la` before assuming any path exists.
2. Read `AGENTS.md` completely.
3. Locate the applicable requirement under `req/` and read it completely.
4. Read the assigned stage's agent file, template, and rubric completely.
5. Read the immediately preceding artifact as the primary input; do not re-derive later stages directly from raw requirements.

## Shared discipline

- Target Microsoft SQL Server unless the user specifies otherwise.
- Preserve requirement → entity → relationship → table → constraint/query traceability.
- Mark every inferred/proposed element visibly and record it under Assumptions.
- Carry every unresolved Open Question forward.
- Never strengthen nullability, uniqueness, checks, or cardinality beyond source evidence.
- Keep verification proportional to the assignment. Agent rubrics may require evidence for a claim, but must not turn optional production hardening into a business requirement.
- Perform stage self-checks without creating repository command/reasoning log files. Put only user-relevant assumptions, open questions, traceability, and reproducible test evidence in deliverables.
- Stop a downstream implementation stage when its upstream design is only a scaffold or has blocking review failures.

## Phase 1 sequence

Use outputs 01–07 and the workflow declared in `AGENTS.md`.

## Phase 2 sequence

1. Preserve/read `req/phase-2-business-requirement.md`.
2. Use `requirement-change-analyst.md` to complete `outputs/08-requirement-change-analysis-G03.md`.
3. Use `phase2-database-design-updater.md` to complete `outputs/09-updated-erd-and-logical-design-G03.md`, including Mermaid `erDiagram`, FDs, and 3NF proof.
4. Use `schema-migration-engineer.md` to implement additive, data-preserving `outputs/10-schema-migration-G03.sql`.
5. Use `database-concurrency-architect.md` to complete `outputs/11-concurrency-design-G03.md`.
6. Use `database-concurrency-implementation-engineer.md` to implement `outputs/12-concurrency-implementation-G03.sql` with one shared protocol for every approval path.
7. Use `database-concurrency-test-engineer.md` to add repeatable two-session tests under `outputs/13-concurrency-tests-G03/`.
8. Use `large-scale-data-generation-engineer.md` to add a deterministic fixed or configurable generator under `outputs/14-data-generator-G03/` for at least three academic years and 100,000 bookings.
9. Use `analytical-query-designer.md` to implement all four reports in `outputs/16-analytical-queries-G03.sql`.
10. Use `database-performance-tuning-engineer.md` to measure and document conflict-check, room-finder, and two non-room-finder report indexes in `outputs/15-index-tuning-report-G03.md`.

The `16`-then-`15` execution order is intentional: the assignment's filenames put the tuning report before the query file numerically, but measured tuning requires finalized executable queries. Keep the assigned filenames unchanged.

## Phase 2 gates

- Do not execute a scaffold containing a deliberate `THROW` guard.
- Do not use destructive drop/recreate logic for migration.
- Demonstrate the concurrency race before claiming prevention, then verify the protected workflow with two sessions.
- Do not claim index improvement without actual before/after execution evidence on the same generated dataset.
- Run a final traceability, naming, source-strength, 3NF, row-count, overlap, and acknowledgement coverage review before delivery.
