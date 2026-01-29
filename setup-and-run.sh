#!/bin/bash
# Complete setup script - runs everything in one go

set -e  # Exit on error

echo "=========================================="
echo "Snowflake Migration - Complete Setup"
echo "=========================================="
echo ""

# Check if SnowSQL is installed
if [ ! -f "/Applications/SnowSQL.app/Contents/MacOS/snowsql" ]; then
    echo "❌ SnowSQL not found!"
    echo "Please run: sudo installer -pkg snowsql-1.3.1-darwin_arm64.pkg -target /"
    exit 1
fi

echo "✅ SnowSQL is installed"
echo ""

# Get connection details
echo "Enter your Snowflake connection details:"
echo ""
read -p "Account name (e.g., abc123.us-east-1): " ACCOUNT
read -p "Username: " USERNAME
read -sp "Password: " PASSWORD
echo ""
echo ""

SNOWSQL="/Applications/SnowSQL.app/Contents/MacOS/snowsql"

# Use environment variable for password to avoid special character issues
export SNOWSQL_PWD="$PASSWORD"

echo "Step 1: Testing connection..."
$SNOWSQL -a "$ACCOUNT" -u "$USERNAME" -q "SELECT 'Connected!' AS status;" > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Connection failed! Please check your credentials."
    exit 1
fi

echo "✅ Connection successful!"
echo ""

echo "Step 2: Creating database and schema..."
$SNOWSQL -a "$ACCOUNT" -u "$USERNAME" -p "$PASSWORD" << 'EOF'
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
$SNOWSQL -a "$ACCOUNT" -u "$USERNAME" -p "$PASSWORD" \
    -d BUDGET_PLANNING -s Planning -w COMPUTE_WH \
    -f snowflake-migration/schema/01_tables.sql

echo "✅ Tables created!"
echo ""

echo "Step 4: Creating stored procedure..."
$SNOWSQL -a "$ACCOUNT" -u "$USERNAME" -p "$PASSWORD" \
    -d BUDGET_PLANNING -s Planning -w COMPUTE_WH \
    -f snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql

echo "✅ Stored procedure created!"
echo ""

echo "Step 5: Verifying setup..."
$SNOWSQL -a "$ACCOUNT" -u "$USERNAME" -p "$PASSWORD" \
    -d BUDGET_PLANNING -s Planning -w COMPUTE_WH << 'EOF'
SHOW TABLES IN SCHEMA Planning;
SHOW PROCEDURES IN SCHEMA Planning;
EOF

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
echo "To connect interactively:"
echo "  ./run-snowsql.sh -a $ACCOUNT -u $USERNAME -d BUDGET_PLANNING -s Planning -w COMPUTE_WH"
echo ""
