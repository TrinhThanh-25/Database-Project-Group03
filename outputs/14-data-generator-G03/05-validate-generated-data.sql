SET NOCOUNT ON;
/* Direct bulk load and cleanup/regeneration can leave stale optimizer statistics.
   Refresh them before correctness checks and before handing the dataset to tuning. */
UPDATE STATISTICS dbo.BOOKING_REQUEST WITH FULLSCAN;
UPDATE STATISTICS dbo.APPROVAL_DECISION WITH FULLSCAN;
UPDATE STATISTICS dbo.USAGE_SESSION WITH FULLSCAN;
UPDATE STATISTICS dbo.MAINTENANCE_RECORD WITH FULLSCAN;
UPDATE STATISTICS dbo.MAINTENANCE_IMPACT_EVENT WITH FULLSCAN;
UPDATE STATISTICS dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT WITH FULLSCAN;
DECLARE @Errors TABLE(check_name NVARCHAR(100),error_count BIGINT);
DECLARE @Generated BIGINT=(SELECT COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id WHERE u.user_id LIKE N'G03-GEN-U-%');
SELECT d.booking_request_id,
       SUM(CASE WHEN outcome.status_code=N'approved' THEN 1 ELSE 0 END) approved_count,
       SUM(CASE WHEN outcome.status_code=N'rejected' THEN 1 ELSE 0 END) rejected_count,
       SUM(CASE WHEN outcome.status_code=N'rejected' AND NULLIF(LTRIM(RTRIM(d.rejection_reason)),N'') IS NOT NULL THEN 1 ELSE 0 END) valid_rejection_count,
       CONVERT(DATETIME2(0),NULL) first_approved_at
INTO #DecisionSummary
FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_STATUS outcome ON outcome.booking_status_id=d.decision_outcome_booking_status_id
GROUP BY d.booking_request_id;
CREATE UNIQUE CLUSTERED INDEX IX_G03_validation_decision_summary ON #DecisionSummary(booking_request_id);
UPDATE ds SET first_approved_at=approved_history.first_approved_at
FROM #DecisionSummary ds JOIN(
 SELECT d.booking_request_id,MIN(d.decision_time) first_approved_at
 FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_STATUS outcome ON outcome.booking_status_id=d.decision_outcome_booking_status_id
 WHERE outcome.status_code=N'approved' GROUP BY d.booking_request_id
)approved_history ON approved_history.booking_request_id=ds.booking_request_id;
INSERT @Errors VALUES(N'booking_count_below_100000',CASE WHEN @Generated<100000 THEN 1 ELSE 0 END);
INSERT @Errors SELECT N'academic_year_coverage_below_3',CASE WHEN COUNT(DISTINCT CASE WHEN MONTH(b.requested_start_time)>=9 THEN YEAR(b.requested_start_time) ELSE YEAR(b.requested_start_time)-1 END)<3 THEN 1 ELSE 0 END FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id WHERE u.user_id LIKE N'G03-GEN-U-%';
INSERT @Errors SELECT N'semester_date_band_coverage_below_6',CASE WHEN COUNT(DISTINCT CONCAT(CASE WHEN MONTH(b.requested_start_time)>=9 THEN YEAR(b.requested_start_time) ELSE YEAR(b.requested_start_time)-1 END,N'-',CASE WHEN MONTH(b.requested_start_time)>=9 THEN N'fall' ELSE N'spring' END))<6 THEN 1 ELSE 0 END FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id WHERE u.user_id LIKE N'G03-GEN-U-%';
INSERT @Errors SELECT N'invalid_time_order',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND b.requested_end_time<=b.requested_start_time;
INSERT @Errors SELECT N'participant_exceeds_space_capacity',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.SPACE s ON s.space_id=b.space_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND b.expected_number_of_participants>s.capacity;
;WITH occupancy AS(
 SELECT b.booking_request_id,b.space_id,b.requested_start_time,b.requested_end_time
 FROM dbo.BOOKING_REQUEST b JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id
 WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code IN(N'approved',N'checked_in')
), ordered AS(
 SELECT *,MAX(requested_end_time) OVER(PARTITION BY space_id ORDER BY requested_start_time,booking_request_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) prior_max_end
 FROM occupancy
)
INSERT @Errors SELECT N'approved_overlap_violations',COUNT_BIG(*) FROM ordered WHERE prior_max_end>requested_start_time;
;WITH escalations AS(
 SELECT e.maintenance_record_id,MAX(e.changed_at) escalated_at
 FROM dbo.MAINTENANCE_IMPACT_EVENT e JOIN dbo.MAINTENANCE_IMPACT_LEVEL oi ON oi.impact_level_id=e.old_impact_level_id JOIN dbo.MAINTENANCE_IMPACT_LEVEL ni ON ni.impact_level_id=e.new_impact_level_id
 WHERE oi.impact_level_code=N'advisory' AND ni.impact_level_code=N'out_of_service' GROUP BY e.maintenance_record_id
)
INSERT @Errors SELECT N'unexplained_active_oos_overlap',COUNT_BIG(*)
FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN #DecisionSummary ds ON ds.booking_request_id=b.booking_request_id AND ds.approved_count>0
JOIN dbo.MAINTENANCE_RECORD m ON m.space_id=b.space_id JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=m.maintenance_status_id JOIN dbo.MAINTENANCE_IMPACT_LEVEL i ON i.impact_level_id=m.impact_level_id
LEFT JOIN escalations esc ON esc.maintenance_record_id=m.maintenance_record_id
WHERE u.user_id LIKE N'G03-GEN-U-%' AND ms.status_name IN(N'Reported',N'In progress') AND i.impact_level_code=N'out_of_service'
  AND b.requested_start_time<COALESCE(m.completion_time,CONVERT(DATETIME2(0),'9999-12-31')) AND b.requested_end_time>CASE WHEN esc.escalated_at>m.start_time THEN esc.escalated_at ELSE m.start_time END
  AND (esc.escalated_at IS NULL OR ds.first_approved_at>esc.escalated_at)
