# Database Concurrency Implementation Engineer

## Role and ownership

Own only `outputs/12-concurrency-implementation-G03.sql`. Implement the reviewed demo protocol in three rerunnable SQL Server procedures; do not add schema, performance indexes, test fixtures, permissions framework, retry machinery, or production `WAITFOR`.

## Inputs

Read `AGENTS.md`, output 10 as the physical schema, output 11 as the concurrency contract, and output 09 as the semantic cross-check.

## Required interfaces

1. `dbo.usp_G03_SubmitBooking`: validate input and current `SPACE_STATUS`; under the space lock reject active out-of-service overlap, capture all active overlapping advisories, choose instant `approved` only for configured space type and participants `<= capacity`, otherwise `pending`; atomically insert booking, acknowledgements, and System approval decision.
2. `dbo.usp_G03_DecideBooking`: active facility staff/manager may approve or reject only `pending`; rejection needs a reason; approval rechecks space status, current approved occupancy, and active out-of-service under the same space lock; update and decision insert are atomic.
3. `dbo.usp_G03_ChangeMaintenanceImpact`: only active/open maintenance may change between `advisory` and `out_of_service`; update current impact and append one event at the same timestamp; verify latest history agrees; for escalation return currently approved/checked-in bookings overlapping the affected interval beginning at `max(changed_at,start_time)`.

## Locking contract

- A discovery read may find `space_id` without a retained lock.
- Then begin transaction and acquire transaction-owned exclusive resource `G03:approved-occupancy:space:<space_id>`.
- Lock/recheck `SPACE` first, then the target booking or maintenance row. Revalidate that it still belongs to the discovered space.
- All meaning is resolved by stable status/role/code text, never guessed identity values.
- Use `TRY/CATCH`, rollback/rethrow, and `CREATE OR ALTER`.
- Derive decision and impact-event timestamps as Vietnam local wall-clock time with `SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time'`; do not depend on host-local time.

The procedures must acquire protection themselves. Callers and tests must never be required to acquire an application lock or open an outer transaction first.

## Script sections

Header/semantics/errors; submit procedure; staff decision procedure; impact-change procedure; minimal object-ID deployment verification.

## Blocking self-check

- All three interfaces follow space → dependent-row order and the shared namespace.
- Both occupancy statuses and half-open predicate are exact.
- `SPACE_STATUS`, active maintenance, acknowledgements, and approval history are handled as described.
- Invalid or concurrent failure leaves no partial booking, decision, acknowledgement, impact update, or event.
- No procedure parses `usage_policy`, guesses an ID, contains `WAITFOR`, or depends on a caller-held lock.
- Only output-10 objects are referenced and no scaffold remains.
