/* ============================================================================
   DEPLOY: FEATURE 255 - ИДЕМПОТЕНТНЫЙ ПЕРЕВОД СРЕДСТВ
   Пакет для запуска на пустой БД.
   Создает рабочую инфраструктуру oper, фичевую реализацию feature255,
   тестовую инфраструктуру test_feature255 и имитирует переключение портов.
   ============================================================================ */
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------------
   1. СОЗДАНИЕ СХЕМ
   --------------------------------------------------------------------------- */
IF SCHEMA_ID(N'oper') IS NULL
    EXEC sp_executesql N'CREATE SCHEMA oper AUTHORIZATION dbo;';
GO

IF SCHEMA_ID(N'feature255') IS NULL
    EXEC sp_executesql N'CREATE SCHEMA feature255 AUTHORIZATION dbo;';
GO

IF SCHEMA_ID(N'test_feature255') IS NULL
    EXEC sp_executesql N'CREATE SCHEMA test_feature255 AUTHORIZATION dbo;';
GO

/* ---------------------------------------------------------------------------
   2. ИНФРАСТРУКТУРА OPER: ТАБЛИЦЫ
   --------------------------------------------------------------------------- */
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
        OperationId    VARCHAR(64) NOT NULL,
        OperationType  VARCHAR(20) NOT NULL,
        AccountFrom    VARCHAR(20) NOT NULL,
        AccountTo      VARCHAR(20) NOT NULL,
        Amount         DECIMAL(18,2) NOT NULL,
        Status         TINYINT NOT NULL,
        ResultCode     INT NULL,
        CreatedAt      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        UpdatedAt      DATETIME2 NULL,
        CONSTRAINT pk_tblIdempotencyRegistry PRIMARY KEY (OperationId)
    );
END;
GO

IF OBJECT_ID(N'oper.tblBusinessOperationLog', N'U') IS NULL
BEGIN
    CREATE TABLE oper.tblBusinessOperationLog
    (
        LogId         BIGINT IDENTITY(1,1) NOT NULL,
        OperationType VARCHAR(20) NOT NULL,
        OperationId   VARCHAR(64) NOT NULL,
        AccountFrom   VARCHAR(20) NOT NULL,
        AccountTo     VARCHAR(20) NOT NULL,
        Amount        DECIMAL(18,2) NOT NULL,
        ResultCode    INT NOT NULL,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT pk_tblBusinessOperationLog PRIMARY KEY (LogId)
    );
END;
GO

IF OBJECT_ID(N'oper.tblSystemErrorLog', N'U') IS NULL
BEGIN
    CREATE TABLE oper.tblSystemErrorLog
    (
        LogId         BIGINT IDENTITY(1,1) NOT NULL,
        ErrorNumber   INT NOT NULL,
        ErrorMessage  NVARCHAR(4000) NOT NULL,
        OperationId   VARCHAR(64) NOT NULL,
        AccountFrom   VARCHAR(20) NOT NULL,
        AccountTo     VARCHAR(20) NOT NULL,
        Amount        DECIMAL(18,2) NOT NULL,
        CreatedAt     DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT pk_tblSystemErrorLog PRIMARY KEY (LogId)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM oper.T WHERE N = 'A')
    INSERT INTO oper.T (N, S) VALUES ('A', 1000.00);
IF NOT EXISTS (SELECT 1 FROM oper.T WHERE N = 'B')
    INSERT INTO oper.T (N, S) VALUES ('B', 0.00);
IF NOT EXISTS (SELECT 1 FROM oper.T WHERE N = 'C')
    INSERT INTO oper.T (N, S) VALUES ('C', 50.00);
GO

/* ---------------------------------------------------------------------------
   3. ИНФРАСТРУКТУРА OPER: АДАПТЕРЫ / ПРОЦЕДУРЫ
   --------------------------------------------------------------------------- */
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
    INSERT INTO oper.tblBusinessOperationLog
        (OperationType, OperationId, AccountFrom, AccountTo, Amount, ResultCode)
    VALUES
        ('TRANSFER', @OperationId, @AccountFrom, @AccountTo, @Amount, @ErrorCode);

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

