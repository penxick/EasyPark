import json
import subprocess
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Thread

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "detect_image.py"


@pytest.mark.parametrize("status", [200, 429, 503])
def test_cli_posts_binary_image_and_reports_http_result(tmp_path, status):
    payload = b"\x89PNG\r\n\x1a\nfixture"
    received = []

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            received.append(
                (
                    self.path,
                    self.headers["Content-Type"],
                    self.rfile.read(int(self.headers["Content-Length"])),
                )
            )
            self.send_response(status)
            self.end_headers()
            self.wfile.write(b'{"vehicles":[]}')

        def log_message(self, *args):
            pass

    image = tmp_path / "image with spaces.png"
    image.write_bytes(payload)
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                str(image),
                "--url",
                f"http://127.0.0.1:{server.server_port}/detect",
            ],
            capture_output=True,
            text=True,
            timeout=10,
        )
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
    assert received == [("/detect", "image/png", payload)]
    if status == 200:
        assert result.returncode == 0
        assert json.loads(result.stdout) == {"vehicles": []}
        assert not result.stderr
    else:
        assert result.returncode == 1
        assert not result.stdout
        assert f"HTTP {status}" in result.stderr


def test_cli_missing_file_is_a_clear_error(tmp_path):
    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(tmp_path / "missing.jpg")],
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert result.returncode == 1
    assert not result.stdout
    assert "Detection failed" in result.stderr
    assert "Traceback" not in result.stderr
