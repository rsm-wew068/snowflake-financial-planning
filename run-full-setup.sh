#!/bin/bash
# Complete setup using config file method (handles special characters)

set -e

echo "=========================================="
echo "Snowflake Migration - Complete Setup"
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

echo "Step 1: Testing connection..."
$SNOWSQL -c temp --config "$TEMP_CONFIG" -q "SELECT 'Connected!' AS status;" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Connection failed! Please check your credentials."
    rm -f "$TEMP_CONFIG"
    exit 1
fi

echo "✅ Connection successful!"
echo ""

echo "Step 2: Creating database and schema..."
$SNOWSQL -c temp --config "$TEMP_CONFIG" << 'EOF'
CREATE DATABASE IF NOT EXISTS BUDGET_PLANNING;
USE DATABASE BUDGET_PLANNING;
CREATE SCHEMA IF NOT EXISTS Planning;
USE SCHEMA Planning;

CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH 
    WAREHOUSE_SIZE = 'XSMALL' 
    AUTO_SUSPEND = 60 
    AUTO_RESUME = TRUE;
USE WAREHOUSE COMPUTE_WH;

SELECT 'Database and schema created!' AS status;
EOF

echo "✅ Database and schema created!"
echo ""

echo "Step 3: Creating tables..."
$SNOWSQL -c temp --config "$TEMP_CONFIG" \
    -f snowflake-migration/schema/01_tables_fixed.sql

echo "✅ Tables created!"
echo ""

echo "Step 4: Creating stored procedure..."
$SNOWSQL -c temp --config "$TEMP_CONFIG" \
    -f snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql

echo "✅ Stored procedure created!"
echo ""

echo "Step 5: Verifying setup..."
$SNOWSQL -c temp --config "$TEMP_CONFIG" << 'EOF'
SHOW TABLES IN SCHEMA Planning;
SHOW PROCEDURES IN SCHEMA Planning;
EOF

# Clean up
rm -f "$TEMP_CONFIG"

echo ""
echo "=========================================="
echo "✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Your Snowflake environment is ready!"
echo ""
echo "Tables created:"
echo "  - FiscalPeriod"
echo "  - GLAccount"
echo "  - CostCenter"
echo "  - BudgetHeader"
echo "  - BudgetLineItem"
echo ""
echo "Stored procedure created:"
echo "  - usp_ProcessBudgetConsolidation"
echo ""
echo "Next steps:"
echo "1. Load test data (see QUICK_START.md)"
echo "2. Test the procedure"
echo "3. Verify results"
echo ""
