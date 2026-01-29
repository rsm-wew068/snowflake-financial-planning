-- Simplified SQL Server tables for testing
USE BUDGET_PLANNING
GO

-- FiscalPeriod
CREATE TABLE Planning.FiscalPeriod (
    FiscalPeriodID          INT IDENTITY(1,1) NOT NULL,
    FiscalYear              SMALLINT NOT NULL,
    FiscalQuarter           TINYINT NOT NULL,
    FiscalMonth             TINYINT NOT NULL,
    PeriodName              NVARCHAR(50) NOT NULL,
    PeriodStartDate         DATE NOT NULL,
    PeriodEndDate           DATE NOT NULL,
    IsClosed                BIT NOT NULL DEFAULT 0,
    ClosedByUserID          INT NULL,
    ClosedDateTime          DATETIME2(7) NULL,
    IsAdjustmentPeriod      BIT NOT NULL DEFAULT 0,
    WorkingDays             TINYINT NULL,
    CreatedDateTime         DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDateTime        DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_FiscalPeriod PRIMARY KEY CLUSTERED (FiscalPeriodID),
    CONSTRAINT UQ_FiscalPeriod_YearMonth UNIQUE (FiscalYear, FiscalMonth)
);
GO

-- GLAccount
CREATE TABLE Planning.GLAccount (
    GLAccountID             INT IDENTITY(1,1) NOT NULL,
    AccountNumber           NVARCHAR(20) NOT NULL,
    AccountName             NVARCHAR(150) NOT NULL,
    AccountType             NCHAR(1) NOT NULL,
    AccountSubType          NVARCHAR(30) NULL,
    ParentAccountID         INT NULL,
    AccountLevel            TINYINT NOT NULL DEFAULT 1,
    IsPostable              BIT NOT NULL DEFAULT 1,
    IsBudgetable            BIT NOT NULL DEFAULT 1,
    IsStatistical           BIT NOT NULL DEFAULT 0,
    NormalBalance           NCHAR(1) NOT NULL DEFAULT 'D',
    CurrencyCode            NCHAR(3) NOT NULL DEFAULT 'USD',
    ConsolidationAccountID  INT NULL,
    IntercompanyFlag        BIT NOT NULL DEFAULT 0,
    IsActive                BIT NOT NULL DEFAULT 1,
    CreatedDateTime         DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDateTime        DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    TaxCode                 NVARCHAR(20) NULL,
    StatutoryAccountCode    NVARCHAR(30) NULL,
    IFRSAccountCode         NVARCHAR(30) NULL,
    CONSTRAINT PK_GLAccount PRIMARY KEY CLUSTERED (GLAccountID),
    CONSTRAINT UQ_GLAccount_Number UNIQUE (AccountNumber),
    CONSTRAINT FK_GLAccount_Parent FOREIGN KEY (ParentAccountID) 
        REFERENCES Planning.GLAccount (GLAccountID)
);
GO

-- CostCenter (simplified - no temporal table for testing)
CREATE TABLE Planning.CostCenter (
    CostCenterID            INT IDENTITY(1,1) NOT NULL,
    CostCenterCode          NVARCHAR(20) NOT NULL,
    CostCenterName          NVARCHAR(100) NOT NULL,
    ParentCostCenterID      INT NULL,
    HierarchyPath           NVARCHAR(1000) NULL,
    HierarchyLevel          INT NULL,
    ManagerEmployeeID       INT NULL,
    DepartmentCode          NVARCHAR(10) NULL,
    IsActive                BIT NOT NULL DEFAULT 1,
    EffectiveFromDate       DATE NOT NULL,
    EffectiveToDate         DATE NULL,
    AllocationWeight        DECIMAL(5,4) NOT NULL DEFAULT 1.0000,
    ValidFrom               DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    ValidTo                 DATETIME2(7) NULL,
    CONSTRAINT PK_CostCenter PRIMARY KEY CLUSTERED (CostCenterID),
    CONSTRAINT UQ_CostCenter_Code UNIQUE (CostCenterCode),
    CONSTRAINT FK_CostCenter_Parent FOREIGN KEY (ParentCostCenterID) 
        REFERENCES Planning.CostCenter (CostCenterID)
);
GO

