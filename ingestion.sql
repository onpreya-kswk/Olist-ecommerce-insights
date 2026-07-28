--------------------------------------------------------------------
-- STEP 0: Create the tables (safe to re-run anytime)
--------------------------------------------------------------------
-- This script only creates the schema -- it does NOT load data.
-- Postgres runs inside Docker in this setup, so server-side COPY
-- can't reach CSV files sitting on the local Windows machine (tried
-- \copy -- psql-only, fails in DBeaver; tried COPY -- "could not
-- open file", since the file lives outside the container). Loading
-- data is done manually per table via DBeaver's Import Data wizard
-- (Database Navigator -> right-click table -> Import Data -> CSV),
-- with encoding set to LATIN1 on each one. See the README for the
-- full walkthrough.

-- 1) Drop views first -- they depend on the tables below, so they
--    must go before any DROP TABLE can succeed. Add new views here
--    as soon as they're created, before the DROP TABLE block, or
--    re-running this script will fail the same way "products already
--    exists" failed before. View_Q4 is listed ahead of time since
--    it's the next one planned -- remove this line if Q4 ends up
--    not needing a view.
DROP VIEW IF EXISTS View_Q2 CASCADE;
DROP VIEW IF EXISTS View_Q3 CASCADE;
DROP VIEW IF EXISTS View_Q4 CASCADE;

-- 2) Now it's safe to drop the tables themselves. Dropped one per
--    line (rather than one combined DROP TABLE ... list) so a failure
--    on any single table is easy to spot.
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS reviews CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS product_category_translation CASCADE;

-- 3) Recreate every table fresh, with columns typed explicitly.
-- NOTE: customers, orders, reviews, and sellers below follow the
-- standard Olist Brazilian E-Commerce dataset column names. Run
--   SELECT table_name, column_name, data_type FROM information_schema.columns
--   WHERE table_name IN ('customers','orders','reviews','sellers')
-- against your own database first and adjust these definitions if
-- anything doesn't match.

CREATE TABLE customers (
    customer_id                TEXT,
    customer_unique_id         TEXT,
    customer_zip_code_prefix   TEXT,
    customer_city              TEXT,
    customer_state             TEXT
);

CREATE TABLE orders (
    order_id                        TEXT,
    customer_id                     TEXT,
    order_status                    TEXT,
    order_purchase_timestamp        TIMESTAMP,
    order_approved_at               TIMESTAMP,
    order_delivered_carrier_date    TIMESTAMP,
    order_delivered_customer_date   TIMESTAMP,
    order_estimated_delivery_date   TIMESTAMP
);

CREATE TABLE order_items (
    order_id             TEXT,
    order_item_id        BIGINT,
    product_id           TEXT,
    seller_id            TEXT,
    shipping_limit_date  TEXT,
    price                DOUBLE PRECISION,
    freight_value        DOUBLE PRECISION
);

CREATE TABLE payments (
    order_id              TEXT,
    payment_sequential    BIGINT,
    payment_type          TEXT,
    payment_installments  BIGINT,
    payment_value         DOUBLE PRECISION
);

CREATE TABLE reviews (
    review_id                 TEXT,
    order_id                  TEXT,
    review_score              INT,
    review_comment_title      TEXT,
    review_comment_message    TEXT,
    review_creation_date      TIMESTAMP,
    review_answer_timestamp   TIMESTAMP
);

CREATE TABLE products (
    product_id                  TEXT,
    product_category_name       TEXT,
    product_name_lenght         DOUBLE PRECISION,
    product_description_lenght  DOUBLE PRECISION,
    product_photos_qty          DOUBLE PRECISION,
    product_weight_g            DOUBLE PRECISION,
    product_length_cm           DOUBLE PRECISION,
    product_height_cm           DOUBLE PRECISION,
    product_width_cm            DOUBLE PRECISION
);

CREATE TABLE sellers (
    seller_id               TEXT,
    seller_zip_code_prefix  TEXT,
    seller_city             TEXT,
    seller_state            TEXT
);

CREATE TABLE product_category_translation (
    product_category_name          TEXT,
    product_category_name_english  TEXT
);

-- 4) This script only creates the table structure. Data is loaded
-- separately through DBeaver's normal Import Data feature: for each
-- of the 8 tables, right-click the table in Database Navigator ->
-- Import Data -> source format CSV -> pick the matching file -> set
-- Encoding to LATIN1 on the extraction settings page -> Proceed.
-- Repeat for all 8 tables:
--   customers, orders, order_items, payments, reviews, products,
--   sellers, product_category_translation