OPTION(HASH JOIN,RECOMPILE);
INSERT @Errors SELECT N'missing_active_advisory_ack',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.MAINTENANCE_RECORD m ON m.space_id=b.space_id AND m.start_time<b.requested_end_time AND COALESCE(m.completion_time,CONVERT(DATETIME2(0),'9999-12-31'))>b.requested_start_time JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=m.maintenance_status_id JOIN dbo.MAINTENANCE_IMPACT_LEVEL i ON i.impact_level_id=m.impact_level_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND ms.status_name IN(N'Reported',N'In progress') AND i.impact_level_code=N'advisory' AND NOT EXISTS(SELECT 1 FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT a WHERE a.booking_request_id=b.booking_request_id AND a.maintenance_record_id=m.maintenance_record_id);
INSERT @Errors SELECT N'missing_escalated_advisory_ack',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.MAINTENANCE_RECORD m ON m.space_id=b.space_id AND m.start_time<b.requested_end_time AND COALESCE(m.completion_time,CONVERT(DATETIME2(0),'9999-12-31'))>b.requested_start_time CROSS APPLY(SELECT TOP(1)e.changed_at FROM dbo.MAINTENANCE_IMPACT_EVENT e JOIN dbo.MAINTENANCE_IMPACT_LEVEL oi ON oi.impact_level_id=e.old_impact_level_id JOIN dbo.MAINTENANCE_IMPACT_LEVEL ni ON ni.impact_level_id=e.new_impact_level_id WHERE e.maintenance_record_id=m.maintenance_record_id AND oi.impact_level_code=N'advisory' AND ni.impact_level_code=N'out_of_service' ORDER BY e.changed_at,e.maintenance_impact_event_id)esc WHERE u.user_id LIKE N'G03-GEN-U-%' AND DATEADD(DAY,-30,b.requested_start_time)<esc.changed_at AND NOT EXISTS(SELECT 1 FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT a WHERE a.booking_request_id=b.booking_request_id AND a.maintenance_record_id=m.maintenance_record_id);
INSERT @Errors SELECT N'duplicate_ack_pair',COUNT_BIG(*) FROM(SELECT booking_request_id,maintenance_record_id FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT GROUP BY booking_request_id,maintenance_record_id HAVING COUNT(*)>1)d;
INSERT @Errors SELECT N'impact_latest_missing_or_mismatch',COUNT_BIG(*) FROM dbo.MAINTENANCE_RECORD m OUTER APPLY(SELECT TOP(1)e.new_impact_level_id FROM dbo.MAINTENANCE_IMPACT_EVENT e WHERE e.maintenance_record_id=m.maintenance_record_id ORDER BY e.changed_at DESC,e.maintenance_impact_event_id DESC)x WHERE m.problem_description LIKE N'G03-GEN-V2:%' AND (x.new_impact_level_id IS NULL OR x.new_impact_level_id<>m.impact_level_id);
INSERT @Errors SELECT N'active_maintenance_has_completion',COUNT_BIG(*) FROM dbo.MAINTENANCE_RECORD m JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=m.maintenance_status_id WHERE m.problem_description LIKE N'G03-GEN-V2:%' AND ms.status_name IN(N'Reported',N'In progress') AND (m.completion_time IS NOT NULL OR m.result_note IS NOT NULL);
INSERT @Errors SELECT N'completed_maintenance_missing_completion',COUNT_BIG(*) FROM dbo.MAINTENANCE_RECORD m JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=m.maintenance_status_id WHERE m.problem_description LIKE N'G03-GEN-V2:%' AND ms.status_name=N'Completed' AND (m.completion_time IS NULL OR m.result_note IS NULL);
INSERT @Errors SELECT N'maintenance_count_not_100',CASE WHEN COUNT_BIG(*)=100 THEN 0 ELSE 1 END FROM dbo.MAINTENANCE_RECORD m WHERE m.problem_description LIKE N'G03-GEN-V2:%';
INSERT @Errors SELECT N'escalation_population_below_10',CASE WHEN COUNT_BIG(*)>=10 THEN 0 ELSE 1 END FROM dbo.MAINTENANCE_IMPACT_EVENT e JOIN dbo.MAINTENANCE_RECORD m ON m.maintenance_record_id=e.maintenance_record_id JOIN dbo.MAINTENANCE_IMPACT_LEVEL oi ON oi.impact_level_id=e.old_impact_level_id JOIN dbo.MAINTENANCE_IMPACT_LEVEL ni ON ni.impact_level_id=e.new_impact_level_id WHERE m.problem_description LIKE N'G03-GEN-V2:%' AND oi.impact_level_code=N'advisory' AND ni.impact_level_code=N'out_of_service';
INSERT @Errors SELECT N'acknowledgement_population_missing',CASE WHEN COUNT_BIG(*)>0 THEN 0 ELSE 1 END FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT a JOIN dbo.MAINTENANCE_RECORD m ON m.maintenance_record_id=a.maintenance_record_id WHERE m.problem_description LIKE N'G03-GEN-V2:%';
INSERT @Errors SELECT N'missing_required_status_population',COUNT_BIG(*) FROM(VALUES(N'approved'),(N'checked_in'),(N'completed'),(N'pending'),(N'rejected'),(N'cancelled'),(N'no_show')) required(status_code) WHERE NOT EXISTS(SELECT 1 FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code=required.status_code);
INSERT @Errors SELECT N'insufficient_purpose_diversity',CASE WHEN COUNT(DISTINCT b.purpose_of_use)<7 THEN 1 ELSE 0 END FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id WHERE u.user_id LIKE N'G03-GEN-U-%';
INSERT @Errors SELECT N'insufficient_space_diversity',CASE WHEN COUNT(DISTINCT s.space_type)<4 OR COUNT(DISTINCT s.capacity)<4 THEN 1 ELSE 0 END FROM dbo.SPACE s WHERE s.unique_space_code LIKE N'G03-GEN-S-%';
INSERT @Errors SELECT N'space_without_status_diversity',COUNT_BIG(*) FROM(SELECT b.space_id FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id WHERE u.user_id LIKE N'G03-GEN-U-%' GROUP BY b.space_id HAVING COUNT(DISTINCT bs.status_code)<7)x;
INSERT @Errors SELECT N'missing_approved_history',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id LEFT JOIN #DecisionSummary ds ON ds.booking_request_id=b.booking_request_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code IN(N'approved',N'checked_in',N'completed',N'no_show') AND COALESCE(ds.approved_count,0)=0;
INSERT @Errors SELECT N'generated_decision_time_invalid',COUNT_BIG(*) FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_REQUEST b ON b.booking_request_id=d.booking_request_id JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND d.decision_time<>DATEADD(DAY,-30,b.requested_start_time);
INSERT @Errors SELECT N'generated_decision_actor_invalid',COUNT_BIG(*)
FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_REQUEST b ON b.booking_request_id=d.booking_request_id JOIN dbo.USER_ACCOUNT requester ON requester.user_account_id=b.requester_user_account_id
JOIN dbo.SPACE s ON s.space_id=b.space_id LEFT JOIN dbo.INSTANT_APPROVAL_SPACE_TYPE iast ON iast.space_type=s.space_type
JOIN dbo.BOOKING_STATUS outcome ON outcome.booking_status_id=d.decision_outcome_booking_status_id JOIN dbo.USER_ACCOUNT actor ON actor.user_account_id=d.decided_by_user_account_id JOIN dbo.ROLE r ON r.role_id=actor.role_id JOIN dbo.ACCOUNT_STATUS acs ON acs.account_status_id=actor.account_status_id
WHERE requester.user_id LIKE N'G03-GEN-U-%' AND (
 (outcome.status_code=N'approved' AND iast.instant_approval_space_type_id IS NOT NULL AND b.expected_number_of_participants<=s.capacity AND NOT(r.role_name=N'System' AND acs.status_name=N'Active'))
 OR (outcome.status_code=N'approved' AND (iast.instant_approval_space_type_id IS NULL OR b.expected_number_of_participants>s.capacity) AND NOT(r.role_name IN(N'facility staff',N'facility manager') AND acs.status_name=N'Active'))
 OR (outcome.status_code=N'rejected' AND NOT(r.role_name IN(N'facility staff',N'facility manager') AND acs.status_name=N'Active')));
