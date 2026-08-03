# Phase 2 Requirement Change Analysis - Group 03

## 1. Metadata and Source Documents

Owned artifact: `outputs/08-requirement-change-analysis-G03.md`

This artifact is produced by the Phase 2 Requirement Change Analyst. It compares the authoritative Phase 2 requirement with the approved Phase 1 business/design baseline, assigns stable analytical labels, classifies changes, and identifies downstream impacts. It does not choose physical storage, locking, indexing, stored-program, or migration mechanisms.

Authoritative inputs read:

| Source | Purpose |
|---|---|
| `AGENTS.md` | Project routing, Phase 2 order, output paths, shared assumptions/open-question rules |
| `req/phase-2-business-requirement.md` | Authoritative Phase 2 source |
| `outputs/01-business-req-analysis-G03.md` | Phase 1 business baseline |
| `outputs/03-logical-design-G03.md` | Phase 1 implemented-design baseline for impact identification |
| `outputs/05-db-definition-G03.sql` | Phase 1 implementation baseline, used only to confirm what Phase 1 stores/enforces |

Source boundary:

- Phase 1 remains the baseline unless the Phase 2 source changes it within a stated scope.
- Phase 2 Section 1.1 changes the Phase 1 maintenance booking rule. Phase 1 BR-19 said a space under maintenance cannot be booked; Phase 2 now distinguishes out-of-service maintenance from advisory maintenance.
- Phase 2 Section 1.2 strengthens Phase 1 BR-09 and BR-10 by requiring the approved-booking non-overlap rule to hold under concurrent instant booking and staff approval operations.
- Phase 2 Section 1.3 and Section 2 add reporting, data generation, query tuning, migration, concurrency, and normalization deliverables.

## 2. Executive Summary

Phase 2 does not replace the Phase 1 system. It extends it in four major areas:

1. Maintenance is no longer a single all-blocking condition. Out-of-service maintenance still blocks overlapping bookings, but advisory maintenance allows booking with notification and recorded acknowledgement.
2. Maintenance records may coexist for the same space and may change impact level while still open. Escalating an advisory to out-of-service creates a business need to find already-approved overlapping bookings so staff can contact requesters.
3. Booking approval now has two paths: instant approval for selected space types when the request satisfies the usage policy, and existing staff approval for other requests. The business invariant is stronger than Phase 1 because it must hold when users and staff act simultaneously.
4. Phase 2 adds analytical reports, large generated data, query tuning evidence, additive migration, concurrency evidence, and normalization validation obligations.

The largest unresolved business choices are the meaning of "selected space types", how to evaluate "satisfy the usage policy", what counts as an active or open maintenance record, how interval endpoints overlap, and whether historically approved statuses such as checked-in or completed count as approved for reports.

## 3. Phase 2 Traceability-Label Catalog

The labels `P2-BR-*` are analytical identifiers [proposed — not stated in source] created for traceability. They do not appear in the Phase 2 source.

