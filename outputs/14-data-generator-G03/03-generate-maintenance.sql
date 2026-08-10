SET NOCOUNT ON; SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.MAINTENANCE_RECORD WHERE problem_description LIKE N'G03-GEN-V2:%') THROW 52420,'Generated maintenance already exists.',1;
DECLARE @Reporter INT=(SELECT TOP(1) u.user_account_id FROM dbo.USER_ACCOUNT u JOIN dbo.ROLE r ON r.role_id=u.role_id WHERE r.role_name=N'facility staff' ORDER BY u.user_account_id),@Reported INT=(SELECT maintenance_status_id FROM dbo.MAINTENANCE_STATUS WHERE status_name=N'Reported'),@Completed INT=(SELECT maintenance_status_id FROM dbo.MAINTENANCE_STATUS WHERE status_name=N'Completed'),@Adv INT=(SELECT impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code=N'advisory'),@Oos INT=(SELECT impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code=N'out_of_service');
;WITH s AS(SELECT space_id,TRY_CONVERT(INT,RIGHT(unique_space_code,3)) n FROM dbo.SPACE WHERE unique_space_code LIKE N'G03-GEN-S-%')
INSERT dbo.MAINTENANCE_RECORD(space_id,reported_by_user_account_id,assigned_to_user_account_id,maintenance_status_id,impact_level_id,problem_description,start_time,completion_time,result_note)
SELECT space_id,@Reporter,@Reporter,
 CASE WHEN n<=40 THEN @Reported ELSE @Completed END,
 CASE WHEN n<=10 OR n>40 THEN @Oos ELSE @Adv END,
 CONCAT(N'G03-GEN-V2:',RIGHT(CONCAT(N'000',n),3)),
 CASE WHEN n<=10 THEN CONVERT(DATETIME2(0),'2030-02-20') WHEN n<=40 THEN CONVERT(DATETIME2(0),'2029-09-01') ELSE DATEADD(DAY,n,CONVERT(DATETIME2(0),'2034-01-01')) END,
 CASE WHEN n<=40 THEN NULL ELSE DATEADD(DAY,n+2,CONVERT(DATETIME2(0),'2034-01-01')) END,
 CASE WHEN n>40 THEN N'Generated completed maintenance' END
FROM s;

/* Rows 1-40 remain active/open, so completion_time and result_note stay NULL.
   Completed rows have both completion_time and result_note. */
/* Baseline: rows 1-40 begin advisory; completed rows begin out-of-service. */
INSERT dbo.MAINTENANCE_IMPACT_EVENT(maintenance_record_id,old_impact_level_id,new_impact_level_id,changed_at)
SELECT m.maintenance_record_id,NULL,CASE WHEN n.n<=40 THEN @Adv ELSE @Oos END,
       CASE WHEN n.n<=10 THEN '2030-02-10' WHEN n.n<=40 THEN '2029-08-20' ELSE m.start_time END
FROM dbo.MAINTENANCE_RECORD m CROSS APPLY(SELECT TRY_CONVERT(INT,RIGHT(m.problem_description,3)) n)n
WHERE m.problem_description LIKE N'G03-GEN-V2:%';
/* Ten explainable advisory -> out-of-service escalations. */
INSERT dbo.MAINTENANCE_IMPACT_EVENT(maintenance_record_id,old_impact_level_id,new_impact_level_id,changed_at)
SELECT m.maintenance_record_id,@Adv,@Oos,'2030-03-01' FROM dbo.MAINTENANCE_RECORD m
WHERE m.problem_description LIKE N'G03-GEN-V2:0[0-1][0-9]' AND TRY_CONVERT(INT,RIGHT(m.problem_description,3)) BETWEEN 1 AND 10;
SELECT COUNT(*) maintenance_rows FROM dbo.MAINTENANCE_RECORD WHERE problem_description LIKE N'G03-GEN-V2:%';
