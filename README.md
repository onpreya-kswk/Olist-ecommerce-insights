# Olist E-Commerce Insights

Digging into Olist's Brazilian e-commerce data to find where marketing spend is safest, how customers pay for expensive items, and what that means for the business.

**Tools:** Python (loading the data), PostgreSQL (all the analysis), Tableau (charts). Python is only used once, at the very start, to move the raw CSV files into the database — every insight after that comes from SQL queries.

## Step 1: Getting the Data In

Before any analysis can happen, the raw CSV files need to live in a proper database instead of eight separate spreadsheets. This step handles that using a Python script.

Script: [`data_ingestion.py`](./data_ingestion.py)

What it does:
* Reads all 8 CSV files and loads each one into its own PostgreSQL table.
* Uses `encoding='latin1'` — without this, the script crashes on the Portuguese accented characters in the product category names.
* Loads data in batches of 10,000 rows instead of all at once, so it doesn't eat up all the RAM on a normal laptop.
* If one file fails to load, the script skips it and keeps going instead of stopping the whole process.

Once this runs, the database is ready and everything else is done in SQL.

## Q2: Where does shipping cost hurt margins the most?

**SQL:** [Q2.sql](./Q2.sql)

### Cleaning the data (Step 1–2 in Q2.sql)

Before writing the real query, checked how trustworthy the data actually was. Found three things worth flagging:

- **2,965 orders have no delivery date at all** — excluded from the analysis, since there's no way to know yet if they'll go through.
- **Only 96,478 of 99,441 orders are actually marked "delivered."** The rest sit in other statuses like canceled or still shipping.
- **8 orders contradict themselves** — status says delivered, but there's no delivery date attached.

Prices, shipping fees, and duplicate order IDs all came back clean, no issues there.

Based on this, the view (Step 3) filters on two conditions together: status must be `delivered`, and the delivery date can't be missing.

### Picking which states to trust (Step 4–5 in Q2.sql)

Looking at all 27 states unfiltered, a problem showed up fast: **states with very few orders had wildly swinging percentages.** RR had only 41 orders but a shipping cost of 28% of revenue, while SP had 40,494 orders and sat at a steady 13.85%.

Worked through the right cutoff in a few steps:

- Tried the common rule of n ≥ 30 first — but it didn't cut anything out. Even RR, the smallest state, had 41 orders.
- Grouped states by order count and checked how wide the percentages swung within each group. Things settle down once a state passes roughly 1,000–2,000 orders.
- Checked how much of the business gets lost at each cutoff: 1,000 orders drops 6.53% of orders and 8.52% of revenue — a reasonable trade. 2,000 orders (more statistically solid) would drop nearly 16% of revenue — too much just for cleaner numbers.

Landed on **1,000 orders** as the threshold, balancing trust in the statistics against not throwing away too much of the overall picture. The final query (Step 6) uses this cutoff and leaves 14 of the 27 states.

### Chart: Shipping cost burden by state

![Q2-1](./Q2-1.png)

Among the 14 states with 1,000+ orders, shipping eats between 13.9% (SP) and 22.7% (PE) of revenue — almost a 9-point gap. PE and CE, both in Brazil's northeast, likely sit farther from the main distribution hub, which drives up their shipping costs. SP, probably home to the main warehouse, carries the lowest shipping burden of the group.

Marketing should lean into SP, DF, and RJ first, since they keep more margin per order. Operations should look at a secondary warehouse near Brazil's northeast to shorten the delivery distance to PE and CE.

**What ruled out the other explanations** (full queries in Step 7 of Q2.sql):
- Average product weight is nearly identical across PE, CE, and SP — heavier packages aren't the cause.
- Average product price in PE and CE is actually higher than SP's, not lower — cheap products aren't skewing the ratio either.
- All three states buy from SP-based sellers at a similar rate (71–78% of orders) — it's not about relying on out-of-state sellers more.
- What's left is plain distance: PE and CE sit roughly 2,000+ km from SP, where most sellers are based.

*Shows only states with 1,000+ orders (14 of 27). The rest were excluded — too few orders to draw a reliable pattern from.*
