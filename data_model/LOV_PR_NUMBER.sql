-- LOV_PR_NUMBER  –  list of values for parameter P_PR_NUMBER (newest first)
SELECT prh.requisition_number
FROM   por_requisition_headers_all prh
ORDER  BY prh.creation_date DESC
