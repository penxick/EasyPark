# Отчёт: Android APK EasyPark

Дата: 11 октября 2026 года.

## Результат

Готовый установочный файл:

`D:\EasyPark\.artifacts\apk\EasyPark-emulator-debug-universal.apk`

Копия: `D:\EasyPark\mobile\build\app\outputs\flutter-apk\app-debug.apk`.

- API: `http://10.0.2.2:3000/api/` — локальный Android Studio Emulator.
- Размер: 180940785 байт (около 172,6 MiB).
- SHA-256: `086C1B5D4850C61EAF79F9687B77D3E22E9876511F3124757C1EE4246F5726E4`.
- applicationId: `com.easypark.easypark`; название: EasyPark; версия 0.1.0 (1).
- minSdk 24 (Android 7.0), targetSdk 36.
- Проверенные ABI внутри APK: armeabi-v7a, arm64-v8a, x86_64.
- Подпись валидна: Android Debug. Это не production-подпись.

APK работает как отдельно установленное Android-приложение. Flutter/Android Studio
и отладчик на устройстве не нужны. Для функций требуется доступный backend.
Этот файл НЕ является интернет-сборкой или готовой сборкой для телефона: его
адрес API относится к Android Studio Emulator на том же ПК, что и backend.

Release APK не создан: постоянные ключ и key.properties отсутствуют, публичный
HTTPS API не предоставлен. Адрес и пароли не придумывались. Инструкция подготовки:
[android-apk-build.md](android-apk-build.md).

## Изменения

- mobile/android/app/build.gradle.kts: чтение локального key.properties,
  постоянная release-подпись вместо debug fallback; проверка наличия keystore
  и явного HTTPS API перед release.
- mobile/lib/core/constants/api_config.dart: удалён скрытый адрес эмулятора;
  API_BASE_URL теперь обязателен. HTTPS использует штатную проверку сертификата.
- mobile/test/support/auth_fixture.dart: явный mock URL для тестов.
- mobile/test/core/api_client_test.dart: явные mock URL и проверка пустого адреса.
- mobile/test/map_test.dart, mobile/test/parking_details_test.dart,
  mobile/test/parking_layout_test.dart: явная конфигурация HTTP mock.
- docs/android-apk-build.md: инструкция по трём режимам API, подписи и установке.
- docs/android-apk-report.md: этот отчёт.

Защищённые ТЗ/Figma, backend, БД и CV-service не изменены. Ранее сделанные
изменения проекта сохранены. Новых пакетов и обновлений зависимостей нет;
pubspec.lock не изменён. Существующая Flutter-иконка сохранена, не брендирована.

## Выполненные проверки

Из mobile:

- `flutter pub get` — успешно (есть уведомления о более новых несовместимых версиях;
  зависимости намеренно не обновлялись).
- `flutter analyze --no-pub` — замечаний нет.
- `flutter test --no-pub --reporter compact` — все 112 прошли.
- `flutter build apk --debug --no-pub --target-platform android-arm,android-arm64,android-x64 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/` — успешно.
- `flutter drive --no-pub --driver=test_driver/admin_base_driver.dart --target=integration_test/admin_full_flow_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/ --dart-define-from-file=../.artifacts/a13-fixture.json` — полный сценарий прошёл.

Сквозной тест проверил вход ADMIN, Dashboard, создание парковки на карте и места,
FREE/UNAVAILABLE, регистрацию USER, карту и созданные данные, восстановление JWT,
защиту маршрута ADMIN и API 403, создание и отмену брони, историю, профиль, выход,
ADMIN-карточки брони и пользователя, аналитику, защиту удаления места с историей.
Тест использовал реальный Docker backend/PostgreSQL. Временные данные удалены
скриптом android-a13-fixture.cjs cleanup. Пользовательская APK сохранена до
тестовой сборки, затем восстановлена и установлена обратно; тестовые аккаунты
и dart-defines отсутствуют в выдаваемой APK.

Дополнительно:

- `aapt dump badging` подтвердил package, min/target SDK, label и три ABI.
- `apksigner verify --print-certs` подтвердил debug-подпись.
- `gradlew.bat :app:assembleRelease --dry-run` намеренно отклонён:
  `Release signing is not configured`. Debug fallback не допускается.
- `adb install -r` и `adb shell am start -n com.easypark.easypark/.MainActivity`:
  обычный APK установлен и запущен без Flutter driver; процесс подтверждён.
- Проверены INTERNET в main manifest и HTTP-разрешение только debug variant.
- Проверка распакованного APK не обнаружила значений ADMIN_PASSWORD, JWT_SECRET,
  POSTGRES_PASSWORD из локального .env в UTF-8/UTF-16LE или файлов keystore.
  Это целевая проверка известных секретов, не полная независимая экспертиза APK.
- `git diff --check` — успешно; все 75 SHA-256 исходных материалов совпали.

Сетевые ошибки, timeout, безопасные сообщения, повторная загрузка и сохранение
сессии при offline покрыты Flutter-тестами. Реальное переключение сетей телефона
и подключение к публичному HTTPS не проверены: устройства/адреса нет.

## Реально проверенные устройства

Pixel_7, emulator-5554, Android API 36, x86_64. ARM64/ARMv7 подтверждены составом
APK, но на физическом ARM-устройстве не запускались. Найдены остаточные папки
BlueStacks_nxt/Bignox, но запускаемых HD-Player.exe/Nox.exe/NoxConsole.exe и
подключённых устройств не обнаружено. BlueStacks, LDPlayer, Nox и телефон
не тестировались; совместимость с ними не заявляется как проверенная.

## Исправленные проблемы и остаточные ограничения

Первый Gradle-прогон выявил конфликт обращения java.util/java.net с Kotlin DSL;
исправлено явными импортами. Удаление fallback API выявило зависимость старых
mock-тестов от локального адреса: им назначен явный test URL, после чего все 112
прошли. Рабочие USER/ADMIN функции не заменялись.

Для окончательного распространения необходимы действующий публичный HTTPS API,
постоянный keystore владельца, сборка release и проверка на целевых устройствах.
Для LAN отдельно потребуется настройка доступа к backend: текущая публикация
Docker привязана к 127.0.0.1. Домашняя сеть, домен, туннель и PostgreSQL наружу
не настраивались. Проверка TLS не отключалась.

APK и логи находятся в игнорируемых .artifacts/*.log. Git commit/push не выполнялись.
