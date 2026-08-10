SET NOCOUNT ON; SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.trg_G03_CT_HoldBookingWrite',N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_G03_CT_HoldBookingWrite;
DECLARE @Ids TABLE(id INT PRIMARY KEY); INSERT @Ids SELECT space_id FROM dbo.SPACE WHERE unique_space_code LIKE N'G03-CT-%';
DELETE a FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT a JOIN dbo.BOOKING_REQUEST b ON b.booking_request_id=a.booking_request_id WHERE b.space_id IN(SELECT id FROM @Ids);
DELETE d FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_REQUEST b ON b.booking_request_id=d.booking_request_id WHERE b.space_id IN(SELECT id FROM @Ids);
DELETE u FROM dbo.USAGE_SESSION u JOIN dbo.BOOKING_REQUEST b ON b.booking_request_id=u.booking_request_id WHERE b.space_id IN(SELECT id FROM @Ids);
DELETE e FROM dbo.MAINTENANCE_IMPACT_EVENT e JOIN dbo.MAINTENANCE_RECORD m ON m.maintenance_record_id=e.maintenance_record_id WHERE m.space_id IN(SELECT id FROM @Ids);
DELETE FROM dbo.BOOKING_REQUEST WHERE space_id IN(SELECT id FROM @Ids);
DELETE FROM dbo.MAINTENANCE_RECORD WHERE space_id IN(SELECT id FROM @Ids);
DELETE FROM dbo.SPACE WHERE space_id IN(SELECT id FROM @Ids);
DELETE FROM dbo.USER_ACCOUNT WHERE user_id LIKE N'G03-CT-%';
DELETE FROM dbo.INSTANT_APPROVAL_SPACE_TYPE WHERE space_type=N'g03-ct-instant';
SELECT N'PASS' AS cleanup_status;
