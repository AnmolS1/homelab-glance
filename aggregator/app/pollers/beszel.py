"""Beszel poller — PocketBase hub for host and container stats.

Auth flow: POST /api/collections/users/auth-with-password → token.
Token cached; re-auth transparently on 401.

Data comes from three collections:
    systems        — host identity (name, uptime) and the system_id for filtering
    system_stats   — CPU %, RAM used/total GB, temperatures, GPU stats
                     (last TEMP_HISTORY_LEN 1-minute records fetched for sparklines)
    container_stats — per-container cpu/mem/net (single 1m record)

On first successful poll, one raw record from each collection is logged at INFO
so field names (which can shift between Beszel versions) can be confirmed:

    docker compose logs glance | grep "BESZEL raw"
"""
import logging
from typing import Any, Dict, List, Optional, Tuple

import httpx

from ..config import settings

logger = logging.getLogger(__name__)


def _find_temp(t: Dict[str, Any], primary: str, *substrings: str) -> Optional[float]:
	"""Return t[primary] if present, else first value whose key contains a substring."""
	if primary in t:
		return float(t[primary])
	for key, val in t.items():
		if any(s in key.lower() for s in substrings):
			return float(val)
	return None


class BeszelPoller:
	def __init__(self, client: httpx.AsyncClient) -> None:
		self._client = client
		self._token: Optional[str] = None
		self._raw_logged = False
		self._last_good_host: Optional[Dict[str, Any]] = None
		self._last_good_sensors: Optional[Dict[str, Any]] = None
		self._last_good_containers: Dict[str, Dict[str, Any]] = {}
		self._status = "pending"
		self._stale = False

	# ── Auth ──────────────────────────────────────────────────────────────────

	async def _auth(self) -> None:
		resp = await self._client.post(
			f"{settings.beszel_url}/api/collections/users/auth-with-password",
			json={"identity": settings.beszel_user, "password": settings.beszel_password},
			timeout=10,
		)
		resp.raise_for_status()
		self._token = resp.json()["token"]
		logger.info("Beszel auth OK")

	async def _get(self, path: str, **kwargs: Any) -> httpx.Response:
		"""Authenticated GET; re-auths once on 401."""
		if not self._token:
			await self._auth()

		has_token = False
		if self._token:
			resp = await self._client.get(
				f"{settings.beszel_url}{path}",
				headers={"Authorization": self._token},
				timeout=10,
				**kwargs,
			)
			has_token = True
		
		if not has_token or resp.status_code == 401:
			logger.info("Beszel 401 — re-authenticating")
			await self._auth()
			if self._token:
				resp = await self._client.get(
					f"{settings.beszel_url}{path}",
					headers={"Authorization": self._token},
					timeout=10,
					**kwargs,
				)
		resp.raise_for_status()
		return resp
			

	# ── Parsing ───────────────────────────────────────────────────────────────

	def _parse_system_stats(
		self, items: List[Dict[str, Any]], name: str, uptime: int
	) -> Tuple[Dict[str, Any], Dict[str, Any]]:
		"""Parse system_stats records (newest-first) into (host, sensors)."""
		if not items:
			return (
				{"name": name, "cpu_pct": 0.0, "ram_used_gb": 0.0, "ram_total_gb": 0.0, "uptime": uptime},
				{},
			)

		if not self._raw_logged:
			logger.info("BESZEL raw system_stats record: %s", items[0])

		cur: Dict[str, Any] = items[0]["stats"]
		cpu = float(cur.get("cpu") or 0)
		ram_used = float(cur.get("mu") or 0)   # mu = mem used GB
		ram_total = float(cur.get("m") or 0)   # m  = mem total GB

		t: Dict[str, Any] = cur.get("t") or {}
		nvme_temp = _find_temp(t, settings.nvme_temp_sensor, "nvme")
		gpu_temp = _find_temp(t, settings.gpu_temp_sensor, "amdgpu", "gpu")

		# GPU block — first entry in the g map
		g: Dict[str, Any] = cur.get("g") or {}
		ginfo: Optional[Dict[str, Any]] = next(iter(g.values()), None)

		# History oldest→newest (records arrive newest-first, so reverse)
		nvme_hist: List[float] = []
		gpu_hist: List[float] = []
		for r in reversed(items):
			rt: Dict[str, Any] = r["stats"].get("t") or {}
			nv = _find_temp(rt, settings.nvme_temp_sensor, "nvme")
			if nv is not None:
				nvme_hist.append(round(float(nv), 2))
			gv = _find_temp(rt, settings.gpu_temp_sensor, "amdgpu", "gpu")
			if gv is not None:
				gpu_hist.append(round(float(gv), 2))

		host = {
			"name": name,
			"cpu_pct": round(cpu, 1),
			"ram_used_gb": round(ram_used, 1),
			"ram_total_gb": round(ram_total, 1),
			"uptime": uptime,
		}
		sensors: Dict[str, Any] = {
			"nvme_temp": round(float(nvme_temp), 1) if nvme_temp is not None else None,
			"gpu_temp": round(float(gpu_temp), 1) if gpu_temp is not None else None,
			"gpu_load_pct": round(float(ginfo["u"]), 1) if ginfo else None,
			"gpu_power_w": round(float(ginfo["p"]), 1) if ginfo else None,
			"gpu_vram_used_mb": int(float(ginfo["mu"])) if ginfo else None,
			"gpu_vram_total_mb": int(float(ginfo["mt"])) if ginfo else None,
			"nvme_temp_history": nvme_hist,
			"gpu_temp_history": gpu_hist,
		}
		return host, sensors

	def _parse_containers(self, record: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
		if not self._raw_logged:
			logger.info("BESZEL raw container_stats record: %s", record)

		result: Dict[str, Dict[str, Any]] = {}
		for c in record.get("stats") or []:
			name = c.get("name") or c.get("n") or ""
			if not name:
				continue
			cpu = float(c.get("cpu") or c.get("c") or 0)
			mem = float(c.get("mem") or c.get("m") or 0)
			b = c.get("b") or []
			b_rx = float(b[0]) if len(b) > 0 else 0.0
			b_tx = float(b[1]) if len(b) > 1 else 0.0
			# 1m records have pre-computed ns (send MB/s) / nr (recv MB/s);
			# other record types only carry raw b[rx, tx] bytes per second.
			tx_mbps = float(c.get("ns") or 0) or (b_tx / 1_048_576 if b_tx else 0.0)
			rx_mbps = float(c.get("nr") or 0) or (b_rx / 1_048_576 if b_rx else 0.0)
			result[name] = {
				"cpu_pct": round(cpu, 2),
				"mem_mb": round(mem, 1),
				"rx_mbps": round(rx_mbps, 3),
				"tx_mbps": round(tx_mbps, 3),
			}
		return result

	# ── Public poll ───────────────────────────────────────────────────────────

	async def poll(self) -> Tuple[Dict[str, Any], Dict[str, Dict[str, Any]]]:
		"""Returns (host_stats, containers_map). Never raises — on failure sets stale."""
		try:
			# systems: host name, uptime, system_id (needed to filter other collections)
			sys_resp = await self._get(
				"/api/collections/systems/records",
				params={"perPage": 50},
			)
			sys_body = sys_resp.json()
			sys_items = sys_body.get("items") or sys_body.get("records") or []
			if not sys_items:
				raise ValueError("No systems records from Beszel")

			sys_rec = sys_items[0]
			if not self._raw_logged:
				logger.info("BESZEL raw systems record: %s", sys_rec)
			system_id: str = sys_rec.get("id", "")
			name: str = sys_rec.get("name", "unknown")
			info: Dict[str, Any] = sys_rec.get("info") or {}
			uptime = int(info.get("u") or sys_rec.get("uptime") or info.get("uptime") or 0)

			# system_stats: CPU, RAM, temperatures, GPU — fetch last N 1m records
			try:
				ss_resp = await self._get(
					"/api/collections/system_stats/records",
					params={
						"filter": f"(system='{system_id}' && type='1m')",
						"sort": "-created",
						"perPage": settings.temp_history_len,
					},
				)
				ss_body = ss_resp.json()
				ss_items = ss_body.get("items") or ss_body.get("records") or []
				host_stats, sensors = self._parse_system_stats(ss_items, name, uptime)
				self._last_good_host = host_stats
				self._last_good_sensors = sensors
			except Exception as exc:
				logger.warning("BeszelPoller system_stats failed: %s", exc)
				if self._last_good_host is None:
					self._last_good_host = {
						"name": name, "cpu_pct": 0.0,
						"ram_used_gb": 0.0, "ram_total_gb": 0.0, "uptime": uptime,
					}

			# container_stats: prefer 1m records (pre-computed ns/nr rates)
			cs_resp = await self._get(
				"/api/collections/container_stats/records",
				params={
					"filter": f"(system='{system_id}' && type='1m')",
					"sort": "-created",
					"perPage": 1,
				},
			)
			cs_body = cs_resp.json()
			citems = cs_body.get("items") or cs_body.get("records") or []
			if not citems:
				fb_resp = await self._get(
					"/api/collections/container_stats/records",
					params={
						"filter": f"(system='{system_id}')",
						"sort": "-created",
						"perPage": 1,
					},
				)
				citems = fb_resp.json().get("items") or fb_resp.json().get("records") or []
			if citems:
				self._last_good_containers = self._parse_containers(citems[0])

			if not self._raw_logged:
				self._raw_logged = True

			self._status = "up"
			self._stale = False

		except Exception as exc:
			logger.warning("BeszelPoller failed: %s", exc)
			self._status = "down"
			self._stale = True

		host_out: Dict[str, Any] = {
			"status": self._status,
			"stale": self._stale,
			**(
				self._last_good_host
				or {
					"name": "unknown",
					"cpu_pct": 0.0,
					"ram_used_gb": 0.0,
					"ram_total_gb": 0.0,
					"uptime": 0,
				}
			),
			"sensors": self._last_good_sensors or {},
		}
		return host_out, self._last_good_containers
