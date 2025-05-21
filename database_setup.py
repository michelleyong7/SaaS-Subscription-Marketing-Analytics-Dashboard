import sqlite3
import os

DB_DIR = "data/sqlite"
DB_NAME = "saas_subscriptions.db"
DB_PATH = os.path.join(DB_DIR, DB_NAME)

def create_database_schema():
    """Creates the database schema for the SaaS Subscriptions Analytics project."""
    os.makedirs(DB_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Drop existing tables to ensure a fresh schema (idempotent)
    tables_to_drop = [
        'subscriptions', 
        'customers', 
        'marketing_campaigns', 
        'plans'
    ]
    for table_name in tables_to_drop:
        cursor.execute(f'DROP TABLE IF EXISTS {table_name};')
    conn.commit()

    # Table: plans
    # Stores information about different subscription plans.
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,            -- e.g., 'Basic', 'Pro', 'Enterprise'
        price_monthly REAL NOT NULL,   -- Monthly price for this plan
        features TEXT                  -- Description of features included
    );
    ''')

    # Table: marketing_campaigns
    # Stores information about marketing campaigns.
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS marketing_campaigns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,        -- Format: 'YYYY-MM-DD'
        end_date TEXT,                   -- Format: 'YYYY-MM-DD', NULL if ongoing
        budget REAL NOT NULL,            -- Total campaign budget
        channel TEXT NOT NULL            -- e.g., 'Social Media', 'Email', 'PPC'
    );
    ''')

    # Table: customers
    # Stores information about individual customers.
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE,
        registration_date TEXT NOT NULL,  -- Format: 'YYYY-MM-DD'
        marketing_campaign_id INTEGER,    -- Which campaign brought this customer (can be NULL)
        FOREIGN KEY (marketing_campaign_id) REFERENCES marketing_campaigns (id)
    );
    ''')

    # Table: subscriptions
    # Core table tracking the lifecycle of each customer subscription to a plan.
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS subscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        plan_id INTEGER NOT NULL,
        start_date TEXT NOT NULL,         -- Format: 'YYYY-MM-DD'
        end_date TEXT,                    -- Format: 'YYYY-MM-DD', NULL if currently active
        status TEXT NOT NULL,             -- 'active', 'canceled', 'upgraded', 'downgraded'
        prev_plan_id INTEGER,             -- Previous plan ID for upgrades/downgrades
        FOREIGN KEY (customer_id) REFERENCES customers (id),
        FOREIGN KEY (plan_id) REFERENCES plans (id),
        FOREIGN KEY (prev_plan_id) REFERENCES plans (id)
    );
    ''')

    conn.commit()
    conn.close()
    print(f"Database schema for '{DB_NAME}' created/re-created successfully at '{DB_PATH}'.")

if __name__ == '__main__':
    create_database_schema() 