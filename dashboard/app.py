import streamlit as st
import sqlite3
import pandas as pd
import plotly.express as px
from datetime import datetime, timedelta
import os

DB_PATH = 'data/sqlite/saas_subscriptions.db'

def load_css(file_name):
    with open(file_name) as f:
        st.markdown(f'<style>{f.read()}</style>', unsafe_allow_html=True)

def ensure_db_directory():
    """Ensures that the directory for the SQLite database exists."""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)

def get_db_connection():
    """Establishes a connection to the SQLite database."""
    ensure_db_directory()
    if not os.path.exists(DB_PATH):
        st.error(f"Database file not found at {DB_PATH}. Please run the database setup and data generation scripts.")
        st.stop()
    return sqlite3.connect(DB_PATH)

@st.cache_data(ttl=600)
def fetch_data(query, params=None):
    """Fetches data from the database using a given query and parameters."""
    conn = None
    try:
        conn = get_db_connection()  # Get fresh connection each time
        df = pd.read_sql_query(query, conn, params=params)
        return df  # Return only the dataframe, not the connection
    except Exception as e:
        st.error(f"Error fetching data: {e}")
        return pd.DataFrame()
    finally:
        if conn:
            conn.close()  # Always close the connection

def get_date_range():
    """Gets the overall min and max date from subscriptions and campaigns for global filter."""
    query_subs = "SELECT MIN(start_date) as min_s, MAX(COALESCE(end_date, DATE('now'))) as max_s FROM subscriptions"
    query_campaigns = "SELECT MIN(start_date) as min_c, MAX(end_date) as max_c FROM marketing_campaigns"
    
    df_subs = fetch_data(query_subs)
    df_campaigns = fetch_data(query_campaigns)

    min_dates = []
    max_dates = []

    if not df_subs.empty and df_subs['min_s'].iloc[0]:
        min_dates.append(pd.to_datetime(df_subs['min_s'].iloc[0]))
    if not df_subs.empty and df_subs['max_s'].iloc[0]:
        max_dates.append(pd.to_datetime(df_subs['max_s'].iloc[0]))
    
    if not df_campaigns.empty and df_campaigns['min_c'].iloc[0]:
        min_dates.append(pd.to_datetime(df_campaigns['min_c'].iloc[0]))
    if not df_campaigns.empty and df_campaigns['max_c'].iloc[0]:
        max_dates.append(pd.to_datetime(df_campaigns['max_c'].iloc[0]))

    if not min_dates or not max_dates:
        # Fallback if no dates found (e.g., empty DB)
        return datetime.today() - timedelta(days=365), datetime.today()

    overall_min_date = min(min_dates)
    overall_max_date = max(max_dates)
    
    return overall_min_date, overall_max_date

