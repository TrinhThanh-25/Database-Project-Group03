/* Generated requests are treated as submitted before the first event relevant
   to their interval, thirty days before requested start. For escalated rows,
   acknowledgement is stored only when that derived submission precedes the
   2030-03-01 escalation. */
SET NOCOUNT ON; SET XACT_ABORT ON;
INSERT dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT(booking_request_id,maintenance_record_id)
SELECT b.booking_request_id,m.maintenance_record_id
FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id
JOIN dbo.MAINTENANCE_RECORD m ON m.space_id=b.space_id AND m.start_time<b.requested_end_time
 AND COALESCE(m.completion_time,CONVERT(DATETIME2(0),'9999-12-31'))>b.requested_start_time
WHERE u.user_id LIKE N'G03-GEN-U-%'
  AND EXISTS(SELECT 1 FROM dbo.MAINTENANCE_IMPACT_EVENT e JOIN dbo.MAINTENANCE_IMPACT_LEVEL i ON i.impact_level_id=e.new_impact_level_id WHERE e.maintenance_record_id=m.maintenance_record_id AND e.old_impact_level_id IS NULL AND i.impact_level_code=N'advisory')
  AND (TRY_CONVERT(INT,RIGHT(m.problem_description,3))>10 OR DATEADD(DAY,-30,b.requested_start_time)<'2030-03-01')
  AND NOT EXISTS(SELECT 1 FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT a WHERE a.booking_request_id=b.booking_request_id AND a.maintenance_record_id=m.maintenance_record_id);
SELECT COUNT(*) acknowledgement_rows FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT a JOIN dbo.MAINTENANCE_RECORD m ON m.maintenance_record_id=a.maintenance_record_id WHERE m.problem_description LIKE N'G03-GEN-V2:%';
