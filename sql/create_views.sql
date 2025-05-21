-- SaaS Analytics Views
-- Ensures dates are handled correctly for comparisons and joins.

-- Helper view to align subscription change events with the calendar week_start_date
CREATE VIEW IF NOT EXISTS v_subscription_changes_weekly AS
SELECT
    sc.event_id,
    sc.customer_id,
    sc.event_date,
    c.week_start_date, -- Aligns event to the week it occurred in
    sc.event_type,
    sc.old_plan,
    sc.new_plan,
    sc.mrr_change
FROM subscription_changes sc
JOIN calendar c ON DATE(sc.event_date) >= DATE(c.week_start_date) AND DATE(sc.event_date) <= DATE(c.week_end_date);

-- MRR Related Views
CREATE VIEW IF NOT EXISTS v_weekly_total_mrr AS
SELECT
    DATE(r.week_start) as week_start_date,
    SUM(r.MRR) as total_mrr
FROM revenue r
GROUP BY 1
ORDER BY 1;

CREATE VIEW IF NOT EXISTS v_weekly_mrr_components AS
SELECT
    c.week_start_date,
    COALESCE(SUM(CASE WHEN scw.event_type = 'trial_conversion' THEN scw.mrr_change ELSE 0 END), 0) as new_mrr,
    COALESCE(SUM(CASE WHEN scw.event_type = 'upgrade' THEN scw.mrr_change ELSE 0 END), 0) as expansion_mrr,
    COALESCE(SUM(CASE WHEN scw.event_type = 'downgrade' THEN scw.mrr_change ELSE 0 END), 0) as contraction_mrr, -- This will be negative or zero
    COALESCE(SUM(CASE WHEN scw.event_type = 'cancellation_processed' AND scw.mrr_change < 0 THEN scw.mrr_change ELSE 0 END), 0) as churned_mrr -- This will be negative or zero
FROM calendar c
LEFT JOIN v_subscription_changes_weekly scw ON c.week_start_date = DATE(scw.week_start_date)
GROUP BY 1
ORDER BY 1;

CREATE VIEW IF NOT EXISTS v_weekly_net_new_mrr AS
SELECT
    week_start_date,
    (new_mrr + expansion_mrr + contraction_mrr + churned_mrr) as net_new_mrr,
    new_mrr,
    expansion_mrr,
    contraction_mrr, 
    churned_mrr 
FROM v_weekly_mrr_components;

-- Customer Activity
CREATE VIEW IF NOT EXISTS v_weekly_active_customers AS
SELECT
    DATE(r.week_start) as week_start_date,
    COUNT(DISTINCT r.customer_id) as active_customers
FROM revenue r
WHERE r.MRR > 0 -- Definition of active customer for this context
GROUP BY 1
ORDER BY 1;

CREATE VIEW IF NOT EXISTS v_weekly_signups AS
SELECT
    c.week_start_date,
    COUNT(DISTINCT cust.customer_id) as new_signups
FROM calendar c
LEFT JOIN customers cust ON DATE(cust.signup_date) >= c.week_start_date AND DATE(cust.signup_date) <= c.week_end_date
GROUP BY 1
ORDER BY 1;

-- Churn Related Views
CREATE VIEW IF NOT EXISTS v_customers_active_at_week_start AS
SELECT
    cal.week_start_date,
    COUNT(DISTINCT cust.customer_id) as active_at_start_of_week
FROM calendar cal
LEFT JOIN customers cust -- LEFT JOIN to include all calendar weeks
    ON DATE(cust.signup_date) < cal.week_start_date -- Signed up before this week started
    AND (cust.churn_date IS NULL OR DATE(cust.churn_date) >= cal.week_start_date) -- And either not churned, or churned during or after this week
GROUP BY 1;

CREATE VIEW IF NOT EXISTS v_customers_churned_in_week AS
SELECT
    cal.week_start_date,
    COUNT(DISTINCT cust.customer_id) as churned_this_week
FROM calendar cal
LEFT JOIN customers cust -- LEFT JOIN to include all calendar weeks
    ON DATE(cust.churn_date) >= cal.week_start_date AND DATE(cust.churn_date) <= cal.week_end_date
