--------------------------------------------------------------------
-- STEP 1: Look at the raw data first
--------------------------------------------------------------------
SELECT order_id, payment_type, payment_installments, payment_value
FROM payments
LIMIT 5;

SELECT product_id, product_category_name
FROM products
LIMIT 5;


--------------------------------------------------------------------
-- STEP 2: Check how clean the data actually is (6 checks)
--------------------------------------------------------------------

-- 2.1: Any nulls in payment_type?
SELECT COUNT(*)
FROM payments
WHERE payment_type IS NULL;
-- Result: 0 rows. Clean already.

-- 2.2: How much of payments is credit_card?
SELECT COUNT(*)
FROM payments
WHERE payment_type = 'credit_card';
-- Result: 76,795 of 103,886 rows. Installments only mean anything for
-- credit_card, so everything past this point filters on that.

-- 2.3: Any nulls in product_category_name?
SELECT COUNT(*)
FROM products
WHERE product_category_name IS NULL;
-- Result: 610 of 32,951 products.

-- 2.4: How many orders do those 610 uncategorized products touch?
SELECT COUNT(DISTINCT oi.order_id) AS orders_with_null_category
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
WHERE p.product_category_name IS NULL;
-- Result: 1,451 orders, about 1.5% of all orders. Small enough to
-- drop — a category called "unknown" wouldn't help anyone deciding
-- which banks to partner with anyway.

-- 2.5: Any order_id paid more than once in payments?
SELECT order_id, COUNT(*)
FROM payments
GROUP BY order_id
HAVING COUNT(*) > 1;
-- Result: 2,961 orders paid in more than one transaction (voucher +
-- card, split cards, etc). Most of these don't affect installments —
-- only the credit_card ones do. Checked next.

-- 2.6: How many of those are credit_card charged more than once on
-- the same order?
SELECT COUNT(*) AS orders_with_multiple_creditcard_rows
FROM (
    SELECT order_id
    FROM payments
    WHERE payment_type = 'credit_card'
    GROUP BY order_id
    HAVING COUNT(order_id) > 1
) sub;
-- Result: 290 orders. Checked these weren't accidental duplicate rows
-- — every one of the 290 has 2 different installment values attached
-- (e.g. one card at 4 months, one at 6 months), confirming they're
-- real split payments, not an error:
SELECT
    order_id,
    COUNT(*) AS num_rows,
    COUNT(DISTINCT payment_installments) AS distinct_installment_values,
    MIN(payment_installments) AS min_installments,
    MAX(payment_installments) AS max_installments
FROM payments
WHERE payment_type = 'credit_card'
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY distinct_installment_values DESC;

-- Conclusion from Step 2: the view (Step 3) needs to (a) filter to
-- payment_type = 'credit_card' and (b) collapse each order down to
-- 1 row using MAX(payment_installments) — two cards running side by
-- side finish when the longer one finishes, not when both are added
-- together, so MAX gives the real payoff length and SUM would have
-- overstated it.


--------------------------------------------------------------------
-- STEP 3: Build the cleaned view
--------------------------------------------------------------------
CREATE OR REPLACE VIEW View_Q3 AS
SELECT order_id, MAX(payment_installments) AS payment_inst
FROM payments
WHERE payment_type = 'credit_card'
GROUP BY order_id;
-- Result: 76,505 rows — validated as 76,795 raw credit_card rows
-- minus the 290 collapsed duplicates.


--------------------------------------------------------------------
-- STEP 4: Query all categories, unfiltered — see the full picture first
--------------------------------------------------------------------
SELECT
    pc.product_category_name_english,
    AVG(co.payment_inst) AS avg_installment,
    COUNT(*) AS num_orders
FROM View_Q3 co
JOIN order_items oi ON co.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_translation pc ON p.product_category_name = pc.product_category_name
WHERE p.product_category_name IS NOT NULL
GROUP BY pc.product_category_name_english
ORDER BY num_orders ASC;
-- Result: 70 categories. Smallest, security_and_services, has only
-- 1 order and an average of 1.0 installments — a big red flag that
-- some of these numbers might not be trustworthy. See Step 5 for how
-- that got resolved.


--------------------------------------------------------------------
-- STEP 5: Deciding which categories to trust (picking a threshold)
--------------------------------------------------------------------

-- 5.1: try the standard rule of thumb, n >= 30
SELECT
    pc.product_category_name_english,
    COUNT(*) AS num_orders
FROM View_Q3 co
JOIN order_items oi ON co.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_translation pc ON p.product_category_name = pc.product_category_name
WHERE p.product_category_name IS NOT NULL
GROUP BY pc.product_category_name_english
HAVING COUNT(*) < 30
ORDER BY num_orders ASC;
-- Result: 9 of 70 categories fall below n = 30 — la_cuisine,
-- fashion_sport, music, cds_dvds_musicals, fashion_childrens_clothes,
-- arts_and_craftmanship, home_comfort_2, flowers, and
-- security_and_services.

