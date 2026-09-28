# Этап 5 — Auth Flutter

Реализованы Splash, формы входа/регистрации, AuthRepository, AuthController и
TokenStorage. Этап 6 не начат: после авторизации открывается прежняя заглушка
«Карта», остальные бизнес-экраны и нижняя навигация ещё не подключены.

## Поведение

- Splash читает сохранённый JWT и проверяет его через `GET /api/users/me`.
- При отсутствии токена открывается Login. Невалидный/просроченный JWT удаляется.
- Ошибка сети или сервера сохраняет токен и показывает повтор проверки либо
  явное действие «Войти снова». Ошибка защищённого хранилища не выдаёт доступ.
- Login отправляет email и пароль. Register — имя, email и пароль; повтор
  проверяется локально. Email нормализуется, пароль не обрезается.
- Регистрация использует ограничение backend 8–128 символов. Имя — 1–100.
  Не совпадающие пароли, пустые поля и некорректный email не отправляются.
- После успеха JWT сохраняется до открытия защищённых маршрутов. Повторное
  нажатие блокируется; серверные 401/409/429 и ошибки сети показываются безопасным текстом.
- Формы поддерживают клавиатуру, autofill, прокрутку и увеличение текста.
- Сохранённый профиль не является основанием авторизации: при запуске профиль
  загружается с backend. Пароли не сохраняются приложением и не логируются.

AuthController управляет состоянием; AuthRepository использует общий ApiClient.
HTTP отсутствует в widgets. ApiClient игнорирует запоздалый 401 старого токена,
если хранилище уже содержит новый токен. Закрытый controller не публикует результаты.

## Соответствие Figma и ТЗ

Повторно изучены LoginScreen.tsx, RegisterScreen.tsx и требования этапа 5.
Использованы градиент blue-50 → indigo-100, белая карточка шириной до 448 px,
отступы 16/24 px, скругления, подписи, синие кнопки, Lucide-иконки у labels,
разделитель и переход между формами. Переиспользуется UI-kit этапа 3.

Изменения по приоритету ТЗ: EasyPark вместо «Лайт Парк», email вместо
«телефон или почта», поле имени и кнопка «Создать аккаунт». После регистрации
используется выданная backend сессия. Демо-учётные записи прототипа не перенесены.
Splash не представлен отдельным экраном в экспорте; использует общую тему,
название EasyPark и индикатор проверки сессии.

## Защищённое хранение и платформы

`flutter_secure_storage` 11.2.0 сохраняет только JWT под ключом `easypark.access_token`.
Android использует защищённое хранилище с KeyStore; iOS — Keychain с доступностью
`first_unlock_this_device`. В исходниках приложения нет постоянного JWT/пароля.
Android backup отключён, чтобы шифрованные данные не переносились без ключей.

По фактическим требованиям установленного Android-плагина minSdk повышен до 24
(Android 7.0). Добавлены iOS entitlements и привязка к трём конфигурациям Runner.
Сборка и исполнение iOS на Windows недоступны; проверить их нужно на macOS/Xcode.

Документация зависимости: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage).
Её платформенные Dart-зависимости, включая web implementation, не взяты из Figma
и не являются переносом React/Vite-прототипа.

## Запуск

Из корня: `docker compose up --build -d --wait`. Затем из `mobile/`:

```powershell
flutter pub get
flutter run -d emulator-5554
```

На Android Emulator API по умолчанию: `http://10.0.2.2:3000/api/`.
Для другого устройства задайте `--dart-define=API_BASE_URL=https://your-host/api/`.
HTTP разрешён только для debug Android; release использует HTTPS.
Локальный эмулятор проверяется с `--no-enable-impeller` как диагностическим
параметром; настройка renderer в AndroidManifest не менялась.

## Созданные файлы

Пути относительно `D:\EasyPark`.

| Файл | Назначение |
| --- | --- |
| `mobile/lib/core/storage/token_storage.dart` | Интерфейс и защищённая реализация хранения JWT |
| `mobile/lib/features/auth/auth_user.dart` | Проверка и разбор API-моделей пользователя/сессии |
| `mobile/lib/features/auth/auth_repository.dart` | Регистрация, вход, получение профиля |
| `mobile/lib/features/auth/auth_controller.dart` | Восстановление, сохранение и аннулирование сессии |
| `mobile/lib/features/auth/auth_validators.dart` | Клиентская валидация полей |
| `mobile/lib/features/auth/auth_layout.dart` | Адаптивная градиентная страница |
| `mobile/lib/features/auth/auth_form_screen.dart` | Login и Register с общими компонентами |
| `mobile/lib/features/auth/splash_screen.dart` | Проверка сессии и восстановление после ошибки |
| `mobile/ios/Runner/Runner.entitlements` | Доступ к Keychain |
| `mobile/test/support/auth_fixture.dart` | Изолированные HTTP/storage-заглушки для тестов |
| `mobile/test/auth_test.dart` | Сессии, ошибки, защита от устаревших ответов |
| `mobile/test/auth_widget_test.dart` | Формы, состояния, маршрутизация и адаптивность |
| `mobile/integration_test/auth_flow_test.dart` | Android + настоящий backend + защищённое хранилище |
| `mobile/tool/render_auth_test.dart` | Рендер четырёх изображений форм для визуальной проверки |
| `docs/stage-5.md` | Этот отчёт |

