import json

import pytest
from fastapi.testclient import TestClient
from ultralytics.utils import ASSETS

from app.detector import YoloDetector
from app.main import create_app
from app.vehicle_library import load_vehicle_classes, match_vehicle_classes


def test_default_library_matches_only_actual_model_labels():
    configured = load_vehicle_classes()
    assert len(configured) == 11
    assert "SUV" in configured
    assert match_vehicle_classes(
        {0: "person", 2: "car", 3: "motorcycle", 5: "bus", 7: "truck"}, configured
    ) == {2: "car", 3: "motorcycle", 5: "bus", 7: "truck"}


def test_model_ids_are_not_hardcoded_and_names_are_canonical():
    assert match_vehicle_classes(
        {8: "suv", 42: "VAN", 99: "person"}, ("SUV", "van")
    ) == {8: "SUV", 42: "van"}
    assert match_vehicle_classes({2: "car"}, ("SUV", "crossover")) == {}


@pytest.mark.parametrize("configured", [[], ["SUV", "scooter"]])
def test_no_supported_classes_keeps_service_ready(tmp_path, configured):
    config = tmp_path / "vehicles.json"
    config.write_text(json.dumps(configured), encoding="utf-8")
    with TestClient(create_app(lambda: YoloDetector(config))) as client:
        assert client.get("/health").status_code == 200
        response = client.post(
            "/detect",
            content=(ASSETS / "bus.jpg").read_bytes(),
            headers={"Content-Type": "image/jpeg"},
        )
        assert response.status_code == 200
        assert response.json() == {"vehicles": []}
        assert (
            client.post(
                "/detect", content=b"invalid", headers={"Content-Type": "image/jpeg"}
            ).status_code
            == 400
        )


@pytest.mark.parametrize("value", [{}, ["car", "CAR"], [" "], [1]])
def test_invalid_configuration_is_rejected(tmp_path, value):
    config = tmp_path / "vehicles.json"
    config.write_text(json.dumps(value), encoding="utf-8")
    with pytest.raises(ValueError):
        load_vehicle_classes(config)
