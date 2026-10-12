-- G_15  APPROVAL HISTORY for the chosen PR, its POs and invoices
-- (child of G_4, link REQUISITION_HEADER_ID).
--
-- * PR and PO actions: PO_ACTION_HISTORY (OBJECT_TYPE_CODE 'REQ'/'REQUISITION' and 'PO').
--   PERFORMER_ID is a PERSON_ID for internal users, or a supplier-contact PARTY_ID when
--   ROLE_CODE = 'SUPPLIER'. Falls back to CREATED_BY (user name) when neither resolves.
-- * Invoice approvals: AP_INV_APRVL_HIST_ALL (APPROVER_ID holds the approver's login user name).
WITH pr AS (
  SELECT prh.requisition_header_id, prh.requisition_number
  FROM   por_requisition_headers_all prh
  WHERE  prh.requisition_number = :P_PR_NUMBER
),
po_ids AS (
  SELECT DISTINCT pda.po_header_id
  FROM   pr
  JOIN   por_requisition_lines_all prl ON prl.requisition_header_id = pr.requisition_header_id
  JOIN   por_req_distributions_all prd ON prd.requisition_line_id   = prl.requisition_line_id
  JOIN   po_distributions_all      pda ON pda.req_distribution_id   = prd.distribution_id
),
inv_ids AS (
  SELECT DISTINCT ail.invoice_id
  FROM   ap_invoice_lines_all ail
  WHERE  ail.po_header_id IN (SELECT po_header_id FROM po_ids)
),
person AS (
  SELECT person_id, display_name
  FROM   per_person_names_f
  WHERE  name_type = 'GLOBAL'
  AND    TRUNC(SYSDATE) BETWEEN effective_start_date AND effective_end_date
),
-- PR + PO actions with the performer's name resolved
doc_hist AS (
  SELECT 1 AS sort1, 'PR ' || pr.requisition_number AS document, pah.*
  FROM   pr
  JOIN   po_action_history pah
         ON  pah.object_id = pr.requisition_header_id
         AND pah.object_type_code IN ('REQ', 'REQUISITION')
  UNION ALL
  SELECT 2, 'PO ' || poh.segment1, pah.*
  FROM   po_headers_all poh
  JOIN   po_action_history pah
         ON  pah.object_id = poh.po_header_id
         AND pah.object_type_code = 'PO'
  WHERE  poh.po_header_id IN (SELECT po_header_id FROM po_ids)
),
hist AS (
  SELECT dh.sort1,
         dh.document,
         INITCAP(REPLACE(dh.action_code, '_', ' '))
           || CASE WHEN dh.role_code IS NOT NULL
                   THEN ' (' || INITCAP(REPLACE(dh.role_code, '_', ' ')) || ')' END   AS action,
         COALESCE(CASE WHEN dh.role_code = 'SUPPLIER' THEN hp.party_name ELSE p.display_name END,
                  dh.created_by)                                                    AS action_by,
         CAST(NVL(dh.action_date, dh.creation_date) AS DATE)                        AS act_date,
         dh.sequence_num                                                            AS seq,
         CASE WHEN NVL(dh.note_message_code_flag, 'N') = 'Y' THEN NULL
              ELSE SUBSTR(dh.note, 1, 120) END                                      AS note
  FROM   doc_hist dh
  LEFT JOIN person     p  ON p.person_id = dh.performer_id AND NVL(dh.role_code, 'X') <> 'SUPPLIER'
  LEFT JOIN hz_parties hp ON hp.party_id = dh.performer_id AND dh.role_code = 'SUPPLIER'
  UNION ALL
  SELECT 3,
         'Invoice ' || aia.invoice_num,
         INITCAP(REPLACE(h.response, '_', ' ')),
         h.approver_id,
         CAST(NVL(h.action_date, h.creation_date) AS DATE),
         NVL(h.notification_order, h.iteration),
         SUBSTR(NVL(h.approver_comments, h.approval_step), 1, 120)
  FROM   ap_inv_aprvl_hist_all h
  JOIN   ap_invoices_all aia ON aia.invoice_id = h.invoice_id
  WHERE  h.invoice_id IN (SELECT invoice_id FROM inv_ids)
)
SELECT (SELECT requisition_header_id FROM pr) AS requisition_header_id,
       document, action, NVL(action_by, '-') AS action_by,
       TO_CHAR(act_date, 'DD/MM/YYYY HH24:MI') AS action_date,
       note
FROM   hist
ORDER  BY sort1, document, act_date, seq