GROUP BY 1;

CREATE VIEW IF NOT EXISTS v_weekly_customer_churn_rate AS
SELECT
    COALESCE(cas.week_start_date, ccw.week_start_date) as week_start_date,
    COALESCE(cas.active_at_start_of_week, 0) as active_at_start_of_week,
    COALESCE(ccw.churned_this_week, 0) as churned_this_week,
    CASE
        WHEN cas.active_at_start_of_week > 0
        THEN (CAST(COALESCE(ccw.churned_this_week, 0) AS REAL) / cas.active_at_start_of_week) * 100
        ELSE 0
    END as customer_churn_rate_percentage
FROM v_customers_active_at_week_start cas
FULL OUTER JOIN v_customers_churned_in_week ccw ON cas.week_start_date = ccw.week_start_date
ORDER BY 1;

CREATE VIEW IF NOT EXISTS v_weekly_revenue_churn_rate AS
SELECT
    mrr_comp.week_start_date,
    LAG(total_mrr.total_mrr, 1, 0) OVER (ORDER BY total_mrr.week_start_date) as mrr_at_start_of_week, -- MRR from previous week's end
    ABS(mrr_comp.churned_mrr) as abs_churned_mrr_in_week,
    CASE
        WHEN LAG(total_mrr.total_mrr, 1, 0) OVER (ORDER BY total_mrr.week_start_date) > 0
        THEN (ABS(mrr_comp.churned_mrr) / (LAG(total_mrr.total_mrr, 1, 0) OVER (ORDER BY total_mrr.week_start_date))) * 100
        ELSE 0
    END as gross_revenue_churn_rate_percentage
FROM v_weekly_mrr_components mrr_comp
JOIN v_weekly_total_mrr total_mrr ON mrr_comp.week_start_date = total_mrr.week_start_date
ORDER BY 1;

-- CAC Related Views
CREATE VIEW IF NOT EXISTS v_weekly_overall_cac AS
SELECT
    DATE(m.week_start) as week_start_date,
    SUM(m.ad_spend) as total_ad_spend,
    s.new_signups,
    CASE
        WHEN s.new_signups > 0
        THEN SUM(m.ad_spend) / s.new_signups
        ELSE 0
    END as overall_cac
FROM marketing m
JOIN v_weekly_signups s ON DATE(m.week_start) = s.week_start_date
GROUP BY 1, 3
ORDER BY 1;

-- Product Engagement
CREATE VIEW IF NOT EXISTS v_weekly_avg_engagement AS
SELECT
    DATE(pu.week_start) as week_start_date,
    COALESCE(wa.active_customers, 0) as active_customers,
    SUM(pu.sessions) as total_sessions,
    SUM(pu.features_used) as total_features_used,
    CASE WHEN wa.active_customers > 0 THEN CAST(SUM(pu.sessions) AS REAL) / wa.active_customers ELSE 0 END as avg_sessions_per_active_customer,
    CASE WHEN wa.active_customers > 0 THEN CAST(SUM(pu.features_used) AS REAL) / wa.active_customers ELSE 0 END as avg_features_per_active_customer
FROM product_usage pu
JOIN v_weekly_active_customers wa ON DATE(pu.week_start) = wa.week_start_date
GROUP BY 1, 2
ORDER BY 1;

-- Cohort Retention Analysis (Weekly)
CREATE VIEW IF NOT EXISTS v_customer_cohorts AS
SELECT
    cust.customer_id,
    cust.signup_date,
    c_cal.week_start_date as cohort_week_start,
    CAST((JULIANDAY(DATE(r_cal.week_start_date)) - JULIANDAY(DATE(c_cal.week_start_date))) / 7 AS INTEGER) as weeks_since_signup
FROM customers cust
JOIN calendar c_cal ON DATE(cust.signup_date) BETWEEN c_cal.week_start_date AND c_cal.week_end_date
-- For calculating weeks_since_signup based on revenue activity:
LEFT JOIN revenue r ON cust.customer_id = r.customer_id
LEFT JOIN calendar r_cal ON DATE(r.week_start) = r_cal.week_start_date;

