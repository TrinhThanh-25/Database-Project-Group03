# Phase 2 Index Tuning Report — Group 03

Status: scaffold created; measured results require a completed schema, generator, and SQL Server test run.

## Workloads

1. Approved-booking conflict check.
2. Room finder (capacity + all required facilities + interval availability).
3. Approved booking hours per space/semester.
4. Approved bookings by weekday/hour/semester.

## Evidence to capture for each workload

- Dataset size/distribution and SQL Server version.
- Exact query and parameter set.
- Baseline indexes and actual execution plan.
- Repeated baseline logical reads, CPU, elapsed time, and median.
- Candidate index rationale and DDL.
- Actual post-index plan and repeated measurements.
- Percentage change, estimate accuracy, storage/write trade-off, and keep/drop decision.

No performance result will be claimed without captured execution evidence.
