# Phase 2 Detailed Implementation Plan — Group 03

## 1. Goal and delivery policy

Extend the existing SQL Server Phase 1 design in place, preserve existing data, demonstrate concurrency safety, generate at least three academic years and 100,000 bookings, implement all four required reports, and provide repeatable before/after index evidence.

Phase 1 files `01` through `07` remain historical baselines. Phase 2 work reads them but writes only the new `08` through `16` artifacts, the Phase 2 requirement source, and agent/skill documentation.

## 2. Baseline findings

- Phase 1 implements 14 tables. The relevant core tables are `SPACE`, `SPACE_FACILITY`, `BOOKING_REQUEST`, `BOOKING_STATUS`, `APPROVAL_DECISION`, and `MAINTENANCE_RECORD`.
- `BOOKING_REQUEST` stores space, status, requested half-open interval, purpose, and participant count, but no submission timestamp, semester, approval route, or advisory acknowledgement.
- `MAINTENANCE_RECORD` stores one maintenance interval/status but no impact level and no impact-change history.
- No `SEMESTER` or academic-period relation exists, although Phase 2 reports take a semester parameter.
- The approved-overlap rule is documented but not executable. A check-then-write race is therefore possible.
- The Phase 1 room finder handles capacity and time but not an arbitrary required facility set and not advisory/out-of-service intervals.
- The current sample dataset is intentionally small and cannot support meaningful query-plan comparison.
- `.opencode/skills/db-design-pipeline/SKILL.md` contains accidental shell-wrapper text and Phase 1-only paths; it must be corrected.

## 3. Proposed design decisions requiring validation

Every item below is `[proposed — not stated in source]` until accepted in artifact 08/09 and recorded as an assumption.

- Add `SEMESTER` so reporting periods have stored boundaries and stable identifiers.
- Add `MAINTENANCE_IMPACT_LEVEL` with controlled values `Advisory` and `Out-of-service`.
- Add `MAINTENANCE_IMPACT_HISTORY` to preserve each escalation/downgrade and support evidence of when an escalation occurred.
- Add `BOOKING_ADVISORY_ACKNOWLEDGEMENT` as a junction/event table between a booking and every advisory maintenance record active at booking time. A row records acknowledgement time; this avoids a single Boolean that cannot prove which advisories were shown.
- Add `SPACE_TYPE_POLICY` (or normalize `SPACE.space_type`) only if needed to configure selected types for automatic approval. Do not assume the usage-policy predicate until requirement analysis resolves how policy satisfaction is represented.
- Record an approval route/source on the approval event or booking only if analysis confirms the fact is required for audit; concurrency safety itself does not require storing it.
- Treat requested intervals as half-open `[start, end)` so adjacent bookings do not conflict. This is `[proposed]` because the source says overlap but does not define endpoint semantics.
- Use stored procedures as the only supported paths that can create an immediately approved booking or approve a pending booking. Both procedures acquire the same transaction-scoped application lock keyed by `space_id`, recheck conflicts inside the transaction, then write the result atomically. `UPDLOCK, HOLDLOCK` on an indexed range is a fallback/defence-in-depth option, but the lock-key design is easier to demonstrate reliably on an initially empty range.

## 4. Ordered work breakdown

### Stage A — Agent and requirement preparation

1. Preserve the supplied Phase 2 text in `req/phase-2-business-requirement.md`.
2. Correct and extend `AGENTS.md`, add the assignment-compatible `AGENT.md`, and rewrite the pipeline `SKILL.md` for artifacts 08–16.
3. Add explicit routes for change analysis, updated design/3NF, migration, concurrency, generator, tuning, and analytics.
4. Define self-check and review gates for every Phase 2 stage without creating repository log files.

Exit criteria: all required paths are declared consistently; `.sql` extension discrepancy for artifact 16 is documented.

### Stage B — Requirement change analysis (`08`)

1. Assign stable Phase 2 requirement IDs (`P2-BR-01...`) without changing the source meaning.
2. Produce an affected-element matrix for Phase 1 entities, relationships, rules, and scripts.
3. Model the two race scenarios: simultaneous instant approvals and staff approval racing another approval/submission.
4. Separate literal requirements from proposals and open questions.
5. Resolve or explicitly defer semester boundaries, active/open maintenance semantics, endpoint overlap semantics, acknowledgement timing, usage-policy evaluation, and contact workflow scope.

