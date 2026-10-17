
import cv2
import time
import json
import numpy as np
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_DIR / "detection_dataset" / "raw"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

SCHEME_PATH = BASE_DIR / "parking_spaces.json"
CAMERA_INDEX = 2

with open(SCHEME_PATH, "r", encoding="utf-8") as f:
    scheme = json.load(f)

WIDTH = int(scheme["width"])
HEIGHT = int(scheme["height"])
SPACES = scheme["spaces"]

dictionary = cv2.aruco.getPredefinedDictionary(
    cv2.aruco.DICT_4X4_50
)
parameters = cv2.aruco.DetectorParameters()
detector = cv2.aruco.ArucoDetector(
    dictionary, parameters
)

clahe = cv2.createCLAHE(
    clipLimit=2.0,
    tileGridSize=(8, 8)
)


def get_transform(frame):
    gray = cv2.cvtColor(
        frame, cv2.COLOR_BGR2GRAY
    )

    found = {}

    for image in (gray, clahe.apply(gray)):
        corners, ids, _ = detector.detectMarkers(image)

        if ids is None:
            continue

        for corner, marker_id in zip(
            corners, ids.flatten()
        ):
            marker_id = int(marker_id)

            if marker_id in (0, 1, 2, 3):
                found[marker_id] = corner[0].mean(axis=0)

        if len(found) == 4:
            break

    if len(found) != 4:
        return None, len(found)

    src = np.float32([
        found[0],
        found[1],
        found[3],
        found[2]
    ])

    dst = np.float32([
        [0, 0],
        [WIDTH - 1, 0],
        [WIDTH - 1, HEIGHT - 1],
        [0, HEIGHT - 1]
    ])

    matrix = cv2.getPerspectiveTransform(src, dst)

    return matrix, 4


camera = cv2.VideoCapture(
    CAMERA_INDEX, cv2.CAP_MSMF
)

if not camera.isOpened():
    raise RuntimeError("Не удалось открыть USB-камеру")

cv2.namedWindow("EasyPark Detection Collector", cv2.WINDOW_NORMAL)
cv2.resizeWindow("EasyPark Detection Collector", 1000, 750)

saved = 0

print("\nEasyPark Detection Dataset")
print("SPACE - сохранить фотографию")
print("Q - выход\n")

try:
    while True:
        ok, frame = camera.read()

        if not ok:
            break

        matrix, count = get_transform(frame)

        if matrix is not None:
            warped = cv2.warpPerspective(
                frame, matrix, (WIDTH, HEIGHT)
            )

            preview = warped.copy()

            for space in SPACES:
                x1 = int(space["x1"])
                y1 = int(space["y1"])
                x2 = int(space["x2"])
                y2 = int(space["y2"])

                cv2.rectangle(
                    preview,
                    (x1, y1),
                    (x2, y2),
                    (0, 255, 0),
                    2
                )

                cv2.putText(
                    preview,
                    space["id"],
                    (x1 + 8, y1 + 28),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.65,
                    (0, 255, 0),
                    2
                )

            cv2.putText(
                preview,
                f"SAVED: {saved}",
                (15, HEIGHT - 15),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.8,
                (255, 255, 255),
                2
            )

            cv2.imshow(
                "EasyPark Detection Collector",
                preview
            )
        else:
            preview = frame.copy()

            cv2.putText(
                preview,
                f"MARKERS: {count}/4",
                (15, 35),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.9,
                (0, 0, 255),
                2
            )

            cv2.imshow(
                "EasyPark Detection Collector",
                preview
            )

        key = cv2.waitKey(1) & 0xFF

        if key == ord("q"):
            break

        if key == 32:
            if matrix is None:
                print("Нужны все 4 ArUco-маркера")
                continue

            filename = f"parking_{time.time_ns()}.jpg"
            path = OUTPUT_DIR / filename

            cv2.imwrite(str(path), warped)
            saved += 1

            print(f"Сохранено: {filename}")

finally:
    camera.release()
    cv2.destroyAllWindows()

print(f"\nВсего новых фотографий: {saved}")
