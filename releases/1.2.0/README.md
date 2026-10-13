# EasyPark 1.2.0+3

- APK: D:\EasyPark\releases\1.2.0\EasyPark-v1.2.0-emulator.apk
- Размер: 161930561 байт (154.43 MiB).
- SHA-256: B5DE5A86423F31F7CD7F08311D1DF2F889DC29C0006BAE92BE1EAF17B2845B96
- aapt: versionName=1.2.0, versionCode=3.
- applicationId: com.easypark.easypark (сохранён).
- Тип: debug, стандартная debug-подпись разработчика.
- API_BASE_URL: http://10.0.2.2:3000/api/
- Адрес можно изменить через настройки приложения.
- Старые APK сохранены. Установленный versionCode не прочитан: эмулятор offline.

Сборка: flutter build apk --debug --no-pub --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/

Подробности функций, миграций и проверок: docs/stage-booking-payment-settings.md.
Реальные платежи и YOLO-подтверждение прибытия/выезда отсутствуют; используется защищённый демонстрационный API. Для писем необходимо настроить SMTP.
