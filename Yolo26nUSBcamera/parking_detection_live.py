
# ============================================================
# EasyPark — обнаружение игрушечных автомобилей в реальном времени
#
# 1. Получает изображение с USB-камеры.
# 2. Находит четыре ArUco-маркера.
# 3. Выравнивает парковку по перспективе.
# 4. Обнаруживает автомобили с помощью YOLO11n Detection.
# 5. Сопоставляет найденные автомобили с местами P1–P8.
# 6. Отображает занятые и свободные места.
#
# Q — выход
# ============================================================

import cv2
import json
import time
import numpy as np

from pathlib import Path
from collections import deque
from ultralytics import YOLO


# ============================================================
# 1. НАСТРОЙКИ
# ============================================================

BASE_DIR = Path(__file__).resolve().parent

# Обученная YOLO26n для обнаружения игрушечных автомобилей
MODEL_PATH = (
    BASE_DIR
    / "runs"
    / "easypark_yolo26_detection"
    / "weights"
    / "best.pt"
)

SCHEME_PATH = BASE_DIR / "parking_spaces.json"

CAMERA_INDEX = 1

# Минимальная уверенность YOLO при обнаружении автомобиля
CONFIDENCE_THRESHOLD = 0.45

# Минимальная доля площади прямоугольника автомобиля,
# которая должна находиться внутри парковочного места
MIN_OVERLAP = 0.35

# Интервал между запусками YOLO (секунды)
INFERENCE_INTERVAL = 0.15

# Количество последних измерений для сглаживания
SMOOTHING_FRAMES = 5

WINDOW_CAMERA = "EasyPark - Camera"
WINDOW_PARKING = "EasyPark - Car Detection"


# ============================================================
# 2. ЗАГРУЗКА СХЕМЫ ПАРКОВКИ
# ============================================================

if not SCHEME_PATH.exists():
    raise FileNotFoundError(
        f"Не найдена схема парковки: {SCHEME_PATH}"
    )

with open(SCHEME_PATH, "r", encoding="utf-8") as file:
    scheme = json.load(file)

WIDTH = int(scheme["width"])
HEIGHT = int(scheme["height"])

spaces = scheme["spaces"]

if len(spaces) != 8:
    raise RuntimeError(
        f"Ожидалось 8 парковочных мест, найдено {len(spaces)}"
    )


# ============================================================
# 3. ЗАГРУЗКА ОБУЧЕННОЙ YOLO DETECTION
# ============================================================

if not MODEL_PATH.exists():
    raise FileNotFoundError(
        f"Не найдена обученная модель: {MODEL_PATH}"
    )

print("Загружаем YOLO Object Detection...")

model = YOLO(str(MODEL_PATH))

print("Классы модели:", model.names)

if set(model.names.values()) != {"car"}:
    raise RuntimeError(
        "Ожидалась модель обнаружения автомобилей "
        f"с классом car. Получено: {model.names}"
    )


# ============================================================
# 4. НАСТРОЙКА ARUCO
# ============================================================

dictionary = cv2.aruco.getPredefinedDictionary(
    cv2.aruco.DICT_4X4_50
)

parameters = cv2.aruco.DetectorParameters()

detector = cv2.aruco.ArucoDetector(
    dictionary,
    parameters
)

clahe = cv2.createCLAHE(
    clipLimit=2.0,
    tileGridSize=(8, 8)
)


def detect_markers(frame):
    """Находит маркеры ArUco с ID 0, 1, 2 и 3."""

    gray = cv2.cvtColor(
        frame,
        cv2.COLOR_BGR2GRAY
    )

    enhanced = clahe.apply(gray)

    found = {}

    for image in (gray, enhanced):
        corners, ids, _ = detector.detectMarkers(image)

        if ids is None:
            continue

        for corner, marker_id in zip(
            corners,
            ids.flatten()
        ):
            marker_id = int(marker_id)

            if marker_id in (0, 1, 2, 3):
                if marker_id not in found:
                    found[marker_id] = corner

        if len(found) == 4:
            break

    return found