Exit criteria: every later design element traces to a Phase 2 requirement or a visibly tagged proposal.

### Stage C — Updated ERD, relational schema, FDs and 3NF (`09`)

1. Read artifact `08` as primary input and Phase 1 logical design as baseline.
2. Publish a Mermaid `erDiagram` showing unchanged and new relations.
3. Define columns, keys, nullability, FKs, constraints, and referential actions with source-strength evidence.
4. List functional dependencies relation by relation.
5. Prove 1NF, 2NF, and 3NF or document decompositions needed to reach 3NF.
6. Define invariants that cannot be expressed by ordinary constraints and route them to migration/concurrency scripts.

Exit criteria: no transitive/partial dependency remains undocumented; acknowledgement supports multiple simultaneous advisories; maintenance history supports escalation lookup.

### Stage D — Data-preserving migration (`10`)

1. Use guarded, additive `CREATE TABLE`/`ALTER TABLE` operations; do not run the destructive Phase 1 drop block.
2. Seed controlled impact levels using stable codes, not assumed identity values.
3. Backfill existing maintenance records under a documented mapping. Because Phase 1 treated all active maintenance as blocking, the conservative candidate is `Out-of-service`; this remains an open migration decision until formally accepted.
4. Add constraints only after backfill and validation queries pass.
5. Wrap migration in transactions where SQL Server permits and add pre/post row-count and orphan checks.
6. Provide rollback guidance for newly added objects/columns without claiming automatic rollback for already-consumed application writes.

Exit criteria: existing Phase 1 rows remain present; migration is rerunnable or fails safely with clear guards.

### Stage E — Concurrency design and implementation (`11`, `12`, `13/`)

1. Document schedules showing the lost invariant under naive `SELECT` then `UPDATE/INSERT`.
2. Implement a shared lock protocol for instant booking and staff approval.
3. In each procedure: begin transaction, acquire per-space lock, resolve approved status by stable name/code, check out-of-service overlap, check approved-booking overlap, write decision/booking, commit; rollback and throw on failure.
4. Make all state changes and advisory acknowledgement inserts atomic with booking submission.
5. Add two-session scripts: setup, Session A, Session B, verification, cleanup. Include an unsafe demonstration and safe prevention.
6. Test boundary-touching intervals, multi-row operations, rollback/retry, instant-vs-staff races, and two different spaces proceeding independently.

Exit criteria: repeated two-session tests never commit overlapping approved bookings for one space; results are captured in `13-concurrency-tests-G03/README.md`.

### Stage F — Large data generation (`14/`)

1. Generate deterministic set-based data with a configurable seed/scale and at least six semesters across three academic years.
2. Target at least 100,000 bookings; keep the option for 500,000.
3. Produce realistic status/time distributions and include cancellations, no-shows, maintenance overlaps, advisory acknowledgements, and both approval routes when represented.
4. Ensure generated approved bookings obey the overlap invariant; generate conflicting requests only in non-approved statuses.
5. Add validation queries for row counts, date span, FK integrity, overlap violations, and acknowledgement coverage.

Exit criteria: one command/script builds the dataset repeatably and validation returns zero integrity violations.

### Stage G — Analytical queries (`16`)

Implement parameterized SQL Server procedures or clearly parameterized query templates for:

1. approved booking hours per space for a semester;
2. approved booking count by weekday and hour for a semester (define how multi-hour bookings contribute);
3. available spaces meeting capacity plus all facilities within a requested interval;
4. approved bookings affected by an escalation to out-of-service.

Candidate detailed reporting queries for tuning: report 1 (hours per space) and report 2 (weekday/hour). These satisfy the requirement to select two reports other than room finder.

Exit criteria: all reports use implemented columns only, define status and interval semantics, and have correctness fixtures.

### Stage H — Index tuning and evidence (`15`)

1. Establish a no-custom-index baseline and warm/cold-cache measurement protocol; record SQL Server version and dataset size.
2. Capture actual execution plans, `SET STATISTICS IO, TIME ON`, logical reads, CPU, elapsed time, row estimates, and repeated-run median.
3. Tune four workloads: conflict check, room finder, approved hours, weekday/hour report.
4. Candidate indexes to test rather than assume final:
   - filtered/indexed access path for approved bookings by `(space_id, requested_start_time, requested_end_time)` where feasible with a stable status representation;
   - `SPACE(capacity, space_id)` plus facility junction access for room finder;
   - semester/time/status covering access for approved-hour aggregation;
   - time/status access for weekday/hour aggregation.
5. Compare write/storage overhead and remove redundant candidates.

Exit criteria: report contains reproducible before/after scripts and measured evidence, not only estimated claims.

### Stage I — Final integration review

1. Run migration on a Phase 1-populated database.
2. Run concurrency tests, generate large data, execute reports, and capture tuning results.
3. Verify file naming, traceability, assumptions/open questions, 3NF evidence, row-count, overlap, and acknowledgement coverage.
4. Prepare content inputs for `G03_Report_P2.pdf`, including member/query ownership and actual LLM model information supplied by the group.

## 5. Required artifacts and current status

The assigned filenames number tuning as 15 and queries as 16. The dependency-safe execution order is `14 → 16 → 15` because measured tuning requires the final query text; artifact filenames are not renumbered.

| Artifact | Owner agent | Purpose | Initial status |
|---|---|---|---|
| `req/phase-2-business-requirement.md` | Pipeline input | Verbatim source | Created |
| `outputs/08-requirement-change-analysis-G03.md` | `requirement-change-analyst.md` | Change/race analysis | Scaffolded; analysis pending |
| `outputs/09-updated-erd-and-logical-design-G03.md` | `phase2-database-design-updater.md` | ERD, schema, FDs, 3NF | Scaffolded; depends on 08 |
| `outputs/10-schema-migration-G03.sql` | `schema-migration-engineer.md` | Additive migration | Scaffolded; depends on 09 |
| `outputs/11-concurrency-design-G03.md` | `database-concurrency-architect.md` | Conflict schedules/solution | Scaffolded; depends on 10 |
| `outputs/12-concurrency-implementation-G03.sql` | `database-concurrency-implementation-engineer.md` | Safe procedures | Scaffolded; depends on 10/11 |
| `outputs/13-concurrency-tests-G03/` | `database-concurrency-test-engineer.md` | Two-session demonstrations | Scaffolded; depends on 12 |
| `outputs/14-data-generator-G03/` | `large-scale-data-generation-engineer.md` | Large deterministic dataset | Scaffolded; depends on 10/12/13 |
| `outputs/15-index-tuning-report-G03.md` | `database-performance-tuning-engineer.md` | Measured tuning results | Scaffolded; depends on 12/14/16 and SQL Server execution |
| `outputs/16-analytical-queries-G03.sql` | `analytical-query-designer.md` | Four required reports | Scaffolded; depends on 09/10/14 |

## 6. Open questions that block final implementation choices

- What defines a semester and are its dates inclusive/exclusive?
- What exact maintenance statuses count as “still open” and “active” at a booking time?
- Does acknowledgement occur at initial request submission only, or again when a pending request is later approved and advisories have changed?
- Must acknowledgements preserve the advisory text/impact snapshot shown to the requester, or is the FK plus timestamp sufficient?
- How is “satisfies the usage policy” evaluated, and how are selected auto-approval space types configured?
- Does “approved bookings” in reports include later `Checked in`/`Completed` bookings whose current status is no longer literally `Approved`?
- For weekday/hour reporting, does a two-hour booking count once at its starting hour or once in every occupied hour bucket?
- When maintenance is escalated, is the affected-booking result computed live or persisted as a contact worklist/contact event?

These questions must remain visible until stakeholder confirmation; later stages may use tagged, reversible assumptions for the demo.

## 7. Hướng dẫn triển khai thực tế

### 7.1. Chuẩn bị môi trường

Phần triển khai và đo hiệu năng cần một SQL Server riêng cho bài demo. Không chạy trực tiếp trên dữ liệu quan trọng.

Yêu cầu tối thiểu:

- Microsoft SQL Server 2019 trở lên hoặc SQL Server Developer Edition.
- SQL Server Management Studio, Azure Data Studio hoặc `sqlcmd`.
- Một database thử nghiệm, ví dụ `CampusSpaceBookingG03`.
- Quyền tạo bảng, khóa ngoại, index, procedure và chạy `sp_getapplock`.
- Bật Actual Execution Plan khi đo index; bật `SET STATISTICS IO, TIME ON` trong session đo.

