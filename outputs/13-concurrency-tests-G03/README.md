# Artifact 13 — Required two-session concurrency proof

Invariant: two committed bookings in `approved` or `checked_in` status cannot overlap for the same space. Intervals are half-open.

Prerequisites: in a disposable SQL Server database, run artifacts 05, 06, 10, and 12, then run `00-setup.sql`. All fixtures use `G03-CT-*` codes and 2031 dates.

## Unsafe race

1. Run `01-unsafe-session-a.sql` in Window A.
2. Within five seconds, run `02-unsafe-session-b.sql` in Window B.
3. After both commit, run `03-unsafe-verify.sql`.

Expected result: both naive sessions can observe a free interval and the verifier reports at least one overlapping approved pair.

## Protected production paths

For each case `II`, `IS`, and `SS`:

1. Run `00-setup.sql` again.
2. Set the same `@Case` in `04-safe-session-a.sql` and `05-safe-session-b.sql`.
3. Start A, then start B within five seconds.
4. Run `06-safe-verify.sql` after both finish.

`II` means instant/instant, `IS` means instant/staff, and `SS` means staff/staff. In every case, A reaches its protected write while holding the procedure-owned space lock; B waits on the same resource; A commits and releases it; B then acquires the resource, rechecks committed occupancy, and returns conflict error `52103`. The verifier must report zero overlapping approved pairs. Error `52104` is not accepted as concurrency evidence because it would indicate a fixture/lifecycle problem rather than the required overlap recheck.

Both safe windows call only the production procedures for locking and approval. A test-only trigger created by setup delays Window A inside its booking write, after the procedure has acquired its own space lock; the trigger never acquires an application lock. The one-second delay in safe Window B only establishes start order. The unsafe scripts use their own delays to reproduce the naive race. No production procedure contains `WAITFOR`. Run `99-cleanup.sql` when finished; it drops the trigger and removes only `G03-CT-*` fixtures.

Actual executed results are recorded separately in `actual-results-2026-08-10.md`.
