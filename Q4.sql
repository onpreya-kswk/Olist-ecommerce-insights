--------------------------------------------------------------------
-- STEP 1: Look at the raw data first
--------------------------------------------------------------------
-- Check raw orders data (Total = 99,441 rows)
SELECT order_id, order_status, order_delivered_customer_date, order_estimated_delivery_date
FROM orders
LIMIT 5;

-- Check raw reviews data (Total = 99,224 rows)
SELECT review_id, order_id, review_score
FROM reviews
LIMIT 5;


--------------------------------------------------------------------
-- STEP 2: Check data clean and count data loss (4 checks)
--------------------------------------------------------------------

-- 2.1: Total raw orders in the system (Check 1)
SELECT COUNT(*) AS total_raw_orders 
FROM orders;
-- Result: 99,441 rows.

-- 2.2: Total orders that are successfully delivered (Check 2)
SELECT COUNT(*) AS total_delivered_orders
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;
-- Result: 96,470 rows.
--
-- Data Loss Report 1: 99,441 - 96,470 = 2,971 rows excluded.
-- Reason: These orders are canceled or still shipping. They have no actual 
-- delivery date, so we cannot calculate delivery delay.

-- 2.3: Any order_id with more than one review row? (Check 3 -- same
-- concern as the duplicate credit_card rows found in Q3: need to
-- confirm these are real repeat reviews, not accidental duplicates,
-- and see how far apart the scores are before deciding how to
-- collapse them to 1 row per order.)
SELECT
    CASE 
        WHEN max_score - min_score = 0 THEN 'Same score (true duplicate)'
        WHEN max_score - min_score <= 1 THEN 'Small disagreement (diff 1)'
        ELSE 'Big disagreement (diff 2+)'
    END AS disagreement_type,
    COUNT(*) AS num_orders
FROM (
    SELECT order_id, MIN(review_score) AS min_score, MAX(review_score) AS max_score
    FROM reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
) sub
GROUP BY disagreement_type
ORDER BY num_orders DESC;
-- Result: 340 orders have more than one review row --
--   Same score (true duplicate):   223 orders (~66%) -- AVG is exact,
--     no distortion at all.
--   Small disagreement (diff 1):    53 orders (~16%) -- AVG lands on
--     a value close to both scores (e.g. 3 and 4 -> 3.5), still a fair
--     summary of the order.
--   Big disagreement (diff 2+):     64 orders (~19%) -- AVG lands on
--     a score neither reviewer actually gave (e.g. 1 and 5 -> 3),
--     which misrepresents both opinions.
--
-- Decision: exclude only the 64 "big disagreement" orders. At
-- 64 / 75,355 (~0.085% of the analysis set), this is smaller than the
-- 1.47% dropped for null categories in Q3 -- negligible cost, and it
-- keeps AVG from being calculated on scores that contradict each
-- other by 2+ points. The 53 "small disagreement" orders are kept --
-- a 1-point gap between reviewers is normal variation, and AVG still
-- summarizes them fairly.

-- 2.4: Total delivered orders that have a customer review, after
-- also dropping the 64 orders with big review disagreement (Check 4)
WITH aggregated_reviews AS (
    -- Combine duplicate reviews for the same order into 1 row using
    -- AVG, but only where the reviews don't wildly disagree (diff < 2)
    SELECT order_id, AVG(review_score) AS avg_review_score
    FROM reviews
    GROUP BY order_id
    HAVING MAX(review_score) - MIN(review_score) < 2
)
SELECT COUNT(*) AS total_perfect_orders
FROM orders o
JOIN aggregated_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;
-- Result: 75,298 rows.
-- Note: this is 75,355 - 75,298 = 57 fewer orders than before the
-- big-disagreement filter, not 64 as expected -- meaning 7 of the 64
-- big-disagreement orders were already excluded by the delivered/date
-- conditions in this query (i.e. they weren't part of the 75,355 to
-- begin with). The overlap doesn't change the decision from Step 2.3,
-- just the exact count actually removed here.
--
-- Data Loss Report 2: 96,470 - 75,298 = 21,172 rows excluded.
-- Reason: most of this gap is delivered orders with no review score at
-- all (21,115, as found before excluding big-disagreement orders);
-- the remaining 57 are orders dropped in Step 2.3 for having review
-- scores that disagree by 2+ points, which AVG can't summarize fairly.
--
-- Final Clean Data for Analysis: 75,298 rows remaining.


