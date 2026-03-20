
 7-Day, 2-Hours/Day SQL Learning Plan (US Healthcare AR)

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


```### Core queries

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

**### Stretch**







