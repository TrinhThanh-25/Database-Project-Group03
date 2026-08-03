# Phase 2 Index Tuning Report - Group 03

Final status: `NOT EXECUTED`

This artifact was prepared by `database-performance-tuning-engineer.md`, but final evidence-based tuning cannot be completed yet. Artifact 16 is still a scaffold and throws `51002`, artifact 14 is marked `NOT EXECUTED`, and this workspace has no SQL Server client available for actual execution plans or `STATISTICS IO/TIME` capture.

No performance result, improvement percentage, or final index recommendation is claimed in this report.

## 1. Executive Summary

The required tuning workloads are:

1. Approved-booking conflict check from artifact 12.
2. Room finder query from artifact 16.
3. Approved booking hours per space/semester from artifact 16.
4. Approved bookings by weekday/hour/semester from artifact 16.

Current outcome:

| Workload | Status | Reason |
| --- | --- | --- |
| Conflict check | `NOT EXECUTED` | Procedure logic exists in artifact 12, but no validated generated dataset or SQL Server execution evidence is available. |
| Room finder | `BLOCKED` | `outputs/16-analytical-queries-G03.sql` is still scaffold-only. |
| Approved hours report | `BLOCKED` | `outputs/16-analytical-queries-G03.sql` is still scaffold-only. |
| Weekday/hour report | `BLOCKED` | `outputs/16-analytical-queries-G03.sql` is still scaffold-only. |

AGENTS.md states the practical execution order is `14 -> 16 -> 15` even though the tuning report filename is numbered `15`. Artifact 15 must be rerun after artifact 16 is implemented and the generator has been executed/validated on SQL Server.

## 2. Environment and SQL Server Settings

Actual environment: `NOT EXECUTED`

SQL Server version/edition:

```sql
SELECT @@VERSION AS sql_server_version;
SELECT SERVERPROPERTY('Edition') AS edition,
       SERVERPROPERTY('ProductVersion') AS product_version,
       SERVERPROPERTY('ProductLevel') AS product_level;
```

Required database settings to record before measurement:

```sql
SELECT name, compatibility_level, is_read_committed_snapshot_on, snapshot_isolation_state_desc
FROM sys.databases
WHERE database_id = DB_ID();
```

Required benchmark session settings:

```sql
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
SET NOCOUNT ON;
```

No actual settings were captured because `sqlcmd` is not installed in this workspace.

## 3. Dataset Configuration and Validation Status

Planned fixed dataset from artifact 14:

| Setting | Planned value |
| --- | --- |
| Run prefix | `G03-LS` |
| Target bookings | `100000` |
| Optional target | `500000` |
| Academic years | `2028-2029`, `2029-2030`, `2030-2031` |
| Semesters | `6` |
| Requesters | `800` |
| Staff users | `20` |
| Spaces | `20` |
| Facilities | `10` |

Validation status: `NOT EXECUTED`

Required validation gate before tuning:

```text
outputs/14-data-generator-G03/05-validate-generated-data.sql
```

The tuning run must not proceed unless validation shows:

| Check | Required result |
| --- | --- |
| Generated booking count | At least `100000` |
| Academic-year coverage | At least `3` academic years |
| Approved booking overlap pairs | `0` |
| Unlabelled approved/out-of-service maintenance overlaps | `0` |
| Missing advisory acknowledgements | `0` |
| Duplicate acknowledgement pairs/events | `0` |
| FK/orphan checks | `0` orphan rows |
| `DBCC CHECKCONSTRAINTS` | Empty result set |

## 4. Existing Index Inventory

Inventory source: static review of artifacts 05 and 10 only. This is not a live `sys.indexes` inventory.

Existing primary key and unique constraints create SQL Server indexes for:

