# Artifact 15 — Index Tuning Report

## 1. Status, environment, and dataset

Status: **EXECUTED — PASS** on 2026-08-10.

- SQL Server 2022 Developer Edition 16.0.4255.1, Linux, compatibility level 160.
- Dedicated benchmark database: `G03Phase2BenchmarkCurrent`.
- The database was rebuilt from the current artifacts 05, 06, 10, 12, 14, and 16. A previously existing database was rejected because it failed the current artifact-14 validator; none of its measurements are used below.
- Dataset: 100,000 `G03-GEN-V2` bookings across academic-year starts 2027–2029, plus nine Phase 1 bookings. It contains 70,007 total approval decisions, 10,890 advisory acknowledgements, and 103 maintenance records.
- Artifact 14 validation returned `PASS`: every recorded error count was zero, the generated booking count was 100,000, and `DBCC CHECKCONSTRAINTS` printed no violation row.
- Before tuning, the four measured fact/association tables had only clustered PK indexes, except for the existing unique `UQ_SPACE_FACILITY_space_id_facility_id`. There was no manual index on `BOOKING_REQUEST`, `APPROVAL_DECISION`, or `MAINTENANCE_RECORD`.
- Result-only output before and after indexing was byte-for-byte identical: 250 lines with SHA-256 `eb44f1c5afeaa1ea9d099ddc16efef4172a9aa665e8ffe4ebef02c49188acd7c`.
- `STATISTICS IO/TIME` was captured with plan serialization disabled. Actual-row plans were captured separately with `SET STATISTICS PROFILE ON`, so plan-output overhead is excluded from the reported elapsed time.

## 2. Fixed workloads and parameters

| Workload | Fixed parameters | Result rows |
|---|---|---:|
| W1 conflict check | Space `G03-GEN-S-050`; current statuses `approved`/`checked_in`; `[2028-09-01 08:00, 09:00)` | 1 |
| W2 room finder | `[2029-09-01 10:00, 11:00)`; capacity 30; generated Projector facility ID | 100 |
| W3 approved hours | Semester `[2027-09-01, 2028-09-01)` | 109 |
| W4 weekday/hour | Same semester; booking-start weekday/hour buckets | 28 |

W1 uses the current occupancy rule. W2–W4 execute the current artifact-16 procedures. W3 and W4 use approved `APPROVAL_DECISION` history rather than inferring historical approval from current booking status.

## 3. Measured before/after results

One compilation/warm-up pass preceded each measured state. The same SQL Server session, database, data, parameters, and result ordering were used before and after indexing.

| Workload | Main logical reads before → after | CPU ms before → after | Elapsed ms before → after | Result equivalence |
|---|---:|---:|---:|---|
| W1 conflict | `BOOKING_REQUEST` 833 → 6 | 7 → 0 displayed | 7 → 0 displayed | 1 row, identical |
| W2 room finder | `BOOKING_REQUEST` 83,300 → 700; `MAINTENANCE_RECORD` 800 → 400; `SPACE_FACILITY` 208 → 208 | 430 → 4 | 430 → 3 | 100 rows, identical |
| W3 approved hours | `BOOKING_REQUEST` 833 → 111; `APPROVAL_DECISION` 864 → 181 | 43 → 40 | 42 → 40 | 109 rows, identical |
| W4 weekday/hour | `BOOKING_REQUEST` 833 → 111; `APPROVAL_DECISION` 864 → 181 | 34 → 28 | 34 → 28 | 28 rows, identical |

Zero milliseconds is SQL Server timer resolution, not zero work. W3 and W4 improve IO substantially but only modestly improve elapsed time on this classroom dataset because the measured semester still contains 33,400 bookings and both reports must aggregate their qualifying rows.

### 3.1 Captured `STATISTICS IO/TIME` evidence

The following normalized excerpts retain the measured table, scan-count, logical-read, physical-read, CPU, and elapsed-time values from the baseline output:

