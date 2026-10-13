# EasyPark

Мобильное приложение поиска и бронирования парковок с административной панелью. Flutter-клиент, NestJS API и PostgreSQL используют общие данные пользователей, парковок, мест и бронирований. Отдельный FastAPI-сервис выполняет распознавание транспорта на изображениях.

**Текущая версия Android: 1.2.2+5** · `com.easypark.easypark` · debug-сборка.

## Возможности

- **USER:** регистрация, вход, сохранение сессии, карта OpenStreetMap, GPS и маршрут OSRM, парковки и схема мест, бронирования, история и профиль.
- **Бронирование:** режимы «Запланировать» с ручным вводом часов/минут и «По счётчику», почасовой тариф, предварительная и фактическая стоимость, восстановление таймера с backend.
- **Оплата:** выбор банковской карты или СБП с сохранением способа оплаты. Это демонстрация — деньги не списываются.
- **ADMIN:** Dashboard, создание и редактирование парковок через карту, управление местами и доступностью, пользователи, бронирования, аналитика по реальным данным PostgreSQL. API защищён JWT и ролью.
- **Настройки сервера:** смена адреса API до входа и из профиля без пересборки APK; поддержка Cloudflare Tunnel.
- **Восстановление пароля:** email-код через настраиваемый SMTP, срок действия и ограничение попыток, одноразовое применение, отзыв прежних JWT после сброса.
- **CV:** отдельный сервис YOLO11n для JPEG/PNG. Автоматическое определение занятости парковочных мест и запуск таймера через YOLO пока не подключены.

## Структура проекта

| Путь | Назначение |
| --- | --- |
| `mobile/` | Flutter/Dart, Android и iOS исходники |
| `backend/` | NestJS/TypeScript, TypeORM, миграции, seed и тесты |
| `cv-service/` | FastAPI, YOLO и инструменты обработки изображений |
| `docs/` | ТЗ, дизайн-референсы и отчёты разработки |
| `releases/` | Документация сборок; APK исключены из Git |
| `.env.example` | Образец конфигурации без действующих секретов |
| `docker-compose.yml` | PostgreSQL, backend и CV-service |

`docs/tz/` и `docs/figma-reference/` — исходные материалы, их не следует изменять при разработке. Figma Make использован как визуальный референс; конечное приложение реализовано Flutter widgets без React/Vite-зависимостей.

## Получить и запустить на другом компьютере

Нужны Git, Docker Desktop с Linux containers и Compose v2. Для сборки Android — Flutter и Android SDK. Проверенная среда: Flutter 3.38.3 / Dart 3.10.1, JDK 17; минимальный Android API 24. iOS требует macOS/Xcode и в текущем цикле не собирался.

Команды ниже рассчитаны на PowerShell:

```powershell
git clone https://github.com/penxick/EasyParkA.git D:\EasyPark
Set-Location D:\EasyPark
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
```

Перед запуском отредактируйте `.env`:

| Переменная | Что указать |
| --- | --- |
| `POSTGRES_PASSWORD` | Собственный пароль новой БД |
| `JWT_SECRET` | Случайный секрет не менее 32 байт, не заглушка |
| `ADMIN_LOGIN` | Логин первоначального администратора, например `admin` |
| `ADMIN_PASSWORD` | Собственный пароль 12–128 символов, не `change_me` |
| `POSTGRES_PORT` | Порт БД на компьютере; по умолчанию `55432` |
| `BACKEND_PORT` / `CV_PORT` | По умолчанию `3000` / `8000` |

Пароли с `#` заключайте в одинарные кавычки. Не публикуйте `.env`, токены и действующие пароли.

### Backend и PostgreSQL

```powershell
docker compose config --quiet
docker compose up -d --build --wait backend
docker compose exec -T backend npm run seed
docker compose ps
Invoke-RestMethod http://127.0.0.1:3000/health
```

Ожидаемый ответ: `{"status":"ok","service":"easypark-backend"}`. При другом `BACKEND_PORT` измените URL.

Backend автоматически применяет миграции перед запуском. Seed необязателен: создаёт демопарковки и места без перезаписи существующих записей. Системный ADMIN создаётся при отсутствии аккаунта; повторный запуск не заменяет его пароль. Изменение `ADMIN_PASSWORD` в `.env` само по себе не сбрасывает пароль существующего администратора.

PostgreSQL хранит данные в Docker volume. Пользователи и бронирования не входят в Git: новая установка получает новую БД, а не копию домашней. Изменение `POSTGRES_PASSWORD` в `.env` не меняет пароль уже созданной БД.

