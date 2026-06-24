# /analyze-requirement

## Description

Analyze business requirements and produce a Business Requirement Analysis document, following a fixed template and passing a self-verification gate before being delivered.

## Agent

Use the agent defined in `.opencode/agent/business-analyst.md`. That file owns the full workflow (how to read input, extract, validate, and self-check) — this command only defines the contract: what goes in, what comes out, and where to find the supporting files.

## Contract

Before producing the output:
1. Read and follow the agent definition from:
   `.opencode/agent/business-analyst.md`
2. Read and follow the structural template from:
   `.opencode/templates/requirement-analysis-template.md`
3. After drafting the output, run the self-check against:
   `.opencode/evaluation/requirement-analysis-rubric.md`
   The output must pass ALL "blocking" checks in the rubric before being written to the final output path. If any blocking check fails, fix the draft and re-run the self-check. Do not deliver a draft that fails a blocking check; if a check cannot be resolved, document it under "Open Questions" instead of silently dropping it.


## Workflow Order

- Step 1 of the pipeline. Does not depend on other agents/commands.

## Required Inputs

* Business requirements document: `req/business-requirement.md`. (if not found, search `req/` for the closest matching filename and record the discrepancy under "Assumptions" — do not guess content that isn't in the file actually found).

## Required Outputs

* Business Requirement Analysis document: `outputs/01-business-req-analysis-G03.md`.
