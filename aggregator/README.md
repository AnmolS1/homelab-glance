# glance aggregator — self-hosting guide

The aggregator is a small FastAPI service that turns your homelab into one JSON
snapshot the **Homelab Glance** iOS/macOS app (and its widgets) can render. It
is the open-source server half of the system: the app ships on the App Store,
the aggregator runs on **your** server.

```
┌─────────────────────────────────────────────────────────────────┐
│  Docker socket-proxy ──► container inventory / stats / logs     │
│  (optional pollers) ──► Jellyfin  qBittorrent  Pi-hole  *arr …  │
│                     ↘        ↓                                   │
│               FastAPI aggregator  (:8765)                        │
│                          ↓                                       │
│        Homelab Glance app + widgets (iOS / macOS)                │
└─────────────────────────────────────────────────────────────────┘
```

Everything is fail-soft: a source that's down marks its card `down`/`stale` and
never blanks the rest of the dashboard.

---

## Quickstart — generic cards, zero service config

The minimum viable deploy is the aggregator + a Docker socket-proxy. You get
**auto-detected generic container cards** — name, running state, uptime,
CPU/mem, logs — for every container on the host, with no per-service
credentials at all.

```bash
cd aggregator
cp ../.env.example .env
# in .env, set the ONE required value:
#   WIDGET_TOKEN=$(openssl rand -hex 32)
docker compose up -d
curl -s localhost:8765/healthz     # → {"ok":true}
```

The bundled [docker-compose.yml](docker-compose.yml) wires the aggregator to a
[`tecnativa/docker-socket-proxy`](https://github.com/Tecnativa/docker-socket-proxy)
with `CONTAINERS=1` (list + logs + stats reads) and `EXEC=0`. The raw Docker
socket is mounted **only** into the proxy, which is never published to the host.

Then in the app: Settings → turn off *Use mock data* → Base URL
`http://<server>:8765` → paste your `WIDGET_TOKEN` → *Test connection*.

> **Why a socket-proxy?** A network-reachable Docker API is root-equivalent on
> the host. The proxy grants the aggregator only the verbs it needs; `EXEC`
> (in-container shells) stays off — always.

## Control plane (opt-in) — start/stop/restart from the app

Writes are disabled until you opt in **twice** (proxy verbs + a second token):

1. In `docker-compose.yml`, uncomment on `dockerproxy`:
   `POST=1`, `ALLOW_START=1`, `ALLOW_STOP=1`, `ALLOW_RESTARTS=1` (keep `EXEC=0`).
2. In `.env`, set `CONTROL_TOKEN` (`openssl rand -hex 32`) — treat it like a
   root password. Reads use `Authorization: Bearer <WIDGET_TOKEN>`; writes must
   *also* send `X-Control-Token`.

Guard rails, all on by default:

- `DOCKER_PROTECTED` (default `dockerproxy,caddy,cloudflared,glance`) — never
  controllable, so the app can't stop its own plumbing.
- `DOCKER_CONTROL_ALLOWLIST` — if set, **only** these names are controllable.
- Every write (including denials) is audited in memory
  (`GET /api/docker/audit`) and, if `AUDIT_LOG_PATH` is set, to a JSON-lines file.

## Rich service cards (opt-in) — per-service pollers

Add these **only for richer cards; everything works without them.** Each
configured poller upgrades that service's generic card to a rich one (streams,
queues, download rates, DNS blocking, …).

