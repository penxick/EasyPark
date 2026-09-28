import io
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.detector import DetectionResponse, InvalidImage, YoloDetector, decode_image
from app.main import MAX_BYTES, create_app


def image_bytes(fmt="PNG", size=(32, 24)):
    buffer = io.BytesIO()
    Image.new("RGB", size, "white").save(buffer, format=fmt)
    return buffer.getvalue()


class Detector:
    def detect(self, data):
        with decode_image(data):
            return DetectionResponse(vehicles=[])


@pytest.mark.parametrize(
    "fmt,media_type", [("PNG", "image/png"), ("JPEG", "image/jpeg")]
)
def test_valid_image_empty_result(fmt, media_type):
    with TestClient(create_app(Detector)) as client:
        response = client.post(
            "/detect", content=image_bytes(fmt), headers={"Content-Type": media_type}
        )
        assert response.status_code == 200
        assert response.json() == {"vehicles": []}


@pytest.mark.parametrize(
    "payload,status",
    [(b"", 400), (b"not an image", 400), (b"x" * (MAX_BYTES + 1), 413)],
)
def test_invalid_payload(payload, status):
    with TestClient(create_app(Detector)) as client:
        response = client.post(
            "/detect", content=payload, headers={"Content-Type": "image/png"}
        )
        assert response.status_code == status


def test_format_size_and_busy_rejections():
    app = create_app(Detector)
    with TestClient(app) as client:
        assert (
            client.post("/detect", json={"url": "http://localhost"}).status_code == 415
        )
        response = client.post(
            "/detect",
            content=image_bytes(size=(4000, 3001)),
            headers={"Content-Type": "image/png"},
        )
        assert response.status_code == 413
        assert app.state.gate.acquire(False)
        try:
            response = client.post(
                "/detect", content=image_bytes(), headers={"Content-Type": "image/png"}
            )
            assert response.status_code == 429
            assert response.headers["Retry-After"] == "1"
            assert client.get("/health").status_code == 200
        finally:
            app.state.gate.release()


def test_inference_failure_is_safe_and_releases_gate():
    class Broken:
        def detect(self, data):
            raise RuntimeError("secret/path/weights")

    with TestClient(create_app(Broken)) as client:
        for _ in range(2):
            response = client.post(
                "/detect", content=image_bytes(), headers={"Content-Type": "image/png"}
            )
            assert response.status_code == 503
            assert "secret" not in response.text


def test_decoder_rejects_other_formats_and_truncated_images():
    for data in [image_bytes("GIF"), image_bytes("JPEG")[:40]]:
        with pytest.raises(InvalidImage):
            decode_image(data)


def test_detection_maps_vehicle_classes_and_clips_boxes():
    class Tensor:
        def __init__(self, values):
            self.values = values

        def cpu(self):
            return self

        def tolist(self):
            return self.values

    result = SimpleNamespace(
        names={0: "person", 2: "car", 5: "bus"},
        boxes=SimpleNamespace(
            xyxy=Tensor([[-10, 1, 90, 40], [0, 0, 1, 1], [10, 10, 3, 3]]),
            conf=Tensor([0.9, 0.8, 0.7]),
            cls=Tensor([2, 0, 5]),
        ),
    )
    detector = YoloDetector.__new__(YoloDetector)
    detector.vehicle_types = {2: "car", 5: "bus"}
    detector._predict = lambda image: result
    response = detector.detect(image_bytes())
    assert len(response.vehicles) == 1
    vehicle = response.vehicles[0]
    assert vehicle.type == "car"
    assert vehicle.confidence == 0.9
    assert vehicle.bbox.model_dump() == {"x1": 0, "y1": 1, "x2": 32, "y2": 24}
