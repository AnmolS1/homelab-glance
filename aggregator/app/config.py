"""Environment-driven settings. All values must be provided via environment variables."""
import os


class Settings:
	# Beszel (PocketBase hub) — BESZEL_USER must be the account email address
	beszel_url: str = os.getenv("BESZEL_URL", "")
	beszel_user: str = os.getenv("BESZEL_USER", "")
	beszel_password: str = os.getenv("BESZEL_PASSWORD", "")

	# Jellyfin
	jellyfin_url: str = os.getenv("JELLYFIN_URL", "")
	jellyfin_key: str = os.getenv("JELLYFIN_KEY", "")

	# qBittorrent (exposed via gluetun on port 8080)
	qbit_url: str = os.getenv("QBIT_URL", "")
	qbit_username: str = os.getenv("QBIT_USERNAME", "")
	qbit_password: str = os.getenv("QBIT_PASSWORD", "")

	# Pi-hole v6 (host-network, FTLCONF_webserver_port=8880)
	pihole_url: str = os.getenv("PIHOLE_URL", "")
	pihole_password: str = os.getenv("PIHOLE_WEBUI_PASSWORD", "")

	# Sonarr
	sonarr_url: str = os.getenv("SONARR_URL", "")
	sonarr_api_key: str = os.getenv("SONARR_API_KEY", "")

	# Radarr
	radarr_url: str = os.getenv("RADARR_URL", "")
	radarr_api_key: str = os.getenv("RADARR_API_KEY", "")

	# Prowlarr
	prowlarr_url: str = os.getenv("PROWLARR_URL", "")
	prowlarr_api_key: str = os.getenv("PROWLARR_API_KEY", "")

	# App
	poll_seconds: int = int(os.getenv("POLL_SECONDS", "15"))
	widget_token: str = os.getenv("WIDGET_TOKEN", "")

	# Docker control plane (optional) — via tecnativa/docker-socket-proxy.
	# Leave DOCKER_PROXY_URL empty to disable the control endpoints entirely.
	docker_proxy_url: str = os.getenv("DOCKER_PROXY_URL", "")          # e.g. http://dockerproxy:2375
	control_token: str = os.getenv("CONTROL_TOKEN", "")               # required for writes (start/stop/restart)
	# If set (comma-separated), ONLY these container names may be controlled.
	# If empty, all containers may be controlled EXCEPT the protected set below.
	docker_control_allowlist: str = os.getenv("DOCKER_CONTROL_ALLOWLIST", "")
	# Never controllable, regardless of allowlist (don't let it stop its own plumbing).
	docker_protected: str = os.getenv("DOCKER_PROTECTED", "dockerproxy,caddy,cloudflared,glance")
	# Optional file to append a JSON-lines audit record for every write.
	audit_log_path: str = os.getenv("AUDIT_LOG_PATH", "")

	# Expansion disk — read via read-only bind mount into the container
	expansion_path: str = os.getenv("EXPANSION_PATH", "/host/expansion")

	# Sensor key names (hardware-specific; check logs after first startup:
	#   docker compose logs glance | grep "BESZEL raw system_stats"
	# then match against the 't' field keys in the logged record)
	nvme_temp_sensor: str = os.getenv("NVME_TEMP_SENSOR", "nvme_composite")
	gpu_temp_sensor: str = os.getenv("GPU_TEMP_SENSOR", "amdgpu_edge")
	temp_history_len: int = int(os.getenv("TEMP_HISTORY_LEN", "30"))


settings = Settings()
