#!/bin/bash
# Quick test script for Snowflake connection

echo "=========================================="
echo "Snowflake Connection Test"
echo "=========================================="
echo ""

# Check if SnowSQL is installed
if [ ! -f "/Applications/SnowSQL.app/Contents/MacOS/snowsql" ]; then
    echo "❌ SnowSQL not found!"
    echo "Please run the installation steps first."
    exit 1
fi

echo "✅ SnowSQL is installed (version: $(/Applications/SnowSQL.app/Contents/MacOS/snowsql --version))"
echo ""

# Prompt for connection details
echo "Enter your Snowflake connection details:"
echo ""
read -p "Account name (e.g., abc123.us-east-1): " ACCOUNT
read -p "Username: " USERNAME
read -sp "Password: " PASSWORD
echo ""
echo ""

# Test connection
echo "Testing connection..."
echo ""

# Use environment variable for password to avoid special character issues
export SNOWSQL_PWD="$PASSWORD"

/Applications/SnowSQL.app/Contents/MacOS/snowsql \
    -a "$ACCOUNT" \
    -u "$USERNAME" \
    -q "SELECT CURRENT_VERSION() AS version, CURRENT_USER() AS user, CURRENT_ACCOUNT() AS account;"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✅ Connection successful!"
    echo "=========================================="
    echo ""
    echo "Next steps:"
    echo "1. Run: ./run-snowsql.sh -a $ACCOUNT -u $USERNAME"
    echo "2. Then execute: !source snowflake-migration/schema/01_tables.sql"
    echo "3. Then execute: !source snowflake-migration/procedures/usp_ProcessBudgetConsolidation.sql"
    echo ""
    echo "Or see SNOWSQL_SETUP.md for detailed instructions."
else
    echo ""
    echo "=========================================="
    echo "❌ Connection failed!"
    echo "=========================================="
    echo ""
    echo "Please check:"
    echo "- Account name is correct (check your Snowflake URL)"
    echo "- Username and password are correct"
    echo "- Your Snowflake account is active"
    echo ""
    echo "See SNOWSQL_SETUP.md for troubleshooting."
fi
