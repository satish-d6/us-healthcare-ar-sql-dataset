-- SAMPLE DATA (synthetic) for US Healthcare AR

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE follow_ups;
TRUNCATE TABLE denials;
TRUNCATE TABLE payments;
TRUNCATE TABLE claim_lines;
TRUNCATE TABLE claims;
TRUNCATE TABLE payers;
TRUNCATE TABLE providers;
TRUNCATE TABLE patients;
SET FOREIGN_KEY_CHECKS = 1;

-- patients
INSERT INTO patients (patient_id, first_name, last_name, dob, gender) VALUES
  (1, 'Ava', 'Patel', '1989-03-15', 'F'),
  (2, 'Liam', 'Johnson', '1984-11-02', 'M'),
  (3, 'Olivia', 'Garcia', '1992-07-21', 'F'),
  (4, 'Ethan', 'Williams', '1978-01-30', 'M'),
  (5, 'Mia', 'Davis', '1995-05-05', 'F'),
  (6, 'Noah', 'Brown', '1988-08-18', 'M'),
  (7, 'Sophia', 'Wilson', '1975-12-09', 'F'),
  (8, 'Mason', 'Taylor', '1990-02-26', 'M'),
  (9, 'Isabella', 'Anderson', '1982-06-12', 'F'),
  (10, 'Lucas', 'Thomas', '1996-09-23', 'M'),
  (11, 'Ella', 'Moore', '1993-04-08', 'F'),
  (12, 'James', 'Martin', '1979-10-14', 'M');

-- providers
INSERT INTO providers (provider_id, provider_name, npi, specialty) VALUES
  (1, 'Green Valley Clinic', '1234567890', 'Family Medicine'),
  (2, 'Sunrise Orthopedics', '2345678901', 'Orthopedics'),
  (3, 'Harmony Cardiology', '3456789012', 'Cardiology'),
  (4, 'North Star Imaging', '4567890123', 'Radiology'),
  (5, 'River Health Pediatrics', '5678901234', 'Pediatrics'),
  (6, 'PrimeCare Internal Med', '6789012345', 'Internal Medicine');

-- payers
INSERT INTO payers (payer_id, payer_name, plan_type) VALUES
  (1, 'Aetna', 'Commercial'),
  (2, 'UnitedHealthcare', 'Commercial'),
  (3, 'Cigna', 'Commercial'),
  (4, 'Medicare', 'Medicare'),
  (5, 'Medicaid', 'Medicaid'),
  (6, 'Blue Cross Blue Shield', 'Commercial');

-- claims
-- Current date assumed 2026-03-11 for aging context.
INSERT INTO claims (claim_id, patient_id, provider_id, payer_id, service_date, submission_date, claim_amount, claim_status) VALUES
  -- 0–30 days
  (1,  1, 1, 1, '2026-02-25', '2026-03-01',  440.00, 'Pending'),
  (2,  2, 3, 3, '2026-02-18', '2026-02-20',  780.00, 'Partial Paid'),
  (3,  3, 4, 2, '2026-01-31', '2026-02-05',  295.00, 'Paid'),

  -- 31–60 days
  (4,  4, 6, 5, '2026-01-12', '2026-01-25',  650.00, 'Denied'),
  (5,  5, 2, 6, '2026-01-05', '2026-01-10',  540.00, 'Partial Paid'),
  (6,  6, 1, 1, '2026-01-01', '2026-01-15',  400.00, 'Paid'),

  -- 61–90 days
  (7,  7, 5, 5, '2025-12-05', '2025-12-10',  1300.00, 'Denied'),
  (8,  8, 1, 2, '2025-12-15', '2025-12-20',  320.00, 'Pending'),
  (9,  9, 6, 4, '2025-12-01', '2025-12-12',  850.00, 'Paid'),

  -- 91–120 days
  (10, 10, 3, 3, '2025-11-10', '2025-11-20',  375.00, 'Partial Paid'),
  (11, 11, 4, 4, '2025-11-01', '2025-11-15',  1045.00, 'Paid'),

  -- 120+ days
  (12, 12, 2, 1, '2025-09-05', '2025-09-12',  1560.00, 'Paid'),
  (13,  3, 5, 5, '2025-10-01', '2025-10-05',  410.00, 'Denied'),
  (14,  2, 4, 4, '2025-10-05', '2025-10-18',  500.00, 'Partial Paid'),
  (15,  4, 3, 3, '2025-10-10', '2025-10-20',  1050.00, 'Paid');

-- claim_lines (sum ≈ claim_amount per claim)
INSERT INTO claim_lines (line_id, claim_id, cpt, units, line_charge) VALUES
  -- Claim 1: 440
  (1, 1, '99214', 1, 180.00),
  (2, 1, '80050', 1, 200.00),
  (3, 1, 'J1100', 1, 60.00),

  -- Claim 2: 780
  (4, 2, '70450', 1, 650.00),
  (5, 2, '97110', 2, 130.00),

  -- Claim 3: 295
  (6, 3, '93000', 1, 140.00),
  (7, 3, '99213', 1, 120.00),
  (8, 3, 'J1100', 1, 35.00),

  -- Claim 4: 650
  (9, 4, '70450', 1, 650.00),

  -- Claim 5: 540
  (10, 5, '97110', 2, 170.00),
  (11, 5, '80050', 1, 200.00),
  (12, 5, '99214', 1, 170.00),

  -- Claim 6: 400
  (13, 6, '80050', 2, 400.00),

  -- Claim 7: 1300
  (14, 7, '70450', 2, 1300.00),

  -- Claim 8: 320
  (15, 8, '99213', 1, 120.00),
  (16, 8, '80050', 1, 200.00),

  -- Claim 9: 850
  (17, 9, '70450', 1, 650.00),
  (18, 9, '99214', 1, 200.00),

  -- Claim 10: 375
  (19, 10, '80050', 1, 200.00),
  (20, 10, '99213', 1, 120.00),
  (21, 10, 'J1100', 1, 55.00),

  -- Claim 11: 1045
  (22, 11, '70450', 1, 650.00),
  (23, 11, '80050', 1, 200.00),
  (24, 11, '99214', 1, 195.00),

  -- Claim 12: 1560
  (25, 12, '70450', 2, 1300.00),
  (26, 12, '99214', 1, 260.00),

  -- Claim 13: 410
  (27, 13, '80050', 1, 200.00),
  (28, 13, '99214', 1, 210.00),

  -- Claim 14: 500
  (29, 14, '80050', 1, 200.00),
  (30, 14, '99214', 1, 180.00),
  (31, 14, '97110', 1, 120.00),

  -- Claim 15: 1050
  (32, 15, '70450', 1, 650.00),
  (33, 15, '80050', 2, 400.00);

-- payments (include partials and adjustments; ensure totals align with statuses)
INSERT INTO payments (payment_id, claim_id, payment_date, paid_amount, adjustment_amount, payment_ref) VALUES
  -- Claim 2 (Partial): paid 450 + adj 0, remaining 330 open
  (1, 2, '2026-03-05', 450.00, 0.00, 'PMT0002-1'),

  -- Claim 3 (Paid): paid 295 fully
  (2, 3, '2026-02-20', 295.00, 0.00, 'PMT0003-1'),

  -- Claim 5 (Partial): paid 300 + adj 100, remaining 140 open
  (3, 5, '2026-02-05', 300.00, 0.00, 'PMT0005-1'),
  (4, 5, '2026-02-25', 0.00, 100.00, 'ADJ0005'),

  -- Claim 6 (Paid): paid 400 fully
  (5, 6, '2026-02-10', 400.00, 0.00, 'PMT0006-1'),

  -- Claim 8 (Pending): no payment

  -- Claim 9 (Paid): two payments totaling 850
  (6, 9, '2026-01-10', 500.00, 0.00, 'PMT0009-1'),
  (7, 9, '2026-01-25', 350.00, 0.00, 'PMT0009-2'),

  -- Claim 10 (Partial): paid 250; no adj; 125 open
  (8, 10, '2026-01-15', 250.00, 0.00, 'PMT0010-1'),

  -- Claim 11 (Paid): mix paid + small adjustment
  (9, 11, '2026-01-05', 900.00, 0.00, 'PMT0011-1'),
  (10, 11, '2026-01-20', 100.00, 45.00, 'PMT0011-2'),

  -- Claim 12 (Paid): paid 1560
  (11, 12, '2025-10-15', 1560.00, 0.00, 'PMT0012-1'),

  -- Claim 14 (Partial): paid 300, adj 100; 100 open
  (12, 14, '2025-12-10', 300.00, 0.00, 'PMT0014-1'),
  (13, 14, '2026-01-12', 0.00, 100.00, 'ADJ0014'),

  -- Claim 15 (Paid): paid 1050
  (14, 15, '2025-11-30', 1050.00, 0.00, 'PMT0015-1');

