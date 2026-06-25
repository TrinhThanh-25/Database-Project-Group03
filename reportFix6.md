# Report Fix 6 - Review `outputs/06-sample-data-G03.sql`

Thoi diem kiem tra: 2026-06-25 20:48 +07  
Pham vi kiem tra: `outputs/06-sample-data-G03.sql`, doi chieu voi `outputs/05-db-definition-G03.sql`, `outputs/03-logical-design-G03.md`, `outputs/04-design-validation-G03.md`, va agent `.opencode/agent/sample-data-preparer.md`.

## 1. Ket luan nhanh

Khong phat hien loi chac chan lam `outputs/06-sample-data-G03.sql` fail neu chay sau `outputs/05-db-definition-G03.sql` tren database sach.

File sample data hien tai dap ung cac rang buoc chinh:

- Tat ca FK deu tham chieu ban ghi cha da insert truoc.
- Gia tri `role`, `current_status`, `booking_type`, `status` khop voi CHECK constraint trong DDL.
- Cac booking khong tham chieu space co trang thai `Under maintenance`, `Temporarily closed`, hoac `Retired`.
- Cac booking `Approved` khong overlap theo cung `unique_space_code`.
- Decision maker trong `APPROVAL_DECISION` la `Facility Staff` hoac `Facility Manager`.
- Booking `Rejected` co `rejection_reason`.
- `USAGE_SESSION` dung nguoi check-in/complete co role `Facility Staff`, va session completed co `actual_end_time` + `final_condition_of_the_space`.

## 2. Loi / rui ro can sua de output chuan xac hon

### F6-01 - Thieu metadata traceability, assumptions, open questions trong output SQL

Muc do: Medium  
File lien quan: `outputs/06-sample-data-G03.sql`, `.opencode/agent/sample-data-preparer.md`

Mo ta:

- `AGENTS.md` yeu cau moi stage phai ghi ro assumptions va open questions, dong thoi carry forward unresolved questions.
- `outputs/06-sample-data-G03.sql` co phan `Notes`, nhung chua co section ro rang cho:
  - assumptions carried forward,
  - open questions carried forward,
  - traceability tu requirement / table / constraint sang nhom sample data.

De xuat sua:

- Cap nhat `.opencode/agent/sample-data-preparer.md` de bat buoc output SQL co comment block dau file gom:
  - `Assumptions Carried Forward`
  - `Open Questions Carried Forward`
  - `Sample Coverage / Traceability`
- Cap nhat `outputs/06-sample-data-G03.sql` de them cac comment block nay, khong can thay doi du lieu insert.

### F6-02 - Agent yeu cau "Departments" nhung schema khong co bang `DEPARTMENT`

Muc do: Low  
File lien quan: `.opencode/agent/sample-data-preparer.md`, `outputs/06-sample-data-G03.sql`

Mo ta:

- Agent ghi sample data phai include `Departments`.
- DDL khong co bang `DEPARTMENT`; department chi la cot `USER_ACCOUNT.department`.
- Output hien tai co note dung: department values duoc dai dien qua `USER_ACCOUNT.department`.
- Tuy nhien instruction agent chua noi ro cach xu ly khi schema khong co bang department, nen cac lan chay sau co the bi agent tu tao bang/insert sai vao bang khong ton tai.

De xuat sua:

- Trong `.opencode/agent/sample-data-preparer.md`, sua yeu cau thanh:
  - "Include department values only through implemented schema. If no `DEPARTMENT` table exists, do not create one; populate `USER_ACCOUNT.department` and document the assumption."
- Giu note hien tai trong `outputs/06-sample-data-G03.sql`.

### F6-03 - Template va rubric sample data dang rong

Muc do: Medium  
File lien quan: `.opencode/templates/sample-data-template.md`, `.opencode/evaluation/sample-data-rubric.md`

Mo ta:

- Hai file nay doc ra khong co noi dung.
- Do do agent sample-data-preparer khong co format/rubric cu the de tu kiem tra output.
- Viec nay lam chat luong output phu thuoc vao agent prompt hon la checklist on dinh cua project.

De xuat sua:

- Them template cho `.opencode/templates/sample-data-template.md` gom:
  - header metadata,
  - input analyzed,
  - assumptions/open questions,
  - insert-order sections,
  - coverage checklist comment,
  - validation notes.
- Them rubric cho `.opencode/evaluation/sample-data-rubric.md` gom cac tieu chi:
  - FK/order validity,
  - CHECK/NOT NULL compliance,
  - trigger compliance,
  - required exceptional cases,
  - no unsupported tables/columns,
  - traceability/assumptions/open questions,
  - SQL Server syntax.

### F6-04 - Output khong co bang checklist de chung minh da cover cac exceptional cases

Muc do: Low  
File lien quan: `outputs/06-sample-data-G03.sql`, `.opencode/agent/sample-data-preparer.md`

Mo ta:

