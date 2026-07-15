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

## Q2: Where Should Marketing Spend Go? (Before the Sale)

**SQL:** [Q2.sql](./Q2.sql)

* **2.1 — Looked at the raw tables first.** Checked how state codes are stored in `customers` and how prices/shipping fees look in `order_items`, before writing anything else.
* **2.2 — Cleaned it up.** Built a view called `v_clean_orders_q2` that only keeps orders marked as delivered, and fixes the date columns so later math doesn't break.
* **2.3 — Ran the numbers.** Joined the tables, grouped by state, and worked out total sales, total shipping cost, and shipping cost as a percentage of revenue for each state.

![Q2-3_1](./Q2-3_1.png)

* **What I found:** Shipping cost eats a very different chunk of revenue depending on the state. **São Paulo (SP)** is the cheapest to ship to — only **13.85%** of the sale price. Remote states like **RR** and **MA** are the opposite, with shipping running **26–28%** of the sale price.
* **What this means:** SP is the safest place to spend marketing money and run discounts, since shipping won't quietly eat the margin.

![Q2-3_2](./Q2-3_2.png)

* **What I found:** The states with the most sales are also the ones with the lowest shipping cost. SP shows up again here — high volume and low delivery overhead at the same time.
* **What this means:** Not every high-revenue state should get the same treatment. If a state sells well but shipping cost is high, the fix is probably to get people to order more per basket (bundles, free-shipping thresholds) rather than just running more ads there.

![Q2-3_3](./Q2-3_3.png)

* **What I found:** Order count and revenue move together in a pretty straight line — growth here is mostly about getting more orders, not a few big-ticket sales. The states with high shipping cost (darker dots) tend to also have fewer orders.
* **What this means:** Two different plays: push order volume in the cheap-shipping states, and look at setting up local warehouses or fulfillment partners near the expensive-shipping ones over time.

## Q3: How Do People Pay for Things? (At Checkout)

**SQL:** [Q3.sql](./Q3.sql)

* **3.1 — Looked at the raw tables first.** Checked how `payment_installments` is recorded in `payments`, and noticed product categories in `products` are still in Portuguese.
* **3.2 — Cleaned it up.** Built a view (`v_clean_products_q3`) that joins in the English category names, and labels anything missing as `'unknown'` so it doesn't break the charts.
* **3.3 — Ran the numbers.** Joined payments to products, filtered to credit card payments only, and calculated the average number of installments per category.

![Q3-3_1](./Q3-3_1.png)

* **What I found:** Expensive categories get stretched out the most. **Computers** average almost **7 months** of installments — the longest on the platform. **Small appliances** and **office furniture** aren't far behind, at around **5–6 months**.
* **What this means:** Keeping 0%-interest financing deals with banks for electronics and furniture matters a lot here — these categories look like they depend on installments to sell at all. I'd want to test this before cutting installment options, since right now it's a pattern in the data, not a proven cause-and-effect.

![Q3-3_2](./Q3-3_2.png)

* **What I found:** Sorting by installment length confirms it — computers and appliances sit at the top. But the categories with the *most orders* are different: things like **bed_bath_table** and **health_beauty** sell in huge volume but only stretch to about 4 months of installments.
* **What this means:** Two different budgets, two different goals. Protect the 0%-interest deals for the expensive electronics (that's what keeps those sales alive). For the high-volume everyday items, it's probably cheaper to offer instant cashback and nudge people toward Pix instead of credit cards, since those items don't need long financing to sell.

![Q3-3_3](./Q3-3_3.png)

* **What I found:** The scatter plot shows a clear pattern — the more expensive the average order, the longer the installment plan tends to be. Expensive tech sits in the top right, cheap impulse-buy categories cluster in the bottom left.
* **What this means:** For the top-right categories, long financing terms look like a real requirement to close the sale, not just a nice-to-have. For the bottom-left categories, it's more about getting people to add a second or third item to the cart, since installments don't seem to be the deciding factor there.


