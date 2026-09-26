from __future__ import annotations
import hashlib,json,os,ssl,sys,time,urllib.parse,urllib.request,zipfile,tempfile
from pathlib import Path
sys.path.insert(0,r"D:\工作\AI工具\ComfyUI")
from custom_nodes.comfyui_weaver.cos_upload import upload_file_to_weaver_cos
from custom_nodes.comfyui_weaver.weaver_api import WeaverClient
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'artifacts/weaver/api_postprocess'; REPORT=OUT/'report.json'
def cred_file():
 v={}
 for line in Path(r"D:\工作\AI工具\ComfyUI\appid.txt").read_text(encoding='utf-8').splitlines():
  d=':' if ':' in line else '='
  if d in line:
   k,x=line.split(d,1);v[k.strip().upper().replace(' ','_')]=x.strip()
 return os.environ.get('WEAVER_APPID') or v.get('APPID') or v.get('APP_ID'),os.environ.get('WEAVER_APPSECRET') or v.get('APP_SECRET') or v.get('APPSECRET') or v.get('KEY')
def tid(r):
 d=(r or {}).get('data') or {};return str(d.get('model_id') or ((d.get('model_ids') or [''])[0]))
def wait(c,i):
 end=time.monotonic()+1200
 while time.monotonic()<end:
  rec=c.get_model_detail(i)
  if rec and rec.get('status')==3:return rec
  if rec and rec.get('status')==4: raise RuntimeError(str(rec.get('failed_reason'))[:300])
  time.sleep(15)
 raise TimeoutError(i)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def download(url,dest):
 ctx=ssl.create_default_context();ctx.check_hostname=False;ctx.verify_mode=ssl.CERT_NONE;dest.parent.mkdir(parents=True,exist_ok=True)
 with urllib.request.urlopen(url,timeout=180,context=ctx) as r,dest.open('wb') as f:
  while b:=r.read(1024*1024):f.write(b)
 return {'path':str(dest),'bytes':dest.stat().st_size,'sha256':sha(dest)}
def zip_model(source,zip_path,extra=None):
 zip_path.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED) as z:
  z.write(source,Path(source).name)
  if extra:z.writestr('params.json',json.dumps(extra,ensure_ascii=False))
 return zip_path
def main():
 OUT.mkdir(parents=True,exist_ok=True); app,secret=cred_file();rtx=os.environ.get('WEAVER_RTX') or os.environ.get('USERNAME') or 'jasonlyan';c=WeaverClient(app,secret,rtx,'https://ws.visvise.com.cn'); cr=c.get_cos_cred();cred=cr.get('data') if isinstance(cr,dict) and 'data' in cr else cr
 api_zip=next(iter((ROOT/'artifacts/weaver/api_candidates/player_a01').glob('Model*.zip')),None)
 assets=[]
 if api_zip:assets.append(('player.a01_api_candidate',api_zip,'glb'))
 for aid,file in [('enemy.b01_authored',ROOT/'artifacts/weaver/authored/enemy_b01_reverse_crab_authored.glb'),('facility.c04_authored',ROOT/'artifacts/weaver/authored/facility_c04_repair_pump_authored.glb')]:
  z=zip_model(file,OUT/(aid+'_input.zip'));assets.append((aid,z,'glb'))
 report={'schema_version':1,'purpose':'Weaver postprocess candidates; authored GLB remains style authority until comparison passes','assets':[]}
 for aid,local,fmt in assets:
  row={'asset_id':aid,'input':str(local),'input_sha256':sha(local)}
  try:
   src=upload_file_to_weaver_cos(c,str(local),object_name=f'cgame/postprocess/{aid}.zip',cred_data=cred)
   uv=tid(c.gen_3d_model(name=f'CGAME_{aid}_uv',node_type=9,input_model=src,params={'uv_params':{'algorithm_model':'Hy3D-UV-v3.0','enable_auto_smoothing':True,'output_model_format':fmt}}));row['uv_task_id']=uv;ur=wait(c,uv);urls=c.extract_output_urls(ur);row['uv_outputs']=[download(u,OUT/aid/f'uv_{i}.zip') for i,u in enumerate(urls,1)]
   if urls:
    lodsrc=urls[0];lod=tid(c.gen_3d_model(name=f'CGAME_{aid}_lod',node_type=2,input_model=lodsrc,params={'lod_params':{'algorithm_model':'VV-LOD-V1.0.0','output_model_format':'fbx','gen_times':1,'reduce_faces':[{'reduce_level':1,'reduce_percent':50,'face_type':1},{'reduce_level':2,'reduce_percent':25,'face_type':1},{'reduce_level':3,'reduce_percent':13,'face_type':1}]}}));row['lod_task_id']=lod;lr=wait(c,lod);row['lod_outputs']=[download(u,OUT/aid/f'lod_{i}.fbx') for i,u in enumerate(c.extract_output_urls(lr),1)]
   if aid=='enemy.b01_authored' and urls:
    rigpack=zip_model(ROOT/'artifacts/weaver/authored/enemy_b01_reverse_crab_authored.glb',OUT/(aid+'_rig_input.zip'),{'mesh_category':'tetrapod'});rigsrc=upload_file_to_weaver_cos(c,str(rigpack),object_name=f'cgame/postprocess/{aid}_rig.zip',cred_data=cred);rig=tid(c.gen_3d_model(name=f'CGAME_{aid}_rig',node_type=5,input_model=rigsrc,params={'go_rigging_params':{'algorithm_model':'MotusAI-Rigging-V2.0','enable_auto_skinning':False}}));row['rig_task_id']=rig;rr=wait(c,rig);row['rig_outputs']=[download(u,OUT/aid/f'rig_{i}.zip') for i,u in enumerate(c.extract_output_urls(rr),1)]
  except Exception as e:row['error']=f'{type(e).__name__}: {str(e)[:300]}'
  report['assets'].append(row);REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({'report':str(REPORT),'assets':report['assets']},ensure_ascii=False))
if __name__=='__main__':main()
