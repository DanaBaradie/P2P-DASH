# Mudad: Oracle Fusion Audit Trail Report

## Phase 1: Requirements Analysis and Technical Feasibility

| | |
|---|---|
| Date | 14 October 2026 |
| Status | Draft for review. Phase 2 (final SQL, data model, layout) starts after the decisions in §6. |
| Inputs | `Audit Trail Report Template.xlsx`, `changes.xlsx` (this folder) |
| Companion files | `02_Field_Mapping.xlsx`: all 375 items, with Fusion column, capture source and status<br>`03_Environment_Discovery.sql`: read-only checks to run in Mudad's DEV/TEST pod |

**Evidence labels used in this document**

| Label | Meaning |
|---|---|
| **[Oracle 26D]** | Confirmed in Oracle's published documentation for release 26D (Tables and Views guides, implementation guides, REST API guide). Links in §7. |
| **[Used before]** | Already used by an earlier BI Publisher report in this repository (P2P Dashboard or AP Inventory). |
| **[Community]** | Common practitioner practice, not stated by Oracle. |
| **[Verify]** | Must be confirmed in Mudad's pod with `03_Environment_Discovery.sql` or a validation test before it is relied on. |

---

## 1. Summary

1. **There is no single audit source in Oracle Fusion.** Each module records change history differently. Some keep it natively, some only after auditing is switched on, and some do not record it at all. The report can still have **one layout, one set of parameters and one output** (the Mudad template). Underneath, each area reads from its own source.

2. **Coverage of the 375 items in the Changes file** (368 fields plus 7 add/delete/action events). Details are in `02_Field_Mapping.xlsx`.

   | Capture status | Items | Meaning |
   |---|---|---|
   | Capturable now | 121 | Fusion already keeps the history: PO change orders, asset transactions, receipt applications, bank reconciliations, invoice holds. |
   | Capturable after setup | 108 | Needs **audit policies** switched on: AP invoices, GL journals, asset descriptive fields. History starts on the day auditing is enabled. |
   | Partial | 11 | Only part of the event is recorded, for example attachment additions but not deletions. |
   | Not capturable | 125 | Fusion records no history for these, and they cannot be audited. |
   | To confirm | 10 | Depends on a clarification (§3.6). |

3. **Not auditable in Oracle Fusion, per Oracle's 26D documentation:**
   - Receivables transactions and receipts
   - Bank statements
   - Purchase requisitions
   - Payables payments

   For these areas the report cannot show old and new field values from Fusion. It can show only the native events that exist (receipt applications, reconciliations, attachment additions). §4.5 lists the options.

   **Confirmed in Mudad's pod on 14 October 2026** (check 1, §4.8): none of these areas has an audit table, while all 8 audit tables for Payables, General Ledger and Assets exist.

4. **Auditing is off by default and is not retroactive.** Every day before the Payables, General Ledger and Assets audit policies are switched on is history that can never be recovered. **Recommendation: enable them now in DEV/TEST, and in Production as soon as Mudad approves** (§4.4), even before the report is built.

5. **Purchase orders have full field-level history without any setup.** It comes from the change-order archive tables. The history has change-order granularity: several edits in one change order share one timestamp.

6. **BI Publisher SQL on the audit tables is common practice [Community], but Oracle does not state that it is supported.** Oracle's supported channels are the Audit Reports page, the *Generate Audit Report* process and the audit REST API. Validation test V-01 (§4.6) confirms that the SQL results match the Audit Reports page before the report relies on them.

---

## 2. Source files reviewed

Both files were read completely, including every worksheet, heading, colour coding and comment.

### 2.1 `Audit Trail Report Template.xlsx` (layout authority)

One worksheet, range A1:H5.

| Row | Content | Formatting |
|---|---|---|
| 1 | **Audit Trail Report** (title) | Calibri 20 bold, navy `#1F4E78`, row height 30 |
| 3 | **Product:** label (A3), value cell B3 | Calibri 11 bold, navy |
| 4 | **User:** label (A4), value cell B4 | Calibri 11 bold, navy |
| 5 | 8 column headers | white bold on navy `#1F4E78`, thin borders, row height 20 |

Grid columns in order, with widths: **Date** (28.5), **Transaction ID** (28.5), **Action Performed** (19.8), **Old Value** (14.6), **New Value** (14.8), **Transaction Status** (18.3), **Approval Status** (14.1), **Voucher Number** (15.2).

The template does **not** contain:
- a Username or Product column in the grid (both appear only as header lines)
- a From/To date line
- a logo
- a sub-area column (for example, invoice vs receipt under Receivables)

### 2.2 `changes.xlsx` (fields to audit)

Nine worksheets, one column each. Yellow rows are section headings. Other coloured rows are sub-headings that describe actions, such as *edit or delete line or add new line*.

| Sheet | Items | Content |
|---|---|---|
| PO (*PO-CHANGE ORDER*) | 76 + 3 events | General (15), Additional Information (2), Lines (22), Schedules (33), Distributions (4). Events: add/delete line, add schedule, add/delete distribution. |
| PR | 20 | Line Details (18), Attachment (2) |
| AP Invoice | 78 + 1 event | Header (11), Lines (43), Taxes (1), Manage Installments (17), Discounts (2), Remittance Messages (3), Holds (1). Event: add/delete line. |
| Payment | 3 | Attachment, Payment Type, Payment reference |
| AR Transaction | 35 | Header (11), Invoice Details (24) |
| AR Receipt | 23 | Receipt fields (15), applications (8, including Add / Unapply Application) |
| Bank Statement | 58 + 1 event | Header (14), Lines (6), Fees and Charges (9), Additional Information (9), Transaction Identification (13), Foreign Currency (4), reconciliation actions (3). Event: add/delete/edit line. |
| Assets | 52 + 2 events | Financial details (16), Change Category (2), Transfer (6), Retire (13), Descriptive Details (15). Events: add/remove assignment lines, Reinstate. |
| General Ledger | 23 | Batch (5), Journal (10), Lines (4), actions: Reverse, Delete, Copy, Print (4) |
| **Total** | **375** | |

---

## 3. Requirements analysis

### 3.1 Report layout and column meaning

The report reproduces the template exactly: title, *Product:* and *User:* lines, and the 8 columns in the template's order, fonts, colours and widths. There is one row per captured change.

| Template column | Content | Rule |
|---|---|---|
| Date | When the change was saved | Date **and time** from the change record, not the transaction or accounting date. Shown in Mudad local time, `DD/MM/YYYY HH24:MI:SS`. |
| Transaction ID | Business document number | PO number, requisition number, invoice number, payment number, AR transaction number, receipt number, bank account + statement number, asset number (book), journal batch / journal name. |
| Action Performed | What changed | The field label as written in the Changes file, prefixed with the level where it changed, for example `Line 2 › Schedule 1 › Promised Delivery Date` or `Installment 1 › Due Date`. Events read `Line added`, `Hold placed`, `Application added`, `Unreconciled`, and so on. |
| Old Value | Value before the change | As the user sees it: supplier name rather than ID, account combination rather than CCID. Blank for additions. |
| New Value | Value after the change | Same display rule. Blank for deletions. |
| Transaction Status | Processing status of the document | Module-specific (§3.4). |
| Approval Status | Approval state of the document | Module-specific (§3.4). `Not applicable` where the module has no approval. |
| Voucher Number | Document or accounting sequence | Module-specific (§3.4). Blank where not applicable. |

### 3.2 Parameters

| Parameter | Type | Behaviour |
|---|---|---|
| From Date | Date (time allowed) | Required. Filters the **modification timestamp**: `change_ts >= From Date`. |
| To Date | Date (time allowed) | Required. Filters the **modification timestamp**. With no time entered, the whole day is included: `change_ts < To Date + 1`. |
| Username | Menu of Fusion user names, multi-select | Filters on the user recorded **on the change record**, never on the document's current *Last Updated By*. Uses BI Publisher's built-in **Can select all** with **NULL value passed**, not a hand-made `'All'` row. |
| Product | Menu of the 8 values, multi-select | Same built-in *Can select all* / NULL handling. |

Filter idiom that works with multi-select parameters:

```sql
AND (COALESCE(NULL, :P_PRODUCT) IS NULL OR x.product IN (:P_PRODUCT))
```

`COALESCE(NULL, …)` is used because BI Publisher expands a multi-value parameter into a list, and `:P IS NULL` fails on a list. The earlier reports in this repository use a manual `'All'` LOV row. This report uses the built-in option instead, as the brief requires.

Date filtering applies to the change timestamp only. An invoice created on 1 September whose supplier changed on 10 October appears in any range that includes 10 October.

### 3.3 Product parameter → transaction areas

None of the ten required areas is dropped.

| Product parameter | Transaction areas | Changes sheet(s) |
|---|---|---|
| Purchase Orders | Purchase Orders | PO |
| Purchase Requisitions | Purchase Requisitions | PR |
| Fixed Assets | Fixed Assets | Assets |
| Bank Statements | **Bank Statements** + **Bank Reconciliations** | Bank Statement (reconciliation actions are its rows 61–63) |
| Receivables | **AR Invoices** + **Receipts** | AR Transaction, AR Receipt |
| Payables | AP Invoices | AP Invoice |
| General Ledger | General Ledger | General Ledger |
| Payments | Payables payments | Payment |

Bank Reconciliations has no parameter value of its own. It sits under **Bank Statements** because the Changes file places the reconciliation actions on the Bank Statement sheet.

### 3.4 Status, approval and voucher columns

All columns below are confirmed in Oracle 26D documentation unless marked otherwise.

| Area | Transaction Status | Approval Status | Voucher Number |
|---|---|---|---|
| Purchase Orders | `PO_HEADERS_ALL.DOCUMENT_STATUS` | From `DOCUMENT_STATUS` / `APPROVED_FLAG` | n/a |
| Purchase Requisitions | `POR_REQUISITION_HEADERS_ALL.DOCUMENT_STATUS` | Same | n/a |
| AP Invoices | Validation status from `AP_INVOICES_PKG.GET_APPROVAL_STATUS` [Used before], plus accounted / unaccounted from `AP_INVOICE_DISTRIBUTIONS_ALL.POSTED_FLAG` | `AP_INVOICES_ALL.WFAPPROVAL_STATUS` (invoice approval workflow) | `AP_INVOICES_ALL.DOC_SEQUENCE_VALUE`, which Oracle describes as *"Voucher number (Sequential Numbering)"*. Fallback `VOUCHER_NUM`. See Q4. |
| Payments | `AP_CHECKS_ALL.STATUS_LOOKUP_CODE` | n/a | `AP_CHECKS_ALL.DOC_SEQUENCE_VALUE` |
| AR Invoices | `RA_CUSTOMER_TRX_ALL.COMPLETE_FLAG` (Complete / Incomplete) | n/a | `RA_CUSTOMER_TRX_ALL.DOC_SEQUENCE_VALUE` |
| Receipts | Current `AR_CASH_RECEIPT_HISTORY_ALL.STATUS` (`CURRENT_RECORD_FLAG = 'Y'`) | n/a | `AR_CASH_RECEIPTS_ALL.DOC_SEQUENCE_VALUE` |
| Bank Statements / Reconciliations | `CE_STATEMENT_HEADERS.RECON_STATUS_CODE`; line `RECON_STATUS` | n/a | n/a |
| Fixed Assets | Asset status (in service / retired) from the book | n/a | n/a |
| General Ledger | `GL_JE_BATCHES.STATUS` (Posted / Unposted) | `GL_JE_BATCHES.APPROVAL_STATUS_CODE` | `NVL(GL_JE_HEADERS.POSTING_ACCT_SEQ_VALUE, DOC_SEQUENCE_VALUE)` [Used before] |

Statuses are the document's **current** status when the report runs. The brief allows "current or relevant". Showing the status as it was at each change would only be possible where the status column is itself audited.

### 3.5 Differences between the template, the Changes file and the brief

| # | Difference | Proposed handling |
|---|---|---|
| D1 | The brief lists Username and Product as columns; the template has them only as header lines. | Keep the template. Group by Product, then User, and **repeat the template's header block (Product / User lines + column headers) for each group**. Every row stays attributed to a user without adding columns. With one product and one user selected, this is exactly the template. (Q1) |
| D2 | The brief's column is *Modification Date*; the template's is *Date*. | Keep the template text *Date*. The content is the modification date and time. |
| D3 | The template has no date-range line. | Follow the template (Q2). |
| D4 | The brief names 10 areas; the parameter list has 8 values. | §3.3, nothing dropped. |
| D5 | The Changes file includes **actions and processes**, not only field edits: Split Installment, Place/Release Hold, Add/Unapply Application, Manual/Automatic Reconciliation, Unreconcile, Reinstate, Calculate Depreciation, Close Period, Reverse, Delete, Copy, Print. | Reported as events. Feasibility differs per action (§4.3). |
| D6 | The Changes file includes **add/delete** of lines, schedules, distributions, statement lines, assignment lines and attachments. | Reported as `… added` / `… deleted` events. Deletions need audit history or archives; plain tables keep nothing once a row is deleted. |
| D7 | The PO sheet is titled *PO-CHANGE ORDER*. | PO changes are those made through change orders after approval. This is also exactly what Fusion archives. |

### 3.6 Points that need a decision or confirmation

Items marked ✔ were resolved during the analysis and are shown for confirmation only.

| # | Question | Assumed until answered |
|---|---|---|
| Q1 | Show Username and Product as header groups (template) or as two extra grid columns? | Header groups (D1). |
| Q2 | Show the selected From/To dates on the report? | Not shown. |
| Q3 | PO: is auditing change orders after approval enough? Edits to a draft before its first approval are not recorded anywhere in Fusion. | Yes. |
| Q4 | **Voucher Number**: confirm the definitions in §3.4. The AP Inventory report used the SLA accounting sequence first; Oracle calls `AP_INVOICES_ALL.DOC_SEQUENCE_VALUE` the invoice voucher number. | §3.4. |
| Q5 | Mudad time zone for displaying and filtering change times. The database runs in UTC (check 9, §4.8), so times must be converted. | `Asia/Riyadh` (UTC+3). Please confirm. |
| Q6 | Transaction / Approval Status: current status, or status at the time of the change? | Current. |
| Q7 | PO *Additional Information → Payment Type, Payment Status* are not standard PO fields. Which descriptive flexfield context/segments hold them? | Header DFF; segments to be supplied. |
| Q8 ✔ | AP Invoice rows that were unclear, as interpreted: row 34 *Number* = PO number on the line; row 46 *Region* = Income Tax Region; row 47 *Type* = Income Tax Type; row 54 *Correction Type* = line match/correction type; row 55 *Number* = corrected invoice. | As stated. Please confirm. |
| Q9 | AP Invoice **Company / Natural Account / Cost Center**: segments of the distribution account (shown as the account change), or something else? | Account segments. |
| Q10 | Payments: **Payment Type** is fixed when a payment is created, and **Payment reference** (`IBY_PAYMENTS_ALL.PAYMENT_REFERENCE_NUMBER`) is system-assigned. What change is expected here? Payments are not auditable in any case (§4.3). | Payables payments only. |
| Q11 | AR Transaction **Number / Name / Contact / Site / Address** under Invoice Details: the line-level ship-to customer? | Line ship-to. |
| Q12 | AR Receipt **Bank / Bank Branch / Bank Account**: customer bank or Mudad remittance bank? **Accounting Date** (row 23): the application's or the receipt's? ✔ *Expection Reason* = application **Exception Reason**. | Customer bank; application date. |
| Q13 | Assets **Calculate Depreciation** and **Close Period** are processes, not asset changes. Is "who ran it and when" enough? | Yes, if C13 shows the process history is accessible. |
| Q14 | GL **Print** changes no data and is not recorded by any Fusion audit source. Can it be dropped? | Dropped. |
| Q15 | Business units / ledgers in scope, and who may run the report? (BI Publisher SQL does not apply Fusion data security.) | All Mudad BUs/ledgers; access restricted by catalog permissions. |
| Q16 | Should document **creation** appear as a row, or only later modifications? | Only modifications and the events in the Changes file. |
| Q17 | For areas that cannot be audited (§4.5), show a clearly labelled indicator *"modified after creation: last by X on Y, previous values not recorded"*? | Not shown, unless requested. |
| Q18 | Is old/new history for AR, receipts, bank statements and requisitions mandatory? If yes, it needs the snapshot solution in §4.5 (Option B), which is outside BI Publisher. | Not mandatory; documented as a limitation. |
| Q19 | PO change timestamp: the change-order **submission** time (when the buyer finished editing) or its **approval** time (when it took effect)? | Submission; approval date is shown through Approval Status. |

---

## 4. Technical feasibility

### 4.1 Why "current value vs. last updated" is not used

A transaction row holds only its current values and its last updater. It cannot show what a field contained before, who changed it earlier, or how many times it changed. Every old value in this report therefore comes from a **stored earlier record**: an audit row, an archived revision, or a history row. No old value is inferred from current data.

### 4.2 Change-history mechanisms available in Oracle Fusion

