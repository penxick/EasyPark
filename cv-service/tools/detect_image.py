"""Send a local JPEG/PNG to EasyPark; print the detection JSON to stdout."""

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

MAX_BYTES = 5 * 1024 * 1024


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("image", type=Path, help="Path to a JPEG or PNG image")
    parser.add_argument("--url", default="http://127.0.0.1:8000/detect")
    args = parser.parse_args(argv)
    try:
        with args.image.open("rb") as source:
            data = source.read(MAX_BYTES + 1)
        if not data or len(data) > MAX_BYTES:
            raise ValueError("Image must be non-empty and at most 5 MiB")
        if data.startswith(b"\x89PNG\r\n\x1a\n"):
            media_type = "image/png"
        elif data.startswith(b"\xff\xd8\xff"):
            media_type = "image/jpeg"
        else:
            raise ValueError("Expected a JPEG or PNG file")
        request = urllib.request.Request(
            args.url, data=data, headers={"Content-Type": media_type}, method="POST"
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            result = json.load(response)
        if not isinstance(result, dict) or not isinstance(result.get("vehicles"), list):
            raise ValueError("Unexpected server response: vehicles list is missing")
        print(json.dumps(result, ensure_ascii=True, indent=2))
        return 0
    except urllib.error.HTTPError as error:
        print(f"Detection failed: HTTP {error.code} {error.reason}", file=sys.stderr)
    except (OSError, ValueError, urllib.error.URLError) as error:
        print(f"Detection failed: {error}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
