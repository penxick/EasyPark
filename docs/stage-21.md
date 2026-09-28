# Этап 21 — Финальная сборка

Подготовлен локальный MVP: актуальная инструкция запуска, проверенные .env.example,
docker-compose.yml, backend, CV, миграции, seed и обычный Android debug APK.
Финальная проверка завершена 29 сентября 2026 года. Новая функциональность не добавлялась.

## Android-артефакт

- Путь: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
- Размер: 180940785 байт (около 173 МиБ).
- SHA-256: `6C2A04BDA9CADB16FEF615101446440F8FB2C0B67A6F942EBE82659C6A51BEE2`.
- Package: com.easypark.easypark, версия 0.1.0, versionCode 1.
- minSdk 24, targetSdk 36; launcher: com.easypark.easypark.MainActivity.
- Встроенный API: http://10.0.2.2:3000/api/ для Android Emulator.

Сборка выполнена из mobile:

```powershell
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/
```

Успешно создан обычный APK, заменивший инструментальную сборку этапа 20.
Метаданные проверены через aapt dump badging; apksigner verify --verbose завершился
успешно, подпись APK v2 корректна. Это локальная debug-сборка, не публикационный
release: production URL и собственный ключ подписи не заданы. iOS не собирался.
Android-сценарий с настоящим backend и secure storage прошёл на этапе 20;
установка именно финального APK на устройство в этапе 21 не выполнялась.

## Серверы, конфигурация и БД

- `docker compose config --quiet` — успешно.
- `docker compose up -d --build --wait` — backend и CV собраны, все сервисы готовы.
- После перерыва Docker Desktop был остановлен. Он запущен повторно, существующие
  сервисы восстановлены через `docker compose up -d --wait` без удаления данных.
- Backend /health и CV /health — status=ok.
- `docker compose exec -T backend npm run migration:run` — Applied migrations: 0.
- `docker compose exec -T backend npm run seed` — вставлено 0 парковок и 0 мест:
  существующие демоданные сохранены, повторный seed не создаёт дубликаты.

Проверены четыре существующие миграции: users, parkings, parking_spaces и
reservations. Автосинхронизация отключена; миграции выполняются до запуска backend.
.env.example содержит необходимые DB/JWT/port/MODEL_PATH параметры, приватный
.env не изменялся. Compose использует healthchecks, постоянный PostgreSQL volume,
локальные порты и read-only каталог пользовательских моделей.

## Файлы

Создан `docs/stage-21.md` — итоговый отчёт.

Изменён `README.md` — вместо накопившихся устаревших описаний этапов теперь
содержит актуальные возможности, команды запуска, миграции/seed, Android-сборку,
API, CV, проверки и ограничения. Удалены неверные утверждения о заглушках карты,
неработающем бронировании и неначатых этапах CV.

Обновлены генерируемый APK, файлы сборки Flutter/Gradle и Docker-образы backend/CV.
Исходный код приложения, зависимости, .env.example, docker-compose.yml, миграции
и seed проверены и сохранены без ненужных изменений.

Все 75 исходных файлов ТЗ и Figma совпадают с source-materials.sha256.json.

## Проверки и ограничения

Полная регрессия этапа 20: 38 backend-, 78 Flutter- и 30 CV-тестов прошли,
как и Android logout, Docker API smoke, анализаторы и форматирование.
После этого рабочий код не менялся; повторная полная регрессия не требовалась.
В этапе 21 проверены сборка, подпись/метаданные APK, Compose, запуск, health,
миграции и seed. README и отчёт отформатированы Prettier.

Ошибок сборки не осталось. Известное предупреждение Starlette TestClient об httpx
описано в этапе 20. CV остаётся самостоятельным сервисом; accuracy на реальных
парковках не измерялась. Реальные платежи, публикация в магазине, production
развёртывание и обучение модели не выполнялись.

Этап 21 завершён. Работа остановлена в ожидании отдельной команды.
