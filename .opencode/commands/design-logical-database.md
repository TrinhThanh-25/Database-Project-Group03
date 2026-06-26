# /design-logical-database

## Description

Design a logical database schema based on the conceptual database design document, following a fixed template and passing a self-verification gate before being delivered.

## Agent

Use the agent defined in `.opencode/agent/logical-database-designer.md`. That file owns the full workflow (how to read input, extract, validate, and self-check) — this command only defines the contract: what goes in, what comes out, and where to find the supporting files.

## Contract

Before producing the output:
1. Read and follow the agent definition from:
   `.opencode/agent/logical-database-designer.md`
2. Read and follow the structural template from:
   `.opencode/templates/logical-design-template.md`
3. After drafting the output, run the self-check against:
   `.opencode/evaluation/logical-design-rubric.md`
   The output must pass ALL "blocking" checks in the rubric before being written to the final output path. If any blocking check fails, fix the draft and re-run the self-check. Do not deliver a draft that fails a blocking check; if a check cannot be resolved, document it under "Open Questions" instead of silently dropping it.

## Workflow Order

- Step 3 of the pipeline. Depends on the output of `/design-conceptual-database` command.

## Required Inputs

* Conceptual Database Design document: `outputs/02-erd-design-G03.md` which is the output of `/design-conceptual-database` command.

## Required Outputs

* Logical Database Design document: `outputs/03-logical-design-G03.md`.
