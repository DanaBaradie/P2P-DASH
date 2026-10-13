WITH
ldg AS (
  SELECT gl.ledger_id,
         gl.name                 AS ledger_name,
         gl.currency_code,
         gl.chart_of_accounts_id
  FROM   gl_ledgers gl
  WHERE  gl.name IN ('Juniors Jordan JO', 'QSR Jordan')
  AND    (:P_LEDGER_NAME IS NULL OR :P_LEDGER_NAME = 'All' OR gl.name = :P_LEDGER_NAME)
),

prd AS (
  SELECT ps.ledger_id,
         ps.period_name,
         ps.effective_period_num AS period_num
  FROM   ldg
  JOIN   gl_period_statuses ps
         ON ps.ledger_id = ldg.ledger_id
        AND ps.application_id = 101
  WHERE  ps.effective_period_num >= (SELECT MIN(f.effective_period_num)
                                     FROM   gl_period_statuses f
                                     WHERE  f.ledger_id = ldg.ledger_id
                                     AND    f.application_id = 101
                                     AND    f.period_name = :P_PERIOD_FROM)
  AND    ps.effective_period_num <= (SELECT MAX(t.effective_period_num)
                                     FROM   gl_period_statuses t
                                     WHERE  t.ledger_id = ldg.ledger_id
                                     AND    t.application_id = 101
                                     AND    t.period_name = :P_PERIOD_TO)
),
acc AS (
  SELECT ldg.ledger_id,
         ldg.ledger_name,
         ldg.currency_code,
         gcc.code_combination_id,
         gcc.chart_of_accounts_id,
         gcc.segment1||'-'||gcc.segment2||'-'||gcc.segment3||'-'||gcc.segment4||'-'||
         gcc.segment5||'-'||gcc.segment6||'-'||gcc.segment7||'-'||gcc.segment8 AS account_combination,
         gcc.segment3 AS natural_account
  FROM   ldg
  JOIN   gl_code_combinations gcc
         ON gcc.chart_of_accounts_id = ldg.chart_of_accounts_id
  WHERE  gcc.segment3 IN ('130090101', '230070102', '130100000', '130101000',
                          '130102000', '230070100', '230070101')
  AND    (:P_NATURAL_ACCOUNT IS NULL OR :P_NATURAL_ACCOUNT = 'All'
          OR gcc.segment3 = REGEXP_SUBSTR(:P_NATURAL_ACCOUNT, '^[0-9]+'))
),

gl_src AS (
  SELECT acc.ledger_id,
         acc.code_combination_id,
         gjh.period_name,
         gjs.user_je_source_name                               AS source,
         gjc.user_je_category_name                             AS category,
         NVL(xal.accounting_date, gjl.effective_date)          AS acct_date,
         NVL(xlk.meaning, xal.accounting_class_code)           AS accounting_class,
         xah.application_id,
         xah.ae_header_id,
         xal.ae_line_num,
         xah.event_id,
         xte.entity_code,
         xte.source_id_int_1,
         xte.transaction_number,
         xet.name                                              AS event_type,
         TO_CHAR(xah.doc_sequence_value)                       AS xla_voucher,
         CASE xah.gl_transfer_status_code
              WHEN 'Y'  THEN 'Transferred'
              WHEN 'N'  THEN 'Not Transferred'
              WHEN 'NT' THEN 'Not to be Transferred'
              WHEN 'S'  THEN 'Selected for Transfer'
         END                                                   AS transfer_to_gl_status,
         CASE WHEN gjh.status = 'P' THEN 'Posted' ELSE 'Unposted' END AS journal_status,
         TO_CHAR(NVL(gjh.posting_acct_seq_value, gjh.doc_sequence_value)) AS gl_sequence,
         gjh.je_header_id,
         gjl.je_line_num,
         CASE WHEN xal.ae_header_id IS NOT NULL THEN NVL(xal.accounted_dr, 0)
              ELSE NVL(gjl.accounted_dr, 0) END                AS debit,
         CASE WHEN xal.ae_header_id IS NOT NULL THEN NVL(xal.accounted_cr, 0)
              ELSE NVL(gjl.accounted_cr, 0) END                AS credit
  FROM   acc
  JOIN   gl_je_lines gjl
         ON gjl.code_combination_id = acc.code_combination_id
  JOIN   gl_je_headers gjh
         ON gjh.je_header_id = gjl.je_header_id
        AND gjh.ledger_id = acc.ledger_id
        AND gjh.actual_flag = 'A'
  JOIN   prd
         ON prd.ledger_id = gjh.ledger_id
        AND prd.period_name = gjh.period_name
  JOIN   gl_je_sources_vl gjs    ON gjs.je_source_name = gjh.je_source
  JOIN   gl_je_categories_vl gjc ON gjc.je_category_name = gjh.je_category
  LEFT JOIN (gl_import_references gir
             JOIN xla_ae_lines xal
                  ON xal.gl_sl_link_id = gir.gl_sl_link_id
                 AND xal.gl_sl_link_table = gir.gl_sl_link_table)
         ON gir.je_header_id = gjl.je_header_id
        AND gir.je_line_num = gjl.je_line_num
  LEFT JOIN xla_ae_headers xah
         ON xah.ae_header_id = xal.ae_header_id
        AND xah.application_id = xal.application_id
  LEFT JOIN xla_events xe
         ON xe.event_id = xah.event_id
        AND xe.application_id = xah.application_id
  LEFT JOIN xla_transaction_entities xte
         ON xte.entity_id = xah.entity_id
        AND xte.application_id = xah.application_id
  LEFT JOIN xla_event_types_tl xet
         ON xet.application_id = xe.application_id
        AND xet.entity_code = xte.entity_code
        AND xet.event_type_code = xe.event_type_code
        AND xet.language = USERENV('LANG')
  LEFT JOIN xla_lookups xlk
         ON xlk.lookup_type = 'XLA_ACCOUNTING_CLASS'
        AND xlk.lookup_code = xal.accounting_class_code
  WHERE  (:P_JOURNAL_SOURCE IS NULL OR :P_JOURNAL_SOURCE = 'All'
          OR gjs.user_je_source_name = :P_JOURNAL_SOURCE)
),

det AS (
  SELECT l.*,
         aia.invoice_num                                       AS invoice_number,
         NVL(l.xla_voucher, TO_CHAR(aia.doc_sequence_value))   AS voucher_number,
         NVL(sup_ap.segment1, sup_rcv.segment1)                AS supplier_number,
         NVL(sup_ap.vendor_name, sup_rcv.vendor_name)          AS supplier_name,
         CASE WHEN rcv.event_source = 'PO' THEN rcv.source_doc_number
              WHEN l.application_id = 707 AND l.entity_code = 'PO_DELIVERY_INTO_INVENTORY'
              THEN l.transaction_number END                    AS po_number,
         NVL(rcv.sla_transaction_number,
             CASE WHEN ct.txn_source_doc_type = 'RCV' THEN ct.txn_source_doc_number END) AS receipt_number,
         esi.item_number                                       AS item,
         NVL(bu_ap.bu_name, bu_rcv.bu_name)                    AS business_unit
  FROM   gl_src l
  LEFT JOIN ap_invoices_all aia
         ON l.entity_code = 'AP_INVOICES'
        AND aia.invoice_id = l.source_id_int_1
  OUTER APPLY (
         SELECT ce.source_doc_number,
                ce.event_source,
                ce.ship_from_inv_org_id,
                ce.sla_transaction_number,
                ce.vendor_id,
                ce.inventory_item_id,
                ce.inventory_org_id,
                ce.business_unit_id
         FROM   cmr_rcv_events ce
         WHERE  ce.event_id = l.event_id
         AND    l.application_id <> 200
         ORDER  BY (SELECT COUNT(*)
                    FROM   xla_distribution_links xdl
                    JOIN   cmr_rcv_distributions crd
                           ON crd.cmr_sub_ledger_id = xdl.source_distribution_id_num_1
                    WHERE  xdl.application_id = l.application_id
                    AND    xdl.ae_header_id = l.ae_header_id
                    AND    xdl.ae_line_num = l.ae_line_num
                    AND    crd.accounting_event_id = ce.accounting_event_id) DESC,
                   ce.accounting_event_id
         FETCH FIRST 1 ROW ONLY
  ) rcv
  LEFT JOIN poz_suppliers_v sup_ap  ON sup_ap.vendor_id  = aia.vendor_id
  LEFT JOIN poz_suppliers_v sup_rcv ON sup_rcv.vendor_id = rcv.vendor_id
  LEFT JOIN inv_material_txns imt
         ON ((l.application_id = 707   AND l.entity_code IN ('TRADE_COST_ACCOUNTING', 'DIRECT_INTERORG_TRANSFER'))
          OR (l.application_id = 10096 AND l.entity_code = 'TRADE_ACCRUALS'))
        AND imt.transaction_id = CASE WHEN REGEXP_LIKE(l.transaction_number, '^[0-9]+$')
                                      THEN TO_NUMBER(l.transaction_number) END
  LEFT JOIN cst_cost_distributions ccd
         ON l.application_id = 707
        AND l.entity_code = 'PO_DELIVERY_INTO_INVENTORY'
        AND ccd.distribution_id = l.source_id_int_1
  LEFT JOIN cst_transactions ct
         ON ct.transaction_id = ccd.transaction_id
  LEFT JOIN egp_system_items_b esi
         ON esi.inventory_item_id = COALESCE(rcv.inventory_item_id, imt.inventory_item_id, ct.inventory_item_id)
        AND esi.organization_id = COALESCE(rcv.inventory_org_id, imt.organization_id, ct.inventory_org_id)
  LEFT JOIN fun_all_business_units_v bu_ap  ON bu_ap.bu_id  = aia.org_id
  LEFT JOIN fun_all_business_units_v bu_rcv ON bu_rcv.bu_id = rcv.business_unit_id
  WHERE  (:P_BUSINESS_UNIT IS NULL OR :P_BUSINESS_UNIT = 'All'
          OR NVL(bu_ap.bu_name, bu_rcv.bu_name) = :P_BUSINESS_UNIT)
),

