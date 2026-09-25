/* ============================================================================
   TEST_FEATURE255. ТЕСТОВАЯ ИНФРАСТРУКТУРА
   ============================================================================ */
GO
IF SCHEMA_ID(N'test_feature255') IS NULL
    EXEC sp_executesql N'CREATE SCHEMA test_feature255 AUTHORIZATION dbo;';
GO

IF OBJECT_ID(N'test_feature255.tblIdempotencyRegistry', N'U') IS NULL
BEGIN
    CREATE TABLE test_feature255.tblIdempotencyRegistry
    (
        OperationId VARCHAR(64) NOT NULL,
        OperationType VARCHAR(20) NOT NULL,
        AccountFrom VARCHAR(20) NOT NULL,
        AccountTo VARCHAR(20) NOT NULL,
        Amount DECIMAL(18,2) NOT NULL,
        Status TINYINT NOT NULL,
        ResultCode INT NULL,
        CONSTRAINT pk_test_feature255_tblIdempotencyRegistry PRIMARY KEY (OperationId)
    );
END;
GO

IF OBJECT_ID(N'test_feature255.tblStubBehavior', N'U') IS NULL
BEGIN
    CREATE TABLE test_feature255.tblStubBehavior
    (
        StubName VARCHAR(64) NOT NULL,
        ReturnValue INT NOT NULL,
        ThrowError BIT NOT NULL DEFAULT 0,
        CONSTRAINT pk_test_feature255_tblStubBehavior PRIMARY KEY (StubName)
    );
END;
GO

IF OBJECT_ID(N'test_feature255.tblStubLog', N'U') IS NULL
BEGIN
    CREATE TABLE test_feature255.tblStubLog
    (
        LogId BIGINT IDENTITY(1,1) NOT NULL,
        StubName VARCHAR(64) NOT NULL,
        CallArgs NVARCHAR(4000) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT pk_test_feature255_tblStubLog PRIMARY KEY (LogId)
    );
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.procResetEnvironment
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM test_feature255.tblStubLog;
    DELETE FROM test_feature255.tblStubBehavior;
    DELETE FROM test_feature255.tblIdempotencyRegistry;

    -- В сценариях тестов значения счетов должны быть сброшены к начальному состоянию.
    DELETE FROM oper.T;
    INSERT INTO oper.T (N, S) VALUES ('A', 1000.00), ('B', 0.00), ('C', 50.00);
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.procUseProdInfrastructure
AS
BEGIN
    SET NOCOUNT ON;
    -- В реальной реализации здесь должны пересоздаваться синонимы feature255.* -> oper.*
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.procUseTestInfrastructure
AS
BEGIN
    SET NOCOUNT ON;
    -- В реальной реализации здесь должны пересоздаваться синонимы feature255.* -> test_feature255.*
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.procSetStubBehavior
    @StubName VARCHAR(64),
    @ReturnValue INT,
    @ThrowError BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM test_feature255.tblStubBehavior WHERE StubName = @StubName)
    BEGIN
        UPDATE test_feature255.tblStubBehavior
        SET ReturnValue = @ReturnValue,
            ThrowError = @ThrowError
        WHERE StubName = @StubName;
        RETURN;
    END;

    INSERT INTO test_feature255.tblStubBehavior (StubName, ReturnValue, ThrowError)
    VALUES (@StubName, @ReturnValue, @ThrowError);
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.AssertEqualInt
    @Expected INT,
    @Actual INT,
    @TestName NVARCHAR(200)
AS
BEGIN
    IF @Expected <> @Actual
        THROW 50000, CONCAT('AssertEqualInt failed: ', @TestName, ' expected=', @Expected, ' actual=', @Actual), 1;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.AssertEqualDecimal
    @Expected DECIMAL(18,2),
    @Actual DECIMAL(18,2),
    @TestName NVARCHAR(200)
AS
BEGIN
    IF @Expected <> @Actual
        THROW 50000, CONCAT('AssertEqualDecimal failed: ', @TestName, ' expected=', @Expected, ' actual=', @Actual), 1;
END;
GO
