# Visual Conversion Guide

## Conversion Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    SQL SERVER ORIGINAL                          │
│                 usp_ProcessBudgetConsolidation                  │
│                        (~350 lines)                             │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                   ANALYSIS PHASE (30 min)                       │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ AI: Identify SQL Server-specific features                │  │
│  │ • 2 Cursors (HierarchyCursor, EliminationCursor)         │  │
│  │ • 3 Table variables with indexes                         │  │
│  │ • WHILE loops with complex logic                         │  │
│  │ • Nested transactions with savepoints                    │  │
│  │ • TRY-CATCH with THROW/RAISERROR                         │  │
│  │ • OUTPUT clause, SCOPE_IDENTITY()                        │  │
│  │ • XML operations, Dynamic SQL                            │  │
│  │ • MERGE with OUTPUT                                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Human: Prioritize and plan approach                      │  │
│  │ • Decision: Pure SQL (not JavaScript)                    │  │
│  │ • Strategy: Set-based operations                         │  │
│  │ • Focus: Maintain business logic                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                 CONVERSION PHASE (3 hours)                      │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ 1. CURSORS → SET-BASED OPERATIONS                       │  │
│  │                                                          │  │
│  │ Before:                    After:                       │  │
│  │ ┌──────────────┐          ┌──────────────┐            │  │
│  │ │ CURSOR       │          │ WHILE loop   │            │  │
│  │ │ FETCH loop   │   ───►   │ + SET-BASED  │            │  │
│  │ │ Row-by-row   │          │ UPDATE       │            │  │
│  │ └──────────────┘          └──────────────┘            │  │
│  │                                                          │  │
│  │ Performance: O(n) → O(levels)                          │  │
│  │ Speedup: 10-100x                                       │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ 2. TABLE VARIABLES → TEMPORARY TABLES                   │  │
│  │                                                          │  │
│  │ Before:                    After:                       │  │
│  │ ┌──────────────┐          ┌──────────────┐            │  │
│  │ │ DECLARE      │          │ CREATE TEMP  │            │  │
│  │ │ @TableVar    │   ───►   │ TABLE        │            │  │
│  │ │ TABLE (...)  │          │ TempTable    │            │  │
│  │ └──────────────┘          └──────────────┘            │  │
│  │                                                          │  │
│  │ Scope: Procedure → Session                             │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ 3. OUTPUT PARAMS → VARIANT RETURN                       │  │
│  │                                                          │  │
│  │ Before:                    After:                       │  │
│  │ ┌──────────────┐          ┌──────────────┐            │  │
│  │ │ @Param1 OUT  │          │ RETURN       │            │  │
│  │ │ @Param2 OUT  │   ───►   │ OBJECT_      │            │  │
│  │ │ @Param3 OUT  │          │ CONSTRUCT()  │            │  │
│  │ └──────────────┘          └──────────────┘            │  │
│  │                                                          │  │
│  │ Result: Multiple params → Single VARIANT object        │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ 4. XML → VARIANT                                        │  │
│  │                                                          │  │
│  │ Before:                    After:                       │  │
│  │ ┌──────────────┐          ┌──────────────┐            │  │
│  │ │ XML column   │          │ VARIANT      │            │  │
│  │ │ .modify()    │   ───►   │ OBJECT_      │            │  │
│  │ │ XPath        │          │ CONSTRUCT()  │            │  │
│  │ └──────────────┘          └──────────────┘            │  │
│  │                                                          │  │
│  │ Query: XPath → JSON notation                           │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ 5. ERROR HANDLING                                       │  │
│  │                                                          │  │
│  │ Before:                    After:                       │  │
│  │ ┌──────────────┐          ┌──────────────┐            │  │
│  │ │ TRY-CATCH    │          │ EXCEPTION    │            │  │
│  │ │ THROW        │   ───►   │ WHEN OTHER   │            │  │
│  │ │ RAISERROR    │          │ Return error │            │  │
│  │ └──────────────┘          └──────────────┘            │  │
│  │                                                          │  │
│  │ Pattern: Throw → Return error object                   │  │
│  └─────────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                  TESTING PHASE (1 hour)                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Test Strategy                                            │  │
│  │                                                          │  │
│  │ 1. Unit Tests        ─► Individual components           │  │
│  │ 2. Comparison Tests  ─► SQL Server vs Snowflake         │  │
│  │ 3. Functional Tests  ─► Business logic validation       │  │
│  │ 4. Performance Tests ─► Speed and resource usage        │  │
│  │ 5. Quality Checks    ─► Data integrity                  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    SNOWFLAKE RESULT                             │
│                 usp_ProcessBudgetConsolidation                  │
│                        (~400 lines)                             │
│                                                                 │
│  ✅ Production-ready                                            │
│  ✅ Fully documented                                            │
│  ✅ Error handling                                              │
│  ✅ Debug mode                                                  │
│  ✅ 10-100x faster                                              │
└─────────────────────────────────────────────────────────────────┘
```

## Cursor Elimination Detail

```
SQL SERVER CURSOR PATTERN:
┌────────────────────────────────────────────────────────────┐
│ DECLARE cursor CURSOR FOR SELECT ...                      │
│ OPEN cursor                                                │
│ FETCH NEXT FROM cursor INTO @var1, @var2                  │
│                                                            │
│ WHILE @@FETCH_STATUS = 0                                  │
│ BEGIN                                                      │
│     ┌──────────────────────────────────────────┐         │
│     │ Process single row                       │         │
│     │ • Calculate values                       │         │
│     │ • Update tables                          │         │
│     │ • Complex logic                          │         │
│     └──────────────────────────────────────────┘         │
│     FETCH NEXT FROM cursor INTO @var1, @var2             │
│ END                                                        │
│                                                            │
│ CLOSE cursor                                               │
│ DEALLOCATE cursor                                          │
└────────────────────────────────────────────────────────────┘
                         │
                         │ CONVERT TO
                         ▼
