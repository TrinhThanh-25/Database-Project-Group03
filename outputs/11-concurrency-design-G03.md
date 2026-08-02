# Phase 2 Concurrency Design — Group 03

Status: scaffold created; final design depends on artifact 09.

## Required coverage

- Unsafe check-then-write schedule for two instant approvals.
- Unsafe schedule for staff approval racing instant/staff approval.
- Invariant: no two committed approved bookings for one space overlap.
- Shared transaction protocol used by every approval path.
- SQL Server isolation/locking choice, deadlock order, retry/error behavior, and interval semantics.
- Advisory acknowledgement and out-of-service checks in the same atomic workflow.
- Security boundary: direct table writes must not bypass the safe procedures.
- Test matrix linked to `outputs/13-concurrency-tests-G03/`.

Candidate solution for evaluation: transaction-scoped `sp_getapplock` keyed by `space_id`, followed by in-transaction conflict recheck and atomic write. This remains `[proposed — not stated in source]` until analyzed and reviewed.
