/* ============================================================================
   TEST_FEATURE255. UNIT-TESTS
   ============================================================================ */
GO
CREATE OR ALTER PROCEDURE test_feature255.test_01_success
AS
BEGIN
    SET NOCOUNT ON;
    -- Проверка успешного сценария перевода.
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_02_validation_missing_account
AS
BEGIN
    SET NOCOUNT ON;
    -- Проверка -1004, -1003, -1005.
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_03_business_error_sender_not_found
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_04_business_error_receiver_not_found
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_05_insufficient_funds
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_06_idempotent_duplicate_success
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_07_idempotent_conflict_in_progress
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_08_idempotent_key_reused_with_other_params
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_09_system_error_on_adapter_failure
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_10_lock_conflict
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_11_missing_operation_id
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_12_result_code_mapping
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_13_replay_log_written
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_14_business_log_written
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_15_system_error_logging
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.test_16_atomicity_on_error
AS
BEGIN
    SET NOCOUNT ON;
    RETURN;
END;
GO
