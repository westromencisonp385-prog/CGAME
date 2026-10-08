# -*- coding: utf-8 -*-
"""Weaver P2 parallel runner: reuse weaver_p2_v2.process_asset with a thread pool.

Usage:
  python -u weaver_p2_parallel.py --asset E02,E03,C01 --workers 5
  python -u weaver_p2_parallel.py --remaining --workers 5   # all PLAN ids without a mid model

Live log: tools/asset_pipeline/logs/p2_parallel_<ts>.log (line-buffered, safe to tail).
"""
import argparse
import json
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
sys.path.insert(0, str(Path(__file__).parent))
import weaver_p2_v2 as p2  # noqa: E402

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)
LOG_PATH = LOG_DIR / f"p2_parallel_{time.strftime('%H%M%S')}.log"
_lock = threading.Lock()


def log(msg: str) -> None:
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    with _lock:
        print(line, flush=True)
        with LOG_PATH.open("a", encoding="utf-8") as f:
            f.write(line + "\n")


p2.log = log  # route inner step logs to the shared live log


def run_one(asset_id: str, mv_algos: list, mesh_algos: list) -> dict:
    client = p2.load_client()  # per-thread client, avoids shared session state
    max_attempts = 6
    for attempt in range(1, max_attempts + 1):
        try:
            return p2.process_asset(client, asset_id, mv_algos, mesh_algos)
        except Exception as exc:  # noqa: BLE001
            msg = str(exc)
            log(f"{asset_id} attempt {attempt} FAILED: {msg}")
            if attempt == max_attempts:
                return {"asset": asset_id, "error": msg}
            throttled = "120041" in msg or "并发" in msg
            wait = (90 if throttled else 30) * attempt
            log(f"{asset_id} retry in {wait}s ({'throttled' if throttled else 'transient'})")
            time.sleep(wait)
    return {"asset": asset_id, "error": "unreachable"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset")
    ap.add_argument("--remaining", action="store_true")
    ap.add_argument("--skip", default="", help="ids currently running elsewhere")
    ap.add_argument("--workers", type=int, default=5)
    args = ap.parse_args()
    skip = {s.strip().upper() for s in args.skip.split(",") if s.strip()}
    if args.remaining:
        assets = [a for a in p2.PLAN if p2.mid_model_path(a) is None and a not in skip]
    else:
        assets = [a.strip().upper() for a in (args.asset or "").split(",") if a.strip()]
    assets = [a for a in assets if a in p2.PLAN]
    if not assets:
        raise SystemExit("nothing to run")
    client = p2.load_client()
    log(f"quota: {client.get_user_quota(rtx=p2.RTX)}")
    mv_algos = client.list_algorithm_model(node_type=7, rtx=p2.RTX)
    mesh_algos = client.list_algorithm_model(node_type=11, rtx=p2.RTX)
    log(f"run {len(assets)} assets with {args.workers} workers: {assets}")
    log(f"live log: {LOG_PATH}")
    results = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {pool.submit(run_one, a, mv_algos, mesh_algos): a for a in assets}
        for fut in as_completed(futures):
            res = fut.result()
            results.append(res)
            log(f"DONE {res.get('asset')} -> {'ERROR ' + res['error'] if 'error' in res else res.get('model')}")
    ok = sum(1 for r in results if "error" not in r)
    log(f"SUMMARY ok={ok}/{len(results)}")
    (LOG_DIR / "p2_parallel_last.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
