# Artifact 15 — Index Tuning Report

## 1. Status, environment, and dataset

Status: **EXECUTED — PASS** on 2026-08-10.

- SQL Server 2022 Developer Edition 16.0.4255.1 (CU25), Linux, compatibility level 160.
- Dataset: `G03-GEN-V2`, 100,000 generated bookings across academic-year starts 2027–2029; artifact 14 validation returned `PASS` with zero approved-overlap errors.
- The corrected generator has 10,890 advisory acknowledgements and 70,000 approval decisions: 15,000 automatic approved decisions use the active `System` actor, while 45,000 approved and 10,000 rejected decisions use active facility staff. It uses four space types, four capacity bands, seven purposes, and every space has all seven lifecycle statuses. Validation rejects an automatic decision on an unconfigured type, an over-capacity participant count, or an overlapping approval made after an out-of-service escalation. W3 and W4 deliberately use approval history rather than inferring historical approval from current status. The actor correction does not change W1–W4 predicates or result aggregates because none of those workloads filters by decision actor.
- Actual plans were captured with `STATISTICS PROFILE/XML`; reads and time used `SET STATISTICS IO,TIME ON`.

The baseline contained clustered PK indexes and `UQ_SPACE_FACILITY_space_id_facility_id`; there were no manual indexes on `BOOKING_REQUEST`, `APPROVAL_DECISION`, or `MAINTENANCE_RECORD`.

## 2. Fixed workloads and parameters

| Workload | Parameters |
|---|---|
| W1 conflict check | Space `G03-GEN-S-050`; statuses approved/checked-in; `2028-09-01 08:00–09:00` |
| W2 room finder | `2029-09-01 10:00–11:00`; capacity 30; generated Projector facility ID; active advisories are present |
| W3 approved hours | Semester `[2027-09-01, 2028-09-01)` |
| W4 weekday/hour | Same semester; booking-start weekday/hour buckets |

The table preserves the captured before/after summary. Acceptance depends on the reproducible same-session protocol in Section 5, not on a required number of repetitions.

## 3. Before/after evidence

| Workload | Main logical reads before → after | CPU ms before → after | Elapsed ms before → after | Rows/checksum unchanged |
|---|---:|---:|---:|---|
| W1 conflict | Booking 833 → 6 | 5 → 0 displayed | 4 → 0 displayed | 1 / 1,123,453,404 — PASS |
| W2 room finder | Booking 83,300 → 700; maintenance 800 → 400; space-facility 208 → 208 | 417 → 5 | 416 → 4 | 100 / 66,896 — PASS |
| W3 approved hours | Booking 833 → 111; approval decision 968 → 181 | 45 → 39 | 45 → 39 | 109 / 16 — PASS |
| W4 weekday/hour | Booking 833 → 111; approval decision 968 → 181 | 35 → 28 | 34 → 28 | 28 / 228 — PASS |

Zero milliseconds is SQL Server timer resolution, not zero work.

Actual-plan observations:

- **W1:** the clustered scan of 100,000 booking rows became a seek on `IX_BOOKING_REQUEST_space_status_start`; requested end time is included to avoid a lookup. Concurrency correctness still comes from the reviewed lock protocol.
- **W2:** repeated full booking scans became per-space seeks on `IX_BOOKING_REQUEST_space_status_start`; per-space maintenance scans became seeks on `IX_MAINTENANCE_RECORD_space_status_impact_start`. The existing `(space_id, facility_id)` unique index remained the facility access path. A separately tested status-leading booking index was not retained because the actual plan did not use it.
- **W3:** the 100,000-row booking scan became a time-range seek on `IX_BOOKING_REQUEST_start_space`. Approval history uses the covering `IX_APPROVAL_DECISION_outcome_booking_time`; it is scanned because the measured semester contains a large fraction of approved decisions, but reads fall from 968 to 181.
- **W4:** the booking side became a bounded start-time seek on `IX_BOOKING_REQUEST_start_space`; approval history uses the same covering decision index. Deterministic weekday/start-hour grouping was unchanged.

## 4. Final index DDL

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

The two booking indexes have different leading keys: same-space conflict/current room availability and historical time-range reporting. The approval-decision index covers the historical approval predicate. The maintenance index serves room availability. The unused status-leading booking candidate and an extra facility index were not retained.

## 5. Reproduction and limitations

On a clean database, run artifacts 05, 06, 10, 12, 14 and 16, then confirm artifact 14 validation, including its statistics refresh. Use one SQL Server session and the exact parameters in Section 2:

1. Execute W1–W4 once with statistics disabled as a compilation/warm-up pass.
2. Enable `SET STATISTICS IO ON` and `SET STATISTICS TIME ON` with `STATISTICS XML OFF`; execute each workload once and save its messages and result set as the baseline.
3. Disable IO/TIME statistics, enable `SET STATISTICS XML ON`, execute each workload once with the same parameters, save the actual plans, then disable XML. This separate capture avoids adding plan serialization to the reported elapsed time.
4. Apply exactly the four retained indexes in Section 4 and execute the same statistics-disabled warm-up pass once.
5. Repeat Steps 2 and 3 once with unchanged parameters.
6. Compare the saved result sets before comparing reads, elapsed time, or operators. A tuning result is invalid if the result differs.

W2–W4 are the procedures in artifact 16. Resolve the W2 facility without guessing its identity value:

```sql
DECLARE @ConflictSpaceId INT=(SELECT space_id FROM dbo.SPACE WHERE unique_space_code=N'G03-GEN-S-050');
SELECT b.booking_request_id,b.requested_start_time,b.requested_end_time
FROM dbo.BOOKING_REQUEST b
JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id
WHERE b.space_id=@ConflictSpaceId
  AND bs.status_code IN(N'approved',N'checked_in')
  AND b.requested_start_time<'2028-09-01T09:00:00'
  AND b.requested_end_time>'2028-09-01T08:00:00';

DECLARE @ProjectorId INT=(SELECT facility_id FROM dbo.FACILITY WHERE facility_name=N'G03-GEN-Projector');
DECLARE @Facilities NVARCHAR(MAX)=CONCAT(N'[',@ProjectorId,N']');
EXEC dbo.usp_G03_FindAvailableSpaces '2029-09-01T10:00:00','2029-09-01T11:00:00',30,@Facilities;
EXEC dbo.usp_G03_ReportApprovedHoursBySpace '2027-09-01T00:00:00','2028-09-01T00:00:00';
EXEC dbo.usp_G03_ReportApprovedBookingStartsByWeekdayHour '2027-09-01T00:00:00','2028-09-01T00:00:00';
```

This is classroom evidence from one SQL Server instance and one deterministic distribution. It does not claim production capacity or generalize beyond the measured parameters.
