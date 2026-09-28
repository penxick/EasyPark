# Этап 16 — CV-service Base

Реализован FastAPI-сервис с готовой предобученной YOLO11n для детекции транспорта.
Обучение не выполнялось. Этап 17 и последующие этапы не начаты.

## Реализация

- `GET /health` возвращает 200 после загрузки и прогрева модели; при ошибке загрузки — 503.
- `POST /detect` принимает JPEG/PNG непосредственно в теле запроса с соответствующим Content-Type.
- Ответ содержит `vehicles`: тип, confidence и bbox с координатами x1/y1/x2/y2 в пикселях изображения после применения EXIF-ориентации.
- Из COCO возвращаются car, motorcycle, bus и truck. Люди и остальные классы исключаются. Внешняя настройка классов оставлена следующему этапу.
- CPU inference: размер 640, порог confidence 0.25, максимум 100 детекций. Координаты ограничиваются размером изображения; некорректные результаты исключаются.
- Ограничения: 5 МиБ тела, 12 миллионов пикселей, 10 секунд чтения тела. Повреждённое или пустое изображение — 400, превышение размера — 413, неподдерживаемый Content-Type — 415, таймаут чтения — 408.
- Один запрос детекции одновременно; при занятости — 429 с Retry-After: 1. Inference выполняется вне event loop, health остаётся доступным.
- Ошибка модели возвращает безопасный 503 без внутренних путей. Входные изображения не сохраняются.

Модель загружается при сборке Docker из фиксированного официального релиза,
проверяется по SHA-256 и включается в образ. Во время работы сервис не скачивает
модель и не принимает пользовательские пути или URL моделей.

Использованы Python 3.11, Ultralytics 8.3.236, PyTorch 2.8.0+cpu и torchvision
0.23.0+cpu. Версии runtime и тестовых зависимостей зафиксированы. Проверенная
среда — Linux Docker; установленный на хосте Python 3.14 для inference не проверялся.

SHA-256 весов `yolo11n.pt`:
`0ebbc80d4a7680d14987a577cd21342b65ecfd94632bd9a8da63ae6417644ee1`.

## Созданные файлы

- `cv-service/download_model.py` — загрузка фиксированных весов с проверкой размера и хеша.
- `cv-service/app/detector.py` — декодирование изображений, модель, фильтрация транспорта и схема ответа.
- `cv-service/tests/test_detect.py` — контракт API, ограничения, ошибки и обработка результатов.
- `cv-service/tests/test_model.py` — интеграционная проверка настоящей модели.
- `cv-service/Dockerfile.test` — тестовый образ поверх runtime-образа.
- `cv-service/Dockerfile.test.dockerignore` — контекст сборки с тестами без локальных окружений и весов.
- `cv-service/README.md` — запуск, контракт, ограничения и сведения о модели.
- `docs/stage-16.md` — этот отчёт.
- `.artifacts/stage-16-yolo11n.pt` — локальная проверочная копия официальных весов; служебный артефакт, не исходный код.

## Изменённые файлы

- `cv-service/app/main.py` — lifespan модели, readiness и POST /detect.
- `cv-service/tests/test_health.py` — проверки готовности и отказа загрузки модели.
- `cv-service/Dockerfile` — CPU-зависимости, веса и запуск от непривилегированного пользователя.
- `cv-service/.dockerignore` — исключение локальных весов и тестового Dockerfile из runtime-контекста.
- `cv-service/requirements.in` — зависимости детектора.
- `cv-service/requirements.txt` — зафиксированные runtime-зависимости Python 3.11/Linux CPU.
- `cv-service/requirements-dev.txt` — зафиксированные зависимости проверок.
- `docker-compose.yml` — время ожидания первоначальной готовности CV увеличено до 60 секунд.
- `.gitignore` — исключение локального каталога весов.
- `README.md` — актуальные состояние проекта и инструкции запуска CV.

Исходники mobile и backend не изменялись. Защищённые материалы ТЗ и Figma
проверены по исходному списку SHA-256: все 75 файлов без изменений.

## Проверки и запуск

1. Runtime-образ собран, `docker compose up -d --build cv-service` выполнен успешно.
2. Итоговый тестовый образ собран через `docker build -f Dockerfile.test -t easypark-cv-test .` из cv-service.
3. `docker run --rm easypark-cv-test`: **12 passed**, включая реальный inference.
4. `docker run --rm easypark-cv-test ruff check app tests download_model.py`: **All checks passed**. Локальная проверка форматирования семи Python-файлов также прошла.
5. `docker compose exec -T cv-service python -m pip check`: **No broken requirements found**.
6. Через опубликованный порт `http://127.0.0.1:8000/health` получен ответ `{"status":"ok","service":"easypark-cv"}`.
7. Через HTTP работающего Uvicorn выполнен POST /detect с комплектным изображением Ultralytics bus.jpg (810 × 1080). Получен автобус с confidence 0.94015 и bbox приблизительно [3.83, 229.36, 796.19, 728.41]; люди не включены в ответ.
8. Контейнеры CV, backend и PostgreSQL имеют статус healthy.

Контрольное изображение проверяет работоспособность интеграции, а не точность
модели на парковках. Датасеты не создавались и обучение не запускалось.

Неисправленных ошибок текущего этапа не обнаружено. В тестах остаётся одно
предупреждение стороннего Starlette TestClient об устаревании интеграции с httpx;
оно не мешает выполнению 12 тестов и не относится к runtime inference.

## Источники модели

- [Документация YOLO11](https://docs.ultralytics.com/models/yolo11/).
- [Параметры predict](https://docs.ultralytics.com/modes/predict/).
- [Официальные веса фиксированного релиза](https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.pt).
- [Версии PyTorch и CPU wheels](https://pytorch.org/get-started/previous-versions/).
- [Лицензия Ultralytics](https://github.com/ultralytics/ultralytics/blob/main/LICENSE).

Пользовательский инструмент тестирования изображений, внешняя настройка классов,
подключение custom best.pt через MODEL_PATH и интеграции следующих этапов здесь
не реализованы. Работа остановлена на завершённом этапе 16.