CREATE VIEW IF NOT EXISTS v_weekly_cohort_retention_summary AS
WITH cohort_base AS (
    SELECT
        c.customer_id,
        cal.week_start_date as cohort_week
    FROM customers c
    JOIN calendar cal ON DATE(c.signup_date) BETWEEN cal.week_start_date AND cal.week_end_date
),
cohort_sizes AS (
    SELECT cohort_week, COUNT(DISTINCT customer_id) as cohort_size
    FROM cohort_base
    GROUP BY cohort_week
),
weekly_activity AS (
    SELECT DISTINCT
        r.customer_id,
        DATE(r.week_start) as activity_week
    FROM revenue r
    WHERE r.MRR > 0
)
SELECT
    cb.cohort_week,
    cs.cohort_size,
    CAST( (JULIANDAY(wa.activity_week) - JULIANDAY(cb.cohort_week)) / 7 AS INTEGER) as week_number_after_signup,
    COUNT(DISTINCT wa.customer_id) as retained_customers,
    ( CAST(COUNT(DISTINCT wa.customer_id) AS REAL) / cs.cohort_size ) * 100 as retention_percentage
FROM cohort_base cb
JOIN weekly_activity wa ON cb.customer_id = wa.customer_id AND wa.activity_week >= cb.cohort_week
JOIN cohort_sizes cs ON cb.cohort_week = cs.cohort_week
GROUP BY 1, 2, 3
ORDER BY 1, 3;

-- Comprehensive Weekly Summary View
CREATE VIEW IF NOT EXISTS v_weekly_dashboard_summary AS
SELECT
    cal.week_start_date,
    cal.month,
    cal.quarter,
    cal.year,
    COALESCE(tmrr.total_mrr, 0) as total_mrr,
    COALESCE(nnm.net_new_mrr, 0) as net_new_mrr,
    COALESCE(nnm.new_mrr, 0) as new_mrr,
    COALESCE(nnm.expansion_mrr, 0) as expansion_mrr,
    COALESCE(nnm.contraction_mrr, 0) as contraction_mrr,
    COALESCE(nnm.churned_mrr, 0) as churned_mrr, -- This is negative
    COALESCE(wac.active_customers, 0) as active_customers,
    COALESCE(signups.new_signups, 0) as new_signups,
    COALESCE(churn.customer_churn_rate_percentage, 0) as customer_churn_rate_pct,
    COALESCE(rev_churn.gross_revenue_churn_rate_percentage, 0) as gross_revenue_churn_rate_pct,
    COALESCE(cac.overall_cac, 0) as overall_cac,
    COALESCE(eng.avg_sessions_per_active_customer, 0) as avg_sessions_per_active_customer
FROM calendar cal
LEFT JOIN v_weekly_total_mrr tmrr ON cal.week_start_date = tmrr.week_start_date
LEFT JOIN v_weekly_net_new_mrr nnm ON cal.week_start_date = nnm.week_start_date
LEFT JOIN v_weekly_active_customers wac ON cal.week_start_date = wac.week_start_date
LEFT JOIN v_weekly_signups signups ON cal.week_start_date = signups.week_start_date
LEFT JOIN v_weekly_customer_churn_rate churn ON cal.week_start_date = churn.week_start_date
LEFT JOIN v_weekly_revenue_churn_rate rev_churn ON cal.week_start_date = rev_churn.week_start_date
LEFT JOIN v_weekly_overall_cac cac ON cal.week_start_date = cac.week_start_date
LEFT JOIN v_weekly_avg_engagement eng ON cal.week_start_date = eng.week_start_date
ORDER BY cal.week_start_date;

-- You can run these CREATE VIEW statements against your SQLite database.
-- Example query to use a view:
-- SELECT * FROM v_weekly_dashboard_summary WHERE year = 2022 AND quarter = 1;
-- SELECT cohort_week, week_number_after_signup, retention_percentage FROM v_weekly_cohort_retention_summary WHERE cohort_week = '2022-01-03';
