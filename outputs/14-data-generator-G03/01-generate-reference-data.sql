SET NOCOUNT ON; SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.SPACE WHERE unique_space_code LIKE N'G03-GEN-%') THROW 52401,'Generated fixtures already exist; run cleanup first.',1;
DECLARE @Dept INT=(SELECT MIN(department_id) FROM dbo.DEPARTMENT),@Active INT=(SELECT account_status_id FROM dbo.ACCOUNT_STATUS WHERE status_name=N'Active'),@Student INT=(SELECT role_id FROM dbo.ROLE WHERE role_name=N'student'),@Available INT=(SELECT space_status_id FROM dbo.SPACE_STATUS WHERE status_name=N'Available');
IF @Dept IS NULL OR @Active IS NULL OR @Student IS NULL OR @Available IS NULL THROW 52402,'Required reference seeds are missing.',1;
;WITH n AS(SELECT TOP(120) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) n FROM sys.all_objects)
INSERT dbo.USER_ACCOUNT(user_id,full_name,email,phone_number,department_id,role_id,account_status_id)
SELECT CONCAT(N'G03-GEN-U-',RIGHT(CONCAT(N'000',n),3)),CONCAT(N'Generated User ',n),CONCAT(N'g03-gen-',n,N'@example.invalid'),N'0',@Dept,@Student,@Active FROM n;
;WITH n AS(SELECT TOP(100) ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) n FROM sys.all_objects)
INSERT dbo.SPACE(unique_space_code,space_name,space_type,building,floor,room_number,capacity,usage_policy,space_status_id)
SELECT CONCAT(N'G03-GEN-S-',RIGHT(CONCAT(N'000',n),3)),CONCAT(N'Generated Space ',n),
       CASE n%4 WHEN 0 THEN N'g03-gen-instant' WHEN 1 THEN N'lecture room' WHEN 2 THEN N'computer lab' ELSE N'seminar room' END,
       N'GEN',CONVERT(NVARCHAR(10),1+(n-1)/25),RIGHT(CONCAT(N'000',n),3),
       CASE n%4 WHEN 0 THEN 30 WHEN 1 THEN 45 WHEN 2 THEN 60 ELSE 90 END,
       CONCAT(N'Preserved descriptive policy variant ',1+n%5,N'; demo evaluator uses capacity only.'),@Available FROM n;
IF NOT EXISTS(SELECT 1 FROM dbo.INSTANT_APPROVAL_SPACE_TYPE WHERE space_type=N'g03-gen-instant') INSERT dbo.INSTANT_APPROVAL_SPACE_TYPE(space_type) VALUES(N'g03-gen-instant');
IF NOT EXISTS(SELECT 1 FROM dbo.FACILITY WHERE facility_name=N'G03-GEN-Projector') INSERT dbo.FACILITY(facility_name) VALUES(N'G03-GEN-Projector');
IF NOT EXISTS(SELECT 1 FROM dbo.FACILITY WHERE facility_name=N'G03-GEN-Whiteboard') INSERT dbo.FACILITY(facility_name) VALUES(N'G03-GEN-Whiteboard');
INSERT dbo.SPACE_FACILITY(space_id,facility_id)
SELECT s.space_id,f.facility_id FROM dbo.SPACE s CROSS JOIN dbo.FACILITY f WHERE s.unique_space_code LIKE N'G03-GEN-S-%' AND f.facility_name=N'G03-GEN-Projector';
INSERT dbo.SPACE_FACILITY(space_id,facility_id)
SELECT s.space_id,f.facility_id FROM dbo.SPACE s CROSS JOIN dbo.FACILITY f WHERE s.unique_space_code LIKE N'G03-GEN-S-%' AND f.facility_name=N'G03-GEN-Whiteboard' AND TRY_CONVERT(INT,RIGHT(s.unique_space_code,3))%2=0;
SELECT N'PASS' status,(SELECT COUNT(*) FROM dbo.USER_ACCOUNT WHERE user_id LIKE N'G03-GEN-U-%') users,(SELECT COUNT(*) FROM dbo.SPACE WHERE unique_space_code LIKE N'G03-GEN-S-%') spaces;
