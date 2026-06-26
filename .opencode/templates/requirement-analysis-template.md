# Business Requirement Analysis - Group 03

## 1. Source Documents

- Requested input: [path as named in the command spec]
- Actual input used: [path actually found via `ls -la`]
- Target system: [system name]

## 2. Business Context

[2-4 sentences grounded in Layer A.]

## 3. System Actors

| Actor | Description | Main Responsibilities / Interactions |
|---|---|---|
| ... | ... | ... |

## 4. Main Entities and Attributes

### 4.1 [Entity Name]

[One-line description.]

Attributes:

- [Attribute 1]
- [Attribute 2]
- ...

Possible [enum field name]s (if applicable):

- ...

## 5. Relationships and Cardinalities

| Relationship | Cardinality | Description |
|---|---:|---|
| ... | ... | ... |

## 6. Business Rules

### 6.1 [Rule Category] Rules

- [Rule, grounded in Layer B]
- ...

## 7. State Transitions

> List only transitions clearly implied by Layer B. Status values whose transition trigger/role the source does not state — e.g. `Cancelled` and `No-show` — stay in the allowed-values list but are NOT asserted as transitions here; carry their missing trigger/role as scoped Open Questions (application/backend-layer), and note that this is intentional, not a data-modeling gap.

### 7.1 [Entity] Status Transitions

| From Status | To Status | Trigger / Condition (grounded in Layer B) |
|---|---|---|
| ... | ... | ... |

## 8. Role Permissions

| Action | Allowed Role(s) per source text | Source basis |
|---|---|---|
| Submit booking request | ... | ... |
| Approve / reject booking | ... | ... |
| Check in booking | ... | ... |
| Complete usage session | ... | ... |
| Report maintenance issue | ... | ... |
| Assign maintenance staff | ... | ... |

Populate ALL actions found in source.
Minimum rows shown below are examples only.
Add additional rows as required.

## 9. Workflow Narratives

### 9.1 Booking Lifecycle (request → approval → check-in → completion)

[Narrative, citing rule numbers inline, e.g., "...per Rule 6.4, the system records..."]

### 9.2 Maintenance Lifecycle (report → assignment → resolution)

[Narrative, citing rule numbers inline.]

## 10. Cross-Entity Constraints

- [Constraint, with explicit note on which direction is grounded in Layer B and which direction (if any) is ambiguous]

## 11. Traceability Matrix

| Requirement Area | Source Requirement | Related Entities | Related Relationships | Related Business Rules |
|---|---|---|---|---|
| ... | ... | ... | ... | ... |

## 12. Assumptions

- [Every assumption made anywhere above, restated here for visibility]

## 13. Open Questions

- Question: [Every "reasonable but unstated" rule, every Layer-A-only detail that didn't qualify for Section 6, ambiguous transition, or ambiguous cross-entity dependency that was deliberately NOT asserted as fact above] — Scope: [Database | Backend | Frontend | Authorization | Business Workflow | Mixed | Other]
