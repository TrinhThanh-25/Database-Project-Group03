# Phase 2 Concurrency Design - Group 03

## 1. Metadata and Inputs

Artifact owner: `database-concurrency-architect.md`

Owned output: `outputs/11-concurrency-design-G03.md`

DBMS: Microsoft SQL Server

Purpose: define the concurrency protocol that every operation capable of creating approved occupancy must use before artifact 12 implements executable SQL and artifact 13 verifies two-session behavior.

Authoritative inputs reviewed:

| Input | Used for |
| --- | --- |
| `AGENTS.md` | Phase 2 workflow, SQL Server target, additive design rules, and requirement that approved-booking non-overlap be protected under concurrent instant and staff approval paths. |
| `outputs/08-requirement-change-analysis-G03.md` | P2-BR-18 through P2-BR-21 concurrency scope, unsafe schedules, maintenance/advisory behavior, and unresolved business questions. |
| `outputs/09-updated-erd-and-logical-design-G03.md` | Logical tables, status/method/impact seed codes, half-open interval assumption, and classification of overlap/advisory rules as implementation logic. |
| `outputs/10-schema-migration-G03.sql` | Physical objects available after migration: `BOOKING_STATUS.status_code`, `APPROVAL_METHOD.method_code`, `MAINTENANCE_IMPACT_LEVEL.impact_level_code`, `BOOKING_ADVISORY_ACKNOWLEDGEMENT`, and related constraints. |

No executable stored procedures, grants, indexes, or test scripts are defined in this artifact. Those are owned by artifacts 12, 13, and 15.

Traceability summary:

| Requirement / upstream rule | Concurrency design response |
| --- | --- |
| P2-BR-18 through P2-BR-21: instant and staff approvals must not produce overlapping approved bookings | One shared SQL Server transaction protocol, protected by transaction-scoped `sp_getapplock` on the target `space_id`. |
| P2-BR-03 through P2-BR-05: out-of-service blocks, advisory permits with notice | The same protected transaction performs out-of-service checks and advisory acknowledgement writes immediately before approval. |
| P2-BR-07 through P2-BR-10: multiple active advisory records may overlap | The transaction records one acknowledgement per active overlapping advisory maintenance record. |
| P2-BR-11 through P2-BR-13 and P2-BR-25: maintenance escalation identifies affected approved bookings | Maintenance impact changes use the same `space_id` lock before changing impact and finding overlapping approved bookings. |
| Output 09 implementation classification | Cross-row overlap, maintenance, advisory, and instant/staff race rules are enforced by reviewed transaction logic, not ordinary row constraints. |

## 2. Formal Invariants and Temporal Semantics

### 2.1 Approved-Booking Non-Overlap Invariant

For any two distinct committed `BOOKING_REQUEST` rows `A` and `B`:

```text
If A and B both count as approved occupancy
and A.space_id = B.space_id,
then NOT (A.requested_start_time < B.requested_end_time
          AND A.requested_end_time > B.requested_start_time).
```

This preserves Phase 1 BR-10 as changed by P2-BR-18 through P2-BR-21: simultaneous instant/staff paths must not approve overlapping use of the same space.

### 2.2 Interval Convention

Intervals are treated as half-open `[start, end)` [proposed — not stated in source], matching output 09. Two intervals overlap when:

```text
A.start < B.end AND A.end > B.start
```

Adjacent bookings are allowed:

```text
A.end = B.start
```

Each writer must reject or fail validation when `requested_start_time >= requested_end_time`; this is already represented by the Phase 1/Phase 2 time-ordering check in output 09.

### 2.3 Approved Occupancy Status Semantics

The implemented conflict predicate must use `BOOKING_STATUS.status_code`, not display names.

Statuses that count as approved occupancy [proposed — not stated in source]:

```text
'approved', 'checked_in', 'completed'
```

Statuses that do not count as approved occupancy:

```text
'pending', 'rejected', 'cancelled', 'no_show'
```

Rationale: `checked_in` and `completed` are downstream states of an approved booking and should remain part of approved booking history for reports and edits. This is an assumption because outputs 08 and 10 carry the open question of whether analytical references to "approved bookings" include checked-in and completed records.

### 2.4 Maintenance Impact Semantics

Out-of-service maintenance blocks new approved occupancy when all are true:

