
import cv2
import random
from pathlib import Path

BASE = Path(__file__).resolve().parent
IMAGES = BASE / "detection_dataset" / "raw"
LABELS = BASE / "detection_dataset" / "labels"

files = sorted(IMAGES.glob("*.jpg"))

if not files:
    raise RuntimeError("Фотографии не найдены")

random.seed(42)

# Проверяем 15 случайных фотографий
samples = random.sample(files, min(15, len(files)))

WINDOW = "EasyPark - Check Labels"

cv2.namedWindow(WINDOW, cv2.WINDOW_NORMAL)
cv2.resizeWindow(WINDOW, 1100, 800)

print("ENTER / SPACE - следующая фотография")
print("Q - выход")

for index, image_path in enumerate(samples, 1):
    image = cv2.imread(str(image_path))

    if image is None:
        continue

    height, width = image.shape[:2]

    label_path = LABELS / f"{image_path.stem}.txt"

    if not label_path.exists():
        print("Нет разметки:", image_path.name)
        continue

    lines = label_path.read_text(
        encoding="utf-8"
    ).splitlines()

    for line in lines:
        values = line.split()

        if len(values) != 5:
            print("Неверная строка:", line)
            continue

        class_id, xc, yc, bw, bh = map(float, values)

        x1 = int((xc - bw / 2) * width)
        y1 = int((yc - bh / 2) * height)
        x2 = int((xc + bw / 2) * width)
        y2 = int((yc + bh / 2) * height)

        cv2.rectangle(
            image,
            (x1, y1),
            (x2, y2),
            (0, 255, 0),
            3
        )

        cv2.putText(
            image,
            "CAR",
            (x1, max(20, y1 - 8)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (0, 255, 0),
            2
        )

    cv2.putText(
        image,
        f"IMAGE {index}/{len(samples)}",
        (20, height - 20),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.8,
        (0, 0, 255),
        2
    )

    cv2.imshow(WINDOW, image)

    while True:
        key = cv2.waitKey(0) & 0xFF

        if key in (13, 10, 32):
            break

        if key == ord("q"):
            cv2.destroyAllWindows()
            raise SystemExit

cv2.destroyAllWindows()

print("Проверка завершена")
