/* ============================================================================
   FEATURE 255. КОНТРАКТ РЕЗУЛЬТАТА
   ============================================================================ */
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
        SET @StatusCode = CASE
                              WHEN @ResultCode = 0 THEN 0
                              ELSE 5
                          END;
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