```text
same space_id
impact_level_code = 'out_of_service'
maintenance interval overlaps requested booking interval
maintenance record is active/open
```

Advisory maintenance does not block approval, but every active/open advisory maintenance record overlapping the requested booking interval must have a corresponding `BOOKING_ADVISORY_ACKNOWLEDGEMENT` row for the booking.

Active/open maintenance mapping [proposed — not stated in source]: a maintenance record is active/open when `completion_time IS NULL` or when its effective maintenance interval overlaps the requested booking interval. The exact `MAINTENANCE_STATUS.status_name` values that also mean active/open remain an open question carried from outputs 08 through 10.

## 3. Approval and Write-Path Inventory

All operations that can produce or preserve approved occupancy must use the same lock namespace and conflict predicate.

| Path | Creates approved occupancy? | Required concurrency behavior |
| --- | ---: | --- |
| Submit request that remains `pending` | No | Does not require the approved-occupancy lock unless it also writes advisory acknowledgements. Any displayed availability is informational and must be rechecked later. |
| Instant submission that becomes `approved` atomically | Yes | Must run the selected protocol before inserting/updating approved status and instant approval audit. |
| Staff approval of an existing pending request | Yes | Must run the same selected protocol before status change and staff approval decision. |
| Staff rejection of a pending request | No | Does not need the approved-occupancy lock for non-overlap, but still writes normal approval audit. |
| Cancellation that removes future occupancy | Removes | Should use the same `space_id` lock when changing a currently occupancy-counting booking to `cancelled` so concurrent tests and audit reads see deterministic state. |
| Status transition to `checked_in` or `completed` | Preserves | Must use the same lock if the operation can change `space_id`, times, or status from a non-occupancy status into an occupancy status. A pure approved-to-checked-in/completed transition with unchanged interval does not create a new conflict. |
| Edit to `space_id`, `requested_start_time`, or `requested_end_time` of an occupancy-counting booking | May create | Must use the protocol, locking the old and new `space_id` values in ascending order if the space changes. |
| Maintenance escalation to `out_of_service` | Does not cancel existing bookings | Must use the same `space_id` lock before impact change and affected-booking lookup, so new approvals cannot pass between escalation and affected-booking identification. |
| Advisory acknowledgement refresh during approval | Supports approval | Must happen inside the approval transaction after the lock and after re-reading active overlapping advisory records. |

Exact procedure responsibilities for artifact 12:

| Planned procedure responsibility | Required parameters | Required result/error contract |
| --- | --- | --- |
| `dbo.usp_SubmitBookingRequest` | requester account id, `space_id`, requested start/end, purpose/details already supported by Phase 1, and caller-provided advisory acknowledgement token/list if advisory maintenance is present [proposed — not stated in source] | Creates `pending` request for non-instant path, or approved request plus instant `APPROVAL_DECISION` when the request qualifies for instant approval. Returns booking id, final status code, and any advisory set mismatch error. |
| `dbo.usp_ApproveBookingRequest` | staff account id, pending `booking_request_id`, decision note | Changes pending request to `approved` and inserts staff `APPROVAL_DECISION`; fails if conflict, out-of-service maintenance, stale advisory acknowledgement set, lock timeout, or deadlock retry exhaustion occurs. |
| `dbo.usp_CancelBookingRequest` | actor account id, `booking_request_id`, cancellation note/reason if supported [proposed — not stated in source] | Changes future occupancy to `cancelled` using the same lock when the current status counts as occupancy. |
| `dbo.usp_RecordMaintenanceImpactChange` | staff account id, `maintenance_record_id`, new impact level code, change note | Changes maintenance impact, inserts `MAINTENANCE_IMPACT_EVENT`, and returns affected approved bookings when the new impact is `out_of_service`. |

## 4. Unsafe Transaction Schedules

These schedules show why ordinary check-then-write logic is insufficient.

### 4.1 Instant Approval Versus Instant Approval

Initial state: no committed approved occupancy for Space S during `[10:00, 11:00)`.

| Step | Transaction A | Transaction B |
| ---: | --- | --- |
| 1 | Checks conflicts for R1, finds none |  |
| 2 |  | Checks conflicts for R2, finds none |
| 3 | Inserts/sets R1 as `approved` |  |
| 4 |  | Inserts/sets R2 as `approved` |
| 5 | Commits | Commits |