Trước khi bắt đầu, sao lưu database Phase 1 hoặc tạo lại database thử nghiệm bằng:

1. `outputs/05-db-definition-G03.sql`;
2. `outputs/06-sample-data-G03.sql`.

Không chạy các file Phase 2 SQL còn dòng `Status: SCAFFOLD ONLY` hoặc `THROW 5100x`. Các guard này chỉ được xóa sau khi nội dung tương ứng hoàn chỉnh và đã review.

### 7.2. Quy trình làm việc với Git

Mỗi artifact nên được hoàn thành và review trong một commit riêng để dễ truy vết:

1. Kiểm tra trạng thái bằng `git status --short`.
2. Chỉ sửa artifact của stage hiện tại và các tài liệu agent thực sự liên quan.
3. Chạy kiểm tra cú pháp/Markdown/SQL phù hợp.
4. Xem `git diff --check` và `git diff -- <file>` trước khi commit.
5. Không đưa file chứa mật khẩu, connection string thật, execution-plan quá lớn hoặc database backup vào Git.

Gợi ý commit theo thứ tự:

- `docs: analyze phase 2 requirement changes`
- `design: update phase 2 erd logical schema and 3nf`
- `db: add data-preserving phase 2 migration`
- `db: document and implement booking concurrency control`
- `test: add two-session concurrency demonstrations`
- `data: add deterministic large data generator`
- `query: implement phase 2 analytical reports`
- `perf: document index tuning evidence`

### 7.3. Cách hoàn thành artifact 08

Input bắt buộc:

- `req/phase-2-business-requirement.md` là nguồn Phase 2.
- `outputs/01-business-req-analysis-G03.md` là baseline nghiệp vụ Phase 1.
- `outputs/03-logical-design-G03.md` và `outputs/05-db-definition-G03.sql` dùng để xác định phần bị ảnh hưởng.

Thực hiện:

1. Gán mã `P2-BR-01`, `P2-BR-02`, ... cho từng yêu cầu độc lập.
2. Với mỗi yêu cầu, ghi rõ nguồn theo tên mục 1.1, 1.2 hoặc 1.3; không trích theo số dòng.
3. Lập bảng `Requirement → Phase 1 element → Change type → Required artifact`.
4. Mô tả ít nhất hai interleaving concurrency bằng các bước T1/T2.
5. Tách ba nhóm: yêu cầu nguồn, giả định đề xuất, câu hỏi mở.
6. Không thiết kế cột hoặc constraint ở stage này ngoài việc nêu nhu cầu dữ liệu.

Kiểm tra hoàn thành:

- Mỗi rule maintenance, auto-approval, concurrent approval và report đều có mã.
- Có phân tích race cho instant-vs-instant và instant-vs-staff/staff-vs-staff.
- Không biến đề xuất `SEMESTER` hoặc bảng history thành sự thật nguồn.
- Mọi câu hỏi từ mục 6 của kế hoạch được giải quyết hoặc carry forward.

### 7.4. Cách hoàn thành artifact 09

Chỉ bắt đầu sau khi artifact 08 không còn trạng thái scaffold.

Thực hiện:

1. Sao chép đầy đủ 14 quan hệ Phase 1 vào baseline logical schema; đánh dấu rõ quan hệ không đổi.
2. Thêm các quan hệ mới chỉ khi trace được về `P2-BR-*` hoặc giả định đã ghi rõ.
3. Với từng bảng, liệt kê cột, SQL Server type, nullability, PK, FK, UNIQUE, CHECK và referential actions.
4. Dùng Mermaid `erDiagram`; mỗi FK là một relationship line riêng.
5. Lập bảng enforcement: constraint thường, procedure/transaction, query hoặc open question.
6. Ghi functional dependency cho từng quan hệ theo dạng `determinant → dependent attributes`.
7. Kiểm tra 3NF: determinant phải là superkey hoặc dependent phải là prime attribute; nếu không đạt, phân rã và giải thích lossless/dependency preservation.

Các quyết định cần chốt trước migration:

- Stored semester hay truyền trực tiếp khoảng ngày.
- Cấu trúc impact-level hiện tại và lịch sử thay đổi.
- Acknowledgement liên kết với từng maintenance record hay lưu snapshot.
- Cách nhận biết auto-approval policy.
- Stable status code để procedure/index không phụ thuộc identity ID.
- Định nghĩa interval `[start, end)`.

