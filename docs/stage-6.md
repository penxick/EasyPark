# Этап 6 — основная навигация

Выполнен только этап 6. Этап 7 не начат.

## Реализация и границы

Созданы отдельные MapScreen, ReservationsScreen и ProfileScreen. Общая оболочка
содержит заголовок EasyPark и нижнее меню Карта / Бронирования / Профиль.
StatefulShellRoute.indexedStack сохраняет состояние веток. Повторный выбор вкладки
не добавляет маршрут в историю. Прямые ссылки выбирают соответствующую вкладку.
Системная кнопка «Назад» из вторичных разделов возвращает на карту.
Гостям меню недоступно; потеря сессии переводит на Login.

Из DriverApp.tsx и DriverProfile.tsx использованы оформление белых поверхностей,
серый фон, синие акценты, Lucide, отступы и карточки. Верхние четыре вкладки
прототипа заменены нижними тремя согласно приоритету ТЗ (§16, этап 6).
На узком экране с крупным текстом нижнее меню размещает пункты вертикально.
Содержимое разделов пока явно обозначено как будущее: без вымышленных данных.
Карта с парковками, бронирования и полноценный профиль остаются на своих этапах.
Новых зависимостей нет; backend, CV и исходные материалы не изменены.

## Созданные файлы

- mobile/lib/features/navigation/main_shell.dart — оболочка и обработка Back.
- mobile/lib/features/navigation/section_preview.dart — адаптивное временное содержимое.
- mobile/lib/features/map/map_screen.dart — экран раздела карты.
- mobile/lib/features/reservation/reservations_screen.dart — экран бронирований.
- mobile/lib/features/profile/profile_screen.dart — экран профиля.
- mobile/test/navigation_test.dart — переходы, прямые ссылки, Back, сохранение ветки,
  сброс сессии и доступность меню при 320×480 и масштабе текста 2.
- mobile/tool/render_navigation_test.dart — воспроизводимая отрисовка для проверки.
- docs/stage-6.md — этот отчёт.

## Изменённые файлы

- mobile/lib/core/router/app_router.dart — три ветки общей оболочки вместо заглушек маршрутов.
- mobile/lib/features/README.md — границы модулей.
- mobile/README.md — состояние мобильного приложения.
- README.md — состояние проекта и ссылка на отчёт.

## Проверки

- dart format — выполнено.
- flutter analyze — без замечаний.
- flutter test — 44 теста прошли, включая существующие проверки авторизации.
- flutter test tool/render_navigation_test.dart с FLUTTER_SDK — прошёл;
  созданы шесть изображений 390 px / 320 px с увеличенным текстом.
- Визуально проверены карта 390 px и профиль 320 px; обрезаний и переполнений нет.
- flutter build apk --debug --no-pub — успешно.
- Контроль SHA256: все 75 исходных файлов неизменны.

Запуск интерфейса проверен Flutter widget harness; отдельный запуск этой сборки
на Android-эмуляторе и сборка iOS в этом этапе не выполнялись.
Ошибок в итоговых проверках нет. При подготовке вспомогательного скрипта отрисовки
исправлена лишняя закрывающая скобка до его запуска.

## Генерируемые артефакты

- .artifacts/stage-6-home-390.png
- .artifacts/stage-6-home-320.png
- .artifacts/stage-6-reservations-390.png
- .artifacts/stage-6-reservations-320.png
- .artifacts/stage-6-profile-390.png
- .artifacts/stage-6-profile-320.png
- mobile/build/app/outputs/flutter-apk/app-debug.apk — обновлённая Android-сборка.

Flutter также обновляет служебные кэши .dart_tool и build; они не являются исходниками.
