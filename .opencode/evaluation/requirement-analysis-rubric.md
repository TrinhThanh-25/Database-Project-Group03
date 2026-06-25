# Evaluation Rubric — Business Requirement Analysis Output

## Purpose

This rubric is run by the analyst agent itself as a mandatory self-check before delivering output (see agent Workflow step 10), and can also be run by a human reviewer afterward. Every "Blocking" item must pass before delivery; "Advisory" items should be addressed but don't block delivery on their own.

Checks below are ordered to match the agent's build sequence (Workflow steps 4–8): Actors → Entities → Relationships → Business Rules → Process-level sections. Run them in this order so an early failure can be fixed before checking what depends on it.

## How to score

For each check, mark: **PASS**, **FAIL**, or **N/A** (with one-line justification for N/A). Any FAIL on a Blocking check means the draft is not ready — fix it and re-run the rubric, do not deliver.

---

## A. Actor Consistency (Blocking) — corresponds to Workflow step 4

| # | Check | Pass criteria |
|---|---|---|
| A1 | No two actors in Section 3 have identical responsibility descriptions | Read every pair of actor rows and compare |
| A2 | Every actor in Section 3 is traceable to Layer B's enumerated role list, with any Layer-A-only actor either merged or explicitly justified | Cross-check Section 3 against Layer B; any discrepancy is noted under Assumptions |

## B. Entity and Attribute Completeness (Blocking) — corresponds to Workflow step 5

| # | Check | Pass criteria |
|---|---|---|
| B1 | For every entity in Section 4, every attribute listed matches what is actually stated in the business requirement — no attribute missing that the source mentions, and no attribute added that the source does not mention | Cross-check each entity's attribute list line by line against the source text |
| B2 | No entity in Section 4 has an attribute whose sole purpose is to reference, identify, assign, select, or associate another entity — all connections between entities belong in Section 5 (Relationships) only | For each entity's attribute list, verify no attribute is a foreign-key-style reference or role-pointer to another entity (e.g., "requested space", "decided by", "checked in by" must NOT appear as attributes — they must appear as relationships in Section 5) |
| B3 | No fact is listed as an attribute on two different entities | Search the whole document for repeated attribute names/concepts across entities |
| B4 | Rejection reason appears only on Approval Decision, not on Booking Request | Check every entity's attribute list by name; confirm rejection reason (or equivalent) appears only in the Approval Decision entity, not in the Booking Request entity |
| B5 | Terminology consistency check: No two different names are used for the same real-world concept | Scan the entire draft for any case where the same real-world concept is referred to by two different names (e.g., "closed" vs "temporarily closed", "manager", vs "facility manager", "staff" vs "facility staff") |



## C. Relationships and Distinct Actions (Blocking) — corresponds to Workflow step 6

| # | Check | Pass criteria |
|---|---|---|
| C1 | "Checked in by" and "completed by" are modeled as two separate relationships | Check the Usage Session entity and Section 5; confirm both are present as separate relationship entries, not merged into one |
| C2 | Any other pair of actions that the source allows to be performed by different people at different times are kept separate | Scan Section 5 relationships for any "merged" multi-action rows |

## D. Business Rules and Source-Grounding (Blocking) — corresponds to Workflow step 7

| # | Check | Pass criteria |
|---|---|---|
| D1 | Every business rule in Section 6 traces to Layer B (the attributed requirement summary), not only to Layer A (narrative/context) | For each rule, confirm the source sentence sits after the stakeholder attribution marker (e.g., "provides the following requirement summary"); if it only appears before that marker, it must be demoted to Open Questions |
| D2 | Every business rule in Section 6 traces to an identifiable source sentence | For each rule, you can name the source sentence/paraphrase it came from |
| D3 | No rule adds a condition, scope, or enforcement mechanism beyond what the source states | Re-read each rule and ask "does the source actually say this, or did I complete the thought myself?" |
| D4 | Section 2 (Business Context) does not contain prescriptive rule language ("must", "should", specific enforcement logic) sourced only from Layer A | Spot-check Section 2 for sentences that read like rules rather than background — if found, verify they're also independently grounded in Layer B before allowing them outside Section 2 |

## E. Process-Level Sections (Blocking) — corresponds to Workflow step 8

| # | Check | Pass criteria |
|---|---|---|
| E1 | Section 7 (State Transitions) is present and non-empty for at least Booking Request | At least one transition table with real content, not a placeholder |
| E2 | Every state transition in Section 7 marked as definite is clearly implied by Layer B's described sequence | Ambiguous transitions are listed in Open Questions, not asserted |
| E3 | Section 8 (Role Permissions) is present and covers at least: submit booking, approve/reject, check in, complete, report maintenance | All five rows present |
| E4 | Section 9 (Workflow Narratives) covers at least the booking lifecycle and the maintenance lifecycle | Both narratives present |
| E5 | Section 10 (Cross-Entity Constraints) is present, even if its content is mostly "ambiguous, see Open Questions" | Section exists and is not silently omitted |
| E6 | Every cross-entity constraint (Section 10) that is stated as definite has a clear, stated direction supported by Layer B | If direction is ambiguous, it must be in Open Questions, not Section 10 as fact |

## F. Actor and Role Cross-Reference (Advisory)

| # | Check | Pass criteria |
|---|---|---|
| F1 | Every role listed under User's "Possible roles" also appears in Section 3's Actors table | Cross-check both lists |
| F2 | Every actor in Section 3 maps to at least one role-permission row in Section 8, or its absence is explainable | Spot-check |

## G. Traceability and Assumptions Hygiene (Advisory)

| # | Check | Pass criteria |
|---|---|---|
| G1 | Every item in Section 12 (Assumptions) is referenced or justified somewhere earlier in the document (not introduced only in Assumptions out of nowhere) | Cross-check |
| G2 | Every item moved out of Business Rules due to failing check D1/D2/D3 has a corresponding entry in Section 13 (Open Questions) | Cross-check removed rules against Open Questions list |

## H. Scope Discipline (Blocking)

| # | Check | Pass criteria |
|---|---|---|
| H1 | No SQL, no table/column definitions, no data types anywhere in the document | Search for `CREATE TABLE`, `VARCHAR`, `PRIMARY KEY`, etc. — none should appear |
| H2 | Document stays at conceptual/business level throughout | Spot-check Section 4 and 6 for implementation-level language |

## I. Self-Check Execution Log (write to `.opencode/logging/self-check-log.md`)

| # | Check | Pass criteria |
|---|---|---|
| I1 | The self-check execution log is completed and written to `.opencode/logging/self-check-log.md`, including the date, time, and name of the person or agent running the check | Confirm the log file exists at the correct path and includes all required fields |

---

## Self-Check Execution Log (write to `.opencode/logging/self-check-log.md`)

```
Run date: [date]
Run time: [time]
Run by: [agent / human reviewer]

A1-A2: [PASS/FAIL each] — [note]
B1-B5: [PASS/FAIL each] — [note]
C1-C2: [PASS/FAIL each] — [note]
D1-D4: [PASS/FAIL each] — [note]
E1-E6: [PASS/FAIL each] — [note]
F1-F2: [PASS/FAIL each] — [note]
G1-G2: [PASS/FAIL each] — [note]
H1-H2: [PASS/FAIL each] — [note]
I1: [PASS/FAIL] — [note]

Blocking failures remaining: [list, or "none"]
Delivery status: [READY / NOT READY — fix blocking failures first]
```