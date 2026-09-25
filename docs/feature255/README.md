# Фича 255: идемпотентный перевод средств

## 1. Контуры

| Контур | Схема | Назначение |
|---|---|---|
| PROD | `oper` | Боевая инфраструктура и рабочие адаптеры |
| FEATURE | `feature255` | Новая редакция процедуры перевода и контракт результата |
| TEST | `test_feature255` | Пустышки адаптеров, заглушки, тестовые данные и раннеры |

Принцип: вся инфраструктура живет в проде (`oper`). Новая редакция логики изолируется в схеме `feature255` и обращается к боевым объектам через синонимы-порты.

## 2. Схема взаимодействий

```text
feature255.procTransferMoney
        | вызов порта (синонима)
        v
feature255.<порт>  --синоним-->  oper.<адаптер>           (боевой режим)
                                \--> test_feature255.<адаптер> (тестовый режим)
```

Переключение режимов выполняется через:

```sql
EXEC test_feature255.procUseProdInfrastructure;
EXEC test_feature255.procUseTestInfrastructure;
```

## 3. Цели фичи

- выполнить перевод средств в идемпотентном режиме;
- обеспечить безопасный контракт результата;
- отделить бизнес-логику от инфраструктуры;
- покрыть сценарии повторов, конфликтов, валидаций и системных ошибок.

## 4. Объекты продакта

| Объект | Тип | Назначение |
|---|---|---|
| `oper.T` | таблица | Счета: `N` (PK), `S` |
| `oper.tblIdempotencyRegistry` | таблица | Реестр идемпотентности |
| `oper.tblBusinessOperationLog` | таблица | Бизнес-журнал |
| `oper.tblSystemErrorLog` | таблица | Технический журнал ошибок |
| `oper.IdempotencyBegin` | процедура | Регистрация идемпотентного ключа |
| `oper.IdempotencyComplete` | процедура | Завершение операции |
| `oper.LockTransferAccounts` | процедура | Блокировка счетов |
| `oper.HandleTransferBusinessError` | процедура | Бизнес-ошибка |
| `oper.HandleIdempotencyConflict` | процедура | Конфликт идемпотентности |
| `oper.WriteBusinessLog` | процедура | Бизнес-журнал |
| `oper.WriteIdempotentReplayLog` | процедура | Лог повторов |
| `oper.LogSystemError` | процедура | Технический лог |
| `oper.procTransferMoney` | процедура | Текущая рабочая версия |

## 5. Объекты фичи

| Объект | Тип | Назначение |
|---|---|---|
| `feature255.procTransferMoney` | процедура | Новая редакция перевода |
| `feature255.tblOperationStatus` | таблица | Справочник статусов |
| `feature255.tblOperationResultStatusMap` | таблица | Отображение кода результата |
| `feature255.fnGetOperationStatusCode` | функция | Код статуса по коду результата |
| `feature255.fnGetOperationStatusMessage` | функция | Сообщение по коду результата |
| 8 синонимов-портов | синонимы | Порты на адаптеры инфраструктуры |

## 6. Контракт результата

Коды результата:

| Код | Значение | Статус |
|---|---|---|
| 0 | Перевод выполнен | SUCCESS |
| 1 | Идемпотентный повтор | DUPLICATE_SUCCESS |
| -1001 | Счет отправителя не найден | BUSINESS_ERROR |
| -1002 | Счет получателя не найден | BUSINESS_ERROR |
| -1003 | Некорректная сумма | VALIDATION_ERROR |
| -1004 | Некорректные номера счетов | VALIDATION_ERROR |
| -1005 | Перевод на тот же счет | VALIDATION_ERROR |
| -1205 | Конфликт блокировок | SYSTEM_ERROR |
| -2000 | Недостаточно средств | BUSINESS_ERROR |
| -3000 | Нет ключа идемпотентности | VALIDATION_ERROR |
| -3001 | Операция уже выполняется | CONFLICT |
| -3002 | Некорректный ответ подсистемы | SYSTEM_ERROR |
| -3003 | Ключ использован для других параметров | CONFLICT |
| -50000 | Системная ошибка | SYSTEM_ERROR |

## 7. Порядок развертывания

```text
1. oper: таблица T, 3 таблицы инфраструктуры, 8 рабочих адаптеров.
2. feature255: файл feature255_objects.sql.
3. test_feature255: таблицы, пустышки, хелперы, тесты, раннеры.
4. EXEC test_feature255.procUseProdInfrastructure;
5. Запуск контрактных и unit-тестов.
```

## 8. Проверка после деплоя

```sql
SELECT s.name AS Port, s.base_object_name AS PointsTo
FROM sys.synonyms s
WHERE s.schema_id = SCHEMA_ID(N'feature255');

DECLARE @RC INT, @SC INT, @Msg NVARCHAR(2048);
EXEC @RC = feature255.procTransferMoney
    @OperationId = 'SMOKE-01', @N1 = 'A', @N2 = 'B', @S = 10.00,
    @ResultCode = @RC OUTPUT, @StatusCode = @SC OUTPUT, @ResultMessage = @Msg OUTPUT;
SELECT @RC AS ResultCode, @SC AS StatusCode, @Msg AS Message;
```

Для более подробной технической схемы см. [feature255_spec.md](feature255_spec.md).