INSERT @Errors SELECT N'generated_decision_cardinality_invalid',COUNT_BIG(*)
FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id LEFT JOIN #DecisionSummary ds ON ds.booking_request_id=b.booking_request_id
WHERE u.user_id LIKE N'G03-GEN-U-%' AND ((bs.status_code IN(N'approved',N'checked_in',N'completed',N'no_show') AND (COALESCE(ds.approved_count,0)<>1 OR COALESCE(ds.rejected_count,0)<>0)) OR (bs.status_code=N'rejected' AND (COALESCE(ds.approved_count,0)<>0 OR COALESCE(ds.rejected_count,0)<>1)) OR (bs.status_code IN(N'pending',N'cancelled') AND (COALESCE(ds.approved_count,0)<>0 OR COALESCE(ds.rejected_count,0)<>0)));
INSERT @Errors SELECT N'checked_in_usage_lifecycle_invalid',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id LEFT JOIN dbo.USAGE_SESSION s ON s.booking_request_id=b.booking_request_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code=N'checked_in' AND (s.usage_session_id IS NULL OR s.actual_end_time IS NOT NULL OR s.completed_by_user_account_id IS NOT NULL OR s.final_condition_of_space IS NOT NULL);
INSERT @Errors SELECT N'completed_usage_lifecycle_invalid',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id LEFT JOIN dbo.USAGE_SESSION s ON s.booking_request_id=b.booking_request_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code=N'completed' AND (s.usage_session_id IS NULL OR s.actual_end_time IS NULL OR s.completed_by_user_account_id IS NULL OR s.final_condition_of_space IS NULL);
INSERT @Errors SELECT N'no_show_usage_or_approval_invalid',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id LEFT JOIN dbo.USAGE_SESSION s ON s.booking_request_id=b.booking_request_id LEFT JOIN #DecisionSummary ds ON ds.booking_request_id=b.booking_request_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code=N'no_show' AND (s.usage_session_id IS NOT NULL OR COALESCE(ds.approved_count,0)=0);
INSERT @Errors SELECT N'rejected_decision_invalid',COUNT_BIG(*) FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id LEFT JOIN #DecisionSummary ds ON ds.booking_request_id=b.booking_request_id WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code=N'rejected' AND COALESCE(ds.valid_rejection_count,0)=0;

SELECT check_name,error_count,CASE WHEN error_count=0 THEN N'PASS' ELSE N'FAIL' END result FROM @Errors ORDER BY check_name;
SELECT bs.status_code,COUNT_BIG(*) booking_count FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id WHERE u.user_id LIKE N'G03-GEN-U-%' GROUP BY bs.status_code ORDER BY bs.status_code;
SELECT CASE WHEN MONTH(b.requested_start_time)>=9 THEN YEAR(b.requested_start_time) ELSE YEAR(b.requested_start_time)-1 END academic_year_start,COUNT_BIG(*) booking_count FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id WHERE u.user_id LIKE N'G03-GEN-U-%' GROUP BY CASE WHEN MONTH(b.requested_start_time)>=9 THEN YEAR(b.requested_start_time) ELSE YEAR(b.requested_start_time)-1 END ORDER BY academic_year_start;
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
IF EXISTS(SELECT 1 FROM @Errors WHERE error_count<>0) THROW 52430,'Generated-data validation failed.',1;
SELECT N'PASS' validation_status,@Generated generated_booking_count;
