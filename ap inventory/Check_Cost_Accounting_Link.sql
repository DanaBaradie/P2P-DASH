SELECT xte.application_id,
       xte.entity_code,
       xet.name                         AS event_type,
       xte.source_id_int_1,
       xte.source_id_int_2,
       xte.source_id_int_3,
       xte.source_id_char_1,
       xal.ae_line_num,
       xdl.source_distribution_type,
       xdl.source_distribution_id_num_1,
       xdl.source_distribution_id_num_2,
       xdl.unrounded_accounted_dr,
       xdl.unrounded_accounted_cr
FROM   xla_transaction_entities xte
JOIN   xla_ae_headers xah
       ON xah.entity_id = xte.entity_id
      AND xah.application_id = xte.application_id
JOIN   xla_ae_lines xal
       ON xal.ae_header_id = xah.ae_header_id
      AND xal.application_id = xah.application_id
JOIN   xla_events xe
       ON xe.event_id = xah.event_id
      AND xe.application_id = xah.application_id
LEFT JOIN xla_event_types_tl xet
       ON xet.application_id = xe.application_id
      AND xet.entity_code = xte.entity_code
      AND xet.event_type_code = xe.event_type_code
      AND xet.language = USERENV('LANG')
LEFT JOIN xla_distribution_links xdl
       ON xdl.application_id = xal.application_id
      AND xdl.ae_header_id = xal.ae_header_id
      AND xdl.ae_line_num = xal.ae_line_num
WHERE  xte.transaction_number = '741405'
ORDER  BY xte.application_id, xte.entity_code, xet.name, xal.ae_line_num


SELECT imt.transaction_id,
       imt.inventory_item_id,
       esi.item_number,
       imt.organization_id,
       org.organization_code            AS organization_code,
       imt.transfer_organization_id,
       torg.organization_code           AS transfer_organization_code,
       imt.transaction_type_id,
       imt.transaction_quantity
FROM   inv_material_txns imt
LEFT JOIN egp_system_items_b esi
       ON esi.inventory_item_id = imt.inventory_item_id
      AND esi.organization_id = imt.organization_id
LEFT JOIN inv_org_parameters org  ON org.organization_id  = imt.organization_id
LEFT JOIN inv_org_parameters torg ON torg.organization_id = imt.transfer_organization_id
WHERE  imt.transaction_id = 741405
