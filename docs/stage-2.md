# Этап 2 — Flutter Base

Выполнен только этап 2. UI-kit, реальные экраны Figma, авторизация, карта,
бронирования и постоянное хранение JWT относятся к следующим этапам.
Backend и CV-service не изменялись.

## Реализация

- `MaterialApp.router` и `go_router`, включая все 9 маршрутов из раздела 51 ТЗ.
  Начальный маршрут — `/splash`. `/` перенаправляется на него.
  Пока используются простые заглушки с названием раздела и идентификатором.
  Это не реализация Splash/Login/Map. Для неизвестного маршрута есть сообщение
  и возврат на стартовый экран. Проверены push/pop и параметры `id`.
- Базовая светлая Material-тема: синий primary и светлый фон согласованы с
  исходным прототипом. Детальные typography, размеры, кнопки, поля, карточки
  и остальные компоненты UI-kit оставлены этапу 3.
- Структура `core/{api,constants,router,storage,theme,state}` и
  `features/{auth,map,parking,reservation,profile}`.
- `ApiClient`: GET/POST/PATCH/DELETE, UTF-8 JSON, query-параметры, единый base URL,
  таймаут с отменой HTTP-запроса, обработка статусов и ошибок транспорта.
  Полные URL и выход за base path отклоняются, автоматические HTTP-redirects
  отключены; токен не может быть переслан клиентом на сторонний адрес.
- JWT берётся из подключаемого `TokenProvider` перед каждым защищённым запросом.
  `authenticated: false` предназначен для будущего входа/регистрации без JWT.
  HTTP 401 превращается в `ApiException`; если запрос содержал JWT, вызывается
  подключаемый `onUnauthorized`. Привязка к TokenStorage/экрану входа — этап 5.
  Ошибка callback не скрывает первоначальный 401.
- `ApiException` даёт безопасные русские сообщения без сырых ответов сервера,
  токенов и технических исключений.
- `LoadState<T>`: idle/loading/success/failure. `LoadController<T>` поддерживает
  повторную загрузку, игнорирует устаревшие результаты и уведомления после dispose.
  Визуальные LoadingIndicator/ErrorWidget будут созданы на этапе 3.
- HTTP-запросов в widgets нет. ApiClient подключается в будущих repositories;
  сетевые операции сейчас проверяются тестами и отдельной диагностической утилитой.

## Настройка сети

По умолчанию: `http://10.0.2.2:3000/api/` — backend на Windows из Android Emulator.
Другой адрес передаётся при запуске/сборке:

```powershell
flutter run --dart-define=API_BASE_URL=https://your-host.example/api/
```

Корневой `.env` Flutter не читает. При изменении адреса нужен перезапуск с
новым `--dart-define`. Base URL нормализуется с завершающим `/`.
Порт должен совпадать с опубликованным портом backend.

Разрешение INTERNET добавлено в основной Android manifest. HTTP разрешён только
в debug manifest для локальной разработки; release сохраняет HTTPS-требования.
На физическом устройстве `10.0.2.2` не подходит: нужен доступный сервер или
`adb reverse tcp:3000 tcp:3000` с `API_BASE_URL=http://127.0.0.1:3000/api/` для debug.
Compose по-прежнему публикует порты только на loopback компьютера.
iOS сохраняет стандартные ограничения ATS; его сборка требует macOS/Xcode.

ApiClient владеет транспортом, в том числе переданным через конструктор:
владелец клиента вызывает `close()`. LoadController и GoRouter также освобождаются.

## Проверки

- `dart format lib test tool` — выполнено.
- `flutter analyze --no-pub` — без замечаний.
- `flutter test --no-pub` — 21 тест пройден.
- Проверены JSON/UTF-8/JWT, обновление токена между запросами, публичный запрос
  без JWT, 401 и callback, HTTP 400/403/404/500/503/302, пустой 204,
  некорректный JSON, транспортный сбой, таймаут, URL вне base path.
