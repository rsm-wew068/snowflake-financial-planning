-- ============================================================================
-- Snowflake Schema Migration: Tables (TESTED VERSION)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS Planning;

-- ============================================================================
-- FiscalPeriod
-- ============================================================================
CREATE OR REPLACE TABLE Planning.FiscalPeriod (
    FiscalPeriodID          INTEGER AUTOINCREMENT,
    FiscalYear              SMALLINT NOT NULL,
    FiscalQuarter           TINYINT NOT NULL,
    FiscalMonth             TINYINT NOT NULL,
    PeriodName              VARCHAR(50) NOT NULL,
    PeriodStartDate         DATE NOT NULL,
    PeriodEndDate           DATE NOT NULL,
    IsClosed                BOOLEAN NOT NULL DEFAULT FALSE,
    ClosedByUserID          INTEGER,
    ClosedDateTime          TIMESTAMP_NTZ,
    IsAdjustmentPeriod      BOOLEAN NOT NULL DEFAULT FALSE,
    WorkingDays             TINYINT,
    CreatedDateTime         TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ModifiedDateTime        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_FiscalPeriod PRIMARY KEY (FiscalPeriodID),
    CONSTRAINT UQ_FiscalPeriod_YearMonth UNIQUE (FiscalYear, FiscalMonth)
);

-- ============================================================================
-- GLAccount
-- ============================================================================
CREATE OR REPLACE TABLE Planning.GLAccount (
    GLAccountID             INTEGER AUTOINCREMENT,
    AccountNumber           VARCHAR(20) NOT NULL,
    AccountName             VARCHAR(150) NOT NULL,
    AccountType             VARCHAR(1) NOT NULL,
    AccountSubType          VARCHAR(30),
    ParentAccountID         INTEGER,
    AccountLevel            TINYINT NOT NULL DEFAULT 1,
    IsPostable              BOOLEAN NOT NULL DEFAULT TRUE,
    IsBudgetable            BOOLEAN NOT NULL DEFAULT TRUE,
    IsStatistical           BOOLEAN NOT NULL DEFAULT FALSE,
    NormalBalance           VARCHAR(1) NOT NULL DEFAULT 'D',
    CurrencyCode            VARCHAR(3) NOT NULL DEFAULT 'USD',
    ConsolidationAccountID  INTEGER,
    IntercompanyFlag        BOOLEAN NOT NULL DEFAULT FALSE,
    IsActive                BOOLEAN NOT NULL DEFAULT TRUE,
    CreatedDateTime         TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ModifiedDateTime        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    TaxCode                 VARCHAR(20),
    StatutoryAccountCode    VARCHAR(30),
    IFRSAccountCode         VARCHAR(30),
    CONSTRAINT PK_GLAccount PRIMARY KEY (GLAccountID),
    CONSTRAINT UQ_GLAccount_Number UNIQUE (AccountNumber),
    CONSTRAINT FK_GLAccount_Parent FOREIGN KEY (ParentAccountID) 
        REFERENCES Planning.GLAccount (GLAccountID)
);

-- ============================================================================
-- CostCenter
-- ============================================================================
CREATE OR REPLACE TABLE Planning.CostCenter (
    CostCenterID            INTEGER AUTOINCREMENT,
    CostCenterCode          VARCHAR(20) NOT NULL,
    CostCenterName          VARCHAR(100) NOT NULL,
    ParentCostCenterID      INTEGER,
    HierarchyPath           VARCHAR(1000),
    HierarchyLevel          INTEGER,
    ManagerEmployeeID       INTEGER,
    DepartmentCode          VARCHAR(10),
    IsActive                BOOLEAN NOT NULL DEFAULT TRUE,
    EffectiveFromDate       DATE NOT NULL,
    EffectiveToDate         DATE,
    AllocationWeight        DECIMAL(5,4) NOT NULL DEFAULT 1.0000,
    ValidFrom               TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ValidTo                 TIMESTAMP_NTZ,
    CONSTRAINT PK_CostCenter PRIMARY KEY (CostCenterID),
    CONSTRAINT UQ_CostCenter_Code UNIQUE (CostCenterCode),
    CONSTRAINT FK_CostCenter_Parent FOREIGN KEY (ParentCostCenterID) 
        REFERENCES Planning.CostCenter (CostCenterID)
);

