-- ============================================================================
-- Snowflake Screenshot Queries for Submission
-- Run these in Snowflake Web UI and take screenshots
-- ============================================================================

USE DATABASE BUDGET_PLANNING;
USE SCHEMA Planning;

-- ============================================================================
-- SCREENSHOT 1: Show all tables exist
-- ============================================================================
SHOW TABLES IN BUDGET_PLANNING.Planning;

-- ============================================================================
-- SCREENSHOT 2: Show procedure exists
-- ============================================================================
SHOW PROCEDURES LIKE 'usp_ProcessBudgetConsolidation';

-- ============================================================================
-- SCREENSHOT 3: Check what BudgetHeaders exist
-- ============================================================================
SELECT BudgetHeaderID, BudgetCode, BudgetName, BudgetType, StatusCode
FROM Planning.BudgetHeader
ORDER BY BudgetHeaderID;

-- ============================================================================
-- SCREENSHOT 4: Execute the procedure (use the correct BudgetHeaderID from above)
-- ============================================================================
-- If BudgetHeaderID = 7, use:
CALL Planning.usp_ProcessBudgetConsolidation(7);
-- If BudgetHeaderID = 1, use:
-- CALL Planning.usp_ProcessBudgetConsolidation(1);

-- ============================================================================
-- SCREENSHOT 5: Show the consolidated budget header was created
-- ============================================================================
SELECT 
    BudgetHeaderID,
    BudgetCode,
    BudgetName,
    BudgetType,
    StatusCode,
    CreatedDateTime
FROM Planning.BudgetHeader 
WHERE BudgetType = 'CONSOLIDATED' 
ORDER BY BudgetHeaderID DESC 
LIMIT 1;

-- ============================================================================
-- SCREENSHOT 6: Show consolidated amounts by account
-- ============================================================================
SELECT 
    g.AccountNumber,
    g.AccountName,
    SUM(bli.FinalAmount) as TotalAmount
FROM Planning.BudgetLineItem bli
JOIN Planning.BudgetHeader bh ON bli.BudgetHeaderID = bh.BudgetHeaderID
JOIN Planning.GLAccount g ON bli.GLAccountID = g.GLAccountID
WHERE bh.BudgetType = 'CONSOLIDATED'
GROUP BY g.AccountNumber, g.AccountName
ORDER BY g.AccountNumber;

-- ============================================================================
-- SCREENSHOT 7: Show consolidated amounts by cost center
-- ============================================================================
SELECT 
    cc.CostCenterCode,
    cc.CostCenterName,
    cc.HierarchyLevel,
    SUM(bli.FinalAmount) as TotalAmount
FROM Planning.BudgetLineItem bli
JOIN Planning.BudgetHeader bh ON bli.BudgetHeaderID = bh.BudgetHeaderID
JOIN Planning.CostCenter cc ON bli.CostCenterID = cc.CostCenterID
WHERE bh.BudgetType = 'CONSOLIDATED'
GROUP BY cc.CostCenterCode, cc.CostCenterName, cc.HierarchyLevel
ORDER BY cc.HierarchyLevel, cc.CostCenterCode;

-- ============================================================================
-- SCREENSHOT 8: Show all consolidated line items
-- ============================================================================
SELECT 
    bli.BudgetLineItemID,
    g.AccountNumber,
    g.AccountName,
    cc.CostCenterCode,
    cc.CostCenterName,
    bli.FinalAmount
FROM Planning.BudgetLineItem bli
JOIN Planning.BudgetHeader bh ON bli.BudgetHeaderID = bh.BudgetHeaderID
JOIN Planning.GLAccount g ON bli.GLAccountID = g.GLAccountID
JOIN Planning.CostCenter cc ON bli.CostCenterID = cc.CostCenterID
WHERE bh.BudgetType = 'CONSOLIDATED'
ORDER BY bli.BudgetLineItemID;
