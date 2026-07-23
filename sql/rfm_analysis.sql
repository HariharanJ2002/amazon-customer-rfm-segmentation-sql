/* ============================================================
   Customer Segmentation via RFM Analysis
   Dataset: Amazon Purchase Survey Data (500-user sample)
   ============================================================
   This script builds an RFM (Recency, Frequency, Monetary)
   customer segmentation pipeline using CTEs/views and window
   functions (NTILE, RANK) in PostgreSQL.

   Pipeline:
     1. base                 -> cleaned transaction-level data with proper date field
     2. rfm_base              -> recency/frequency/monetary per user
     3. rfm_scores            -> quintile scores (1-5) per R/F/M dimension
     4. rfm_segments           -> business-labeled customer segments
     5. category_by_segment    -> category affinity check per segment
     6. segment summary queries -> revenue/user share by segment
   ============================================================ */


-- ------------------------------------------------------------
-- STEP 1: Base view
-- Builds a clean transaction-level view with order value and
-- a proper DATE field (raw data stores year/month/day separately,
-- with month as a 3-letter abbreviation e.g. 'Dec').
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW base AS
SELECT
    user_id,
    product_id,
    category,
    quantity,
    purchase_price_per_unit AS unit_price,
    quantity * purchase_price_per_unit AS order_value,
    TO_DATE(year || '-' || month || '-' || day, 'YYYY-Mon-DD') AS purchase_date
FROM amazon_survey;


-- ------------------------------------------------------------
-- STEP 2: Recency, Frequency, Monetary per user
-- Recency  = days since each user's last purchase, relative to
--            the most recent date across the whole dataset
--            (used as a proxy for "today" since the data is historical)
-- Frequency = total number of transactions per user
-- Monetary  = total amount spent per user
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW rfm_base AS
SELECT
    user_id,
    MAX(purchase_date) AS last_purchase,
    (SELECT MAX(purchase_date) FROM base) - MAX(purchase_date) AS recency_days,
    COUNT(*) AS frequency,
    SUM(order_value) AS monetary
FROM base
GROUP BY user_id;


-- ------------------------------------------------------------
-- STEP 3: Quintile scoring (1-5) per dimension using NTILE
-- Convention: 5 = best, 1 = worst, for all three scores.
--   r_score: recent activity scores higher (recency_days DESC)
--   f_score: more frequent purchasing scores higher
--   m_score: higher total spend scores higher
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW rfm_scores AS
SELECT
    user_id,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC)     AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC)      AS m_score
FROM rfm_base;


-- ------------------------------------------------------------
-- STEP 4: Segment labeling
-- Translates numeric R/F/M scores into business-readable
-- customer segments using CASE logic.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW rfm_segments AS
SELECT
    user_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_code,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 3 THEN 'New/Promising'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        WHEN r_score = 3 AND f_score <= 2 AND m_score <= 2 THEN 'Needs Attention'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Needs Attention'  -- catch-all for remaining mixed/ambiguous combinations
    END AS segment_label
FROM rfm_scores;


-- ------------------------------------------------------------
-- STEP 5: Category affinity by segment
-- Checks whether purchase category preferences differ across
-- customer segments. "Unknown" category rows are excluded here
-- since they don't add meaningful category-level insight
-- (they are still included in all RFM calculations above).
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW category_by_segment AS
SELECT
    r.segment_label,
    b.category,
    COUNT(*) AS num_orders,
    ROUND(SUM(b.order_value), 2) AS category_revenue,
    RANK() OVER (PARTITION BY r.segment_label ORDER BY SUM(b.order_value) DESC) AS category_rank
FROM base b
JOIN rfm_segments r ON b.user_id = r.user_id
WHERE b.category != 'Unknown'
GROUP BY r.segment_label, b.category;


-- ============================================================
-- SUMMARY / REPORTING QUERIES
-- ============================================================

-- Segment size + distribution check
SELECT
    segment_label,
    COUNT(*) AS num_users
FROM rfm_segments
GROUP BY segment_label
ORDER BY num_users DESC;


-- Segment-level averages (recency, frequency, monetary)
SELECT
    segment_label,
    COUNT(*) AS num_users,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary,
    ROUND(SUM(monetary), 2) AS total_monetary
FROM rfm_segments
GROUP BY segment_label
ORDER BY total_monetary DESC;


-- Segment revenue ranking + % share of total revenue
-- (mirrors the "% of Total Revenue" DAX measure used in Power BI)
SELECT
    segment_label,
    COUNT(*) AS num_users,
    ROUND(SUM(monetary), 2) AS total_monetary,
    RANK() OVER (ORDER BY SUM(monetary) DESC) AS value_rank,
    ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_of_total_revenue
FROM rfm_segments
GROUP BY segment_label
ORDER BY total_monetary DESC;


-- Top categories per segment (top 3 shown)
SELECT *
FROM category_by_segment
WHERE category_rank <= 3
ORDER BY segment_label, category_rank;


-- Data quality check: rows with missing category data
SELECT category, COUNT(*)
FROM amazon_survey
WHERE category = 'Unknown'
GROUP BY category;