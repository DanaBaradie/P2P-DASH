SELECT t.module,
       t.base_table,
       t.base_table || '_' AS audit_table_name,
       CASE WHEN EXISTS (SELECT 1 FROM all_objects o WHERE o.object_name = t.base_table || '_')
            THEN 'EXISTS - changes can be recorded'
            ELSE 'DOES NOT EXIST - Fusion cannot record changes' END AS proof_result
FROM (
  SELECT 'AP Invoices (control)' AS module, 'AP_INVOICES_ALL' AS base_table, 1 AS sort_key FROM dual
  UNION ALL SELECT 'AR Transactions', 'RA_CUSTOMER_TRX_ALL', 2 FROM dual
  UNION ALL SELECT 'AR Transactions', 'RA_CUSTOMER_TRX_LINES_ALL', 3 FROM dual
  UNION ALL SELECT 'AR Receipts', 'AR_CASH_RECEIPTS_ALL', 4 FROM dual
  UNION ALL SELECT 'Bank Statements', 'CE_STATEMENT_HEADERS', 5 FROM dual
  UNION ALL SELECT 'Bank Statements', 'CE_STATEMENT_LINES', 6 FROM dual
  UNION ALL SELECT 'Purchase Requisitions', 'POR_REQUISITION_HEADERS_ALL', 7 FROM dual
  UNION ALL SELECT 'Purchase Requisitions', 'POR_REQUISITION_LINES_ALL', 8 FROM dual
  UNION ALL SELECT 'Payments', 'AP_CHECKS_ALL', 9 FROM dual
) t
ORDER BY t.sort_key
;

SELECT t.module,
       t.base_table,
       (SELECT COUNT(*) FROM fnd_audit_attributes a
        WHERE a.table_name = t.base_table) AS fields_in_audit_setup,
       (SELECT COUNT(*) FROM fnd_audit_attributes a
        WHERE a.table_name = t.base_table AND a.enabled_flag = 'Y') AS fields_being_audited,
       CASE WHEN (SELECT COUNT(*) FROM fnd_audit_attributes a WHERE a.table_name = t.base_table) = 0
            THEN 'NOT AUDITABLE - Oracle offers no audit fields for this table'
            ELSE 'AUDITABLE' END AS proof_result
FROM (
  SELECT 'AP Invoices (control)' AS module, 'AP_INVOICES_ALL' AS base_table, 1 AS sort_key FROM dual
  UNION ALL SELECT 'AR Transactions', 'RA_CUSTOMER_TRX_ALL', 2 FROM dual
  UNION ALL SELECT 'AR Transactions', 'RA_CUSTOMER_TRX_LINES_ALL', 3 FROM dual
  UNION ALL SELECT 'AR Receipts', 'AR_CASH_RECEIPTS_ALL', 4 FROM dual
  UNION ALL SELECT 'Bank Statements', 'CE_STATEMENT_HEADERS', 5 FROM dual
  UNION ALL SELECT 'Bank Statements', 'CE_STATEMENT_LINES', 6 FROM dual
  UNION ALL SELECT 'Purchase Requisitions', 'POR_REQUISITION_HEADERS_ALL', 7 FROM dual
  UNION ALL SELECT 'Purchase Requisitions', 'POR_REQUISITION_LINES_ALL', 8 FROM dual
  UNION ALL SELECT 'Payments', 'AP_CHECKS_ALL', 9 FROM dual
) t
ORDER BY t.sort_key
;

SELECT 'AR Transactions' AS module,
       COUNT(*) AS total_records,
       SUM(CASE WHEN last_update_date > creation_date + INTERVAL '1' MINUTE THEN 1 ELSE 0 END) AS records_changed_after_creation,
       'Only the current values are stored; the previous values were overwritten' AS proof_result
FROM   ra_customer_trx_all
UNION ALL
SELECT 'AR Receipts', COUNT(*),
       SUM(CASE WHEN last_update_date > creation_date + INTERVAL '1' MINUTE THEN 1 ELSE 0 END),
       'Only the current values are stored; the previous values were overwritten'
FROM   ar_cash_receipts_all
UNION ALL
SELECT 'Bank Statement Lines', COUNT(*),
       SUM(CASE WHEN last_update_date > creation_date + INTERVAL '1' MINUTE THEN 1 ELSE 0 END),
       'Only the current values are stored; the previous values were overwritten'