-- BudgetHeader
CREATE TABLE Planning.BudgetHeader (
    BudgetHeaderID          INT IDENTITY(1,1) NOT NULL,
    BudgetCode              NVARCHAR(30) NOT NULL,
    BudgetName              NVARCHAR(100) NOT NULL,
    BudgetType              NVARCHAR(20) NOT NULL,
    ScenarioType            NVARCHAR(20) NOT NULL,
    FiscalYear              SMALLINT NOT NULL,
    StartPeriodID           INT NOT NULL,
    EndPeriodID             INT NOT NULL,
    BaseBudgetHeaderID      INT NULL,
    StatusCode              NVARCHAR(15) NOT NULL DEFAULT 'DRAFT',
    SubmittedByUserID       INT NULL,
    SubmittedDateTime       DATETIME2(7) NULL,
    ApprovedByUserID        INT NULL,
    ApprovedDateTime        DATETIME2(7) NULL,
    LockedDateTime          DATETIME2(7) NULL,
    IsLocked                AS (CASE WHEN LockedDateTime IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END),
    VersionNumber           INT NOT NULL DEFAULT 1,
    Notes                   NVARCHAR(MAX) NULL,
    ExtendedProperties      XML NULL,
    CreatedDateTime         DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    ModifiedDateTime        DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_BudgetHeader PRIMARY KEY CLUSTERED (BudgetHeaderID),
    CONSTRAINT UQ_BudgetHeader_Code_Year UNIQUE (BudgetCode, FiscalYear, VersionNumber),
    CONSTRAINT FK_BudgetHeader_StartPeriod FOREIGN KEY (StartPeriodID) 
        REFERENCES Planning.FiscalPeriod (FiscalPeriodID),
    CONSTRAINT FK_BudgetHeader_EndPeriod FOREIGN KEY (EndPeriodID) 
        REFERENCES Planning.FiscalPeriod (FiscalPeriodID),
    CONSTRAINT FK_BudgetHeader_BaseBudget FOREIGN KEY (BaseBudgetHeaderID) 
        REFERENCES Planning.BudgetHeader (BudgetHeaderID)
);
GO

-- BudgetLineItem
CREATE TABLE Planning.BudgetLineItem (
    BudgetLineItemID        BIGINT IDENTITY(1,1) NOT NULL,
    BudgetHeaderID          INT NOT NULL,
    GLAccountID             INT NOT NULL,
    CostCenterID            INT NOT NULL,
    FiscalPeriodID          INT NOT NULL,
    OriginalAmount          DECIMAL(19,4) NOT NULL DEFAULT 0,
    AdjustedAmount          DECIMAL(19,4) NOT NULL DEFAULT 0,
    FinalAmount             AS (OriginalAmount + AdjustedAmount) PERSISTED,
    LocalCurrencyAmount     DECIMAL(19,4) NULL,
    ReportingCurrencyAmount DECIMAL(19,4) NULL,
    StatisticalQuantity     DECIMAL(18,6) NULL,
    UnitOfMeasure           NVARCHAR(10) NULL,
    SpreadMethodCode        NVARCHAR(20) NULL,
    SeasonalityFactor       DECIMAL(8,6) NULL,
    SourceSystem            NVARCHAR(30) NULL,
    SourceReference         NVARCHAR(100) NULL,
    ImportBatchID           UNIQUEIDENTIFIER NULL,
    IsAllocated             BIT NOT NULL DEFAULT 0,
    AllocationSourceLineID  BIGINT NULL,
    AllocationPercentage    DECIMAL(8,6) NULL,
    LastModifiedByUserID    INT NULL,
    LastModifiedDateTime    DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
    RowHash                 AS (HASHBYTES('SHA2_256', 
        CAST(GLAccountID AS NVARCHAR(20)) + '|' +
        CAST(CostCenterID AS NVARCHAR(20)) + '|' +
        CAST(FiscalPeriodID AS NVARCHAR(20)) + '|' +
        CAST(OriginalAmount + AdjustedAmount AS NVARCHAR(50))
    )) PERSISTED,
    CONSTRAINT PK_BudgetLineItem PRIMARY KEY CLUSTERED (BudgetLineItemID),
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
GO

PRINT 'Tables created successfully';
GO
