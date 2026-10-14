/* =====================================================================================
   Mudad Audit Trail Report - 03 Environment Discovery
   -------------------------------------------------------------------------------------
   Purpose : confirm, in Mudad's own Fusion pod, every object and column the design relies on
             (feasibility Step 3) BEFORE the final data model is written.
   Where   : DEV or TEST pod first (not Production without authorization).
   How     : create a temporary BI Publisher data model (data source ApplicationDB_FSCM),
             paste ONE check at a time as a SQL data set, view the data, and send the output
             (Excel export) back. Every statement is a read-only SELECT.
   Names   : every table/column below is taken from Oracle's 26D "Tables and Views" guides
             (oedmf / oedmp / oedma). Checks C1, C3, C11 and C13 discover objects by name
             pattern on purpose, because their exact content must be read from the pod.
   ===================================================================================== */


/* ---------- C1  Audit tables: which exist in this pod --------------------------------
   Oracle documents each audit table as <base table>_ (trailing underscore).
   Expected FOUND  : Payables invoice objects, General Ledger journals, Assets FA_ADDITIONS_B.
   Expected MISSING: the rest. They are the evidence that those areas cannot be audited.
   If any "Expected MISSING" table is FOUND, report it: that area would become auditable. */
WITH t (base_table, expectation) AS (
  SELECT 'AP_INVOICES_ALL',               'Expected FOUND'   FROM dual UNION ALL
  SELECT 'AP_INVOICE_LINES_ALL',          'Expected FOUND'   FROM dual UNION ALL
  SELECT 'AP_INVOICE_DISTRIBUTIONS_ALL',  'Expected FOUND'   FROM dual UNION ALL
  SELECT 'AP_PAYMENT_SCHEDULES_ALL',      'Expected FOUND'   FROM dual UNION ALL
  SELECT 'GL_JE_BATCHES',                 'Expected FOUND'   FROM dual UNION ALL
  SELECT 'GL_JE_HEADERS',                 'Expected FOUND'   FROM dual UNION ALL
  SELECT 'GL_JE_LINES',                   'Expected FOUND'   FROM dual UNION ALL
  SELECT 'FA_ADDITIONS_B',                'Expected FOUND'   FROM dual UNION ALL
  SELECT 'FA_ADDITIONS_TL',               'Expected MISSING' FROM dual UNION ALL
  SELECT 'AP_CHECKS_ALL',                 'Expected MISSING' FROM dual UNION ALL
  SELECT 'AP_HOLDS_ALL',                  'Expected MISSING' FROM dual UNION ALL
  SELECT 'RA_CUSTOMER_TRX_ALL',           'Expected MISSING' FROM dual UNION ALL
  SELECT 'RA_CUSTOMER_TRX_LINES_ALL',     'Expected MISSING' FROM dual UNION ALL
  SELECT 'AR_CASH_RECEIPTS_ALL',          'Expected MISSING' FROM dual UNION ALL
  SELECT 'AR_RECEIVABLE_APPLICATIONS_ALL','Expected MISSING' FROM dual UNION ALL
  SELECT 'CE_STATEMENT_HEADERS',          'Expected MISSING' FROM dual UNION ALL
  SELECT 'CE_STATEMENT_LINES',            'Expected MISSING' FROM dual UNION ALL
  SELECT 'POR_REQUISITION_HEADERS_ALL',   'Expected MISSING' FROM dual UNION ALL
  SELECT 'POR_REQUISITION_LINES_ALL',     'Expected MISSING' FROM dual UNION ALL
  SELECT 'PO_HEADERS_ALL',                'Expected MISSING' FROM dual UNION ALL
  SELECT 'PO_LINES_ALL',                  'Expected MISSING' FROM dual
)
SELECT t.base_table,
       t.base_table || '_'                                                AS audit_table,
       t.expectation,
       CASE WHEN COUNT(o.object_name) > 0 THEN 'FOUND' ELSE 'MISSING' END AS actual,
       LISTAGG(o.owner || ':' || o.object_type, ', ') WITHIN GROUP (ORDER BY o.owner) AS objects
FROM   t
LEFT JOIN all_objects o
       ON o.object_name = t.base_table || '_'
GROUP  BY t.base_table, t.expectation
ORDER  BY t.expectation, t.base_table
;


/* ---------- C2  Audit tables: audit columns and data already recorded -----------------
   C2a: expected per table AUDIT_ACTION_TYPE_, AUDIT_CHANGE_BIT_MAP_, AUDIT_IMPERSONATOR_. */
SELECT table_name, column_name, data_type, data_length
FROM   all_tab_columns
WHERE  table_name IN ('AP_INVOICES_ALL_', 'AP_INVOICE_LINES_ALL_', 'AP_INVOICE_DISTRIBUTIONS_ALL_',
                      'AP_PAYMENT_SCHEDULES_ALL_', 'GL_JE_BATCHES_', 'GL_JE_HEADERS_', 'GL_JE_LINES_',
                      'FA_ADDITIONS_B_')
AND    column_name LIKE 'AUDIT%'
ORDER  BY table_name, column_name
;

/* C2b: is anything already being audited, and since when?
   Keep only the branches for tables C1 reported FOUND (a missing table fails the statement).
   0 rows recorded = auditing not enabled yet for that object.                            */
