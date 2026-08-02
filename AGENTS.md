# AGENTS.md

## Project context

- Project directory: `.` (the repository root where this file lives)
- Project type: This is a demo project, not production.
- Run `ls -la` to detect new files before assuming anything exists.

## Purpose

This project transforms business requirements into database design artifacts, through a fixed pipeline of specialized agents. This file defines routing, workflow order, shared conventions, and output locations across the whole pipeline. Each agent's own file (see "Available Agents") owns the detailed steps and extraction rules for its specific stage — this file does not duplicate them.

## Available Agents

- `business-analyst.md` — business requirement analysis
- `conceptual-database-designer.md` — conceptual database design
- `logical-database-designer.md` — logical database design
- `database-design-reviewer.md` — database design validation
- `database-definition-implementation-engineer.md` — database implementation
- `sample-data-preparer.md` — sample data preparation
- `sql-query-designer.md` — SQL query design

## Workflow Order

Always follow this order:

1. Business Requirement Analysis — business-analyst
2. Conceptual Database Design — conceptual-database-designer
3. Logical Database Design — logical-database-designer
4. Database Design Validation — database-design-reviewer
5. Database Implementation — database-definition-implementation-engineer
6. Sample Data Preparation — sample-data-preparer
7. Query Design — sql-query-designer

The workflow may start from any step requested by the user. However, when multiple consecutive steps are requested, they must be executed sequentially without skipping intermediate steps.

Each step's agent must read the previous step's output file (see "Outputs" below) as its primary input, not re-derive its work from the original raw requirement. Step 1 is the only step that reads the raw requirement directly.

## Routing Rules

Business requirement tasks: business-analyst
ERD tasks: conceptual-database-designer
Relational schema tasks: logical-database-designer
Validation tasks: database-design-reviewer
DDL implementation tasks: database-definition-implementation-engineer
Sample data tasks: sample-data-preparer
SQL query tasks: sql-query-designer

## DBMS

Use Microsoft SQL Server unless the user specifies another DBMS.

## Global Rules

These apply across all 7 agents, not only the first step:

- Record assumptions explicitly, in every stage's output.
- Record open questions explicitly, in every stage's output. Carry forward unresolved questions from earlier stages rather than silently dropping them.
- Preserve traceability from requirement → entity → relationship → table → constraint, across every stage's output.
- Use Mermaid `erDiagram` for ERD (conceptual-database-designer stage).
- Do not silently invent rules, constraints, or design decisions beyond what the previous stage's output (or, for stage 1, Layer B of the raw requirement) actually supports. When in doubt, raise it as an Open Question rather than asserting it as fact.
- Consistent inference labeling: Any element you add that the source does not state as a literal stored fact — a proposed identifier, a derived attribute, an inferred outcome value, or an added constraint — must be marked with a consistent, visible tag (e.g. `[proposed — not stated in source]`) at the point it appears, AND recorded as an Assumption. Do not mark some inferred elements while silently leaving another (e.g. a derived "decision outcome" value) unmarked. Either every inferred element carries the tag, or none of them is inferred.
- Constraint-strength evidence: Do not make a constraint stronger than the source supports. Do not mark an attribute NOT NULL / mandatory, nor add a UNIQUE, CHECK, or tightened cardinality, unless the source states or clearly implies that strength. When the source says a value is "recorded" or "stored" but is silent on whether it is mandatory, default to the weaker option (nullable / unconstrained) or raise it as an Open Question. Apply the same strength consistently to sibling fields of the same kind — do not make one source-optional field mandatory while correctly leaving its sibling optional.
- Source citation format: Cite the source by quoting or paraphrasing its content and naming the section / requirement label (e.g. "BR-15", "the Facility Manager summary, approval paragraph"). Do not cite the raw requirement by line number — it is continuous prose, so "line N" references are fragile and frequently wrong. Reference the requirement statement itself, not a line index.
- Each agent loads its own detailed workflow, extraction/design rules, applicable template, and applicable evaluation rubric from its own agent file before producing output. This file (`AGENTS.md`) only defines routing and shared conventions — it does not restate per-agent steps.
- Perform the applicable self-check and review before delivery, but do not create a repository logging folder. User-facing artifacts must contain only deliverable content, assumptions, open questions, traceability, and reproducible test evidence.

## Outputs Format

- `outputs/01-business-req-analysis-G03.md`
- `outputs/02-erd-design-G03.md`
- `outputs/03-logical-design-G03.md`
- `outputs/04-design-validation-G03.md`
- `outputs/05-db-definition-G03.sql`
- `outputs/06-sample-data-G03.sql`
- `outputs/07-query-design-G03.sql`

## Phase 2 Extension Workflow

Phase 2 extends, and does not replace, artifacts 01–07. Follow this order:

8. Requirement Change Analysis — business-analyst
9. Updated ERD, Logical Design, Functional Dependencies, and 3NF — conceptual-database-designer then logical-database-designer
10. Data-Preserving Schema Migration — database-definition-implementation-engineer
11. Concurrency Design — logical-database-designer with database-design-reviewer validation
12. Concurrency Implementation — database-definition-implementation-engineer
13. Concurrency Tests — database-design-reviewer validates evidence
14. Large Sample Data Generator — sample-data-preparer
15. Analytical Queries — sql-query-designer (writes numbered artifact `16`)
16. Index Tuning Report — sql-query-designer with database-design-reviewer validation (writes numbered artifact `15`)

For Phase 2, each stage reads its declared upstream artifact as primary input and may read Phase 1 artifacts only as the implementation baseline. Execute requested stages sequentially. The assignment numbers the tuning report `15` and analytical SQL `16`, but tuning depends on executable analytical queries; therefore execution order is `... 14 → 16 → 15`, while filenames remain exactly as assigned.

### Phase 2 Source and Outputs

- `req/phase-2-business-requirement.md`
- `outputs/08-requirement-change-analysis-G03.md`
- `outputs/09-updated-erd-and-logical-design-G03.md`
- `outputs/10-schema-migration-G03.sql`
- `outputs/11-concurrency-design-G03.md`
- `outputs/12-concurrency-implementation-G03.sql`
- `outputs/13-concurrency-tests-G03/`
- `outputs/14-data-generator-G03/`
- `outputs/15-index-tuning-report-G03.md`
- `outputs/16-analytical-queries-G03.sql`

The assignment source spells artifact 16 with `.sq`; Group 03 uses `.sql` because it is a Microsoft SQL Server script and records the discrepancy in the preserved requirement.

### Phase 2 Rules

- Migration must be additive and data-preserving. Never reuse the destructive Phase 1 drop/recreate block as the Phase 2 migration.
- The approved-booking non-overlap invariant must be protected under concurrent instant and staff approval paths, not merely checked by a standalone query.
- All paths that can create an approved booking must share one reviewed transaction/locking protocol.
- Concurrency evidence must use repeatable two-session scripts with stated execution order and expected/actual results.
- Generated data must span at least three academic years and contain at least 100,000 bookings, plus maintenance, cancellations, no-shows, and advisory acknowledgements.
- Implement all four Phase 2 reports. Tune the conflict check, room finder, and two reporting queries other than room finder.
- Performance claims require captured actual-plan and `STATISTICS IO/TIME` evidence before and after indexing on the same dataset and parameters.
- Artifact 09 must list functional dependencies and prove every relation is at least in 3NF or document its decomposition.
- Scaffold markers and deliberate `THROW` guards are not completed deliverables; remove them only after the upstream design is reviewed and executable content is verified.
