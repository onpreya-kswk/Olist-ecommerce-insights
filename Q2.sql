SELECT 
    c.customer_state AS state_name,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price) AS total_product_revenue,
    SUM(oi.freight_value) AS total_shipping_cost,
    -- Calculate the ratio: Shipping cost as a percentage of the total (lower is better)
    ROUND((SUM(oi.freight_value) / SUM(oi.price) * 100)::numeric, 2) AS shipping_to_revenue_pct
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'  -- (Select orders with status Delivered)
GROUP BY c.customer_state
ORDER BY total_product_revenue DESC; -- (Ordered by Revenue: Highest to Lowest)