-- denials (for Denied/Partial/Pending claims)
INSERT INTO denials (denial_id, claim_id, denial_date, denial_code, denial_reason, denial_status) VALUES
  -- Claim 1 Pending: info missing
  (1, 1, '2026-03-05', 'CO-16', 'Claim/service lacks information or has submission/billing error.', 'Open'),

  -- Claim 2 Partial: level of service, later overturned
  (2, 2, '2026-02-28', 'CO-151', 'Payer deems info does not support this level of service.', 'Overturned'),

  -- Claim 4 Denied: medical necessity
  (3, 4, '2026-02-05', 'CO-50', 'Not deemed a medical necessity.', 'Appealed'),

  -- Claim 5 Partial: bundled
  (4, 5, '2026-01-20', 'CO-97', 'Payment included in another service/procedure.', 'Open'),

  -- Claim 7 Denied: deductible or policy
  (5, 7, '2026-01-05', 'PR-1', 'Deductible Amount.', 'Upheld'),

  -- Claim 8 Pending: under review
  (6, 8, '2026-01-02', 'CO-16', 'Additional documentation requested.', 'Open'),

  -- Claim 10 Partial: medical records requested
  (7, 10, '2026-01-05', 'CO-16', 'Medical records required for review.', 'Open'),

  -- Claim 13 Denied: non-covered
  (8, 13, '2025-11-01', 'CO-50', 'Non-covered service.', 'Upheld');

-- follow_ups (AR rep actions)
INSERT INTO follow_ups (followup_id, claim_id, followup_date, action, outcome, notes) VALUES
  (1, 1, '2026-03-06', 'Check Portal', 'Pending Review', 'Portal shows additional info required'),
  (2, 1, '2026-03-09', 'Requested Medical Records', 'No Response', 'Faxed clinic notes'),

  (3, 2, '2026-02-25', 'Call Payer', 'Resolved', 'Denial overturned per supervisor'),
  (4, 2, '2026-03-04', 'Check Portal', 'Paid', 'Partial payment posted'),

  (5, 4, '2026-02-10', 'Appeal Filed', 'Appeal in Progress', 'Submitted medical necessity letter'),

  (6, 5, '2026-01-25', 'Resubmitted', 'Pending Review', 'Corrected coding and resubmitted'),

  (7, 7, '2026-01-15', 'Call Payer', 'P2P Scheduled', 'Peer-to-peer setup'),

  (8, 8, '2026-01-05', 'Requested Medical Records', 'No Response', 'Requested EOB and OP notes'),

  (9, 10, '2026-01-18', 'Check Portal', 'Pending Review', 'Awaiting clinical review'),
  (10, 10, '2026-02-05', 'Call Payer', 'No Response', 'Left voicemail'),

  (11, 11, '2026-01-10', 'Check Portal', 'Resolved', 'Short pay adjustment posted'),

  (12, 13, '2025-11-05', 'Appeal Filed', 'Upheld', 'Non-covered benefit confirmed'),

  (13, 14, '2025-12-20', 'Resubmitted', 'Pending Review', 'Sent corrected claim'),
  (14, 14, '2026-01-15', 'Call Payer', 'No Response', 'Follow-up planned'),

  (15, 15, '2025-11-25', 'Check Portal', 'Paid', 'Payment posted');
