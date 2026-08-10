# Artifact 13 actual results — 2026-08-10

Environment: SQL Server 2022 Developer Edition 16.0.4255.1 (CU25), Linux, disposable database `G03LocalTimeGeneratorVerify20260810`, compatibility 160. The database was removed after evidence capture.

| Executed case | Actual committed-state evidence | Result |
|---|---|---|
| Unsafe instant/instant | Both naive sessions committed; verifier found 1 overlapping approved pair | PASS: race reproduced |
| Safe instant/instant | A committed; B returned 52103; verifier found 0 overlap pairs | PASS |
| Safe instant/staff | Instant A committed; staff B returned 52103; verifier found 0 overlap pairs | PASS |
| Safe staff/staff | Staff A committed; staff B returned 52103; verifier found 0 overlap pairs | PASS |

One classroom repetition was executed for each required case. In every safe case, both windows called production procedures without acquiring an application lock first: A committed, B acquired the resource afterward, rechecked the committed overlap, and returned `52103`. Production procedures contained no `WAITFOR`; the deterministic protected hold occurred only in the setup-created test trigger after A had acquired its own lock. Final status: **PASS**.