**A. Business-object auditing (Manage Audit Policies)** [Oracle 26D]

- **Configuration.** Setup and Maintenance > Manage Audit Policies: set Audit Level to *Auditing* for the product, then tick the objects and attributes in *Configure Business Object Attributes*. Auditing is disabled by default.
- **Storage.** Each audited table has an audit table named *base table + underscore* (for example `AP_INVOICES_ALL_`). It has the same columns as the base table plus `AUDIT_ACTION_TYPE_` (INSERT/UPDATE/DELETE), `AUDIT_CHANGE_BIT_MAP_` and `AUDIT_IMPERSONATOR_`.
  - The primary key is `LAST_UPDATE_DATE, LAST_UPDATED_BY, <base key>`.
  - **Who** = `LAST_UPDATED_BY` of the audit row, which holds the user name (`VARCHAR2(64)`).
  - **When** = `LAST_UPDATE_DATE` (`TIMESTAMP`).
- **Content.** *"The audit table is added with the snapshot of the row, every time an update is made for the audit-enabled columns."* So the old value of a change comes from the previous snapshot of the same record.
- **Limits:**
  - **Not retroactive.** Disabling it is also prospective only.
  - **Payables transaction objects record update and delete only**, and only when the user makes the change. Data changed by scheduled processes is not recorded.
  - Long-text and LOB attributes are not audited.
  - Impersonation is no longer recorded (only for legacy data).
- **Supported read channels:**
  - Navigator > Tools > **Audit Reports**, with old/new values, user and date filters. Export is capped at 10,000 records per entity.
  - The **Generate Audit Report** scheduled process.
  - REST `POST /fscmRestApi/fndAuditRESTService/audittrail/getaudithistory` (up to one month per call), and `…/get-auditsetup`, which lists every auditable object and attribute per product.
- **BI Publisher SQL on the audit tables:** widely used [Community]. Oracle neither documents it as supported nor forbids it.

**B. Native transaction history (no setup)** [Oracle 26D]

| Source | What it records | Who / when |
|---|---|---|
| `PO_VERSIONS` + `PO_HEADERS/LINES/LINE_LOCATIONS/DISTRIBUTIONS_ARCHIVE_ALL` | One `PO_VERSIONS` row per change order (`CO_SEQUENCE`, `CHANGE_ORDER_STATUS`, submitted/approved/processed dates). Archive rows hold every PO field, valid for a `FROM_CO_SEQ`–`TO_CO_SEQ` range, with `ENTITY_CHANGE_TYPE_CODE` (new/changed) and `ENTITY_CO_DISPOSITION` (approved/rejected/canceled). | Change order `CREATED_BY`, `SUBMITTED_DATE` |
| `FA_TRANSACTION_HEADERS` + `FA_BOOKS`, `FA_ASSET_HISTORY`, `FA_DISTRIBUTION_HISTORY`, `FA_RETIREMENTS` | Every asset transaction (adjustment, reclass, transfer, retirement, reinstatement). It closes the old row (`TRANSACTION_HEADER_ID_OUT`) and opens a new one (`_IN`). | `CREATED_BY`, `DATE_EFFECTIVE` |
| `AR_RECEIVABLE_APPLICATIONS_ALL` | Each apply creates a row. Each unapply reverses it (`REVERSAL_GL_DATE`) and adds an offsetting row. | `CREATED_BY`, `CREATION_DATE` |
| `CE_RECON_HISTORY` + `CE_RECON_HISTORY_ITEMS` | Each reconciliation group: `RECON_ACTION` (reconcile / unreconcile), `AUTO_RECON_FLAG`, and the matched items. | `CREATED_BY`, `CREATION_DATE` |
| `AP_HOLDS_ALL` | Hold placed (`HELD_BY`, `HOLD_DATE`, `HOLD_REASON`) and released (`RELEASE_LOOKUP_CODE`, `RELEASE_REASON`). | `HELD_BY` / `LAST_UPDATED_BY` |
| `GL_JE_HEADERS` reversal link; `GL_JE_ACTION_LOG` | Reversal journals (`ACCRUAL_REV_*`, `REVERSED_JE_HEADER_ID`). The action log is *"the history of a journal batch"* with user, role and time. Its columns are read in C11. | Reversal `CREATED_BY`; action-log user |
| `FND_ATTACHED_DOCUMENTS` + `FND_DOCUMENTS_TL` | Attachment additions (file name / URL, category). Deleted attachments leave no row. | `CREATED_BY`, `CREATION_DATE` |

### 4.3 Feasibility by transaction area

| Area | Source | Old → new values | Who / when reliable | Coverage of Changes-file items | Setup needed |
|---|---|---|---|---|---|
| **Purchase Orders** | Change-order archives (B) | Yes | Yes (per change order) | 76 of 79; 2 depend on Q7; attachment deletions not recorded | None |
| **Purchase Requisitions** | none for fields; attachments (B) | **No** | — | 0 of 18 fields; attachment additions only | Not auditable [Oracle 26D: no `POR_REQUISITION_*_` audit table, no revision tables] |
| **Fixed Assets** | Asset transactions (B); `FA_ADDITIONS_B_` audit (A) | Yes | Yes | 33 native; 13 after setup; Description not auditable (`FA_ADDITIONS_TL` has no audit table); 6 to confirm | Enable Assets auditing for descriptive attributes |
| **Bank Statements** | none for fields | **No** | — | 0 of 54 fields; line additions only | Not auditable [Oracle 26D: no `CE_STATEMENT_*_` audit table] |
| **Bank Reconciliations** | `CE_RECON_HISTORY` (B) | State + matched items | Yes | 3 of 3 | None |
| **AR Invoices** | none | **No** | — | 0 of 35 | Not auditable [Oracle 26D: no `RA_CUSTOMER_TRX*_` audit table] |
| **Receipts** | Applications (B) | Yes, for applications | Yes | 7 application items; 14 receipt fields not capturable | Receipt fields not auditable [Oracle 26D: no `AR_CASH_RECEIPTS_ALL_` audit table] |
| **AP Invoices** | Payables audit (A); holds, attachments (B) | Yes | Yes | 75 after setup + holds; 3 partial | Enable *Invoice, Invoice Lines, Invoice Distributions, Invoice Installments* with the listed attributes |
| **General Ledger** | Journal audit (A); reversal / action log (B) | Yes | Yes | 20 after setup; reversal native; Copy to confirm; Print not capturable | Enable General Ledger journal auditing |
| **Payments** | attachments (B) | **No** | — | Payment Type, Payment reference not capturable | Not auditable [Oracle 26D: no `AP_CHECKS_ALL_` audit table] |

