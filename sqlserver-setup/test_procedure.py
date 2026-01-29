#!/usr/bin/env python3
"""
Test SQL Server stored procedure and compare with Snowflake results
"""

import pymssql
import json

def main():
    print("=" * 70)
    print("SQL Server Procedure Test")
    print("=" * 70)
    print()
    
    # Connect to SQL Server
    conn = pymssql.connect(
        server='localhost',
        port=1433,
        user='sa',
        password='YourStrong@Passw0rd',
        database='BUDGET_PLANNING',
        autocommit=True
    )
    cursor = conn.cursor()
    
    # Create the procedure
    print("Creating stored procedure...")
    with open('sqlserver-setup/04-create-procedure-simple.sql', 'r') as f:
        sql = f.read()
    
    batches = [b.strip() for b in sql.split('GO') if b.strip() and not b.strip().startswith('--')]
    for batch in batches:
        if 'USE ' in batch.upper():
            continue
        try:
            cursor.execute(batch)
        except Exception as e:
            print(f"Warning: {e}")
    
    print("✅ Procedure created\n")
    
    # Execute the procedure
    print("Executing procedure...")
    cursor.execute("""
        EXEC Planning.usp_ProcessBudgetConsolidation
            @SourceBudgetHeaderID = 1,
            @ConsolidationType = 'FULL',
            @IncludeEliminations = 1,
            @RecalculateAllocations = 1,
            @UserID = 100,
            @DebugMode = 1
    """)
    
    # Get result
    result = cursor.fetchone()
    if result:
        print("\n📊 Procedure Result:")
        print(f"  Success: {result[0]}")
        print(f"  ErrorCode: {result[1]}")
        print(f"  ConsolidationRunID: {result[2]}")
        print(f"  TargetBudgetHeaderID: {result[3]}")
        print(f"  RowsProcessed: {result[4]}")
        print(f"  ProcessingTime: {result[5]}")
        print()
        
        if result[0]:  # Success
            target_id = result[3]
            
            # Query consolidated results
            print("=" * 70)
            print("SQL Server Consolidated Results")
            print("=" * 70)
            print()
            
            # Get consolidated budget header
            cursor.execute(f"""
                SELECT 
                    BudgetHeaderID,
                    BudgetCode,
                    BudgetName,
                    BudgetType,
                    StatusCode
                FROM Planning.BudgetHeader
                WHERE BudgetHeaderID = {target_id}
            """)
            
            print("Consolidated Budget Header:")
            for row in cursor.fetchall():
                print(f"  ID: {row[0]}")
                print(f"  Code: {row[1]}")
                print(f"  Name: {row[2]}")
                print(f"  Type: {row[3]}")
                print(f"  Status: {row[4]}")
            print()
            
            # Get amounts by account
            cursor.execute(f"""
                SELECT 
                    gla.AccountNumber,
                    gla.AccountName,
                    SUM(bli.OriginalAmount + bli.AdjustedAmount) AS TotalAmount
                FROM Planning.BudgetLineItem bli
                INNER JOIN Planning.GLAccount gla ON bli.GLAccountID = gla.GLAccountID
                WHERE bli.BudgetHeaderID = {target_id}
                GROUP BY gla.AccountNumber, gla.AccountName
                ORDER BY gla.AccountNumber
            """)
            
            print("Amounts by Account:")
            print(f"{'Account':<10} {'Account Name':<25} {'Total Amount':>15}")
            print("-" * 52)
            for row in cursor.fetchall():
                print(f"{row[0]:<10} {row[1]:<25} {row[2]:>15,.2f}")
            print()
            
            # Get amounts by cost center
            cursor.execute(f"""
                SELECT 
                    cc.CostCenterCode,
                    cc.CostCenterName,
                    cc.HierarchyLevel,
                    SUM(bli.OriginalAmount + bli.AdjustedAmount) AS TotalAmount
                FROM Planning.BudgetLineItem bli
                INNER JOIN Planning.CostCenter cc ON bli.CostCenterID = cc.CostCenterID
                WHERE bli.BudgetHeaderID = {target_id}
                GROUP BY cc.CostCenterCode, cc.CostCenterName, cc.HierarchyLevel, cc.HierarchyPath
                ORDER BY cc.HierarchyPath
            """)
            
            print("Amounts by Cost Center:")
            print(f"{'Code':<10} {'Name':<20} {'Level':<7} {'Total Amount':>15}")
            print("-" * 54)
            for row in cursor.fetchall():
                print(f"{row[0]:<10} {row[1]:<20} {row[2]:<7} {row[3]:>15,.2f}")
            print()
            
            # Get line item count
            cursor.execute(f"""
                SELECT COUNT(*) FROM Planning.BudgetLineItem
                WHERE BudgetHeaderID = {target_id}
            """)
            count = cursor.fetchone()[0]
            print(f"Total Line Items: {count}")
            print()
            
    cursor.close()
    conn.close()
    
    print("=" * 70)
    print("✅ SQL Server Test Complete!")
    print("=" * 70)
    print()
    print("Compare these results with Snowflake results to verify migration accuracy.")
    print()

if __name__ == '__main__':
    main()
