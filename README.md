# EasyPark — локальный MVP, этап 21

## Получить проект на другом компьютере

```powershell
git clone https://github.com/penxick/EasyParkA.git D:\EasyPark
cd D:\EasyPark
Copy-Item .env.example .env
```

Отредактируйте `.env`: замените `POSTGRES_PASSWORD` и `JWT_SECRET` своими
значениями. Для JWT_SECRET нужен случайный секрет длиной не менее 32 байт.
Установите Docker Desktop и запустите команды раздела «Запуск серверов» ниже.
Демопарковки создаются командой seed. Локальная база пользователей и броней
не хранится в Git: на новом компьютере она будет пустой, зарегистрируйтесь снова.

Для Android установите Flutter и Android SDK, затем выполните команды раздела
«Android». Сборочные каталоги, `node_modules`, Python-окружение и APK не входят
в репозиторий: Docker и Flutter восстановят их при сборке. Исходные материалы ТЗ
и Figma входят в репозиторий без изменений.

Flutter-приложение поиска и бронирования парковок, NestJS backend с PostgreSQL
и отдельный FastAPI CV-сервис. Этапы 0–21 выполнены; результаты финальной сборки
описаны в [отчёте этапа 21](docs/stage-21.md), матрица тестирования —
в [отчёте этапа 20](docs/stage-20.md).

## Возможности

Регистрация, вход и восстановление JWT-сессии; карта OpenStreetMap; информация
о парковке и схема мест; бронирование на 30/60/120/180 минут; отмена и история;
профиль и выход. Backend защищает от двойной брони транзакциями и уникальным
индексом, автоматически завершает истёкшие брони. CV распознаёт транспорт готовой
YOLO11n на CPU, принимает тестовые изображения и поддерживает локальные веса
через MODEL_PATH. Обучение не выполняется, CV не подключён к Flutter.

## Структура

- `mobile/` — Flutter/Dart, Android/iOS исходники.
- `backend/` — NestJS/TypeScript, TypeORM, миграции и seed.
- `cv-service/` — Python/FastAPI, YOLO и CLI проверки изображений.
- `docs/stage-0.md` … `docs/stage-21.md` — отчёты разработки.
- `docs/tz/` и `docs/figma-reference/` — защищённые исходные материалы.
- `source-materials.sha256.json` — контрольные суммы 75 исходных файлов.

React/Vite экспорт использован как дизайн-источник; приложение реализовано
Flutter widgets без переноса web-зависимостей. Корень проекта — D:\EasyPark.

## Требования

Windows PowerShell, Docker Desktop с Linux containers и Compose v2.
Проверены Flutter 3.38.3 / Dart 3.10.1, Android SDK и JDK 17; Android минимум API 24.
Для backend вне Docker нужен Node.js 22.13+ либо 24+, для CV рекомендуется
Docker с Python 3.11. CLI detect_image.py использует стандартную библиотеку Python.
iOS требует macOS/Xcode и здесь не собирался.

## Запуск серверов

Из D:\EasyPark:

```powershell
# Только если .env ещё отсутствует:
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
# Отредактируйте .env: задайте собственные POSTGRES_PASSWORD и JWT_SECRET.
# JWT_SECRET — случайный секрет не менее 32 байт, не значение-заглушка.
docker compose config --quiet
docker compose up -d --build --wait
docker compose exec -T backend npm run seed
docker compose ps
Invoke-RestMethod http://127.0.0.1:3000/health
Invoke-RestMethod http://127.0.0.1:8000/health
```

Backend и CV возвращают status=ok. При смене портов в .env измените URL.
Опубликованы только локальные порты: backend 3000, CV 8000, PostgreSQL 55432.
Первоначальная сборка CV скачивает зависимости и официальные веса с проверкой
SHA-256; при обычном запуске модель уже находится в образе.

Backend автоматически выполняет четыре миграции перед запуском HTTP; ошибка
миграции останавливает запуск. synchronize и migrationsRun отключены.
Миграции создают users, parkings, parking_spaces и reservations с ограничениями.
Повторная ручная проверка:

```powershell
docker compose exec -T backend npm run migration:run
```

Seed вручную создаёт три демопарковки и по 20 мест без перезаписи существующих
записей. Учётные записи создаются через приложение, общего пароля нет.
PostgreSQL хранит данные в volume easypark_postgres_data. Изменение пароля в .env
не меняет пароль уже созданной БД.

