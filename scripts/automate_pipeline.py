import subprocess
import os
import argparse

# --- Configuration ---
DATABASE_NAME = "saas_analytics.db"
# Assume this script is in a 'scripts' subdirectory of the project root.
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SQL_DIR = os.path.join(PROJECT_ROOT, "sql")
# DATA_DIR is where regenerated data (e.g., CSVs) might be placed.
# schema.sql would then typically use .import commands to load from this directory
# or a subdirectory within SQL_DIR. For simplicity, we assume schema.sql knows where to find its data files.
# Example: DATA_DIR = os.path.join(PROJECT_ROOT, "data_files_for_import") 
SCHEMA_FILE = os.path.join(SQL_DIR, "schema.sql")
CREATE_VIEWS_FILE = os.path.join(SQL_DIR, "create_views.sql")
DB_PATH = os.path.join(PROJECT_ROOT, DATABASE_NAME)

# --- Helper Functions ---
def get_db_path():
    """Returns the absolute path to the SQLite database."""
    return os.path.abspath(DB_PATH)

def execute_sqlite_script(sql_file_path):
    """Executes an SQL script against the SQLite database."""
    db_path = get_db_path()
    abs_sql_file_path = os.path.abspath(sql_file_path)
    
    if not os.path.exists(abs_sql_file_path):
        print(f"Error: SQL script file not found at {abs_sql_file_path}")
        return False

    print(f"Executing SQL script: {abs_sql_file_path} on database: {db_path}")
    try:
        with open(abs_sql_file_path, 'r') as f:
            sql_script_content = f.read()

        process = subprocess.run(
            f'sqlite3 "{db_path}"',
            input=sql_script_content,
            text=True,
            capture_output=True,
            check=False, 
            shell=True 
        )
        
        if process.returncode == 0:
            print(f"Successfully executed {os.path.basename(abs_sql_file_path)}.")
            if process.stdout.strip():
                print(f"Stdout:\\n{process.stdout.strip()}")
            return True
        else:
            print(f"Error executing {os.path.basename(abs_sql_file_path)}:")
            print(f"Return Code: {process.returncode}")
            if process.stdout.strip():
                print(f"Stdout:\\n{process.stdout.strip()}")
            if process.stderr.strip():
                print(f"Stderr:\\n{process.stderr.strip()}")
            return False
    except FileNotFoundError: # This specific error is for 'sqlite3' command itself
        print(f"Error: sqlite3 command not found. Ensure SQLite3 is installed and in your system PATH.")
        return False
    except Exception as e:
        print(f"An unexpected error occurred while executing {os.path.basename(abs_sql_file_path)}: {e}")
        return False

def test_sqlite3_connection():
    """Tests if sqlite3 command is accessible."""
    print("Testing SQLite3 accessibility...")
    try:
        process = subprocess.run(
            "sqlite3 --version", # Simple command to check
            text=True,
            capture_output=True,
            check=True, # Expect success
            shell=True
        )
        print(f"SQLite3 version: {process.stdout.strip()}")
        return True
    except FileNotFoundError:
        print("Error: sqlite3 command not found. Please ensure SQLite3 is installed and its directory is in your system PATH.")
        return False
    except subprocess.CalledProcessError as e:
        print(f"Error executing 'sqlite3 --version'. Is SQLite3 installed and in PATH?")
        if e.stdout: print(f"Stdout: {e.stdout}")
        if e.stderr: print(f"Stderr: {e.stderr}")
        return False
    except Exception as e:
        print(f"An unexpected error occurred while testing sqlite3: {e}")
        return False

# --- Pipeline Steps ---
def regenerate_source_data(force_regeneration=False):
    """
    Placeholder function to regenerate source data (e.g., CSV files).
    This function should implement the actual data generation logic.
    The generated data files should be placed where schema.sql expects them for .import commands.
    """
    print("Step 1: Regenerating source data...")
    if force_regeneration:
        print("Forcing data regeneration.")
    # Actual data regeneration logic would go here.
    # For example, running another script:
    # data_gen_script = os.path.join(PROJECT_ROOT, "scripts", "generate_csv_data.py")
    # if os.path.exists(data_gen_script):
    #     print(f"Running data generation script: {data_gen_script}")
    #     subprocess.run(["python", data_gen_script, "--output-dir", SQL_DIR], check=True) # Or wherever schema expects it
    # else:
    # print(f"Data generation script {data_gen_script} not found.")
    print("Data regeneration step completed (Placeholder - implement actual logic).")
    return True # Assume success for placeholder

def initialize_database():
    """
    Initializes the database: deletes the old one if it exists,
    then loads the schema and any initial data via schema.sql.
    """
    print("Step 2: Initializing database...")
    db_path = get_db_path()
    if os.path.exists(db_path):
        try:
            os.remove(db_path)
            print(f"Removed existing database: {db_path}")
        except OSError as e:
            print(f"Error removing existing database {db_path}: {e}")
            return False
    
    print(f"Creating new database and loading schema/data from: {SCHEMA_FILE}")
    if not execute_sqlite_script(SCHEMA_FILE):
        print("Failed to load schema and initial data. Check schema.sql and its data import paths.")
        return False
    
    print("Database initialized successfully.")
    return True

