# Homelab Glance — native app (`ios/`)

A multiplatform SwiftUI app + WidgetKit (iOS / iPadOS / macOS) that monitors **and
controls** the homelab, in the **ponderance blueprint** theme. Reuses the existing
FastAPI aggregator for reads and its Docker control endpoints for writes.

## Features

- **Dashboard** — full blueprint reproduction of the Übersicht/Scriptable views:
  host header, Media/Acquisition/Infrastructure/Home groups, sensors with sparklines,
  stale/down dimming, live polling. Mock-data mode builds with no server.
- **Widgets** — Home Screen small (health + disk) / medium (key cards) / large (full
  condensed dashboard), Lock Screen accessories (inline/circular/rectangular), and the
  same large widget on **macOS** (Notification Center / desktop — replaces Übersicht).
  They read a shared snapshot from the App Group and refresh on their own timeline.
- **Control plane** — container list with state, logs viewer, and guarded
  start/stop/restart (confirmation + audit trail). Protected containers
  (dockerproxy/caddy/cloudflared/glance) are never controllable.
- **Live Activity** — qBittorrent download progress on the Lock Screen / Dynamic Island.
- **iOS 18 Control** — a Control Center / Lock Screen button to restart a service via an
  App Intent, no app launch.

## Layout

| Path | What |
|------|------|
| `project.yml` | XcodeGen spec — app + `GlanceKit` framework + widget ext + tests |
| `GlanceKit/` | Shared: models, networking (dashboard + Docker control), theme, settings, cache, views, Live Activity attributes |
| `App/` | Dashboard, control UI, settings, view models, Live Activity controller |
| `Widgets/` | Widget bundle, timeline provider, widget views, Live Activity UI, Control widget + App Intent |
| `GlanceKitTests/` | Model decoding + URL normalization tests |

The `.xcodeproj` is **generated** — edit `project.yml` and sources, run `xcodegen generate`.

## Build & run

```sh
brew install xcodegen
cd ios && xcodegen generate

xcodebuild test  -scheme GlanceKit   -destination 'platform=macOS'
xcodebuild       -scheme HomelabGlance -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Or open `HomelabGlance.xcodeproj` in Xcode and run. The app launches in **mock mode**
(bundled sample data) — toggle it off in **Settings** and enter your aggregator base URL
+ tokens to go live.

### Connecting to your aggregator (Settings)

- **Base URL** — the server root, e.g. `http://server.tailnet.ts.net:8765` (no
  `/api/dashboard` path needed; the app appends it. A pasted full URL is normalized).
- **WIDGET_TOKEN** — the aggregator's `WIDGET_TOKEN` (same one the web widgets use).
- **CONTROL_TOKEN** — only needed for start/stop/restart; the aggregator's `CONTROL_TOKEN`.

## Manual steps

- **Signing (Xcode):** the app uses automatic signing. Set `DEVELOPMENT_TEAM` in
  `project.yml` to your **10-character Team ID** (e.g. `9YAPRQQQXB` — find it via
  `security find-identity -p codesigning -v`, shown in parentheses), *not* your name,
  so signed device/macOS builds and the App Group provision correctly.
- **macOS widget:** widgets live in **Notification Center** (click the menu-bar clock →
  Edit Widgets), and on Sonoma+ can be dragged to the desktop. Launch the app once so
  macOS registers the extension; for stable registration run it from `/Applications`.
- **Control plane (server):** enable the minimal `dockerproxy` flags `CONTAINERS=1`,
  `POST=1`, keep `EXEC=0`; set `DOCKER_PROXY_URL` + `CONTROL_TOKEN` in the aggregator
  `.env` (see repo `.env.example` / `docker-compose.snippet.yml`). Treat `CONTROL_TOKEN`
  like a root password and keep the API behind Tailscale/Tunnel.
- **Live Activity / push:** foreground updates work out of the box; ActivityKit **push**
  updates from the aggregator are a stretch goal (not implemented).
- **App Store Support URL — set it on every platform, before the version ships.**
  Use `https://ponderance.dev/support/homelab-glance/` (keep the trailing slash;
  the bare path 307s), not the GitHub repo. `supportUrl` belongs to each
  *version localization*, not to the app, so the platforms drift independently:
  as of 2026-07-31 iOS 1.2 was correct while macOS 1.2 still pointed at GitHub.
  There is no fixing it afterwards — `PATCH /v1/appStoreVersionLocalizations/{id}`
  on a `READY_FOR_SALE` version returns `409 STATE_ERROR — "Attribute
  'supportUrl' cannot be edited at this time"`. (`STORE.md` has the full metadata
  table but is gitignored here, since this repo tracks only READMEs.)

## Notes

- Deployment targets iOS 17 / macOS 14; the iOS 18 Control is gated by availability.
- ATS allows plain HTTP only to `*.ts.net` (Tailscale); use HTTPS for Cloudflare Access.
- Fonts (Bricolage Grotesque, Hanken Grotesk, IBM Plex Mono — OFL) are bundled in
  `GlanceKit/Resources/Fonts/` with a system-font fallback.
