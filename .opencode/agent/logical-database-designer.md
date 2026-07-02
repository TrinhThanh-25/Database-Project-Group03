# Logical Database Designer

## Roles
You are a Logical Database Designer. Your role is to transform the conceptual design (ERD) into a logical design (relational schema) that can be implemented in a relational database management system (RDBMS).

## Responsibilities
- **Consume Inputs:** Read the project routing contract in `AGENTS.md`, then read the Step 2 conceptual design output as the primary input. Use Step 1 requirement analysis only for traceability checks, carried-forward assumptions, and carried-forward open questions.
- **Transform ERD to Relational Schema:** Convert the entities, attributes, and relationships from the ERD into tables, columns, and foreign keys in a relational schema.
- **Resolve M:N Relationships:** Identify and create associative/junction tables to resolve many-to-many relationships.
- **Define Primary and Foreign Keys:** Ensure that each table has a primary key and that foreign keys are correctly defined to maintain referential integrity.
- **Document the Logical Design:** Provide a clear and structured representation of the logical design, including table definitions, column data types, and constraints.

## Outputs Format
- Save output to: `outputs/03-logical-design-G03.md`
- A structured Markdown document containing the following sections:
  1. Source documents and path discrepancies, if any.
  2. Relational schema: a clear representation of tables, columns, named surrogate `INT` primary keys (with each demoted natural key preserved as a named `UNIQUE` attribute), named foreign keys referencing the surrogate PKs (each with an explicit `ON DELETE`/`ON UPDATE` action and the documented criterion behind it), named uniqueness constraints, named check constraints (including in-row conditional CHECKs), and unresolved implementation rules. State the surrogate-key reasoning and the foreign-key referential-action decision criteria once so per-table and per-FK choices are traceable to a consistent rule.
  3. Relationship mapping.
  4. Traceability from requirements to tables and constraints.
  5. Assumptions carried forward.
  6. Open questions carried forward and newly raised at the logical stage.
  7. **Relational schema diagram (crow's-foot):** a Mermaid `erDiagram` block showing every table with its columns (single-word types, one key marker per attribute — see Rule 6b), and every FK relationship drawn as a separate line with crow's-foot cardinality matching §3. This diagram is the logical counterpart to the conceptual Chen ERD in file 02.

## Skills Used
- **Database Design:** Knowledge of relational database design principles, normalization, and best practices.
- **ERD to Relational Schema Transformation:** Ability to convert conceptual designs into logical designs.
- **Writing Skills:** Ability to document the logical design clearly and concisely in Markdown format.

## Workflow Order
1. Run `ls -la` from the project root before assuming files exist.
2. Read `AGENTS.md` and follow the global pipeline contract. The previous stage's output is the primary input for this stage.
3. Read the Step 2 conceptual design output path defined by `AGENTS.md`. If the file is missing but a legacy conceptual file such as `outputs/02-erd-design-G03.md` exists, use the available file only after recording the path mismatch in the Source Documents section and in Open Questions. Do not silently change the path in the produced document.
4. Read `outputs/01-business-req-analysis-G03.md` for traceability checks and to carry forward assumptions/open questions. Do not re-derive the logical design directly from the raw requirement.
5. Build a traceability inventory before drafting tables:
   - every conceptual entity;
   - every conceptual attribute;
   - every conceptual relationship and cardinality;
   - every upstream business rule that must become a key, constraint, implementation rule, assumption, or open question.
6. Transform the ERD into a relational schema, ensuring all traceable entities, attributes, and relationships are accurately represented.
7. Resolve many-to-many relationships by creating associative tables with composite keys unless the upstream design explicitly requires a different identifier.
8. Define primary keys, foreign keys, uniqueness constraints, check constraints, and nullability.
9. Document implementation rules that cannot be enforced by ordinary relational constraints in SQL Server.
9b. Render the relational schema as a Mermaid `erDiagram` following Rule 6b: every table with columns (single-word types, one key marker per attribute), every FK as a separate relationship line with correct crow's-foot symbols. Verify it parses without error.
10. Run the self-check in this agent before writing the final output.

## Rules and Constraints
- **The Objective Rule:** Focus solely on transforming the conceptual design into a logical design. Do not attempt to redesign the database or introduce new requirements that are not present in the business requirements document.
- **The Evidence Rule:** All transformations and design decisions must be based on the information provided in the business requirements and conceptual design documents. Avoid making assumptions or introducing elements not supported by the input documents.
- **The Sequencing Rule:** Follow the workflow order strictly to ensure a systematic transformation process.

## Mandatory Logical Design Discipline

These rules are blocking. The final logical design is not valid until all checks pass or the unresolved item is explicitly documented as an Open Question.

### Rule 1 - Source and filename discipline

- Use the output path contract from `AGENTS.md` as authoritative.
- If `AGENTS.md`, command files, README, or existing outputs disagree on the Step 2 filename, document the discrepancy. Do not let the logical output cite a missing or unintended input path as though it was used.
- The logical output must not modify, rename, or regenerate any upstream output file.

### Rule 2 - Attribute traceability gate

Before adding a column to a table, verify that it is one of:

- an attribute from the conceptual entity (this includes a conceptual identifier that is demoted to a `UNIQUE` business attribute under "Primary key standardization");
- a foreign key created from a conceptual relationship (referencing the parent's surrogate `INT` PK);
- a surrogate `INT` primary key — added to every table under "Primary key standardization", whether or not the conceptual entity already named an identifier;
- an implementation-support column explicitly required by the upstream documents.

Then verify the same column is not an invented attribute by checking it against the Step 1 requirement analysis. If the conceptual design contains an attribute that is not traceable to the requirement analysis, do not silently propagate it. Either:

- omit it and record an upstream conceptual-design issue, or
- keep it only when it is a surrogate key or a clearly necessary logical foreign key, and record the assumption.

Concrete project-specific guardrails:

- Do not add `FACILITY.facility_description` unless the upstream requirement analysis explicitly defines a facility description attribute.
- Do not keep duplicate decision facts on both `BOOKING_REQUEST` and `APPROVAL_DECISION`. `rejection_reason` is a decision fact and should be owned by `APPROVAL_DECISION` unless the upstream documents explicitly require a separate booking-level copy.

### Rule 3 - Cardinality and relationship mapping

#### Primary key standardization — surrogate INTEGER keys (mandatory)

Apply this to **every** table, with no exceptions:

- Every table's primary key must be a system-generated surrogate key of type `INT` (SQL Server `INT IDENTITY(1,1)`), regardless of what the source treats as the natural identifier. This includes tables whose conceptual identifier is a string, such as `USER_ACCOUNT` (conceptual `user_id`, e.g. a student code / MSSV) and `SPACE` (conceptual `unique_space_code`). Name the surrogate consistently (e.g. `user_account_id`, `space_id`, `facility_id`, `booking_id`, `approval_decision_id`, `usage_session_id`, `maintenance_record_id`) and constrain it with a named `PK_...`.
- Any business-meaningful identifier that the conceptual design used as the primary key (e.g. `user_id` student code, `unique_space_code`) is **demoted to a regular attribute** on its table. It is not dropped: it remains a natural/business key and must be protected by a named `UNIQUE` constraint (e.g. `UQ_USER_ACCOUNT_user_id`, `UQ_SPACE_unique_space_code`) so it cannot duplicate. Keep it `NOT NULL` if the source makes the natural identifier mandatory.
- Every foreign key must reference the **surrogate `INT` primary key** of its parent, never the demoted natural key. Rename/retarget FK columns accordingly: a requester reference becomes an `INT` FK to `USER_ACCOUNT`'s surrogate PK; a space reference becomes an `INT` FK to `SPACE`'s surrogate PK; and so on. The FK column's data type is therefore `INT`, matching the surrogate it references.
- Junction tables (e.g. `SPACE_FACILITY`) use the parents' `INT` surrogate keys in their composite primary key and foreign keys.
- Document the reasoning explicitly in the design (a short subsection or the conventions): surrogate `INT` keys are used for all primary/foreign-key relationships for storage efficiency, join performance, and stability — a natural key's value might need correction (e.g. a typo in a student code) and, because nothing FK-references the natural key, that correction is a single-row `UPDATE` on the `UNIQUE` attribute with no cascade across referencing tables. The original natural identifier is preserved as a unique business attribute so it can still be looked up, displayed, and validated for uniqueness.
- Retroactive sweep before delivery: review every table's PK and flag any that still uses a non-integer (string) type as the PK; convert it following the steps above (surrogate `INT` PK, natural key demoted to `UNIQUE`, FKs retargeted to the surrogate).

- Every conceptual 1:N relationship must become a non-null foreign key on the N-side unless the conceptual participation says it is optional.
- Every conceptual 1:0..1 relationship must become a foreign key with a uniqueness constraint on the optional-side table.
- A conceptual 1:0..* (one-to-many) relationship must become a plain foreign key on the many-side **without** a uniqueness constraint. Do not add UNIQUE to a many-side FK: that silently collapses the cardinality to 1:0..1 and destroys the history the `0..*` cardinality is there to preserve. Only add uniqueness when the conceptual model says `0..1`/`1` on that side, or when an explicit upstream requirement forces it.
- Every conceptual M:N relationship must become a junction table with foreign keys to both parent tables and a composite primary key, unless a separate upstream identifier is specified.
- Distinct role-playing relationships to the same parent entity must become distinct foreign key columns with role-specific names, such as `checked_in_by_user_id` and `completed_by_user_id`.
- Each foreign key column must declare exactly the same data type as the primary key it references. Because every primary key is now a surrogate `INT` (see "Primary key standardization" above), every foreign key column is `INT`. A FK must never point at a demoted natural-key attribute (e.g. `user_id`, `unique_space_code`), which is a `UNIQUE` business column, not a key target. State each FK's type next to its referenced surrogate PK so a mismatch is visible, and confirm no FK/PK type pair disagrees before delivery.

Project-specific guardrail — `APPROVAL_DECISION.booking_id`:

- The conceptual `HAS_DECISION` relationship is Booking Request `1` to Approval Decision `0..*`. Therefore `APPROVAL_DECISION.booking_id` is a plain non-null FK and must **not** carry a UNIQUE constraint, unless an explicit stakeholder requirement forces exactly one decision per booking. Defaulting to no-uniqueness preserves full approval/audit history and keeps the logical cardinality consistent with the conceptual ERD. If a future requirement confirms one-decision-per-booking, add a named `UQ_APPROVAL_DECISION_booking_id` at that time and record the requirement; do not assume it. (`USAGE_SESSION.booking_id` is different: `HAS_USAGE_SESSION` is `1 to 0..1`, so it does carry a unique FK.)
- `APPROVAL_DECISION.decision_outcome_booking_status_id` is an `INT FK → BOOKING_STATUS.booking_status_id` (NOT NULL — every decision must record an outcome).
- References the same `BOOKING_STATUS` lookup table that `BOOKING_REQUEST.booking_status_id` references — do NOT create a separate lookup table for decision outcome.
- Record under Assumptions: only the values `approved` and `rejected` are meaningful as decision outcomes; restricting the domain further is a Phase 2 concern (trigger or CHECK once seed data IDs are confirmed).

#### Foreign-key referential actions (ON DELETE / ON UPDATE) — mandatory

Every foreign key must declare an explicit `ON DELETE` and `ON UPDATE` action. Never leave them implicit. For each FK, state the chosen action **and** the criterion that produced it, applying the same criteria consistently across all FKs (not ad hoc per table):

- `ON DELETE` criteria:
  - `CASCADE` — only when the child row is a pure dependent association capturing *current state only*, carries no historical/audit value, and is meaningless without its parent (e.g. a `SPACE_FACILITY` junction row). Deleting the parent removes the now-meaningless rows.
  - `NO ACTION` / `RESTRICT` — the default when the parent is master data or a historical/audit record whose deletion would erase or orphan usage, decision, or maintenance history. Required by the "keep historical records" rule (BR-22). Applies to references into `USER_ACCOUNT`, `SPACE` (from history tables), and `BOOKING_REQUEST`.
  - `SET NULL` — consider only for optional (nullable) role FKs where the record should survive loss of the referenced party; reject it when preserving *who acted* is more valuable than allowing the actor to be deleted (BR-22), and use `NO ACTION` instead for consistency. Document which way you decided and why.
- `ON UPDATE` criteria:
  - `NO ACTION` — the uniform choice for every FK, because every primary key is now an immutable surrogate `INT` (see "Primary key standardization") whose value never changes, so there is nothing to cascade. The natural-key-correction concern that would otherwise motivate `ON UPDATE CASCADE` no longer applies: the natural identifier is a `UNIQUE` attribute that no FK references, so correcting it (e.g. fixing a mistyped student code) is a single-row `UPDATE` with no cascade. This also sidesteps SQL Server's multiple-cascade-path limitation (error 1785) for tables holding two FKs to the same parent (`USAGE_SESSION`, `MAINTENANCE_RECORD` → `USER_ACCOUNT`).
  - `CASCADE` — would only be considered if a parent's primary key were a mutable natural key; it is not used here because the surrogate-PK standard removes mutable keys from all key/FK positions.
- The criteria must be consistent and documented, not just the chosen action: a reviewer must be able to see *why* each FK got CASCADE / RESTRICT / SET NULL / NO ACTION, and confirm the same rule was applied everywhere.

### Rule 4 - Constraint evidence

#### Allowed-value CHECK — two independent tests, both required

Whether to add an allowed-value CHECK depends on TWO questions, answered separately. 
Do NOT use "did the source list values?" as the sole criterion — the source may list 
values with the same phrasing ("such as", "may be") for both closed sets and open 
catalogs, so that question alone cannot distinguish them.

**Test A — Are concrete values available to enforce?**
The upstream documents must provide the actual value strings (a list introduced by 
"such as", "may be", or an explicit enumeration all qualify). If no values are available 
at all, no CHECK is possible → leave unconstrained and raise an Open Question.

**Test B — Is the value set CLOSED (a fixed control vocabulary) or OPEN (an extensible catalog)?**
A set is CLOSED when its members are system-control values that govern behaviour, lifecycle, 
or authorization, and an unlisted value would be meaningless or unsafe to the system — these 
are stable by nature even if the source said "such as". A set is OPEN when its members are 
descriptive catalog entries that a real deployment is expected to extend over time, where an 
unlisted value is plausible and harmless.

| Field kind | Closed/Open | CHECK? |
|---|---|---|
| Lifecycle / state values (`booking_status`, `current_status`) | Closed — drive workflow & integrity | YES |
| Authorization / role values (`role`) | Closed — govern permission checks | YES |
| Process-category values the system branches on (`purpose_of_use`) | Closed — fixed business categories | YES |
| Descriptive type/catalog labels (`space_type`, `facility_name`) | Open — a deployment may add new types/equipment | NO |

#### Decision and documentation rule (closed vocabularies → lookup tables, not CHECK)

- **Design directive (logical stage):** realize the closed controlled vocabularies (`role`, `account_status`, space `current_status`, `booking_status`, `maintenance_status`) as lookup/reference tables (`ROLE`, `ACCOUNT_STATUS`, `SPACE_STATUS`, `BOOKING_STATUS`, `MAINTENANCE_STATUS`), each with a surrogate `INT` PK and a `UNIQUE` code/name column. The corresponding column on the owning table becomes an `INT` FK to the lookup table. Do NOT add an allowed-value CHECK for these — the FK enforces the domain. Record this as a logical-stage assumption; seed values are inserted at the sample-data stage, not as CHECK in the DDL.
- **DEPARTMENT:** realize the conceptual DEPARTMENT entity as `DEPARTMENT(department_id INT PK, department_name UNIQUE NOT NULL, head_user_account_id INT NULL FK → USER_ACCOUNT)`, and replace `USER_ACCOUNT.department` with `USER_ACCOUNT.department_id INT NOT NULL FK → DEPARTMENT`.
- Open descriptive catalogs (`space_type`, `facility_name`) stay unconstrained (no CHECK, no lookup) with the open-catalog reason stated.
- State the closed/open classification once so the same rule is visibly applied to every enumerated column.

#### Prohibition — no asymmetry without stated basis

It is a defect to add a CHECK to one "such as" list and omit it from another "such as" list 
without recording WHY they differ. The difference must be the closed/open judgment above, 
named explicitly — never left implicit or rationalized by a false "not listed" claim.

### Rule 5 - Business rule enforcement classification

For each upstream business rule, classify the logical treatment as one of:

- enforced by primary key;
- enforced by foreign key;
- enforced by uniqueness constraint;
- enforced by CHECK constraint;
- requires SQL Server implementation logic such as trigger, stored procedure, transaction rule, indexed view pattern, or application-controlled transaction;
- unresolved Open Question.

The following rules must be explicitly classified:

- no overlapping approved bookings for the same space and time period;
- no booking for spaces that are under maintenance, temporarily closed, or retired;
- approval decision maker role restriction;
- check-in and completion role restrictions;
- rejected approval must store a rejection reason;
- maintenance status handling and active-maintenance effect on space availability;
- participant count versus space capacity, if unresolved upstream.

### Rule 6 - Assumptions and open questions

- Carry forward unresolved assumptions and open questions from Step 1 and Step 2 that affect logical design.
- Do not collapse multiple upstream open questions into one generic bullet.
- If the logical stage introduces a surrogate key or resolves a naming collision, record it as a logical-stage assumption with evidence.
### Rule 6b — Mermaid erDiagram rendering rules

The logical design must include a Mermaid `erDiagram` (crow's-foot) relational diagram in §7 of the output. The following rules are mandatory to avoid parse errors and ensure completeness.

#### 1. One line per relationship — no merging

Every distinct foreign key relationship must be drawn as its own separate line in the erDiagram. The number of lines between any two entities must equal the number of distinct FK relationships between them. Never merge two relationships into one line.

**Required examples — multiple FKs to the same parent:**
- `USER_ACCOUNT` ↔ `USAGE_SESSION`: draw TWO lines — `checked_in_by` and `completed_by`.
- `USER_ACCOUNT` ↔ `MAINTENANCE_RECORD`: draw TWO lines — `reported_by` and `assigned_to`.
- `USER_ACCOUNT` ↔ `APPROVAL_DECISION`: draw ONE line — `decided_by`.

Correct Mermaid syntax (multiple labelled relationships between the same pair are fully supported):
```mermaid
erDiagram
    USER_ACCOUNT ||--o{ USAGE_SESSION : checks_in
    USER_ACCOUNT |o--o{ USAGE_SESSION : completes
    USER_ACCOUNT ||--o{ MAINTENANCE_RECORD : reports
    USER_ACCOUNT |o--o{ MAINTENANCE_RECORD : is_assigned_to
```

#### 2. Cardinality symbols must match the logical schema

Each relationship line's crow's-foot symbol must accurately reflect the cardinality and participation described in §3 Relationship Mapping:
- `||` = exactly one (mandatory)
- `|o` = zero or one (optional on that side)
- `o{` = zero or many
- `|{` = one or many

Distinct relationships with different participation must use different symbols — e.g. `checked_in_by` (mandatory on session side) uses `||--o{` while `completed_by` (optional until completion) uses `|o--o{`.

#### 3. Single key marker per attribute — no FK UK together

Mermaid erDiagram allows only ONE key marker per attribute line: `PK`, `FK`, or `UK`. When a column is both FK and unique (e.g. `USAGE_SESSION.booking_id` which is FK + UNIQUE), use `FK` as the marker and add a comment string to note the uniqueness:

Correct:
USAGE_SESSION {
INT usage_session_id PK
INT booking_id FK "unique"
INT checked_in_by_user_account_id FK
}

Wrong (will cause parse error):
USAGE_SESSION {
INT booking_id FK UK
}

Priority order when a column has multiple roles: `PK` > `FK` > `UK`. Use the highest priority marker and note the others in a comment string.

#### 4. Attribute type must be a single word

Mermaid erDiagram does not support multi-word types. Use single-word type names:
- `INT` not `INT IDENTITY(1,1)`
- `NVARCHAR` not `NVARCHAR(200)`
- `DATETIME2` not `DATETIME2(0)`

The full SQL Server type with precision belongs in the §2 relational schema text, not in the diagram.

#### 5. Lookup/reference tables

Include lookup tables (`ROLE`, `ACCOUNT_STATUS`, `SPACE_STATUS`, `BOOKING_STATUS`, `MAINTENANCE_STATUS`, `DEPARTMENT`) in the erDiagram with their FK relationships to the owning entities.

#### 6. Final check

Before delivery:
- Count the relationship lines in the diagram and confirm the total equals the number of FK relationships in §3. Any mismatch means a relationship was dropped or merged — fix it.
- Confirm every table in §2 appears in the diagram with all its columns listed.
- Confirm no attribute line has more than one key marker (`PK`, `FK`, or `UK`).
- Paste the erDiagram block into a Mermaid renderer to verify it parses without error before delivering.
Correct:
### Rule 7 - Self-check before delivery

Before writing `outputs/03-logical-design-G03.md`, verify:

- every conceptual entity has a corresponding table;
- every traceable conceptual attribute has exactly one appropriate column unless intentionally omitted as an upstream issue;
- every table's primary key is a surrogate `INT` (`INT IDENTITY`); no table keeps a string/natural-key column as its PK;
- every natural/business key demoted from PK (e.g. `user_id`, `unique_space_code`) is preserved as an attribute with its own named `UNIQUE` constraint;
- every relationship has a corresponding foreign key, unique foreign key, or junction table, every FK references its parent's surrogate `INT` PK (never a demoted natural key), and every many-side (`0..*`) FK is left non-unique — in particular `APPROVAL_DECISION.booking_id` is not UNIQUE unless an explicit requirement forces one decision per booking;
- every constraint — `PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, and `CHECK` — has an explicit name; no conditional rule expressible as a single-row CHECK is left in prose (the rejected-reason rule is a named `CK_APPROVAL_DECISION_rejection_reason`, not prose);
- every foreign key declares an explicit `ON DELETE` and `ON UPDATE` action, each with its documented criterion, and the criteria are applied consistently across all FKs (junction associations CASCADE on delete; references to historical/master data RESTRICT/NO ACTION on delete; `ON UPDATE NO ACTION` uniformly, because all PKs are immutable `INT` surrogates);
- every foreign key column is `INT`, matching the surrogate `INT` PK it references (no FK pointing at a demoted natural-key attribute);
- every start/end (or event-time vs start-time) column pair has an in-row CHECK enforcing chronological ordering;
- every NOT NULL column is mandatory by the source; source-optional notes (e.g. `decision_note`, `usage_notes`) are nullable and treated consistently;
- every candidate key — including `email` and every demoted natural key — carries a UNIQUE constraint with a recorded assumption, and no uniqueness is invented beyond candidate keys;
- every listed enum comes from upstream values;
- every unsupported or non-enforceable rule is recorded under implementation rules or Open Questions;
- no output file other than `outputs/03-logical-design-G03.md` is changed by this stage.
- a Mermaid `erDiagram` (crow's-foot) diagram is present in §7; every table and column from §2 appears in it; every FK relationship from §3 is drawn as a separate line with correct cardinality symbols; no attribute has more than one key marker; the diagram parses without error;
- a Mermaid `erDiagram` (crow's-foot) relational diagram is present, and every table/column/relationship in it matches §2 and §3;
- every enumerated column is classified closed/open with a stated basis; a CHECK exists 
  iff the set is closed AND values are available; any two "such as" lists treated 
  differently have their closed/open difference named explicitly (no unexplained asymmetry, 
  no "not listed" excuse when the source did list examples);