If R1 and R2 overlap on Space S, the invariant is violated. This is the P2-BR-20 instant-approval race described in output 08.

### 4.2 Staff Approval Versus Instant Approval

Initial state: pending R3 and new instant-eligible R4 target the same space with overlapping intervals.

| Step | Staff Transaction A | Instant Transaction B |
| ---: | --- | --- |
| 1 | Loads pending R3 |  |
| 2 | Checks conflicts, finds none |  |
| 3 |  | Checks instant eligibility and conflicts for R4, finds none |
| 4 | Sets R3 to `approved`, writes staff decision |  |
| 5 |  | Inserts/sets R4 as `approved`, writes instant decision |
| 6 | Commits | Commits |

If both observations were made before the other transaction committed, both approvals can commit without a shared lock.

### 4.3 Staff Approval Versus Staff Approval

Initial state: pending R5 and pending R6 overlap on the same space.

| Step | Staff Transaction A | Staff Transaction B |
| ---: | --- | --- |
| 1 | Loads R5 |  |
| 2 |  | Loads R6 |
| 3 | Checks conflicts, finds none |  |
| 4 |  | Checks conflicts, finds none |
| 5 | Approves R5 |  |
| 6 |  | Approves R6 |
| 7 | Commits | Commits |

Staff approval needs the same protocol as instant approval because the risk is the same cross-row overlap.

### 4.4 Maintenance Escalation Versus New Approval

Initial state: advisory maintenance M1 overlaps a future request interval. Staff escalates M1 to out-of-service while a requester is being approved for the same space and time.

| Step | Maintenance Transaction A | Approval Transaction B |
| ---: | --- | --- |
| 1 | Reads M1 and prepares escalation |  |
| 2 |  | Checks no out-of-service maintenance, because M1 is still advisory |
| 3 | Changes M1 to out-of-service |  |
| 4 | Finds affected approved bookings |  |
| 5 |  | Approves new booking |
| 6 | Commits | Commits |

Without a shared `space_id` lock, the affected-booking lookup can miss the new approval or the approval can ignore the escalation. The source says existing affected approved bookings must be found for staff contact, not automatically cancelled.

## 5. Candidate Strategy Comparison

| Strategy | Correct when no matching booking row exists? | Isolation / row-versioning behavior | Granularity | Deadlock / operational risk | Decision |
| --- | --- | --- | --- | --- | --- |
| `READ COMMITTED` check then write | No. If no row matches, there is no row to protect. | Row-versioning settings can make reads even less blocking; ordinary reads do not prevent another approval. | High concurrency but unsafe. | Low blocking but violates invariant. | Rejected. |
| `SERIALIZABLE` with key-range locks and a supporting interval index | Potentially, but only if the query uses an access path that produces a range lock covering the empty conflict interval. | Correctness depends on transaction isolation and lock hints such as `UPDLOCK, HOLDLOCK`; `READ_COMMITTED_SNAPSHOT` does not replace serializable range protection. | Good by indexed range, but fragile if access path changes. | Possible deadlocks on range scans; requires deterministic query/index discipline. | Not selected as primary because artifact 15 owns indexes and an optimizer-dependent range plan is risky for a demo handoff. |
| Transaction-scoped `sp_getapplock` keyed by `space_id` | Yes. The lock resource exists independently of data rows and protects the empty conflict range for that space. | Works under normal SQL Server isolation because the application lock serializes writers before reads/writes. Reads still occur inside a transaction after the lock. | Allows concurrent approvals for different spaces; serializes only writers for the same space. | Low for one-space operations; multi-space operations require sorted lock order. | Selected. |
| Table-level lock around approval | Yes. | Correct but blocks unrelated spaces. | Poor; one space conflict blocks all approval work. | Lower logical risk but unnecessary contention. | Rejected. |
| Optimistic insert/update plus retry | No ordinary SQL Server constraint can express interval overlap across rows. | Retrying after a post-check still permits races unless backed by serializable/app lock. | High but unsafe alone. | Complex failure windows. | Rejected as standalone; retry is used only for lock timeout/deadlock handling. |

Selected strategy: transaction-owned `sp_getapplock`, one exclusive application lock per target `space_id`.

