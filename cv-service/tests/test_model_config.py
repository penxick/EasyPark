import shutil

import pytest
from fastapi.testclient import TestClient
from ultralytics.utils import ASSETS

from app.main import create_app
from app.model_config import SERVICE_ROOT, resolve_model_path


def test_default_model_path(monkeypatch):
    monkeypatch.delenv("MODEL_PATH", raising=False)
    assert resolve_model_path() == SERVICE_ROOT / "weights" / "yolo11n.pt"


@pytest.mark.parametrize("value", ["", "https://example.com/model.pt", "missing.pt"])
def test_invalid_path_keeps_api_alive_but_unavailable(monkeypatch, value):
    monkeypatch.setenv("MODEL_PATH", value)
    with TestClient(create_app()) as client:
        assert client.get("/health").status_code == 503
        assert client.post("/detect").status_code == 503


def test_corrupt_weights_do_not_fall_back(monkeypatch, tmp_path):
    weights = tmp_path / "broken.pt"
    weights.write_bytes(b"invalid weights")
    monkeypatch.setenv("MODEL_PATH", str(weights))
    with TestClient(create_app()) as client:
        assert client.get("/health").status_code == 503


def test_alternate_weights_path_runs_real_inference(monkeypatch, tmp_path):
    weights = tmp_path / "best.pt"
    shutil.copyfile(SERVICE_ROOT / "weights" / "yolo11n.pt", weights)
    monkeypatch.setenv("MODEL_PATH", str(weights))
    with TestClient(create_app()) as client:
        assert client.get("/health").status_code == 200
        response = client.post(
            "/detect",
            content=(ASSETS / "bus.jpg").read_bytes(),
            headers={"Content-Type": "image/jpeg"},
        )
        assert response.status_code == 200
        assert any(v["type"] == "bus" for v in response.json()["vehicles"])
