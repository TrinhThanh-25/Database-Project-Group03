# Phase 2 Large-Scale Data Generator - Group 03

Final status: `NOT EXECUTED`

Reason: this workspace does not have a SQL Server command-line client, so row counts and validation results are expected results only until the scripts are run in SQL Server.

## Purpose

This directory contains a deterministic, set-based SQL Server generator for Phase 2 performance testing. It creates reference data, users, spaces, facilities, semesters, at least 100,000 bookings, decisions, usage sessions, maintenance records, impact history, and advisory acknowledgements.

The generator intentionally uses direct trusted bulk inserts for speed. This is not an application write path and does not replace the artifact 12 concurrency procedures. Generated data may be used for reports and tuning only after `05-validate-generated-data.sql` returns zero invariant violations.

## Execution Order

Run from this directory in SQLCMD mode so each script can include `00-config.sql`:

1. `99-cleanup-generated-data.sql`
2. `01-generate-reference-data.sql`
3. `02-generate-bookings.sql`
4. `03-generate-maintenance.sql`
5. `04-generate-acknowledgements.sql`
6. `05-validate-generated-data.sql`

Prerequisites:

- `outputs/05-db-definition-G03.sql`
- `outputs/10-schema-migration-G03.sql`
- `outputs/12-concurrency-implementation-G03.sql`

## Deterministic Configuration

Defaults in `00-config.sql`:

| Setting | Value |
| --- | --- |
| Run prefix | `G03-LS` |
| Target bookings | `100000` |
| Requester users | `800` |
| Staff users | `20` |
| Spaces | `20` |
| Facilities | `10` |
| Base date | `2028-08-19` |
| Optional batch size | `50000` |
| Academic years | `2028-2029`, `2029-2030`, `2030-2031` |
| Semesters | `6` |

The booking target can be increased to `500000` by changing `G03_TARGET_BOOKINGS` in `00-config.sql` before generation.

## Expected Distribution

The status formula is deterministic over the booking sequence:

| Status code | Approximate share |
| --- | ---: |
| `completed` | 45% |
| `approved` | 15% |
| `checked_in` | 5% |
| `pending` | 15% |
| `cancelled` | 8% |
| `rejected` | 6% |
| `no_show` | 6% |

Every booking receives a non-overlapping slot for its assigned space. Non-approved rows may coexist in the same generated schedule, but the default formula still assigns unique space/time slots to all generated bookings to keep validation simple and deterministic.

Maintenance target population:

- 300 current advisory records overlapping generated booking slots.
- 200 current out-of-service records in off-hour windows that do not overlap generated bookings.
- 100 current out-of-service records labelled as later advisory-to-out-of-service escalations that may overlap already-approved bookings for affected-booking reports.

Advisory acknowledgement population:

- One row per generated approved/checked-in/completed booking and current advisory maintenance record whose intervals overlap.
- Duplicate booking/maintenance pairs are forbidden by validation.

## Expected Validation

`05-validate-generated-data.sql` returns labelled result sets for:

- booking target and academic-year coverage;
- counts by status, semester, purpose, and space;
- generated relation orphan checks;
- duplicate generated codes/business pairs;
- time-order checks;
- approved booking overlap, expected `0`;
- approved booking versus out-of-service maintenance, split into labelled escalation and unlabelled cases. Unlabelled overlap is expected `0`;
- advisory acknowledgement coverage, expected missing count `0`;
- duplicate acknowledgement pairs, expected `0`;
- maintenance impact current-state consistency, expected mismatch count `0`;
- `DBCC CHECKCONSTRAINTS` guidance.

## Actual Evidence

Environment: `NOT EXECUTED`

SQL Server version: `NOT EXECUTED`

Run date: `NOT EXECUTED`

Requested booking count: `100000`

Actual booking count: `NOT EXECUTED`

Generation duration: `NOT EXECUTED`

Validation status: `NOT EXECUTED`

## Cleanup

Run `99-cleanup-generated-data.sql` to delete only rows tied to the `G03-LS` generated users, spaces, facilities, semesters, and maintenance descriptions. The cleanup script leaves normal project/sample data and shared lookup rows intact.
