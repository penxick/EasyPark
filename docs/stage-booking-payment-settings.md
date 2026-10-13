# EasyPark 1.2.0 — бронирование, оплата и настройки

## Реализовано

Два режима на существующем Flutter-экране: «Запланировать» с ручным вводом часов/минут и «По счётчику». Выбор CARD/СБП сохраняется в PostgreSQL. Оплата демонстрационная, деньги не списываются. Дизайн основан на двух предоставленных скриншотах. Зона не выдумывается: существующая модель места не содержит такого поля.

Backend сохраняет почасовой тариф на момент создания сессии, предварительную и итоговую суммы раздельно. Расчёты выполняются целочисленно, с округлением до копейки. Создание брони не запускает фактический таймер. Подтверждённое прибытие запускает его; кнопка завершения переводит сессию в ожидание выезда. Только подтверждение выезда завершает расчёт и освобождает место. Повторные события не начисляют оплату повторно. Старые бронирования и pricePer30Min сохранены.

На главном экране показана активная сессия. После открытия приложения данные и прошедшее время загружаются с backend. В карточке доступны план, фактическое время, текущая/итоговая стоимость и способ оплаты.

Добавлено восстановление пароля: код на 10 минут, хранится HMAC, не более пяти попыток, повторная отправка не чаще минуты, одноразовое применение. Новый пароль хешируется; прежние JWT отзываются. Ответ не раскрывает наличие аккаунта. Без SMTP возвращается честное сообщение о недоступности отправки.

Адрес API доступен через шестерёнку до входа и настройки профилей USER/ADMIN. Проверяется /health, адрес сохраняется локально. Смена сервера требует успешного выхода и удаления старого JWT. Проверка нового сервера выполняется без старого токена. HTTPS-проверки не отключены.

Оригинальный логотип подключён к входу, регистрации, splash и Android launcher. Исходник не изменён. CV-service, YOLO и исправление GPS не изменялись.

## Миграции

- 1791849600000-parking-sessions.ts — nullable-поля режима, оплаты, тарифа, фактического времени и стоимости; существующие строки сохранены.
- 1791849601000-password-resets.ts — password_resets и users.tokenVersion.

Обе миграции применены к локальной PostgreSQL при проверке. В Docker они выполняются при старте backend. Для другого сервера: собрать backend и выполнить `npm run migration:run` перед запуском. Не включать synchronize. Откат первой миграции запрещён при наличии новых сессий, чтобы не потерять их данные.

## Проверки

- Backend build и ESLint: успешно.
- Полный прогон backend: 79 тестов, 0 ошибок.
- После завершающей проверки SMTP-конфигурации и исправления конкурентного теста: два целевых теста денежных расчётов, жизненного цикла, доступа и сброса пароля прошли.
- Flutter analyze: замечаний нет.
- Flutter tests: 121 тест, 0 ошибок.
- git diff --check: ошибок нет (только уведомления Windows о LF/CRLF).
- Хеши всех 75 файлов docs/tz и docs/figma-reference совпадают с исходными. Копия логотипа идентична оригиналу.
- Физическое устройство/BlueStacks и полный Android-сценарий не проверены в этом запуске: эмулятор offline. Интеграционный Android-тест обновлён под ручной ввод, но не запускался. Визуальное совпадение на реальном устройстве не подтверждено.
- Реальная SMTP-доставка не проверена: почтовые реквизиты не настроены. Реальные платежи и YOLO-события не реализованы этим изменением.

## Как проверить бронирование и таймер

1. Запустить обновлённый backend. Войти USER, выбрать свободное место с почасовым тарифом.
2. В «Запланировать» ввести 1 час 30 минут. При тарифе 80 ₽/час предварительная стоимость должна составить 120 ₽. Выбрать карту или СБП и подтвердить демонстрационную оплату.
3. Открыть бронирования: состояние «Ожидаем прибытия», фактический таймер ещё не запущен.
4. Для демонстрационных событий задать в локальном .env `DEMO_PARKING_EVENTS_ENABLED=true` и перезапустить backend. По умолчанию метод выключен. Получить JWT ADMIN обычным входом; токен не публиковать.
5. Отправить авторизованный ADMIN-запрос `POST /api/reservations/<id>/demo-event`, JSON `{"event":"ARRIVAL"}`. Заголовок Authorization: Bearer <ADMIN_JWT>. USER получает 403, без JWT — 401.
6. Обновить карточку или дождаться опроса (до 10 секунд). Таймер идёт. Закрыть и снова открыть приложение: он восстанавливается по серверному времени.
7. Нажать «Завершить парковку»: состояние ожидания выезда, занятое место ещё не освобождается.
8. Отправить тем же защищённым методом `{"event":"DEPARTURE"}`. Таймер останавливается, фиксируются итоговая сумма и демонстрационная оплата. Повторный DEPARTURE не меняет результат.
9. Повторить для режима «По счётчику»: поля длительности отсутствуют; до подтверждения прибытия начисления нет. Проверить выбранный способ оплаты в истории.

Событие DEPARTURE — явное демонстрационное подтверждение физического выезда. Это не автоматическое распознавание камерой. Без подтверждения сессия продолжает работать; нажатие кнопки само по себе место не освобождает.

## SMTP

