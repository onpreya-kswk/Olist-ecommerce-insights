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
    -- Use English names. If a name is missing, use 'unknown' so the chart does not break.
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


--------------------------------------------------------------------
-- STEP 3.4: Data Cleaning for Scatter Plot (Building the Pre-Calculated View)
--------------------------------------------------------------------
-- Build a new view specifically structured to feed clean data into the Tableau scatter plot
CREATE OR REPLACE VIEW v_scatter_q3 AS
SELECT 
    p.product_category,
    -- Pre-calculate and force average payment values into numeric types to bypass Tableau web tool bugs
    ROUND(AVG(pay.payment_value)::numeric, 2) AS avg_order_value,
    -- Pre-calculate the average installment months per product group
    ROUND(AVG(pay.payment_installments)::numeric, 2) AS avg_payment_installments,
    -- Aggregate total unique orders to determine bubble marks sizes in the visual chart
    COUNT(DISTINCT pay.order_id) AS total_credit_card_orders
FROM payments pay
JOIN order_items i ON pay.order_id = i.order_id
JOIN v_clean_products_q3 p ON i.product_id = p.product_id
-- Focus strictly on credit card payments to monitor actual customer installment habits
WHERE pay.payment_type = 'credit_card'
GROUP BY p.product_category;


--------------------------------------------------------------------
-- STEP 3.5: Final Output Fetching (Testing the Result Sheet)
--------------------------------------------------------------------
-- Pull everything from the freshly built asset, ordered from the highest basket value down
SELECT * FROM v_scatter_q3 ORDER BY avg_order_value DESC;




