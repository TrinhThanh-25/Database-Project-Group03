# Functional Dependencies and 3NF Analysis - Group 03

## 1. Scope and Sources

This separate analysis file lists the functional dependencies (FDs) for the current Group 03 schema and explains why the complete schema satisfies Third Normal Form (3NF).

Primary source used:

- `outputs/09-updated-erd-and-logical-design-G03.md`, especially Sections 7, 10, and 11.

Implementation cross-check sources:

- `outputs/05-db-definition-G03.sql`
- `outputs/10-schema-migration-G03.sql`

Schema scope:

- All 14 Phase 1 tables are included.
- All 6 Phase 2 added tables are included.
- Modified Phase 2 tables are analyzed in their updated form: `BOOKING_STATUS`, `APPROVAL_DECISION`, and `MAINTENANCE_RECORD`.

## 2. Normalization Criteria Used

1NF criteria:

- Every relation has atomic attributes.
- Repeating groups are decomposed into separate relations.
- Multi-valued relationships are stored in association/history tables, not as lists inside parent rows.

2NF criteria:

- Every non-prime attribute must depend on the whole of every candidate key.
- Relations with only single-attribute candidate keys automatically avoid partial dependency.
- Relations with composite candidate keys are checked separately.

3NF criteria:

- For every non-trivial FD `X -> A`, either `X` is a superkey, or `A` is a prime attribute.
- Candidate keys include surrogate primary keys and declared alternate keys / unique business keys.
- Foreign keys do not create transitive dependencies inside the same relation because descriptive data for the referenced entity remains in the referenced table.

Terminology:

- Prime attribute: an attribute that is part of at least one candidate key.
- Non-prime attribute: an attribute that is not part of any candidate key.
- Superkey: a set of attributes that functionally determines every attribute in the relation.

## 3. Functional Dependencies by Table

### 3.1 `ROLE`

Attributes:

- `role_id`
- `role_name`

Candidate keys:

- `{role_id}`
- `{role_name}`

Functional dependencies:

- `role_id -> role_name`
- `role_name -> role_id`

3NF explanation:

Both determinants are candidate keys, so every non-trivial FD has a superkey on the left side. `ROLE` satisfies 3NF.

### 3.2 `ACCOUNT_STATUS`

Attributes:

- `account_status_id`
- `status_name`

Candidate keys:

- `{account_status_id}`
- `{status_name}`

Functional dependencies:

- `account_status_id -> status_name`
- `status_name -> account_status_id`

3NF explanation:

Both determinants are candidate keys. There is no non-key attribute determining another non-key attribute. `ACCOUNT_STATUS` satisfies 3NF.

### 3.3 `DEPARTMENT`

Attributes:

- `department_id`
- `department_name`
- `head_user_account_id`

Candidate keys:

- `{department_id}`
- `{department_name}`

Functional dependencies:

- `department_id -> department_name, head_user_account_id`
- `department_name -> department_id, head_user_account_id`

Prime attributes:

- `department_id`
- `department_name`

3NF explanation:

Each determinant is a candidate key. `head_user_account_id` depends on the department identity, not on another non-key department attribute. User details for the head are not copied into this table; they remain in `USER_ACCOUNT`. `DEPARTMENT` satisfies 3NF.

### 3.4 `USER_ACCOUNT`

Attributes:

- `user_account_id`
- `user_id`
- `full_name`
- `email`
- `phone_number`
- `department_id`
- `role_id`
- `account_status_id`

Candidate keys:

- `{user_account_id}`
- `{user_id}`
- `{email}`

Functional dependencies:

- `user_account_id -> user_id, full_name, email, phone_number, department_id, role_id, account_status_id`
- `user_id -> user_account_id, full_name, email, phone_number, department_id, role_id, account_status_id`
- `email -> user_account_id, user_id, full_name, phone_number, department_id, role_id, account_status_id`

Prime attributes:

- `user_account_id`
- `user_id`
- `email`

3NF explanation:

All listed non-trivial FDs are determined by candidate keys. Department names, role names, and account-status names are not stored in `USER_ACCOUNT`; only their foreign-key identifiers are stored. This avoids transitive dependencies such as `department_id -> department_name` inside `USER_ACCOUNT`. `USER_ACCOUNT` satisfies 3NF.

### 3.5 `SPACE_STATUS`

Attributes:

- `space_status_id`
- `status_name`

Candidate keys:

- `{space_status_id}`
- `{status_name}`

Functional dependencies:

- `space_status_id -> status_name`
- `status_name -> space_status_id`

3NF explanation:

Both determinants are candidate keys. `SPACE_STATUS` satisfies 3NF.

### 3.6 `SPACE`

Attributes:

- `space_id`
- `unique_space_code`
- `space_name`
- `space_type`
- `building`
- `floor`
- `room_number`
- `capacity`
- `usage_policy`
- `space_status_id`

Candidate keys:

- `{space_id}`
- `{unique_space_code}`

Functional dependencies:

- `space_id -> unique_space_code, space_name, space_type, building, floor, room_number, capacity, usage_policy, space_status_id`
- `unique_space_code -> space_id, space_name, space_type, building, floor, room_number, capacity, usage_policy, space_status_id`

Prime attributes:

- `space_id`
- `unique_space_code`

3NF explanation:

The surrogate key and unique business code each determine the full space row. Status display data is decomposed into `SPACE_STATUS`, and facilities are decomposed into `FACILITY` plus `SPACE_FACILITY` instead of being repeated in `SPACE`. `SPACE` satisfies 3NF.

### 3.7 `FACILITY`

Attributes:

- `facility_id`
- `facility_name`

Candidate keys:

- `{facility_id}`

Functional dependencies:

- `facility_id -> facility_name`

Prime attributes:

- `facility_id`

3NF explanation:

The only supported determinant is the primary key. `facility_name` is not unique in the Phase 1 design, so no additional FD is claimed. `FACILITY` satisfies 3NF.

### 3.8 `SPACE_FACILITY`

Attributes:

- `space_facility_id`
- `space_id`
- `facility_id`

Candidate keys:

- `{space_facility_id}`
- `{space_id, facility_id}`

Functional dependencies:

- `space_facility_id -> space_id, facility_id`
- `space_id, facility_id -> space_facility_id`

Prime attributes:

- `space_facility_id`
- `space_id`
- `facility_id`

3NF explanation:

This is an association relation. The composite pair `{space_id, facility_id}` prevents duplicate associations, and there are no descriptive non-key attributes in the table. Because all attributes are prime, the relation satisfies 3NF.

### 3.9 `BOOKING_STATUS`

Attributes:

- `booking_status_id`
- `status_code`
- `status_name`

Candidate keys:

- `{booking_status_id}`
- `{status_code}`
- `{status_name}`

Functional dependencies:

- `booking_status_id -> status_code, status_name`
- `status_code -> booking_status_id, status_name`
- `status_name -> booking_status_id, status_code`

3NF explanation:

Every determinant is a candidate key. `BOOKING_STATUS` satisfies 3NF.

### 3.10 `BOOKING_REQUEST`

Attributes:

- `booking_request_id`
- `requester_user_account_id`
- `space_id`
- `booking_status_id`
- `requested_start_time`
- `requested_end_time`
- `purpose_of_use`
- `expected_number_of_participants`

Candidate keys:

- `{booking_request_id}`

Functional dependencies:

- `booking_request_id -> requester_user_account_id, space_id, booking_status_id, requested_start_time, requested_end_time, purpose_of_use, expected_number_of_participants`

Prime attributes:

- `booking_request_id`

3NF explanation:

All booking facts depend on the booking request identity. Requester details, space details, and booking-status details are referenced through FKs and not duplicated in the booking row. There is no non-key determinant such as `space_id -> capacity` inside `BOOKING_REQUEST`; that dependency belongs to `SPACE`. `BOOKING_REQUEST` satisfies 3NF.

### 3.11 `APPROVAL_METHOD`

Attributes:

- `approval_method_id`
- `method_code`
- `method_name`

Candidate keys:

- `{approval_method_id}`
- `{method_code}`
- `{method_name}`

Functional dependencies:

- `approval_method_id -> method_code, method_name`
- `method_code -> approval_method_id, method_name`
- `method_name -> approval_method_id, method_code`

3NF explanation:

Every determinant is a candidate key. `APPROVAL_METHOD` satisfies 3NF.

### 3.12 `APPROVAL_DECISION`

Attributes:

- `approval_decision_id`
- `booking_request_id`
- `decided_by_user_account_id`
- `decision_outcome_booking_status_id`
- `decision_method_id`
- `decision_time`
- `decision_note`
- `rejection_reason`

Candidate keys:

- `{approval_decision_id}`

Functional dependencies:

- `approval_decision_id -> booking_request_id, decided_by_user_account_id, decision_outcome_booking_status_id, decision_method_id, decision_time, decision_note, rejection_reason`

