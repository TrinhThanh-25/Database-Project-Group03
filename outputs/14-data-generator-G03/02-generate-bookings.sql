/* Trusted offline set-based load. It is not an application write path; run 05 validation before benchmarking. */
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Target INT=100000;
IF (SELECT COUNT(*) FROM dbo.SPACE WHERE unique_space_code LIKE N'G03-GEN-S-%')<>100 THROW 52410,'Run reference generation first.',1;
IF EXISTS(SELECT 1 FROM dbo.BOOKING_REQUEST WHERE purpose_of_use=N'administrative event' AND requested_start_time>='2027-09-01' AND requester_user_account_id IN(SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id LIKE N'G03-GEN-U-%')) THROW 52411,'Generated bookings already exist.',1;

;WITH n AS(
 SELECT TOP(@Target) ROW_NUMBER() OVER(ORDER BY a.object_id,b.object_id) n FROM sys.all_objects a CROSS JOIN sys.all_objects b
), shaped AS(
 SELECT n,
   1+((n-1)%100) space_no,1+((n-1)%120) user_no,
   ((n-1)/100)%3 year_no,(n-1)/300 slot_no,
   CASE ((n-1)/100)%10 WHEN 0 THEN N'approved' WHEN 1 THEN N'approved' WHEN 2 THEN N'checked_in' WHEN 3 THEN N'completed' WHEN 4 THEN N'pending' WHEN 5 THEN N'pending' WHEN 6 THEN N'rejected' WHEN 7 THEN N'cancelled' WHEN 8 THEN N'no_show' ELSE N'approved' END status_code
 FROM n
), timed AS(
 SELECT *,DATEADD(HOUR,8+2*((slot_no/2)%4),DATEADD(DAY,(slot_no/2)/4,
        CASE WHEN slot_no%2=0 THEN DATEADD(YEAR,year_no,CONVERT(DATETIME2(0),'2027-09-01'))
             ELSE DATEADD(YEAR,year_no,CONVERT(DATETIME2(0),'2028-02-01')) END)) start_time FROM shaped
)
INSERT dbo.BOOKING_REQUEST(requester_user_account_id,space_id,booking_status_id,requested_start_time,requested_end_time,purpose_of_use,expected_number_of_participants)
SELECT u.user_account_id,s.space_id,bs.booking_status_id,t.start_time,DATEADD(MINUTE,90,t.start_time),
       CASE t.n%7 WHEN 0 THEN N'lecture' WHEN 1 THEN N'examination' WHEN 2 THEN N'seminar' WHEN 3 THEN N'workshop' WHEN 4 THEN N'meeting' WHEN 5 THEN N'student activity' ELSE N'administrative event' END,
       1+(t.n%s.capacity)
FROM timed t JOIN dbo.USER_ACCOUNT u ON u.user_id=CONCAT(N'G03-GEN-U-',RIGHT(CONCAT(N'000',t.user_no),3))
JOIN dbo.SPACE s ON s.unique_space_code=CONCAT(N'G03-GEN-S-',RIGHT(CONCAT(N'000',t.space_no),3))
JOIN dbo.BOOKING_STATUS bs ON bs.status_code=t.status_code;

DECLARE @System INT=(SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id=N'SYSTEM_AUTO_APPROVER'),@Staff INT=(SELECT TOP(1) u.user_account_id FROM dbo.USER_ACCOUNT u JOIN dbo.ROLE r ON r.role_id=u.role_id WHERE r.role_name IN(N'facility staff',N'facility manager') ORDER BY u.user_account_id);
IF @System IS NULL OR @Staff IS NULL THROW 52412,'System and staff decision actors are required.',1;
INSERT dbo.APPROVAL_DECISION(booking_request_id,decided_by_user_account_id,decision_outcome_booking_status_id,decision_time,decision_note,rejection_reason)
SELECT b.booking_request_id,
       CASE WHEN bs.status_code=N'rejected' THEN @Staff
            WHEN iast.instant_approval_space_type_id IS NOT NULL AND b.expected_number_of_participants<=s.capacity THEN @System
            ELSE @Staff END,
       (SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code=CASE WHEN bs.status_code=N'rejected' THEN N'rejected' ELSE N'approved' END),
       DATEADD(DAY,-30,b.requested_start_time),
       CASE WHEN bs.status_code=N'rejected' THEN N'G03-GEN-V2 staff rejection'
            WHEN iast.instant_approval_space_type_id IS NOT NULL AND b.expected_number_of_participants<=s.capacity THEN N'G03-GEN-V2 automatic demo approval'
            ELSE N'G03-GEN-V2 staff approval' END,
       CASE WHEN bs.status_code=N'rejected' THEN N'Deterministic generated rejection' END
FROM dbo.BOOKING_REQUEST b JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id
JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id
JOIN dbo.SPACE s ON s.space_id=b.space_id
LEFT JOIN dbo.INSTANT_APPROVAL_SPACE_TYPE iast ON iast.space_type=s.space_type
WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code IN(N'approved',N'checked_in',N'completed',N'no_show',N'rejected');

INSERT dbo.USAGE_SESSION(booking_request_id,checked_in_by_user_account_id,completed_by_user_account_id,actual_start_time,initial_condition_of_space,actual_end_time,final_condition_of_space,usage_notes)
SELECT b.booking_request_id,@Staff,CASE WHEN bs.status_code=N'completed' THEN @Staff END,DATEADD(MINUTE,2,b.requested_start_time),N'Good',CASE WHEN bs.status_code=N'completed' THEN DATEADD(MINUTE,-2,b.requested_end_time) END,CASE WHEN bs.status_code=N'completed' THEN N'Good' END,N'G03-GEN-V2'
FROM dbo.BOOKING_REQUEST b JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id
WHERE u.user_id LIKE N'G03-GEN-U-%' AND bs.status_code IN(N'checked_in',N'completed');
SELECT COUNT(*) generated_bookings FROM dbo.BOOKING_REQUEST b JOIN dbo.USER_ACCOUNT u ON u.user_account_id=b.requester_user_account_id WHERE u.user_id LIKE N'G03-GEN-U-%';
