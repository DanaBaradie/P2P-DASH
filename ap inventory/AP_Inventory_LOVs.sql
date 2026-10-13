/* =====================================================================
   AP-Inventory Report - Lists of Values
   Paste each one into its own LOV in the data model.
   ===================================================================== */

/* ---------- LOV_LEDGER  ->  P_LEDGER_NAME  (default: Juniors Jordan JO) */
SELECT ledger_name
FROM (
  SELECT 'All' AS ledger_name, 0 AS sort_key FROM dual
  UNION ALL
  SELECT name, 1 FROM gl_ledgers WHERE name IN ('Juniors Jordan JO', 'QSR Jordan')
)
ORDER BY sort_key, ledger_name


/* ---------- LOV_BUSINESS_UNIT  ->  P_BUSINESS_UNIT  (default: All)
   Parameter refresh: set "Refresh other parameters on change" on P_LEDGER_NAME */
SELECT bu_name
FROM (
  SELECT 'All' AS bu_name, 0 AS sort_key FROM dual
  UNION ALL
  SELECT DISTINCT bu.bu_name, 1
  FROM   fun_all_business_units_v bu
  JOIN   gl_ledgers gl ON gl.ledger_id = bu.primary_ledger_id
  WHERE  gl.name IN ('Juniors Jordan JO', 'QSR Jordan')
  AND    (:P_LEDGER_NAME IS NULL OR :P_LEDGER_NAME = 'All' OR gl.name = :P_LEDGER_NAME)
)
ORDER BY sort_key, bu_name


/* ---------- LOV_JOURNAL_SOURCE  ->  P_JOURNAL_SOURCE  (default: All) */
SELECT 'All' FROM dual
UNION ALL SELECT 'Manual' FROM dual
UNION ALL SELECT 'Payables' FROM dual
UNION ALL SELECT 'Receipt Accounting' FROM dual
UNION ALL SELECT 'Cost Accounting' FROM dual
UNION ALL SELECT 'Spreadsheet' FROM dual


/* ---------- LOV_NATURAL_ACCOUNT  ->  P_NATURAL_ACCOUNT  (default: All) */
SELECT 'All' FROM dual
UNION ALL SELECT '130090101 - Receiving Inspection' FROM dual
UNION ALL SELECT '230070102 - Landed Cost Clearing' FROM dual
UNION ALL SELECT '130100000 - Trade In-Transit Valuation' FROM dual
UNION ALL SELECT '130101000 - Trade Clearing' FROM dual
UNION ALL SELECT '130102000 - Interorganization Payables' FROM dual
UNION ALL SELECT '230070100 - Inventory Accrual' FROM dual
UNION ALL SELECT '230070101 - Expense Accrual' FROM dual


/* ---------- LOV_PERIOD  ->  P_PERIOD_FROM and P_PERIOD_TO  (both required)
   Newest first, in calendar order (not alphabetical). Adjustment periods
   are left out of the list but are still included when they fall inside
   the From-To range. */
SELECT period_name
FROM (
  SELECT ps.period_name,
         MAX(ps.effective_period_num) AS period_num
  FROM   gl_period_statuses ps
  JOIN   gl_ledgers gl ON gl.ledger_id = ps.ledger_id
  WHERE  ps.application_id = 101
  AND    ps.adjustment_period_flag = 'N'
  AND    ps.closing_status <> 'N'
  AND    gl.name IN ('Juniors Jordan JO', 'QSR Jordan')
  AND    (:P_LEDGER_NAME IS NULL OR :P_LEDGER_NAME = 'All' OR gl.name = :P_LEDGER_NAME)
  GROUP  BY ps.period_name
)
ORDER BY period_num DESC