```text
=== W1_CONFLICT ===
Table 'BOOKING_REQUEST'. Scan count 1, logical reads 833, physical reads 0.
CPU time = 7 ms, elapsed time = 7 ms.

=== W2_ROOM_FINDER ===
Table 'MAINTENANCE_RECORD'. Scan count 101, logical reads 800, physical reads 0.
Table 'BOOKING_REQUEST'. Scan count 1, logical reads 83300, physical reads 0.
Table 'SPACE_FACILITY'. Scan count 0, logical reads 208, physical reads 0.
CPU time = 430 ms, elapsed time = 430 ms.

=== W3_APPROVED_HOURS ===
Table 'BOOKING_REQUEST'. Scan count 1, logical reads 833, physical reads 0.
Table 'APPROVAL_DECISION'. Scan count 1, logical reads 864, physical reads 0.
CPU time = 43 ms, elapsed time = 42 ms.

=== W4_WEEKDAY_HOUR ===
Table 'BOOKING_REQUEST'. Scan count 1, logical reads 833, physical reads 0.
Table 'APPROVAL_DECISION'. Scan count 1, logical reads 864, physical reads 0.
CPU time = 34 ms, elapsed time = 34 ms.
```

The corresponding measured output after applying the four retained indexes was:

```text
=== W1_CONFLICT ===
Table 'BOOKING_REQUEST'. Scan count 2, logical reads 6, physical reads 0.
CPU time = 0 ms, elapsed time = 0 ms.

=== W2_ROOM_FINDER ===
Table 'MAINTENANCE_RECORD'. Scan count 200, logical reads 400, physical reads 0.
Table 'BOOKING_REQUEST'. Scan count 200, logical reads 700, physical reads 0.
Table 'SPACE_FACILITY'. Scan count 0, logical reads 208, physical reads 0.
CPU time = 4 ms, elapsed time = 3 ms.

=== W3_APPROVED_HOURS ===
Table 'BOOKING_REQUEST'. Scan count 1, logical reads 111, physical reads 0.
Table 'APPROVAL_DECISION'. Scan count 1, logical reads 181, physical reads 0.
CPU time = 40 ms, elapsed time = 40 ms.

=== W4_WEEKDAY_HOUR ===
Table 'BOOKING_REQUEST'. Scan count 1, logical reads 111, physical reads 0.
Table 'APPROVAL_DECISION'. Scan count 1, logical reads 181, physical reads 0.
CPU time = 28 ms, elapsed time = 28 ms.
```

The increased scan counts in tuned W2 are repeated per-space seeks, not full-table scans; the logical-read reduction from 83,300 to 700 confirms the different access pattern. Supporting lookup reads, including `SPACE_FACILITY` 208, were unchanged and are not hidden in the comparison.

## 4. Captured actual-plan evidence

`SET STATISTICS PROFILE ON` reports actual rows and executions. The profile capture was performed after the measured IO/TIME pass with unchanged parameters.

| Workload | Before indexing | After indexing |
|---|---|---|
| W1 | `Clustered Index Scan` on `PK_BOOKING_REQUEST`; actual output 1 row | `Index Seek` on `IX_BOOKING_REQUEST_space_status_start`; actual output 1 row |
| W2 booking exclusion | Repeated `Clustered Index Scan` on `PK_BOOKING_REQUEST` | Repeated `Index Seek` on `IX_BOOKING_REQUEST_space_status_start` |
| W2 maintenance checks | Two repeated `Clustered Index Scan` operators on `PK_MAINTENANCE_RECORD` | Two repeated `Index Seek` operators on `IX_MAINTENANCE_RECORD_space_status_impact_start` |
| W3 booking range | `Clustered Index Scan` on `PK_BOOKING_REQUEST`; actual input 33,400 rows | `Index Seek` on `IX_BOOKING_REQUEST_start_space`; actual input 33,400 rows |
| W3 approval history | `Clustered Index Scan` on `PK_APPROVAL_DECISION`; actual input 70,007 rows | Covering `Index Scan` on `IX_APPROVAL_DECISION_outcome_booking_time`; 60,007 approved rows flow from the indexed outcome range |
| W4 booking range | `Clustered Index Scan` on `PK_BOOKING_REQUEST`; actual input 33,400 rows | Bounded `Index Seek` on `IX_BOOKING_REQUEST_start_space`; actual input 33,400 rows |
| W4 approval history | `Clustered Index Scan` on `PK_APPROVAL_DECISION`; actual input 70,007 rows | Covering `Index Scan` on `IX_APPROVAL_DECISION_outcome_booking_time`; 60,007 approved rows flow from the indexed outcome range |

Representative raw actual-profile operator text:

