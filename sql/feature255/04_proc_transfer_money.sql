/* ============================================================================
   FEATURE 255. ПРОЦЕДУРА ПЕРЕВОДА (НОВАЯ РЕДАКЦИЯ)
   ============================================================================ */
CREATE OR ALTER PROCEDURE feature255.procTransferMoney
    @OperationId VARCHAR(64),
    @N1 VARCHAR(20),
    @N2 VARCHAR(20),
    @S DECIMAL(18, 2),
    @ResultCode INT = NULL OUTPUT,
    @StatusCode INT = NULL OUTPUT,
    @ResultMessage NVARCHAR(2048) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @ReturnCode INT = 0;
    DECLARE @OuterTranCount INT = @@TRANCOUNT;
    DECLARE @Savepoint VARCHAR(32) = 'TransferMoneySave';
    DECLARE @SavepointActive BIT = 0;
    DECLARE @IdempotencyStatus TINYINT = 255;
    DECLARE @PreviousResult INT = NULL;

    SET @ResultCode = -50000;
    SET @StatusCode = 5;
    SET @ResultMessage = N'Системная ошибка. Повторите позже или обратитесь в поддержку.';

    BEGIN TRY

        IF @OperationId IS NULL OR @OperationId = ''
        BEGIN
            SET @ReturnCode = -3000;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleTransferBusinessError
                @ErrorCode = @ReturnCode, @OperationId = @OperationId,
                @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;

            RETURN @ResultCode;
        END;

        IF @N1 IS NULL OR @N1 = '' OR @N2 IS NULL OR @N2 = ''
        BEGIN
            SET @ReturnCode = -1004;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleTransferBusinessError
                @ErrorCode = @ReturnCode, @OperationId = @OperationId,
                @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;

            RETURN @ResultCode;
        END;

        IF @S IS NULL OR @S <= 0
        BEGIN
            SET @ReturnCode = -1003;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleTransferBusinessError
                @ErrorCode = @ReturnCode, @OperationId = @OperationId,
                @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;

            RETURN @ResultCode;
        END;

        IF @N1 = @N2
        BEGIN
            SET @ReturnCode = -1005;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleTransferBusinessError
                @ErrorCode = @ReturnCode, @OperationId = @OperationId,
                @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;

            RETURN @ResultCode;
        END;

        IF @OuterTranCount = 0
            BEGIN TRANSACTION;
        ELSE
        BEGIN
            SAVE TRANSACTION @Savepoint;
            SET @SavepointActive = 1;
        END;

        EXEC @ReturnCode = feature255.IdempotencyBegin
            @OperationId = @OperationId,
            @OperationType = 'TRANSFER',
            @AccountFrom = @N1,
            @AccountTo = @N2,
            @Amount = @S,
            @Status = @IdempotencyStatus OUTPUT,
            @PreviousResultCode = @PreviousResult OUTPUT;

        IF @ReturnCode <> 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = N'Ошибка регистрации операции в подсистеме идемпотентности.';
            RETURN @ResultCode;
        END;

        IF @IdempotencyStatus NOT IN (0, 1, 2)
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ReturnCode = -3002;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleIdempotencyConflict
                @OperationId = @OperationId, @ErrorCode = @ReturnCode;

            RETURN @ResultCode;
        END;

        IF @IdempotencyStatus = 1
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            EXEC @ReturnCode = feature255.WriteIdempotentReplayLog
                @OperationId = @OperationId,
                @PreviousResultCode = @PreviousResult;

            IF @ReturnCode <> 0
            BEGIN
                SET @ResultCode = @ReturnCode;
                SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
                SET @ResultMessage = N'Ошибка логирования идемпотентного повтора.';
                RETURN @ResultCode;
            END;

            IF ISNULL(@PreviousResult, 0) = 0
                SET @ReturnCode = 1;
            ELSE
                SET @ReturnCode = @PreviousResult;

            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);
            RETURN @ResultCode;
        END;

        IF @IdempotencyStatus = 2
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ReturnCode = -3001;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleIdempotencyConflict
                @OperationId = @OperationId, @ErrorCode = @ReturnCode;

            RETURN @ResultCode;
        END;

        EXEC @ReturnCode = feature255.LockTransferAccounts
            @AccountFrom = @N1,
            @AccountTo = @N2;

        IF @ReturnCode <> 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = N'Не удалось заблокировать счета для перевода.';
            RETURN @ResultCode;
        END;

        IF NOT EXISTS (SELECT 1 FROM oper.T WITH (UPDLOCK) WHERE N = @N1)
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ReturnCode = -1001;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleTransferBusinessError
                @ErrorCode = @ReturnCode, @OperationId = @OperationId,
                @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;

            RETURN @ResultCode;
        END;

        IF NOT EXISTS (SELECT 1 FROM oper.T WITH (UPDLOCK) WHERE N = @N2)
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ReturnCode = -1002;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleTransferBusinessError
                @ErrorCode = @ReturnCode, @OperationId = @OperationId,
                @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;

            RETURN @ResultCode;
        END;

        UPDATE oper.T
        SET S = S - @S
        WHERE N = @N1
          AND S >= @S;

        IF @@ROWCOUNT = 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ReturnCode = -2000;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

            EXEC feature255.HandleTransferBusinessError
                @ErrorCode = @ReturnCode, @OperationId = @OperationId,
                @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;

            RETURN @ResultCode;
        END;

        UPDATE oper.T
        SET S = S + @S
        WHERE N = @N2;

        IF @@ROWCOUNT <> 1
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ReturnCode = -1002;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = N'Не удалось зачислить средства на счет получателя.';

            EXEC feature255.HandleTransferBusinessError
                @ErrorCode = @ReturnCode, @OperationId = @OperationId,
                @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;

            RETURN @ResultCode;
        END;

        EXEC @ReturnCode = feature255.WriteBusinessLog
            @OperationType = 'TRANSFER',
            @OperationId = @OperationId,
            @AccountFrom = @N1,
            @AccountTo = @N2,
            @Amount = @S,
            @ResultCode = 0;

        IF @ReturnCode <> 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = N'Ошибка записи бизнес-журнала.';
            RETURN @ResultCode;
        END;

        EXEC @ReturnCode = feature255.IdempotencyComplete
            @OperationId = @OperationId,
            @ResultCode = 0;

        IF @ReturnCode <> 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = N'Ошибка завершения операции в подсистеме идемпотентности.';
            RETURN @ResultCode;
        END;

        IF @OuterTranCount = 0
            COMMIT TRANSACTION;

        SET @ReturnCode = 0;
        SET @ResultCode = 0;
        SET @StatusCode = feature255.fnGetOperationStatusCode(0);
        SET @ResultMessage = feature255.fnGetOperationStatusMessage(0);
        RETURN 0;

    END TRY
    BEGIN CATCH

        DECLARE @ErrorNumber INT = ERROR_NUMBER();
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();

        IF XACT_STATE() = -1
            ROLLBACK TRANSACTION;
        ELSE IF XACT_STATE() = 1
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;
        END;

        BEGIN TRY
            EXEC feature255.LogSystemError
                @ErrorNumber = @ErrorNumber,
                @ErrorMessage = @ErrorMessage,
                @OperationId = @OperationId,
                @AccountFrom = @N1,
                @AccountTo = @N2,
                @Amount = @S;
        END TRY
        BEGIN CATCH
        END CATCH;

        IF @ErrorNumber IN (1205, 1222)
            SET @ReturnCode = -1205;
        ELSE IF @ErrorNumber IN (2601, 2627)
            SET @ReturnCode = -3001;
        ELSE
            SET @ReturnCode = -50000;

        SET @ResultCode = @ReturnCode;
        SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
        SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);

        RETURN @ResultCode;

    END CATCH;
END;
GO
