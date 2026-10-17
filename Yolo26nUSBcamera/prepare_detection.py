# Подготовка датасета для обучения YOLO Object Detection.
# Проверяет фотографии и разметку машинок, делит данные
# на обучающую (80%) и проверочную (20%) выборки.
# Создаёт структуру папок YOLO и файл data.yaml.
# Исходные фотографии и разметку не изменяет.

from pathlib import Path
import random
import shutil

BASE = Path(__file__).resolve().parent

SOURCE_IMAGES = BASE / "detection_dataset" / "raw"
SOURCE_LABELS = BASE / "detection_dataset" / "labels"

OUTPUT = BASE / "detection_dataset" / "yolo"

random.seed(42)

images = sorted(SOURCE_IMAGES.glob("*.jpg"))

if len(images) != 105:
    print(f"Внимание: найдено {len(images)} фотографий")

if not images:
    raise RuntimeError("Фотографии не найдены")

for image in images:
    label = SOURCE_LABELS / f"{image.stem}.txt"

    if not label.exists():
        raise RuntimeError(
            f"Нет разметки для {image.name}"
        )

# Перемешиваем фотографии
random.shuffle(images)

# 80% обучение, 20% проверка
split_index = int(len(images) * 0.8)

train_images = images[:split_index]
val_images = images[split_index:]

# Пересоздаём только подготовленный датасет.
# Исходные фотографии и разметку не трогаем.
if OUTPUT.exists():
    shutil.rmtree(OUTPUT)

for split, files in (
    ("train", train_images),
    ("val", val_images)
):
    image_dir = OUTPUT / "images" / split
    label_dir = OUTPUT / "labels" / split

    image_dir.mkdir(parents=True, exist_ok=True)
    label_dir.mkdir(parents=True, exist_ok=True)

    for image in files:
        label = SOURCE_LABELS / f"{image.stem}.txt"

        shutil.copy2(
            image,
            image_dir / image.name
        )

        shutil.copy2(
            label,
            label_dir / label.name
        )

    print(f"{split}: {len(files)} фотографий")

# Создаём конфигурацию YOLO
yaml_path = OUTPUT / "data.yaml"

yaml_content = (
    f"path: '{OUTPUT.as_posix()}'\n"
    "train: images/train\n"
    "val: images/val\n"
    "nc: 1\n"
    "names:\n"
    "  0: car\n"
)

yaml_path.write_text(
    yaml_content,
    encoding="utf-8"
)

print("\nДатасет готов!")
print("Конфигурация:", yaml_path)
