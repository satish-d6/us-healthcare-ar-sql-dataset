-- SCHEMA for US Healthcare AR (MySQL 8.x)
-- Creates: patients, providers, payers, claims, claim_lines, payments, denials, follow_ups
-- Notes:
-- * Uses InnoDB and utf8mb4 for full compatibility
-- * Enumerations enforce valid statuses
-- * FK relationships with ON DELETE CASCADE for child tables (lab/demo convenience)

-- Optional: uncomment to create and use a DB
-- CREATE DATABASE IF NOT EXISTS ar_sql CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
-- USE ar_sql;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS follow_ups;
DROP TABLE IF EXISTS denials;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS claim_lines;
DROP TABLE IF EXISTS claims;
DROP TABLE IF EXISTS payers;
DROP TABLE IF EXISTS providers;
DROP TABLE IF EXISTS patients;

SET FOREIGN_KEY_CHECKS = 1;

-- Dimension tables
CREATE TABLE patients (
  patient_id   INT PRIMARY KEY,
  first_name   VARCHAR(100) NOT NULL,
  last_name    VARCHAR(100) NOT NULL,
  dob          DATE NOT NULL,
  gender       ENUM('M','F','O') NOT NULL DEFAULT 'O',
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE providers (
  provider_id   INT PRIMARY KEY,
  provider_name VARCHAR(200) NOT NULL,
  npi           VARCHAR(15)  NOT NULL,
  specialty     VARCHAR(100) NOT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_providers_npi (npi)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE payers (
  payer_id     INT PRIMARY KEY,
  payer_name   VARCHAR(200) NOT NULL,
  plan_type    ENUM('Commercial','Medicare','Medicaid') NOT NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_payers_name (payer_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Fact header
CREATE TABLE claims (
  claim_id         INT PRIMARY KEY,
  patient_id       INT NOT NULL,
  provider_id      INT NOT NULL,
  payer_id         INT NOT NULL,
  service_date     DATE NOT NULL,
  submission_date  DATE NOT NULL,
  claim_amount     DECIMAL(10,2) NOT NULL,
  claim_status     ENUM('Pending','Denied','Paid','Partial Paid') NOT NULL,
  created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_claims_patient  FOREIGN KEY (patient_id)  REFERENCES patients(patient_id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_claims_provider FOREIGN KEY (provider_id) REFERENCES providers(provider_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_claims_payer    FOREIGN KEY (payer_id)    REFERENCES payers(payer_id)      ON DELETE RESTRICT ON UPDATE CASCADE,

  KEY idx_claims_payer (payer_id),
  KEY idx_claims_patient (patient_id),
  KEY idx_claims_provider (provider_id),
  KEY idx_claims_submission_date (submission_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Detail lines
CREATE TABLE claim_lines (
  line_id     INT PRIMARY KEY,
  claim_id    INT NOT NULL,
  cpt         VARCHAR(10) NOT NULL,
  units       INT NOT NULL DEFAULT 1,
  line_charge DECIMAL(10,2) NOT NULL,
  created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_lines_claim FOREIGN KEY (claim_id) REFERENCES claims(claim_id) ON DELETE CASCADE ON UPDATE CASCADE,
  KEY idx_lines_claim (claim_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Payments/remits
CREATE TABLE payments (
  payment_id        INT PRIMARY KEY,
  claim_id          INT NOT NULL,
  payment_date      DATE NOT NULL,
  paid_amount       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  adjustment_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  payment_ref       VARCHAR(64) NOT NULL,
  created_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_payments_claim FOREIGN KEY (claim_id) REFERENCES claims(claim_id) ON DELETE CASCADE ON UPDATE CASCADE,
  KEY idx_payments_claim_date (claim_id, payment_date),
  KEY idx_payments_ref (payment_ref)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Denials
CREATE TABLE denials (
  denial_id     INT PRIMARY KEY,
  claim_id      INT NOT NULL,
  denial_date   DATE NOT NULL,
  denial_code   VARCHAR(20) NOT NULL,
  denial_reason VARCHAR(255) NOT NULL,
  denial_status ENUM('Open','Appealed','Upheld','Overturned') NOT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_denials_claim FOREIGN KEY (claim_id) REFERENCES claims(claim_id) ON DELETE CASCADE ON UPDATE CASCADE,
  KEY idx_denials_claim (claim_id),
  KEY idx_denials_code (denial_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- AR follow-ups/activities
CREATE TABLE follow_ups (
  followup_id  INT PRIMARY KEY,
  claim_id     INT NOT NULL,
  followup_date DATE NOT NULL,
  action       VARCHAR(100) NOT NULL,
  outcome      VARCHAR(100) NOT NULL,
  notes        VARCHAR(255) NULL,
  created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_followups_claim FOREIGN KEY (claim_id) REFERENCES claims(claim_id) ON DELETE CASCADE ON UPDATE CASCADE,
  KEY idx_followups_claim_date (claim_id, followup_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Helpful computed views (optional)
-- Example payer scorecard view; comment out if not needed.
/*
CREATE OR REPLACE VIEW vw_payer_scorecard AS
WITH claim_stats AS (
  SELECT c.claim_id, c.payer_id, c.submission_date,
         MIN(p.payment_date) AS first_payment_date,
         SUM(p.paid_amount) AS total_paid,
         SUM(p.adjustment_amount) AS total_adj
  FROM claims c
  LEFT JOIN payments p ON p.claim_id = c.claim_id
  GROUP BY c.claim_id, c.payer_id, c.submission_date
),
 denial_flags AS (
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
JOIN claims c ON c.claim_id = cs.claim_id
JOIN payers py ON py.payer_id = c.payer_id
LEFT JOIN denial_flags df ON df.claim_id = c.claim_id
GROUP BY py.payer_name;
*/