| ID | Atomic Phase 2 requirement | Source citation | Classification |
|---|---|---|---|
| P2-BR-01 | Phase 2 extends the Phase 1 system after the pilot; it does not replace Phase 1. | Phase 2 Section 1, "Phase 2 extends the Phase 1 system accordingly." | New |
| P2-BR-02 | Maintenance work must have an impact level. | Phase 2 Section 1.1, "maintenance has impact level out-of-service" and "impact level advisory." | Changed |
| P2-BR-03 | Out-of-service maintenance makes the space unusable. | Phase 2 Section 1.1, out-of-service examples and unusable wording. | Changed |
| P2-BR-04 | A space cannot be booked for any period that overlaps an out-of-service maintenance period. | Phase 2 Section 1.1, "cannot be booked for any time period that overlaps the maintenance period." | Changed |
| P2-BR-05 | Advisory maintenance means the space remains usable even though equipment or comfort is affected. | Phase 2 Section 1.1, advisory examples and usable wording. | Changed |
| P2-BR-06 | Advisory maintenance does not prevent booking. | Phase 2 Section 1.1, "the space can still be booked." | Changed |
| P2-BR-07 | At booking time, the requester must be notified of all active advisories on the selected space. | Phase 2 Section 1.1, advisory notification sentence. | New |
| P2-BR-08 | The system must record that the requester was informed of advisory maintenance, with the acknowledgement stored with the booking. | Phase 2 Section 1.1, "must record that the requester was informed." | New |
| P2-BR-09 | A space may have several active maintenance records at the same time. | Phase 2 Section 1.1, additional rules, simultaneous records sentence. | Changed |
| P2-BR-10 | Simultaneous active maintenance records for one space may have different impact levels. | Phase 2 Section 1.1, additional rules, "with different impact levels." | New |
| P2-BR-11 | A maintenance record's impact level may be escalated or downgraded while the maintenance is still open. | Phase 2 Section 1.1, escalation/downgrade sentence. | New |
| P2-BR-12 | When an advisory is escalated to out-of-service, already-approved bookings overlapping the maintenance period must be identified. | Phase 2 Section 1.1, affected-booking identification sentence. | New |
| P2-BR-13 | The system must support finding affected bookings so staff can contact requesters. | Phase 2 Section 1.1, "so that staff can contact the requesters." | New |
| P2-BR-14 | At the beginning of each semester, many users may submit booking requests at approximately the same time. | Phase 2 Section 1.2, first paragraph. | Unchanged but affected |
| P2-BR-15 | Popular spaces may receive several overlapping requests within a short interval. | Phase 2 Section 1.2, first paragraph. | Unchanged but affected |
| P2-BR-16 | For selected space types, requests satisfying the usage policy may be approved automatically at submission time. | Phase 2 Section 1.2, instant approval sentence. | New |
| P2-BR-17 | Requests outside the instant-approval scope continue through the existing staff approval workflow. | Phase 2 Section 1.2, "Other requests continue..." | Changed |
| P2-BR-18 | Concurrent users and staff may check availability before any operation records its result. | Phase 2 Section 1.2, concurrency risk paragraph. | New |
| P2-BR-19 | The system must prevent two approved bookings from using the same space during overlapping periods. | Phase 2 Section 1.2, invariant sentence. | Unchanged but affected |
| P2-BR-20 | The approved-booking non-overlap rule must hold regardless of whether approval occurs by instant booking or staff approval. | Phase 2 Section 1.2, "regardless of whether..." | Changed |
| P2-BR-21 | The approved-booking non-overlap rule must remain valid during simultaneous user and staff operations. | Phase 2 Section 1.2, final sentence. | Changed |
| P2-BR-22 | The system must support total approved booking hours of each space for a given semester. | Phase 2 Section 1.3, first report bullet. | New |
| P2-BR-23 | The system must support number of approved bookings by weekday and hour for a given semester. | Phase 2 Section 1.3, second report bullet. | New |
| P2-BR-24 | The system must support finding available spaces satisfying required capacity, required facilities, and a given period. | Phase 2 Section 1.3, third report bullet. | New |
| P2-BR-25 | The system must support reporting approved bookings affected when a maintenance record is escalated to out-of-service. | Phase 2 Section 1.3, fourth report bullet. | New |
| P2-BR-26 | Students must implement all four Phase 2 analytical queries. | Phase 2 Section 1.3, "Students must implement all of these queries." | New |
| P2-BR-27 | Index/tuning work must cover the booking conflict check, the room finder, and reporting queries. | Phase 2 Section 1.3 indexing sentence and Phase 2 Section 2 indexing/tuning paragraph. | New |
| P2-BR-28 | Queries must be tested on a sufficiently large generated dataset so before/after indexing differences can be observed. | Phase 2 Section 1.3, generated dataset sentence. | New |
| P2-BR-29 | Phase 2 requires requirement-change analysis of affected entities, relationships, business rules, and concurrent-operation conflicts. | Phase 2 Section 2, Requirement Change Analysis paragraph. | New |
| P2-BR-30 | Phase 2 requires an updated ERD and relational schema supporting impact levels, advisory acknowledgements, and concurrent booking. | Phase 2 Section 2, Design Update paragraph. | New |
| P2-BR-31 | Phase 2 migration must implement changes on top of Phase 1 and preserve existing data or document the migration approach. | Phase 2 Section 2, Schema Migration paragraph. | New |
| P2-BR-32 | Phase 2 concurrency work must identify at least one conflict, implement a suitable solution, and provide demonstration scripts. | Phase 2 Section 2, Concurrency Design and Implementation paragraph. | New |
| P2-BR-33 | Generated sample data must cover at least three academic years and at least 100,000 booking records, with maintenance, cancellations, no-shows, and advisory acknowledgements. | Phase 2 Section 2, Sample Data Generation paragraph. | New |
| P2-BR-34 | Analytical query work must implement all reports and select two reporting queries other than room finder for detailed indexing/performance analysis. | Phase 2 Section 2, Analytical Queries paragraph. | New |
| P2-BR-35 | Indexing and tuning must compare execution plans and execution times before and after indexing. | Phase 2 Section 2, Indexing and Query Tuning paragraph. | New |
| P2-BR-36 | Normalization validation must identify functional dependencies and ensure all relations satisfy at least 3NF. | Phase 2 Section 2, Normalization Validation paragraph. | New |
| P2-BR-37 | The Phase 2 group report must include members, individual queries, LLM/agent improvements, concurrency conflicts/solutions/results, tuning results, FDs, and normal-form proof or steps to 3NF. | Phase 2 Section 3.1, Group Report bullets. | New |
| P2-BR-38 | The repository must include the numbered Phase 2 artifacts 08 through 16. | Phase 2 Section 3.2, Group Agent Git Repository artifact list; AGENTS.md Phase 2 outputs. | New |
| P2-BR-39 | The source spells artifact 16 with `.sq`, while Group 03 records and uses `.sql` for the SQL Server script. | Phase 2 Section 3.2 artifact list and the preservation note in `req/phase-2-business-requirement.md`; AGENTS.md Phase 2 Source and Outputs. | New |