SELECT 'AP_INVOICES_ALL_' AS audit_table, COUNT(*) AS audit_rows,
       MIN(last_update_date) AS first_change, MAX(last_update_date) AS last_change
FROM   ap_invoices_all_
UNION ALL
SELECT 'AP_INVOICE_LINES_ALL_', COUNT(*), MIN(last_update_date), MAX(last_update_date) FROM ap_invoice_lines_all_
UNION ALL
SELECT 'AP_INVOICE_DISTRIBUTIONS_ALL_', COUNT(*), MIN(last_update_date), MAX(last_update_date) FROM ap_invoice_distributions_all_
UNION ALL
SELECT 'AP_PAYMENT_SCHEDULES_ALL_', COUNT(*), MIN(last_update_date), MAX(last_update_date) FROM ap_payment_schedules_all_
UNION ALL
SELECT 'GL_JE_BATCHES_', COUNT(*), MIN(last_update_date), MAX(last_update_date) FROM gl_je_batches_
UNION ALL
SELECT 'GL_JE_HEADERS_', COUNT(*), MIN(last_update_date), MAX(last_update_date) FROM gl_je_headers_
UNION ALL
SELECT 'GL_JE_LINES_', COUNT(*), MIN(last_update_date), MAX(last_update_date) FROM gl_je_lines_
UNION ALL
SELECT 'FA_ADDITIONS_B_', COUNT(*), MIN(last_update_date), MAX(last_update_date) FROM fa_additions_b_
;

/* C2c: action types recorded so far (Payables: UPDATE / DELETE expected, INSERT not expected). */
SELECT 'AP_INVOICES_ALL_' AS audit_table, audit_action_type_, COUNT(*) AS cnt FROM ap_invoices_all_ GROUP BY audit_action_type_
UNION ALL
SELECT 'AP_INVOICE_LINES_ALL_', audit_action_type_, COUNT(*) FROM ap_invoice_lines_all_ GROUP BY audit_action_type_
UNION ALL
SELECT 'GL_JE_HEADERS_', audit_action_type_, COUNT(*) FROM gl_je_headers_ GROUP BY audit_action_type_
;


/* ---------- C3  Audit setup: which objects / attributes are switched on ---------------
   Preferred, supported checks (no SQL):
     a) Setup and Maintenance > Manage Audit Policies > Configure Business Object Attributes,
        for Payables, Receivables, Cash Management, Assets, General Ledger, Purchasing and
        Self Service Procurement: screenshot the objects offered and the ticked attributes.
     b) REST: POST /fscmRestApi/fndAuditRESTService/audittrail/get-auditsetup (per product)
        returns every auditable object and attribute with an isAuditable flag.
   Optional SQL: Oracle's older developer guide describes FND_AUDIT_ATTRIBUTES as an internal
   table. First list what the pod actually has:                                           */
SELECT owner, object_name, object_type
FROM   all_objects
WHERE  object_name LIKE 'FND\_AUDIT%' ESCAPE '\'
ORDER  BY object_name
;
/* Then list its columns before querying it (do not assume the legacy column names): */
SELECT column_name, data_type
FROM   all_tab_columns
WHERE  table_name = 'FND_AUDIT_ATTRIBUTES'
ORDER  BY column_id
;


/* ---------- C4  Audit row semantics (validation test V-01) ----------------------------
   After V-01 is executed in TEST (create invoice, change supplier, change amount, change
   supplier again, using two different users), run this for that invoice and compare it row by
   row with Navigator > Tools > Audit Reports for the same invoice. It answers:
   does each row hold the values AFTER the change or BEFORE it? Is the creation state present?
   Who and when are recorded where?                                                         */
SELECT a.last_update_date, a.last_updated_by, a.audit_action_type_, a.audit_impersonator_,
       a.audit_change_bit_map_, a.object_version_number,
       a.invoice_num, a.vendor_id, a.vendor_site_id, a.invoice_amount, a.description, a.invoice_date
FROM   ap_invoices_all_ a
WHERE  a.invoice_id = :P_TEST_INVOICE_ID
ORDER  BY a.last_update_date, a.object_version_number
;


/* ---------- C5  Column availability for every native column the design uses ----------
   536 table/column pairs, all taken from Oracle's 26D Tables and Views guides.
   Expected result: no MISSING rows. Any MISSING row is reported back before Phase 2. */
