"""Docker control plane via tecnativa/docker-socket-proxy.

Monitor (GET list/logs) is low-risk; control (POST start/stop/restart) requires
CONTROL_TOKEN, is allowlisted, and every write is audited. EXEC is never used —
this module only ever issues container lifecycle calls the proxy is configured
to allow (`CONTAINERS=1`, `POST=1`, `EXEC=0`).

A network-reachable Docker control API is root-equivalent to the host; the
allowlist here refuses to touch the plumbing (dockerproxy/caddy/cloudflared/self).
"""
import json
import logging
import time
from collections import deque
from typing import Any, Deque, Dict, List

import httpx

from .config import settings

logger = logging.getLogger(__name__)

VALID_ACTIONS = {"start", "stop", "restart"}

_audit: Deque[Dict[str, Any]] = deque(maxlen=200)


class DockerControlError(Exception):
	"""Carries an HTTP status + detail for the API layer to surface."""

	def __init__(self, status: int, detail: str) -> None:
		self.status = status
		self.detail = detail
		super().__init__(detail)


def _names_from(csv: str) -> set:
	return {n.strip() for n in csv.split(",") if n.strip()}


def is_controllable(name: str) -> bool:
	"""True if `name` may be start/stop/restarted: not protected, and (if an
	allowlist is configured) present in it."""
	if name in _names_from(settings.docker_protected):
		return False
	allow = _names_from(settings.docker_control_allowlist)
	return name in allow if allow else True


def _container_name(c: Dict[str, Any]) -> str:
	names = c.get("Names") or []
	if names:
		return str(names[0]).lstrip("/")
	return str(c.get("Id", ""))[:12]


def _demux(data: bytes) -> str:
	"""Decode Docker's multiplexed log stream. Non-TTY logs are framed as
	[stream(1)][0,0,0][size(4 BE)][payload]; TTY logs are raw — detect and pass
	through."""
	if len(data) >= 8 and data[0] in (0, 1, 2) and data[1:4] == b"\x00\x00\x00":
		out: List[str] = []
		i, n = 0, len(data)
		while i + 8 <= n:
			size = int.from_bytes(data[i + 4:i + 8], "big")
			i += 8
			out.append(data[i:i + size].decode("utf-8", "replace"))
			i += size
		return "".join(out)
	return data.decode("utf-8", "replace")


def _record(action: str, container: str, result: str, actor: str) -> Dict[str, Any]:
	entry = {
		"ts": int(time.time()),
		"action": action,
		"container": container,
		"result": result,
		"actor": actor,
	}
	_audit.appendleft(entry)
	logger.info("AUDIT %s %s -> %s (by %s)", action, container, result, actor)
	if settings.audit_log_path:
		try:
			with open(settings.audit_log_path, "a", encoding="utf-8") as f:
				f.write(json.dumps(entry) + "\n")
		except Exception as exc:  # never let auditing failure break the action
			logger.warning("audit write failed: %s", exc)
	return entry


def audit_entries() -> List[Dict[str, Any]]:
	return list(_audit)


class DockerProxyClient:
	def __init__(self, client: httpx.AsyncClient) -> None:
		self._client = client

	def _base(self) -> str:
		if not settings.docker_proxy_url:
			raise DockerControlError(503, "Docker control not configured (DOCKER_PROXY_URL unset)")
		return settings.docker_proxy_url.rstrip("/")

	async def list_containers(self) -> List[Dict[str, Any]]:
		try:
			resp = await self._client.get(
				f"{self._base()}/containers/json", params={"all": "true"}, timeout=10
			)
			resp.raise_for_status()
		except DockerControlError:
			raise
		except Exception as exc:
			raise DockerControlError(502, f"Docker proxy error: {exc}")
		out: List[Dict[str, Any]] = []
		for c in resp.json():
			name = _container_name(c)
			out.append({
				"id": str(c.get("Id", ""))[:12],
				"name": name,
				"image": c.get("Image"),
				"state": c.get("State"),     # running, exited, …
				"status": c.get("Status"),   # "Up 3 hours"
				"controllable": is_controllable(name),
			})
		return out

	async def logs(self, container: str, tail: int = 200) -> str:
		try:
			resp = await self._client.get(
				f"{self._base()}/containers/{container}/logs",
				params={"stdout": "1", "stderr": "1", "tail": str(tail)},
				timeout=15,
			)
			resp.raise_for_status()
		except DockerControlError:
			raise
		except Exception as exc:
			raise DockerControlError(502, f"Docker proxy error: {exc}")
		return _demux(resp.content)

	async def action(self, container: str, action: str, actor: str = "app") -> Dict[str, Any]:
		if action not in VALID_ACTIONS:
			raise DockerControlError(400, f"Invalid action: {action}")
		if not is_controllable(container):
			_record(action, container, "denied", actor)
			raise DockerControlError(403, f"Container '{container}' is not controllable")
		try:
			resp = await self._client.post(
				f"{self._base()}/containers/{container}/{action}", timeout=20
			)
			# 204 = done; 304 = already in target state (e.g. start a running container)
			if resp.status_code not in (204, 304):
				resp.raise_for_status()
		except DockerControlError:
			raise
		except Exception as exc:
			_record(action, container, f"error:{exc}", actor)
			raise DockerControlError(502, f"Docker proxy error: {exc}")
		return _record(action, container, "ok", actor)
