# Data Source

**Dataset name:** NYC Yellow Taxi Trip Data — 2024-01 (Yellow)

**URL / fetch instructions:**
Loadable directly via DuckDB, no download or signup required:
read_parquet('https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet')

Sample regeneration (first 1000 rows):
python: duckdb.sql("SELECT * FROM read_parquet('...') LIMIT 1000").df().to_csv('data/sample.csv', index=False)

**License:**
Public domain / NYC Open Data terms. Data is pseudonymized, not anonymized. See https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

**Approximate size:**
- Row count: ~2.96 million (January 2024 slice)
- Table count: 1 (single trip-level table)
- Columns: 19 (VendorID, pickup/dropoff timestamps, passenger_count, trip_distance, RatecodeID, PULocationID, DOLocationID, payment_type, fare/tip/tolls/tax breakdown, total_amount, congestion_surcharge, Airport_fee)

**Update frequency:**
Published monthly by NYC TLC; this project uses a fixed historical month (2024-01) for reproducibility.