## 4. Requirement Change Matrix

| P2 ID(s) | Change type | Phase 1 baseline | Phase 2 effect |
|---|---|---|---|
| P2-BR-01 | New | Phase 1 artifacts define the original booking, maintenance, usage, and reporting baseline. | Phase 2 must preserve Phase 1 unless explicitly changed. |
| P2-BR-02 through P2-BR-06 | Changed | Phase 1 BR-19 and CEC-02 treat under-maintenance space as not bookable. | Maintenance now has impact levels; only out-of-service maintenance blocks overlapping bookings, while advisory maintenance allows booking. |
| P2-BR-07, P2-BR-08 | New | Phase 1 stores maintenance records and bookings but has no advisory notification or acknowledgement fact. | Booking-time advisory notification and booking-linked acknowledgement become new business facts. |
| P2-BR-09, P2-BR-10 | Changed/New | Phase 1 allows a space to have many maintenance records over time but does not explicitly describe multiple active simultaneous records or mixed impact levels. | Phase 2 requires simultaneous active records and different impact levels to be representable. |
| P2-BR-11 through P2-BR-13 | New | Phase 1 maintenance status values and transitions are unresolved; no impact-level change workflow exists. | Impact level may change while open, and escalation to out-of-service creates an affected-booking lookup/contact workflow. |
| P2-BR-14, P2-BR-15 | Unchanged but affected | Phase 1 BR-09 and BR-10 already prevent approved overlapping bookings. | High-volume concurrent submission makes the existing invariant operationally risky. |
| P2-BR-16, P2-BR-17 | New/Changed | Phase 1 says a booking request may require approval, and approval criteria are an open question. | Phase 2 introduces instant approval for selected qualifying requests while preserving staff approval for others. |
| P2-BR-18 through P2-BR-21 | Changed | Phase 1 recorded the no-overlap rule as a cross-entity constraint requiring implementation logic. | The rule must be protected across simultaneous instant and staff approval operations. |
| P2-BR-22 through P2-BR-26 | New | Phase 1 query design covers operational queries, not the full Phase 2 analytical report set. | Four new analytical reports must be implemented. |
| P2-BR-27, P2-BR-28, P2-BR-34, P2-BR-35 | New | Phase 1 has no performance-evidence obligation. | Phase 2 requires large-data testing and before/after tuning evidence for conflict checking, room finding, and reporting queries. |
| P2-BR-29 through P2-BR-33, P2-BR-36 through P2-BR-39 | New | Phase 1 produced artifacts 01 through 07. | Phase 2 requires artifacts 08 through 16, additive migration, concurrency design/tests, generated data, normalization validation, and report documentation. |

