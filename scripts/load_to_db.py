import sqlite3
import pandas as pd

def load_table_to_sqlite(csv_path, table_name, db_path='data/sqlite/saas.db'):
    df = pd.read_csv(csv_path)
    conn = sqlite3.connect(db_path)
    df.to_sql(table_name, conn, if_exists='replace', index=False)
    conn.close()

if __name__ == "__main__":
    load_table_to_sqlite("data/raw/customers.csv", "customers")
