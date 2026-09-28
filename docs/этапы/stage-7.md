# Этап 7 — Parking Backend

Выполнен только этап 7. Этап 8 (карта Flutter) не начат.

## Результат

Parking хранит id, name, description, address, latitude, longitude, pricePerHour,
workingHours, createdAt, updatedAt. Координаты имеют точность 6 знаков, цена —
2 знака и хранится PostgreSQL numeric; в JSON координаты и цена возвращаются числами.
БД проверяет широту −90…90, долготу −180…180 и неотрицательную конечную цену.
Миграция добавляет только parkings; synchronize остаётся выключенным.

GET /api/parkings возвращает массив с устойчивой сортировкой по id.
GET /api/parkings/:id возвращает объект; отсутствующий id — 404,
некорректный или выходящий за диапазон PostgreSQL integer — 400.
Оба маршрута требуют действующий Bearer JWT (без него 401), как основной
авторизованный сценарий приложения. Изменяющие административные API не добавлены.
Количество мест не выдумывается: ParkingSpace предусмотрен этапом 10.

Изучены требования этапа, сущность Parking в ТЗ, DriverApp/DriverProfile ранее
и ParkingList.tsx в этом этапе. Цена в прототипе задана для места; в текущем
контракте согласно ТЗ цена принадлежит парковке. Web-код и зависимости не переносились.

## Seed

Три вымышленные демопарковки в районе Красноярска с явной пометкой «Демо».
Координаты — учебные точки, тарифы и режим работы не являются реальными сведениями.
Seed запускается отдельно, не при каждом старте сервера. Транзакция и advisory lock
защищают одновременные запуски. По паре name/address существующая запись пропускается,
её цена и другие поля не перезаписываются. Если вручную изменить name/address,
следующий seed снова добавит исходную демозапись. Бизнес-уникальность адресов не вводится.

Из корня проекта для Docker:

```powershell
docker compose up -d --build backend
docker compose exec -T backend npm run seed
```

Локально из backend (конфигурация из корневого .env):

```powershell
npm run build
npm run migration:run
npm run seed
npm start
```

## Созданные файлы

- backend/src/parking/parking.entity.ts — сущность, типы, ограничения БД.
- backend/src/parking/parking.service.ts — список и получение одной парковки.
- backend/src/parking/parking.controller.ts — HTTP API, JWT guard и проверка id.
- backend/src/parking/parking.module.ts — регистрация сущности и зависимостей.
- backend/src/database/migrations/1790380800000-create-parkings.ts — обратимая миграция.
- backend/src/database/parking-seed.ts — демоданные и повторяемое заполнение.
- backend/src/database/seed.ts — CLI seed с закрытием соединений.
- backend/test/integration/parking.test.cjs — API, БД, миграция и seed.
- backend/test/docker-parking-smoke.cjs — проверка HTTP в запущенном Docker.
- docs/stage-7.md — этот отчёт.

## Изменённые файлы

- backend/src/app.module.ts — подключён ParkingModule.
- backend/src/auth/auth.module.ts — экспорт JwtModule и UsersModule для guard в других модулях.
- backend/src/database/database.module.ts — регистрация новой миграции.
- backend/package.json — команда npm run seed.
- README.md — состояние проекта, команды и отчёт этапа.

Новых зависимостей нет; package-lock.json, Flutter, CV и исходные материалы не менялись.
Обновлены генерируемые backend/dist, образ Docker и таблица миграций локальной БД;
в parkings сохранены три демозаписи. Тестовые пользователи и записи удалены адресно.

## Проверки и ошибки

- Prettier format / format:check — успешно.
- ESLint — без замечаний.
- Nest build — успешно локально и в Docker.
- Unit tests — 11/11.
- Integration tests — 13/13 вместе с Auth и Database.
- Проверены точный JSON-контракт, дробная цена, авторизация, 400/404,
  запрет неподдерживаемого POST, отсутствие schema drift, up/down миграции
  в отдельной временной схеме, ограничения БД, конкурентный seed и сохранение правок.
- Docker smoke — реальные регистрация, список, detail и 401 успешно.
- Повторный seed в Docker добавил 0 записей, всего три демопарковки.
- Backend, PostgreSQL и CV имеют статус healthy.
- SHA256 всех 75 исходных файлов совпадает с исходным baseline.

Первый npm-запуск из корня не нашёл package.json: команды повторены из backend.
При запуске нового модуля обнаружена недоступность JwtService для JwtAuthGuard:
исправлен экспорт зависимостей AuthModule, затем повторены проверки.
Сохраняется прежнее предупреждение npm о deprecated glob@10.5.0 в транзитивных
зависимостях; npm ci сообщил 0 vulnerabilities. Итоговых ошибок текущего этапа нет.

Flutter не менялся и не пересобирался. Следующий шаг требует отдельной команды.
