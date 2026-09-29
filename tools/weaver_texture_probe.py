"""One real texture-generation probe against the authored B01 control asset."""
from __future__ import annotations
import json, sys, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; sys.path.insert(0,str(ROOT/".agents/skills/weaver-asset-production/scripts"))
from weaver_api_client import WeaverClient
from weaver_credentials import require_credentials
from weaver_asset_helpers import cos_object_name, download_metadata, first_model_id, output_urls_or_download, wait_for_model

def main():
    app,secret,rtx,base=require_credentials(); c=WeaverClient(app,secret,base); cred=c.get_cos_cred(rtx=rtx)
    model=ROOT/"game/assets/models/formal_slice/b01_reverse_crab_formal.glb"; archive=ROOT/"artifacts/weaver/capability-study/texture/b01_input.zip"; archive.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as z:z.write(model,model.name)
    model_url=c.upload_file(archive,cred,object_name=cos_object_name(cred,"cgame/capability-study/texture/b01_input.zip"))
    ref=ROOT/"docs/assets/comic-whale-v1/N01-hydraulic-barricade-crab.png"; ref_url=c.upload_file(ref,cred,object_name=cos_object_name(cred,"cgame/capability-study/texture/b01_ref.png"))
    task=first_model_id(c.gen_3d_model(name="CGAME_capability_b01_texture",node_type=8,input_model=model_url,input_view={"main_view":ref_url},params={"tex_params":{"algorithm_model":"Hy3D-TEX-v3.5-preview","resolution":1024,"unwarp_uv":False,"prompt":"graphic comic construction material: deep petrol blue, ochre yellow, bone white, restrained tomato red, hard cel value blocks, authored painted edge marks, no text"}},rtx=rtx))
    rec=wait_for_model(c,task,rtx=rtx); files=[]
    for i,url in enumerate(output_urls_or_download(c,rec,task,rtx=rtx),1):files.append(download_metadata(c,url,ROOT/f"artifacts/weaver/capability-study/texture/{task}_{i}.zip"))
    report={"asset_id":"enemy.b01_reverse_crab_formal","node_type":8,"task_id":task,"status":rec.get("status"),"outputs":files,"input_has_uv":True,"accepted":"pending_blender_style_compare"}; (ROOT/"artifacts/weaver/capability-study/texture/report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8"); print(json.dumps({"task_id":task,"status":rec.get("status"),"outputs":files},ensure_ascii=False))
if __name__=="__main__":main()
