# A7 — Admin Flutter Base

Дата: 10 октября 2026 года. Этап завершён; следующий — A8.

## Реализация

Общий экран входа принимает логин или email. Регистрация USER сохраняет
проверку email. После входа и восстановления JWT роль ADMIN направляет в /admin,
USER — в существующую пользовательскую часть. Прямой переход USER на /admin
и вложенные маршруты показывает «Нет доступа», не загружая административные API.
Backend продолжает независимо проверять JWT и роль.

Dashboard получает GET /api/admin/analytics через общий ApiClient. Отображает
восемь обязательных счётчиков и процент загрузки доступных мест. Предусмотрены
загрузка, ошибка с повтором, пустая база, обновление кнопкой/жестом и при возврате
приложения на передний план. Значения не захардкожены. При 403 роль повторно
проверяется через /users/me; неизменившаяся роль не вызывает цикл загрузки.

Меню содержит Главную, Парковки, Бронирования, Пользователей, Аналитику и Профиль.
На телефоне используется Drawer, на широком экране — боковая панель. Профиль
переиспользует существующий ProfileDetails и выход с очисткой secure storage.
Маршруты будущих разделов защищены, но пока показывают явные заглушки.
CRUD, карта администратора, списки пользователей/броней и подробная аналитика
относятся к A8–A12 и на этом этапе не реализованы.

Изучен локальный Figma-reference, в частности OperatorApp.tsx и стили.
Сохранены белые карточки, серый фон, синие заголовки, зелёный счётчик свободных
мест, отступы и полоса загрузки. Использованы существующие UI-kit и Lucide.
Демонстрационные платежи/выручка из референса не переносились. React-код и
web-зависимости не добавлялись. Системный пароль не встраивается во Flutter.

## Проверки

- flutter analyze: без замечаний.
- flutter test: 88 тестов прошли, включая 9 новых проверок ADMIN.
- Проверены login/redirect, восстановление сессии, запрет USER deep links,
  профиль/logout, loading/error/retry/empty/refresh, изменение роли при 403,
  отсутствие повторяющегося цикла при 403, ширина 320 с масштабом текста 2
  и широкий экран 1200.
- Android integration test на emulator-5554 с работающим HTTP API прошёл:
  вход временного ADMIN, восстановление JWT из secure storage, реальные
  показатели, меню, профиль и выход.
- Снимки Dashboard и меню просмотрены; перекрытия элементов не обнаружены.
  Снимки сохранены локально в .artifacts/admin-a7/ (не входят в Git).
- Временный ADMIN и файлы его тестовых credentials удалены после проверки.
- Обычный debug APK повторно собран, установлен и запущен на эмуляторе,
  заменив тестовую сборку. API_BASE_URL=http://10.0.2.2:3000/api/.
- Все 75 SHA-256 исходных материалов совпали; git diff --check прошёл.

В ходе работы исправлены ошибки тестовой константы и форматирования условий,
а также предотвращён цикл повторной загрузки при 403. Повторные проверки прошли.
Первый запрос разрешения обычной APK-сборки завершился тайм-аутом автоматической
проверки; разрешённый повтор и сборка прошли. Нерешённых ошибок A7 не обнаружено.
Полная регрессия USER на устройстве и CV предусмотрена A13; текущий Flutter
набор включает прежние USER-тесты. Backend и CV исходники в A7 не изменялись.

## Созданные файлы

- mobile/lib/features/admin/data/admin_api.dart — общий API адаптер аналитики.
- mobile/lib/features/admin/models/admin_summary.dart — модель и проверка показателей.
- mobile/lib/features/admin/repositories/admin_repository.dart — загрузка и обработка 403.
- mobile/lib/features/admin/widgets/admin_stat_card.dart — карточка показателя.
- mobile/lib/features/admin/widgets/admin_shell.dart — адаптивное меню.
- mobile/lib/features/admin/screens/admin_dashboard_screen.dart — Dashboard и состояния.
- mobile/lib/features/admin/screens/admin_profile_screen.dart — профиль ADMIN.
- mobile/lib/features/admin/screens/admin_section_screen.dart — заглушки будущих разделов.
- mobile/test/admin_test.dart — модель, авторизация, маршруты и UI.
- mobile/integration_test/admin_base_test.dart — Android сценарий с реальным API.
- mobile/test_driver/admin_base_driver.dart — сохранение тестовых снимков.
- docs/admin/stage-a7.md — этот отчёт.

## Изменённые файлы

- mobile/lib/features/auth/auth_validators.dart — проверка логина.
- mobile/lib/features/auth/auth_repository.dart — отправка login вместо email при входе.
- mobile/lib/features/auth/auth_controller.dart — роль и обновление identity после 403.
- mobile/lib/features/auth/auth_form_screen.dart — поле «Логин / Email».
- mobile/lib/core/router/app_routes.dart — имена административных путей.
- mobile/lib/core/router/app_router.dart — guard, redirect и административные маршруты.
- mobile/lib/core/widgets/app_top_bar.dart — поддержка кнопки меню.
- mobile/test/auth_test.dart — актуальный текст ошибки входа.
- mobile/test/auth_widget_test.dart — актуальная валидация входа.
- mobile/integration_test/auth_flow_test.dart — трассировка поля login.
- README.md — актуальные возможности и следующий этап.

Генерируемые mobile/build и .artifacts обновлены и игнорируются Git. Предыдущие
изменения A1–A6 сохранены. ТЗ/Figma не изменялись, GitHub не обновлялся.
