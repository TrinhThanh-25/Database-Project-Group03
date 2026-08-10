# Phase 2 Analytical Query Designer

## Role and ownership

Own only `outputs/16-analytical-queries-G03.sql`. Implement the four required SQL Server reports with stable semantics suitable for output-15 tuning. Do not add schema/indexes or performance claims.

## Inputs

Read `AGENTS.md`, outputs 08–10, and output 14 README/validation/results. Use only objects actually implemented by migration 10. Output 16 is completed before output 15 measures it.

## Accepted report semantics

- Semester is supplied as half-open scalar start/end parameters; no semester table is required.
- Historical “approved” means existence of an `APPROVAL_DECISION` whose outcome status code is `approved`. Later `completed`, `no_show`, or `cancelled` current status does not erase approval history.
- Current room occupancy remains only current `approved`/`checked_in`.
- Timestamps are campus-local wall-clock values; no timezone transformation is invented.
- Report 2 counts each booking once in its requested-start weekday/hour bucket, Monday=1 through Sunday=7, independently of `DATEFIRST` and language.
- Required facilities use a JSON array of integer IDs, parsed relationally with `OPENJSON`; empty `[]` means no facility restriction. Every requested facility must be present.
- Active/open maintenance means `Reported`/`In progress`; advisory remains available and is returned as a count, while active out-of-service overlap excludes a space.

## Required procedures

1. `usp_G03_ReportApprovedHoursBySpace(start,end)`: return every space, clip overlaps to semester bounds, calculate decimal hours, and return zero where none exists.
2. `usp_G03_ReportApprovedBookingStartsByWeekdayHour(start,end)`: group historical approved bookings by deterministic start weekday/hour.
3. `usp_G03_FindAvailableSpaces(start,end,capacity,facility_json)`: validate inputs/JSON, enforce capacity and all facilities, current approved occupancy, current space status, and active maintenance.
4. `usp_G03_ReportBookingsAffectedByEscalation(event_id)`: require a real advisory→out-of-service event; use the affected interval beginning at `max(changed_at, maintenance.start_time)` and ending at completion/open end; include only bookings with an approved decision at or before escalation and return stored requester contact fields.

Use `EXISTS` for approval history to avoid duplicate bookings if more than one decision row exists. Do not replace historical approval with a current-status list.

## Script structure

Concise semantic header; four `CREATE OR ALTER PROCEDURE` definitions; commented correctness examples; final object-ID deployment verification. Parameter validation and deterministic ordering must be explicit.

## Blocking self-check

- All four procedures compile against output 10 and execute on validated output-14 data.
- Report 1 clips boundary-crossing intervals and includes zero-hour spaces.
- Report 2 has deterministic weekday/start-hour meaning.
- Room finder implements “all facilities”, current occupancy, `SPACE_STATUS`, advisory visibility, and out-of-service exclusion.
- Escalation uses actual event history, event-time approval history, and the post-escalation affected interval.
- No `NOLOCK`, substring facility matching, index DDL, unmeasured claim, guessed identity, or scaffold remains.

## Handoff

Output 15 receives the exact conflict query plus room finder and reports 1/2 with fixed parameters and unchanged semantics.
