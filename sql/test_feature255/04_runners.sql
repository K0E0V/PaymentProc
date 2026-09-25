/* ============================================================================
   TEST_FEATURE255. RUNNERS
   ============================================================================ */
GO
CREATE OR ALTER PROCEDURE test_feature255.procRunUnitTests
AS
BEGIN
    SET NOCOUNT ON;
    -- Последовательный запуск test_01 ... test_16.
    EXEC test_feature255.test_01_success;
    EXEC test_feature255.test_02_validation_missing_account;
    EXEC test_feature255.test_03_business_error_sender_not_found;
    EXEC test_feature255.test_04_business_error_receiver_not_found;
    EXEC test_feature255.test_05_insufficient_funds;
    EXEC test_feature255.test_06_idempotent_duplicate_success;
    EXEC test_feature255.test_07_idempotent_conflict_in_progress;
    EXEC test_feature255.test_08_idempotent_key_reused_with_other_params;
    EXEC test_feature255.test_09_system_error_on_adapter_failure;
    EXEC test_feature255.test_10_lock_conflict;
    EXEC test_feature255.test_11_missing_operation_id;
    EXEC test_feature255.test_12_result_code_mapping;
    EXEC test_feature255.test_13_replay_log_written;
    EXEC test_feature255.test_14_business_log_written;
    EXEC test_feature255.test_15_system_error_logging;
    EXEC test_feature255.test_16_atomicity_on_error;
END;
GO

CREATE OR ALTER PROCEDURE test_feature255.procRunContractTests
AS
BEGIN
    SET NOCOUNT ON;
    -- Последовательный запуск contract-тестов.
    EXEC test_feature255.test_c01_contract_success_against_oper;
    EXEC test_feature255.test_c02_contract_idempotency_against_oper;
    EXEC test_feature255.test_c03_contract_validation_against_oper;
    EXEC test_feature255.test_c04_contract_infrastructure_consistency;
END;
GO
