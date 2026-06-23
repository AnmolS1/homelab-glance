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
    "disk_used_tb": 2.31,
    "disk_total_tb": 7.28
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
2. Create your secrets file (keep it outside this repo so it is never committed):
   ```bash
   mkdir -p ~/.config/homelab-glance
   cp ubersicht/glance.secrets.env.example ~/.config/homelab-glance/secrets.env
   $EDITOR ~/.config/homelab-glance/secrets.env
   # Set WIDGET_TOKEN and AGGREGATOR_URL
   ```
3. Copy `ubersicht/glance.jsx` into your Übersicht widgets folder
4. Übersicht will auto-load and refresh every 30 s

The widget sources `~/.config/homelab-glance/secrets.env` at shell time so
secrets never live in the widget file itself.

---

## Scriptable widget setup

1. Install [Scriptable](https://scriptable.app/) on your iPhone
2. Open `scriptable/setup-keychain.js`, fill in `WIDGET_TOKEN` and `AGGREGATOR_URL`,
   then run it once inside Scriptable — this stores both values in the iOS Keychain
3. Copy the contents of `scriptable/glance.js` into a new Scriptable script
4. Add a new Scriptable widget to your home screen, select "Large" size, and choose
   the glance script
5. Delete the setup-keychain.js script from Scriptable (the Keychain entries survive)

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
