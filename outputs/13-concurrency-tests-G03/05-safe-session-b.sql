/* Window B. Start within five seconds of A and use the same @Case. */
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Case NVARCHAR(2)=N'II';
IF @Case NOT IN(N'II',N'IS',N'SS') THROW 52320,'Case must be II, IS, or SS.',1;
WAITFOR DELAY '00:00:01';
DECLARE @Code NVARCHAR(50)=CASE @Case WHEN N'II' THEN N'G03-CT-II' WHEN N'IS' THEN N'G03-CT-IS' ELSE N'G03-CT-SS' END;
DECLARE @S INT=(SELECT space_id FROM dbo.SPACE WHERE unique_space_code=@Code),
        @U INT=(SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id=N'G03-CT-USER-B'),
        @Staff INT=(SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id=N'G03-CT-STAFF-B');
DECLARE @Start DATETIME2(0)=CASE WHEN @Case=N'II' THEN '2031-02-01T10:15:00' WHEN @Case=N'IS' THEN '2031-02-01T10:00:00' ELSE '2031-02-02T10:15:00' END,
        @End DATETIME2(0)=CASE WHEN @Case=N'II' THEN '2031-02-01T10:45:00' WHEN @Case=N'IS' THEN '2031-02-01T11:00:00' ELSE '2031-02-02T11:15:00' END;
BEGIN TRY
    IF @Case=N'II'
        EXEC dbo.usp_G03_SubmitBooking @U,@S,@Start,@End,N'meeting',5;
    ELSE
    BEGIN
        DECLARE @B INT=(SELECT b.booking_request_id FROM dbo.BOOKING_REQUEST b JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=b.booking_status_id WHERE b.space_id=@S AND b.requested_start_time=@Start AND bs.status_code=N'pending');
        EXEC dbo.usp_G03_DecideBooking @B,@Staff,N'approved',N'concurrency test B',NULL;
    END;
    THROW 52322,'Competing approval unexpectedly succeeded.',1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER()<>52103 THROW;
    SELECT @Case AS case_code,ERROR_NUMBER() AS expected_error,ERROR_MESSAGE() AS result;
END CATCH;
