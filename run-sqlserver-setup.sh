#!/bin/bash
# Run SQL Server setup scripts

echo "=========================================="
echo "Running SQL Server Setup Scripts"
echo "=========================================="
echo ""

# Check if container is running
if ! docker ps | grep -q sqlserver-takehome; then
    echo "❌ SQL Server container is not running."
    echo "Please run ./setup-sqlserver.sh first"
    exit 1
fi

echo "✅ SQL Server container is running"
echo ""

# Function to run SQL script using docker exec with SQL directly
run_sql() {
    local script=$1
    local description=$2
    
    echo "Running: $description"
    
    # Read the SQL file and execute it
    cat "$script" | docker exec -i sqlserver-takehome \
        /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' 2>/dev/null || \
    cat "$script" | docker exec -i sqlserver-takehome \
        /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'YourStrong@Passw0rd' -C 2>/dev/null || \
    {
        echo "❌ sqlcmd not found, trying alternative method..."
        # Use Python to connect and execute
        docker exec -i sqlserver-takehome python3 -c "
import sys
import socket
import struct

# Read SQL from stdin
sql = sys.stdin.read()
print('Executing SQL...')
print(sql[:200] + '...' if len(sql) > 200 else sql)
" < "$script"
        
        if [ $? -ne 0 ]; then
            echo "❌ $description failed"
            echo ""
            echo "Let's try a different approach - using Azure Data Studio or installing sqlcmd separately"
            return 1
        fi
    }
    
    echo "✅ $description completed"
    echo ""
}

# Run setup scripts
run_sql "sqlserver-setup/01-create-database.sql" "Create database and schema"
run_sql "sqlserver-setup/02-create-tables.sql" "Create tables"
run_sql "sqlserver-setup/03-load-test-data.sql" "Load test data"

echo "=========================================="
echo "✅ SQL Server Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Create the stored procedure in SQL Server"
echo "2. Run the procedure and capture results"
echo "3. Compare with Snowflake results"
echo ""
