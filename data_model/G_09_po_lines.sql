-- G_9  PO lines with receiving progress (linked to G_8 on PO_HEADER_ID).
-- ATTACHMENT_NAME / ATTACHMENT_URL = the PO's header attachment ("Notes and Attachments" on the PO page).
-- Fusion keeps attachment metadata in FND_ATTACHED_DOCUMENTS (ENTITY_NAME = 'PO_HEADERS',
-- PK1_VALUE = PO_HEADER_ID, PK2_VALUE = PO_VERSIONS.VERSION_ID) and the file itself in the content
-- server (UCM). The link calls the UCM GET_FILE service, which returns the original file under its
-- original name; the viewer needs the AttachmentsRead role. Only one PO version is used (the current
-- one, else the latest that has attachments) so change orders do not repeat files. With several files
-- the newest is linked and the label shows how many more exist, e.g. "Quote.pdf (+2)".
WITH pp AS (
  SELECT DISTINCT pda.po_header_id
  FROM   por_requisition_headers_all prh
  JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = prh.requisition_header_id
  JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
  JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
  WHERE  prh.requisition_number = :P_PR_NUMBER
),
att_all AS (
  SELECT fad.pk1_value                                     AS po_header_id,
         fad.document_id,
         fad.last_update_date,
         COALESCE(fdt.file_name, fdt.url, 'Attachment')    AS file_name,
         CASE WHEN fd.datatype_code = 'WEB_PAGE' THEN fdt.url
              ELSE 'https://' || (SELECT MAX(dd.external_virtual_host)
                                  FROM   fusion.ask_deployed_domains dd
                                  WHERE  dd.deployed_domain_name = 'FADomain')
                   || '/cs/idcplg?IdcService=GET_FILE'      -- CHR(38) = ampersand (BIP reads a literal one as a lexical)
                   || CHR(38) || 'dID='      || fdt.dm_version_number
                   || CHR(38) || 'dDocName=' || fdt.dm_document_id
                   || CHR(38) || 'allowInterrupt=1'
         END                                               AS file_url,
         DENSE_RANK() OVER (PARTITION BY fad.pk1_value
                            ORDER BY CASE WHEN fad.pk2_value = TO_CHAR(poh.current_version_id) THEN 0 ELSE 1 END,
                                     NVL(ver.co_sequence, -1) DESC) AS ver_rank
  FROM   fnd_attached_documents fad
  JOIN   fnd_documents          fd  ON fd.document_id  = fad.document_id
  JOIN   fnd_documents_tl       fdt ON fdt.document_id = fad.document_id AND fdt.language = USERENV('LANG')
  JOIN   po_headers_all         poh ON TO_CHAR(poh.po_header_id) = fad.pk1_value
  LEFT JOIN po_versions         ver ON TO_CHAR(ver.version_id) = fad.pk2_value AND ver.po_header_id = poh.po_header_id
  WHERE  fad.entity_name = 'PO_HEADERS'
  AND    fad.pk1_value IN (SELECT TO_CHAR(po_header_id) FROM pp)
  AND    (   (fd.datatype_code =  'WEB_PAGE' AND fdt.url IS NOT NULL)
          OR (fd.datatype_code <> 'WEB_PAGE' AND fdt.dm_document_id IS NOT NULL AND fdt.dm_version_number IS NOT NULL))
),
att AS (
  SELECT po_header_id,
         MAX(file_name) KEEP (DENSE_RANK FIRST ORDER BY last_update_date DESC, document_id DESC) AS file_name,
         MAX(file_url)  KEEP (DENSE_RANK FIRST ORDER BY last_update_date DESC, document_id DESC) AS file_url,
         COUNT(DISTINCT document_id)                                                            AS file_cnt
  FROM   att_all
  WHERE  ver_rank = 1
  GROUP  BY po_header_id
)
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
       poh.attribute2                       AS payment_status,   -- PO header DFF: Payment Status
       NVL(att.file_name || CASE WHEN att.file_cnt > 1 THEN ' (+' || (att.file_cnt - 1) || ')' END, '-')
                                            AS attachment_name,
       att.file_url                         AS attachment_url    -- NULL when the PO has no attachment
FROM   po_lines_all pol
JOIN   po_line_locations_all pll ON pll.po_line_id = pol.po_line_id
JOIN   po_headers_all        poh ON poh.po_header_id = pol.po_header_id
LEFT JOIN ap_terms_tl        pt  ON pt.term_id = poh.terms_id AND pt.language = USERENV('LANG')
LEFT JOIN att                    ON att.po_header_id = TO_CHAR(pol.po_header_id)
WHERE  pol.po_header_id IN (SELECT po_header_id FROM pp)
ORDER  BY pol.po_header_id, pol.line_num
