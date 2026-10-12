-- G_16  NEEDS ATTENTION – documents stuck in the cycle (top-level dataset, no link).
-- Follows :P_PR_NUMBER (all PRs, or only the chosen one). Shows the 15 longest-waiting items.
-- Always returns at least one row: when nothing is stuck it says so.
--
-- Rules (change the day thresholds here if the business wants different ones):
--   1 PR pending approval for more than 3 days (since submission)
--   2 PR approved more than 7 days ago with no RFQ and no PO
--   3 RFQ bidding closed more than 3 days ago, nothing awarded, no PO
--   4 Open PO with quantity still to receive after its promised / need-by date
--   5 Goods received more than 7 days ago but no invoice on the PO
--   6 Invoice with an unpaid balance past its due date
WITH prs AS (
  SELECT prh.requisition_header_id,
         prh.requisition_number,
         UPPER(REPLACE(prh.document_status, '_', ' ')) AS status,
         CAST(prh.creation_date AS DATE)               AS created_on,
         prh.preparer_id
  FROM   por_requisition_headers_all prh
  WHERE  (:P_PR_NUMBER IS NULL OR prh.requisition_number = :P_PR_NUMBER)
),
person AS (
  SELECT person_id, display_name
  FROM   per_person_names_f
  WHERE  name_type = 'GLOBAL'
  AND    TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date
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
req_act AS (
  SELECT pah.object_id,
         MAX(CASE WHEN pah.action_code = 'APPROVE'
                  THEN NVL(pah.action_date, CAST(pah.creation_date AS DATE)) END) AS approved_on,
         MAX(CASE WHEN pah.action_code = 'SUBMIT'
                  THEN NVL(pah.action_date, CAST(pah.creation_date AS DATE)) END) AS submitted_on
  FROM   po_action_history pah
  WHERE  pah.object_type_code IN ('REQ', 'REQUISITION')
  AND    pah.object_id IN (SELECT requisition_header_id FROM prs)
  GROUP  BY pah.object_id
),
issues AS (
  -- 1 PR pending approval
  SELECT 'PR pending approval · طلب بانتظار الاعتماد' AS issue,
         prs.requisition_number AS pr_number, prs.requisition_number AS document,
         NVL(ra.submitted_on, prs.created_on) AS since,
         p.display_name AS owner,
         'Follow up with the approver · متابعة المعتمد' AS action
  FROM   prs
  LEFT JOIN req_act ra ON ra.object_id = prs.requisition_header_id
  LEFT JOIN person  p  ON p.person_id  = prs.preparer_id
  WHERE  prs.status = 'PENDING APPROVAL'
  AND    SYSDATE - NVL(ra.submitted_on, prs.created_on) > 3
  UNION ALL
  -- 2 approved PR not progressed
  SELECT 'Approved PR – no RFQ or PO · طلب معتمد دون متابعة',
         prs.requisition_number, prs.requisition_number,
         NVL(ra.approved_on, prs.created_on),
         p.display_name,
         'Start an RFQ or create the PO · بدء طلب عروض أو إنشاء أمر شراء'
  FROM   prs
  LEFT JOIN req_act ra ON ra.object_id = prs.requisition_header_id
  LEFT JOIN person  p  ON p.person_id  = prs.preparer_id
  WHERE  prs.status = 'APPROVED'
  AND    NOT EXISTS (SELECT 1 FROM pr_rfq r WHERE r.requisition_header_id = prs.requisition_header_id)
  AND    NOT EXISTS (SELECT 1 FROM pr_po  pp WHERE pp.requisition_header_id = prs.requisition_header_id)
  AND    SYSDATE - NVL(ra.approved_on, prs.created_on) > 7
  UNION ALL
  -- 3 RFQ closed without award
  SELECT 'RFQ closed – not awarded · طلب عروض مغلق دون ترسية',
         prs.requisition_number, pah.document_number,
         pah.close_bidding_date,
         pah.created_by,
         'Evaluate bids and award · تقييم العروض والترسية'
  FROM   pr_rfq r
  JOIN   prs ON prs.requisition_header_id = r.requisition_header_id
  JOIN   pon_auction_headers_all pah ON pah.auction_header_id = r.auction_header_id
  WHERE  pah.close_bidding_date < SYSDATE - 3
  AND    pah.auction_status NOT IN ('CANCELLED', 'CANCELED', 'DRAFT')
  AND    NOT EXISTS (SELECT 1 FROM pon_bid_headers b
                     WHERE  b.auction_header_id = pah.auction_header_id
                     AND    (b.award_status = 'AWARDED' OR NVL(b.total_award_amount, 0) > 0))
  AND    NOT EXISTS (SELECT 1 FROM pr_po pp WHERE pp.requisition_header_id = r.requisition_header_id)
  UNION ALL
  -- 4 PO delivery overdue
  SELECT 'PO delivery overdue · تأخر التوريد',
         prs.requisition_number, poh.segment1,
         MIN(NVL(pll.promised_date, pll.need_by_date)),
         MAX(p.display_name),
         'Chase the supplier or receive · متابعة المورد أو الاستلام'
  FROM   pr_po pp
  JOIN   prs ON prs.requisition_header_id = pp.requisition_header_id
  JOIN   po_headers_all        poh ON poh.po_header_id = pp.po_header_id
  JOIN   po_line_locations_all pll ON pll.po_header_id = poh.po_header_id
  LEFT JOIN person p ON p.person_id = poh.agent_id
  WHERE  UPPER(poh.document_status) = 'OPEN'
  AND    NVL(pll.quantity_received, 0) < pll.quantity - NVL(pll.quantity_cancelled, 0)
  AND    NVL(pll.promised_date, pll.need_by_date) < TRUNC(SYSDATE)
  GROUP  BY prs.requisition_number, poh.segment1
  UNION ALL
  -- 5 received, not invoiced
  SELECT 'Received – not invoiced · مستلم دون فاتورة',
         prs.requisition_number, poh.segment1,
         MAX(rt.transaction_date),
         MAX(sup.vendor_name),
         'Request the supplier invoice · طلب الفاتورة من المورد'
  FROM   pr_po pp
  JOIN   prs ON prs.requisition_header_id = pp.requisition_header_id
  JOIN   po_headers_all   poh ON poh.po_header_id = pp.po_header_id
  JOIN   rcv_transactions rt  ON rt.po_header_id  = poh.po_header_id AND rt.transaction_type = 'RECEIVE'
  LEFT JOIN poz_suppliers_v sup ON sup.vendor_id = poh.vendor_id
  WHERE  NOT EXISTS (SELECT 1 FROM ap_invoice_lines_all ail WHERE ail.po_header_id = poh.po_header_id)
  GROUP  BY prs.requisition_number, poh.segment1
  HAVING MAX(rt.transaction_date) < SYSDATE - 7
  UNION ALL
  -- 6 invoice overdue for payment
  SELECT 'Invoice overdue for payment · فاتورة متأخرة السداد',
         prs.requisition_number, aia.invoice_num,
         MIN(ps.due_date),
         MAX(sup.vendor_name),
         'Pay the supplier · سداد المورد'
  FROM   pr_po pp
  JOIN   prs ON prs.requisition_header_id = pp.requisition_header_id
  JOIN   (SELECT DISTINCT invoice_id, po_header_id
          FROM   ap_invoice_lines_all
          WHERE  po_header_id IS NOT NULL) ail ON ail.po_header_id = pp.po_header_id
  JOIN   ap_invoices_all          aia ON aia.invoice_id = ail.invoice_id
  JOIN   ap_payment_schedules_all ps  ON ps.invoice_id  = aia.invoice_id
  LEFT JOIN poz_suppliers_v sup ON sup.vendor_id = aia.vendor_id
  WHERE  NVL(ps.amount_remaining, 0) > 0
  AND    ps.due_date < TRUNC(SYSDATE)
  AND    aia.cancelled_date IS NULL
  GROUP  BY prs.requisition_number, aia.invoice_num
),
top_issues AS (
  SELECT issue, pr_number, document, since, owner, action
  FROM   issues
  ORDER  BY since
  FETCH  FIRST 15 ROWS ONLY
)
SELECT issue, pr_number, document, since_date, waiting, owner, action
FROM (
  SELECT 1 AS sort_key_grp, SYSDATE - since AS sort_key,
         issue, pr_number, document,
         TO_CHAR(since, 'DD/MM/YYYY')            AS since_date,
         TRUNC(SYSDATE - since) || ' days'       AS waiting,
         NVL(owner, '-')                         AS owner,
         action
  FROM   top_issues
  UNION ALL
  SELECT 2, NULL,
         'Nothing is stuck – all documents are moving · لا توجد بنود متأخرة',
         '-', '-', '-', '-', '-', '-'
  FROM   dual
  WHERE  NOT EXISTS (SELECT 1 FROM issues)
)
ORDER BY sort_key_grp, sort_key DESC
