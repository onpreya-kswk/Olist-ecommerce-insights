import pandas as pd
from sqlalchemy import create_engine, text

# Base setup - change the password and DB name to match your machine
DATABASE_URL = "postgresql://postgres:your_password@localhost:5432/postgres"
engine = create_engine(DATABASE_URL)

FOLDER_PATH = "C:/EX_TRF/5_Project/2_Olist Brazilian E-Commerce Dataset"

files = {
    'customers': f"{FOLDER_PATH}/olist_customers_dataset.csv",
    'orders': f"{FOLDER_PATH}/olist_orders_dataset.csv",
    'order_items': f"{FOLDER_PATH}/olist_order_items_dataset.csv",
    'payments': f"{FOLDER_PATH}/olist_order_payments_dataset.csv",
    'reviews': f"{FOLDER_PATH}/olist_order_reviews_dataset.csv",
    'products': f"{FOLDER_PATH}/olist_products_dataset.csv",
    'sellers': f"{FOLDER_PATH}/olist_sellers_dataset.csv",
    'product_category_translation': f"{FOLDER_PATH}/product_category_name_translation.csv"
}

print("Starting isolated data ingestion...")

# Clear out any old Views first, otherwise Postgres locks down the main tables and blocks drops
# เคลียร์ทางล่วงหน้า: ลบพวก View เก่าๆ ทิ้งไปก่อน ไม่งั้น Postgres จะล็อกไม่ยอมให้ลบตารางหลัก
with engine.connect() as clear_conn:
    clear_conn.execute(text("DROP VIEW IF EXISTS v_clean_orders_q2 CASCADE;"))
    clear_conn.execute(text("DROP VIEW IF EXISTS v_clean_products_q3 CASCADE;"))
    clear_conn.execute(text("DROP VIEW IF EXISTS v_scatter_q3 CASCADE;"))
    clear_conn.execute(text("DROP VIEW IF EXISTS v_clean_reviews_q4 CASCADE;"))
    clear_conn.commit()

# Use engine.connect() so each table processes on its own without causing a domino crash effect
with engine.connect() as conn:
    for table_name, full_file_path in files.items():
        try:
            # Rename translation table columns right away to keep them consistent with products data
            if table_name == 'product_category_translation':
                df_temp = pd.read_csv(
                    full_file_path,
                    encoding='latin1',
                    header=0,
                    names=['product_category_name', 'product_category_name_english']
                )
            else:
                df_temp = pd.read_csv(full_file_path, encoding='latin1', parse_dates=True)

            # Upload data to SQL in 10k row steps to save local machine RAM
            df_temp.to_sql(
                name=table_name,
                con=conn,
                if_exists='replace',
                index=False,
                chunksize=10000
            )
            conn.commit()  # Save table changes immediately if the current loop passes
            print(f" ✅ Complete: Imported '{table_name}'")

        except Exception as e:
            # Print table error logs and rollback the failed item so the rest can keep going
            print(f" ❌ Error with '{table_name}': {e}")
            conn.rollback()

print("\n✅ All tables finished processing!")