### Необязательный CV-service

```powershell
docker compose up -d --build --wait cv-service
Invoke-RestMethod http://127.0.0.1:8000/health
python cv-service/tools/detect_image.py "D:\Pictures\parking.jpg"
```

Первая сборка скачивает зависимости и веса. [Контракт CV, ограничения и собственные модели](cv-service/README.md).

### Остановка и обновление

```powershell
# Остановка с сохранением БД:
docker compose stop

# После получения изменений backend:
git pull --ff-only
docker compose up -d --build --wait backend
```

`docker compose down -v` удаляет данные PostgreSQL — для обновления проекта эту команду не используйте.

## Android: запуск и APK

```powershell
Set-Location D:\EasyPark\mobile
flutter pub get
flutter doctor
flutter devices
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/
```

Замените `<device-id>` идентификатором из `flutter devices`. Адрес `10.0.2.2` ведёт из Android Emulator на компьютер с backend. На телефоне нужен доступный ему адрес — настройте его в приложении.

```powershell
flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Результат: `mobile/build/app/outputs/flutter-apk/app-debug.apk`. `API_BASE_URL` задаёт адрес по умолчанию; сохранённый в настройках адрес имеет приоритет. Изменение серверного `.env` не меняет адрес приложения.

[Метаданные сборки 1.2.2+5](releases/1.2.2/README.md). [Ссылка на папку готовых APK](releases/APKDownloadsLink.md). APK не хранится в Git. Загрузка последнего APK на GitHub Releases завершилась сетевыми ошибками, поэтому наличие файла там не подтверждено; проект можно собрать приведённой командой. Указанные в отчётах пути `D:\EasyPark\releases\...` относятся к компьютеру сборки.

Это debug APK, не релиз для магазина. Для публикации нужны собственная подпись и производственная конфигурация; текущая release-конфигурация использует debug signing.

## Телефон или ноутбук через Cloudflare Tunnel

Backend и туннель должны работать на домашнем компьютере. На другом устройстве Docker не нужен, если приложение подключено к этому backend.

1. Запустите туннель к `http://127.0.0.1:3000` установленным `cloudflared`:

   ```powershell
   cloudflared tunnel --url http://127.0.0.1:3000
   ```

2. Скопируйте выданный HTTPS-адрес. Quick Tunnel может выдавать новый адрес при каждом запуске.
3. В приложении откройте шестерёнку на экране входа или настройки профиля.
4. Введите `https://<ваш-туннель>.trycloudflare.com/api/`. Версия 1.2.2 также принимает домен без `/api/` и нормализует его.
5. Нажмите «Проверить подключение», затем «Сохранить» и войдите в аккаунт домашнего backend.

При успешной смене сервера прежний JWT удаляется. При неудачной проверке адрес и авторизация сохраняются. Токен старого сервера не передаётся новому.

| Действие | Метод и адрес |
| --- | --- |
| Проверка | `GET https://<сервер>/health` |
| Вход | `POST https://<сервер>/api/auth/login` |
| Регистрация | `POST https://<сервер>/api/auth/register` |
| Парковки | `GET https://<сервер>/api/parkings` с JWT |

Успешная проверка требует HTTP 200 и JSON EasyPark. `/api/health` не используется. Открытие адреса входа браузером выполняет GET и не проверяет POST-маршрут авторизации.

В debug-сборке запросы входа/регистрации выводят безопасную строку `EasyPark auth HTTP`: метод, URL без query, статус, категорию ошибки и время. Пароли, JWT, email и тела запросов не логируются. Отключение при сборке: `--dart-define=API_DIAGNOSTICS=false`.

**Проверка входа через актуальный Cloudflare Tunnel на физическом телефоне ожидает ручного подтверждения.** [Диагностика и исправление URL](docs/cloudflare-auth-fix.md).

## Бронирование и фактический таймер

«Запланировать» принимает ручную длительность от 1 до 1440 минут. «По счётчику» не требует длительности. Стоимость рассчитывается по почасовому тарифу с округлением до копейки; тариф сохраняется в сессии, поэтому последующее изменение цены не переписывает её историю.

Создание сессии → ожидание прибытия → подтверждённое прибытие → таймер → запрос завершения → подтверждённый выезд → итоговая стоимость.

Создание брони не запускает фактический таймер. Кнопка завершения не освобождает физически занятое место: таймер продолжается до подтверждения выезда. После перезапуска клиента время восстанавливается с backend. Старые бронирования и поля прежнего тарифа сохранены для совместимости.

Для демонстрации, пока нет автоматических событий камеры:

