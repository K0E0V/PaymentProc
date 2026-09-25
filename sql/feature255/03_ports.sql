/* ============================================================================
   FEATURE 255. ПОРТЫ: СИНОНИМЫ НА BOEВУЮ ИНФРАСТРУКТУРУ oper
   ============================================================================ */
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

SELECT s.name AS Port, s.base_object_name AS PointsTo
FROM sys.synonyms s
WHERE s.schema_id = SCHEMA_ID(N'feature255');
GO
