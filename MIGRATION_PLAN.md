# SQL Server to Snowflake Migration Plan

## Migration Strategy

### Phase 1: Schema Migration (Foundation)
Convert tables, types, and functions that the stored procedures depend on.

### Phase 2: Stored Procedure Conversion (Priority)
Focus on `usp_ProcessBudgetConsolidation` first, then additional procedures.

### Phase 3: Testing & Verification
Create test data and verify correctness.

---

## Key SQL Server → Snowflake Conversion Patterns

### 1. **Cursors** → Set-Based Operations or JavaScript UDFs
- SQL Server cursors don't exist in Snowflake
- Convert to recursive CTEs, window functions, or JavaScript stored procedures

### 2. **Table Variables** → Temporary Tables
- `DECLARE @TableVar TABLE (...)` → `CREATE TEMPORARY TABLE temp_table (...)`
- Table variables with indexes → Temp tables with clustering keys

### 3. **WHILE Loops** → Recursive CTEs or JavaScript
- Simple loops → Recursive CTEs
- Complex loops → JavaScript stored procedures

### 4. **Transaction Management**
- Named transactions → Simplified transaction model
- Savepoints → Limited support (use separate transactions)
- `@@TRANCOUNT` → Not available (track manually if needed)

### 5. **Error Handling**
- `TRY-CATCH` → `TRY-CATCH` (similar but different)
- `THROW`/`RAISERROR` → `RAISE_ERROR()` or exceptions in JavaScript
- `ERROR_NUMBER()`, `ERROR_MESSAGE()` → Different functions

### 6. **Data Types**
- `HIERARCHYID` → Materialized path (VARCHAR) or nested set model
- `XML` → `VARIANT` (JSON-like structure)
- `ROWVERSION` → `TIMESTAMP` or sequence
- `UNIQUEIDENTIFIER` → `VARCHAR(36)` or `BINARY(16)`

### 7. **Computed Columns**
- Persisted computed columns → Views or materialized views
- `HASHBYTES()` → `HASH()` or `SHA2()`

### 8. **OUTPUT Clause**
- `OUTPUT inserted.* INTO @table` → Use RETURNING clause or separate SELECT

### 9. **Dynamic SQL**
- `sp_executesql` → `EXECUTE IMMEDIATE`
- Output parameters → Different approach (use temp tables)

### 10. **Functions**
- Scalar UDFs → Snowflake UDFs (SQL or JavaScript)
- Table-valued functions → Views or table functions
- `CROSS APPLY` with TVF → `LATERAL FLATTEN` or joins

---

## Conversion Approach for `usp_ProcessBudgetConsolidation`

### Major Challenges Identified:

1. **Two cursors** (HierarchyCursor, EliminationCursor)
   - Solution: Convert to recursive CTEs or JavaScript

2. **Three table variables** with indexes
   - Solution: Use temporary tables

3. **WHILE loops** with complex logic
   - Solution: Recursive CTEs or JavaScript

4. **Nested transactions** with savepoints
   - Solution: Simplify transaction model

5. **OUTPUT clause** capturing inserted rows
   - Solution: Use RETURNING or separate queries

6. **Dynamic SQL** with output parameters
   - Solution: Use EXECUTE IMMEDIATE with temp tables

7. **XML processing** (ExtendedProperties.modify)
   - Solution: Convert to VARIANT/OBJECT operations

8. **MERGE statement** with OUTPUT
   - Solution: Snowflake MERGE (similar but check syntax)

---

## File Structure

```
snowflake-migration/
├── schema/
│   ├── 01_tables.sql           # Table definitions
│   ├── 02_types.sql            # Type equivalents (temp table patterns)
│   ├── 03_functions.sql        # UDF conversions
│   └── 04_views.sql            # View conversions
├── procedures/
│   ├── usp_ProcessBudgetConsolidation.sql  # REQUIRED
│   ├── usp_PerformFinancialClose.sql       # Optional
│   ├── usp_ExecuteCostAllocation.sql       # Optional
│   ├── usp_GenerateRollingForecast.sql     # Optional
│   ├── usp_ReconcileIntercompanyBalances.sql # Optional
│   └── usp_BulkImportBudgetData.sql        # Optional
├── testing/
│   ├── test_data.sql           # Sample test data
│   └── verification_queries.sql # Validation queries
└── CONVERSION_NOTES.md         # Detailed conversion decisions
```

---

## Next Steps

1. ✅ Analyze source code (DONE)
2. ⏭️ Convert schema (tables, types, functions)
3. ⏭️ Convert `usp_ProcessBudgetConsolidation`
4. ⏭️ Create test data and verification approach
5. ⏭️ Document AI usage and decisions
6. ⏭️ (Optional) Convert additional procedures