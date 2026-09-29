"""Live Weaver checks for 2D preprocessing, segmentation, editing, and mid-model inputs.

This script intentionally records only non-sensitive evidence. It reads the local
credential file through ``weaver_credentials`` and never writes credentials or
signed URLs to the repository.
"""

from __future__ import annotations

import base64
import hashlib
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / ".agents" / "skills" / "weaver-asset-production" / "scripts"))

from weaver_api_client import WeaverAPIError, WeaverClient  # noqa: E402
from weaver_asset_helpers import cos_object_name, download_metadata, first_model_id, output_urls_or_download, wait_for_model  # noqa: E402
from weaver_credentials import require_credentials  # noqa: E402

OUT = ROOT / "artifacts" / "weaver" / "capability-study" / "2d"
REPORT = OUT / "report.json"

SAMPLES = {
    "N01": {
        "image": ROOT / "docs/assets/comic-whale-v1/N01-hydraulic-barricade-crab.png",
        "model_id_360": "Model2026092800610042",
    },
    "E02": {
        "image": ROOT / "docs/assets/comic-whale-v1/E02-polarity-ring-hunter.png",
        "model_id_360": "Model2026092800610047",
    },
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def safe_url(url: Any) -> str | None:
    if not isinstance(url, str) or not url:
        return None
    parsed = urllib.parse.urlsplit(url)
    path = re.sub(r"/user-[^/]+/", "/user-redacted/", parsed.path)
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, path, "", ""))


def safe_value(value: Any) -> Any:
    """Drop query signatures and large binary masks from saved responses."""
    if isinstance(value, str):
        if value.startswith(("http://", "https://")):
            return {"url": safe_url(value), "temporary_query_dropped": "?" in value}
        if len(value) > 8192:
            return {"length": len(value), "sha256": hashlib.sha256(value.encode()).hexdigest()}
        return value
    if isinstance(value, dict):
        return {str(k): safe_value(v) for k, v in value.items() if k not in {"mask_image", "paint_mask"}}
    if isinstance(value, list):
        return [safe_value(v) for v in value]
    return value


def load_report() -> dict[str, Any]:
    if REPORT.is_file():
        try:
            return json.loads(REPORT.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            pass
    return {
        "schema_version": 1,
        "purpose": "live Weaver 2D API capability study; outputs remain candidates",
        "samples": {},
        "algorithms": {},
        "notes": [
            "Credentials are local only; signed URLs are downloaded immediately and removed from evidence.",
            "A successful API response proves the endpoint accepted the schema, not game-ready quality.",
        ],
    }


def persist(report: dict[str, Any]) -> None:
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")


def record_error(row: dict[str, Any], stage: str, exc: Exception) -> None:
    data: dict[str, Any] = {"type": type(exc).__name__, "message": str(exc)[:500]}
    if isinstance(exc, WeaverAPIError):
        data.update({"code": exc.code, "req_id": exc.req_id})
    row.setdefault("errors", {})[stage] = data


def sse_segment(client: WeaverClient, *, payload: dict[str, Any], rtx: str) -> dict[str, Any]:
    """Call init_segment and collect all SSE frames, returning the reply data."""
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    headers = client._headers("POST", body, rtx)
    headers["Accept"] = "text/event-stream"
    headers["Cache-Control"] = "no-cache"
    req = urllib.request.Request(
        client.base_url + "/weaver/component/init_segment",
        data=body,
        headers=headers,
        method="POST",
    )
    frames: list[dict[str, Any]] = []
    event: str | None = None
    data_lines: list[str] = []

    def consume() -> dict[str, Any] | None:
        nonlocal event, data_lines
        if not event and not data_lines:
            return None
        raw = "\n".join(data_lines)
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            data = raw
        frame = {"event": event or "message", "data": data}
        frames.append(frame)
        event, data_lines = None, []
        return frame

    with client.opener(req, timeout=180) as response:
        for raw_line in response:
            line = raw_line.decode("utf-8", errors="replace").rstrip("\r\n")
            if not line:
                frame = consume()
                if frame and frame["event"] in {"reply", "error"}:
                    break
                continue
            if line.startswith("event:"):
                event = line[6:].strip()
            elif line.startswith("data:"):
                data_lines.append(line[5:].lstrip())
                # Some deployments keep the HTTP stream open after the reply
                # frame and omit the trailing blank line.  Parse the terminal
                # frame as soon as its data arrives so the caller cannot hang.
                if event == "reply":
                    consume()
                    break
        consume()

    reply = next((f for f in reversed(frames) if f["event"] == "reply"), None)
    error = next((f for f in reversed(frames) if f["event"] == "error"), None)
    if error:
        detail = error["data"] if isinstance(error["data"], dict) else {"message": error["data"]}
        raise RuntimeError(f"init_segment error: {detail}")
    if not reply:
        raise RuntimeError(f"init_segment ended without reply; events={[f['event'] for f in frames]}")
    return {"frames": frames, "reply": reply["data"]}


def view_data(reply: dict[str, Any]) -> dict[str, Any]:
    """Normalize old/new reply shapes to the fields used by downstream calls."""
    if "segment_output" in reply:
        return reply["segment_output"]
    return reply


def components(reply: dict[str, Any]) -> list[dict[str, Any]]:
    output = view_data(reply)
    main = output.get("main_view") or output.get("main_view_data") or output
    if isinstance(main, dict):
        segment = main.get("segment_data") or main
        values = segment.get("components") if isinstance(segment, dict) else None
        return [v for v in (values or []) if isinstance(v, dict) and v.get("label") is not None]
    return []


def find_client_id(reply: dict[str, Any]) -> str:
    for key in ("client_id",):
        if reply.get(key):
            return str(reply[key])
    for key in ("main_view_data", "main_view"):
        value = reply.get(key)
        if isinstance(value, dict) and value.get("client_id"):
            return str(value["client_id"])
    return ""


def call(client: WeaverClient, path: str, payload: dict[str, Any], *, rtx: str) -> Any:
    return client.request(path, payload, rtx=rtx)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    app_id, secret, rtx, base_url = require_credentials()
    client = WeaverClient(app_id, secret, base_url, timeout=180)
    report = load_report()
    report["started_at"] = report.get("started_at") or time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    persist(report)

    # Confirm the algorithm names used by the 2D and mid-model branches.
    for node_type in (11, 14, 16):
        key = str(node_type)
        if key not in report["algorithms"]:
            try:
                report["algorithms"][key] = {"status": "success", "models": client.list_algorithm_model(node_type=node_type, rtx=rtx)}
            except Exception as exc:  # noqa: BLE001 - keep the ledger useful
                report["algorithms"][key] = {"status": "error", "error": str(exc)[:500]}
            persist(report)

    credential = client.get_cos_cred(rtx=rtx)
    for asset_id, sample in SAMPLES.items():
        image = Path(sample["image"])
        row = report["samples"].setdefault(asset_id, {"input": str(image), "input_sha256": sha(image), "model_id_360": sample["model_id_360"]})
        row.setdefault("preprocess", {})
        live_result_urls: dict[str, str] = {}
        try:
            if "source_url" not in row:
                source = client.upload_file(image, credential, object_name=cos_object_name(credential, f"cgame/2d-study/{asset_id}.png"))
                row["source_url"] = safe_url(source)
                row["source_uploaded"] = True
                persist(report)
            else:
                source = client.upload_file(image, credential, object_name=cos_object_name(credential, f"cgame/2d-study/{asset_id}-repeat.png"))
        except Exception as exc:
            record_error(row, "upload", exc)
            persist(report)
            continue

        # Background removal, all four documented style presets, and pattern removal.
        if "remove_background" not in row["preprocess"]:
            try:
                result = call(client, "weaver/resource/remove_background", {"image_url": source}, rtx=rtx)
                url = result.get("image_url") if isinstance(result, dict) else None
                destination = OUT / asset_id / "remove_background.png"
                if url:
                    row["preprocess"]["remove_background"] = {"status": "success", "output": download_metadata(client, url, destination)}
                else:
                    row["preprocess"]["remove_background"] = {"status": "success", "response": safe_value(result)}
            except Exception as exc:
                record_error(row, "remove_background", exc)
            persist(report)

        styles = row["preprocess"].setdefault("styles", {})
        for style_type in (1, 2, 3, 4):
            key = str(style_type)
            if key in styles:
                continue
            try:
                result = call(client, "weaver/resource/style_transfer", {"input_view": source, "style_type": style_type}, rtx=rtx)
                url = result.get("result_image") if isinstance(result, dict) else None
                destination = OUT / asset_id / f"style_{style_type}.png"
                if url:
                    live_result_urls[f"style_{style_type}"] = url
                styles[key] = {"style_type": style_type, "status": "success", "output": download_metadata(client, url, destination) if url else {"response": safe_value(result)}}
            except Exception as exc:
                record_error(row, f"style_{style_type}", exc)
            persist(report)

        if "pattern_remove" not in row["preprocess"]:
            try:
                result = call(client, "weaver/resource/patter_auto_remove", {"input_view": source}, rtx=rtx)
                url = result.get("result_image") if isinstance(result, dict) else None
                destination = OUT / asset_id / "pattern_removed.png"
                if url:
                    live_result_urls["pattern_remove"] = url
                row["preprocess"]["pattern_remove"] = {"status": "success", "output": download_metadata(client, url, destination) if url else {"response": safe_value(result)}}
            except Exception as exc:
                record_error(row, "pattern_remove", exc)
            persist(report)

        # Persist one stylized and one pattern-removed node_type=16 asset per sample.
        saved = row["preprocess"].setdefault("saved_assets", {})
        for kind, preprocess_type, param_key, result_name in (
            ("style_4", 1, "style_param", "style_4"),
            ("pattern_remove", 2, "remove_pattern_param", "pattern_removed"),
        ):
            if kind in saved:
                continue
            source_record = styles.get("4") if kind == "style_4" else row["preprocess"].get("pattern_remove")
            try:
                result_image = live_result_urls.get(kind)
                # The API explicitly requires the signed result_image returned
                # by the immediately preceding preprocessing call. If this
                # process is resumed, obtain a fresh URL before saving.
                if not result_image:
                    if kind == "style_4":
                        fresh = call(client, "weaver/resource/style_transfer", {"input_view": source, "style_type": 4}, rtx=rtx)
                    else:
                        fresh = call(client, "weaver/resource/patter_auto_remove", {"input_view": source}, rtx=rtx)
                    result_image = fresh.get("result_image") if isinstance(fresh, dict) else None
                if not result_image:
                    raise RuntimeError("preprocess endpoint returned no result_image")
                payload: dict[str, Any] = {
                    "name": f"CGAME_{asset_id}_{result_name}",
                    "input_view": source,
                    "preprocess_type": preprocess_type,
                    "algorithm_model": "VV-Pre2D-V1.0.0",
                }
                if param_key == "style_param":
                    payload[param_key] = {"style_type": 4, "result_image": result_image}
                else:
                    payload[param_key] = {"result_image": result_image}
                saved_id = call(client, "weaver/resource/gen_preprocess", payload, rtx=rtx)
                saved[kind] = {"status": "success", "model_id": saved_id.get("model_id") if isinstance(saved_id, dict) else saved_id}
            except Exception as exc:
                record_error(row, f"save_{kind}", exc)
            persist(report)

        # Run both front-view and four-view segmentation on two different inputs.
        segments = row.setdefault("segments", {})
        for split_type, granularity in ((1, 2), (2, 3)):
            key = f"split_{split_type}_granularity_{granularity}"
            if key in segments:
                continue
            segment_row: dict[str, Any] = {"split_type": split_type, "granularity": granularity, "input_model_id_360": sample["model_id_360"]}
            try:
                result = sse_segment(client, payload={
                    "name": f"CGAME_{asset_id}_segment_{split_type}",
                    "algorithm_model": "VV-SplitMask-V1.0.0",
                    "model_id": sample["model_id_360"],
                    "split_type": split_type,
                    "granularity": granularity,
                    "prompt": "拆分主体、可独立运动的机械部件、武器环和装甲板；保持每个部件完整。",
                }, rtx=rtx)
                reply = result["reply"]
                segment_row.update({"status": "success", "event_types": [f["event"] for f in result["frames"]], "client_id": find_client_id(reply), "component_count": len(components(reply)), "components": safe_value(components(reply)), "reply": safe_value(reply)})
                # Save the raw reply locally without masks; it is useful for QA and reruns.
                (OUT / asset_id).mkdir(parents=True, exist_ok=True)
                (OUT / asset_id / f"{key}_reply.json").write_text(json.dumps(safe_value(reply), ensure_ascii=False, indent=2), encoding="utf-8")
            except Exception as exc:
                record_error(segment_row, "init_segment", exc)
            segments[key] = segment_row
            persist(report)

        # Use the four-view session for the full edit surface.
        four = segments.get("split_2_granularity_3")
        if four and four.get("status") == "success" and four.get("client_id"):
            client_id = four["client_id"]
            edit = four.setdefault("edit", {})
            labels = [int(c["label"]) for c in four.get("components", []) if isinstance(c, dict) and str(c.get("label", "")).isdigit()]
            if labels and "begin_segment" not in edit:
                try:
                    edit["begin_segment"] = {"status": "success", "response": safe_value(call(client, "weaver/component/begin_segment", {"client_id": client_id, "view_type": 0, "component_label": labels[0]}, rtx=rtx))}
                except Exception as exc:
                    record_error(edit, "begin_segment", exc)
                persist(report)
            if "segment" not in edit:
                try:
                    edit["segment"] = {"status": "success", "response": safe_value(call(client, "weaver/component/segment", {"client_id": client_id, "view_type": 0, "add_pixels": [{"x": 512, "y": 512}], "remove_pixels": [{"x": 16, "y": 16}], "rects": [{"left_top_pixel": {"x": 480, "y": 480}, "right_bottom_pixel": {"x": 544, "y": 544}}]}, rtx=rtx))}
                except Exception as exc:
                    record_error(edit, "segment", exc)
                persist(report)
            if "confirm_segment" not in edit:
                try:
                    edit["confirm_segment"] = {"status": "success", "response": safe_value(call(client, "weaver/component/confirm_segment", {"client_id": client_id, "view_type": 0}, rtx=rtx))}
                except Exception as exc:
                    record_error(edit, "confirm_segment", exc)
                persist(report)
            if "boundary_adjust" not in edit:
                try:
                    # The API requires a raw one-byte-per-pixel mask, not a PNG.
                    mask = bytearray(2048 * 2048)
                    for y in range(1000, 1016):
                        mask[y * 2048 + 1000 : y * 2048 + 1016] = b"\x01" * 16
                    payload = {"client_id": client_id, "view_type": 0, "paint_mask": base64.b64encode(mask).decode("ascii"), "component_label": labels[0]}
                    edit["boundary_adjust"] = {"status": "success", "response": safe_value(call(client, "weaver/component/boundary_adjust", payload, rtx=rtx))}
                except Exception as exc:
                    record_error(edit, "boundary_adjust", exc)
                persist(report)
            if len(labels) >= 2 and "merge" not in edit:
                try:
                    edit["merge"] = {"status": "success", "response": safe_value(call(client, "weaver/component/merge", {"client_id": client_id, "component_labels": labels[:2], "view_type": 0}, rtx=rtx))}
                except Exception as exc:
                    record_error(edit, "merge", exc)
                persist(report)
            if "auto_merge" not in edit:
                try:
                    edit["auto_merge"] = {"status": "success", "response": safe_value(call(client, "weaver/component/auto_merge", {"client_id": client_id}, rtx=rtx))}
                except Exception as exc:
                    record_error(edit, "auto_merge", exc)
                persist(report)
            if labels and "part_rename" not in edit:
                try:
                    edit["part_rename"] = {"status": "success", "response": safe_value(call(client, "weaver/component/part_rename", {"client_id": client_id, "view_type": 0, "component_label": labels[0], "new_name": f"{asset_id}_core"}, rtx=rtx))}
                except Exception as exc:
                    record_error(edit, "part_rename", exc)
                persist(report)
            if "save_segment" not in edit:
                try:
                    saved = call(client, "weaver/component/save_segment", {"client_id": client_id, "name": f"CGAME_{asset_id}_segment_edit", "algorithm_model": "VV-SplitMask-V1.0.0"}, rtx=rtx)
                    edit["save_segment"] = {"status": "success", "model_id": saved.get("model_id") if isinstance(saved, dict) else saved}
                except Exception as exc:
                    record_error(edit, "save_segment", exc)
                persist(report)
            # Reopen the persisted node and exercise the documented cancel path
            # in a fresh edit session. This changes no generation quota.
            saved_segment_id = (edit.get("save_segment") or {}).get("model_id")
            if saved_segment_id and "open_segment" not in edit:
                try:
                    opened = call(client, "weaver/component/open_segment", {"model_id": saved_segment_id}, rtx=rtx)
                    opened_client = find_client_id(opened if isinstance(opened, dict) else {})
                    edit["open_segment"] = {"status": "success", "client_id": opened_client, "model_id": saved_segment_id}
                    if opened_client and labels:
                        call(client, "weaver/component/begin_segment", {"client_id": opened_client, "view_type": 0, "component_label": labels[0]}, rtx=rtx)
                        cancelled = call(client, "weaver/component/cancel_segment", {"client_id": opened_client, "view_type": 0}, rtx=rtx)
                        edit["cancel_segment"] = {"status": "success", "response": safe_value(cancelled)}
                except Exception as exc:
                    record_error(edit, "open_or_cancel_segment", exc)
                persist(report)

    # One successful saved segment is enough to prove the split -> mid-model contract.
    for asset_id, row in report["samples"].items():
        if row.get("segments"):
            for segment in row["segments"].values():
                segment_model_id = (segment.get("edit") or {}).get("save_segment", {}).get("model_id")
                if not segment_model_id or row.get("mid_model"):
                    continue
                try:
                    label = next((int(c["label"]) for c in segment.get("components", []) if str(c.get("label", "")).isdigit()), None)
                    params = {"image_gen_model_params": {"algorithm_model": "VV-MeshGen-V1.5.0", "face_type": 1, "face_num": 12000, "output_model_format": "glb", "segment_model_id": segment_model_id}}
                    if label is not None:
                        params["image_gen_model_params"]["component_label"] = label
                    ids = client.gen_3d_model(name=f"CGAME_{asset_id}_mid_from_segment", node_type=11, params=params, rtx=rtx)
                    task_id = first_model_id(ids)
                    row["mid_model"] = {"status": "submitted", "task_id": task_id, "segment_model_id": segment_model_id, "component_label": label}
                    persist(report)
                    record = wait_for_model(client, task_id, rtx=rtx, timeout=1200, interval=10)
                    urls = output_urls_or_download(client, record, task_id, rtx=rtx)
                    row["mid_model"].update({"status": "success", "outputs": [download_metadata(client, url, OUT / asset_id / f"mid_from_segment_{index}.zip") for index, url in enumerate(urls, 1)]})
                except Exception as exc:
                    record_error(row, "mid_model", exc)
                persist(report)
                break
            if row.get("mid_model"):
                break

    report["finished_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    persist(report)
    print(json.dumps({"report": str(REPORT), "samples": list(report["samples"]), "algorithm_nodes": list(report["algorithms"])}, ensure_ascii=False))


if __name__ == "__main__":
    main()
