SELECT v.co_sequence, v.co_num, v.revision_num, v.change_order_status,
       v.created_by, v.creation_date, v.submitted_date, v.approved_date, v.processed_date,
       SUBSTR(v.change_order_desc, 1, 200) AS change_order_desc,
       h.document_status AS po_status, h.creation_date AS po_created, h.approved_date AS po_first_approved
FROM   po_headers_all h
LEFT JOIN po_versions v ON v.po_header_id = h.po_header_id
WHERE  UPPER(REPLACE(h.segment1, ' ', '')) = 'PO-MUDAD-34'
ORDER  BY v.co_sequence
;

SELECT 'ARCHIVE' AS src, l.line_num, l.from_co_seq, l.to_co_seq,
       l.entity_co_disposition, l.entity_change_type_code,
       l.item_description, l.quantity, l.unit_price,
       l.last_updated_by, l.last_update_date
FROM   po_lines_archive_all l
JOIN   po_headers_all h ON h.po_header_id = l.po_header_id
WHERE  UPPER(REPLACE(h.segment1, ' ', '')) = 'PO-MUDAD-34'
UNION ALL
SELECT 'DRAFT', l.line_num, NULL, NULL, NULL, l.entity_change_type_code,
       l.item_description, l.quantity, l.unit_price,
       l.last_updated_by, l.last_update_date
FROM   po_lines_draft_all l
JOIN   po_headers_all h ON h.po_header_id = l.po_header_id
WHERE  UPPER(REPLACE(h.segment1, ' ', '')) = 'PO-MUDAD-34'
UNION ALL
SELECT 'CURRENT', l.line_num, NULL, NULL, NULL, NULL,
       l.item_description, l.quantity, l.unit_price,
       l.last_updated_by, l.last_update_date
FROM   po_lines_all l
JOIN   po_headers_all h ON h.po_header_id = l.po_header_id
WHERE  UPPER(REPLACE(h.segment1, ' ', '')) = 'PO-MUDAD-34'
ORDER  BY 2, 1, 3
;

SELECT 'ARCHIVE' AS src, s.shipment_num, s.from_co_seq, s.to_co_seq,
       s.entity_co_disposition, s.entity_change_type_code,
       s.quantity, s.last_updated_by, s.last_update_date
FROM   po_line_locations_archive_all s
WHERE  s.po_line_id IN (SELECT l.po_line_id FROM po_lines_all l
                        JOIN po_headers_all h ON h.po_header_id = l.po_header_id
                        WHERE UPPER(REPLACE(h.segment1, ' ', '')) = 'PO-MUDAD-34')
UNION ALL
SELECT 'CURRENT', s.shipment_num, NULL, NULL, NULL, NULL,
       s.quantity, s.last_updated_by, s.last_update_date
FROM   po_line_locations_all s
WHERE  s.po_line_id IN (SELECT l.po_line_id FROM po_lines_all l
                        JOIN po_headers_all h ON h.po_header_id = l.po_header_id
                        WHERE UPPER(REPLACE(h.segment1, ' ', '')) = 'PO-MUDAD-34')
ORDER  BY 2, 1, 3
