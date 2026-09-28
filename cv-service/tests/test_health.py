from fastapi.testclient import TestClient

from app.main import create_app


def test_health() -> None:
    with TestClient(create_app(lambda: object())) as client:
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok", "service": "easypark-cv"}


def test_failed_model_is_not_reported_healthy() -> None:
    def fail():
        raise RuntimeError("private model path")

    with TestClient(create_app(fail)) as client:
        assert client.get("/health").status_code == 503
        response = client.post(
            "/detect", content=b"x", headers={"Content-Type": "image/png"}
        )
        assert response.status_code == 503
        assert "private" not in response.text
