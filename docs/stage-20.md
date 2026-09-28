# Этап 20 — Тестирование

Выполнены проверки Auth, Parking, Reservation и CV из ТЗ. Ошибок приложения
по выполненным проверкам не обнаружено. Этап 21 не начат.

## Матрица требований и результатов

| Область | Проверка | Результат |
| --- | --- | --- |
| Auth | Регистрация, логин | Backend integration и Docker smoke прошли |
| Auth | Неверный пароль, существующий email | Корректные отказы; конкурентная регистрация создаёт одного пользователя |
| Auth | Отсутствующий JWT | Защищённые endpoints отказывают; также проверены поддельный и истёкший JWT |
| Auth | Logout | Flutter unit/widget и Android API 36: токен удалён, профиль закрыт, новая сессия не восстанавливается; повторный вход работает |
| Parking | Список, одна парковка, схема мест | Integration и Docker HTTP прошли; доступны три демопарковки и 60 мест |
| Reservation | Свободное место | Бронь создаётся; проверены длительности, серверная цена и время |
| Reservation | Занятое и забронированное место | Отказ 409; также проверены physicalOccupied и UNAVAILABLE |
| Reservation | Отмена | Освобождение места, идемпотентность, права владельца, сохранение физических/административных ограничений |
| Reservation | Два пользователя одновременно | Восемь конкурентных запросов от двух пользователей: одна успешная бронь и семь конфликтов, корректный счётчик |
| CV | Изображение с машиной | На контрольном PNG распознаны car |
| CV | Несколько транспортных средств | На том же изображении получены пять car и один truck |
| CV | Изображение без машины | Белый PNG 640 × 480 возвращает пустой vehicles |
| CV | Некорректный файл | Бинарная строка вместо изображения возвращает HTTP 400 |

Дополнительно проверены миграции в изолированных схемах, ограничения PostgreSQL,
фоновое завершение бронирования в Docker, сохранение JWT после перезапуска backend,
ошибки secure storage, неподдерживаемые классы модели и MODEL_PATH.

## Выполненные команды

Backend (из backend):

```powershell
npm run format:check
npm run lint
npm run build
node --test test/*.test.cjs test/integration/*.test.cjs
node test/docker-parking-smoke.cjs
node test/docker-reservation-smoke.cjs
node test/docker-auth-smoke.cjs
```

Все проверки успешны, **38 тестов**, пропусков нет. Тесты использовали собственные
временные записи и удалили их; общие таблицы не очищались.

Flutter (из mobile):

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test/profile_flow_test.dart -d emulator-5554 --dart-define=TEST_EMAIL=<уникальный-stage15-email> --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

69 файлов уже отформатированы, анализатор без замечаний, **78 тестов** прошли.
Android integration: **1 тест прошёл**, настоящий backend и secure storage.
Временный аккаунт удалён по точному email из артефакта текущего запуска;
эмулятор остановлен. APK в build — инструментальная тестовая сборка, не финальная
сборка этапа 21. iOS на Windows не проверялся.

CV:

```powershell
docker run --rm easypark-cv-test
docker run --rm easypark-cv-test ruff check app tests tools
docker run --rm easypark-cv-test ruff format --check app tests tools
```

**30 тестов прошли**, Ruff и форматирование успешны. Новый smoke_cv.py отдельно
проверен Ruff и выполнен внутри работающего CV-контейнера против HTTP /detect.
Для повторения передайте PNG с несколькими автомобилями:

```powershell
docker compose cp cv-service/tools/smoke_cv.py cv-service:/tmp/stage20-smoke.py
docker compose cp .artifacts/stage-20-cars.png cv-service:/tmp/stage20-cars.png
docker compose exec -T cv-service python /tmp/stage20-smoke.py /tmp/stage20-cars.png
```

Контрольный пример взят из [OpenCV extra, cars.png](https://github.com/opencv/opencv_extra/blob/4.x/testdata/cv/dpm/cars.png).
SHA-256: `8B158F6BFE5AD0D18698830B7CA679BE5315550B5798AFEC135F15597BD16421`.
Это один пример для функциональной проверки, не собранный обучающий датасет.
Обучение не выполнялось. Эти проверки не измеряют точность на реальных парковках;
отрицательный пример здесь синтетический.

## Созданные файлы

- `cv-service/tools/smoke_cv.py` — воспроизводимая HTTP-проверка четырёх CV-сценариев.
- `docs/stage-20.md` — матрица проверок и отчёт.
- `.artifacts/stage-20-cars.png` — контрольный пример OpenCV.
- `.artifacts/stage-20-test-email.txt` — идентификатор временного Android-аккаунта.
- `.artifacts/stage-20-cleanup.cjs` — удаление только этого аккаунта с проверкой формата идентификатора.
- `.artifacts/stage-20-emulator.log` и `.artifacts/stage-20-emulator-error.log` — журналы эмулятора.

## Изменённые файлы

- `README.md` — статус этапа и ссылка на отчёт.
- Генерируемые `backend/dist/`, Flutter/Gradle build/cache и тестовый
  `mobile/build/app/outputs/flutter-apk/app-debug.apk` обновлены проверками.

Рабочий код приложения и зависимости не изменялись. Все 75 защищённых файлов ТЗ
и Figma сверены по SHA-256 и не изменены. Сохраняется прежнее предупреждение
Starlette TestClient о deprecated-интеграции с httpx; оно не мешает тестам.
Неисправленных ошибок по выполненным проверкам нет. Работа остановлена на этапе 20.
