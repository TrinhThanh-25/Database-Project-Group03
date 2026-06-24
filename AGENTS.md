# AGENTS.md

## Project context

- Project directory: <!-- YOUR ROOT DIRECTORY -->
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
- Each agent loads its own detailed workflow, extraction/design rules, applicable template, and applicable evaluation rubric from its own agent file before producing output. This file (`AGENTS.md`) only defines routing and shared conventions — it does not restate per-agent steps.

## Outputs Format

- `outputs/01-business-req-analysis-G03.md`
- `outputs/02-conceptual-design-G03.md`
- `outputs/03-logical-design-G03.md`
- `outputs/04-design-validation-G03.md`
- `outputs/05-database-implementation-G03.sql`
- `outputs/06-sample-data-G03.sql`
- `outputs/07-query-design-G03.sql`