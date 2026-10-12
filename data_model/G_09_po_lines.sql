-- G_9  PO lines with receiving progress (linked to G_8 on PO_HEADER_ID).
SELECT pol.po_header_id,
       pol.line_num                         AS po_line_no,
       pol.item_description                 AS po_line_desc,
       pll.quantity                         AS po_qty,
       pll.price_override                   AS unit_price,
       pll.quantity * pll.price_override    AS line_amount_excl_tax,
       pll.quantity * pll.price_override
         + NVL((SELECT SUM(NVL(d.nonrecoverable_tax, 0) + NVL(d.recoverable_tax, 0))
                FROM   po_distributions_all d
                WHERE  d.line_location_id = pll.line_location_id), 0) AS line_amount_incl_tax,
       NVL(pll.quantity_received, 0)        AS received_qty,
       CASE WHEN NVL(pll.quantity_received, 0) = 0 THEN 'Not received'
            WHEN pll.quantity_received < pll.quantity - NVL(pll.quantity_cancelled, 0) THEN 'Partially received'
            ELSE 'Fully received' END       AS receive_status,
       pt.name                              AS payment_terms,
       poh.attribute1                       AS payment_type,     -- PO header DFF: Payment Type
       poh.attribute2                       AS payment_status    -- PO header DFF: Payment Status
FROM   po_lines_all pol
JOIN   po_line_locations_all pll ON pll.po_line_id = pol.po_line_id
JOIN   po_headers_all        poh ON poh.po_header_id = pol.po_header_id
LEFT JOIN ap_terms_tl        pt  ON pt.term_id = poh.terms_id AND pt.language = USERENV('LANG')
WHERE  pol.po_header_id IN (SELECT pda.po_header_id
                            FROM   por_requisition_headers_all prh
                            JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = prh.requisition_header_id
                            JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
                            JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
                            WHERE  prh.requisition_number = :P_PR_NUMBER)
ORDER  BY pol.po_header_id, pol.line_num
