"""qBittorrent poller — transfer speeds + torrent counts via Web API v2.

SID cookie cached; re-login on 403.
"""
import logging
from typing import Any, Dict, Optional

import httpx

from ..config import settings

logger = logging.getLogger(__name__)

# qBittorrent state sets
_ACTIVE_STATES = {"downloading", "metaDL", "allocating", "checkingDL", "forcedDL"}
_SEEDING_STATES = {"uploading", "stalledUP", "forcedUP", "checkingUP", "queuedUP"}


class QBitPoller:
	id = "qbittorrent"
	title = "qBittorrent"
	group = "Acquisition"
	container_name = "qbittorrent"

	def __init__(self, client: httpx.AsyncClient) -> None:
		self._client = client
		self._sid: Optional[str] = None
		self._last_good: Dict[str, Any] = {
			"dl_mibps": 0.0,
			"ul_mibps": 0.0,
			"active": 0,
			"seeding": 0,
		}
		self._status = "pending"
		self._stale = False

	async def _login(self) -> None:
		resp = await self._client.post(
			f"{settings.qbit_url}/api/v2/auth/login",
			data={"username": settings.qbit_username, "password": settings.qbit_password},
			timeout=10,
		)
		resp.raise_for_status()
		sid = resp.cookies.get("SID")
		if not sid:
			raise ValueError("qBit login returned no SID cookie")
		self._sid = sid

	def _cookies(self) -> Dict[str, str]:
		return {"SID": self._sid} if self._sid else {}

	async def _get(self, path: str, **kwargs: Any) -> httpx.Response:
		if not self._sid:
			await self._login()
		resp = await self._client.get(
			f"{settings.qbit_url}{path}",
			cookies=self._cookies(),
			timeout=10,
			**kwargs,
		)
		if resp.status_code == 403:
			logger.info("qBit 403 — re-logging in")
			self._sid = None
			await self._login()
			resp = await self._client.get(
				f"{settings.qbit_url}{path}",
				cookies=self._cookies(),
				timeout=10,
				**kwargs,
			)
		resp.raise_for_status()
		return resp

	async def poll(self) -> Dict[str, Any]:
		try:
			info_resp = await self._get("/api/v2/transfer/info")
			info = info_resp.json()

			torrents_resp = await self._get("/api/v2/torrents/info")
			torrents = torrents_resp.json()

			dl_bytes: int = info.get("dl_info_speed", 0)
			ul_bytes: int = info.get("up_info_speed", 0)
			active = sum(1 for t in torrents if t.get("state") in _ACTIVE_STATES)
			seeding = sum(1 for t in torrents if t.get("state") in _SEEDING_STATES)

			self._last_good = {
				"dl_mibps": round(dl_bytes / 1_048_576, 2),
				"ul_mibps": round(ul_bytes / 1_048_576, 2),
				"active": active,
				"seeding": seeding,
			}
			self._status = "up"
			self._stale = False

		except Exception as exc:
			logger.warning("QBitPoller failed: %s", exc)
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
