/* ============================================================================
   OPER. АДАПТЕРЫ ПЕРЕВОДА И ЛОГИРОВАНИЯ
   ============================================================================ */
GO
CREATE OR ALTER PROCEDURE oper.LockTransferAccounts
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    RETURN 0;
END;
GO

CREATE OR ALTER PROCEDURE oper.HandleTransferBusinessError
    @ErrorCode INT,
    @OperationId VARCHAR(64),
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20),
    @Amount DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    RETURN 0;
END;
GO

CREATE OR ALTER PROCEDURE oper.WriteBusinessLog
    @OperationType VARCHAR(20),
    @OperationId VARCHAR(64),
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20),
    @Amount DECIMAL(18,2),
    @ResultCode INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO oper.tblBusinessOperationLog
        (OperationType, OperationId, AccountFrom, AccountTo, Amount, ResultCode)
    VALUES
        (@OperationType, @OperationId, @AccountFrom, @AccountTo, @Amount, @ResultCode);

    RETURN 0;
END;
GO

CREATE OR ALTER PROCEDURE oper.WriteIdempotentReplayLog
    @OperationId VARCHAR(64),
    @PreviousResultCode INT
AS
BEGIN
    SET NOCOUNT ON;
    RETURN 0;
END;
GO

CREATE OR ALTER PROCEDURE oper.LogSystemError
    @ErrorNumber INT,
    @ErrorMessage NVARCHAR(4000),
    @OperationId VARCHAR(64),
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20),
    @Amount DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO oper.tblSystemErrorLog
        (ErrorNumber, ErrorMessage, OperationId, AccountFrom, AccountTo, Amount)
    VALUES
        (@ErrorNumber, @ErrorMessage, @OperationId, @AccountFrom, @AccountTo, @Amount);

    RETURN 0;
END;
GO