Superseded Phase 1 rule:

- Phase 1 BR-19, "A space under maintenance cannot be booked," is superseded only where Phase 2 Section 1.1 distinguishes advisory maintenance. The narrower Phase 2 rule is: out-of-service maintenance blocks overlapping bookings; advisory maintenance permits booking with notification and acknowledgement. Phase 1 BR-19 still matters for out-of-service maintenance and for unresolved interpretations of the existing "under maintenance" space status.

## 5. Affected Actors and Permissions

| Actor | Phase 1 role | Phase 2 impact |
|---|---|---|
| Booking requester roles: student, lecturer, teaching assistant, department administrator | Submit booking requests. | Must receive all active advisory notices at booking time and have acknowledgement recorded with the booking (P2-BR-07, P2-BR-08). May receive instant approval for selected qualifying requests (P2-BR-16). |
| Facility staff | Approve/reject bookings, check in/complete usage, maintenance assignment may be stored. | Continue staff approval for non-instant requests (P2-BR-17). Need affected-booking lookup when maintenance escalates (P2-BR-12, P2-BR-13). May participate in concurrent approval conflicts (P2-BR-18 through P2-BR-21). |
| Facility manager | Stakeholder and approval actor in Phase 1. | Needs new reports and affected-booking visibility (P2-BR-22 through P2-BR-25). Provides the changed maintenance policy in Phase 2 Section 1.1. |
| System/service behavior [proposed — not stated in source] | Phase 1 did not describe a system actor for automatic decisions. | Needed as an analytical label for automatic approval at submission time; the source states automatic approval but does not name an actor or audit requirement (P2-BR-16). |
| Staff for requester contact [proposed — not stated in source] | Phase 1 says staff view history and maintenance lists but does not define contact workflow. | Staff must be able to find affected approved bookings so requesters can be contacted after escalation; the source does not require storing the contact attempt or outcome (P2-BR-13). |

Permission impacts and unresolved boundaries:

- "Selected space types" is not defined in the source. The affected permission/scope of instant approval remains open (P2-BR-16).
- "Satisfy the usage policy" is not executable from the Phase 2 source. Phase 1 already carried usage-policy enforcement as an open question; Phase 2 makes the question blocking for instant approval (P2-BR-16).
- The source does not say whether instant approvals need an approval-decision audit comparable to staff approvals. This affects downstream design and migration but is not resolved here.

## 6. Affected Entities, Facts, and Relationships

Affected Phase 1 entities and business facts:

| Phase 1 concept | Existing Phase 1 basis | Phase 2 impact |
|---|---|---|
| SPACE | Phase 1 BR-03/BR-04 store space details and current status. | Space remains the booked/maintained resource. Availability now depends on booking overlaps, out-of-service maintenance overlaps, advisory notices, and existing closed/retired rules. |
| MAINTENANCE_RECORD | Phase 1 BR-17/BR-18 store space, reporter, assignment, problem, start/completion, status, and result. | Needs the business fact "impact level" with at least out-of-service and advisory values from Phase 2 Section 1.1. Multiple active records with mixed impact levels must be supported. |
| Maintenance activity state [proposed — not stated in source] | Phase 1 open question: allowed maintenance status values and transitions are unresolved. | Phase 2 uses "active" and "still open"; the exact mapping to Phase 1 maintenance status remains open. |
| BOOKING_REQUEST | Phase 1 BR-06/BR-08 store request details and status. | Must represent instant/staff approval outcome, advisory acknowledgement, and affected approved bookings for reports. |
| APPROVAL_DECISION | Phase 1 BR-13 records staff decision maker, time, note, and outcome for approved/rejected staff decisions. | Phase 2 adds instant approval; whether automatic approval has an equivalent decision record is open. |
| BOOKING_STATUS | Phase 1 BR-08 includes pending, approved, rejected, cancelled, checked in, completed, no-show. | Reports refer to "approved bookings"; whether checked-in or completed statuses count as approved history is open. |
| FACILITY | Phase 1 BR-05 stores facilities available in each space. | Room finder must filter available spaces by required facility list (P2-BR-24). |
| USER_ACCOUNT | Phase 1 BR-01/BR-02 stores requester and staff roles. | Requesters must receive advisory notice; staff contact affected requesters; concurrent staff approvals are in scope. |
| Usage session | Phase 1 BR-15/BR-16 stores actual check-in and completion facts. | Not directly changed, but generated data must include cancellations and no-shows, and reports may need to avoid confusing usage completion with approval state. |

