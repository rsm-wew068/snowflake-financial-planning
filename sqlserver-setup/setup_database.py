#!/usr/bin/env python3
"""
Setup SQL Server database using pymssql
Install: pip install pymssql
"""

import pymssql
import sys
import os

def run_sql_file(cursor, filepath, database=None):
    """Execute SQL from a file"""
    print(f"Running: {filepath}")
    
    with open(filepath, 'r') as f:
        sql = f.read()
    
    # Split by GO statements
    batches = [batch.strip() for batch in sql.split('GO') if batch.strip()]
    
    current_db = None
    
    for i, batch in enumerate(batches, 1):
        # Skip empty batches but not ones that start with comments followed by code
        if not batch or (batch.startswith('--') and '\n' not in batch):
            continue
            
        # Handle USE statements - execute them but track database
        if 'USE ' in batch.upper():
            lines = batch.split('\n')
            for line in lines:
                if line.strip().upper().startswith('USE '):
                    db_name = line.strip().split()[1].rstrip(';')
                    print(f"  Switching to database: {db_name}")
                    current_db = db_name
                    break
        
        try:
            cursor.execute(batch)
            result_msg = f"  Batch {i}/{len(batches)} executed"
            if current_db and 'USE ' not in batch.upper():
                result_msg += f" (in {current_db})"
            print(result_msg)
        except Exception as e:
            error_msg = str(e)
            # Ignore certain expected errors
            if 'does not exist' in error_msg and 'DROP' in batch.upper():
                print(f"  ℹ️  Batch {i} skipped (object doesn't exist yet)")
            elif 'already exists' in error_msg:
                print(f"  ℹ️  Batch {i} skipped (object already exists)")
            else:
                print(f"  ⚠️  Batch {i} warning: {e}")
            # Continue anyway for some errors
    
    print(f"✅ {filepath} completed\n")

def main():
    print("=" * 50)
    print("SQL Server Database Setup")
    print("=" * 50)
    print()
    
    # Connection details
    server = 'localhost'
    port = 1433
    user = 'sa'
    password = 'YourStrong@Passw0rd'
    
    try:
        print("Connecting to SQL Server (master database)...")
        conn = pymssql.connect(
            server=server,
            port=port,
            user=user,
            password=password,
            database='master',
            autocommit=True
        )
        cursor = conn.cursor()
        print("✅ Connected successfully\n")
        
        # Run database creation script
        run_sql_file(cursor, 'sqlserver-setup/01-create-database.sql')
        
        # Close and reconnect to the new database
        cursor.close()
        conn.close()
        
        print("Reconnecting to BUDGET_PLANNING database...")
        conn = pymssql.connect(
            server=server,
            port=port,
            user=user,
            password=password,
            database='BUDGET_PLANNING',
            autocommit=True
        )
        cursor = conn.cursor()
        print("✅ Connected to BUDGET_PLANNING\n")
        
        # Run table and data scripts
        run_sql_file(cursor, 'sqlserver-setup/02-create-tables.sql')
        run_sql_file(cursor, 'sqlserver-setup/03-load-test-data.sql')
        
        # Verify data
        print("Verifying data...")
        cursor.execute("USE BUDGET_PLANNING")
        cursor.execute("""
            SELECT 'Fiscal Periods' AS DataType, COUNT(*) AS RecordCount FROM Planning.FiscalPeriod
            UNION ALL
            SELECT 'GL Accounts', COUNT(*) FROM Planning.GLAccount
            UNION ALL
            SELECT 'Cost Centers', COUNT(*) FROM Planning.CostCenter
            UNION ALL
            SELECT 'Budget Headers', COUNT(*) FROM Planning.BudgetHeader
            UNION ALL
            SELECT 'Budget Line Items', COUNT(*) FROM Planning.BudgetLineItem;
        """)
        
        print("\nData Summary:")
        for row in cursor.fetchall():
            print(f"  {row[0]}: {row[1]}")
        
        cursor.close()
        conn.close()
        
        print()
        print("=" * 50)
        print("✅ SQL Server Setup Complete!")
        print("=" * 50)
        print()
        
        return 0
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\nMake sure:")
        print("  1. SQL Server container is running")
        print("  2. pymssql is installed: pip install pymssql")
        return 1

if __name__ == '__main__':
    sys.exit(main())
