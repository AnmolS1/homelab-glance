"""FastAPI application entry point.

Endpoints:
  GET /healthz           — always 200 {"ok": true}, unauthenticated
  GET /api/dashboard     — full merged snapshot; requires Bearer token when WIDGET_TOKEN is set
"""
import asyncio
import logging
from contextlib import asynccontextmanager
from typing import Any, AsyncIterator, Dict

import httpx
from fastapi import FastAPI, HTTPException, Request

from .config import settings
from .docker_control import DockerControlError, DockerProxyClient, audit_entries
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


def _require_widget_token(request: Request) -> None:
	"""Bearer WIDGET_TOKEN guard — active only when WIDGET_TOKEN is configured."""
	if not settings.widget_token:
		return
	auth = request.headers.get("Authorization", "")
	if not auth.startswith("Bearer "):
		raise HTTPException(status_code=401, detail="Missing Bearer token")
	if auth[len("Bearer "):] != settings.widget_token:
		raise HTTPException(status_code=401, detail="Invalid token")


def _require_control_token(request: Request) -> None:
	"""Writes require the Bearer WIDGET_TOKEN *and* a separate X-Control-Token."""
	_require_widget_token(request)
	if not settings.control_token:
		raise HTTPException(status_code=503, detail="Control plane disabled (CONTROL_TOKEN unset)")
	if request.headers.get("X-Control-Token", "") != settings.control_token:
		raise HTTPException(status_code=403, detail="Invalid control token")


@app.get("/api/dashboard")
async def dashboard(request: Request) -> Dict[str, Any]:
	_require_widget_token(request)

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


# ── Docker control plane ────────────────────────────────────────────────────
# Reads (containers/logs/audit) require the Bearer WIDGET_TOKEN.
# Writes (start/stop/restart) additionally require the X-Control-Token header.

@app.get("/api/docker/containers")
async def docker_containers(request: Request) -> Dict[str, Any]:
	_require_widget_token(request)
	async with httpx.AsyncClient() as client:
		try:
			return {"containers": await DockerProxyClient(client).list_containers()}
		except DockerControlError as exc:
			raise HTTPException(status_code=exc.status, detail=exc.detail)


@app.get("/api/docker/{container}/logs")
async def docker_logs(container: str, request: Request, tail: int = 200) -> Dict[str, Any]:
	_require_widget_token(request)
	async with httpx.AsyncClient() as client:
		try:
			logs = await DockerProxyClient(client).logs(container, tail=tail)
			return {"container": container, "logs": logs}
		except DockerControlError as exc:
			raise HTTPException(status_code=exc.status, detail=exc.detail)


@app.post("/api/docker/{container}/{action}")
async def docker_action(container: str, action: str, request: Request) -> Dict[str, Any]:
	_require_control_token(request)
	async with httpx.AsyncClient() as client:
		try:
			entry = await DockerProxyClient(client).action(container, action, actor="app")
			return {"ok": True, "container": container, "action": action, "audit": entry}
		except DockerControlError as exc:
			raise HTTPException(status_code=exc.status, detail=exc.detail)


@app.get("/api/docker/audit")
async def docker_audit(request: Request) -> Dict[str, Any]:
	_require_widget_token(request)
	return {"entries": audit_entries()}
