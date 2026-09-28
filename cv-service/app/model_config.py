"""Resolve local inference weights; never download a user-selected model."""

import os
from pathlib import Path

SERVICE_ROOT = Path(__file__).resolve().parent.parent


def resolve_model_path() -> Path:
    configured = os.environ.get("MODEL_PATH", "weights/yolo11n.pt").strip()
    if not configured or "://" in configured:
        raise ValueError("MODEL_PATH must identify a local .pt file")
    path = Path(configured)
    if not path.is_absolute():
        path = SERVICE_ROOT / path
    path = path.resolve()
    if path.suffix.lower() != ".pt" or not path.is_file():
        raise ValueError("MODEL_PATH must identify an existing .pt file")
    return path