WITH req_raw (tab, cols) AS (
  SELECT 'AP_BATCHES_ALL', 'BATCH_ID,BATCH_NAME' FROM dual
  UNION ALL SELECT 'AP_CHECKS_ALL', 'CHECK_ID,CHECK_NUMBER,DOC_SEQUENCE_VALUE,PAYMENT_ID,PAYMENT_TYPE_FLAG,STATUS_LOOKUP_CODE' FROM dual
  UNION ALL SELECT 'AP_HOLDS_ALL', 'CREATED_BY,CREATION_DATE,HELD_BY,HOLD_DATE,HOLD_ID,HOLD_LOOKUP_CODE,HOLD_REASON,INVOICE_ID,LAST_UPDATED_BY,LAST_UPDATE_DATE,RELEASE_LOOKUP_CODE,RELEASE_REASON' FROM dual
  UNION ALL SELECT 'AP_INVOICES_ALL', 'AMOUNT_APPLICABLE_TO_DISCOUNT,BANK_CHARGE_BEARER,BATCH_ID,CANCELLED_DATE,DELIVERY_CHANNEL_CODE,DESCRIPTION,DOC_SEQUENCE_VALUE,EXCLUSIVE_PAYMENT_FLAG,INVOICE_AMOUNT,INVOICE_DATE,INVOICE_ID,INVOICE_NUM' FROM dual
  UNION ALL SELECT 'AP_INVOICES_ALL', 'INVOICE_TYPE_LOOKUP_CODE,LAST_UPDATED_BY,LAST_UPDATE_DATE,PAYMENT_REASON_CODE,PAYMENT_REASON_COMMENTS,PAYMENT_STATUS_FLAG,PAY_GROUP_LOOKUP_CODE,REQUESTER_ID,SETTLEMENT_PRIORITY,TERMS_DATE,TERMS_ID,URI_CHECK_DIGIT' FROM dual
  UNION ALL SELECT 'AP_INVOICES_ALL', 'VENDOR_ID,VENDOR_SITE_ID,VOUCHER_NUM,WFAPPROVAL_STATUS' FROM dual
  UNION ALL SELECT 'AP_INVOICE_DISTRIBUTIONS_ALL', 'DISTRIBUTION_LINE_NUMBER,DIST_CODE_COMBINATION_ID,INVOICE_DISTRIBUTION_ID,INVOICE_ID,INVOICE_LINE_NUMBER,POSTED_FLAG' FROM dual
  UNION ALL SELECT 'AP_INVOICE_LINES_ALL', 'ACCOUNTING_DATE,AMOUNT,ASSESSABLE_VALUE,ASSETS_TRACKING_FLAG,ASSET_BOOK_TYPE_CODE,ASSET_CATEGORY_ID,AWT_GROUP_ID,CONTROL_AMOUNT,CORRECTED_INV_ID,DEFAULT_DIST_CCID,DEF_ACCTG_ACCRUAL_CCID,DEF_ACCTG_END_DATE' FROM dual
  UNION ALL SELECT 'AP_INVOICE_LINES_ALL', 'DEF_ACCTG_START_DATE,DESCRIPTION,DISTRIBUTION_SET_ID,FINAL_DISCHARGE_LOCATION_ID,INCOME_TAX_REGION,INVENTORY_ITEM_ID,INVOICE_ID,LAST_UPDATED_BY,LAST_UPDATE_DATE,LINE_NUMBER,LINE_TYPE_LOOKUP_CODE,MANUFACTURER' FROM dual
  UNION ALL SELECT 'AP_INVOICE_LINES_ALL', 'MATCH_TYPE,MODEL_NUMBER,PJC_PROJECT_ID,PO_HEADER_ID,PRIMARY_INTENDED_USE,PRODUCT_CATEGORY,PRODUCT_FISC_CLASSIFICATION,PRODUCT_TYPE,QUANTITY_INVOICED,REQUESTER_ID,SERIAL_NUMBER,SHIP_FROM_LOCATION_ID' FROM dual
  UNION ALL SELECT 'AP_INVOICE_LINES_ALL', 'SHIP_TO_LOCATION_ID,TAX_CLASSIFICATION_CODE,TAX_RATE_CODE,TRX_BUSINESS_CATEGORY,TYPE_1099,UNIT_MEAS_LOOKUP_CODE,UNIT_PRICE,USER_DEFINED_FISC_CLASS' FROM dual
  UNION ALL SELECT 'AP_INV_APRVL_HIST_ALL', 'ACTION_DATE,APPROVER_ID,CREATION_DATE,INVOICE_ID,RESPONSE' FROM dual
  UNION ALL SELECT 'AP_PAYMENT_SCHEDULES_ALL', 'DISCOUNT_AMOUNT_AVAILABLE,DISCOUNT_DATE,DUE_DATE,EXTERNAL_BANK_ACCOUNT_ID,GROSS_AMOUNT,HOLD_FLAG,INVOICE_ID,PAYMENT_METHOD_CODE,PAYMENT_NUM,PAYMENT_PRIORITY,REMITTANCE_MESSAGE1,REMITTANCE_MESSAGE2' FROM dual
  UNION ALL SELECT 'AP_PAYMENT_SCHEDULES_ALL', 'REMITTANCE_MESSAGE3' FROM dual
  UNION ALL SELECT 'AR_CASH_RECEIPTS_ALL', 'AMOUNT,CASH_RECEIPT_ID,COMMENTS,CUSTOMER_BANK_ACCOUNT_ID,CUSTOMER_BANK_BRANCH_ID,CUSTOMER_SITE_USE_ID,DEPOSIT_DATE,DOC_SEQUENCE_VALUE,PAY_FROM_CUSTOMER,POSTMARK_DATE,RECEIPT_DATE,RECEIPT_NUMBER' FROM dual
  UNION ALL SELECT 'AR_CASH_RECEIPTS_ALL', 'RESOURCE_ID,STATUS,STRUCTURED_PAYMENT_REFERENCE,VAT_TAX_ID' FROM dual
  UNION ALL SELECT 'AR_CASH_RECEIPT_HISTORY_ALL', 'CASH_RECEIPT_HISTORY_ID,CASH_RECEIPT_ID,CREATED_BY,CREATION_DATE,CURRENT_RECORD_FLAG,STATUS' FROM dual
  UNION ALL SELECT 'AR_MEMO_LINES_ALL_B', 'MEMO_LINE_SEQ_ID' FROM dual
  UNION ALL SELECT 'AR_RECEIVABLE_APPLICATIONS_ALL', 'AMOUNT_APPLIED,APPLICATION_REF_NUM,APPLIED_CUSTOMER_TRX_ID,APPLY_DATE,CASH_RECEIPT_ID,CREATED_BY,CREATION_DATE,DISPLAY,EARNED_DISCOUNT_TAKEN,EXCEPTION_REASON_CODE,GL_DATE,RECEIVABLE_APPLICATION_ID' FROM dual
  UNION ALL SELECT 'AR_RECEIVABLE_APPLICATIONS_ALL', 'REVERSAL_GL_DATE,STATUS' FROM dual
  UNION ALL SELECT 'CE_RECON_HISTORY', 'AUTO_RECON_FLAG,BANK_ACCOUNT_ID,CREATED_BY,CREATION_DATE,RECON_ACTION,RECON_HISTORY_ID' FROM dual
  UNION ALL SELECT 'CE_RECON_HISTORY_ITEMS', 'CLEARED_AMOUNT,CLEARED_DATE,RECON_HISTORY_ID,RECON_SOURCE,SOURCE_ID,SOURCE_LINE_ID' FROM dual
  UNION ALL SELECT 'CE_STATEMENT_HEADERS', 'BANK_ACCOUNT_ID,ELECTRONIC_SEQ_NUM,INTRADAY_FLAG,LAST_UPDATED_BY,LAST_UPDATE_DATE,LEGAL_SEQ_NUM,RECON_STATUS_CODE,STATEMENT_HEADER_ID,STATEMENT_NUMBER,STMT_FROM_DATE,STMT_TO_DATE' FROM dual
  UNION ALL SELECT 'CE_STATEMENT_LINES', 'ACCNT_SERVICER_REF,ADDENDA_TXT,AMOUNT,BOOKING_DATE,CHECK_NUMBER,CLEARING_SYSTEM_REF,CONTRACT_IDENTIFICATION,COUNTERPARTY_AGENT_IDENTIFIER,COUNTERPARTY_AGENT_NAME,COUNTERPARTY_IBAN,COUNTERPARTY_IDENTIFIER,COUNTERPARTY_NAME' FROM dual
  UNION ALL SELECT 'CE_STATEMENT_LINES', 'CREDITOR_REFERENCE,CUSTOMER_REFERENCE,END_TO_END_ID,EXCHANGE_RATE,EXCHANGE_RATE_DATE,FLOW_INDICATOR,INSTRUCTION_IDENTIFICATION,LINE_NUMBER,MANDATE_IDENTIFICATION_NUMBER,MESSAGE_IDENTIFIER,PAYMENT_INFO_IDENTIFIER,RECON_HISTORY_ID' FROM dual
  UNION ALL SELECT 'CE_STATEMENT_LINES', 'RECON_REFERENCE,RECON_STATUS,REVERSAL_IND_FLAG,REVERSAL_REASON_CODE,STATEMENT_HEADER_ID,STATEMENT_LINE_ID,STRUCTURED_PAYMENT_REFERENCE,TRANSACTION_ID,TRX_CODE_ID,TRX_CURR_CODE,VALUE_DATE' FROM dual
  UNION ALL SELECT 'CE_STMT_BALANCES', 'BALANCE_AMOUNT,BALANCE_CODE,STATEMENT_HEADER_ID,STMT_BALANCE_ID' FROM dual
  UNION ALL SELECT 'CE_STMT_BAL_AVALBTY', 'ACTUAL_DATE,AVAILABLE_BALANCE_AMT,NUMBER_OF_FLOAT_DAYS' FROM dual
  UNION ALL SELECT 'CE_STMT_LINE_CHARGES', 'CHARGES_AMT,CHARGES_CURR,CHARGE_PERCENT_RATE,CHARGE_SERVICE_CODE,TAX_AMOUNT,TAX_CURR,TAX_ID,TAX_RATE,TRX_CHARGE_BEARER_CODE' FROM dual
  UNION ALL SELECT 'CE_TRANSACTION_CODES', 'TRANSACTION_CODE_ID,TRX_CODE' FROM dual
  UNION ALL SELECT 'FA_ADDITIONS_B', 'ASSET_ID,ASSET_KEY_CCID,ASSET_NUMBER,COMMITMENT,INVESTMENT_LAW,MANUFACTURER_NAME,MODEL_NUMBER,NEW_USED,OWNED_LEASED,PARENT_ASSET_ID,PROPERTY_1245_1250_CODE,PROPERTY_TYPE_CODE' FROM dual
  UNION ALL SELECT 'FA_ADDITIONS_B', 'SERIAL_NUMBER,TAG_NUMBER' FROM dual
  UNION ALL SELECT 'FA_ADDITIONS_TL', 'DESCRIPTION' FROM dual
  UNION ALL SELECT 'FA_ASSET_HISTORY', 'ASSET_ID,CATEGORY_ID,TRANSACTION_HEADER_ID_IN,TRANSACTION_HEADER_ID_OUT' FROM dual
  UNION ALL SELECT 'FA_BONUS_RULES', 'BONUS_RULE,BONUS_RULE_ID' FROM dual
  UNION ALL SELECT 'FA_BOOKS', 'ASSET_ID,BONUS_RULE_ID,BOOK_TYPE_CODE,CASH_GENERATING_UNIT_ID,CONVENTION_TYPE_ID,COST,DATE_PLACED_IN_SERVICE,DEPRN_LIMIT_TYPE,METHOD_ID,PERCENT_SALVAGE_VALUE,SALVAGE_TYPE,TRANSACTION_HEADER_ID_IN' FROM dual
  UNION ALL SELECT 'FA_BOOKS', 'TRANSACTION_HEADER_ID_OUT' FROM dual
  UNION ALL SELECT 'FA_CONVENTION_TYPES', 'CONVENTION_TYPE_ID,PRORATE_CONVENTION_CODE' FROM dual
  UNION ALL SELECT 'FA_DISTRIBUTION_HISTORY', 'ASSET_ID,ASSIGNED_TO,CODE_COMBINATION_ID,DISTRIBUTION_ID,LOCATION_ID,TRANSACTION_HEADER_ID_IN,TRANSACTION_HEADER_ID_OUT,UNITS_ASSIGNED' FROM dual
  UNION ALL SELECT 'FA_METHODS', 'LIFE_IN_MONTHS,METHOD_CODE,METHOD_ID' FROM dual
  UNION ALL SELECT 'FA_RETIREMENTS', 'ASSET_ID,COST_OF_REMOVAL,COST_RETIRED,DATE_RETIRED,PROCEEDS_OF_SALE,REFERENCE_NUM,RETIREMENT_CONVENTION_TYPE_ID,RETIREMENT_ID,RETIREMENT_TYPE_CODE,SOLD_TO,TRADE_IN_ASSET_ID,TRANSACTION_HEADER_ID_IN' FROM dual
  UNION ALL SELECT 'FA_TRANSACTION_HEADERS', 'AMORTIZATION_START_DATE,ASSET_ID,BOOK_TYPE_CODE,CREATED_BY,DATE_EFFECTIVE,LAST_UPDATED_BY,TRANSACTION_DATE_ENTERED,TRANSACTION_HEADER_ID,TRANSACTION_NAME,TRANSACTION_SUBTYPE,TRANSACTION_TYPE_CODE' FROM dual
  UNION ALL SELECT 'FND_ATTACHED_DOCUMENTS', 'CATEGORY_NAME,CREATED_BY,CREATION_DATE,DOCUMENT_ID,ENTITY_NAME,PK1_VALUE,PK2_VALUE' FROM dual
  UNION ALL SELECT 'FND_DOCUMENTS', 'DATATYPE_CODE,DOCUMENT_ID' FROM dual
  UNION ALL SELECT 'FND_DOCUMENTS_TL', 'DOCUMENT_ID,FILE_NAME,LANGUAGE,TITLE,URL' FROM dual
  UNION ALL SELECT 'GL_JE_BATCHES', 'APPROVAL_STATUS_CODE,CONTROL_TOTAL,DEFAULT_PERIOD_NAME,DESCRIPTION,JE_BATCH_ID,NAME,STATUS' FROM dual
  UNION ALL SELECT 'GL_JE_HEADERS', 'ACCRUAL_REV_CHANGE_SIGN_FLAG,ACCRUAL_REV_JE_HEADER_ID,ACCRUAL_REV_PERIOD_NAME,ACCRUAL_REV_STATUS,CURRENCY_CODE,DEFAULT_EFFECTIVE_DATE,DESCRIPTION,DOC_SEQUENCE_VALUE,EXTERNAL_REFERENCE,JE_BATCH_ID,JE_CATEGORY,JE_HEADER_ID' FROM dual
  UNION ALL SELECT 'GL_JE_HEADERS', 'NAME,POSTING_ACCT_SEQ_VALUE,REFERENCE_DATE,STATUS' FROM dual
  UNION ALL SELECT 'GL_JE_LINES', 'CODE_COMBINATION_ID,DESCRIPTION,ENTERED_CR,ENTERED_DR,JE_HEADER_ID,JE_LINE_NUM' FROM dual
  UNION ALL SELECT 'IBY_PAYMENTS_ALL', 'PAYMENT_ID,PAYMENT_REFERENCE_NUMBER' FROM dual
  UNION ALL SELECT 'PER_USERS', 'ACTIVE_FLAG,PERSON_ID,SUSPENDED,USERNAME,USER_ID' FROM dual
  UNION ALL SELECT 'POR_REQUISITION_HEADERS_ALL', 'DOCUMENT_STATUS,REQUISITION_HEADER_ID,REQUISITION_NUMBER' FROM dual
  UNION ALL SELECT 'POR_REQUISITION_LINES_ALL', 'CATEGORY_ID,CURRENCY_CODE,ITEM_DESCRIPTION,LAST_UPDATED_BY,LAST_UPDATE_DATE,LINE_NUMBER,MANUFACTURER_NAME,MANUFACTURER_PART_NUMBER,NEW_SUPPLIER_FLAG,NOTE_TO_BUYER,NOTE_TO_RECEIVER,NOTE_TO_SUPPLIER' FROM dual
  UNION ALL SELECT 'POR_REQUISITION_LINES_ALL', 'QUANTITY,REQUISITION_HEADER_ID,REQUISITION_LINE_ID,SOURCE_DOC_HEADER_ID,SUGGESTED_BUYER_ID,SUGGESTED_SUPPLIER_ITEM_NUMBER,UNIT_PRICE,UOM_CODE,VENDOR_CONTACT_ID,VENDOR_ID,VENDOR_SITE_ID' FROM dual
  UNION ALL SELECT 'PO_ACTION_HISTORY', 'ACTION_CODE,ACTION_DATE,OBJECT_ID,OBJECT_TYPE_CODE,PERFORMER_ID,PO_VERSION_ID,ROLE_CODE' FROM dual
  UNION ALL SELECT 'PO_DISTRIBUTIONS_ALL', 'CODE_COMBINATION_ID,DELIVER_TO_LOCATION_ID,DELIVER_TO_PERSON_ID,QUANTITY_ORDERED' FROM dual
  UNION ALL SELECT 'PO_DISTRIBUTIONS_ARCHIVE_ALL', 'DISTRIBUTION_NUM,ENTITY_CHANGE_TYPE_CODE,ENTITY_CO_DISPOSITION,FROM_CO_SEQ,LINE_LOCATION_ID,PO_DISTRIBUTION_ID,TO_CO_SEQ' FROM dual
  UNION ALL SELECT 'PO_HEADERS_ALL', 'ACCEPTANCE_REQUIRED_FLAG,ACCEPTANCE_WITHIN_DAYS,AGENT_ID,APPROVED_FLAG,BILL_TO_LOCATION_ID,CARRIER_ID,COMMENTS,CONFIRMING_ORDER_FLAG,CURRENCY_CODE,CURRENT_VERSION_ID,DOCUMENT_STATUS,FOB_LOOKUP_CODE' FROM dual
  UNION ALL SELECT 'PO_HEADERS_ALL', 'FREIGHT_TERMS_LOOKUP_CODE,MODE_OF_TRANSPORT,PO_HEADER_ID,SEGMENT1,SHIP_TO_LOCATION_ID,SUPPLIER_NOTIF_METHOD,TERMS_ID,VENDOR_CONTACT_ID,VENDOR_ID,VENDOR_SITE_ID' FROM dual
  UNION ALL SELECT 'PO_HEADERS_ARCHIVE_ALL', 'ENTITY_CHANGE_TYPE_CODE,ENTITY_CO_DISPOSITION,FROM_CO_SEQ,LAST_UPDATED_BY,LAST_UPDATE_DATE,PO_HEADER_ID,TO_CO_SEQ' FROM dual
  UNION ALL SELECT 'PO_LINES_ALL', 'HAZARD_CLASS_ID,ITEM_DESCRIPTION,ITEM_REVISION,NEGOTIATED_BY_PREPARER_FLAG,NOTE_TO_VENDOR,QUANTITY,UNIT_PRICE,UN_NUMBER_ID,UOM_CODE,VENDOR_PRODUCT_NUM' FROM dual
  UNION ALL SELECT 'PO_LINES_ARCHIVE_ALL', 'ENTITY_CHANGE_TYPE_CODE,ENTITY_CO_DISPOSITION,FROM_CO_SEQ,LINE_NUM,PO_HEADER_ID,PO_LINE_ID,TO_CO_SEQ' FROM dual
  UNION ALL SELECT 'PO_LINE_LOCATIONS_ALL', 'ALLOW_SUBSTITUTE_RECEIPTS_FLAG,ASSESSABLE_VALUE,CARRIER_ID,COUNTRY_OF_ORIGIN_CODE,DAYS_EARLY_RECEIPT_ALLOWED,DAYS_LATE_RECEIPT_ALLOWED,ENFORCE_SHIP_TO_LOCATION_CODE,FINAL_DISCHARGE_LOCATION_ID,INPUT_TAX_CLASSIFICATION_CODE,INSPECTION_REQUIRED_FLAG,INVOICE_CLOSE_TOLERANCE,LINE_INTENDED_USE' FROM dual
  UNION ALL SELECT 'PO_LINE_LOCATIONS_ALL', 'MATCH_OPTION,MODE_OF_TRANSPORT,NEED_BY_DATE,NOTE_TO_RECEIVER,PRODUCT_CATEGORY,PRODUCT_FISC_CLASSIFICATION,PRODUCT_TYPE,PROMISED_DATE,QTY_RCV_EXCEPTION_CODE,QTY_RCV_TOLERANCE,QUANTITY,RECEIPT_DAYS_EXCEPTION_CODE' FROM dual
  UNION ALL SELECT 'PO_LINE_LOCATIONS_ALL', 'RECEIPT_REQUIRED_FLAG,RECEIVE_CLOSE_TOLERANCE,RECEIVING_ROUTING_ID,SERVICE_LEVEL,SHIP_TO_LOCATION_ID,SUPPLIER_ORDER_LINE_NUMBER,TRX_BUSINESS_CATEGORY,USER_DEFINED_FISC_CLASS' FROM dual
  UNION ALL SELECT 'PO_LINE_LOCATIONS_ARCHIVE_ALL', 'ENTITY_CHANGE_TYPE_CODE,ENTITY_CO_DISPOSITION,FROM_CO_SEQ,LINE_LOCATION_ID,PO_LINE_ID,SHIPMENT_NUM,TO_CO_SEQ' FROM dual
  UNION ALL SELECT 'PO_VERSIONS', 'APPROVED_DATE,CHANGE_ORDER_DESC,CHANGE_ORDER_STATUS,CO_NUM,CO_SEQUENCE,CREATED_BY,CREATION_DATE,ORIGINATOR_ROLE,PO_HEADER_ID,PROCESSED_DATE,REQUEST_DATE,REVISION_NUM' FROM dual
  UNION ALL SELECT 'PO_VERSIONS', 'SUBMITTED_DATE,VERSION_ID' FROM dual
  UNION ALL SELECT 'RA_CUSTOMER_TRX_ALL', 'BILLING_DATE,BILL_TO_CUSTOMER_ID,BILL_TO_SITE_USE_ID,COMPLETE_FLAG,CT_REFERENCE,CUSTOMER_TRX_ID,CUST_TRX_TYPE_SEQ_ID,DOC_SEQUENCE_VALUE,INVOICE_CURRENCY_CODE,INVOICING_RULE_ID,SHIP_TO_CUSTOMER_ID,SHIP_TO_SITE_USE_ID' FROM dual
  UNION ALL SELECT 'RA_CUSTOMER_TRX_ALL', 'TERM_ID,TRX_DATE,TRX_NUMBER' FROM dual
  UNION ALL SELECT 'RA_CUSTOMER_TRX_LINES_ALL', 'ACCOUNTING_RULE_ID,ASSESSABLE_VALUE,CUSTOMER_TRX_ID,CUSTOMER_TRX_LINE_ID,DESCRIPTION,FINAL_DISCHARGE_LOCATION_ID,LINE_INTENDED_USE,LINE_TYPE,MEMO_LINE_SEQ_ID,PRODUCT_FISC_CLASSIFICATION,PRODUCT_TYPE,QUANTITY_INVOICED' FROM dual
  UNION ALL SELECT 'RA_CUSTOMER_TRX_LINES_ALL', 'REASON_CODE,RULE_END_DATE,RULE_START_DATE,SHIP_TO_ADDRESS_ID,SHIP_TO_CONTACT_ID,SHIP_TO_CUSTOMER_ID,SHIP_TO_SITE_USE_ID,TAX_CLASSIFICATION_CODE,TAX_INVOICE_DATE,TAX_INVOICE_NUMBER,TRX_BUSINESS_CATEGORY,UNIT_SELLING_PRICE' FROM dual
  UNION ALL SELECT 'RA_CUSTOMER_TRX_LINES_ALL', 'UOM_CODE,USER_DEFINED_FISC_CLASS' FROM dual
  UNION ALL SELECT 'RA_CUST_TRX_TYPES_ALL', 'CUST_TRX_TYPE_SEQ_ID,NAME,TYPE' FROM dual
),
req AS (
  SELECT r.tab, REGEXP_SUBSTR(r.cols, '[^,]+', 1, n.n) AS col
  FROM   req_raw r
  JOIN   (SELECT LEVEL AS n FROM dual CONNECT BY LEVEL <= 12) n
         ON n.n <= REGEXP_COUNT(r.cols, ',') + 1
)
SELECT req.tab                                                     AS table_name,
       req.col                                                     AS column_name,
       CASE WHEN COUNT(atc.column_name) = 0 THEN 'MISSING' ELSE 'OK' END AS status,
       MAX(atc.data_type)                                          AS data_type
