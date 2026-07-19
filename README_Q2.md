# Cleaning the data before Q2

Before writing the real query for Q2 (how much shipping cost eats into revenue per state), I needed to check how trustworthy the data actually was. Five checks, one at a time.

## Check 1: How many orders have no delivery date

The `order_delivered_customer_date` column is what decides whether an order actually reached the customer, so this came first.

```sql
SELECT COUNT(*) 
FROM orders 
WHERE order_delivered_customer_date IS NULL;
```

**Result: 2,965 rows.** Almost 3,000 orders have no delivery date at all. These need to be excluded — there's no way to know yet if they'll even go through.

## Check 2: How many order statuses exist

Knew there were 2,965 undelivered orders, but didn't yet know what the other statuses looked like.

```sql
SELECT order_status, COUNT(*)
FROM orders
GROUP BY order_status
ORDER BY COUNT(*) DESC;
```

**Result:** delivered = 96,478 out of 99,441 total. The rest split across shipped, canceled, unavailable, invoiced, processing, created, and approved.

## Check 3: Any orders marked delivered but missing a delivery date?

This checks for a contradiction — if an order's status says "delivered," it should always have a date attached.

```sql
SELECT COUNT(*)
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;
```

**Result: 8 rows.** Found 8 orders where the data contradicts itself — status says delivered, but no date. This is why the filter needs both conditions together, not just one.

## Check 4: Any negative or zero prices/shipping fees

Switched over to the `order_items` table, since that's where Q2 pulls price and shipping numbers from.

```sql
SELECT COUNT(*)
FROM order_items
WHERE price <= 0 OR freight_value < 0;
```

**Result: 0 rows.** No bad values here — this part of the data is clean already.

## Check 5: Any duplicate order_ids in orders

Checking that one row in `orders` really means one order — no accidental duplicates.

```sql
SELECT order_id, COUNT(*)
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;
```

**Result: 0 rows.** No duplicates.

---

# Building the filtered view

Based on all five checks, two conditions were needed: keep only `delivered` status, and require an actual delivery date (to catch the contradiction found in check 3).

```sql
CREATE OR REPLACE VIEW View_Q2 AS
SELECT
    order_id,
    customer_id,
    order_status,
    order_delivered_customer_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;
```

---

# Deciding which states to trust (picking a threshold)

After joining to `customers` and `order_items` and calculating shipping % of revenue by state, a problem showed up: **states with very few orders had percentages that swung wildly.** State RR had only 41 orders but its shipping percentage jumped to 28%, while SP had 40,494 orders and sat at a steady 13.85%.

Landed on the right cutoff in three steps:

**Tried n ≥ 30 first** (a common statistical rule of thumb) — but it cut nothing out. Even the smallest state, RR, had 41 orders, so 30 was too low a bar for this dataset.

**Checked where the percentages start to settle down** — grouped states by order count and looked at how wide the spread got within each group. Things clearly stabilize once a state passes roughly 1,000–2,000 orders (below that, percentages can swing by 8–10 points; above it, the swing shrinks to 2–3 points).

**Checked how much of the business gets cut at each threshold** — cutting at 1,000 orders drops 6.53% of total orders and 8.52% of total revenue, which is still a reasonable amount to lose. Cutting at 2,000 (more statistically solid) would drop nearly 16% of revenue — too much to lose just for cleaner numbers.

**Landed on 1,000 orders as the threshold** — a balance between trusting the statistics and not throwing away too much of the overall picture.

```sql
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
```

*Note: the chart built from this query only shows states with 1,000+ orders (14 of 27). The rest were left out because they didn't have enough orders to draw a reliable conclusion from.*
