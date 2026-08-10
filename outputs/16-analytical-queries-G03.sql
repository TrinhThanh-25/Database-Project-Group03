/*
 Artifact 16 — Four Phase 2 analytical reports (SQL Server, Group 03)

 Common semantics: semester bounds and requested intervals are half-open.
 Historical reports treat a booking as approved when it has an approved
 APPROVAL_DECISION; current room occupancy remains status_code approved or
 checked_in. Timestamps are already stored as Vietnam-local wall-clock values;
 reports compare them directly without a second conversion. Procedures validate
 start < end.

 Report 2 uses each booking's requested start weekday/hour, so each booking is
 counted once. Report 3 accepts a JSON array of integer facility IDs; OPENJSON
 converts it to a relational input without comma/sub-string matching. Empty []
 means no facility restriction.
*/
SET NOCOUNT ON; SET XACT_ABORT ON;
GO

/* P2-BR-22. Result: every space, clipped decimal approved hours. */
CREATE OR ALTER PROCEDURE dbo.usp_G03_ReportApprovedHoursBySpace
 @semester_start DATETIME2(0),@semester_end DATETIME2(0)
AS
BEGIN
 SET NOCOUNT ON;
 IF @semester_start IS NULL OR @semester_end IS NULL OR @semester_end<=@semester_start THROW 52600,'Invalid semester interval.',1;
 SELECT s.space_id,s.unique_space_code,s.space_name,
   CAST(COALESCE(SUM(CASE WHEN br.booking_request_id IS NULL THEN 0 ELSE DATEDIFF_BIG(SECOND,
      CASE WHEN br.requested_start_time<@semester_start THEN @semester_start ELSE br.requested_start_time END,
      CASE WHEN br.requested_end_time>@semester_end THEN @semester_end ELSE br.requested_end_time END) END),0)/3600.0 AS DECIMAL(18,2)) approved_hours
 FROM dbo.SPACE s
 LEFT JOIN(
   SELECT b.* FROM dbo.BOOKING_REQUEST b
   WHERE b.requested_start_time<@semester_end AND b.requested_end_time>@semester_start
     AND EXISTS(SELECT 1 FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_STATUS outcome ON outcome.booking_status_id=d.decision_outcome_booking_status_id WHERE d.booking_request_id=b.booking_request_id AND outcome.status_code=N'approved')
 )br ON br.space_id=s.space_id
 GROUP BY s.space_id,s.unique_space_code,s.space_name
 ORDER BY s.unique_space_code;
END;
GO

/* P2-BR-23. Monday=1 ... Sunday=7, independent of DATEFIRST/language. */
CREATE OR ALTER PROCEDURE dbo.usp_G03_ReportApprovedBookingStartsByWeekdayHour
 @semester_start DATETIME2(0),@semester_end DATETIME2(0)
AS
BEGIN
 SET NOCOUNT ON;
 IF @semester_start IS NULL OR @semester_end IS NULL OR @semester_end<=@semester_start THROW 52600,'Invalid semester interval.',1;
 SELECT 1+(DATEDIFF(DAY,CONVERT(DATE,'19000101'),CONVERT(DATE,b.requested_start_time))%7) weekday_number,
        CHOOSE(1+(DATEDIFF(DAY,CONVERT(DATE,'19000101'),CONVERT(DATE,b.requested_start_time))%7),N'Monday',N'Tuesday',N'Wednesday',N'Thursday',N'Friday',N'Saturday',N'Sunday') weekday_name,
        DATEPART(HOUR,b.requested_start_time) start_hour,COUNT_BIG(*) approved_booking_count
 FROM dbo.BOOKING_REQUEST b
 WHERE b.requested_start_time>=@semester_start AND b.requested_start_time<@semester_end
   AND EXISTS(SELECT 1 FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_STATUS outcome ON outcome.booking_status_id=d.decision_outcome_booking_status_id WHERE d.booking_request_id=b.booking_request_id AND outcome.status_code=N'approved')
 GROUP BY 1+(DATEDIFF(DAY,CONVERT(DATE,'19000101'),CONVERT(DATE,b.requested_start_time))%7),DATEPART(HOUR,b.requested_start_time)
 ORDER BY weekday_number,start_hour;
END;
GO

/* P2-BR-24. JSON example: N'[1,2]'. Advisory is returned, not excluded. */
CREATE OR ALTER PROCEDURE dbo.usp_G03_FindAvailableSpaces
 @requested_start DATETIME2(0),@requested_end DATETIME2(0),@required_capacity INT,@required_facility_ids_json NVARCHAR(MAX)=N'[]'