| Table | Existing indexed constraints |
| --- | --- |
| `ROLE` | `PK_ROLE`, `UQ_ROLE_role_name` |
| `ACCOUNT_STATUS` | `PK_ACCOUNT_STATUS`, `UQ_ACCOUNT_STATUS_status_name` |
| `DEPARTMENT` | `PK_DEPARTMENT`, `UQ_DEPARTMENT_department_name` |
| `USER_ACCOUNT` | `PK_USER_ACCOUNT`, `UQ_USER_ACCOUNT_user_id`, `UQ_USER_ACCOUNT_email` |
| `SPACE_STATUS` | `PK_SPACE_STATUS`, `UQ_SPACE_STATUS_status_name` |
| `SPACE` | `PK_SPACE`, `UQ_SPACE_unique_space_code` |
| `FACILITY` | `PK_FACILITY` |
| `SPACE_FACILITY` | `PK_SPACE_FACILITY`, `UQ_SPACE_FACILITY_space_id_facility_id` |
| `BOOKING_STATUS` | `PK_BOOKING_STATUS`, `UQ_BOOKING_STATUS_status_name`, `UQ_BOOKING_STATUS_status_code` |
| `BOOKING_REQUEST` | `PK_BOOKING_REQUEST` |
| `APPROVAL_DECISION` | `PK_APPROVAL_DECISION` |
| `USAGE_SESSION` | `PK_USAGE_SESSION`, `UQ_USAGE_SESSION_booking_request_id` |
| `MAINTENANCE_STATUS` | `PK_MAINTENANCE_STATUS`, `UQ_MAINTENANCE_STATUS_status_name` |
| `MAINTENANCE_RECORD` | `PK_MAINTENANCE_RECORD` |
| `APPROVAL_METHOD` | `PK_APPROVAL_METHOD`, `UQ_APPROVAL_METHOD_method_code`, `UQ_APPROVAL_METHOD_method_name` |
| `MAINTENANCE_IMPACT_LEVEL` | `PK_MAINTENANCE_IMPACT_LEVEL`, `UQ_MAINTENANCE_IMPACT_LEVEL_impact_level_code`, `UQ_MAINTENANCE_IMPACT_LEVEL_impact_level_name` |
| `ACADEMIC_SEMESTER` | `PK_ACADEMIC_SEMESTER`, `UQ_ACADEMIC_SEMESTER_semester_code`, `UQ_ACADEMIC_SEMESTER_academic_year_label_semester_name` |
| `INSTANT_APPROVAL_SPACE_TYPE` | `PK_INSTANT_APPROVAL_SPACE_TYPE`, `UQ_INSTANT_APPROVAL_SPACE_TYPE_space_type` |
| `MAINTENANCE_IMPACT_EVENT` | `PK_MAINTENANCE_IMPACT_EVENT` |
| `BOOKING_ADVISORY_ACKNOWLEDGEMENT` | `PK_BOOKING_ADVISORY_ACKNOWLEDGEMENT`, `UQ_BOOKING_ADVISORY_ACKNOWLEDGEMENT_booking_maintenance` |

Live inventory query to run before measurement:

```sql
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint,
    STRING_AGG(COL_NAME(ic.object_id, ic.column_id), ', ')
        WITHIN GROUP (ORDER BY ic.key_ordinal) AS key_columns
FROM sys.indexes AS i
JOIN sys.index_columns AS ic
  ON ic.object_id = i.object_id
 AND ic.index_id = i.index_id
WHERE i.object_id IN (
    OBJECT_ID(N'dbo.BOOKING_REQUEST'),
    OBJECT_ID(N'dbo.BOOKING_STATUS'),
    OBJECT_ID(N'dbo.SPACE'),
    OBJECT_ID(N'dbo.SPACE_FACILITY'),
    OBJECT_ID(N'dbo.FACILITY'),
    OBJECT_ID(N'dbo.MAINTENANCE_RECORD'),
    OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_LEVEL'),
    OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_EVENT'),
    OBJECT_ID(N'dbo.ACADEMIC_SEMESTER')
)
GROUP BY i.object_id, i.index_id, i.name, i.type_desc, i.is_unique, i.is_primary_key, i.is_unique_constraint
ORDER BY table_name, index_name;
```

## 5. Benchmark Protocol and Limitations

Protocol required for the final tuning run:

1. Deploy artifacts 05, 10, 12, 14, and 16.
2. Run artifact 14 cleanup/generation/validation on one fixed target count.
3. Save validation output.
4. Capture live index inventory.
5. For each workload, record exact SQL and parameters.
6. Run one compilation/setup execution that is not counted.
7. Run at least five measured warm-cache executions with `STATISTICS IO/TIME`.
8. Save actual execution plans.
9. Add one candidate index at a time.
10. Rerun the same query with the same parameters and same dataset.
11. Verify result equivalence.
12. Record index size and write-path impact.

Current limitations:

- Artifact 16 is incomplete, so three required workload queries do not exist.
- Artifact 14 has not been executed or validated.
- Actual SQL Server plans, reads, CPU, elapsed time, memory grants, warnings, spills, and row estimates were not captured.
- No index DDL is recommended because the agent rules require measurement first.

## 6. Workload 1: Conflict Check Before/After

Query identity: approved-booking conflict predicate inside:

- `dbo.usp_SubmitBookingRequest`
- `dbo.usp_ApproveBookingRequest`

Relevant predicate from artifact 12:

```sql
WHERE br.space_id = @space_id
  AND bs.status_code IN (N'approved', N'checked_in', N'completed')
  AND br.requested_start_time < @requested_end_time
  AND br.requested_end_time > @requested_start_time
```

Representative parameters to use after generator execution:

```sql
DECLARE @space_id INT = (
    SELECT MIN(space_id)
    FROM dbo.SPACE
    WHERE unique_space_code LIKE N'G03-LS-SPACE-%'
);
DECLARE @requested_start_time DATETIME2(0) = '2029-02-10T10:00:00';
DECLARE @requested_end_time   DATETIME2(0) = '2029-02-10T12:00:00';
```

Baseline plan summary: `NOT EXECUTED`

Baseline metrics:

| Metric | Value |
| --- | --- |
| Logical reads | `NOT EXECUTED` |
| CPU time | `NOT EXECUTED` |
| Elapsed time | `NOT EXECUTED` |
| Actual rows | `NOT EXECUTED` |
| Estimated rows | `NOT EXECUTED` |
| Memory grant/spills | `NOT EXECUTED` |

Bottleneck diagnosis: `NOT EXECUTED`

Candidate index/query change: not recommended yet. A likely measurement candidate after baseline capture is a nonclustered index beginning with `BOOKING_REQUEST.space_id` and interval columns, but this remains an untested hypothesis and is not final DDL.

Post-change plan summary: `NOT EXECUTED`

Post-change metrics: `NOT EXECUTED`

Absolute and percentage changes: `NOT EXECUTED`

Result-equivalence check: `NOT EXECUTED`

Keep/drop decision: `NOT EXECUTED`

Concurrency note: even if an index improves the conflict check, it does not replace the transaction-owned `sp_getapplock` protocol from artifacts 11 and 12.

## 7. Workload 2: Room Finder Before/After

Query identity: `BLOCKED`

Reason: `outputs/16-analytical-queries-G03.sql` is scaffold-only and throws:

```text
51002 Scaffold only: complete and migrate the Phase 2 logical design before implementing analytical queries.
```

Expected semantics from artifacts 08 and 09:

- minimum capacity;
- every requested facility must be present;
- requested interval must not overlap approved occupancy for the same space;
- requested interval must not overlap active out-of-service maintenance;
- advisory maintenance does not remove the room from results, but may require notice/acknowledgement in OLTP paths.

Baseline plan summary: `NOT EXECUTED`

Baseline metrics: `NOT EXECUTED`

Bottleneck diagnosis: `NOT EXECUTED`

Candidate index/query-shape change: not recommended before the final query exists and is measured.

Post-change plan summary: `NOT EXECUTED`

Result-equivalence check: `NOT EXECUTED`

Keep/drop decision: `NOT EXECUTED`

## 8. Workload 3: Approved-Hours Report Before/After

Query identity: `BLOCKED`

Reason: artifact 16 is incomplete.

Expected semantics:

- report total approved booking hours by space for a supplied semester;
- approved occupancy status set is `approved`, `checked_in`, `completed` per artifact 11 assumption;
- semester boundaries come from `ACADEMIC_SEMESTER`.

Baseline plan summary: `NOT EXECUTED`

Baseline metrics: `NOT EXECUTED`

Bottleneck diagnosis: `NOT EXECUTED`

Candidate index/query-shape change: not recommended before actual query text, parameters, and baseline evidence exist.

Post-change plan summary: `NOT EXECUTED`

Result-equivalence check: `NOT EXECUTED`

Keep/drop decision: `NOT EXECUTED`

## 9. Workload 4: Weekday/Hour Report Before/After

Query identity: `BLOCKED`

Reason: artifact 16 is incomplete.

Expected semantics:

- report approved booking counts by weekday and hour for a supplied semester;
- approved occupancy status set is `approved`, `checked_in`, `completed`;
- semester boundaries come from `ACADEMIC_SEMESTER`.

