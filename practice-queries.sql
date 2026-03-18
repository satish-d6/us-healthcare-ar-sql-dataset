-- PRACTICE QUERIES for US Healthcare AR (MySQL 8)
-- Run after loading schema.sql and sample-data.sql
-- All queries are safe to run read-only. Modify as you like.

/* =============================================================
   0) Quick sanity checks
   ============================================================= */
-- Table row counts
SELECT 'patients' AS table_name, COUNT(*) AS row_count FROM patients
UNION ALL SELECT 'providers', COUNT(*) FROM providers
UNION ALL SELECT 'payers', COUNT(*) FROM payers
UNION ALL SELECT 'claims', COUNT(*) FROM claims
UNION ALL SELECT 'claim_lines', COUNT(*) FROM claim_lines
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'denials', COUNT(*) FROM denials
UNION ALL SELECT 'follow_ups', COUNT(*) FROM follow_ups;

-- Total charges at claim header level
SELECT SUM(claim_amount) AS total_claim_charges FROM claims;

/* =============================================================
   1) Core joins & context
   ============================================================= */
-- Claim header with patient/provider/payer context
SELECT c.claim_id,
       CONCAT(p.first_name,' ',p.last_name) AS patient,
       pr.provider_name,
       py.payer_name,
       c.service_date, c.submission_date,
       c.claim_amount, c.claim_status
FROM claims c
JOIN patients  p  ON p.patient_id   = c.patient_id
JOIN providers pr ON pr.provider_id = c.provider_id
JOIN payers    py ON py.payer_id    = c.payer_id
ORDER BY c.submission_date DESC, c.claim_id DESC
LIMIT 50;

-- Claim lines detail
SELECT cl.claim_id, cl.line_id, cl.cpt, cl.units, cl.line_charge
FROM claim_lines cl
ORDER BY cl.claim_id, cl.line_id;

/* =============================================================
   2) Payments & balances
   ============================================================= */
-- Net balance by claim = charges - payments - adjustments
SELECT c.claim_id,
       c.claim_amount,
       IFNULL(SUM(p.paid_amount),0) AS total_paid,
       IFNULL(SUM(p.adjustment_amount),0) AS total_adjusted,
       c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) AS balance
FROM claims c
LEFT JOIN payments p ON p.claim_id = c.claim_id
GROUP BY c.claim_id, c.claim_amount
ORDER BY balance DESC, c.claim_amount DESC;

-- Open AR only (balance > 0)
WITH balances AS (
  SELECT c.claim_id,
         c.payer_id,
         c.submission_date,
         c.claim_status,
         c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) AS balance
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.payer_id, c.submission_date, c.claim_status, c.claim_amount
)
SELECT b.claim_id, py.payer_name, b.submission_date, b.claim_status, b.balance
FROM balances b
JOIN payers py ON py.payer_id = b.payer_id
WHERE b.balance > 0
ORDER BY b.balance DESC;

/* =============================================================
   3) Denial analytics
   ============================================================= */
-- Denials by code (volume & $ at header level)
SELECT d.denial_code,
       COUNT(DISTINCT d.claim_id) AS claims_denied,
       COUNT(*) AS denial_events,
       SUM(c.claim_amount) AS denied_claim_amount
FROM denials d
JOIN claims c ON c.claim_id = d.claim_id
GROUP BY d.denial_code
ORDER BY claims_denied DESC, denial_events DESC;

-- Top denial reasons (textual)
SELECT d.denial_reason,
       COUNT(*) AS events
FROM denials d
GROUP BY d.denial_reason
ORDER BY events DESC
LIMIT 10;

-- Denial status funnel
SELECT d.denial_status,
       COUNT(*) AS events
FROM denials d
GROUP BY d.denial_status
ORDER BY events DESC;

/* =============================================================
   4) AR Aging buckets (based on submission_date)
   ============================================================= */
