# Conceptual Database Design - Group 03

## 1. Source Documents

- Requested input: [path as named in the command spec]
- Actual input used: [path actually found via `ls -la`]

## 2. Conceptual ERD

[Insert Mermaid erDiagram block here.]

> Note: Where two or more distinct relationships exist between the same entity pair, only one representative line is shown in the diagram. See §4 Relationship Constraints for the full detail of each relationship.

## 3. Entity Definitions

### 3.1 [Entity Name]

[One-line description.]

Attributes:
- [identifier_attribute] *(identifier)* — source: [upstream entity definition / proposed surrogate per Rule 1]
- [Attribute 2] — source: [upstream entity definition sentence or "proposed surrogate"]
- ...

> Relationships involving this entity are listed in §4 Relationship Constraints.

### 3.2 [Entity Name]

[One-line description.]

Attributes:
- [identifier_attribute] *(identifier)* — source: [upstream entity definition / proposed surrogate per Rule 1]
- [Attribute 2] — source: [upstream entity definition sentence]
- ...

> Relationships involving this entity are listed in §4 Relationship Constraints.

## 4. Relationship Constraints

This table is the authoritative relationship model. The Mermaid diagram in §2 is a visual aid only.

> Write the `Cardinality` value in the same order as the columns: Entity-A side first, then Entity-B side (e.g. `1 to 0..*` means A=1, B=0..*). Keep this orientation uniform on every row — do not flip it for individual rows.

| Relationship Name | Entity A | Entity B | Cardinality | Participation | Explanation |
|---|---|---|---|---|---|
| [RELATIONSHIP_NAME] | [Entity A] | [Entity B] | [e.g. 1 to 0..*] | A→B: Each [A] … [zero/one/many] [B]. B→A: Each [B] must … [exactly one / zero or one] [A]. | [Source: upstream analysis "Relationships" row / business rule ref] |

## 5. Business Rule Coverage

For every business rule in the upstream analysis (Section 6), explain how the conceptual design supports it, or explicitly state that enforcement is deferred.

| Upstream Rule | How the Design Supports It |
|---|---|
| [Rule ref + text] | [Design element that captures it, OR "[Rule] — enforcement deferred to logical/physical design"] |

## 6. Design Reasoning

[Explain design choices, trade-offs, and non-obvious decisions. Must include: why any multi-relationship pairs between the same entity pair are kept as distinct relationships despite the Mermaid diagram merging them visually.]

## 7. Assumptions

Every assumption must carry a source tag:
- `[upstream]` — carried forward from the upstream analysis without change.
- `[upstream-corrected]` — item from upstream that was modified here (e.g. duplicate attribute removed, identifier added). Must state what changed and why.
- `[design-level]` — new assumption introduced at this stage, not present in upstream analysis.

An assumption list that uses only generic statements without itemising each one is incomplete and blocks delivery.

- [upstream] [Assumption text]
- [upstream-corrected] [What changed and why]
- [design-level] [New assumption and justification]

## 8. Open Questions

List every ambiguity or unresolved issue from the upstream analysis that has a direct impact on this model. Do not summarise upstream open questions as a single bullet — each must have its own entry.

- [Open question from upstream analysis, with note on which design decision it blocks or defers]
- [New ambiguity identified at this stage]
