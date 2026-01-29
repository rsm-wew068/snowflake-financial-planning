#!/bin/bash
# Load test data into Snowflake

echo "=========================================="
echo "Loading Test Data"
echo "=========================================="
echo ""

# Get credentials
read -p "Account name (KBVUCBE-OZB10247): " ACCOUNT
ACCOUNT=${ACCOUNT:-KBVUCBE-OZB10247}

read -p "Username (WEW068): " USERNAME
USERNAME=${USERNAME:-WEW068}

read -sp "Password: " PASSWORD
echo ""
echo ""

# Create temporary config file
TEMP_CONFIG=$(mktemp)
cat > "$TEMP_CONFIG" << EOF
[connections.temp]
accountname = $ACCOUNT
username = $USERNAME
password = $PASSWORD
dbname = BUDGET_PLANNING
schemaname = Planning
warehousename = COMPUTE_WH
EOF

SNOWSQL="/Applications/SnowSQL.app/Contents/MacOS/snowsql"

echo "Loading test data..."
echo ""

$SNOWSQL -c temp --config "$TEMP_CONFIG" << 'EOF'

-- ============================================================================
-- Test Data for Budget Consolidation
-- ============================================================================

-- Insert fiscal periods
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
    1,
    3,
    'APPROVED'
);

-- Insert budget line items
INSERT INTO Planning.BudgetLineItem (
    BudgetHeaderID, GLAccountID, CostCenterID, FiscalPeriodID,
    OriginalAmount, AdjustedAmount, FinalAmount
)
VALUES 
    -- Division A, Dept A1
    (1, 1, 4, 1, 50000, 0, 50000),
    (1, 4, 4, 1, 100000, 0, 100000),
    (1, 5, 4, 1, 30000, 0, 30000),
    
    -- Division A, Dept A2
    (1, 1, 5, 1, 30000, 0, 30000),
    (1, 4, 5, 1, 80000, 0, 80000),
    (1, 5, 5, 1, 25000, 0, 25000),
    
    -- Division B
    (1, 1, 3, 1, 40000, 0, 40000),
    (1, 4, 3, 1, 90000, 0, 90000),
    (1, 5, 3, 1, 28000, 0, 28000),
    
    -- Intercompany entries (should eliminate)
    (1, 5, 4, 1, 10000, 0, 10000),
    (1, 6, 3, 1, -10000, 0, -10000);

-- Update computed columns
CALL Planning.UpdateComputedColumns();

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

EOF

# Clean up
rm -f "$TEMP_CONFIG"

echo ""
echo "=========================================="
echo "✅ Test Data Loaded!"
echo "=========================================="
echo ""
echo "Data Summary:"
echo "  - 3 Fiscal Periods (Jan-Mar 2024)"
echo "  - 6 GL Accounts (including 2 intercompany)"
echo "  - 5 Cost Centers (3-level hierarchy)"
echo "  - 1 Budget Header (APPROVED status)"
echo "  - 11 Budget Line Items"
echo ""
echo "Next step: Test the stored procedure"
echo "  ./test-procedure.sh"
echo ""