def calculate_transform(found):
    """Вычисляет перспективное преобразование парковки."""

    if len(found) != 4:
        return None

    centers = {
        marker_id: corner[0].mean(axis=0)
        for marker_id, corner in found.items()
    }

    source_points = np.float32([
        centers[0],
        centers[1],
        centers[3],
        centers[2]
    ])

    destination_points = np.float32([
        [0, 0],
        [WIDTH - 1, 0],
        [WIDTH - 1, HEIGHT - 1],
        [0, HEIGHT - 1]
    ])

    return cv2.getPerspectiveTransform(
        source_points,
        destination_points
    )


# ============================================================
# 5. ОПРЕДЕЛЕНИЕ ПЕРЕСЕЧЕНИЯ МАШИНКИ С МЕСТОМ
# ============================================================

def calculate_overlap(car_box, space):
    """
    Возвращает долю площади bounding box автомобиля,
    находящуюся внутри парковочного места.
    """

    cx1, cy1, cx2, cy2 = car_box

    sx1 = int(space["x1"])
    sy1 = int(space["y1"])
    sx2 = int(space["x2"])
    sy2 = int(space["y2"])

    intersection_x1 = max(cx1, sx1)
    intersection_y1 = max(cy1, sy1)

    intersection_x2 = min(cx2, sx2)
    intersection_y2 = min(cy2, sy2)

    intersection_width = max(
        0,
        intersection_x2 - intersection_x1
    )

    intersection_height = max(
        0,
        intersection_y2 - intersection_y1
    )

    intersection_area = (
        intersection_width * intersection_height
    )

    car_area = max(
        1,
        (cx2 - cx1) * (cy2 - cy1)
    )

    return intersection_area / car_area


# ============================================================
# 6. ХРАНЕНИЕ СОСТОЯНИЙ ПАРКОВОЧНЫХ МЕСТ
# ============================================================

history = {
    space["id"]: deque(maxlen=SMOOTHING_FRAMES)
    for space in spaces
}

statuses = {
    space["id"]: False
    for space in spaces
}

detections = []


def update_detection(warped):
    """
    Запускает YOLO и обновляет занятость парковочных мест.
    """

    global detections

    results = model.predict(
        source=warped,
        imgsz=640,
        conf=CONFIDENCE_THRESHOLD,
        device=0,
        verbose=False
    )

    current_detections = []

    current_occupied = {
        space["id"]: False
        for space in spaces
    }

    if results and results[0].boxes is not None:
        boxes = results[0].boxes

        for box in boxes:
            class_id = int(box.cls[0])

            if model.names[class_id] != "car":
                continue

            confidence = float(box.conf[0])

            x1, y1, x2, y2 = (
                box.xyxy[0]
                .cpu()
                .numpy()
                .astype(int)
            )

            car_box = (
                int(x1),
                int(y1),
                int(x2),
                int(y2)
            )

            best_space = None
            best_overlap = 0.0

            for space in spaces:
                overlap = calculate_overlap(
                    car_box,
                    space
                )

                if overlap > best_overlap:
                    best_overlap = overlap
                    best_space = space["id"]

            assigned_space = None

            if (
                best_space is not None
                and best_overlap >= MIN_OVERLAP
            ):
                current_occupied[best_space] = True
                assigned_space = best_space

            current_detections.append({
                "box": car_box,
                "confidence": confidence,
                "space": assigned_space
            })

    detections = current_detections

    # Сглаживаем результаты, чтобы места не мигали
    for space in spaces:
        space_id = space["id"]

        history[space_id].append(
            current_occupied[space_id]
        )

        votes = sum(history[space_id])

        statuses[space_id] = (
            votes > len(history[space_id]) / 2
        )


# ============================================================
# 7. ОТОБРАЖЕНИЕ РЕЗУЛЬТАТОВ
# ============================================================

