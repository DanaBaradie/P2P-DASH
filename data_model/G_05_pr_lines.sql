-- G_5  PR lines (linked to G_4 on REQUISITION_HEADER_ID).
-- Filtered by the parameter too, so the query never scans every requisition line.
SELECT prl.requisition_header_id,
       prl.line_number                 AS pr_line_no,
       prl.item_description            AS pr_line_desc,
       prl.quantity                    AS pr_line_qty,
       prl.unit_price                  AS pr_line_price,
       prl.quantity * prl.unit_price   AS pr_line_amount
FROM   por_requisition_lines_all prl
WHERE  prl.requisition_header_id IN (SELECT prh.requisition_header_id
                                     FROM   por_requisition_headers_all prh
                                     WHERE  prh.requisition_number = :P_PR_NUMBER)
ORDER  BY prl.line_number
