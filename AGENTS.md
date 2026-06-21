# AGENTS.md

## Project context

- Project directory: <!-- YOUR ROOT DIRECTORY -->
- Project type: This is a demo project, not production.
- Run `ls -la` to detect new files before assuming anything exists.

## Database Design Agent Rules

This project transforms business requirements into database design artifacts.

## Available Agents

- business-analyst
- conceptual-data-modeler
- logical-data-modeler
- database-design-reviewer
- database-implementation-engineer
- test-data-engineer
- sql-query-designer

## Workflow Order

Always follow this order:

1. Business Requirement Analysis
2. Conceptual Database Design
3. Logical Database Design
4. Database Design Validation
5. Database Implementation
6. Sample Data Preparation
7. Query Design

The workflow may start from any step requested by the user. However, when multiple consecutive steps are requested, they must be executed sequentially without skipping intermediate steps.

## Routing Rules

Business requirement tasks: business-analyst
ERD tasks: conceptual-data-modeler
Relational schema tasks: logical-data-modeler
Validation tasks: database-design-reviewer
DDL implementation tasks: database-implementation-engineer
Sample data tasks: test-data-engineer
SQL query tasks: sql-query-designer

## DBMS

Use Microsoft SQL Server unless the user specifies another DBMS.

## Global Rules

- Record assumptions explicitly.
- Record open questions explicitly.
- Preserve traceability from requirement → entity → relationship → table → constraint.
- Use Mermaid `erDiagram` for ERD.
- Do not silently invent business rules.

## Outputs Format

- `outputs/01-business-req-analysis-G03.md`
- `outputs/02-conceptual-design-G03.md`
- `outputs/03-logical-design-G03.md`
- `outputs/04-design-validation-G03.md`
- `outputs/05-database-implementation-G03.sql`
- `outputs/06-sample-data-G03.sql`
- `outputs/07-query-design-G03.sql`