Prime attributes:

- `approval_decision_id`

3NF explanation:

Each decision row represents one decision event. The decision event identity determines the booking, actor, outcome, method, time, and notes. Booking details, user details, status descriptions, and method descriptions are decomposed into their own tables. `booking_request_id` is deliberately not unique, so no FD from `booking_request_id` to decision details is claimed. `APPROVAL_DECISION` satisfies 3NF.

### 3.13 `USAGE_SESSION`

Attributes:

- `usage_session_id`
- `booking_request_id`
- `checked_in_by_user_account_id`
- `completed_by_user_account_id`
- `actual_start_time`
- `initial_condition_of_space`
- `actual_end_time`
- `final_condition_of_space`
- `usage_notes`

Candidate keys:

- `{usage_session_id}`
- `{booking_request_id}`

Functional dependencies:

- `usage_session_id -> booking_request_id, checked_in_by_user_account_id, completed_by_user_account_id, actual_start_time, initial_condition_of_space, actual_end_time, final_condition_of_space, usage_notes`
- `booking_request_id -> usage_session_id, checked_in_by_user_account_id, completed_by_user_account_id, actual_start_time, initial_condition_of_space, actual_end_time, final_condition_of_space, usage_notes`

Prime attributes:

- `usage_session_id`
- `booking_request_id`

3NF explanation:

The schema allows at most one usage session per booking through `UQ_USAGE_SESSION_booking_request_id`, so both `usage_session_id` and `booking_request_id` are candidate keys. All non-prime usage facts depend on either candidate key. User details are referenced, not copied. `USAGE_SESSION` satisfies 3NF.

### 3.14 `MAINTENANCE_STATUS`

Attributes:

- `maintenance_status_id`
- `status_name`

Candidate keys:

- `{maintenance_status_id}`
- `{status_name}`

Functional dependencies:

- `maintenance_status_id -> status_name`
- `status_name -> maintenance_status_id`

3NF explanation:

Both determinants are candidate keys. `MAINTENANCE_STATUS` satisfies 3NF.

### 3.15 `MAINTENANCE_IMPACT_LEVEL`

Attributes:

- `impact_level_id`
- `impact_level_code`
- `impact_level_name`

Candidate keys:

- `{impact_level_id}`
- `{impact_level_code}`
- `{impact_level_name}`

Functional dependencies:

- `impact_level_id -> impact_level_code, impact_level_name`
- `impact_level_code -> impact_level_id, impact_level_name`
- `impact_level_name -> impact_level_id, impact_level_code`

3NF explanation:

Every determinant is a candidate key. `MAINTENANCE_IMPACT_LEVEL` satisfies 3NF.

### 3.16 `MAINTENANCE_RECORD`

Attributes:

- `maintenance_record_id`
- `space_id`
- `reported_by_user_account_id`
- `assigned_to_user_account_id`
- `maintenance_status_id`
- `impact_level_id`
- `problem_description`
- `start_time`
- `completion_time`
- `result_note`

Candidate keys:

- `{maintenance_record_id}`

Functional dependencies:

- `maintenance_record_id -> space_id, reported_by_user_account_id, assigned_to_user_account_id, maintenance_status_id, impact_level_id, problem_description, start_time, completion_time, result_note`

Prime attributes:

- `maintenance_record_id`

3NF explanation:

The maintenance record identity determines all facts about the maintenance item. Space details, user details, maintenance-status descriptions, and impact-level descriptions are referenced through FKs and not duplicated. Impact history is decomposed into `MAINTENANCE_IMPACT_EVENT` rather than repeated inside the current maintenance row. `MAINTENANCE_RECORD` satisfies 3NF.

### 3.17 `MAINTENANCE_IMPACT_EVENT`

Attributes:

- `maintenance_impact_event_id`
- `maintenance_record_id`
- `old_impact_level_id`
- `new_impact_level_id`
- `changed_by_user_account_id`
- `changed_at`
- `change_note`

Candidate keys:

- `{maintenance_impact_event_id}`

Functional dependencies:

- `maintenance_impact_event_id -> maintenance_record_id, old_impact_level_id, new_impact_level_id, changed_by_user_account_id, changed_at, change_note`

Prime attributes:

- `maintenance_impact_event_id`

3NF explanation:

Each row is one impact-change event. The event identity determines the maintenance record, old/new impact levels, actor, timestamp, and note. Impact-level names and user details are decomposed. No FD such as `{maintenance_record_id, changed_at} -> ...` is claimed because the schema does not enforce that pair as unique. `MAINTENANCE_IMPACT_EVENT` satisfies 3NF.

