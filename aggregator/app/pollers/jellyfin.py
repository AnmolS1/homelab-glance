"""Jellyfin poller — active streams via /Sessions."""
import logging
from typing import Any, Dict

import httpx

from ..config import settings

logger = logging.getLogger(__name__)


class JellyfinPoller:
	id = "jellyfin"
	title = "Jellyfin"
	group = "Media"
	container_name = "jellyfin"

	def __init__(self, client: httpx.AsyncClient) -> None:
		self._client = client
		self._last_good: Dict[str, Any] = {"streams": 0, "now_playing": []}
		self._status = "pending"
		self._stale = False

	async def poll(self) -> Dict[str, Any]:
		try:
			resp = await self._client.get(
				f"{settings.jellyfin_url}/Sessions",
				headers={"X-Emby-Token": settings.jellyfin_key},
				timeout=10,
			)
			resp.raise_for_status()
			sessions = resp.json()

			active = [s for s in sessions if s.get("NowPlayingItem")]
			now_playing = [
				{
					"user": s.get("UserName", ""),
					"title": s["NowPlayingItem"].get("Name", ""),
				}
				for s in active
			]

			self._last_good = {"streams": len(active), "now_playing": now_playing}
			self._status = "up"
			self._stale = False

		except Exception as exc:
			logger.warning("JellyfinPoller failed: %s", exc)
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
