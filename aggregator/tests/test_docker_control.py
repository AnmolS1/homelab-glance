"""Tests for the Docker control plane — allowlist, log demux, proxy client, and
the API auth guards. The proxy is mocked with httpx.MockTransport; no real
docker-socket-proxy or network is touched."""
import asyncio

import httpx
import pytest
from fastapi.testclient import TestClient

from app import docker_control as dc
from app.config import settings
from app.main import app


def _client(handler):
	return httpx.AsyncClient(transport=httpx.MockTransport(handler))


# ── allowlist ───────────────────────────────────────────────────────────────

def test_is_controllable_protected(monkeypatch):
	monkeypatch.setattr(settings, "docker_protected", "dockerproxy,caddy,cloudflared,glance")
	monkeypatch.setattr(settings, "docker_control_allowlist", "")
	assert dc.is_controllable("sonarr") is True
	assert dc.is_controllable("dockerproxy") is False
	assert dc.is_controllable("caddy") is False


def test_is_controllable_allowlist(monkeypatch):
	monkeypatch.setattr(settings, "docker_protected", "dockerproxy")
	monkeypatch.setattr(settings, "docker_control_allowlist", "sonarr,radarr")
	assert dc.is_controllable("sonarr") is True
	assert dc.is_controllable("jellyfin") is False        # not in allowlist
	assert dc.is_controllable("dockerproxy") is False      # protected overrides


# ── log demux ─────────────────────────────────────────────────────────────--

def test_demux_framed():
	payload = b"hello world\n"
	frame = b"\x01\x00\x00\x00" + len(payload).to_bytes(4, "big") + payload
	assert dc._demux(frame) == "hello world\n"


def test_demux_raw_passthrough():
	assert dc._demux(b"plain tty output") == "plain tty output"


# ── proxy client ─────────────────────────────────────────────────────────────

def test_list_containers(monkeypatch):
	monkeypatch.setattr(settings, "docker_proxy_url", "http://dockerproxy:2375")
	monkeypatch.setattr(settings, "docker_protected", "dockerproxy")
	monkeypatch.setattr(settings, "docker_control_allowlist", "")

	def handler(request):
		assert request.url.path == "/containers/json"
		assert request.url.params.get("all") == "true"
		return httpx.Response(200, json=[
			{"Id": "abc123def456789", "Names": ["/sonarr"], "Image": "linuxserver/sonarr",
			 "State": "running", "Status": "Up 2 hours"},
			{"Id": "deadbeef", "Names": ["/dockerproxy"], "Image": "tecnativa/docker-socket-proxy",
			 "State": "running", "Status": "Up"},
		])

	async def run():
		async with _client(handler) as c:
			return await dc.DockerProxyClient(c).list_containers()

	out = asyncio.run(run())
	assert out[0]["name"] == "sonarr"
	assert out[0]["id"] == "abc123def456"
	assert out[0]["controllable"] is True
	assert out[1]["name"] == "dockerproxy"
	assert out[1]["controllable"] is False


def test_action_ok_audits(monkeypatch):
	monkeypatch.setattr(settings, "docker_proxy_url", "http://dockerproxy:2375")
	monkeypatch.setattr(settings, "docker_protected", "dockerproxy")
	monkeypatch.setattr(settings, "docker_control_allowlist", "")
	calls = []

	def handler(request):
		calls.append((request.method, request.url.path))
		return httpx.Response(204)

	async def run():
		async with _client(handler) as c:
			return await dc.DockerProxyClient(c).action("sonarr", "restart", actor="test")

	entry = asyncio.run(run())
	assert calls == [("POST", "/containers/sonarr/restart")]
	assert entry["result"] == "ok"
	assert dc.audit_entries()[0]["container"] == "sonarr"


def test_action_denied_for_protected(monkeypatch):
	monkeypatch.setattr(settings, "docker_proxy_url", "http://dockerproxy:2375")
	monkeypatch.setattr(settings, "docker_protected", "dockerproxy")

	async def run():
		async with _client(lambda r: httpx.Response(204)) as c:
			await dc.DockerProxyClient(c).action("dockerproxy", "stop")

	with pytest.raises(dc.DockerControlError) as exc:
		asyncio.run(run())
	assert exc.value.status == 403


def test_action_rejects_invalid_verb(monkeypatch):
	monkeypatch.setattr(settings, "docker_proxy_url", "http://dockerproxy:2375")

	async def run():
		async with _client(lambda r: httpx.Response(204)) as c:
			await dc.DockerProxyClient(c).action("sonarr", "exec")

	with pytest.raises(dc.DockerControlError) as exc:
		asyncio.run(run())
	assert exc.value.status == 400


# ── API auth guards ───────────────────────────────────────────────────────--

def test_containers_requires_token(monkeypatch):
	monkeypatch.setattr(settings, "widget_token", "secret")
	c = TestClient(app)
	assert c.get("/api/docker/containers").status_code == 401


def test_containers_503_when_proxy_unset(monkeypatch):
	monkeypatch.setattr(settings, "widget_token", "secret")
	monkeypatch.setattr(settings, "docker_proxy_url", "")
	c = TestClient(app)
	r = c.get("/api/docker/containers", headers={"Authorization": "Bearer secret"})
	assert r.status_code == 503


def test_write_requires_control_token(monkeypatch):
	monkeypatch.setattr(settings, "widget_token", "secret")
	monkeypatch.setattr(settings, "control_token", "ctl")
	c = TestClient(app)
	# valid widget token but missing X-Control-Token → 403
	r = c.post("/api/docker/sonarr/restart", headers={"Authorization": "Bearer secret"})
	assert r.status_code == 403
