-- KPI Queries for SaaS Analytics Portfolio Project

-- 1. Total MRR Trend (Weekly)
-- Shows the overall growth of Monthly Recurring Revenue over time.
SELECT
    week_start_date,
    total_mrr
FROM v_weekly_total_mrr
ORDER BY week_start_date;

-- 2. MRR Growth Components (Weekly)
-- Breaks down the MRR changes into new, expansion, contraction, and churned MRR.
SELECT
    week_start_date,
    new_mrr,
    expansion_mrr,
    contraction_mrr, -- Typically negative or zero
    churned_mrr,     -- Typically negative or zero
    net_new_mrr
FROM v_weekly_net_new_mrr
ORDER BY week_start_date;

-- 3. Active Customers Trend (Weekly)
-- Tracks the number of paying customers over time.
SELECT
    week_start_date,
    active_customers
FROM v_weekly_active_customers
ORDER BY week_start_date;

-- 4. Customer Churn Rate Trend (Weekly Percentage)
-- Shows the percentage of customers lost each week.
SELECT
    week_start_date,
    active_at_start_of_week,
    churned_this_week,
    customer_churn_rate_percentage
FROM v_weekly_customer_churn_rate
ORDER BY week_start_date;

-- 5. Gross Revenue Churn Rate Trend (Weekly Percentage)
-- Shows the percentage of MRR lost each week.
SELECT
    week_start_date,
    mrr_at_start_of_week,
    abs_churned_mrr_in_week,
    gross_revenue_churn_rate_percentage
FROM v_weekly_revenue_churn_rate
ORDER BY week_start_date;

-- 6. New Signups Trend (Weekly)
-- Tracks the number of new customers acquired each week.
SELECT
    week_start_date,
    new_signups
FROM v_weekly_signups
ORDER BY week_start_date;

-- 7. Customer Acquisition Cost (CAC) Trend (Weekly)
-- Shows the average cost to acquire a new customer each week.
SELECT
    week_start_date,
    total_ad_spend,
    new_signups,
    overall_cac
FROM v_weekly_overall_cac
ORDER BY week_start_date;

-- 8. Product Engagement Trend (Weekly Average Sessions per Active Customer)
-- Measures how actively customers are using the product.
SELECT
    week_start_date,
    active_customers,
    avg_sessions_per_active_customer
FROM v_weekly_avg_engagement
ORDER BY week_start_date;

-- 9. Cohort Retention Analysis (Example for a specific cohort)
-- Tracks how many customers from a specific signup week remain active over subsequent weeks.
-- Replace 'YYYY-MM-DD' with an actual cohort_week_start from your v_customer_cohorts or v_weekly_cohort_retention_summary
SELECT
    cohort_week,
    week_number_after_signup,
    cohort_size,
    retained_customers,
    retention_percentage
FROM v_weekly_cohort_retention_summary
WHERE cohort_week = (SELECT MIN(cohort_week) FROM v_weekly_cohort_retention_summary) -- Example: Oldest cohort
ORDER BY cohort_week, week_number_after_signup;

-- To get a list of available cohort weeks:
-- SELECT DISTINCT cohort_week FROM v_weekly_cohort_retention_summary ORDER BY cohort_week;

-- 10. Weekly Performance Snapshot (Example for the most recent week)
-- Provides a summary of all key metrics for a specific period.
SELECT
    week_start_date,
    month,
    quarter,
    year,
    total_mrr,
    net_new_mrr,
    new_mrr,
    expansion_mrr,
    contraction_mrr,
    churned_mrr,
    active_customers,
    new_signups,
    customer_churn_rate_pct,
    gross_revenue_churn_rate_pct,
    overall_cac,
    avg_sessions_per_active_customer
FROM v_weekly_dashboard_summary
WHERE week_start_date = (SELECT MAX(week_start_date) FROM v_weekly_dashboard_summary) -- Example: Most recent week
ORDER BY week_start_date DESC;

-- Example: Get data for a specific month (e.g., January 2023)
-- Assuming your calendar view has month and year correctly populated and week_start_date is the first day of the week.
-- You might need to adjust based on how your calendar table defines months for weekly data.
/*
SELECT
    week_start_date,
    total_mrr,
    net_new_mrr,
    active_customers,
    customer_churn_rate_pct,
    overall_cac
FROM v_weekly_dashboard_summary
WHERE year = 2023 AND month = 1 -- Example: For January 2023
ORDER BY week_start_date;
*/

-- Remember to replace placeholder dates or conditions with actual values relevant to your dataset.
-- These queries leverage the views created in `sql/create_views.sql`.
-- You can run these against your SQLite database (e.g., using DB Browser for SQLite or `sqlite3` CLI).
-- Example: sqlite3 saas_analytics.db < sql/kpi_queries.sql > results.txt
-- (This ^ command might need adjustment for PowerShell, e.g., Get-Content sql/kpi_queries.sql | sqlite3 saas_analytics.db > results.txt)