### 4.4 Audit configuration required (do this first)

Setup and Maintenance > **Manage Audit Policies**, in DEV/TEST now and in Production once approved:

1. **Payables.** Audit Level = Auditing. In *Configure Business Object Attributes*, tick the attributes from the Changes file on:
   - **Invoice:** supplier, site, invoice group, number, amount, description, date, terms, terms date, requester, plus the payment-related header attributes: bank charge bearer, settlement priority, delivery channel, pay group, payment reason, payment reason comments, pay alone, URI check digit, discountable amount.
   - **Invoice Lines.**
   - **Invoice Distributions:** account.
   - **Invoice Installments:** due date, gross amount, payment priority, payment method, bank account, hold flag, discount date and amount, remittance messages 1–3.

   Only Supplier and Supplier Site are ticked by default. The exact attribute-by-attribute list is the *Payables* rows of `02_Field_Mapping.xlsx` with status *Capturable after setup*.
2. **General Ledger.** Audit Level = Auditing. Enable the *Journals* objects (batch, header, lines) for the 20 listed attributes, and journal attachments.
3. **Assets.** Audit Level = Auditing. Enable the asset object behind `FA_ADDITIONS_B` for: asset number, tag number, serial number, parent asset, manufacturer, model, asset key, property type, property class, owned/leased, new/used, commitment, investment law.
4. Tick **only** the attributes Mudad needs. Oracle warns that extra attributes and long search ranges affect performance.
5. Grant the audit/finance-control users `FND_VIEW_AUDIT_HISTORY_PRIV` so the Audit Reports page can be used to cross-check the report.

The exact object names on the setup page are confirmed with C3 (the setup page itself, or the `get-auditsetup` REST call).

### 4.5 Areas that cannot be audited: options

The affected areas are AR transactions, receipt header fields, bank statements, requisition lines and payment fields: 125 items in total.

| Option | What it gives | Limits | Effort |
|---|---|---|---|
| **A. Document the limitation** (recommended now) | The report shows every native event for these areas (applications, reconciliations, attachment additions) and no field values. Optionally adds the *modified after creation* indicator (Q17). | No old/new values. | None |
| **B. Snapshot capture outside BI Publisher** | A scheduled extract (for example every few hours) of the in-scope fields, stored and compared in an external store such as Oracle Integration Cloud + Autonomous Database. Produces old/new values from go-live onwards. | Not part of the Fusion BI Publisher report: Fusion BI Publisher cannot store snapshots, so these rows would be reported from the external store. Several changes between two snapshots appear as one. The user is the last updater at snapshot time, so attribution can be wrong if two people edit the same record between snapshots. No history before go-live. | High (new integration, storage, maintenance) |
| **C. Oracle enhancement request** | Request auditing for Receivables transactions/receipts, bank statements and requisitions (Oracle Idea Lab / SR). Re-check `get-auditsetup` after each quarterly update. | Depends on Oracle. | Low |
| **D. Preventive controls** | Restrict edit privileges on completed transactions; use approval workflows where available. | Reduces risk; does not create history. | Low–medium |

**Recommendation:** A + C now, with D as a complementary control. Option B only if Mudad confirms the history is mandatory (Q18).

### 4.6 Validation needed in Mudad's pod before Phase 2

I have no access to Mudad's environment, so nothing above has been executed against it. `03_Environment_Discovery.sql` turns every assumption into a check:

| Check | Confirms |
|---|---|
| C1 | Which audit tables exist: expected present for Payables, GL and Assets; expected absent for AR, CE statements, requisitions and payments. |
| C2 | Audit columns, whether anything is already being audited and since when, and the action types recorded. |
| C3 | Audit setup (objects and attributes enabled). |
| C4 | Audit row semantics (with validation test V-01). |
| C5 | All 536 native table/column pairs the design uses (expected: no MISSING). |
| C6 | Time zone of stored timestamps. |
| C7 / C15 | PO change-order and archive structure, statuses and dispositions in use. |
| C8 | WHO user names match `PER_USERS.USERNAME`. |
| C9 / C10 | Bank balance codes and reconciliation action codes in use. |
| C11 | Journal action log columns. |
| C12 | Attachment entity names per document type. |
| C13 | Scheduled-process history visibility (Q13). |
| C14 | Asset transaction types in use. |

**Validation tests (TEST pod):**

| Test | Steps | What it decides |
|---|---|---|
| **V-01** | Enable Payables auditing. Create an invoice. As user 1 change the supplier; as user 2 change the amount; as user 1 change the supplier again. Compare C4 output with the Audit Reports page. | Whether audit rows hold the value after or before each change. Whether the first change's old value is recorded (creation is not audited for Payables). Whether the SQL result matches Oracle's own report. **This decides the AP / GL / Assets extractor logic.** |
| **V-02** | On an approved PO, create change order 1 (supplier site, line price, schedule date, distribution account). Approve it. Create change order 2. Run C7. | The archive comparison and which user and timestamp represent the change (Q19). |
| **V-03** | Note the screen time of the V-01 change and compare it with `LAST_UPDATE_DATE` (C6). | Time zone conversion. |
| **V-04** | Run C8. | User mapping. |

