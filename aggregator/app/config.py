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


settings = Settings()