Affected relationships:

| Relationship | Phase 2 impact |
|---|---|
| SPACE has MAINTENANCE_RECORD | Must allow multiple simultaneous active records and mixed impact levels for the same space. |
| BOOKING_REQUEST selects SPACE | Booking-time evaluation must consider approved booking overlaps, out-of-service maintenance overlaps, and active advisories. |
| USER_ACCOUNT submits BOOKING_REQUEST | Requester receives advisory notices and acknowledgement is stored with the booking. |
| BOOKING_REQUEST has APPROVAL_DECISION | Existing staff decision history is affected by the new instant approval path, but the source does not state whether instant approval creates the same kind of decision fact. |
| USER_ACCOUNT makes APPROVAL_DECISION | Staff approval remains for non-instant requests; concurrent staff operations are now explicitly in scope. |
| SPACE has FACILITY | Room finder requires matching capacity and required facility list for a requested period. |

## 7. Changed and New Business Rules

Changed maintenance rules:

- Phase 1 BR-19 is narrowed: out-of-service maintenance blocks overlapping bookings, per P2-BR-03 and P2-BR-04.
- Advisory maintenance is non-blocking but requires requester notice and stored acknowledgement, per P2-BR-05 through P2-BR-08.
- A space may have multiple active maintenance records with different impact levels, per P2-BR-09 and P2-BR-10.
- Impact level may change while maintenance is still open, per P2-BR-11.
- Escalation from advisory to out-of-service requires finding already-approved overlapping bookings for staff contact, per P2-BR-12 and P2-BR-13.

Changed booking/approval rules:

- Phase 1 BR-10 remains substantively unchanged as a business invariant: two approved bookings for the same space cannot overlap.
- Phase 2 strengthens the enforcement context: the invariant must hold across instant approval and staff approval, and under simultaneous operations, per P2-BR-20 and P2-BR-21.
- Phase 2 adds instant approval for selected space types when requests satisfy usage policy, per P2-BR-16.
- Staff approval remains for other requests, per P2-BR-17.

New reporting and evidence rules:

- Four analytical reports are required: total approved hours by space, approved bookings by weekday/hour, room finder, and affected bookings after maintenance escalation (P2-BR-22 through P2-BR-25).
- The implementation must support large-data testing and tuning evidence (P2-BR-27, P2-BR-28, P2-BR-33 through P2-BR-35).
- Updated design must include FDs and at least 3NF validation (P2-BR-36).

Rules not resolved here:

- No policy predicate is invented for "satisfy the usage policy".
- No qualifying space types are chosen.
- No endpoint convention is chosen for overlapping intervals.
- No final schema, transaction, locking, indexing, or stored-program mechanism is selected.

## 8. Concurrent-Operation Conflict Analysis

The schedules below describe business-operation races only. They identify why the Phase 2 invariant is at risk; they do not prescribe a technical concurrency-control mechanism.

### 8.1 Schedule A: Instant approval versus instant approval

Initial state:

- Space S [proposed — not stated in source] is a selected space type eligible for instant approval.
- Request R1 [proposed — not stated in source] and Request R2 [proposed — not stated in source] target the same space with overlapping requested periods.
- No already-approved booking is visible for that space/period.
- No out-of-service maintenance overlaps the requested period.
- Advisory notices, if any, are non-blocking and acknowledged at booking time.

Operation A:

1. User A submits R1.
2. The system checks whether R1 can be instantly approved.
3. The system observes the space as available for R1's requested period.
4. The system prepares to record R1 as approved.

