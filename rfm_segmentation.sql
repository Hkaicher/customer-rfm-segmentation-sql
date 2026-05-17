-- ============================================================
-- PROJECT   : RFM Customer Segmentation Analysis
-- DATABASE  : RFM_Segmentation
-- DATASET   : sales_data (order-level transactions)
-- AUTHOR    : [Mohammad Hamdan Kaicher]
-- DATE      : 2025
-- TOOL      : MySQL
-- ============================================================
-- DESCRIPTION:
--   RFM (Recency, Frequency, Monetary) is a proven marketing
--   framework to rank and segment customers based on their
--   purchase behavior. Each customer gets:
--     R → Days since last purchase     (lower = better)
--     F → Number of distinct orders    (higher = better)
--     M → Total revenue generated      (higher = better)
--
--   Each dimension is scored 1–5 using NTILE(5).
--   Scores are concatenated into an RFM combo (e.g., "555")
--   and mapped to 10 business segments.
-- ============================================================


-- ============================================================
-- STEP 0: DATABASE SETUP
-- ============================================================

CREATE DATABASE IF NOT EXISTS RFM_Segmentation;
USE RFM_Segmentation;


-- ============================================================
-- STEP 1: QUICK DATA SANITY CHECK
-- ============================================================
-- Validate order counts, deduplication, and revenue totals per customer.
-- ordernumber can repeat across rows (line items), so distinct count
-- gives the true number of orders.

SELECT 
    customername,
    COUNT(ordernumber)          AS total_row_count,      -- includes line items
    COUNT(DISTINCT ordernumber) AS distinct_order_count, -- true order count
    SUM(sales)                  AS total_revenue
FROM sales_data
GROUP BY customername;

-- FINDINGS from initial exploration:
--   Date range: 2003-01-06 → 2005-05-31
--   Reference date (snapshot): max(orderdate) = '2005-05-31'


-- ============================================================
-- STEP 2: RFM SEGMENTATION VIEW
-- ============================================================
-- This view is the core of the analysis. It:
--   1. Calculates raw RFM values per customer
--   2. Converts them to 1–5 scores using NTILE()
--   3. Combines scores into a 3-digit RFM code
--   4. Maps that code to a named business segment

CREATE OR REPLACE VIEW RFM_VIEW AS

WITH 

-- --------------------------------------------------------
-- CTE 1: Raw RFM Values
-- Recency  → days between last purchase and snapshot date
-- Frequency → number of distinct orders placed
-- Monetary  → total revenue (rounded)
-- --------------------------------------------------------
RFM_values AS (
    SELECT 
        customername,
        DATEDIFF(
            (SELECT MAX(STR_TO_DATE(orderdate, '%d/%m/%y')) FROM sales_data),
             MAX(STR_TO_DATE(orderdate, '%d/%m/%y'))
        )                              AS recency_value,   -- days inactive
        COUNT(DISTINCT ordernumber)    AS freq_value,       -- order count
        ROUND(SUM(sales), 0)           AS monetary_value    -- total spend
    FROM sales_data
    GROUP BY customername
),

-- --------------------------------------------------------
-- CTE 2: RFM Scores (1–5 via NTILE)
-- NOTE on ordering:
--   Recency   → lower days = more recent = BETTER → order DESC
--   Frequency → higher orders = BETTER            → order ASC
--   Monetary  → higher spend  = BETTER            → order ASC
-- --------------------------------------------------------
RFM_score AS (
    SELECT 
        rv.*,
        NTILE(5) OVER (ORDER BY recency_value  DESC) AS r_score,
        NTILE(5) OVER (ORDER BY freq_value     ASC)  AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC)  AS m_score
    FROM RFM_values AS rv
),

-- --------------------------------------------------------
-- CTE 3: Combined Score
-- total_rfm_com → additive score (3–15), useful for ranking
-- rfm_com       → concatenated code (e.g., "543"), used for segment mapping
-- --------------------------------------------------------
RFM_com AS (
    SELECT
        *,
        (r_score + f_score + m_score) AS total_rfm_com,
        CONCAT(r_score, f_score, m_score) AS rfm_com
    FROM RFM_score
)

-- --------------------------------------------------------
-- FINAL SELECT: Map RFM codes → Business Segments
-- Segment definitions follow standard RFM industry logic.
-- "Other" catches any code not explicitly listed (edge cases).
-- --------------------------------------------------------
SELECT
    rm.*,
    CASE
        -- High R + High F + High M → your most valuable, engaged customers
        WHEN rfm_com IN ('445','454','455','544','545','554','555')
            THEN 'Champions'

        -- High loyalty, consistent buyers, solid spenders
        WHEN rfm_com IN ('335','343','344','345','354','355','443','444','543','553')
            THEN 'Loyal'

        -- Recent + some frequency → nurture into Loyal
        WHEN rfm_com IN ('323','341','342','351','352','431','441','442','451','452',
                         '531','541','542','551','552','333','353','423','432','433',
                         '453','532','533')
            THEN 'Potential Loyalist'

        -- Recent but low F/M → new-ish, show promise
        WHEN rfm_com IN ('413','414','415','513','514','515','313','314','315','424',
                         '425','524','525','523')
            THEN 'Promising'

        -- Mid-tier on all dimensions → slipping, need re-engagement
        WHEN rfm_com IN ('324','325','434','435','534','535','334')
            THEN 'Need Attention'

        -- Used to be great, haven't bought recently → high-value win-back targets
        WHEN rfm_com IN ('135','145','214','144','154','155','245','254','255')
            THEN 'Cannot Lose'

        -- Very recent, low history → just onboarded
        WHEN rfm_com IN ('411','412','421','422','511','512','521','522')
            THEN 'New Customers'

        -- Decent past behavior, going cold → act before they churn
        WHEN rfm_com IN ('124','125','133','134','142','143','152','153','224','225',
                         '234','235','242','243','244','252','253')
            THEN 'At Risk'

        -- Low recency + low engagement → almost gone
        WHEN rfm_com IN ('122','123','132','211','212','213','221','222','223','231',
                         '232','241','251','311','312','321','322','331','332','233')
            THEN 'About to Sleep'

        -- Haven't bought in ages, low F and M → likely churned
        WHEN rfm_com IN ('111','112','113','114','115','121','131','141','151','215')
            THEN 'Lost'

        ELSE 'Other'
    END AS rfm_segment

FROM RFM_com AS rm;


-- ============================================================
-- STEP 3: SEGMENT SUMMARY REPORT
-- ============================================================
-- Business-ready output: how many customers fall into each
-- segment, and what their average behavior looks like.
-- Use this for dashboard reporting or stakeholder presentations.

SELECT 
    rfm_segment                         AS segment,
    COUNT(customername)                 AS customer_count,
    ROUND(AVG(recency_value), 0)        AS avg_days_inactive,
    ROUND(AVG(freq_value), 1)           AS avg_orders,
    ROUND(AVG(monetary_value), 0)       AS avg_spend_usd
FROM RFM_VIEW
GROUP BY rfm_segment
ORDER BY avg_spend_usd DESC;
