-- G_12  One row that feeds the whole overview page: scope, six stages, PR/PO totals by status, routes.
-- Amounts are returned pre-formatted (1,234.50) so the page reads cleanly; % values include the sign.
-- 'Other' = every status not listed separately, so each panel always adds up to 'All Statuses'.
WITH prs AS (
  SELECT prh.requisition_header_id,
         prh.requisition_number,
         UPPER(REPLACE(prh.document_status, '_', ' ')) AS status,
         (SELECT NVL(SUM(l.quantity * l.unit_price), 0)
          FROM   por_requisition_lines_all l
          WHERE  l.requisition_header_id = prh.requisition_header_id) AS amt
  FROM   por_requisition_headers_all prh
  WHERE  (:P_PR_NUMBER IS NULL OR prh.requisition_number = :P_PR_NUMBER)
),
tot AS (
  SELECT COUNT(*) AS c FROM prs
),
pr_rfq AS (
  SELECT DISTINCT prs.requisition_header_id, ai.auction_header_id
  FROM   prs
  JOIN   pon_auction_item_prices_all ai ON ai.requisition_number = prs.requisition_number
),
pr_po AS (
  SELECT DISTINCT prl.requisition_header_id, pda.po_header_id
  FROM   prs
  JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = prs.requisition_header_id
  JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
  JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
),
po_amt AS (
  SELECT poh.po_header_id,
         UPPER(REPLACE(poh.document_status, '_', ' ')) AS status,
         NVL(SUM(pda.quantity_ordered * pll.price_override
                 + NVL(pda.nonrecoverable_tax, 0) + NVL(pda.recoverable_tax, 0)), 0) AS amt
  FROM   po_headers_all poh
  LEFT JOIN po_line_locations_all pll ON pll.po_header_id     = poh.po_header_id
  LEFT JOIN po_distributions_all  pda ON pda.line_location_id = pll.line_location_id
  WHERE  poh.po_header_id IN (SELECT po_header_id FROM pr_po)
  GROUP  BY poh.po_header_id, poh.document_status
),
pr_rcv AS (
  SELECT DISTINCT pp.requisition_header_id, rt.shipment_header_id
  FROM   pr_po pp
  JOIN   rcv_transactions rt ON rt.po_header_id = pp.po_header_id
  WHERE  rt.transaction_type = 'RECEIVE'
),
pr_inv AS (
  SELECT DISTINCT pp.requisition_header_id, ail.invoice_id
  FROM   pr_po pp
  JOIN   ap_invoice_lines_all ail ON ail.po_header_id = pp.po_header_id
),
pr_pay AS (
  SELECT DISTINCT pi.requisition_header_id, aip.invoice_payment_id, aip.check_id, aip.amount
  FROM   pr_inv pi
  JOIN   ap_invoice_payments_all aip ON aip.invoice_id = pi.invoice_id
  WHERE  NVL(aip.reversal_flag, 'N') = 'N'
),
stages AS (
  SELECT 1 AS stage_order, 'Purchase Requisition' AS stage_name,
         (SELECT COUNT(*) FROM prs) AS stage_count,
         (SELECT NVL(SUM(amt), 0) FROM prs) AS stage_amount,
         (SELECT COUNT(*) FROM prs) AS prs_reached
  FROM dual
  UNION ALL
  SELECT 2, 'RFQ / Negotiation',
         (SELECT COUNT(DISTINCT auction_header_id) FROM pr_rfq),
         (SELECT NVL(SUM(b.buyer_bid_total), 0)
          FROM   pon_bid_headers b
          WHERE  b.auction_header_id IN (SELECT auction_header_id FROM pr_rfq)
          AND    b.bid_status = 'ACTIVE'
          AND    (b.award_status = 'AWARDED' OR NVL(b.total_award_amount, 0) > 0)),
         (SELECT COUNT(DISTINCT requisition_header_id) FROM pr_rfq)
  FROM dual
  UNION ALL
  SELECT 3, 'Purchase Order',
         (SELECT COUNT(*) FROM po_amt),
         (SELECT NVL(SUM(amt), 0) FROM po_amt),
         (SELECT COUNT(DISTINCT requisition_header_id) FROM pr_po)
  FROM dual
  UNION ALL
  SELECT 4, 'Receipt',
         (SELECT COUNT(DISTINCT shipment_header_id) FROM pr_rcv),
         (SELECT NVL(SUM(rt.quantity * pll.price_override), 0)
          FROM   rcv_transactions rt
          JOIN   po_line_locations_all pll ON pll.line_location_id = rt.po_line_location_id
          WHERE  rt.transaction_type = 'RECEIVE'
          AND    rt.po_header_id IN (SELECT po_header_id FROM pr_po)),
         (SELECT COUNT(DISTINCT requisition_header_id) FROM pr_rcv)
  FROM dual
  UNION ALL
  SELECT 5, 'Invoice',
         (SELECT COUNT(DISTINCT invoice_id) FROM pr_inv),
         (SELECT NVL(SUM(aia.invoice_amount), 0)
          FROM   ap_invoices_all aia
          WHERE  aia.invoice_id IN (SELECT invoice_id FROM pr_inv)),
         (SELECT COUNT(DISTINCT requisition_header_id) FROM pr_inv)
  FROM dual
  UNION ALL
  SELECT 6, 'Payment',
         (SELECT COUNT(DISTINCT check_id) FROM pr_pay),
         (SELECT NVL(SUM(amount), 0) FROM (SELECT DISTINCT invoice_payment_id, amount FROM pr_pay)),
         (SELECT COUNT(DISTINCT requisition_header_id) FROM pr_pay)
  FROM dual
),
routes AS (
  SELECT CASE
           WHEN EXISTS (SELECT 1 FROM pr_rfq r WHERE r.requisition_header_id = prs.requisition_header_id) THEN 'RFQ'
           WHEN EXISTS (SELECT 1 FROM pr_po  p WHERE p.requisition_header_id = prs.requisition_header_id) THEN 'DIRECT'
           ELSE 'NONE'
         END AS route
  FROM   prs
)
SELECT sc.*, st.*, pr.*, po.*, ro.*
FROM  (SELECT NVL(:P_PR_NUMBER, 'All purchase requisitions') AS scope_label,
              TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI')         AS as_of
       FROM dual) sc,
      (SELECT
         MAX(CASE WHEN s.stage_order = 1 THEN s.stage_count END) AS s1_count,
         TO_CHAR(NVL(MAX(CASE WHEN s.stage_order = 1 THEN s.stage_amount END), 0), 'FM999,999,999,990.00') AS s1_amount,
         NVL(ROUND(100 * MAX(CASE WHEN s.stage_order = 1 THEN s.prs_reached END) / NULLIF(MAX(t.c), 0)), 0) || '%' AS s1_pct,
         MAX(CASE WHEN s.stage_order = 2 THEN s.stage_count END) AS s2_count,
         TO_CHAR(NVL(MAX(CASE WHEN s.stage_order = 2 THEN s.stage_amount END), 0), 'FM999,999,999,990.00') AS s2_amount,
         NVL(ROUND(100 * MAX(CASE WHEN s.stage_order = 2 THEN s.prs_reached END) / NULLIF(MAX(t.c), 0)), 0) || '%' AS s2_pct,
         MAX(CASE WHEN s.stage_order = 3 THEN s.stage_count END) AS s3_count,
         TO_CHAR(NVL(MAX(CASE WHEN s.stage_order = 3 THEN s.stage_amount END), 0), 'FM999,999,999,990.00') AS s3_amount,
         NVL(ROUND(100 * MAX(CASE WHEN s.stage_order = 3 THEN s.prs_reached END) / NULLIF(MAX(t.c), 0)), 0) || '%' AS s3_pct,
         MAX(CASE WHEN s.stage_order = 4 THEN s.stage_count END) AS s4_count,
         TO_CHAR(NVL(MAX(CASE WHEN s.stage_order = 4 THEN s.stage_amount END), 0), 'FM999,999,999,990.00') AS s4_amount,
         NVL(ROUND(100 * MAX(CASE WHEN s.stage_order = 4 THEN s.prs_reached END) / NULLIF(MAX(t.c), 0)), 0) || '%' AS s4_pct,
         MAX(CASE WHEN s.stage_order = 5 THEN s.stage_count END) AS s5_count,
         TO_CHAR(NVL(MAX(CASE WHEN s.stage_order = 5 THEN s.stage_amount END), 0), 'FM999,999,999,990.00') AS s5_amount,
         NVL(ROUND(100 * MAX(CASE WHEN s.stage_order = 5 THEN s.prs_reached END) / NULLIF(MAX(t.c), 0)), 0) || '%' AS s5_pct,
         MAX(CASE WHEN s.stage_order = 6 THEN s.stage_count END) AS s6_count,
         TO_CHAR(NVL(MAX(CASE WHEN s.stage_order = 6 THEN s.stage_amount END), 0), 'FM999,999,999,990.00') AS s6_amount,
         NVL(ROUND(100 * MAX(CASE WHEN s.stage_order = 6 THEN s.prs_reached END) / NULLIF(MAX(t.c), 0)), 0) || '%' AS s6_pct
       FROM stages s CROSS JOIN tot t) st,
      (SELECT
         COUNT(*) AS pr_total_cnt,
         TO_CHAR(NVL(SUM(amt), 0), 'FM999,999,999,990.00') AS pr_total_amt,
         COUNT(CASE WHEN NVL(status, 'X') = 'PENDING APPROVAL' THEN 1 END) AS pr_pend_cnt,
         TO_CHAR(NVL(SUM(CASE WHEN NVL(status, 'X') = 'PENDING APPROVAL' THEN amt END), 0), 'FM999,999,999,990.00') AS pr_pend_amt,
         COUNT(CASE WHEN NVL(status, 'X') = 'APPROVED' THEN 1 END) AS pr_appr_cnt,
         TO_CHAR(NVL(SUM(CASE WHEN NVL(status, 'X') = 'APPROVED' THEN amt END), 0), 'FM999,999,999,990.00') AS pr_appr_amt,
         COUNT(CASE WHEN NVL(status, 'X') = 'INCOMPLETE' THEN 1 END) AS pr_incomp_cnt,
         TO_CHAR(NVL(SUM(CASE WHEN NVL(status, 'X') = 'INCOMPLETE' THEN amt END), 0), 'FM999,999,999,990.00') AS pr_incomp_amt,
         COUNT(CASE WHEN NOT ((NVL(status, 'X') = 'PENDING APPROVAL') OR (NVL(status, 'X') = 'APPROVED') OR (NVL(status, 'X') = 'INCOMPLETE')) THEN 1 END) AS pr_other_cnt,
         TO_CHAR(NVL(SUM(CASE WHEN NOT ((NVL(status, 'X') = 'PENDING APPROVAL') OR (NVL(status, 'X') = 'APPROVED') OR (NVL(status, 'X') = 'INCOMPLETE')) THEN amt END), 0), 'FM999,999,999,990.00') AS pr_other_amt
  FROM prs) pr,
      (SELECT
         COUNT(*) AS po_total_cnt,
         TO_CHAR(NVL(SUM(amt), 0), 'FM999,999,999,990.00') AS po_total_amt,
         COUNT(CASE WHEN NVL(status, 'X') = 'OPEN' THEN 1 END) AS po_open_cnt,
         TO_CHAR(NVL(SUM(CASE WHEN NVL(status, 'X') = 'OPEN' THEN amt END), 0), 'FM999,999,999,990.00') AS po_open_amt,
         COUNT(CASE WHEN NVL(status, 'X') = 'INCOMPLETE' THEN 1 END) AS po_incomp_cnt,
         TO_CHAR(NVL(SUM(CASE WHEN NVL(status, 'X') = 'INCOMPLETE' THEN amt END), 0), 'FM999,999,999,990.00') AS po_incomp_amt,
         COUNT(CASE WHEN NVL(status, 'X') LIKE '%CLOSED%' THEN 1 END) AS po_closed_cnt,
         TO_CHAR(NVL(SUM(CASE WHEN NVL(status, 'X') LIKE '%CLOSED%' THEN amt END), 0), 'FM999,999,999,990.00') AS po_closed_amt,
         COUNT(CASE WHEN NOT ((NVL(status, 'X') = 'OPEN') OR (NVL(status, 'X') = 'INCOMPLETE') OR (NVL(status, 'X') LIKE '%CLOSED%')) THEN 1 END) AS po_other_cnt,
         TO_CHAR(NVL(SUM(CASE WHEN NOT ((NVL(status, 'X') = 'OPEN') OR (NVL(status, 'X') = 'INCOMPLETE') OR (NVL(status, 'X') LIKE '%CLOSED%')) THEN amt END), 0), 'FM999,999,999,990.00') AS po_other_amt
  FROM po_amt) po,
      (SELECT COUNT(CASE WHEN route = 'RFQ'    THEN 1 END) AS rt_rfq,
              COUNT(CASE WHEN route = 'DIRECT' THEN 1 END) AS rt_direct,
              COUNT(CASE WHEN route = 'NONE'   THEN 1 END) AS rt_none
       FROM routes) ro
