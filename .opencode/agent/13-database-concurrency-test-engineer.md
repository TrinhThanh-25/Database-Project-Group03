# Database Concurrency Test Engineer

## Role and ownership

Own only `outputs/13-concurrency-tests-G03/`. Produce the smallest repeatable two-session proof required by Phase 2, using output-12 production procedures for protected cases.

## Inputs

Read `AGENTS.md`, outputs 10–12, and the existing output-13 README/results before changing the suite.

## Required files

`README.md`, `00-setup.sql`, unsafe A/B/verifier scripts `01`–`03`, compact safe A/B/verifier scripts `04`–`06`, and `99-cleanup.sql`. Add an actual-results file only after real execution.

## Required evidence

- Deterministic disposable `G03-CT-*` fixtures.
- One deliberately naive unsafe instant/instant check-then-write race; committed-state verifier must find an overlap.
- Protected instant/instant, instant/staff, and staff/staff cases using the same `@Case`-driven safe scripts: A commits, B rechecks after synchronization and must return exactly conflict `52103`; committed-state verifier must find zero overlaps. Do not accept lifecycle `52104` as equivalent evidence.
- Exact Window A/Window B order, expected outcomes, cleanup, and actual environment/results.

## Self-locking proof rule

Safe scripts must call `usp_G03_SubmitBooking` or `usp_G03_DecideBooking` directly. They must not call `sp_getapplock`, a lock-helper procedure, or hold an outer transaction on behalf of production code.

To make the interleaving deterministic, setup may create a narrowly scoped test-only `AFTER INSERT, UPDATE` trigger controlled by `SESSION_CONTEXT`. It may only delay Window A after the production procedure has reached its booking write, and it must never acquire an application lock. Cleanup must drop the trigger. Production output 12 must contain no `WAITFOR`.

Client error text alone is not proof: execute the verifier after both sessions finish. Keep optional timeout, deadlock, permission, boundary, rollback, retry, and broad regression matrices out of the required suite unless explicitly requested.

## Blocking self-check

- Unsafe and protected demonstrations are separate and require two real sessions.
- Safe callers acquire no lock before invoking the procedures.
- All II/IS/SS combinations were run or clearly marked expected-only.
- Verifiers inspect committed `approved`/`checked_in` half-open overlaps.
- Actual results include error/result and final overlap count, and are never fabricated.
- Setup/cleanup affect only the test trigger and `G03-CT-*` rows; no scaffold remains.