--------------------------------------------------------------------
-- STEP 3: Build the filtered view
--------------------------------------------------------------------
DROP VIEW IF EXISTS View_Q4 CASCADE;

-- Creates the cleaned view, with duplicate reviews on the same order
-- collapsed to 1 row using AVG -- unlike Q3's MAX (installments are a
-- single commitment length; review scores are separate opinions, so
-- averaging them is the fairer summary of "how this order was rated").
-- Orders where duplicate reviews disagree by 2+ points are dropped
-- entirely (see Step 2.3) -- AVG can't fairly summarize a 1-star and
-- a 5-star review on the same order.
CREATE VIEW View_Q4 AS
WITH aggregated_reviews AS (
    -- Collapse duplicate reviews on the same order into 1 row using
    -- their average (orders with 2+ point disagreement were already
    -- excluded above via the HAVING clause)
    SELECT order_id, AVG(review_score) AS avg_review_score
    FROM reviews
    GROUP BY order_id
    HAVING MAX(review_score) - MIN(review_score) < 2
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    -- Number of days late (a positive value means delivered after the
    -- estimated date)
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) AS delivery_delay_days,
    -- Label each order 'Delayed' if it arrived after the estimate,
    -- otherwise 'On-Time'
    CASE 
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Delayed'
        ELSE 'On-Time'
    END AS delivery_performance,
    r.avg_review_score AS review_score
FROM orders o
-- Join to the collapsed review data -- this join is what shrinks the
-- table down to 1 row per order
INNER JOIN aggregated_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;

-- Quick check to verify final row count
SELECT COUNT(*) FROM View_Q4;
-- Result: should be 75,298, matching total_perfect_orders from Step
-- 2.4 exactly -- confirms no rows were lost or duplicated in the view.


--------------------------------------------------------------------
-- STEP 4: Query overall performance — see the full picture first
--------------------------------------------------------------------
SELECT
    delivery_performance,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(review_score)::numeric, 2) AS avg_review_score
FROM View_Q4
GROUP BY delivery_performance;
-- Result: [run this -- these numbers were calculated before the 64
-- big-disagreement orders were excluded in Step 3, so the totals will
-- shift slightly (previously On-Time 69,379 | Delayed 5,976 | Total
-- 75,355, avg scores 4.29 vs 2.56). Update all three lines below and
-- the conclusion once re-run against the corrected View_Q4.]
-- On-Time -> [rerun] orders | [rerun] average score
-- Delayed ->  [rerun] orders | [rerun] average score
-- Total   -> [rerun] orders.
--
-- Conclusion from Step 4: Delivery delay drops the review score significantly.


--------------------------------------------------------------------
-- STEP 5: Query all states, unfiltered — see the full picture first
--------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(CASE WHEN o.delivery_performance = 'On-Time' THEN o.review_score END)::numeric, 2) AS avg_score_on_time,
    ROUND(AVG(CASE WHEN o.delivery_performance = 'Delayed' THEN o.review_score END)::numeric, 2) AS avg_score_delayed,
    -- Calculate the score drop (On-Time score minus Delayed score)
    ROUND((AVG(CASE WHEN o.delivery_performance = 'On-Time' THEN o.review_score END) - 
           AVG(CASE WHEN o.delivery_performance = 'Delayed' THEN o.review_score END))::numeric, 2) AS score_drop
FROM View_Q4 o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY total_orders ASC;
-- Result: 27 states in total. The smallest state, RR, has very few orders 
-- and its score drop is too volatile. Small states have low order volumes, 
-- making their averages swing wildly and untrustworthy for statistical analysis. 
-- See Step 6 for how to resolve this.


