# Evaluation Rubric - Database Design Validation

Use this rubric to produce and self-check `outputs/04-design-validation-G03.md`.

## Purpose

This rubric defines the criteria used to validate the quality, completeness, correctness, consistency, and implementation readiness of the submitted database design deliverables. It is run by the database-design-reviewer agent itself as a mandatory self-check before delivering the validation report, and can also be used by a human reviewer afterward.

The reviewer must use this rubric to objectively assess the submitted artifacts without redesigning the solution or introducing new business requirements. Every Blocking item must be examined before the report is delivered.

## How to Score

For each check, mark **PASS**, **FAIL**, or **N/A** with a short justification. A **FAIL** means the reviewed design has an issue that must be reported in `outputs/04-design-validation-G03.md` with a severity level, supporting evidence, and a recommendation (see the rules below). Do not conclude the review or assign a grade while any Blocking check is unexamined.

---

## A. Requirement Analysis Validation (Blocking)

Verify that the business requirement analysis accurately captures the original business requirements.

| # | Check | Pass Criteria |
|---|---|---|
| A1 | Business purpose is correctly identified | The analysis states the system's purpose consistent with the source. |
| A2 | All actors are identified | Every role named in the source appears as an actor. |
| A3 | All major entities are identified | Every major entity in the source is captured. |
| A4 | Important attributes are identified | Key attributes for each entity are present. |
| A5 | Relationships are identified | Relationships between entities are captured. |
| A6 | Business rules are captured | Source business rules appear in the analysis. |
| A7 | Assumptions and open questions are explicitly documented | Both sections are present and non-empty where applicable. |
| A8 | No unsupported business requirements are introduced | No rule/attribute is asserted beyond what the source supports. |
| A9 | Cancelled/No-show transitions are correctly classified, not flagged as a defect | The analysis lists `Cancelled`/`No-show` as status values but does not assert their transition triggers, carrying the missing trigger/role as a scoped Open Question (application/backend-layer). The reviewer treats this as accepted handling, **not** a data-modeling gap; report a finding only if the analysis instead asserted an ungrounded transition rule or mis-scoped the question. |

## B. Conceptual Database Design Validation (Blocking)

Verify that the ERD correctly represents the business domain.

| # | Check | Pass Criteria |
|---|---|---|
| B1 | All required entities are present | Every analysis entity is modeled. |
| B2 | Entity names are meaningful and consistent | Names match analysis terminology. |
| B3 | Relationships correctly represent business processes | Each relationship reflects a real source interaction. |
| B4 | Cardinalities are correct | Cardinalities match the analysis. |
| B5 | Participation constraints are appropriate | Optional/mandatory participation matches the source. |
| B6 | Many-to-many relationships are modeled correctly | M:N relationships are represented as such. |
| B7 | Important business concepts are represented | No major concept is dropped. |
| B8 | No unnecessary entities are introduced | No invented entity is present. |

## C. Logical Database Design Validation (Blocking)

Verify that the conceptual design has been correctly transformed into a relational schema.

| # | Check | Pass Criteria |
|---|---|---|
| C1 | Every conceptual entity is mapped to an appropriate relation | One table per conceptual entity. |
| C2 | Primary keys are correctly defined | Each table has an appropriate, named PK. |
| C3 | Foreign keys correctly represent relationships | Every relationship is an FK, unique FK, or junction table. |
| C4 | Candidate keys are identified where appropriate | Natural unique attributes are recognized as candidate keys. |
| C5 | Many-to-many relationships are resolved correctly | M:N becomes a junction table with composite key. |
| C6 | Naming conventions are consistent | Table/column/PK/FK/UQ/CK names follow one convention. |
| C7 | Redundant data is minimized | No fact is duplicated across tables. |
| C8 | The schema follows relational design best practices | Normalization is reasonable and justified. |

## D. Constraint Validation (Blocking)

Verify that the schema supports the required integrity constraints.