Operation B:

1. User B submits R2 at approximately the same time.
2. The system checks whether R2 can be instantly approved.
3. Before Operation A's result is visible to Operation B, the system also observes the space as available.
4. The system prepares to record R2 as approved.

Conflict:

- Availability observation made by A: no approved overlapping booking exists.
- Availability observation made by B: no approved overlapping booking exists.
- If both operations record approval, two approved bookings use the same space during overlapping periods.
- Violated invariant: P2-BR-19, P2-BR-20, P2-BR-21.
- This is both a logical booking conflict and a check-then-write race caused by concurrent execution.

### 8.2 Schedule B: Staff approval versus instant approval

Initial state:

- Pending Request R3 [proposed — not stated in source] and new Request R4 [proposed — not stated in source] target the same space with overlapping requested periods.
- R3 is in the staff approval path.
- R4 qualifies for instant approval.
- No approved overlapping booking is visible before either operation records approval.

Operation A:

1. Staff member reviews R3.
2. Staff member checks availability for the requested space/period.
3. Staff member observes no approved overlapping booking.
4. Staff member prepares to approve R3.

Operation B:

1. User submits R4 at approximately the same time.
2. The system checks instant approval eligibility and availability.
3. Before Operation A's result is visible to Operation B, the system observes no approved overlapping booking.
4. The system prepares to approve R4 instantly.

Conflict:

- Availability observation made by staff path: R3 appears approvable.
- Availability observation made by instant path: R4 appears approvable.
- If both operations record approval, the same space has overlapping approved use.
- Violated invariant: P2-BR-18, P2-BR-19, P2-BR-20, P2-BR-21.
- This is both a logical booking conflict and a check-then-write race across two approval paths.

### 8.3 Schedule C: Staff approval versus staff approval

Initial state:

- Pending Requests R5 and R6 [proposed — not stated in source] target the same space with overlapping periods.
- Two staff members review the requests simultaneously.
- No approved overlapping booking is visible before either decision is recorded.

Operation A:

1. Staff member A checks availability for R5.
2. Staff member A observes no approved overlapping booking.
3. Staff member A prepares to approve R5.

Operation B:

1. Staff member B checks availability for R6.
2. Before Operation A's result is visible, Staff member B observes no approved overlapping booking.
3. Staff member B prepares to approve R6.

Conflict:

- If both approvals are recorded, the same space has overlapping approved use.
- Violated invariant: P2-BR-18, P2-BR-19, P2-BR-20, P2-BR-21.
- This is a check-then-write race in the existing staff approval workflow, newly made explicit by Phase 2.

### 8.4 Maintenance escalation impact schedule

Initial state:

- Advisory Maintenance M1 [proposed — not stated in source] affects Space S and overlaps already-approved Booking R7 [proposed — not stated in source].
- R7 was allowed because advisory maintenance does not block booking.

Operation:

1. Staff changes M1's impact level from advisory to out-of-service while M1 is still open.
2. The system must identify already-approved bookings overlapping M1's maintenance period.
3. Staff must be able to use that result to contact requesters.

Impact:

- This is not a retroactive booking-deletion rule. The Phase 2 source says already-approved bookings must be identified so staff can contact requesters; it does not say the system must automatically cancel, reject, or modify them.
- Affected requirements: P2-BR-11, P2-BR-12, P2-BR-13, P2-BR-25.
- This is a maintenance escalation contact/reporting need, not the same conflict type as two simultaneous approvals.

## 9. Reporting, Data-Volume, Tuning, and Normalization Obligations

Reports:

| Report obligation | P2 ID | Affected concepts |
|---|---|---|
| Total approved booking hours of each space for a given semester | P2-BR-22 | Space, booking request, booking status, semester definition [proposed — not stated in source] |
| Number of approved bookings by weekday and hour for a given semester | P2-BR-23 | Booking request, booking status, requested/approved time period, semester definition [proposed — not stated in source] |
| Available spaces satisfying capacity, required facility list, and requested period | P2-BR-24 | Space, facility, booking overlap, out-of-service maintenance overlap, current space availability rules |
| Approved bookings affected by escalation to out-of-service | P2-BR-25 | Maintenance record, impact-level change, approved booking overlap, requester contact need |

