"""Thread-safe (asyncio) in-memory snapshot store.

The background poll loop writes via set_snapshot(); the API endpoint reads via
get_snapshot(). Both hold the same asyncio.Lock, so there is never a torn read.
"""
import asyncio
from typing import Any, Dict, Optional

_lock = asyncio.Lock()
_snapshot: Optional[Dict[str, Any]] = None


async def get_snapshot() -> Optional[Dict[str, Any]]:
	async with _lock:
		return _snapshot


async def set_snapshot(snap: Dict[str, Any]) -> None:
	global _snapshot
	async with _lock:
		_snapshot = snap