FROM   req
LEFT JOIN all_tab_columns atc
       ON atc.table_name  = req.tab
      AND atc.column_name = req.col
GROUP  BY req.tab, req.col
ORDER  BY CASE WHEN COUNT(atc.column_name) = 0 THEN 0 ELSE 1 END, req.tab, req.col
;


/* ---------- C6  Time zone: how change timestamps are stored ---------------------------
   Compare with a change whose local time is known (for example the V-01 supplier change).
   If LAST_UPDATE_DATE is 3 hours behind the time shown on screen, timestamps are stored in
   UTC and the report converts them to Asia/Riyadh.                                         */
SELECT DBTIMEZONE, SESSIONTIMEZONE, SYSTIMESTAMP, CURRENT_TIMESTAMP, SYSDATE
FROM   dual
;


/* ---------- C7  Purchase order change-order history for one PO ------------------------
   Pick a PO with at least two processed change orders. Expected: one PO_VERSIONS row per
   change order (CO_SEQUENCE 0 = original) and archive rows whose FROM_CO_SEQ / TO_CO_SEQ
   ranges chain together.                                                                  */
SELECT v.co_sequence, v.co_num, v.revision_num, v.change_order_status, v.originator_role,
       v.created_by, v.creation_date, v.submitted_date, v.approved_date, v.processed_date,
       SUBSTR(v.change_order_desc, 1, 200) AS change_order_desc
