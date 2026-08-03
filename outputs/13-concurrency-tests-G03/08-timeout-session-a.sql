/*
 Timeout regression - Session A.
 Start this first, then run 09-timeout-session-b.sql in Window B.
*/

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @space_id INT = (SELECT space_id FROM dbo.SPACE WHERE unique_space_code = N'G03-CT-TIMEOUT');
IF @space_id IS NULL
    THROW 51308, 'Timeout Session A prerequisite missing. Run 00-setup.sql.', 1;

BEGIN TRANSACTION;
EXEC dbo.usp_G03_AcquireSpaceApprovalLock @space_id = @space_id, @lock_timeout_ms = 10000;
PRINT 'Timeout Session A is holding the app lock for 15 seconds. Start 09-timeout-session-b.sql now.';
WAITFOR DELAY '00:00:15';
COMMIT TRANSACTION;

SELECT N'Timeout Session A committed after holding lock' AS result;