SNOWFLAKE SET-BASED PATTERN:
┌────────────────────────────────────────────────────────────┐
│ -- Get max level                                           │
│ MaxLevel := (SELECT MAX(Level) FROM Nodes);               │
│ CurrentLevel := MaxLevel;                                  │
│                                                            │
│ WHILE (CurrentLevel >= 0) DO                              │
│     ┌──────────────────────────────────────────┐         │
│     │ Process ALL rows at this level           │         │
│     │ • SET-BASED UPDATE                       │         │
│     │ • Single SQL statement                   │         │
│     │ • Bulk operation                         │         │
│     └──────────────────────────────────────────┘         │
│     CurrentLevel := CurrentLevel - 1;                     │
│ END WHILE;                                                 │
└────────────────────────────────────────────────────────────┘

PERFORMANCE COMPARISON:
┌─────────────────┬──────────────┬──────────────┐
│ Metric          │ SQL Server   │ Snowflake    │
├─────────────────┼──────────────┼──────────────┤
│ Iterations      │ O(n)         │ O(levels)    │
│ Processing      │ Row-by-row   │ Set-based    │
│ Round trips     │ Many         │ Few          │
│ Speed           │ Baseline     │ 10-100x      │
└─────────────────┴──────────────┴──────────────┘
```

## Data Flow Diagram

```
INPUT:
┌─────────────────────────────────────────────────────────┐
│ SourceBudgetHeaderID: 1                                 │
│ ConsolidationType: 'FULL'                               │
│ IncludeEliminations: TRUE                               │
│ RecalculateAllocations: TRUE                            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
STEP 1: VALIDATE
┌─────────────────────────────────────────────────────────┐
│ • Check source budget exists                            │
│ • Verify status (APPROVED/LOCKED)                       │
│ • Log validation step                                   │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
STEP 2: CREATE TARGET
┌─────────────────────────────────────────────────────────┐
│ • Insert new BudgetHeader                               │
│ • Copy metadata from source                             │
│ • Add consolidation metadata (VARIANT)                  │
│ • Get new TargetBudgetHeaderID                          │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
STEP 3: BUILD HIERARCHY
┌─────────────────────────────────────────────────────────┐
│ • Recursive CTE to explode hierarchy                    │
│ • Insert into HierarchyNodes temp table                 │
│ • Order by level (bottom-up)                            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
STEP 4: CONSOLIDATE (Bottom-Up)
┌─────────────────────────────────────────────────────────┐
│ Level 2 (Leaf):                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ • Sum amounts for each leaf node                    │ │
│ │ • Update HierarchyNodes.SubtotalAmount              │ │
│ │ • MERGE into ConsolidatedAmounts                    │ │
│ └─────────────────────────────────────────────────────┘ │
│                     │                                    │
│                     ▼                                    │
│ Level 1 (Parent):                                       │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ • Sum amounts + child subtotals                     │ │
│ │ • Update HierarchyNodes.SubtotalAmount              │ │
│ │ • MERGE into ConsolidatedAmounts                    │ │
│ └─────────────────────────────────────────────────────┘ │
│                     │                                    │
│                     ▼                                    │
│ Level 0 (Root):                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ • Sum all child subtotals                           │ │
│ │ • Update HierarchyNodes.SubtotalAmount              │ │
│ │ • MERGE into ConsolidatedAmounts                    │ │
│ └─────────────────────────────────────────────────────┘ │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
STEP 5: ELIMINATIONS (if enabled)
┌─────────────────────────────────────────────────────────┐
│ • Find intercompany accounts                            │
│ • Match offsetting entries (self-join)                  │
│ • Update EliminationAmount                              │
│ • MERGE into ConsolidatedAmounts                        │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
STEP 6: RECALCULATE (if enabled)
┌─────────────────────────────────────────────────────────┐
│ • Extract options from VARIANT                          │
│ • Calculate FinalAmount                                 │
│ • Apply rounding                                        │
│ • Filter zero balances (optional)                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
STEP 7: INSERT RESULTS
┌─────────────────────────────────────────────────────────┐
│ • Insert into BudgetLineItem                            │
│ • Link to TargetBudgetHeaderID                          │
│ • Set metadata (source, timestamp, etc.)                │
│ • Capture inserted rows (if debug mode)                 │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
OUTPUT:
┌─────────────────────────────────────────────────────────┐
│ VARIANT Object:                                         │
│ {                                                       │
│   "Success": true,                                      │
│   "TargetBudgetHeaderID": 2,                            │
│   "RowsProcessed": 150,                                 │
│   "ConsolidationRunID": "uuid-string",                  │
│   "ProcessingTime": 3,                                  │
│   "ErrorCode": 0,                                       │
│   "ErrorMessage": null,                                 │
│   "ProcessingLog": [...],  // if debug mode            │
│   "InsertedLines": [...]   // if debug mode            │
│ }                                                       │
└─────────────────────────────────────────────────────────┘
```
