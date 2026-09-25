/* ============================================================================
   TEST_FEATURE255. CONTRACT-TESTS
   ============================================================================ */
GO
CREATE OR ALTER PROCEDURE test_feature255.test_c01_contract_success_against_oper
AS
BEGIN
    SET NOCOUNT ON;
    -- Для реального стенда проверка успеха операции в `oper`.
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_c02_contract_idempotency_against_oper
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_c03_contract_validation_against_oper
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_c04_contract_infrastructure_consistency
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO
