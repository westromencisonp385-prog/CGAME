"""Small, offline-testable helpers shared by the Weaver production scripts.

The helpers deliberately keep credentials and signed URLs out of logs.  Network
requests still happen only when a caller invokes a ``WeaverClient`` method.
"""

from __future__ import annotations

import hashlib
import time
from pathlib import Path
from typing import Any


def cos_object_name(credential: Any, suffix: str) -> str:
    """Place a caller supplied suffix below the temporary COS path prefix."""

    prefix = str(credential.path_prefix).rstrip("/")
    clean_suffix = str(suffix).lstrip("/")
    if clean_suffix == prefix or clean_suffix.startswith(prefix + "/"):
        return clean_suffix
    return f"{prefix}/{clean_suffix}"


def first_model_id(response: Any) -> str:
    """Return the first ID from the standard client's list response.

    Accepting a mapping as well keeps the helper useful with recorded responses
    from the old SDK while the production scripts use ``list[str]`` directly.
    """

    if isinstance(response, str):
        return response
    if isinstance(response, (list, tuple)):
        return str(response[0]) if response else ""
    if isinstance(response, dict):
        data = response.get("data") if isinstance(response.get("data"), dict) else response
        value = data.get("model_id") or (data.get("model_ids") or [""])[0]
        return str(value)
    return ""


def wait_for_model(client: Any, model_id: str, *, rtx: str,
                   timeout: float = 1200, interval: float = 15) -> dict[str, Any]:
    """Poll one model ID and retain the documented failure reason."""

    if not model_id:
        raise ValueError("model_id is required")
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        rows, _ = client.get_model_list(model_id_list=[model_id], limit=20, rtx=rtx)
        if rows:
            model = rows[0]
            status = model.get("status")
            if status == 3:
                return model
            if status == 4:
                reason = model.get("failed_reason") or model.get("msg") or "task failed"
                raise RuntimeError(f"model {model_id} failed: {reason!s}"[:500])
        time.sleep(interval)
    raise TimeoutError(f"model {model_id} did not finish before timeout")


def output_urls(record: dict[str, Any]) -> list[str]:
    """Extract terminal artifact URLs from a documented model record.

    LOD and text-to-motion expose nested candidate files, while regular nodes
    use ``output_model``.  The order is stable and duplicates are removed.
    """

    urls: list[str] = []

    def add(value: Any) -> None:
        if isinstance(value, str) and value and value not in urls:
            urls.append(value)

    lod = record.get("lod_output") or {}
    if isinstance(lod, dict):
        for item in lod.get("lod_files") or []:
            if isinstance(item, dict):
                add(item.get("download_url") or item.get("output_model"))
        add(lod.get("zip_file"))

    framing = record.get("framing_ai_output") or {}
    if isinstance(framing, dict):
        for item in framing.get("text2_motion_result") or []:
            if isinstance(item, dict):
                add(item.get("output_model"))

    add(record.get("output_model"))
    return urls


def output_urls_or_download(client: Any, record: dict[str, Any], model_id: str,
                            *, rtx: str) -> list[str]:
    """Use fresh signed output URL fallback when a response omits one."""

    urls = output_urls(record)
    if urls:
        return urls
    signed = client.download_model(model_id=model_id, rtx=rtx)
    return [signed] if isinstance(signed, str) and signed else []


def download_metadata(client: Any, url: str, destination: str | Path) -> dict[str, Any]:
    """Download through the standard client and return non-sensitive metadata."""

    path = client.download_file(url, destination)
    return {
        "path": str(path),
        "bytes": path.stat().st_size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }
