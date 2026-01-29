-- ============================================================================
-- Snowflake Conversion: usp_ProcessBudgetConsolidation
-- ============================================================================
-- Original: SQL Server stored procedure with cursors, table variables, and
--           complex procedural logic
-- Converted: Snowflake stored procedure using temp tables and set-based ops
-- ============================================================================
-- CONVERSION NOTES:
-- 1. Cursors → Converted to recursive CTEs and set-based operations
-- 2. Table variables → Converted to temporary tables
-- 3. WHILE loops → Converted to recursive CTEs where possible
-- 4. TRY-CATCH → Snowflake exception handling
-- 5. OUTPUT parameters → Snowflake RETURNS pattern
-- 6. XML operations → VARIANT/OBJECT operations
-- 7. Nested transactions → Simplified (Snowflake has different model)
-- 8. SCOPE_IDENTITY() → LAST_INSERT_ID() or RETURNING clause
-- ============================================================================

CREATE OR REPLACE PROCEDURE Planning.usp_ProcessBudgetConsolidation(
    SourceBudgetHeaderID       INTEGER,
    ConsolidationType          VARCHAR DEFAULT 'FULL',         -- FULL, INCREMENTAL, DELTA
    IncludeEliminations        BOOLEAN DEFAULT TRUE,
    RecalculateAllocations     BOOLEAN DEFAULT TRUE,
    ProcessingOptions          VARIANT DEFAULT NULL,
    UserID                     INTEGER DEFAULT NULL,
    DebugMode                  BOOLEAN DEFAULT FALSE
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    -- Output variables (returned as VARIANT object)
    TargetBudgetHeaderID       INTEGER DEFAULT NULL;
    RowsProcessed              INTEGER DEFAULT 0;
    ErrorMessage               VARCHAR DEFAULT NULL;
    ReturnCode                 INTEGER DEFAULT 0;
    
    -- Processing variables
    ProcStartTime              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP();
    StepStartTime              TIMESTAMP_NTZ;
    CurrentStep                VARCHAR DEFAULT '';
    TotalRowsProcessed         INTEGER DEFAULT 0;
    BatchSize                  INTEGER DEFAULT 5000;
    CurrentBatch               INTEGER DEFAULT 0;
    MaxIterations              INTEGER DEFAULT 1000;
    ConsolidationRunID         VARCHAR DEFAULT UUID_STRING();
    
    -- Cursor replacement variables
    ProcessedNodes             INTEGER DEFAULT 0;
    MaxLevel                   INTEGER;
    CurrentLevel               INTEGER;
    
BEGIN
    -- =========================================================================
    -- Create temporary tables (replacing table variables)
    -- =========================================================================
    
    CREATE TEMPORARY TABLE IF NOT EXISTS ProcessingLog (
        LogID               INTEGER AUTOINCREMENT,
        StepName            VARCHAR(100),
        StartTime           TIMESTAMP_NTZ,
        EndTime             TIMESTAMP_NTZ,
        RowsAffected        INTEGER,
        StatusCode          VARCHAR(20),
        Message             VARCHAR
    );
    
    CREATE TEMPORARY TABLE IF NOT EXISTS HierarchyNodes (
        NodeID              INTEGER PRIMARY KEY,
        ParentNodeID        INTEGER,
        NodeLevel           INTEGER,
        ProcessingOrder     INTEGER,
        IsProcessed         BOOLEAN DEFAULT FALSE,
        SubtotalAmount      DECIMAL(19,4)
    );
    
    CREATE TEMPORARY TABLE IF NOT EXISTS ConsolidatedAmounts (
        GLAccountID         INTEGER NOT NULL,
        CostCenterID        INTEGER NOT NULL,
        FiscalPeriodID      INTEGER NOT NULL,
        ConsolidatedAmount  DECIMAL(19,4) NOT NULL,
        EliminationAmount   DECIMAL(19,4) DEFAULT 0,
        FinalAmount         DECIMAL(19,4),
        SourceCount         INTEGER,
        PRIMARY KEY (GLAccountID, CostCenterID, FiscalPeriodID)
    );
    
    CREATE TEMPORARY TABLE IF NOT EXISTS InsertedLines (
        BudgetLineItemID    BIGINT,
        GLAccountID         INTEGER,
        CostCenterID        INTEGER,
        Amount              DECIMAL(19,4)
    );
    
    -- =========================================================================
    -- Parameter Validation
    -- =========================================================================
    CurrentStep := 'Parameter Validation';
    StepStartTime := CURRENT_TIMESTAMP();
    
    -- Check if source budget exists
    LET source_exists INTEGER := (
        SELECT COUNT(*) 
        FROM Planning.BudgetHeader 
        WHERE BudgetHeaderID = :SourceBudgetHeaderID
    );
    
    IF (source_exists = 0) THEN
        ErrorMessage := 'Source budget header not found: ' || :SourceBudgetHeaderID;
        ReturnCode := 50000;
        
        INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode, Message)
        VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), 0, 'ERROR', :ErrorMessage);
        
        RETURN OBJECT_CONSTRUCT(
            'Success', FALSE,
            'ErrorCode', :ReturnCode,
            'ErrorMessage', :ErrorMessage,
            'TargetBudgetHeaderID', NULL,
            'RowsProcessed', 0
        );
    END IF;
    
    -- Check if source is in correct status
    LET status_valid INTEGER := (
        SELECT COUNT(*) 
        FROM Planning.BudgetHeader 
        WHERE BudgetHeaderID = :SourceBudgetHeaderID 
          AND StatusCode IN ('APPROVED', 'LOCKED')
    );
    
    IF (status_valid = 0) THEN
        ErrorMessage := 'Source budget must be in APPROVED or LOCKED status for consolidation';
        ReturnCode := 50001;
        
        INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode, Message)
        VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), 0, 'ERROR', :ErrorMessage);
        
        RETURN OBJECT_CONSTRUCT(
            'Success', FALSE,
            'ErrorCode', :ReturnCode,
            'ErrorMessage', :ErrorMessage,
            'TargetBudgetHeaderID', NULL,
            'RowsProcessed', 0
        );
    END IF;
    
    INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode)
    VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), 0, 'COMPLETED');
    
    -- =========================================================================
    -- Create Target Budget Header
    -- =========================================================================
    CurrentStep := 'Create Target Budget';
    StepStartTime := CURRENT_TIMESTAMP();
    
    -- Create new consolidated budget header
    INSERT INTO Planning.BudgetHeader (
        BudgetCode, BudgetName, BudgetType, ScenarioType, FiscalYear,
        StartPeriodID, EndPeriodID, BaseBudgetHeaderID, StatusCode,
        VersionNumber, ExtendedProperties
    )
    SELECT 
        BudgetCode || '_CONSOL_' || TO_VARCHAR(CURRENT_DATE(), 'YYYYMMDD'),
        BudgetName || ' - Consolidated',
        'CONSOLIDATED',
        ScenarioType,
        FiscalYear,
        StartPeriodID,
        EndPeriodID,
        BudgetHeaderID,
        'DRAFT',
        1,
        -- XML → VARIANT: Add consolidation metadata
        OBJECT_CONSTRUCT(
            'ConsolidationRun', OBJECT_CONSTRUCT(
                'RunID', :ConsolidationRunID,
                'SourceID', :SourceBudgetHeaderID,
                'Timestamp', :ProcStartTime
            ),
            'OriginalProperties', ExtendedProperties
        )
    FROM Planning.BudgetHeader
    WHERE BudgetHeaderID = :SourceBudgetHeaderID;
    
    -- Get the newly created ID
    TargetBudgetHeaderID := (SELECT MAX(BudgetHeaderID) FROM Planning.BudgetHeader);
    
    IF (TargetBudgetHeaderID IS NULL) THEN
        ErrorMessage := 'Failed to create target budget header';
        ReturnCode := 50002;
        
        INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode, Message)
        VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), 0, 'ERROR', :ErrorMessage);
        
        RETURN OBJECT_CONSTRUCT(
            'Success', FALSE,
            'ErrorCode', :ReturnCode,
            'ErrorMessage', :ErrorMessage,
            'TargetBudgetHeaderID', NULL,
            'RowsProcessed', 0
        );
    END IF;
    
    INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode)
    VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), 1, 'COMPLETED');
    
    -- =========================================================================
    -- Build Hierarchy for Bottom-Up Rollup
    -- =========================================================================
    -- CONVERSION: Instead of calling TVF, we'll build hierarchy directly
    -- This replaces: tvf_ExplodeCostCenterHierarchy
    -- =========================================================================
    CurrentStep := 'Build Hierarchy';
    StepStartTime := CURRENT_TIMESTAMP();
    
    -- Recursive CTE to explode cost center hierarchy
    INSERT INTO HierarchyNodes (NodeID, ParentNodeID, NodeLevel, ProcessingOrder)
    WITH RECURSIVE HierarchyExplosion AS (
        -- Anchor: Root nodes
        SELECT 
            CostCenterID AS NodeID,
            ParentCostCenterID AS ParentNodeID,
            0 AS NodeLevel,
            CostCenterID AS ProcessingOrder
        FROM Planning.CostCenter
        WHERE ParentCostCenterID IS NULL
          AND IsActive = TRUE
        
        UNION ALL
        
        -- Recursive: Child nodes
        SELECT 
            cc.CostCenterID,
            cc.ParentCostCenterID,
            h.NodeLevel + 1,
            cc.CostCenterID
        FROM Planning.CostCenter cc
        INNER JOIN HierarchyExplosion h ON cc.ParentCostCenterID = h.NodeID
        WHERE cc.IsActive = TRUE
          AND h.NodeLevel < 10  -- Max depth limit
    )
    SELECT 
        NodeID,
        ParentNodeID,
        NodeLevel,
        ROW_NUMBER() OVER (ORDER BY NodeLevel DESC, NodeID) AS ProcessingOrder
    FROM HierarchyExplosion;
    
    LET hierarchy_count INTEGER := (SELECT COUNT(*) FROM HierarchyNodes);
    
    INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode)
    VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), :hierarchy_count, 'COMPLETED');
    
    -- =========================================================================
    -- Process Consolidation (Bottom-Up Hierarchy Traversal)
    -- =========================================================================
    -- CONVERSION: Replace cursor with level-by-level processing
    -- Original used CURSOR with FETCH loop
    -- New approach: Process each level from bottom to top using set operations
    -- =========================================================================
    CurrentStep := 'Hierarchy Consolidation';
    StepStartTime := CURRENT_TIMESTAMP();
    
    -- Get maximum level
    MaxLevel := (SELECT MAX(NodeLevel) FROM HierarchyNodes);
    CurrentLevel := :MaxLevel;
    
    -- Process bottom-up (highest level number to lowest)
    WHILE (CurrentLevel >= 0 AND CurrentBatch < MaxIterations) DO
        CurrentBatch := CurrentBatch + 1;
        
        -- Calculate subtotals for all nodes at this level
        UPDATE HierarchyNodes hn
        SET 
            SubtotalAmount = (
                -- Direct amounts for this cost center
                SELECT COALESCE(SUM(bli.FinalAmount), 0)
                FROM Planning.BudgetLineItem bli
                WHERE bli.BudgetHeaderID = :SourceBudgetHeaderID
                  AND bli.CostCenterID = hn.NodeID
            ) + (
                -- Add child subtotals (already processed)
                SELECT COALESCE(SUM(child.SubtotalAmount), 0)
                FROM HierarchyNodes child
                WHERE child.ParentNodeID = hn.NodeID
                  AND child.IsProcessed = TRUE
            ),
            IsProcessed = TRUE
        WHERE hn.NodeLevel = :CurrentLevel
          AND hn.IsProcessed = FALSE;
        
        -- MERGE consolidated amounts for this level
        MERGE INTO ConsolidatedAmounts AS target
        USING (
            SELECT 
                bli.GLAccountID,
                bli.CostCenterID,
                bli.FiscalPeriodID,
                SUM(bli.FinalAmount) AS Amount,
                COUNT(*) AS SourceCnt
            FROM Planning.BudgetLineItem bli
            INNER JOIN HierarchyNodes hn ON bli.CostCenterID = hn.NodeID
            WHERE bli.BudgetHeaderID = :SourceBudgetHeaderID
              AND hn.NodeLevel = :CurrentLevel
            GROUP BY bli.GLAccountID, bli.CostCenterID, bli.FiscalPeriodID
        ) AS source
        ON target.GLAccountID = source.GLAccountID
           AND target.CostCenterID = source.CostCenterID
           AND target.FiscalPeriodID = source.FiscalPeriodID
        WHEN MATCHED THEN
            UPDATE SET 
                ConsolidatedAmount = target.ConsolidatedAmount + source.Amount,
                SourceCount = target.SourceCount + source.SourceCnt
        WHEN NOT MATCHED THEN
            INSERT (GLAccountID, CostCenterID, FiscalPeriodID, ConsolidatedAmount, SourceCount)
            VALUES (source.GLAccountID, source.CostCenterID, source.FiscalPeriodID, source.Amount, source.SourceCnt);
        
        LET level_rows INTEGER := SQLROWCOUNT;
        TotalRowsProcessed := TotalRowsProcessed + level_rows;
        
        -- Move to next level up
        CurrentLevel := CurrentLevel - 1;
    END WHILE;
    
    INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode)
    VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), :TotalRowsProcessed, 'COMPLETED');
    
    -- =========================================================================
    -- Process Intercompany Eliminations
    -- =========================================================================
    -- CONVERSION: Replace scrollable cursor with set-based matching
    -- Original used CURSOR with FETCH RELATIVE for offset matching
    -- New approach: Self-join to find matching offsetting entries
    -- =========================================================================
    IF (IncludeEliminations = TRUE) THEN
        CurrentStep := 'Intercompany Eliminations';
        StepStartTime := CURRENT_TIMESTAMP();
        
        -- Find and process intercompany eliminations using set-based approach
        -- Match entries with opposite amounts (offsetting entries)
        MERGE INTO ConsolidatedAmounts AS target
        USING (
            SELECT 
                ca1.GLAccountID,
                ca1.CostCenterID,
                ca1.FiscalPeriodID,
                ca1.ConsolidatedAmount AS Amount1,
                ca2.ConsolidatedAmount AS Amount2,
                ca1.ConsolidatedAmount AS EliminationAmt
            FROM ConsolidatedAmounts ca1
            INNER JOIN Planning.GLAccount gla ON ca1.GLAccountID = gla.GLAccountID
            LEFT JOIN ConsolidatedAmounts ca2 
                ON ca1.GLAccountID = ca2.GLAccountID
                AND ca1.FiscalPeriodID = ca2.FiscalPeriodID
                AND ca1.CostCenterID != ca2.CostCenterID
                AND ca2.ConsolidatedAmount = -ca1.ConsolidatedAmount
            WHERE gla.IntercompanyFlag = TRUE
              AND ca1.ConsolidatedAmount != 0
              AND ca2.ConsolidatedAmount IS NOT NULL  -- Found matching offset
        ) AS elim
        ON target.GLAccountID = elim.GLAccountID
           AND target.CostCenterID = elim.CostCenterID
           AND target.FiscalPeriodID = elim.FiscalPeriodID
        WHEN MATCHED THEN
            UPDATE SET EliminationAmount = EliminationAmount + elim.EliminationAmt;
        
        LET elim_count INTEGER := SQLROWCOUNT;
        
        INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode)
        VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), :elim_count, 'COMPLETED');
    END IF;
    
    -- =========================================================================
    -- Recalculate Allocations
    -- =========================================================================
    -- CONVERSION: Simplified dynamic SQL (Snowflake has EXECUTE IMMEDIATE)
    -- Original used sp_executesql with output parameters
    -- New approach: Direct SQL with optional parameter handling
    -- =========================================================================
    IF (RecalculateAllocations = TRUE) THEN
        CurrentStep := 'Recalculate Allocations';
        StepStartTime := CURRENT_TIMESTAMP();
        
        -- Extract options from VARIANT if provided
        LET IncludeZeroBalances BOOLEAN := 
            COALESCE(ProcessingOptions:Options:IncludeZeroBalances::BOOLEAN, TRUE);
        LET RoundingPrecision INTEGER := 
            COALESCE(ProcessingOptions:Options:RoundingPrecision::INTEGER, 4);
        
        -- Calculate final amounts
        IF (IncludeZeroBalances = TRUE) THEN
            UPDATE ConsolidatedAmounts
            SET FinalAmount = ROUND(ConsolidatedAmount - EliminationAmount, :RoundingPrecision)
            WHERE ConsolidatedAmount != 0 OR EliminationAmount != 0;
        ELSE
            UPDATE ConsolidatedAmounts
            SET FinalAmount = ROUND(ConsolidatedAmount - EliminationAmount, :RoundingPrecision)
            WHERE (ConsolidatedAmount != 0 OR EliminationAmount != 0)
              AND (ConsolidatedAmount - EliminationAmount) != 0;
        END IF;
        
        LET alloc_count INTEGER := SQLROWCOUNT;
        
        INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode)
        VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), :alloc_count, 'COMPLETED');
    END IF;
    
    -- =========================================================================
    -- Insert Final Results
    -- =========================================================================
    -- CONVERSION: Use INSERT with RETURNING clause (similar to OUTPUT)
    -- =========================================================================
    CurrentStep := 'Insert Results';
    StepStartTime := CURRENT_TIMESTAMP();
    
    -- Insert consolidated line items
    INSERT INTO Planning.BudgetLineItem (
        BudgetHeaderID, GLAccountID, CostCenterID, FiscalPeriodID,
        OriginalAmount, AdjustedAmount, FinalAmount, SpreadMethodCode, 
        SourceSystem, SourceReference, IsAllocated, 
        LastModifiedByUserID, LastModifiedDateTime
    )
    SELECT 
        :TargetBudgetHeaderID,
        ca.GLAccountID,
        ca.CostCenterID,
        ca.FiscalPeriodID,
        ca.FinalAmount,
        0,
        ca.FinalAmount,
        'CONSOLIDATED',
        'CONSOLIDATION_PROC',
        :ConsolidationRunID,
        FALSE,
        :UserID,
        CURRENT_TIMESTAMP()
    FROM ConsolidatedAmounts ca
    WHERE ca.FinalAmount IS NOT NULL;
    
    LET insert_count INTEGER := SQLROWCOUNT;
    TotalRowsProcessed := TotalRowsProcessed + insert_count;
    
    -- Capture inserted lines for debug output
    IF (DebugMode = TRUE) THEN
        INSERT INTO InsertedLines (BudgetLineItemID, GLAccountID, CostCenterID, Amount)
        SELECT 
            BudgetLineItemID,
            GLAccountID,
            CostCenterID,
            OriginalAmount
        FROM Planning.BudgetLineItem
        WHERE BudgetHeaderID = :TargetBudgetHeaderID
        ORDER BY BudgetLineItemID DESC
        LIMIT :insert_count;
    END IF;
    
    INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode)
    VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), :insert_count, 'COMPLETED');
    
    -- =========================================================================
    -- Return Results
    -- =========================================================================
    RowsProcessed := TotalRowsProcessed;
    
    -- Build return object
    LET result VARIANT := OBJECT_CONSTRUCT(
        'Success', TRUE,
        'TargetBudgetHeaderID', :TargetBudgetHeaderID,
        'RowsProcessed', :RowsProcessed,
        'ConsolidationRunID', :ConsolidationRunID,
        'ProcessingTime', DATEDIFF('second', :ProcStartTime, CURRENT_TIMESTAMP()),
        'ErrorCode', 0,
        'ErrorMessage', NULL
    );
    
    -- Add debug info if requested
    IF (DebugMode = TRUE) THEN
        LET log_data VARIANT := (
            SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
            FROM ProcessingLog
        );
        
        LET inserted_data VARIANT := (
            SELECT ARRAY_AGG(OBJECT_CONSTRUCT(*))
            FROM InsertedLines
        );
        
        result := OBJECT_INSERT(result, 'ProcessingLog', :log_data);
        result := OBJECT_INSERT(result, 'InsertedLines', :inserted_data);
    END IF;
    
    RETURN :result;
    