## Изменённые файлы

- `mobile/lib/main.dart` — инициализация Flutter binding перед плагинами.
- `mobile/lib/app.dart` — создание AuthController, запуск восстановления и освобождение ресурсов.
- `mobile/lib/core/router/app_router.dart` — реальные auth-маршруты и guards.
- `mobile/lib/core/api/api_client.dart` — защита новой сессии от старого 401.
- `mobile/lib/core/storage/token_provider.dart` — актуальный комментарий контракта.
- `mobile/lib/core/widgets/app_text_field.dart` — иконки рядом с labels.
- `mobile/lib/core/widgets/app_button.dart` — синий outline из Figma.
- `mobile/lib/features/README.md` — границы feature-модулей.
- `mobile/test/widget_test.dart` — проверки маршрутов с учётом авторизации.
- `mobile/pubspec.yaml`, `mobile/pubspec.lock` — secure storage и integration_test.
- `mobile/android/app/build.gradle.kts` — Android API 24+.
- `mobile/android/app/src/main/AndroidManifest.xml` — запрет backup.
- `mobile/ios/Runner.xcodeproj/project.pbxproj` — подключение entitlements.
- `mobile/README.md`, `README.md` — запуск и текущий статус.

Flutter также обновляет GeneratedPluginRegistrant для Android/iOS, `.dart_tool/`,
`.flutter-plugins-dependencies`, файлы сборки и APK. Эти производные файлы не
редактировались вручную. Backend и CV исходники не изменены; интеграционный тест
создаёт отдельного временного пользователя для проверки авторизации.

## Проверки

Команды из `mobile/`:

```powershell
dart format --output=none --set-exit-if-changed lib test tool integration_test
flutter analyze
flutter test
flutter test tool/render_auth_test.dart --dart-define=FLUTTER_SDK=C:/Users/User/flutter/flutter
flutter test integration_test/auth_flow_test.dart -d emulator-5554 --no-enable-impeller --dart-define=TEST_EMAIL=stage5-unique-test-id@example.com --timeout=3m
flutter build apk --debug --no-pub
```

Android-тест предназначен для тестового эмулятора: в начале удаляет ключ сессии
EasyPark, создаёт аккаунт и оставляет его JWT для отдельной проверки перезапуска
процесса. После проверки аккаунт удаляется по точному случайному email.

Результаты:

- Форматирование: 40 Dart-файлов, изменений не требуется.
- `flutter analyze`: без замечаний.
- `flutter test`: все 42 теста прошли (29 прежних с обновлённой маршрутизацией и 13 новых auth-проверок).
- Android integration_test с настоящим backend и KeyStore: успешная регистрация,
  восстановление с новым controller, очистка токена, неверный пароль и успешный повторный вход.
- Обычный APK установлен и запущен отдельно. Вход через реальные поля формы
  успешен; после `am force-stop` и нового запуска открылась «Карта» без повторного
  ввода credentials. После удаления только временного пользователя и перезапуска
  приложение вернулось на Login.
- `flutter build apk --debug --no-pub`: обычный APK успешно собран.
- Четыре изображения форм отрисованы и просмотрены; ширина 390 px и 320 px
  с текстом 200%. Widget-тесты дополнительно проверяют прокрутку при клавиатуре.
- Все 75 исходных файлов совпадают по SHA-256 с baseline; защищённые папки неизменны.

Найденные проблемы и исправления: Android-плагин требует minSdk 24 — конфигурация
обновлена; при Android-автотесте повторный ввод после disabled/loading требовал
явного фокуса и ожидания подключения нативной клавиатуры. Тест теперь проверяет,
что новое значение применилось; успешный повторный вход подтверждён. Это не
ошибка серверного хеширования. Во время работы проверка разрешений один раз
остановилась из-за лимита использования; после команды продолжить выполнена успешно.

Неисправленных ошибок этапа по выполненным проверкам не обнаружено. iOS не
собирался на Windows. Диагностическое отключение Impeller вызывает предупреждение
Flutter о будущем удалении этого флага; в конфигурацию приложения оно не внесено.

Артефакты в `.artifacts/`:

- `stage-5-login-390.png`, `stage-5-register-390.png` — обычный размер форм.
- `stage-5-login-320.png`, `stage-5-register-320.png` — крупный текст, прокручиваемые формы.
- `stage-5-android-restored.png`, `stage-5-android-restored.xml` — новый процесс с восстановленной сессией.
- `stage-5-android-login.png`, `stage-5-android-login.xml` — Login после отклонения сессии.
- `stage-5-test-email.txt` — случайный адрес собственного тестового пользователя для точечной очистки.
- `stage-5-emulator.log`, `stage-5-emulator-error.log` — запуск тестового эмулятора.
- `stage-5-login-filled.xml`, `stage-5-after-login.xml` — промежуточные проверки обычной формы.

APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`.
