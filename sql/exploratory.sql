-- Exploratory and Debugging Queries for SaaS Analytics

-- These queries are for ad-hoc exploration, debugging views, or one-off analysis.
-- You can uncomment and run them individually as needed using a SQLite browser or the CLI.

-- ----------------------------------------
-- DATABASE STRUCTURE AND METADATA
-- ----------------------------------------

-- List all tables in the database
-- SELECT name FROM sqlite_master WHERE type='table';

-- List all views in the database
-- SELECT name FROM sqlite_master WHERE type='view';

-- Get the schema (CREATE statement) for a specific table
-- SELECT sql FROM sqlite_master WHERE type='table' AND name='customers';
-- SELECT sql FROM sqlite_master WHERE type='table' AND name='revenue';
-- SELECT sql FROM sqlite_master WHERE type='table' AND name='subscription_changes';

-- Get the schema (CREATE statement) for a specific view
-- SELECT sql FROM sqlite_master WHERE type='view' AND name='v_weekly_total_mrr';
-- SELECT sql FROM sqlite_master WHERE type='view' AND name='v_weekly_mrr_components';
-- SELECT sql FROM sqlite_master WHERE type='view' AND name='v_weekly_dashboard_summary';

-- ----------------------------------------
-- INSPECTING BASE TABLE DATA
-- ----------------------------------------

-- Show first 10 customers
-- SELECT * FROM customers LIMIT 10;

-- Show first 10 revenue entries
-- SELECT * FROM revenue LIMIT 10;

-- Show first 10 subscription changes
-- SELECT * FROM subscription_changes LIMIT 10;

-- Show marketing spend
-- SELECT * FROM marketing;

-- Show product usage data
-- SELECT * FROM product_usage LIMIT 10;

-- Show calendar data for a specific month
-- SELECT * FROM calendar WHERE year = 2023 AND month = 1;

-- ----------------------------------------
-- INSPECTING VIEW OUTPUTS (RAW)
-- ----------------------------------------

-- Show output of v_subscription_changes_weekly
-- SELECT * FROM v_subscription_changes_weekly LIMIT 10;

-- Show output of v_weekly_total_mrr
-- SELECT * FROM v_weekly_total_mrr ORDER BY week_start_date DESC LIMIT 5;

-- Show output of v_weekly_mrr_components
-- SELECT * FROM v_weekly_mrr_components ORDER BY week_start_date DESC LIMIT 5;

-- Show output of v_weekly_net_new_mrr
-- SELECT * FROM v_weekly_net_new_mrr ORDER BY week_start_date DESC LIMIT 5;

-- Show output of v_weekly_active_customers
-- SELECT * FROM v_weekly_active_customers ORDER BY week_start_date DESC LIMIT 5;

-- Show output of v_weekly_signups
-- SELECT * FROM v_weekly_signups ORDER BY week_start_date DESC LIMIT 5;

-- Show customers active at week start and churned in week (for churn rate debugging)
-- SELECT * FROM v_customers_active_at_week_start WHERE week_start_date = '2023-01-16';
-- SELECT * FROM v_customers_churned_in_week WHERE week_start_date = '2023-01-16';
-- SELECT * FROM v_weekly_customer_churn_rate WHERE week_start_date = '2023-01-16';

-- Show weekly revenue churn rate components
-- SELECT * FROM v_weekly_revenue_churn_rate ORDER BY week_start_date DESC LIMIT 5;

-- Show weekly CAC components
-- SELECT * FROM v_weekly_overall_cac ORDER BY week_start_date DESC LIMIT 5;

-- Show weekly engagement metrics
-- SELECT * FROM v_weekly_avg_engagement ORDER BY week_start_date DESC LIMIT 5;

-- Show cohort retention summary for a specific cohort
-- SELECT * FROM v_weekly_cohort_retention_summary WHERE cohort_week = '2023-01-02' ORDER BY week_number_after_signup;

-- Show the full weekly dashboard summary for a few recent weeks
-- SELECT * FROM v_weekly_dashboard_summary ORDER BY week_start_date DESC LIMIT 5;

-- ----------------------------------------
-- CUSTOM EXPLORATORY QUERIES (EXAMPLES)
-- ----------------------------------------

-- Find a specific customer's journey through subscription_changes
-- SELECT * FROM subscription_changes WHERE customer_id = 'cust_001' ORDER BY event_date;

-- Check revenue entries for a specific customer
-- SELECT * FROM revenue WHERE customer_id = 'cust_001' ORDER BY week_start;

-- Check MRR components for a specific week where something looks off
-- SELECT * FROM v_weekly_mrr_components WHERE week_start_date = '2023-01-16';

-- Deep dive into net new MRR calculation for a specific week:
-- Step 1: Get the components for the week from v_weekly_mrr_components
-- SELECT new_mrr, expansion_mrr, contraction_mrr, churned_mrr
-- FROM v_weekly_mrr_components
-- WHERE week_start_date = '2023-01-16';
-- Step 2: Verify against v_subscription_changes_weekly for that week
-- SELECT event_type, SUM(mrr_change) as total_mrr_change_for_type
-- FROM v_subscription_changes_weekly
-- WHERE week_start_date = '2023-01-16'
-- GROUP BY event_type;

-- Count customers by their first signup week (cohort identification from base table)
-- SELECT strftime('%Y-%W', signup_date) as signup_year_week, COUNT(DISTINCT customer_id) as num_customers
-- FROM customers
-- GROUP BY 1 ORDER BY 1;
-- Note: The week numbering of strftime('%W') might differ from your calendar table if it has custom week definitions.
-- It's often better to use the cohort_week from v_weekly_cohort_retention_summary or v_customer_cohorts.

-- Sum of MRR for active customers in a specific week from the base 'revenue' table
-- SELECT week_start, SUM(MRR) as total_mrr_from_revenue_table
-- FROM revenue
-- WHERE MRR > 0 AND week_start = '2023-01-16'
-- GROUP BY week_start;
-- Compare this to:
-- SELECT week_start_date, total_mrr FROM v_weekly_total_mrr WHERE week_start_date = '2023-01-16';

-- Look at all subscription changes for a week where churn seemed high
-- SELECT sc.*
-- FROM subscription_changes sc
-- JOIN calendar cal ON DATE(sc.event_date) BETWEEN cal.week_start_date AND cal.week_end_date
-- WHERE cal.week_start_date = '2023-01-16' AND sc.event_type = 'cancellation_processed';

-- Remember to use a SQLite client to run these. Most are commented out by default.
-- Uncomment the query you want to run.
