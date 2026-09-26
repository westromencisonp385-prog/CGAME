from __future__ import annotations
import hashlib,json,os,ssl,sys,time,urllib.parse,urllib.request
from pathlib import Path
sys.path.insert(0,r"D:\工作\AI工具\ComfyUI")
from custom_nodes.comfyui_weaver.cos_upload import upload_file_to_weaver_cos
from custom_nodes.comfyui_weaver.weaver_api import WeaverClient
ROOT=Path(__file__).resolve().parents[1]; INPUT=ROOT/'artifacts/weaver/inputs/player_a01-style-v4.png'; OUT=ROOT/'artifacts/weaver/api_candidates/player_a01'; REPORT=ROOT/'artifacts/weaver/api_candidates/player_a01-report.json'
def read():
 v={}
 for line in Path(r"D:\工作\AI工具\ComfyUI\appid.txt").read_text(encoding='utf-8').splitlines():
  d=':' if ':' in line else '='
  if d in line:
   k,x=line.split(d,1);v[k.strip().upper().replace(' ','_')]=x.strip()
 return os.environ.get('WEAVER_APPID') or v.get('APPID') or v.get('APP_ID'),os.environ.get('WEAVER_APPSECRET') or v.get('APP_SECRET') or v.get('APPSECRET') or v.get('KEY')
def tid(r):
 d=(r or {}).get('data') or {}; return str(d.get('model_id') or ((d.get('model_ids') or [''])[0]))
def wait(c,i):
 end=time.monotonic()+1200
 while time.monotonic()<end:
  rec=c.get_model_detail(i)
  if rec and rec.get('status')==3:return rec
  if rec and rec.get('status')==4:raise RuntimeError(str(rec.get('failed_reason'))[:200])
  time.sleep(15)
 raise TimeoutError(i)
def download(url,dest):
 ctx=ssl.create_default_context();ctx.check_hostname=False;ctx.verify_mode=ssl.CERT_NONE;dest.parent.mkdir(parents=True,exist_ok=True)
 with urllib.request.urlopen(url,timeout=180,context=ctx) as r,dest.open('wb') as f:
  while b:=r.read(1024*1024):f.write(b)
 h=hashlib.sha256(dest.read_bytes()).hexdigest();return {'path':str(dest),'bytes':dest.stat().st_size,'sha256':h}
def main():
 app,secret=read();rtx=os.environ.get('WEAVER_RTX') or os.environ.get('USERNAME') or 'jasonlyan';c=WeaverClient(app,secret,rtx,'https://ws.visvise.com.cn'); credresp=c.get_cos_cred();cred=credresp.get('data') if isinstance(credresp,dict) and 'data' in credresp else credresp
 src=upload_file_to_weaver_cos(c,str(INPUT),object_name='cgame/style-v4/player_a01.png',cred_data=cred)
 mv=tid(c.gen_multi_views(name='CGAME_style_v4_player_a01_360',input_view={'main_view':src},params={'image_gen_360_params':{'algorithm_model':'VV-MultiView-V1.0.0','enable_a_pose':False}}));mvrec=wait(c,mv);views=(mvrec.get('image_gen_360_output') or {}).get('output_view') or {}
 hm=tid(c.gen_3d_model(name='CGAME_style_v4_player_a01_high',node_type=3,input_view={k:views.get(k,'') for k in ('main_view','back_view','left_view','right_view')},params={'image_gen_model_params':{'algorithm_model':'Hy3D-3.5-0515','output_model_format':'glb','face_type':1,'face_num':30000,'strict_mode':True,'skip_360_preprocess':True}}));rec=wait(c,hm);urls=c.extract_output_urls(rec);files=[]
 for n,u in enumerate(urls,1):files.append(download(u,OUT/f'{hm}_{n}.zip'))
 REPORT.parent.mkdir(parents=True,exist_ok=True);REPORT.write_text(json.dumps({'asset_id':'player.machine.a01_whale_jaw','style_anchor':'docs/assets/style-anchor-industrial-folk-v1.png','view_task_id':mv,'model_task_id':hm,'model_status':rec.get('status'),'outputs':files,'review':'pending_blender_and_godot_style_check'},ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps({'report':str(REPORT),'outputs':[x['path'] for x in files]},ensure_ascii=False))
if __name__=='__main__':main()
