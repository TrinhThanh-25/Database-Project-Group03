# Sample Data SQL Template

Use this structure for `outputs/06-sample-data-G03.sql`.

```sql
/*
Sample Data - Group 03
Target DBMS: Microsoft SQL Server

Input Analyzed:
- outputs/05-db-definition-G03.sql

Execution Assumption:
- Run this script after outputs/05-db-definition-G03.sql has recreated the schema, unless the user explicitly asks for an idempotent sample-data script.
- Idempotency: [state "clean database only" or describe the dependency-safe IF NOT EXISTS / scoped cleanup strategy used consistently throughout the script.]

Assumptions Carried Forward:
- [List assumptions that affect sample data.]

Open Questions Carried Forward:
- [List unresolved questions from prior stages that affect sample data, or state "None identified in the input used for this stage."]

Trigger Compliance:
- TRG_NAME on TABLE_NAME: [rule enforced] -> [how inserted rows comply].

Sample Coverage / Traceability:
- Requirement/table/constraint coverage: [short mapping].
- Enumerated value coverage: [map implemented CHECK status values to inserted IDs/codes where practical, including SPACE.current_status values such as In use if allowed].
- Exceptional case: [case name] -> [inserted ID or code].
*/

/* ============================================================
   Parent table section
   ============================================================ */

INSERT INTO dbo.TABLE_NAME (column_1, column_2) VALUES
(value_1, value_2);
GO

/* ============================================================
   Child table section
   ============================================================ */

INSERT INTO dbo.CHILD_TABLE_NAME (child_column, parent_key_column) VALUES
(child_value, parent_key_value);
GO
```

Required output properties:

- Use only tables and columns implemented in `outputs/05-db-definition-G03.sql`.
- Use explicit column lists in every `INSERT`.
- Order inserts so every foreign key parent exists first.
- Make the script either clean-database-only with a clear header assumption or fully idempotent with one consistent dependency-safe strategy.
- Include comment sections for assumptions, open questions, trigger compliance, and coverage traceability.
- Map exceptional cases to specific inserted IDs.
- Keep approval notes consistent with booking lifecycle status; historical approvals should say they are historical when the current booking status has changed.
- Keep usage-session actual times inside the requested booking window unless an explicitly documented assumption says otherwise.
- Do not include internal self-check or command logs in this SQL file.
