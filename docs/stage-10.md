# Этап 10 — ParkingSpace Backend

Выполнен только этап 10. Flutter-схема парковки (этап 11) не начата.

## Реализация

ParkingSpace хранит id, parkingId, code, status, physicalOccupied, x, y,
polygon, createdAt и updatedAt. Статусы: FREE, OCCUPIED, RESERVED, UNAVAILABLE.
По умолчанию статус FREE, physicalOccupied=false, polygon=null.

В БД добавлены внешний ключ на parkings с ON DELETE RESTRICT, уникальный индекс
по (parkingId, code), проверки непустого кода без внешних пробелов, статуса и
конечных неотрицательных координат. Polygon — nullable jsonb, для ненулевого значения
проверяется массив минимум из трёх элементов. Полная геометрическая проверка точек
и привязка к изображению камеры относятся к будущему CV/административному вводу;
на текущем этапе внешнего API записи polygon нет.

GET /api/parkings/:parkingId/spaces требует JWT и возвращает массив мест только
указанной парковки, отсортированный по code/id. Существующая парковка без мест
возвращает [], отсутствующая — 404, некорректный id — 400, запрос без JWT — 401.
Отдельный GET /spaces/:id, административные изменения и бронирование не добавлялись.

GET /api/parkings и GET /api/parkings/:id теперь также возвращают числовые
freeSpaces и totalSpaces. Они вычисляются по ParkingSpace в том же SQL-запросе,
а не хранятся в Parking. Свободным считается status=FREE AND physicalOccupied=false.
Для парковки без мест оба значения равны 0. Все остальные поля контракта сохранены.
Подробный экран этапа 9 уже поддерживает эти поля и получает числа без изменения
Flutter-кода. Краткая карточка карты на этом этапе не менялась.

## Демоданные и Figma

Seed добавляет 20 мест A01…D05 каждой из трёх демопарковок: 60 записей всего.
На парковку: 11 FREE, 4 OCCUPIED, 4 RESERVED, 1 UNAVAILABLE.
Статусы демонстрационные: RESERVED не создаёт реальную Reservation.

Расположение основано на ParkingMap.tsx и DriverApp.tsx Figma: четыре колонки,
пять рядов, логическое поле 600×350. x/y обозначают левый верхний угол места;
для будущей схемы размеры прототипа — 80×40. Коды приведены к формату ТЗ (A01).
Polygon оставлен null: координаты схемы не выдаются за калибровку камеры.

Seed запускается вручную командой npm run seed; сначала добавляет парковки,
затем места. Транзакция, advisory lock и ON CONFLICT DO NOTHING делают заполнение
повторяемым и безопасным при двух одновременных запусках. Существующие статусы,
координаты и другие изменения не перезаписываются. Места добавляются только в
демопарковки, найденные по их исходным name/address.

## Созданные файлы

- backend/src/parking-spaces/parking-space.entity.ts — сущность и ограничения.
- backend/src/parking-spaces/parking-spaces.service.ts — выборка мест с проверкой парковки.
- backend/src/parking-spaces/parking-spaces.controller.ts — защищённый GET endpoint.
- backend/src/parking-spaces/parking-spaces.module.ts — зависимости модуля.
- backend/src/database/migrations/1790553600000-create-parking-spaces.ts — обратимая миграция.
- backend/src/database/parking-space-seed.ts — тестовые места и заполнение.
- backend/test/integration/parking-spaces.test.cjs — API, ограничения, счётчики, миграция и seed.
- docs/stage-10.md — этот отчёт.

## Изменённые файлы

- backend/src/app.module.ts — подключение ParkingSpacesModule.
- backend/src/database/database.module.ts — регистрация миграции.
- backend/src/database/seed.ts — добавление мест после парковок.
- backend/src/parking/parking.service.ts — вычисляемые счётчики.
- backend/test/integration/parking.test.cjs — расширенный контракт парковки.
- backend/test/docker-parking-smoke.cjs — HTTP-проверка мест и счётчиков в Docker.
- README.md — актуальные команды и состояние проекта.
- mobile/README.md — уточнение доступности счётчиков из backend.

Новых зависимостей нет. Flutter/Dart, CV, package.json/lock не изменялись.
Обновлены генерируемый backend/dist, Docker-образ и локальная БД: новая таблица,
запись миграции и 60 демомест. Ранее существующие данные не удалялись.

## Проверки и запуск

```powershell
# Из backend:
npm run format:check
npm run lint
npm run build
npm run migration:run
npm run seed
node --test test/*.test.cjs test/integration/*.test.cjs

# Из корня:
docker compose up -d --build backend
docker compose exec -T backend npm run seed

# Из backend после запуска Docker:
node test/docker-parking-smoke.cjs
```

- Форматирование и lint — успешно.
- Сборки Nest локально и Docker — успешно.
- Миграция применена; synchronize остаётся false.
- 29/29 backend-проверок прошли (11 unit и 18 интеграционных, включая вложенные).
- Проверены JWT, поля ответа, сортировка, разделение по parkingId, пустой список,
  400/404, неподдерживаемый POST, уникальность, FK, статусы, NaN/Infinity/отрицательные
  координаты, минимальная структура polygon и запрет удаления парковки с местами.
- Проверено изменение счётчиков после смены статуса и исключение физически занятых
  мест со статусом FREE; пустая парковка возвращает 0/0.
- Schema drift отсутствует. Up/down/up/down проверены в отдельной временной схеме.
- Конкурентный seed создал ровно 60 мест; повтор не изменил отредактированные записи.
- Docker smoke проверил все три демопарковки, их 60 мест, четыре статуса и счётчики.
- Повторный seed в Docker добавил 0 парковок и 0 мест.
- Backend, PostgreSQL и CV имеют статус healthy.
- Временные пользователи и места тестов удалены адресно, временные схемы удалены.
- SHA256 исходных материалов: 75 файлов без изменений.

Ошибок текущего этапа в итоговых проверках не обнаружено.
Flutter не менялся и не пересобирался. Следующий этап требует отдельной команды.
