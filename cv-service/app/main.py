"""Stage 16: bounded image input and pretrained vehicle detection."""

import asyncio
import logging
from collections.abc import Callable
from contextlib import asynccontextmanager
from threading import Lock

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from starlette.concurrency import run_in_threadpool

from app.detector import DetectionResponse, ImageTooLarge, InvalidImage, YoloDetector

MAX_BYTES = 5 * 1024 * 1024
logger = logging.getLogger(__name__)


def create_app(detector_factory: Callable = YoloDetector) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.detector = None
        try:
            app.state.detector = await run_in_threadpool(detector_factory)
        except Exception:
            logger.error("Pretrained detector initialization failed")
        yield
        app.state.detector = None

    app = FastAPI(title="EasyPark CV Service", version="0.2.0", lifespan=lifespan)
    app.state.detector = None
    app.state.gate = Lock()

    @app.get("/health")
    async def health():
        ready = app.state.detector is not None
        return JSONResponse(
            {"status": "ok" if ready else "unavailable", "service": "easypark-cv"},
            status_code=200 if ready else 503,
        )

    @app.post("/detect", response_model=DetectionResponse)
    async def detect(request: Request):
        if app.state.detector is None:
            raise HTTPException(503, "Detector is unavailable")
        media_type = request.headers.get("content-type", "").split(";")[0].lower()
        if media_type not in {"image/jpeg", "image/png"}:
            raise HTTPException(415, "Send a JPEG or PNG image as the request body")
        if not app.state.gate.acquire(blocking=False):
            raise HTTPException(429, "Detector is busy", headers={"Retry-After": "1"})
        try:

            async def read_body() -> bytes:
                chunks, size = [], 0
                async for chunk in request.stream():
                    size += len(chunk)
                    if size > MAX_BYTES:
                        raise HTTPException(413, "Image exceeds 5 MiB")
                    chunks.append(chunk)
                return b"".join(chunks)

            data = await asyncio.wait_for(read_body(), timeout=10)
            if not data:
                raise HTTPException(400, "Image is empty")
            return await run_in_threadpool(app.state.detector.detect, data)
        except TimeoutError as error:
            raise HTTPException(408, "Image upload timed out") from error
        except InvalidImage as error:
            raise HTTPException(400, "Invalid JPEG or PNG image") from error
        except ImageTooLarge as error:
            raise HTTPException(413, "Image exceeds 12 megapixels") from error
        except HTTPException:
            raise
        except Exception as error:
            logger.error("Vehicle inference failed")
            raise HTTPException(503, "Detection failed; retry later") from error
        finally:
            app.state.gate.release()

    return app


app = create_app()