FROM   po_versions v
JOIN   po_headers_all h ON h.po_header_id = v.po_header_id
WHERE  h.segment1 = :P_TEST_PO_NUMBER
ORDER  BY v.co_sequence
;
SELECT 'HEADER' AS lvl, a.from_co_seq, a.to_co_seq, a.entity_co_disposition, a.entity_change_type_code,
       a.last_updated_by, a.last_update_date, CAST(NULL AS NUMBER) AS line_num
FROM   po_headers_archive_all a
JOIN   po_headers_all h ON h.po_header_id = a.po_header_id
WHERE  h.segment1 = :P_TEST_PO_NUMBER
UNION ALL
SELECT 'LINE', l.from_co_seq, l.to_co_seq, l.entity_co_disposition, l.entity_change_type_code,
       l.last_updated_by, l.last_update_date, l.line_num
FROM   po_lines_archive_all l
JOIN   po_headers_all h ON h.po_header_id = l.po_header_id
WHERE  h.segment1 = :P_TEST_PO_NUMBER
ORDER  BY 1, 8, 2
;


/* ---------- C8  User names: do WHO columns match PER_USERS.USERNAME? ------------------
   Expected: almost every value MATCHED. Unmatched values are usually integration or process
   users; they are shown as recorded.                                                       */
