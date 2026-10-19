SELECT username
FROM   per_users
WHERE  username IS NOT NULL
ORDER  BY username
;

SELECT product
FROM  (SELECT 'Purchase Orders' AS product, 1 AS sort_key FROM dual
       UNION ALL SELECT 'Purchase Requisitions', 2 FROM dual
       UNION ALL SELECT 'Fixed Assets', 3 FROM dual
       UNION ALL SELECT 'Bank Statements', 4 FROM dual
       UNION ALL SELECT 'Receivables', 5 FROM dual
       UNION ALL SELECT 'Payables', 6 FROM dual
       UNION ALL SELECT 'General Ledger', 7 FROM dual
       UNION ALL SELECT 'Payments', 8 FROM dual)
ORDER  BY sort_key
