# SaaS Subscription Analytics Dashboard

A comprehensive analytics dashboard for SaaS businesses to track and analyze subscription metrics, customer lifecycles, and marketing campaign performance.

## Features

- **Key Metrics Overview**: Track MRR trends, MRR movements (new, expansion, contraction, churned), and active subscriptions over time.
- **Subscription Fluctuations Analysis**: Detailed tracking of new subscriptions, cancellations, upgrades, and downgrades with event timeline and logs.
- **Marketing Impact Analysis**: Measure campaign performance by customer acquisition, initial MRR, and customer acquisition cost (CAC).

## Project Structure

```
saas_analytics_project/
│
├── data/
│   └── sqlite/           # Database storage directory
│       └── saas_subscriptions.db  # SQLite database (generated)
│
├── dashboard/
│   └── app.py            # Streamlit dashboard application
│
├── database_setup.py     # Script to create database schema
├── generate_sample_data.py  # Script to populate database with sample data
├── requirements.txt      # Project dependencies
└── README.md             # This documentation file
```

## Database Schema

The project uses a SQLite database (`saas_subscriptions.db`) with the following tables:

### Plans
- Stores information about subscription plans
- Fields: id, name, price_monthly, features

### Marketing Campaigns
- Tracks marketing campaigns and their performance metrics
- Fields: id, name, start_date, end_date, budget, channel

### Customers
- Stores customer information including acquisition source
- Fields: id, name, email, registration_date, marketing_campaign_id

### Subscriptions
- Core table tracking the subscription lifecycle events
- Fields: id, customer_id, plan_id, start_date, end_date, status, prev_plan_id
- Status can be: 'active', 'canceled', 'upgraded', 'downgraded'

## Installation and Setup

### Prerequisites
- Python 3.7+
- pip (Python package installer)

### Installation

1. Clone this repository or download the files
2. Install dependencies:
   ```
   pip install -r requirements.txt
   ```
3. Set up the database:
   ```
   python database_setup.py
   ```
4. Generate sample data:
   ```
   python generate_sample_data.py
   ```
5. Run the Streamlit dashboard:
   ```
   streamlit run dashboard/app.py
   ```

## Usage

### Dashboard Navigation

1. **Global Filters**: Use the date range selector in the sidebar to filter all data by time period.

2. **Section Selection**: Choose between different dashboard sections using the radio buttons in the sidebar:
   - Key Metrics Overview
   - Subscription Fluctuations
   - Marketing Impact

3. **Chart Interaction**: All charts are interactive (powered by Plotly):
   - Hover to see detailed values
   - Click and drag to zoom
   - Double-click to reset view
   - Use the toolbar in the top-right of each chart for additional options

## Sample Data

The `generate_sample_data.py` script creates realistic sample data, including:

- 3 subscription plans (Basic, Pro, Enterprise)
- ~10 marketing campaigns across different channels
- ~200 customers with varying registration dates
- Subscription lifecycle events including new subscriptions, upgrades, downgrades, and cancellations
- Time span of approximately 2 years

## Extending the Project

To extend this project for your own needs:

1. **Custom Data**: Modify `database_setup.py` and `generate_sample_data.py` to match your actual data structure.

2. **Additional Metrics**: Add new calculation functions to `dashboard/app.py` and extend the UI accordingly.

3. **Real Data Import**: Create import scripts to migrate your actual SaaS data into the database structure.

## Metrics Documentation

### MRR (Monthly Recurring Revenue)
- The predictable revenue that a SaaS business expects to receive every month.
- Calculated daily as the sum of all active subscription monthly values.

### MRR Movements
- **New MRR**: Revenue from first-time subscriptions.
- **Expansion MRR**: Additional revenue from existing customers upgrading to higher plans.
- **Contraction MRR**: Reduced revenue from existing customers downgrading to lower plans.
- **Churned MRR**: Revenue lost from cancellations.

### Customer Acquisition Cost (CAC)
- The cost to acquire a single customer, calculated as: Campaign Budget / Number of Customers Acquired.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 