--------------------------------------------------------------------
-- STEP 6: Deciding which states to trust (picking a threshold)
--------------------------------------------------------------------

-- 6.1: try the standard rule of thumb, n >= 30 -- check if it cuts
-- anything, same first move as Q2 and Q3.
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM View_Q4 o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) < 30
ORDER BY total_orders ASC;
-- Result: [run this -- note which states, if any, fall below 30]

-- 6.2: check how much of the business gets cut at 1,000 orders,
-- same method used in Q2 -- measured here by orders and by review
-- volume, since Q4 has no revenue figure to weigh against.
WITH state_totals AS (
    SELECT
        c.customer_state,
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM View_Q4 o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_state
)
SELECT
    ROUND(100.0 * SUM(total_orders) FILTER (WHERE total_orders < 1000)
        / SUM(total_orders), 2) AS pct_orders_excluded_at_1000
FROM state_totals;
-- Result: [run this -- confirm 1,000 is actually a reasonable cutoff
-- for View_Q4's own order distribution, not just reused from Q2
-- because the number happened to work there]
--
-- Conclusion: keep 1,000 as the threshold only if this comes back
-- similarly low-cost as it did in Q2/Q3; otherwise adjust and re-check.


--------------------------------------------------------------------
-- STEP 7: Final query — states with enough orders to trust
--------------------------------------------------------------------
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    -- Percentage of delayed orders in each state
    ROUND((COUNT(DISTINCT CASE WHEN o.delivery_performance = 'Delayed' THEN o.order_id END) * 100.0 / COUNT(DISTINCT o.order_id))::numeric, 2) AS delay_rate_pct,
    ROUND(AVG(CASE WHEN o.delivery_performance = 'On-Time' THEN o.review_score END)::numeric, 2) AS avg_score_on_time,
    ROUND(AVG(CASE WHEN o.delivery_performance = 'Delayed' THEN o.review_score END)::numeric, 2) AS avg_score_delayed,
    ROUND((AVG(CASE WHEN o.delivery_performance = 'On-Time' THEN o.review_score END) - 
           AVG(CASE WHEN o.delivery_performance = 'Delayed' THEN o.review_score END))::numeric, 2) AS score_drop
