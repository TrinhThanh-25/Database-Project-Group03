/*
 Artifact 12 — Production concurrency SQL (SQL Server, Group 03)

 Interfaces:
   dbo.usp_G03_SubmitBooking
   dbo.usp_G03_DecideBooking
   dbo.usp_G03_ChangeMaintenanceImpact

 Occupancy: booking status_code approved or checked_in.
 Active/open maintenance: status_name Reported or In progress.
 Instant demo eligibility: configured SPACE.space_type and participants <=
 SPACE.capacity. SPACE.usage_policy is retained but deliberately not parsed.
 Every DATETIME2 interval parameter and stored booking/maintenance timestamp is
 interpreted as Vietnam local wall-clock time. Generated decision and impact-
 event timestamps are derived with SQL Server zone `SE Asia Standard Time`
 rather than depending on the database host's local timezone.

 Demo errors: 52100 invalid input; 52101 missing/inactive principal or object;
 52102 unavailable/out-of-service; 52103 approved overlap; 52104 invalid
 lifecycle/outcome; 52105 impact-history mismatch; 52110 lock acquisition failed.
 All failures roll back and leave no partial booking/decision/ack/event writes.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_G03_SubmitBooking
    @requester_user_account_id INT,
    @space_id INT,
    @requested_start_time DATETIME2(0),
    @requested_end_time DATETIME2(0),
    @purpose_of_use NVARCHAR(80),
    @expected_number_of_participants INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @requester_user_account_id IS NULL OR @space_id IS NULL
       OR @requested_start_time IS NULL OR @requested_end_time IS NULL
       OR @requested_end_time<=@requested_start_time
       OR @expected_number_of_participants IS NULL OR @expected_number_of_participants<=0
       OR NULLIF(LTRIM(RTRIM(@purpose_of_use)),N'') IS NULL
       OR @purpose_of_use NOT IN(N'lecture',N'examination',N'seminar',N'workshop',N'meeting',N'student activity',N'administrative event')
        THROW 52100, 'Invalid booking input.', 1;

    DECLARE @LockResult INT, @Resource NVARCHAR(255)=N'G03:approved-occupancy:space:'+CONVERT(NVARCHAR(20),@space_id);
    DECLARE @Capacity INT, @SpaceType NVARCHAR(100), @SpaceStatus NVARCHAR(80);
    DECLARE @PendingId INT, @ApprovedId INT, @ChosenStatusId INT, @ChosenCode NVARCHAR(40);
    DECLARE @SystemUserId INT, @BookingId INT, @AckCount INT;
    DECLARE @Advisories TABLE(maintenance_record_id INT PRIMARY KEY);

    BEGIN TRY
        BEGIN TRANSACTION;
        EXEC @LockResult=sys.sp_getapplock @Resource=@Resource,@LockMode='Exclusive',@LockOwner='Transaction',@DbPrincipal='public';
        IF @LockResult<0 THROW 52110, 'Space lock could not be acquired.', 1;

        SELECT @Capacity=s.capacity,@SpaceType=s.space_type,@SpaceStatus=ss.status_name
        FROM dbo.SPACE s WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.SPACE_STATUS ss ON ss.space_status_id=s.space_status_id
        WHERE s.space_id=@space_id;
        IF @Capacity IS NULL THROW 52101, 'Space does not exist.', 1;
        IF LOWER(@SpaceStatus) IN (N'temporarily closed',N'retired')
            THROW 52102, 'Space is unavailable.', 1;

        IF NOT EXISTS(
            SELECT 1 FROM dbo.USER_ACCOUNT u
            JOIN dbo.ACCOUNT_STATUS a ON a.account_status_id=u.account_status_id
            WHERE u.user_account_id=@requester_user_account_id AND a.status_name=N'Active')
            THROW 52101, 'Requester does not exist or is not active.', 1;

        SELECT @PendingId=booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code=N'pending';
        SELECT @ApprovedId=booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code=N'approved';
        IF @PendingId IS NULL OR @ApprovedId IS NULL THROW 52101, 'Required booking statuses are missing.', 1;

        /* P2-BR-03/04: every submission is rejected over active out-of-service. */
        IF EXISTS(
            SELECT 1 FROM dbo.MAINTENANCE_RECORD mr
            JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=mr.maintenance_status_id
            JOIN dbo.MAINTENANCE_IMPACT_LEVEL il ON il.impact_level_id=mr.impact_level_id
            WHERE mr.space_id=@space_id AND ms.status_name IN(N'Reported',N'In progress')
              AND il.impact_level_code=N'out_of_service'
              AND mr.start_time<@requested_end_time
              AND COALESCE(mr.completion_time,CONVERT(DATETIME2(0),'9999-12-31'))>@requested_start_time)
            THROW 52102, 'Requested interval overlaps active out-of-service maintenance.', 1;

        INSERT @Advisories(maintenance_record_id)
        SELECT mr.maintenance_record_id
        FROM dbo.MAINTENANCE_RECORD mr
        JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=mr.maintenance_status_id
        JOIN dbo.MAINTENANCE_IMPACT_LEVEL il ON il.impact_level_id=mr.impact_level_id
        WHERE mr.space_id=@space_id AND ms.status_name IN(N'Reported',N'In progress')
          AND il.impact_level_code=N'advisory'
          AND mr.start_time<@requested_end_time
          AND COALESCE(mr.completion_time,CONVERT(DATETIME2(0),'9999-12-31'))>@requested_start_time;

        IF @expected_number_of_participants<=@Capacity
           AND EXISTS(SELECT 1 FROM dbo.INSTANT_APPROVAL_SPACE_TYPE WHERE space_type=@SpaceType)
        BEGIN
            IF EXISTS(
                SELECT 1 FROM dbo.BOOKING_REQUEST br
                JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=br.booking_status_id
                WHERE br.space_id=@space_id AND bs.status_code IN(N'approved',N'checked_in')
                  AND br.requested_start_time<@requested_end_time
                  AND br.requested_end_time>@requested_start_time)
                THROW 52103, 'Approved occupancy overlaps the requested interval.', 1;
            SET @ChosenStatusId=@ApprovedId; SET @ChosenCode=N'approved';
        END
        ELSE
        BEGIN
            SET @ChosenStatusId=@PendingId; SET @ChosenCode=N'pending';
        END;

        INSERT dbo.BOOKING_REQUEST(requester_user_account_id,space_id,booking_status_id,requested_start_time,requested_end_time,purpose_of_use,expected_number_of_participants)
        VALUES(@requester_user_account_id,@space_id,@ChosenStatusId,@requested_start_time,@requested_end_time,@purpose_of_use,@expected_number_of_participants);
        SET @BookingId=CONVERT(INT,SCOPE_IDENTITY());

        INSERT dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT(booking_request_id,maintenance_record_id)
        SELECT @BookingId,maintenance_record_id FROM @Advisories;
        SET @AckCount=@@ROWCOUNT;

        IF @ChosenCode=N'approved'
        BEGIN
            SELECT @SystemUserId=u.user_account_id
            FROM dbo.USER_ACCOUNT u JOIN dbo.ROLE r ON r.role_id=u.role_id
            JOIN dbo.ACCOUNT_STATUS a ON a.account_status_id=u.account_status_id
            WHERE u.user_id=N'SYSTEM_AUTO_APPROVER' AND r.role_name=N'System' AND a.status_name=N'Active';
            IF @SystemUserId IS NULL THROW 52101, 'Active System decision actor is missing.', 1;
            DECLARE @DecisionTime DATETIME2(0)=CONVERT(DATETIME2(0),SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
            INSERT dbo.APPROVAL_DECISION(booking_request_id,decided_by_user_account_id,decision_outcome_booking_status_id,decision_time,decision_note,rejection_reason)
            VALUES(@BookingId,@SystemUserId,@ApprovedId,@DecisionTime,N'Automatic demo approval: configured space type and participants within capacity.',NULL);
        END;

        COMMIT TRANSACTION;
        SELECT @BookingId AS booking_request_id,@ChosenCode AS booking_status_code,@AckCount AS advisory_acknowledgement_count;
        SELECT mr.maintenance_record_id,mr.problem_description,mr.start_time,mr.completion_time
        FROM @Advisories a JOIN dbo.MAINTENANCE_RECORD mr ON mr.maintenance_record_id=a.maintenance_record_id
        ORDER BY mr.maintenance_record_id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_G03_DecideBooking
    @booking_request_id INT,
    @decided_by_user_account_id INT,
    @decision_outcome_code NVARCHAR(40),
    @decision_note NVARCHAR(1000)=NULL,
    @rejection_reason NVARCHAR(1000)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @decision_outcome_code=LOWER(LTRIM(RTRIM(@decision_outcome_code)));
    IF @booking_request_id IS NULL OR @decided_by_user_account_id IS NULL
       OR @decision_outcome_code NOT IN(N'approved',N'rejected')
       OR (@decision_outcome_code=N'rejected' AND NULLIF(LTRIM(RTRIM(@rejection_reason)),N'') IS NULL)
        THROW 52100, 'Invalid decision input.', 1;

    DECLARE @SpaceId INT,@LockedSpaceId INT,@Start DATETIME2(0),@End DATETIME2(0),@CurrentCode NVARCHAR(40),@SpaceStatus NVARCHAR(80);
    DECLARE @OutcomeId INT,@LockResult INT,@Resource NVARCHAR(255);
    BEGIN TRY
        /* Discovery read acquires no retained update lock. The canonical held-lock
           order starts with the space domain, then SPACE, then BOOKING_REQUEST. */
        SELECT @SpaceId=br.space_id
        FROM dbo.BOOKING_REQUEST br
        WHERE br.booking_request_id=@booking_request_id;
        IF @SpaceId IS NULL THROW 52101, 'Booking does not exist.', 1;
        SET @Resource=N'G03:approved-occupancy:space:'+CONVERT(NVARCHAR(20),@SpaceId);

        BEGIN TRANSACTION;
        EXEC @LockResult=sys.sp_getapplock @Resource=@Resource,@LockMode='Exclusive',@LockOwner='Transaction',@DbPrincipal='public';
        IF @LockResult<0 THROW 52110, 'Space lock could not be acquired.', 1;

        SELECT @SpaceStatus=ss.status_name
        FROM dbo.SPACE s WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.SPACE_STATUS ss ON ss.space_status_id=s.space_status_id
        WHERE s.space_id=@SpaceId;
        IF @SpaceStatus IS NULL THROW 52101, 'Space does not exist.', 1;

        SELECT @LockedSpaceId=br.space_id,@Start=br.requested_start_time,@End=br.requested_end_time,@CurrentCode=bs.status_code
        FROM dbo.BOOKING_REQUEST br WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=br.booking_status_id
        WHERE br.booking_request_id=@booking_request_id;
        IF @LockedSpaceId IS NULL THROW 52101, 'Booking does not exist.', 1;
        IF @LockedSpaceId<>@SpaceId THROW 52104, 'Booking space changed during decision.', 1;
        IF @CurrentCode<>N'pending' THROW 52104, 'Only a Pending booking may be decided.', 1;
        IF NOT EXISTS(
            SELECT 1 FROM dbo.USER_ACCOUNT u JOIN dbo.ROLE r ON r.role_id=u.role_id
            JOIN dbo.ACCOUNT_STATUS a ON a.account_status_id=u.account_status_id
            WHERE u.user_account_id=@decided_by_user_account_id
              AND r.role_name IN(N'facility staff',N'facility manager') AND a.status_name=N'Active')
            THROW 52101, 'Decision actor is not authorized active staff.', 1;
        SELECT @OutcomeId=booking_status_id FROM dbo.BOOKING_STATUS WHERE status_code=@decision_outcome_code;
        IF @OutcomeId IS NULL THROW 52101, 'Decision outcome status is missing.', 1;

        IF @decision_outcome_code=N'approved'
        BEGIN
            IF LOWER(@SpaceStatus) IN(N'temporarily closed',N'retired')
                THROW 52102, 'Space is unavailable.', 1;
            IF EXISTS(
                SELECT 1 FROM dbo.BOOKING_REQUEST other_br
                JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=other_br.booking_status_id
                WHERE other_br.space_id=@SpaceId AND other_br.booking_request_id<>@booking_request_id
                  AND bs.status_code IN(N'approved',N'checked_in')
                  AND other_br.requested_start_time<@End AND other_br.requested_end_time>@Start)
                THROW 52103, 'Approved occupancy overlaps this booking.', 1;
            IF EXISTS(
                SELECT 1 FROM dbo.MAINTENANCE_RECORD mr
                JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=mr.maintenance_status_id
                JOIN dbo.MAINTENANCE_IMPACT_LEVEL il ON il.impact_level_id=mr.impact_level_id
                WHERE mr.space_id=@SpaceId AND ms.status_name IN(N'Reported',N'In progress')
                  AND il.impact_level_code=N'out_of_service' AND mr.start_time<@End
                  AND COALESCE(mr.completion_time,CONVERT(DATETIME2(0),'9999-12-31'))>@Start)
                THROW 52102, 'Booking overlaps active out-of-service maintenance.', 1;
        END;

        UPDATE dbo.BOOKING_REQUEST SET booking_status_id=@OutcomeId WHERE booking_request_id=@booking_request_id;
        DECLARE @DecisionTime DATETIME2(0)=CONVERT(DATETIME2(0),SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
        INSERT dbo.APPROVAL_DECISION(booking_request_id,decided_by_user_account_id,decision_outcome_booking_status_id,decision_time,decision_note,rejection_reason)
        VALUES(@booking_request_id,@decided_by_user_account_id,@OutcomeId,@DecisionTime,@decision_note,CASE WHEN @decision_outcome_code=N'rejected' THEN @rejection_reason END);
        COMMIT TRANSACTION;
        SELECT @booking_request_id AS booking_request_id,@decision_outcome_code AS booking_status_code;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_G03_ChangeMaintenanceImpact
    @maintenance_record_id INT,
    @new_impact_level_code NVARCHAR(40)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    SET @new_impact_level_code=LOWER(LTRIM(RTRIM(@new_impact_level_code)));
    IF @maintenance_record_id IS NULL OR @new_impact_level_code NOT IN(N'advisory',N'out_of_service')
        THROW 52100, 'Invalid impact-change input.', 1;

    DECLARE @SpaceId INT,@LockedSpaceId INT,@OldId INT,@NewId INT,@OldCode NVARCHAR(40),@Status NVARCHAR(80);
    DECLARE @Start DATETIME2(0),@End DATETIME2(0),@LockResult INT,@Resource NVARCHAR(255),
            @ChangedAt DATETIME2(0)=CONVERT(DATETIME2(0),SYSUTCDATETIME() AT TIME ZONE 'UTC' AT TIME ZONE 'SE Asia Standard Time');
    BEGIN TRY
        /* Discovery read only; held locks follow space -> maintenance. */
        SELECT @SpaceId=mr.space_id
        FROM dbo.MAINTENANCE_RECORD mr
        WHERE mr.maintenance_record_id=@maintenance_record_id;
        IF @SpaceId IS NULL THROW 52101, 'Maintenance record does not exist.', 1;
        SET @Resource=N'G03:approved-occupancy:space:'+CONVERT(NVARCHAR(20),@SpaceId);

        BEGIN TRANSACTION;
        EXEC @LockResult=sys.sp_getapplock @Resource=@Resource,@LockMode='Exclusive',@LockOwner='Transaction',@DbPrincipal='public';
        IF @LockResult<0 THROW 52110, 'Space lock could not be acquired.', 1;

        IF NOT EXISTS(SELECT 1 FROM dbo.SPACE s WITH(UPDLOCK,HOLDLOCK) WHERE s.space_id=@SpaceId)
            THROW 52101, 'Space does not exist.', 1;

        SELECT @LockedSpaceId=mr.space_id,@OldId=mr.impact_level_id,@OldCode=il.impact_level_code,
               @Status=ms.status_name,@Start=mr.start_time,@End=mr.completion_time
        FROM dbo.MAINTENANCE_RECORD mr WITH(UPDLOCK,HOLDLOCK)
        JOIN dbo.MAINTENANCE_IMPACT_LEVEL il ON il.impact_level_id=mr.impact_level_id
        JOIN dbo.MAINTENANCE_STATUS ms ON ms.maintenance_status_id=mr.maintenance_status_id
        WHERE mr.maintenance_record_id=@maintenance_record_id;
        IF @LockedSpaceId IS NULL THROW 52101, 'Maintenance record does not exist.', 1;
        IF @LockedSpaceId<>@SpaceId THROW 52104, 'Maintenance space changed during impact update.', 1;
        IF @Status NOT IN(N'Reported',N'In progress') THROW 52104, 'Impact may change only while maintenance is active/open.', 1;
        SELECT @NewId=impact_level_id FROM dbo.MAINTENANCE_IMPACT_LEVEL WHERE impact_level_code=@new_impact_level_code;
        IF @NewId IS NULL THROW 52101, 'Impact level is missing.', 1;
        IF @NewId=@OldId THROW 52104, 'New impact must differ from current impact.', 1;
        IF EXISTS(
            SELECT 1 FROM (SELECT TOP(1) new_impact_level_id FROM dbo.MAINTENANCE_IMPACT_EVENT
                           WHERE maintenance_record_id=@maintenance_record_id
                           ORDER BY changed_at DESC,maintenance_impact_event_id DESC) latest
            WHERE latest.new_impact_level_id<>@OldId)
            THROW 52105, 'Current impact does not match latest impact event.', 1;

        UPDATE dbo.MAINTENANCE_RECORD SET impact_level_id=@NewId WHERE maintenance_record_id=@maintenance_record_id;
        INSERT dbo.MAINTENANCE_IMPACT_EVENT(maintenance_record_id,old_impact_level_id,new_impact_level_id,changed_at)
        VALUES(@maintenance_record_id,@OldId,@NewId,@ChangedAt);
        COMMIT TRANSACTION;

        SELECT @maintenance_record_id AS maintenance_record_id,@OldCode AS old_impact_level_code,
               @new_impact_level_code AS new_impact_level_code,@ChangedAt AS changed_at;
        IF @OldCode=N'advisory' AND @new_impact_level_code=N'out_of_service'
            SELECT br.booking_request_id,br.requester_user_account_id,u.user_id,u.full_name,u.email,
                   br.requested_start_time,br.requested_end_time,bs.status_code
            FROM dbo.BOOKING_REQUEST br JOIN dbo.BOOKING_STATUS bs ON bs.booking_status_id=br.booking_status_id
            JOIN dbo.USER_ACCOUNT u ON u.user_account_id=br.requester_user_account_id
            WHERE br.space_id=@SpaceId AND bs.status_code IN(N'approved',N'checked_in')
              AND br.requested_start_time<COALESCE(@End,CONVERT(DATETIME2(0),'9999-12-31'))
              AND br.requested_end_time>CASE WHEN @ChangedAt>@Start THEN @ChangedAt ELSE @Start END
            ORDER BY br.booking_request_id;
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

SELECT OBJECT_ID(N'dbo.usp_G03_SubmitBooking',N'P') AS submit_procedure_id,
       OBJECT_ID(N'dbo.usp_G03_DecideBooking',N'P') AS decision_procedure_id,
       OBJECT_ID(N'dbo.usp_G03_ChangeMaintenanceImpact',N'P') AS impact_procedure_id;