1. Укажите в `.env` `DEMO_PARKING_EVENTS_ENABLED=true` и пересоздайте backend командой `docker compose up -d backend`.
2. С JWT администратора отправьте `POST /api/reservations/<id>/demo-event` с JSON `{"event":"ARRIVAL"}`.
3. После завершения отправьте туда же `{"event":"DEPARTURE"}`.

Метод по умолчанию выключен, защищён ролью ADMIN и не является интеграцией YOLO. Способ оплаты CARD/СБП и подтверждение оплаты демонстрационные; реального списания нет. [Подробный сценарий и миграции](docs/stage-booking-payment-settings.md).

## Восстановление пароля и SMTP

В `.env` настройте `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` и пересоздайте backend. Обычно порт `587` используется с `SMTP_SECURE=false` и STARTTLS, `465` — с `SMTP_SECURE=true`. Используйте настройки своего почтового сервиса; проверка сертификатов не отключена.

На экране входа выберите восстановление пароля. Код действует 10 минут, допускает не более пяти попыток и одно успешное применение; повторная отправка ограничена минутой. После сброса старые JWT недействительны. Без SMTP приложение сообщает, что отправка не настроена. Ответ не раскрывает наличие email в БД.

Реальная доставка требует настроенного SMTP и отдельно проверяется на вашей установке. Отправка асинхронная, постоянной очереди доставки нет.

## Основные API

Все бизнес-маршруты имеют префикс `/api`. Защищённые запросы используют `Authorization: Bearer <JWT>`.

| Метод и путь | Назначение |
| --- | --- |
| `GET /health` | Проверка backend без JWT |
| `POST /api/auth/register` | Регистрация USER |
| `POST /api/auth/login` | Вход USER/ADMIN |
| `POST /api/auth/password-reset/request` | Запрос кода |
| `POST /api/auth/password-reset/confirm` | Подтверждение сброса |
| `GET /api/users/me` | Профиль |
| `GET /api/parkings` | Парковки |
| `GET /api/parkings/:id` | Детали парковки |
| `GET /api/parkings/:id/spaces` | Места |
| `POST /api/reservations/sessions` | Новая сессия PLANNED/METERED |
| `GET /api/reservations/me` | Личные сессии и история |
| `PATCH /api/reservations/:id/finish` | Запрос завершения |
| `PATCH /api/reservations/:id/cancel` | Отмена до прибытия для новой сессии |
| `POST /api/reservations/:id/demo-event` | Демособытие, только ADMIN |

Прежний `POST /api/reservations` сохранён для совместимости. Административные endpoints и проверки ролей описаны в [отчётах A1–A13](docs/admin/stage-a1.md).

## Разработка и проверки

Для backend вне Docker требуется Node.js `^22.13.0` или `>=24.0.0`. PostgreSQL должен работать, корневой `.env` — быть настроен. Не запускайте два backend на одном порту.

```powershell
Set-Location D:\EasyPark\backend
npm ci
npm run build
npm run lint
node --test test/*.test.cjs test/integration/*.test.cjs
```

Локальный backend использует `DB_HOST` и `POSTGRES_PORT` из `.env`; Compose подключается к `postgres:5432`. Миграции для локального запуска: `npm run migration:run`, сервер: `npm run start:dev`.

```powershell
Set-Location D:\EasyPark\mobile
flutter pub get
flutter analyze
flutter test
```

Последние зафиксированные результаты:

- Обновление бронирования: backend — 79 тестов, Flutter — 121 тест; целевые backend-проверки после завершающих изменений также прошли.
- Исправление Cloudflare: Flutter analyze без замечаний, 43 целевых теста прошли, Android debug APK 1.2.2+5 собран; версия и applicationId проверены через aapt.
- Это результаты разных прогонов, их не следует складывать. Полный сценарий на физическом телефоне через актуальный туннель пока не подтверждён.

## Документация и ограничения

- [Бронирование, таймер, SMTP и настройки](docs/stage-booking-payment-settings.md)
- [Проверка корневого /health](docs/server-health-fix.md)
- [Исправление Cloudflare-авторизации](docs/cloudflare-auth-fix.md)
- [ADMIN: аудит и план](docs/admin/stage-a1.md), [аккаунт и защита](docs/admin/stage-a2.md), [регрессионные проверки](docs/admin/stage-a13.md)
- [CV-service](cv-service/README.md)

Реальные платежи, автоматические события прибытия/выезда от YOLO, RTSP и WebSocket не реализованы. SMTP требует внешней настройки. Старые отчёты этапов описывают состояние на момент их выполнения; актуальные сценарии приведены выше.


