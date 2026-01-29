-- Load test data into SQL Server
USE BUDGET_PLANNING
GO

-- Insert fiscal periods
INSERT INTO Planning.FiscalPeriod (
    FiscalYear, FiscalQuarter, FiscalMonth, PeriodName, 
    PeriodStartDate, PeriodEndDate
)
VALUES 
    (2024, 1, 1, 'Jan 2024', '2024-01-01', '2024-01-31'),
    (2024, 1, 2, 'Feb 2024', '2024-02-01', '2024-02-29'),
    (2024, 1, 3, 'Mar 2024', '2024-03-01', '2024-03-31');
GO

-- Insert GL accounts
INSERT INTO Planning.GLAccount (
    AccountNumber, AccountName, AccountType, NormalBalance, IntercompanyFlag
)
VALUES 
    ('1000', 'Cash', 'A', 'D', 0),
    ('2000', 'Accounts Payable', 'L', 'C', 0),
    ('4000', 'Revenue', 'R', 'C', 0),
    ('5000', 'Salaries', 'X', 'D', 0),
    ('9000', 'Intercompany Receivable', 'A', 'D', 1),
    ('9100', 'Intercompany Payable', 'L', 'C', 1);
GO

-- Insert cost centers (hierarchy)
INSERT INTO Planning.CostCenter (
    CostCenterCode, CostCenterName, ParentCostCenterID, 
    HierarchyPath, HierarchyLevel, EffectiveFromDate, IsActive
)
VALUES 
    ('CC001', 'Corporate', NULL, '/1/', 0, '2024-01-01', 1),
    ('CC010', 'Division A', 1, '/1/2/', 1, '2024-01-01', 1),
    ('CC020', 'Division B', 1, '/1/3/', 1, '2024-01-01', 1),
    ('CC011', 'Dept A1', 2, '/1/2/4/', 2, '2024-01-01', 1),
    ('CC012', 'Dept A2', 2, '/1/2/5/', 2, '2024-01-01', 1);
GO

-- Insert budget header
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
GO

-- Insert budget line items
-- NOTE: Using explicit GLAccountIDs based on insertion order
INSERT INTO Planning.BudgetLineItem (
    BudgetHeaderID, GLAccountID, CostCenterID, FiscalPeriodID,
    OriginalAmount, AdjustedAmount
)
VALUES 
    -- Division A, Dept A1 (CostCenterID = 4)
    (1, 1, 4, 1, 50000, 0),    -- Cash
    (1, 3, 4, 1, 100000, 0),   -- Revenue
    (1, 4, 4, 1, 30000, 0),    -- Salaries
    
    -- Division A, Dept A2 (CostCenterID = 5)
    (1, 1, 5, 1, 30000, 0),    -- Cash
    (1, 3, 5, 1, 80000, 0),    -- Revenue
    (1, 4, 5, 1, 25000, 0),    -- Salaries
    
    -- Division B (CostCenterID = 3)
    (1, 1, 3, 1, 40000, 0),    -- Cash
    (1, 3, 3, 1, 90000, 0),    -- Revenue
    (1, 4, 3, 1, 28000, 0),    -- Salaries
    
    -- Intercompany entries
    (1, 5, 4, 1, 10000, 0),    -- IC Receivable
    (1, 6, 3, 1, -10000, 0);   -- IC Payable
GO

-- Verify data loaded
SELECT 'Fiscal Periods' AS DataType, COUNT(*) AS RecordCount FROM Planning.FiscalPeriod
UNION ALL
SELECT 'GL Accounts', COUNT(*) FROM Planning.GLAccount
UNION ALL
SELECT 'Cost Centers', COUNT(*) FROM Planning.CostCenter
UNION ALL
SELECT 'Budget Headers', COUNT(*) FROM Planning.BudgetHeader
UNION ALL
SELECT 'Budget Line Items', COUNT(*) FROM Planning.BudgetLineItem;
GO

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
GO

PRINT 'Test data loaded successfully';
GO