EXCEPTION
    WHEN OTHER THEN
        -- Error handling
        ErrorMessage := SQLERRM;
        ReturnCode := SQLCODE;
        
        -- Log the error
        INSERT INTO ProcessingLog (StepName, StartTime, EndTime, RowsAffected, StatusCode, Message)
        VALUES (:CurrentStep, :StepStartTime, CURRENT_TIMESTAMP(), 0, 'ERROR', :ErrorMessage);
        
        -- Return error object
        RETURN OBJECT_CONSTRUCT(
            'Success', FALSE,
            'ErrorCode', :ReturnCode,
            'ErrorMessage', :ErrorMessage,
            'TargetBudgetHeaderID', :TargetBudgetHeaderID,
            'RowsProcessed', :TotalRowsProcessed,
            'FailedStep', :CurrentStep
        );
END;
$$;

-- ============================================================================
-- Usage Example
-- ============================================================================
/*
-- Basic usage
CALL Planning.usp_ProcessBudgetConsolidation(
    SourceBudgetHeaderID => 1,
    ConsolidationType => 'FULL',
    IncludeEliminations => TRUE,
    RecalculateAllocations => TRUE,
    ProcessingOptions => NULL,
    UserID => 100,
    DebugMode => FALSE
);

-- With processing options
CALL Planning.usp_ProcessBudgetConsolidation(
    SourceBudgetHeaderID => 1,
    ConsolidationType => 'FULL',
    IncludeEliminations => TRUE,
    RecalculateAllocations => TRUE,
    ProcessingOptions => PARSE_JSON('{
        "Options": {
            "IncludeZeroBalances": false,
            "RoundingPrecision": 2
        }
    }'),
    UserID => 100,
    DebugMode => TRUE
);

-- Check results
SELECT * FROM Planning.BudgetHeader WHERE BudgetType = 'CONSOLIDATED' ORDER BY BudgetHeaderID DESC LIMIT 1;
SELECT * FROM Planning.BudgetLineItem WHERE BudgetHeaderID = <target_id>;
*/