SELECT w.username,
       CASE WHEN u.user_id IS NULL THEN 'UNMATCHED' ELSE 'MATCHED' END AS match_status,
       w.rows_updated
FROM  (SELECT last_updated_by AS username, COUNT(*) AS rows_updated
       FROM   ap_invoices_all
       WHERE  last_update_date >= SYSDATE - 90
       GROUP  BY last_updated_by) w
LEFT JOIN per_users u ON u.username = w.username
ORDER  BY match_status DESC, w.rows_updated DESC
;


/* ---------- C9  Bank statement balance codes in use (for CLBD / OPBD) ------------------ */
SELECT balance_code, COUNT(*) AS cnt
FROM   ce_stmt_balances
GROUP  BY balance_code
ORDER  BY cnt DESC
;


/* ---------- C10 Reconciliation history action codes in use ---------------------------- */
SELECT recon_action, auto_recon_flag, COUNT(*) AS cnt,
       MIN(creation_date) AS first_seen, MAX(creation_date) AS last_seen
FROM   ce_recon_history
GROUP  BY recon_action, auto_recon_flag
ORDER  BY recon_action, auto_recon_flag
;


/* ---------- C11 Journal action log (GL_JE_ACTION_LOG) ----------------------------------
   Oracle documents it as the history of a journal batch (user, role, date and time of each
   action). Read its columns from the pod first; a second query on the actions in use is
   written once the column names are known.                                                */