FROM View_Q4 o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 1000
ORDER BY score_drop DESC;
-- Result: 11 states remain after using the threshold of >= 1000 orders
-- (RJ, PE, DF, GO, RS, SC, MG, BA, ES, PR, SP). This is the result set
-- the chart is built from.
--
-- Note: CE -- one of Q2's two highest shipping-cost states, alongside
-- PE -- drops out of this list entirely. Checked directly: CE has
-- only 984 orders in View_Q4, just under the 1,000 cutoff. This isn't
-- a data error -- View_Q4's filter is stricter than Q2's View_Q2. Q2
-- only required delivered + valid dates; Q4 also requires a review
-- score (and excludes orders with big review disagreement), so fewer
-- CE orders clear the bar here even though CE cleared 1,000 easily
-- under Q2's looser filter.
--
-- Conclusion from Step 7: score_drop ranges from 1.44 (SP) up to 2.12
-- (RJ), with PE close behind at 2.09. PE -- the one high-shipping-cost
-- state from Q2 still present here -- does sit near the top, but RJ
-- (not flagged as high-shipping-cost in Q2) sits above it, and SP
-- (Q2's lowest shipping-cost state) sits at the bottom as expected.
-- This is consistent with Step 4's finding: delay hurts review scores
-- everywhere, and shipping cost alone doesn't clearly predict which
-- states get hit hardest. Step 8 digs into why.


--------------------------------------------------------------------
-- STEP 8: Deep dive — Does distance from the hub explain the score drop?
--------------------------------------------------------------------

-- 8.1: Is the actual number of delay days higher for PE and CE (Q2's
-- high-shipping-cost, far-from-hub states) than for SP (Q2's lowest)?
-- Included here even though CE fell below Step 7's 1,000-order
-- threshold, since this query isn't restricted by that cutoff -- CE
-- still has enough orders (984) to compare on its own.
SELECT
    c.customer_state,
    ROUND(AVG(o.delivery_delay_days) FILTER (WHERE o.delivery_performance = 'Delayed')::numeric, 1) AS avg_days_late_when_delayed,
    ROUND(AVG(o.review_score) FILTER (WHERE o.delivery_performance = 'Delayed')::numeric, 2) AS avg_score_when_delayed
FROM View_Q4 o
JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_state IN ('PE', 'CE', 'SP')
GROUP BY c.customer_state;
-- Result: CE  -> 14.4 days late on average | 2.20 average score when delayed
--         PE  -> 10.6 days late on average | 2.20 average score when delayed
--         SP  ->  6.3 days late on average | 2.89 average score when delayed
--
-- CE and PE run more than double SP's average delay when a delay
-- happens, and their average score when delayed is noticeably lower
-- than SP's. This connects back to Q2: CE and PE sit farthest from
-- the SP distribution hub, so when something does go wrong, the delay
-- tends to run longer there -- and a longer delay drives the score
-- down further. The chain is: distance from hub -> longer delays when
-- they happen -> lower satisfaction on those delayed orders.
--
-- This also explains why Step 7's score_drop (on-time score minus
-- delayed score, within the same state) didn't cleanly rank PE/CE at
-- the top -- score_drop nets out each state's own on-time baseline,
-- which varies by state for reasons beyond delay alone. Looking at
-- the delayed orders on their own, as done here, shows the
-- distance -> delay severity -> lower score pattern more directly.

-- 8.2: Does the delay-days -> lower-score pattern hold across all 11
-- states from Step 7, not just the 3 checked in 8.1? CE is added back
-- in here too (via the OR clause) since it's directly relevant to the
-- Q2 comparison even though it falls just under the 1,000-order bar.
-- This is the result set Chart 2 is built from.
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(o.delivery_delay_days) FILTER (WHERE o.delivery_performance = 'Delayed')::numeric, 1) AS avg_days_late_when_delayed,
    ROUND(AVG(o.review_score) FILTER (WHERE o.delivery_performance = 'Delayed')::numeric, 2) AS avg_score_when_delayed
FROM View_Q4 o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.customer_state
HAVING COUNT(DISTINCT o.order_id) >= 1000 OR c.customer_state = 'CE'
ORDER BY avg_days_late_when_delayed DESC;
-- Result: CE  ->  984 orders | 14.4 days late | 2.20 avg score
--         RJ  -> 9576 orders | 12.2 days late | 2.13 avg score
--         PE  -> 1229 orders | 10.6 days late | 2.20 avg score
--         BA  -> 2571 orders | 10.3 days late | 2.58 avg score
--         GO  -> 1510 orders |  9.7 days late | 2.45 avg score
--         ES  -> 1592 orders |  8.9 days late | 2.70 avg score
--         RS  -> 4183 orders |  8.4 days late | 2.54 avg score
--         PR  -> 3884 orders |  7.0 days late | 2.79 avg score
--         SC  -> 2797 orders |  6.9 days late | 2.65 avg score
--         MG  -> 8847 orders |  6.8 days late | 2.69 avg score
--         SP  -> 31536 orders |  6.3 days late | 2.89 avg score
--         DF  -> 1646 orders |  6.1 days late | 2.46 avg score
--
-- The overall direction holds: the 3 longest-delay states (CE, RJ, PE)
-- sit at the bottom on score, and SP -- among the shortest delays --
-- sits at the top. But it's not a clean straight line -- two states
-- break the pattern:
--   - DF has the shortest average delay of all (6.1 days, even
--     shorter than SP's 6.3) but a middling score (2.46), well below
--     what its short delay would predict.
--   - BA (10.3 days) scores higher (2.58) than GO (9.7 days, 2.45)
--     despite running a longer delay -- the two are out of order.
-- So delay length is a real driver of dissatisfaction, but not the
-- only one -- something else (unmeasured here) pulls DF's score down
-- and lifts BA's, on top of the delay-length effect.