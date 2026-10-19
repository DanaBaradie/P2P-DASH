WITH
prm AS (
  SELECT CAST(FROM_TZ(CAST(NVL(CAST(:P_FROM_DATE AS DATE), TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'Asia/Riyadh' AS DATE))) AS TIMESTAMP), 'Asia/Riyadh') AT TIME ZONE 'UTC' AS TIMESTAMP)     AS from_utc,
         CAST(FROM_TZ(CAST(NVL(CAST(:P_TO_DATE AS DATE), TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'Asia/Riyadh' AS DATE))) + 1 AS TIMESTAMP), 'Asia/Riyadh') AT TIME ZONE 'UTC' AS TIMESTAMP) AS to_utc,
         CASE WHEN COALESCE(NULL, :P_PRODUCT) IS NULL OR 'Payables' IN (:P_PRODUCT) THEN 'Y' ELSE 'N' END AS run_ap,
         CASE WHEN COALESCE(NULL, :P_PRODUCT) IS NULL OR 'Purchase Orders' IN (:P_PRODUCT) THEN 'Y' ELSE 'N' END AS run_po,
         CASE WHEN COALESCE(NULL, :P_PRODUCT) IS NULL OR 'General Ledger' IN (:P_PRODUCT) THEN 'Y' ELSE 'N' END AS run_gl,
         CASE WHEN COALESCE(NULL, :P_PRODUCT) IS NULL OR 'Fixed Assets' IN (:P_PRODUCT) THEN 'Y' ELSE 'N' END AS run_fa,
         CASE WHEN COALESCE(NULL, :P_PRODUCT) IS NULL OR 'Receivables' IN (:P_PRODUCT) THEN 'Y' ELSE 'N' END AS run_ar,
         CASE WHEN COALESCE(NULL, :P_PRODUCT) IS NULL OR 'Bank Statements' IN (:P_PRODUCT) THEN 'Y' ELSE 'N' END AS run_ce,
         CASE WHEN COALESCE(NULL, :P_PRODUCT) IS NULL OR 'Purchase Requisitions' IN (:P_PRODUCT) THEN 'Y' ELSE 'N' END AS run_pr,
         CASE WHEN COALESCE(NULL, :P_PRODUCT) IS NULL OR 'Payments' IN (:P_PRODUCT) THEN 'Y' ELSE 'N' END AS run_pay
  FROM   dual
),
inv_keys AS (
  SELECT DISTINCT a.invoice_id
  FROM   ap_invoices_all_ a
  CROSS JOIN prm
  WHERE  prm.run_ap = 'Y'
  AND    a.audit_action_type_ IN ('UPDATE', 'DELETE')
  AND    a.last_update_date >= prm.from_utc
  AND    a.last_update_date <  prm.to_utc
),
inv_seq AS (
  SELECT a.invoice_id,
         a.last_update_date,
         a.last_updated_by,
         a.audit_action_type_,
         a.invoice_num AS audit_invoice_num,
         a.vendor_id,
         a.vendor_site_id,
         a.batch_id,
         a.invoice_num,
         a.invoice_amount,
         a.description,
         a.invoice_date,
         a.terms_id,
         a.terms_date,
         a.requester_id,
         a.uri_check_digit,
         a.bank_charge_bearer,
         a.settlement_priority,
         a.delivery_channel_code,
         a.pay_group_lookup_code,
         a.payment_reason_code,
         a.payment_reason_comments,
         a.exclusive_payment_flag,
         a.amount_applicable_to_discount,
         a.remittance_message1,
         a.remittance_message2,
         a.remittance_message3,
         ROW_NUMBER() OVER (PARTITION BY a.invoice_id
                            ORDER BY a.last_update_date, a.object_version_number) AS rn
  FROM   ap_invoices_all_ a
  WHERE  (a.invoice_id) IN (SELECT invoice_id FROM inv_keys)
),
inv_chg AS (
  SELECT n.invoice_id AS invoice_id,
         n.last_update_date AS change_ts,
         n.last_updated_by  AS username,
         CAST(NULL AS VARCHAR2(60)) AS level_lbl,
         0 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.vendor_id)
           WHEN 2 THEN TO_CHAR(o.vendor_site_id)
           WHEN 3 THEN TO_CHAR(o.batch_id)
           WHEN 4 THEN o.invoice_num
           WHEN 5 THEN TO_CHAR(o.invoice_amount, 'FM999,999,999,990.00')
           WHEN 6 THEN o.description
           WHEN 7 THEN TO_CHAR(o.invoice_date, 'DD/MM/YYYY')
           WHEN 8 THEN TO_CHAR(o.terms_id)
           WHEN 9 THEN TO_CHAR(o.terms_date, 'DD/MM/YYYY')
           WHEN 10 THEN TO_CHAR(o.requester_id)
           WHEN 11 THEN o.uri_check_digit
           WHEN 12 THEN o.bank_charge_bearer
           WHEN 13 THEN o.settlement_priority
           WHEN 14 THEN o.delivery_channel_code
           WHEN 15 THEN o.pay_group_lookup_code
           WHEN 16 THEN o.payment_reason_code
           WHEN 17 THEN o.payment_reason_comments
           WHEN 18 THEN o.exclusive_payment_flag
           WHEN 19 THEN TO_CHAR(o.amount_applicable_to_discount, 'FM999,999,999,990.00')
           WHEN 20 THEN o.remittance_message1
           WHEN 21 THEN o.remittance_message2
           WHEN 22 THEN o.remittance_message3
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.vendor_id)
           WHEN 2 THEN TO_CHAR(n.vendor_site_id)
           WHEN 3 THEN TO_CHAR(n.batch_id)
           WHEN 4 THEN n.invoice_num
           WHEN 5 THEN TO_CHAR(n.invoice_amount, 'FM999,999,999,990.00')
           WHEN 6 THEN n.description
           WHEN 7 THEN TO_CHAR(n.invoice_date, 'DD/MM/YYYY')
           WHEN 8 THEN TO_CHAR(n.terms_id)
           WHEN 9 THEN TO_CHAR(n.terms_date, 'DD/MM/YYYY')
           WHEN 10 THEN TO_CHAR(n.requester_id)
           WHEN 11 THEN n.uri_check_digit
           WHEN 12 THEN n.bank_charge_bearer
           WHEN 13 THEN n.settlement_priority
           WHEN 14 THEN n.delivery_channel_code
           WHEN 15 THEN n.pay_group_lookup_code
           WHEN 16 THEN n.payment_reason_code
           WHEN 17 THEN n.payment_reason_comments
           WHEN 18 THEN n.exclusive_payment_flag
           WHEN 19 THEN TO_CHAR(n.amount_applicable_to_discount, 'FM999,999,999,990.00')
           WHEN 20 THEN n.remittance_message1
           WHEN 21 THEN n.remittance_message2
           WHEN 22 THEN n.remittance_message3
         END AS new_raw,
         'N' AS is_event,
         CASE WHEN o.audit_action_type_ = 'HISTORY' THEN n.last_update_date ELSE o.last_update_date END AS old_written_ts,
         ea.enabled_ts
  FROM   inv_seq n
  CROSS JOIN prm
  LEFT JOIN inv_seq o
         ON o.invoice_id = n.invoice_id
        AND o.rn = n.rn - 1
  CROSS JOIN (
    SELECT 1 AS ord, 'Supplier' AS lbl, 'SUPPLIER' AS dec_type, 'VENDOR_ID' AS col_name FROM dual
    UNION ALL SELECT 2, 'Supplier Site', 'SITE', 'VENDOR_SITE_ID' FROM dual
    UNION ALL SELECT 3, 'Invoice Group', 'BATCH', 'BATCH_ID' FROM dual
    UNION ALL SELECT 4, 'Number', 'RAW', 'INVOICE_NUM' FROM dual
    UNION ALL SELECT 5, 'Amount', 'RAW', 'INVOICE_AMOUNT' FROM dual
    UNION ALL SELECT 6, 'Description', 'RAW', 'DESCRIPTION' FROM dual
    UNION ALL SELECT 7, 'Date', 'RAW', 'INVOICE_DATE' FROM dual
    UNION ALL SELECT 8, 'Payment Terms', 'TERMS', 'TERMS_ID' FROM dual
    UNION ALL SELECT 9, 'Terms Date', 'RAW', 'TERMS_DATE' FROM dual
    UNION ALL SELECT 10, 'Requester', 'PERSON', 'REQUESTER_ID' FROM dual
    UNION ALL SELECT 11, 'Unique Remittance Identifier Check Digit', 'RAW', 'URI_CHECK_DIGIT' FROM dual
    UNION ALL SELECT 12, 'Bank Charge Bearer', 'RAW', 'BANK_CHARGE_BEARER' FROM dual
    UNION ALL SELECT 13, 'Settlement Priority', 'RAW', 'SETTLEMENT_PRIORITY' FROM dual
    UNION ALL SELECT 14, 'Delivery Channel', 'RAW', 'DELIVERY_CHANNEL_CODE' FROM dual
    UNION ALL SELECT 15, 'Pay Group', 'RAW', 'PAY_GROUP_LOOKUP_CODE' FROM dual
    UNION ALL SELECT 16, 'Payment Reason', 'RAW', 'PAYMENT_REASON_CODE' FROM dual
    UNION ALL SELECT 17, 'Payment Reason Comments', 'RAW', 'PAYMENT_REASON_COMMENTS' FROM dual
    UNION ALL SELECT 18, 'Pay Alone', 'YN', 'EXCLUSIVE_PAYMENT_FLAG' FROM dual
    UNION ALL SELECT 19, 'Discountable Amount', 'RAW', 'AMOUNT_APPLICABLE_TO_DISCOUNT' FROM dual
    UNION ALL SELECT 20, 'Remittance Message 1', 'RAW', 'REMITTANCE_MESSAGE1' FROM dual
    UNION ALL SELECT 21, 'Remittance Message 2', 'RAW', 'REMITTANCE_MESSAGE2' FROM dual
    UNION ALL SELECT 22, 'Remittance Message 3', 'RAW', 'REMITTANCE_MESSAGE3' FROM dual
  ) f
  LEFT JOIN (SELECT faa.column_name, MAX(faa.last_update_date) AS enabled_ts
             FROM   fnd_audit_attributes faa
             WHERE  faa.table_name = 'AP_INVOICES_ALL'
             AND    faa.enabled_flag = 'Y'
             GROUP  BY faa.column_name) ea
         ON ea.column_name = f.col_name
  WHERE  n.audit_action_type_ = 'UPDATE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
  UNION ALL
  SELECT n.invoice_id,
         n.last_update_date,
         n.last_updated_by,
         CAST(NULL AS VARCHAR2(60)),
         0,
         0,
         'Deleted',
         'RAW',
         NULL,
         NULL,
         'Y',
         CAST(NULL AS TIMESTAMP),
         CAST(NULL AS TIMESTAMP)
  FROM   inv_seq n
  CROSS JOIN prm
  WHERE  n.audit_action_type_ = 'DELETE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
),
lin_keys AS (
  SELECT DISTINCT a.invoice_id, a.line_number
  FROM   ap_invoice_lines_all_ a
  CROSS JOIN prm
  WHERE  prm.run_ap = 'Y'
  AND    a.audit_action_type_ IN ('UPDATE', 'DELETE')
  AND    a.last_update_date >= prm.from_utc
  AND    a.last_update_date <  prm.to_utc
),
lin_seq AS (
  SELECT a.invoice_id, a.line_number,
         a.last_update_date,
         a.last_updated_by,
         a.audit_action_type_,
         a.line_type_lookup_code,
         a.amount,
         a.distribution_set_id,
         a.default_dist_ccid,
         a.accounting_date,
         a.description,
         a.requester_id,
         a.tax_classification_code,
         a.ship_to_location_id,
         a.awt_group_id,
         a.ship_from_location_id,
         a.final_discharge_location_id,
         a.trx_business_category,
         a.intended_use_classif_id,
         a.prod_fc_categ_id,
         a.user_defined_fisc_class,
         a.product_type,
         a.product_category,
         a.assessable_value,
         a.control_amount,
         a.po_header_id,
         a.quantity_invoiced,
         a.unit_price,
         a.unit_meas_lookup_code,
         a.inventory_item_id,
         a.def_acctg_start_date,
         a.def_acctg_end_date,
         a.def_acctg_accrual_ccid,
         a.type_1099,
         a.assets_tracking_flag,
         a.manufacturer,
         a.model_number,
         a.serial_number,
         a.asset_book_type_code,
         a.corrected_inv_id,
         a.pjc_project_id,
         ROW_NUMBER() OVER (PARTITION BY a.invoice_id, a.line_number
                            ORDER BY a.last_update_date, a.object_version_number) AS rn
  FROM   ap_invoice_lines_all_ a
  WHERE  (a.invoice_id, a.line_number) IN (SELECT invoice_id, line_number FROM lin_keys)
),
lin_chg AS (
  SELECT n.invoice_id AS invoice_id,
         n.last_update_date AS change_ts,
         n.last_updated_by  AS username,
         'Line ' || n.line_number || ' > ' AS level_lbl,
         n.line_number AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN o.line_type_lookup_code
           WHEN 2 THEN TO_CHAR(o.amount, 'FM999,999,999,990.00')
           WHEN 3 THEN TO_CHAR(o.distribution_set_id)
           WHEN 4 THEN TO_CHAR(o.default_dist_ccid)
           WHEN 5 THEN TO_CHAR(o.accounting_date, 'DD/MM/YYYY')
           WHEN 6 THEN o.description
           WHEN 7 THEN TO_CHAR(o.requester_id)
           WHEN 8 THEN o.tax_classification_code
           WHEN 9 THEN TO_CHAR(o.ship_to_location_id)
           WHEN 10 THEN TO_CHAR(o.awt_group_id)
           WHEN 11 THEN TO_CHAR(o.ship_from_location_id)
           WHEN 12 THEN TO_CHAR(o.final_discharge_location_id)
           WHEN 13 THEN o.trx_business_category
           WHEN 14 THEN TO_CHAR(o.intended_use_classif_id)
           WHEN 15 THEN TO_CHAR(o.prod_fc_categ_id)
           WHEN 16 THEN o.user_defined_fisc_class
           WHEN 17 THEN o.product_type
           WHEN 18 THEN o.product_category
           WHEN 19 THEN TO_CHAR(o.assessable_value, 'FM999,999,999,990.00')
           WHEN 20 THEN TO_CHAR(o.control_amount, 'FM999,999,999,990.00')
           WHEN 21 THEN TO_CHAR(o.po_header_id)
           WHEN 22 THEN TO_CHAR(o.quantity_invoiced)
           WHEN 23 THEN TO_CHAR(o.unit_price)
           WHEN 24 THEN o.unit_meas_lookup_code
           WHEN 25 THEN TO_CHAR(o.inventory_item_id)
           WHEN 26 THEN TO_CHAR(o.def_acctg_start_date, 'DD/MM/YYYY')
           WHEN 27 THEN TO_CHAR(o.def_acctg_end_date, 'DD/MM/YYYY')
           WHEN 28 THEN TO_CHAR(o.def_acctg_accrual_ccid)
           WHEN 29 THEN o.type_1099
           WHEN 30 THEN o.assets_tracking_flag
           WHEN 31 THEN o.manufacturer
           WHEN 32 THEN o.model_number
           WHEN 33 THEN o.serial_number
           WHEN 34 THEN o.asset_book_type_code
           WHEN 35 THEN TO_CHAR(o.corrected_inv_id)
           WHEN 36 THEN TO_CHAR(o.pjc_project_id)
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN n.line_type_lookup_code
           WHEN 2 THEN TO_CHAR(n.amount, 'FM999,999,999,990.00')
           WHEN 3 THEN TO_CHAR(n.distribution_set_id)
           WHEN 4 THEN TO_CHAR(n.default_dist_ccid)
           WHEN 5 THEN TO_CHAR(n.accounting_date, 'DD/MM/YYYY')
           WHEN 6 THEN n.description
           WHEN 7 THEN TO_CHAR(n.requester_id)
           WHEN 8 THEN n.tax_classification_code
           WHEN 9 THEN TO_CHAR(n.ship_to_location_id)
           WHEN 10 THEN TO_CHAR(n.awt_group_id)
           WHEN 11 THEN TO_CHAR(n.ship_from_location_id)
           WHEN 12 THEN TO_CHAR(n.final_discharge_location_id)
           WHEN 13 THEN n.trx_business_category
           WHEN 14 THEN TO_CHAR(n.intended_use_classif_id)
           WHEN 15 THEN TO_CHAR(n.prod_fc_categ_id)
           WHEN 16 THEN n.user_defined_fisc_class
           WHEN 17 THEN n.product_type
           WHEN 18 THEN n.product_category
           WHEN 19 THEN TO_CHAR(n.assessable_value, 'FM999,999,999,990.00')
           WHEN 20 THEN TO_CHAR(n.control_amount, 'FM999,999,999,990.00')
           WHEN 21 THEN TO_CHAR(n.po_header_id)
           WHEN 22 THEN TO_CHAR(n.quantity_invoiced)
           WHEN 23 THEN TO_CHAR(n.unit_price)
           WHEN 24 THEN n.unit_meas_lookup_code
           WHEN 25 THEN TO_CHAR(n.inventory_item_id)
           WHEN 26 THEN TO_CHAR(n.def_acctg_start_date, 'DD/MM/YYYY')
           WHEN 27 THEN TO_CHAR(n.def_acctg_end_date, 'DD/MM/YYYY')
           WHEN 28 THEN TO_CHAR(n.def_acctg_accrual_ccid)
           WHEN 29 THEN n.type_1099
           WHEN 30 THEN n.assets_tracking_flag
           WHEN 31 THEN n.manufacturer
           WHEN 32 THEN n.model_number
           WHEN 33 THEN n.serial_number
           WHEN 34 THEN n.asset_book_type_code
           WHEN 35 THEN TO_CHAR(n.corrected_inv_id)
           WHEN 36 THEN TO_CHAR(n.pjc_project_id)
         END AS new_raw,
         'N' AS is_event,
         CASE WHEN o.audit_action_type_ = 'HISTORY' THEN n.last_update_date ELSE o.last_update_date END AS old_written_ts,
         ea.enabled_ts
  FROM   lin_seq n
  CROSS JOIN prm
  LEFT JOIN lin_seq o
         ON o.invoice_id = n.invoice_id AND o.line_number = n.line_number
        AND o.rn = n.rn - 1
  CROSS JOIN (
    SELECT 1 AS ord, 'Type' AS lbl, 'LINETYPE' AS dec_type, 'LINE_TYPE_LOOKUP_CODE' AS col_name FROM dual
    UNION ALL SELECT 2, 'Amount', 'RAW', 'AMOUNT' FROM dual
    UNION ALL SELECT 3, 'Distribution Set', 'DSET', 'DISTRIBUTION_SET_ID' FROM dual
    UNION ALL SELECT 4, 'Distribution Combination', 'ACCOUNT', 'DEFAULT_DIST_CCID' FROM dual
    UNION ALL SELECT 5, 'Accounting Date', 'RAW', 'ACCOUNTING_DATE' FROM dual
    UNION ALL SELECT 6, 'Description', 'RAW', 'DESCRIPTION' FROM dual
    UNION ALL SELECT 7, 'Requester', 'PERSON', 'REQUESTER_ID' FROM dual
    UNION ALL SELECT 8, 'Tax Classification', 'RAW', 'TAX_CLASSIFICATION_CODE' FROM dual
    UNION ALL SELECT 9, 'Ship-to Location', 'LOC', 'SHIP_TO_LOCATION_ID' FROM dual
    UNION ALL SELECT 10, 'Withholding', 'AWT', 'AWT_GROUP_ID' FROM dual
    UNION ALL SELECT 11, 'Ship-from Location', 'LOC', 'SHIP_FROM_LOCATION_ID' FROM dual
    UNION ALL SELECT 12, 'Location of Final Discharge', 'LOC', 'FINAL_DISCHARGE_LOCATION_ID' FROM dual
    UNION ALL SELECT 13, 'Transaction Business Category', 'RAW', 'TRX_BUSINESS_CATEGORY' FROM dual
    UNION ALL SELECT 14, 'Intended Use', 'FC', 'INTENDED_USE_CLASSIF_ID' FROM dual
    UNION ALL SELECT 15, 'Product Fiscal Classification', 'RAW', 'PROD_FC_CATEG_ID' FROM dual
    UNION ALL SELECT 16, 'User-Defined Fiscal Classification', 'RAW', 'USER_DEFINED_FISC_CLASS' FROM dual
    UNION ALL SELECT 17, 'Product Type', 'RAW', 'PRODUCT_TYPE' FROM dual
    UNION ALL SELECT 18, 'Product Category', 'RAW', 'PRODUCT_CATEGORY' FROM dual
    UNION ALL SELECT 19, 'Assessable Value', 'RAW', 'ASSESSABLE_VALUE' FROM dual
    UNION ALL SELECT 20, 'Tax Control Amount', 'RAW', 'CONTROL_AMOUNT' FROM dual
    UNION ALL SELECT 21, 'Purchase Order Number', 'PO', 'PO_HEADER_ID' FROM dual
    UNION ALL SELECT 22, 'Quantity', 'RAW', 'QUANTITY_INVOICED' FROM dual
    UNION ALL SELECT 23, 'Unit Price', 'RAW', 'UNIT_PRICE' FROM dual
    UNION ALL SELECT 24, 'UOM', 'RAW', 'UNIT_MEAS_LOOKUP_CODE' FROM dual
    UNION ALL SELECT 25, 'Inventory Item', 'ITEM', 'INVENTORY_ITEM_ID' FROM dual
    UNION ALL SELECT 26, 'Start Date', 'RAW', 'DEF_ACCTG_START_DATE' FROM dual
    UNION ALL SELECT 27, 'End Date', 'RAW', 'DEF_ACCTG_END_DATE' FROM dual
    UNION ALL SELECT 28, 'Accrual Account', 'ACCOUNT', 'DEF_ACCTG_ACCRUAL_CCID' FROM dual
    UNION ALL SELECT 29, 'Income Tax Type', 'RAW', 'TYPE_1099' FROM dual
    UNION ALL SELECT 30, 'Track as Asset', 'YN', 'ASSETS_TRACKING_FLAG' FROM dual
    UNION ALL SELECT 31, 'Manufacturer', 'RAW', 'MANUFACTURER' FROM dual
    UNION ALL SELECT 32, 'Model', 'RAW', 'MODEL_NUMBER' FROM dual
    UNION ALL SELECT 33, 'Serial Number', 'RAW', 'SERIAL_NUMBER' FROM dual
    UNION ALL SELECT 34, 'Book', 'RAW', 'ASSET_BOOK_TYPE_CODE' FROM dual
    UNION ALL SELECT 35, 'Corrected Invoice Number', 'INVOICE', 'CORRECTED_INV_ID' FROM dual
    UNION ALL SELECT 36, 'Project Number', 'RAW', 'PJC_PROJECT_ID' FROM dual
  ) f
  LEFT JOIN (SELECT faa.column_name, MAX(faa.last_update_date) AS enabled_ts
             FROM   fnd_audit_attributes faa
             WHERE  faa.table_name = 'AP_INVOICE_LINES_ALL'
             AND    faa.enabled_flag = 'Y'
             GROUP  BY faa.column_name) ea
         ON ea.column_name = f.col_name
  WHERE  n.audit_action_type_ = 'UPDATE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
  UNION ALL
  SELECT n.invoice_id,
         n.last_update_date,
         n.last_updated_by,
         'Line ' || n.line_number || ' > ',
         n.line_number,
         0,
         'Deleted',
         'RAW',
         NULL,
         NULL,
         'Y',
         CAST(NULL AS TIMESTAMP),
         CAST(NULL AS TIMESTAMP)
  FROM   lin_seq n
  CROSS JOIN prm
  WHERE  n.audit_action_type_ = 'DELETE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
),
dst_keys AS (
  SELECT DISTINCT a.invoice_distribution_id
  FROM   ap_invoice_distributions_all_ a
  CROSS JOIN prm
  WHERE  prm.run_ap = 'Y'
  AND    a.audit_action_type_ IN ('UPDATE', 'DELETE')
  AND    a.last_update_date >= prm.from_utc
  AND    a.last_update_date <  prm.to_utc
),
dst_seq AS (
  SELECT a.invoice_distribution_id,
         a.last_update_date,
         a.last_updated_by,
         a.audit_action_type_,
         a.dist_code_combination_id,
         ROW_NUMBER() OVER (PARTITION BY a.invoice_distribution_id
                            ORDER BY a.last_update_date, a.object_version_number) AS rn
  FROM   ap_invoice_distributions_all_ a
  WHERE  (a.invoice_distribution_id) IN (SELECT invoice_distribution_id FROM dst_keys)
),
dst_chg AS (
  SELECT (SELECT MAX(d.invoice_id) FROM ap_invoice_distributions_all d WHERE d.invoice_distribution_id = n.invoice_distribution_id) AS invoice_id,
         n.last_update_date AS change_ts,
         n.last_updated_by  AS username,
         'Line ' || NVL(TO_CHAR((SELECT MAX(d.invoice_line_number) FROM ap_invoice_distributions_all d WHERE d.invoice_distribution_id = n.invoice_distribution_id)), '?') || ' > Distribution ' || NVL(TO_CHAR((SELECT MAX(d.distribution_line_number) FROM ap_invoice_distributions_all d WHERE d.invoice_distribution_id = n.invoice_distribution_id)), '?') || ' > ' AS level_lbl,
         1000 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.dist_code_combination_id)
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.dist_code_combination_id)
         END AS new_raw,
         'N' AS is_event,
         CASE WHEN o.audit_action_type_ = 'HISTORY' THEN n.last_update_date ELSE o.last_update_date END AS old_written_ts,
         ea.enabled_ts
  FROM   dst_seq n
  CROSS JOIN prm
  LEFT JOIN dst_seq o
         ON o.invoice_distribution_id = n.invoice_distribution_id
        AND o.rn = n.rn - 1
  CROSS JOIN (
    SELECT 1 AS ord, 'Distribution Combination' AS lbl, 'ACCOUNT' AS dec_type, 'DIST_CODE_COMBINATION_ID' AS col_name FROM dual
  ) f
  LEFT JOIN (SELECT faa.column_name, MAX(faa.last_update_date) AS enabled_ts
             FROM   fnd_audit_attributes faa
             WHERE  faa.table_name = 'AP_INVOICE_DISTRIBUTIONS_ALL'
             AND    faa.enabled_flag = 'Y'
             GROUP  BY faa.column_name) ea
         ON ea.column_name = f.col_name
  WHERE  n.audit_action_type_ = 'UPDATE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
  UNION ALL
  SELECT (SELECT MAX(d.invoice_id) FROM ap_invoice_distributions_all d WHERE d.invoice_distribution_id = n.invoice_distribution_id),
         n.last_update_date,
         n.last_updated_by,
         'Line ' || NVL(TO_CHAR((SELECT MAX(d.invoice_line_number) FROM ap_invoice_distributions_all d WHERE d.invoice_distribution_id = n.invoice_distribution_id)), '?') || ' > Distribution ' || NVL(TO_CHAR((SELECT MAX(d.distribution_line_number) FROM ap_invoice_distributions_all d WHERE d.invoice_distribution_id = n.invoice_distribution_id)), '?') || ' > ',
         1000,
         0,
         'Deleted',
         'RAW',
         NULL,
         NULL,
         'Y',
         CAST(NULL AS TIMESTAMP),
         CAST(NULL AS TIMESTAMP)
  FROM   dst_seq n
  CROSS JOIN prm
  WHERE  n.audit_action_type_ = 'DELETE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
),
ins_keys AS (
  SELECT DISTINCT a.invoice_id, a.payment_num
  FROM   ap_payment_schedules_all_ a
  CROSS JOIN prm
  WHERE  prm.run_ap = 'Y'
  AND    a.audit_action_type_ IN ('UPDATE', 'DELETE')
  AND    a.last_update_date >= prm.from_utc
  AND    a.last_update_date <  prm.to_utc
),
ins_seq AS (
  SELECT a.invoice_id, a.payment_num,
         a.last_update_date,
         a.last_updated_by,
         a.audit_action_type_,
         a.due_date,
         a.gross_amount,
         a.payment_priority,
         a.payment_method_code,
         a.external_bank_account_id,
         a.iby_hold_reason,
         a.remittance_message1,
         a.remittance_message2,
         a.remittance_message3,
         ROW_NUMBER() OVER (PARTITION BY a.invoice_id, a.payment_num
                            ORDER BY a.last_update_date, a.object_version_number) AS rn
  FROM   ap_payment_schedules_all_ a
  WHERE  (a.invoice_id, a.payment_num) IN (SELECT invoice_id, payment_num FROM ins_keys)
),
ins_chg AS (
  SELECT n.invoice_id AS invoice_id,
         n.last_update_date AS change_ts,
         n.last_updated_by  AS username,
         'Installment ' || n.payment_num || ' > ' AS level_lbl,
         2000 + n.payment_num AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.due_date, 'DD/MM/YYYY')
           WHEN 2 THEN TO_CHAR(o.gross_amount, 'FM999,999,999,990.00')
           WHEN 3 THEN TO_CHAR(o.payment_priority)
           WHEN 4 THEN o.payment_method_code
           WHEN 5 THEN TO_CHAR(o.external_bank_account_id)
           WHEN 6 THEN o.iby_hold_reason
           WHEN 7 THEN o.remittance_message1
           WHEN 8 THEN o.remittance_message2
           WHEN 9 THEN o.remittance_message3
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.due_date, 'DD/MM/YYYY')
           WHEN 2 THEN TO_CHAR(n.gross_amount, 'FM999,999,999,990.00')
           WHEN 3 THEN TO_CHAR(n.payment_priority)
           WHEN 4 THEN n.payment_method_code
           WHEN 5 THEN TO_CHAR(n.external_bank_account_id)
           WHEN 6 THEN n.iby_hold_reason
           WHEN 7 THEN n.remittance_message1
           WHEN 8 THEN n.remittance_message2
           WHEN 9 THEN n.remittance_message3
         END AS new_raw,
         'N' AS is_event,
         CASE WHEN o.audit_action_type_ = 'HISTORY' THEN n.last_update_date ELSE o.last_update_date END AS old_written_ts,
         ea.enabled_ts
  FROM   ins_seq n
  CROSS JOIN prm
  LEFT JOIN ins_seq o
         ON o.invoice_id = n.invoice_id AND o.payment_num = n.payment_num
        AND o.rn = n.rn - 1
  CROSS JOIN (
    SELECT 1 AS ord, 'Due Date' AS lbl, 'RAW' AS dec_type, 'DUE_DATE' AS col_name FROM dual
    UNION ALL SELECT 2, 'Gross Amount', 'RAW', 'GROSS_AMOUNT' FROM dual
    UNION ALL SELECT 3, 'Payment Priority', 'RAW', 'PAYMENT_PRIORITY' FROM dual
    UNION ALL SELECT 4, 'Payment Method', 'PAYMETHOD', 'PAYMENT_METHOD_CODE' FROM dual
    UNION ALL SELECT 5, 'Bank Account', 'BANKACCT', 'EXTERNAL_BANK_ACCOUNT_ID' FROM dual
    UNION ALL SELECT 6, 'Hold Reason', 'RAW', 'IBY_HOLD_REASON' FROM dual
    UNION ALL SELECT 7, 'Remittance Message 1', 'RAW', 'REMITTANCE_MESSAGE1' FROM dual
    UNION ALL SELECT 8, 'Remittance Message 2', 'RAW', 'REMITTANCE_MESSAGE2' FROM dual
    UNION ALL SELECT 9, 'Remittance Message 3', 'RAW', 'REMITTANCE_MESSAGE3' FROM dual
  ) f
  LEFT JOIN (SELECT faa.column_name, MAX(faa.last_update_date) AS enabled_ts
             FROM   fnd_audit_attributes faa
             WHERE  faa.table_name = 'AP_PAYMENT_SCHEDULES_ALL'
             AND    faa.enabled_flag = 'Y'
             GROUP  BY faa.column_name) ea
         ON ea.column_name = f.col_name
  WHERE  n.audit_action_type_ = 'UPDATE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
  UNION ALL
  SELECT n.invoice_id,
         n.last_update_date,
         n.last_updated_by,
         'Installment ' || n.payment_num || ' > ',
         2000 + n.payment_num,
         0,
         'Deleted',
         'RAW',
         NULL,
         NULL,
         'Y',
         CAST(NULL AS TIMESTAMP),
         CAST(NULL AS TIMESTAMP)
  FROM   ins_seq n
  CROSS JOIN prm
  WHERE  n.audit_action_type_ = 'DELETE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
),
hld_chg AS (
  SELECT h.invoice_id,
         h.hold_date AS change_ts,
         NVL(h.held_by, h.created_by) AS username,
         CAST(NULL AS VARCHAR2(60)) AS level_lbl,
         3000 AS sub_ord,
         1 AS ord,
         'Hold placed' AS lbl,
         'RAW' AS dec_type,
         CAST(NULL AS VARCHAR2(400)) AS old_raw,
         h.hold_lookup_code || NVL2(h.hold_reason, ' - ' || h.hold_reason, NULL) AS new_raw,
         'Y' AS is_event,
         CAST(NULL AS TIMESTAMP) AS old_written_ts,
         CAST(NULL AS TIMESTAMP) AS enabled_ts
  FROM   ap_holds_all h
  CROSS JOIN prm
  WHERE  prm.run_ap = 'Y'
  AND    h.hold_date >= prm.from_utc
  AND    h.hold_date <  prm.to_utc
  UNION ALL
  SELECT h.invoice_id,
         h.last_update_date,
         h.last_updated_by,
         CAST(NULL AS VARCHAR2(60)),
         3000,
         2,
         'Hold released',
         'RAW',
         h.hold_lookup_code || NVL2(h.hold_reason, ' - ' || h.hold_reason, NULL),
         h.release_lookup_code || NVL2(h.release_reason, ' - ' || h.release_reason, NULL),
         'Y',
         CAST(NULL AS TIMESTAMP),
         CAST(NULL AS TIMESTAMP)
  FROM   ap_holds_all h
  CROSS JOIN prm
  WHERE  prm.run_ap = 'Y'
  AND    h.release_lookup_code IS NOT NULL
  AND    h.last_update_date >= prm.from_utc
  AND    h.last_update_date <  prm.to_utc
),
ap_all AS (
  SELECT invoice_id, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM inv_chg
  UNION ALL
  SELECT invoice_id, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM lin_chg
  UNION ALL
  SELECT invoice_id, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM dst_chg
  UNION ALL
  SELECT invoice_id, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM ins_chg
  UNION ALL
  SELECT invoice_id, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM hld_chg
),
ap_ctx AS (
  SELECT i.invoice_id,
         i.invoice_num,
         INITCAP(REPLACE(AP_INVOICES_PKG.GET_APPROVAL_STATUS(i.invoice_id, i.invoice_amount,
                         i.payment_status_flag, i.invoice_type_lookup_code), '_', ' '))
           || ' / '
           || (SELECT CASE WHEN COUNT(*) = 0                              THEN 'Unaccounted'
                           WHEN MIN(NVL(d.posted_flag, 'N')) = 'Y'        THEN 'Accounted'
                           WHEN MAX(NVL(d.posted_flag, 'N')) = 'Y'        THEN 'Partially Accounted'
                           ELSE 'Unaccounted' END
               FROM   ap_invoice_distributions_all d
               WHERE  d.invoice_id = i.invoice_id)                       AS transaction_status,
         INITCAP(REPLACE(i.wfapproval_status, '_', ' '))                 AS approval_status,
         NVL(TO_CHAR(i.doc_sequence_value), i.voucher_num)              AS voucher_number
  FROM   ap_invoices_all i
  WHERE  i.invoice_id IN (SELECT invoice_id FROM ap_all)
),
ap_rows AS (
  SELECT 'Payables'                                                        AS product,
         c.username,
         c.change_ts,
         NVL(x.invoice_num,
             (SELECT MAX(s.audit_invoice_num) FROM inv_seq s WHERE s.invoice_id = c.invoice_id)) AS transaction_id,
         c.sub_ord,
         c.ord,
         c.level_lbl || c.lbl                                              AS action_performed,
         NVL(CASE c.dec_type
           WHEN 'SUPPLIER'  THEN (SELECT MAX(s.vendor_name) FROM poz_suppliers_v s WHERE s.vendor_id = TO_NUMBER(c.old_raw))
           WHEN 'SITE'      THEN (SELECT MAX(ss.vendor_site_code) FROM poz_supplier_sites_all_m ss WHERE ss.vendor_site_id = TO_NUMBER(c.old_raw))
           WHEN 'BATCH'     THEN (SELECT MAX(b.batch_name) FROM ap_batches_all b WHERE b.batch_id = TO_NUMBER(c.old_raw))
           WHEN 'TERMS'     THEN (SELECT MAX(t.name) FROM ap_terms_tl t WHERE t.term_id = TO_NUMBER(c.old_raw) AND t.language = USERENV('LANG'))
           WHEN 'PERSON'    THEN (SELECT MAX(p.display_name) FROM per_person_names_f p
                                  WHERE p.person_id = TO_NUMBER(c.old_raw) AND p.name_type = 'GLOBAL'
                                  AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date)
           WHEN 'LOC'       THEN (SELECT MAX(l.location_code) FROM hr_locations_all l WHERE l.location_id = TO_NUMBER(c.old_raw))
           WHEN 'AWT'       THEN (SELECT MAX(g.name) FROM ap_awt_groups g WHERE g.group_id = TO_NUMBER(c.old_raw))
           WHEN 'DSET'      THEN (SELECT MAX(ds.distribution_set_name) FROM ap_distribution_sets_all ds WHERE ds.distribution_set_id = TO_NUMBER(c.old_raw))
           WHEN 'ACCOUNT'   THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                   cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                   cc.segment9 || '-' || cc.segment10, '-'))
                                  FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.old_raw))
           WHEN 'PO'        THEN (SELECT MAX(ph.segment1) FROM po_headers_all ph WHERE ph.po_header_id = TO_NUMBER(c.old_raw))
           WHEN 'ITEM'      THEN (SELECT MAX(it.item_number) FROM egp_system_items_b it WHERE it.inventory_item_id = TO_NUMBER(c.old_raw))
           WHEN 'INVOICE'   THEN (SELECT MAX(ci.invoice_num) FROM ap_invoices_all ci WHERE ci.invoice_id = TO_NUMBER(c.old_raw))
           WHEN 'PAYMETHOD' THEN (SELECT MAX(pm.payment_method_name) FROM iby_payment_methods_tl pm
                                  WHERE pm.payment_method_code = c.old_raw AND pm.language = USERENV('LANG'))
           WHEN 'BANKACCT'  THEN (SELECT MAX(NVL(ba.masked_bank_account_num, ba.bank_account_num)) FROM iby_ext_bank_accounts ba
                                  WHERE ba.ext_bank_account_id = TO_NUMBER(c.old_raw))
           WHEN 'LINETYPE'  THEN (SELECT MAX(lc.displayed_field) FROM ap_lookup_codes lc
                                  WHERE lc.lookup_type = 'INVOICE LINE TYPE' AND lc.lookup_code = c.old_raw)
           WHEN 'FC'        THEN (SELECT MAX(fc.classification_code) FROM zx_fc_codes_b fc WHERE fc.classification_id = TO_NUMBER(c.old_raw))
           WHEN 'YN'        THEN DECODE(c.old_raw, 'Y', 'Yes', 'N', 'No', c.old_raw)
           WHEN 'ASSET'     THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = TO_NUMBER(c.old_raw))
           WHEN 'GLCAT'     THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.old_raw)
           WHEN 'REVMETH'   THEN DECODE(c.old_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.old_raw)
         END, c.old_raw) AS old_value,
         NVL(CASE c.dec_type
           WHEN 'SUPPLIER'  THEN (SELECT MAX(s.vendor_name) FROM poz_suppliers_v s WHERE s.vendor_id = TO_NUMBER(c.new_raw))
           WHEN 'SITE'      THEN (SELECT MAX(ss.vendor_site_code) FROM poz_supplier_sites_all_m ss WHERE ss.vendor_site_id = TO_NUMBER(c.new_raw))
           WHEN 'BATCH'     THEN (SELECT MAX(b.batch_name) FROM ap_batches_all b WHERE b.batch_id = TO_NUMBER(c.new_raw))
           WHEN 'TERMS'     THEN (SELECT MAX(t.name) FROM ap_terms_tl t WHERE t.term_id = TO_NUMBER(c.new_raw) AND t.language = USERENV('LANG'))
           WHEN 'PERSON'    THEN (SELECT MAX(p.display_name) FROM per_person_names_f p
                                  WHERE p.person_id = TO_NUMBER(c.new_raw) AND p.name_type = 'GLOBAL'
                                  AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date)
           WHEN 'LOC'       THEN (SELECT MAX(l.location_code) FROM hr_locations_all l WHERE l.location_id = TO_NUMBER(c.new_raw))
           WHEN 'AWT'       THEN (SELECT MAX(g.name) FROM ap_awt_groups g WHERE g.group_id = TO_NUMBER(c.new_raw))
           WHEN 'DSET'      THEN (SELECT MAX(ds.distribution_set_name) FROM ap_distribution_sets_all ds WHERE ds.distribution_set_id = TO_NUMBER(c.new_raw))
           WHEN 'ACCOUNT'   THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                   cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                   cc.segment9 || '-' || cc.segment10, '-'))
                                  FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.new_raw))
           WHEN 'PO'        THEN (SELECT MAX(ph.segment1) FROM po_headers_all ph WHERE ph.po_header_id = TO_NUMBER(c.new_raw))
           WHEN 'ITEM'      THEN (SELECT MAX(it.item_number) FROM egp_system_items_b it WHERE it.inventory_item_id = TO_NUMBER(c.new_raw))
           WHEN 'INVOICE'   THEN (SELECT MAX(ci.invoice_num) FROM ap_invoices_all ci WHERE ci.invoice_id = TO_NUMBER(c.new_raw))
           WHEN 'PAYMETHOD' THEN (SELECT MAX(pm.payment_method_name) FROM iby_payment_methods_tl pm
                                  WHERE pm.payment_method_code = c.new_raw AND pm.language = USERENV('LANG'))
           WHEN 'BANKACCT'  THEN (SELECT MAX(NVL(ba.masked_bank_account_num, ba.bank_account_num)) FROM iby_ext_bank_accounts ba
                                  WHERE ba.ext_bank_account_id = TO_NUMBER(c.new_raw))
           WHEN 'LINETYPE'  THEN (SELECT MAX(lc.displayed_field) FROM ap_lookup_codes lc
                                  WHERE lc.lookup_type = 'INVOICE LINE TYPE' AND lc.lookup_code = c.new_raw)
           WHEN 'FC'        THEN (SELECT MAX(fc.classification_code) FROM zx_fc_codes_b fc WHERE fc.classification_id = TO_NUMBER(c.new_raw))
           WHEN 'YN'        THEN DECODE(c.new_raw, 'Y', 'Yes', 'N', 'No', c.new_raw)
           WHEN 'ASSET'     THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = TO_NUMBER(c.new_raw))
           WHEN 'GLCAT'     THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.new_raw)
           WHEN 'REVMETH'   THEN DECODE(c.new_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.new_raw)
         END, c.new_raw) AS new_value,
         x.transaction_status,
         x.approval_status,
         x.voucher_number
  FROM   ap_all c
  LEFT JOIN ap_ctx x ON x.invoice_id = c.invoice_id
  WHERE  (c.is_event = 'Y' OR DECODE(c.old_raw, c.new_raw, 0, 1) = 1)
  AND    (c.old_raw IS NOT NULL OR c.old_written_ts IS NULL OR c.enabled_ts IS NULL
          OR c.old_written_ts >= c.enabled_ts)
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR c.username IN (:P_USERNAME))
),
po_pending AS (
  SELECT x.po_header_id, x.created_by, x.change_ts, x.approval_status
  FROM  (SELECT v.po_header_id,
                v.created_by,
                NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) AS change_ts,
                CASE WHEN NVL(v.rejected_flag, 'N') = 'Y'  THEN 'Rejected'
                     WHEN NVL(v.withdrawn_flag, 'N') = 'Y' THEN 'Withdrawn'
                     ELSE INITCAP(v.change_order_status) END AS approval_status,
                ROW_NUMBER() OVER (PARTITION BY v.po_header_id ORDER BY v.co_sequence DESC) AS rn
         FROM   po_versions v
         CROSS JOIN prm
         WHERE  prm.run_po = 'Y'
         AND    v.co_sequence > 0
         AND    v.change_order_status <> 'PROCESSED'
         AND    NVL(v.co_canceled_flag, 'N') = 'N') x
  WHERE  x.rn = 1
),
poh_arc AS (
  SELECT n.po_header_id AS po_header_id,
         v.created_by AS username,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) AS change_ts,
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y' THEN 'Rejected'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END AS approval_status,
         CAST(NULL AS VARCHAR2(80)) AS level_lbl,
         0 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.agent_id)
           WHEN 2 THEN TO_CHAR(o.vendor_id)
           WHEN 3 THEN TO_CHAR(o.vendor_site_id)
           WHEN 4 THEN TO_CHAR(o.vendor_contact_id)
           WHEN 5 THEN o.supplier_notif_method
           WHEN 6 THEN TO_CHAR(o.bill_to_location_id)
           WHEN 7 THEN TO_CHAR(o.ship_to_location_id)
           WHEN 8 THEN o.currency_code
           WHEN 9 THEN o.comments
           WHEN 10 THEN o.acceptance_required_flag
           WHEN 11 THEN TO_CHAR(o.terms_id)
           WHEN 12 THEN TRIM(o.carrier_id || ' ' || o.mode_of_transport)
           WHEN 13 THEN o.freight_terms_lookup_code
           WHEN 14 THEN o.fob_lookup_code
           WHEN 15 THEN o.confirming_order_flag
           WHEN 16 THEN o.attribute_category
           WHEN 17 THEN o.attribute1
           WHEN 18 THEN o.attribute2
           WHEN 19 THEN o.attribute3
           WHEN 20 THEN o.attribute4
           WHEN 21 THEN o.attribute5
           WHEN 22 THEN o.attribute6
           WHEN 23 THEN o.attribute7
           WHEN 24 THEN o.attribute8
           WHEN 25 THEN o.attribute9
           WHEN 26 THEN o.attribute10
           WHEN 27 THEN o.attribute11
           WHEN 28 THEN o.attribute12
           WHEN 29 THEN o.attribute13
           WHEN 30 THEN o.attribute14
           WHEN 31 THEN o.attribute15
           WHEN 32 THEN o.attribute16
           WHEN 33 THEN o.attribute17
           WHEN 34 THEN o.attribute18
           WHEN 35 THEN o.attribute19
           WHEN 36 THEN o.attribute20
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.agent_id)
           WHEN 2 THEN TO_CHAR(n.vendor_id)
           WHEN 3 THEN TO_CHAR(n.vendor_site_id)
           WHEN 4 THEN TO_CHAR(n.vendor_contact_id)
           WHEN 5 THEN n.supplier_notif_method
           WHEN 6 THEN TO_CHAR(n.bill_to_location_id)
           WHEN 7 THEN TO_CHAR(n.ship_to_location_id)
           WHEN 8 THEN n.currency_code
           WHEN 9 THEN n.comments
           WHEN 10 THEN n.acceptance_required_flag
           WHEN 11 THEN TO_CHAR(n.terms_id)
           WHEN 12 THEN TRIM(n.carrier_id || ' ' || n.mode_of_transport)
           WHEN 13 THEN n.freight_terms_lookup_code
           WHEN 14 THEN n.fob_lookup_code
           WHEN 15 THEN n.confirming_order_flag
           WHEN 16 THEN n.attribute_category
           WHEN 17 THEN n.attribute1
           WHEN 18 THEN n.attribute2
           WHEN 19 THEN n.attribute3
           WHEN 20 THEN n.attribute4
           WHEN 21 THEN n.attribute5
           WHEN 22 THEN n.attribute6
           WHEN 23 THEN n.attribute7
           WHEN 24 THEN n.attribute8
           WHEN 25 THEN n.attribute9
           WHEN 26 THEN n.attribute10
           WHEN 27 THEN n.attribute11
           WHEN 28 THEN n.attribute12
           WHEN 29 THEN n.attribute13
           WHEN 30 THEN n.attribute14
           WHEN 31 THEN n.attribute15
           WHEN 32 THEN n.attribute16
           WHEN 33 THEN n.attribute17
           WHEN 34 THEN n.attribute18
           WHEN 35 THEN n.attribute19
           WHEN 36 THEN n.attribute20
         END AS new_raw,
         'N' AS is_event
  FROM   po_headers_archive_all n
  JOIN   po_headers_archive_all o
         ON  o.po_header_id = n.po_header_id
        AND o.to_co_seq = n.from_co_seq
        AND NVL(o.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  JOIN   po_versions v
         ON  v.po_header_id = n.po_header_id
        AND v.co_sequence  = n.from_co_seq
  CROSS JOIN (
    SELECT 1 AS ord, 'Buyer' AS lbl, 'PERSON' AS dec_type FROM dual
    UNION ALL SELECT 2, 'Supplier', 'SUPPLIER' FROM dual
    UNION ALL SELECT 3, 'Supplier Site', 'SITE' FROM dual
    UNION ALL SELECT 4, 'Supplier Contact', 'RAW' FROM dual
    UNION ALL SELECT 5, 'Communication Method', 'RAW' FROM dual
    UNION ALL SELECT 6, 'Bill-to Location', 'LOC' FROM dual
    UNION ALL SELECT 7, 'Default Ship-to Location', 'LOC' FROM dual
    UNION ALL SELECT 8, 'Currency', 'RAW' FROM dual
    UNION ALL SELECT 9, 'Description', 'RAW' FROM dual
    UNION ALL SELECT 10, 'Required Acknowledgment', 'RAW' FROM dual
    UNION ALL SELECT 11, 'Payment Terms', 'TERMS' FROM dual
    UNION ALL SELECT 12, 'Shipping Method', 'RAW' FROM dual
    UNION ALL SELECT 13, 'Freight Terms', 'RAW' FROM dual
    UNION ALL SELECT 14, 'FOB', 'RAW' FROM dual
    UNION ALL SELECT 15, 'Confirming Order', 'YN' FROM dual
    UNION ALL SELECT 16, 'Additional Information > Context', 'RAW' FROM dual
    UNION ALL SELECT 17, 'Additional Information > Attribute 1', 'RAW' FROM dual
    UNION ALL SELECT 18, 'Additional Information > Attribute 2', 'RAW' FROM dual
    UNION ALL SELECT 19, 'Additional Information > Attribute 3', 'RAW' FROM dual
    UNION ALL SELECT 20, 'Additional Information > Attribute 4', 'RAW' FROM dual
    UNION ALL SELECT 21, 'Additional Information > Attribute 5', 'RAW' FROM dual
    UNION ALL SELECT 22, 'Additional Information > Attribute 6', 'RAW' FROM dual
    UNION ALL SELECT 23, 'Additional Information > Attribute 7', 'RAW' FROM dual
    UNION ALL SELECT 24, 'Additional Information > Attribute 8', 'RAW' FROM dual
    UNION ALL SELECT 25, 'Additional Information > Attribute 9', 'RAW' FROM dual
    UNION ALL SELECT 26, 'Additional Information > Attribute 10', 'RAW' FROM dual
    UNION ALL SELECT 27, 'Additional Information > Attribute 11', 'RAW' FROM dual
    UNION ALL SELECT 28, 'Additional Information > Attribute 12', 'RAW' FROM dual
    UNION ALL SELECT 29, 'Additional Information > Attribute 13', 'RAW' FROM dual
    UNION ALL SELECT 30, 'Additional Information > Attribute 14', 'RAW' FROM dual
    UNION ALL SELECT 31, 'Additional Information > Attribute 15', 'RAW' FROM dual
    UNION ALL SELECT 32, 'Additional Information > Attribute 16', 'RAW' FROM dual
    UNION ALL SELECT 33, 'Additional Information > Attribute 17', 'RAW' FROM dual
    UNION ALL SELECT 34, 'Additional Information > Attribute 18', 'RAW' FROM dual
    UNION ALL SELECT 35, 'Additional Information > Attribute 19', 'RAW' FROM dual
    UNION ALL SELECT 36, 'Additional Information > Attribute 20', 'RAW' FROM dual
  ) f
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    n.from_co_seq > 0
  AND    NVL(n.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
  UNION ALL
  SELECT n.po_header_id,
         v.created_by,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date),
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y' THEN 'Rejected'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END,
         CAST(NULL AS VARCHAR2(80)),
         0,
         0,
         'Purchase order added',
         'RAW',
         CAST(NULL AS VARCHAR2(400)),
         TO_CHAR(n.agent_id),
         'Y'
  FROM   po_headers_archive_all n
  JOIN   po_versions v
         ON  v.po_header_id = n.po_header_id
        AND v.co_sequence  = n.from_co_seq
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    n.from_co_seq > 0
  AND    n.entity_change_type_code = 'I'
  AND    NVL(n.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  AND    NOT EXISTS (SELECT 1 FROM po_headers_archive_all o WHERE o.po_header_id = n.po_header_id AND o.to_co_seq = n.from_co_seq)
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
),
poh_dft AS (
  SELECT pv.po_header_id,
         pv.created_by AS username,
         pv.change_ts,
         pv.approval_status,
         CAST(NULL AS VARCHAR2(80)) AS level_lbl,
         0 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.agent_id)
           WHEN 2 THEN TO_CHAR(o.vendor_id)
           WHEN 3 THEN TO_CHAR(o.vendor_site_id)
           WHEN 4 THEN TO_CHAR(o.vendor_contact_id)
           WHEN 5 THEN o.supplier_notif_method
           WHEN 6 THEN TO_CHAR(o.bill_to_location_id)
           WHEN 7 THEN TO_CHAR(o.ship_to_location_id)
           WHEN 8 THEN o.currency_code
           WHEN 9 THEN o.comments
           WHEN 10 THEN o.acceptance_required_flag
           WHEN 11 THEN TO_CHAR(o.terms_id)
           WHEN 12 THEN TRIM(o.carrier_id || ' ' || o.mode_of_transport)
           WHEN 13 THEN o.freight_terms_lookup_code
           WHEN 14 THEN o.fob_lookup_code
           WHEN 15 THEN o.confirming_order_flag
           WHEN 16 THEN o.attribute_category
           WHEN 17 THEN o.attribute1
           WHEN 18 THEN o.attribute2
           WHEN 19 THEN o.attribute3
           WHEN 20 THEN o.attribute4
           WHEN 21 THEN o.attribute5
           WHEN 22 THEN o.attribute6
           WHEN 23 THEN o.attribute7
           WHEN 24 THEN o.attribute8
           WHEN 25 THEN o.attribute9
           WHEN 26 THEN o.attribute10
           WHEN 27 THEN o.attribute11
           WHEN 28 THEN o.attribute12
           WHEN 29 THEN o.attribute13
           WHEN 30 THEN o.attribute14
           WHEN 31 THEN o.attribute15
           WHEN 32 THEN o.attribute16
           WHEN 33 THEN o.attribute17
           WHEN 34 THEN o.attribute18
           WHEN 35 THEN o.attribute19
           WHEN 36 THEN o.attribute20
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.agent_id)
           WHEN 2 THEN TO_CHAR(n.vendor_id)
           WHEN 3 THEN TO_CHAR(n.vendor_site_id)
           WHEN 4 THEN TO_CHAR(n.vendor_contact_id)
           WHEN 5 THEN n.supplier_notif_method
           WHEN 6 THEN TO_CHAR(n.bill_to_location_id)
           WHEN 7 THEN TO_CHAR(n.ship_to_location_id)
           WHEN 8 THEN n.currency_code
           WHEN 9 THEN n.comments
           WHEN 10 THEN n.acceptance_required_flag
           WHEN 11 THEN TO_CHAR(n.terms_id)
           WHEN 12 THEN TRIM(n.carrier_id || ' ' || n.mode_of_transport)
           WHEN 13 THEN n.freight_terms_lookup_code
           WHEN 14 THEN n.fob_lookup_code
           WHEN 15 THEN n.confirming_order_flag
           WHEN 16 THEN n.attribute_category
           WHEN 17 THEN n.attribute1
           WHEN 18 THEN n.attribute2
           WHEN 19 THEN n.attribute3
           WHEN 20 THEN n.attribute4
           WHEN 21 THEN n.attribute5
           WHEN 22 THEN n.attribute6
           WHEN 23 THEN n.attribute7
           WHEN 24 THEN n.attribute8
           WHEN 25 THEN n.attribute9
           WHEN 26 THEN n.attribute10
           WHEN 27 THEN n.attribute11
           WHEN 28 THEN n.attribute12
           WHEN 29 THEN n.attribute13
           WHEN 30 THEN n.attribute14
           WHEN 31 THEN n.attribute15
           WHEN 32 THEN n.attribute16
           WHEN 33 THEN n.attribute17
           WHEN 34 THEN n.attribute18
           WHEN 35 THEN n.attribute19
           WHEN 36 THEN n.attribute20
         END AS new_raw,
         CASE WHEN o.po_header_id IS NULL THEN 'Y' ELSE 'N' END AS is_new
  FROM   po_headers_draft_all n
  JOIN   po_pending pv ON pv.po_header_id = n.po_header_id
  LEFT JOIN po_headers_all o ON o.po_header_id = n.po_header_id
  CROSS JOIN (
    SELECT 1 AS ord, 'Buyer' AS lbl, 'PERSON' AS dec_type FROM dual
    UNION ALL SELECT 2, 'Supplier', 'SUPPLIER' FROM dual
    UNION ALL SELECT 3, 'Supplier Site', 'SITE' FROM dual
    UNION ALL SELECT 4, 'Supplier Contact', 'RAW' FROM dual
    UNION ALL SELECT 5, 'Communication Method', 'RAW' FROM dual
    UNION ALL SELECT 6, 'Bill-to Location', 'LOC' FROM dual
    UNION ALL SELECT 7, 'Default Ship-to Location', 'LOC' FROM dual
    UNION ALL SELECT 8, 'Currency', 'RAW' FROM dual
    UNION ALL SELECT 9, 'Description', 'RAW' FROM dual
    UNION ALL SELECT 10, 'Required Acknowledgment', 'RAW' FROM dual
    UNION ALL SELECT 11, 'Payment Terms', 'TERMS' FROM dual
    UNION ALL SELECT 12, 'Shipping Method', 'RAW' FROM dual
    UNION ALL SELECT 13, 'Freight Terms', 'RAW' FROM dual
    UNION ALL SELECT 14, 'FOB', 'RAW' FROM dual
    UNION ALL SELECT 15, 'Confirming Order', 'YN' FROM dual
    UNION ALL SELECT 16, 'Additional Information > Context', 'RAW' FROM dual
    UNION ALL SELECT 17, 'Additional Information > Attribute 1', 'RAW' FROM dual
    UNION ALL SELECT 18, 'Additional Information > Attribute 2', 'RAW' FROM dual
    UNION ALL SELECT 19, 'Additional Information > Attribute 3', 'RAW' FROM dual
    UNION ALL SELECT 20, 'Additional Information > Attribute 4', 'RAW' FROM dual
    UNION ALL SELECT 21, 'Additional Information > Attribute 5', 'RAW' FROM dual
    UNION ALL SELECT 22, 'Additional Information > Attribute 6', 'RAW' FROM dual
    UNION ALL SELECT 23, 'Additional Information > Attribute 7', 'RAW' FROM dual
    UNION ALL SELECT 24, 'Additional Information > Attribute 8', 'RAW' FROM dual
    UNION ALL SELECT 25, 'Additional Information > Attribute 9', 'RAW' FROM dual
    UNION ALL SELECT 26, 'Additional Information > Attribute 10', 'RAW' FROM dual
    UNION ALL SELECT 27, 'Additional Information > Attribute 11', 'RAW' FROM dual
    UNION ALL SELECT 28, 'Additional Information > Attribute 12', 'RAW' FROM dual
    UNION ALL SELECT 29, 'Additional Information > Attribute 13', 'RAW' FROM dual
    UNION ALL SELECT 30, 'Additional Information > Attribute 14', 'RAW' FROM dual
    UNION ALL SELECT 31, 'Additional Information > Attribute 15', 'RAW' FROM dual
    UNION ALL SELECT 32, 'Additional Information > Attribute 16', 'RAW' FROM dual
    UNION ALL SELECT 33, 'Additional Information > Attribute 17', 'RAW' FROM dual
    UNION ALL SELECT 34, 'Additional Information > Attribute 18', 'RAW' FROM dual
    UNION ALL SELECT 35, 'Additional Information > Attribute 19', 'RAW' FROM dual
    UNION ALL SELECT 36, 'Additional Information > Attribute 20', 'RAW' FROM dual
  ) f
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    pv.change_ts >= prm.from_utc
  AND    pv.change_ts <  prm.to_utc
),
pol_arc AS (
  SELECT (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id) AS po_header_id,
         v.created_by AS username,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) AS change_ts,
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y' THEN 'Rejected'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END AS approval_status,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)), '?') || ' > ' AS level_lbl,
         NVL((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id), 0) * 10000 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.quantity)
           WHEN 2 THEN o.uom_code
           WHEN 3 THEN TO_CHAR(o.unit_price)
           WHEN 4 THEN o.item_revision
           WHEN 5 THEN o.item_description
           WHEN 6 THEN o.vendor_product_num
           WHEN 7 THEN o.negotiated_by_preparer_flag
           WHEN 8 THEN TO_CHAR(o.contract_id)
           WHEN 9 THEN TO_CHAR(o.from_header_id)
           WHEN 10 THEN TO_CHAR(o.hazard_class_id)
           WHEN 11 THEN TO_CHAR(o.un_number_id)
           WHEN 12 THEN o.note_to_vendor
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.quantity)
           WHEN 2 THEN n.uom_code
           WHEN 3 THEN TO_CHAR(n.unit_price)
           WHEN 4 THEN n.item_revision
           WHEN 5 THEN n.item_description
           WHEN 6 THEN n.vendor_product_num
           WHEN 7 THEN n.negotiated_by_preparer_flag
           WHEN 8 THEN TO_CHAR(n.contract_id)
           WHEN 9 THEN TO_CHAR(n.from_header_id)
           WHEN 10 THEN TO_CHAR(n.hazard_class_id)
           WHEN 11 THEN TO_CHAR(n.un_number_id)
           WHEN 12 THEN n.note_to_vendor
         END AS new_raw,
         'N' AS is_event
  FROM   po_lines_archive_all n
  JOIN   po_lines_archive_all o
         ON  o.po_line_id = n.po_line_id
        AND o.to_co_seq = n.from_co_seq
        AND NVL(o.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  JOIN   po_versions v
         ON  v.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)
        AND v.co_sequence  = n.from_co_seq
  CROSS JOIN (
    SELECT 1 AS ord, 'Quantity' AS lbl, 'RAW' AS dec_type FROM dual
    UNION ALL SELECT 2, 'UOM', 'RAW' FROM dual
    UNION ALL SELECT 3, 'Price', 'RAW' FROM dual
    UNION ALL SELECT 4, 'Revision', 'RAW' FROM dual
    UNION ALL SELECT 5, 'Description', 'RAW' FROM dual
    UNION ALL SELECT 6, 'Supplier Item', 'RAW' FROM dual
    UNION ALL SELECT 7, 'Negotiated', 'YN' FROM dual
    UNION ALL SELECT 8, 'Agreement', 'PO' FROM dual
    UNION ALL SELECT 9, 'Source Agreement', 'PO' FROM dual
    UNION ALL SELECT 10, 'Hazard Class', 'RAW' FROM dual
    UNION ALL SELECT 11, 'UN Number', 'RAW' FROM dual
    UNION ALL SELECT 12, 'Note to Supplier', 'RAW' FROM dual
  ) f
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    n.from_co_seq > 0
  AND    NVL(n.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
  UNION ALL
  SELECT (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id),
         v.created_by,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date),
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y' THEN 'Rejected'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)), '?') || ' > ',
         NVL((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id), 0) * 10000,
         0,
         'Line added',
         'RAW',
         CAST(NULL AS VARCHAR2(400)),
         TO_CHAR(n.quantity),
         'Y'
  FROM   po_lines_archive_all n
  JOIN   po_versions v
         ON  v.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)
        AND v.co_sequence  = n.from_co_seq
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    n.from_co_seq > 0
  AND    n.entity_change_type_code = 'I'
  AND    NVL(n.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  AND    NOT EXISTS (SELECT 1 FROM po_lines_archive_all o WHERE o.po_line_id = n.po_line_id AND o.to_co_seq = n.from_co_seq)
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
),
pol_dft AS (
  SELECT pv.po_header_id,
         pv.created_by AS username,
         pv.change_ts,
         pv.approval_status,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)), '?') || ' > ' AS level_lbl,
         NVL((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id), 0) * 10000 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.quantity)
           WHEN 2 THEN o.uom_code
           WHEN 3 THEN TO_CHAR(o.unit_price)
           WHEN 4 THEN o.item_revision
           WHEN 5 THEN o.item_description
           WHEN 6 THEN o.vendor_product_num
           WHEN 7 THEN o.negotiated_by_preparer_flag
           WHEN 8 THEN TO_CHAR(o.contract_id)
           WHEN 9 THEN TO_CHAR(o.from_header_id)
           WHEN 10 THEN TO_CHAR(o.hazard_class_id)
           WHEN 11 THEN TO_CHAR(o.un_number_id)
           WHEN 12 THEN o.note_to_vendor
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.quantity)
           WHEN 2 THEN n.uom_code
           WHEN 3 THEN TO_CHAR(n.unit_price)
           WHEN 4 THEN n.item_revision
           WHEN 5 THEN n.item_description
           WHEN 6 THEN n.vendor_product_num
           WHEN 7 THEN n.negotiated_by_preparer_flag
           WHEN 8 THEN TO_CHAR(n.contract_id)
           WHEN 9 THEN TO_CHAR(n.from_header_id)
           WHEN 10 THEN TO_CHAR(n.hazard_class_id)
           WHEN 11 THEN TO_CHAR(n.un_number_id)
           WHEN 12 THEN n.note_to_vendor
         END AS new_raw,
         CASE WHEN o.po_line_id IS NULL THEN 'Y' ELSE 'N' END AS is_new
  FROM   po_lines_draft_all n
  JOIN   po_pending pv ON pv.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)
  LEFT JOIN po_lines_all o ON o.po_line_id = n.po_line_id
  CROSS JOIN (
    SELECT 1 AS ord, 'Quantity' AS lbl, 'RAW' AS dec_type FROM dual
    UNION ALL SELECT 2, 'UOM', 'RAW' FROM dual
    UNION ALL SELECT 3, 'Price', 'RAW' FROM dual
    UNION ALL SELECT 4, 'Revision', 'RAW' FROM dual
    UNION ALL SELECT 5, 'Description', 'RAW' FROM dual
    UNION ALL SELECT 6, 'Supplier Item', 'RAW' FROM dual
    UNION ALL SELECT 7, 'Negotiated', 'YN' FROM dual
    UNION ALL SELECT 8, 'Agreement', 'PO' FROM dual
    UNION ALL SELECT 9, 'Source Agreement', 'PO' FROM dual
    UNION ALL SELECT 10, 'Hazard Class', 'RAW' FROM dual
    UNION ALL SELECT 11, 'UN Number', 'RAW' FROM dual
    UNION ALL SELECT 12, 'Note to Supplier', 'RAW' FROM dual
  ) f
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    pv.change_ts >= prm.from_utc
  AND    pv.change_ts <  prm.to_utc
),
pos_arc AS (
  SELECT (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id) AS po_header_id,
         v.created_by AS username,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) AS change_ts,
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y' THEN 'Rejected'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END AS approval_status,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)), '?') || ' > Schedule ' || NVL(TO_CHAR(n.shipment_num), '?') || ' > ' AS level_lbl,
         NVL((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id), 0) * 10000 + NVL(n.shipment_num, 0) * 100 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.ship_to_location_id)
           WHEN 2 THEN TO_CHAR(o.need_by_date, 'DD/MM/YYYY')
           WHEN 3 THEN TO_CHAR(o.promised_date, 'DD/MM/YYYY')
           WHEN 4 THEN TRIM(o.carrier_id || ' ' || o.mode_of_transport || ' ' || o.service_level)
           WHEN 5 THEN TO_CHAR(o.quantity)
           WHEN 6 THEN o.country_of_origin_code
           WHEN 7 THEN TO_CHAR(o.days_early_receipt_allowed)
           WHEN 8 THEN TO_CHAR(o.days_late_receipt_allowed)
           WHEN 9 THEN o.receipt_days_exception_code
           WHEN 10 THEN o.enforce_ship_to_location_code
           WHEN 11 THEN TO_CHAR(o.receive_close_tolerance)
           WHEN 12 THEN TO_CHAR(o.qty_rcv_tolerance)
           WHEN 13 THEN o.qty_rcv_exception_code
           WHEN 14 THEN TO_CHAR(o.receiving_routing_id)
           WHEN 15 THEN o.match_option
           WHEN 16 THEN CASE WHEN o.inspection_required_flag = 'Y' THEN '4-Way' WHEN o.receipt_required_flag = 'Y' THEN '3-Way' ELSE '2-Way' END
           WHEN 17 THEN o.allow_substitute_receipts_flag
           WHEN 18 THEN TO_CHAR(o.invoice_close_tolerance)
           WHEN 19 THEN o.note_to_receiver
           WHEN 20 THEN TO_CHAR(o.assessable_value, 'FM999,999,999,990.00')
           WHEN 21 THEN o.input_tax_classification_code
           WHEN 22 THEN o.line_intended_use
           WHEN 23 THEN o.user_defined_fisc_class
           WHEN 24 THEN TO_CHAR(o.final_discharge_location_id)
           WHEN 25 THEN o.product_category
           WHEN 26 THEN o.product_fisc_classification
           WHEN 27 THEN o.product_type
           WHEN 28 THEN o.trx_business_category
           WHEN 29 THEN o.supplier_order_line_number
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.ship_to_location_id)
           WHEN 2 THEN TO_CHAR(n.need_by_date, 'DD/MM/YYYY')
           WHEN 3 THEN TO_CHAR(n.promised_date, 'DD/MM/YYYY')
           WHEN 4 THEN TRIM(n.carrier_id || ' ' || n.mode_of_transport || ' ' || n.service_level)
           WHEN 5 THEN TO_CHAR(n.quantity)
           WHEN 6 THEN n.country_of_origin_code
           WHEN 7 THEN TO_CHAR(n.days_early_receipt_allowed)
           WHEN 8 THEN TO_CHAR(n.days_late_receipt_allowed)
           WHEN 9 THEN n.receipt_days_exception_code
           WHEN 10 THEN n.enforce_ship_to_location_code
           WHEN 11 THEN TO_CHAR(n.receive_close_tolerance)
           WHEN 12 THEN TO_CHAR(n.qty_rcv_tolerance)
           WHEN 13 THEN n.qty_rcv_exception_code
           WHEN 14 THEN TO_CHAR(n.receiving_routing_id)
           WHEN 15 THEN n.match_option
           WHEN 16 THEN CASE WHEN n.inspection_required_flag = 'Y' THEN '4-Way' WHEN n.receipt_required_flag = 'Y' THEN '3-Way' ELSE '2-Way' END
           WHEN 17 THEN n.allow_substitute_receipts_flag
           WHEN 18 THEN TO_CHAR(n.invoice_close_tolerance)
           WHEN 19 THEN n.note_to_receiver
           WHEN 20 THEN TO_CHAR(n.assessable_value, 'FM999,999,999,990.00')
           WHEN 21 THEN n.input_tax_classification_code
           WHEN 22 THEN n.line_intended_use
           WHEN 23 THEN n.user_defined_fisc_class
           WHEN 24 THEN TO_CHAR(n.final_discharge_location_id)
           WHEN 25 THEN n.product_category
           WHEN 26 THEN n.product_fisc_classification
           WHEN 27 THEN n.product_type
           WHEN 28 THEN n.trx_business_category
           WHEN 29 THEN n.supplier_order_line_number
         END AS new_raw,
         'N' AS is_event
  FROM   po_line_locations_archive_all n
  JOIN   po_line_locations_archive_all o
         ON  o.line_location_id = n.line_location_id
        AND o.to_co_seq = n.from_co_seq
        AND NVL(o.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  JOIN   po_versions v
         ON  v.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)
        AND v.co_sequence  = n.from_co_seq
  CROSS JOIN (
    SELECT 1 AS ord, 'Location' AS lbl, 'LOC' AS dec_type FROM dual
    UNION ALL SELECT 2, 'Requested Delivery Date', 'RAW' FROM dual
    UNION ALL SELECT 3, 'Promised Delivery Date', 'RAW' FROM dual
    UNION ALL SELECT 4, 'Shipping Method', 'RAW' FROM dual
    UNION ALL SELECT 5, 'Quantity', 'RAW' FROM dual
    UNION ALL SELECT 6, 'Country of Origin', 'RAW' FROM dual
    UNION ALL SELECT 7, 'Early Receipt Tolerance in Days', 'RAW' FROM dual
    UNION ALL SELECT 8, 'Late Receipt Tolerance in Days', 'RAW' FROM dual
    UNION ALL SELECT 9, 'Receipt Date Exception Action', 'RAW' FROM dual
    UNION ALL SELECT 10, 'Ship-to Exception Action', 'RAW' FROM dual
    UNION ALL SELECT 11, 'Receipt Close Tolerance Percent', 'RAW' FROM dual
    UNION ALL SELECT 12, 'Overreceipt Tolerance Percent', 'RAW' FROM dual
    UNION ALL SELECT 13, 'Overreceipt Action', 'RAW' FROM dual
    UNION ALL SELECT 14, 'Receipt Routing', 'RAW' FROM dual
    UNION ALL SELECT 15, 'Invoice Match Option', 'RAW' FROM dual
    UNION ALL SELECT 16, 'Match Approval Level', 'RAW' FROM dual
    UNION ALL SELECT 17, 'Allow Substitute Receipts', 'YN' FROM dual
    UNION ALL SELECT 18, 'Invoice Close Tolerance Percent', 'RAW' FROM dual
    UNION ALL SELECT 19, 'Note to Receiver', 'RAW' FROM dual
    UNION ALL SELECT 20, 'Assessable Value', 'RAW' FROM dual
    UNION ALL SELECT 21, 'Tax Classification', 'RAW' FROM dual
    UNION ALL SELECT 22, 'Intended Use', 'RAW' FROM dual
    UNION ALL SELECT 23, 'User-Defined Fiscal Classification', 'RAW' FROM dual
    UNION ALL SELECT 24, 'Location of Final Discharge', 'LOC' FROM dual
    UNION ALL SELECT 25, 'Product Category', 'RAW' FROM dual
    UNION ALL SELECT 26, 'Product Fiscal Classification', 'RAW' FROM dual
    UNION ALL SELECT 27, 'Product Type', 'RAW' FROM dual
    UNION ALL SELECT 28, 'Transaction Business Category', 'RAW' FROM dual
    UNION ALL SELECT 29, 'Supplier Order Line', 'RAW' FROM dual
  ) f
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    n.from_co_seq > 0
  AND    NVL(n.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
  UNION ALL
  SELECT (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id),
         v.created_by,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date),
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y' THEN 'Rejected'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)), '?') || ' > Schedule ' || NVL(TO_CHAR(n.shipment_num), '?') || ' > ',
         NVL((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id), 0) * 10000 + NVL(n.shipment_num, 0) * 100,
         0,
         'Schedule added',
         'RAW',
         CAST(NULL AS VARCHAR2(400)),
         TO_CHAR(n.ship_to_location_id),
         'Y'
  FROM   po_line_locations_archive_all n
  JOIN   po_versions v
         ON  v.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)
        AND v.co_sequence  = n.from_co_seq
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    n.from_co_seq > 0
  AND    n.entity_change_type_code = 'I'
  AND    NVL(n.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  AND    NOT EXISTS (SELECT 1 FROM po_line_locations_archive_all o WHERE o.line_location_id = n.line_location_id AND o.to_co_seq = n.from_co_seq)
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
),
pos_dft AS (
  SELECT pv.po_header_id,
         pv.created_by AS username,
         pv.change_ts,
         pv.approval_status,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)), '?') || ' > Schedule ' || NVL(TO_CHAR(n.shipment_num), '?') || ' > ' AS level_lbl,
         NVL((SELECT MAX(bl.line_num) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id), 0) * 10000 + NVL(n.shipment_num, 0) * 100 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.ship_to_location_id)
           WHEN 2 THEN TO_CHAR(o.need_by_date, 'DD/MM/YYYY')
           WHEN 3 THEN TO_CHAR(o.promised_date, 'DD/MM/YYYY')
           WHEN 4 THEN TRIM(o.carrier_id || ' ' || o.mode_of_transport || ' ' || o.service_level)
           WHEN 5 THEN TO_CHAR(o.quantity)
           WHEN 6 THEN o.country_of_origin_code
           WHEN 7 THEN TO_CHAR(o.days_early_receipt_allowed)
           WHEN 8 THEN TO_CHAR(o.days_late_receipt_allowed)
           WHEN 9 THEN o.receipt_days_exception_code
           WHEN 10 THEN o.enforce_ship_to_location_code
           WHEN 11 THEN TO_CHAR(o.receive_close_tolerance)
           WHEN 12 THEN TO_CHAR(o.qty_rcv_tolerance)
           WHEN 13 THEN o.qty_rcv_exception_code
           WHEN 14 THEN TO_CHAR(o.receiving_routing_id)
           WHEN 15 THEN o.match_option
           WHEN 16 THEN CASE WHEN o.inspection_required_flag = 'Y' THEN '4-Way' WHEN o.receipt_required_flag = 'Y' THEN '3-Way' ELSE '2-Way' END
           WHEN 17 THEN o.allow_substitute_receipts_flag
           WHEN 18 THEN TO_CHAR(o.invoice_close_tolerance)
           WHEN 19 THEN o.note_to_receiver
           WHEN 20 THEN TO_CHAR(o.assessable_value, 'FM999,999,999,990.00')
           WHEN 21 THEN o.input_tax_classification_code
           WHEN 22 THEN o.line_intended_use
           WHEN 23 THEN o.user_defined_fisc_class
           WHEN 24 THEN TO_CHAR(o.final_discharge_location_id)
           WHEN 25 THEN o.product_category
           WHEN 26 THEN o.product_fisc_classification
           WHEN 27 THEN o.product_type
           WHEN 28 THEN o.trx_business_category
           WHEN 29 THEN o.supplier_order_line_number
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.ship_to_location_id)
           WHEN 2 THEN TO_CHAR(n.need_by_date, 'DD/MM/YYYY')
           WHEN 3 THEN TO_CHAR(n.promised_date, 'DD/MM/YYYY')
           WHEN 4 THEN TRIM(n.carrier_id || ' ' || n.mode_of_transport || ' ' || n.service_level)
           WHEN 5 THEN TO_CHAR(n.quantity)
           WHEN 6 THEN n.country_of_origin_code
           WHEN 7 THEN TO_CHAR(n.days_early_receipt_allowed)
           WHEN 8 THEN TO_CHAR(n.days_late_receipt_allowed)
           WHEN 9 THEN n.receipt_days_exception_code
           WHEN 10 THEN n.enforce_ship_to_location_code
           WHEN 11 THEN TO_CHAR(n.receive_close_tolerance)
           WHEN 12 THEN TO_CHAR(n.qty_rcv_tolerance)
           WHEN 13 THEN n.qty_rcv_exception_code
           WHEN 14 THEN TO_CHAR(n.receiving_routing_id)
           WHEN 15 THEN n.match_option
           WHEN 16 THEN CASE WHEN n.inspection_required_flag = 'Y' THEN '4-Way' WHEN n.receipt_required_flag = 'Y' THEN '3-Way' ELSE '2-Way' END
           WHEN 17 THEN n.allow_substitute_receipts_flag
           WHEN 18 THEN TO_CHAR(n.invoice_close_tolerance)
           WHEN 19 THEN n.note_to_receiver
           WHEN 20 THEN TO_CHAR(n.assessable_value, 'FM999,999,999,990.00')
           WHEN 21 THEN n.input_tax_classification_code
           WHEN 22 THEN n.line_intended_use
           WHEN 23 THEN n.user_defined_fisc_class
           WHEN 24 THEN TO_CHAR(n.final_discharge_location_id)
           WHEN 25 THEN n.product_category
           WHEN 26 THEN n.product_fisc_classification
           WHEN 27 THEN n.product_type
           WHEN 28 THEN n.trx_business_category
           WHEN 29 THEN n.supplier_order_line_number
         END AS new_raw,
         CASE WHEN o.line_location_id IS NULL THEN 'Y' ELSE 'N' END AS is_new
  FROM   po_line_locations_draft_all n
  JOIN   po_pending pv ON pv.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_lines_all bl WHERE bl.po_line_id = n.po_line_id)
  LEFT JOIN po_line_locations_all o ON o.line_location_id = n.line_location_id
  CROSS JOIN (
    SELECT 1 AS ord, 'Location' AS lbl, 'LOC' AS dec_type FROM dual
    UNION ALL SELECT 2, 'Requested Delivery Date', 'RAW' FROM dual
    UNION ALL SELECT 3, 'Promised Delivery Date', 'RAW' FROM dual
    UNION ALL SELECT 4, 'Shipping Method', 'RAW' FROM dual
    UNION ALL SELECT 5, 'Quantity', 'RAW' FROM dual
    UNION ALL SELECT 6, 'Country of Origin', 'RAW' FROM dual
    UNION ALL SELECT 7, 'Early Receipt Tolerance in Days', 'RAW' FROM dual
    UNION ALL SELECT 8, 'Late Receipt Tolerance in Days', 'RAW' FROM dual
    UNION ALL SELECT 9, 'Receipt Date Exception Action', 'RAW' FROM dual
    UNION ALL SELECT 10, 'Ship-to Exception Action', 'RAW' FROM dual
    UNION ALL SELECT 11, 'Receipt Close Tolerance Percent', 'RAW' FROM dual
    UNION ALL SELECT 12, 'Overreceipt Tolerance Percent', 'RAW' FROM dual
    UNION ALL SELECT 13, 'Overreceipt Action', 'RAW' FROM dual
    UNION ALL SELECT 14, 'Receipt Routing', 'RAW' FROM dual
    UNION ALL SELECT 15, 'Invoice Match Option', 'RAW' FROM dual
    UNION ALL SELECT 16, 'Match Approval Level', 'RAW' FROM dual
    UNION ALL SELECT 17, 'Allow Substitute Receipts', 'YN' FROM dual
    UNION ALL SELECT 18, 'Invoice Close Tolerance Percent', 'RAW' FROM dual
    UNION ALL SELECT 19, 'Note to Receiver', 'RAW' FROM dual
    UNION ALL SELECT 20, 'Assessable Value', 'RAW' FROM dual
    UNION ALL SELECT 21, 'Tax Classification', 'RAW' FROM dual
    UNION ALL SELECT 22, 'Intended Use', 'RAW' FROM dual
    UNION ALL SELECT 23, 'User-Defined Fiscal Classification', 'RAW' FROM dual
    UNION ALL SELECT 24, 'Location of Final Discharge', 'LOC' FROM dual
    UNION ALL SELECT 25, 'Product Category', 'RAW' FROM dual
    UNION ALL SELECT 26, 'Product Fiscal Classification', 'RAW' FROM dual
    UNION ALL SELECT 27, 'Product Type', 'RAW' FROM dual
    UNION ALL SELECT 28, 'Transaction Business Category', 'RAW' FROM dual
    UNION ALL SELECT 29, 'Supplier Order Line', 'RAW' FROM dual
  ) f
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    pv.change_ts >= prm.from_utc
  AND    pv.change_ts <  prm.to_utc
),
pod_arc AS (
  SELECT (SELECT MAX(bl.po_header_id) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id) AS po_header_id,
         v.created_by AS username,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) AS change_ts,
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y' THEN 'Rejected'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END AS approval_status,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id)), '?') || ' > Schedule ' || NVL(TO_CHAR((SELECT MAX(bll.shipment_num) FROM po_line_locations_all bll WHERE bll.line_location_id = n.line_location_id)), '?') || ' > Distribution ' || NVL(TO_CHAR(n.distribution_num), '?') || ' > ' AS level_lbl,
         NVL((SELECT MAX(bl.line_num) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id), 0) * 10000 + NVL((SELECT MAX(bll.shipment_num) FROM po_line_locations_all bll WHERE bll.line_location_id = n.line_location_id), 0) * 100 + NVL(n.distribution_num, 0) AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.deliver_to_person_id)
           WHEN 2 THEN TO_CHAR(o.deliver_to_location_id)
           WHEN 3 THEN TO_CHAR(o.code_combination_id)
           WHEN 4 THEN TO_CHAR(o.quantity_ordered)
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.deliver_to_person_id)
           WHEN 2 THEN TO_CHAR(n.deliver_to_location_id)
           WHEN 3 THEN TO_CHAR(n.code_combination_id)
           WHEN 4 THEN TO_CHAR(n.quantity_ordered)
         END AS new_raw,
         'N' AS is_event
  FROM   po_distributions_archive_all n
  JOIN   po_distributions_archive_all o
         ON  o.po_distribution_id = n.po_distribution_id
        AND o.to_co_seq = n.from_co_seq
        AND NVL(o.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  JOIN   po_versions v
         ON  v.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id)
        AND v.co_sequence  = n.from_co_seq
  CROSS JOIN (
    SELECT 1 AS ord, 'Requester' AS lbl, 'PERSON' AS dec_type FROM dual
    UNION ALL SELECT 2, 'Deliver-to Location', 'LOC' FROM dual
    UNION ALL SELECT 3, 'PO Charge Account', 'ACCOUNT' FROM dual
    UNION ALL SELECT 4, 'Quantity', 'RAW' FROM dual
  ) f
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    n.from_co_seq > 0
  AND    NVL(n.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
  UNION ALL
  SELECT (SELECT MAX(bl.po_header_id) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id),
         v.created_by,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date),
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y' THEN 'Rejected'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id)), '?') || ' > Schedule ' || NVL(TO_CHAR((SELECT MAX(bll.shipment_num) FROM po_line_locations_all bll WHERE bll.line_location_id = n.line_location_id)), '?') || ' > Distribution ' || NVL(TO_CHAR(n.distribution_num), '?') || ' > ',
         NVL((SELECT MAX(bl.line_num) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id), 0) * 10000 + NVL((SELECT MAX(bll.shipment_num) FROM po_line_locations_all bll WHERE bll.line_location_id = n.line_location_id), 0) * 100 + NVL(n.distribution_num, 0),
         0,
         'Distribution added',
         'RAW',
         CAST(NULL AS VARCHAR2(400)),
         TO_CHAR(n.deliver_to_person_id),
         'Y'
  FROM   po_distributions_archive_all n
  JOIN   po_versions v
         ON  v.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id)
        AND v.co_sequence  = n.from_co_seq
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    n.from_co_seq > 0
  AND    n.entity_change_type_code = 'I'
  AND    NVL(n.entity_co_disposition, 'X') NOT IN ('REJECTED', 'CANCELED')
  AND    NOT EXISTS (SELECT 1 FROM po_distributions_archive_all o WHERE o.po_distribution_id = n.po_distribution_id AND o.to_co_seq = n.from_co_seq)
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
),
pod_dft AS (
  SELECT pv.po_header_id,
         pv.created_by AS username,
         pv.change_ts,
         pv.approval_status,
         'Line ' || NVL(TO_CHAR((SELECT MAX(bl.line_num) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id)), '?') || ' > Schedule ' || NVL(TO_CHAR((SELECT MAX(bll.shipment_num) FROM po_line_locations_all bll WHERE bll.line_location_id = n.line_location_id)), '?') || ' > Distribution ' || NVL(TO_CHAR(n.distribution_num), '?') || ' > ' AS level_lbl,
         NVL((SELECT MAX(bl.line_num) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id), 0) * 10000 + NVL((SELECT MAX(bll.shipment_num) FROM po_line_locations_all bll WHERE bll.line_location_id = n.line_location_id), 0) * 100 + NVL(n.distribution_num, 0) AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.deliver_to_person_id)
           WHEN 2 THEN TO_CHAR(o.deliver_to_location_id)
           WHEN 3 THEN TO_CHAR(o.code_combination_id)
           WHEN 4 THEN TO_CHAR(o.quantity_ordered)
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.deliver_to_person_id)
           WHEN 2 THEN TO_CHAR(n.deliver_to_location_id)
           WHEN 3 THEN TO_CHAR(n.code_combination_id)
           WHEN 4 THEN TO_CHAR(n.quantity_ordered)
         END AS new_raw,
         CASE WHEN o.po_distribution_id IS NULL THEN 'Y' ELSE 'N' END AS is_new
  FROM   po_distributions_draft_all n
  JOIN   po_pending pv ON pv.po_header_id = (SELECT MAX(bl.po_header_id) FROM po_line_locations_all bll JOIN po_lines_all bl ON bl.po_line_id = bll.po_line_id WHERE bll.line_location_id = n.line_location_id)
  LEFT JOIN po_distributions_all o ON o.po_distribution_id = n.po_distribution_id
  CROSS JOIN (
    SELECT 1 AS ord, 'Requester' AS lbl, 'PERSON' AS dec_type FROM dual
    UNION ALL SELECT 2, 'Deliver-to Location', 'LOC' FROM dual
    UNION ALL SELECT 3, 'PO Charge Account', 'ACCOUNT' FROM dual
    UNION ALL SELECT 4, 'Quantity', 'RAW' FROM dual
  ) f
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    pv.change_ts >= prm.from_utc
  AND    pv.change_ts <  prm.to_utc
),
po_all AS (
  SELECT po_header_id, username, change_ts, approval_status, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event FROM poh_arc
  UNION ALL
  SELECT po_header_id, username, change_ts, approval_status, level_lbl, sub_ord,
         CASE WHEN is_new = 'Y' THEN 0 ELSE ord END,
         CASE WHEN is_new = 'Y' THEN 'Purchase order added' ELSE lbl END,
         dec_type,
         CASE WHEN is_new = 'Y' THEN NULL ELSE old_raw END,
         new_raw,
         is_new
  FROM   poh_dft
  WHERE  is_new = 'N' OR ord = 1
  UNION ALL
  SELECT po_header_id, username, change_ts, approval_status, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event FROM pol_arc
  UNION ALL
  SELECT po_header_id, username, change_ts, approval_status, level_lbl, sub_ord,
         CASE WHEN is_new = 'Y' THEN 0 ELSE ord END,
         CASE WHEN is_new = 'Y' THEN 'Line added' ELSE lbl END,
         dec_type,
         CASE WHEN is_new = 'Y' THEN NULL ELSE old_raw END,
         new_raw,
         is_new
  FROM   pol_dft
  WHERE  is_new = 'N' OR ord = 1
  UNION ALL
  SELECT po_header_id, username, change_ts, approval_status, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event FROM pos_arc
  UNION ALL
  SELECT po_header_id, username, change_ts, approval_status, level_lbl, sub_ord,
         CASE WHEN is_new = 'Y' THEN 0 ELSE ord END,
         CASE WHEN is_new = 'Y' THEN 'Schedule added' ELSE lbl END,
         dec_type,
         CASE WHEN is_new = 'Y' THEN NULL ELSE old_raw END,
         new_raw,
         is_new
  FROM   pos_dft
  WHERE  is_new = 'N' OR ord = 1
  UNION ALL
  SELECT po_header_id, username, change_ts, approval_status, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event FROM pod_arc
  UNION ALL
  SELECT po_header_id, username, change_ts, approval_status, level_lbl, sub_ord,
         CASE WHEN is_new = 'Y' THEN 0 ELSE ord END,
         CASE WHEN is_new = 'Y' THEN 'Distribution added' ELSE lbl END,
         dec_type,
         CASE WHEN is_new = 'Y' THEN NULL ELSE old_raw END,
         new_raw,
         is_new
  FROM   pod_dft
  WHERE  is_new = 'N' OR ord = 1
  UNION ALL
  SELECT v.po_header_id,
         v.created_by,
         NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date),
         CASE WHEN NVL(v.rejected_flag, 'N') = 'Y'  THEN 'Rejected'
              WHEN NVL(v.withdrawn_flag, 'N') = 'Y' THEN 'Withdrawn'
              WHEN v.change_order_status = 'PROCESSED' THEN 'Approved'
              ELSE INITCAP(v.change_order_status) END,
         CAST(NULL AS VARCHAR2(80)),
         -1,
         0,
         'Change Order Description',
         'RAW',
         CAST(NULL AS VARCHAR2(400)),
         SUBSTR(v.change_order_desc, 1, 400),
         'Y'
  FROM   po_versions v
  CROSS JOIN prm
  WHERE  prm.run_po = 'Y'
  AND    v.co_sequence > 0
  AND    v.change_order_desc IS NOT NULL
  AND    NVL(v.co_canceled_flag, 'N') = 'N'
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) >= prm.from_utc
  AND    NVL(CAST(v.submitted_date AS TIMESTAMP), v.creation_date) <  prm.to_utc
),
po_rows AS (
  SELECT 'Purchase Orders'                                                 AS product,
         c.username,
         c.change_ts,
         h.segment1                                                        AS transaction_id,
         c.sub_ord,
         c.ord,
         c.level_lbl || c.lbl                                              AS action_performed,
         NVL(CASE c.dec_type
           WHEN 'SUPPLIER'  THEN (SELECT MAX(s.vendor_name) FROM poz_suppliers_v s WHERE s.vendor_id = TO_NUMBER(c.old_raw))
           WHEN 'SITE'      THEN (SELECT MAX(ss.vendor_site_code) FROM poz_supplier_sites_all_m ss WHERE ss.vendor_site_id = TO_NUMBER(c.old_raw))
           WHEN 'BATCH'     THEN (SELECT MAX(b.batch_name) FROM ap_batches_all b WHERE b.batch_id = TO_NUMBER(c.old_raw))
           WHEN 'TERMS'     THEN (SELECT MAX(t.name) FROM ap_terms_tl t WHERE t.term_id = TO_NUMBER(c.old_raw) AND t.language = USERENV('LANG'))
           WHEN 'PERSON'    THEN (SELECT MAX(p.display_name) FROM per_person_names_f p
                                  WHERE p.person_id = TO_NUMBER(c.old_raw) AND p.name_type = 'GLOBAL'
                                  AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date)
           WHEN 'LOC'       THEN (SELECT MAX(l.location_code) FROM hr_locations_all l WHERE l.location_id = TO_NUMBER(c.old_raw))
           WHEN 'AWT'       THEN (SELECT MAX(g.name) FROM ap_awt_groups g WHERE g.group_id = TO_NUMBER(c.old_raw))
           WHEN 'DSET'      THEN (SELECT MAX(ds.distribution_set_name) FROM ap_distribution_sets_all ds WHERE ds.distribution_set_id = TO_NUMBER(c.old_raw))
           WHEN 'ACCOUNT'   THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                   cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                   cc.segment9 || '-' || cc.segment10, '-'))
                                  FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.old_raw))
           WHEN 'PO'        THEN (SELECT MAX(ph.segment1) FROM po_headers_all ph WHERE ph.po_header_id = TO_NUMBER(c.old_raw))
           WHEN 'ITEM'      THEN (SELECT MAX(it.item_number) FROM egp_system_items_b it WHERE it.inventory_item_id = TO_NUMBER(c.old_raw))
           WHEN 'INVOICE'   THEN (SELECT MAX(ci.invoice_num) FROM ap_invoices_all ci WHERE ci.invoice_id = TO_NUMBER(c.old_raw))
           WHEN 'PAYMETHOD' THEN (SELECT MAX(pm.payment_method_name) FROM iby_payment_methods_tl pm
                                  WHERE pm.payment_method_code = c.old_raw AND pm.language = USERENV('LANG'))
           WHEN 'BANKACCT'  THEN (SELECT MAX(NVL(ba.masked_bank_account_num, ba.bank_account_num)) FROM iby_ext_bank_accounts ba
                                  WHERE ba.ext_bank_account_id = TO_NUMBER(c.old_raw))
           WHEN 'LINETYPE'  THEN (SELECT MAX(lc.displayed_field) FROM ap_lookup_codes lc
                                  WHERE lc.lookup_type = 'INVOICE LINE TYPE' AND lc.lookup_code = c.old_raw)
           WHEN 'FC'        THEN (SELECT MAX(fc.classification_code) FROM zx_fc_codes_b fc WHERE fc.classification_id = TO_NUMBER(c.old_raw))
           WHEN 'YN'        THEN DECODE(c.old_raw, 'Y', 'Yes', 'N', 'No', c.old_raw)
           WHEN 'ASSET'     THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = TO_NUMBER(c.old_raw))
           WHEN 'GLCAT'     THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.old_raw)
           WHEN 'REVMETH'   THEN DECODE(c.old_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.old_raw)
         END, c.old_raw) AS old_value,
         NVL(CASE c.dec_type
           WHEN 'SUPPLIER'  THEN (SELECT MAX(s.vendor_name) FROM poz_suppliers_v s WHERE s.vendor_id = TO_NUMBER(c.new_raw))
           WHEN 'SITE'      THEN (SELECT MAX(ss.vendor_site_code) FROM poz_supplier_sites_all_m ss WHERE ss.vendor_site_id = TO_NUMBER(c.new_raw))
           WHEN 'BATCH'     THEN (SELECT MAX(b.batch_name) FROM ap_batches_all b WHERE b.batch_id = TO_NUMBER(c.new_raw))
           WHEN 'TERMS'     THEN (SELECT MAX(t.name) FROM ap_terms_tl t WHERE t.term_id = TO_NUMBER(c.new_raw) AND t.language = USERENV('LANG'))
           WHEN 'PERSON'    THEN (SELECT MAX(p.display_name) FROM per_person_names_f p
                                  WHERE p.person_id = TO_NUMBER(c.new_raw) AND p.name_type = 'GLOBAL'
                                  AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date)
           WHEN 'LOC'       THEN (SELECT MAX(l.location_code) FROM hr_locations_all l WHERE l.location_id = TO_NUMBER(c.new_raw))
           WHEN 'AWT'       THEN (SELECT MAX(g.name) FROM ap_awt_groups g WHERE g.group_id = TO_NUMBER(c.new_raw))
           WHEN 'DSET'      THEN (SELECT MAX(ds.distribution_set_name) FROM ap_distribution_sets_all ds WHERE ds.distribution_set_id = TO_NUMBER(c.new_raw))
           WHEN 'ACCOUNT'   THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                   cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                   cc.segment9 || '-' || cc.segment10, '-'))
                                  FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.new_raw))
           WHEN 'PO'        THEN (SELECT MAX(ph.segment1) FROM po_headers_all ph WHERE ph.po_header_id = TO_NUMBER(c.new_raw))
           WHEN 'ITEM'      THEN (SELECT MAX(it.item_number) FROM egp_system_items_b it WHERE it.inventory_item_id = TO_NUMBER(c.new_raw))
           WHEN 'INVOICE'   THEN (SELECT MAX(ci.invoice_num) FROM ap_invoices_all ci WHERE ci.invoice_id = TO_NUMBER(c.new_raw))
           WHEN 'PAYMETHOD' THEN (SELECT MAX(pm.payment_method_name) FROM iby_payment_methods_tl pm
                                  WHERE pm.payment_method_code = c.new_raw AND pm.language = USERENV('LANG'))
           WHEN 'BANKACCT'  THEN (SELECT MAX(NVL(ba.masked_bank_account_num, ba.bank_account_num)) FROM iby_ext_bank_accounts ba
                                  WHERE ba.ext_bank_account_id = TO_NUMBER(c.new_raw))
           WHEN 'LINETYPE'  THEN (SELECT MAX(lc.displayed_field) FROM ap_lookup_codes lc
                                  WHERE lc.lookup_type = 'INVOICE LINE TYPE' AND lc.lookup_code = c.new_raw)
           WHEN 'FC'        THEN (SELECT MAX(fc.classification_code) FROM zx_fc_codes_b fc WHERE fc.classification_id = TO_NUMBER(c.new_raw))
           WHEN 'YN'        THEN DECODE(c.new_raw, 'Y', 'Yes', 'N', 'No', c.new_raw)
           WHEN 'ASSET'     THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = TO_NUMBER(c.new_raw))
           WHEN 'GLCAT'     THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.new_raw)
           WHEN 'REVMETH'   THEN DECODE(c.new_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.new_raw)
         END, c.new_raw) AS new_value,
         INITCAP(REPLACE(h.document_status, '_', ' '))                     AS transaction_status,
         c.approval_status,
         CAST(NULL AS VARCHAR2(60))                                        AS voucher_number
  FROM   po_all c
  LEFT JOIN po_headers_all h ON h.po_header_id = c.po_header_id
  WHERE  (c.is_event = 'Y' OR DECODE(c.old_raw, c.new_raw, 0, 1) = 1)
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR c.username IN (:P_USERNAME))
)
,
glb_keys AS (
  SELECT DISTINCT a.je_batch_id
  FROM   gl_je_batches_ a
  CROSS JOIN prm
  WHERE  prm.run_gl = 'Y'
  AND    a.audit_action_type_ IN ('UPDATE', 'DELETE')
  AND    a.last_update_date >= prm.from_utc
  AND    a.last_update_date <  prm.to_utc
),
glb_seq AS (
  SELECT a.je_batch_id,
         a.last_update_date,
         a.last_updated_by,
         a.audit_action_type_,
         a.name AS audit_name,
         a.name,
         a.description,
         a.control_total,
         ROW_NUMBER() OVER (PARTITION BY a.je_batch_id
                            ORDER BY a.last_update_date, a.object_version_number) AS rn
  FROM   gl_je_batches_ a
  WHERE  (a.je_batch_id) IN (SELECT je_batch_id FROM glb_keys)
),
glb_chg AS (
  SELECT CAST(NULL AS NUMBER) AS je_header_id,
         n.je_batch_id AS je_batch_id,
         n.audit_name AS audit_name,
         n.last_update_date AS change_ts,
         n.last_updated_by  AS username,
         'Batch > ' AS level_lbl,
         0 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN o.name
           WHEN 2 THEN o.description
           WHEN 3 THEN TO_CHAR(o.control_total, 'FM999,999,999,990.00')
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN n.name
           WHEN 2 THEN n.description
           WHEN 3 THEN TO_CHAR(n.control_total, 'FM999,999,999,990.00')
         END AS new_raw,
         'N' AS is_event,
         CASE WHEN o.audit_action_type_ = 'HISTORY' THEN n.last_update_date ELSE o.last_update_date END AS old_written_ts,
         ea.enabled_ts
  FROM   glb_seq n
  CROSS JOIN prm
  LEFT JOIN glb_seq o
         ON o.je_batch_id = n.je_batch_id
        AND o.rn = n.rn - 1
  CROSS JOIN (
    SELECT 1 AS ord, 'Journal Batch' AS lbl, 'RAW' AS dec_type, 'NAME' AS col_name FROM dual
    UNION ALL SELECT 2, 'Description', 'RAW', 'DESCRIPTION' FROM dual
    UNION ALL SELECT 3, 'Control Total', 'RAW', 'CONTROL_TOTAL' FROM dual
  ) f
  LEFT JOIN (SELECT faa.column_name, MAX(faa.last_update_date) AS enabled_ts
             FROM   fnd_audit_attributes faa
             WHERE  faa.table_name = 'GL_JE_BATCHES'
             AND    faa.enabled_flag = 'Y'
             GROUP  BY faa.column_name) ea
         ON ea.column_name = f.col_name
  WHERE  n.audit_action_type_ = 'UPDATE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
  UNION ALL
  SELECT CAST(NULL AS NUMBER),
         n.je_batch_id,
         n.audit_name,
         n.last_update_date,
         n.last_updated_by,
         'Batch > ',
         0,
         0,
         'Deleted',
         'RAW',
         NULL,
         NULL,
         'Y',
         CAST(NULL AS TIMESTAMP),
         CAST(NULL AS TIMESTAMP)
  FROM   glb_seq n
  CROSS JOIN prm
  WHERE  n.audit_action_type_ = 'DELETE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
),
glh_keys AS (
  SELECT DISTINCT a.je_header_id
  FROM   gl_je_headers_ a
  CROSS JOIN prm
  WHERE  prm.run_gl = 'Y'
  AND    a.audit_action_type_ IN ('UPDATE', 'DELETE')
  AND    a.last_update_date >= prm.from_utc
  AND    a.last_update_date <  prm.to_utc
),
glh_seq AS (
  SELECT a.je_header_id,
         a.last_update_date,
         a.last_updated_by,
         a.audit_action_type_,
         a.name AS audit_name,
         a.name,
         a.description,
         a.default_effective_date,
         a.je_category,
         a.currency_code,
         a.external_reference,
         a.reference_date,
         a.accrual_rev_period_name,
         a.accrual_rev_change_sign_flag,
         ROW_NUMBER() OVER (PARTITION BY a.je_header_id
                            ORDER BY a.last_update_date, a.object_version_number) AS rn
  FROM   gl_je_headers_ a
  WHERE  (a.je_header_id) IN (SELECT je_header_id FROM glh_keys)
),
glh_chg AS (
  SELECT n.je_header_id AS je_header_id,
         NULL AS je_batch_id,
         n.audit_name AS audit_name,
         n.last_update_date AS change_ts,
         n.last_updated_by  AS username,
         CAST(NULL AS VARCHAR2(80)) AS level_lbl,
         100 AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN o.name
           WHEN 2 THEN o.description
           WHEN 3 THEN TO_CHAR(o.default_effective_date, 'DD/MM/YYYY')
           WHEN 4 THEN o.je_category
           WHEN 5 THEN o.currency_code
           WHEN 6 THEN o.external_reference
           WHEN 7 THEN TO_CHAR(o.reference_date, 'DD/MM/YYYY')
           WHEN 8 THEN o.accrual_rev_period_name
           WHEN 9 THEN o.accrual_rev_change_sign_flag
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN n.name
           WHEN 2 THEN n.description
           WHEN 3 THEN TO_CHAR(n.default_effective_date, 'DD/MM/YYYY')
           WHEN 4 THEN n.je_category
           WHEN 5 THEN n.currency_code
           WHEN 6 THEN n.external_reference
           WHEN 7 THEN TO_CHAR(n.reference_date, 'DD/MM/YYYY')
           WHEN 8 THEN n.accrual_rev_period_name
           WHEN 9 THEN n.accrual_rev_change_sign_flag
         END AS new_raw,
         'N' AS is_event,
         CASE WHEN o.audit_action_type_ = 'HISTORY' THEN n.last_update_date ELSE o.last_update_date END AS old_written_ts,
         ea.enabled_ts
  FROM   glh_seq n
  CROSS JOIN prm
  LEFT JOIN glh_seq o
         ON o.je_header_id = n.je_header_id
        AND o.rn = n.rn - 1
  CROSS JOIN (
    SELECT 1 AS ord, 'Journal' AS lbl, 'RAW' AS dec_type, 'NAME' AS col_name FROM dual
    UNION ALL SELECT 2, 'Description', 'RAW', 'DESCRIPTION' FROM dual
    UNION ALL SELECT 3, 'Accounting Date', 'RAW', 'DEFAULT_EFFECTIVE_DATE' FROM dual
    UNION ALL SELECT 4, 'Category', 'GLCAT', 'JE_CATEGORY' FROM dual
    UNION ALL SELECT 5, 'Currency', 'RAW', 'CURRENCY_CODE' FROM dual
    UNION ALL SELECT 6, 'Reference', 'RAW', 'EXTERNAL_REFERENCE' FROM dual
    UNION ALL SELECT 7, 'Reference Date', 'RAW', 'REFERENCE_DATE' FROM dual
    UNION ALL SELECT 8, 'Reversal Period', 'RAW', 'ACCRUAL_REV_PERIOD_NAME' FROM dual
    UNION ALL SELECT 9, 'Reversal Method', 'REVMETH', 'ACCRUAL_REV_CHANGE_SIGN_FLAG' FROM dual
  ) f
  LEFT JOIN (SELECT faa.column_name, MAX(faa.last_update_date) AS enabled_ts
             FROM   fnd_audit_attributes faa
             WHERE  faa.table_name = 'GL_JE_HEADERS'
             AND    faa.enabled_flag = 'Y'
             GROUP  BY faa.column_name) ea
         ON ea.column_name = f.col_name
  WHERE  n.audit_action_type_ = 'UPDATE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
  UNION ALL
  SELECT n.je_header_id,
         NULL,
         n.audit_name,
         n.last_update_date,
         n.last_updated_by,
         CAST(NULL AS VARCHAR2(80)),
         100,
         0,
         'Deleted',
         'RAW',
         NULL,
         NULL,
         'Y',
         CAST(NULL AS TIMESTAMP),
         CAST(NULL AS TIMESTAMP)
  FROM   glh_seq n
  CROSS JOIN prm
  WHERE  n.audit_action_type_ = 'DELETE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
),
gll_keys AS (
  SELECT DISTINCT a.je_header_id, a.je_line_num
  FROM   gl_je_lines_ a
  CROSS JOIN prm
  WHERE  prm.run_gl = 'Y'
  AND    a.audit_action_type_ IN ('UPDATE', 'DELETE')
  AND    a.last_update_date >= prm.from_utc
  AND    a.last_update_date <  prm.to_utc
),
gll_seq AS (
  SELECT a.je_header_id, a.je_line_num,
         a.last_update_date,
         a.last_updated_by,
         a.audit_action_type_,
         a.code_combination_id,
         a.entered_dr,
         a.entered_cr,
         a.description,
         ROW_NUMBER() OVER (PARTITION BY a.je_header_id, a.je_line_num
                            ORDER BY a.last_update_date, a.object_version_number) AS rn
  FROM   gl_je_lines_ a
  WHERE  (a.je_header_id, a.je_line_num) IN (SELECT je_header_id, je_line_num FROM gll_keys)
),
gll_chg AS (
  SELECT n.je_header_id AS je_header_id,
         NULL AS je_batch_id,
         CAST(NULL AS VARCHAR2(100)) AS audit_name,
         n.last_update_date AS change_ts,
         n.last_updated_by  AS username,
         'Line ' || n.je_line_num || ' > ' AS level_lbl,
         1000 + n.je_line_num AS sub_ord,
         f.ord,
         f.lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.code_combination_id)
           WHEN 2 THEN TO_CHAR(o.entered_dr, 'FM999,999,999,990.00')
           WHEN 3 THEN TO_CHAR(o.entered_cr, 'FM999,999,999,990.00')
           WHEN 4 THEN o.description
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.code_combination_id)
           WHEN 2 THEN TO_CHAR(n.entered_dr, 'FM999,999,999,990.00')
           WHEN 3 THEN TO_CHAR(n.entered_cr, 'FM999,999,999,990.00')
           WHEN 4 THEN n.description
         END AS new_raw,
         'N' AS is_event,
         CASE WHEN o.audit_action_type_ = 'HISTORY' THEN n.last_update_date ELSE o.last_update_date END AS old_written_ts,
         ea.enabled_ts
  FROM   gll_seq n
  CROSS JOIN prm
  LEFT JOIN gll_seq o
         ON o.je_header_id = n.je_header_id AND o.je_line_num = n.je_line_num
        AND o.rn = n.rn - 1
  CROSS JOIN (
    SELECT 1 AS ord, 'Account' AS lbl, 'ACCOUNT' AS dec_type, 'CODE_COMBINATION_ID' AS col_name FROM dual
    UNION ALL SELECT 2, 'Debit', 'RAW', 'ENTERED_DR' FROM dual
    UNION ALL SELECT 3, 'Credit', 'RAW', 'ENTERED_CR' FROM dual
    UNION ALL SELECT 4, 'Description', 'RAW', 'DESCRIPTION' FROM dual
  ) f
  LEFT JOIN (SELECT faa.column_name, MAX(faa.last_update_date) AS enabled_ts
             FROM   fnd_audit_attributes faa
             WHERE  faa.table_name = 'GL_JE_LINES'
             AND    faa.enabled_flag = 'Y'
             GROUP  BY faa.column_name) ea
         ON ea.column_name = f.col_name
  WHERE  n.audit_action_type_ = 'UPDATE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
  UNION ALL
  SELECT n.je_header_id,
         NULL,
         CAST(NULL AS VARCHAR2(100)),
         n.last_update_date,
         n.last_updated_by,
         'Line ' || n.je_line_num || ' > ',
         1000 + n.je_line_num,
         0,
         'Deleted',
         'RAW',
         NULL,
         NULL,
         'Y',
         CAST(NULL AS TIMESTAMP),
         CAST(NULL AS TIMESTAMP)
  FROM   gll_seq n
  CROSS JOIN prm
  WHERE  n.audit_action_type_ = 'DELETE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
),
glr_chg AS (
  SELECT r.reversed_je_header_id AS je_header_id,
         CAST(NULL AS NUMBER) AS je_batch_id,
         CAST(NULL AS VARCHAR2(100)) AS audit_name,
         r.creation_date AS change_ts,
         r.created_by AS username,
         CAST(NULL AS VARCHAR2(80)) AS level_lbl,
         900 AS sub_ord,
         0 AS ord,
         'Reversed' AS lbl,
         'RAW' AS dec_type,
         CAST(NULL AS VARCHAR2(400)) AS old_raw,
         r.name AS new_raw,
         'Y' AS is_event,
         CAST(NULL AS TIMESTAMP) AS old_written_ts,
         CAST(NULL AS TIMESTAMP) AS enabled_ts
  FROM   gl_je_headers r
  CROSS JOIN prm
  WHERE  prm.run_gl = 'Y'
  AND    r.reversed_je_header_id IS NOT NULL
  AND    r.creation_date >= prm.from_utc
  AND    r.creation_date <  prm.to_utc
),
gl_all AS (
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM glb_chg
  UNION ALL
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM glh_chg
  UNION ALL
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM gll_chg
  UNION ALL
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM glr_chg
),
gl_rows AS (
  SELECT 'General Ledger'                                                  AS product,
         c.username,
         c.change_ts,
         CASE WHEN c.je_header_id IS NOT NULL
              THEN NVL(h.name, c.audit_name)
              ELSE NVL((SELECT MIN(hh.name) FROM gl_je_headers hh WHERE hh.je_batch_id = c.je_batch_id), 'Deleted journal')
         END                                                               AS transaction_id,
         c.sub_ord,
         c.ord,
         c.level_lbl || c.lbl                                              AS action_performed,
         NVL(CASE c.dec_type
           WHEN 'SUPPLIER'  THEN (SELECT MAX(s.vendor_name) FROM poz_suppliers_v s WHERE s.vendor_id = TO_NUMBER(c.old_raw))
           WHEN 'SITE'      THEN (SELECT MAX(ss.vendor_site_code) FROM poz_supplier_sites_all_m ss WHERE ss.vendor_site_id = TO_NUMBER(c.old_raw))
           WHEN 'BATCH'     THEN (SELECT MAX(b.batch_name) FROM ap_batches_all b WHERE b.batch_id = TO_NUMBER(c.old_raw))
           WHEN 'TERMS'     THEN (SELECT MAX(t.name) FROM ap_terms_tl t WHERE t.term_id = TO_NUMBER(c.old_raw) AND t.language = USERENV('LANG'))
           WHEN 'PERSON'    THEN (SELECT MAX(p.display_name) FROM per_person_names_f p
                                  WHERE p.person_id = TO_NUMBER(c.old_raw) AND p.name_type = 'GLOBAL'
                                  AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date)
           WHEN 'LOC'       THEN (SELECT MAX(l.location_code) FROM hr_locations_all l WHERE l.location_id = TO_NUMBER(c.old_raw))
           WHEN 'AWT'       THEN (SELECT MAX(g.name) FROM ap_awt_groups g WHERE g.group_id = TO_NUMBER(c.old_raw))
           WHEN 'DSET'      THEN (SELECT MAX(ds.distribution_set_name) FROM ap_distribution_sets_all ds WHERE ds.distribution_set_id = TO_NUMBER(c.old_raw))
           WHEN 'ACCOUNT'   THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                   cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                   cc.segment9 || '-' || cc.segment10, '-'))
                                  FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.old_raw))
           WHEN 'PO'        THEN (SELECT MAX(ph.segment1) FROM po_headers_all ph WHERE ph.po_header_id = TO_NUMBER(c.old_raw))
           WHEN 'ITEM'      THEN (SELECT MAX(it.item_number) FROM egp_system_items_b it WHERE it.inventory_item_id = TO_NUMBER(c.old_raw))
           WHEN 'INVOICE'   THEN (SELECT MAX(ci.invoice_num) FROM ap_invoices_all ci WHERE ci.invoice_id = TO_NUMBER(c.old_raw))
           WHEN 'PAYMETHOD' THEN (SELECT MAX(pm.payment_method_name) FROM iby_payment_methods_tl pm
                                  WHERE pm.payment_method_code = c.old_raw AND pm.language = USERENV('LANG'))
           WHEN 'BANKACCT'  THEN (SELECT MAX(NVL(ba.masked_bank_account_num, ba.bank_account_num)) FROM iby_ext_bank_accounts ba
                                  WHERE ba.ext_bank_account_id = TO_NUMBER(c.old_raw))
           WHEN 'LINETYPE'  THEN (SELECT MAX(lc.displayed_field) FROM ap_lookup_codes lc
                                  WHERE lc.lookup_type = 'INVOICE LINE TYPE' AND lc.lookup_code = c.old_raw)
           WHEN 'FC'        THEN (SELECT MAX(fc.classification_code) FROM zx_fc_codes_b fc WHERE fc.classification_id = TO_NUMBER(c.old_raw))
           WHEN 'YN'        THEN DECODE(c.old_raw, 'Y', 'Yes', 'N', 'No', c.old_raw)
           WHEN 'ASSET'     THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = TO_NUMBER(c.old_raw))
           WHEN 'GLCAT'     THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.old_raw)
           WHEN 'REVMETH'   THEN DECODE(c.old_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.old_raw)
         END, c.old_raw) AS old_value,
         NVL(CASE c.dec_type
           WHEN 'SUPPLIER'  THEN (SELECT MAX(s.vendor_name) FROM poz_suppliers_v s WHERE s.vendor_id = TO_NUMBER(c.new_raw))
           WHEN 'SITE'      THEN (SELECT MAX(ss.vendor_site_code) FROM poz_supplier_sites_all_m ss WHERE ss.vendor_site_id = TO_NUMBER(c.new_raw))
           WHEN 'BATCH'     THEN (SELECT MAX(b.batch_name) FROM ap_batches_all b WHERE b.batch_id = TO_NUMBER(c.new_raw))
           WHEN 'TERMS'     THEN (SELECT MAX(t.name) FROM ap_terms_tl t WHERE t.term_id = TO_NUMBER(c.new_raw) AND t.language = USERENV('LANG'))
           WHEN 'PERSON'    THEN (SELECT MAX(p.display_name) FROM per_person_names_f p
                                  WHERE p.person_id = TO_NUMBER(c.new_raw) AND p.name_type = 'GLOBAL'
                                  AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date)
           WHEN 'LOC'       THEN (SELECT MAX(l.location_code) FROM hr_locations_all l WHERE l.location_id = TO_NUMBER(c.new_raw))
           WHEN 'AWT'       THEN (SELECT MAX(g.name) FROM ap_awt_groups g WHERE g.group_id = TO_NUMBER(c.new_raw))
           WHEN 'DSET'      THEN (SELECT MAX(ds.distribution_set_name) FROM ap_distribution_sets_all ds WHERE ds.distribution_set_id = TO_NUMBER(c.new_raw))
           WHEN 'ACCOUNT'   THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                   cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                   cc.segment9 || '-' || cc.segment10, '-'))
                                  FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.new_raw))
           WHEN 'PO'        THEN (SELECT MAX(ph.segment1) FROM po_headers_all ph WHERE ph.po_header_id = TO_NUMBER(c.new_raw))
           WHEN 'ITEM'      THEN (SELECT MAX(it.item_number) FROM egp_system_items_b it WHERE it.inventory_item_id = TO_NUMBER(c.new_raw))
           WHEN 'INVOICE'   THEN (SELECT MAX(ci.invoice_num) FROM ap_invoices_all ci WHERE ci.invoice_id = TO_NUMBER(c.new_raw))
           WHEN 'PAYMETHOD' THEN (SELECT MAX(pm.payment_method_name) FROM iby_payment_methods_tl pm
                                  WHERE pm.payment_method_code = c.new_raw AND pm.language = USERENV('LANG'))
           WHEN 'BANKACCT'  THEN (SELECT MAX(NVL(ba.masked_bank_account_num, ba.bank_account_num)) FROM iby_ext_bank_accounts ba
                                  WHERE ba.ext_bank_account_id = TO_NUMBER(c.new_raw))
           WHEN 'LINETYPE'  THEN (SELECT MAX(lc.displayed_field) FROM ap_lookup_codes lc
                                  WHERE lc.lookup_type = 'INVOICE LINE TYPE' AND lc.lookup_code = c.new_raw)
           WHEN 'FC'        THEN (SELECT MAX(fc.classification_code) FROM zx_fc_codes_b fc WHERE fc.classification_id = TO_NUMBER(c.new_raw))
           WHEN 'YN'        THEN DECODE(c.new_raw, 'Y', 'Yes', 'N', 'No', c.new_raw)
           WHEN 'ASSET'     THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = TO_NUMBER(c.new_raw))
           WHEN 'GLCAT'     THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.new_raw)
           WHEN 'REVMETH'   THEN DECODE(c.new_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.new_raw)
         END, c.new_raw) AS new_value,
         NVL((SELECT MAX(lv.meaning) FROM fnd_lookup_values_vl lv
              WHERE  lv.lookup_type = 'MJE_BATCH_STATUS' AND lv.lookup_code = NVL(hb.status, b.status)),
             DECODE(NVL(hb.status, b.status), 'P', 'Posted', 'U', 'Unposted', NVL(hb.status, b.status))) AS transaction_status,
         DECODE(NVL(hb.approval_status_code, b.approval_status_code),
                'A', 'Approved', 'I', 'In Process', 'J', 'Rejected', 'R', 'Required',
                'V', 'Validation Failed', 'Z', 'Not Required',
                NVL(hb.approval_status_code, b.approval_status_code))      AS approval_status,
         TO_CHAR(NVL(h.posting_acct_seq_value, h.doc_sequence_value))      AS voucher_number
  FROM   gl_all c
  LEFT JOIN gl_je_headers h  ON h.je_header_id = c.je_header_id
  LEFT JOIN gl_je_batches hb ON hb.je_batch_id = h.je_batch_id
  LEFT JOIN gl_je_batches b  ON b.je_batch_id  = c.je_batch_id
  WHERE  (c.is_event = 'Y' OR DECODE(c.old_raw, c.new_raw, 0, 1) = 1)
  AND    (c.old_raw IS NOT NULL OR c.old_written_ts IS NULL OR c.enabled_ts IS NULL
          OR c.old_written_ts >= c.enabled_ts)
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR c.username IN (:P_USERNAME))
)
,
fa_trx AS (
  SELECT t.transaction_header_id,
         t.asset_id,
         t.book_type_code,
         t.transaction_type_code,
         t.transaction_subtype,
         t.transaction_name,
         t.created_by,
         CAST(t.date_effective AS TIMESTAMP) AS change_ts,
         CASE t.transaction_type_code WHEN 'ADJUSTMENT' THEN 'Adjust Assets' WHEN 'RECLASS' THEN 'Change Category' WHEN 'TRANSFER' THEN 'Transfer Assets' WHEN 'TRANSFER IN' THEN 'Transfer Assets' WHEN 'TRANSFER OUT' THEN 'Transfer Assets' WHEN 'UNIT ADJUSTMENT' THEN 'Transfer Assets' WHEN 'FULL RETIREMENT' THEN 'Retire Assets' WHEN 'PARTIAL RETIREMENT' THEN 'Retire Assets' WHEN 'REINSTATEMENT' THEN 'Reinstate' ELSE INITCAP(t.transaction_type_code) END AS section_lbl
  FROM   fa_transaction_headers t
  CROSS JOIN prm
  WHERE  prm.run_fa = 'Y'
  AND    t.transaction_type_code NOT IN ('ADDITION', 'CIP ADDITION', 'ADDITION/VOID')
  AND    CAST(t.date_effective AS TIMESTAMP) >= prm.from_utc
  AND    CAST(t.date_effective AS TIMESTAMP) <  prm.to_utc
),
fa_chg AS (
  SELECT t.asset_id,
         t.book_type_code,
         t.change_ts,
         t.created_by AS username,
         t.transaction_header_id * 100 AS sub_ord,
         0 AS ord,
         t.section_lbl || CASE WHEN t.transaction_subtype = 'AMORTIZED' THEN ' (Amortized)' END || ' > Comments' AS lbl,
         'RAW' AS dec_type,
         CAST(NULL AS VARCHAR2(400)) AS old_raw,
         t.transaction_name AS new_raw
  FROM   fa_trx t
  WHERE  TRIM(t.transaction_name) IS NOT NULL
  UNION ALL
  SELECT t.asset_id, t.book_type_code, t.change_ts, t.created_by, t.transaction_header_id * 100, f.ord,
         t.section_lbl || ' > ' || f.lbl, 'RAW',
         CASE f.ord
           WHEN 1 THEN TO_CHAR(o.cost, 'FM999,999,999,990.00')
           WHEN 2 THEN o.salvage_type
           WHEN 3 THEN TO_CHAR(o.percent_salvage_value)
           WHEN 4 THEN (SELECT MAX(m.method_code) FROM fa_methods m WHERE m.method_id = o.method_id)
           WHEN 5 THEN (SELECT MAX(TRUNC(m.life_in_months / 12) || ' years ' || MOD(m.life_in_months, 12) || ' months') FROM fa_methods m WHERE m.method_id = o.method_id)
           WHEN 6 THEN TO_CHAR(o.date_placed_in_service, 'DD/MM/YYYY')
           WHEN 7 THEN (SELECT MAX(ct.prorate_convention_code) FROM fa_convention_types ct WHERE ct.convention_type_id = o.convention_type_id)
           WHEN 8 THEN (SELECT MAX(br.bonus_rule) FROM fa_bonus_rules br WHERE br.bonus_rule_id = o.bonus_rule_id)
           WHEN 9 THEN TO_CHAR(o.cash_generating_unit_id)
           WHEN 10 THEN o.deprn_limit_type
         END,
         CASE f.ord
           WHEN 1 THEN TO_CHAR(n.cost, 'FM999,999,999,990.00')
           WHEN 2 THEN n.salvage_type
           WHEN 3 THEN TO_CHAR(n.percent_salvage_value)
           WHEN 4 THEN (SELECT MAX(m.method_code) FROM fa_methods m WHERE m.method_id = n.method_id)
           WHEN 5 THEN (SELECT MAX(TRUNC(m.life_in_months / 12) || ' years ' || MOD(m.life_in_months, 12) || ' months') FROM fa_methods m WHERE m.method_id = n.method_id)
           WHEN 6 THEN TO_CHAR(n.date_placed_in_service, 'DD/MM/YYYY')
           WHEN 7 THEN (SELECT MAX(ct.prorate_convention_code) FROM fa_convention_types ct WHERE ct.convention_type_id = n.convention_type_id)
           WHEN 8 THEN (SELECT MAX(br.bonus_rule) FROM fa_bonus_rules br WHERE br.bonus_rule_id = n.bonus_rule_id)
           WHEN 9 THEN TO_CHAR(n.cash_generating_unit_id)
           WHEN 10 THEN n.deprn_limit_type
         END
  FROM   fa_trx t
  JOIN   fa_books o ON o.asset_id = t.asset_id AND o.book_type_code = t.book_type_code
                   AND o.transaction_header_id_out = t.transaction_header_id
  JOIN   fa_books n ON n.asset_id = t.asset_id AND n.book_type_code = t.book_type_code
                   AND n.transaction_header_id_in = t.transaction_header_id
  CROSS JOIN (
    SELECT 1 AS ord, 'Cost' AS lbl FROM dual
    UNION ALL SELECT 2, 'Salvage Value Type' FROM dual
    UNION ALL SELECT 3, 'Salvage Value Percent' FROM dual
    UNION ALL SELECT 4, 'Depreciation Method' FROM dual
    UNION ALL SELECT 5, 'Life in Years / Months' FROM dual
    UNION ALL SELECT 6, 'In Service Date' FROM dual
    UNION ALL SELECT 7, 'Prorate Convention' FROM dual
    UNION ALL SELECT 8, 'Bonus Rule' FROM dual
    UNION ALL SELECT 9, 'Cash Generating Unit' FROM dual
    UNION ALL SELECT 10, 'Depreciation Limit Type' FROM dual
  ) f
  UNION ALL
  SELECT t.asset_id, t.book_type_code, t.change_ts, t.created_by, t.transaction_header_id * 100, 20 + f.ord,
         t.section_lbl || ' > ' || f.lbl, 'RAW',
         CASE f.ord WHEN 1 THEN (SELECT MAX(RTRIM(fc.segment1 || '-' || fc.segment2 || '-' || fc.segment3, '-')) FROM fa_categories_b fc WHERE fc.category_id = o.category_id) WHEN 2 THEN TO_CHAR(o.units) END,
         CASE f.ord WHEN 1 THEN (SELECT MAX(RTRIM(fc.segment1 || '-' || fc.segment2 || '-' || fc.segment3, '-')) FROM fa_categories_b fc WHERE fc.category_id = n.category_id) WHEN 2 THEN TO_CHAR(n.units) END
  FROM   fa_trx t
  JOIN   fa_asset_history o ON o.asset_id = t.asset_id AND o.transaction_header_id_out = t.transaction_header_id
  JOIN   fa_asset_history n ON n.asset_id = t.asset_id AND n.transaction_header_id_in = t.transaction_header_id
  CROSS JOIN (
    SELECT 1 AS ord, 'Category' AS lbl FROM dual
    UNION ALL SELECT 2, 'Units' FROM dual
  ) f
  UNION ALL
  SELECT t.asset_id, t.book_type_code, t.change_ts, t.created_by, t.transaction_header_id * 100, 40,
         t.section_lbl || ' > Assignment removed', 'RAW',
         'Units ' || d.units_assigned || NVL2(d.assigned_to, ', Employee ' || NVL((SELECT MAX(p.display_name) FROM per_person_names_f p WHERE p.person_id = d.assigned_to AND p.name_type = 'GLOBAL' AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date), TO_CHAR(d.assigned_to)), NULL) || ', Account ' || (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' || cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' || cc.segment9 || '-' || cc.segment10, '-')) FROM gl_code_combinations cc WHERE cc.code_combination_id = d.code_combination_id) || ', Location ' || d.location_id,
         CAST(NULL AS VARCHAR2(400))
  FROM   fa_trx t
  JOIN   fa_distribution_history d ON d.asset_id = t.asset_id AND d.transaction_header_id_out = t.transaction_header_id
  WHERE  t.transaction_type_code IN ('TRANSFER', 'TRANSFER IN', 'TRANSFER OUT', 'UNIT ADJUSTMENT', 'RECLASS')
  UNION ALL
  SELECT t.asset_id, t.book_type_code, t.change_ts, t.created_by, t.transaction_header_id * 100, 41,
         t.section_lbl || ' > Assignment added', 'RAW',
         CAST(NULL AS VARCHAR2(400)),
         'Units ' || d.units_assigned || NVL2(d.assigned_to, ', Employee ' || NVL((SELECT MAX(p.display_name) FROM per_person_names_f p WHERE p.person_id = d.assigned_to AND p.name_type = 'GLOBAL' AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date), TO_CHAR(d.assigned_to)), NULL) || ', Account ' || (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' || cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' || cc.segment9 || '-' || cc.segment10, '-')) FROM gl_code_combinations cc WHERE cc.code_combination_id = d.code_combination_id) || ', Location ' || d.location_id
  FROM   fa_trx t
  JOIN   fa_distribution_history d ON d.asset_id = t.asset_id AND d.transaction_header_id_in = t.transaction_header_id
  WHERE  t.transaction_type_code IN ('TRANSFER', 'TRANSFER IN', 'TRANSFER OUT', 'UNIT ADJUSTMENT', 'RECLASS')
  UNION ALL
  SELECT t.asset_id, t.book_type_code, t.change_ts, t.created_by, t.transaction_header_id * 100, 50 + f.ord,
         t.section_lbl || ' > ' || f.lbl, 'RAW',
         CAST(NULL AS VARCHAR2(400)),
         CASE f.ord
           WHEN 1 THEN TO_CHAR(r.date_retired, 'DD/MM/YYYY')
           WHEN 2 THEN TO_CHAR(r.cost_retired, 'FM999,999,999,990.00')
           WHEN 3 THEN TO_CHAR(r.proceeds_of_sale, 'FM999,999,999,990.00')
           WHEN 4 THEN TO_CHAR(r.cost_of_removal, 'FM999,999,999,990.00')
           WHEN 5 THEN r.retirement_type_code
           WHEN 6 THEN (SELECT MAX(ct.prorate_convention_code) FROM fa_convention_types ct WHERE ct.convention_type_id = r.retirement_convention_type_id)
           WHEN 7 THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = r.trade_in_asset_id)
           WHEN 8 THEN r.reference_num
           WHEN 9 THEN r.sold_to
         END
  FROM   fa_trx t
  JOIN   fa_retirements r ON r.asset_id = t.asset_id AND r.book_type_code = t.book_type_code
                         AND r.transaction_header_id_in = t.transaction_header_id
  CROSS JOIN (
    SELECT 1 AS ord, 'Retire Date' AS lbl FROM dual
    UNION ALL SELECT 2, 'Cost Retired' FROM dual
    UNION ALL SELECT 3, 'Proceeds of Sale' FROM dual
    UNION ALL SELECT 4, 'Cost of Removal' FROM dual
    UNION ALL SELECT 5, 'Retirement Reason' FROM dual
    UNION ALL SELECT 6, 'Retirement Convention' FROM dual
    UNION ALL SELECT 7, 'Trade in Asset' FROM dual
    UNION ALL SELECT 8, 'Check or Invoice Number' FROM dual
    UNION ALL SELECT 9, 'Sold To' FROM dual
  ) f
),
fad_keys AS (
  SELECT DISTINCT a.asset_id
  FROM   fa_additions_b_ a
  CROSS JOIN prm
  WHERE  prm.run_fa = 'Y'
  AND    a.audit_action_type_ IN ('UPDATE', 'DELETE')
  AND    a.last_update_date >= prm.from_utc
  AND    a.last_update_date <  prm.to_utc
),
fad_seq AS (
  SELECT a.asset_id,
         a.last_update_date,
         a.last_updated_by,
         a.audit_action_type_,
         a.asset_number,
         a.tag_number,
         a.serial_number,
         a.parent_asset_id,
         a.manufacturer_name,
         a.model_number,
         a.asset_key_ccid,
         a.property_type_code,
         a.property_1245_1250_code,
         a.owned_leased,
         a.new_used,
         a.commitment,
         a.investment_law,
         ROW_NUMBER() OVER (PARTITION BY a.asset_id ORDER BY a.last_update_date, a.object_version_number) AS rn
  FROM   fa_additions_b_ a
  WHERE  a.asset_id IN (SELECT asset_id FROM fad_keys)
),
fad_chg AS (
  SELECT n.asset_id,
         CAST(NULL AS VARCHAR2(30)) AS book_type_code,
         n.last_update_date AS change_ts,
         n.last_updated_by AS username,
         0 AS sub_ord,
         f.ord,
         'Update Descriptive Details > ' || f.lbl AS lbl,
         f.dec_type,
         CASE f.ord
           WHEN 1 THEN o.asset_number
           WHEN 2 THEN o.tag_number
           WHEN 3 THEN o.serial_number
           WHEN 4 THEN TO_CHAR(o.parent_asset_id)
           WHEN 5 THEN o.manufacturer_name
           WHEN 6 THEN o.model_number
           WHEN 7 THEN TO_CHAR(o.asset_key_ccid)
           WHEN 8 THEN o.property_type_code
           WHEN 9 THEN o.property_1245_1250_code
           WHEN 10 THEN o.owned_leased
           WHEN 11 THEN o.new_used
           WHEN 12 THEN o.commitment
           WHEN 13 THEN o.investment_law
         END AS old_raw,
         CASE f.ord
           WHEN 1 THEN n.asset_number
           WHEN 2 THEN n.tag_number
           WHEN 3 THEN n.serial_number
           WHEN 4 THEN TO_CHAR(n.parent_asset_id)
           WHEN 5 THEN n.manufacturer_name
           WHEN 6 THEN n.model_number
           WHEN 7 THEN TO_CHAR(n.asset_key_ccid)
           WHEN 8 THEN n.property_type_code
           WHEN 9 THEN n.property_1245_1250_code
           WHEN 10 THEN n.owned_leased
           WHEN 11 THEN n.new_used
           WHEN 12 THEN n.commitment
           WHEN 13 THEN n.investment_law
         END AS new_raw,
         CASE WHEN o.audit_action_type_ = 'HISTORY' THEN n.last_update_date ELSE o.last_update_date END AS old_written_ts,
         ea.enabled_ts
  FROM   fad_seq n
  CROSS JOIN prm
  LEFT JOIN fad_seq o ON o.asset_id = n.asset_id AND o.rn = n.rn - 1
  CROSS JOIN (
    SELECT 1 AS ord, 'Asset Number' AS lbl, 'RAW' AS dec_type, 'ASSET_NUMBER' AS col_name FROM dual
    UNION ALL SELECT 2, 'Tag Number', 'RAW', 'TAG_NUMBER' FROM dual
    UNION ALL SELECT 3, 'Serial Number', 'RAW', 'SERIAL_NUMBER' FROM dual
    UNION ALL SELECT 4, 'Parent Asset', 'ASSET', 'PARENT_ASSET_ID' FROM dual
    UNION ALL SELECT 5, 'Manufacturer', 'RAW', 'MANUFACTURER_NAME' FROM dual
    UNION ALL SELECT 6, 'Model', 'RAW', 'MODEL_NUMBER' FROM dual
    UNION ALL SELECT 7, 'Asset Key', 'RAW', 'ASSET_KEY_CCID' FROM dual
    UNION ALL SELECT 8, 'Property Type', 'RAW', 'PROPERTY_TYPE_CODE' FROM dual
    UNION ALL SELECT 9, 'Property Class', 'RAW', 'PROPERTY_1245_1250_CODE' FROM dual
    UNION ALL SELECT 10, 'Ownership', 'RAW', 'OWNED_LEASED' FROM dual
    UNION ALL SELECT 11, 'Bought', 'RAW', 'NEW_USED' FROM dual
    UNION ALL SELECT 12, 'Commitment', 'RAW', 'COMMITMENT' FROM dual
    UNION ALL SELECT 13, 'Investment Law', 'RAW', 'INVESTMENT_LAW' FROM dual
  ) f
  LEFT JOIN (SELECT faa.column_name, MAX(faa.last_update_date) AS enabled_ts
             FROM   fnd_audit_attributes faa
             WHERE  faa.table_name = 'FA_ADDITIONS_B'
             AND    faa.enabled_flag = 'Y'
             GROUP  BY faa.column_name) ea
         ON ea.column_name = f.col_name
  WHERE  n.audit_action_type_ = 'UPDATE'
  AND    n.last_update_date >= prm.from_utc
  AND    n.last_update_date <  prm.to_utc
),
fa_rows AS (
  SELECT 'Fixed Assets' AS product,
         c.username,
         c.change_ts,
         (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = c.asset_id)
           || NVL2(c.book_type_code, ' (' || c.book_type_code || ')', NULL) AS transaction_id,
         c.sub_ord,
         c.ord,
         c.lbl AS action_performed,
         NVL(CASE c.dec_type
           WHEN 'SUPPLIER'  THEN (SELECT MAX(s.vendor_name) FROM poz_suppliers_v s WHERE s.vendor_id = TO_NUMBER(c.old_raw))
           WHEN 'SITE'      THEN (SELECT MAX(ss.vendor_site_code) FROM poz_supplier_sites_all_m ss WHERE ss.vendor_site_id = TO_NUMBER(c.old_raw))
           WHEN 'BATCH'     THEN (SELECT MAX(b.batch_name) FROM ap_batches_all b WHERE b.batch_id = TO_NUMBER(c.old_raw))
           WHEN 'TERMS'     THEN (SELECT MAX(t.name) FROM ap_terms_tl t WHERE t.term_id = TO_NUMBER(c.old_raw) AND t.language = USERENV('LANG'))
           WHEN 'PERSON'    THEN (SELECT MAX(p.display_name) FROM per_person_names_f p
                                  WHERE p.person_id = TO_NUMBER(c.old_raw) AND p.name_type = 'GLOBAL'
                                  AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date)
           WHEN 'LOC'       THEN (SELECT MAX(l.location_code) FROM hr_locations_all l WHERE l.location_id = TO_NUMBER(c.old_raw))
           WHEN 'AWT'       THEN (SELECT MAX(g.name) FROM ap_awt_groups g WHERE g.group_id = TO_NUMBER(c.old_raw))
           WHEN 'DSET'      THEN (SELECT MAX(ds.distribution_set_name) FROM ap_distribution_sets_all ds WHERE ds.distribution_set_id = TO_NUMBER(c.old_raw))
           WHEN 'ACCOUNT'   THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                   cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                   cc.segment9 || '-' || cc.segment10, '-'))
                                  FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.old_raw))
           WHEN 'PO'        THEN (SELECT MAX(ph.segment1) FROM po_headers_all ph WHERE ph.po_header_id = TO_NUMBER(c.old_raw))
           WHEN 'ITEM'      THEN (SELECT MAX(it.item_number) FROM egp_system_items_b it WHERE it.inventory_item_id = TO_NUMBER(c.old_raw))
           WHEN 'INVOICE'   THEN (SELECT MAX(ci.invoice_num) FROM ap_invoices_all ci WHERE ci.invoice_id = TO_NUMBER(c.old_raw))
           WHEN 'PAYMETHOD' THEN (SELECT MAX(pm.payment_method_name) FROM iby_payment_methods_tl pm
                                  WHERE pm.payment_method_code = c.old_raw AND pm.language = USERENV('LANG'))
           WHEN 'BANKACCT'  THEN (SELECT MAX(NVL(ba.masked_bank_account_num, ba.bank_account_num)) FROM iby_ext_bank_accounts ba
                                  WHERE ba.ext_bank_account_id = TO_NUMBER(c.old_raw))
           WHEN 'LINETYPE'  THEN (SELECT MAX(lc.displayed_field) FROM ap_lookup_codes lc
                                  WHERE lc.lookup_type = 'INVOICE LINE TYPE' AND lc.lookup_code = c.old_raw)
           WHEN 'FC'        THEN (SELECT MAX(fc.classification_code) FROM zx_fc_codes_b fc WHERE fc.classification_id = TO_NUMBER(c.old_raw))
           WHEN 'YN'        THEN DECODE(c.old_raw, 'Y', 'Yes', 'N', 'No', c.old_raw)
           WHEN 'ASSET'     THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = TO_NUMBER(c.old_raw))
           WHEN 'GLCAT'     THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.old_raw)
           WHEN 'REVMETH'   THEN DECODE(c.old_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.old_raw)
         END, c.old_raw) AS old_value,
         NVL(CASE c.dec_type
           WHEN 'SUPPLIER'  THEN (SELECT MAX(s.vendor_name) FROM poz_suppliers_v s WHERE s.vendor_id = TO_NUMBER(c.new_raw))
           WHEN 'SITE'      THEN (SELECT MAX(ss.vendor_site_code) FROM poz_supplier_sites_all_m ss WHERE ss.vendor_site_id = TO_NUMBER(c.new_raw))
           WHEN 'BATCH'     THEN (SELECT MAX(b.batch_name) FROM ap_batches_all b WHERE b.batch_id = TO_NUMBER(c.new_raw))
           WHEN 'TERMS'     THEN (SELECT MAX(t.name) FROM ap_terms_tl t WHERE t.term_id = TO_NUMBER(c.new_raw) AND t.language = USERENV('LANG'))
           WHEN 'PERSON'    THEN (SELECT MAX(p.display_name) FROM per_person_names_f p
                                  WHERE p.person_id = TO_NUMBER(c.new_raw) AND p.name_type = 'GLOBAL'
                                  AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date)
           WHEN 'LOC'       THEN (SELECT MAX(l.location_code) FROM hr_locations_all l WHERE l.location_id = TO_NUMBER(c.new_raw))
           WHEN 'AWT'       THEN (SELECT MAX(g.name) FROM ap_awt_groups g WHERE g.group_id = TO_NUMBER(c.new_raw))
           WHEN 'DSET'      THEN (SELECT MAX(ds.distribution_set_name) FROM ap_distribution_sets_all ds WHERE ds.distribution_set_id = TO_NUMBER(c.new_raw))
           WHEN 'ACCOUNT'   THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                   cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                   cc.segment9 || '-' || cc.segment10, '-'))
                                  FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.new_raw))
           WHEN 'PO'        THEN (SELECT MAX(ph.segment1) FROM po_headers_all ph WHERE ph.po_header_id = TO_NUMBER(c.new_raw))
           WHEN 'ITEM'      THEN (SELECT MAX(it.item_number) FROM egp_system_items_b it WHERE it.inventory_item_id = TO_NUMBER(c.new_raw))
           WHEN 'INVOICE'   THEN (SELECT MAX(ci.invoice_num) FROM ap_invoices_all ci WHERE ci.invoice_id = TO_NUMBER(c.new_raw))
           WHEN 'PAYMETHOD' THEN (SELECT MAX(pm.payment_method_name) FROM iby_payment_methods_tl pm
                                  WHERE pm.payment_method_code = c.new_raw AND pm.language = USERENV('LANG'))
           WHEN 'BANKACCT'  THEN (SELECT MAX(NVL(ba.masked_bank_account_num, ba.bank_account_num)) FROM iby_ext_bank_accounts ba
                                  WHERE ba.ext_bank_account_id = TO_NUMBER(c.new_raw))
           WHEN 'LINETYPE'  THEN (SELECT MAX(lc.displayed_field) FROM ap_lookup_codes lc
                                  WHERE lc.lookup_type = 'INVOICE LINE TYPE' AND lc.lookup_code = c.new_raw)
           WHEN 'FC'        THEN (SELECT MAX(fc.classification_code) FROM zx_fc_codes_b fc WHERE fc.classification_id = TO_NUMBER(c.new_raw))
           WHEN 'YN'        THEN DECODE(c.new_raw, 'Y', 'Yes', 'N', 'No', c.new_raw)
           WHEN 'ASSET'     THEN (SELECT MAX(ad.asset_number) FROM fa_additions_b ad WHERE ad.asset_id = TO_NUMBER(c.new_raw))
           WHEN 'GLCAT'     THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.new_raw)
           WHEN 'REVMETH'   THEN DECODE(c.new_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.new_raw)
         END, c.new_raw) AS new_value,
         CAST(NULL AS VARCHAR2(80)) AS transaction_status,
         CAST(NULL AS VARCHAR2(80)) AS approval_status,
         CAST(NULL AS VARCHAR2(60)) AS voucher_number
  FROM  (SELECT asset_id, book_type_code, change_ts, username, sub_ord, ord, lbl, dec_type, old_raw, new_raw,
                CASE WHEN ord = 0 THEN 'Y' ELSE 'N' END AS is_event,
                CAST(NULL AS TIMESTAMP) AS old_written_ts, CAST(NULL AS TIMESTAMP) AS enabled_ts
         FROM   fa_chg
         UNION ALL
         SELECT asset_id, book_type_code, change_ts, username, sub_ord, ord, lbl, dec_type, old_raw, new_raw,
                'N', old_written_ts, enabled_ts
         FROM   fad_chg) c
  WHERE  (c.is_event = 'Y' OR DECODE(c.old_raw, c.new_raw, 0, 1) = 1)
  AND    (c.old_raw IS NOT NULL OR c.old_written_ts IS NULL OR c.enabled_ts IS NULL
          OR c.old_written_ts >= c.enabled_ts)
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR c.username IN (:P_USERNAME))
),
ar_rows AS (
  SELECT 'Receivables' AS product,
         x.created_by AS username,
         x.creation_date AS change_ts,
         x.receipt_number AS transaction_id,
         x.receivable_application_id AS sub_ord,
         0 AS ord,
         CASE WHEN x.amount_applied < 0 THEN 'Unapply Application' ELSE 'Add Application' END AS action_performed,
         CASE WHEN x.amount_applied < 0 THEN x.summary END AS old_value,
         CASE WHEN x.amount_applied < 0 THEN NULL ELSE x.summary END AS new_value,
         (SELECT MAX(INITCAP(h.status)) FROM ar_cash_receipt_history_all h
          WHERE  h.cash_receipt_id = x.cash_receipt_id AND h.current_record_flag = 'Y') AS transaction_status,
         CAST(NULL AS VARCHAR2(80)) AS approval_status,
         TO_CHAR(x.doc_sequence_value) AS voucher_number
  FROM  (SELECT ra.receivable_application_id,
                ra.cash_receipt_id,
                ra.created_by,
                ra.creation_date,
                ra.amount_applied,
                cr.receipt_number,
                cr.doc_sequence_value,
                NVL((SELECT MAX(t.trx_number) FROM ra_customer_trx_all t WHERE t.customer_trx_id = ra.applied_customer_trx_id), '-')
                || ' | Applied Amount ' || TO_CHAR(ABS(ra.amount_applied), 'FM999,999,999,990.00')
                || ' | Application Date ' || TO_CHAR(ra.apply_date, 'DD/MM/YYYY')
                || ' | Accounting Date ' || TO_CHAR(ra.gl_date, 'DD/MM/YYYY')
                || NVL2(ra.earned_discount_taken, ' | Discount ' || TO_CHAR(ABS(ra.earned_discount_taken), 'FM999,999,999,990.00'), NULL)
                || NVL2(ra.application_ref_num, ' | Application Reference ' || ra.application_ref_num, NULL)
                || NVL2(ra.exception_reason_code, ' | Exception Reason ' || ra.exception_reason_code, NULL) AS summary
         FROM   ar_receivable_applications_all ra
         JOIN   ar_cash_receipts_all cr ON cr.cash_receipt_id = ra.cash_receipt_id
         CROSS JOIN prm
         WHERE  prm.run_ar = 'Y'
         AND    ra.status = 'APP'
         AND    ra.creation_date >= prm.from_utc
         AND    ra.creation_date <  prm.to_utc
         AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR ra.created_by IN (:P_USERNAME))) x
),
ce_rows AS (
  SELECT 'Bank Statements' AS product,
         h.created_by AS username,
         h.creation_date AS change_ts,
         (SELECT MAX(ba.bank_account_name) FROM ce_bank_accounts ba WHERE ba.bank_account_id = h.bank_account_id)
           || ' / ' || NVL((SELECT MIN(sh.statement_number)
                            FROM   ce_recon_history_items i
                            JOIN   ce_statement_lines sl ON sl.statement_line_id = i.source_id
                            JOIN   ce_statement_headers sh ON sh.statement_header_id = sl.statement_header_id
                            WHERE  i.recon_history_id = h.recon_history_id AND i.recon_source = 'BS'), '-') AS transaction_id,
         h.recon_history_id AS sub_ord,
         0 AS ord,
         CASE WHEN h.recon_action LIKE 'U%' THEN 'Unreconcile'
              WHEN NVL(h.auto_recon_flag, 'N') = 'Y' THEN 'Automatic Reconciliation'
              ELSE 'Manual Reconciliation' END || ' (' || h.recon_action || ')' AS action_performed,
         CAST(NULL AS VARCHAR2(400)) AS old_value,
         'Statement lines: ' || (SELECT COUNT(*) FROM ce_recon_history_items i WHERE i.recon_history_id = h.recon_history_id AND i.recon_source = 'BS')
           || ' | Transactions: ' || (SELECT COUNT(*) FROM ce_recon_history_items i WHERE i.recon_history_id = h.recon_history_id AND i.recon_source <> 'BS')
           || ' | Amount: ' || (SELECT TO_CHAR(SUM(i.cleared_amount), 'FM999,999,999,990.00') FROM ce_recon_history_items i
                                WHERE i.recon_history_id = h.recon_history_id AND i.recon_source = 'BS') AS new_value,
         (SELECT MAX(INITCAP(sh.recon_status_code))
          FROM   ce_recon_history_items i
          JOIN   ce_statement_lines sl ON sl.statement_line_id = i.source_id
          JOIN   ce_statement_headers sh ON sh.statement_header_id = sl.statement_header_id
          WHERE  i.recon_history_id = h.recon_history_id AND i.recon_source = 'BS') AS transaction_status,
         CAST(NULL AS VARCHAR2(80)) AS approval_status,
         CAST(NULL AS VARCHAR2(60)) AS voucher_number
  FROM   ce_recon_history h
  CROSS JOIN prm
  WHERE  prm.run_ce = 'Y'
  AND    h.creation_date >= prm.from_utc
  AND    h.creation_date <  prm.to_utc
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR h.created_by IN (:P_USERNAME))
)
,
att_base AS (
  SELECT fad.entity_name,
         fad.pk1_value,
         fad.created_by,
         fad.creation_date,
         fad.attached_document_id,
         fad.category_name,
         (SELECT MAX(COALESCE(dt.file_name, dt.url, dt.title))
          FROM   fnd_documents_tl dt
          WHERE  dt.document_id = fad.document_id
          AND    dt.language = USERENV('LANG')) AS file_label
  FROM   fnd_attached_documents fad
  CROSS JOIN prm
  WHERE  fad.entity_name IN ('PO_HEADERS', 'POR_REQUISITION_LINES', 'AP_CHECKS_ALL')
  AND    fad.creation_date >= prm.from_utc
  AND    fad.creation_date <  prm.to_utc
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR fad.created_by IN (:P_USERNAME))
  AND    NOT EXISTS (SELECT 1
                     FROM   fnd_attached_documents f2
                     WHERE  f2.entity_name = fad.entity_name
                     AND    f2.pk1_value   = fad.pk1_value
                     AND    f2.document_id = fad.document_id
                     AND    f2.creation_date < fad.creation_date)
),
att_rows AS (
  SELECT 'Purchase Orders' AS product,
         a.created_by AS username,
         a.creation_date AS change_ts,
         h.segment1 AS transaction_id,
         -2 AS sub_ord,
         a.attached_document_id AS ord,
         'Attachment added' AS action_performed,
         CAST(NULL AS VARCHAR2(400)) AS old_value,
         a.file_label || NVL2(a.category_name, ' (' || a.category_name || ')', NULL) AS new_value,
         INITCAP(REPLACE(h.document_status, '_', ' ')) AS transaction_status,
         CAST(NULL AS VARCHAR2(80)) AS approval_status,
         CAST(NULL AS VARCHAR2(60)) AS voucher_number
  FROM   att_base a
  JOIN   po_headers_all h ON TO_CHAR(h.po_header_id) = a.pk1_value
  CROSS JOIN prm
  WHERE  a.entity_name = 'PO_HEADERS'
  AND    prm.run_po = 'Y'
  UNION ALL
  SELECT 'Purchase Requisitions',
         a.created_by,
         a.creation_date,
         rh.requisition_number,
         rl.line_number,
         a.attached_document_id,
         'Line ' || rl.line_number || ' > Attachment added',
         CAST(NULL AS VARCHAR2(400)),
         a.file_label || NVL2(a.category_name, ' (' || a.category_name || ')', NULL),
         INITCAP(REPLACE(rh.document_status, '_', ' ')),
         INITCAP(REPLACE(rh.document_status, '_', ' ')),
         CAST(NULL AS VARCHAR2(60))
  FROM   att_base a
  JOIN   por_requisition_lines_all rl ON TO_CHAR(rl.requisition_line_id) = a.pk1_value
  JOIN   por_requisition_headers_all rh ON rh.requisition_header_id = rl.requisition_header_id
  CROSS JOIN prm
  WHERE  a.entity_name = 'POR_REQUISITION_LINES'
  AND    prm.run_pr = 'Y'
  UNION ALL
  SELECT 'Payments',
         a.created_by,
         a.creation_date,
         TO_CHAR(c.check_number),
         0,
         a.attached_document_id,
         'Attachment added',
         CAST(NULL AS VARCHAR2(400)),
         a.file_label || NVL2(a.category_name, ' (' || a.category_name || ')', NULL),
         INITCAP(REPLACE(c.status_lookup_code, '_', ' ')),
         CAST(NULL AS VARCHAR2(80)),
         TO_CHAR(c.doc_sequence_value)
  FROM   att_base a
  JOIN   ap_checks_all c ON TO_CHAR(c.check_id) = a.pk1_value
  CROSS JOIN prm
  WHERE  a.entity_name = 'AP_CHECKS_ALL'
  AND    prm.run_pay = 'Y'
),
gla_rows AS (
  SELECT 'General Ledger' AS product,
         NVL(l.user_id, l.created_by) AS username,
         l.creation_date AS change_ts,
         NVL(h.name, (SELECT MIN(hh.name) FROM gl_je_headers hh WHERE hh.je_batch_id = l.je_batch_id)) AS transaction_id,
         950 AS sub_ord,
         NVL(l.history_id, 0) AS ord,
         'Copy' AS action_performed,
         CAST(NULL AS VARCHAR2(400)) AS old_value,
         (SELECT MAX(t.name) FROM gl_je_headers t WHERE t.je_header_id = l.target_je_header_id) AS new_value,
         NVL((SELECT MAX(lv.meaning) FROM fnd_lookup_values_vl lv
              WHERE  lv.lookup_type = 'MJE_BATCH_STATUS' AND lv.lookup_code = b.status),
             DECODE(b.status, 'P', 'Posted', 'U', 'Unposted', b.status)) AS transaction_status,
         DECODE(b.approval_status_code,
                'A', 'Approved', 'I', 'In Process', 'J', 'Rejected', 'R', 'Required',
                'V', 'Validation Failed', 'Z', 'Not Required', b.approval_status_code) AS approval_status,
         TO_CHAR(NVL(h.posting_acct_seq_value, h.doc_sequence_value)) AS voucher_number
  FROM   gl_je_action_log l
  LEFT JOIN gl_je_headers h ON h.je_header_id = l.je_header_id
  LEFT JOIN gl_je_batches b ON b.je_batch_id = NVL(l.je_batch_id, h.je_batch_id)
  CROSS JOIN prm
  WHERE  prm.run_gl = 'Y'
  AND    UPPER(l.action_code) LIKE '%COPY%'
  AND    l.creation_date >= prm.from_utc
  AND    l.creation_date <  prm.to_utc
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR NVL(l.user_id, l.created_by) IN (:P_USERNAME))
)
,
ess_rows AS (
  SELECT 'Fixed Assets' AS product,
         e.username AS username,
         CAST(e.submission AS TIMESTAMP) AS change_ts,
         'Request ' || e.requestid AS transaction_id,
         0 AS sub_ord,
         0 AS ord,
         CASE WHEN UPPER(e.definition || ' ' || e.name) LIKE '%CLOSE%' THEN 'Close Period'
              ELSE 'Calculate Depreciation' END AS action_performed,
         CAST(NULL AS VARCHAR2(400)) AS old_value,
         SUBSTR(NVL(e.name, e.definition), 1, 400) AS new_value,
         DECODE(e.state, 1, 'Wait', 2, 'Ready', 3, 'Running', 4, 'Completed', 5, 'Blocked',
                         6, 'Hold', 7, 'Cancelling', 8, 'Expired', 9, 'Cancelled', 10, 'Error',
                         11, 'Warning', 12, 'Succeeded', 13, 'Paused', TO_CHAR(e.state)) AS transaction_status,
         CAST(NULL AS VARCHAR2(80)) AS approval_status,
         CAST(NULL AS VARCHAR2(60)) AS voucher_number
  FROM   ess_request_history e
  CROSS JOIN prm
  WHERE  prm.run_fa = 'Y'
  AND    LOWER(e.definition) LIKE '%assets%'
  AND   (UPPER(e.definition || ' ' || e.name) LIKE '%DEPRECIATION%'
         OR UPPER(e.definition || ' ' || e.name) LIKE '%DEPRN%'
         OR UPPER(e.definition || ' ' || e.name) LIKE '%CLOSE%PERIOD%'
         OR UPPER(e.definition || ' ' || e.name) LIKE '%PERIOD%CLOSE%')
  AND    CAST(e.submission AS TIMESTAMP) >= prm.from_utc
  AND    CAST(e.submission AS TIMESTAMP) <  prm.to_utc
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR e.username IN (:P_USERNAME))
)

