# -*- coding: utf-8 -*-
"""Wait for the Weaver texture batch, then refresh formal + rigged GLBs for every textured asset.

Usage: python -u finalize_textured.py
"""
import json
import subprocess
import sys
import time
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import weaver_p2_v2 as p2  # noqa: E402
import componentize_all as ca  # noqa: E402

GODOT = r"C:\Users\jasonlyan\AppData\Local\Microsoft\WinGet\Links\godot.exe"
PROJ = str(Path(__file__).resolve().parents[2] / "game")


def textured_ids() -> list[str]:
    return [a for a in p2.PLAN if sorted((p2.OUT_ROOT / a / "weaver" / "tex").glob("*.glb"))]


def main() -> None:
    deadline = time.time() + 3600 * 2
    while time.time() < deadline:
        done = textured_ids()
        print(f"[{time.strftime('%H:%M:%S')}] textured {len(done)}/{len(p2.PLAN)}", flush=True)
        if len(done) >= len(p2.PLAN):
            break
        last = HERE / "logs" / "tex_last.json"
        if last.exists() and last.stat().st_mtime > time.time() - 120 and len(done) > 0:
            # batch process wrote summary -> finished (some may have failed)
            break
        time.sleep(60)
    ids = textured_ids()
    print("refresh:", ",".join(ids), flush=True)
    subprocess.run([sys.executable, "-u", str(HERE / "import_formal_models.py"), ",".join(ids)], check=False)
    slots = [p2.PLAN[a]["slot"] for a in ids if p2.PLAN[a]["slot"] in ca.SPECS]
    subprocess.run([sys.executable, "-u", str(HERE / "componentize_all.py"), ",".join(slots)], check=False)
    subprocess.run([GODOT, "--headless", "--import", "--path", PROJ], check=False, capture_output=True)
    missing = [a for a in p2.PLAN if a not in ids]
    print(json.dumps({"textured": ids, "missing": missing}, ensure_ascii=False), flush=True)
    print("FINALIZE DONE", flush=True)


if __name__ == "__main__":
    main()