Baseline plan summary: `NOT EXECUTED`

Baseline metrics: `NOT EXECUTED`

Bottleneck diagnosis: `NOT EXECUTED`

Candidate index/query-shape change: not recommended before actual query text, parameters, and baseline evidence exist.

Post-change plan summary: `NOT EXECUTED`

Result-equivalence check: `NOT EXECUTED`

Keep/drop decision: `NOT EXECUTED`

## 10. Final Index DDL and Deployment Order

Final index DDL: none.

Reason: the tuning agent may recommend and script indexes only after actual measurement on the finalized workloads and one fixed validated dataset. That evidence is not available.

Deployment order for the future measured report:

1. Capture baseline metrics with no manual tuning indexes.
2. Create first candidate index.
3. Refresh statistics only under the documented protocol.
4. Rerun identical workload measurements.
5. Keep or drop the candidate.
6. Repeat for remaining candidates.
7. Publish only the final minimal kept DDL.

## 11. Redundant/Rejected Candidate Indexes

No candidate index was tested, so no candidate is accepted or rejected as evidence.

Pre-measurement cautions for the later tuning run:

- Do not duplicate existing PK/UQ indexes.
- Do not create filtered indexes that depend on hard-coded lookup identity values.
- Do not cover every selected column by default.
- Do not remove correctness predicates from room finder or conflict checks.
- Do not use `NOLOCK`.
- Do not treat an index as a substitute for the same-space application lock.

## 12. Storage and Write Trade-Offs

Storage/write analysis status: `NOT EXECUTED`

The final measured report must include:

```sql
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    SUM(ps.used_page_count) * 8.0 / 1024.0 AS used_mb
FROM sys.indexes AS i
JOIN sys.dm_db_partition_stats AS ps
  ON ps.object_id = i.object_id
 AND ps.index_id = i.index_id
WHERE OBJECT_SCHEMA_NAME(i.object_id) = N'dbo'
GROUP BY i.object_id, i.name
ORDER BY used_mb DESC;
```

Write-path impact to evaluate:

- `BOOKING_REQUEST` insert/update cost for generator loads and OLTP approvals.
- `APPROVAL_DECISION` insert cost.
- `BOOKING_ADVISORY_ACKNOWLEDGEMENT` insert cost.
- `MAINTENANCE_RECORD` impact/time update cost.
- `SPACE_FACILITY` maintenance cost if room-finder indexes are added.

## 13. Reproduction Instructions

To complete artifact 15 with evidence:

1. Run agent 16 and replace `outputs/16-analytical-queries-G03.sql` with executable analytical queries.
2. Deploy artifacts 05, 10, 12, 14, and 16 in SQL Server.
3. Run:

```text
outputs/14-data-generator-G03/99-cleanup-generated-data.sql
outputs/14-data-generator-G03/01-generate-reference-data.sql
outputs/14-data-generator-G03/02-generate-bookings.sql
outputs/14-data-generator-G03/03-generate-maintenance.sql
outputs/14-data-generator-G03/04-generate-acknowledgements.sql
outputs/14-data-generator-G03/05-validate-generated-data.sql
```

4. Save validation output.
5. Capture baseline index inventory.
6. Capture actual plans and `STATISTICS IO/TIME` for all four workloads.
7. Test candidate indexes one at a time.
8. Verify result equivalence after each candidate.
9. Fill this report with measured before/after evidence and final DDL.

## 14. Assumptions, Limitations, and Open Questions

Assumptions:

- SQL Server remains the DBMS target.
- Artifact 14's default `G03-LS` generated dataset is the intended fixed benchmark dataset.
- Approved occupancy status set remains `approved`, `checked_in`, `completed`.
- Room finder and reporting query semantics will be implemented in artifact 16 without changing business meaning.

Limitations:

- This report contains no actual execution evidence.
- Artifact 16 is incomplete, so three required workloads cannot be benchmarked.
- Artifact 14 validation has not been executed.
- No final DDL is recommended.

Open questions:

- Which SQL Server version/edition and compatibility level will be used for final measurement?
- Will the final dataset target be `100000` or `500000` bookings?
- Will measurements be performed warm-cache only, or also cold-cache on an isolated test instance?
- Which exact parameter sets from artifact 16 should represent average and worst-case room-finder/report workloads?
