SELECT ccdl.*
FROM   cst_cost_distribution_lines ccdl
WHERE  ccdl.distribution_line_id IN (896261, 901051, 899411)


SELECT xdl.source_distribution_id_num_1,
       ccd.distribution_id,
       ct.transaction_id,
       ct.txn_source_doc_number,
       ct.rcv_transaction_id,
       ct.inventory_item_id,
       ct.inventory_org_id
FROM   xla_distribution_links xdl
JOIN   cst_cost_distribution_lines ccdl
       ON ccdl.distribution_line_id = xdl.source_distribution_id_num_1
JOIN   cst_cost_distributions ccd
       ON ccd.distribution_id = ccdl.distribution_id
JOIN   cst_transactions ct
       ON ct.transaction_id = ccd.transaction_id
WHERE  xdl.application_id = 707
AND    xdl.source_distribution_type = 'PO_DELIVERY_INTO_INVENTORY'
AND    xdl.source_distribution_id_num_1 IN (896261, 901051, 899411)
