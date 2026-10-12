-- G_11  Invoices and their payments per PO (linked to G_8 on PO_HEADER_ID).
-- One row per payment. The invoice amount is shown on the first row only, so the
-- table total is not double-counted when an invoice is paid in several payments.
-- Reversed (voided) payments are excluded.
SELECT ail.po_header_id,
       aia.invoice_num                                  AS invoice_number,
       TO_CHAR(aia.invoice_date, 'DD/MM/YYYY')          AS invoice_date,
       CASE WHEN ROW_NUMBER() OVER (PARTITION BY ail.po_header_id, aia.invoice_id
                                    ORDER BY ac.check_date, aip.invoice_payment_id) = 1
            THEN aia.invoice_amount END                 AS invoice_amount,
       INITCAP(REPLACE(AP_INVOICES_PKG.GET_APPROVAL_STATUS(aia.invoice_id, aia.invoice_amount,
                       aia.payment_status_flag, aia.invoice_type_lookup_code), '_', ' ')) AS invoice_status,
       TO_CHAR(ac.check_number)                         AS payment_number,
       TO_CHAR(ac.check_date, 'DD/MM/YYYY')             AS payment_date,
       aip.amount                                       AS payment_amount,
       CASE WHEN aip.invoice_payment_id IS NULL THEN 'Not paid'
            WHEN aia.payment_status_flag = 'Y'  THEN 'Paid'
            WHEN aia.payment_status_flag = 'P'  THEN 'Partially paid'
            ELSE 'Unpaid' END                           AS payment_status
FROM   ap_invoices_all aia
JOIN   (SELECT DISTINCT invoice_id, po_header_id
        FROM   ap_invoice_lines_all
        WHERE  po_header_id IN (SELECT pda.po_header_id
                                FROM   por_requisition_headers_all prh
                                JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = prh.requisition_header_id
                                JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
                                JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
                                WHERE  prh.requisition_number = :P_PR_NUMBER)) ail
       ON ail.invoice_id = aia.invoice_id
LEFT JOIN ap_invoice_payments_all aip
       ON  aip.invoice_id = aia.invoice_id
       AND NVL(aip.reversal_flag, 'N') = 'N'
LEFT JOIN ap_checks_all ac ON ac.check_id = aip.check_id
ORDER  BY ail.po_header_id, aia.invoice_num, ac.check_date
