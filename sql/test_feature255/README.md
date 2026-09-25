# Тестовый контур: `test_feature255`

Этот контур служит для проверки сценариев отказа и идемпотентности без влияния на боевую инфраструктуру.

## Основные компоненты

- `tblIdempotencyRegistry` — подложка реестра идемпотентности;
- `tblStubBehavior` — поведение заглушек: `ReturnValue` и `ThrowError`;
- `tblStubLog` — лог вызовов заглушек;
- 8 пустышек с именами портов;
- `procResetEnvironment` — сброс окружения и начальные данные;
- `procSetStubBehavior` — настройка заглушки;
- `procUseProdInfrastructure` — переключение на `oper.*`;
- `procUseTestInfrastructure` — переключение на `test_feature255.*`;
- `AssertEqualInt`, `AssertEqualDecimal` — ассерты;
- набор тестов `test_01 ... test_16`;
- проверка контрактов `test_c01 ...`;
- раннеры `procRunUnitTests`, `procRunContractTests`.

## Режимы выполнения

```sql
EXEC test_feature255.procUseProdInfrastructure;
EXEC test_feature255.procResetEnvironment;
EXEC test_feature255.procRunContractTests;

EXEC test_feature255.procUseTestInfrastructure;
EXEC test_feature255.procResetEnvironment;
EXEC test_feature255.procRunUnitTests;
```

## Требования к реализации

- тесты должны запускаться изолированно;
- поведение заглушек должно быть явно управляемым;
- проверка результата должна происходить через ассерты и `THROW` при расхождении;
- не должно быть побочного влияния между сериями тестов.
