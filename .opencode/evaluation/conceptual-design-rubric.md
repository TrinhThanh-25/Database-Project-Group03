# Evaluation Rubric - Conceptual Database Design Output

## Purpose

This rubric is run by the analyst agent itself as a mandatory self-check before delivering output (see agent Workflow step 10), and can also be run by a human reviewer afterward. Every "Blocking" item must pass before delivery; "Advisory" items should be addressed but don't block delivery on their own.

Checks below are ordered to match the agent's build sequence (Workflow steps 4–8): Actors → Entities → Relationships → Business Rules → Process-level sections. Run them in this order so an early failure can be fixed before checking what depends on it.

## How to score

For each check, mark: **PASS**, **FAIL**, or **N/A** (with one-line justification for N/A). Any FAIL on a Blocking check means the draft is not ready — fix it and re-run the rubric, do not deliver.

## A. Entities, Attribute, Relationship, Cardinality and Traceability Completeness (Blocking) — corresponds to Workflow steps 4–6

| # | Check | Pass criteria |
|---|---|---|
| A1 | Every entity in the conceptual design has all attributes listed in the business requirements analysis document | Cross-check each entity's attribute list line by line against the source text |
| A2 | Every relationship in the conceptual design is represented with appropriate cardinalities and participation constraints as specified in the business requirements analysis document | For each relationship, confirm that the cardinality and participation constraints match the source text |
| A3 | Every entity, attribute, and relationship in the conceptual design traces to a specific item in the business requirements analysis document | For each entity, attribute, and relationship, confirm that it can be traced back to a specific item in the source document |
| A4 | No invented entities, attributes, relationships, cardinalities, or constraints are present in the conceptual design | Confirm that all elements in the design are supported by the source document and that no additional elements have been added |

## B. Workflow and Relationship between Entities (Blocking) — corresponds to Workflow steps 7–8

| # | Check | Pass criteria |
|---|---|---|
| B1 | The conceptual design accurately represents the workflow and relationships between entities as specified in the business requirements analysis document | Cross-check the workflow and relationships in the design against the source text |
| B2 | Any ambiguities or unresolved issues from the business requirements analysis document that affect the conceptual design are documented in the "Open Questions" section | Confirm that all ambiguities or unresolved issues are listed in the "Open Questions" section and that they are not silently resolved in the design |

## C. Self-Check Execution Log (append this when running the rubric)

| # | Check | Pass criteria |
|---|---|---|
| C1 | The self-check execution log is completed and includes the date, time, and name of the person or agent running the check | Confirm that the log includes all required information and is complete |


## Self-Check Execution Log (append this when running the rubric)

```
Run date: [date]
Run time: [time]
Run by: [agent / human reviewer]

A1-A4: [PASS/FAIL each] — [note]
B1-B2: [PASS/FAIL each] — [note]
C1: [PASS/FAIL] — [note]

Blocking failures remaining: [list, or "none"]
Delivery status: [READY / NOT READY — fix blocking failures first]
```