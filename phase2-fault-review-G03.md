# Phase 2 Fault Review - Group 03

Review date: 2026-08-10

Scope reviewed:

- `req/phase-2-business-requirement.md`
- `outputs/08-requirement-change-analysis-G03.md`
- `outputs/09-updated-erd-and-logical-design-G03.md`
- `outputs/10-schema-migration-G03.sql`
- `outputs/11-concurrency-design-G03.md`
- `outputs/12-concurrency-implementation-G03.sql`
- `outputs/13-concurrency-tests-G03/`
- `outputs/14-data-generator-G03/`
- `outputs/15-index-tuning-report-G03.md`
- `outputs/16-analytical-queries-G03.sql`

Basis for review:

- Phase 2 requirement Section 1.1 requires advisory/out-of-service impact levels, advisory acknowledgement, and affected-booking lookup after escalation.
- Phase 2 requirement Section 1.2 requires the approved-booking non-overlap invariant to remain valid during simultaneous instant and staff operations.
- Phase 2 requirement Sections 1.3 and 2 require all four analytical queries, at least 100,000 generated bookings across at least three academic years, concurrency tests, normalization validation, and before/after tuning evidence.
- `AGENTS.md` additionally requires shared approval-path locking, repeatable two-session evidence, 100,000-row generated data with maintenance/cancellations/no-shows/advisory acknowledgements, tuning of the conflict check, room finder, and two non-room-finder reports, with actual-plan and `STATISTICS IO/TIME` evidence.

## Executive Summary

Artifacts 08, 09, 10, 11, 13, 14, and 16 are broadly consistent with the Phase 2 requirement and the repository pipeline rules. The strongest design is the compact additive schema and the shared per-space `sp_getapplock` protocol.

The main faults are evidence/atomicity gaps rather than broad design failure:

| ID | Severity | Area | Summary |
|---|---|---|---|
| F-01 | High | Concurrency implementation | Affected bookings after maintenance escalation are selected after `COMMIT`, outside the protected transaction. |
| F-02 | Medium | Data-generator validation | `DBCC CHECKCONSTRAINTS` output is shown but not made part of the failure gate. |
| F-03 | Medium | Index tuning evidence | The tuning report summarizes actual-plan and IO/TIME evidence but does not include raw captured evidence or file references. |
| F-04 | Medium | Repository deliverables | The requirement asks for `AGENT.md` and `SKILL.md`; `AGENT.md` exists, but no repository-root `SKILL.md` exists. |
| F-05 | Low | Concurrency test robustness | Unsafe race scripts insert into `BOOKING_REQUEST` without explicit column lists. |

## Findings

### F-01 - Affected-booking query runs after commit

Severity: High

Affected file: `outputs/12-concurrency-implementation-G03.sql`

Evidence:

- `usp_G03_ChangeMaintenanceImpact` updates `MAINTENANCE_RECORD`, inserts `MAINTENANCE_IMPACT_EVENT`, then commits at lines 281-284.
- The affected-booking result set for advisory-to-out-of-service escalation is selected only after the commit at lines 286-296.
- Artifact 11 says impact change should update current impact, append the event, and identify affected bookings atomically under the same space lock, especially in lines 98-100.

Why this is a fault:

- The update/event write itself is transactional, but the returned affected-booking set is not protected by the transaction-owned space application lock after `COMMIT`.
- A concurrent operation could change relevant booking state after the lock is released and before/during result consumption.
- This weakens the Phase 2 requirement that the system support finding already-approved affected bookings when advisory maintenance is escalated to out-of-service.

Impact:

- Staff may receive a result set that is not the exact affected set at escalation time.
- The implementation no longer fully matches the reviewed concurrency design contract.

Suggested fix reference: `report/phase2-fix-suggestions-G03.md`, Fix F-01.

### F-02 - Constraint-check result is not enforced by validation

Severity: Medium

Affected file: `outputs/14-data-generator-G03/05-validate-generated-data.sql`

Evidence:

- The validation script outputs generated-data checks from `@Errors` at lines 85-87.
- It runs `DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS` at line 88.
- It throws only when `@Errors` contains nonzero counts at line 89.
- `DBCC CHECKCONSTRAINTS` can return violation rows without being included in `@Errors`.

Why this is a fault:

- The README says generated data must not be used until validation returns zero errors and `DBCC CHECKCONSTRAINTS` is clean.
- The script displays DBCC results but does not fail automatically if DBCC returns rows.
- A user could miss DBCC output and still see the final validation path continue if `@Errors` is clean.

Impact:

- Generated benchmark data could be accepted even when a declarative constraint violation is present.
- Tuning evidence based on that data would be less trustworthy.

Suggested fix reference: `report/phase2-fix-suggestions-G03.md`, Fix F-02.

