# Этап 4 — Auth Backend

Реализован только этап 4 ТЗ: User, AuthModule, JWT, регистрация, вход,
`GET /users/me`. Этап 5 (Flutter Auth) не начат. Mobile и CV-код не менялись.

Изучены разделы 8, 11–15, 31–34 и этап 4 в `docs/tz/TZ_EasyPark.md`, формы
LoginScreen/RegisterScreen Figma. По приоритету ТЗ используется email и имя;
телефон, автомобиль, тестовые пароли и администраторский вход прототипа не перенесены.

## API

Базовый URL локального backend: `http://127.0.0.1:3000/api`.

| Метод и путь | Запрос / авторизация | Результат |
| --- | --- | --- |
| POST `/auth/register` | JSON `name`, `email`, `password` | 201, `{accessToken, user}` |
| POST `/auth/login` | JSON `email`, `password` | 200, `{accessToken, user}` |
| GET `/users/me` | `Authorization: Bearer <accessToken>` | 200, объект `user` |

`user` содержит только `id` (число), `name`, `email`, `role`, `createdAt`,
`updatedAt` (ISO 8601). Поля password/passwordHash не возвращаются ни в одном
ответе. Успешные ответы авторизации и профиля содержат `Cache-Control: no-store`.

Пример тела регистрации:

```json
{"name":"Роман","email":"roman@example.com","password":"My parking password"}
```

Валидация:

- Имя обрезается по краям; 1–100 символов.
- Email обрезается по краям, приводится к нижнему регистру; корректный адрес до 254 символов.
- Пароль регистрации: 8–128 символов, не только пробелы. Не обрезается и не нормализуется.
  Это принятое ограничение backend, поскольку ТЗ не задаёт длину. В прототипе минимум 5;
  Flutter этапа 5 должен использовать контракт backend 8–128.
- Повтор пароля проверяется во Flutter перед отправкой; по контракту ТЗ backend
  принимает одно поле `password`. Лишние поля, включая `role` и `passwordHash`, дают 400.

Ошибки: 400 — входные данные; 401 — неверные credentials/JWT; 409 — занятый email;
429 — слишком частые запросы. Неверный пароль и неизвестный email возвращают
одинаковое сообщение: «Неверный email или пароль.»

## Хранение и безопасность

User содержит все поля ТЗ. PostgreSQL гарантирует уникальность нормализованного
email индексом `UQ_users_email`. CHECK запрещает ненормализованный email и роли
вне USER/ADMIN. Регистрация всегда создаёт USER. Публичного повышения роли нет.

Пароли хешируются асинхронным scrypt из Node.js: N=32768, r=8, p=3, случайная
соль 16 байт, ключ 64 байта, constant-time сравнение. Формат хранит параметры,
соль и хеш. Для неизвестного email выполняется такая же затратная проверка.
`passwordHash` исключён из обычных ORM SELECT; ответы дополнительно строятся
явным списком разрешённых полей.

JWT: HS256, issuer `easypark-backend`, audience `easypark-mobile`, `sub` — строка
с ID. Проверяются подпись, алгоритм, issuer/audience, exp/iat и существование
пользователя. Роль и профиль читаются из БД, а не из токена. JWT удалённого
пользователя не проходит проверку.

`JWT_SECRET` обязателен, не короче 32 байт, placeholder запрещён. В локальный
игнорируемый `.env` добавлен случайный секрет; его значение не сохранено в отчёте.
`JWT_TTL_SECONDS`: 604800 (7 суток) по умолчанию, диапазон 60–2592000.
JWT переживает перезапуск backend при том же секрете. После истечения — новый вход.
Refresh tokens и серверное отзывание отдельных сессий в ТЗ не предусмотрены;
logout на будущих этапах удаляет токен на клиенте. Ротация секрета инвалидирует все JWT.

Регистрация и вход ограничены 20 запросами за 60 секунд на IP и endpoint.
Счётчик хранится в памяти одного backend и сбрасывается при перезапуске.
Для нескольких экземпляров потребуется общее хранилище лимитов; текущий Compose
запускает один экземпляр. Proxy trust не включён: произвольный X-Forwarded-For
не используется для обхода лимита. Ошибка 429 содержит Retry-After.

## Миграция и запуск

`synchronize` и автоматическое `migrationsRun` остаются false. Миграция создаёт
таблицу users, ограничения и индекс. Docker выполняет команду миграции перед
HTTP-сервером, в транзакции; повторный запуск ничего не меняет. Существующий том
PostgreSQL сохраняется. `down` миграции удаляет таблицу и её данные, поэтому
автоматический rollback на рабочей БД не запускается.

Из корня после настройки `.env`:

```powershell
docker compose up --build -d --wait
```

Локально из `backend/`, с работающей PostgreSQL:

```powershell
npm ci
npm run build
npm run migration:run
npm start
```