Audit data is purged when a TEST pod is refreshed from Production with data masking [Community]. Run V-01 after the last planned refresh, or repeat it after a refresh.

### 4.7 Known limitations (preliminary)

1. **No history before auditing is enabled** for AP invoices, GL journals and asset descriptive fields.
2. **Payables auditing does not record inserts** or changes made by scheduled processes. Added invoice lines and new installments are shown from their own creator and creation time. The first change's old value **is** recorded: a `HISTORY` row holds the state before it (§4.8).
2a. **Attributes enabled later:** an attribute ticked after a record's `HISTORY` row was written has no earlier value in that row. Its first appearance must not be reported as a change; the extractor compares only columns that hold a value in both rows, or that were audited at both times. To be confirmed with the screenshots.
3. **Purchase orders:** history exists only for processed change orders. All edits in one change order share one timestamp and one user (the change-order creator). Drafts edited before the first approval leave no history.
4. **No field history** for AR transactions, receipt header fields, bank statements, requisition lines or payment fields (§4.5).
5. **Asset Description** cannot be audited (`FA_ADDITIONS_TL` has no audit table).
6. **Deleted attachments** are not recorded, except journal attachments once journal auditing is enabled.
7. **GL Print** is not a data change and is not recorded. **GL Copy** depends on C11.
8. Impersonation is no longer recorded by Fusion. How proxy users appear is not documented and is checked in V-01.
9. Statuses are current, not historical (Q6).
10. Audit history is removed by TEST-pod refreshes [Community].

### 4.8 Environment check results

Results from Mudad's pod, received 14 October 2026. Numbers are the statement order in `03_Environment_Discovery.sql`.

| # | Check | Result | Consequence |
|---|---|---|---|
| 1 | Audit tables | **As expected.** FOUND: `AP_INVOICES_ALL_`, `AP_INVOICE_LINES_ALL_`, `AP_INVOICE_DISTRIBUTIONS_ALL_`, `AP_PAYMENT_SCHEDULES_ALL_`, `GL_JE_BATCHES_`, `GL_JE_HEADERS_`, `GL_JE_LINES_`, `FA_ADDITIONS_B_`. MISSING: the 13 others (AP payments and holds, AR transactions/lines, receipts and applications, bank statements/lines, asset description, requisitions, PO). | The capture split in §4.3 is confirmed for Mudad's pod, not only by Oracle's documentation. |
| 8 | Native columns | **No MISSING columns.** Missing rows are listed first, and the first row returned was OK. | All native columns the design uses exist. |
| 9 | Time zone | `DBTIMEZONE` = +00:00, `SESSIONTIMEZONE` = UTC, `SYSDATE` in UTC. | Timestamps are converted from UTC to Mudad time for display, and the From/To dates are converted to UTC for filtering. V-03 confirms this against a change made on screen. |
| 3 | Audit data already recorded | `AP_INVOICES_ALL_`: 17 rows, 05-Oct-2026 08:01 to 13-Oct-2026 10:03 UTC.<br>`GL_JE_BATCHES_` 16, `GL_JE_HEADERS_` 11, `GL_JE_LINES_` 21 rows, all on 12-Oct-2026 between 08:41 and 12:19 UTC.<br>`AP_INVOICE_LINES_ALL_`, `AP_INVOICE_DISTRIBUTIONS_ALL_`, `AP_PAYMENT_SCHEDULES_ALL_`, `FA_ADDITIONS_B_`: 0 rows. | Auditing is **already on** for the AP invoice header (history from 5 Oct 2026) and for GL journals (activity on 12 Oct only, which looks like a test). Lines, distributions, installments and Assets show nothing: either not enabled, or no audited change yet (screenshots will tell). The report cannot show anything before these dates. |

Added checks **20** (AP invoice audit rows next to the current invoice) and **21** (GL journal header audit rows next to the current journal). They use the existing audit rows to answer V-01's main question without a new test: does each audit row hold the values after the change or before it, which columns are being audited (non-audited columns are empty in the audit rows), and are deletions recorded.

| 20, 21 | How audit rows are stored (AP invoice header, GL journal header) | For each record:<ul><li>The **first** audited change writes a `HISTORY` row: the state *before* that change, carrying its earlier WHO values.</li><li>**Every change** then writes an `UPDATE` row: the state *after* the change, with `LAST_UPDATED_BY` / `LAST_UPDATE_DATE` = who and when.</li><li>`OBJECT_VERSION_NUMBER` increases with each row.</li></ul>Examples: invoice 300000004847090 shows 800 → 1000 → 1200 → 1380 and then number inv-234 → inv-23478, five separate changes. Invoice 300000004842569 shows the number changing inv-964 → inv-964122.<br>Columns that are not audited are empty: GL `STATUS` (never null in the base table) is empty in every audit row, and AP `DESCRIPTION` / `BATCH_ID` are empty too.<br>No `DELETE` rows yet. `AUDIT_IMPERSONATOR_` empty. All rows by `admin_impl`. | **V-01's main question is answered.**<ul><li>Old value = the previous row of the same record (`HISTORY` or `UPDATE`).</li><li>New value, user and time = the `UPDATE` row.</li><li>`HISTORY` rows are never reported as changes.</li><li>The first change's old value **is** available.</li></ul>Only columns that are audited may be compared.<br>The current invoice's *Last Updated* is often later than its last audit row (for example invoice 300000004778645: version 14 now, last audit row version 5). This shows that changes to non-audited columns and process updates are not in the audit, and that "last updated by" cannot be used as an audit trail.<br>AP header attributes audited so far appear to be supplier, site, number, amount, date and terms. Description and invoice group look not ticked; the screenshots will confirm. |

