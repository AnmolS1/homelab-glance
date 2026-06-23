"""Background poll loop.

Runs all pollers concurrently every POLL_SECONDS; joins Beszel container stats onto
each service card by container name; reads /mnt/expansion disk usage directly from
a bind-mounted host path; never lets one dead source blank the others.
"""
import asyncio
import logging
import os
import time
from typing import Any, Dict, List, Tuple, cast

import httpx

from .config import settings
from .store import set_snapshot
from .pollers.beszel import BeszelPoller
from .pollers.jellyfin import JellyfinPoller
from .pollers.qbit import QBitPoller
from .pollers.pihole import PiholePoller
from .pollers.arr import ArrPoller

logger = logging.getLogger(__name__)

# Home-group containers have no dedicated API poller; they appear in the widget
# populated only from the Beszel container join (cpu/mem/status).
_HOME_CONTAINERS = [
	{"id": "mosquitto", "title": "Mosquitto", "group": "Home", "container_name": "mosquitto"},
	{"id": "zigbee2mqtt", "title": "Zigbee2MQTT", "group": "Home", "container_name": "zigbee2mqtt"},
]


def _read_expansion_disk() -> Dict[str, float]:
	"""Read expansion drive usage via bind-mounted host path. Returns {} if unavailable."""
	try:
		st = os.statvfs(settings.expansion_path)
		total = st.f_frsize * st.f_blocks
		avail = st.f_frsize * st.f_bavail
		used = total - avail
		TiB = 1024 ** 4
		return {
			"disk_used_tb": round(used / TiB, 2),
			"disk_total_tb": round(total / TiB, 2),
		}
	except Exception as exc:
		logger.warning("Expansion disk read failed (%s): %s", settings.expansion_path, exc)
		return {}


def _enrich(card: Dict[str, Any], container_stats: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
	"""Overlay Beszel container cpu/mem/net onto a service card."""
	cname = card.get("container_name", "")
	cs = container_stats.get(cname, {})
	return {
		**card,
		"cpu_pct": cs.get("cpu_pct"),
		"mem_mb": cs.get("mem_mb"),
		"rx_mbps": cs.get("rx_mbps"),
		"tx_mbps": cs.get("tx_mbps"),
		"container_running": cname in container_stats,
	}


async def poll_once(
	beszel: BeszelPoller,
	jellyfin: JellyfinPoller,
	qbit: QBitPoller,
	pihole: PiholePoller,
	sonarr: ArrPoller,
	radarr: ArrPoller,
	prowlarr: ArrPoller,
) -> None:
	"""Run all pollers concurrently, merge, and write to the snapshot store."""
	results = await asyncio.gather(
		beszel.poll(),
		jellyfin.poll(),
		qbit.poll(),
		pihole.poll(),
		sonarr.poll(),
		radarr.poll(),
		prowlarr.poll(),
	)

	host_dict, container_stats = cast(
		Tuple[Dict[str, Any], Dict[str, Dict[str, Any]]], results[0]
	)
	service_cards = cast(List[Dict[str, Any]], results[1:])

	# Add /mnt/expansion disk stats (independent of Beszel status)
	host_dict.update(_read_expansion_disk())

	# Enrich service cards with Beszel container stats
	enriched = [_enrich(c, container_stats) for c in service_cards]

	# Add Home-group cards (stats-only; status derived from Beszel container presence)
	for hc in _HOME_CONTAINERS:
		cname = hc["container_name"]
		cs = container_stats.get(cname, {})
		enriched.append(
			{
				"id": hc["id"],
				"title": hc["title"],
				"group": hc["group"],
				"container_name": cname,
				"status": "up" if cname in container_stats else "unknown",
				"stale": False,
				"cpu_pct": cs.get("cpu_pct"),
				"mem_mb": cs.get("mem_mb"),
				"rx_mbps": cs.get("rx_mbps"),
				"tx_mbps": cs.get("tx_mbps"),
				"container_running": cname in container_stats,
				"data": {},
			}
		)

	snapshot: Dict[str, Any] = {
		"generated_at": int(time.time()),
		"poll_seconds": settings.poll_seconds,
		"host": host_dict,
		"cards": enriched,
	}
	await set_snapshot(snapshot)
	logger.debug("Snapshot updated — %d cards", len(enriched))


async def poll_loop() -> None:
	"""Entry point for the background task: runs forever, sleeps POLL_SECONDS between cycles."""
	async with httpx.AsyncClient(follow_redirects=True) as client:
		beszel = BeszelPoller(client)
		jellyfin = JellyfinPoller(client)
		qbit = QBitPoller(client)
		pihole = PiholePoller(client)
		sonarr = ArrPoller(
			client,
			id="sonarr",
			title="Sonarr",
			group="Acquisition",
			container_name="sonarr",
			base_url=settings.sonarr_url,
			api_key=settings.sonarr_api_key,
			api_version="v3",
			wanted_field="wanted",
		)
		radarr = ArrPoller(
			client,
			id="radarr",
			title="Radarr",
			group="Acquisition",
			container_name="radarr",
			base_url=settings.radarr_url,
			api_key=settings.radarr_api_key,
			api_version="v3",
			wanted_field="missing",
		)
		prowlarr = ArrPoller(
			client,
			id="prowlarr",
			title="Prowlarr",
			group="Acquisition",
			container_name="prowlarr",
			base_url=settings.prowlarr_url,
			api_key=settings.prowlarr_api_key,
			api_version="v1",
			wanted_field="grabs",
		)

		while True:
			try:
				await poll_once(beszel, jellyfin, qbit, pihole, sonarr, radarr, prowlarr)
			except Exception:
				logger.exception("Unexpected error in poll_once")
			await asyncio.sleep(settings.poll_seconds)
