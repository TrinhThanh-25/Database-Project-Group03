# Database Design Agent Project — Phase 2

Group 03 extends its Phase 1 Microsoft SQL Server database and AI-agent pipeline to support maintenance impact levels, advisory acknowledgements, safe concurrent approval, large-scale sample data, analytical reports, and index tuning.

Phase 2 builds on the Phase 1 artifacts; it does not replace them.

## 1. Phase 2 scope

The repository covers the following work:

1. Analyse the changes from the Phase 1 business rules.
2. Update the ERD, relational design, functional dependencies, and 3NF validation.
3. Migrate the existing Phase 1 database without dropping existing data.
4. Prevent overlapping approved bookings under concurrent instant and staff approval.
5. Demonstrate the concurrency conflict and its prevention with repeatable two-session tests.
6. Generate at least 100,000 realistic bookings across at least three academic years.
7. Implement all four required analytical reports.
8. Compare selected queries before and after indexing on the same dataset and parameters.

The Phase 2 source requirement is preserved in [`req/phase-2-business-requirement.md`](req/phase-2-business-requirement.md).

## 2. Technology

- DBMS: Microsoft SQL Server
- SQL dialect: T-SQL
- Agent runner: OpenCode
- ERD notation: Mermaid `erDiagram`

The SQL scripts can be executed with SQL Server Management Studio, Azure Data Studio, or another SQL Server client that supports separate query sessions.

## 3. Repository structure

```text
.
├── .opencode/
│   ├── agent/                         # Phase 1 and Phase 2 stage owners
│   ├── commands/                      # Phase 1 slash commands
│   ├── evaluation/                    # Phase 1 evaluation rubrics
│   ├── templates/                     # Phase 1 artifact templates
│   └── skills/db-design-pipeline/
│       └── SKILL.md                   # Pipeline routing and execution guidance
├── req/
│   ├── business-requirement.md
│   └── phase-2-business-requirement.md
├── outputs/                           # Numbered Phase 1 and Phase 2 deliverables
├── AGENT.md                           # Assignment-facing agent summary
├── AGENTS.md                          # Canonical project workflow and routing rules
├── Database_Phase1_Report.pdf
└── README.md
```

Do not commit API keys, access tokens, private credentials, `node_modules/`, or temporary execution files.

## 4. Agent workflow

Each stage has one owner in `.opencode/agent/`. A stage reads its declared upstream artifact as its primary input and writes only its owned output. `AGENTS.md` contains the canonical routing rules.

### Phase 1 baseline

| Stage | Owner | Output |
|---:|---|---|
| 1 | Business Analyst | `outputs/01-business-req-analysis-G03.md` |
| 2 | Conceptual Database Designer | `outputs/02-erd-design-G03.md` |
| 3 | Logical Database Designer | `outputs/03-logical-design-G03.md` |
| 4 | Database Design Reviewer | `outputs/04-design-validation-G03.md` |
| 5 | Database Definition Implementation Engineer | `outputs/05-db-definition-G03.sql` |
| 6 | Sample Data Preparer | `outputs/06-sample-data-G03.sql` |
| 7 | SQL Query Designer | `outputs/07-query-design-G03.sql` |

The existing Phase 1 slash commands remain available in `.opencode/commands/`, including `/design-db` for the Phase 1 pipeline.

### Phase 2 extension

| Artifact | Owner | Output |
|---:|---|---|
| 08 | Requirement Change Analyst | `outputs/08-requirement-change-analysis-G03.md` |
| 09 | Phase 2 Database Design Updater | `outputs/09-updated-erd-and-logical-design-G03.md` |
| 10 | Schema Migration Engineer | `outputs/10-schema-migration-G03.sql` |
| 11 | Database Concurrency Architect | `outputs/11-concurrency-design-G03.md` |
| 12 | Database Concurrency Implementation Engineer | `outputs/12-concurrency-implementation-G03.sql` |
| 13 | Database Concurrency Test Engineer | `outputs/13-concurrency-tests-G03/` |
| 14 | Large-scale Data Generation Engineer | `outputs/14-data-generator-G03/` |
| 16 | Analytical Query Designer | `outputs/16-analytical-queries-G03.sql` |
| 15 | Database Performance Tuning Engineer | `outputs/15-index-tuning-report-G03.md` |

The assignment numbers the tuning report as artifact 15 and the analytical queries as artifact 16. Because tuning requires executable queries, the execution order is `08 → 09 → 10 → 11 → 12 → 13 → 14 → 16 → 15`; the filenames retain the assigned numbers.