## 6. Selected SQL Server Protocol and Rationale

### 6.1 Lock Resource

Resource name:

```text
G03CampusBooking:ApprovedOccupancy:space_id:{space_id}
```

Rules:

| Item | Required value |
| --- | --- |
| Lock API | `sys.sp_getapplock` |
| Resource | `G03CampusBooking:ApprovedOccupancy:space_id:{space_id}` |
| Mode | `Exclusive` |
| Owner | `Transaction` |
| Acquisition point | After `BEGIN TRANSACTION`, before conflict, out-of-service, advisory, or approval writes |
| Release point | Automatic at `COMMIT` or `ROLLBACK` |
| Timeout | 10,000 ms [proposed — not stated in source] |
| Success return codes | `>= 0` |
| Failure return codes | `< 0`, handled by rollback and a stable application error |

The namespace includes the system purpose and `space_id`, satisfying the need for a stable lock independent of existing rows. It serializes all approval-producing writers for one space while permitting independent spaces to proceed concurrently.

### 6.2 Why This Protects Empty Ranges

The race condition exists even when no conflicting booking currently exists. A row lock cannot protect a row that is not present. The selected app-lock resource is present by name, so the first transaction to acquire `G03CampusBooking:ApprovedOccupancy:space_id:S` forces every other approval-producing writer for Space S to wait before it performs the conflict check. When the second writer later acquires the lock, it rechecks against the first writer's committed result and must fail or choose a non-overlapping interval.

### 6.3 Dependence on Shared Protocol

This design is correct only if every path that can create approved occupancy uses the same namespace. It is not safe to implement separate instant and staff procedures with different lock names, different lock modes, or conflict predicates.

The implementation must centralize the conflict predicate or keep it byte-for-byte equivalent across approval paths. Artifact 12 should treat divergence between instant/staff logic as a correctness defect.

## 7. Transaction Steps for Instant Submission

The instant path creates a booking and approval decision in one database transaction only after the request is known to qualify for instant approval.

Pre-transaction work:

1. Validate request shape and required input fields.
2. Resolve `space_id` and requested interval.
3. Evaluate policy/configuration facts that do not require writer serialization, such as whether the space type appears in `INSTANT_APPROVAL_SPACE_TYPE`.
4. Present advisory information to the requester outside the database transaction if UI acknowledgement is needed.

Database transaction:

1. `BEGIN TRANSACTION`.
2. Acquire `sp_getapplock` on `G03CampusBooking:ApprovedOccupancy:space_id:{space_id}` with `Exclusive`, `Transaction`, and the configured timeout.
3. If the app-lock return code is negative, roll back and return the mapped lock failure.
4. Re-read the target `SPACE` row and verify the space is still bookable according to Phase 1 status rules.
5. Recheck instant-approval eligibility from committed database state.
6. Recheck approved-occupancy conflicts using the formal overlap predicate and occupancy status set.
7. Recheck overlapping active/open out-of-service maintenance; fail if one exists.
8. Re-read overlapping active/open advisory maintenance.
9. Compare the advisory set acknowledged before the transaction with the current advisory set. If the set changed, roll back with `ADVISORY_SET_CHANGED`; do not wait for user interaction inside the transaction.
10. Insert the `BOOKING_REQUEST` row or update the just-created request to `approved`, depending on the artifact 12 implementation style.
11. Insert the instant `APPROVAL_DECISION` row using `APPROVAL_METHOD.method_code = 'instant_approval'` and nullable `decided_by_user_account_id`, as allowed by output 09.
12. Insert one `BOOKING_ADVISORY_ACKNOWLEDGEMENT` row for each active/open advisory maintenance record disclosed for this booking.
13. Commit.

Conflict failure result:

```text
BOOKING_CONFLICT: another approved occupancy for the same space overlaps the requested interval.
```

Out-of-service failure result:

```text
SPACE_OUT_OF_SERVICE: active out-of-service maintenance overlaps the requested interval.
```

Advisory mismatch result:

```text
ADVISORY_SET_CHANGED: advisory maintenance changed after requester acknowledgement; caller must show the current advisory set and retry.
```

## 8. Transaction Steps for Staff Approval

The staff path approves an existing pending booking. It must not rely on availability observed when the request was originally submitted.

