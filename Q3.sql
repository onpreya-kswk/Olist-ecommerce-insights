-- ====================================================================
-- Q3 (During Checkout): Product Categories & Credit Card Installments
-- ====================================================================

--------------------------------------------------------------------
-- STEP 3.1: Data Exploration (Checking raw payment and product text)
--------------------------------------------------------------------
SELECT order_id, payment_type, payment_installments, payment_value 
FROM payments 
LIMIT 5;

SELECT product_id, product_category_name 
FROM products 
LIMIT 5;


--------------------------------------------------------------------
-- STEP 3.2: Data Cleaning (Translating categories and handling nulls)
--------------------------------------------------------------------
CREATE OR REPLACE VIEW v_clean_products_q3 AS 
SELECT 
    p.product_id,
    -- สลับมาใช้ภาษาอังกฤษ ถ้าสินค้าชิ้นไหนไม่มีให้แทนค่าด้วย 'unknown' ป้องกันกราฟพัง
    COALESCE(t.product_category_name_english, 'unknown') AS product_category
FROM products p
LEFT JOIN product_category_translation t 
    ON p.product_category_name = t.product_category_name;


--------------------------------------------------------------------
-- STEP 3.3: Core Analytical Query (Calculating average installments)
--------------------------------------------------------------------
SELECT 
    p.product_category,
    COUNT(DISTINCT pay.order_id) AS total_credit_card_orders,
    ROUND(AVG(pay.payment_installments)::numeric, 2) AS avg_payment_installments,
    MAX(pay.payment_installments) AS max_payment_installments
FROM payments pay
JOIN order_items i ON pay.order_id = i.order_id
JOIN v_clean_products_q3 p ON i.product_id = p.product_id
WHERE pay.payment_type = 'credit_card'
GROUP BY p.product_category
ORDER BY avg_payment_installments DESC;

