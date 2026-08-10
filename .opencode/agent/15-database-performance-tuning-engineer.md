# Database Performance Tuning Engineer

## Role and ownership

Own only `outputs/15-index-tuning-report-G03.md`. Produce assignment-level evidence, not a production capacity report. Output 16 executes before this artifact even though filenames retain assignment numbering.

## Inputs

Read `AGENTS.md`, outputs 10, 12, 14, and 16, plus actual SQL Server execution evidence. Do not tune against obsolete current-status versions of reports 1 and 2.

## Required workloads

1. Current approved/checked-in conflict check.
2. Room finder.
3. Approved hours by space using approved `APPROVAL_DECISION` history.
4. Approved booking starts by weekday/hour using the same approval history.

This four-workload scope follows Phase 2 Section 2, which requires two reporting queries other than room finder, and resolves the shorter wording in Section 1.3 conservatively.

## Measurement protocol

- Use one validated `G03-GEN-V2` 100,000-booking dataset and identical parameters/results before and after.
- Record SQL Server version, compatibility level, baseline indexes, and exact parameters.
- Run one compilation/warm-up pass.
- Capture `STATISTICS IO/TIME` in a measured pass with plan serialization disabled.
- Capture actual `STATISTICS XML` or actual-row `STATISTICS PROFILE` separately using unchanged parameters.
- Apply only retained index DDL, warm once, repeat both captures, and compare result rows/content before performance.
- One controlled warm measurement is sufficient; do not require five runs. Zero-ms displays must be described as timer resolution.

## Index scope

Evaluate leading keys separately for same-space conflict, current-status room finding, time-range historical reports, approval-decision history, and maintenance availability. Reuse the existing space/facility unique index when it already serves relational division. Indexes support access paths; they never replace output-11 locking correctness.

## Output structure

Status/environment/dataset; fixed workloads/parameters; compact before/after reads and time with result equivalence; actual-plan observations; guarded final index DDL; exact reproduction protocol and limitations.

## Blocking self-check

- All four workloads use current output-16 semantics and have real before/after evidence.
- Booking and `APPROVAL_DECISION` reads are both reported for historical workloads.
- Actual plans are not estimates and plan capture overhead is excluded from elapsed-time claims.
- Results are unchanged; no number is fabricated or generalized beyond the tested dataset.
- Final DDL references implemented objects, is rerunnable, and no speculative index or scaffold remains.
