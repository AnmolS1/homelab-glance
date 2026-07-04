"""Unit tests for compute_stats (Docker stats payload → cpu/mem summary)."""
from app.docker_control import compute_stats

MiB = 1024 * 1024


def _payload(
    total=200_000_000,
    pre_total=100_000_000,
    system=2_000_000_000,
    pre_system=1_000_000_000,
    online_cpus=4,
    mem_usage=512 * MiB,
    mem_limit=2048 * MiB,
    mem_stats=None,
):
    return {
        "cpu_stats": {
            "cpu_usage": {"total_usage": total},
            "system_cpu_usage": system,
            "online_cpus": online_cpus,
        },
        "precpu_stats": {
            "cpu_usage": {"total_usage": pre_total},
            "system_cpu_usage": pre_system,
        },
        "memory_stats": {
            "usage": mem_usage,
            "limit": mem_limit,
            "stats": mem_stats if mem_stats is not None else {},
        },
    }


def test_normal_payload():
    out = compute_stats(_payload())
    # (100e6 / 1e9) * 4 cpus * 100 = 40.0%
    assert out["cpu_pct"] == 40.0
    assert out["mem_used_mb"] == 512.0
    assert out["mem_limit_mb"] == 2048.0


def test_zero_system_delta_yields_no_cpu():
    out = compute_stats(_payload(system=1_000_000_000, pre_system=1_000_000_000))
    assert out["cpu_pct"] is None
    assert out["mem_used_mb"] == 512.0


def test_one_shot_style_empty_precpu():
    p = _payload()
    p["precpu_stats"] = {}  # one-shot=true leaves precpu zeroed/empty
    out = compute_stats(p)
    assert out["cpu_pct"] is None


def test_cgroup_v2_subtracts_inactive_file():
    out = compute_stats(_payload(mem_usage=512 * MiB, mem_stats={"inactive_file": 128 * MiB}))
    assert out["mem_used_mb"] == 384.0


def test_cgroup_v1_subtracts_cache():
    out = compute_stats(_payload(mem_usage=512 * MiB, mem_stats={"cache": 64 * MiB}))
    assert out["mem_used_mb"] == 448.0


def test_percpu_fallback_when_online_cpus_missing():
    p = _payload()
    del p["cpu_stats"]["online_cpus"]
    p["cpu_stats"]["cpu_usage"]["percpu_usage"] = [1, 2]  # 2 cpus
    out = compute_stats(p)
    # (100e6 / 1e9) * 2 * 100 = 20.0%
    assert out["cpu_pct"] == 20.0


def test_empty_payload_is_all_none():
    out = compute_stats({})
    assert out == {"cpu_pct": None, "mem_used_mb": None, "mem_limit_mb": None}
