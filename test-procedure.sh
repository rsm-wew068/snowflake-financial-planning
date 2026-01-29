#!/bin/bash
# Test the stored procedure

echo "=========================================="
echo "Testing Stored Procedure"
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

echo "Running consolidation procedure..."
echo ""

$SNOWSQL -c temp --config "$TEMP_CONFIG" << 'EOF'

-- Call the procedure
CALL Planning.usp_ProcessBudgetConsolidation(
    SourceBudgetHeaderID => 1,
    ConsolidationType => 'FULL',
    IncludeEliminations => TRUE,
    RecalculateAllocations => TRUE,
    ProcessingOptions => NULL,
    UserID => 100,
    DebugMode => TRUE
);

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

-- Check amounts by account
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

EOF

# Clean up
rm -f "$TEMP_CONFIG"

echo ""
echo "=========================================="
echo "✅ Test Complete!"
echo "=========================================="
echo ""
echo "Review the results above to verify:"
echo "  1. New consolidated budget was created"
echo "  2. Line items were inserted"
echo "  3. Amounts are correct"
echo "  4. Hierarchy rollup worked"
echo ""