/* ---------------------------------------------------------------------------
   4. ИНФРАСТРУКТУРА OPER: ГЛАВНАЯ БОЕВАЯ ПРОЦЕДУРА
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE oper.procTransferMoney
    @OperationId VARCHAR(64),
    @N1 VARCHAR(20),
    @N2 VARCHAR(20),
    @S DECIMAL(18,2),
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
            SET @StatusCode = 2;
            SET @ResultMessage = N'Не указан ключ идемпотентности.';
            RETURN @ResultCode;
        END;

        IF @N1 IS NULL OR @N1 = '' OR @N2 IS NULL OR @N2 = ''
        BEGIN
            SET @ReturnCode = -1004;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = 2;
            SET @ResultMessage = N'Не указаны номера счетов.';
            RETURN @ResultCode;
        END;

        IF @S IS NULL OR @S <= 0
        BEGIN
            SET @ReturnCode = -1003;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = 2;
            SET @ResultMessage = N'Сумма перевода должна быть больше нуля.';
            RETURN @ResultCode;
        END;

        IF @N1 = @N2
        BEGIN
            SET @ReturnCode = -1005;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = 2;
            SET @ResultMessage = N'Перевод на тот же счет запрещен.';
            RETURN @ResultCode;
        END;

        IF @OuterTranCount = 0
            BEGIN TRANSACTION;
        ELSE
        BEGIN
            SAVE TRANSACTION @Savepoint;
            SET @SavepointActive = 1;
        END;

        EXEC @ReturnCode = oper.IdempotencyBegin
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
            SET @StatusCode = 5;
            SET @ResultMessage = N'Ошибка регистрации операции в подсистеме идемпотентности.';
            RETURN @ResultCode;
        END;

        IF @IdempotencyStatus = 1
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ResultCode = ISNULL(@PreviousResult, 1);
            SET @StatusCode = CASE WHEN @ResultCode = 0 THEN 0 ELSE 1 END;
            SET @ResultMessage = CASE WHEN @ResultCode = 0 THEN N'Операция выполнена успешно.' ELSE N'Операция уже была успешно выполнена ранее.' END;
            RETURN @ResultCode;
        END;

        IF @IdempotencyStatus = 2
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            SET @ReturnCode = -3001;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = 4;
            SET @ResultMessage = N'Операция с этим ключом уже выполняется. Повторите запрос позже.';
            RETURN @ResultCode;
        END;

        EXEC @ReturnCode = oper.LockTransferAccounts @AccountFrom = @N1, @AccountTo = @N2;
        IF @ReturnCode <> 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = 5;
            SET @ResultMessage = N'Не удалось заблокировать счета для перевода.';
            RETURN @ResultCode;
        END;

        IF NOT EXISTS (SELECT 1 FROM oper.T WITH (UPDLOCK) WHERE N = @N1)
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;
            SET @ResultCode = -1001;
            SET @StatusCode = 3;
            SET @ResultMessage = N'Счет отправителя не найден.';
            RETURN @ResultCode;
        END;

        IF NOT EXISTS (SELECT 1 FROM oper.T WITH (UPDLOCK) WHERE N = @N2)
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;
            SET @ResultCode = -1002;
            SET @StatusCode = 3;
            SET @ResultMessage = N'Счет получателя не найден.';
            RETURN @ResultCode;
        END;

        UPDATE oper.T
        SET S = S - @S
        WHERE N = @N1 AND S >= @S;

        IF @@ROWCOUNT = 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;
            SET @ResultCode = -2000;
            SET @StatusCode = 3;
            SET @ResultMessage = N'Недостаточно средств на счете отправителя.';
            RETURN @ResultCode;
        END;

        UPDATE oper.T
        SET S = S + @S
        WHERE N = @N2;

        IF @@ROWCOUNT <> 1
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;
            SET @ResultCode = -1002;
            SET @StatusCode = 3;
            SET @ResultMessage = N'Не удалось зачислить средства на счет получателя.';
            RETURN @ResultCode;
        END;

        EXEC @ReturnCode = oper.WriteBusinessLog
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
            SET @StatusCode = 5;
            SET @ResultMessage = N'Ошибка записи бизнес-журнала.';
            RETURN @ResultCode;
        END;

        EXEC @ReturnCode = oper.IdempotencyComplete @OperationId = @OperationId, @ResultCode = 0;
        IF @ReturnCode <> 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = 5;
            SET @ResultMessage = N'Ошибка завершения операции в подсистеме идемпотентности.';
            RETURN @ResultCode;
        END;

        IF @OuterTranCount = 0
            COMMIT TRANSACTION;

        SET @ResultCode = 0;
        SET @StatusCode = 0;
        SET @ResultMessage = N'Операция выполнена успешно.';
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
            EXEC oper.LogSystemError
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
            SET @ResultCode = -1205;
        ELSE IF @ErrorNumber IN (2601, 2627)
            SET @ResultCode = -3001;
        ELSE
            SET @ResultCode = -50000;

        SET @StatusCode = 5;
        SET @ResultMessage = N'Системная ошибка. Повторите позже или обратитесь в поддержку.';
        RETURN @ResultCode;
    END CATCH;
END;
GO

/* ---------------------------------------------------------------------------
   5. FEATURE255: СХЕМА, СЛОВАРИ И ФУНКЦИИ КОНТРАКТА РЕЗУЛЬТАТА
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'feature255.tblOperationStatus', N'U') IS NULL
BEGIN
    CREATE TABLE feature255.tblOperationStatus
    (
        StatusCode        INT NOT NULL,
        StatusName        VARCHAR(30) NOT NULL,
        StatusDescription NVARCHAR(200) NOT NULL,
        CONSTRAINT pk_tblOperationStatus PRIMARY KEY (StatusCode),
        CONSTRAINT uq_tblOperationStatus_Name UNIQUE (StatusName)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationStatus WHERE StatusCode = 0)
    INSERT INTO feature255.tblOperationStatus VALUES (0, 'SUCCESS', N'Операция выполнена успешно.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationStatus WHERE StatusCode = 1)
    INSERT INTO feature255.tblOperationStatus VALUES (1, 'DUPLICATE_SUCCESS', N'Операция уже была успешно выполнена ранее.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationStatus WHERE StatusCode = 2)
    INSERT INTO feature255.tblOperationStatus VALUES (2, 'VALIDATION_ERROR', N'Ошибка проверки входных данных.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationStatus WHERE StatusCode = 3)
    INSERT INTO feature255.tblOperationStatus VALUES (3, 'BUSINESS_ERROR', N'Бизнес-ошибка операции.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationStatus WHERE StatusCode = 4)
    INSERT INTO feature255.tblOperationStatus VALUES (4, 'CONFLICT', N'Конфликт идемпотентности или параллельного выполнения.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationStatus WHERE StatusCode = 5)
    INSERT INTO feature255.tblOperationStatus VALUES (5, 'SYSTEM_ERROR', N'Системная ошибка.');
GO

IF OBJECT_ID(N'feature255.tblOperationResultStatusMap', N'U') IS NULL
BEGIN
    CREATE TABLE feature255.tblOperationResultStatusMap
    (
        ResultCode     INT NOT NULL,
        StatusCode     INT NOT NULL,
        DefaultMessage NVARCHAR(2048) NOT NULL,
        CONSTRAINT pk_tblOperationResultStatusMap PRIMARY KEY (ResultCode),
        CONSTRAINT fk_tblOperationResultStatusMap_Status
            FOREIGN KEY (StatusCode) REFERENCES feature255.tblOperationStatus (StatusCode)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = 0)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (0, 0, N'Операция выполнена успешно.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = 1)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (1, 1, N'Операция уже была успешно выполнена ранее.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -1001)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-1001, 3, N'Счет отправителя не найден.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -1002)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-1002, 3, N'Счет получателя не найден.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -1003)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-1003, 2, N'Сумма перевода должна быть больше нуля.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -1004)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-1004, 2, N'Не указаны номера счетов.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -1005)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-1005, 2, N'Перевод на тот же счет запрещен.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -1205)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-1205, 5, N'Конфликт блокировок. Повторите операцию позже.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -2000)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-2000, 3, N'Недостаточно средств на счете отправителя.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -3000)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-3000, 2, N'Не указан ключ идемпотентности.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -3001)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-3001, 4, N'Операция с этим ключом уже выполняется. Повторите запрос позже.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -3002)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-3002, 5, N'Некорректный ответ подсистемы идемпотентности.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -3003)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-3003, 4, N'Ключ идемпотентности уже использован для другого набора параметров.');
IF NOT EXISTS (SELECT 1 FROM feature255.tblOperationResultStatusMap WHERE ResultCode = -50000)
    INSERT INTO feature255.tblOperationResultStatusMap VALUES (-50000, 5, N'Системная ошибка. Повторите позже или обратитесь в поддержку.');
GO

CREATE OR ALTER FUNCTION feature255.fnGetOperationStatusCode
(
    @ResultCode INT
)
RETURNS INT
AS
BEGIN
    IF @ResultCode IS NULL
        RETURN 5;

    DECLARE @StatusCode INT;

    SELECT @StatusCode = StatusCode
    FROM feature255.tblOperationResultStatusMap
    WHERE ResultCode = @ResultCode;

    IF @StatusCode IS NULL
    BEGIN
        SET @StatusCode = CASE WHEN @ResultCode = 0 THEN 0 ELSE 5 END;
    END;

    RETURN @StatusCode;
END;
GO

CREATE OR ALTER FUNCTION feature255.fnGetOperationStatusMessage
(
    @ResultCode INT
)
RETURNS NVARCHAR(2048)
AS
BEGIN
    IF @ResultCode IS NULL
        RETURN N'Системная ошибка. Повторите позже или обратитесь в поддержку.';

    DECLARE @Message NVARCHAR(2048);

    SELECT @Message = DefaultMessage
    FROM feature255.tblOperationResultStatusMap
    WHERE ResultCode = @ResultCode;

    IF @Message IS NULL
    BEGIN
        SET @Message = CASE
            WHEN @ResultCode = 0 THEN N'Операция выполнена успешно.'
            WHEN @ResultCode = 1 THEN N'Операция уже была успешно выполнена ранее.'
            WHEN @ResultCode < 0 THEN N'Системная ошибка. Повторите позже или обратитесь в поддержку.'
            ELSE N'Неизвестный результат операции.'
        END;
    END;

    RETURN @Message;
END;
GO

/* ---------------------------------------------------------------------------
   6. FEATURE255: ПОРТЫ (СИНОНИМЫ) НА INFRASTRUCTURE
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'feature255.IdempotencyBegin','SN') IS NOT NULL DROP SYNONYM feature255.IdempotencyBegin;
IF OBJECT_ID(N'feature255.IdempotencyComplete','SN') IS NOT NULL DROP SYNONYM feature255.IdempotencyComplete;
IF OBJECT_ID(N'feature255.LockTransferAccounts','SN') IS NOT NULL DROP SYNONYM feature255.LockTransferAccounts;
IF OBJECT_ID(N'feature255.HandleTransferBusinessError','SN') IS NOT NULL DROP SYNONYM feature255.HandleTransferBusinessError;
IF OBJECT_ID(N'feature255.HandleIdempotencyConflict','SN') IS NOT NULL DROP SYNONYM feature255.HandleIdempotencyConflict;
IF OBJECT_ID(N'feature255.WriteBusinessLog','SN') IS NOT NULL DROP SYNONYM feature255.WriteBusinessLog;
IF OBJECT_ID(N'feature255.WriteIdempotentReplayLog','SN') IS NOT NULL DROP SYNONYM feature255.WriteIdempotentReplayLog;
IF OBJECT_ID(N'feature255.LogSystemError','SN') IS NOT NULL DROP SYNONYM feature255.LogSystemError;
GO

CREATE SYNONYM feature255.IdempotencyBegin            FOR oper.IdempotencyBegin;
CREATE SYNONYM feature255.IdempotencyComplete         FOR oper.IdempotencyComplete;
CREATE SYNONYM feature255.LockTransferAccounts        FOR oper.LockTransferAccounts;
CREATE SYNONYM feature255.HandleTransferBusinessError FOR oper.HandleTransferBusinessError;
CREATE SYNONYM feature255.HandleIdempotencyConflict   FOR oper.HandleIdempotencyConflict;
CREATE SYNONYM feature255.WriteBusinessLog            FOR oper.WriteBusinessLog;
CREATE SYNONYM feature255.WriteIdempotentReplayLog    FOR oper.WriteIdempotentReplayLog;
CREATE SYNONYM feature255.LogSystemError              FOR oper.LogSystemError;
GO

/* ---------------------------------------------------------------------------
   7. FEATURE255: ОСНОВНАЯ ПРОЦЕДУРА ПЕРЕВОДА
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE feature255.procTransferMoney
    @OperationId VARCHAR(64),
    @N1 VARCHAR(20),
    @N2 VARCHAR(20),
    @S DECIMAL(18,2),
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
            EXEC feature255.HandleTransferBusinessError @ErrorCode = @ReturnCode, @OperationId = @OperationId, @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;
            RETURN @ResultCode;
        END;

        IF @N1 IS NULL OR @N1 = '' OR @N2 IS NULL OR @N2 = ''
        BEGIN
            SET @ReturnCode = -1004;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);
            EXEC feature255.HandleTransferBusinessError @ErrorCode = @ReturnCode, @OperationId = @OperationId, @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;
            RETURN @ResultCode;
        END;

        IF @S IS NULL OR @S <= 0
        BEGIN
            SET @ReturnCode = -1003;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);
            EXEC feature255.HandleTransferBusinessError @ErrorCode = @ReturnCode, @OperationId = @OperationId, @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;
            RETURN @ResultCode;
        END;

        IF @N1 = @N2
        BEGIN
            SET @ReturnCode = -1005;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);
            EXEC feature255.HandleTransferBusinessError @ErrorCode = @ReturnCode, @OperationId = @OperationId, @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;
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
            EXEC feature255.HandleIdempotencyConflict @OperationId = @OperationId, @ErrorCode = @ReturnCode;
            RETURN @ResultCode;
        END;

        IF @IdempotencyStatus = 1
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;

            EXEC @ReturnCode = feature255.WriteIdempotentReplayLog @OperationId = @OperationId, @PreviousResultCode = @PreviousResult;
            IF @ReturnCode <> 0
            BEGIN
                SET @ResultCode = @ReturnCode;
                SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
                SET @ResultMessage = N'Ошибка логирования идемпотентного повтора.';
                RETURN @ResultCode;
            END;

            SET @ReturnCode = ISNULL(@PreviousResult, 1);
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
            EXEC feature255.HandleIdempotencyConflict @OperationId = @OperationId, @ErrorCode = @ReturnCode;
            RETURN @ResultCode;
        END;

        EXEC @ReturnCode = feature255.LockTransferAccounts @AccountFrom = @N1, @AccountTo = @N2;
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
            EXEC feature255.HandleTransferBusinessError @ErrorCode = @ReturnCode, @OperationId = @OperationId, @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;
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
            EXEC feature255.HandleTransferBusinessError @ErrorCode = @ReturnCode, @OperationId = @OperationId, @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;
            RETURN @ResultCode;
        END;

        UPDATE oper.T
        SET S = S - @S
        WHERE N = @N1 AND S >= @S;

        IF @@ROWCOUNT = 0
        BEGIN
            IF @OuterTranCount = 0 ROLLBACK TRANSACTION;
            ELSE IF @SavepointActive = 1 ROLLBACK TRANSACTION @Savepoint;
            SET @ReturnCode = -2000;
            SET @ResultCode = @ReturnCode;
            SET @StatusCode = feature255.fnGetOperationStatusCode(@ReturnCode);
            SET @ResultMessage = feature255.fnGetOperationStatusMessage(@ReturnCode);
            EXEC feature255.HandleTransferBusinessError @ErrorCode = @ReturnCode, @OperationId = @OperationId, @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;
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
            EXEC feature255.HandleTransferBusinessError @ErrorCode = @ReturnCode, @OperationId = @OperationId, @AccountFrom = @N1, @AccountTo = @N2, @Amount = @S;
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

        EXEC @ReturnCode = feature255.IdempotencyComplete @OperationId = @OperationId, @ResultCode = 0;
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

/* ---------------------------------------------------------------------------
   8. TEST_FEATURE255: ТЕСТОВАЯ ИНФРАСТРУКТУРА С ЗАГЛУШКАМИ
   --------------------------------------------------------------------------- */
