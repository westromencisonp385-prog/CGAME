"""Load Weaver credentials without storing secrets in the repository."""

from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _parse(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        delimiter = ":" if ":" in line and "=" not in line.split(":", 1)[0] else "="
        if delimiter not in line:
            continue
        key, value = line.split(delimiter, 1)
        values[key.strip().upper().replace(" ", "_")] = value.strip()
    return values


def _credential_paths() -> list[Path]:
    configured = os.environ.get("WEAVER_CREDENTIALS_FILE")
    if configured:
        return [Path(configured)]
    return [
        Path.home() / ".config" / "wanderberg" / "weaver-credentials.txt",
        ROOT / "config" / "weaver-credentials.local.txt",
        Path(r"D:\工作\AI工具\ComfyUI\appid.txt"),
    ]


def load_credentials() -> tuple[str | None, str | None, str | None, str | None]:
    """Return app id, secret, rtx and base URL, preferring environment variables."""

    values: dict[str, str] = {}
    for path in _credential_paths():
        if path.is_file():
            values = _parse(path)
            break
    app_id = os.environ.get("WEAVER_APPID") or values.get("APPID") or values.get("APP_ID")
    secret = (
        os.environ.get("WEAVER_APPSECRET")
        or values.get("APP_SECRET")
        or values.get("APPSECRET")
        or values.get("KEY")
    )
    rtx = os.environ.get("WEAVER_RTX") or values.get("RTX") or os.environ.get("USERNAME") or "jasonlyan"
    base_url = os.environ.get("WEAVER_BASE_URL") or values.get("BASE_URL") or "https://ws.visvise.com.cn/openapi"
    return app_id, secret, rtx, base_url


def require_credentials() -> tuple[str, str, str, str]:
    app_id, secret, rtx, base_url = load_credentials()
    if not app_id or not secret:
        raise RuntimeError(
            "Weaver credentials not found. Set WEAVER_APPID/WEAVER_APPSECRET or "
            "create ~/.config/wanderberg/weaver-credentials.txt from the example."
        )
    return app_id, secret, rtx or "jasonlyan", base_url
