-- G_7  Supplier bids (linked to G_6 on AUCTION_HEADER_ID). Awarded bid is listed first.
SELECT pbh.auction_header_id,
       hp.party_name        AS bid_supplier,
       pbh.bid_number,
       pbh.buyer_bid_total  AS bid_amount,
       CASE WHEN pbh.award_status = 'AWARDED' OR NVL(pbh.total_award_amount, 0) > 0
            THEN 'AWARDED' ELSE 'Not awarded' END AS is_awarded,
       'Responded'          AS response_status
FROM   pon_bid_headers pbh
LEFT JOIN hz_parties hp ON hp.party_id = pbh.trading_partner_id
WHERE  pbh.bid_status = 'ACTIVE'
AND    pbh.auction_header_id IN (SELECT ai.auction_header_id
                                 FROM   pon_auction_item_prices_all ai
                                 WHERE  ai.requisition_number = :P_PR_NUMBER)
ORDER  BY pbh.auction_header_id,
          CASE WHEN pbh.award_status = 'AWARDED' OR NVL(pbh.total_award_amount, 0) > 0 THEN 0 ELSE 1 END,
          pbh.buyer_bid_total
