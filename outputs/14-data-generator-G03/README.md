# Phase 2 Data Generator — Group 03

Status: scaffold created; generator depends on the migrated schema and concurrency contract.

Targets:

- SQL Server-compatible, deterministic, set-based generation.
- At least three academic years / six semesters.
- At least 100,000 booking records; configurable up to 500,000.
- Maintenance, cancellations, no-shows, instant/staff approvals, and advisory acknowledgements.
- Zero overlapping approved bookings per space.
- Validation for counts, date range, FKs, conflicts, and acknowledgement coverage.

Planned files: `00-config.sql`, `01-generate-reference-data.sql`, `02-generate-bookings.sql`, `03-generate-maintenance.sql`, `04-generate-acknowledgements.sql`, and `05-validate-generated-data.sql`.
