-- Simplified version of usp_ProcessBudgetConsolidation for testing
USE BUDGET_PLANNING
GO

CREATE OR ALTER PROCEDURE Planning.usp_ProcessBudgetConsolidation
    @SourceBudgetHeaderID       INT,
    @ConsolidationType          VARCHAR(20) = 'FULL',
    @IncludeEliminations        BIT = 1,
    @RecalculateAllocations     BIT = 1,
    @UserID                     INT = NULL,
    @DebugMode                  BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Variables
    DECLARE @TargetBudgetHeaderID INT;
    DECLARE @SourceBudgetCode NVARCHAR(30);
    DECLARE @SourceBudgetName NVARCHAR(100);
    DECLARE @FiscalYear SMALLINT;
    DECLARE @StartPeriodID INT;
    DECLARE @EndPeriodID INT;
    DECLARE @ConsolidationRunID UNIQUEIDENTIFIER = NEWID();
    DECLARE @RowsProcessed INT = 0;
    
    -- Validate source budget exists
    IF NOT EXISTS (SELECT 1 FROM Planning.BudgetHeader WHERE BudgetHeaderID = @SourceBudgetHeaderID)
    BEGIN
        SELECT 
            Success = CAST(0 AS BIT),
            ErrorCode = 50000,
            ErrorMessage = 'Source budget header not found: ' + CAST(@SourceBudgetHeaderID AS VARCHAR(10)),
            RowsProcessed = 0;
        RETURN;
    END
    
    -- Get source budget details
    SELECT 
        @SourceBudgetCode = BudgetCode,
        @SourceBudgetName = BudgetName,
        @FiscalYear = FiscalYear,
        @StartPeriodID = StartPeriodID,
        @EndPeriodID = EndPeriodID
    FROM Planning.BudgetHeader
    WHERE BudgetHeaderID = @SourceBudgetHeaderID;
    
    -- Create target budget header
    INSERT INTO Planning.BudgetHeader (
        BudgetCode,
        BudgetName,
        BudgetType,
        ScenarioType,
        FiscalYear,
        StartPeriodID,
        EndPeriodID,
        StatusCode,
        BaseBudgetHeaderID
    )
    VALUES (
        @SourceBudgetCode + '_CONSOL_' + CONVERT(VARCHAR(8), GETDATE(), 112),
        @SourceBudgetName + ' - Consolidated',
        'CONSOLIDATED',
        'BASE',
        @FiscalYear,
        @StartPeriodID,
        @EndPeriodID,
        'DRAFT',
        @SourceBudgetHeaderID
    );
    
    SET @TargetBudgetHeaderID = SCOPE_IDENTITY();
    
    -- Copy line items from source to target
    INSERT INTO Planning.BudgetLineItem (
        BudgetHeaderID,
        GLAccountID,
        CostCenterID,
        FiscalPeriodID,
        OriginalAmount,
        AdjustedAmount,
        SpreadMethodCode
    )
    SELECT 
        @TargetBudgetHeaderID,
        GLAccountID,
        CostCenterID,
        FiscalPeriodID,
        OriginalAmount,
        AdjustedAmount,
        'CONSOLIDATED'
    FROM Planning.BudgetLineItem
    WHERE BudgetHeaderID = @SourceBudgetHeaderID;
    
    SET @RowsProcessed = @@ROWCOUNT;
    
    -- Return success result (simple SELECT instead of JSON)
    SELECT 
        Success = CAST(1 AS BIT),
        ErrorCode = 0,
        ConsolidationRunID = CAST(@ConsolidationRunID AS NVARCHAR(50)),
        TargetBudgetHeaderID = @TargetBudgetHeaderID,
        RowsProcessed = @RowsProcessed,
        ProcessingTime = 0;
END
GO

PRINT 'Stored procedure created successfully'
GO
