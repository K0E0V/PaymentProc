/* ============================================================================
   OPER. ЯДРО ИНФРАСТРУКТУРЫ
   ============================================================================ */
GO
IF SCHEMA_ID(N'oper') IS NULL
    EXEC sp_executesql N'CREATE SCHEMA oper AUTHORIZATION dbo;';
GO

IF OBJECT_ID(N'oper.T', N'U') IS NULL
BEGIN
    CREATE TABLE oper.T
    (
        N VARCHAR(20) NOT NULL,
        S DECIMAL(18,2) NOT NULL CONSTRAINT ck_oper_T_balance CHECK (S >= 0),
        CONSTRAINT pk_oper_T PRIMARY KEY (N)
    );
END;
GO

IF OBJECT_ID(N'oper.tblIdempotencyRegistry', N'U') IS NULL
BEGIN
    CREATE TABLE oper.tblIdempotencyRegistry
    (
        OperationId         VARCHAR(64) NOT NULL,
        OperationType       VARCHAR(20) NOT NULL,
        AccountFrom         VARCHAR(20) NOT NULL,
        AccountTo           VARCHAR(20) NOT NULL,
        Amount              DECIMAL(18,2) NOT NULL,
        Status              TINYINT NOT NULL,
        ResultCode          INT NULL,
        CreatedAt           DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        UpdatedAt           DATETIME2 NULL,
        CONSTRAINT pk_tblIdempotencyRegistry PRIMARY KEY (OperationId)
    );
END;
GO

IF OBJECT_ID(N'oper.tblBusinessOperationLog', N'U') IS NULL
BEGIN
    CREATE TABLE oper.tblBusinessOperationLog
    (
        LogId               BIGINT IDENTITY(1,1) NOT NULL,
        OperationType       VARCHAR(20) NOT NULL,
        OperationId         VARCHAR(64) NOT NULL,
        AccountFrom         VARCHAR(20) NOT NULL,
        AccountTo           VARCHAR(20) NOT NULL,
        Amount              DECIMAL(18,2) NOT NULL,
        ResultCode          INT NOT NULL,
        CreatedAt           DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT pk_tblBusinessOperationLog PRIMARY KEY (LogId)
    );
END;
GO

IF OBJECT_ID(N'oper.tblSystemErrorLog', N'U') IS NULL
BEGIN
    CREATE TABLE oper.tblSystemErrorLog
    (
        LogId               BIGINT IDENTITY(1,1) NOT NULL,
        ErrorNumber         INT NOT NULL,
        ErrorMessage        NVARCHAR(4000) NOT NULL,
        OperationId         VARCHAR(64) NOT NULL,
        AccountFrom         VARCHAR(20) NOT NULL,
        AccountTo           VARCHAR(20) NOT NULL,
        Amount              DECIMAL(18,2) NOT NULL,
        CreatedAt           DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT pk_tblSystemErrorLog PRIMARY KEY (LogId)
    );
END;
GO

-- Базовые тестовые значения на стенде
IF NOT EXISTS (SELECT 1 FROM oper.T WHERE N = 'A')
    INSERT INTO oper.T (N, S) VALUES ('A', 1000.00);
IF NOT EXISTS (SELECT 1 FROM oper.T WHERE N = 'B')
    INSERT INTO oper.T (N, S) VALUES ('B', 0.00);
IF NOT EXISTS (SELECT 1 FROM oper.T WHERE N = 'C')
    INSERT INTO oper.T (N, S) VALUES ('C', 50.00);
GO