### 3.18 `BOOKING_ADVISORY_ACKNOWLEDGEMENT`

Attributes:

- `advisory_acknowledgement_id`
- `booking_request_id`
- `maintenance_record_id`
- `acknowledged_impact_level_id`
- `acknowledged_at`
- `advisory_message_snapshot`

Candidate keys:

- `{advisory_acknowledgement_id}`
- `{booking_request_id, maintenance_record_id}`

Functional dependencies:

- `advisory_acknowledgement_id -> booking_request_id, maintenance_record_id, acknowledged_impact_level_id, acknowledged_at, advisory_message_snapshot`
- `booking_request_id, maintenance_record_id -> advisory_acknowledgement_id, acknowledged_impact_level_id, acknowledged_at, advisory_message_snapshot`

Prime attributes:

- `advisory_acknowledgement_id`
- `booking_request_id`
- `maintenance_record_id`

3NF explanation:

The composite candidate key `{booking_request_id, maintenance_record_id}` represents exactly one acknowledgement of one disclosed advisory for one booking. `acknowledged_at`, `acknowledged_impact_level_id`, and `advisory_message_snapshot` depend on the whole booking/advisory pair, not on only the booking or only the maintenance record. Booking details and maintenance details are referenced rather than duplicated. The optional message snapshot is an audit fact of the acknowledgement event, not a dependency on a separate non-key attribute. `BOOKING_ADVISORY_ACKNOWLEDGEMENT` satisfies 3NF.

### 3.19 `INSTANT_APPROVAL_SPACE_TYPE`

Attributes:

- `instant_approval_space_type_id`
- `space_type`
- `is_active`
- `configured_at`
- `configured_by_user_account_id`
- `configuration_note`

Candidate keys:

- `{instant_approval_space_type_id}`
- `{space_type}`

Functional dependencies:

- `instant_approval_space_type_id -> space_type, is_active, configured_at, configured_by_user_account_id, configuration_note`
- `space_type -> instant_approval_space_type_id, is_active, configured_at, configured_by_user_account_id, configuration_note`

Prime attributes:

- `instant_approval_space_type_id`
- `space_type`

3NF explanation:

The table records configuration by selected space-type value. Both the surrogate key and the unique `space_type` value determine the configuration facts. The configuring user's details remain in `USER_ACCOUNT`. `INSTANT_APPROVAL_SPACE_TYPE` satisfies 3NF.

### 3.20 `ACADEMIC_SEMESTER`

Attributes:

- `semester_id`
- `semester_code`
- `academic_year_label`
- `semester_name`
- `semester_start_date`
- `semester_end_date`

Candidate keys:

- `{semester_id}`
- `{semester_code}`
- `{academic_year_label, semester_name}`

Functional dependencies:

- `semester_id -> semester_code, academic_year_label, semester_name, semester_start_date, semester_end_date`
- `semester_code -> semester_id, academic_year_label, semester_name, semester_start_date, semester_end_date`
- `academic_year_label, semester_name -> semester_id, semester_code, semester_start_date, semester_end_date`

Prime attributes:

- `semester_id`
- `semester_code`
- `academic_year_label`
- `semester_name`

3NF explanation:

All supported determinants are candidate keys. The date attributes depend on the semester identity or unique academic-year/semester-name pair. Under this design, no FD is claimed from `academic_year_label` alone or from `semester_name` alone to dates, because the same semester name can recur across years and the same academic year can contain multiple semesters. `ACADEMIC_SEMESTER` satisfies 3NF.

## 4. Whole-Schema 1NF Explanation

The schema satisfies 1NF because all attributes are scalar values:

- A user has one row in `USER_ACCOUNT`; role, department, and account status are stored through FKs.
- A space's facilities are not stored as a comma-separated list. They are decomposed into `FACILITY` and `SPACE_FACILITY`.
- Booking decisions are stored as rows in `APPROVAL_DECISION`, not as repeated decision columns in `BOOKING_REQUEST`.
- Usage lifecycle facts are stored in `USAGE_SESSION`.
- Maintenance impact history is stored in `MAINTENANCE_IMPACT_EVENT`, not as repeated impact columns in `MAINTENANCE_RECORD`.
- Advisory acknowledgements are stored one row per booking/advisory pair in `BOOKING_ADVISORY_ACKNOWLEDGEMENT`.
- Semester reporting windows are stored in `ACADEMIC_SEMESTER`, not embedded as repeated columns on bookings.