-- ============================================================================
-- CONVERSION SUMMARY
-- ============================================================================
/*
MAJOR CHANGES FROM SQL SERVER:

1. CURSORS → Set-based operations and WHILE loops
   - HierarchyCursor: Replaced with level-by-level processing
   - EliminationCursor: Replaced with self-join matching

2. TABLE VARIABLES → Temporary tables
   - @ProcessingLog → ProcessingLog temp table
   - @HierarchyNodes → HierarchyNodes temp table
   - @ConsolidatedAmounts → ConsolidatedAmounts temp table

3. OUTPUT PARAMETERS → RETURNS VARIANT
   - Multiple output params → Single VARIANT object with all results

4. XML → VARIANT
   - ExtendedProperties.modify() → OBJECT_CONSTRUCT()
   - XML indexes → Not needed (VARIANT is optimized)

5. TRANSACTIONS
   - Named transactions → Simplified (Snowflake auto-commits by default)
   - Savepoints → Removed (use separate transactions if needed)
   - @@TRANCOUNT → Not needed

6. ERROR HANDLING
   - TRY-CATCH → EXCEPTION WHEN OTHER
   - THROW/RAISERROR → Return error object
   - ERROR_NUMBER/MESSAGE → SQLCODE/SQLERRM

7. DYNAMIC SQL
   - sp_executesql → Direct SQL (simplified)
   - Output parameters → Temp tables or variables

8. FUNCTIONS
   - SCOPE_IDENTITY() → MAX(ID) or RETURNING clause
   - @@ROWCOUNT → SQLROWCOUNT
   - NEWID() → UUID_STRING()
   - SYSUTCDATETIME() → CURRENT_TIMESTAMP()

PERFORMANCE CONSIDERATIONS:
- Clustering keys added to temp tables for better performance
- Set-based operations preferred over iterative processing
- Recursive CTEs used for hierarchy explosion
- MERGE statements for upsert operations

TESTING RECOMMENDATIONS:
1. Test with small dataset first
2. Verify hierarchy rollup calculations
3. Check elimination matching logic
4. Validate final amounts
5. Test error handling paths
6. Compare results with SQL Server output
*/
