# Database Definition Template - Group 03

Use this template as the structural guide for `outputs/05-db-definition-G03.sql`.
The output is a **single SQL file only** 

All metadata, assumptions, open questions, and stub explanations are embedded as
SQL block comments (`-- ...`) iside the `.sql` file itself.

---

## Required SQL File Structure

The SQL file must follow this top-to-bottom structure exactly:

### 1. File Header Block

```sql
-- ============================================================
-- DATABASE DEFINITION - G03
-- Campus Space Management System
-- Target DBMS : Microsoft SQL Server
-- Logical design input : outputs/03-logical-design-G03.md
-- Validation input     : outputs/04-design-validation-G03.md
-- ============================================================
--
-- DDL-STAGE ASSUMPTIONS
-- [ddl-stage] Surrogate integer PKs use IDENTITY(1,1).
-- [ddl-stage] Non-clustered indexes created on all FK columns for join performance.
-- [ddl-stage] Trigger stubs use AFTER INSERT, UPDATE with RAISERROR/ROLLBACK pattern.
-- [ddl-stage] <any additional assumptions introduced at this stage>
--
-- UPSTREAM ASSUMPTIONS CARRIED FORWARD
-- [upstream] facility_id, booking_id, approval_decision_id, usage_session_id,
--            maintenance_record_id are proposed surrogate identifiers not named
--            in the original business requirement.
-- [upstream] USER entity renamed USER_ACCOUNT to avoid reserved SQL Server keyword.
-- [upstream] Lifecycle completion columns are nullable by design.
-- [upstream] decision_note and rejection_reason are distinct attributes on
--            APPROVAL_DECISION; no rejection_reason on BOOKING_REQUEST.
--
-- OPEN QUESTIONS CARRIED FORWARD
-- (See -- OPEN QUESTION blocks at each affected table for detail.)
-- Q1.  MAINTENANCE_RECORD.status: allowed values not confirmed upstream.
-- Q2.  Does an active maintenance record auto-set SPACE.current_status?
-- Q3.  Which roles may report/assign maintenance?
-- Q4.  What triggers Cancelled and No-show booking status transitions?
-- Q5.  Must every approved/rejected booking have exactly one APPROVAL_DECISION row?
-- Q6.  Should expected_number_of_participants <= SPACE.capacity be enforced?
-- Q7.  What are the allowed values for USER_ACCOUNT.account_status?
-- Q8.  Can a booking move Pending -> Checked in without passing through Approved?
-- Q9.  Should APPROVAL_DECISION include a decision_outcome column to simplify
--      BR-13 rejection-reason enforcement? Currently inferred via cross-table join.
-- Q10. <carry forward any additional open questions from §6 of the logical design>
-- ============================================================
```

### 2. Table Blocks (one per table, in dependency order)

Required order: USER_ACCOUNT → SPACE → FACILITY → SPACE_FACILITY →
BOOKING_REQUEST → APPROVAL_DECISION → USAGE_SESSION → MAINTENANCE_RECORD

Each table block follows this structure:

```sql
-- ============================================================
-- TABLE: [TABLE_NAME]
-- Source: Logical Design §2.[n]
-- ============================================================
CREATE TABLE [TABLE_NAME] (
    [column_name]  [SQL_Server_type]  [NOT NULL | NULL],
    ...
    CONSTRAINT [PK_NAME] PRIMARY KEY ([pk_column])
);
GO

-- Foreign keys
ALTER TABLE [TABLE_NAME]
    ADD CONSTRAINT [FK_NAME]
        FOREIGN KEY ([fk_column]) REFERENCES [PARENT_TABLE]([parent_column]);
GO

-- Unique constraints
ALTER TABLE [TABLE_NAME]
    ADD CONSTRAINT [UQ_NAME] UNIQUE ([column]);
GO

-- CHECK constraints
ALTER TABLE [TABLE_NAME]
    ADD CONSTRAINT [CK_NAME] CHECK ([condition]);
GO

-- Indexes on FK columns
CREATE NONCLUSTERED INDEX [IX_TABLE_column] ON [TABLE_NAME] ([column]);
GO
```

After the table DDL, append any applicable stubs and open question blocks:

