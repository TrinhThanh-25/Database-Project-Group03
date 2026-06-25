# Database Design Validation Rubric

## Purpose

This rubric defines the evaluation criteria used to validate the quality, completeness, correctness, consistency, and implementation readiness of the submitted database design deliverables.

The reviewer must use this rubric to objectively assess the submitted artifacts without redesigning the solution or introducing new business requirements.

---

# Evaluation Criteria

## 1. Requirement Analysis Validation

### Objective

Verify that the business requirement analysis accurately captures the original business requirements.

### Evaluation Criteria

- Business purpose is correctly identified.
- All actors are identified.
- All major entities are identified.
- Important attributes are identified.
- Relationships are identified.
- Business rules are captured.
- Assumptions and open questions are explicitly documented.
- No unsupported business requirements are introduced.

---

## 2. Conceptual Database Design Validation

### Objective

Verify that the ERD correctly represents the business domain.

### Evaluation Criteria

- All required entities are present.
- Entity names are meaningful and consistent.
- Relationships correctly represent business processes.
- Cardinalities are correct.
- Participation constraints are appropriate.
- Many-to-many relationships are modeled correctly.
- Important business concepts are represented.
- No unnecessary entities are introduced.

---

## 3. Logical Database Design Validation

### Objective

Verify that the conceptual design has been correctly transformed into a relational schema.

### Evaluation Criteria

- Every conceptual entity is mapped to an appropriate relation.
- Primary keys are correctly defined.
- Foreign keys correctly represent relationships.
- Candidate keys are identified where appropriate.
- Many-to-many relationships are resolved correctly.
- Naming conventions are consistent.
- Redundant data is minimized.
- The schema follows relational database design best practices.

---

## 4. Constraint Validation

### Objective

Verify that the schema supports the required integrity constraints.

### Evaluation Criteria

- Primary key constraints are appropriate.
- Foreign key constraints are complete.
- CHECK constraints are defined where applicable.
- UNIQUE constraints are applied where required.
- NOT NULL constraints are used appropriately.
- Referential integrity is preserved.

---

## 5. Business Rule Validation

### Objective

Verify that business rules are properly represented throughout the design.

### Evaluation Criteria

For each important business rule, verify whether it is:

- captured during requirement analysis;
- represented in the conceptual design;
- represented in the logical schema;
- enforceable during database implementation.

Business rules that cannot be enforced using relational constraints alone should be identified as implementation risks.

---

## 6. Requirement Coverage Validation

### Objective

Verify that every important business requirement is traceable throughout the design.

### Evaluation Criteria

Each major requirement should be traceable to:

- Business Requirement Analysis
- Conceptual Database Design
- Logical Database Design

Missing coverage should be reported.

---

## 7. Design Consistency Validation

### Objective

Verify consistency across all submitted deliverables.

### Evaluation Criteria

The reviewer should verify that:

- entity names remain consistent;
- attribute names remain consistent;
- relationship definitions remain consistent;
- business rules remain consistent;
- terminology is used consistently throughout all documents.

---

## 8. Implementation Risk Assessment

### Objective

Identify design decisions that require implementation logic beyond the relational schema.

### Examples

Examples include, but are not limited to:

- overlapping booking prevention;
- unavailable space booking prevention;
- role-based authorization;
- conditional constraints;
- workflow-dependent validation.

The reviewer should explain why implementation logic is required and identify the associated implementation risk.

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

---

## Medium

An issue that may introduce ambiguity, weaken validation, or increase implementation complexity without fundamentally invalidating the design.

Examples:

- Missing conditional constraint
- Nullable field requiring clarification
- Weak normalization
- Missing business rule documentation

---

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