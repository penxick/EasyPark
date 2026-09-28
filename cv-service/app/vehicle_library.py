"""Configured vehicle names matched to model labels, without inferred subclasses."""

import json
from pathlib import Path

DEFAULT_CONFIG = Path(__file__).with_name("vehicle_classes.json")


def load_vehicle_classes(path: Path = DEFAULT_CONFIG) -> tuple[str, ...]:
    names = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(names, list) or any(
        not isinstance(name, str) or not name.strip() for name in names
    ):
        raise ValueError("Vehicle classes must be a list of non-empty strings")
    cleaned = tuple(name.strip() for name in names)
    if len({name.casefold() for name in cleaned}) != len(cleaned):
        raise ValueError("Vehicle classes must be unique")
    return cleaned


def match_vehicle_classes(
    names: dict[int, str], configured: tuple[str, ...]
) -> dict[int, str]:
    canonical = {name.casefold(): name for name in configured}
    return {
        class_id: canonical[label.strip().casefold()]
        for class_id, label in names.items()
        if label.strip().casefold() in canonical
    }
