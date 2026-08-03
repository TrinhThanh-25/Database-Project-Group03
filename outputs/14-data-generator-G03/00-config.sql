/*
 Group 03 Phase 2 large-scale generator configuration.

 These are SQLCMD variables. Run the generator scripts in SQLCMD mode.
 Change G03_TARGET_BOOKINGS to 500000 for the optional larger benchmark.
*/

:setvar G03_RUN_PREFIX "G03-LS"
:setvar G03_TARGET_BOOKINGS "100000"
:setvar G03_REQUESTER_COUNT "800"
:setvar G03_STAFF_COUNT "20"
:setvar G03_SPACE_COUNT "20"
:setvar G03_FACILITY_COUNT "10"
:setvar G03_BASE_DATE "2028-08-19"
:setvar G03_SLOT_HOURS "2"
:setvar G03_SLOTS_PER_DAY "4"
:setvar G03_BATCH_SIZE "50000"