Phase 2 does not define additional slash commands. In OpenCode, request the relevant owner-agent by stage and require it to read the previous stage's output before updating its artifact.

## 5. Running the database artifacts

Use a disposable SQL Server database for the full demonstration.

### 5.1. Establish the Phase 1 baseline

Run in order:

```text
outputs/05-db-definition-G03.sql
outputs/06-sample-data-G03.sql
```

### 5.2. Apply the Phase 2 implementation

Run in order:

```text
outputs/10-schema-migration-G03.sql
outputs/12-concurrency-implementation-G03.sql
```

The migration is additive and data-preserving. It must not reuse the destructive Phase 1 drop-and-recreate block.

### 5.3. Run the two-session concurrency demonstration

Open two independent SQL Server query windows and follow:

```text
outputs/13-concurrency-tests-G03/README.md
```

The folder contains setup, unsafe demonstration, safe demonstration, verification, cleanup, and captured result notes. The safe case demonstrates that after Session A commits, Session B rechecks under synchronization, detects the overlap, and returns conflict error `52103`.

### 5.4. Generate and validate the large dataset

Follow the exact order in:

```text
outputs/14-data-generator-G03/README.md
```

The generator creates deterministic data spanning three academic years, including at least 100,000 bookings, maintenance records, cancellations, no-shows, approval history, usage lifecycle data, and advisory acknowledgements. Run `05-validate-generated-data.sql` after generation.

### 5.5. Run reports and index analysis

Use:

```text
outputs/16-analytical-queries-G03.sql
outputs/15-index-tuning-report-G03.md
```

Artifact 16 implements all four required reports. Artifact 15 documents the reproducible before/after protocol for the booking conflict check, room finder, and two selected reporting queries. Performance comparisons must use the same database state and parameters and capture actual execution plans plus `STATISTICS IO/TIME` evidence.

## 6. Phase 2 deliverables

```text
outputs/08-requirement-change-analysis-G03.md
outputs/09-updated-erd-and-logical-design-G03.md
outputs/10-schema-migration-G03.sql
outputs/11-concurrency-design-G03.md
outputs/12-concurrency-implementation-G03.sql
outputs/13-concurrency-tests-G03/
outputs/14-data-generator-G03/
outputs/15-index-tuning-report-G03.md
outputs/16-analytical-queries-G03.sql
```

The source requirement spells artifact 16 with the `.sq` extension. Group 03 uses `.sql` because the artifact is an executable Microsoft SQL Server script; the discrepancy is recorded in the preserved requirement.

The assignment also requires `G03_Report_P2.pdf`, containing group contributions, models used, agent improvements, concurrency design and test results, index-tuning evidence, functional dependencies, and 3NF proof or decomposition.

## 7. Approved demo conventions

The artifacts consistently use these project decisions:

- Times stored in the project are interpreted as Vietnam local time (`Asia/Ho_Chi_Minh`, UTC+07:00).
- The existing `usage_policy` remains unchanged.
- Demo auto-approval compares the requester's guest count with the permitted occupancy.
- `System` represents an automated approval actor.
- An advisory is active when the maintenance level is `advisory` and the latest record status is `Reported` or `In progress`; “maintenance is still open” has the same meaning.
- Approved occupancy conflicts consider bookings with status `approved` or `checked_in` whose time intervals overlap.
- All approval paths use the shared space-then-booking lock order.

These conventions are intentionally limited to the agreed demo scope rather than presented as production policy.

## 8. OpenCode setup

Install OpenCode using its official documentation, open this repository, and select an LLM provider and model:

```bash
cd path/to/Database-Project-Group03
opencode
```

Inside OpenCode, use `/connect` to configure a provider and `/models` to select a model. Never store provider credentials in the repository.

To control token usage, update only the requested stage instead of regenerating the whole pipeline. Review every generated artifact and preserve traceability, assumptions, and unresolved open questions.

## 9. Academic responsibility

AI tools support the design process, but Group 03 remains responsible for understanding and validating the delivered work. Group members must be able to explain:

- how the agent pipeline was configured and improved;
- why the Phase 2 schema and migration preserve the Phase 1 design;
- how the concurrency protocol prevents overlapping approvals;
- how the generated data represents valid booking lifecycles;
- how the analytical queries and selected indexes work; and
- how the relations satisfy Third Normal Form.
