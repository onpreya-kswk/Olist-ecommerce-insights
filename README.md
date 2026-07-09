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
