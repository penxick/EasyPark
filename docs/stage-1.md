# Этап 1 — Backend Base

Выполнен только этап 1 из `docs/tz/TZ_EasyPark.md`. Этап 2 не начат.
Прототип Figma уже изучен на этапе 0; повторно проверена структура `App.tsx`.
Настройки серверной инфраструктуры не требуют переноса интерфейса.
Flutter, CV-service, исходное ТЗ и Figma-экспорт не редактировались.

## Реализация

- Глобальный ConfigModule читает корневой `.env`; переменные процесса имеют приоритет.
- При старте проверяются обязательные настройки БД, непустой host и диапазоны портов.
  Сообщения проверки не включают пароль или другие значения конфигурации.
- TypeORM создаёт соединение с PostgreSQL. В Docker используется `postgres:5432`,
  локально — `127.0.0.1:55432` по умолчанию. Настройки задаются переменными окружения.
- `synchronize: false`, `migrationsRun: false`: схема не создаётся и не изменяется.
  Сущности, миграции, seed, авторизация и бизнес-API относятся к следующим этапам.
- Настроены ограниченный пул соединений, таймауты соединения/запроса и 3 попытки
  подключения при запуске. При невозможности подключения HTTP-сервер не стартует.
- Глобальный ValidationPipe преобразует DTO, проверяет поля и отклоняет неизвестные
  поля (`whitelist`, `forbidNonWhitelisted`, `forbidUnknownValues`). DTO бизнес-функций
  пока нет; настройки проверены на тестовом DTO вне production API.
- Общий префикс будущего API — `/api`. `GET /health` исключён из префикса.
- `/health` выполняет `SELECT 1`. Успех: HTTP 200 и прежний JSON
  `{"status":"ok","service":"easypark-backend"}`. Недоступная БД: HTTP 503 и
  `{"status":"error","service":"easypark-backend","database":"unavailable"}`.
- При завершении NestJS закрывает соединения TypeORM.

## Конфигурация

| Переменная                                          | Назначение                                                                           |
| --------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `PORT`                                              | HTTP-порт локального backend; при отсутствии используется `BACKEND_PORT`, затем 3000 |
| `BACKEND_PORT`                                      | Публикуемый порт Compose и резервный HTTP-порт локального backend                    |
| `DB_HOST`                                           | Адрес PostgreSQL; локальный default 127.0.0.1; в Compose — postgres                  |
| `POSTGRES_PORT`                                     | Локально — порт PostgreSQL из `.env` (55432); внутри backend-контейнера — 5432       |
| `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` | Обязательные настройки подключения                                                   |

Существующий локальный `.env` не менялся. `DB_HOST` в нём можно не задавать:
действует default. Новая переменная задокументирована в `.env.example`.

## Созданные файлы

- `backend/src/config/environment.ts` — проверка и нормализация конфигурации.
- `backend/src/database/database.module.ts` — TypeORM/PostgreSQL и настройки пула.
- `backend/src/setup.ts` — общие настройки приложения и ValidationPipe.
- `backend/test/environment.test.cjs` — проверки переменных окружения.
- `backend/test/validation.test.cjs` — проверки DTO, недопустимых и лишних полей.
- `backend/test/integration/database.test.cjs` — настоящий AppModule, PostgreSQL и HTTP health.
- `docs/stage-1.md` — этот отчёт.
- `.artifacts/stage-1-compose.log` — журнал сборки и запуска контейнеров.

## Изменённые файлы

- `backend/src/app.module.ts` — подключены ConfigModule и DatabaseModule.
- `backend/src/main.ts` — порт из ConfigService, общая настройка приложения.
- `backend/src/health.controller.ts` — проверка БД и HTTP 503 при недоступности.
- `backend/test/health.test.cjs` — HTTP 200/503, восстановление, исключение `/health` из `/api`.
- `backend/package.json` — зависимости и команда `test:integration`.
- `backend/package-lock.json` — закреплённые зависимости.
- `docker-compose.yml` — переменные подключения PostgreSQL для backend.
- `.env.example` — адрес БД для локального запуска.
- `README.md` — актуальные запуск, конфигурация и проверки.

Установка также обновила `backend/node_modules/`, сборка — `backend/dist/`;
это сгенерированные файлы, исключённые из Git. Исходники этапа 0 не удалялись.

## Проверки 24.09.2026

| Проверка                             | Результат                                 |
| ------------------------------------ | ----------------------------------------- |
| Prettier format / format:check       | Пройдены                                  |
| ESLint                               | Без замечаний                             |
| NestJS / TypeScript build            | Успешно                                   |
| `npm test`                           | 8 тестов пройдены                         |
| `npm run test:integration`           | 1 тест с реальным PostgreSQL пройден      |
| Docker Compose build и запуск        | Все 3 сервиса healthy                     |
| `/health` на работающем backend      | HTTP 200                                  |
| Остановка только PostgreSQL EasyPark | Backend вернул HTTP 503                   |
| Повторный запуск PostgreSQL          | Backend вернул HTTP 200 без перезапуска   |
| `pg_stat_activity`                   | Подключение easypark-backend присутствует |
| Таблицы в public                     | 0; бизнес-схема не создана                |

## Замечания

Ошибок сборки, lint или тестов не осталось. npm при установке сообщил о deprecated
транзитивной зависимости `glob@10.5.0` внутри `typeorm@0.3.31`, но audit сообщил
0 известных уязвимостей. Принудительная замена её major-версии через override не
выполнялась, чтобы не нарушать совместимость TypeORM. Это оставшееся предупреждение
пакетного менеджера, а не ошибка запуска.

Сервисы оставлены запущенными; БД после проверки отказа восстановлена.
Команды запуска находятся в [README](../README.md).

Официальные источники настройки:
[NestJS ConfigModule](https://docs.nestjs.com/techniques/configuration),
[NestJS ValidationPipe](https://docs.nestjs.com/techniques/validation),
[NestJS databases](https://docs.nestjs.com/techniques/database).
