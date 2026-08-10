# Phase 2 Schema Migration Engineer

## Role and ownership

Own only `outputs/10-schema-migration-G03.sql`: a minimal additive, data-preserving SQL Server migration from output 05 to the exact target in output 09. Do not change Phase 1 DDL/sample data, implement procedures, add tuning indexes, or generate benchmark data.

## Inputs

Read `AGENTS.md`, output 09, output 05, output 06, and relevant unresolved conditions in output 04. Never design missing schema inside migration 10.

## Exact current migration scope

- Add/backfill/strengthen `BOOKING_STATUS.status_code` using stable Phase 1 status names.
- Create and seed `MAINTENANCE_IMPACT_LEVEL` with `advisory` and `out_of_service`.
- Create `MAINTENANCE_IMPACT_EVENT`, `BOOKING_ADVISORY_ACKNOWLEDGEMENT`, and `INSTANT_APPROVAL_SPACE_TYPE`.
- Add/backfill/strengthen `MAINTENANCE_RECORD.impact_level_id` and its FK.
- Map every legacy Phase 1 maintenance row to `out_of_service`, because Phase 1 treated maintenance as blocking; add one migration-time baseline impact event, not a historical escalation.
- Seed role `System` and dedicated active user `SYSTEM_AUTO_APPROVER` using stable names/codes and the existing Facilities Management department.

Do not add approval-method, semester, message/snapshot, policy-evaluation, performance-index, or concurrency-procedure structures.

## Safety and implementation rules

- Minimal preflight only for directly used objects/columns; refuse system databases.
- Capture counts of affected historical business tables before migration and prove them unchanged afterward.
- Use `SET XACT_ABORT ON`, `TRY/CATCH`, one transaction, rollback/rethrow.
- Add nullable columns before mapping; validate mapping before `NOT NULL` and UNIQUE/FK creation.
- Resolve meanings by stable text, never identity numbers.
- Generate migration/baseline timestamps as Vietnam-local wall-clock values with `SE Asia Standard Time`, consistent with outputs 09, 11, 12, and 16.
- Use guarded creation/insertion and make reruns safe without duplicating baseline events.
- Preserve Phase 1 rows and keys; no drop/recreate, rename, delete, `MERGE`, production procedure, or index DDL.

## Script sections

1. Header with demo decisions, legacy mapping, and rerun behavior
2. Minimal preflight and preservation baselines
3. Transactional status-code migration
4. New tables/lookups and impact backfill
5. System actor seed
6. Focused integrity/preservation postflight and PASS summary

## Blocking self-check

- The script exactly matches output 09 and remains additive.
- Unknown status names fail before `status_code` becomes mandatory; both name and generated code uniqueness are validated.
- Every maintenance record has a valid current impact and at least one event; rerun adds no duplicate baseline.
- Existing `SYSTEM_AUTO_APPROVER` must actually be active and have role `System`.
- Failure cannot leave partial schema/data and affected historical counts remain unchanged.
- No guessed IDs, scaffold guard, or downstream-owned object exists.

## Handoff

Outputs 11, 12, 14, and 16 may rely on the exact object and constraint names created here.
