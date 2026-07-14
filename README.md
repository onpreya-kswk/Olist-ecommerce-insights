# Olist-ecommerce-insights
Analysis of Olist E-Commerce using PostgreSQL and Python to optimize marketing, payment strategy, and delivery performance

## Data Ingestion

This step moves the raw data from local CSV files into a PostgreSQL database using Python. It sets up a proper relational structure so we can run SQL queries smoothly.

The complete setup logic is handled by the Python script included in this repository.

### Key Details
* **Source to Destination:** Loads raw local CSV files directly into a local PostgreSQL database.
* **Text Fixing:** Uses `encoding='latin1'` to stop the script from crashing on Portuguese special characters.
* **Auto Dates:** Uses `parse_dates=True` so Pandas fixes all date text formats into proper timestamps automatically.
* **RAM Saving:** Pushes data in chunks of 10,000 rows to keep memory usage low and prevent system freezes.

## Q2: Target Market & Shipping Profitability (Before Buying)

**SQL:** [Q2.sql](./Q2.sql)

* **Step 2.1: Checking Raw Data** – Looked at the `customers` and `order_items` tables to see how the state locations, product prices, and shipping fees look.
* **Step 2.2: Cleaning the Tables** – Created a safe SQL View called `v_clean_orders_q2`. This removes canceled orders and fixes date formats so the calculations stay accurate.
* **Step 2.3: Final Query** – Joined the cleaned tables together. Grouped everything by state to calculate the total product sales, shipping costs, and the final `shipping_to_revenue_pct` numbers.

![Q2-3_1](./Q2-3_1.png)

* **Key Insight:** Shipping cost varies a lot across Brazil. **SP (São Paulo)** has the lowest shipping burden at only **13.85%**. On the other hand, remote states like **RR** and **MA** are the most expensive, with shipping taking up over **26% to 28%** of the product price.
* **Business Action:** SP is the safest and cheapest area to run marketing ads and big discount promotions because shipping won't eat into our profits.

![Q2-3_2](./Q2-3_2.png)

* **Key Insight:** The chart shows that our highest-selling states are actually the ones with the lowest shipping costs. The big revenue peak on the left belongs to SP, which combines high sales volumes with very low delivery overhead.
* **Business Action:** We shouldn't treat every high-revenue state the same way. If a state has decent sales but the shipping line sits high up, we need to bundle products together to increase the average order size and offset the delivery fee.

![Q2-3_3](./Q2-3_3.png)

* **Key Insight:** There is a clear, tight link between total orders and total revenue. The dots follow a steady upward line, meaning our sales growth depends heavily on order volume rather than just a few expensive items. The darker red dots (high shipping burden) mostly sit at the lower end of the order volume.
* **Business Action:** To push the business forward, we need to focus on getting more order numbers in low-shipping regions (light-colored dots) while slowly building up warehouse hubs near the high-shipping regions to lower their costs.

## Q3: Category Installment Behaviors (During Checkout)

**SQL:** [Q3.sql](./Q3.sql)

* **Step 3.1: Checking Raw Data** – Looked at the `payments` and `products` tables to see how payment installment months are recorded and checked the native Portuguese category names.
* **Step 3.2: Cleaning the Tables** – Updated the Python setup script to match the raw schema types. Created a clean database connection that sets up English headers and handles missing category nulls as 'unknown' to avoid blank charts.
* **Step 3.3: Final Query** – Joined the payments and cleaned product assets together in DBeaver. Filtered exclusively for `credit_card` logs to calculate `total_credit_card_orders` and the final `avg_payment_installments` numbers.

![Q3-3_1](./Q3-3_1.png)

* **Key Insight:** Customers heavily rely on payment flexibility for high-value items. **Computers** lead the entire platform with the longest installment plan, averaging **nearly 7 months**. Other expensive categories like **small_appliances** and **office_furniture** also show a high installment burden, averaging around **5 to 6 months**.
* **Business Action:** The business must protect and prioritize long-term "0% interest" partnership deals with banks for the tech and furniture sectors. Removing these long installment plans will directly kill our sales volumes for high-ticket items.

![Q3-3_2](./Q3-3_2.png)

* **Key Insight:** Sorting by financing duration clearly proves that tech and heavy machinery dominate long-term credit. **Computers** lead the charts at nearly 7 installment months, followed closely by appliances and furniture. However, daily volume is driven by fast-moving items in the middle—like **bed_bath_table** and **health_beauty**—which have massive order counts (tall orange bars) but stay on shorter 4-month repayment cycles.
* **Business Action:** Financial promo budgets should focus on safeguarding 0% interest programs exclusively for high-ticket electronics (the left side of the chart) to protect cart conversions. For high-volume daily items, marketing should shift budgets toward instant cashbacks to nudge customers away from credit cards and toward low-fee payment alternatives like Pix.

![Q3-3_3](./Q3-3_3.png)

* **Key Insight:** The scatter plot charts a clear positive connection between order transaction size and installment months. High-ticket tech assets gather in the top-right zone, signaling strict dependency on monthly financing to clear inventory. Low-value impulse categories stay clustered in the bottom-left.
* **Business Action:** For categories pinned in the top-right sector, extended financing terms are a non-negotiable sales driver. For clusters on the lower-left with small pricing weights, operations should incentivize cross-category bundling at checkout to bump up total cart values before unlocking monthly installment perks.


