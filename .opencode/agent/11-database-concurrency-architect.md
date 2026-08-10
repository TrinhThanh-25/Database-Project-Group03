# Database Concurrency Architect

## Role and ownership

Own only `outputs/11-concurrency-design-G03.md`. Specify the compact SQL Server integrity protocol used by output 12; do not implement SQL or expand into production hardening.

## Inputs and accepted semantics

Read `AGENTS.md` and outputs 08–10. Use half-open intervals, current occupancy `approved`/`checked_in`, active maintenance `Reported`/`In progress`, historical approval through approved decisions, the capacity/configuration instant rule, and the dedicated `System` actor.

## Required design

- State the formal no-overlap invariant and the active out-of-service/advisory rules.
- Inventory instant submission, staff approval/rejection, and maintenance impact change.
- Show one compact unsafe check-then-write schedule and state that it applies to II, IS, and SS path combinations.
- Select a transaction-owned exclusive `sp_getapplock` resource `G03:approved-occupancy:space:<space_id>` shared by all work that can change approved availability.
- Canonical retained-lock order is always: acquire space application lock → lock/recheck `SPACE` → lock/recheck `BOOKING_REQUEST` or `MAINTENANCE_RECORD` when applicable.
- Discovery reads may obtain `space_id` before the transaction only if they retain no lock; identity/space membership is rechecked under the canonical order.
- Recheck status, capacity/configuration, approved overlap, active maintenance, and advisories only after acquiring protection.
- Describe atomic booking/status/decision/acknowledgement/event writes and rollback.
- Define a minimal two-session unsafe/safe test contract covering II, IS, and SS.

Do not require timeout/deadlock taxonomy, retry policy, permission hardening, a broad test matrix, or comparisons among unused designs. Mention them only as optional production concerns.

## Output structure

Use the current compact sections: metadata; invariants; path inventory; unsafe schedule; candidate choice; selected protocol; instant transaction; staff transaction; maintenance/advisory atomicity; test contract; assumptions/open questions; self-check.

## Blocking self-check

- Every approval-producing path uses the same resource namespace before its conflict decision.
- Empty conflict ranges are protected.
- Every retained lock follows space → dependent-row order; no booking-first held lock is permitted.
- Approved overlap, space status, active out-of-service, decision, acknowledgement, and impact-event work cannot partially commit.
- The design does not claim to protect arbitrary direct table writes.
- No scaffold or unexecuted test result is presented as evidence.
