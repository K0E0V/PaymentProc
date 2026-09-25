/* ============================================================================
   FEATURE 255. ИДЕМПОТЕНТНЫЙ ПЕРЕВОД СРЕДСТВ. СХЕМА И СЛОВАРИ
   ============================================================================ */
GO
IF SCHEMA_ID(N'feature255') IS NULL
    EXEC sp_executesql N'CREATE SCHEMA feature255 AUTHORIZATION dbo;';
GO

IF OBJECT_ID(N'feature255.tblOperationStatus', N'U') IS NULL
BEGIN
    CREATE TABLE feature255.tblOperationStatus
    (
        StatusCode        INT           NOT NULL,
        StatusName        VARCHAR(30)   NOT NULL,
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
        ResultCode     INT            NOT NULL,
        StatusCode     INT            NOT NULL,
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
