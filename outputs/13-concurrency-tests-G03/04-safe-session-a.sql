/* Window A. Set @Case to II, IS, or SS in both windows. */
SET NOCOUNT ON; SET XACT_ABORT ON;
DECLARE @Case NVARCHAR(2)=N'II';
IF @Case NOT IN(N'II',N'IS',N'SS') THROW 52320,'Case must be II, IS, or SS.',1;
DECLARE @Code NVARCHAR(50)=CASE @Case WHEN N'II' THEN N'G03-CT-II' WHEN N'IS' THEN N'G03-CT-IS' ELSE N'G03-CT-SS' END;
DECLARE @S INT=(SELECT space_id FROM dbo.SPACE WHERE unique_space_code=@Code),
        @U INT=(SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id=N'G03-CT-USER-A'),
        @Staff INT=(SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id=N'G03-CT-STAFF-A');
DECLARE @Start DATETIME2(0)=CASE WHEN @Case IN(N'II',N'IS') THEN '2031-02-01T10:00:00' ELSE '2031-02-02T10:00:00' END,
        @End DATETIME2(0)=CASE WHEN @Case IN(N'II',N'IS') THEN '2031-02-01T11:00:00' ELSE '2031-02-02T11:00:00' END;
BEGIN TRY
    EXEC sys.sp_set_session_context @key=N'G03_CT_HOLD',@value=1;
    IF @Case IN(N'II',N'IS')
        EXEC dbo.usp_G03_SubmitBooking @U,@S,@Start,@End,N'meeting',5;
    ELSE
    BEGIN
        DECLARE @B INT=(SELECT booking_request_id FROM dbo.BOOKING_REQUEST WHERE space_id=@S AND requested_start_time=@Start);
        EXEC dbo.usp_G03_DecideBooking @B,@Staff,N'approved',N'concurrency test A',NULL;
    END;
    EXEC sys.sp_set_session_context @key=N'G03_CT_HOLD',@value=NULL;
    SELECT @Case AS case_code,N'A committed through production procedure' AS result;
END TRY
BEGIN CATCH
    EXEC sys.sp_set_session_context @key=N'G03_CT_HOLD',@value=NULL;
    THROW;
END CATCH;
