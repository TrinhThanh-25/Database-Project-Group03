# Phase 2 Fix Suggestions - Group 03

This file lists concrete fixes for the issues in `report/phase2-fault-review-G03.md`. It does not modify the Phase 2 artifacts by itself.

## Fix F-01 - Capture affected bookings before committing impact escalation

Affected file: `outputs/12-concurrency-implementation-G03.sql`

Goal:

- Keep `MAINTENANCE_RECORD.impact_level_id`, `MAINTENANCE_IMPACT_EVENT`, and the affected-booking set synchronized to one protected escalation point.
- Return the affected-booking set captured while the transaction-owned per-space application lock is still held.

Suggested implementation pattern:

```sql
DECLARE @Affected TABLE(
    booking_request_id INT NOT NULL PRIMARY KEY,
    requester_user_account_id INT NOT NULL,
    user_id NVARCHAR(50) NOT NULL,
    full_name NVARCHAR(200) NOT NULL,
    email NVARCHAR(254) NOT NULL,
    requested_start_time DATETIME2(0) NOT NULL,
    requested_end_time DATETIME2(0) NOT NULL,
    status_code NVARCHAR(40) NOT NULL
);

UPDATE dbo.MAINTENANCE_RECORD
SET impact_level_id = @NewId
WHERE maintenance_record_id = @maintenance_record_id;

INSERT dbo.MAINTENANCE_IMPACT_EVENT(
    maintenance_record_id,
    old_impact_level_id,
    new_impact_level_id,
    changed_at
)
VALUES(@maintenance_record_id, @OldId, @NewId, @ChangedAt);

IF @OldCode = N'advisory' AND @new_impact_level_code = N'out_of_service'
BEGIN
    INSERT @Affected(
        booking_request_id,
        requester_user_account_id,
        user_id,
        full_name,
        email,
        requested_start_time,
        requested_end_time,
        status_code
    )
    SELECT br.booking_request_id,
           br.requester_user_account_id,
           u.user_id,
           u.full_name,
           u.email,
           br.requested_start_time,
           br.requested_end_time,
           bs.status_code
    FROM dbo.BOOKING_REQUEST br
    JOIN dbo.BOOKING_STATUS bs
      ON bs.booking_status_id = br.booking_status_id
    JOIN dbo.USER_ACCOUNT u
      ON u.user_account_id = br.requester_user_account_id
    WHERE br.space_id = @SpaceId
      AND bs.status_code IN(N'approved', N'checked_in')
      AND br.requested_start_time < COALESCE(@End, CONVERT(DATETIME2(0), '9999-12-31'))
      AND br.requested_end_time > CASE WHEN @ChangedAt > @Start THEN @ChangedAt ELSE @Start END;
END;

COMMIT TRANSACTION;

SELECT @maintenance_record_id AS maintenance_record_id,
       @OldCode AS old_impact_level_code,
       @new_impact_level_code AS new_impact_level_code,
       @ChangedAt AS changed_at;

SELECT booking_request_id,
       requester_user_account_id,
       user_id,
       full_name,
       email,
       requested_start_time,
       requested_end_time,
       status_code
FROM @Affected
ORDER BY booking_request_id;
```

Verification after fix:

- Re-run artifact 12 deployment.
- Re-run artifact 13 protected tests to ensure no regression in the shared lock protocol.
- Add one smoke test for `usp_G03_ChangeMaintenanceImpact` using a generated advisory-to-out-of-service event and confirm the returned rows match `usp_G03_ReportBookingsAffectedByEscalation` for that event.

## Fix F-02 - Make DBCC constraint checks fail validation automatically

Affected file: `outputs/14-data-generator-G03/05-validate-generated-data.sql`

Goal:

- Keep the displayed `DBCC CHECKCONSTRAINTS` result, but also fail the script if DBCC returns any violation rows.

Suggested implementation pattern:

```sql
CREATE TABLE #ConstraintViolations(
    table_name SYSNAME NULL,
    constraint_name SYSNAME NULL,
    where_clause NVARCHAR(MAX) NULL
);

INSERT #ConstraintViolations(table_name, constraint_name, where_clause)
EXEC(N'DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS');

SELECT table_name,
       constraint_name,
       where_clause
FROM #ConstraintViolations
ORDER BY table_name, constraint_name;

INSERT @Errors
SELECT N'dbcc_checkconstraints_violations', COUNT_BIG(*)
FROM #ConstraintViolations;

IF EXISTS(SELECT 1 FROM @Errors WHERE error_count <> 0)
    THROW 52430, 'Generated-data validation failed.', 1;
```

Notes:

- Confirm the exact output column names/types for `DBCC CHECKCONSTRAINTS` on the SQL Server version used by the class environment.
- If direct `INSERT EXEC DBCC` is not accepted by the environment, use a wrapper temp table with the observed columns from the local SQL Server instance.

Verification after fix:

