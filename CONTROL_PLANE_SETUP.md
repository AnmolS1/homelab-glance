# Docker Control Plane — server-side setup & handoff

Finish wiring the native app's Docker control plane (start/stop/restart from the app).
**Run this from a session ON `discofin-server`** — not through the Mac's SMB mount of
`/mnt/expansion` (that path corrupts writes; see "The blocker" below).

## Current state (already done — don't redo)
- **`homelab-glance` repo** (this Mac, branch `dev`, ~3 commits unpushed): the aggregator
  control plane exists — `aggregator/app/docker_control.py` + `/api/docker/*` routes in
  `main.py` + config in `config.py`. Endpoints:
  - `GET  /api/docker/containers` — list (auth: `Authorization: Bearer <WIDGET_TOKEN>`)
  - `GET  /api/docker/{name}/logs?tail=200` — logs (Bearer)
  - `POST /api/docker/{name}/{start|stop|restart}` — write (Bearer **and** `X-Control-Token: <CONTROL_TOKEN>`)
  - `GET  /api/docker/audit` — audit trail (Bearer)
  - Allowlist: never controls `dockerproxy,caddy,cloudflared,glance` (`DOCKER_PROTECTED`).
- **`discofin-server` repo** (uncommitted edits in `/mnt/expansion/docker`):
  - `docker-compose.yml` → `glance.environment` now includes
    `DOCKER_PROXY_URL=http://dockerproxy:2375` and `CONTROL_TOKEN=${CONTROL_TOKEN}`.
  - The vendored aggregator copy (`homelab-glance/aggregator/app/`) was synced to include
    the control-plane code (it predated it). Verified byte-identical to the upstream
    aggregator + control plane.
  - `dockerproxy` already has `CONTAINERS=1 POST=1 EXEC=0`, no published port, and is on the
    same `docker_default` network as `glance` → `http://dockerproxy:2375` resolves. ✓

## The blocker — `.env` corruption on exFAT/SMB
`/mnt/expansion` is an **exFAT/NTFS external drive shared over SMB**. Writes to `.env`
through that path land as **NUL bytes** (observed: an appended `CONTROL_TOKEN=` line became
79 `0x00` bytes; the file accumulated 200+ nulls). `lsattr` fails ("Operation not supported")
and editors (vim) produce garbage — all symptoms of the same fs/transport issue. `docker
compose` still runs only because the read-path `KEY=VALUE` lines happen to be intact between
the nulls. **`CONTROL_TOKEN` is NOT actually in `.env` yet**, and at least one secret value
has an embedded NUL (likely clobbered).

## Steps (on the server, native filesystem, Docker available)
1. **Confirm the damage locally** (native path, not via SMB):
   ```sh
   tr -cd '\000' < /mnt/expansion/docker/.env | wc -c    # >0 = corrupted
   ```
2. **Recreate `.env` clean.** Strongly prefer the server's **native ext4 system disk**, not the
   exFAT expansion drive (exFAT is the root cause; it shouldn't hold Docker secrets/bind config).
   - If moving it: keep it in the compose project dir (Compose loads `.env` from there for
     `${VAR}` substitution); relocate the compose project to ext4, or use an absolute
     `env_file:` path on ext4.
   - Rebuild the file with stream tools only (never vim on exFAT):
     `tr -d '\000' < .env > .env.clean` as a starting point, then **verify every secret value**
     — `.env.bak.*` is also corrupted, so reconstruct affected values from your password manager.
   - Add the freshly-regenerated token: `printf 'CONTROL_TOKEN=%s\n' '<token>' >> .env`
   - Re-verify: `tr -cd '\000' < .env | wc -c` → **0**, and `grep -c '^WIDGET_TOKEN=' .env` → 1,
     `grep -c '^CONTROL_TOKEN=' .env` → 1.
3. **Rebuild glance** (must `--build` — a plain restart reuses the old image without the endpoints):
   ```sh
   docker compose up -d --build glance
   docker logs glance --tail 30        # no env/parse errors
   ```
4. **Verify reads** (no control token needed):
   ```sh
   curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer <WIDGET_TOKEN>" \
     http://localhost:8765/api/docker/containers           # 200 expected (503 = proxy/env, 502 = proxy flags)
   ```
   The app's control screen should now list containers.
5. **Verify writes** (the actual control path) — restart a safe service and check the audit:
   ```sh
   curl -s -X POST -H "Authorization: Bearer <WIDGET_TOKEN>" -H "X-Control-Token: <CONTROL_TOKEN>" \
     http://localhost:8765/api/docker/sonarr/restart        # {"ok":true,...}
   curl -s -H "Authorization: Bearer <WIDGET_TOKEN>" http://localhost:8765/api/docker/audit
   ```
   Or do it from the app (Control screen → ••• → Restart → confirm) and watch the audit list.
6. **Commit** the `discofin-server` changes (`docker-compose.yml` + the synced aggregator files).

## Notes
- The control token in the prior chat was **regenerated** — use the new value only.
- App side: Settings → CONTROL_TOKEN (Keychain). Base URL is the server root
  (`http://discofin-server.tail40f2e5.ts.net:8765`), no `/api/...` path.
- Long term: move the Docker stack's config + secrets off exFAT onto native ext4 to stop the
  corruption recurring.
