# Quick Start Guide - Snowflake Migration

## Prerequisites

1. **Snowflake Account** (Free trial: https://signup.snowflake.com/)
2. **Snowflake CLI or Web UI** access
3. **Appropriate privileges** to create schemas, tables, and procedures

## Setup Steps (5 minutes)

### Step 1: Create Database and Schema

```sql
-- Create database (if needed)
CREATE DATABASE IF NOT EXISTS BUDGET_PLANNING;
USE DATABASE BUDGET_PLANNING;

-- Create schema
CREATE SCHEMA IF NOT EXISTS Planning;
USE SCHEMA Planning;
```

### Step 2: Create Tables

Copy and execute the entire contents of:
```
snowflake-migration/schema/01_tables.sql
```

This will create:
- FiscalPeriod
- GLAccount
- CostCenter (with history table)
- BudgetHeader
- BudgetLineItem
- Helper procedure for computed columns

### Step 3: Create the Stored Procedure

Copy and execute the entire contents of:
```
snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql
```

### Step 4: Load Test Data

```sql
-- Insert fiscal period
INSERT INTO Planning.FiscalPeriod (
    FiscalYear, FiscalQuarter, FiscalMonth, PeriodName, 
    PeriodStartDate, PeriodEndDate
)
VALUES 
    (2024, 1, 1, 'Jan 2024', '2024-01-01', '2024-01-31'),
    (2024, 1, 2, 'Feb 2024', '2024-02-01', '2024-02-29'),
    (2024, 1, 3, 'Mar 2024', '2024-03-01', '2024-03-31');

-- Insert GL accounts
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

-- Insert cost centers (hierarchy)
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
    1,  -- Jan
    3,  -- Mar
    'APPROVED'
);

-- Insert budget line items
INSERT INTO Planning.BudgetLineItem (
    BudgetHeaderID, GLAccountID, CostCenterID, FiscalPeriodID,
    OriginalAmount, AdjustedAmount, FinalAmount
)
VALUES 
    -- Division A, Dept A1
    (1, 1, 4, 1, 50000, 0, 50000),   -- Cash
    (1, 4, 4, 1, 100000, 0, 100000), -- Revenue
    (1, 5, 4, 1, 30000, 0, 30000),   -- Salaries
    
    -- Division A, Dept A2
    (1, 1, 5, 1, 30000, 0, 30000),   -- Cash
    (1, 4, 5, 1, 80000, 0, 80000),   -- Revenue
    (1, 5, 5, 1, 25000, 0, 25000),   -- Salaries
    
    -- Division B
    (1, 1, 3, 1, 40000, 0, 40000),   -- Cash
    (1, 4, 3, 1, 90000, 0, 90000),   -- Revenue
    (1, 5, 3, 1, 28000, 0, 28000),   -- Salaries
    
    -- Intercompany entries (should eliminate)
    (1, 5, 4, 1, 10000, 0, 10000),   -- IC Receivable from Div B
    (1, 6, 3, 1, -10000, 0, -10000); -- IC Payable to Div A

-- Update computed columns
CALL Planning.UpdateComputedColumns();
```

## Running the Procedure

### Basic Execution

```sql
-- Execute consolidation
CALL Planning.usp_ProcessBudgetConsolidation(
    SourceBudgetHeaderID => 1,
    ConsolidationType => 'FULL',
    IncludeEliminations => TRUE,
    RecalculateAllocations => TRUE,
    ProcessingOptions => NULL,
    UserID => 100,
    DebugMode => TRUE
);
```

### View Results

```sql
-- Check the result object (returned by procedure)
-- Look for: Success, TargetBudgetHeaderID, RowsProcessed

-- View created budget header
SELECT * 
FROM Planning.BudgetHeader 
WHERE BudgetType = 'CONSOLIDATED' 
ORDER BY BudgetHeaderID DESC 
LIMIT 1;

-- View consolidated line items
SELECT 
    bli.BudgetLineItemID,
    gla.AccountNumber,
    gla.AccountName,
    cc.CostCenterCode,
    cc.CostCenterName,
    fp.PeriodName,
    bli.FinalAmount
FROM Planning.BudgetLineItem bli
INNER JOIN Planning.GLAccount gla ON bli.GLAccountID = gla.GLAccountID
INNER JOIN Planning.CostCenter cc ON bli.CostCenterID = cc.CostCenterID
INNER JOIN Planning.FiscalPeriod fp ON bli.FiscalPeriodID = fp.FiscalPeriodID
WHERE bli.BudgetHeaderID = (
    SELECT MAX(BudgetHeaderID) 
    FROM Planning.BudgetHeader 
    WHERE BudgetType = 'CONSOLIDATED'
)
ORDER BY cc.HierarchyPath, gla.AccountNumber;
```

### Verify Results

```sql
-- Check row count
SELECT 
    'Total consolidated line items' AS metric,
    COUNT(*) AS value
FROM Planning.BudgetLineItem
WHERE BudgetHeaderID = (
    SELECT MAX(BudgetHeaderID) 
    FROM Planning.BudgetHeader 
    WHERE BudgetType = 'CONSOLIDATED'
);

-- Check amount totals by account
SELECT 
    gla.AccountNumber,
    gla.AccountName,
    SUM(bli.FinalAmount) AS TotalAmount
FROM Planning.BudgetLineItem bli
INNER JOIN Planning.GLAccount gla ON bli.GLAccountID = gla.GLAccountID
WHERE bli.BudgetHeaderID = (
    SELECT MAX(BudgetHeaderID) 
    FROM Planning.BudgetHeader 
    WHERE BudgetType = 'CONSOLIDATED'
)
GROUP BY gla.AccountNumber, gla.AccountName
ORDER BY gla.AccountNumber;

-- Verify hierarchy rollup
-- Corporate total should equal sum of all divisions
SELECT 
    cc.CostCenterCode,
    cc.CostCenterName,
    cc.HierarchyLevel,
    SUM(bli.FinalAmount) AS TotalAmount
FROM Planning.BudgetLineItem bli
INNER JOIN Planning.CostCenter cc ON bli.CostCenterID = cc.CostCenterID
WHERE bli.BudgetHeaderID = (
    SELECT MAX(BudgetHeaderID) 
    FROM Planning.BudgetHeader 
    WHERE BudgetType = 'CONSOLIDATED'
)
GROUP BY cc.CostCenterCode, cc.CostCenterName, cc.HierarchyLevel
ORDER BY cc.HierarchyPath;
```

## Expected Results

With the test data above, you should see:

1. **New budget header created**
   - BudgetCode: `B2024Q1_CONSOL_YYYYMMDD`
   - BudgetType: `CONSOLIDATED`
   - StatusCode: `DRAFT`

2. **Consolidated line items**
   - Multiple line items for each account/cost center/period combination
   - Hierarchy rollups included
   - Intercompany eliminations applied (if enabled)

3. **Amount totals**
   - Revenue: 270,000 (100k + 80k + 90k)
   - Salaries: 83,000 (30k + 25k + 28k)
   - Cash: 120,000 (50k + 30k + 40k)
   - Intercompany: 0 (eliminated)

## Troubleshooting

### Issue: Procedure not found
```sql
-- Check if procedure exists
SHOW PROCEDURES LIKE 'usp_ProcessBudgetConsolidation' IN SCHEMA Planning;

-- Recreate if needed
-- Re-run: snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql
```

### Issue: Table not found
```sql
-- Check if tables exist
SHOW TABLES IN SCHEMA Planning;

-- Recreate if needed
-- Re-run: snowflake-migration/schema/01_tables.sql
```

### Issue: Foreign key violation
```sql
-- Check data integrity
SELECT 'BudgetLineItem missing BudgetHeader' AS issue, COUNT(*) AS count
FROM Planning.BudgetLineItem bli
LEFT JOIN Planning.BudgetHeader bh ON bli.BudgetHeaderID = bh.BudgetHeaderID
WHERE bh.BudgetHeaderID IS NULL

UNION ALL

SELECT 'BudgetLineItem missing GLAccount', COUNT(*)
FROM Planning.BudgetLineItem bli
LEFT JOIN Planning.GLAccount gla ON bli.GLAccountID = gla.GLAccountID
WHERE gla.GLAccountID IS NULL;

-- Fix: Ensure test data is loaded in correct order (see Step 4)
```

### Issue: Procedure returns error
```sql
-- Check the error message in the return object
-- Look for: ErrorCode, ErrorMessage, FailedStep

-- Common issues:
-- 1. Source budget not in APPROVED/LOCKED status
UPDATE Planning.BudgetHeader 
SET StatusCode = 'APPROVED' 
WHERE BudgetHeaderID = 1;

-- 2. Source budget doesn't exist
SELECT * FROM Planning.BudgetHeader WHERE BudgetHeaderID = 1;
```

## Performance Monitoring

```sql
-- Check execution time
SELECT 
    QUERY_ID,
    QUERY_TEXT,
    EXECUTION_TIME / 1000 AS execution_seconds,
    ROWS_PRODUCED
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TEXT LIKE '%usp_ProcessBudgetConsolidation%'
  AND EXECUTION_STATUS = 'SUCCESS'
ORDER BY START_TIME DESC
LIMIT 5;

-- Check resource usage
SELECT 
    QUERY_ID,
    WAREHOUSE_SIZE,
    CREDITS_USED_CLOUD_SERVICES,
    BYTES_SCANNED,
    ROWS_PRODUCED
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TEXT LIKE '%usp_ProcessBudgetConsolidation%'
  AND EXECUTION_STATUS = 'SUCCESS'
ORDER BY START_TIME DESC
LIMIT 1;
```

## Cleanup

```sql
-- Remove test data
DELETE FROM Planning.BudgetLineItem WHERE BudgetHeaderID > 1;
DELETE FROM Planning.BudgetHeader WHERE BudgetHeaderID > 1;

-- Or drop everything and start over
DROP SCHEMA Planning CASCADE;
```

## Next Steps

1. ✅ Verify the procedure works with test data
2. ✅ Review the code and conversion notes
3. ✅ Run additional test cases (see verification_approach.md)
4. ✅ Test with larger datasets
5. ✅ Measure performance
6. ⏭️ Convert additional stored procedures (optional)

## Support Files

- **Full verification guide**: `snowflake-migration/testing/verification_approach.md`
- **AI usage explanation**: `AI_USAGE_EXPLANATION.md`
- **Migration strategy**: `MIGRATION_PLAN.md`
- **Deliverables summary**: `DELIVERABLES_SUMMARY.md`

---

**Estimated setup time: 5-10 minutes**  
**Estimated test execution time: < 1 minute**
