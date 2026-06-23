"""Generic Sonarr / Radarr / Prowlarr poller (all use the same header+shape)."""
import logging
from typing import Any, Dict

import httpx

logger = logging.getLogger(__name__)


class ArrPoller:
	"""Polls one *arr service for queue status and wanted/missing/grabs.

	Args:
		id:           card id (e.g. "sonarr")
		title:        display title
		group:        card group
		container_name: name as it appears in Beszel container stats
		base_url:     service root URL
		api_key:      X-Api-Key value
		api_version:  "v3" (Sonarr/Radarr) or "v1" (Prowlarr)
		wanted_field: key name for the "wanted/missing/grabs" count in the data dict
	"""

	def __init__(
		self,
		client: httpx.AsyncClient,
		id: str,
		title: str,
		group: str,
		container_name: str,
		base_url: str,
		api_key: str,
		api_version: str = "v3",
		wanted_field: str = "wanted",
	) -> None:
		self._client = client
		self.id = id
		self.title = title
		self.group = group
		self.container_name = container_name
		self._base = base_url
		self._key = api_key
		self._api_version = api_version
		self._wanted_field = wanted_field
		self._last_good: Dict[str, Any] = (
			{"queries": 0, "grabs": 0} if id == "prowlarr"
			else {"queue": 0, wanted_field: 0}
		)
		self._status = "pending"
		self._stale = False

	def _headers(self) -> Dict[str, str]:
		return {"X-Api-Key": self._key}

	async def poll(self) -> Dict[str, Any]:
		try:
			if self.id == "prowlarr":
				# Prowlarr has no /queue/status endpoint; use indexerstats for
				# per-indexer query/grab totals.
				stats_resp = await self._client.get(
					f"{self._base}/api/v1/indexerstats",
					headers=self._headers(),
					timeout=10,
				)
				stats_resp.raise_for_status()
				indexers = stats_resp.json().get("indexers", [])
				total_queries = sum(i.get("numberOfQueries", 0) + i.get("numberOfRssQueries", 0) for i in indexers)
				total_grabs = sum(i.get("numberOfGrabs", 0) for i in indexers)
				data: Dict[str, Any] = {"queries": total_queries, "grabs": total_grabs}
			else:
				base = f"{self._base}/api/{self._api_version}"

				# Queue status — Sonarr and Radarr both support this endpoint
				q_resp = await self._client.get(
					f"{base}/queue/status",
					headers=self._headers(),
					timeout=10,
				)
				q_resp.raise_for_status()
				queue_total: int = q_resp.json().get("totalCount", 0)

				# Sonarr / Radarr — wanted/missing
				w_resp = await self._client.get(
					f"{base}/wanted/missing",
					headers=self._headers(),
					params={"pageSize": 1},
					timeout=10,
				)
				w_resp.raise_for_status()
				wanted: int = w_resp.json().get("totalRecords", 0)
				data = {"queue": queue_total, self._wanted_field: wanted}

			self._last_good = data
			self._status = "up"
			self._stale = False

		except Exception as exc:
			logger.warning("ArrPoller[%s] failed: %s", self.id, exc)
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