| Service | Env vars | Card shows |
|---|---|---|
| [Beszel](https://beszel.dev) hub | `BESZEL_URL`, `BESZEL_USER` (account **email**), `BESZEL_PASSWORD` | host CPU/RAM/disk/uptime + per-container cpu/mem join |
| Jellyfin | `JELLYFIN_URL`, `JELLYFIN_KEY` | active streams, now playing |
| qBittorrent | `QBIT_URL`, `QBIT_USERNAME`, `QBIT_PASSWORD` | ↓/↑ rates, active/seeding |
| Pi-hole v6 | `PIHOLE_URL`, `PIHOLE_WEBUI_PASSWORD` | blocked %, queries, gravity |
| Sonarr | `SONARR_URL`, `SONARR_API_KEY` | queue, wanted |
| Radarr | `RADARR_URL`, `RADARR_API_KEY` | queue, missing |
| Prowlarr | `PROWLARR_URL`, `PROWLARR_API_KEY` | queue, grabs |

Use explicit `http://<LAN-IP>:<port>` URLs — that sidesteps docker-network and
VPN-namespace edge cases (e.g. qBittorrent behind gluetun).

## Full environment reference

Copy [.env.example](../.env.example) (kept in sync with
[`app/config.py`](app/config.py)) and fill in what you use.

**Required**

| Var | Purpose |
|---|---|
| `WIDGET_TOKEN` | Bearer token the app sends on every read. `openssl rand -hex 32`. |

**Control plane (optional)**

| Var | Default | Purpose |
|---|---|---|
| `DOCKER_PROXY_URL` | *(empty = docker features off)* | socket-proxy URL, e.g. `http://dockerproxy:2375` |
| `CONTROL_TOKEN` | *(empty = writes off)* | second token required for start/stop/restart |
| `DOCKER_CONTROL_ALLOWLIST` | *(empty = all except protected)* | comma-separated names that MAY be controlled |
| `DOCKER_PROTECTED` | `dockerproxy,caddy,cloudflared,glance` | names that may NEVER be controlled |
| `AUDIT_LOG_PATH` | *(empty)* | JSON-lines audit file for every write |

**App tuning (optional)**

| Var | Default | Purpose |
|---|---|---|
| `POLL_SECONDS` | `15` | poll interval |
| `EXPANSION_PATH` | `/host/expansion` | read-only bind mount for data-drive usage |
| `NVME_TEMP_SENSOR` / `GPU_TEMP_SENSOR` | `nvme_composite` / `amdgpu_edge` | Beszel sensor key names (hardware-specific) |
| `TEMP_HISTORY_LEN` | `30` | sensor sparkline length |

## Reaching the aggregator from the app

The app needs a Base URL it can reach from wherever you are:

- **LAN** — `http://<LAN-IP>:8765`. Works out of the box: the app's transport
  policy (ATS) allows cleartext to private-range/`.local` hosts.
- **Tailscale** — `http://<host>.<tailnet>.ts.net:8765`. Also works: `*.ts.net`
  rides Tailscale's encrypted WireGuard tunnel and the app carries a scoped
  ATS exception for it. (Plain `http://` to any *other* public hostname is
  blocked by iOS — that's deliberate.)
- **Reverse proxy / Cloudflare Tunnel** — `https://glance.example.com`. The
  cleanest option for use away from home; any valid HTTPS endpoint needs no
  exceptions at all.

Prefer HTTPS whenever the aggregator is reachable beyond your LAN. Pair the
Base URL with your `WIDGET_TOKEN` (and `CONTROL_TOKEN` for writes) in the app's
Settings.

## API reference

All `/api/*` reads require `Authorization: Bearer <WIDGET_TOKEN>` once the
token is set. Writes additionally require `X-Control-Token: <CONTROL_TOKEN>`.

| Endpoint | Method | Purpose |
|---|---|---|
| `/healthz` | GET | liveness (no auth) |
| `/api/dashboard` | GET | full snapshot: `host`, rich `cards`, and the auto-detected `containers` inventory |
| `/api/docker/containers` | GET | container inventory (id, name, image, state, status, controllable) |
| `/api/docker/{name}/stats` | GET | one CPU/mem sample (`stream=false` two-sample delta, ~1s) |
| `/api/docker/{name}/logs?tail=200` | GET | recent logs (demuxed) |
| `/api/docker/{name}/{start\|stop\|restart}` | POST | lifecycle action — control token + allowlist + audit |
| `/api/docker/audit` | GET | recent write audit entries |

Container reads (list/logs/stats) are all covered by the proxy's
`CONTAINERS=1` — no additional proxy privilege is ever needed for reads.

## Image publishing

Pushes to `main` and `v*` tags build a multi-arch (amd64/arm64) image via
[.github/workflows/publish.yml](../.github/workflows/publish.yml):

```
ghcr.io/anmols1/homelab-glance-aggregator:latest
```

Prefer a pinned tag in production. To build from source instead, swap the
compose `image:` for `build: .`.

## Development

```bash
cd aggregator
pip install -r requirements.txt pytest pytest-asyncio
python -m pytest tests/
uvicorn app.main:app --reload --port 8765
```
