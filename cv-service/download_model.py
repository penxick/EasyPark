"""Fetch the fixed official inference weights when building the image."""

import hashlib
from pathlib import Path
from urllib.request import urlopen

URL = "https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.pt"
SHA256 = "0ebbc80d4a7680d14987a577cd21342b65ecfd94632bd9a8da63ae6417644ee1"


def main() -> None:
    target = Path(__file__).parent / "weights" / "yolo11n.pt"
    target.parent.mkdir(exist_ok=True)
    with urlopen(URL, timeout=60) as response:
        data = response.read(10 * 1024 * 1024 + 1)
    if len(data) > 10 * 1024 * 1024 or hashlib.sha256(data).hexdigest() != SHA256:
        raise RuntimeError("Pretrained weights checksum mismatch")
    target.write_bytes(data)


if __name__ == "__main__":
    main()