В локальном .env указать SMTP_HOST, SMTP_PORT (обычно 587), SMTP_SECURE=false для STARTTLS или true для TLS-порта 465, SMTP_USER, SMTP_PASSWORD, SMTP_FROM. Значения пароля не коммитить. Сертификаты проверяются. Docker Compose передаёт эти переменные backend; после изменения пересоздать backend.

На входе выбрать «Забыли пароль?», ввести зарегистрированный email, получить шестизначный код и задать новый пароль. Код действует 10 минут; повторное использование запрещено. Письмо отправляется асинхронно: сообщение о запросе не гарантирует доставку, а при сбое доставки код аннулируется. Очередь доставки не сохраняется при аварийном завершении процесса.

## Cloudflare / другой backend

В настройках сервера указать полный адрес API, например https://example.trycloudflare.com/api/. Выполнить проверку подключения и сохранить. Для Cloudflare использовать текущий URL своего туннеля; приложение не создаёт туннель автоматически. При смене адреса потребуется новый вход. Кнопка сброса подставляет адрес сборки; затем его нужно сохранить.

Адрес этой Android-сборки: http://10.0.2.2:3000/api/ (Android Emulator). Для телефона и BlueStacks указать достижимый адрес через настройки. Backend должен содержать новые изменения: со старым сервером новые endpoints недоступны.

Команда обновления Docker backend из корня проекта: `docker compose up -d --build --wait backend`. Она использует существующий том PostgreSQL; `down -v` выполнять не нужно.

## Сборка

Версия 1.2.0+3, applicationId com.easypark.easypark сохранён. Старые APK не удалялись. Установленную версию проверить не удалось из-за offline-эмулятора; versionCode 3 больше последнего выпущенного 2. APK и проверенные метаданные перечислены в сопутствующем файле релиза.

## Созданные и изменённые файлы

- `.env.example`
- `"docs/logo/\320\233\320\276\320\263\320\276 \320\270\320\267\320\270\320\277\320\260\321\200\320\272.png"`
- `backend/package-lock.json`
- `backend/package.json`
- `backend/src/admin/admin-analytics.service.ts`
- `backend/src/auth/auth.controller.ts`
- `backend/src/auth/auth.dto.ts`
- `backend/src/auth/auth.module.ts`
- `backend/src/auth/auth.service.ts`
- `backend/src/auth/jwt-auth.guard.ts`
- `backend/src/auth/password-reset.service.ts`
- `backend/src/database/database.module.ts`
- `backend/src/database/migrations/1791849600000-parking-sessions.ts`
- `backend/src/database/migrations/1791849601000-password-resets.ts`
- `backend/src/parking-spaces/parking-spaces.service.ts`
- `backend/src/reservations/admin-reservation.projection.ts`
- `backend/src/reservations/money.ts`
- `backend/src/reservations/reservation.entity.ts`
- `backend/src/reservations/reservations.controller.ts`
- `backend/src/reservations/reservations.service.ts`
- `backend/src/reservations/session.dto.ts`
- `backend/src/users/user.entity.ts`
- `backend/test/integration/admin-auth.test.cjs`
- `backend/test/integration/parking-sessions.test.cjs`
- `docker-compose.yml`
- `docs/stage-booking-payment-settings.md`
- `mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-mdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png`
- `mobile/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`
- `mobile/assets/easypark-logo.png`
- `mobile/integration_test/admin_full_flow_test.dart`
- `mobile/lib/core/router/app_router.dart`
- `mobile/lib/core/storage/server_address_storage.dart`
- `mobile/lib/features/admin/screens/admin_profile_screen.dart`
- `mobile/lib/features/auth/auth_controller.dart`
- `mobile/lib/features/auth/auth_form_screen.dart`
- `mobile/lib/features/auth/auth_repository.dart`
- `mobile/lib/features/auth/password_reset_screen.dart`
- `mobile/lib/features/auth/server_settings_screen.dart`
- `mobile/lib/features/auth/splash_screen.dart`
- `mobile/lib/features/map/parking.dart`
- `mobile/lib/features/profile/profile_screen.dart`
- `mobile/lib/features/reservation/active_parking_banner.dart`
- `mobile/lib/features/reservation/booking_screen.dart`
- `mobile/lib/features/reservation/parking_session_card.dart`
- `mobile/lib/features/reservation/reservation_card.dart`
- `mobile/lib/features/reservation/reservation_repository.dart`
- `mobile/lib/features/reservation/reservation.dart`
- `mobile/pubspec.yaml`
- `mobile/test/auth_widget_test.dart`
- `mobile/test/booking_sessions_test.dart`
- `mobile/test/map_test.dart`
- `mobile/test/parking_details_test.dart`
- `mobile/test/reservation_test.dart`
- `mobile/test/support/reservation_fixture.dart`
- `releases/1.2.0/README.md` — версия, размер, SHA-256 и параметры сборки.
- `releases/1.2.0/EasyPark-v1.2.0-emulator.apk` — отдельный APK, исключён из Git как бинарный артефакт.

## Проверка локального запуска

Docker backend пересобран и запущен с существующей PostgreSQL. Оба контейнера Healthy; GET http://127.0.0.1:3000/health вернул status=ok, service=easypark-backend. CV-service не пересоздавался. SMTP и демонстрационные события не включались автоматически.

APK проверен aapt: 1.2.0, versionCode 3, com.easypark.easypark. Размер 161930561 байт. SHA-256 предыдущего APK 1.1.0 совпадает с исходным.