### F-03 - Tuning report lacks raw captured evidence

Severity: Medium

Affected file: `outputs/15-index-tuning-report-G03.md`

Evidence:

- The report states that actual plans were captured and reads/time used `SET STATISTICS IO,TIME ON` at line 10.
- It provides summarized before/after reads and timings at lines 27-32.
- It gives a reproduction protocol at lines 68-77.
- It does not include raw `STATISTICS IO/TIME` message output, actual XML/profile snippets, or paths to saved plan/evidence files.

Why this is a fault:

- The Phase 2 project rule requires captured actual-plan and `STATISTICS IO/TIME` evidence before and after indexing on the same dataset and parameters.
- A summary table is useful but does not let a reviewer verify actual-vs-estimated plan capture, object-level IO messages, or whether the same parameters were used.

Impact:

- The tuning claim is plausible but under-evidenced for audit/review.
- A reviewer may mark the performance section as incomplete even if the measurements were actually run.

Suggested fix reference: `report/phase2-fix-suggestions-G03.md`, Fix F-03.

### F-04 - Possible missing root `SKILL.md` deliverable

Severity: Medium

Affected files:

- `AGENT.md`
- `.opencode/skills/db-design-pipeline/SKILL.md`
- repository root

Evidence:

- Phase 2 requirement Section 2 states that groups must update `AGENT.md` and `SKILL.md` and briefly describe improvements.
- Phase 2 requirement Section 3.2 repeats that the repository must update `AGENT.md`, `SKILL.md`, and add artifacts 08-16.
- Repository root contains `AGENT.md`, but no root-level `SKILL.md` was found.
- An updated skill file does exist at `.opencode/skills/db-design-pipeline/SKILL.md`.

Why this is a fault:

- If the instructor expects a root-level `SKILL.md`, the repository deliverable is incomplete.
- If the `.opencode` skill is intended to satisfy the requirement, `AGENT.md` should explicitly point to it to avoid ambiguity.

Impact:

- Submission packaging risk, not a database-design correctness issue.

Suggested fix reference: `report/phase2-fix-suggestions-G03.md`, Fix F-04.

### F-05 - Unsafe test scripts omit column lists

Severity: Low

Affected files:

- `outputs/13-concurrency-tests-G03/01-unsafe-session-a.sql`
- `outputs/13-concurrency-tests-G03/02-unsafe-session-b.sql`

Evidence:

- Both scripts use `INSERT dbo.BOOKING_REQUEST VALUES(...)` at line 7 of each file.

Why this is a fault:

- This currently works only because `BOOKING_REQUEST` has the expected non-identity column order.
- If the table gains a column later, the unsafe demonstration can fail for a schema-shape reason unrelated to concurrency.

Impact:

- Low risk for the current Phase 2 artifacts, but easy to make more robust.

Suggested fix reference: `report/phase2-fix-suggestions-G03.md`, Fix F-05.

## Artifact-by-Artifact Notes

### Artifact 08

No blocking fault found. It catalogs Phase 2 requirements, carries open questions, and correctly avoids prescribing physical implementation.

### Artifact 09

No blocking fault found. It preserves Phase 1 relations, adds a compact Phase 2 delta, includes a Mermaid ERD, FDs, and 3NF proof. The design's explicit choice to avoid unsupported tables such as semester master data or approval-method lookup is consistent with the accepted compact design.

### Artifact 10

No blocking fault found. The migration is additive, uses a transaction with rollback, backfills legacy maintenance as out-of-service, adds baseline impact events, and seeds the System actor by stable names.

### Artifact 11

No blocking fault found. The selected per-space transaction-owned `sp_getapplock` protocol addresses the empty-range booking conflict and applies to instant and staff approval paths.

### Artifact 12

Finding F-01 applies. The main approval procedures otherwise follow the reviewed shared-lock protocol and use stable status codes.

### Artifact 13

Finding F-05 applies. The required unsafe and safe two-session cases are present, with actual results recorded for instant/instant, instant/staff, and staff/staff.

### Artifact 14

Finding F-02 applies. The generator otherwise satisfies the headline requirements: 100,000 bookings, three academic years, maintenance, cancellations, no-shows, advisory acknowledgements, and actual validation results.

### Artifact 15

Finding F-03 applies. The selected workloads match the stricter project interpretation: conflict check, room finder, approved hours, and weekday/hour report.

### Artifact 16

No blocking fault found. It implements all four reports using SQL Server procedures, historical approved-decision semantics, room-finder JSON facility matching, advisory count visibility, and escalation event lookup.

## Overall Risk

The Phase 2 package is close to complete. The main corrective action should be to fix F-01 in the implementation and test/smoke it, then strengthen validation/evidence packaging for F-02 and F-03. F-04 should be resolved before submission to avoid a documentation packaging penalty.
