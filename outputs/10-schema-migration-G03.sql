/*
 Artifact 10 — Phase 2 additive migration (SQL Server, Group 03)

 Target: the Phase 2 additions required by artifact 09.
 Demo decisions: active/open maintenance = Reported or In progress; approved
 occupancy = approved or checked_in; instant eligibility compares expected
 participants with SPACE.capacity; automatic decisions use a dedicated active
 USER_ACCOUNT assigned role System. SPACE.usage_policy is preserved unchanged.
 Every business DATETIME2 value uses Vietnam-local wall-clock time; timestamps
 generated here are converted with SQL Server zone SE Asia Standard Time.

 Legacy mapping [approved demo assumption]: every Phase 1 maintenance row is
 imported with current impact out_of_service because Phase 1 treated all
 maintenance as blocking. One event stamped at migration time establishes the
 imported baseline; it is not represented as a historical escalation.

 The migration is additive: it does not drop Phase 1 tables or delete Phase 1
 rows. It is safely rerunnable. Failure rolls back the current transaction.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

/* 1. Minimal preflight for objects directly used by this migration. */
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 52000, 'Run migration in the Group 03 application database.', 1;

IF OBJECT_ID(N'dbo.ROLE', N'U') IS NULL
 OR OBJECT_ID(N'dbo.ACCOUNT_STATUS', N'U') IS NULL
 OR OBJECT_ID(N'dbo.DEPARTMENT', N'U') IS NULL
 OR OBJECT_ID(N'dbo.USER_ACCOUNT', N'U') IS NULL
 OR OBJECT_ID(N'dbo.SPACE', N'U') IS NULL
 OR OBJECT_ID(N'dbo.BOOKING_STATUS', N'U') IS NULL
 OR OBJECT_ID(N'dbo.BOOKING_REQUEST', N'U') IS NULL
 OR OBJECT_ID(N'dbo.APPROVAL_DECISION', N'U') IS NULL
 OR OBJECT_ID(N'dbo.MAINTENANCE_RECORD', N'U') IS NULL
    THROW 52001, 'Unsupported source schema: required Phase 1 table is missing.', 1;

IF COL_LENGTH(N'dbo.SPACE', N'space_type') IS NULL
 OR COL_LENGTH(N'dbo.BOOKING_STATUS', N'status_name') IS NULL
 OR COL_LENGTH(N'dbo.MAINTENANCE_RECORD', N'maintenance_record_id') IS NULL
    THROW 52002, 'Unsupported source schema: required Phase 1 column is missing.', 1;

/* Counts prove that the three historical business tables affected by new
   relationships survive the additive migration. */
DECLARE @Baseline TABLE(table_name SYSNAME PRIMARY KEY, row_count BIGINT NOT NULL);
INSERT @Baseline VALUES
 (N'BOOKING_REQUEST',   (SELECT COUNT_BIG(*) FROM dbo.BOOKING_REQUEST)),
 (N'APPROVAL_DECISION', (SELECT COUNT_BIG(*) FROM dbo.APPROVAL_DECISION)),
 (N'MAINTENANCE_RECORD',(SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_RECORD));