def draw_results(image):
    """Рисует места и прямоугольники автомобилей."""

    # Сначала рисуем парковочные места
    for space in spaces:
        space_id = space["id"]

        x1 = int(space["x1"])
        y1 = int(space["y1"])
        x2 = int(space["x2"])
        y2 = int(space["y2"])

        occupied = statuses[space_id]

        if occupied:
            color = (0, 0, 255)
            label = "BUSY"
        else:
            color = (0, 255, 0)
            label = "FREE"

        cv2.rectangle(
            image,
            (x1, y1),
            (x2, y2),
            color,
            3
        )

        cv2.putText(
            image,
            f"{space_id}: {label}",
            (x1 + 8, y1 + 28),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.65,
            color,
            2
        )

    # Затем рисуем bounding boxes найденных автомобилей
    for detection in detections:
        x1, y1, x2, y2 = detection["box"]

        confidence = detection["confidence"]
        space_id = detection["space"]

        # Голубой прямоугольник — найденная машинка
        cv2.rectangle(
            image,
            (x1, y1),
            (x2, y2),
            (255, 255, 0),
            2
        )

        label = f"CAR {confidence:.0%}"

        if space_id is not None:
            label += f" -> {space_id}"

        cv2.putText(
            image,
            label,
            (x1, max(18, y1 - 8)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.55,
            (255, 255, 0),
            2
        )

    free_count = sum(
        not occupied
        for occupied in statuses.values()
    )

    busy_count = sum(statuses.values())

    cv2.putText(
        image,
        f"FREE: {free_count}  BUSY: {busy_count}",
        (15, HEIGHT - 15),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (255, 255, 255),
        2
    )


# ============================================================
# 8. ПОДКЛЮЧЕНИЕ USB-КАМЕРЫ
# ============================================================

camera = cv2.VideoCapture(
    CAMERA_INDEX,
    cv2.CAP_MSMF
)

if not camera.isOpened():
    raise RuntimeError(
        "Не удалось открыть USB-камеру"
    )

cv2.namedWindow(
    WINDOW_CAMERA,
    cv2.WINDOW_NORMAL
)

cv2.namedWindow(
    WINDOW_PARKING,
    cv2.WINDOW_NORMAL
)

cv2.resizeWindow(
    WINDOW_CAMERA,
    800,
    600
)

cv2.resizeWindow(
    WINDOW_PARKING,
    1000,
    750
)

last_inference = 0.0

print("\nEasyPark YOLO Object Detection запущена")
print("Q — выход\n")


# ============================================================
# 9. ОСНОВНОЙ ЦИКЛ
# ============================================================

try:
    while True:
        success, frame = camera.read()

        if not success:
            print("Ошибка получения кадра с камеры")
            break

        camera_preview = frame.copy()

        found = detect_markers(frame)

        if found:
            marker_corners = list(found.values())

            marker_ids = np.array(
                list(found.keys()),
                dtype=np.int32
            ).reshape(-1, 1)

            cv2.aruco.drawDetectedMarkers(
                camera_preview,
                marker_corners,
                marker_ids
            )

        cv2.putText(
            camera_preview,
            f"MARKERS: {len(found)}/4",
            (15, 35),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (0, 255, 0) if len(found) == 4
            else (0, 0, 255),
            2
        )

        matrix = calculate_transform(found)

        if matrix is not None:
            warped = cv2.warpPerspective(
                frame,
                matrix,
                (WIDTH, HEIGHT)
            )

            current_time = time.monotonic()

            if (
                current_time - last_inference
                >= INFERENCE_INTERVAL
            ):
                update_detection(warped)
                last_inference = current_time

            parking_preview = warped.copy()

            draw_results(parking_preview)

            cv2.imshow(
                WINDOW_PARKING,
                parking_preview
            )

        cv2.imshow(
            WINDOW_CAMERA,
            camera_preview
        )

        key = cv2.waitKey(1) & 0xFF

        if key == ord("q"):
            break

finally:
    camera.release()
    cv2.destroyAllWindows()

print("EasyPark YOLO остановлена")
