from __future__ import annotations
import hashlib,json,os,ssl,sys,time,urllib.request
from pathlib import Path
sys.path.insert(0,r"D:\工作\AI工具\ComfyUI")
from custom_nodes.comfyui_weaver.cos_upload import upload_file_to_weaver_cos
from custom_nodes.comfyui_weaver.weaver_api import WeaverClient
ROOT=Path(__file__).resolve().parents[1]; ZIP=ROOT/'artifacts/weaver/authored/enemy_b01_rig_input.zip'; OUT=ROOT/'artifacts/weaver/api_candidates/b01_rig'; REPORT=OUT/'report.json'
def creds():
 v={}
 for line in Path(r"D:\工作\AI工具\ComfyUI\appid.txt").read_text(encoding='utf-8').splitlines():
  d=':' if ':' in line else '='
  if d in line:k,x=line.split(d,1);v[k.strip().upper().replace(' ','_')]=x.strip()
 return os.environ.get('WEAVER_APPID') or v.get('APPID') or v.get('APP_ID'),os.environ.get('WEAVER_APPSECRET') or v.get('APP_SECRET') or v.get('APPSECRET') or v.get('KEY')
def tid(r):d=(r or {}).get('data') or {};return str(d.get('model_id') or ((d.get('model_ids') or [''])[0]))
def wait(c,i):
 end=time.monotonic()+1200
 while time.monotonic()<end:
  r=c.get_model_detail(i)
  if r and r.get('status')==3:return r
  if r and r.get('status')==4:raise RuntimeError(str(r.get('failed_reason'))[:300])
  time.sleep(15)
 raise TimeoutError(i)
def main():
 app,sec=creds();rtx=os.environ.get('WEAVER_RTX') or os.environ.get('USERNAME') or 'jasonlyan';c=WeaverClient(app,sec,rtx,'https://ws.visvise.com.cn');cr=c.get_cos_cred();cred=cr.get('data') if isinstance(cr,dict) and 'data' in cr else cr;src=upload_file_to_weaver_cos(c,str(ZIP),object_name='cgame/actions/b01_rig_input.zip',cred_data=cred);job=tid(c.gen_3d_model(name='CGAME_b01_reverse_crab_rig_fbx',node_type=5,input_model=src,params={'go_rigging_params':{'algorithm_model':'MotusAI-Rigging-V2.0','enable_auto_skinning':False}}));rec=wait(c,job);urls=c.extract_output_urls(rec);OUT.mkdir(parents=True,exist_ok=True);files=[]
 for n,u in enumerate(urls,1):
  ctx=ssl.create_default_context();ctx.check_hostname=False;ctx.verify_mode=ssl.CERT_NONE;p=OUT/f'{job}_{n}.zip';
  with urllib.request.urlopen(u,timeout=180,context=ctx) as r:
   with p.open('wb') as pf:
    while b:=r.read(1024*1024):pf.write(b)
  files.append({'path':str(p),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
 REPORT.write_text(json.dumps({'task_id':job,'status':rec.get('status'),'outputs':files,'note':'FBX+model.json rigging contract'},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'report':str(REPORT),'outputs':files},ensure_ascii=False))
if __name__=='__main__':main()
