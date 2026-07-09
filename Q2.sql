-- ====================================================================
-- Q2 (Before Buying): Target Market & Profitability Analysis
-- ====================================================================

--------------------------------------------------------------------
-- STEP 2.1: Data Exploration (Sifting through raw structures)
--------------------------------------------------------------------
-- Look at how state codes are stored
SELECT customer_id, customer_unique_id, customer_state 
FROM customers 
LIMIT 5;

-- Examine raw pricing and freight structures
SELECT order_id, price, freight_value 
FROM order_items 
LIMIT 5;


--------------------------------------------------------------------
-- STEP 2.2: Data Cleaning (Building a safe, delivered-only view)
--------------------------------------------------------------------
CREATE OR REPLACE VIEW v_clean_orders_q2 AS 
SELECT 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp::timestamp AS purchase_date,
    order_delivered_customer_date::timestamp AS delivered_date
FROM orders
WHERE order_status = 'delivered' 
  AND order_delivered_customer_date IS NOT NULL;


--------------------------------------------------------------------
-- STEP 2.3: Core Analytical Query
--------------------------------------------------------------------
SELECT 
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(i.price)::numeric, 2) AS total_product_revenue,
    ROUND(SUM(i.freight_value)::numeric, 2) AS total_shipping_cost,
    -- Ratio Formula: Lower % means higher net margins for the business
    ROUND((SUM(i.freight_value) / SUM(i.price) * 100)::numeric, 2) AS shipping_to_revenue_pct
FROM v_clean_orders_q2 o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items i ON o.order_id = i.order_id
GROUP BY c.customer_state
ORDER BY total_product_revenue DESC;
