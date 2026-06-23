# homelab-glance

A self-hosted widget system that surfaces live homelab server stats on a macOS
desktop (via [Übersicht](https://tracesof.net/uebersicht/)) and an iOS home-screen
widget (via [Scriptable](https://scriptable.app/)), both fed by a single FastAPI
aggregator. Styled to match the [gethomepage/Homepage](https://gethomepage.dev/)
stone/dark theme.

```
┌──────────────────────────────────────────────────────────────┐
│   Beszel  Jellyfin  qBittorrent  Pi-hole  Sonarr  Radarr     │
│      ↘        ↓         ↓           ↓       ↓      ↓        │
│              FastAPI aggregator  (:8765)                      │
│                 ↙                     ↘                       │
│         Übersicht (macOS)        Scriptable (iOS)             │
└──────────────────────────────────────────────────────────────┘
```

Every source is polled independently every `POLL_SECONDS` seconds. A failure sets that
card's `status:"down"` and keeps its last-good values + a `stale` flag — it never
blanks the rest of the dashboard.

---

## Architecture

| Component | Path | Purpose |
|-----------|------|---------|
| `aggregator/` | FastAPI + httpx | Polls all services, merges into one JSON snapshot |
| `ubersicht/glance.jsx` | Übersicht widget | Full dashboard on the macOS desktop |
| `scriptable/glance.js` | Scriptable widget | Large iOS home-screen widget |

The aggregator runs as a Docker container. All source services are reached via
environment-configured URLs — typically the server's LAN IP or Tailscale IP plus
their published port. Using an explicit IP avoids docker-network and VPN-namespace
edge cases (e.g. qBittorrent runs inside the Gluetun network namespace).

---

## Prerequisites

- **Network access** — the aggregator container must be able to reach each service
  URL you configure. The macOS and iOS clients must be able to reach the aggregator.
  [Tailscale](https://tailscale.com/) is a convenient way to expose the aggregator
  to your Mac and iPhone without port-forwarding.
- **Beszel read-only account** — create a dedicated user in the Beszel hub admin UI
  at `http://YOUR_SERVER_IP:8090/_/` → Collections → users → New record. Grant no
  admin privileges. `BESZEL_USER` must be the account's **email address** (PocketBase
  uses email as the authentication identity, not a username).

---

## Environment variables

Copy `.env.example` to `.env` in your project root and fill in every value.
If you are merging the aggregator into an existing Docker Compose stack, you can
source these from that stack's `.env` file instead.

### Required secrets

| Variable | Description |
|----------|-------------|
| `BESZEL_USER` | Beszel PocketBase account **email** |
| `BESZEL_PASSWORD` | Beszel PocketBase password |
| `JELLYFIN_KEY` | Jellyfin API key (Dashboard → API Keys) |
| `QBIT_USERNAME` | qBittorrent WebUI username |
| `QBIT_PASSWORD` | qBittorrent WebUI password |
| `PIHOLE_WEBUI_PASSWORD` | Pi-hole v6 web UI password |
| `SONARR_API_KEY` | Sonarr API key (Settings → General) |
| `RADARR_API_KEY` | Radarr API key (Settings → General) |
| `PROWLARR_API_KEY` | Prowlarr API key (Settings → General) |
| `WIDGET_TOKEN` | Bearer token for `/api/dashboard` (see below) |

### URLs

| Variable | Default port | Description |
|----------|-------------|-------------|
| `BESZEL_URL` | 8090 | Beszel hub URL |
| `JELLYFIN_URL` | 8096 | Jellyfin URL |
| `QBIT_URL` | 8080 | qBittorrent WebUI URL |
| `PIHOLE_URL` | 8880 | Pi-hole URL |
| `SONARR_URL` | 8989 | Sonarr URL |
| `RADARR_URL` | 7878 | Radarr URL |
| `PROWLARR_URL` | 9696 | Prowlarr URL |

### Tuning

| Variable | Default | Description |
|----------|---------|-------------|
| `POLL_SECONDS` | `15` | How often to refresh the snapshot |

### Generating WIDGET\_TOKEN

```bash
openssl rand -hex 32
# Paste the output into WIDGET_TOKEN in your .env
```

The token is required in `Authorization: Bearer <token>` on every call to
`/api/dashboard`. `/healthz` is always unauthenticated.

---

## Deployment

### Standalone

```bash
# Copy and fill in your values
cp .env.example .env
$EDITOR .env

# Build image and start container
docker compose -f docker-compose.snippet.yml up -d --build

# Verify
curl -s localhost:8765/healthz            # → {"ok":true}
curl -s localhost:8765/api/dashboard      # → 401
curl -s -H "Authorization: Bearer $WIDGET_TOKEN" localhost:8765/api/dashboard | jq
```

### Merged into an existing stack

Copy the service block from `docker-compose.snippet.yml` into your existing
`docker-compose.yml`, adjusting the `build:` path to point at this repo's
`aggregator/` directory. Ensure your existing `.env` file contains all the
variables listed above.

### Notes on disk and sensors

**Disk** — `host.disk_used_tb` / `host.disk_total_tb` reflect the path mounted at
`EXPANSION_PATH` inside the container (default `/host/expansion`). Add a read-only
bind mount of your data drive in your compose service and set `EXPANSION_PATH` to
match. If the mount is absent the disk stat returns `null` (widgets show `—`).

**Sensor key names** are hardware-specific. After first startup, run:
```bash
docker compose logs glance | grep "BESZEL raw system_stats"
```
Find the `'t'` field in the logged record and note the key names (e.g.
`nvme_composite`, `amdgpu_edge`). Set `NVME_TEMP_SENSOR` / `GPU_TEMP_SENSOR` in
your `.env` if they differ from the defaults.

---

## Snapshot schema

`GET /api/dashboard` returns:

```json
{
  "generated_at": 1718900000,
  "poll_seconds": 15,
  "host": {
    "status": "up",
    "stale": false,
    "name": "homelab",
    "cpu_pct": 12.4,
    "ram_used_gb": 14.2,
    "ram_total_gb": 32.0,
    "uptime": 864000,
    "disk_used_tb": 5.29,
    "disk_total_tb": 20.01,
    "sensors": {
      "nvme_temp": 49.0,
      "gpu_temp": 52.0,
      "gpu_load_pct": 15.9,
      "gpu_power_w": 4.6,
      "gpu_vram_used_mb": 1853,
      "gpu_vram_total_mb": 18078,
      "nvme_temp_history": [49.85, 50.85, 49.85],
      "gpu_temp_history": [58, 55, 56]
    }
  },
  "cards": [
    {
      "id": "jellyfin",
      "title": "Jellyfin",
      "group": "Media",
      "container_name": "jellyfin",
      "status": "up",
      "stale": false,
      "cpu_pct": 2.1,
      "mem_mb": 1400.0,
      "rx_mbps": 0.003,
      "tx_mbps": 12.4,
      "container_running": true,
      "data": {
        "streams": 1,
        "now_playing": [{"user": "alice", "title": "Dune: Part Two"}]
      }
    },
    {
      "id": "qbittorrent",
      "group": "Acquisition",
      "data": {"dl_mibps": 4.2, "ul_mibps": 0.8, "active": 2, "seeding": 47}
    },
    {
      "id": "sonarr",
      "group": "Acquisition",
      "data": {"queue": 1, "wanted": 3}
    },
    {
      "id": "radarr",
      "group": "Acquisition",
      "data": {"queue": 0, "missing": 12}
    },
    {
      "id": "prowlarr",
      "group": "Acquisition",
      "data": {"queries": 1842, "grabs": 231}
    },
    {
      "id": "pihole",
      "group": "Infrastructure",
      "data": {"queries": 52341, "blocked": 8912, "blocked_pct": 17.0, "gravity": 1632423}
    },
    {
      "id": "mosquitto",
      "group": "Home",
      "container_running": true,
      "data": {}
    },
    {
      "id": "zigbee2mqtt",
      "group": "Home",
      "container_running": true,
      "data": {}
    }
  ]
}
```

`status` is `"up"` | `"down"` | `"pending"` | `"unknown"`. `stale: true` means the
last-good cached value is being shown because the most recent poll failed.

---

## Übersicht widget setup

1. Install [Übersicht](https://tracesof.net/uebersicht/)
2. Copy `ubersicht/glance.jsx` into your Übersicht widgets folder
3. Open that copy and edit the constants at the top:
   ```js
   const AGGREGATOR_URL = "http://YOUR_SERVER_IP:8765/api/dashboard"
   const WIDGET_TOKEN   = "CHANGE_ME"
   const SHOW_LOGO      = true   // set false to hide the brand logo
   ```
4. Save — Übersicht will auto-reload and refresh every 30 s

The widget file lives in the Übersicht folder, which is not a git repo, so
editing these constants directly is safe.

**Logo:** The brand logo is embedded as a base64 data URI (`LOGO_URI`) directly
in the script — no external image file is needed. To swap it for a different
variant, run:
```bash
base64 -i path/to/logo.svg | tr -d '\n'
```
and paste the output into `LOGO_URI` prefixed with `data:image/svg+xml;base64,`.

---

## Scriptable widget setup

1. Install [Scriptable](https://scriptable.app/) on your iPhone
2. Open `scriptable/setup-keychain.js`, fill in `WIDGET_TOKEN` and `AGGREGATOR_URL`,
   then run it once inside Scriptable — this stores both values in the iOS Keychain
3. Copy the contents of `scriptable/glance.js` into a new Scriptable script
4. Optionally edit the logo toggle near the top of the script:
   ```js
   const SHOW_LOGO = true   // set false to hide the brand logo
   ```
5. Add a new Scriptable widget to your home screen, select "Large" size, and choose
   the glance script
6. Delete the setup-keychain.js script from Scriptable (the Keychain entries survive)

**Logo:** The amber logo is embedded as a base64 PNG (`LOGO_PNG_B64`) so the script
is self-contained. To regenerate with a different variant or size:
```bash
sips -Z 120 path/to/logo.png --out /tmp/logo-120.png && base64 -i /tmp/logo-120.png | tr -d '\n'
```
Paste the output into the `LOGO_PNG_B64` constant.

### iOS refresh caveat

`widget.refreshAfterDate` is set to 5 minutes, but **iOS throttles widget refresh
at its own discretion** regardless of the hint — actual cadence may be 15–60 minutes
depending on battery, background app refresh settings, and iOS heuristics. The value
is only a hint, not a guarantee. For real-time data use the Übersicht widget on macOS.

---

## Beszel field-name drift

Beszel's PocketBase schema has changed between versions. On the first successful poll,
the aggregator logs one complete raw `systems` record and one `container_stats` record
at INFO level. Check the container logs after first startup:

```bash
docker compose logs glance | grep "BESZEL raw"
```

If field names differ from what the code expects, update `_parse_host` and
`_parse_containers` in `aggregator/app/pollers/beszel.py`.