- Проверены loading/success/error/retry, устаревшие ответы, dispose.
- Widget-тесты: старт, все маршруты, параметры, неизвестный маршрут, push/pop,
  экран 320×480 с масштабом текста 2.
- `dart run tool/api_smoke.dart` — реальный backend: JSON `/health` и обработка 404.
  Утилита специально использует корневой URL, потому что `/health` находится вне `/api`.

`flutter build apk --debug --no-pub` завершён успешно. APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
Контрольные суммы всех 75 исходных файлов совпали; добавлений и удалений в исходных папках нет.
На эмуляторе в этом этапе повторный запуск не выполнялся: старт и маршруты
проверены widget-тестами, а совместимость Android — сборкой APK.

## Созданные файлы

- `mobile/lib/app.dart` — корневое приложение, тема и жизненный цикл router.
- `mobile/lib/core/theme/app_theme.dart` — базовая тема.
- `mobile/lib/core/router/app_routes.dart` — пути из ТЗ.
- `mobile/lib/core/router/app_router.dart` — GoRouter, заглушки и неизвестный маршрут.
- `mobile/lib/core/constants/api_config.dart` — адрес и таймаут API.
- `mobile/lib/core/api/api_client.dart` — единый сетевой клиент.
- `mobile/lib/core/api/api_exception.dart` — типизированные ошибки и сообщения.
- `mobile/lib/core/storage/token_provider.dart` — контракт получения JWT.
- `mobile/lib/core/state/load_state.dart` — состояния загрузки.
- `mobile/lib/core/state/load_controller.dart` — управление загрузкой.
- `mobile/lib/features/README.md` — границы feature-модулей.
- `mobile/lib/features/auth/.gitkeep` — зарезервированная папка авторизации.
- `mobile/lib/features/map/.gitkeep` — зарезервированная папка карты.
- `mobile/lib/features/parking/.gitkeep` — зарезервированная папка парковок.
- `mobile/lib/features/reservation/.gitkeep` — зарезервированная папка бронирований.
- `mobile/lib/features/profile/.gitkeep` — зарезервированная папка профиля.
- `mobile/test/core/api_client_test.dart` — проверки API-клиента.
- `mobile/test/core/load_controller_test.dart` — проверки состояний загрузки.
- `mobile/tool/api_smoke.dart` — запросы к реальному backend для диагностики.
- `docs/stage-2.md` — этот отчёт.

## Изменённые файлы

- `mobile/lib/main.dart` — вход в выделенное корневое приложение.
- `mobile/pubspec.yaml`, `mobile/pubspec.lock` — зависимости go_router и http.
- `mobile/test/widget_test.dart` — проверки маршрутизации и адаптивности.
- `mobile/android/app/src/main/AndroidManifest.xml` — разрешение INTERNET.
- `mobile/android/app/src/debug/AndroidManifest.xml` — HTTP только для debug.
- `mobile/README.md`, `README.md` — актуальное описание и команды запуска.

Зависимости Flutter, `.dart_tool`, `build` и Gradle caches обновляются инструментами
и исключены из Git. TSX/JSX, React/Vite/Tailwind/Radix/MUI не переносились.
Транзитивные `web` и `flutter_web_plugins` — Dart/Flutter-пакеты зависимостей http
и go_router, они не взяты из прототипа.

## Замечания

Замечания анализатора (лишний импорт, порядок импортов и стиль CLI-утилиты)
исправлены. Совместимая с установленным Flutter версия go_router — 17.5.0;
обновление до 18 и обновление Flutter SDK не выполнялись. Сообщения pub о более
новых несовместимых версиях не являются ошибками сборки.

Источники: [go_router](https://pub.dev/packages/go_router),
[http](https://pub.dev/packages/http),
[Flutter ThemeData](https://docs.flutter.dev/cookbook/design/themes).
Этап 3 не начат.
