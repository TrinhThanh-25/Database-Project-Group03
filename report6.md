# Review report for `outputs/06-sample-data-G03.sql`

## Scope

- Reviewed file: `outputs/06-sample-data-G03.sql`
- Compared against authoritative DDL: `outputs/05-db-definition-G03.sql`
- Supporting context checked: `outputs/03-logical-design-G03.md`, `outputs/04-design-validation-G03.md`, `.opencode/agent/sample-data-preparer.md`
- Constraint areas checked: table/column existence, insert order, primary keys, foreign keys, unique constraints, check constraints, and implemented triggers.
- Execution note: `sqlcmd` is installed, but no local SQL Server engine/localdb command was found during review, so this is a static review rather than a live execution test.

## Summary

No definite execution-blocking error was found in `outputs/06-sample-data-G03.sql` when it is run after `outputs/05-db-definition-G03.sql` on a clean database, as the file itself assumes.

The sample data appears to satisfy the implemented DDL constraints:

- All inserted tables and columns exist in `outputs/05-db-definition-G03.sql`.
- Parent rows are inserted before child rows.
- FK references resolve to inserted parent rows.
- CHECK values for role, space status, booking purpose, booking status, and time ordering are valid.
- `SPACE_FACILITY(space_id, facility_id)` pairs are unique.
- Approved bookings do not overlap for the same space under the current trigger.
- Bookings do not reference spaces with `Under maintenance`, `Temporarily closed`, or `Retired` status.
- Approval decision makers are `Facility Staff` or `Facility Manager`.
- The rejected booking has a non-null rejection reason.
- Usage-session completion fields are consistently populated or consistently null.

## Potential issues and recommended fixes

| ID | Severity | Potential issue | Evidence | Recommended fix | File to fix if allowed |
|---|---|---|---|---|---|
| R6-01 | Medium | The script is not idempotent. It will fail with duplicate PK/UQ values if run twice without rerunning the DDL drop/recreate script first. | Header lines 11-14 state the script assumes a clean database and is not idempotent. Fixed IDs are inserted with `SET IDENTITY_INSERT`. | If repeatable standalone sample-data execution is required, add dependency-safe cleanup before inserts or wrap inserts in `IF NOT EXISTS` checks. If clean-DDL-first execution is accepted, keep the current design but make sure the grader/test runner runs `outputs/05-db-definition-G03.sql` first. | `outputs/06-sample-data-G03.sql` |
| R6-02 | Low | Decision notes for non-`Approved` current booking statuses may confuse query tests that infer approval state from text. | Approval rows for booking IDs 4, 5, 6, and 7 use notes such as "Initially approved" or "Approved..." while their current statuses are `Cancelled`, `Checked in`, `Completed`, and `No-show`. The DDL has no `decision_outcome` column, so this is not a constraint error. | Make the notes explicit as historical approval notes, for example "Prior approval recorded; booking later cancelled" or "Prior approval recorded; requester did not attend." This keeps the current status clear. | `outputs/06-sample-data-G03.sql` |
| R6-03 | Low | Usage session actual start times occur before requested start times. This is legal under the current DDL, but may be unexpected in business-level validation or demo queries. | Usage session 1 starts at `2026-07-04T08:55:00` for a booking requested from `09:00`; usage session 2 starts at `09:55` for a booking requested from `10:00`. The DDL only checks `actual_end_time > actual_start_time`. | Either document early check-in as a sample-data assumption, or align `actual_start_time` with or after `requested_start_time` if tests expect usage to stay within requested booking windows. | `outputs/06-sample-data-G03.sql`; optionally `outputs/05-db-definition-G03.sql` only if the business rule should be enforced |
| R6-04 | Low | The allowed `SPACE.current_status = 'In use'` value is not represented by any sample `SPACE` row. This is not required for successful execution, but leaves one allowed status untested. | DDL `CK_SPACE_current_status` allows `Available`, `In use`, `Under maintenance`, `Temporarily closed`, and `Retired`; sample spaces cover all except `In use`. | If broader status coverage is desired, add one `SPACE` row with `current_status = 'In use'`, or change the checked-in booking's space status only if doing so will not conflict with the unavailable-space booking trigger at insert time. A safer approach is adding a separate unbooked `In use` space. | `outputs/06-sample-data-G03.sql` |
| R6-05 | Low | Live execution was not verified against SQL Server in this review environment. Static review found no constraint mismatch, but runtime behavior can still depend on database/session setup. | `sqlcmd` exists, but `sqllocaldb`/`sqlservr` were not found in the checked command path. | Run `outputs/05-db-definition-G03.sql` followed by `outputs/06-sample-data-G03.sql` on the target SQL Server instance before submission. | No SQL file change required unless runtime testing finds an actual error |

## Notes on non-issues

- The absence of a `DEPARTMENT` table is handled correctly because the DDL does not implement one; department values are inserted into `USER_ACCOUNT.department`.
- Maintenance reporter roles are mixed, but this is acceptable because the DDL explicitly leaves reporter/assignee role restrictions unresolved.
- `APPROVAL_DECISION` has no `decision_outcome` column in the DDL, so the sample data correctly does not insert that column.
- `MAINTENANCE_RECORD.status` has no CHECK constraint, so values such as `In progress`, `Completed`, and `Pending inspection` are valid under the implemented schema.

## Final assessment

`outputs/06-sample-data-G03.sql` is acceptable under the current DDL and clean-database execution assumption. The main improvement is not a constraint fix but a robustness/clarity improvement: make the sample script idempotent if standalone reruns are expected, and clarify approval notes or early check-in timing if demo queries depend on those semantics.