Pre-transaction work:

1. Authenticate/authorize staff actor.
2. Collect approval note/decision text outside the database transaction.
3. Identify the pending `booking_request_id`.

Database transaction:

1. `BEGIN TRANSACTION`.
2. Load the target `BOOKING_REQUEST` row for update and confirm its current `BOOKING_STATUS.status_code = 'pending'`.
3. Resolve the target `space_id`, `requested_start_time`, and `requested_end_time` from the locked booking row.
4. Acquire `sp_getapplock` on `G03CampusBooking:ApprovedOccupancy:space_id:{space_id}` with `Exclusive`, `Transaction`, and the configured timeout.
5. If the app-lock return code is negative, roll back and return the mapped lock failure.
6. Recheck approved-occupancy conflicts, excluding the target request id.
7. Recheck overlapping active/open out-of-service maintenance; fail if one exists.
8. Re-read overlapping active/open advisory maintenance. If the requester's acknowledgement set is missing or stale, fail with `ADVISORY_ACK_REQUIRED` or `ADVISORY_SET_CHANGED` according to implementation policy.
9. Update the booking status to `approved`.
10. Insert a staff `APPROVAL_DECISION` row using `APPROVAL_METHOD.method_code = 'staff_approval'`, staff `decided_by_user_account_id`, decision time, note, and outcome status `approved`.
11. Insert any missing `BOOKING_ADVISORY_ACKNOWLEDGEMENT` rows only when the requester has already acknowledged the exact current advisory set before the transaction.
12. Commit.

Important boundary: staff approval cannot pause inside the transaction to ask a requester or staff member to acknowledge newly discovered advisory records. It must roll back and ask the caller to collect acknowledgement outside the transaction.

## 9. Maintenance and Advisory Atomicity

### 9.1 Out-of-Service Maintenance

Approving a booking must check active/open out-of-service maintenance after acquiring the same `space_id` app lock. This prevents a booking from being approved while a concurrent maintenance transaction is escalating the same space.

When a maintenance record is changed to `out_of_service`:

1. Validate actor and requested impact change outside the transaction.
2. `BEGIN TRANSACTION`.
3. Load the maintenance record for update and resolve its `space_id` and maintenance interval.
4. Acquire `sp_getapplock` on `G03CampusBooking:ApprovedOccupancy:space_id:{space_id}`.
5. Re-read current impact level and active/open state.
6. Update `MAINTENANCE_RECORD.impact_level_id`.
7. Insert `MAINTENANCE_IMPACT_EVENT`.
8. Find committed approved-occupancy bookings for the same space whose intervals overlap the maintenance interval.
9. Return that affected-booking set to staff after commit for requester contact.

Existing approved bookings are not automatically cancelled or modified because output 08 states the source requires finding them so staff can contact requesters, not automatic cancellation.

### 9.2 Advisory Acknowledgements

The advisory set is part of the approval decision because P2-BR-05 through P2-BR-08 require notice and stored acknowledgement when advisory maintenance overlaps a booking.

Design rule:

```text
The advisory set displayed to the requester must equal the advisory set re-read inside the protected approval transaction.
```

If the current advisory set differs from the acknowledged set, the transaction rolls back. This is required because multiple active advisory records can exist for one space and some may be added, completed, escalated, or downgraded while the requester is reviewing the page.

The acknowledgement relation already has `UQ_BOOKING_ADVISORY_ACKNOWLEDGEMENT_booking_maintenance`, so retries can be implemented idempotently by artifact 12.

## 10. Lock Order, Timeout, Deadlock, and Retry Policy

### 10.1 Single-Space Operations

Most booking operations target one `space_id`. For these:

1. Validate immutable inputs outside the transaction.
2. `BEGIN TRANSACTION`.
3. Acquire the single app lock.
4. Recheck all facts used to approve.
5. Write.
6. Commit.

### 10.2 Multi-Space Operations

If a future operation can approve or edit bookings for multiple spaces in one transaction [proposed — not stated in source], it must:

1. Build the distinct set of affected `space_id` values.
2. Sort by numeric `space_id` ascending.
3. Acquire `G03CampusBooking:ApprovedOccupancy:space_id:{space_id}` locks in that order.
4. Perform all checks only after all required locks are acquired.