# --- KPI Calculation Functions ---
def calculate_mrr_and_movements(start_date, end_date):
    """
    Calculates MRR, New MRR, Churned MRR, Expansion MRR, Contraction MRR over time.
    This is a simplified version. A more accurate calculation would track individual subscription changes.
    """
    query = """
    WITH RECURSIVE dates(date) AS (
        SELECT DATE(?) -- start_date
        UNION ALL
        SELECT DATE(date, '+1 day')
        FROM dates
        WHERE date < DATE(?) -- end_date
    ),
    subscription_daily_mrr AS (
        SELECT
            s.customer_id,
            p.price_monthly,
            s.start_date,
            COALESCE(s.end_date, DATE('now', '+100 years')) as effective_end_date, 
            s.status,
            LAG(s.plan_id, 1, NULL) OVER (PARTITION BY s.customer_id ORDER BY s.start_date) as prev_plan_id,
            LAG(p.price_monthly, 1, 0) OVER (PARTITION BY s.customer_id ORDER BY s.start_date) as prev_plan_price
        FROM subscriptions s
        JOIN plans p ON s.plan_id = p.id
    )
    SELECT
        d.date,
        SUM(CASE WHEN sdm.start_date <= d.date AND sdm.effective_end_date > d.date THEN sdm.price_monthly ELSE 0 END) as mrr,
        
        SUM(CASE 
            WHEN sdm.start_date = d.date AND sdm.prev_plan_id IS NULL -- New customer or first subscription
            THEN sdm.price_monthly ELSE 0 
            END) as new_mrr,
            
        SUM(CASE 
            WHEN sdm.effective_end_date = d.date AND sdm.status = 'canceled' -- Explicit cancellation
            THEN sdm.price_monthly ELSE 0 
            END) as churned_mrr,

        SUM(CASE 
            WHEN sdm.start_date = d.date AND sdm.prev_plan_id IS NOT NULL AND sdm.price_monthly > sdm.prev_plan_price -- Upgrade
            THEN (sdm.price_monthly - sdm.prev_plan_price) ELSE 0 
            END) as expansion_mrr,

        SUM(CASE 
            WHEN sdm.start_date = d.date AND sdm.prev_plan_id IS NOT NULL AND sdm.price_monthly < sdm.prev_plan_price -- Downgrade
            THEN (sdm.prev_plan_price - sdm.price_monthly) ELSE 0 -- Positive value for contraction amount
            END) as contraction_mrr
            
    FROM dates d
    LEFT JOIN subscription_daily_mrr sdm ON 1=1 -- Join all and filter in SUM cases, or refine join condition
    GROUP BY d.date
    ORDER BY d.date;
    """
    df = fetch_data(query, (start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')))
    if not df.empty:
        df['date'] = pd.to_datetime(df['date'])
    return df

def calculate_active_subscriptions(start_date, end_date):
    query = """
    WITH RECURSIVE dates(date) AS (
        SELECT DATE(?) -- start_date
        UNION ALL
        SELECT DATE(date, '+1 day')
        FROM dates
        WHERE date < DATE(?) -- end_date
    )
    SELECT
        d.date,
        COUNT(DISTINCT s.customer_id) as active_subscriptions
    FROM dates d
    LEFT JOIN subscriptions s ON s.start_date <= d.date AND (s.end_date IS NULL OR s.end_date > d.date) AND s.status = 'active'
    GROUP BY d.date
    ORDER BY d.date;
    """
    df = fetch_data(query, (start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')))
    if not df.empty:
        df['date'] = pd.to_datetime(df['date'])
    return df
    
def get_subscription_events(start_date, end_date):
    """Fetches new subscriptions, cancellations, upgrades, downgrades within the date range."""
    query = """
    SELECT 
        s.id,
        s.customer_id,
        c.name as customer_name,
        s.plan_id,
        p.name as plan_name,
        p.price_monthly,
        s.start_date,
        s.end_date,
        s.status,
        LAG(s.plan_id, 1, NULL) OVER (PARTITION BY s.customer_id ORDER BY s.start_date) as prev_plan_id,
        (SELECT name from plans where id = prev_plan_id) as prev_plan_name,
        LAG(p.price_monthly, 1, NULL) OVER (PARTITION BY s.customer_id ORDER BY s.start_date) as prev_price
    FROM subscriptions s
    JOIN plans p ON s.plan_id = p.id
    JOIN customers c ON s.customer_id = c.id
    WHERE s.start_date BETWEEN DATE(?) AND DATE(?) OR s.end_date BETWEEN DATE(?) AND DATE(?)
    ORDER BY s.start_date
    """
    df = fetch_data(query, (
        start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d'),
        start_date.strftime('%Y-%m-%d'), end_date.strftime('%Y-%m-%d')
    ))

    if df.empty:
        return pd.DataFrame(columns=['date', 'type', 'details', 'mrr_change'])

    df['start_date'] = pd.to_datetime(df['start_date'])
    df['end_date'] = pd.to_datetime(df['end_date'], errors='coerce')
    
    events = []

    for _, row in df.iterrows():
        # New Subscriptions
        if row['status'] == 'active' and pd.isna(row['prev_plan_id']) and row['start_date'] >= start_date and row['start_date'] <= end_date:
            events.append({
                'date': row['start_date'], 
                'type': 'New Subscription', 
                'details': f"Customer {row['customer_name']} started {row['plan_name']}",
                'mrr_change': row['price_monthly']
            })

        # Cancellations
        if row['status'] == 'canceled' and row['end_date'] is not pd.NaT and row['end_date'] >= start_date and row['end_date'] <= end_date:
            events.append({
                'date': row['end_date'], 
                'type': 'Cancellation', 
                'details': f"Customer {row['customer_name']} canceled {row['plan_name']}",
                'mrr_change': -row['price_monthly']
            })
        
        # Upgrades
        if row['status'] == 'upgraded' and row['start_date'] >= start_date and row['start_date'] <= end_date: # 'upgraded' status implies it's the start of new plan
            if row['prev_price'] is not None and row['price_monthly'] > row['prev_price']:
                 events.append({
                    'date': row['start_date'], 
                    'type': 'Upgrade', 
                    'details': f"Customer {row['customer_name']} upgraded from {row['prev_plan_name']} to {row['plan_name']}",
                    'mrr_change': row['price_monthly'] - row['prev_price']
                })

        # Downgrades
        if row['status'] == 'downgraded' and row['start_date'] >= start_date and row['start_date'] <= end_date: # 'downgraded' status implies it's the start of new plan
            if row['prev_price'] is not None and row['price_monthly'] < row['prev_price']:
                events.append({
                    'date': row['start_date'], 
                    'type': 'Downgrade', 
                    'details': f"Customer {row['customer_name']} downgraded from {row['prev_plan_name']} to {row['plan_name']}",
                    'mrr_change': row['price_monthly'] - row['prev_price'] # Negative value
                })
                
    return pd.DataFrame(events)

def get_marketing_campaign_summary(start_date, end_date):
    query = """
    SELECT 
        mc.id,
        mc.name,
        mc.start_date,
        mc.end_date,
        mc.budget,
        mc.channel,
        COUNT(DISTINCT c.id) as acquired_customers_during_campaign,
        SUM(CASE WHEN s.start_date >= mc.start_date AND (s.end_date IS NULL OR s.end_date >= mc.start_date) THEN p.price_monthly ELSE 0 END) as initial_mrr_from_acquired
    FROM marketing_campaigns mc
    LEFT JOIN customers c ON mc.id = c.marketing_campaign_id 
        AND c.registration_date BETWEEN mc.start_date AND mc.end_date -- Customer registered during campaign
    LEFT JOIN subscriptions s ON c.id = s.customer_id 
        AND s.start_date >= mc.start_date -- Subscription started during or after campaign start
        AND (s.prev_plan_id IS NULL) -- Count only initial subscription for this MRR
    LEFT JOIN plans p ON s.plan_id = p.id
    WHERE mc.start_date <= DATE(?) AND mc.end_date >= DATE(?) -- Campaigns active within the filter range
    GROUP BY mc.id, mc.name, mc.start_date, mc.end_date, mc.budget, mc.channel
    ORDER BY mc.start_date
    """
    df = fetch_data(query, (end_date.strftime('%Y-%m-%d'), start_date.strftime('%Y-%m-%d')))
    if not df.empty:
        df['start_date'] = pd.to_datetime(df['start_date'])
        df['end_date'] = pd.to_datetime(df['end_date'])
        df['cac'] = df.apply(lambda row: row['budget'] / row['acquired_customers_during_campaign'] if row['acquired_customers_during_campaign'] > 0 else 0, axis=1)
    return df

# --- Streamlit App Layout ---
st.set_page_config(layout="wide", page_title="SaaS Subscription Analytics")

# Load custom CSS
css_file_path = os.path.join(os.path.dirname(__file__), "assets", "style.css")
if os.path.exists(css_file_path):
    load_css(css_file_path)
else:
    st.warning(f"Custom CSS file not found at {css_file_path}. Using default styles.")

st.title("📊 SaaS Subscription & Marketing Analytics Dashboard")

# Check for database
ensure_db_directory()
if not os.path.exists(DB_PATH):
    st.warning(f"Database not found at {DB_PATH}. Please run `database_setup.py` and `generate_sample_data.py` first.")
    st.markdown("""### Instructions:

1. Make sure you have Python installed.
2. Install required packages: `pip install -r requirements.txt`
3. Run the database setup: `python database_setup.py`
4. Generate sample data: `python generate_sample_data.py`
5. Refresh this page.""")
    st.stop()


# --- Global Filters ---
min_db_date, max_db_date = get_date_range()

st.sidebar.header("Global Filters")
selected_start_date = st.sidebar.date_input("Start Date", min_db_date, min_value=min_db_date, max_value=max_db_date)
selected_end_date = st.sidebar.date_input("End Date", max_db_date, min_value=min_db_date, max_value=max_db_date)

# Convert to datetime objects for comparison
selected_start_date = datetime.combine(selected_start_date, datetime.min.time())
selected_end_date = datetime.combine(selected_end_date, datetime.max.time())


if selected_start_date > selected_end_date:
    st.sidebar.error("Error: End date must be after start date.")
    st.stop()

# --- Main Dashboard Sections ---
st.sidebar.header("Dashboard Sections")
display_section = st.sidebar.radio(
    "Choose a section:",
    options=['Key Metrics Overview', 'Subscription Fluctuations', 'Marketing Impact'],
    index=0 
)

# --- Key Metrics Overview ---
if display_section == 'Key Metrics Overview':
    st.header("Key Metrics Overview")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("MRR Trend & Movements")
        mrr_df = calculate_mrr_and_movements(selected_start_date, selected_end_date)
        if not mrr_df.empty:
            fig_mrr = px.line(mrr_df, x='date', y='mrr', title='Monthly Recurring Revenue (MRR)',
                            color_discrete_sequence=px.colors.sequential.Viridis)
            st.plotly_chart(fig_mrr, use_container_width=True)
            
            mrr_movements_df = mrr_df[['date', 'new_mrr', 'churned_mrr', 'expansion_mrr', 'contraction_mrr']]
            mrr_movements_df = mrr_movements_df.set_index('date')
            # Resample to monthly for a cleaner view of movements, if data spans multiple months
            if (selected_end_date - selected_start_date).days > 60 :
                 mrr_movements_df = mrr_movements_df.resample('M').sum().reset_index()

            fig_mrr_b = px.bar(mrr_movements_df, x='date', y=['new_mrr', 'churned_mrr', 'expansion_mrr', 'contraction_mrr'],
                             title='MRR Movements (Summed)', barmode='group',
                             color_discrete_map={
                                 'new_mrr': '#2ecc71',        # Green
                                 'churned_mrr': '#e74c3c',    # Red
                                 'expansion_mrr': '#3498db',  # Blue
                                 'contraction_mrr': '#f39c12' # Orange
                             })
            st.plotly_chart(fig_mrr_b, use_container_width=True)
        else:
            st.info("No MRR data available for the selected period.")

    with col2:
        st.subheader("Active Subscriptions")
        active_subs_df = calculate_active_subscriptions(selected_start_date, selected_end_date)
        if not active_subs_df.empty:
            fig_active_subs = px.line(active_subs_df, x='date', y='active_subscriptions', title='Active Subscriptions Over Time',
                                    color_discrete_sequence=px.colors.sequential.Plasma)
            st.plotly_chart(fig_active_subs, use_container_width=True)
        else:
            st.info("No active subscription data available for the selected period.")


# --- Subscription Fluctuations ---
elif display_section == 'Subscription Fluctuations':
    st.header("Subscription Fluctuations Analysis")
    st.markdown("Track new subscriptions, cancellations, upgrades, and downgrades.")

    events_df = get_subscription_events(selected_start_date, selected_end_date)

    if not events_df.empty:
        # Summary Counts
        st.subheader("Event Counts")
        event_counts = events_df['type'].value_counts().reset_index()
        event_counts.columns = ['Event Type', 'Count']
        st.table(event_counts)

        # Plot event counts over time (e.g., monthly)
        events_df['month_year'] = events_df['date'].dt.to_period('M').astype(str)
        monthly_events = events_df.groupby(['month_year', 'type']).size().reset_index(name='count')
        
        fig_events_timeline = px.bar(monthly_events, x='month_year', y='count', color='type',
                                     title='Subscription Events Over Time (Monthly)',
                                     labels={'month_year': 'Month', 'count': 'Number of Events'},
                                     color_discrete_sequence=px.colors.qualitative.Pastel)
        st.plotly_chart(fig_events_timeline, use_container_width=True)

        # Detailed Log
        st.subheader("Detailed Event Log")
        st.dataframe(events_df[['date', 'type', 'details', 'mrr_change']].sort_values(by='date', ascending=False), use_container_width=True)
    else:
        st.info("No subscription events found for the selected period.")

# --- Marketing Impact ---
elif display_section == 'Marketing Impact':
    st.header("Marketing Campaign Impact")
    st.markdown("Analyze customer acquisition and initial MRR from campaigns.")
    
    campaign_summary_df = get_marketing_campaign_summary(selected_start_date, selected_end_date)
    
    if not campaign_summary_df.empty:
        st.subheader("Campaign Performance Summary")
        st.dataframe(campaign_summary_df[[
            'name', 'start_date', 'end_date', 'budget', 'channel', 
            'acquired_customers_during_campaign', 'initial_mrr_from_acquired', 'cac'
        ]], use_container_width=True)

        st.subheader("Acquired Customers by Campaign")
        fig_campaign_cust = px.bar(campaign_summary_df, x='name', y='acquired_customers_during_campaign', 
                                   color='channel', title='Customers Acquired During Campaign Period',
                                   color_discrete_sequence=px.colors.qualitative.Vivid)
        st.plotly_chart(fig_campaign_cust, use_container_width=True)
        
        st.subheader("Initial MRR from Acquired Customers by Campaign")
        fig_campaign_mrr = px.bar(campaign_summary_df, x='name', y='initial_mrr_from_acquired', 
                                  color='channel', title='Initial MRR from Customers Acquired During Campaign',
                                  color_discrete_sequence=px.colors.qualitative.Plotly)
        st.plotly_chart(fig_campaign_mrr, use_container_width=True)
        
        st.subheader("Customer Acquisition Cost (CAC) by Campaign")
        fig_campaign_cac = px.bar(campaign_summary_df, x='name', y='cac', 
                                  color='channel', title='Customer Acquisition Cost (CAC)',
                                  color_discrete_sequence=px.colors.qualitative.Safe)
        st.plotly_chart(fig_campaign_cac, use_container_width=True)

    else:
        st.info("No marketing campaign data available for the selected period, or no campaigns were active/ended in this period.")

# --- Footer ---
st.sidebar.markdown("---")
st.sidebar.info("Dashboard for SaaS Subscription Analytics. Uses `saas_subscriptions.db`.")

if __name__ == '__main__':
    # This allows the script to be run directly for testing if needed,
    # but Streamlit runs it by calling `streamlit run dashboard/app.py`
    pass

