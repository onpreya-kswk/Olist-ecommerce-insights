--------------------------------------------------------------------
-- STEP 1: Look at the raw data first
--------------------------------------------------------------------
SELECT order_id, customer_id, order_status, order_delivered_customer_date
FROM orders
LIMIT 5;

SELECT order_id, price, freight_value
FROM order_items
LIMIT 5;


--------------------------------------------------------------------
-- STEP 2: Check how clean the data actually is (5 checks)
--------------------------------------------------------------------

-- 2.1: How many orders have no delivery date?
SELECT COUNT(*) 
FROM orders 
WHERE order_delivered_customer_date IS NULL;
-- Result: 2,965 rows. Need to exclude these — no way to know yet if
-- they'll even go through.

-- 2.2: What order statuses exist?
SELECT order_status, COUNT(*)
FROM orders
GROUP BY order_status
ORDER BY COUNT(*) DESC;
-- Result: delivered = 96,478 out of 99,441. The rest split across
-- shipped, canceled, unavailable, invoiced, processing, created, approved.

-- 2.3: Any orders marked delivered but missing a delivery date?
SELECT COUNT(*)
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
-- Result: 8 rows. Data contradicts itself here, which is why the
-- filter needs both conditions together, not just one.

-- 2.4: Any negative or zero prices/shipping fees?
SELECT COUNT(*)
FROM order_items
WHERE price <= 0 OR freight_value < 0;
-- Result: 0 rows. Clean already.

-- 2.5: Any duplicate order_ids in orders?
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
-- Result: 0 rows. No duplicates.

-- Conclusion from Step 2: the view (Step 3) needs two conditions —
-- order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL


--------------------------------------------------------------------
-- STEP 3: Build the filtered view
--------------------------------------------------------------------
CREATE OR REPLACE VIEW View_Q2 AS
SELECT
    order_id,
    customer_id,
    order_status,
    order_delivered_customer_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;


--------------------------------------------------------------------
-- STEP 4: Query all states, unfiltered — see the full picture first
--------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    CAST(SUM(i.price) AS DECIMAL(10,2)) AS price_orders,
    CAST(SUM(i.freight_value) AS DECIMAL(10,2)) AS shipping_orders,
    CAST((SUM(i.freight_value) / SUM(i.price) * 100) AS DECIMAL(10,2)) AS shipping_to_revenue_pct
FROM View_Q2 o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items i ON o.order_id = i.order_id
GROUP BY c.customer_state
ORDER BY total_orders ASC;
-- Result: 27 states. Smallest, RR, has only 41 orders and a shipping
-- percentage of 28% — a big red flag that some of these numbers might
-- not be trustworthy. See Step 5 for how that got resolved.


--------------------------------------------------------------------
-- STEP 5: Deciding which states to trust (picking a threshold)
--------------------------------------------------------------------

-- 5.1: try the standard rule of thumb, n >= 30
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    CAST((SUM(i.freight_value) / SUM(i.price) * 100) AS DECIMAL(10,2)) AS shipping_to_revenue_pct
FROM View_Q2 o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items i ON o.order_id = i.order_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 30
ORDER BY total_orders ASC;
-- Result: still all 27 states. Even RR (the smallest) has 41 orders,
-- so 30 is too low a bar for this dataset — it doesn't cut anything.

-- 5.2: check how much of the business gets cut at 1,000 orders vs 2,000
WITH state_totals AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(i.price) AS total_revenue
    FROM View_Q2 o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items i ON o.order_id = i.order_id
    GROUP BY c.customer_state
)
SELECT
    ROUND(100.0 * SUM(total_orders) FILTER (WHERE total_orders < 1000)
        / SUM(total_orders), 2) AS pct_orders_excluded_at_1000,
    ROUND(100.0 * SUM(total_revenue) FILTER (WHERE total_orders < 1000)
        / SUM(total_revenue), 2) AS pct_revenue_excluded_at_1000
FROM state_totals;
-- Result: cutting at 1,000 orders drops 6.53% of orders and 8.52% of
-- revenue — a reasonable trade. Cutting at 2,000 instead (checked the
-- same way) would drop close to 16% of revenue, too much just to make
-- the numbers a bit more stable statistically.
--
-- Conclusion: 1,000 orders is the threshold used in Step 6 — a balance
-- between trusting the statistics and not throwing away too much of
-- the overall picture.


--------------------------------------------------------------------
-- STEP 6: Final query — states with enough orders to trust
--------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    CAST(SUM(i.price) AS DECIMAL(10,2)) AS price_orders,
    CAST(SUM(i.freight_value) AS DECIMAL(10,2)) AS shipping_orders,
    CAST((SUM(i.freight_value) / SUM(i.price) * 100) AS DECIMAL(10,2)) AS shipping_to_revenue_pct
FROM View_Q2 o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items i ON o.order_id = i.order_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 1000
ORDER BY shipping_to_revenue_pct DESC;
-- Result: 14 states left. This is the result set the chart is built from.


--------------------------------------------------------------------
-- STEP 7: Why do PE and CE have the highest shipping burden?
--------------------------------------------------------------------

-- 7.1: is the problem on the freight side or the price side?
SELECT
    c.customer_state,
    ROUND(AVG(i.price)::numeric, 2) AS avg_price_per_item,
    ROUND(AVG(i.freight_value)::numeric, 2) AS avg_freight_per_item
FROM View_Q2 o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items i ON o.order_id = i.order_id
WHERE c.customer_state IN ('PE', 'CE', 'SP')
GROUP BY c.customer_state;
-- Result: PE/CE prices aren't lower than SP's (actually higher), but
-- their freight is more than double SP's (32.7 vs 15.1). The problem
-- is freight being genuinely expensive, not cheap products skewing
-- the ratio.

-- 7.2: is product weight the reason freight is higher?
SELECT
    c.customer_state,
    ROUND(AVG(p.product_weight_g)::numeric, 2) AS avg_weight_g
FROM View_Q2 o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items i ON o.order_id = i.order_id
JOIN products p ON i.product_id = p.product_id
WHERE c.customer_state IN ('PE', 'CE', 'SP')
GROUP BY c.customer_state;
-- Result: average weight is nearly identical across all three states
-- (1,927-2,035 g). Ruled out.

-- 7.3: do PE/CE customers rely more on out-of-state sellers?
SELECT
    c.customer_state AS buyer_state,
    s.seller_state,
    COUNT(*) AS order_count
FROM View_Q2 o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items i ON o.order_id = i.order_id
JOIN sellers s ON i.seller_id = s.seller_id
WHERE c.customer_state IN ('PE', 'CE', 'SP')
GROUP BY c.customer_state, s.seller_state
ORDER BY c.customer_state, order_count DESC;
-- Result: all three states buy from SP-based sellers at a similar
-- rate (71-78% of orders). Ruled out.
--
-- What's left standing: plain geographic distance. PE and CE sit
-- roughly 2,000+ km from SP, where most sellers are based, while SP's
-- own orders travel a much shorter distance on average.