This deterministic order is required to avoid app-lock deadlocks between transactions that touch the same spaces in opposite order.

### 10.3 Timeout Handling

Timeout value: 10 seconds [proposed — not stated in source].

Required mapping:

| `sp_getapplock` result | Meaning | Required behavior |
| ---: | --- | --- |
| `0` or positive | Lock granted or converted | Continue. |
| `-1` | Timeout | Roll back and return `CONCURRENCY_TIMEOUT`; caller may retry. |
| `-2` | Request canceled | Roll back and return `CONCURRENCY_CANCELLED`. |
| `-3` | Deadlock victim | Roll back and retry according to deadlock policy. |
| Other negative code | Lock acquisition error | Roll back and return `CONCURRENCY_LOCK_ERROR`. |

### 10.4 Deadlock and Retry

The design minimizes deadlocks because normal approval paths lock exactly one resource. Still, SQL Server can choose a deadlock victim when maintenance, edits, or multi-space operations are added.

Retry policy [proposed — not stated in source]:

```text
Retry only the whole transaction, never the middle of a transaction.
Maximum attempts: 3.
Backoff: short increasing delay controlled by the caller or procedure.
Do not retry validation failures such as BOOKING_CONFLICT, SPACE_OUT_OF_SERVICE, or ADVISORY_SET_CHANGED.
```

### 10.5 Rollback Behavior

Because the app lock uses `LockOwner = 'Transaction'`, rollback releases the lock. Artifact 13 must include a two-session rollback test to prove a failed/rolled-back approval does not continue blocking the same space.

### 10.6 Different-Space Concurrency

Two transactions for different `space_id` values use different app-lock resources. They should not block each other because the invariant only applies within one space. Artifact 13 must verify this with two sessions approving overlapping times for different spaces.

## 11. Permissions and Bypass Prevention

The app-lock design is only correct when direct writes cannot bypass it.

Required security boundary for artifact 12:

| Object | Direct app-role write access |
| --- | --- |
| `BOOKING_REQUEST` | Deny direct `INSERT`, `UPDATE`, and `DELETE`; use reviewed procedures for approval-producing transitions. |
| `APPROVAL_DECISION` | Deny direct `INSERT`, `UPDATE`, and `DELETE`; decisions are written by reviewed procedures. |
| `BOOKING_ADVISORY_ACKNOWLEDGEMENT` | Deny direct `INSERT`, `UPDATE`, and `DELETE`; acknowledgements are written by reviewed approval workflow. |
| `MAINTENANCE_RECORD` | Deny direct impact/time/status writes except reviewed maintenance procedure. |
| `MAINTENANCE_IMPACT_EVENT` | Deny direct writes except reviewed maintenance procedure. |
| Lookup tables such as `BOOKING_STATUS`, `APPROVAL_METHOD`, and `MAINTENANCE_IMPACT_LEVEL` | Seed/admin-only changes after migration. |

Allowed application surface [proposed — not stated in source]:

```text
Application roles receive EXECUTE on reviewed procedures, not direct table mutation permissions.
```

Administrative or migration accounts may retain table-write permissions, but those are outside normal application operation and must not be used for booking approval workflows.

Optional defense-in-depth for future work: DML triggers could reject direct overlap-creating writes, but this artifact does not require triggers and artifact 12 must not rely on an unimplemented trigger to make the protocol correct.

## 12. Test Matrix and Expected Outcomes

Artifact 13 must provide repeatable two-session scripts with exact execution order, expected result, and actual result placeholders/evidence.

