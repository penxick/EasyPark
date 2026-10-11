# Android APK EasyPark: сборка и установка

Все команды Flutter выполнять из `D:\EasyPark\mobile`. Требуется существующий Flutter/Android SDK только на компьютере сборки. Получатель APK устанавливает файл средствами Android: Flutter, Android Studio и отладчик ему не нужны. Backend для работы функций должен быть доступен по сети.

## Готовая локальная сборка

`D:\EasyPark\.artifacts\apk\EasyPark-emulator-debug-universal.apk`

Это debug APK с API `http://10.0.2.2:3000/api/` только для Android Studio Emulator на ПК, где работает backend. Не распространяйте его как готовую телефонную/интернет-сборку: 10.0.2.2 — специальный адрес хоста Android Studio Emulator. Наличие нескольких ABI не делает адрес сервера универсальным.

Пакет `com.easypark.easypark`, имя EasyPark, Android 7.0/API 24 и новее. В APK присутствуют armeabi-v7a, arm64-v8a, x86_64. Это не гарантия работы каждого стороннего эмулятора: он должен поддерживать API 24+ и одну из этих ABI. Android x86 32-bit не включён.

Для эмулятора:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm,android-arm64,android-x64 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/
D:\sdk\platform-tools\adb.exe -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
D:\sdk\platform-tools\adb.exe -s emulator-5554 shell am start -n com.easypark.easypark/.MainActivity
```

Команда am start запускает установленное приложение самостоятельно; flutter run не требуется. На телефоне передайте APK через USB/файл и разрешите установку из выбранного источника. При конфликте сертификата обновления нужна прежняя подпись; удаление старого приложения стирает его локальную сессию.

## Три варианта адреса

Адрес задаётся явно при каждой сборке; fallback на localhost/эмулятор удалён. В `--dart-define` допустим только адрес, без JWT, паролей и секретов. Не используйте `.env` backend как `--dart-define-from-file`.

1. Android Studio Emulator: `http://10.0.2.2:3000/api/`, debug.
2. Локальная сеть: `http://<IP_ПК>:3000/api/`, debug. Замените IP на реальный адрес ПК, например через переменную `$apiUrl = Read-Host 'Адрес API локальной сети'`, затем `flutter build apk --debug --dart-define=API_BASE_URL=$apiUrl`. Не задавайте localhost/10.0.2.2 на телефоне или стороннем эмуляторе.
3. Окончательная версия: `https://<публичный-домен>/api/`, release. Введите реальный действующий HTTPS URL. Он должен быть доступен с телефона, ноутбука и эмулятора вне домашней сети.

Текущий Docker Compose публикует backend и PostgreSQL на loopback ПК. Для LAN понадобится отдельная настройка публикации backend и firewall; для интернета — домен/HTTPS reverse proxy либо туннель с сохранением маршрута /api/. Это не выполнено данным этапом. PostgreSQL в интернет не публиковать. Адрес ПК и публичный домен здесь намеренно не заданы.

HTTPS обрабатывается штатным HTTP-клиентом с проверкой сертификатов. Самоподписанный/недоверенный сертификат не обходится. HTTP разрешён debug manifest только для локальной разработки; release использует HTTPS. При потере соединения существующие экраны показывают безопасную ошибку и повторную загрузку. API timeout — 15 секунд; автоматические изменения данных повторно не отправляются.

## Постоянная release-подпись

В проекте нет release keystore или `android/key.properties`. Debug-подпись больше не подставляется в release. Попытка release без настроек останавливается с сообщением. Ключ и пароли создаёт/выбирает владелец; они не генерировались этим этапом.

Создание ключа: выберите постоянный путь вне Git и выполните в PowerShell (keytool запросит пароль и данные владельца интерактивно):

```powershell
$keystorePath = Read-Host 'Полный путь для нового постоянного release keystore (.jks)'
& 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe' -genkeypair -v -keystore $keystorePath -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias easypark
```

Не перезаписывайте уже существующий ключ. Храните защищённую резервную копию ключа и паролей; тот же ключ нужен для последующих обновлений APK.

Создайте локально `D:\EasyPark\mobile\android\key.properties`:

```properties
storeFile=C:/absolute/path/to/your/easypark-release.jks
storePassword=<ваш пароль хранилища>
keyAlias=easypark
keyPassword=<ваш пароль ключа>
```

Замените все placeholders. Используйте прямые слеши в Windows-пути; специальные символы Properties при необходимости экранируйте. Файл и *.jks/*.keystore уже исключены Android .gitignore. Не добавляйте их принудительно в Git и не отправляйте пароль в чат.

После настройки ключа и публичного API:

```powershell
$apiUrl = Read-Host 'Действующий публичный HTTPS API URL с /api/'
flutter build apk --release --target-platform android-arm,android-arm64,android-x64 --dart-define=API_BASE_URL=$apiUrl
```

Результат: `D:\EasyPark\mobile\build\app\outputs\flutter-apk\app-release.apk`.
Для уменьшения размера отдельных файлов добавьте `--split-per-abi`: будут app-armeabi-v7a-release.apk, app-arm64-v8a-release.apk, app-x86_64-release.apk. Проверяйте каждый предназначенный для распространения APK:

```powershell
D:\sdk\build-tools\36.1.0\apksigner.bat verify --print-certs build\app\outputs\flutter-apk\app-release.apk
D:\sdk\build-tools\36.1.0\aapt.exe dump badging build\app\outputs\flutter-apk\app-release.apk
```

Официальная инструкция Flutter: [Build and release an Android app](https://docs.flutter.dev/deployment/android).

## Иконка и проверка устройств

Текущая иконка — стандартная Flutter, сохранена без изменения дизайна. Название в Android — EasyPark. Для отдельной брендированной иконки нужен согласованный ресурс.

Реально проверен только Pixel_7 x86_64. Физический телефон, BlueStacks, LDPlayer, Nox не проверены: подключённых устройств/запускаемых плееров не обнаружено (остаточные папки BlueStacks/Nox есть). Для них потребуется сборка с доступным им LAN/HTTPS адресом, а не адресом Android Studio Emulator.