WITH base AS (
  SELECT c.claim_id,
         c.claim_amount,
         DATEDIFF(CURDATE(), c.submission_date) AS age_days
  FROM claims c
), bucketed AS (
  SELECT claim_id,
         claim_amount,
         age_days,
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
       SUM(claim_amount) AS total_ar
FROM bucketed
GROUP BY age_bucket
ORDER BY FIELD(age_bucket,'0-30','31-60','61-90','91-120','120+');

/* =============================================================
   5) Payer scorecard (TAT, denial rate, recovery %)
   ============================================================= */
WITH claim_stats AS (
  SELECT c.claim_id,
         c.payer_id,
         c.submission_date,
         MIN(p.payment_date) AS first_payment_date,
         SUM(p.paid_amount)  AS total_paid,
         SUM(p.adjustment_amount) AS total_adj
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.payer_id, c.submission_date
), denial_flags AS (
  SELECT c.claim_id, 1 AS has_denial
  FROM claims c
  JOIN denials d ON d.claim_id = c.claim_id
  GROUP BY c.claim_id
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

/* =============================================================
   6) Follow-up effectiveness
   ============================================================= */
-- Days to first follow-up since submission
WITH first_fu AS (
  SELECT c.claim_id,
         MIN(fu.followup_date) AS first_followup_date,
         c.submission_date
  FROM claims c
  JOIN follow_ups fu ON fu.claim_id = c.claim_id
  GROUP BY c.claim_id, c.submission_date
)
SELECT DATEDIFF(first_followup_date, submission_date) AS days_to_first_followup,
       COUNT(*) AS claim_count
FROM first_fu
GROUP BY DATEDIFF(first_followup_date, submission_date)
ORDER BY days_to_first_followup;

-- Follow-up outcomes distribution (latest outcome per claim)
WITH ranked AS (
  SELECT fu.claim_id, fu.outcome,
         ROW_NUMBER() OVER (PARTITION BY fu.claim_id ORDER BY fu.followup_date DESC, fu.followup_id DESC) AS rn
  FROM follow_ups fu
)
SELECT outcome, COUNT(*) AS claims
FROM ranked
WHERE rn = 1
GROUP BY outcome
ORDER BY claims DESC;

/* =============================================================
   7) Intermediate SQL patterns
   ============================================================= */
-- Claims with no payments posted
SELECT c.claim_id, c.claim_status, c.claim_amount
FROM claims c
LEFT JOIN payments p ON p.claim_id = c.claim_id
WHERE p.claim_id IS NULL
ORDER BY c.claim_amount DESC;

-- Claims with payments but still open balance
WITH bal AS (
  SELECT c.claim_id,
         c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) AS balance
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.claim_amount
)
SELECT b.claim_id, b.balance
FROM bal b
WHERE b.balance > 0
ORDER BY b.balance DESC;

-- Top CPT charges by frequency and revenue
SELECT cl.cpt,
       COUNT(*) AS line_count,
       SUM(cl.line_charge) AS total_charge
FROM claim_lines cl
GROUP BY cl.cpt
ORDER BY total_charge DESC, line_count DESC;

/* =============================================================
   8) Quality checks & troubleshooting
   ============================================================= */
-- Header vs. lines consistency (expect some tiny differences acceptable in synthetic data)
SELECT c.claim_id,
       c.claim_amount AS header_amount,
       SUM(cl.line_charge) AS lines_sum,
       (SUM(cl.line_charge) - c.claim_amount) AS diff
FROM claims c
JOIN claim_lines cl ON cl.claim_id = c.claim_id
GROUP BY c.claim_id, c.claim_amount
HAVING ABS(SUM(cl.line_charge) - c.claim_amount) > 0.01
ORDER BY ABS(diff) DESC;

-- Negative payments or adjustments (should be none in seed)
SELECT * FROM payments WHERE paid_amount < 0 OR adjustment_amount < 0;

-- Denials linked to claims that are fully paid (valid but interesting)
WITH paid_full AS (
  SELECT c.claim_id
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.claim_amount
  HAVING c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) = 0
)
SELECT d.*
FROM denials d
JOIN paid_full pf ON pf.claim_id = d.claim_id
ORDER BY d.claim_id, d.denial_date;

/* =============================================================
   9) Ready-made views you can persist (optional)
   ============================================================= */
-- Uncomment to create material views for convenience
-- CREATE OR REPLACE VIEW vw_claim_balances AS
-- WITH balances AS (
--   SELECT c.claim_id,
--          c.payer_id,
--          c.claim_status,
--          c.submission_date,
--          c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) AS balance
--   FROM claims c
--   LEFT JOIN payments p ON p.claim_id = c.claim_id
--   GROUP BY c.claim_id, c.payer_id, c.submission_date, c.claim_status, c.claim_amount
-- )
-- SELECT * FROM balances;

