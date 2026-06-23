"""FastAPI application entry point.

Endpoints:
  GET /healthz           — always 200 {"ok": true}, unauthenticated
  GET /api/dashboard     — full merged snapshot; requires Bearer token when WIDGET_TOKEN is set
"""
import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Any, AsyncIterator, Dict

from fastapi import FastAPI, HTTPException, Request

from .config import settings
from .loop import poll_loop
from .store import get_snapshot

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s  %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    task = asyncio.create_task(poll_loop())
    logger.info("Poll loop started (every %ds)", settings.poll_seconds)
    try:
        yield
    finally:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
        logger.info("Poll loop stopped")


app = FastAPI(title="homelab-glance", version="1.0.0", lifespan=lifespan)


@app.get("/healthz")
async def healthz() -> Dict[str, bool]:
    return {"ok": True}


@app.get("/api/dashboard")
async def dashboard(request: Request) -> Dict[str, Any]:
    # Auth guard — only active when WIDGET_TOKEN is configured
    if settings.widget_token:
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            raise HTTPException(status_code=401, detail="Missing Bearer token")
        if auth[len("Bearer "):] != settings.widget_token:
            raise HTTPException(status_code=401, detail="Invalid token")

    snap = await get_snapshot()
    if snap is None:
        # First-cycle grace: return an empty-but-valid envelope
        return {
            "generated_at": None,
            "poll_seconds": settings.poll_seconds,
            "host": {},
            "cards": [],
        }
    return snap
