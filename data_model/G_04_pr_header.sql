-- G_4  PR header. Returns a row ONLY when a PR number is chosen, so with the
-- parameter blank the detail section disappears and the report stays one page.
-- ROUTE carries the "No RFQ found" message shown in the RFQ section.
SELECT prh.requisition_header_id,
       prh.requisition_number                         AS pr_number,
       ppn.display_name                               AS requester,
       INITCAP(REPLACE(prh.document_status, '_', ' ')) AS pr_status,
       TO_CHAR(prh.creation_date, 'DD/MM/YYYY')        AS pr_date,
       TO_CHAR((SELECT NVL(SUM(l.quantity * l.unit_price), 0)
                FROM   por_requisition_lines_all l
                WHERE  l.requisition_header_id = prh.requisition_header_id),
               'FM999,999,999,990.00')                 AS pr_amount,
       CASE
         WHEN EXISTS (SELECT 1 FROM pon_auction_item_prices_all ai
                      WHERE  ai.requisition_number = prh.requisition_number)
           THEN 'Via RFQ / Negotiation'
         WHEN EXISTS (SELECT 1
                      FROM   por_requisition_lines_all prl
                      JOIN   por_req_distributions_all prd ON prd.requisition_line_id = prl.requisition_line_id
                      JOIN   po_distributions_all      pda ON pda.req_distribution_id = prd.distribution_id
                      WHERE  prl.requisition_header_id = prh.requisition_header_id)
           THEN 'No RFQ found - PR converted directly to PO'
         ELSE 'No RFQ found - PR not yet progressed'
       END                                             AS route,
       CASE WHEN NOT EXISTS (SELECT 1
                             FROM   por_requisition_lines_all prl
                             JOIN   por_req_distributions_all prd ON prd.requisition_line_id = prl.requisition_line_id
                             JOIN   po_distributions_all      pda ON pda.req_distribution_id = prd.distribution_id
                             WHERE  prl.requisition_header_id = prh.requisition_header_id)
            THEN 'No purchase order yet · لا يوجد أمر شراء بعد' END AS po_msg
FROM   por_requisition_headers_all prh
LEFT JOIN per_person_names_f ppn
       ON  ppn.person_id = prh.preparer_id
       AND ppn.name_type = 'GLOBAL'
       AND TRUNC(SYSDATE) BETWEEN ppn.effective_start_date AND ppn.effective_end_date
WHERE  :P_PR_NUMBER IS NOT NULL
AND    prh.requisition_number = :P_PR_NUMBER
