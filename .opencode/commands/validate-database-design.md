# /validate-database-design

## Description

Review and validate the business requirement analysis, conceptual database design, and logical database design against the business requirements. Produce an objective validation report that identifies design strengths, issues, implementation risks, and recommendations without modifying the submitted design.

## Agent

Before producing the output:
1. Read and follow the agent definition from:
   `.opencode/agent/database-design-reviewer.md`
2. Use the official validation report template.
3. Use the validation rubric to evaluate the design.
4. Base every finding on evidence from the reviewed artifacts.

## Aliases

* /validate-design
* /database-design-review
* /design-review

## Required Inputs

* Business Requirements document: `req/business-requirement.md`.
* Business Requirement Analysis document: `outputs/01-business-req-analysis-G03.md` which is the output of `/analyze-requirement` command.
* Conceptual Database Design document: `outputs/02-erd-design-G03.md` which is the output of `/design-conceptual-database` command.
* Logical Database Design document: `outputs/03-logical-design-G03.md` which is the output of `/design-logical-database` command.

Inputs must be reviewed in the following order:
1. Business Requirement
2. Requirement Analysis
3. Conceptual Design
4. Logical Design

## Required Outputs

* Database Design Validation Report: `outputs/04-design-validation-G03.md`.

## Validation Focus

The reviewer must validate:

- Requirement coverage
- Entity completeness
- Attribute completeness
- Relationship correctness
- Cardinality
- Participation constraints
- Primary keys
- Foreign keys
- Candidate keys
- Business rule coverage
- Constraint feasibility
- SQL implementation risks

## Execution Rules

- Do not redesign the database.
- Do not introduce new business requirements.
- Do not modify previous outputs.
- Validate only the submitted artifacts.
- Every issue must include:
  - severity
  - evidence
  - recommendation

## Deliverable Quality

The report should be:

- Objective
- Evidence-based
- Traceable to the reviewed documents
- Actionable
- Suitable for database implementation review

## Evaluation

Use:

.opencode/evaluation/validation-rubric.md

to evaluate the completeness, correctness, consistency, and requirement coverage of the submitted design.

## Template

Generate the report using:

.opencode/skills/db-design-pipeline/templates/validation-template.md