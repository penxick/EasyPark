
import cv2
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

IMAGE_DIR = BASE_DIR / "detection_dataset" / "raw"
LABEL_DIR = BASE_DIR / "detection_dataset" / "labels"

LABEL_DIR.mkdir(parents=True, exist_ok=True)

WINDOW = "EasyPark - Car Labeling"

images = sorted(IMAGE_DIR.glob("*.jpg"))

if not images:
    raise RuntimeError(
        f"Фотографии не найдены: {IMAGE_DIR}"
    )

cv2.namedWindow(WINDOW, cv2.WINDOW_NORMAL)
cv2.resizeWindow(WINDOW, 1100, 800)

current_image = None
boxes = []
drawing = False
start_point = None
mouse_point = None


def mouse_callback(event, x, y, flags, userdata):
    global drawing, start_point, mouse_point

    if current_image is None:
        return

    height, width = current_image.shape[:2]

    x = max(0, min(x, width - 1))
    y = max(0, min(y, height - 1))

    if event == cv2.EVENT_LBUTTONDOWN:
        drawing = True
        start_point = (x, y)
        mouse_point = (x, y)

    elif event == cv2.EVENT_MOUSEMOVE and drawing:
        mouse_point = (x, y)

    elif event == cv2.EVENT_LBUTTONUP and drawing:
        drawing = False

        x1 = min(start_point[0], x)
        y1 = min(start_point[1], y)
        x2 = max(start_point[0], x)
        y2 = max(start_point[1], y)

        if x2 - x1 >= 5 and y2 - y1 >= 5:
            boxes.append((x1, y1, x2, y2))

        start_point = None
        mouse_point = None


cv2.setMouseCallback(WINDOW, mouse_callback)


def save_labels(image_path, rectangles):
    height, width = current_image.shape[:2]

    label_path = LABEL_DIR / (
        image_path.stem + ".txt"
    )

    lines = []

    for x1, y1, x2, y2 in rectangles:
        center_x = (x1 + x2) / 2 / width
        center_y = (y1 + y2) / 2 / height

        box_width = (x2 - x1) / width
        box_height = (y2 - y1) / height

        # 0 = car
        lines.append(
            f"0 {center_x:.6f} {center_y:.6f} "
            f"{box_width:.6f} {box_height:.6f}"
        )

    label_path.write_text(
        "\n".join(lines),
        encoding="utf-8"
    )


print("\nEasyPark — разметка машинок")
print("Выделяй автомобили мышкой.")
print("ENTER — сохранить и перейти дальше")
print("Z — отменить последний прямоугольник")
print("R — очистить разметку кадра")
print("Q — выйти (прогресс сохраняется)")
print("Пустой кадр: ENTER без прямоугольников\n")

try:
    for index, image_path in enumerate(images):
        label_path = LABEL_DIR / (
            image_path.stem + ".txt"
        )

        if label_path.exists():
            print(
                f"Пропускаем размеченный кадр: "
                f"{image_path.name}"
            )
            continue

        current_image = cv2.imread(str(image_path))

        if current_image is None:
            print(f"Ошибка чтения: {image_path}")
            continue

        boxes = []
        drawing = False
        start_point = None
        mouse_point = None

        while True:
            preview = current_image.copy()

            for x1, y1, x2, y2 in boxes:
                cv2.rectangle(
                    preview,
                    (x1, y1),
                    (x2, y2),
                    (0, 255, 0),
                    2
                )

            if drawing and start_point and mouse_point:
                cv2.rectangle(
                    preview,
                    start_point,
                    mouse_point,
                    (0, 255, 255),
                    2
                )

            cv2.putText(
                preview,
                f"IMAGE {index + 1}/{len(images)} | CARS: {len(boxes)}",
                (15, 35),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.75,
                (0, 0, 255),
                2
            )

            cv2.imshow(WINDOW, preview)

            key = cv2.waitKey(20) & 0xFF

            if key in (13, 10):
                save_labels(image_path, boxes)

                print(
                    f"[{index + 1}/{len(images)}] "
                    f"Сохранено машинок: {len(boxes)}"
                )
                break

            elif key == ord("z"):
                if boxes:
                    boxes.pop()

            elif key == ord("r"):
                boxes.clear()

            elif key == ord("q"):
                print("Разметка остановлена.")
                raise KeyboardInterrupt

except KeyboardInterrupt:
    pass

finally:
    cv2.destroyAllWindows()

print("\nГотово. Разметка сохранена в:")
print(LABEL_DIR)