Data-volume and evidence obligations:

- Generated data must span at least three academic years and contain at least 100,000 booking records; the source permits increasing to 500,000 records if necessary to show indexing effects (P2-BR-33).
- Generated data must include maintenance, cancellations, no-shows, and advisory acknowledgements (P2-BR-33).
- Query testing must be large enough to observe before/after indexing differences (P2-BR-28).
- Tuning evidence must compare execution plans and execution times before and after indexing (P2-BR-35).
- AGENTS.md additionally requires captured actual-plan and `STATISTICS IO/TIME` evidence before and after indexing on the same dataset and parameters.

Index-analysis scope:

- Phase 2 Section 1.3 asks for suitable indexes for the booking conflict check, room finder, and one additional reporting query.
- Phase 2 Section 2 asks for two reporting queries, other than room finder, for detailed indexing and performance analysis.
- AGENTS.md follows the stricter artifact rule: tune the booking conflict check, room finder, and two reporting queries other than room finder. This artifact records the source tension rather than silently deleting it.

Normalization obligation:

- Updated design must identify functional dependencies and ensure all relations satisfy at least Third Normal Form, or document decomposition/proof steps (P2-BR-36).

## 10. Downstream Artifact Impact Matrix (`09`-`16`)

| Artifact | Required downstream impact | Driving P2 IDs |
|---|---|---|
| `09-updated-erd-and-logical-design-G03.md` | Update conceptual/logical design for maintenance impact levels, advisory acknowledgement, instant/staff approval implications, affected-booking lookup support, FDs, and 3NF proof. | P2-BR-02 through P2-BR-13, P2-BR-16 through P2-BR-21, P2-BR-24 through P2-BR-25, P2-BR-30, P2-BR-36 |
| `10-schema-migration-G03.sql` | Implement additive, data-preserving changes on top of Phase 1; preserve existing data or document migration approach. | P2-BR-01, P2-BR-02 through P2-BR-13, P2-BR-16 through P2-BR-21, P2-BR-31 |
| `11-concurrency-design-G03.md` | Design a reviewed concurrency approach that covers instant approval, staff approval, and the shared approved-booking non-overlap invariant. | P2-BR-18 through P2-BR-21, P2-BR-32 |
| `12-concurrency-implementation-G03.sql` | Implement the chosen concurrency solution after artifact 11; all approval paths must use the reviewed protocol required by AGENTS.md. | P2-BR-18 through P2-BR-21, P2-BR-32 |
| `13-concurrency-tests-G03/` | Provide repeatable two-session evidence for the races and their prevention. | P2-BR-18 through P2-BR-21, P2-BR-32 |
| `14-data-generator-G03/` | Generate deterministic large data across at least three academic years with at least 100,000 booking records plus required event types. | P2-BR-28, P2-BR-33 |
| `16-analytical-queries-G03.sql` | Implement all four analytical reports. Group 03 uses `.sql` although the source lists `.sq`. | P2-BR-22 through P2-BR-26, P2-BR-34, P2-BR-39 |
| `15-index-tuning-report-G03.md` | Tune conflict check, room finder, and two reporting queries other than room finder; compare before/after evidence on the same data and parameters. | P2-BR-27, P2-BR-28, P2-BR-34, P2-BR-35 |

## 11. Assumptions

- Assumption: The `P2-BR-*` labels are analytical identifiers [proposed — not stated in source] created solely for traceability.
- Assumption: "System/service behavior" is an analytical actor [proposed — not stated in source] for automatic approval because the source states automatic approval but does not name the acting user or audit actor.
- Assumption: "Staff for requester contact" is an analytical actor [proposed — not stated in source] because the source requires staff to contact requesters after escalation but does not specify which staff role performs the contact.
- Assumption: Example request, maintenance, and space labels used in concurrency schedules, such as R1 and M1, are scenario identifiers [proposed — not stated in source] and are not design identifiers.
- Assumption: "Semester definition" in reporting is a required analytical concept [proposed — not stated in source] because reports are scoped to a given semester, but the source does not define semester dates, academic calendar storage, or how semester boundaries are supplied.
- Assumption: Advisory acknowledgement may require more detail than a single unspecified flag [proposed — not stated in source]; the source only says the requester was informed and acknowledgement is stored with the booking.
- Assumption carried from Phase 1: The source word "closed" maps to the listed status "temporarily closed."
- Assumption carried from Phase 1: "Manager" in approval is treated as the facility manager role.
- Assumption carried from Phase 1: The booking status values include pending, approved, rejected, cancelled, checked in, completed, and no-show.