| # | Check | Pass Criteria |
|---|---|---|
| D1 | Primary key constraints are appropriate | Each PK uniquely identifies its rows. |
| D2 | Foreign key constraints are complete and type-matched | Each FK column is `INT`, matching the surrogate `INT` PK it references; flag any FK that targets a demoted natural-key attribute or whose type differs from the referenced surrogate PK. |
| D3 | CHECK constraints are defined where applicable | Allowed-value CHECKs use upstream values; every derivable single-row CHECK is present — chronological ordering of paired time columns (`requested_end_time > requested_start_time`, `actual_end_time > actual_start_time`, `completion_time > start_time`). A missing in-row CHECK is a logical-design gap, not merely an implementation risk, and must be reported even when trigger-level rules are well covered. |
| D4 | UNIQUE constraints match candidate keys | Candidate keys — the university-account `email` and every natural key demoted from PK (`user_id`, `unique_space_code`) — carry a named UNIQUE; uniqueness is not invented beyond candidate keys. |
| D5 | NOT NULL matches source-stated strength | A column is NOT NULL only where the source makes the value mandatory. A NOT NULL on a source-optional note (e.g. `decision_note`) while a sibling note (`usage_notes`) is nullable is an inconsistency to report. |
| D6 | Referential integrity is preserved | All references resolve to valid parent rows. |
| D7 | Every FK declares explicit, consistently-reasoned referential actions | Each FK states both `ON DELETE` and `ON UPDATE`, with the criterion behind the choice present and applied consistently across all FKs (junction associations CASCADE on delete; references to historical/master data RESTRICT/NO ACTION on delete to preserve history; `ON UPDATE NO ACTION` uniformly because all PKs are immutable `INT` surrogates). Report any FK missing an action or with absent/inconsistent reasoning. |
| D8 | Every constraint is named; no in-row rule is prose-only | All CHECK/UNIQUE/FK/PK constraints have explicit names. Any conditional rule expressible as a single-row CHECK is a named constraint — the rejected-decision rule must be a named `CK_APPROVAL_DECISION_rejection_reason`, not prose. Only genuine cross-row/cross-table rules may stay prose-only as implementation logic. |
| D9 | Many-side cardinality is not silently restricted by UNIQUE | No `0..*` (many-side) FK carries a UNIQUE that collapses it to `0..1`. `APPROVAL_DECISION.booking_id` is non-unique (matching conceptual `HAS_DECISION` `1 to 0..*`) unless an explicit requirement forces one decision per booking; an unjustified UNIQUE is reported. |
| D10 | Primary keys are standardized to surrogate INTEGER keys | Every entity's PK is a surrogate `INT`; every former natural-key column (`user_id`, `unique_space_code`) is preserved as an attribute with a named `UNIQUE` constraint; every FK references the correct surrogate `INT` PK with a matching `INT` type. Report any table that still uses a string/natural PK, any missing UNIQUE on a demoted natural key, or any FK still pointing at a natural key. |

## E. Business Rule Validation (Blocking)

Verify that business rules are properly represented throughout the design.

| # | Check | Pass Criteria |
|---|---|---|
| E1 | Each business rule is traced through every stage | For each rule, confirm whether it is captured in analysis, represented in the conceptual design, represented in the logical schema, and enforceable during implementation. |
| E2 | Non-relational rules are flagged as implementation risks | Rules that cannot be enforced by relational constraints alone are identified as implementation risks. |

## F. Requirement Coverage Validation (Blocking)

Verify that every important business requirement is traceable throughout the design.

| # | Check | Pass Criteria |
|---|---|---|
| F1 | Each major requirement is traceable across stages | Traceable to Business Requirement Analysis, Conceptual Design, and Logical Design. |
| F2 | Missing coverage is reported | Any requirement without full coverage is flagged. |

## G. Design Consistency Validation (Blocking)

Verify consistency across all submitted deliverables.

| # | Check | Pass Criteria |
|---|---|---|
| G1 | Entity names remain consistent | Same entity name used across all documents. |
| G2 | Attribute names remain consistent | Same attribute name used across all documents. |
| G3 | Relationship definitions remain consistent | Relationships described identically across stages. |
| G4 | Business rules remain consistent | Rules are not restated with conflicting meaning. |
| G5 | Terminology is used consistently | No two names for the same concept. |
| G6 | Inferred/proposed elements are labeled consistently | Any value the source does not state as a stored fact (e.g. a derived `decision_outcome` from the "approved or rejected" conditional) carries a visible inference tag and a matching assumption, rather than being asserted as fact. |
| G7 | Cardinality notation order is uniform | The conceptual §4 table reads Entity-A side first on every row. |

