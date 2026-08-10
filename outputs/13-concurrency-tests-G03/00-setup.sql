/* Minimal fixtures for unsafe and protected approval races. */
SET NOCOUNT ON; SET XACT_ABORT ON;
IF OBJECT_ID(N'dbo.usp_G03_SubmitBooking',N'P') IS NULL
 OR OBJECT_ID(N'dbo.usp_G03_DecideBooking',N'P') IS NULL
    THROW 52300,'Artifacts 10 and 12 must be deployed first.',1;

DECLARE @SpaceIds TABLE(id INT PRIMARY KEY);
INSERT @SpaceIds SELECT space_id FROM dbo.SPACE WHERE unique_space_code LIKE N'G03-CT-%';
DELETE a FROM dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT a JOIN dbo.BOOKING_REQUEST b ON b.booking_request_id=a.booking_request_id WHERE b.space_id IN(SELECT id FROM @SpaceIds);
DELETE d FROM dbo.APPROVAL_DECISION d JOIN dbo.BOOKING_REQUEST b ON b.booking_request_id=d.booking_request_id WHERE b.space_id IN(SELECT id FROM @SpaceIds);
DELETE u FROM dbo.USAGE_SESSION u JOIN dbo.BOOKING_REQUEST b ON b.booking_request_id=u.booking_request_id WHERE b.space_id IN(SELECT id FROM @SpaceIds);
DELETE e FROM dbo.MAINTENANCE_IMPACT_EVENT e JOIN dbo.MAINTENANCE_RECORD m ON m.maintenance_record_id=e.maintenance_record_id WHERE m.space_id IN(SELECT id FROM @SpaceIds);
DELETE FROM dbo.BOOKING_REQUEST WHERE space_id IN(SELECT id FROM @SpaceIds);
DELETE FROM dbo.MAINTENANCE_RECORD WHERE space_id IN(SELECT id FROM @SpaceIds);
DELETE FROM dbo.SPACE WHERE space_id IN(SELECT id FROM @SpaceIds);
DELETE FROM dbo.USER_ACCOUNT WHERE user_id LIKE N'G03-CT-%';
DELETE FROM dbo.INSTANT_APPROVAL_SPACE_TYPE WHERE space_type=N'g03-ct-instant';

DECLARE @Dept INT=(SELECT MIN(department_id) FROM dbo.DEPARTMENT),
        @Active INT=(SELECT account_status_id FROM dbo.ACCOUNT_STATUS WHERE status_name=N'Active'),
        @StudentRole INT=(SELECT role_id FROM dbo.ROLE WHERE role_name=N'student'),
        @StaffRole INT=(SELECT role_id FROM dbo.ROLE WHERE role_name=N'facility staff'),
        @Available INT=(SELECT space_status_id FROM dbo.SPACE_STATUS WHERE status_name=N'Available');
IF @Dept IS NULL OR @Active IS NULL OR @StudentRole IS NULL OR @StaffRole IS NULL OR @Available IS NULL
    THROW 52301,'Required reference values are missing.',1;

INSERT dbo.USER_ACCOUNT(user_id,full_name,email,phone_number,department_id,role_id,account_status_id) VALUES
(N'G03-CT-USER-A',N'G03 Test User A',N'g03-ct-a@example.invalid',N'0',@Dept,@StudentRole,@Active),
(N'G03-CT-USER-B',N'G03 Test User B',N'g03-ct-b@example.invalid',N'0',@Dept,@StudentRole,@Active),
(N'G03-CT-STAFF-A',N'G03 Test Staff A',N'g03-ct-staff-a@example.invalid',N'0',@Dept,@StaffRole,@Active),
(N'G03-CT-STAFF-B',N'G03 Test Staff B',N'g03-ct-staff-b@example.invalid',N'0',@Dept,@StaffRole,@Active);

INSERT dbo.SPACE(unique_space_code,space_name,space_type,building,floor,room_number,capacity,usage_policy,space_status_id) VALUES
(N'G03-CT-UNSAFE',N'Unsafe race',N'g03-ct-instant',N'CT',N'1',N'01',30,N'Demo policy text.',@Available),
(N'G03-CT-II',N'Instant versus instant',N'g03-ct-instant',N'CT',N'1',N'02',30,N'Demo policy text.',@Available),
(N'G03-CT-IS',N'Instant versus staff',N'g03-ct-instant',N'CT',N'1',N'03',30,N'Demo policy text.',@Available),
(N'G03-CT-SS',N'Staff versus staff',N'g03-ct-staff',N'CT',N'1',N'04',30,N'Demo policy text.',@Available);
INSERT dbo.INSTANT_APPROVAL_SPACE_TYPE(space_type) VALUES(N'g03-ct-instant');

DECLARE @Pending INT=(SELECT booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code=N'pending'),
        @UserA INT=(SELECT user_account_id FROM dbo.USER_ACCOUNT WHERE user_id=N'G03-CT-USER-A');
INSERT dbo.BOOKING_REQUEST(requester_user_account_id,space_id,booking_status_id,requested_start_time,requested_end_time,purpose_of_use,expected_number_of_participants)
SELECT @UserA,s.space_id,@Pending,'2031-02-01T10:00:00','2031-02-01T11:00:00',N'meeting',5 FROM dbo.SPACE s WHERE s.unique_space_code=N'G03-CT-IS'
UNION ALL SELECT @UserA,s.space_id,@Pending,'2031-02-02T10:00:00','2031-02-02T11:00:00',N'meeting',5 FROM dbo.SPACE s WHERE s.unique_space_code=N'G03-CT-SS'
UNION ALL SELECT @UserA,s.space_id,@Pending,'2031-02-02T10:15:00','2031-02-02T11:15:00',N'meeting',5 FROM dbo.SPACE s WHERE s.unique_space_code=N'G03-CT-SS';

/* Test-only delay: it pauses A inside its booking write after the production
   procedure has acquired the space lock. It never acquires that lock itself. */
GO
CREATE OR ALTER TRIGGER dbo.trg_G03_CT_HoldBookingWrite
ON dbo.BOOKING_REQUEST
AFTER INSERT,UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRY_CONVERT(INT,SESSION_CONTEXT(N'G03_CT_HOLD'))=1
       AND EXISTS(SELECT 1 FROM inserted i JOIN dbo.SPACE s ON s.space_id=i.space_id WHERE s.unique_space_code LIKE N'G03-CT-%')
        WAITFOR DELAY '00:00:06';
END;
GO
SELECT N'PASS' AS setup_status;