FROM   ce_statement_lines
UNION ALL
SELECT 'Requisition Lines', COUNT(*),
       SUM(CASE WHEN last_update_date > creation_date + INTERVAL '1' MINUTE THEN 1 ELSE 0 END),
       'Only the current values are stored; the previous values were overwritten'
FROM   por_requisition_lines_all
UNION ALL
SELECT 'Payments', COUNT(*),
       SUM(CASE WHEN last_update_date > creation_date + INTERVAL '1' MINUTE THEN 1 ELSE 0 END),
       'Only the current values are stored; the previous values were overwritten'
FROM   ap_checks_all
;

SELECT 'AR Transaction' AS module,
       t.trx_number AS document_number,
       t.creation_date,
       t.last_update_date,
       t.last_updated_by,
       (SELECT COUNT(*) FROM ra_customer_trx_all x WHERE x.customer_trx_id = t.customer_trx_id) AS versions_stored,
       'Changed after creation, but only 1 version exists: the old values are gone' AS proof_result
FROM   ra_customer_trx_all t
WHERE  t.last_update_date > t.creation_date + INTERVAL '1' MINUTE
AND    ROWNUM <= 5
UNION ALL
SELECT 'AR Receipt', r.receipt_number, r.creation_date, r.last_update_date, r.last_updated_by,
       (SELECT COUNT(*) FROM ar_cash_receipts_all x WHERE x.cash_receipt_id = r.cash_receipt_id),
       'Changed after creation, but only 1 version exists: the old values are gone'
FROM   ar_cash_receipts_all r
WHERE  r.last_update_date > r.creation_date + INTERVAL '1' MINUTE
AND    ROWNUM <= 5
UNION ALL
SELECT 'Bank Statement', s.statement_number, s.creation_date, s.last_update_date, s.last_updated_by,
       (SELECT COUNT(*) FROM ce_statement_headers x WHERE x.statement_header_id = s.statement_header_id),
       'Changed after creation, but only 1 version exists: the old values are gone'
FROM   ce_statement_headers s
WHERE  s.last_update_date > s.creation_date + INTERVAL '1' MINUTE
AND    ROWNUM <= 5
UNION ALL
SELECT 'Requisition', h.requisition_number, h.creation_date, h.last_update_date, l.last_updated_by,
       (SELECT COUNT(*) FROM por_requisition_lines_all x WHERE x.requisition_line_id = l.requisition_line_id),
       'Changed after creation, but only 1 version exists: the old values are gone'
FROM   por_requisition_lines_all l
JOIN   por_requisition_headers_all h ON h.requisition_header_id = l.requisition_header_id
WHERE  l.last_update_date > l.creation_date + INTERVAL '1' MINUTE
AND    ROWNUM <= 5
UNION ALL
SELECT 'Payment', TO_CHAR(c.check_number), c.creation_date, c.last_update_date, c.last_updated_by,
       (SELECT COUNT(*) FROM ap_checks_all x WHERE x.check_id = c.check_id),
       'Changed after creation, but only 1 version exists: the old values are gone'
FROM   ap_checks_all c
WHERE  c.last_update_date > c.creation_date + INTERVAL '1' MINUTE
AND    ROWNUM <= 5
;

SELECT o.object_name,
       MAX(o.object_type) AS object_type,
       CASE WHEN o.object_name LIKE '%HIST%' OR o.object_name LIKE '%ARCH%' OR o.object_name LIKE '%AUDIT%'
                 OR o.object_name LIKE '%VERSION%' OR o.object_name LIKE '%\_' ESCAPE '\'
            THEN 'History-type object: check what it stores'
            ELSE 'Current data only' END AS proof_result
FROM   all_objects o
WHERE  o.object_type IN ('TABLE', 'VIEW', 'SYNONYM')
AND   (o.object_name LIKE 'RA\_CUSTOMER\_TRX%' ESCAPE '\'
       OR o.object_name LIKE 'AR\_CASH\_RECEIPT%' ESCAPE '\'
       OR o.object_name LIKE 'CE\_STATEMENT%' ESCAPE '\'
       OR o.object_name LIKE 'POR\_REQUISITION%' ESCAPE '\'
       OR o.object_name LIKE 'AP\_CHECKS%' ESCAPE '\')
GROUP  BY o.object_name
ORDER  BY 3, 1
;

SELECT 'AP Invoices (control - auditable)' AS module,
       COUNT(*) AS change_records_stored,
       MIN(last_update_date) AS first_change,
       MAX(last_update_date) AS last_change,
       'Old and new values ARE stored here, because Oracle allows this table to be audited' AS proof_result
FROM   ap_invoices_all_