IF OBJECT_ID(N'test_feature255.tblIdempotencyRegistry', N'U') IS NULL
BEGIN
    CREATE TABLE test_feature255.tblIdempotencyRegistry
    (
        OperationId   VARCHAR(64) NOT NULL,
        OperationType VARCHAR(20) NOT NULL,
        AccountFrom   VARCHAR(20) NOT NULL,
        AccountTo     VARCHAR(20) NOT NULL,
        Amount        DECIMAL(18,2) NOT NULL,
        Status        TINYINT NOT NULL,
        ResultCode    INT NULL,
        CONSTRAINT pk_test_feature255_tblIdempotencyRegistry PRIMARY KEY (OperationId)
    );
END;
GO

IF OBJECT_ID(N'test_feature255.tblStubBehavior', N'U') IS NULL
BEGIN
    CREATE TABLE test_feature255.tblStubBehavior
    (
        StubName     VARCHAR(64) NOT NULL,
        ReturnValue  INT NOT NULL,
        ThrowError   BIT NOT NULL DEFAULT 0,
        CONSTRAINT pk_test_feature255_tblStubBehavior PRIMARY KEY (StubName)
    );
END;
GO

IF OBJECT_ID(N'test_feature255.tblStubLog', N'U') IS NULL
BEGIN
    CREATE TABLE test_feature255.tblStubLog
    (
        LogId       BIGINT IDENTITY(1,1) NOT NULL,
        StubName    VARCHAR(64) NOT NULL,
        CallArgs    NVARCHAR(4000) NULL,
        CreatedAt   DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
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
    DELETE FROM oper.T;
    INSERT INTO oper.T (N, S) VALUES ('A', 1000.00), ('B', 0.00), ('C', 50.00);
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

CREATE OR ALTER PROCEDURE test_feature255.procUseProdInfrastructure
AS
BEGIN
    SET NOCOUNT ON;

    EXEC(N'
        IF OBJECT_ID(N''feature255.IdempotencyBegin'',''SN'') IS NOT NULL DROP SYNONYM feature255.IdempotencyBegin;
        IF OBJECT_ID(N''feature255.IdempotencyComplete'',''SN'') IS NOT NULL DROP SYNONYM feature255.IdempotencyComplete;
        IF OBJECT_ID(N''feature255.LockTransferAccounts'',''SN'') IS NOT NULL DROP SYNONYM feature255.LockTransferAccounts;
        IF OBJECT_ID(N''feature255.HandleTransferBusinessError'',''SN'') IS NOT NULL DROP SYNONYM feature255.HandleTransferBusinessError;
        IF OBJECT_ID(N''feature255.HandleIdempotencyConflict'',''SN'') IS NOT NULL DROP SYNONYM feature255.HandleIdempotencyConflict;
        IF OBJECT_ID(N''feature255.WriteBusinessLog'',''SN'') IS NOT NULL DROP SYNONYM feature255.WriteBusinessLog;
        IF OBJECT_ID(N''feature255.WriteIdempotentReplayLog'',''SN'') IS NOT NULL DROP SYNONYM feature255.WriteIdempotentReplayLog;
        IF OBJECT_ID(N''feature255.LogSystemError'',''SN'') IS NOT NULL DROP SYNONYM feature255.LogSystemError;

        CREATE SYNONYM feature255.IdempotencyBegin            FOR oper.IdempotencyBegin;
        CREATE SYNONYM feature255.IdempotencyComplete         FOR oper.IdempotencyComplete;
        CREATE SYNONYM feature255.LockTransferAccounts        FOR oper.LockTransferAccounts;
        CREATE SYNONYM feature255.HandleTransferBusinessError FOR oper.HandleTransferBusinessError;
        CREATE SYNONYM feature255.HandleIdempotencyConflict   FOR oper.HandleIdempotencyConflict;
        CREATE SYNONYM feature255.WriteBusinessLog            FOR oper.WriteBusinessLog;
        CREATE SYNONYM feature255.WriteIdempotentReplayLog    FOR oper.WriteIdempotentReplayLog;
        CREATE SYNONYM feature255.LogSystemError              FOR oper.LogSystemError;
    ');
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.procUseTestInfrastructure
AS
BEGIN
    SET NOCOUNT ON;

    EXEC(N'
        IF OBJECT_ID(N''feature255.IdempotencyBegin'',''SN'') IS NOT NULL DROP SYNONYM feature255.IdempotencyBegin;
        IF OBJECT_ID(N''feature255.IdempotencyComplete'',''SN'') IS NOT NULL DROP SYNONYM feature255.IdempotencyComplete;
        IF OBJECT_ID(N''feature255.LockTransferAccounts'',''SN'') IS NOT NULL DROP SYNONYM feature255.LockTransferAccounts;
        IF OBJECT_ID(N''feature255.HandleTransferBusinessError'',''SN'') IS NOT NULL DROP SYNONYM feature255.HandleTransferBusinessError;
        IF OBJECT_ID(N''feature255.HandleIdempotencyConflict'',''SN'') IS NOT NULL DROP SYNONYM feature255.HandleIdempotencyConflict;
        IF OBJECT_ID(N''feature255.WriteBusinessLog'',''SN'') IS NOT NULL DROP SYNONYM feature255.WriteBusinessLog;
        IF OBJECT_ID(N''feature255.WriteIdempotentReplayLog'',''SN'') IS NOT NULL DROP SYNONYM feature255.WriteIdempotentReplayLog;
        IF OBJECT_ID(N''feature255.LogSystemError'',''SN'') IS NOT NULL DROP SYNONYM feature255.LogSystemError;

        CREATE SYNONYM feature255.IdempotencyBegin            FOR test_feature255.IdempotencyBegin;
        CREATE SYNONYM feature255.IdempotencyComplete         FOR test_feature255.IdempotencyComplete;
        CREATE SYNONYM feature255.LockTransferAccounts        FOR test_feature255.LockTransferAccounts;
        CREATE SYNONYM feature255.HandleTransferBusinessError FOR test_feature255.HandleTransferBusinessError;
        CREATE SYNONYM feature255.HandleIdempotencyConflict   FOR test_feature255.HandleIdempotencyConflict;
        CREATE SYNONYM feature255.WriteBusinessLog            FOR test_feature255.WriteBusinessLog;
        CREATE SYNONYM feature255.WriteIdempotentReplayLog    FOR test_feature255.WriteIdempotentReplayLog;
        CREATE SYNONYM feature255.LogSystemError              FOR test_feature255.LogSystemError;
    ');
END;
GO

/* ---------------------------------------------------------------------------
   9. TEST_FEATURE255: ЗАГЛУШКИ АДАПТЕРОВ
   --------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE test_feature255.IdempotencyBegin
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
    DECLARE @ReturnValue INT = 0;
    DECLARE @ThrowError BIT = 0;
    SELECT @ReturnValue = ReturnValue, @ThrowError = ThrowError
    FROM test_feature255.tblStubBehavior
    WHERE StubName = 'IdempotencyBegin';

    INSERT INTO test_feature255.tblStubLog (StubName, CallArgs)
    VALUES ('IdempotencyBegin', CONCAT(@OperationId, '|', @OperationType, '|', @AccountFrom, '|', @AccountTo, '|', @Amount));

    IF @ThrowError = 1
        THROW 50000, 'Stub IdempotencyBegin threw error', 1;

    IF EXISTS (SELECT 1 FROM test_feature255.tblIdempotencyRegistry WHERE OperationId = @OperationId)
    BEGIN
        DECLARE @State TINYINT;
        DECLARE @LastResult INT;
        SELECT @State = Status, @LastResult = ResultCode
        FROM test_feature255.tblIdempotencyRegistry
        WHERE OperationId = @OperationId;

        SET @Status = @State;
        SET @PreviousResultCode = @LastResult;
        RETURN @ReturnValue;
    END;

    INSERT INTO test_feature255.tblIdempotencyRegistry
        (OperationId, OperationType, AccountFrom, AccountTo, Amount, Status, ResultCode)
    VALUES (@OperationId, @OperationType, @AccountFrom, @AccountTo, @Amount, 0, NULL);

    SET @Status = 0;
    SET @PreviousResultCode = NULL;
    RETURN 0;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.IdempotencyComplete
    @OperationId VARCHAR(64),
    @ResultCode INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReturnValue INT = 0;
    DECLARE @ThrowError BIT = 0;
    SELECT @ReturnValue = ReturnValue, @ThrowError = ThrowError
    FROM test_feature255.tblStubBehavior
    WHERE StubName = 'IdempotencyComplete';

    INSERT INTO test_feature255.tblStubLog (StubName, CallArgs)
    VALUES ('IdempotencyComplete', CONCAT(@OperationId, '|', @ResultCode));

    IF @ThrowError = 1
        THROW 50000, 'Stub IdempotencyComplete threw error', 1;

    UPDATE test_feature255.tblIdempotencyRegistry
    SET Status = 1,
        ResultCode = @ResultCode
    WHERE OperationId = @OperationId;

    RETURN @ReturnValue;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.LockTransferAccounts
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReturnValue INT = 0;
    DECLARE @ThrowError BIT = 0;
    SELECT @ReturnValue = ReturnValue, @ThrowError = ThrowError
    FROM test_feature255.tblStubBehavior
    WHERE StubName = 'LockTransferAccounts';

    INSERT INTO test_feature255.tblStubLog (StubName, CallArgs)
    VALUES ('LockTransferAccounts', CONCAT(@AccountFrom, '|', @AccountTo));

    IF @ThrowError = 1
        THROW 50000, 'Stub LockTransferAccounts threw error', 1;

    RETURN @ReturnValue;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.HandleTransferBusinessError
    @ErrorCode INT,
    @OperationId VARCHAR(64),
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20),
    @Amount DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReturnValue INT = 0;
    DECLARE @ThrowError BIT = 0;
    SELECT @ReturnValue = ReturnValue, @ThrowError = ThrowError
    FROM test_feature255.tblStubBehavior
    WHERE StubName = 'HandleTransferBusinessError';

    INSERT INTO test_feature255.tblStubLog (StubName, CallArgs)
    VALUES ('HandleTransferBusinessError', CONCAT(@ErrorCode, '|', @OperationId, '|', @AccountFrom, '|', @AccountTo, '|', @Amount));

    IF @ThrowError = 1
        THROW 50000, 'Stub HandleTransferBusinessError threw error', 1;

    RETURN @ReturnValue;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.HandleIdempotencyConflict
    @OperationId VARCHAR(64),
    @ErrorCode INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReturnValue INT = 0;
    DECLARE @ThrowError BIT = 0;
    SELECT @ReturnValue = ReturnValue, @ThrowError = ThrowError
    FROM test_feature255.tblStubBehavior
    WHERE StubName = 'HandleIdempotencyConflict';

    INSERT INTO test_feature255.tblStubLog (StubName, CallArgs)
    VALUES ('HandleIdempotencyConflict', CONCAT(@OperationId, '|', @ErrorCode));

    IF @ThrowError = 1
        THROW 50000, 'Stub HandleIdempotencyConflict threw error', 1;

    RETURN @ReturnValue;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.WriteBusinessLog
    @OperationType VARCHAR(20),
    @OperationId VARCHAR(64),
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20),
    @Amount DECIMAL(18,2),
    @ResultCode INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReturnValue INT = 0;
    DECLARE @ThrowError BIT = 0;
    SELECT @ReturnValue = ReturnValue, @ThrowError = ThrowError
    FROM test_feature255.tblStubBehavior
    WHERE StubName = 'WriteBusinessLog';

    INSERT INTO test_feature255.tblStubLog (StubName, CallArgs)
    VALUES ('WriteBusinessLog', CONCAT(@OperationType, '|', @OperationId, '|', @AccountFrom, '|', @AccountTo, '|', @Amount, '|', @ResultCode));

    IF @ThrowError = 1
        THROW 50000, 'Stub WriteBusinessLog threw error', 1;

    RETURN @ReturnValue;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.WriteIdempotentReplayLog
    @OperationId VARCHAR(64),
    @PreviousResultCode INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReturnValue INT = 0;
    DECLARE @ThrowError BIT = 0;
    SELECT @ReturnValue = ReturnValue, @ThrowError = ThrowError
    FROM test_feature255.tblStubBehavior
    WHERE StubName = 'WriteIdempotentReplayLog';

    INSERT INTO test_feature255.tblStubLog (StubName, CallArgs)
    VALUES ('WriteIdempotentReplayLog', CONCAT(@OperationId, '|', @PreviousResultCode));

    IF @ThrowError = 1
        THROW 50000, 'Stub WriteIdempotentReplayLog threw error', 1;

    RETURN @ReturnValue;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.LogSystemError
    @ErrorNumber INT,
    @ErrorMessage NVARCHAR(4000),
    @OperationId VARCHAR(64),
    @AccountFrom VARCHAR(20),
    @AccountTo VARCHAR(20),
    @Amount DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @ReturnValue INT = 0;
    DECLARE @ThrowError BIT = 0;
    SELECT @ReturnValue = ReturnValue, @ThrowError = ThrowError
    FROM test_feature255.tblStubBehavior
    WHERE StubName = 'LogSystemError';

    INSERT INTO test_feature255.tblStubLog (StubName, CallArgs)
    VALUES ('LogSystemError', CONCAT(@ErrorNumber, '|', @ErrorMessage, '|', @OperationId, '|', @AccountFrom, '|', @AccountTo, '|', @Amount));

    IF @ThrowError = 1
        THROW 50000, 'Stub LogSystemError threw error', 1;

    RETURN @ReturnValue;
END;
GO

/* ---------------------------------------------------------------------------
   10. ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ
   --------------------------------------------------------------------------- */
-- Контрактный режим: через боевую инфраструктуру oper
-- EXEC test_feature255.procUseProdInfrastructure;
-- EXEC test_feature255.procResetEnvironment;
-- DECLARE @RC INT, @SC INT, @Msg NVARCHAR(2048);
-- EXEC @RC = feature255.procTransferMoney @OperationId='SMOKE-01', @N1='A', @N2='B', @S=10.00, @ResultCode=@RC OUTPUT, @StatusCode=@SC OUTPUT, @ResultMessage=@Msg OUTPUT;
-- SELECT @RC AS ResultCode, @SC AS StatusCode, @Msg AS Message;

-- Тестовый режим: через заглушки test_feature255
-- EXEC test_feature255.procUseTestInfrastructure;
-- EXEC test_feature255.procResetEnvironment;
-- EXEC test_feature255.procSetStubBehavior 'IdempotencyBegin', 0, 0;
-- DECLARE @RC2 INT, @SC2 INT, @Msg2 NVARCHAR(2048);
-- EXEC @RC2 = feature255.procTransferMoney @OperationId='SMOKE-TEST', @N1='A', @N2='B', @S=10.00, @ResultCode=@RC2 OUTPUT, @StatusCode=@SC2 OUTPUT, @ResultMessage=@Msg2 OUTPUT;
-- SELECT @RC2 AS ResultCode, @SC2 AS StatusCode, @Msg2 AS Message;
GO

SELECT 'DEPLOY_OK' AS Status;
GO
