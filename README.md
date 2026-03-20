# US Healthcare AR SQL Dataset + 7‑Day Learning Plan

Practice **real US Healthcare Accounts Receivable (AR)** analytics using SQL — no local install needed.  
This project includes a relational schema (claims, lines, denials, payments, follow-ups, payers, patients, providers), realistic sample data, practice queries, and a **7‑day, 2‑hours/day** learning plan.

> 💡 Built by **Satish** to learn, practice, and showcase **SQL + Healthcare AR analytics**.

---

## 🔗 Quick Start

- **Run instantly on DB Fiddle (MySQL) (https://www.db-fiddle.com/):**
  1. Paste `sql/schema.sql` in Schema SQL window
  2. Paste `sql/sample-data.sql` in Schema SQL window
  3. Run queries from `sql/practice-queries.sql` in Query SQL window 

- **Local (MySQL):**
  ```bash
  # 1) Start MySQL and log in
  mysql -u root -p

  # 2) Create DB and use it
  CREATE DATABASE ar_sql;
  USE ar_sql;

  # 3) Load schema and data (from your shell/terminal)
  mysql -u root -p ar_sql < sql/schema.sql
  mysql -u root -p ar_sql < sql/sample-data.sql


📁 Repository Structure
    
us-healthcare-ar-sql-dataset/  
│  
├── README.md  
├── sql/  
│   ├── schema.sql             # Tables + constraints + indexes (MySQL)  
│   ├── sample-data.sql        # Synthetic, realistic test data  
│   ├── practice-queries.sql   # Copy-ready queries from this README  
│  
├── learning-plan/  
│   ├── 7-day-plan.md          # Beginner → Intermediate in 7 days  
│  
└── screenshots/  
    └── dbfiddle-screenshot.png  


🩺 What This Simulates (Real AR Use-Cases)

- Claim → Line → Payment/Denial lifecycle
- Denial analytics (top denial codes, avoidable write-offs, appeal candidates)
- AR aging (0–30, 31–60, 61–90, 91–120, 120+)
- Payer behavior (TAT, denial rate, recovery %)
- Follow-up effectiveness (follow-up lag, promise-to-pay validation)


🧩 Schema Overview (MySQL)
Core Entities

* patients — demographics
* providers — rendering/billing providers
* payers — insurance companies
* claims — header-level claim info
* claim_lines — CPT/HCPCS/units/charge
* payments — remit/payments (can be multiple per claim)
* denials — denials (CARC/RARC, reason, status)
* follow_ups — AR representative activities

Key Relationships

* patients (1) — (M) claims
* providers (1) — (M) claims
* payers (1) — (M) claims
* claims (1) — (M) claim_lines
* claims (1) — (M) payments
* claims (1) — (M) denials
* claims (1) — (M) follow_ups


erDiagram
  patients ||--o{ claims : has
  providers ||--o{ claims : bills
  payers ||--o{ claims : covers
  claims ||--o{ claim_lines : contains
  claims ||--o{ payments : receives
  claims ||--o{ denials : may_have
  claims ||--o{ follow_ups : tracked_by

  patients {
    int patient_id PK
    string first_name
    string last_name
    date dob
    string gender
  }

  providers {
    int provider_id PK
    string provider_name
    string npi
    string specialty
  }

  payers {
    int payer_id PK
    string payer_name
    string plan_type
  }

  claims {
    int claim_id PK
    int patient_id FK
    int provider_id FK
    int payer_id FK
    date service_date
    date submission_date
    decimal claim_amount
    string claim_status
  }

  claim_lines {
    int line_id PK
    int claim_id FK
    string cpt
    int units
    decimal line_charge
  }

  payments {
    int payment_id PK
    int claim_id FK
    date payment_date
    decimal paid_amount
    decimal adjustment_amount
    string payment_ref
  }

  denials {
    int denial_id PK
    int claim_id FK
    date denial_date
    string denial_code
    string denial_reason
    string denial_status
  }

  follow_ups {
    int followup_id PK
    int claim_id FK
    date followup_date
    string action
    string outcome
    string notes
  }


📋 Table Descriptions (High-Level)

* patients — minimal PHI-like fields (synthetic) for joining
* providers — NPI-style identifiers and specialty
* payers — insurance plans (Commercial, Medicare, Medicaid, etc.)
* claims — header: dates, amounts, status (Pending, Denied, Paid, Partial Paid)
* claim_lines — procedural details (CPT, units, charge)
* payments — paid + adjustments across one/many remits
* denials — denial codes/reasons; status (Open, Appealed, Overturned, Upheld)
* follow_ups — AR rep touchpoints with action & outcome


🎓 7‑Day Learning Plan (2 hrs/day)

Full version in learning-plan/7-day-plan.md.


Day 1 — Setup, understand tables & relationships
Day 2 — SELECT, WHERE, ORDER BY, LIMIT
Day 3 — JOINs (claims↔lines, claims↔payments, claims↔denials)
Day 4 — GROUP BY, aggregations, HAVING
Day 5 — Real AR scenarios: top denials, pending high-value, oldest claims
Day 6 — CTEs, CASE, window functions (if using MySQL 8+)
Day 7 — Build 3 portfolio reports (Aging, Denials, Payer scorecard) and commit SQL    


🧪 Data Notes

* All data is synthetic and for educational purposes only.
* Denial codes are simplified; map to CARC/RARC style patterns for realism.
* Monetary fields use DECIMAL(10,2). Dates are spread to enable aging logic. 

⚙️ Performance (Optional)
Recommended indexes (if your dataset grows):
    
CREATE INDEX idx_claims_payer ON claims(payer_id);
CREATE INDEX idx_claims_submission_date ON claims(submission_date);
CREATE INDEX idx_payments_claim ON payments(claim_id, payment_date);
CREATE INDEX idx_denials_claim ON denials(claim_id, denial_code);
CREATE INDEX idx_followups_claim ON follow_ups(claim_id, followup_date);


🤝 Contributing
PRs welcome! Ideas:

* More denial codes and payer-specific rules
* Appeal outcomes & overturn analytics
* Prior auth/eligibility tables
* KPI views (materialized by scheduler)
* Power BI or Looker Studio dashboards fed by this schema

    
📜 License
MIT — use and remix freely with attribution.

    
🙌 Acknowledgments
Thanks to the broader healthcare analytics community for inspiration around AR aging, denial management, and payer scorecards. This project is inspired by common revenue cycle practices and public documentation (e.g., CMS educational resources and general CARC/RARC code frameworks).




    

