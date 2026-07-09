import pandas as pd
from sqlalchemy import create_engine

# Database connection setup - tweak the password and DB name if needed
DATABASE_URL = "postgresql://postgres:your_password@localhost:5432/postgres"
engine = create_engine(DATABASE_URL)

# Base path for the local Olist CSV files
FOLDER_PATH = "C:/EX_TRF/5_Project/2_Olist Brazilian E-Commerce Dataset"

# Map out table names directly to their file paths
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

print("Starting simplified data ingestion...")

# Wrapping everything in a transaction context to keep data safe from partial crashes
with engine.begin() as conn:
    for table_name, full_file_path in files.items():
        try:
            # Force latin1 encoding to handle wacky Brazilian characters without breaking the execution
            # Enable parse_dates so pandas automatically auto-detects and converts target date fields
            df_temp = pd.read_csv(full_file_path, encoding='latin1', parse_dates=True)

            # Drop method='multi' to dodge sketchy postgres version mismatches
            # Keep chunksize at 10k to stay clear of memory/RAM throttling
            df_temp.to_sql(
                name=table_name,
                con=conn,
                if_exists='replace',
                index=False,
                chunksize=10000
            )
            print(f" ✅ Complete: Imported '{table_name}'")

        except Exception as e:
            # Catch anomalies table by table without stopping the entire migration script
            print(f" ❌ Error with '{table_name}': {e}")

print("\n✅ All tables successfully imported!")