bal AS (
  SELECT acc.ledger_id,
         acc.ledger_name,
         acc.code_combination_id,
         acc.chart_of_accounts_id,
         acc.account_combination,
         acc.natural_account,
         prd.period_name,
         prd.period_num,
         NVL((SELECT MAX(NVL(b.begin_balance_dr, 0) - NVL(b.begin_balance_cr, 0)
                       + NVL(b.period_net_dr, 0)   - NVL(b.period_net_cr, 0))
                     KEEP (DENSE_RANK LAST ORDER BY b.period_year, b.period_num)
              FROM   gl_balances b
              WHERE  b.ledger_id = acc.ledger_id
              AND    b.code_combination_id = acc.code_combination_id
              AND    b.currency_code = acc.currency_code
              AND    b.actual_flag = 'A'
              AND    NVL(b.translated_flag, 'X') NOT IN ('Y', 'R')
              AND    b.period_year * 10000 + b.period_num < prd.period_num), 0)
       + NVL((SELECT SUM(NVL(ugl.accounted_dr, 0) - NVL(ugl.accounted_cr, 0))
              FROM   gl_je_lines ugl
              JOIN   gl_je_headers ugh
                     ON ugh.je_header_id = ugl.je_header_id
              JOIN   gl_period_statuses ups
                     ON ups.ledger_id = ugh.ledger_id
                    AND ups.application_id = 101
                    AND ups.period_name = ugh.period_name
              WHERE  ugl.code_combination_id = acc.code_combination_id
              AND    ugh.ledger_id = acc.ledger_id
              AND    ugh.actual_flag = 'A'
              AND    ugh.status <> 'P'
              AND    ups.effective_period_num < prd.period_num), 0) AS opening_balance
  FROM   acc
  JOIN   prd ON prd.ledger_id = acc.ledger_id
),

scope AS (
  SELECT b.*
  FROM   bal b
  WHERE  EXISTS (SELECT 1 FROM det d
                 WHERE  d.ledger_id = b.ledger_id
                 AND    d.code_combination_id = b.code_combination_id)
  OR     EXISTS (SELECT 1 FROM bal b2
                 WHERE  b2.ledger_id = b.ledger_id
                 AND    b2.code_combination_id = b.code_combination_id
                 AND    b2.opening_balance <> 0)
)
SELECT s.ledger_name,
       s.ledger_id || '-' || s.code_combination_id                    AS account_key,
       s.account_combination,
       gl_flexfields_pkg.get_concat_description(s.chart_of_accounts_id,
                                                s.code_combination_id) AS account_description,
       s.natural_account,
       gl_flexfields_pkg.get_description_sql(s.chart_of_accounts_id, 3,
                                             s.natural_account)        AS natural_account_description,
       s.period_name,
       s.period_num,
       s.opening_balance,
       SUM(NVL(d.debit, 0))  OVER (PARTITION BY s.ledger_id, s.code_combination_id, s.period_name) AS period_debit,
       SUM(NVL(d.credit, 0)) OVER (PARTITION BY s.ledger_id, s.code_combination_id, s.period_name) AS period_credit,
       s.opening_balance
         + SUM(NVL(d.debit, 0) - NVL(d.credit, 0))
             OVER (PARTITION BY s.ledger_id, s.code_combination_id, s.period_name)          AS closing_balance,
       NVL(d.source, 'No activity in this period')                    AS source,
       d.category,
       TO_CHAR(d.acct_date, 'DD-Mon-YYYY', 'NLS_DATE_LANGUAGE=AMERICAN') AS accounting_date,
       d.accounting_class,
       d.invoice_number,
       d.voucher_number,
       d.supplier_number,
       d.supplier_name,
       d.transfer_to_gl_status,
       d.journal_status,
       d.po_number,
       d.receipt_number,
       d.item,
       d.gl_sequence,
       TO_CHAR(d.ae_header_id)                                        AS journal_entry,
       d.event_type,
       d.business_unit,
       CASE WHEN d.debit  <> 0 THEN d.debit  END                      AS debit,
       CASE WHEN d.credit <> 0 THEN d.credit END                      AS credit
FROM   scope s
LEFT JOIN det d
       ON d.ledger_id = s.ledger_id
      AND d.code_combination_id = s.code_combination_id
      AND d.period_name = s.period_name
ORDER  BY s.ledger_name,
          s.account_combination,
          s.period_num,
          d.acct_date,
          d.je_header_id,
          d.je_line_num,
          d.ae_header_id,
          d.ae_line_num
