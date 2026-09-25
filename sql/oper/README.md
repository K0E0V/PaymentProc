# Boeвой контур: `oper`

Данный раздел содержит описание рабочих объектов операционного контура. Полный набор объектов должен быть развернут до запуска фичи `feature255`.

## Обязательные объекты

- `oper.T` — таблица счетов;
- `oper.tblIdempotencyRegistry` — реестр идемпотентности;
- `oper.tblBusinessOperationLog` — бизнес-журнал;
- `oper.tblSystemErrorLog` — технический журнал;
- `oper.IdempotencyBegin` — регистрация ключа;
- `oper.IdempotencyComplete` — завершение операции;
- `oper.LockTransferAccounts` — блокировка счетов;
- `oper.HandleTransferBusinessError` — фиксация бизнес-ошибки;
- `oper.HandleIdempotencyConflict` — фиксация конфликта;
- `oper.WriteBusinessLog` — запись бизнес-логов;
- `oper.WriteIdempotentReplayLog` — запись логов повторного вызова;
- `oper.LogSystemError` — логирование системных ошибок;
- `oper.procTransferMoney` — текущая боевая процедура.

## Набор скриптов

- `sql/oper/01_oper_core.sql` — таблицы и базовые объекты;
- `sql/oper/02_idempotency_adapters.sql` — адаптеры идемпотентности;
- `sql/oper/03_transfer_adapters.sql` — адаптеры перевода и логирования;
- `sql/oper/04_prod_transfer_proc.sql` — боевая редакция `procTransferMoney`.

## Принцип работы

Сценарии и операции в `oper` должны быть детерминированными, транзакционными и безопасными для повторных вызовов. Объекты этого контура остаются рабочей инфраструктурой и используются через синонимы из `feature255`.