AS
BEGIN
 SET NOCOUNT ON;
 IF @requested_start IS NULL OR @requested_end IS NULL OR @requested_end<=@requested_start OR @required_capacity IS NULL OR @required_capacity<=0 THROW 52600,'Invalid room-finder input.',1;
 IF ISJSON(@required_facility_ids_json)<>1 OR LEFT(LTRIM(@required_facility_ids_json),1)<>N'[' THROW 52601,'Facility input must be a JSON array of integer IDs.',1;
 DECLARE @Required TABLE(facility_id INT PRIMARY KEY);
 INSERT @Required(facility_id) SELECT DISTINCT TRY_CONVERT(INT,[value]) FROM OPENJSON(@required_facility_ids_json) WHERE TRY_CONVERT(INT,[value]) IS NOT NULL;
 IF EXISTS(SELECT 1 FROM OPENJSON(@required_facility_ids_json) WHERE TRY_CONVERT(INT,[value]) IS NULL) THROW 52601,'Facility array contains a non-integer value.',1;

 SELECT s.space_id,s.unique_space_code,s.space_name,s.capacity,s.space_type,s.usage_policy,
        adv.active_advisory_count
 FROM dbo.SPACE s JOIN dbo.SPACE_STATUS ss ON ss.space_status_id=s.space_status_id
 OUTER APPLY(SELECT COUNT_BIG(*) active_advisory_count FROM dbo.MAINTENANCE_RECORD m JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=m.maintenance_status_id JOIN dbo.MAINTENANCE_IMPACT_LEVEL i ON i.impact_level_id=m.impact_level_id WHERE m.space_id=s.space_id AND ms.status_name IN(N'Reported',N'In progress') AND i.impact_level_code=N'advisory' AND m.start_time<@requested_end AND COALESCE(m.completion_time,CONVERT(DATETIME2(0),'9999-12-31'))>@requested_start)adv
 WHERE s.capacity>=@required_capacity AND LOWER(ss.status_name) NOT IN(N'temporarily closed',N'retired')
   AND NOT EXISTS(SELECT 1 FROM @Required r WHERE NOT EXISTS(SELECT 1 FROM dbo.SPACE_FACILITY sf WHERE sf.space_id=s.space_id AND sf.facility_id=r.facility_id))
   AND NOT EXISTS(SELECT 1 FROM dbo.BOOKING_REQUEST b JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id WHERE b.space_id=s.space_id AND bs.status_code IN(N'approved',N'checked_in') AND b.requested_start_time<@requested_end AND b.requested_end_time>@requested_start)
   AND NOT EXISTS(SELECT 1 FROM dbo.MAINTENANCE_RECORD m JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=m.maintenance_status_id JOIN dbo.MAINTENANCE_IMPACT_LEVEL i ON i.impact_level_id=m.impact_level_id WHERE m.space_id=s.space_id AND ms.status_name IN(N'Reported',N'In progress') AND i.impact_level_code=N'out_of_service' AND m.start_time<@requested_end AND COALESCE(m.completion_time,CONVERT(DATETIME2(0),'9999-12-31'))>@requested_start)
 ORDER BY s.capacity,s.unique_space_code;
END;
GO

/* P2-BR-25. Uses the actual advisory -> out_of_service event. */
CREATE OR ALTER PROCEDURE dbo.usp_G03_ReportBookingsAffectedByEscalation
 @maintenance_impact_event_id INT
AS
BEGIN
 SET NOCOUNT ON;
 IF @maintenance_impact_event_id IS NULL THROW 52600,'Impact event ID is required.',1;
 DECLARE @MaintenanceId INT,@SpaceId INT,@ChangedAt DATETIME2(0),@MStart DATETIME2(0),@MEnd DATETIME2(0),@AffectedStart DATETIME2(0);
 SELECT @MaintenanceId=e.maintenance_record_id,@SpaceId=m.space_id,@ChangedAt=e.changed_at,@MStart=m.start_time,@MEnd=m.completion_time
 FROM dbo.MAINTENANCE_IMPACT_EVENT e JOIN dbo.MAINTENANCE_RECORD m ON m.maintenance_record_id=e.maintenance_record_id
 JOIN dbo.MAINTENANCE_IMPACT_LEVEL old_i ON old_i.impact_level_id=e.old_impact_level_id
 JOIN dbo.MAINTENANCE_IMPACT_LEVEL new_i ON new_i.impact_level_id=e.new_impact_level_id
 WHERE e.maintenance_impact_event_id=@maintenance_impact_event_id AND old_i.impact_level_code=N'advisory' AND new_i.impact_level_code=N'out_of_service';
 IF @MaintenanceId IS NULL THROW 52602,'Event is not an advisory-to-out-of-service escalation.',1;
 SET @AffectedStart=CASE WHEN @ChangedAt>@MStart THEN @ChangedAt ELSE @MStart END;

 SELECT b.booking_request_id,b.requester_user_account_id,u.user_id,u.full_name,u.email,u.phone_number,
        b.requested_start_time,b.requested_end_time,bs.status_code,@ChangedAt escalated_at
 FROM dbo.BOOKING_REQUEST b JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id
 WHERE b.space_id=@SpaceId
   AND b.requested_start_time<COALESCE(@MEnd,CONVERT(DATETIME2(0),'9999-12-31')) AND b.requested_end_time>@AffectedStart
   AND EXISTS(SELECT 1 FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_STATUS outcome ON outcome.booking_status_id=d.decision_outcome_booking_status_id WHERE d.booking_request_id=b.booking_request_id AND outcome.status_code=N'approved' AND d.decision_time<=@ChangedAt)
 ORDER BY b.requested_start_time,b.booking_request_id;
END;
GO

/* Correctness examples; replace IDs with values from the target database. */
-- EXEC dbo.usp_G03_ReportApprovedHoursBySpace '2027-09-01','2028-09-01';
-- EXEC dbo.usp_G03_ReportApprovedBookingStartsByWeekdayHour '2027-09-01','2028-09-01';
-- EXEC dbo.usp_G03_FindAvailableSpaces '2027-09-01T08:00:00','2027-09-01T10:00:00',30,N'[]';
-- EXEC dbo.usp_G03_ReportBookingsAffectedByEscalation @maintenance_impact_event_id=1;

SELECT OBJECT_ID(N'dbo.usp_G03_ReportApprovedHoursBySpace',N'P') report_1,
OBJECT_ID(N'dbo.usp_G03_ReportApprovedBookingStartsByWeekdayHour',N'P') report_2,
OBJECT_ID(N'dbo.usp_G03_FindAvailableSpaces',N'P') report_3,
OBJECT_ID(N'dbo.usp_G03_ReportBookingsAffectedByEscalation',N'P') report_4;