-- 5.2: check how much of the business gets cut at that threshold
WITH category_totals AS (
    SELECT
        pc.product_category_name_english,
        COUNT(*) AS num_orders
    FROM View_Q3 co
    JOIN order_items oi ON co.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN product_category_translation pc ON p.product_category_name = pc.product_category_name
    WHERE p.product_category_name IS NOT NULL
    GROUP BY pc.product_category_name_english
)
SELECT
    ROUND(100.0 * SUM(num_orders) FILTER (WHERE num_orders < 30)
        / SUM(num_orders), 2) AS pct_rows_excluded_at_30
FROM category_totals;
-- Result: cutting at n = 30 drops only about 0.16% of the
-- order-category rows used in this analysis — unlike Q2, where
-- reaching a trustworthy sample size meant giving up a real chunk of
-- revenue (8.52% at the 1,000-order cutoff), here the cutoff barely
-- costs anything.
--
-- Conclusion: n >= 30 is the threshold used in Step 6 — same rule of
-- thumb Q2 tried first, except this time it actually holds up.


--------------------------------------------------------------------
-- STEP 6: Final query — categories with enough orders to trust
--------------------------------------------------------------------
SELECT
    pc.product_category_name_english,
    AVG(co.payment_inst) AS avg_installment,
    COUNT(*) AS num_orders
FROM View_Q3 co
JOIN order_items oi ON co.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_translation pc ON p.product_category_name = pc.product_category_name
WHERE p.product_category_name IS NOT NULL
GROUP BY pc.product_category_name_english
HAVING COUNT(*) >= 30
ORDER BY avg_installment DESC;
-- Result: 61 categories left. This is the result set Chart 1 is
-- built from.


--------------------------------------------------------------------
-- STEP 7: Is this really about category, or just about price?
--------------------------------------------------------------------

-- 7.1: does avg_installment track avg_price closely enough that
-- category adds nothing beyond price?
SELECT
    pc.product_category_name_english,
    AVG(co.payment_inst) AS avg_installment,
    ROUND(AVG(oi.price)::numeric, 2) AS avg_price,
    COUNT(*) AS num_orders
FROM View_Q3 co
JOIN order_items oi ON co.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_translation pc ON p.product_category_name = pc.product_category_name
WHERE p.product_category_name IS NOT NULL
GROUP BY pc.product_category_name_english
HAVING COUNT(*) >= 30
ORDER BY avg_installment DESC;
-- Result: price and installment move together in general (computers
-- tops both lists at $1,115.67 avg price and 7.42 installments), but
-- several categories break the pattern enough to rule out price as
-- the sole explanation:
--   - office_furniture (5.20 installments) sits on par with
--     home_appliances_2 (5.50), despite an avg price barely a third
--     as high ($166 vs $555) — and clearly above cool_stuff and
--     furniture_bedroom, which sit in the same $170-176 price band
--     but only manage 4.0 installments.
--   - diapers_and_hygiene (3.19 installments, avg price $40.67) out-
--     installments telephony and books_general_interest (2.83 and
--     2.85) despite both of those costing nearly double.
--   - fixed_telephony breaks the pattern the other way: avg price
--     $225.84 (higher than watches_gifts and construction_tools_safety)
--     but only 3.12 installments, well below both.
--
-- Conclusion: price explains part of the pattern, but categories like
-- office_furniture and diapers_and_hygiene clearly get financed longer
-- than their price alone would predict — category carries real signal
-- on its own, not just a stand-in for price. This is the result set
-- Chart 2 is built from.


--------------------------------------------------------------------
-- STEP 8: Chart 3 — does order volume change the picture?
--------------------------------------------------------------------

-- Same query as Step 6, kept separate here since Chart 3 plots
-- num_orders against avg_installment directly (log scale on
-- num_orders) to check that high-volume categories like bed_bath_table
-- (8,929 orders) and office_furniture (1,185 orders) land in a
-- sensible spot, rather than the ranking being driven by small,
-- barely-passed-the-cutoff categories.
SELECT
    pc.product_category_name_english,
    AVG(co.payment_inst) AS avg_installment,
    ROUND(AVG(oi.price)::numeric, 2) AS avg_price,
    COUNT(*) AS num_orders
FROM View_Q3 co
JOIN order_items oi ON co.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_translation pc ON p.product_category_name = pc.product_category_name
WHERE p.product_category_name IS NOT NULL
GROUP BY pc.product_category_name_english
HAVING COUNT(*) >= 30
ORDER BY num_orders DESC;
