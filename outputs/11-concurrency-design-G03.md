# Artifact 11 — Concurrency Design

## 1. Metadata and inputs

Status: reviewed implementation contract for Microsoft SQL Server.

Inputs: artifacts 08, 09, and the exact physical schema in artifact 10. This design adds no tables or business rules.

Demo decisions carried from artifact 09:

- intervals are half-open `[start,end)`;
- approved occupancy means current `BOOKING_STATUS.status_code IN ('approved','checked_in')`;
- active/open maintenance means current status name `Reported` or `In progress`;
- an active advisory is an active record whose current impact code is `advisory`;
- instant eligibility means configured `SPACE.space_type` and `expected participants <= SPACE.capacity`; `usage_policy` stays unchanged and is not parsed;
- instant decisions are stored using the dedicated active `System` user.
- every interval parameter and stored booking/maintenance timestamp is interpreted as Vietnam local wall-clock time; generated decision and impact-event timestamps use `SE Asia Standard Time`, independent of the SQL Server host timezone.

## 2. Formal invariants and temporal semantics

For distinct committed bookings `A` and `B`:

```text
if status(A), status(B) ∈ {approved, checked_in}
and A.space_id = B.space_id,
then not (A.start < B.end and A.end > B.start).
```

Boundary-touching intervals are allowed. `Completed`, `Cancelled`, `Rejected`, `Pending`, and `No-show` do not occupy the current schedule under the approved demo rule.

Within one transaction:

1. No booking may become `approved` when an overlapping active `out_of_service` maintenance record exists.
2. A new booking must receive one acknowledgement row for every overlapping active `advisory` record disclosed at submission.
3. Current maintenance impact and the newest impact event must agree.
4. Escalation changes current impact and appends the event atomically; it identifies affected bookings but does not cancel them.

## 3. Approval/write-path inventory

| Path | May create occupancy? | Required behavior |
|---|---:|---|
| Submit non-eligible request | No | Insert `Pending`; still disclose and acknowledge active advisories. |
| Submit instant-eligible request | Yes | Lock, recheck conflict/maintenance, insert `Approved`, insert System decision and acknowledgements atomically. |
| Staff approves Pending request | Yes | Use the same lock/rechecks, update status and insert staff decision atomically. |
| Staff rejects request | No | Update to `Rejected`, require nonblank reason, insert decision. |
| Status changes to `checked_in` | Does not create a new interval | It must originate from an already approved row; a future interface must use the same space lock if it can originate from another status. |
| Cancellation/completion/no-show | Removes occupancy | Not implemented here because upstream transition actors/rules remain open. |
| Maintenance impact change | Can make existing bookings affected | Uses the same space lock, updates current impact, appends event, returns affected bookings. |

## 4. Unsafe schedules

For instant/instant, instant/staff, and staff/staff, the same anomaly is possible with naive `READ COMMITTED`: T1 checks and finds no conflicting committed row; T2 performs the same check before T1 commits; both write Approved; both commit. `UPDLOCK` on existing booking rows alone is insufficient when the conflict range is empty.

## 5. Candidate comparison

Plain `READ COMMITTED` plus a conflict query is unsafe. Group 03 selects a transaction-owned exclusive `sp_getapplock` per space because it protects the conflict domain even when no booking row exists. Indexes improve access but do not replace this integrity protocol.

## 6. Selected SQL Server protocol

- Begin a transaction before acquiring the application lock.
- Resource: `G03:approved-occupancy:space:<space_id>`; mode `Exclusive`; owner `Transaction`; database principal `public`.
- Failure to acquire the lock aborts and rolls back the operation.
- Canonical order is space domain first, dependent row second: acquire the space application lock, lock/recheck `SPACE`, then lock/recheck the target booking or maintenance row when one exists.
- Re-read the space, statuses, capacity, configuration, bookings, and maintenance only after lock acquisition. No `NOLOCK` is permitted.
- Lock releases automatically at commit/rollback.

`sp_getapplock` serializes approval-affecting work for the same space regardless of whether conflicting rows exist. Operations on different spaces use different resources.

Demo boundary: instant and staff approval operations call the artifact-12 procedures. Arbitrary privileged direct table updates are outside the assignment and are not claimed to be protected.

## 7. Instant submission transaction

1. Validate scalar IDs, positive participants, allowed purpose, and `start < end` before the transaction.
2. Begin transaction; acquire the selected space's application lock, then read and lock the `SPACE` row.
3. Re-read the space and stable lookup meanings.
4. Determine eligibility from exact `space_type` configuration and `participants <= capacity`. Do not parse `usage_policy`.
5. If eligible, reject when an overlapping active out-of-service record exists; check overlap against both `approved` and `checked_in`; choose `approved`. Otherwise choose `pending`.
6. Capture every overlapping active advisory in a transaction-local set.
7. Insert `BOOKING_REQUEST`.
8. Insert one acknowledgement per captured advisory.
9. If approved, insert one approved `APPROVAL_DECISION` using the active `System` user.
10. Commit and return booking ID, status code, and acknowledgement count.

The acknowledgement rows and returned advisory result set represent exactly the advisories observed under the lock. Pending submissions also record their booking-time disclosure.

## 8. Staff decision transaction

1. Validate outcome is `approved` or `rejected`; require nonblank reason for rejection.
2. Read the target booking's `space_id` without retaining a row lock, then begin the transaction.
3. Acquire the same space application lock, lock/recheck `SPACE`, then lock/re-read the booking row and verify it still belongs to that space.
4. Reject approval when the current space status is `Temporarily closed` or `Retired`; only `pending` may be decided.
5. Validate that the actor is active and role is `facility staff` or `facility manager`.
6. For approval, check overlapping `approved`/`checked_in` rows excluding the current booking and active out-of-service maintenance.
7. Update the booking status, then insert the decision row; commit.

Existing acknowledgements remain attached to the booking. The source requires notification at booking time, so staff approval does not manufacture a later acknowledgement.

## 9. Maintenance/advisory atomicity

The impact-change operation first reads the maintenance row's `space_id` without retaining a row lock. It then begins a transaction, acquires the same space resource, locks/rechecks `SPACE`, and only then locks/rechecks the maintenance row. It validates active status and a real level change, updates `MAINTENANCE_RECORD.impact_level_id`, and appends `MAINTENANCE_IMPACT_EVENT` with one database timestamp. For advisory → out-of-service it returns current approved occupancy (`approved`, `checked_in`) whose booking interval overlaps the out-of-service period beginning at the escalation time. It does not silently cancel or contact requesters.

## 10. Minimal test contract

| Case | Expected committed result |
|---|---|
| Unsafe instant/instant | Naive scripts can commit two overlapping approved rows |
| Safe instant/instant | At most one approved; loser gets conflict |
| Safe instant/staff | At most one approved |
| Safe staff/staff | At most one approved |

Two real sessions execute each schedule, followed by a committed-state overlap query.

## 11. Assumptions, risks, and open questions

Assumptions are the demo decisions listed in Section 1. Open questions retained: selected instant space types, authorized maintenance actors, cancelled/no-show transitions, reopening completed maintenance, authoritative semester calendar, and whether production needs a real usage-policy evaluator.

## Blocking self-check

- [x] Every approval path uses one namespace and transaction-owned exclusive lock.
- [x] Empty ranges, both occupancy statuses, half-open boundaries, maintenance, and acknowledgements are covered.
- [x] Lock timing/order and the repeatable two-session test contract are explicit.
- [x] No test result or performance claim is asserted here.