- Run the generator on a clean disposable database.
- Run `05-validate-generated-data.sql` and confirm `PASS` with zero DBCC rows.
- In a transaction, intentionally violate a trusted check/FK scenario if possible, run validation, confirm it throws, then roll back.

## Fix F-03 - Attach raw tuning evidence

Affected file: `outputs/15-index-tuning-report-G03.md`

Goal:

- Preserve the existing concise summary, but add auditable raw evidence for before/after IO/TIME and actual plans.

Suggested file structure:

- `outputs/15-index-tuning-evidence-G03/README.md`
- `outputs/15-index-tuning-evidence-G03/W1-before-statistics.txt`
- `outputs/15-index-tuning-evidence-G03/W1-after-statistics.txt`
- `outputs/15-index-tuning-evidence-G03/W1-before-plan.sqlplan` or `W1-before-profile.txt`
- `outputs/15-index-tuning-evidence-G03/W1-after-plan.sqlplan` or `W1-after-profile.txt`
- Repeat the same pattern for W2, W3, and W4.

Minimum content for each workload:

- Exact parameter values.
- Result row count and checksum before indexing.
- `STATISTICS IO` messages before indexing.
- `STATISTICS TIME` messages before indexing.
- Actual-plan evidence before indexing, not estimated plan only.
- Final index DDL applied.
- Result row count and checksum after indexing.
- `STATISTICS IO` messages after indexing.
- `STATISTICS TIME` messages after indexing.
- Actual-plan evidence after indexing.

Suggested report edit:

```markdown
Raw evidence files are stored under `outputs/15-index-tuning-evidence-G03/`.
For each workload, the `*-statistics.txt` files contain the measured `STATISTICS IO/TIME` messages with plan serialization disabled, and the `*-plan.*` files contain actual execution-plan/profile evidence captured separately with identical parameters.
```

Verification after fix:

- Check that every summarized number in `outputs/15-index-tuning-report-G03.md` can be traced to a raw evidence file.
- Confirm actual plan capture is separate from the measured elapsed-time run.
- Confirm result checksums match before and after indexing.

## Fix F-04 - Resolve `SKILL.md` deliverable ambiguity

Affected files:

- `AGENT.md`
- optional new root `SKILL.md`
- `.opencode/skills/db-design-pipeline/SKILL.md`

Goal:

- Make it obvious how the repository satisfies the requirement to update `AGENT.md` and `SKILL.md`.

Option A: add a root pointer file.

```markdown
# Group 03 Skill Entry Point

The assignment refers to `SKILL.md`. The executable OpenCode skill lives at `.opencode/skills/db-design-pipeline/SKILL.md`.

Phase 2 skill improvements include separate handling for requirement changes, schema migration, concurrency design/implementation/tests, large deterministic data generation, analytical queries, and index tuning evidence.
```

Option B: keep only the `.opencode` skill but update `AGENT.md`.

```markdown
The assignment's `SKILL.md` requirement is satisfied by `.opencode/skills/db-design-pipeline/SKILL.md`, which defines the Phase 2 database-design pipeline skill.
```

Recommended option:

- Use Option A. It is small, explicit, and avoids packaging ambiguity.

Verification after fix:

- Confirm repository root contains both `AGENT.md` and `SKILL.md`.
- Confirm `SKILL.md` points to the actual OpenCode skill path.
- Confirm `AGENT.md` still points readers to `AGENTS.md` for canonical pipeline rules.

## Fix F-05 - Add explicit columns to unsafe inserts

Affected files:

- `outputs/13-concurrency-tests-G03/01-unsafe-session-a.sql`
- `outputs/13-concurrency-tests-G03/02-unsafe-session-b.sql`

Goal:

- Keep the unsafe race deliberately naive, but make it robust against harmless column-order changes.

Replace this pattern:

```sql
INSERT dbo.BOOKING_REQUEST VALUES(@U,@S,@A,'2031-01-01T10:00:00','2031-01-01T11:00:00',N'meeting',5);
```

With this pattern:

```sql
INSERT dbo.BOOKING_REQUEST(
    requester_user_account_id,
    space_id,
    booking_status_id,
    requested_start_time,
    requested_end_time,
    purpose_of_use,
    expected_number_of_participants
)
VALUES(@U, @S, @A, '2031-01-01T10:00:00', '2031-01-01T11:00:00', N'meeting', 5);
```

Apply the same explicit column list to Window B with its own interval values.

Verification after fix:

- Re-run `00-setup.sql`.
- Run unsafe Window A and Window B as documented.
- Confirm `03-unsafe-verify.sql` still reports at least one overlapping approved pair.

## Suggested Fix Order

1. Fix F-01 first because it affects the reviewed concurrency/maintenance atomicity contract.
2. Fix F-02 before relying on generated data for final report evidence.
3. Fix F-03 before submission because performance grading usually depends on visible evidence.
4. Fix F-04 before packaging the repository.
5. Fix F-05 when touching artifact 13, because it is low risk and simple.
