"""Stage 20: real HTTP checks using one supplied multi-vehicle image."""

import argparse
import io
import json
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path)
    parser.add_argument("--url", default="http://127.0.0.1:8000/detect")
    args = parser.parse_args()

    def detect(data):
        request = urllib.request.Request(
            args.url, data=data, headers={"Content-Type": "image/png"}
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)["vehicles"]

    vehicles = detect(args.image.read_bytes())
    assert any(item["type"] == "car" for item in vehicles), "No car detected"
    assert len(vehicles) >= 2, "Multiple vehicles were not detected"
    buffer = io.BytesIO()
    Image.new("RGB", (640, 480), "white").save(buffer, format="PNG")
    assert detect(buffer.getvalue()) == [], "False vehicle on blank image"
    try:
        detect(b"not an image")
    except urllib.error.HTTPError as error:
        assert error.code == 400
    else:
        raise AssertionError("Invalid file was accepted")
    print(json.dumps({"vehicles": vehicles, "blank": "passed", "invalid": "passed"}))


if __name__ == "__main__":
    main()