## H. Implementation Risk Assessment (Blocking)

Identify design decisions that require implementation logic beyond the relational schema.

| # | Check | Pass Criteria |
|---|---|---|
| H1 | Implementation-logic needs are identified with rationale and risk | For each rule needing logic beyond the schema (e.g. overlapping booking prevention, unavailable-space booking prevention, role-based authorization, conditional constraints, workflow-dependent validation), the report explains why and states the associated risk. |

---

# Severity Levels

## High

A critical issue that may violate business requirements, compromise data integrity, or prevent correct implementation.

Examples:

- Missing core entity
- Incorrect relationship
- Missing primary key
- Incorrect foreign key
- Missing enforcement of a critical business rule

## Medium

An issue that may introduce ambiguity, weaken validation, or increase implementation complexity without fundamentally invalidating the design.

Examples:

- Missing conditional constraint
- Nullable field requiring clarification
- Weak normalization
- Missing business rule documentation

## Low

A minor issue affecting maintainability, readability, documentation, or consistency.

Examples:

- Naming inconsistency
- Documentation improvement
- Optional constraint
- Style improvement

---

# Evidence Rule

Every finding must reference evidence from one or more reviewed artifacts.

The reviewer must not report unsupported findings or make assumptions beyond the submitted documents.

Cite evidence by quoting or paraphrasing its content and naming the requirement label or section (e.g. "BR-15", "the approval paragraph"). Do not cite the raw requirement (`req/business-requirement.md`) by line number — it is continuous prose, so line indices do not map to discrete rules and are unverifiable. Flag any upstream document that cites the source by fabricated line numbers as a Low-severity traceability issue.

---

# Recommendation Rule

Each identified issue should include:

- Issue description
- Severity level
- Supporting evidence
- Recommendation

Recommendations should improve the submitted design without redesigning the entire database.

---

# Final Decision

The reviewer shall assign one of the following outcomes:

- **ACCEPTED**
  - The design satisfies the business requirements with no significant issues.

- **ACCEPTED WITH CONDITIONS**
  - The design is acceptable, but implementation or clarification is required before proceeding.

- **REJECTED**
  - The design contains critical issues that prevent progression to database implementation.

The final decision must be supported by the evaluation results and identified issues.

## Grading Discipline

- A top-range grade (A / A-, or any "excellent, no significant issues" rating) for the logical or conceptual design is not permitted while basic enforceable-without-trigger constraints are missing or unverified: in-row CHECK ordering constraints (D3), constraint-strength consistency (D5), FK/PK data-type matching (D2), uniform cardinality notation (G7), explicit and consistently-reasoned FK referential actions (D7), complete constraint naming with no prose-only in-row rule (D8), non-over-restricted many-side cardinality (D9), and surrogate-INTEGER primary-key standardization with demoted natural keys preserved as UNIQUE (D10). Verify each before settling on a grade.
- Do not state "no … issue was found" for any criterion you did not actually check. Thorough coverage of trigger-level rules (overlap, role, cross-table) does not substitute for checking the simple in-row constraints; let the grade reflect any that are missing.

---

## Self-Check Execution Log

Write the completed self-check to `.opencode/logging/self-check-log.md`, not inside the final report.

```text
Run date: [date]
Run time: [time]
Run by: [agent / human reviewer]

A1-A9: [PASS/FAIL each] — [note]
B1-B8: [PASS/FAIL each] — [note]
C1-C8: [PASS/FAIL each] — [note]
D1-D10: [PASS/FAIL each] — [note]
E1-E2: [PASS/FAIL each] — [note]
F1-F2: [PASS/FAIL each] — [note]
G1-G7: [PASS/FAIL each] — [note]
H1: [PASS/FAIL] — [note]

Blocking failures remaining: [list, or "none"]
Final decision: [ACCEPTED / ACCEPTED WITH CONDITIONS / REJECTED]
```
