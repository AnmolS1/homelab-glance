"""Beszel poller — PocketBase hub for host and container stats.

Auth flow: POST /api/collections/users/auth-with-password -> token.
Token cached; re-auth transparently on 401.

On the first successful poll we log one raw systems record and one container_stats
record at INFO so field names (which shift between Beszel versions) can be confirmed
before the mapping is considered correct.
"""
import logging
from typing import Any, Dict, Optional

import httpx

from ..config import settings

logger = logging.getLogger(__name__)


class BeszelPoller:
    def __init__(self, client: httpx.AsyncClient) -> None:
        self._client = client
        self._token: Optional[str] = None
        self._raw_logged = False
        self._last_good_host: Optional[Dict[str, Any]] = None
        self._last_good_containers: Dict[str, Dict[str, Any]] = {}
        self._status = "pending"
        self._stale = False

    # ------------------------------------------------------------------
    # Auth
    # ------------------------------------------------------------------

    async def _auth(self) -> str:
        resp = await self._client.post(
            f"{settings.beszel_url}/api/collections/users/auth-with-password",
            json={"identity": settings.beszel_user, "password": settings.beszel_password},
            timeout=10,
        )
        resp.raise_for_status()
        self._token = resp.json()["token"]
        logger.info("Beszel auth OK")
        return self._token

    async def _get(self, path: str, **kwargs: Any) -> httpx.Response:
        """GET with auth; re-auth once on 401."""
        if not self._token:
            await self._auth()
        headers = {"Authorization": self._token}
        resp = await self._client.get(
            f"{settings.beszel_url}{path}", headers=headers, timeout=10, **kwargs
        )
        if resp.status_code == 401:
            logger.info("Beszel 401 — re-authenticating")
            self._token = None
            await self._auth()
            resp = await self._client.get(
                f"{settings.beszel_url}{path}",
                headers={"Authorization": self._token},
                timeout=10,
                **kwargs,
            )
        resp.raise_for_status()
        return resp

    # ------------------------------------------------------------------
    # Parsing (field names shift between Beszel versions)
    # ------------------------------------------------------------------

    def _parse_host(self, record: Dict[str, Any]) -> Dict[str, Any]:
        if not self._raw_logged:
            logger.info("BESZEL raw systems record: %s", record)

        info: Dict[str, Any] = record.get("info") or {}

        # Beszel 0.18.x uses abbreviated keys in the info object:
        #   cpu  = CPU usage %
        #   u    = uptime seconds
        #   mp   = memory used GiB
        #   dp   = disk used %
        #   dt   = disk total GiB (root partition)
        # Older versions used full names; try both.
        cpu = float(info.get("cpu") or info.get("cpu_pct") or 0)
        uptime = int(info.get("u") or record.get("uptime") or info.get("uptime") or 0)

        # Memory: 'mp' = used GiB in v0.18.x; fallback to longer names in older versions
        mem_used = float(info.get("mp") or info.get("mem_used") or info.get("mem") or 0)
        # Total RAM: derive from 'mp'/'m_p' percentage if available, else leave as 0
        mem_total_raw = float(info.get("m") or info.get("mem_total") or info.get("memTotal") or 0)
        mem_total = mem_total_raw  # 0 means "unknown" — widgets show "—"

        # Disk: 'dp' = used %, 'dt' = total GiB (root disk only in v0.18.x)
        disk_total_gib = float(info.get("dt") or info.get("disk_total") or info.get("diskTotal") or 0)
        disk_pct = float(info.get("dp") or info.get("disk_pct") or 0)
        disk_used_gib = disk_total_gib * disk_pct / 100.0
        disk_used_tb = disk_used_gib / 1024
        disk_total_tb = disk_total_gib / 1024

        return {
            "name": record.get("name", "unknown"),
            "cpu_pct": round(cpu, 1),
            "ram_used_gb": round(mem_used, 1),
            "ram_total_gb": round(mem_total, 1),
            "uptime": uptime,
            "disk_used_tb": round(disk_used_tb, 3),
            "disk_total_tb": round(disk_total_tb, 3),
        }

    def _parse_containers(self, record: Dict[str, Any]) -> Dict[str, Dict[str, Any]]:
        if not self._raw_logged:
            logger.info("BESZEL raw container_stats record: %s", record)

        stats = record.get("stats") or []
        result: Dict[str, Dict[str, Any]] = {}

        for c in stats:
            # Beszel 0.18.x container stat keys:
            #   n  = name,  c = cpu %,  m = mem MiB
            #   ns = net send MB/s,  nr = net recv MB/s
            #   b  = [rx_bytes, tx_bytes] cumulative (not rates — ignore for display)
            name = c.get("name") or c.get("n") or ""
            if not name:
                continue

            cpu = float(c.get("cpu") or c.get("c") or 0)
            mem = float(c.get("mem") or c.get("m") or 0)  # MiB

            # Network rates: 1m records have pre-computed ns (send MB/s) / nr (recv MB/s).
            # Other record types only have 'b': [rx_bytes, tx_bytes] per-second snapshot —
            # divide by 1_048_576 to get MB/s.
            b = c.get("b") or []
            b_rx = float(b[0]) if len(b) > 0 else 0.0
            b_tx = float(b[1]) if len(b) > 1 else 0.0
            tx_mbps = float(c.get("ns") or 0) or (b_tx / 1_048_576 if b_tx else 0.0)
            rx_mbps = float(c.get("nr") or 0) or (b_rx / 1_048_576 if b_rx else 0.0)

            result[name] = {
                "cpu_pct": round(cpu, 2),
                "mem_mb": round(mem, 1),
                "rx_mbps": round(rx_mbps, 3),
                "tx_mbps": round(tx_mbps, 3),
            }

        return result

    # ------------------------------------------------------------------
    # Public poll
    # ------------------------------------------------------------------

    async def poll(self) -> tuple[Dict[str, Any], Dict[str, Dict[str, Any]]]:
        """Returns (host_stats, containers_map). Never raises — on failure sets stale."""
        try:
            systems_resp = await self._get(
                "/api/collections/systems/records",
                params={"perPage": 50},
            )
            items = systems_resp.json().get("items") or systems_resp.json().get("records") or []
            if not items:
                raise ValueError("No systems records from Beszel")

            record = items[0]
            system_id: str = record.get("id", "")
            host = self._parse_host(record)

            # Prefer 1m records — they carry pre-computed ns/nr rate fields.
            # If no 1m record exists yet, fall back to any recent record.
            cstats_resp = await self._get(
                "/api/collections/container_stats/records",
                params={
                    "filter": f"(system='{system_id}' && type='1m')",
                    "sort": "-created",
                    "perPage": 1,
                },
            )
            citems = (
                cstats_resp.json().get("items")
                or cstats_resp.json().get("records")
                or []
            )
            if not citems:
                # fall back: any type
                fb_resp = await self._get(
                    "/api/collections/container_stats/records",
                    params={
                        "filter": f"(system='{system_id}')",
                        "sort": "-created",
                        "perPage": 1,
                    },
                )
                citems = (
                    fb_resp.json().get("items")
                    or fb_resp.json().get("records")
                    or []
                )
            containers = self._parse_containers(citems[0]) if citems else {}

            if not self._raw_logged:
                self._raw_logged = True

            self._last_good_host = host
            self._last_good_containers = containers
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
                    "disk_used_tb": 0.0,
                    "disk_total_tb": 0.0,
                }
            ),
        }
        return host_out, self._last_good_containers
