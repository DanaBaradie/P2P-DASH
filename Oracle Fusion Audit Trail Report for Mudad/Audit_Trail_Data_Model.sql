WITH
prm AS (
  SELECT CAST(FROM_TZ(CAST(NVL(CAST(:P_FROM_DATE AS DATE), TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'Asia/Riyadh' AS DATE))) AS TIMESTAMP), 'Asia/Riyadh') AT TIME ZONE 'UTC' AS TIMESTAMP)     AS from_utc,
         CAST(FROM_TZ(CAST(NVL(CAST(:P_TO_DATE AS DATE), TRUNC(CAST(SYSTIMESTAMP AT TIME ZONE 'Asia/Riyadh' AS DATE))) + 1 AS TIMESTAMP), 'Asia/Riyadh') AT TIME ZONE 'UTC' AS TIMESTAMP) AS to_utc,
         'Y' AS run_gl
  FROM   dual
),
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
  WHERE  r.reversed_je_header_id IS NOT NULL
  AND    r.creation_date >= prm.from_utc
  AND    r.creation_date <  prm.to_utc
),
glc_chg AS (
  SELECT l.je_header_id,
         l.je_batch_id,
         CAST(NULL AS VARCHAR2(100)) AS audit_name,
         l.creation_date AS change_ts,
         NVL(l.user_id, l.created_by) AS username,
         CAST(NULL AS VARCHAR2(80)) AS level_lbl,
         950 AS sub_ord,
         0 AS ord,
         'Copy' AS lbl,
         'RAW' AS dec_type,
         CAST(NULL AS VARCHAR2(400)) AS old_raw,
         (SELECT MAX(t.name) FROM gl_je_headers t WHERE t.je_header_id = l.target_je_header_id) AS new_raw,
         'Y' AS is_event,
         CAST(NULL AS TIMESTAMP) AS old_written_ts,
         CAST(NULL AS TIMESTAMP) AS enabled_ts
  FROM   gl_je_action_log l
  CROSS JOIN prm
  WHERE  UPPER(l.action_code) LIKE '%COPY%'
  AND    l.creation_date >= prm.from_utc
  AND    l.creation_date <  prm.to_utc
),
gl_all AS (
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM glb_chg
  UNION ALL
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM glh_chg
  UNION ALL
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM gll_chg
  UNION ALL
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM glr_chg
  UNION ALL
  SELECT je_header_id, je_batch_id, audit_name, change_ts, username, level_lbl, sub_ord, ord, lbl, dec_type, old_raw, new_raw, is_event, old_written_ts, enabled_ts FROM glc_chg
),
gl_rows AS (
  SELECT c.username,
         c.change_ts,
         CASE WHEN c.je_header_id IS NOT NULL
              THEN NVL(h.name, c.audit_name)
              ELSE NVL((SELECT MIN(hh.name) FROM gl_je_headers hh WHERE hh.je_batch_id = c.je_batch_id), 'Deleted journal')
         END                                                               AS transaction_id,
         c.sub_ord,
         c.ord,
         c.level_lbl || c.lbl                                              AS action_performed,
         NVL(CASE c.dec_type
           WHEN 'ACCOUNT' THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                 cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                 cc.segment9 || '-' || cc.segment10, '-'))
                                FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.old_raw))
           WHEN 'GLCAT'   THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.old_raw)
           WHEN 'REVMETH' THEN DECODE(c.old_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.old_raw)
         END, c.old_raw) AS old_value,
         NVL(CASE c.dec_type
           WHEN 'ACCOUNT' THEN (SELECT MAX(RTRIM(cc.segment1 || '-' || cc.segment2 || '-' || cc.segment3 || '-' || cc.segment4 || '-' ||
                                                 cc.segment5 || '-' || cc.segment6 || '-' || cc.segment7 || '-' || cc.segment8 || '-' ||
                                                 cc.segment9 || '-' || cc.segment10, '-'))
                                FROM gl_code_combinations cc WHERE cc.code_combination_id = TO_NUMBER(c.new_raw))
           WHEN 'GLCAT'   THEN (SELECT MAX(jc.user_je_category_name) FROM gl_je_categories_vl jc WHERE jc.je_category_name = c.new_raw)
           WHEN 'REVMETH' THEN DECODE(c.new_raw, 'Y', 'Change Sign', 'N', 'Switch Debit/Credit', c.new_raw)
         END, c.new_raw) AS new_value,
         bt.status AS status_code,
         bt.approval_status_code,
         TO_CHAR(NVL(h.posting_acct_seq_value, h.doc_sequence_value))      AS voucher_number
  FROM   gl_all c
  LEFT JOIN gl_je_headers h  ON h.je_header_id = c.je_header_id
  LEFT JOIN gl_je_batches bt ON bt.je_batch_id = NVL(c.je_batch_id, h.je_batch_id)
  WHERE  (c.is_event = 'Y' OR DECODE(c.old_raw, c.new_raw, 0, 1) = 1)
  AND    (c.old_raw IS NOT NULL OR c.old_written_ts IS NULL OR c.enabled_ts IS NULL
          OR c.old_written_ts >= c.enabled_ts)
  AND    (COALESCE(NULL, :P_USERNAME) IS NULL OR c.username IN (:P_USERNAME))
)
SELECT 'General Ledger' AS product,
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
       NVL((SELECT MAX(lv.meaning)
            FROM   fnd_lookup_values_vl lv
            WHERE  lv.lookup_type = 'MJE_BATCH_STATUS'
            AND    lv.lookup_code = r.status_code),
           DECODE(r.status_code, 'P', 'Posted', 'U', 'Unposted', r.status_code)) AS transaction_status,
       DECODE(r.approval_status_code,
              'A', 'Approved', 'I', 'In Process', 'J', 'Rejected', 'R', 'Required',
              'V', 'Validation Failed', 'Z', 'Not Required',
              r.approval_status_code)                                      AS approval_status,
       r.voucher_number
FROM   gl_rows r
ORDER  BY r.username, r.change_ts, r.transaction_id, r.sub_ord, r.ord
