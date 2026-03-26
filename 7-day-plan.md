
 7-Day, 2-Hours/Day SQL Learning Plan (US Healthcare AR)

- **Run instantly on DB Fiddle (MySQL) (https://www.db-fiddle.com/):**
  1. Paste `sql/schema.sql` in Schema SQL window
  2. Paste `sql/sample-data.sql` in Schema SQL window
  3. Run below day wise queries in Query SQL window

     **Make sure to use Database: MySQL v8 version in https://www.db-fiddle.com/**
     
> **Stack:** MySQL 8 • Schema: `sql/schema.sql` • Data: `sql/sample-data.sql`
>
> Each day includes: learning goals, warm-up checks, and **runnable queries** that build from beginner → intermediate using the AR dataset (claims, lines, payments, denials, follow_ups, payers, patients, providers).
---


## ✅ Day 1 — Explore the Schema & Sanity Checks
**Goal (2 hrs):** Understand tables, keys, and basic `SELECT`/filters.

### Warm-up
```sql
-- List all tables (manually inspect in your DB UI)
-- SHOW TABLES;  -- (uncomment if running locally)

-- Row counts per table
SELECT 'patients' t, COUNT(*) c FROM patients
UNION ALL SELECT 'providers', COUNT(*) FROM providers
UNION ALL SELECT 'payers', COUNT(*) FROM payers
UNION ALL SELECT 'claims', COUNT(*) FROM claims
UNION ALL SELECT 'claim_lines', COUNT(*) FROM claim_lines
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'denials', COUNT(*) FROM denials
UNION ALL SELECT 'follow_ups', COUNT(*) FROM follow_ups;


### Core queries

-- Inspect recent claims
SELECT claim_id, service_date, submission_date, claim_amount, claim_status
FROM claims
ORDER BY submission_date DESC
LIMIT 10;

-- Inspect dimension lookups
SELECT * FROM payers
ORDER BY payer_name;

SELECT * FROM providers
ORDER BY provider_name;

SELECT * FROM patients
ORDER BY last_name, first_name;

-- Simple filters
SELECT * FROM claims
WHERE claim_status = 'Pending';

SELECT * FROM claims
WHERE claim_amount > 500
ORDER BY claim_amount DESC;

### Stretch
-- Find top 5 most expensive claims submitted in the last 120 days
SELECT claim_id, submission_date, claim_amount
FROM claims
WHERE submission_date >= (CURDATE() - INTERVAL 120 DAY)
ORDER BY claim_amount DESC
LIMIT 5;

## ✅ Day 2 — Join Fundamentals (Context Building)
Goal (2 hrs): Learn JOIN patterns to enrich claim context.

### Warm-up
-- Claim + patient + provider + payer context
SELECT c.claim_id,
       CONCAT(pt.first_name,' ',pt.last_name) AS patient,
       pr.provider_name,
       py.payer_name,
       c.service_date, c.submission_date,
       c.claim_amount, c.claim_status
FROM claims c
JOIN patients  pt ON pt.patient_id  = c.patient_id
JOIN providers pr ON pr.provider_id = c.provider_id
JOIN payers    py ON py.payer_id    = c.payer_id
ORDER BY c.submission_date DESC
LIMIT 20;

### Core queries
-- Header ↔ Lines
SELECT c.claim_id, cl.line_id, cl.cpt, cl.units, cl.line_charge
FROM claims c
JOIN claim_lines cl ON cl.claim_id = c.claim_id
ORDER BY c.claim_id, cl.line_id;

-- Header ↔ Payments
SELECT c.claim_id, p.payment_id, p.payment_date, p.paid_amount, p.adjustment_amount
FROM claims c
LEFT JOIN payments p ON p.claim_id = c.claim_id
ORDER BY c.claim_id, p.payment_date;

-- Header ↔ Denials
SELECT c.claim_id, d.denial_code, d.denial_status, d.denial_date
FROM claims c
LEFT JOIN denials d ON d.claim_id = c.claim_id
ORDER BY c.claim_id, d.denial_date;

### Stretch
-- Claims that have both a denial and a payment
SELECT DISTINCT c.claim_id
FROM claims c
JOIN denials d  ON d.claim_id = c.claim_id
JOIN payments p ON p.claim_id = c.claim_id
ORDER BY c.claim_id;


✅ Day 3 — Aggregations & Balances
Goal (2 hrs): Use GROUP BY, SUM, and compute balances.

### Warm-up
-- Total charges, paid, adjustments
SELECT 
  SUM(c.claim_amount) AS total_charges,
  SUM(p.paid_amount) AS total_paid,
  SUM(p.adjustment_amount) AS total_adjustments
FROM claims c
LEFT JOIN payments p ON p.claim_id = c.claim_id;

### Core queries
-- Balance by claim
SELECT c.claim_id,
       c.claim_amount,
       IFNULL(SUM(p.paid_amount),0) AS paid,
       IFNULL(SUM(p.adjustment_amount),0) AS adjusted,
       c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) AS balance
FROM claims c
LEFT JOIN payments p ON p.claim_id = c.claim_id
GROUP BY c.claim_id, c.claim_amount
ORDER BY balance DESC;

-- Payer-wise recovery %
SELECT py.payer_name,
       SUM(p.paid_amount) / NULLIF(SUM(c.claim_amount),0) * 100 AS recovery_pct
FROM claims c
JOIN payers py ON py.payer_id = c.payer_id
LEFT JOIN payments p ON p.claim_id = c.claim_id
GROUP BY py.payer_name
ORDER BY recovery_pct DESC;

-- Denials by code
SELECT d.denial_code,
       COUNT(DISTINCT d.claim_id) AS claims_denied,
       COUNT(*) AS denial_events
FROM denials d
GROUP BY d.denial_code
ORDER BY claims_denied DESC, denial_events DESC;

### Stretch
-- High-balance open claims (>0)
WITH bal AS (
  SELECT c.claim_id,
         c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) AS balance
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.claim_amount
)
SELECT * FROM bal WHERE balance > 0 ORDER BY balance DESC;

✅ Day 4 — Real AR Scenarios (Aging, Top Denials)
Goal (2 hrs): Build AR aging buckets and denial insights.

### Warm-up
-- Age days since submission
SELECT claim_id, submission_date, DATEDIFF(CURDATE(), submission_date) AS age_days
FROM claims
ORDER BY age_days DESC
LIMIT 15;

### Core queries 
-- Aging buckets by header charges
WITH base AS (
  SELECT claim_id,
         claim_amount,
         DATEDIFF(CURDATE(), submission_date) AS age_days
  FROM claims
), bucketed AS (
  SELECT claim_id, claim_amount, age_days,
         CASE
           WHEN age_days <= 30 THEN '0-30'
           WHEN age_days <= 60 THEN '31-60'
           WHEN age_days <= 90 THEN '61-90'
           WHEN age_days <= 120 THEN '91-120'
           ELSE '120+'
         END AS age_bucket
  FROM base
)
SELECT age_bucket,
       COUNT(*) AS claims,
       SUM(claim_amount) AS ar_amount
FROM bucketed
GROUP BY age_bucket
ORDER BY FIELD(age_bucket,'0-30','31-60','61-90','91-120','120+');

-- Top denial codes with $ impact
SELECT d.denial_code,
       COUNT(DISTINCT d.claim_id) AS claims,
       SUM(c.claim_amount) AS denied_amount
FROM denials d
JOIN claims c ON c.claim_id = d.claim_id
GROUP BY d.denial_code
ORDER BY denied_amount DESC;

### Stretch
-- Oldest pending claims by payer
SELECT py.payer_name, c.claim_id, c.submission_date,
       DATEDIFF(CURDATE(), c.submission_date) AS age_days
FROM claims c
JOIN payers py ON py.payer_id = c.payer_id
WHERE c.claim_status = 'Pending'
ORDER BY age_days DESC, c.claim_amount DESC
LIMIT 10;

✅ Day 5 — CTEs, CASE, and Derived KPIs
Goal (2 hrs): Use CTEs and CASE to create intermediate tables & KPIs.

### Warm-up
-- CASE-based payer category
SELECT payer_name,
       CASE plan_type
         WHEN 'Medicare' THEN 'Govt'
         WHEN 'Medicaid' THEN 'Govt'
         ELSE 'Commercial'
       END AS payer_category
FROM payers
ORDER BY payer_category, payer_name;

### Core queries
-- Payer Scorecard: TAT, denial rate, recovery %
WITH claim_stats AS (
  SELECT c.claim_id, c.payer_id, c.submission_date,
         MIN(p.payment_date) AS first_payment_date,
         SUM(p.paid_amount)  AS total_paid
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.payer_id, c.submission_date
), denial_flags AS (
  SELECT d.claim_id, 1 AS has_denial
  FROM denials d
  GROUP BY d.claim_id
)
SELECT py.payer_name,
       COUNT(cs.claim_id) AS claims_submitted,
       ROUND(AVG(CASE WHEN cs.first_payment_date IS NOT NULL
                      THEN DATEDIFF(cs.first_payment_date, cs.submission_date) END),1) AS avg_TAT_days,
       ROUND(AVG(IF(df.has_denial=1,1,0))*100,1) AS denial_rate_pct,
       ROUND(SUM(cs.total_paid)/NULLIF(SUM(c.claim_amount),0)*100,1) AS recovery_pct
FROM claim_stats cs
JOIN claims c  ON c.claim_id = cs.claim_id
JOIN payers py ON py.payer_id = c.payer_id
LEFT JOIN denial_flags df ON df.claim_id = c.claim_id
GROUP BY py.payer_name
ORDER BY recovery_pct DESC, avg_TAT_days ASC;

-- Follow-up SLA: % touched within 14 days
WITH first_fu AS (
  SELECT c.claim_id, c.submission_date, MIN(fu.followup_date) AS first_fu
  FROM claims c
  LEFT JOIN follow_ups fu ON fu.claim_id = c.claim_id
  GROUP BY c.claim_id, c.submission_date
)
SELECT ROUND(AVG(CASE WHEN first_fu IS NOT NULL AND DATEDIFF(first_fu, submission_date) <= 14 THEN 1 ELSE 0 END)*100,1) AS pct_touched_14d
FROM first_fu;

### Stretch
-- Claims w/ denial later fully recovered
WITH paid_full AS (
  SELECT c.claim_id
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.claim_amount
  HAVING c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) = 0
)
SELECT DISTINCT d.claim_id
FROM denials d
JOIN paid_full pf ON pf.claim_id = d.claim_id
ORDER BY d.claim_id;

✅ Day 6 — Window Functions & Ranking
Goal (2 hrs): Use window functions for rank, rolling, and latest states.

### Warm-up
-- Rank payers by recovery %
WITH pay AS (
  SELECT c.payer_id,
         SUM(p.paid_amount)/NULLIF(SUM(c.claim_amount),0) AS rec
  FROM claims c LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.payer_id
)
SELECT py.payer_name, rec,
       DENSE_RANK() OVER (ORDER BY rec DESC) AS rnk
FROM pay JOIN payers py ON py.payer_id = pay.payer_id
ORDER BY rnk;

### Core queries
-- Latest follow-up outcome per claim
WITH r AS (
  SELECT fu.*, ROW_NUMBER() OVER (PARTITION BY fu.claim_id ORDER BY fu.followup_date DESC, fu.followup_id DESC) AS rn
  FROM follow_ups fu
)
SELECT claim_id, followup_date, action, outcome, notes
FROM r
WHERE rn = 1
ORDER BY followup_date DESC;

-- Payment cadence: days from submission to first payment by claim
WITH fp AS (
  SELECT c.claim_id, c.submission_date, MIN(p.payment_date) AS first_pay
  FROM claims c LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.submission_date
)
SELECT claim_id,
       DATEDIFF(first_pay, submission_date) AS days_to_first_pay
FROM fp
WHERE first_pay IS NOT NULL
ORDER BY days_to_first_pay;

### Stretch
-- Top 10 open-balance claims with payer, rank by balance
WITH bal AS (
  SELECT c.claim_id, c.payer_id, c.claim_amount - IFNULL(SUM(p.paid_amount), 0) - IFNULL(SUM(p.adjustment_amount), 0) AS balance
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.payer_id, c.claim_amount
)
SELECT *
FROM (
    SELECT b.claim_id, py.payer_name, b.balance, DENSE_RANK() OVER (ORDER BY b.balance DESC) AS balance_rank
    FROM bal b
    JOIN payers py ON py.payer_id = b.payer_id
    WHERE b.balance > 0
) ranked
WHERE ranked.balance_rank <= 10;

✅ Day 7 — Portfolio Reports (Save & Commit)
Goal (2 hrs): Build 3 “portfolio-grade” queries and commit.

### 1) AR Aging Summary (Header-Level)

WITH base AS (
  SELECT claim_id, claim_amount, DATEDIFF(CURDATE(), submission_date) AS age_days FROM claims
), bucketed AS (
  SELECT claim_id, claim_amount,
         CASE
           WHEN age_days <= 30 THEN '0-30'
           WHEN age_days <= 60 THEN '31-60'
           WHEN age_days <= 90 THEN '61-90'
           WHEN age_days <= 120 THEN '91-120'
           ELSE '120+'
         END AS age_bucket
  FROM base
)
SELECT age_bucket,
       COUNT(*) AS claim_count,
       SUM(claim_amount) AS ar_amount
FROM bucketed
GROUP BY age_bucket
ORDER BY FIELD(age_bucket,'0-30','31-60','61-90','91-120','120+');


### 2) Payer Scorecard (TAT, Denial Rate, Recovery %)

WITH claim_stats AS (
  SELECT c.claim_id, c.payer_id, c.submission_date,
         MIN(p.payment_date) AS first_payment_date,
         SUM(p.paid_amount)  AS total_paid
  FROM claims c LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.payer_id, c.submission_date
), denial_flags AS (
  SELECT d.claim_id, 1 AS has_denial FROM denials d GROUP BY d.claim_id
)
SELECT py.payer_name,
       COUNT(cs.claim_id) AS claims_submitted,
       ROUND(AVG(CASE WHEN cs.first_payment_date IS NOT NULL
                      THEN DATEDIFF(cs.first_payment_date, cs.submission_date) END),1) AS avg_TAT_days,
       ROUND(AVG(IF(df.has_denial=1,1,0))*100,1) AS denial_rate_pct,
       ROUND(SUM(cs.total_paid)/NULLIF(SUM(c.claim_amount),0)*100,1) AS recovery_pct
FROM claim_stats cs
JOIN claims c  ON c.claim_id = cs.claim_id
JOIN payers py ON py.payer_id = c.payer_id
LEFT JOIN denial_flags df ON df.claim_id = c.claim_id
GROUP BY py.payer_name
ORDER BY recovery_pct DESC, avg_TAT_days ASC;


### 3) Open AR Worklist (Oldest & Highest Balance w/ Last Follow-up)

WITH balances AS (
  SELECT c.claim_id, c.payer_id, c.submission_date,
         c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) AS balance
  FROM claims c LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.payer_id, c.submission_date, c.claim_amount
), last_fu AS (
  SELECT fu.claim_id, MAX(fu.followup_date) AS last_followup
  FROM follow_ups fu
  GROUP BY fu.claim_id
)
SELECT b.claim_id, py.payer_name, b.submission_date,
       DATEDIFF(CURDATE(), b.submission_date) AS age_days,
       b.balance, l.last_followup
FROM balances b
JOIN payers py ON py.payer_id = b.payer_id
LEFT JOIN last_fu l ON l.claim_id = b.claim_id
WHERE b.balance > 0
ORDER BY age_days DESC, b.balance DESC
LIMIT 25;











