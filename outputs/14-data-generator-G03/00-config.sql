/* Shared deterministic defaults repeated by each script: run_id G03-GEN-V2,
   100000 bookings, 120 users, 100 spaces, academic years 2027/28-2029/30. */
SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.MAINTENANCE_IMPACT_EVENT',N'U') IS NULL OR OBJECT_ID(N'dbo.BOOKING_ADVISORY_ACKNOWLEDGEMENT',N'U') IS NULL THROW 52400,'Run artifact 10 first.',1;
SELECT N'G03-GEN-V2' AS run_id,100000 AS target_bookings,120 AS generated_users,100 AS generated_spaces,
       CONVERT(DATE,'2027-09-01') AS first_academic_year_start,3 AS academic_year_count,5000 AS recommended_batch_size;
