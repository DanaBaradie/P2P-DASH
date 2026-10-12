-- G_13  PR LIFECYCLE – one row for the chosen PR (child of G_4, link REQUISITION_HEADER_ID).
-- Drives the lifecycle timeline, progress strip and money trail.
-- State per stage: exactly ONE of Sn_DONE / Sn_WIP / Sn_TODO is filled, so the layout
-- shows it in the right colour (green / amber / grey) without conditional formatting.
WITH pr AS (
  SELECT prh.requisition_header_id,
         prh.requisition_number,
         UPPER(REPLACE(prh.document_status, '_', ' ')) AS status,
         TRUNC(prh.creation_date) AS d,
         (SELECT COUNT(*) FROM por_requisition_lines_all l
          WHERE  l.requisition_header_id = prh.requisition_header_id) AS line_cnt,
         (SELECT NVL(SUM(l.quantity * l.unit_price), 0) FROM por_requisition_lines_all l
          WHERE  l.requisition_header_id = prh.requisition_header_id) AS amt
  FROM   por_requisition_headers_all prh
  WHERE  prh.requisition_number = :P_PR_NUMBER
),
auc_ids AS (
  SELECT DISTINCT ai.auction_header_id
  FROM   pon_auction_item_prices_all ai
  WHERE  ai.requisition_number = :P_PR_NUMBER
),
rfq AS (
  SELECT COUNT(*) AS cnt,
         LISTAGG(pah.document_number, ', ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY pah.document_number) AS refs,
         LISTAGG(DISTINCT REPLACE(INITCAP(REPLACE(pah.auction_status, '_', ' ')), 'Auction', 'RFQ'), ', ' ON OVERFLOW TRUNCATE)
                 WITHIN GROUP (ORDER BY REPLACE(INITCAP(REPLACE(pah.auction_status, '_', ' ')), 'Auction', 'RFQ')) AS statuses,
         TRUNC(MIN(pah.creation_date)) AS d,
         MAX(CASE WHEN pah.auction_status LIKE '%CLOSED%' OR pah.auction_status LIKE '%AWARD%'
                    OR pah.auction_status LIKE '%COMPLETE%' THEN 1 ELSE 0 END) AS any_closed
  FROM   pon_auction_headers_all pah
  WHERE  pah.auction_header_id IN (SELECT auction_header_id FROM auc_ids)
),
bids AS (
  SELECT COUNT(*) AS cnt,
         COUNT(CASE WHEN b.award_status = 'AWARDED' OR NVL(b.total_award_amount, 0) > 0 THEN 1 END) AS awarded_cnt,
         MAX(CASE WHEN b.award_status = 'AWARDED' OR NVL(b.total_award_amount, 0) > 0 THEN hp.party_name END) AS awarded_sup
  FROM   pon_bid_headers b
  LEFT JOIN hz_parties hp ON hp.party_id = b.trading_partner_id
  WHERE  b.bid_status = 'ACTIVE'
  AND    b.auction_header_id IN (SELECT auction_header_id FROM auc_ids)
),
po_ids AS (
  SELECT DISTINCT pda.po_header_id
  FROM   por_requisition_headers_all prh
  JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = prh.requisition_header_id
  JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
  JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
  WHERE  prh.requisition_number = :P_PR_NUMBER
),
po AS (
  SELECT COUNT(*) AS cnt,
         LISTAGG(poh.segment1, ', ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY poh.segment1) AS refs,
         LISTAGG(DISTINCT INITCAP(REPLACE(poh.document_status, '_', ' ')), ', ' ON OVERFLOW TRUNCATE)
                 WITHIN GROUP (ORDER BY INITCAP(REPLACE(poh.document_status, '_', ' '))) AS statuses,
         LISTAGG(DISTINCT sup.vendor_name, ', ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY sup.vendor_name) AS suppliers,
         TRUNC(MIN(poh.creation_date)) AS d,
         COUNT(CASE WHEN UPPER(REPLACE(poh.document_status, '_', ' '))
                         IN ('INCOMPLETE', 'PENDING APPROVAL', 'REJECTED', 'WITHDRAWN') THEN 1 END) AS pending_cnt
  FROM   po_headers_all poh
  LEFT JOIN poz_suppliers_v sup ON sup.vendor_id = poh.vendor_id
  WHERE  poh.po_header_id IN (SELECT po_header_id FROM po_ids)
),
po_val AS (
  SELECT NVL(SUM(pda.quantity_ordered * pll.price_override
                 + NVL(pda.nonrecoverable_tax, 0) + NVL(pda.recoverable_tax, 0)), 0) AS amt
  FROM   po_line_locations_all pll
  JOIN   po_distributions_all  pda ON pda.line_location_id = pll.line_location_id
  WHERE  pll.po_header_id IN (SELECT po_header_id FROM po_ids)
),
qty AS (
  SELECT NVL(SUM(pll.quantity - NVL(pll.quantity_cancelled, 0)), 0) AS ordered,
         NVL(SUM(NVL(pll.quantity_received, 0)), 0)                AS received
  FROM   po_line_locations_all pll
  WHERE  pll.po_header_id IN (SELECT po_header_id FROM po_ids)
),
rcv AS (
  SELECT COUNT(DISTINCT rt.shipment_header_id) AS cnt,
         LISTAGG(DISTINCT rsh.receipt_num, ', ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY rsh.receipt_num) AS refs,
         NVL(SUM(rt.quantity * pll.price_override), 0) AS amt,
         TRUNC(MIN(rt.transaction_date)) AS d_first,
         TRUNC(MAX(rt.transaction_date)) AS d_last
  FROM   rcv_transactions rt
  JOIN   rcv_shipment_headers  rsh ON rsh.shipment_header_id = rt.shipment_header_id
  JOIN   po_line_locations_all pll ON pll.line_location_id   = rt.po_line_location_id
  WHERE  rt.transaction_type = 'RECEIVE'
  AND    rt.po_header_id IN (SELECT po_header_id FROM po_ids)
),
inv_ids AS (
  SELECT DISTINCT ail.invoice_id
  FROM   ap_invoice_lines_all ail
  WHERE  ail.po_header_id IN (SELECT po_header_id FROM po_ids)
),
inv AS (
  SELECT COUNT(*) AS cnt,
         LISTAGG(x.invoice_num, ', ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY x.invoice_num) AS refs,
         LISTAGG(DISTINCT x.st, ', ' ON OVERFLOW TRUNCATE) WITHIN GROUP (ORDER BY x.st) AS statuses,
         NVL(SUM(x.invoice_amount), 0) AS amt,
         TRUNC(MIN(x.invoice_date)) AS d_first,
         TRUNC(MAX(x.invoice_date)) AS d_last,
         COUNT(CASE WHEN NVL(x.payment_status_flag, 'N') <> 'Y' THEN 1 END) AS unpaid_cnt
  FROM  (SELECT aia.invoice_num, aia.invoice_amount, aia.invoice_date, aia.payment_status_flag,
                INITCAP(REPLACE(AP_INVOICES_PKG.GET_APPROVAL_STATUS(aia.invoice_id, aia.invoice_amount,
                        aia.payment_status_flag, aia.invoice_type_lookup_code), '_', ' ')) AS st
         FROM   ap_invoices_all aia
         WHERE  aia.invoice_id IN (SELECT invoice_id FROM inv_ids)) x
),
pay AS (
  SELECT COUNT(DISTINCT ac.check_id) AS cnt,
         LISTAGG(DISTINCT TO_CHAR(ac.check_number), ', ' ON OVERFLOW TRUNCATE)
                 WITHIN GROUP (ORDER BY TO_CHAR(ac.check_number)) AS refs,
         NVL(SUM(aip.amount), 0) AS amt,
         TRUNC(MIN(ac.check_date)) AS d_first,
         TRUNC(MAX(ac.check_date)) AS d_last
  FROM   ap_invoice_payments_all aip
  JOIN   ap_checks_all ac ON ac.check_id = aip.check_id
  WHERE  aip.invoice_id IN (SELECT invoice_id FROM inv_ids)
  AND    NVL(aip.reversal_flag, 'N') = 'N'
),
-- D = completed, W = in progress, N = not started, S = skipped (no RFQ, PR went straight to PO)
st AS (
  SELECT pr.requisition_header_id, pr.requisition_number, pr.status AS pr_status, pr.d AS pr_d,
         pr.line_cnt, pr.amt AS pr_amt,
         rfq.cnt AS rfq_cnt, rfq.refs AS rfq_refs, rfq.statuses AS rfq_statuses, rfq.d AS rfq_d,
         bids.cnt AS bid_cnt, bids.awarded_sup,
         po.cnt AS po_cnt, po.refs AS po_refs, po.statuses AS po_statuses, po.suppliers, po.d AS po_d,
         po_val.amt AS po_amt, qty.ordered, qty.received,
         rcv.cnt AS rcv_cnt, rcv.refs AS rcv_refs, rcv.amt AS rcv_amt, rcv.d_first AS rcv_d1, rcv.d_last AS rcv_d2,
         inv.cnt AS inv_cnt, inv.refs AS inv_refs, inv.statuses AS inv_statuses, inv.amt AS inv_amt,
         inv.d_first AS inv_d1, inv.d_last AS inv_d2,
         pay.cnt AS pay_cnt, pay.refs AS pay_refs, pay.amt AS pay_amt, pay.d_first AS pay_d1, pay.d_last AS pay_d2,
         CASE WHEN pr.status = 'APPROVED' THEN 'D' ELSE 'W' END AS s1,
         CASE WHEN rfq.cnt > 0 THEN CASE WHEN bids.awarded_cnt > 0 OR rfq.any_closed = 1 OR po.cnt > 0
                                         THEN 'D' ELSE 'W' END
              WHEN po.cnt > 0 THEN 'S'
              ELSE 'N' END AS s2,
         CASE WHEN po.cnt = 0 THEN 'N' WHEN po.pending_cnt > 0 THEN 'W' ELSE 'D' END AS s3,
         CASE WHEN po.cnt = 0 OR qty.received = 0 THEN 'N'
              WHEN qty.received < qty.ordered THEN 'W' ELSE 'D' END AS s4,
         CASE WHEN inv.cnt = 0 THEN 'N'
              WHEN inv.amt >= po_val.amt - 0.01 THEN 'D' ELSE 'W' END AS s5,
         CASE WHEN pay.cnt = 0 THEN 'N'
              WHEN inv.unpaid_cnt = 0 AND inv.amt >= po_val.amt - 0.01 THEN 'D' ELSE 'W' END AS s6
  FROM   pr CROSS JOIN rfq CROSS JOIN bids CROSS JOIN po CROSS JOIN po_val CROSS JOIN qty
         CROSS JOIN rcv CROSS JOIN inv CROSS JOIN pay
),
cur AS (
  SELECT st.*,
         CASE WHEN s1 NOT IN ('D', 'S') THEN 1
              WHEN s2 NOT IN ('D', 'S') THEN 2
              WHEN s3 NOT IN ('D', 'S') THEN 3
              WHEN s4 NOT IN ('D', 'S') THEN 4
              WHEN s5 NOT IN ('D', 'S') THEN 5
              WHEN s6 NOT IN ('D', 'S') THEN 6
              ELSE 7 END AS cur_stage,
         (CASE WHEN s1 IN ('D', 'S') THEN 1 ELSE 0 END + CASE WHEN s2 IN ('D', 'S') THEN 1 ELSE 0 END
        + CASE WHEN s3 IN ('D', 'S') THEN 1 ELSE 0 END + CASE WHEN s4 IN ('D', 'S') THEN 1 ELSE 0 END
        + CASE WHEN s5 IN ('D', 'S') THEN 1 ELSE 0 END + CASE WHEN s6 IN ('D', 'S') THEN 1 ELSE 0 END) AS done_cnt
  FROM   st
)
SELECT requisition_header_id,
       -- state labels: only one of DONE / WIP / TODO is non-null per stage
       DECODE(s1, 'D', 'COMPLETED · مكتمل') AS s1_done, DECODE(s1, 'W', 'IN PROGRESS · قيد التنفيذ') AS s1_wip,
       DECODE(s1, 'N', 'NOT STARTED · لم تبدأ') AS s1_todo,
       DECODE(s2, 'D', 'COMPLETED · مكتمل') AS s2_done, DECODE(s2, 'W', 'IN PROGRESS · قيد التنفيذ') AS s2_wip,
       DECODE(s2, 'N', 'NOT STARTED · لم تبدأ', 'S', 'SKIPPED · لا يوجد طلب عروض') AS s2_todo,
       DECODE(s3, 'D', 'COMPLETED · مكتمل') AS s3_done, DECODE(s3, 'W', 'IN PROGRESS · قيد التنفيذ') AS s3_wip,
       DECODE(s3, 'N', 'NOT STARTED · لم تبدأ') AS s3_todo,
       DECODE(s4, 'D', 'COMPLETED · مكتمل') AS s4_done, DECODE(s4, 'W', 'IN PROGRESS · قيد التنفيذ') AS s4_wip,
       DECODE(s4, 'N', 'NOT STARTED · لم تبدأ') AS s4_todo,
       DECODE(s5, 'D', 'COMPLETED · مكتمل') AS s5_done, DECODE(s5, 'W', 'IN PROGRESS · قيد التنفيذ') AS s5_wip,
       DECODE(s5, 'N', 'NOT STARTED · لم تبدأ') AS s5_todo,
       DECODE(s6, 'D', 'COMPLETED · مكتمل') AS s6_done, DECODE(s6, 'W', 'IN PROGRESS · قيد التنفيذ') AS s6_wip,
       DECODE(s6, 'N', 'NOT STARTED · لم تبدأ') AS s6_todo,
       DECODE(cur_stage, 1, 'CURRENT STAGE · المرحلة الحالية') AS s1_here, DECODE(cur_stage, 2, 'CURRENT STAGE · المرحلة الحالية') AS s2_here,
       DECODE(cur_stage, 3, 'CURRENT STAGE · المرحلة الحالية') AS s3_here, DECODE(cur_stage, 4, 'CURRENT STAGE · المرحلة الحالية') AS s4_here,
       DECODE(cur_stage, 5, 'CURRENT STAGE · المرحلة الحالية') AS s5_here, DECODE(cur_stage, 6, 'CURRENT STAGE · المرحلة الحالية') AS s6_here,
       -- stage 1 – PR
       INITCAP(pr_status)                                       AS s1_status,
       TO_CHAR(pr_d, 'DD/MM/YYYY')                              AS s1_date,
       requisition_number                                       AS s1_ref,
       line_cnt || ' line(s) · SAR ' || TO_CHAR(pr_amt, 'FM999,999,999,990.00') || ' excl. VAT' AS s1_info,
       -- stage 2 – RFQ
       CASE WHEN rfq_cnt > 0 THEN rfq_statuses ELSE 'No RFQ found' END            AS s2_status,
       TO_CHAR(rfq_d, 'DD/MM/YYYY')                                               AS s2_date,
       NVL(rfq_refs, '-')                                                         AS s2_ref,
       CASE WHEN rfq_cnt > 0 THEN bid_cnt || ' bid(s) · '
                 || NVL('Awarded: ' || awarded_sup, 'not awarded yet')
            WHEN s2 = 'S' THEN 'PR converted directly to PO'
            ELSE 'Waiting for RFQ or PO' END                                      AS s2_info,
       -- stage 3 – PO
       NVL(po_statuses, 'Not created')                                            AS s3_status,
       TO_CHAR(po_d, 'DD/MM/YYYY')                                                AS s3_date,
       NVL(po_refs, '-')                                                          AS s3_ref,
       CASE WHEN po_cnt > 0 THEN suppliers || ' · SAR ' || TO_CHAR(po_amt, 'FM999,999,999,990.00') || ' incl. VAT'
            ELSE 'No purchase order yet' END                                      AS s3_info,
       -- stage 4 – Receipt
       DECODE(s4, 'D', 'Fully received', 'W', 'Partially received', 'Not received') AS s4_status,
       TO_CHAR(rcv_d2, 'DD/MM/YYYY')                                              AS s4_date,
       NVL(rcv_refs, '-')                                                         AS s4_ref,
       CASE WHEN po_cnt > 0 THEN 'Received ' || received || ' of ' || ordered || ' unit(s)'
            ELSE 'Nothing to receive yet' END                                     AS s4_info,
       -- stage 5 – Invoice
       NVL(inv_statuses, 'Not invoiced')                                          AS s5_status,
       TO_CHAR(inv_d2, 'DD/MM/YYYY')                                              AS s5_date,
       NVL(inv_refs, '-')                                                         AS s5_ref,
       'SAR ' || TO_CHAR(inv_amt, 'FM999,999,999,990.00') || ' of '
              || TO_CHAR(po_amt, 'FM999,999,999,990.00') || ' invoiced'           AS s5_info,
       -- stage 6 – Payment
       DECODE(s6, 'D', 'Fully paid', 'W', 'Partially paid', 'Not paid')           AS s6_status,
       TO_CHAR(pay_d2, 'DD/MM/YYYY')                                              AS s6_date,
       NVL(pay_refs, '-')                                                         AS s6_ref,
       'SAR ' || TO_CHAR(pay_amt, 'FM999,999,999,990.00') || ' paid'              AS s6_info,
       -- days between stages (shown on the arrows)
       CASE WHEN rfq_d IS NOT NULL THEN GREATEST(rfq_d - pr_d, 0) || ' days' END                   AS d12,
       CASE WHEN po_d  IS NOT NULL THEN GREATEST(po_d - NVL(rfq_d, pr_d), 0) || ' days' END        AS d23,
       CASE WHEN rcv_d1 IS NOT NULL AND po_d IS NOT NULL THEN GREATEST(rcv_d1 - po_d, 0) || ' days' END AS d34,
       CASE WHEN inv_d1 IS NOT NULL THEN GREATEST(inv_d1 - NVL(rcv_d1, po_d), 0) || ' days' END   AS d45,
       CASE WHEN pay_d1 IS NOT NULL THEN GREATEST(pay_d1 - inv_d1, 0) || ' days' END              AS d56,
       -- progress strip
       DECODE(cur_stage, 1, 'Purchase Requisition', 2, 'RFQ / Negotiation', 3, 'Purchase Order',
                         4, 'Receipt', 5, 'Invoice', 6, 'Payment', 'Cycle complete')               AS current_stage,
       DECODE(cur_stage, 1, 'طلب الشراء', 2, 'طلب عروض الأسعار', 3, 'أمر الشراء',
                         4, 'الاستلام', 5, 'الفاتورة', 6, 'الدفع', 'اكتملت الدورة')                AS current_stage_ar,
       DECODE(cur_stage,
              1, 'Complete and approve the requisition',
              2, CASE WHEN rfq_cnt > 0 THEN 'Evaluate bids and award a supplier' ELSE 'Start an RFQ or create the PO' END,
              3, 'Create and approve the purchase order',
              4, 'Receive the goods / services',
              5, 'Enter and validate the supplier invoice',
              6, 'Pay the supplier',
              'Nothing pending')                                                   AS next_step,
       DECODE(cur_stage,
              1, 'إكمال طلب الشراء واعتماده',
              2, CASE WHEN rfq_cnt > 0 THEN 'تقييم العروض والترسية على مورد' ELSE 'بدء طلب عروض أو إنشاء أمر الشراء' END,
              3, 'إنشاء أمر الشراء واعتماده',
              4, 'استلام البضائع / الخدمات',
              5, 'إدخال فاتورة المورد والتحقق منها',
              6, 'سداد مستحقات المورد',
              'لا توجد إجراءات معلقة')                                              AS next_step_ar,
       ROUND(done_cnt / 6 * 100) || '%'                                            AS progress_pct,
       done_cnt || ' of 6 stages done'                                             AS stages_done,
       (CASE WHEN cur_stage = 7 THEN pay_d2 ELSE TRUNC(SYSDATE) END - pr_d) || ' days' AS cycle_days,
       -- money trail
       TO_CHAR(pr_amt, 'FM999,999,999,990.00')                                     AS mt_requested,
       TO_CHAR(po_amt, 'FM999,999,999,990.00')                                     AS mt_ordered,
       TO_CHAR(rcv_amt, 'FM999,999,999,990.00')                                    AS mt_received,
       TO_CHAR(inv_amt, 'FM999,999,999,990.00')                                    AS mt_invoiced,
       TO_CHAR(pay_amt, 'FM999,999,999,990.00')                                    AS mt_paid,
       TO_CHAR(GREATEST(inv_amt - pay_amt, 0), 'FM999,999,999,990.00')             AS mt_due
FROM   cur
