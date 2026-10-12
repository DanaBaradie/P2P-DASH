-- G_10  Receipts per PO (linked to G_8 on PO_HEADER_ID).
SELECT rt.po_header_id,
       rsh.receipt_num                                AS receipt_number,
       TO_CHAR(MIN(rt.transaction_date), 'DD/MM/YYYY') AS receipt_date,
       SUM(rt.quantity)                               AS receipt_qty,
       CASE WHEN SUM(rt.quantity) >= (SELECT SUM(l.quantity - NVL(l.quantity_cancelled, 0))
                                      FROM   po_line_locations_all l
                                      WHERE  l.po_header_id = rt.po_header_id)
            THEN 'Fully received' ELSE 'Partially received' END AS receipt_status
FROM   rcv_transactions rt
JOIN   rcv_shipment_headers rsh ON rsh.shipment_header_id = rt.shipment_header_id
WHERE  rt.transaction_type = 'RECEIVE'
AND    rt.po_header_id IN (SELECT pda.po_header_id
                           FROM   por_requisition_headers_all prh
                           JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = prh.requisition_header_id
                           JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
                           JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
                           WHERE  prh.requisition_number = :P_PR_NUMBER)
GROUP  BY rt.po_header_id, rsh.receipt_num
ORDER  BY MIN(rt.transaction_date)