| 5, 6 + setup page | Audit setup (`FND_AUDIT_ATTRIBUTES` exists and is readable) | **Payables** objects Invoice, Invoice Lines, Invoice Distributions and Invoice Installments are now ticked in TEST.<br>Every Changes-file field offered is enabled, except as listed below.<br>**Not offered** (cannot be audited): line Income Tax Region, Asset Category, Correction Type, tax Rate Name; installment Discount Date, Discount amount and hold flag (only Hold Reason is offered).<br>**To confirm:** line Accrual Account, Start Date, Asset Book.<br>**Assets:** all 14 descriptive fields enabled.<br>**General Ledger:** all batch, journal and line fields enabled, except batch Accounting Period (`DEFAULT_PERIOD_NAME`), which is offered but not ticked. | `02_Field_Mapping.xlsx` updated. The same setup must be repeated in Production. |

Still pending:
- Checks 2, 4–7 and 10–19.
- GL batch Accounting Period: not offered on the setup page; covered partly through the journal accounting date. Line Accrual Account, Start Date and Asset Book: enabled 18 Oct 2026. Setup in TEST is complete; repeat it in Production.
- A test with a second user (V-01 user part) and a deleted line (DELETE rows).
- Which environment checks 1–9 ran in (DEV, TEST or Production).
- The Manage Audit Policies screenshots.
- Validation tests V-01 to V-04.

---

## 5. Proposed solution design (outline for Phase 2)

### 5.1 Data model

One BI Publisher data model with one main data set: a `UNION ALL` of **extractors**, one per source and area. Every extractor returns the same columns:

| Column | Purpose |
|---|---|
| `PRODUCT`, `AREA` | Parameter value and transaction area |
| `TRX_KEY`, `TRANSACTION_ID` | Internal key (joins only) and displayed document number |
| `CHANGE_TS`, `CHANGE_TS_LOCAL` | Change time in database time (filtering) and Mudad time (display) |
| `USERNAME`, `USER_DISPLAY_NAME` | User recorded on the change record (`PER_USERS` → person name for display) |
| `ACTION_PERFORMED`, `OLD_VALUE`, `NEW_VALUE` | Level path + Changes-file label; decoded values |
| `TRANSACTION_STATUS`, `APPROVAL_STATUS`, `VOUCHER_NUMBER` | Document context (§3.4) |
| `SOURCE_CODE`, `EVENT_KEY` | Traceability (not displayed) and unique row key |

There are three kinds of extractor:

1. **Audit-history extractor** for `AP_INVOICES_ALL_`, `AP_INVOICE_LINES_ALL_`, `AP_INVOICE_DISTRIBUTIONS_ALL_`, `AP_PAYMENT_SCHEDULES_ALL_`, `GL_JE_*_` and `FA_ADDITIONS_B_`.
   - Finds the records changed in the date range, then compares each audit row with the neighbouring row of the same record. Which neighbour depends on the snapshot semantics confirmed by V-01.
   - The comparison window includes rows **older than From Date**, so the first change in the range still has its old value.
   - Each audited column is compared with a NULL-safe test, and one row is produced per column that changed. `DELETE` rows become `… deleted` events.
2. **Version-comparison extractor** for purchase orders: archive row at change-order sequence *n* compared with the row valid at *n − 1*, at header, line, schedule and distribution level.
3. **Event extractor** for holds, receipt applications, asset transactions, reconciliations, journal reversals and attachment additions.

### 5.2 Accuracy rules

- Old values only from stored earlier records (§4.1).
- Context columns are computed once per document and joined on `TRX_KEY`. Multi-row sources (sequences, approvals) are reduced to one value per document **before** the join, so changes are never duplicated.
- Each stored change is compared only with the record immediately before it for the same key. A document edited five times shows five sets of changes.
- IDs are decoded separately for the old and the new value.
- The user always comes from the change record.

### 5.3 Parameters in SQL

```sql
AND x.change_ts >= :P_FROM_DATE_DB
AND x.change_ts <  :P_TO_DATE_DB + 1
AND (COALESCE(NULL, :P_USERNAME) IS NULL OR x.username IN (:P_USERNAME))
AND (COALESCE(NULL, :P_PRODUCT)  IS NULL OR 'Payables' IN (:P_PRODUCT))  -- gate per extractor
```

`:P_FROM_DATE_DB` / `:P_TO_DATE_DB` are the parameter dates converted from Mudad time to database time; whether a conversion is needed depends on C6 / V-03. Each extractor is gated by product, so unselected products are not queried.

### 5.4 Layout

A BI Publisher **Excel template** (`.xls`, the same template type the AP Inventory report already uses) built to match `Audit Trail Report Template.xlsx`: title, Product/User block, 8 columns, colours and widths. Data is grouped by Product, then User (Q1), and sorted by Date, then Transaction ID.

The layout is built: **`Audit_Trail_Report_Layout.xls`**. Its requirements on the Phase 2 data model:

- **One flat data group named `G_AUDIT`**, one row per change. The template does the Product/User grouping itself, using the same `XDO_METADATA` regrouping pattern as the AP Inventory layout:
  - `G_BLOCK` repeats rows 3–7 (Product line, User line, column headers, data, spacer) for each distinct `PRODUCT` + `USERNAME`.
  - `G_CHANGE` repeats row 6 for each change in that block.
