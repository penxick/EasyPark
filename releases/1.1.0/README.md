# EasyPark 1.1.0+2

Debug APK для Android-эмулятора: `EasyPark-v1.1.0-emulator.apk`.

- applicationId: `com.easypark.easypark`
- versionName: `1.1.0`
- versionCode: `2`
- Backend: `http://10.0.2.2:3000/api/`
- Размер: 159897873 байта
- SHA-256: `1EEA54B86A4BD4424F1B61C368BC0A07740F378CEEF36B874EE46DBB0F32AE1F`

APK распространяется через GitHub Releases, а не Git: размер превышает лимит обычного файла репозитория. Локальные старые APK сохранены.

Версия включает тарифы за 30 минут, выбор длительности, управление масштабом, геолокацию с Android fallback и интерфейс маршрута. Реальная доступность OSRM из проверочной среды пока не подтверждена из-за ошибки TLS.

Backend требует новой миграции `AddParkingPrice301791763200000`. Подробности и результаты проверок: [отчёт](../../docs/stage-pricing-navigation.md).
