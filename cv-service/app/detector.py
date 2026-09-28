"""Inference only: local YOLO detection weights, no training or file uploads."""

import io
import math
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, Field

from app.model_config import resolve_model_path
from app.vehicle_library import (
    DEFAULT_CONFIG,
    load_vehicle_classes,
    match_vehicle_classes,
)

MAX_PIXELS = 12_000_000


class InvalidImage(ValueError):
    pass


class ImageTooLarge(ValueError):
    pass


class BoundingBox(BaseModel):
    x1: float = Field(ge=0, allow_inf_nan=False)
    y1: float = Field(ge=0, allow_inf_nan=False)
    x2: float = Field(ge=0, allow_inf_nan=False)
    y2: float = Field(ge=0, allow_inf_nan=False)


class Vehicle(BaseModel):
    type: str
    confidence: float = Field(ge=0, le=1, allow_inf_nan=False)
    bbox: BoundingBox


class DetectionResponse(BaseModel):
    vehicles: list[Vehicle]


def decode_image(data: bytes) -> Image.Image:
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.format not in {"JPEG", "PNG"}:
                raise InvalidImage("Only JPEG and PNG are supported")
            if image.width * image.height > MAX_PIXELS:
                raise ImageTooLarge()
            image.load()
            return ImageOps.exif_transpose(image).convert("RGB")
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError) as error:
        if isinstance(error, (InvalidImage, ImageTooLarge)):
            raise
        raise InvalidImage("Invalid image") from error
    except Image.DecompressionBombError as error:
        raise ImageTooLarge() from error


class YoloDetector:
    def __init__(self, vehicle_config: Path = DEFAULT_CONFIG) -> None:
        import torch
        from ultralytics import YOLO

        weights = resolve_model_path()
        torch.set_num_threads(2)
        self.model = YOLO(str(weights), task="detect")
        if self.model.task != "detect":
            raise ValueError("MODEL_PATH must contain a detection model")
        self.vehicle_types = match_vehicle_classes(
            self.model.names, load_vehicle_classes(vehicle_config)
        )
        self.classes = list(self.vehicle_types)
        # Verify inference before reporting readiness. No training is performed.
        self._predict(Image.new("RGB", (64, 64)))

    def _predict(self, image: Image.Image):
        return self.model.predict(
            source=image,
            device="cpu",
            imgsz=640,
            conf=0.25,
            classes=self.classes or None,
            max_det=100,
            verbose=False,
            save=False,
        )[0]

    def detect(self, data: bytes) -> DetectionResponse:
        with decode_image(data) as image:
            # An empty intersection is valid. Never return unfiltered predictions.
            if not self.vehicle_types:
                return DetectionResponse(vehicles=[])
            result = self._predict(image)
            vehicles = []
            if result.boxes is None:
                return DetectionResponse(vehicles=[])
            boxes = result.boxes.xyxy.cpu().tolist()
            scores = result.boxes.conf.cpu().tolist()
            classes = result.boxes.cls.cpu().tolist()
            for box, score, class_id in zip(boxes, scores, classes, strict=True):
                name = self.vehicle_types.get(int(class_id))
                if name is None or not all(math.isfinite(v) for v in [*box, score]):
                    continue
                x1, y1, x2, y2 = box
                x1, x2 = [min(max(x, 0), image.width) for x in (x1, x2)]
                y1, y2 = [min(max(y, 0), image.height) for y in (y1, y2)]
                if x2 <= x1 or y2 <= y1 or not 0 <= score <= 1:
                    continue
                vehicles.append(
                    Vehicle(
                        type=name,
                        confidence=score,
                        bbox=BoundingBox(x1=x1, y1=y1, x2=x2, y2=y2),
                    )
                )
            return DetectionResponse(vehicles=vehicles)