CREATE OR REPLACE TABLE Planning.CostCenterHistory (
    CostCenterID            INTEGER NOT NULL,
    CostCenterCode          VARCHAR(20) NOT NULL,
    CostCenterName          VARCHAR(100) NOT NULL,
    ParentCostCenterID      INTEGER,
    HierarchyPath           VARCHAR(1000),
    HierarchyLevel          INTEGER,
    ManagerEmployeeID       INTEGER,
    DepartmentCode          VARCHAR(10),
    IsActive                BOOLEAN NOT NULL,
    EffectiveFromDate       DATE NOT NULL,
    EffectiveToDate         DATE,
    AllocationWeight        DECIMAL(5,4) NOT NULL,
    ValidFrom               TIMESTAMP_NTZ NOT NULL,
    ValidTo                 TIMESTAMP_NTZ NOT NULL,
    HistoryInsertedAt       TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- BudgetHeader
-- ============================================================================
CREATE OR REPLACE TABLE Planning.BudgetHeader (
    BudgetHeaderID          INTEGER AUTOINCREMENT,
    BudgetCode              VARCHAR(30) NOT NULL,
    BudgetName              VARCHAR(100) NOT NULL,
    BudgetType              VARCHAR(20) NOT NULL,
    ScenarioType            VARCHAR(20) NOT NULL,
    FiscalYear              SMALLINT NOT NULL,
    StartPeriodID           INTEGER NOT NULL,
    EndPeriodID             INTEGER NOT NULL,
    BaseBudgetHeaderID      INTEGER,
    StatusCode              VARCHAR(15) NOT NULL DEFAULT 'DRAFT',
    SubmittedByUserID       INTEGER,
    SubmittedDateTime       TIMESTAMP_NTZ,
    ApprovedByUserID        INTEGER,
    ApprovedDateTime        TIMESTAMP_NTZ,
    LockedDateTime          TIMESTAMP_NTZ,
    IsLocked                BOOLEAN,
    VersionNumber           INTEGER NOT NULL DEFAULT 1,
    Notes                   VARCHAR,
    ExtendedProperties      VARIANT,
    CreatedDateTime         TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ModifiedDateTime        TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT PK_BudgetHeader PRIMARY KEY (BudgetHeaderID),
    CONSTRAINT UQ_BudgetHeader_Code_Year UNIQUE (BudgetCode, FiscalYear, VersionNumber),
    CONSTRAINT FK_BudgetHeader_StartPeriod FOREIGN KEY (StartPeriodID) 
        REFERENCES Planning.FiscalPeriod (FiscalPeriodID),
    CONSTRAINT FK_BudgetHeader_EndPeriod FOREIGN KEY (EndPeriodID) 
        REFERENCES Planning.FiscalPeriod (FiscalPeriodID),
    CONSTRAINT FK_BudgetHeader_BaseBudget FOREIGN KEY (BaseBudgetHeaderID) 
        REFERENCES Planning.BudgetHeader (BudgetHeaderID)
);

-- ============================================================================
-- BudgetLineItem
-- ============================================================================
CREATE OR REPLACE TABLE Planning.BudgetLineItem (
    BudgetLineItemID        BIGINT AUTOINCREMENT,
    BudgetHeaderID          INTEGER NOT NULL,
    GLAccountID             INTEGER NOT NULL,
    CostCenterID            INTEGER NOT NULL,
    FiscalPeriodID          INTEGER NOT NULL,
    OriginalAmount          DECIMAL(19,4) NOT NULL DEFAULT 0,
    AdjustedAmount          DECIMAL(19,4) NOT NULL DEFAULT 0,
    FinalAmount             DECIMAL(19,4),
    LocalCurrencyAmount     DECIMAL(19,4),
    ReportingCurrencyAmount DECIMAL(19,4),
    StatisticalQuantity     DECIMAL(18,6),
    UnitOfMeasure           VARCHAR(10),
    SpreadMethodCode        VARCHAR(20),
    SeasonalityFactor       DECIMAL(8,6),
    SourceSystem            VARCHAR(30),
    SourceReference         VARCHAR(100),
    ImportBatchID           VARCHAR(36),
    IsAllocated             BOOLEAN NOT NULL DEFAULT FALSE,
    AllocationSourceLineID  BIGINT,
    AllocationPercentage    DECIMAL(8,6),
    LastModifiedByUserID    INTEGER,
    LastModifiedDateTime    TIMESTAMP_NTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    RowHash                 BINARY(32),
    CONSTRAINT PK_BudgetLineItem PRIMARY KEY (BudgetLineItemID),
    CONSTRAINT FK_BudgetLineItem_Header FOREIGN KEY (BudgetHeaderID) 
        REFERENCES Planning.BudgetHeader (BudgetHeaderID),
    CONSTRAINT FK_BudgetLineItem_Account FOREIGN KEY (GLAccountID) 
        REFERENCES Planning.GLAccount (GLAccountID),
    CONSTRAINT FK_BudgetLineItem_CostCenter FOREIGN KEY (CostCenterID) 
        REFERENCES Planning.CostCenter (CostCenterID),
    CONSTRAINT FK_BudgetLineItem_Period FOREIGN KEY (FiscalPeriodID) 
        REFERENCES Planning.FiscalPeriod (FiscalPeriodID),
    CONSTRAINT FK_BudgetLineItem_AllocationSource FOREIGN KEY (AllocationSourceLineID) 
        REFERENCES Planning.BudgetLineItem (BudgetLineItemID),
    CONSTRAINT UQ_BudgetLineItem_NaturalKey UNIQUE (BudgetHeaderID, GLAccountID, CostCenterID, FiscalPeriodID)
);

-- ============================================================================
-- Helper procedure for computed columns
-- ============================================================================
CREATE OR REPLACE PROCEDURE Planning.UpdateComputedColumns()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    UPDATE Planning.BudgetLineItem
    SET FinalAmount = OriginalAmount + AdjustedAmount
    WHERE FinalAmount IS NULL OR FinalAmount != OriginalAmount + AdjustedAmount;
    
    UPDATE Planning.BudgetHeader
    SET IsLocked = (LockedDateTime IS NOT NULL)
    WHERE IsLocked IS NULL OR IsLocked != (LockedDateTime IS NOT NULL);
    
    UPDATE Planning.CostCenter
    SET HierarchyLevel = ARRAY_SIZE(SPLIT(HierarchyPath, '/')) - 2
    WHERE HierarchyPath IS NOT NULL 
      AND (HierarchyLevel IS NULL OR HierarchyLevel != ARRAY_SIZE(SPLIT(HierarchyPath, '/')) - 2);
    
    UPDATE Planning.BudgetLineItem
    SET RowHash = SHA2(
        CONCAT(
            CAST(GLAccountID AS STRING), '|',
            CAST(CostCenterID AS STRING), '|',
            CAST(FiscalPeriodID AS STRING), '|',
            CAST(FinalAmount AS STRING)
        ), 256)
    WHERE RowHash IS NULL;
    
    RETURN 'Computed columns updated successfully';
END;
$$;

-- Verify tables created
SHOW TABLES IN SCHEMA Planning;
