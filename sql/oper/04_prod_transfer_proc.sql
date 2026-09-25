/* ============================================================================
   OPER. БОЕВАЯ РЕДАКЦИЯ ПРОЦЕДУРЫ ПЕРЕВОДА
   ============================================================================ */
GO
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

    -- Здесь должна быть текущая боевая процедура из VCS.
    -- После промоушена новой фичи эта логика будет заменена на реализацию из feature255.
    IF @N1 IS NULL OR @N2 IS NULL OR @S IS NULL
    BEGIN
        SET @ResultCode = -1004;
        SET @StatusCode = 2;
        SET @ResultMessage = N'Не указаны номера счетов или сумма.';
        RETURN @ResultCode;
    END;

    SET @ResultCode = 0;
    SET @StatusCode = 0;
    SET @ResultMessage = N'Операция выполнена успешно.';
    RETURN 0;
END;
GO
