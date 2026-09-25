/* ============================================================================
   OPER. АДАПТЕРЫ ИДЕМПОТЕНТНОСТИ
   ============================================================================ */
GO
CREATE OR ALTER PROCEDURE oper.IdempotencyBegin
    @OperationId VARCHAR(64),
    @OperationType VARCHAR(20),
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20),
    @Amount DECIMAL(18,2),
    @Status TINYINT OUTPUT,
    @PreviousResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    IF @OperationId IS NULL OR @OperationId = ''
    BEGIN
        SET @Status = 255;
        SET @PreviousResultCode = NULL;
        RETURN -3000;
    END;

    IF EXISTS (SELECT 1 FROM oper.tblIdempotencyRegistry WHERE OperationId = @OperationId)
    BEGIN
        DECLARE @CurrentStatus TINYINT;
        DECLARE @CurrentResultCode INT;

        SELECT @CurrentStatus = Status, @CurrentResultCode = ResultCode
        FROM oper.tblIdempotencyRegistry
        WHERE OperationId = @OperationId;

        IF @CurrentStatus = 0
        BEGIN
            SET @Status = 1;
            SET @PreviousResultCode = @CurrentResultCode;
            RETURN 0;
        END;

        IF @CurrentStatus = 2
        BEGIN
            SET @Status = 2;
            SET @PreviousResultCode = @CurrentResultCode;
            RETURN 0;
        END;

        SET @Status = 1;
        SET @PreviousResultCode = @CurrentResultCode;
        RETURN 0;
    END;

    INSERT INTO oper.tblIdempotencyRegistry
        (OperationId, OperationType, AccountFrom, AccountTo, Amount, Status, ResultCode)
    VALUES
        (@OperationId, @OperationType, @AccountFrom, @AccountTo, @Amount, 0, NULL);

    SET @Status = 0;
    SET @PreviousResultCode = NULL;
    RETURN 0;
END;
GO

CREATE OR ALTER PROCEDURE oper.IdempotencyComplete
    @OperationId VARCHAR(64),
    @ResultCode INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM oper.tblIdempotencyRegistry WHERE OperationId = @OperationId)
        RETURN -3002;

    UPDATE oper.tblIdempotencyRegistry
    SET Status = 1,
        ResultCode = @ResultCode,
        UpdatedAt = SYSDATETIME()
    WHERE OperationId = @OperationId;

    RETURN 0;
END;
GO

CREATE OR ALTER PROCEDURE oper.HandleIdempotencyConflict
    @OperationId VARCHAR(64),
    @ErrorCode INT
AS
BEGIN
    SET NOCOUNT ON;
    RETURN 0;
END;
GO