SELECT r.product,
       r.username,
       NVL((SELECT MAX(p.display_name)
            FROM   per_users u
            JOIN   per_person_names_f p
                   ON  p.person_id = u.person_id
                   AND p.name_type = 'GLOBAL'
                   AND TRUNC(SYSDATE) BETWEEN p.effective_start_date AND p.effective_end_date
            WHERE  u.username = r.username), r.username) || ' (' || r.username || ')' AS user_label,
       TO_CHAR(FROM_TZ(CAST(r.change_ts AS TIMESTAMP), 'UTC') AT TIME ZONE 'Asia/Riyadh',
               'DD/MM/YYYY HH24:MI:SS')                                    AS change_date,
       r.transaction_id,
       r.action_performed,
       r.old_value,
       r.new_value,
       r.transaction_status,
       r.approval_status,
       r.voucher_number
FROM  (SELECT * FROM ap_rows
       UNION ALL
       SELECT * FROM po_rows
       UNION ALL
       SELECT * FROM gl_rows
       UNION ALL
       SELECT * FROM fa_rows
       UNION ALL
       SELECT * FROM ar_rows
       UNION ALL
       SELECT * FROM ce_rows
       UNION ALL
       SELECT * FROM att_rows
       UNION ALL
       SELECT * FROM gla_rows
       UNION ALL
       SELECT * FROM ess_rows) r
ORDER  BY r.product, r.username, r.change_ts, r.transaction_id, r.sub_ord, r.ord
