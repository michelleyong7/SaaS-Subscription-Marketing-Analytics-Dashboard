-- Base table schemas and sample data for SaaS Analytics

-- Dates should be in 'YYYY-MM-DD' format for SQLite compatibility.

-- ------------------------------
-- TABLE CREATION
-- ------------------------------

-- 1. Calendar Table
-- Needs to be populated for the entire analysis period.
CREATE TABLE IF NOT EXISTS calendar (
    date TEXT PRIMARY KEY, -- Full date, YYYY-MM-DD
    week_start_date TEXT,  -- YYYY-MM-DD, typically Monday
    week_end_date TEXT,    -- YYYY-MM-DD, typically Sunday
    month INTEGER,         -- 1-12
    quarter INTEGER,       -- 1-4
    year INTEGER           -- YYYY
);

-- 2. Customers Table
CREATE TABLE IF NOT EXISTS customers (
    customer_id TEXT PRIMARY KEY,
    signup_date TEXT,       -- YYYY-MM-DD
    churn_date TEXT,        -- YYYY-MM-DD, NULL if not churned
    first_plan_id TEXT,     -- Initial plan (could be 'trial')
    acquisition_source TEXT, -- e.g., 'Organic', 'Paid Search', 'Referral', 'Social'
    country TEXT            -- e.g., 'USA', 'Canada', 'UK', 'Germany', 'France'
);