## 5. Whole-Schema 2NF Explanation

Most relations have only single-attribute candidate keys, so partial dependency is impossible for those relations.

The relations with composite candidate keys are:

| Relation | Composite candidate key | 2NF reason |
|---|---|---|
| `SPACE_FACILITY` | `{space_id, facility_id}` | The table has no non-prime descriptive attributes. The row represents the whole space/facility pair. |
| `BOOKING_ADVISORY_ACKNOWLEDGEMENT` | `{booking_request_id, maintenance_record_id}` | Acknowledgement facts depend on the whole disclosed booking/advisory pair, not just one side. |
| `ACADEMIC_SEMESTER` | `{academic_year_label, semester_name}` | Semester dates and code depend on the full year/name pair, not on year alone or semester name alone. |

Therefore, no relation has a non-prime attribute depending on only part of a composite candidate key. The full schema satisfies 2NF.

## 6. Whole-Schema 3NF Explanation

The schema satisfies 3NF because every non-trivial FD listed above has a candidate key as its determinant. The only apparent dependencies from FK values to descriptive values are intentionally kept outside the referencing table:

| Referencing table | Referenced dependency kept out of the table |
|---|---|
| `USER_ACCOUNT` | `department_id -> department_name`, `role_id -> role_name`, `account_status_id -> status_name` |
| `SPACE` | `space_status_id -> status_name` |
| `BOOKING_REQUEST` | `requester_user_account_id -> user details`, `space_id -> space details`, `booking_status_id -> status_code/status_name` |
| `APPROVAL_DECISION` | `booking_request_id -> booking facts`, `decided_by_user_account_id -> user details`, `decision_outcome_booking_status_id -> status facts`, `decision_method_id -> method facts` |
| `USAGE_SESSION` | `booking_request_id -> booking facts`, `checked_in_by_user_account_id -> user details`, `completed_by_user_account_id -> user details` |
| `MAINTENANCE_RECORD` | `space_id -> space details`, `reported_by_user_account_id -> user details`, `assigned_to_user_account_id -> user details`, `maintenance_status_id -> status_name`, `impact_level_id -> impact-level code/name` |
| `MAINTENANCE_IMPACT_EVENT` | `maintenance_record_id -> maintenance facts`, `old_impact_level_id -> old impact details`, `new_impact_level_id -> new impact details`, `changed_by_user_account_id -> user details` |
| `BOOKING_ADVISORY_ACKNOWLEDGEMENT` | `booking_request_id -> booking facts`, `maintenance_record_id -> maintenance facts`, `acknowledged_impact_level_id -> impact-level details` |
| `INSTANT_APPROVAL_SPACE_TYPE` | `configured_by_user_account_id -> user details` |

Because those descriptive dependencies are decomposed into separate referenced relations, they do not become transitive dependencies inside the referencing relations.

No relation requires further decomposition to reach 3NF.

## 7. Assumptions and Open Questions

Assumptions carried from the updated logical design:

- Surrogate `INT IDENTITY(1,1)` primary keys are used consistently.
- Natural/business identifiers that are declared unique are treated as candidate keys.
- `BOOKING_STATUS.status_code`, `APPROVAL_METHOD`, `MAINTENANCE_IMPACT_LEVEL`, `MAINTENANCE_IMPACT_EVENT`, `BOOKING_ADVISORY_ACKNOWLEDGEMENT`, `INSTANT_APPROVAL_SPACE_TYPE`, and `ACADEMIC_SEMESTER` are Phase 2 additions or proposed structures recorded in artifact 09.
- `FACILITY.facility_name` is not treated as a candidate key because the Phase 1 schema did not constrain it as unique.
- No extra FDs are claimed from nullable or unconstrained attributes unless the schema declares the determinant as a key.

Open questions carried forward:

- Which space types are selected for instant approval?
- What executable predicate determines that a request satisfies `SPACE.usage_policy`?
- Which maintenance status values mean active or open?
- Do checked-in and completed bookings count as approved bookings for reports?
- What are the authoritative semester calendars?
- Does opening maintenance automatically change `SPACE.space_status_id`?

## 8. Conclusion

The complete updated schema satisfies 3NF. Every relation is in 1NF, no relation has a partial dependency that violates 2NF, and every non-trivial FD in the schema has a candidate key determinant or is decomposed into a separate referenced relation. No additional decomposition is required for 3NF.
