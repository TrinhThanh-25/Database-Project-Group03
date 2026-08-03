# Concurrency Tests - Group 03

Final status: `NOT EXECUTED`

Reason: this workspace does not have `sqlcmd`, and no SQL Server connection was available in the agent environment. The scripts below are written as reproducible SQL Server two-session tests with expected results only. Do not cite them as passed evidence until they are run and actual results are captured.

## Purpose

These scripts verify the Phase 2 invariant from artifacts 11 and 12:

```text
For the same space_id, two committed booking rows whose status_code is
approved, checked_in, or completed must not have overlapping half-open
requested intervals.

Overlap: A.requested_start_time < B.requested_end_time
     AND A.requested_end_time > B.requested_start_time
```

The unsafe scripts demonstrate a naive check-then-write race. The safe scripts call the production procedures in `outputs/12-concurrency-implementation-G03.sql`, especially:

- `dbo.usp_SubmitBookingRequest`
- `dbo.usp_ApproveBookingRequest`
- `dbo.usp_G03_AcquireSpaceApprovalLock`
- `dbo.usp_RecordMaintenanceImpactChange`

## Prerequisites

Run these artifacts in the target database first:

1. `outputs/05-db-definition-G03.sql`
2. `outputs/06-sample-data-G03.sql` if normal seed data is desired
3. `outputs/10-schema-migration-G03.sql`
4. `outputs/12-concurrency-implementation-G03.sql`
5. `outputs/13-concurrency-tests-G03/00-setup.sql`

All scripts assume the current connection is already using the target database. They do not issue `USE` because the database name is environment-specific.

## Fixture Identifiers

Cleanup and verification target only fixture values with these distinctive prefixes:

- User IDs: `G03-CT-%`
- Department: `G03-CT-DEPT`
- Space codes: `G03-CT-%`
- Space type: `G03-CT-InstantType`
- Booking purpose: `meeting`
- Test interval years: `2031` and `2032`

## Required Two-Window Unsafe Test

1. Open Window A and run `01-unsafe-session-a.sql`.
2. When Window A prints the message telling you to start Window B, immediately run `02-unsafe-session-b.sql` in Window B.
3. After both scripts finish, run `03-unsafe-verify.sql`.

Expected result: `03-unsafe-verify.sql` reports at least one overlapping committed approved pair for the unsafe fixture space. This is the race artifact 12 is designed to prevent.

Actual result: `NOT EXECUTED`.

## Required Two-Window Safe Test

1. Run `99-cleanup.sql`, then `00-setup.sql`.
2. Open Window A and run `04-safe-session-a.sql`.
3. When Window A prints the message telling you to start Window B, immediately run `05-safe-session-b.sql` in Window B.
4. After both scripts finish, run `06-safe-verify.sql`.

Expected results:

- Safe instant/instant same-space overlap: one approved booking, one `51220 BOOKING_CONFLICT`.
- Safe staff/instant same-space overlap: one approved booking, one `51220 BOOKING_CONFLICT`.
- Safe staff/staff same-space overlap: one approved booking, one `51220 BOOKING_CONFLICT`.
- Same-time different-space approval while Window A holds another space lock: succeeds, showing unrelated spaces are not serialized by one global lock.
- `06-safe-verify.sql` reports zero overlapping committed approved pairs for safe fixture spaces.

Actual result: `NOT EXECUTED`.

## Boundary and Regression Tests

Run `07-boundary-and-regression-tests.sql` after cleanup/setup. It is a single-session regression script for:

- adjacent intervals allowed;
- same-time different-space approvals allowed;
- out-of-service maintenance blocks approval with error `51221`;
- active advisory maintenance requires acknowledgement with error `51223`;
- acknowledged advisory maintenance creates exactly one acknowledgement row.

Additional two-session regression scripts are included because timeout and rollback require a second live connection:

- Timeout: run `08-timeout-session-a.sql`, then `09-timeout-session-b.sql`.
- Rollback release: run `10-rollback-session-a.sql`, then `11-rollback-session-b.sql`, then `12-timeout-rollback-verify.sql`.

Expected timeout result: Window B returns `51202 CONCURRENCY_TIMEOUT` and no partial booking/decision rows.

Expected rollback result: Window A rolls back its outer transaction, Window B later succeeds, and verification finds exactly one approved rollback fixture booking.

Actual result: `NOT EXECUTED`.

## Interpreting Results

Expected blocking is not by itself a pass. A safe test passes only when the final verification query shows no committed overlap for approved occupancy statuses.

Expected production errors:

| Error | Meaning |
| ---: | --- |
| 51202 | `CONCURRENCY_TIMEOUT` |
| 51220 | `BOOKING_CONFLICT` |
| 51221 | `SPACE_OUT_OF_SERVICE` |
| 51222 | `ADVISORY_SET_CHANGED` |
| 51223 | `ADVISORY_ACK_REQUIRED` |

## Actual Evidence Log

Environment: `NOT EXECUTED`

SQL Server version: `NOT EXECUTED`

Run date: `NOT EXECUTED`

Repetition count: `0`

Actual result files/screenshots: none.

For multi-run conclusions, execute at least 10 repetitions or document why the classroom demonstration uses fewer.

## Cleanup

Run `99-cleanup.sql` after tests. It deletes only rows tied to the `G03-CT-*` fixture identifiers and leaves normal project/sample data intact.