```powershell
docker compose logs --tail 100
docker compose down
```

Обычный down сохраняет данные; down -v удаляет том и для обычной остановки не нужен.

## Android

```powershell
Set-Location D:\EasyPark\mobile
flutter pub get
flutter doctor
flutter emulators --launch Pixel_7
flutter devices
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/
```

Используйте имя доступного у вас AVD вместо Pixel_7. Адрес 10.0.2.2 ведёт с
Android Emulator на компьютер с Docker. Карта требует интернета для OSM-плиток.
После входа доступны карта, бронирования и профиль.

Финальная локальная сборка обычного приложения:

```powershell
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
Это debug APK для локального MVP, не пакет для публикации. В release-конфигурации
пока используется debug signing; перед публикацией потребуются собственная
подпись и HTTPS API. Production-адрес не задан. API_BASE_URL встраивается при
сборке, изменение .env сервера не меняет адрес внутри APK.
Для физического устройства нужен доступный ему backend или USB adb reverse
и отдельная сборка с API_BASE_URL=http://127.0.0.1:3000/api/.

## CV

```powershell
Set-Location D:\EasyPark
python cv-service/tools/detect_image.py "D:\Pictures\parking.jpg"
```

POST /detect принимает бинарный JPEG/PNG до 5 МиБ и 12 миллионов пикселей.
Ответ содержит vehicles с type, confidence и bbox. Пустой список — успешный
результат. Ошибки CLI выводятся в stderr, код завершения 1; успешный JSON — stdout,
код 0. Изображения не сохраняются сервисом.

Для собственных доверенных YOLO detection весов положите файл в
cv-service/models/best.pt, задайте MODEL_PATH=/app/models/best.pt в .env и выполните
`docker compose up -d --force-recreate cv-service`. Каталог подключён read-only.
По умолчанию MODEL_PATH=/app/weights/yolo11n.pt. Совместимость проверяется при
загрузке и прогреве; при ошибке /health возвращает 503 без подмены модели.
[Контракт, классы, ограничения и источники модели](cv-service/README.md).

## API

GET /health доступен без JWT; бизнес-маршруты backend имеют префикс /api.

| Метод и путь                       | Назначение                                    |
| ---------------------------------- | --------------------------------------------- |
| POST /api/auth/register            | Регистрация                                   |
| POST /api/auth/login               | Вход                                          |
| GET /api/users/me                  | Профиль                                       |
| GET /api/parkings                  | Парковки                                      |
| GET /api/parkings/:id              | Одна парковка                                 |
| GET /api/parkings/:id/spaces       | Схема мест                                    |
| POST /api/reservations             | Бронирование: parkingSpaceId, durationMinutes |
| GET /api/reservations/me           | Личные брони и история                        |
| PATCH /api/reservations/:id/cancel | Отмена                                        |

Защищённые запросы используют Authorization: Bearer <JWT>. Logout локально
удаляет JWT из secure storage; endpoint отзыва токенов не предусмотрен.

## Проверки и локальная разработка

Из backend (PostgreSQL должен работать, корневой .env настроен):

```powershell
npm ci
npm run format:check
npm run lint
npm run build
node --test test/*.test.cjs test/integration/*.test.cjs
# Для локального сервера остановите Docker backend, чтобы освободить порт:
npm run migration:run
npm run start:dev
```

Не запускайте два сервера на одном порту. Локальный backend читает DB_HOST и
POSTGRES_PORT из корневого .env, Compose переопределяет адрес на postgres:5432.

Из mobile:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Из cv-service после сборки runtime-образа:

```powershell
docker build -f Dockerfile.test -t easypark-cv-test .
docker run --rm easypark-cv-test
docker run --rm easypark-cv-test ruff check app tests tools
```

Этап 20: 38 backend-тестов, 78 Flutter-тестов, 30 CV-тестов, Android logout и
Docker smoke прошли. Осталось предупреждение тестового Starlette об httpx.
Тестовые APK не являются поставляемым APK; после Android integration test
повторите обычный flutter build apk для восстановления приложения.

Не реализованы реальные платежи, admin-panel, RTSP, WebSocket и автоматическое
обновление занятости через CV. Функциональные примеры CV не являются оценкой
точности на реальных парковках. Разработка остановлена на этапе 21.