Не запускайте сборку, очищающую dist, одновременно с миграциями/тестами из dist.

## Все созданные и изменённые файлы

Пути относительно `D:\EasyPark`.

Созданы:

| Файл | Назначение |
| --- | --- |
| `backend/src/users/user.entity.ts` | Сущность, роли и безопасное представление пользователя |
| `backend/src/users/users.module.ts` | Репозиторий пользователей и сервис |
| `backend/src/users/users.service.ts` | Создание, поиск и обработка конфликта email |
| `backend/src/users/users.controller.ts` | Защищённый профиль; зарегистрирован в AuthModule для доступа к guard |
| `backend/src/auth/auth.module.ts` | JWT, limiter и провайдеры авторизации |
| `backend/src/auth/auth.controller.ts` | Регистрация и вход |
| `backend/src/auth/auth.service.ts` | Проверка пароля и выдача сессии |
| `backend/src/auth/auth.dto.ts` | Нормализация и валидация запросов |
| `backend/src/auth/password.service.ts` | Scrypt и проверка хеша |
| `backend/src/auth/jwt-auth.guard.ts` | Проверка JWT и актуального пользователя |
| `backend/src/database/migrations/1789776000000-create-users.ts` | Версионированная схема users |
| `backend/src/database/migrate.ts` | Команда применения миграций без HTTP |
| `backend/test/password.test.cjs` | Пароли, случайная соль и повреждённые хеши |
| `backend/test/integration/auth.test.cjs` | HTTP, JWT, роли, конкуренция и миграция с PostgreSQL |
| `backend/test/docker-auth-smoke.cjs` | Регистрация и сохранение JWT/пользователя после перезапуска контейнера |
| `docs/stage-4.md` | Этот отчёт и API-контракт |

Изменены:

- `backend/src/app.module.ts` — подключён AuthModule.
- `backend/src/config/environment.ts` — JWT secret/TTL и проверка настроек.
- `backend/src/database/database.module.ts` — регистрация миграции.
- `backend/test/environment.test.cjs` — настройки JWT.
- `backend/package.json` — JWT 12.0.2, throttler 6.7.1, команды миграции и Docker smoke.
- `backend/package-lock.json` — закреплённые зависимости.
- `backend/Dockerfile` — миграция перед сервером.
- `docker-compose.yml` — переменные JWT в backend.
- `.env.example` — шаблон JWT-настроек.
- `.env` — локальный секрет и TTL, файл игнорируется системой контроля версий.
- `README.md` — статус этапа, запуск, миграции и API.

Производные изменения: `backend/dist/`, `backend/node_modules/`, Docker-образ
backend и таблицы users/migrations в существующем PostgreSQL-томе.
Защищённые папки исходников не менялись.

## Проверки

- `npm run format:check`, `npm run lint`, `npm run build`.
- `npm test`: 11 тестов.
- `npm run test:integration`: 10 проверок (8 сценариев Auth, их общий тест и прежняя проверка БД).
- Повторный `npm run migration:run`: 0 новых миграций.
- Соответствие схемы сущности проверено через schema diff — изменений нет.
- Up/down миграции проверены только в отдельной временной схеме.
- Интеграционные данные удаляются по точным случайным email; рабочие таблицы не очищаются.
- `docker compose up --build -d --wait backend cv-service` — успешная сборка и запуск.
- `npm run test:docker` — регистрация, перезапуск backend, прежний JWT и повторный вход прошли.
- Backend, PostgreSQL и CV-service healthy; оба `/health` отвечают успешно.
- SHA-256 всех 75 исходных файлов совпадает с baseline, добавлений в защищённых папках нет.

Набор проверяет успешную регистрацию/вход, нормализацию email, дубликаты и две
одновременные регистрации, неверный пароль, валидацию, запрет регистрации ADMIN,
отсутствующий/повреждённый/просроченный JWT, другой ключ/алгоритм/issuer/audience,
отсутствующий exp, некорректный sub, удалённого пользователя и лимит запросов.

Обнаруженные и устранённые проблемы проверки: Node test runner требовал разрешения
на дочерние процессы (EPERM); параллельная пересборка временно очищала dist во время
повторной миграции — проверки выполнены последовательно; тестовый JWT без exp
нужно создавать отдельным signer без опции expiresIn, а не с undefined.

Сохраняется прежнее предупреждение npm о deprecated транзитивном `glob@10.5.0`
из TypeORM; при установке и Docker-сборке npm audit сообщил 0 уязвимостей.
Принудительная подмена транзитивной major-версии не выполнялась. Неисправленных
ошибок текущего этапа по выполненным проверкам не обнаружено.

Источники: [NestJS JWT](https://docs.nestjs.com/security/authentication),
[Node.js scrypt](https://nodejs.org/api/crypto.html#cryptoscryptpassword-salt-keylen-options-callback),
[TypeORM migrations](https://typeorm.io/docs/advanced-topics/migrations/).
