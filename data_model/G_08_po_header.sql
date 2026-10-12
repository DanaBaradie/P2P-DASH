-- G_8  POs created from the PR (linked to G_4 on REQUISITION_HEADER_ID).
-- Amounts are now the FULL PO value (all lines), not only the distributions backed by this PR.
WITH pp AS (
  SELECT DISTINCT prl.requisition_header_id, pda.po_header_id
  FROM   por_requisition_headers_all prh
  JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = prh.requisition_header_id
  JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
  JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
  WHERE  prh.requisition_number = :P_PR_NUMBER
),
amt AS (
  SELECT pll.po_header_id,
         SUM(pda.quantity_ordered * pll.price_override)                       AS excl,
         SUM(NVL(pda.nonrecoverable_tax, 0) + NVL(pda.recoverable_tax, 0))  AS tax
  FROM   po_line_locations_all pll
  JOIN   po_distributions_all  pda ON pda.line_location_id = pll.line_location_id
  WHERE  pll.po_header_id IN (SELECT po_header_id FROM pp)
  GROUP  BY pll.po_header_id
)
SELECT pp.requisition_header_id,
       poh.po_header_id,
       poh.segment1                                         AS po_number,
       INITCAP(REPLACE(poh.document_status, '_', ' '))      AS po_status,
       sup.segment1                                         AS supplier_number,
       sup.vendor_name                                      AS supplier_name,
       TO_CHAR(NVL(a.excl, 0), 'FM999,999,999,990.00')                  AS po_amount_excl_tax,
       TO_CHAR(NVL(a.tax, 0), 'FM999,999,999,990.00')                   AS po_tax_amount,
       TO_CHAR(NVL(a.excl, 0) + NVL(a.tax, 0), 'FM999,999,999,990.00')  AS po_amount_incl_tax,
       CASE WHEN NOT EXISTS (SELECT 1 FROM rcv_transactions rt
                             WHERE  rt.po_header_id = poh.po_header_id AND rt.transaction_type = 'RECEIVE')
            THEN 'Not received yet · لم يتم الاستلام بعد' END              AS rcv_msg,
       CASE WHEN NOT EXISTS (SELECT 1 FROM ap_invoice_lines_all ail WHERE ail.po_header_id = poh.po_header_id)
            THEN 'Not invoiced yet · لم تصدر فاتورة بعد' END               AS inv_msg
FROM   pp
JOIN   po_headers_all poh ON poh.po_header_id = pp.po_header_id
LEFT JOIN amt a           ON a.po_header_id   = poh.po_header_id
LEFT JOIN poz_suppliers_v sup ON sup.vendor_id = poh.vendor_id
ORDER  BY poh.segment1
