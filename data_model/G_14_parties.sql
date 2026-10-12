-- G_14  WHO WAS INVOLVED – people and suppliers on the cycle of the chosen PR
-- (child of G_4, link REQUISITION_HEADER_ID). Uses standard WHO columns only.
WITH pr AS (
  SELECT prh.requisition_header_id, prh.requisition_number, prh.preparer_id, prh.creation_date
  FROM   por_requisition_headers_all prh
  WHERE  prh.requisition_number = :P_PR_NUMBER
),
auc_ids AS (
  SELECT DISTINCT ai.auction_header_id
  FROM   pon_auction_item_prices_all ai
  WHERE  ai.requisition_number = :P_PR_NUMBER
),
po_ids AS (
  SELECT DISTINCT pda.po_header_id
  FROM   pr
  JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = pr.requisition_header_id
  JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
  JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
),
inv_ids AS (
  SELECT DISTINCT ail.invoice_id
  FROM   ap_invoice_lines_all ail
  WHERE  ail.po_header_id IN (SELECT po_header_id FROM po_ids)
),
person AS (
  SELECT person_id, display_name
  FROM   per_person_names_f
  WHERE  name_type = 'GLOBAL'
  AND    TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date
),
rows_ AS (
  -- 1 Requisition
  SELECT 1 AS sort1, 1 AS sort2, '1 · PR' AS stage, 'Requester' AS prole,
         p.display_name AS pname, 'Created ' || pr.requisition_number AS detail, pr.creation_date AS act_date
  FROM   pr LEFT JOIN person p ON p.person_id = pr.preparer_id
  UNION ALL
  -- 2 RFQ: owner + every bidding supplier
  SELECT 2, 1, '2 · RFQ', 'RFQ created by', pah.created_by, pah.document_number, pah.creation_date
  FROM   pon_auction_headers_all pah
  WHERE  pah.auction_header_id IN (SELECT auction_header_id FROM auc_ids)
  UNION ALL
  SELECT 2, CASE WHEN b.award_status = 'AWARDED' OR NVL(b.total_award_amount, 0) > 0 THEN 2 ELSE 3 END,
         '2 · RFQ',
         CASE WHEN b.award_status = 'AWARDED' OR NVL(b.total_award_amount, 0) > 0
              THEN 'Awarded supplier' ELSE 'Bidding supplier' END,
         hp.party_name,
         'Bid ' || b.bid_number || ' · SAR ' || TO_CHAR(b.buyer_bid_total, 'FM999,999,999,990.00'),
         b.creation_date
  FROM   pon_bid_headers b
  LEFT JOIN hz_parties hp ON hp.party_id = b.trading_partner_id
  WHERE  b.bid_status = 'ACTIVE'
  AND    b.auction_header_id IN (SELECT auction_header_id FROM auc_ids)
  UNION ALL
  -- 3 PO: buyer + supplier
  SELECT 3, 1, '3 · PO', 'Buyer', p.display_name, poh.segment1, poh.creation_date
  FROM   po_headers_all poh
  LEFT JOIN person p ON p.person_id = poh.agent_id
  WHERE  poh.po_header_id IN (SELECT po_header_id FROM po_ids)
  UNION ALL
  SELECT 3, 2, '3 · PO', 'Supplier', sup.vendor_name, 'Supplier No. ' || sup.segment1 || ' · ' || poh.segment1,
         poh.creation_date
  FROM   po_headers_all poh
  LEFT JOIN poz_suppliers_v sup ON sup.vendor_id = poh.vendor_id
  WHERE  poh.po_header_id IN (SELECT po_header_id FROM po_ids)
  UNION ALL
  -- 4 Receipt
  SELECT 4, 1, '4 · Receipt', 'Received by', rt.created_by, rsh.receipt_num, MIN(rt.transaction_date)
  FROM   rcv_transactions rt
  JOIN   rcv_shipment_headers rsh ON rsh.shipment_header_id = rt.shipment_header_id
  WHERE  rt.transaction_type = 'RECEIVE'
  AND    rt.po_header_id IN (SELECT po_header_id FROM po_ids)
  GROUP  BY rt.created_by, rsh.receipt_num
  UNION ALL
  -- 5 Invoice
  SELECT 5, 1, '5 · Invoice', 'Invoice entered by', aia.created_by, aia.invoice_num, aia.creation_date
  FROM   ap_invoices_all aia
  WHERE  aia.invoice_id IN (SELECT invoice_id FROM inv_ids)
  UNION ALL
  -- 6 Payment
  SELECT DISTINCT 6, 1, '6 · Payment', 'Paid by', ac.created_by,
         'Payment ' || ac.check_number || ' · SAR ' || TO_CHAR(ac.amount, 'FM999,999,999,990.00'), ac.check_date
  FROM   ap_invoice_payments_all aip
  JOIN   ap_checks_all ac ON ac.check_id = aip.check_id
  WHERE  aip.invoice_id IN (SELECT invoice_id FROM inv_ids)
  AND    NVL(aip.reversal_flag, 'N') = 'N'
)
SELECT (SELECT requisition_header_id FROM pr) AS requisition_header_id,
       stage AS party_stage, prole AS party_role, NVL(pname, '-') AS party_name, detail AS party_detail,
       TO_CHAR(act_date, 'DD/MM/YYYY') AS party_date
FROM   rows_
ORDER  BY sort1, sort2, act_date
