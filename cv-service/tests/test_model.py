"""Integration check using the official image bundled with Ultralytics."""

from fastapi.testclient import TestClient
from ultralytics.utils import ASSETS

from app.main import create_app


def test_pretrained_cpu_model_detects_bus_over_http():
    with TestClient(create_app()) as client:
        assert client.get("/health").status_code == 200
        response = client.post(
            "/detect",
            content=(ASSETS / "bus.jpg").read_bytes(),
            headers={"Content-Type": "image/jpeg"},
        )
        assert response.status_code == 200
        vehicles = response.json()["vehicles"]
        assert any(vehicle["type"] == "bus" for vehicle in vehicles)
        for vehicle in vehicles:
            assert vehicle["type"] in {"car", "motorcycle", "bus", "truck"}
            assert 0.25 <= vehicle["confidence"] <= 1
            box = vehicle["bbox"]
            assert 0 <= box["x1"] < box["x2"] <= 810
            assert 0 <= box["y1"] < box["y2"] <= 1080