SELECT column_name, data_type, data_length
FROM   all_tab_columns
WHERE  table_name = 'GL_JE_ACTION_LOG'
ORDER  BY column_id
;


/* ---------- C12 Attachment entity names used per document type ------------------------
   Gives the ENTITY_NAME values for attachments on invoices, payments, transactions,
   receipts, statements, journals, assets and requisition lines.                           */
SELECT fad.entity_name, COUNT(*) AS attachments, MAX(fad.creation_date) AS latest
FROM   fnd_attached_documents fad
WHERE  REGEXP_LIKE(fad.entity_name, '^(AP|AR|RA|CE|FA|GL|PO|POR|IBY)_')
GROUP  BY fad.entity_name
ORDER  BY fad.entity_name
;


/* ---------- C13 Scheduled-process history visible to BI Publisher? -------------------
   Needed only for Assets "Calculate Depreciation" / "Close Period" (Q13).                 */
SELECT owner, object_name, object_type
FROM   all_objects
WHERE  object_name LIKE 'ESS\_REQUEST%' ESCAPE '\'
ORDER  BY object_name
;


/* ---------- C14 Asset transaction types in use ---------------------------------------- */
SELECT transaction_type_code, transaction_subtype, COUNT(*) AS cnt,
       MIN(date_effective) AS first_seen, MAX(date_effective) AS last_seen
FROM   fa_transaction_headers
GROUP  BY transaction_type_code, transaction_subtype
ORDER  BY cnt DESC
;


/* ---------- C15 PO change-order statuses and archive dispositions in use -------------- */
SELECT 'PO_VERSIONS.CHANGE_ORDER_STATUS' AS item, change_order_status AS value, COUNT(*) AS cnt
FROM   po_versions
GROUP  BY change_order_status
UNION ALL
SELECT 'PO_HEADERS_ARCHIVE_ALL.ENTITY_CO_DISPOSITION', entity_co_disposition, COUNT(*)
FROM   po_headers_archive_all
GROUP  BY entity_co_disposition
UNION ALL
SELECT 'PO_LINES_ARCHIVE_ALL.ENTITY_CHANGE_TYPE_CODE', entity_change_type_code, COUNT(*)
FROM   po_lines_archive_all
GROUP  BY entity_change_type_code
ORDER  BY 1, 3 DESC
;