BEGIN TRY
    BEGIN TRANSACTION;

    /* 2. Stable booking codes: nullable -> validated backfill -> NOT NULL. */
    IF COL_LENGTH(N'dbo.BOOKING_STATUS', N'status_code') IS NULL
        EXEC(N'ALTER TABLE dbo.BOOKING_STATUS ADD status_code NVARCHAR(40) NULL;');

    EXEC(N'UPDATE dbo.BOOKING_STATUS
       SET status_code = CASE LOWER(LTRIM(RTRIM(status_name)))
            WHEN N''pending'' THEN N''pending''
            WHEN N''approved'' THEN N''approved''
            WHEN N''rejected'' THEN N''rejected''
            WHEN N''cancelled'' THEN N''cancelled''
            WHEN N''checked in'' THEN N''checked_in''
            WHEN N''completed'' THEN N''completed''
            WHEN N''no-show'' THEN N''no_show''
          END
     WHERE status_code IS NULL;');

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.BOOKING_STATUS') AND name=N'status_code' AND is_nullable=1)
       AND EXISTS (SELECT 1 FROM dbo.BOOKING_STATUS WHERE status_name NOT IN(N'Pending',N'Approved',N'Rejected',N'Cancelled',N'Checked in',N'Completed',N'No-show'))
        THROW 52004, 'BOOKING_STATUS contains an unmapped status_name.', 1;
    IF CONVERT(INT,(SELECT COUNT(*) FROM dbo.BOOKING_STATUS))<>CONVERT(INT,(SELECT COUNT(DISTINCT status_name) FROM dbo.BOOKING_STATUS))
        THROW 52005, 'BOOKING_STATUS status_name backfill is not unique.', 1;

    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.BOOKING_STATUS') AND name=N'status_code' AND is_nullable=1)
        EXEC(N'ALTER TABLE dbo.BOOKING_STATUS ALTER COLUMN status_code NVARCHAR(40) NOT NULL;');
    IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.BOOKING_STATUS') AND name=N'UQ_BOOKING_STATUS_status_code')
        EXEC(N'ALTER TABLE dbo.BOOKING_STATUS ADD CONSTRAINT UQ_BOOKING_STATUS_status_code UNIQUE(status_code);');

    /* 3. New lookup and entity/history/association tables. */
    IF OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_LEVEL', N'U') IS NULL
        CREATE TABLE dbo.MAINTENANCE_IMPACT_LEVEL(
            impact_level_id INT IDENTITY(1,1) NOT NULL,
            impact_level_code NVARCHAR(40) NOT NULL,
            CONSTRAINT PK_MAINTENANCE_IMPACT_LEVEL PRIMARY KEY(impact_level_id),
            CONSTRAINT UQ_MAINTENANCE_IMPACT_LEVEL_impact_level_code UNIQUE(impact_level_code)
        );

    IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code=N'advisory')
        INSERT dbo.MAINTENANCE_IMPACT_LEVEL(impact_level_code) VALUES(N'advisory');
    IF NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code=N'out_of_service')
        INSERT dbo.MAINTENANCE_IMPACT_LEVEL(impact_level_code) VALUES(N'out_of_service');

    IF OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_EVENT', N'U') IS NULL
        CREATE TABLE dbo.MAINTENANCE_IMPACT_EVENT(
            maintenance_impact_event_id INT IDENTITY(1,1) NOT NULL,
            maintenance_record_id INT NOT NULL,
            old_impact_level_id INT NULL,
            new_impact_level_id INT NOT NULL,
            changed_at DATETIME2(0) NOT NULL CONSTRAINT DF_MAINTENANCE_IMPACT_EVENT_changed_at
                DEFAULT (CONVERT(DATETIME2(0),SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time')),
            CONSTRAINT PK_MAINTENANCE_IMPACT_EVENT PRIMARY KEY(maintenance_impact_event_id),
            CONSTRAINT FK_MAINTENANCE_IMPACT_EVENT_maintenance_record_id FOREIGN KEY(maintenance_record_id) REFERENCES dbo.MAINTENANCE_RECORD(maintenance_record_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_MAINTENANCE_IMPACT_EVENT_old_impact_level_id FOREIGN KEY(old_impact_level_id) REFERENCES dbo.MAINTENANCE_IMPACT_LEVEL(impact_level_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_MAINTENANCE_IMPACT_EVENT_new_impact_level_id FOREIGN KEY(new_impact_level_id) REFERENCES dbo.MAINTENANCE_IMPACT_LEVEL(impact_level_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT CK_MAINTENANCE_IMPACT_EVENT_distinct_levels CHECK(old_impact_level_id IS NULL OR old_impact_level_id<>new_impact_level_id)
        );

    IF OBJECT_ID(N'dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT', N'U') IS NULL
        CREATE TABLE dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT(
            advisory_acknowledgement_id INT IDENTITY(1,1) NOT NULL,
            booking_request_id INT NOT NULL,
            maintenance_record_id INT NOT NULL,
            CONSTRAINT PK_BOOKING_ADVISORY_ACKNOWLEDGEMENT PRIMARY KEY(advisory_acknowledgement_id),
            CONSTRAINT UQ_BOOKING_ADVISORY_ACKNOWLEDGEMENT_booking_maintenance UNIQUE(booking_request_id,maintenance_record_id),
            CONSTRAINT FK_BOOKING_ADVISORY_ACKNOWLEDGEMENT_booking_request_id FOREIGN KEY(booking_request_id) REFERENCES dbo.BOOKING_REQUEST(booking_request_id) ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT FK_BOOKING_ADVISORY_ACKNOWLEDGEMENT_maintenance_record_id FOREIGN KEY(maintenance_record_id) REFERENCES dbo.MAINTENANCE_RECORD(maintenance_record_id) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

    IF OBJECT_ID(N'dbo.INSTANT_APPROVAL_SPACE_TYPE', N'U') IS NULL
        CREATE TABLE dbo.INSTANT_APPROVAL_SPACE_TYPE(
            instant_approval_space_type_id INT IDENTITY(1,1) NOT NULL,
            space_type NVARCHAR(100) NOT NULL,
            CONSTRAINT PK_INSTANT_APPROVAL_SPACE_TYPE PRIMARY KEY(instant_approval_space_type_id),
            CONSTRAINT UQ_INSTANT_APPROVAL_SPACE_TYPE_space_type UNIQUE(space_type),
            CONSTRAINT CK_INSTANT_APPROVAL_SPACE_TYPE_nonblank CHECK(LTRIM(RTRIM(space_type))<>N'')
        );

    /* 4. Add/backfill current maintenance impact. */
    IF COL_LENGTH(N'dbo.MAINTENANCE_RECORD', N'impact_level_id') IS NULL
        EXEC(N'ALTER TABLE dbo.MAINTENANCE_RECORD ADD impact_level_id INT NULL;');

    DECLARE @OutOfServiceId INT=(SELECT impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code=N'out_of_service');
    EXEC sys.sp_executesql N'UPDATE dbo.MAINTENANCE_RECORD SET impact_level_id=@ImpactId WHERE impact_level_id IS NULL;',N'@ImpactId INT',@OutOfServiceId;

    DECLARE @BadImpactRows INT;
    EXEC sys.sp_executesql N'SELECT @Bad=COUNT(*) FROM dbo.MAINTENANCE_RECORD WHERE impact_level_id IS NULL;',N'@Bad INT OUTPUT',@BadImpactRows OUTPUT;
    IF @BadImpactRows<>0
        THROW 52006, 'Maintenance impact backfill failed.', 1;
    IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.MAINTENANCE_RECORD') AND name=N'impact_level_id' AND is_nullable=1)
        EXEC(N'ALTER TABLE dbo.MAINTENANCE_RECORD ALTER COLUMN impact_level_id INT NOT NULL;');
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.MAINTENANCE_RECORD') AND name=N'FK_MAINTENANCE_RECORD_impact_level_id')
        EXEC(N'ALTER TABLE dbo.MAINTENANCE_RECORD WITH CHECK ADD CONSTRAINT FK_MAINTENANCE_RECORD_impact_level_id FOREIGN KEY(impact_level_id) REFERENCES dbo.MAINTENANCE_IMPACT_LEVEL(impact_level_id) ON DELETE NO ACTION ON UPDATE NO ACTION;');

    DECLARE @MigrationTime DATETIME2(0)=CONVERT(DATETIME2(0),SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
    EXEC sys.sp_executesql N'INSERT dbo.MAINTENANCE_IMPACT_EVENT(maintenance_record_id,old_impact_level_id,new_impact_level_id,changed_at)
      SELECT mr.maintenance_record_id,NULL,mr.impact_level_id,@At FROM dbo.MAINTENANCE_RECORD mr
      WHERE NOT EXISTS (SELECT 1 FROM dbo.MAINTENANCE_IMPACT_EVENT e WHERE e.maintenance_record_id=mr.maintenance_record_id);',N'@At DATETIME2(0)',@MigrationTime;

    /* 5. Demo automatic-decision actor; meanings are resolved by names. */
    IF NOT EXISTS (SELECT 1 FROM dbo.ROLE WHERE role_name=N'System')
        INSERT dbo.ROLE(role_name) VALUES(N'System');

    DECLARE @SystemRoleId INT=(SELECT role_id FROM dbo.ROLE WHERE role_name=N'System');
    DECLARE @ActiveStatusId INT=(SELECT account_status_id FROM dbo.ACCOUNT_STATUS WHERE status_name=N'Active');
    DECLARE @SystemDepartmentId INT=(SELECT department_id FROM dbo.DEPARTMENT WHERE department_name=N'Facilities Management');
    IF @ActiveStatusId IS NULL OR @SystemDepartmentId IS NULL
        THROW 52007, 'System user requires Active account status and Facilities Management department.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.USER_ACCOUNT WHERE user_id=N'SYSTEM_AUTO_APPROVER')
        INSERT dbo.USER_ACCOUNT(user_id,full_name,email,phone_number,department_id,role_id,account_status_id)
        VALUES(N'SYSTEM_AUTO_APPROVER',N'Automatic Approval System',N'system-auto-approver@internal.invalid',N'N/A',@SystemDepartmentId,@SystemRoleId,@ActiveStatusId);

    IF NOT EXISTS (
        SELECT 1 FROM dbo.USER_ACCOUNT u JOIN dbo.ROLE r ON r.role_id=u.role_id
        JOIN dbo.ACCOUNT_STATUS a ON a.account_status_id=u.account_status_id
        WHERE u.user_id=N'SYSTEM_AUTO_APPROVER' AND r.role_name=N'System' AND a.status_name=N'Active')
        THROW 52008, 'Existing SYSTEM_AUTO_APPROVER does not have active System identity.', 1;

    /* 6. Minimal postflight: new maintenance state is valid and historical
       booking/decision/maintenance rows were not removed. */
    SET @BadImpactRows=0;
    EXEC sys.sp_executesql N'SELECT @Bad=COUNT(*) FROM dbo.MAINTENANCE_RECORD mr LEFT JOIN dbo.MAINTENANCE_IMPACT_LEVEL il ON il.impact_level_id=mr.impact_level_id WHERE il.impact_level_id IS NULL;',N'@Bad INT OUTPUT',@BadImpactRows OUTPUT;
    IF @BadImpactRows<>0
        THROW 52009, 'Orphan maintenance impact detected.', 1;
    IF EXISTS (SELECT 1 FROM dbo.MAINTENANCE_RECORD mr WHERE NOT EXISTS(SELECT 1 FROM dbo.MAINTENANCE_IMPACT_EVENT e WHERE e.maintenance_record_id=mr.maintenance_record_id))
        THROW 52010, 'Maintenance record without baseline/history event detected.', 1;

    IF (SELECT COUNT_BIG(*) FROM dbo.BOOKING_REQUEST)<>(SELECT row_count FROM @Baseline WHERE table_name=N'BOOKING_REQUEST')
     OR (SELECT COUNT_BIG(*) FROM dbo.APPROVAL_DECISION)<>(SELECT row_count FROM @Baseline WHERE table_name=N'APPROVAL_DECISION')
     OR (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_RECORD)<>(SELECT row_count FROM @Baseline WHERE table_name=N'MAINTENANCE_RECORD')
        THROW 52011, 'Phase 1 business-row count changed unexpectedly.', 1;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;

SELECT N'PASS' AS migration_status,
       (SELECT COUNT_BIG(*) FROM dbo.BOOKING_REQUEST) AS booking_rows_preserved,
       (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_RECORD) AS maintenance_rows_preserved,
       (SELECT COUNT_BIG(*) FROM dbo.MAINTENANCE_IMPACT_EVENT) AS impact_event_rows,
       (SELECT COUNT_BIG(*) FROM dbo.USER_ACCOUNT WHERE user_id=N'SYSTEM_AUTO_APPROVER') AS system_actor_rows;
