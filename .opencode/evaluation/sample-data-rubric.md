# Sample Data Evaluation Rubric

Use this rubric to self-check `outputs/06-sample-data-G03.sql` before finalizing it.

## 1. Schema Fidelity

- Uses only tables and columns present in `outputs/05-db-definition-G03.sql`.
- Does not create, alter, or drop schema objects.
- Does not invent unsupported lookup tables such as `DEPARTMENT` when the DDL does not implement them.
- Uses Microsoft SQL Server syntax consistently.

## 2. Constraint Validity

- Inserts parent rows before child rows.
- Every foreign key references an existing parent row.
- Every primary key and unique value is non-duplicated.
- Every required `NOT NULL` column has a value.
- Every `CHECK` value exactly matches the allowed values in the DDL.
- Date/time values satisfy ordering constraints.

## 3. Trigger Compliance

- Reads and accounts for every trigger in the DDL.
- Lists each trigger's affected table and enforced rule in the SQL header.
- Avoids rows that would be rejected by triggers.
- Does not include negative test rows in the load script unless the user explicitly asks for a failing test script.
- Usage-session actual times stay within the requested booking window unless the header explicitly documents an early check-in or late checkout assumption and the DDL permits it.

## 4. Coverage

- Includes realistic parent data for users, spaces, and facilities.
- Covers all required roles implemented by the DDL.
- Covers all required booking statuses implemented by the DDL.
- Covers allowed status values from implemented `CHECK` constraints where practical; for example, include a safe unbooked `SPACE.current_status = 'In use'` row if that value is allowed and otherwise uncovered.
- Covers important exceptional cases: rejected with reason, cancelled, no-show, completed, checked-in/in-progress, maintenance, unavailable spaces where supported.
- Uses varied purposes, participant counts, dates, and notes.

## 5. Traceability and Documentation

- Header includes input analyzed and execution assumption.
- Header includes assumptions carried forward.
- Header includes open questions carried forward, including unresolved questions from earlier stages when relevant.
- Header includes sample coverage / traceability mapping cases to inserted IDs.
- Comments separate SQL sections clearly without replacing executable SQL.
- Approval/rejection notes are semantically clear. Historical approvals for bookings later cancelled, checked in, completed, or marked no-show are labeled as prior/historical approval notes and are not phrased as current status.

## 6. Load Behavior

- Script can run successfully immediately after `outputs/05-db-definition-G03.sql` on a clean database.
- If idempotency is required, the script implements it explicitly and safely for every fixed key/unique value using one consistent dependency-safe strategy; otherwise the clean-schema requirement is documented.
- Fixed identity inserts with `SET IDENTITY_INSERT` are either guarded/cleaned safely for reruns or clearly documented as clean-database-only.
- No insert depends on nondeterministic current dates unless the DDL or requirements explicitly require it.