-- 3. Subscription Changes Table
CREATE TABLE IF NOT EXISTS subscription_changes (
    event_id TEXT PRIMARY KEY,
    customer_id TEXT,
    event_date TEXT,        -- YYYY-MM-DD
    event_type TEXT,        -- e.g., 'trial_start', 'trial_conversion', 'upgrade', 'downgrade', 'cancellation_request', 'cancellation_processed'
    old_plan_id TEXT,       -- Can be NULL for initial event
    new_plan_id TEXT,       -- Can be NULL if churned
    mrr_change REAL,        -- Positive for new/upgrade, negative for downgrade/churn. Reflects the *change* in MRR.
    new_mrr_value REAL,     -- The new MRR after this change. For 'cancellation_processed', this would be 0.
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 4. Revenue Table
-- Stores actual MRR recognized per customer for a given week.
CREATE TABLE IF NOT EXISTS revenue (
    revenue_id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id TEXT,
    week_start TEXT,        -- YYYY-MM-DD, Monday (references calendar.week_start_date)
    MRR REAL,               -- MRR amount for that customer for that week
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- 5. Marketing Table
CREATE TABLE IF NOT EXISTS marketing (
    marketing_id INTEGER PRIMARY KEY AUTOINCREMENT,
    week_start TEXT,        -- YYYY-MM-DD, Monday
    channel TEXT,           -- e.g., 'Google Ads', 'Facebook Ads', 'Content Marketing', 'Email Marketing'
    ad_spend REAL
);

-- 6. Product Usage Table
CREATE TABLE IF NOT EXISTS product_usage (
    usage_id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id TEXT,
    week_start TEXT,        -- YYYY-MM-DD, Monday
    sessions INTEGER,
    features_used INTEGER,
    time_spent_minutes INTEGER,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- ------------------------------
-- DATA POPULATION
-- ------------------------------

-- Plan MRRs for reference:
-- trial: $0
-- basic: $20
-- standard: $50
-- premium: $100

-- Populate Calendar for 6 months (Jan 2023 - Jun 2023)
-- Ensuring all week_start_dates are present for the period.
-- For simplicity, adding entries for the start and end of each week, plus some mid-points if month/quarter changes.
-- A full calendar table would have an entry for every day.

INSERT INTO calendar (date, week_start_date, week_end_date, month, quarter, year) VALUES
-- January 2023
('2023-01-02', '2023-01-02', '2023-01-08', 1, 1, 2023), -- Week 1 Start
('2023-01-08', '2023-01-02', '2023-01-08', 1, 1, 2023), -- Week 1 End
('2023-01-09', '2023-01-09', '2023-01-15', 1, 1, 2023), -- Week 2 Start
('2023-01-15', '2023-01-09', '2023-01-15', 1, 1, 2023), -- Week 2 End
('2023-01-16', '2023-01-16', '2023-01-22', 1, 1, 2023), -- Week 3 Start
('2023-01-22', '2023-01-16', '2023-01-22', 1, 1, 2023), -- Week 3 End
('2023-01-23', '2023-01-23', '2023-01-29', 1, 1, 2023), -- Week 4 Start
('2023-01-29', '2023-01-23', '2023-01-29', 1, 1, 2023), -- Week 4 End
('2023-01-30', '2023-01-30', '2023-02-05', 1, 1, 2023), -- Week 5 Start (Spans Jan/Feb)

-- February 2023
('2023-02-01', '2023-01-30', '2023-02-05', 2, 1, 2023), -- Mid-week 5 (Feb starts)
('2023-02-05', '2023-01-30', '2023-02-05', 2, 1, 2023), -- Week 5 End
('2023-02-06', '2023-02-06', '2023-02-12', 2, 1, 2023), -- Week 6 Start
('2023-02-12', '2023-02-06', '2023-02-12', 2, 1, 2023), -- Week 6 End
('2023-02-13', '2023-02-13', '2023-02-19', 2, 1, 2023), -- Week 7 Start
('2023-02-19', '2023-02-13', '2023-02-19', 2, 1, 2023), -- Week 7 End
('2023-02-20', '2023-02-20', '2023-02-26', 2, 1, 2023), -- Week 8 Start
('2023-02-26', '2023-02-20', '2023-02-26', 2, 1, 2023), -- Week 8 End
('2023-02-27', '2023-02-27', '2023-03-05', 2, 1, 2023), -- Week 9 Start (Spans Feb/Mar)

-- March 2023
('2023-03-01', '2023-02-27', '2023-03-05', 3, 1, 2023), -- Mid-week 9 (Mar starts)
('2023-03-05', '2023-02-27', '2023-03-05', 3, 1, 2023), -- Week 9 End
('2023-03-06', '2023-03-06', '2023-03-12', 3, 1, 2023), -- Week 10 Start
('2023-03-12', '2023-03-06', '2023-03-12', 3, 1, 2023), -- Week 10 End
('2023-03-13', '2023-03-13', '2023-03-19', 3, 1, 2023), -- Week 11 Start
('2023-03-19', '2023-03-13', '2023-03-19', 3, 1, 2023), -- Week 11 End
('2023-03-20', '2023-03-20', '2023-03-26', 3, 1, 2023), -- Week 12 Start
('2023-03-26', '2023-03-20', '2023-03-26', 3, 1, 2023), -- Week 12 End
('2023-03-27', '2023-03-27', '2023-04-02', 3, 1, 2023), -- Week 13 Start (Spans Mar/Apr, Q1 end for these dates)

-- April 2023
('2023-04-01', '2023-03-27', '2023-04-02', 4, 2, 2023), -- Mid-week 13 (Apr, Q2 starts)
('2023-04-02', '2023-03-27', '2023-04-02', 4, 2, 2023), -- Week 13 End
('2023-04-03', '2023-04-03', '2023-04-09', 4, 2, 2023), -- Week 14 Start
('2023-04-09', '2023-04-03', '2023-04-09', 4, 2, 2023), -- Week 14 End
('2023-04-10', '2023-04-10', '2023-04-16', 4, 2, 2023), -- Week 15 Start
('2023-04-16', '2023-04-10', '2023-04-16', 4, 2, 2023), -- Week 15 End
('2023-04-17', '2023-04-17', '2023-04-23', 4, 2, 2023), -- Week 16 Start
('2023-04-23', '2023-04-17', '2023-04-23', 4, 2, 2023), -- Week 16 End
('2023-04-24', '2023-04-24', '2023-04-30', 4, 2, 2023), -- Week 17 Start
('2023-04-30', '2023-04-24', '2023-04-30', 4, 2, 2023), -- Week 17 End

-- May 2023
('2023-05-01', '2023-05-01', '2023-05-07', 5, 2, 2023), -- Week 18 Start
('2023-05-07', '2023-05-01', '2023-05-07', 5, 2, 2023), -- Week 18 End
('2023-05-08', '2023-05-08', '2023-05-14', 5, 2, 2023), -- Week 19 Start
('2023-05-14', '2023-05-08', '2023-05-14', 5, 2, 2023), -- Week 19 End
('2023-05-15', '2023-05-15', '2023-05-21', 5, 2, 2023), -- Week 20 Start
('2023-05-21', '2023-05-15', '2023-05-21', 5, 2, 2023), -- Week 20 End
('2023-05-22', '2023-05-22', '2023-05-28', 5, 2, 2023), -- Week 21 Start
('2023-05-28', '2023-05-22', '2023-05-28', 5, 2, 2023), -- Week 21 End
('2023-05-29', '2023-05-29', '2023-06-04', 5, 2, 2023), -- Week 22 Start (Spans May/Jun)

-- June 2023
('2023-06-01', '2023-05-29', '2023-06-04', 6, 2, 2023), -- Mid-week 22 (Jun starts)
('2023-06-04', '2023-05-29', '2023-06-04', 6, 2, 2023), -- Week 22 End
('2023-06-05', '2023-06-05', '2023-06-11', 6, 2, 2023), -- Week 23 Start
('2023-06-11', '2023-06-05', '2023-06-11', 6, 2, 2023), -- Week 23 End
('2023-06-12', '2023-06-12', '2023-06-18', 6, 2, 2023), -- Week 24 Start
('2023-06-18', '2023-06-12', '2023-06-18', 6, 2, 2023), -- Week 24 End
('2023-06-19', '2023-06-19', '2023-06-25', 6, 2, 2023), -- Week 25 Start
('2023-06-25', '2023-06-19', '2023-06-25', 6, 2, 2023), -- Week 25 End
('2023-06-26', '2023-06-26', '2023-07-02', 6, 2, 2023), -- Week 26 Start (Spans Jun/Jul)
('2023-06-30', '2023-06-26', '2023-07-02', 6, 2, 2023); -- End of June, Week 26 mid

-- Populate Customers (Approx 15 customers over 6 months)
INSERT INTO customers (customer_id, signup_date, churn_date, first_plan_id, acquisition_source, country) VALUES
('cust_001', '2023-01-05', NULL, 'trial', 'Organic', 'USA'),
('cust_002', '2023-01-10', '2023-03-15', 'basic', 'Paid Search', 'Canada'),
('cust_003', '2023-01-15', NULL, 'standard', 'Referral', 'UK'),
('cust_004', '2023-02-01', NULL, 'trial', 'Social', 'Germany'),
('cust_005', '2023-02-10', '2023-05-20', 'premium', 'Organic', 'USA'),
('cust_006', '2023-02-20', NULL, 'basic', 'Paid Search', 'France'),
('cust_007', '2023-03-01', NULL, 'trial', 'Referral', 'Canada'),
('cust_008', '2023-03-10', '2023-06-12', 'standard', 'Social', 'USA'),
('cust_009', '2023-03-15', NULL, 'premium', 'Organic', 'UK'),
('cust_010', '2023-04-01', NULL, 'basic', 'Paid Search', 'Germany'),
('cust_011', '2023-04-05', '2023-06-25', 'trial', 'Referral', 'USA'),
('cust_012', '2023-04-10', NULL, 'standard', 'Social', 'Canada'),
('cust_013', '2023-05-01', NULL, 'premium', 'Organic', 'France'),
('cust_014', '2023-05-15', NULL, 'trial', 'Paid Search', 'UK'),
('cust_015', '2023-06-01', NULL, 'basic', 'Referral', 'USA');

-- Populate Subscription Changes
-- (event_id, customer_id, event_date, event_type, old_plan_id, new_plan_id, mrr_change, new_mrr_value)
INSERT INTO subscription_changes (event_id, customer_id, event_date, event_type, old_plan_id, new_plan_id, mrr_change, new_mrr_value) VALUES
-- Cust 001: Trial -> Standard -> Premium
('evt_001', 'cust_001', '2023-01-05', 'trial_start', NULL, 'trial', 0, 0),
('evt_002', 'cust_001', '2023-01-12', 'trial_conversion', 'trial', 'standard', 50, 50),
('evt_003', 'cust_001', '2023-04-01', 'upgrade', 'standard', 'premium', 50, 100),

-- Cust 002: Basic -> Churn
('evt_004', 'cust_002', '2023-01-10', 'trial_conversion', 'trial', 'basic', 20, 20), 
('evt_005', 'cust_002', '2023-03-15', 'cancellation_processed', 'basic', NULL, -20, 0),

-- Cust 003: Standard (Stays)
('evt_006', 'cust_003', '2023-01-15', 'trial_conversion', 'trial', 'standard', 50, 50),

-- Cust 004: Trial -> Standard -> Basic
('evt_007', 'cust_004', '2023-02-01', 'trial_start', NULL, 'trial', 0, 0),
('evt_008', 'cust_004', '2023-02-08', 'trial_conversion', 'trial', 'standard', 50, 50),
('evt_009', 'cust_004', '2023-05-01', 'downgrade', 'standard', 'basic', -30, 20),

-- Cust 005: Premium -> Churn
('evt_010', 'cust_005', '2023-02-10', 'trial_conversion', 'trial', 'premium', 100, 100),
('evt_011', 'cust_005', '2023-05-20', 'cancellation_processed', 'premium', NULL, -100, 0),

-- Cust 006: Basic (Stays)
('evt_012', 'cust_006', '2023-02-20', 'trial_conversion', 'trial', 'basic', 20, 20),

-- Cust 007: Trial -> Standard
('evt_013', 'cust_007', '2023-03-01', 'trial_start', NULL, 'trial', 0, 0),
('evt_014', 'cust_007', '2023-03-08', 'trial_conversion', 'trial', 'standard', 50, 50),

-- Cust 008: Standard -> Churn
('evt_015', 'cust_008', '2023-03-10', 'trial_conversion', 'trial', 'standard', 50, 50),
('evt_016', 'cust_008', '2023-06-12', 'cancellation_processed', 'standard', NULL, -50, 0),

-- Cust 009: Premium (Stays)
('evt_017', 'cust_009', '2023-03-15', 'trial_conversion', 'trial', 'premium', 100, 100),

-- Cust 010: Basic (Stays)
('evt_018', 'cust_010', '2023-04-01', 'trial_conversion', 'trial', 'basic', 20, 20),

-- Cust 011: Trial -> Basic -> Churn
('evt_019', 'cust_011', '2023-04-05', 'trial_start', NULL, 'trial', 0, 0),
('evt_020', 'cust_011', '2023-04-12', 'trial_conversion', 'trial', 'basic', 20, 20),
('evt_021', 'cust_011', '2023-06-25', 'cancellation_processed', 'basic', NULL, -20, 0),

-- Cust 012: Standard (Stays)
('evt_022', 'cust_012', '2023-04-10', 'trial_conversion', 'trial', 'standard', 50, 50),

-- Cust 013: Premium (Stays)
('evt_023', 'cust_013', '2023-05-01', 'trial_conversion', 'trial', 'premium', 100, 100),

-- Cust 014: Trial -> basic (converts late June)
('evt_024', 'cust_014', '2023-05-15', 'trial_start', NULL, 'trial', 0, 0),
('evt_025', 'cust_014', '2023-06-28', 'trial_conversion', 'trial', 'basic', 20, 20),

-- Cust 015: Basic (Signs up in June)
('evt_026', 'cust_015', '2023-06-01', 'trial_conversion', 'trial', 'basic', 20, 20);


-- Populate Revenue Table (Illustrative - needs full systematic population)
-- This will be very verbose if done for all customers and all weeks.
-- For now, adding a few key examples to show how it should be structured.
-- A script is highly recommended for full population based on subscription_changes.

-- Week starting 2023-01-02
INSERT INTO revenue (customer_id, week_start, MRR) VALUES
('cust_001', '2023-01-02', 0); -- Trial started Jan 5

-- Week starting 2023-01-09
INSERT INTO revenue (customer_id, week_start, MRR) VALUES
('cust_001', '2023-01-09', 50), -- Converted to standard (50) on Jan 12
('cust_002', '2023-01-09', 20), -- Converted to basic (20) on Jan 10
('cust_003', '2023-01-09', 0);  -- Signs up for standard (50) on Jan 15

-- Week starting 2023-01-16
INSERT INTO revenue (customer_id, week_start, MRR) VALUES
('cust_001', '2023-01-16', 50),
('cust_002', '2023-01-16', 20),
('cust_003', '2023-01-16', 50);

-- Illustrative entries for cust_001 for its entire lifecycle (Standard then Premium)
-- Jan to Mar (Standard @ 50 MRR)
INSERT INTO revenue (customer_id, week_start, MRR) SELECT 'cust_001', week_start_date, 50 FROM calendar WHERE week_start_date BETWEEN '2023-01-09' AND '2023-03-20' GROUP BY 1,2,3;
-- Apr to Jun (Premium @ 100 MRR)
INSERT INTO revenue (customer_id, week_start, MRR) SELECT 'cust_001', week_start_date, 100 FROM calendar WHERE week_start_date BETWEEN '2023-03-27' AND '2023-06-26' GROUP BY 1,2,3;

-- Illustrative entries for cust_002 (Basic @ 20 MRR, Churns Mar 15)
INSERT INTO revenue (customer_id, week_start, MRR) SELECT 'cust_002', week_start_date, 20 FROM calendar WHERE week_start_date BETWEEN '2023-01-09' AND '2023-03-06' GROUP BY 1,2,3;
INSERT INTO revenue (customer_id, week_start, MRR) VALUES ('cust_002', '2023-03-13', 0); -- Churned mid-week, MRR for the week is 0

-- Week starting 2023-06-26 (cust_011 churns Jun 25, cust_014 converts Jun 28)
INSERT INTO revenue (customer_id, week_start, MRR) VALUES
('cust_011', '2023-06-26', 0),
('cust_014', '2023-06-26', 20);

-- IMPORTANT: The revenue table needs to be populated for all active customers for ALL 26 weeks.
-- The above entries are for demonstration of structure and key events only.
-- A full dataset would require automation or very careful manual entry, considering each customer's plan changes and churn date.

-- Populate Marketing (Example for 6 months, a few channels per week)
INSERT INTO marketing (week_start, channel, ad_spend) VALUES
-- Jan 2023
('2023-01-02', 'Google Ads', 200), ('2023-01-02', 'Facebook Ads', 150),
('2023-01-09', 'Google Ads', 210), ('2023-01-09', 'Facebook Ads', 155),
('2023-01-16', 'Google Ads', 205), ('2023-01-16', 'Facebook Ads', 160), ('2023-01-16', 'Content Marketing', 50),
('2023-01-23', 'Google Ads', 215), ('2023-01-23', 'Facebook Ads', 165), ('2023-01-23', 'Content Marketing', 55),
('2023-01-30', 'Google Ads', 220), ('2023-01-30', 'Facebook Ads', 170), ('2023-01-30', 'Content Marketing', 60), ('2023-01-30', 'Email Marketing', 30),
-- Feb 2023
('2023-02-06', 'Google Ads', 225), ('2023-02-06', 'Facebook Ads', 175), ('2023-02-06', 'Content Marketing', 65), ('2023-02-06', 'Email Marketing', 35),
('2023-02-13', 'Google Ads', 230), ('2023-02-13', 'Facebook Ads', 180), ('2023-02-13', 'Content Marketing', 70), ('2023-02-13', 'Email Marketing', 40),
('2023-02-20', 'Google Ads', 235), ('2023-02-20', 'Facebook Ads', 185), ('2023-02-20', 'Content Marketing', 75), ('2023-02-20', 'Email Marketing', 45),
('2023-02-27', 'Google Ads', 240), ('2023-02-27', 'Facebook Ads', 190), ('2023-02-27', 'Content Marketing', 80), ('2023-02-27', 'Email Marketing', 50),
-- Mar 2023
('2023-03-06', 'Google Ads', 250), ('2023-03-06', 'Facebook Ads', 200), ('2023-03-06', 'Content Marketing', 85), ('2023-03-06', 'Email Marketing', 55),
('2023-03-13', 'Google Ads', 255), ('2023-03-13', 'Facebook Ads', 205), ('2023-03-13', 'Content Marketing', 90), ('2023-03-13', 'Email Marketing', 60),
('2023-03-20', 'Google Ads', 260), ('2023-03-20', 'Facebook Ads', 210), ('2023-03-20', 'Content Marketing', 95), ('2023-03-20', 'Email Marketing', 65),
('2023-03-27', 'Google Ads', 265), ('2023-03-27', 'Facebook Ads', 215), ('2023-03-27', 'Content Marketing', 100), ('2023-03-27', 'Email Marketing', 70),
-- Apr 2023
('2023-04-03', 'Google Ads', 270), ('2023-04-03', 'Facebook Ads', 220), ('2023-04-03', 'Content Marketing', 105), ('2023-04-03', 'Email Marketing', 75),
('2023-04-10', 'Google Ads', 275), ('2023-04-10', 'Facebook Ads', 225), ('2023-04-10', 'Content Marketing', 110), ('2023-04-10', 'Email Marketing', 80),
('2023-04-17', 'Google Ads', 280), ('2023-04-17', 'Facebook Ads', 230), ('2023-04-17', 'Content Marketing', 115), ('2023-04-17', 'Email Marketing', 85),
('2023-04-24', 'Google Ads', 285), ('2023-04-24', 'Facebook Ads', 235), ('2023-04-24', 'Content Marketing', 120), ('2023-04-24', 'Email Marketing', 90),
-- May 2023
('2023-05-01', 'Google Ads', 290), ('2023-05-01', 'Facebook Ads', 240), ('2023-05-01', 'Content Marketing', 125), ('2023-05-01', 'Email Marketing', 95),
('2023-05-08', 'Google Ads', 295), ('2023-05-08', 'Facebook Ads', 245), ('2023-05-08', 'Content Marketing', 130), ('2023-05-08', 'Email Marketing', 100),
('2023-05-15', 'Google Ads', 300), ('2023-05-15', 'Facebook Ads', 250), ('2023-05-15', 'Content Marketing', 135), ('2023-05-15', 'Email Marketing', 105),
('2023-05-22', 'Google Ads', 305), ('2023-05-22', 'Facebook Ads', 255), ('2023-05-22', 'Content Marketing', 140), ('2023-05-22', 'Email Marketing', 110),
('2023-05-29', 'Google Ads', 310), ('2023-05-29', 'Facebook Ads', 260), ('2023-05-29', 'Content Marketing', 145), ('2023-05-29', 'Email Marketing', 115),
-- Jun 2023
('2023-06-05', 'Google Ads', 315), ('2023-06-05', 'Facebook Ads', 265), ('2023-06-05', 'Content Marketing', 150), ('2023-06-05', 'Email Marketing', 120),
('2023-06-12', 'Google Ads', 320), ('2023-06-12', 'Facebook Ads', 270), ('2023-06-12', 'Content Marketing', 155), ('2023-06-12', 'Email Marketing', 125),
('2023-06-19', 'Google Ads', 325), ('2023-06-19', 'Facebook Ads', 275), ('2023-06-19', 'Content Marketing', 160), ('2023-06-19', 'Email Marketing', 130),
('2023-06-26', 'Google Ads', 330), ('2023-06-26', 'Facebook Ads', 280), ('2023-06-26', 'Content Marketing', 165), ('2023-06-26', 'Email Marketing', 135);

-- Populate Product Usage (Illustrative - for active customers for relevant weeks)
-- This also needs to be systematically populated for all customers and active weeks.
INSERT INTO product_usage (customer_id, week_start, sessions, features_used, time_spent_minutes) VALUES
-- Cust 001 (Standard then Premium)
('cust_001', '2023-01-09', 10, 5, 120), ('cust_001', '2023-01-16', 12, 6, 130), ('cust_001', '2023-01-23', 11, 5, 125), ('cust_001', '2023-01-30', 13, 6, 140),
('cust_001', '2023-02-06', 10, 5, 120), ('cust_001', '2023-02-13', 12, 6, 135), ('cust_001', '2023-02-20', 11, 5, 128), ('cust_001', '2023-02-27', 14, 7, 150),
('cust_001', '2023-03-06', 10, 5, 130), ('cust_001', '2023-03-13', 12, 6, 140), ('cust_001', '2023-03-20', 11, 6, 135),
('cust_001', '2023-03-27', 15, 8, 200), -- Upgraded to Premium Apr 1
('cust_001', '2023-04-03', 16, 9, 220), ('cust_001', '2023-04-10', 17, 9, 230), ('cust_001', '2023-04-17', 15, 8, 210), ('cust_001', '2023-04-24', 16, 9, 225),
('cust_001', '2023-05-01', 18, 10, 240), ('cust_001', '2023-05-08', 17, 9, 235), ('cust_001', '2023-05-15', 15, 8, 215), ('cust_001', '2023-05-22', 16, 9, 228),
('cust_001', '2023-05-29', 18, 10, 250), ('cust_001', '2023-06-05', 17, 9, 240), ('cust_001', '2023-06-12', 19, 10, 260), ('cust_001', '2023-06-19', 18, 10, 255),
('cust_001', '2023-06-26', 20, 11, 270),

-- Cust 002 (Basic, churns Mar 15)
('cust_002', '2023-01-09', 5, 2, 40), ('cust_002', '2023-01-16', 6, 3, 45), ('cust_002', '2023-01-23', 5, 2, 42), ('cust_002', '2023-01-30', 7, 3, 50),
('cust_002', '2023-02-06', 5, 2, 40), ('cust_002', '2023-02-13', 6, 3, 46), ('cust_002', '2023-02-20', 4, 2, 35), ('cust_002', '2023-02-27', 5, 2, 41),
('cust_002', '2023-03-06', 3, 1, 20), ('cust_002', '2023-03-13', 1, 1, 5), -- Churns Mar 15

-- Cust 003 (Standard, stays active)
('cust_003', '2023-01-16', 9, 4, 90), ('cust_003', '2023-01-23', 10, 5, 100), ('cust_003', '2023-01-30', 8, 4, 85),
-- ... (Sample: Continue for all active weeks for cust_003 up to end of June)
('cust_003', '2023-06-26', 12, 6, 130);

-- Generating comprehensive and consistent weekly data for revenue and product_usage for 15 customers
-- over 26 weeks is extremely verbose for manual SQL INSERTs.
-- The provided samples illustrate the structure and type of data.
-- A full, robust dataset would typically be generated by a script (e.g., Python) and imported from CSVs.

-- Final Note:
-- This expanded schema provides a much richer dataset for analysis.
-- However, generating and maintaining perfectly consistent mock data of this scale manually in SQL INSERTs is very challenging.
-- For a portfolio project, generating CSVs with a script (e.g., Python) and then using SQLite's .import command
-- in this schema.sql file would be a more robust and scalable approach for data population.
-- For now, this provides the structure and an idea of the expanded data.
-- The actual number of INSERT statements for Revenue and Product Usage would be very large
-- if fully populated for 15 customers over 26 weeks.
