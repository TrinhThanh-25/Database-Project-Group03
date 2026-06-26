# /validate-database-design

## Description

Review and validate the business requirement analysis, conceptual database design, and logical database design against the business requirements. Produce an objective validation report that identifies design strengths, issues, implementation risks, and recommendations without modifying the submitted design.

## Agent

Use the agent defined in `.opencode/agent/database-design-reviewer.md`. That file owns the full workflow (how to read input, extract, validate, and self-check) — this command only defines the contract: what goes in, what comes out, and where to find the supporting files.

## Contract

Before producing the output:
1. Read and follow the agent definition from:
   `.opencode/agent/database-design-reviewer.md`
2. Read and follow the structural template from:
   `.opencode/templates/validation-template.md`
3. After drafting the output, run the self-check against:
   `.opencode/evaluation/validation-rubric.md`
   The output must pass ALL "blocking" checks in the rubric before being written to the final output path. If any blocking check fails, fix the draft and re-run the self-check. Do not deliver a draft that fails a blocking check; if a check cannot be resolved, document it under "Open Questions" instead of silently dropping it.

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