```sql
-- ------------------------------------------------------------
-- IMPLEMENTATION REQUIRED: [Short rule name]
-- BR: [BR reference number(s)]
-- Tables: [comma-separated list of tables involved]
-- Enforce: [plain-language description of what the trigger must check]
-- ------------------------------------------------------------
CREATE TRIGGER [TR_NAME] ON [TABLE_NAME]
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    -- TODO: implement [rule description]
    -- Example pattern:
    --   IF EXISTS (SELECT 1 FROM INSERTED i JOIN ... WHERE [violation condition])
    --   BEGIN
    --       RAISERROR('[Error message]', 16, 1);
    --       ROLLBACK TRANSACTION;
    --   END
END;
GO

-- OPEN QUESTION [Qn]: [Question text]
-- Affected table/column: [TABLE_NAME].[column_name]
-- No constraint or trigger has been added for this question.
-- Resolve upstream before adding enforcement logic.
```

---

## Required Tables Checklist

Every table listed below must be present in the SQL file.

| # | Table | PK | Key FKs | Unique | Notes |
|---|---|---|---|---|---|
| 1 | `USER_ACCOUNT` | `user_id` | — | — | Renamed from `USER` (reserved word). |
| 2 | `SPACE` | `unique_space_code` | — | — | Natural key from source. |
| 3 | `FACILITY` | `facility_id` | — | — | Surrogate key; proposed identifier. |
| 4 | `SPACE_FACILITY` | `(unique_space_code, facility_id)` | → SPACE, → FACILITY | — | Junction table for M:N. |
| 5 | `BOOKING_REQUEST` | `booking_id` | → USER_ACCOUNT (requester), → SPACE | — | Surrogate key. |
| 6 | `APPROVAL_DECISION` | `approval_decision_id` | → BOOKING_REQUEST, → USER_ACCOUNT (maker) | `booking_id` | UQ enforces 1:0..1. |
| 7 | `USAGE_SESSION` | `usage_session_id` | → BOOKING_REQUEST, → USER_ACCOUNT (×2) | `booking_id` | UQ enforces 1:0..1. Two role-specific FK columns. |
| 8 | `MAINTENANCE_RECORD` | `maintenance_record_id` | → SPACE, → USER_ACCOUNT (×2) | — | Two role-specific FK columns. |

---

## Required Implementation-Logic Stubs Checklist

Every stub listed below must appear in the SQL file. Missing any stub is a Blocking failure.

| # | Trigger/Stub Name | After Which Table | BR Ref |
|---|---|---|---|
| 1 | `TR_BOOKING_REQUEST_NoOverlap` | `BOOKING_REQUEST` | BR-8, BR-9 |
| 2 | `TR_BOOKING_REQUEST_SpaceAvailability` | `BOOKING_REQUEST` | BR-10, BR-20 |
| 3 | `TR_APPROVAL_DECISION_RoleCheck` | `APPROVAL_DECISION` | BR-11, BR-12 |
| 4 | `TR_APPROVAL_DECISION_RejectionReason` | `APPROVAL_DECISION` | BR-13 |
| 5 | `TR_USAGE_SESSION_CheckInRoleCheck` | `USAGE_SESSION` | BR-14 |
| 6 | `TR_USAGE_SESSION_CompletionRoleCheck` | `USAGE_SESSION` | BR-16 |
| 7 | `TR_USAGE_SESSION_CompletionConsistency` | `USAGE_SESSION` | BR-16, BR-17 |

---

## Required Open Question Blocks Checklist

Every open question listed below must have a `-- OPEN QUESTION` comment block
at the relevant table in the SQL file.

| Q# | Affected Table | Topic |
|---|---|---|
| Q1 | `MAINTENANCE_RECORD` | Maintenance status allowed values |
| Q2 | `MAINTENANCE_RECORD` / `SPACE` | Auto-sync of SPACE.current_status from active maintenance |
| Q3 | `MAINTENANCE_RECORD` | Roles permitted to report / assign maintenance |
| Q4 | `BOOKING_REQUEST` | Triggers for Cancelled and No-show status transitions |
| Q5 | `APPROVAL_DECISION` | Whether every approved/rejected booking requires an APPROVAL_DECISION row |
| Q6 | `BOOKING_REQUEST` | Whether expected_number_of_participants ≤ SPACE.capacity should be enforced |
| Q7 | `USER_ACCOUNT` | Allowed values for account_status |
| Q8 | `BOOKING_REQUEST` | Whether approval workflow can be bypassed (Pending → Checked in) |
| Q9 | `APPROVAL_DECISION` | Absence of decision_outcome column and its impact on BR-13 enforcement |