- Du lieu hien tai co du cac case: rejected, cancelled, no-show, completed, under maintenance, temporarily closed, retired.
- Nhung output chi viet mo ta ngan, khong co checklist ro rang mapping tung case voi booking/space/record ID.
- Khi reviewer hoac agent buoc 7 doc lai, phai tu suy luan tu cac insert.

De xuat sua:

- Them comment block vao dau/cuoi `outputs/06-sample-data-G03.sql`:
  - rejected booking: `booking_id = 2004`, decision `3003`
  - cancelled booking: `booking_id = 2005`
  - no-show booking: `booking_id = 2008`
  - completed booking/session: `booking_id = 2006`, session `4001`
  - checked-in booking/session: `booking_id = 2007`, session `4002`
  - under maintenance space: `CS-L202`
  - temporarily closed space: `CS-M201`
  - retired space: `CS-OLD1`
- Cap nhat `.opencode/agent/sample-data-preparer.md` de bat buoc ghi coverage checklist nay.

### F6-05 - Chua co buoc yeu cau agent kiem tra trigger logic mot cach rieng

Muc do: Medium  
File lien quan: `.opencode/agent/sample-data-preparer.md`

Mo ta:

- DDL co trigger quan trong:
  - `TRG_BOOKING_REQUEST_VALIDATE`
  - `TRG_APPROVAL_DECISION_VALIDATE`
  - `TRG_USAGE_SESSION_VALIDATE`
- Agent hien tai noi chung "verify constraints", nhung chua yeu cau liet ke trigger nao da kiem tra va rule nao du lieu sample phai tranh.
- Output lan nay tinh co dung, nhung agent co the bo sot trigger trong lan sau.

De xuat sua:

- Them vao `.opencode/agent/sample-data-preparer.md` mot muc bat buoc:
  - Read the full DDL including triggers and views, not only `CREATE TABLE`.
  - For each trigger, list affected table, forbidden pattern, and how sample data avoids or covers it.
  - Do not create negative test rows in `outputs/06-sample-data-G03.sql` if they would break the load script.

### F6-06 - Khong idempotent neu chay sample data nhieu lan tren cung database

Muc do: Low  
File lien quan: `outputs/06-sample-data-G03.sql`, `.opencode/agent/sample-data-preparer.md`

Mo ta:

- File chi co `INSERT`, khong co `DELETE`, `MERGE`, hoac guard `IF NOT EXISTS`.
- Neu chay lai tren database da co sample data, se bi trung primary key.
- Day khong phai loi neu workflow luon chay `outputs/05-db-definition-G03.sql` truoc vi DDL co drop/create tables.

De xuat sua:

- Neu project muon script sample data co the chay doc lap lap lai, cap nhat agent de sinh `DELETE` theo dependency order hoac `IF NOT EXISTS`.
- Neu workflow yeu cau database sach, them comment dau file: "Run only after `outputs/05-db-definition-G03.sql` recreates the schema."

## 3. Cac file nen sua cho Opencode hoat dong dung hon

1. `.opencode/agent/sample-data-preparer.md`
   - Lam ro khong duoc tao bang/cot ngoai DDL.
   - Lam ro xu ly department khi khong co bang `DEPARTMENT`.
   - Bat buoc doc full DDL gom triggers.
   - Bat buoc ghi assumptions, open questions, traceability va coverage checklist.

2. `.opencode/templates/sample-data-template.md`
   - Hien dang rong, can them template chuan cho output SQL va comment sections.

3. `.opencode/evaluation/sample-data-rubric.md`
   - Hien dang rong, can them rubric tu kiem tra sample data.

4. `outputs/06-sample-data-G03.sql`
   - Khong can sua cac gia tri INSERT de pass constraint.
   - Nen them metadata/comment sections: assumptions, open questions, trigger compliance, coverage checklist, va ghi ro script can chay sau DDL tren database sach.

## 4. De xuat noi dung sua nhanh cho agent

Them vao `.opencode/agent/sample-data-preparer.md`:

```md
Additional validation requirements:
- Read the entire `outputs/05-db-definition-G03.sql`, including triggers and views.
- Do not create or reference tables/columns that are not implemented in the DDL.
- If the requirement mentions departments but the DDL has no `DEPARTMENT` table, represent departments only through implemented columns such as `USER_ACCOUNT.department` and document this as an assumption.
- Before writing SQL, build a checklist for every PK, FK, CHECK, UNIQUE, NOT NULL constraint and every trigger.
- The output SQL must include comment sections for Assumptions Carried Forward, Open Questions Carried Forward, Trigger Compliance, and Sample Coverage.
- Exceptional cases must be traceable to specific inserted IDs.
- The sample load script should either be documented as requiring a clean schema after DDL, or be made idempotent by explicit project choice.
```

## 5. Final assessment

`outputs/06-sample-data-G03.sql` hien tai co the xem la dung ve mat constraint/runtime trong workflow hien tai. Cac diem can fix chu yeu nam o chat luong instruction/template/rubric va kha nang traceability cua output, khong phai o cac dong INSERT cu the.
