# customer-rfm-segmentation-sql
SQL-based RFM (Recency, Frequency, Monetary) customer segmentation using MySQL window functions and CTEs — maps customers into 10 actionable business segments.

## 🔍 What is RFM?
 
RFM is a data-driven customer segmentation framework used in marketing and CRM. Every customer gets scored across three dimensions:
 
| Dimension | Measures | Better Score = |
|-----------|----------|----------------|
| **Recency (R)** | Days since last purchase | Bought recently |
| **Frequency (F)** | Number of distinct orders | Buys often |
| **Monetary (M)** | Total revenue generated | Spends more |
 
Each dimension is scored **1–5** using `NTILE(5)`, then combined into a 3-digit code (e.g., `"554"`) that maps to one of **10 business segments**.
 
---
 
## 🗂️ Dataset
 
- **Table:** `sales_data`
- **Date range:** `2003-01-06` → `2005-05-31`
- **Key columns used:** `customername`, `ordernumber`, `orderdate`, `sales`
- **Date format:** `'%d/%m/%y'` (parsed with `STR_TO_DATE`)
> The dataset is based on a classic sales sample dataset commonly used for SQL analytics practice.
 
---
 
## 🏗️ Project Structure
 
```
rfm-segmentation/
│
├── rfm_segmentation.sql    # Full SQL script (setup → view → report)
└── README.md               # You are here
```
 
---
 
## 🚀 How to Run
 
1. Open MySQL Workbench (or any MySQL-compatible client)
2. Import your `sales_data` table into MySQL
3. Run `rfm_segmentation.sql` top to bottom
4. Query `RFM_VIEW` or the summary report for output
```sql
-- See all customer segments
SELECT * FROM RFM_VIEW;
 
-- Segment-level summary (use this for dashboards)
SELECT rfm_segment, COUNT(*), AVG(monetary_value)
FROM RFM_VIEW
GROUP BY rfm_segment;
```
 
---
 
## 📐 Scoring Logic
 
```
NTILE(5) over recency  → lower days inactive = score 5
NTILE(5) over frequency → more orders = score 5
NTILE(5) over monetary  → higher spend = score 5
```
 
The 3-digit combo (e.g., `"555"`) is then matched against predefined segment rules:
 
| Segment | RFM Profile | Action |
|---|---|---|
| **Champions** | High R, F, M | Reward & upsell |
| **Loyal** | High loyalty, consistent | Engage & retain |
| **Potential Loyalist** | Recent, growing | Nurture |
| **Promising** | Recent but low spend | Onboard well |
| **Need Attention** | Mid-tier, slipping | Re-engage now |
| **Cannot Lose** | High value, gone quiet | Win back urgently |
| **New Customers** | Just joined | Welcome campaign |
| **At Risk** | Good past, going cold | Targeted offers |
| **About to Sleep** | Low activity | Last-chance push |
| **Lost** | No recent activity | Reactivation or sunset |
 
---
 
## 🛠️ Tech Stack
 
- **Database:** MySQL 8+
- **Features used:** CTEs (`WITH`), Window Functions (`NTILE`), Views (`CREATE OR REPLACE VIEW`), `DATEDIFF`, `STR_TO_DATE`
---
 
## 📌 Key Design Decisions
 
- Used `COUNT(DISTINCT ordernumber)` for frequency — raw row count inflates due to line items per order
- Snapshot date = `MAX(orderdate)` in the dataset (not `CURDATE()`) for reproducible, dataset-relative analysis
- Scores 1–5 via `NTILE(5)` — robust against outliers, no manual binning needed
- Segment mapping is based on widely adopted RFM industry conventions
---
 
## 📈 Sample Output
 
| Segment | Customers | Avg Days Inactive | Avg Orders | Avg Spend |
|---|---|---|---|---|
| Champions | 12 | 34 | 9 | $89,420 |
| Loyal | 18 | 121 | 6 | $61,300 |
| Lost | 9 | 610 | 2 | $12,800 |
| ... | ... | ... | ... | ... |
 
---
 
## 👤 Author
 
**[Mohammad Hamdan Kaicher]**  
[LinkedIn](https://linkedin.com/in/hamdankaicher)
## 📄 License
 
MIT — free to use, adapt, and share.