```text
W1 before: Clustered Index Scan OBJECT: BOOKING_REQUEST.PK_BOOKING_REQUEST
W1 after:  Index Seek OBJECT: BOOKING_REQUEST.IX_BOOKING_REQUEST_space_status_start

W2 before: Clustered Index Scan OBJECT: BOOKING_REQUEST.PK_BOOKING_REQUEST
W2 after:  Index Seek OBJECT: BOOKING_REQUEST.IX_BOOKING_REQUEST_space_status_start
W2 before: Clustered Index Scan OBJECT: MAINTENANCE_RECORD.PK_MAINTENANCE_RECORD
W2 after:  Index Seek OBJECT: MAINTENANCE_RECORD.IX_MAINTENANCE_RECORD_space_status_impact_start

W3/W4 before: Clustered Index Scan OBJECT: BOOKING_REQUEST.PK_BOOKING_REQUEST
W3/W4 after:  Index Seek OBJECT: BOOKING_REQUEST.IX_BOOKING_REQUEST_start_space
W3/W4 before: Clustered Index Scan OBJECT: APPROVAL_DECISION.PK_APPROVAL_DECISION
W3/W4 after:  Index Scan OBJECT: APPROVAL_DECISION.IX_APPROVAL_DECISION_outcome_booking_time
```

The approval-decision operator remains a scan because approved history is a large fraction of the 70,007 decision rows. The narrower covering index still reduces its logical reads from 864 to 181. Indexes improve access paths; concurrency correctness continues to come from the artifact-11/12 per-space locking protocol.

## 5. Final retained index DDL

```sql
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.BOOKING_REQUEST') AND name=N'IX_BOOKING_REQUEST_space_status_start')
    CREATE INDEX IX_BOOKING_REQUEST_space_status_start
    ON dbo.BOOKING_REQUEST(space_id,booking_status_id,requested_start_time)
    INCLUDE(requested_end_time);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.BOOKING_REQUEST') AND name=N'IX_BOOKING_REQUEST_start_space')
    CREATE INDEX IX_BOOKING_REQUEST_start_space
    ON dbo.BOOKING_REQUEST(requested_start_time,space_id)
    INCLUDE(requested_end_time);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.APPROVAL_DECISION') AND name=N'IX_APPROVAL_DECISION_outcome_booking_time')
    CREATE INDEX IX_APPROVAL_DECISION_outcome_booking_time
    ON dbo.APPROVAL_DECISION(decision_outcome_booking_status_id,booking_request_id,decision_time);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.MAINTENANCE_RECORD') AND name=N'IX_MAINTENANCE_RECORD_space_status_impact_start')
    CREATE INDEX IX_MAINTENANCE_RECORD_space_status_impact_start
    ON dbo.MAINTENANCE_RECORD(space_id,maintenance_status_id,impact_level_id,start_time)
    INCLUDE(completion_time);
```

The two booking indexes have different leading keys: same-space conflict/current room availability and semester time-range reporting. The approval-decision index covers historical approval, and the maintenance index supports both out-of-service exclusion and advisory visibility in the room finder. The existing `(space_id, facility_id)` unique index already serves facility relational division, so no additional facility index is retained.

## 6. Reproduction protocol and limitations

On a clean SQL Server database:

1. Run artifacts 05, 06, 10, 12, the artifact-14 scripts in documented order, and artifact 16.
2. Run artifact 14 validation. Stop unless every error count is zero and `DBCC CHECKCONSTRAINTS` prints no violation row.
3. Confirm the baseline has no manual indexes on `BOOKING_REQUEST`, `APPROVAL_DECISION`, or `MAINTENANCE_RECORD`.
4. Execute W1–W4 once with statistics disabled as the compilation/warm-up pass.
5. Enable `SET STATISTICS IO ON` and `SET STATISTICS TIME ON`, keep `STATISTICS XML/PROFILE` off, and execute W1–W4 once with the fixed parameters in Section 2.
6. Disable IO/TIME, enable `SET STATISTICS PROFILE ON`, and execute the same workloads once to capture actual-row plans separately.
7. Apply exactly the four indexes in Section 5, warm once, and repeat Steps 5–6 with unchanged parameters.
8. Compare the ordered result-only output before comparing IO, time, or operators. This run used an exact file comparison and SHA-256 equality.

This is one controlled warm measurement on one classroom SQL Server instance and one deterministic distribution. Millisecond timings can vary with the host, so logical reads and actual access-path changes are the more stable evidence. The report does not claim production capacity or generalize beyond the measured parameters.
