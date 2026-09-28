# Этап 8 — карта Flutter

Выполнен только этап 8. Этап 9 не начат.

## Результат

После входа MapScreen получает GET /api/parkings с текущим JWT через общий ApiClient.
ParkingRepository проверяет список, уникальность id, координаты и цену; повреждённый
ответ не превращается в некорректные маркеры. JWT не передаётся картографическому сервису.

Карта показывает маркеры всех полученных парковок и первоначально охватывает их.
Доступны перемещение и масштабирование, возврат ко всем маркерам, обновление данных.
При переключении нижних вкладок сохраняется экземпляр карты и положение камеры.
Нажатие на маркер открывает прокручиваемую карточку: название, адрес, цена,
сообщение о недоступных пока счётчиках мест и «Подробнее».
Кнопка ведёт на существующую заглушку /parking/:id; полноценный экран — этап 9.

Есть состояния загрузки, пустого списка и ошибки API с повтором. При 401 работает
общий сброс авторизации. Ошибка фоновых тайлов показывает отдельное уведомление
и кнопку повтора; маркеры остаются доступными. При малой высоте и крупном тексте
область карты прокручивается, предотвращая переполнение.

## Дизайн и зависимости

В локальном Figma городской экран — текстовая заглушка; ParkingMap.tsx рисует схему
мест, а не географическую карту. Использованы существующие цвета, Lucide, белая
карточка, серый вторичный текст и синяя кнопка; схему мест на этом этапе не переносили.
Счётчики свободных/всех мест не выдумывались: backend получит ParkingSpace позднее.

Добавлены Flutter-пакеты flutter_map 8.3.2, latlong2 0.10.1, url_launcher 6.3.2
и их разрешённые pub зависимости. Web-зависимости прототипа не переносились.
Карта использует HTTPS OpenStreetMap, идентификатор com.easypark.easypark,
встроенный дисковый кэш flutter_map по HTTP-заголовкам, panBuffer 0, max zoom 19.
Есть видимая кликабельная атрибуция; массовая загрузка и offline-пакеты не реализованы.
Разрешение геолокации, API-ключи, платежи и маршруты до парковки не добавлялись.

Справочные материалы:
- https://pub.dev/packages/flutter_map
- https://docs.fleaflet.dev/layers/tile-layer
- https://operations.osmfoundation.org/policies/tiles/

Публичный сервер OSM не гарантирует доступность; для масштабного публичного
развёртывания нужно повторно оценить подходящий картографический сервис.

## Созданные файлы

- mobile/lib/features/map/parking.dart — валидируемая модель и формат цены.
- mobile/lib/features/map/parking_repository.dart — чтение парковок через API.
- mobile/lib/features/map/parking_map.dart — карта, маркеры, тайлы, атрибуция и повтор загрузки.
- mobile/lib/features/map/parking_summary.dart — адаптивная краткая карточка.
- mobile/test/map_test.dart — семь тестов контракта и поведения интерфейса.
- mobile/test/support/map_fixture.dart — данные и локальные поставщики тайлов для тестов.
- mobile/integration_test/map_flow_test.dart — реальный Android/backend сценарий.
- mobile/tool/render_map_test.dart — воспроизводимая отрисовка карточки.
- docs/stage-8.md — этот отчёт.

## Изменённые файлы

- mobile/lib/features/map/map_screen.dart — заменена заглушка, добавлены загрузка и карточка.
- mobile/lib/core/router/app_router.dart — передача общего API-клиента в ParkingRepository.
- mobile/pubspec.yaml — три зависимости карты.
- mobile/pubspec.lock — разрешённые версии и транзитивные зависимости.
- mobile/lib/features/README.md — границы и владение зависимостями.
- mobile/README.md — запуск и проверки карты.
- README.md — состояние проекта.

Flutter автоматически обновил регистрацию url_launcher:
- mobile/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
- mobile/ios/Runner/GeneratedPluginRegistrant.m

Также обновлены служебные .dart_tool, build и .flutter-plugins-dependencies.
Backend, CV и исходные материалы не изменены.

## Проверки

- dart format — выполнено, итоговая проверка без изменений.
- flutter analyze — без замечаний.
- flutter test — 51/51, включая семь новых проверок карты.
- flutter test integration_test/map_flow_test.dart на Pixel_7 API 36 — успешно:
  реальная регистрация/JWT, GET parkings, минимум три маркера, переключение вкладок,
  сохранение экземпляра карты, карточка с данными backend, переход и возврат.
- flutter test tool/render_map_test.dart — успешно; карточка 390 px и 320 px при тексте 200%.
- flutter build apk --debug --no-pub — успешно; собран обычный lib/main.dart, не тестовый APK.
- Обычный APK установлен, выполнен вход тестовым аккаунтом, реальные тайлы OSM
  и три маркера визуально проверены; карточка открыта нажатием на маркер.
- Все 75 SHA256 исходных файлов совпадают с baseline.
- Временный stage8-пользователь удалён по точному email; демопарковки сохранены.
- Эмулятор остановлен. iOS не собирался: доступна Windows.

Исправлены четыре замечания lint к блокам if и переполнение при 320×480/тексте 200%
в состоянии ошибки тайлов. Первую имитацию сбоя тайла уточнили: ошибка декодирования
вместо синхронного исключения конструктора поставщика. Итоговый тест проходит.
При Android-сборке был временный DNS-сбой dl.google.com и сообщение Kotlin
incremental cache о разных дисках C:/D:. Повторная сборка Flutter завершилась
успешно; обычный APK также собран. Постоянных обходных настроек Gradle не добавляли.

## Артефакты

- mobile/build/app/outputs/flutter-apk/app-debug.apk
- .artifacts/stage-8-android.png — реальная карта на Android.
- .artifacts/stage-8-android-card.png — реальная карточка на Android.
- .artifacts/stage-8-card-390.png
- .artifacts/stage-8-card-320.png
- .artifacts/stage-8-ui.xml — дерево интерфейса карты.
- .artifacts/stage-8-test-email.txt — адрес уже удалённого тестового аккаунта.
- .artifacts/stage-8-emulator.log
- .artifacts/stage-8-emulator-error.log

Следующий этап требует отдельной команды.