def refresh_database_views():
    """Creates or refreshes database views using create_views.sql."""
    print("Step 3: Refreshing database views...")
    if not execute_sqlite_script(CREATE_VIEWS_FILE):
        print("Failed to create/refresh database views.")
        return False
    print("Database views refreshed successfully.")
    return True

def trigger_dashboard_update():
    """Placeholder function to trigger a dashboard update (e.g., Tableau, Streamlit refresh)."""
    print("Step 4: Triggering dashboard update (Placeholder)...")
    # Example implementation:
    # import requests
    # DASHBOARD_HOOK_URL = "YOUR_DASHBOARD_API_OR_WEBHOOK_URL"
    # try:
    #     print(f"Sending trigger to dashboard hook: {DASHBOARD_HOOK_URL}")
    #     response = requests.post(DASHBOARD_HOOK_URL, timeout=10)
    #     response.raise_for_status() # Raises HTTPError for bad responses (4XX or 5XX)
    #     print("Dashboard update successfully triggered.")
    # except requests.exceptions.RequestException as e:
    #     print(f"Failed to trigger dashboard update: {e}")
    #     return False # Or handle as non-critical
    print("Dashboard update step completed (Placeholder - implement actual logic).")
    return True

def send_summary_email():
    """Placeholder function to send a summary email."""
    print("Step 5: Sending summary email (Placeholder)...")
    # Example implementation:
    # import smtplib
    # from email.mime.text import MIMEText
    # SENDER = "pipeline@example.com"
    # RECEIVERS = ["user@example.com"]
    # subject = "SaaS Analytics Pipeline: Data Refresh Complete"
    # body = "The data pipeline has successfully regenerated data, reloaded the database, and refreshed views."
    # msg = MIMEText(body)
    # msg['Subject'] = subject
    # msg['From'] = SENDER
    # msg['To'] = ', '.join(RECEIVERS)
    # try:
    #     with smtplib.SMTP('localhost') as smtp: # Or your actual SMTP server
    #         smtp.send_message(msg)
    #     print("Summary email sent successfully.")
    # except Exception as e:
    #     print(f"Failed to send summary email: {e}")
    #     return False # Or handle as non-critical
    print("Email summary step completed (Placeholder - implement actual logic).")
    return True

# --- Main Pipeline Orchestration ---
def run_pipeline(args):
    """Main function to orchestrate the data pipeline."""
    print("--- Starting SaaS Analytics Data Refresh Pipeline ---")
    print(f"Project Root: {PROJECT_ROOT}")
    print(f"SQL Directory: {SQL_DIR}")
    print(f"Database Path: {DB_PATH}")
    print(f"Schema File: {SCHEMA_FILE}")
    print(f"Views File: {CREATE_VIEWS_FILE}")
    print("---")

    if not test_sqlite3_connection():
        print("Critical: SQLite3 is not accessible. Aborting pipeline.")
        return False

    if not os.path.exists(SCHEMA_FILE):
        print(f"Critical Error: Schema file not found at '{SCHEMA_FILE}'. Aborting.")
        return False
    if not os.path.exists(CREATE_VIEWS_FILE):
        print(f"Critical Error: Views file not found at '{CREATE_VIEWS_FILE}'. Aborting.")
        return False

    if not regenerate_source_data(force_regeneration=args.force_regenerate):
        print("Pipeline halted: Failed to regenerate source data.")
        return False

    if not initialize_database():
        print("Pipeline halted: Failed to initialize the database.")
        return False

    if not refresh_database_views():
        print("Pipeline halted: Failed to refresh database views.")
        return False

    if not args.skip_dashboard:
        if not trigger_dashboard_update():
            print("Warning: Failed to trigger dashboard update. Continuing...")
            # Depending on criticality, you might 'return False' here
    else:
        print("Skipped: Dashboard update trigger.")

    if not args.skip_email:
        if not send_summary_email():
            print("Warning: Failed to send summary email. Continuing...")
    else:
        print("Skipped: Summary email.")

    print("--- SaaS Analytics Data Refresh Pipeline completed successfully! ---")
    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Automated SaaS Analytics Data Refresh Pipeline. "
                    "Regenerates data, reloads SQLite DB, refreshes views, "
                    "and optionally triggers dashboard/email notifications."
    )
    parser.add_argument(
        "--force-regenerate",
        action="store_true",
        help="Force regeneration of source data (behavior depends on placeholder implementation)."
    )
    parser.add_argument(
        "--skip-dashboard",
        action="store_true",
        help="Skip the (placeholder) dashboard update step."
    )
    parser.add_argument(
        "--skip-email",
        action="store_true",
        help="Skip the (placeholder) summary email step."
    )
    
    pipeline_args = parser.parse_args()
    
    if not run_pipeline(pipeline_args):
        print("--- Pipeline execution failed. ---")
        exit(1)
    else:
        exit(0)
