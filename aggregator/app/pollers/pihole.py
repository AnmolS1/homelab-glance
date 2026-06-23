"""Pi-hole v6 poller — DNS stats via new /api/* endpoints.

Pi-hole v6 has a strict concurrent-session cap. We keep one sid alive, refresh
only when validity expires, and never open a fresh session on each poll.
"""
import logging
import time
from typing import Any, Dict, Optional

import httpx

from ..config import settings

logger = logging.getLogger(__name__)


class PiholePoller:
	id = "pihole"
	title = "Pi-hole"
	group = "Infrastructure"
	container_name = "pihole"

	def __init__(self, client: httpx.AsyncClient) -> None:
		self._client = client
		self._sid: Optional[str] = None
		self._sid_expiry: float = 0.0
		self._last_good: Dict[str, Any] = {
			"queries": 0,
			"blocked": 0,
			"blocked_pct": 0.0,
			"gravity": 0,
		}
		self._status = "pending"
		self._stale = False

	async def _ensure_sid(self) -> str:
		"""Return cached sid; re-auth only if expired (with 60 s margin)."""
		if self._sid and time.time() < self._sid_expiry - 60:
			return self._sid

		resp = await self._client.post(
			f"{settings.pihole_url}/api/auth",
			json={"password": settings.pihole_password},
			timeout=10,
		)
		resp.raise_for_status()
		body = resp.json()
		session = body.get("session", {})
		sid = session.get("sid") or session.get("id")
		if not sid:
			raise ValueError(f"Pi-hole auth returned no sid; body={body}")
		validity: int = int(session.get("validity", 1800))
		self._sid = sid
		self._sid_expiry = time.time() + validity
		logger.info("Pi-hole auth OK (valid %ds)", validity)
		return str(self._sid)

	async def poll(self) -> Dict[str, Any]:
		try:
			sid = await self._ensure_sid()
			resp = await self._client.get(
				f"{settings.pihole_url}/api/stats/summary",
				headers={"X-FTL-SID": sid},
				timeout=10,
			)
			resp.raise_for_status()
			body = resp.json()

			queries = body.get("queries", {})
			gravity = body.get("gravity", {})

			self._last_good = {
				"queries": int(queries.get("total", 0)),
				"blocked": int(queries.get("blocked", 0)),
				"blocked_pct": round(float(queries.get("percent_blocked", 0.0)), 1),
				"gravity": int(gravity.get("domains_being_blocked", 0)),
			}
			self._status = "up"
			self._stale = False

		except Exception as exc:
			logger.warning("PiholePoller failed: %s", exc)
			self._status = "down"
			self._stale = True

		return {
			"id": self.id,
			"title": self.title,
			"group": self.group,
			"container_name": self.container_name,
			"status": self._status,
			"stale": self._stale,
			"data": self._last_good,
		}
