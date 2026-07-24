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

Landed on **1,000 orders** as the threshold, balancing trust in the statistics against not throwing away too much of the overall picture. The final query (Step 6) uses this cutoff and leaves 12 of the 27 states.

### Chart: Shipping cost burden by state

![Q2-1](./Q2-1.png)

Among the 12 states with 1,000+ orders, shipping eats between 13.9% (SP) and 22.7% (PE) of revenue — almost a 9-point gap. PE and CE, both in Brazil's northeast, likely sit farther from the main distribution hub, which drives up their shipping costs. SP, probably home to the main warehouse, carries the lowest shipping burden of the group.

Marketing should lean into SP, DF, and RJ first, since they keep more margin per order. Operations should look at a secondary warehouse near Brazil's northeast to shorten the delivery distance to PE and CE.

**What ruled out the other explanations** (full queries in Step 7 of Q2.sql):
- Average product weight is nearly identical across PE, CE, and SP — heavier packages aren't the cause.
- Average product price in PE and CE is actually higher than SP's, not lower — cheap products aren't skewing the ratio either.
- All three states buy from SP-based sellers at a similar rate (71–78% of orders) — it's not about relying on out-of-state sellers more.
- What's left is plain distance: PE and CE sit roughly 2,000+ km from SP, where most sellers are based.

*Shows only states with 1,000+ orders. The rest were excluded — too few orders to draw a reliable pattern from.*

### Chart 2: Revenue vs shipping cost burden by state

![Q2-2](./Q2-2.png)

Revenue bars drop off fast, from SP (~5M) down to CE (under 250K), while 
the shipping percentage line runs roughly the opposite direction, climbing 
from 13.85% at SP up to a peak of 22.66% at PE. Checked whether order 
count and revenue actually track each other — they do, ranking identically 
across all 12 states. The one clear break in the pattern is DF, whose 
shipping percentage sits lower than states with similar revenue 
(16.74% vs BA's 19.76%).

Likely because DF, Brazil's capital, has unusually good transport 
infrastructure even though it isn't an economic hub like SP. This backs 
up prioritizing ad spend on SP, RJ, and MG, and suggests DF's setup is 
worth digging into further — there may be something to apply to the 
mid-table states (GO, ES, BA).

**Supporting evidence** (full queries in Step 8 of Q2.sql):
- DF's average freight per item (21.07) is genuinely lower than GO 
  (22.56), ES (22.03), and BA (26.49) — not a rounding coincidence.
- Order count and revenue rank identically across all 12 states — this 
  chart reflects both at once, not two separate stories.
- Side note: CE's average revenue per order (~172) runs almost 40% 
  higher than SP's (~125), despite far fewer orders — possibly because 
  distant-state customers bundle more into each order to offset 
  shipping cost.

### Chart 3: More orders means more revenue and lower shipping cost — the pattern holds across all 12 states

![Q2-3](./Q2-3.png)

Every point lines up along a clear diagonal on the log-log scale, 
confirming that order count and revenue move together almost 1:1 
(matches what Chart 2 showed). SP sits at the top right, the darkest 
green point — highest orders, highest revenue, lowest shipping cost. 
CE sits at the bottom left, colored red — lowest on every count.

The color gradient running from top-right to bottom-left lines up with 
the cause already confirmed in Step 7: distance from the distribution 
hub. This backs up giving SP top priority, since it wins on all three 
fronts at once. States like CE and BA should be operations' first 
focus, since they carry both a small customer base and high shipping 
cost at the same time.

*No outliers here, so there's nothing extra to dig into like there was 
for Charts 1 and 2.*

Q3: Which product category relies most on installment payments?

SQL: Q3.sql

Cleaning the data (Step 1–2 in Q3.sql)

Before writing the real query, checked how trustworthy the payment and product data actually was. Found two things worth flagging:

610 of 32,951 products have no category name — these touch 1,451 orders, just 1.5% of all orders. Small enough to drop; a category labeled "unknown" carries no weight in a bank installment negotiation anyway.
290 orders were charged on credit_card more than once — split across two cards on the same purchase, each with its own installment plan (e.g. one card at 4 months, one at 6). Checked these weren't accidental duplicate rows first: every one of the 290 has genuinely different installment values attached, confirming they're real parallel transactions.

Payment type nulls and duplicate order_id checks elsewhere came back clean, no issues there.

Based on this, the two decisions baked into the cleaned view (Step 2) are: drop products with no category, and collapse each of those 290 split-payment orders down to one row using MAX(payment_installments) — two cards running in parallel finish when the longer plan finishes, not when both are added together, so MAX reflects the real commitment length and SUM would have overstated it.

Picking which categories to trust (Step 3 in Q3.sql)

Looking at all 70 categories unfiltered, the same problem from Q2 showed up again: categories with very few orders swing wildly. security_and_services had exactly 1 order and an average of 1.0 installments — not a real pattern, just a single data point standing in for an entire category.

Worked through the cutoff the same way as Q2:

Tried n ≥ 30 and checked what it would cost. Only 9 of 70 categories fall below this line — la_cuisine, fashion_sport, music, cds_dvds_musicals, fashion_childrens_clothes, arts_and_craftmanship, home_comfort_2, flowers, and security_and_services — together making up roughly 0.16% of all order-category rows in the analysis.
Unlike Q2, where reaching a trustworthy sample size meant giving up a real chunk of revenue (8.52% at the 1,000-order cutoff), this trade-off cost next to nothing — the categories getting dropped genuinely have too few orders to say anything about, and dropping them barely moves the dataset.

Landed on n ≥ 30 as the threshold. The final query (Step 5) uses this cutoff and keeps 61 of the 70 categories.

Chart: Average installments by category

(insert chart here — top categories by avg_installment, n ≥ 30)

Among the 61 categories with 30+ orders, average installments range from 7.4 months (computers) down to roughly 2.1 months (electronics) — a gap of more than 5 months between the longest and shortest financing behavior. The categories clustered at the top — computers (7.4), small_appliances_home_oven_and_coffee (6.4), home_appliances_2 (5.5), and office_furniture (5.2, backed by 1,185 orders) — are all big-ticket, long-life purchases. The categories at the bottom — electronics (2.1), home_appliances (2.2), drinks (2.2) — are lower-cost or consumable, so there's little reason to spread the cost.

Marketing and finance teams should prioritize 0%-interest bank deals around computers, office_furniture, home_confort, and furniture_living_room first, since these combine both a long average financing window and enough order volume (particularly office_furniture, at nearly 1,200 orders) that a financing deal protects real revenue rather than a handful of outlier sales.

What's left to check before trusting "category" as the driver

One open question this analysis hasn't ruled out yet: is this really about category, or is it just "expensive items get financed longer" showing up wearing a category label? Step 4 in Q3.sql sets up a query comparing avg_installment against avg_price per category — if the ranking by installment doesn't line up cleanly with the ranking by price, that confirms category carries information beyond just cost. That comparison is queued up as the next step before finalizing this section the way Q2 ruled out weight, price, and seller location as explanations for shipping cost.
