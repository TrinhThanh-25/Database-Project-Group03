# Artifact 14 actual results — 2026-08-10

Environment: SQL Server 2022 Developer Edition 16.0.4255.1 (CU25), Linux, disposable database `G03Phase2AuditR1`, compatibility 160. Run ID: `G03-GEN-V2`. The disposable database was removed after the final validation and report smoke test.

| Population | Actual count |
|---|---:|
| Generated users | 120 |
| Generated spaces | 100 |
| Bookings | 100,000 |
| Approval decisions | 70,000 |
| Usage sessions | 20,000 |
| Maintenance records | 100 |
| Impact events | 110 |
| Advisory acknowledgements | 10,890 |

Decision-actor distribution: active `System` actor = 15,000 approved decisions, active facility staff = 45,000 approved decisions and 10,000 rejected decisions. No System decision belongs to an unconfigured space type, and every generated participant count is within the selected space capacity.

Booking status distribution: approved 30,000; checked-in 10,000; pending 20,000; completed, rejected, cancelled, and no-show 10,000 each. Academic-year starts: 2027 = 33,400; 2028 = 33,300; 2029 = 33,300. Both fall and spring date bands are populated in each academic year, for six semester bands.

The final positive run returned zero errors for all 28 checks: booking count, three-year/six-semester-band coverage, time and capacity validity, approved overlap, approvals after out-of-service escalation, current and historical advisory acknowledgement coverage, required maintenance/escalation populations, duplicate acknowledgement pairs, missing/mismatched impact history, maintenance completion consistency, purpose/space/status diversity, decision history/time/actor/cardinality, checked-in/completed usage lifecycle, no-show lifecycle, and rejected decision/reason consistency. `DBCC CHECKCONSTRAINTS` returned no violations.

Three validation rounds were used on 2026-08-10: the clean initial generation passed; a transaction-scoped negative test intentionally introduced one invalid System actor and one over-capacity booking and validation rejected both with error `52430`; cleanup followed by full deterministic regeneration produced the same counts and passed again. The final validation completed in approximately 6.7 seconds after statistics refresh and set-based overlap/history checks. This is correctness/repeatability evidence, not an application-performance claim. Final status: **PASS**.

Post-regeneration analytical smoke execution also passed: report 1 returned 109 spaces, report 2 returned 28 weekday/hour buckets, the representative room finder returned 100 spaces, and a generated escalation event returned 32 affected bookings.