-- CREATE OR REPLACE VIEW vw_aging AS
-- WITH base AS (
--   SELECT c.claim_id, c.claim_amount,
--          DATEDIFF(CURDATE(), c.submission_date) AS age_days
--   FROM claims c
-- ), bucketed AS (
--   SELECT claim_id, claim_amount, age_days,
--          CASE
--            WHEN age_days <= 30 THEN '0-30'
--            WHEN age_days <= 60 THEN '31-60'
--            WHEN age_days <= 90 THEN '61-90'
--            WHEN age_days <= 120 THEN '91-120'
--            ELSE '120+'
--          END AS age_bucket
--   FROM base
-- )
-- SELECT age_bucket, COUNT(*) AS claim_count, SUM(claim_amount) AS total_ar
-- FROM bucketed
-- GROUP BY age_bucket
-- ORDER BY FIELD(age_bucket,'0-30','31-60','61-90','91-120','120+');

-- CREATE OR REPLACE VIEW vw_payer_scorecard AS
-- WITH claim_stats AS (
--   SELECT c.claim_id, c.payer_id, c.submission_date,
--          MIN(p.payment_date) AS first_payment_date,
--          SUM(p.paid_amount) AS total_paid,
--          SUM(p.adjustment_amount) AS total_adj
--   FROM claims c
--   LEFT JOIN payments p ON p.claim_id = c.claim_id
--   GROUP BY c.claim_id, c.payer_id, c.submission_date
-- ), denial_flags AS (
--   SELECT d.claim_id, 1 AS has_denial
--   FROM denials d
--   GROUP BY d.claim_id
-- )
-- SELECT py.payer_name,
--        COUNT(cs.claim_id) AS claims_submitted,
--        ROUND(AVG(CASE WHEN cs.first_payment_date IS NOT NULL
--                       THEN DATEDIFF(cs.first_payment_date, cs.submission_date) END),1) AS avg_TAT_days,
--        ROUND(AVG(IF(df.has_denial=1,1,0))*100,1) AS denial_rate_pct,
--        ROUND(SUM(cs.total_paid)/NULLIF(SUM(c.claim_amount),0)*100,1) AS recovery_pct
-- FROM claim_stats cs
-- JOIN claims c  ON c.claim_id = cs.claim_id
-- JOIN payers py ON py.payer_id = c.payer_id
-- LEFT JOIN denial_flags df ON df.claim_id = c.claim_id
-- GROUP BY py.payer_name
-- ORDER BY recovery_pct DESC, avg_TAT_days ASC;

/* =============================================================
   10) Portfolio prompts (build & save your answers)
   ============================================================= */
-- A) Oldest high-value open claims (balance>0) with payer & last follow-up
WITH balances AS (
  SELECT c.claim_id, c.payer_id, c.submission_date,
         c.claim_amount - IFNULL(SUM(p.paid_amount),0) - IFNULL(SUM(p.adjustment_amount),0) AS balance
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.payer_id, c.submission_date, c.claim_amount
), last_fu AS (
  SELECT fu.claim_id, MAX(fu.followup_date) AS last_followup
  FROM follow_ups fu
  GROUP BY fu.claim_id
)
SELECT b.claim_id, py.payer_name, b.submission_date, b.balance, l.last_followup
FROM balances b
JOIN payers py ON py.payer_id = b.payer_id
LEFT JOIN last_fu l ON l.claim_id = b.claim_id
WHERE b.balance > 0
ORDER BY b.submission_date ASC, b.balance DESC
LIMIT 15;

-- B) Denial overturn rate by payer (Overturned / total denials)
WITH d AS (
  SELECT c.payer_id,
         SUM(CASE WHEN denial_status='Overturned' THEN 1 ELSE 0 END) AS overturned,
         COUNT(*) AS total_denials
  FROM denials d
  JOIN claims c ON c.claim_id = d.claim_id
  GROUP BY c.payer_id
)
SELECT py.payer_name,
       overturned,
       total_denials,
       ROUND(overturned/NULLIF(total_denials,0)*100,1) AS overturn_rate_pct
FROM d
JOIN payers py ON py.payer_id = d.payer_id
ORDER BY overturn_rate_pct DESC;

-- C) First-touch follow-up SLA: % of claims touched within 14 days
WITH first_fu AS (
  SELECT c.claim_id, c.submission_date, MIN(fu.followup_date) AS first_fu
  FROM claims c
  LEFT JOIN follow_ups fu ON fu.claim_id = c.claim_id
  GROUP BY c.claim_id, c.submission_date
)
SELECT ROUND(AVG(CASE WHEN first_fu IS NOT NULL AND DATEDIFF(first_fu, submission_date) <= 14 THEN 1 ELSE 0 END)*100,1) AS pct_touched_14d
FROM first_fu;
