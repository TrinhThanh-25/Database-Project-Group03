cat > .opencode/skills/db-design-pipeline/SKILL.md <<'EOF'
---
name: db-design-pipeline
description: Analyze business requirements and produce conceptual ERD, logical database design, and DDL documents step by step.
compatibility: opencode
---

# Database Design Pipeline Skill

Use this skill when the user asks to transform business requirements into a database design.

## Important behavior

Before assuming anything, inspect the project:

1. Run `ls -la`.
2. Locate requirement files under `req/`, `docs/`, or files passed by the user.
3. Read the relevant requirement files fully before designing.
4. If the requirement is incomplete, continue with explicit assumptions, but also create an unresolved questions section.

## Required output files

Create or update the following files:

1. `outputs/01-business-requirement-analysis-G03.md`
2. `outputs/02-erd-design-G03.md`
3. `outputs/03-logical-design-G03.md`
4. `outputs/04-design-validation-G03.sql`
5. `outputs/05-db-definition-G03.sql`
6. `outputs/06-sample-data-G03.sql`
7. `outputs/07-query-design-G03.sql`

Do not skip any Markdown file.

## Execution Order

1. /analyze-requirement
2. /conceptual-design
3. /logical-design
4. /validate-design
5. /implement-database
6. /generate-test-data
7. /design-queries

## Rules and Constraints

- Each step must be executed in order, and the output of each step must be saved to the specified file.
- Do not jump to later steps without completing the previous ones.
- If any step fails, report the issue and stop the pipeline.

