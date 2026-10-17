#Обучение YOLO11n Object Detection — модель, которая будет обнаруживать именно автомобили, а не просто определять наличие предметов на парковочном месте
from pathlib import Path

import torch
from ultralytics import YOLO

BASE = Path(__file__).resolve().parent

DATA = BASE / "detection_dataset" / "yolo" / "data.yaml"

if not DATA.exists():
    raise FileNotFoundError(
        f"Не найден data.yaml: {DATA}"
    )

if not torch.cuda.is_available():
    raise RuntimeError("CUDA недоступна!")

print("GPU:", torch.cuda.get_device_name(0))
print("Датасет:", DATA)

# YOLO11n для обнаружения объектов
model = YOLO("yolo26n.pt")

model.train(
    data=str(DATA),
    epochs=100,
    imgsz=640,
    batch=8,
    device=0,
    workers=0,
    patience=25,
    project=str(BASE / "runs"),
    name="easypark_yolo26_detection",
    exist_ok=True,
    plots=True
)

print("\nОбучение завершено!")

print(
    "Модель:",
    BASE / "runs" / "easypark_detection"
    / "weights" / "best.pt"
)