## 12. Open Questions Carried Forward

Phase 1 open questions still relevant:

- Question: How, if at all, should the stored usage policy be enforced against booking requests? Phase 2 makes this blocking for instant approval (P2-BR-16).
- Question: Which listed account roles are included in generic "Staff" viewing permissions?
- Question: Which prior booking status, business event, and actor set a booking request to cancelled? Phase 2 data generation must include cancellations (P2-BR-33).
- Question: Which prior booking status, business event, and actor set a booking request to no-show? Phase 2 data generation must include no-shows (P2-BR-33).
- Question: What are the allowed maintenance status values and their transitions? Phase 2 adds active/open maintenance and impact-level changes (P2-BR-09 through P2-BR-11).
- Question: Which role is allowed to report a maintenance issue?
- Question: Who assigns the assigned staff member on a maintenance record, and at what point in the workflow is assignment required?
- Question: Does creating or opening a maintenance record automatically change the related space status to under maintenance, or is the space status updated independently? Phase 2 narrows the rule by impact level but does not resolve status synchronization.
- Question: Should Layer-A-only requester eligibility and special-equipment checks become explicit system requirements?
- Question: Should expected participants be constrained to space capacity? Phase 2 room finder uses required capacity, but the source still does not state a booking-submission capacity rejection rule.
- Question: Must every approved or rejected booking have exactly one approval decision record?
- Question: Should booking status have stable machine-readable values in addition to display labels?

New Phase 2 open questions:

- Question: Which space types are "selected space types" for instant approval? Affects P2-BR-16 and artifacts 09 through 13.
- Question: What does it mean for a request to "satisfy the usage policy"? The source does not define an executable predicate. Affects P2-BR-16 and artifacts 09 through 13.
- Question: Does instant approval require the same approval audit facts as staff approval, or a different automatic-decision record? Affects P2-BR-16, P2-BR-17, and artifacts 09 through 12.
- Question: What exactly counts as an "active" advisory or "still open" maintenance record? The source uses both phrases but does not map them to Phase 1 maintenance statuses. Affects P2-BR-07, P2-BR-09, P2-BR-11, and P2-BR-12.
- Question: Are out-of-service and advisory the complete set of impact levels, or only the two values currently required by the source? Affects P2-BR-02.
- Question: When a maintenance impact level is downgraded, is any requester notification required? The source only states contact support for advisory-to-out-of-service escalation. Affects P2-BR-11 through P2-BR-13.
- Question: What interval endpoint convention defines "overlap" for bookings and maintenance periods? Requested intervals remain unspecified at endpoints until an explicit convention is accepted. Affects P2-BR-04, P2-BR-12, P2-BR-19, P2-BR-24, and P2-BR-25.
- Question: For analytical reports, do checked-in and completed bookings count as "approved bookings", or only records whose current status is approved? Affects P2-BR-22, P2-BR-23, and P2-BR-25.
- Question: How is a "given semester" defined or supplied for reports and generated data? Affects P2-BR-22, P2-BR-23, and P2-BR-33.
- Question: For required facility list matching, must a space contain every requested facility, at least one requested facility, or support quantities/working condition? Affects P2-BR-24.
- Question: For affected-booking contact after escalation, must the system store contact attempts or outcomes, or only support finding affected bookings? The source only requires finding so staff can contact requesters. Affects P2-BR-13 and P2-BR-25.
- Question: Phase 2 Section 1.3 says tune one additional reporting query, while Section 2 and AGENTS.md require two reporting queries other than room finder. Group 03 should follow AGENTS.md unless the instructor clarifies otherwise. Affects P2-BR-27, P2-BR-34, and P2-BR-35.
