"""Read-only Weaver capability inventory. No generation or deletion calls."""
from __future__ import annotations
import json, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/".agents/skills/weaver-asset-production/scripts"))
from weaver_api_client import WeaverClient
from weaver_credentials import require_credentials

def main():
    app, secret, rtx, base = require_credentials(); client=WeaverClient(app,secret,base); out={}
    try: out["quota"]={k:v for k,v in client.get_user_quota(rtx=rtx).items() if k in {"model_quota","animation_quota","image_processing_quota","server_ts"}}
    except Exception as e: out["quota"]={"error":type(e).__name__,"message":str(e)[:200]}
    out["algorithms"]={}
    for node_type in range(1,17):
        try: out["algorithms"][str(node_type)]=client.list_algorithm_model(node_type=node_type,rtx=rtx)
        except Exception as e: out["algorithms"][str(node_type)]={"error":type(e).__name__,"message":str(e)[:200]}
    for language in ("zh","en"):
        try:
            value=client.request("weaver/demo/get_text2motion_prompt_list",{"language":language},rtx=rtx)
            out[f"motion_prompt_demo_{language}"]={"prompt_count":len(value.get("prompt_list",[])),"segment_demo_count":len(value.get("segment_demos",[]))}
        except Exception as e: out[f"motion_prompt_demo_{language}"]={"error":type(e).__name__,"message":str(e)[:200]}
    try:
        rows,total=client.get_model_list(limit=20,offset=0,rtx=rtx); out["model_list"]={"total_count":total,"returned":len(rows)}
    except Exception as e: out["model_list"]={"error":type(e).__name__,"message":str(e)[:200]}
    path=ROOT/"artifacts/weaver/capability-inventory.json"; path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding="utf-8"); print(json.dumps({"path":str(path),"node_types":len(out.get("algorithms",{})),"quota":out.get("quota")},ensure_ascii=False))
if __name__=="__main__": main()