| Test id | Scenario | Session A | Session B | Expected outcome |
| --- | --- | --- | --- | --- |
| CT-01 | Instant vs instant, same space, overlapping intervals | Acquire lock and approve R1, hold before commit | Attempts instant approval R2 | B waits; after A commits, B rechecks and fails `BOOKING_CONFLICT`. |
| CT-02 | Instant vs instant, same space, adjacent intervals | Approves `[10:00, 11:00)` | Approves `[11:00, 12:00)` | Both commit; adjacency is not overlap. |
| CT-03 | Instant vs instant, different spaces, same interval | Approves Space S1 | Approves Space S2 | Both can proceed because app-lock resources differ. |
| CT-04 | Staff vs instant, same space, overlapping intervals | Staff approves pending R3 and holds transaction | Instant path attempts R4 | One commits; the later recheck fails `BOOKING_CONFLICT`. |
| CT-05 | Staff vs staff, same space, overlapping pending requests | Staff approves R5 | Staff approves R6 | One commits; the later recheck fails `BOOKING_CONFLICT`. |
| CT-06 | Rollback releases app lock | Acquires lock then rolls back | Attempts approval for same space | B proceeds after rollback and can commit if no committed conflict exists. |
| CT-07 | Lock timeout | Holds same-space app lock beyond timeout | Attempts approval | B rolls back with `CONCURRENCY_TIMEOUT`; no partial booking/decision rows remain. |
| CT-08 | Deadlock/multi-space ordering | Attempts multi-space operation on spaces 1 then 2 | Attempts multi-space operation using sorted order | No app-lock deadlock from opposite ordering because both acquire ascending `space_id`. |
| CT-09 | Out-of-service blocks approval | Escalates/open maintenance to `out_of_service` and holds | Attempts overlapping approval | B waits; after A commits, B fails `SPACE_OUT_OF_SERVICE`. |
| CT-10 | Maintenance escalation affected-booking set | Existing approved booking overlaps advisory maintenance | Escalates maintenance to out-of-service | Escalation returns the already-approved overlapping booking for staff contact and does not cancel it. |
| CT-11 | Advisory acknowledgement set changes | Displays advisory set to requester, then a new advisory is inserted/escalated before approval | Attempts approval with stale set | Approval rolls back with `ADVISORY_SET_CHANGED`. |
| CT-12 | Advisory acknowledgement rows | Active advisory records A and B overlap approved booking | Approval commits | Exactly one acknowledgement row exists per booking/advisory pair. |
| CT-13 | Direct write bypass | Application role attempts direct update to set overlapping booking approved | N/A | Direct table write is denied; only reviewed procedures can mutate approval-producing state. |

The tests must not claim performance improvement. Performance evidence belongs to artifact 15.

## 13. Assumptions, Risks, and Open Questions

### Assumptions

- The half-open interval convention `[start, end)` is used for booking and maintenance overlap checks [proposed — not stated in source].
- `BOOKING_STATUS.status_code IN ('approved', 'checked_in', 'completed')` counts as approved occupancy for conflict checks and approved-booking reports [proposed — not stated in source].
- `pending`, `rejected`, `cancelled`, and `no_show` do not count as approved occupancy.
- A 10-second app-lock timeout is acceptable for the demo workflow [proposed — not stated in source].
- The system can enforce application access through stored procedures and deny direct table writes to normal app roles [proposed — not stated in source].
- Maintenance active/open detection can be implemented from `completion_time` plus an agreed `MAINTENANCE_STATUS` mapping [proposed — not stated in source].
- Instant approvals create an `APPROVAL_DECISION` row using `APPROVAL_METHOD.method_code = 'instant_approval'` and nullable `decided_by_user_account_id`, following output 09's design [proposed — not stated in source].

### Risks

- Any approval-producing writer that skips the shared `G03CampusBooking:ApprovedOccupancy:space_id:{space_id}` lock can violate the invariant.
- If instant and staff procedures use different status sets, one path may miss a conflict seen by the other path.
- If advisory acknowledgement is collected inside a long database transaction, lock duration and user think time can cause avoidable blocking. The design explicitly requires acknowledgement outside the transaction and revalidation inside it.
- If maintenance active/open status values remain undefined, artifact 12 must choose a conservative predicate and record the same assumption in SQL comments.
- Application locks are not visible as ordinary row locks to developers reading table definitions; artifact 12 should make lock naming and error handling obvious in procedure comments.

### Open Questions Carried Forward

- Which exact space types are eligible for instant approval?
- What executable predicate means a request satisfies the usage policy for instant approval?
- Which `MAINTENANCE_STATUS.status_name` values mean active/open/still open?
- Are `out_of_service` and `advisory` the complete long-term impact-level set, or only the Phase 2 required values?
- Should checked-in and completed bookings always count as approved bookings in every analytical report, or only for conflict history?
- Which actor and business event set bookings to `cancelled` and `no_show`?
- Does maintenance downgrade from out-of-service to advisory require requester notification, or only advisory-to-out-of-service escalation?
