/* Window B: start within five seconds of Window A. */
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @S INT=(SELECT space_id FROM dbo.SPACE WHERE unique_space_code=N'G03-CT-UNSAFE'),@U INT=(SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id=N'G03-CT-USER-B'),@A INT=(SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code=N'approved');
BEGIN TRANSACTION;
IF EXISTS(SELECT 1 FROM dbo.BOOKING_REQUEST b JOIN dbo.BOOKING_STATUS s ON s.booking_status_id=b.booking_status_id WHERE b.space_id=@S AND s.status_code IN(N'approved',N'checked_in') AND b.requested_start_time<'2031-01-01T11:00:00' AND b.requested_end_time>'2031-01-01T10:00:00') THROW 52310,'Fixture not free.',1;
WAITFOR DELAY '00:00:02';
INSERT dbo.BOOKING_REQUEST VALUES(@U,@S,@A,'2031-01-01T10:15:00','2031-01-01T10:45:00',N'meeting',5);
COMMIT;
