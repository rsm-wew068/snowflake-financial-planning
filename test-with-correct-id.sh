#!/bin/bash
# Test procedure with correct BudgetHeaderID

echo "=========================================="
echo "Testing Procedure with Correct Data"
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

echo "Running consolidation procedure with BudgetHeaderID = 7..."
echo ""

$SNOWSQL -c temp --config "$TEMP_CONFIG" << 'EOF'

-- Call the procedure with the correct ID
CALL Planning.usp_ProcessBudgetConsolidation(
    SourceBudgetHeaderID => 7,
    ConsolidationType => 'FULL',
    IncludeEliminations => TRUE,
    RecalculateAllocations => TRUE,
    ProcessingOptions => NULL,
    UserID => 100,
    DebugMode => TRUE
);

SELECT '=== CONSOLIDATED BUDGET CREATED ===' AS Section;

-- Check created budget
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

SELECT '=== LINE ITEM COUNT ===' AS Section;

-- Check line item count
SELECT 
    'Total Line Items' AS Metric,
    COUNT(*) AS Value
FROM Planning.BudgetLineItem
WHERE BudgetHeaderID = (
    SELECT MAX(BudgetHeaderID) 
    FROM Planning.BudgetHeader 
    WHERE BudgetType = 'CONSOLIDATED'
);

SELECT '=== AMOUNTS BY ACCOUNT (CONSOLIDATED) ===' AS Section;

-- Check amounts by account in consolidated budget
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

SELECT '=== HIERARCHY ROLLUP ===' AS Section;

-- Check hierarchy rollup
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
GROUP BY cc.CostCenterCode, cc.CostCenterName, cc.HierarchyLevel, cc.HierarchyPath
ORDER BY cc.HierarchyPath;

SELECT '=== COMPARISON: SOURCE vs CONSOLIDATED ===' AS Section;

-- Compare source vs consolidated
SELECT 
    'SOURCE (ID 7)' AS BudgetType,
    gla.AccountNumber,
    gla.AccountName,
    SUM(bli.FinalAmount) AS TotalAmount
FROM Planning.BudgetLineItem bli
INNER JOIN Planning.GLAccount gla ON bli.GLAccountID = gla.GLAccountID
WHERE bli.BudgetHeaderID = 7
GROUP BY gla.AccountNumber, gla.AccountName
UNION ALL
SELECT 
    'CONSOLIDATED',
    gla.AccountNumber,
    gla.AccountName,
    SUM(bli.FinalAmount)
FROM Planning.BudgetLineItem bli
INNER JOIN Planning.GLAccount gla ON bli.GLAccountID = gla.GLAccountID
WHERE bli.BudgetHeaderID = (
    SELECT MAX(BudgetHeaderID) 
    FROM Planning.BudgetHeader 
    WHERE BudgetType = 'CONSOLIDATED'
)
GROUP BY gla.AccountNumber, gla.AccountName
ORDER BY AccountNumber, BudgetType;

EOF

# Clean up
rm -f "$TEMP_CONFIG"

echo ""
echo "=========================================="
echo "✅ Test Complete!"
echo "=========================================="
echo ""
echo "EXPECTED RESULTS:"
echo "  Cash (1000): 120,000"
echo "  Revenue (4000): 270,000"
echo "  Salaries (5000): 83,000"
echo "  IC Receivable (9000): 10,000"
echo "  IC Payable (9100): -10,000"
echo ""
echo "The consolidated budget should match the source budget"
echo "since we're consolidating a single budget with no eliminations."
echo ""