- **Elements:** `PRODUCT`, `USERNAME` (grouping key), `USER_LABEL` (shown after *User:*, for example `Display Name (username)`), `CHANGE_DATE` (text, `DD/MM/YYYY HH24:MI:SS`, Mudad time), `TRANSACTION_ID`, `ACTION_PERFORMED`, `OLD_VALUE`, `NEW_VALUE`, `TRANSACTION_STATUS`, `APPROVAL_STATUS`, `VOUCHER_NUMBER`.
- **Sort order:** the SQL returns rows ordered by `PRODUCT`, `USERNAME`, change timestamp, `TRANSACTION_ID`. Blocks appear in the order of their first row.
- **Preview:** `Audit_Trail_Sample_Data.xml` holds illustrative rows in this structure for previewing the layout before the data model exists.

### 5.5 Security and performance

- The report and data model go in a custom catalog folder that only audit/finance-control roles can open. BI Publisher SQL bypasses Fusion data security.
- Each extractor filters on the change timestamp first.
- Ranges longer than about a month should run as a scheduled report (Oracle's own guidance for audit searches).

---

## 6. Next steps

| # | Action | Owner |
|---|---|---|
| 1 | Answer Q1–Q19 (§3.6). The ones that shape the build are Q1, Q4, Q5, Q17, Q18 and Q19. | Mudad / project lead |
| 2 | **Enable the audit policies in §4.4** in DEV/TEST now, and in Production as soon as approved. | Mudad Fusion admin |
| 3 | Run `03_Environment_Discovery.sql` in DEV/TEST and return the outputs. | Mudad / consultant |
| 4 | Run validation tests V-01 to V-04 in TEST. | Mudad / consultant |
| 5 | **Phase 2:** final SQL data model, LOVs, Excel layout, implementation guide, validation scripts per product, final limitations list. | Consultant |

---

## 7. Sources (Oracle Help Center, release 26D unless noted)

- Audit policies (disabled by default, not retroactive): https://docs.oracle.com/en/cloud/saas/financials/26d/fafcf/audit-policies.html
- Audit configuration for business object attributes: https://docs.oracle.com/en/cloud/saas/financials/26d/fafcf/audit-configuration-for-business-object-attributes.html
- Payables transaction business objects (Invoice, Lines, Distributions, Installments): https://docs.oracle.com/en/cloud/saas/financials/26d/faipp/payables-transaction-business-objects.html
- Auditing Payables business objects: https://docs.oracle.com/en/cloud/saas/financials/26d/faipp/auditing-payables-business-objects.html
- View audit report (Audit Reports page, export limit): https://docs.oracle.com/en/cloud/saas/applications-common/26d/oacpr/view-audit-report.html
- Audit REST: get audit history: https://docs.oracle.com/en/cloud/saas/applications-common/26d/farca/op-fscmrestapi-fndauditrestservice-audittrail-getaudithistory-post.html
- Audit REST: get audit setup: https://docs.oracle.com/en/cloud/saas/applications-common/26d/farca/op-fscmrestapi-fndauditrestservice-audittrail-get-auditsetup-post.html
- Journal attachments audit: https://docs.oracle.com/en/cloud/saas/financials/26d/faugl/journal-attachments-audit.html
- Audit tables: AP_INVOICES_ALL_ https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/apinvoicesall-11096.html · GL_JE_HEADERS_ https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/gljeheaders-10218.html · FA_ADDITIONS_B_ https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/faadditionsb-11893.html
- PO change history: https://docs.oracle.com/en/cloud/saas/procurement/26d/oaprc/how-can-i-view-the-change-history-of-a-document.html · PO_VERSIONS https://docs.oracle.com/en/cloud/saas/procurement/26d/oedmp/poversions-24040.html · PO_HEADERS_ARCHIVE_ALL https://docs.oracle.com/en/cloud/saas/procurement/26d/oedmp/poheadersarchiveall-23971.html
- Requisition document history: https://docs.oracle.com/en/cloud/saas/procurement/26d/oaprc/document-history.html
- Native history tables: CE_RECON_HISTORY https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/cereconhistory-11356.html · AP_HOLDS_ALL https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/apholdsall-11070.html · AR_RECEIVABLE_APPLICATIONS_ALL https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/arreceivableapplicationsall-12493.html · FA_TRANSACTION_HEADERS https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/fatransactionheaders-11849.html · GL_JE_ACTION_LOG https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/gljeactionlog-10208.html
- Tables and Views guides: Financials https://docs.oracle.com/en/cloud/saas/financials/26d/oedmf/toc.htm · Procurement https://docs.oracle.com/en/cloud/saas/procurement/26d/oedmp/toc.htm · Common https://docs.oracle.com/en/cloud/saas/applications-common/26d/oedma/toc.htm

---

## 8. Change log

### 19 October 2026: report restricted to General Ledger (testing feedback)

| # | Change | Root cause / reason |
|---|---|---|
| 1 | Scope reduced to **General Ledger only**. The Payables, Purchase Orders, Fixed Assets, Receivables, Bank Statements, Requisitions and Payments sections were removed from the SQL itself, not only hidden in the layout. The Product parameter is no longer used. | Requested scope change. |
| 2 | **Transaction ID = journal name** for every row. Batch-level changes show the name of the batch's journal. | Action-log and batch-level rows fell back to the batch name when no journal was linked. |
| 3 | **Journal action log reduced to Copy.** The "Journal Action > Created / Updated" rows are removed. | These are events from GL_JE_ACTION_LOG, not field changes. |
| 4 | Only **user-entered fields** are compared: entered debit/credit, account, description, header and batch fields. Accounted amounts and running totals are never reported. | Derived values change with every edit and are not user changes. |
| 5 | **Transaction Status** read from Oracle's MJE_BATCH_STATUS lookup (journal batch status), with Posted / Unposted as fallback. | Raw status codes such as U were displayed. |
| 6 | **Coverage sheet removed** from the Excel layout. | Requested. |
| 7 | Fixed Assets "Comments" false positive fixed in the generator (kept for future use, not in the GL report). | A Comments row was produced for every asset transaction, even without a comment. |