Kiểm tra hoàn thành:

- ERD, schema text và relationship mapping đồng nhất.
- Có thể xác định chính xác migration DDL từ tài liệu, không cần đoán.
- Tất cả relation đạt ít nhất 3NF và có bằng chứng.
- Rule chống overlap được phân loại là transaction/concurrency logic, không phải row-level CHECK.

### 7.5. Cách hoàn thành và chạy migration 10

Thực hiện migration trên bản sao database Phase 1:

1. Thay guard `THROW 51000` bằng preflight thực tế sau khi artifact 09 được duyệt.
2. Kiểm tra các bảng Phase 1 tồn tại và lưu row count trước migration.
3. Tạo bảng lookup/child mới trước; thêm cột nullable trước khi backfill.
4. Seed lookup bằng code/name có `IF NOT EXISTS` hoặc `MERGE` an toàn; không hard-code identity ID.
5. Backfill maintenance Phase 1 theo migration assumption đã được duyệt.
6. Chạy truy vấn tìm NULL/orphan/duplicate sau backfill.
7. Chỉ sau đó mới thêm `NOT NULL`, FK, UNIQUE hoặc CHECK.
8. Commit transaction; trong `CATCH`, rollback và `THROW` lại lỗi gốc.
9. Chạy lại script để kiểm tra idempotency hoặc thông báo “already migrated” an toàn.

Validation tối thiểu:

```sql
SELECT COUNT(*) FROM dbo.BOOKING_REQUEST;
SELECT COUNT(*) FROM dbo.MAINTENANCE_RECORD;
DBCC CHECKCONSTRAINTS WITH ALL_CONSTRAINTS;
```

So sánh row count trước/sau và kiểm tra không có bản ghi Phase 1 bị mất.

### 7.6. Cách thiết kế concurrency 11

Mô tả race theo timeline, ví dụ:

| Bước | Session A | Session B |
|---|---|---|
| 1 | Kiểm tra khoảng trống: không thấy conflict | |
| 2 | | Kiểm tra cùng khoảng: không thấy conflict |
| 3 | Ghi Approved | |
| 4 | | Ghi Approved |
| 5 | Commit | Commit, invariant bị vi phạm |

Protocol đề xuất cần bảo đảm:

1. Mọi đường dẫn tạo trạng thái Approved gọi procedure được kiểm soát.
2. Procedure bắt đầu transaction và lấy lock theo `space_id`.
3. Sau khi có lock mới kiểm tra out-of-service và booking overlap.
4. Ghi booking/status/decision/acknowledgement trong cùng transaction.
5. Commit giải phóng transaction-owned application lock.
6. Lỗi timeout/deadlock/conflict phải rollback và trả mã lỗi rõ ràng.

Không chỉ dựa vào application code: quyền `INSERT/UPDATE` trực tiếp lên bảng liên quan cần bị hạn chế trong mô hình triển khai được đề xuất.

### 7.7. Cách triển khai concurrency 12

Procedure nên dùng mẫu kiểm soát lỗi:

```sql
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    -- acquire per-space lock
    -- recheck maintenance and approved overlaps
    -- perform atomic writes
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
```

Điểm review bắt buộc:

- `sp_getapplock` dùng `LockOwner = 'Transaction'` và resource key chứa database/schema/space ID.
- Kiểm tra overlap dùng `existing_start < requested_end AND existing_end > requested_start`.
- Instant approval và staff approval dùng cùng lock namespace và cùng thứ tự kiểm tra.
- Không dùng `NOLOCK` trong integrity check.
- Không giữ transaction mở trong khi chờ tương tác người dùng.
- Resolve status bằng stable code/name một lần trong transaction; không đoán identity ID.

### 7.8. Cách chạy concurrency tests 13

Mở hai cửa sổ query cùng kết nối vào một database test.

Unsafe test:

1. Chạy `00-setup.sql`.
2. Chạy Session A đến điểm chờ được đánh dấu.
3. Chạy Session B đến điểm chờ.
4. Cho A rồi B tiếp tục.
5. Chạy verify; kỳ vọng thấy hai approved rows overlap trong workflow không bảo vệ.

Safe test:

1. Reset fixture.
2. Chạy safe Session A và giữ transaction theo hướng dẫn.
3. Chạy safe Session B; B phải chờ hoặc nhận conflict sau khi A commit.
4. Chạy verify; kỳ vọng tối đa một approved booking trong cặp conflict.
5. Lặp lại ít nhất 10 lần và ghi actual results vào README.

Không đưa `WAITFOR` dài vào procedure production; chỉ dùng delay có kiểm soát trong script demo để tái hiện interleaving.

### 7.9. Cách tạo dữ liệu lớn 14

Ưu tiên set-based SQL thay vì 100.000 lệnh `INSERT` riêng lẻ:

1. Tạo tally/numbers source.
2. Seed sáu semester thuộc ba academic years.
3. Sinh user, space, facility và maintenance trước.
4. Sinh booking theo slot cố định cho các status Approved/Checked in/Completed để không overlap.
5. Sinh pending/rejected/cancelled/no-show với phân phối thực tế; các status không approved có thể overlap.
6. Tạo advisory acknowledgement chỉ khi advisory active tại booking time.
7. Cho phép cấu hình `@BookingTarget = 100000` hoặc `500000`.
8. Dùng cùng seed và cùng cấu hình cho đo before/after index.

Generator phải kết thúc bằng kiểm tra:

- tổng bookings đạt target;
- dữ liệu phủ ít nhất ba academic years;
- có maintenance, cancellation, no-show và acknowledgement;
- không có approved overlap;
- không có approved booking overlap out-of-service maintenance;
- không có orphan FK.

### 7.10. Cách hoàn thành analytical queries 16

Mỗi query/procedure phải có:

- business question;
- input parameters và validation;
- interval/status semantics;
- executable SQL;
- expected columns;
- correctness fixture hoặc test case.

Room finder nhận danh sách facility bằng table-valued parameter hoặc temp/table input được tài liệu hóa. Điều kiện “đủ mọi facility yêu cầu” nên dùng relational division, ví dụ `NOT EXISTS` một facility yêu cầu chưa tồn tại trong `SPACE_FACILITY`; không dùng chuỗi comma-separated để so khớp tên.

Với booking hour report, xử lý booking cắt qua biên semester bằng cách clamp interval về biên semester trước khi `DATEDIFF`. Với weekday/hour report, ghi rõ một booking nhiều giờ được tính theo start hour hay từng occupied-hour bucket trước khi viết SQL.

### 7.11. Cách đo và viết tuning report 15

Thứ tự thực hiện là `14 → 16 → 15`:

1. Load cùng một dataset cố định.
2. Gỡ/chưa tạo bốn candidate indexes; lưu index inventory baseline.
3. Bật Actual Plan và `SET STATISTICS IO, TIME ON`.
4. Chạy mỗi workload ít nhất năm lần với cùng parameter; ghi median của các lần warm-cache.
5. Lưu actual plan và chỉ số baseline.
6. Tạo từng candidate index riêng, cập nhật statistics nếu cần.
7. Chạy lại cùng query/parameter/số lần.
8. So sánh scan/seek, logical reads, CPU, elapsed time, memory grant, sort/hash spill và estimate accuracy.
9. Kiểm tra tác động ghi và kích thước index.
10. Giữ index chỉ khi lợi ích đo được lớn hơn chi phí và không trùng index khác.

Không dùng `DBCC DROPCLEANBUFFERS` trên môi trường dùng chung. Nếu cần cold-cache test, chỉ thực hiện trên SQL Server test riêng và ghi rõ phương pháp.

### 7.12. Definition of Done

Phase 2 chỉ hoàn thành khi:

- Artifacts 08–16 không còn nhãn scaffold hoặc guard `THROW 5100x`.
- Migration chạy thành công trên database Phase 1 có dữ liệu và không làm mất row.
- ERD/schema/migration đồng nhất và mọi relation có bằng chứng 3NF.
- Hai-session test chứng minh race và giải pháp phòng ngừa.
- Dataset có tối thiểu 100.000 bookings trong ít nhất ba academic years.
- Bốn analytical reports chạy đúng trên schema migrated.
- Conflict check, room finder và hai report khác có actual-plan/IO/time trước và sau index.
- Assumptions và open questions xuất hiện nhất quán ở mọi stage liên quan.
- `git diff --check` sạch và không có credential/database backup được commit.
