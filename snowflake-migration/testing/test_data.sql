-- ============================================================================
-- Test Data for usp_ProcessBudgetConsolidation
-- ============================================================================
-- This script creates test data to verify the budget consolidation procedure
-- works correctly with hierarchy rollups and intercompany eliminations.

USE DATABASE BUDGET_PLANNING;
USE SCHEMA Planning;

-- ============================================================================
-- Insert Fiscal Periods
-- ============================================================================
INSERT INTO Planning.FiscalPeriod (
    FiscalYear, FiscalQuarter, FiscalMonth, PeriodName, 
    PeriodStartDate, PeriodEndDate
)
VALUES 
    (2024, 1, 1, 'Jan 2024', '2024-01-01', '2024-01-31'),
    (2024, 1, 2, 'Feb 2024', '2024-02-01', '2024-02-29'),
    (2024, 1, 3, 'Mar 2024', '2024-03-01', '2024-03-31');

-- ============================================================================
-- Insert GL Accounts
-- ============================================================================
-- Note: GLAccountID will be auto-assigned by AUTOINCREMENT
-- GLAccountID 1 = Cash (1000)
-- GLAccountID 2 = Accounts Payable (2000)
-- GLAccountID 3 = Revenue (4000)
-- GLAccountID 4 = Salaries (5000)
-- GLAccountID 5 = Intercompany Receivable (9000)
-- GLAccountID 6 = Intercompany Payable (9100)

INSERT INTO Planning.GLAccount (
    AccountNumber, AccountName, AccountType, NormalBalance, IntercompanyFlag
)
VALUES 
    ('1000', 'Cash', 'A', 'D', FALSE),
    ('2000', 'Accounts Payable', 'L', 'C', FALSE),
    ('4000', 'Revenue', 'R', 'C', FALSE),
    ('5000', 'Salaries', 'X', 'D', FALSE),
    ('9000', 'Intercompany Receivable', 'A', 'D', TRUE),
    ('9100', 'Intercompany Payable', 'L', 'C', TRUE);

-- ============================================================================
-- Insert Cost Centers (3-level hierarchy)
-- ============================================================================
-- CostCenterID 1 = Corporate (root)
-- CostCenterID 2 = Division A (child of Corporate)
-- CostCenterID 3 = Division B (child of Corporate)
-- CostCenterID 4 = Dept A1 (child of Division A)
-- CostCenterID 5 = Dept A2 (child of Division A)

INSERT INTO Planning.CostCenter (
    CostCenterCode, CostCenterName, ParentCostCenterID, 
    HierarchyPath, HierarchyLevel, EffectiveFromDate, IsActive
)
VALUES 
    ('CC001', 'Corporate', NULL, '/1/', 0, '2024-01-01', TRUE),
    ('CC010', 'Division A', 1, '/1/2/', 1, '2024-01-01', TRUE),
    ('CC020', 'Division B', 1, '/1/3/', 1, '2024-01-01', TRUE),
    ('CC011', 'Dept A1', 2, '/1/2/4/', 2, '2024-01-01', TRUE),
    ('CC012', 'Dept A2', 2, '/1/2/5/', 2, '2024-01-01', TRUE);

-- ============================================================================
-- Insert Budget Header
-- ============================================================================
INSERT INTO Planning.BudgetHeader (
    BudgetCode, BudgetName, BudgetType, ScenarioType, FiscalYear,
    StartPeriodID, EndPeriodID, StatusCode
)
VALUES (
    'B2024Q1', 
    'Budget 2024 Q1', 
    'ANNUAL', 
    'BASE', 
    2024,
    1,
    3,
    'APPROVED'
);

-- ============================================================================
-- Insert Budget Line Items
-- ============================================================================
-- IMPORTANT: Use correct GLAccountIDs based on the order inserted above
-- GLAccountID 1 = Cash (1000)
-- GLAccountID 3 = Revenue (4000)
-- GLAccountID 4 = Salaries (5000)
-- GLAccountID 5 = IC Receivable (9000)
-- GLAccountID 6 = IC Payable (9100)

INSERT INTO Planning.BudgetLineItem (
    BudgetHeaderID, GLAccountID, CostCenterID, FiscalPeriodID,
    OriginalAmount, AdjustedAmount, FinalAmount
)
VALUES 
    -- Division A, Dept A1 (CostCenterID = 4)
    (1, 1, 4, 1, 50000, 0, 50000),    -- Cash
    (1, 3, 4, 1, 100000, 0, 100000),  -- Revenue
    (1, 4, 4, 1, 30000, 0, 30000),    -- Salaries
    
    -- Division A, Dept A2 (CostCenterID = 5)
    (1, 1, 5, 1, 30000, 0, 30000),    -- Cash
    (1, 3, 5, 1, 80000, 0, 80000),    -- Revenue
    (1, 4, 5, 1, 25000, 0, 25000),    -- Salaries
    
    -- Division B (CostCenterID = 3)
    (1, 1, 3, 1, 40000, 0, 40000),    -- Cash
    (1, 3, 3, 1, 90000, 0, 90000),    -- Revenue
    (1, 4, 3, 1, 28000, 0, 28000),    -- Salaries
    
    -- Intercompany entries (should be tracked but not eliminated in this test)
    (1, 5, 4, 1, 10000, 0, 10000),    -- IC Receivable
    (1, 6, 3, 1, -10000, 0, -10000);  -- IC Payable

-- ============================================================================
-- Update Computed Columns
-- ============================================================================
CALL Planning.UpdateComputedColumns();

-- ============================================================================
-- Verify Test Data
-- ============================================================================
SELECT 'Test Data Summary' AS Info;

SELECT 'Fiscal Periods' AS DataType, COUNT(*) AS RecordCount 
FROM Planning.FiscalPeriod
UNION ALL
SELECT 'GL Accounts', COUNT(*) FROM Planning.GLAccount
UNION ALL
SELECT 'Cost Centers', COUNT(*) FROM Planning.CostCenter
UNION ALL
SELECT 'Budget Headers', COUNT(*) FROM Planning.BudgetHeader
UNION ALL
SELECT 'Budget Line Items', COUNT(*) FROM Planning.BudgetLineItem;

-- Show expected totals by account
SELECT 
    gla.AccountNumber,
    gla.AccountName,
    SUM(bli.FinalAmount) AS TotalAmount
FROM Planning.BudgetLineItem bli
INNER JOIN Planning.GLAccount gla ON bli.GLAccountID = gla.GLAccountID
WHERE bli.BudgetHeaderID = 1
GROUP BY gla.AccountNumber, gla.AccountName
ORDER BY gla.AccountNumber;

-- ============================================================================
-- Expected Results
-- ============================================================================
-- After running usp_ProcessBudgetConsolidation with BudgetHeaderID = 1:
--
-- Expected Consolidated Totals:
--   Cash (1000): 120,000 (50k + 30k + 40k)
--   Revenue (4000): 270,000 (100k + 80k + 90k)
--   Salaries (5000): 83,000 (30k + 25k + 28k)
--   IC Receivable (9000): 10,000
--   IC Payable (9100): -10,000
--
-- Expected Hierarchy Rollup:
--   Dept A1 (CC011): 190,000 (50k Cash + 100k Revenue + 30k Salaries + 10k IC)
--   Dept A2 (CC012): 135,000 (30k Cash + 80k Revenue + 25k Salaries)
--   Division B (CC020): 148,000 (40k Cash + 90k Revenue + 28k Salaries - 10k IC)
-- ============================================================================
