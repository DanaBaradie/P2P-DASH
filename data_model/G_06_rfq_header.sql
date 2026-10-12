-- G_6  RFQ / negotiation header (linked to G_4 on PR_NUMBER = REQUISITION_NUMBER).
-- RFQ_TIME_REMAINING is now the real time left until bidding closes.
SELECT DISTINCT
       pah.auction_header_id,
       pah.document_number                              AS rfq_number,
       REPLACE(INITCAP(REPLACE(pah.auction_status, '_', ' ')), 'Auction', 'RFQ')   AS rfq_status,
       CASE
         WHEN pah.auction_status LIKE '%CLOSED%'
           OR pah.auction_status IN ('CANCELLED', 'CANCELED')  THEN 'Closed'
         WHEN pah.auction_status = 'DRAFT'                     THEN 'Not published yet'
         WHEN pah.close_bidding_date IS NULL                   THEN 'Open'
         WHEN pah.close_bidding_date <= SYSDATE                THEN 'Bidding closed'
         ELSE TRUNC(pah.close_bidding_date - SYSDATE) || ' days '
              || TRUNC(MOD((pah.close_bidding_date - SYSDATE) * 24, 24)) || ' hrs left'
       END                                              AS rfq_time_remaining,
       NVL((SELECT MAX(COALESCE(s.vendor_name, hp.party_name))
            FROM   pon_bid_headers b
            LEFT JOIN poz_suppliers_v s ON s.vendor_id = b.vendor_id
            LEFT JOIN hz_parties hp     ON hp.party_id = b.trading_partner_id
            WHERE  b.auction_header_id = pah.auction_header_id
            AND    b.bid_status = 'ACTIVE'
            AND    (b.award_status = 'AWARDED' OR NVL(b.total_award_amount, 0) > 0)),
           'Not awarded yet')                           AS awarded_supplier,
       ai.requisition_number
FROM   pon_auction_headers_all pah
JOIN   pon_auction_item_prices_all ai ON ai.auction_header_id = pah.auction_header_id
WHERE  ai.requisition_number = :P_PR_NUMBER
