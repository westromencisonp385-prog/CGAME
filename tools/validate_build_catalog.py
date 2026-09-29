from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'game/content/builds/build_catalog_v1.json'
data=json.loads(path.read_text(encoding='utf-8'))
assert data['schema_version']==3
builds=data['builds']; assert len(builds)==100
ids=[b['build_id'] for b in builds]; assert len(set(ids))==100
families=data['families']; assert len(families)==10 and all(v['count']==10 for v in families.values())
required={'build_id','name','family','status','operation','parts','growth','counterplay','failure_test','visual_signature','feedback','save_identity','evidence'}
for b in builds:
    assert required <= b.keys(), b['build_id']
    assert b['status']=='proposal'
    assert len(b['parts']) >= 4 and len(b['growth']) == 4
    assert len({p['part_id'] for p in b['parts']}) == len(b['parts'])
    assert all(p['mount'] and p['joint_and_function'] and p['removal_consequence'] and p['power_from'] for p in b['parts'])
    assert all(stage['active_parts'] and stage['change'] for stage in b['growth'])
    assert all(k in b['feedback'] for k in ('vfx','audio','ui'))
    assert b['save_identity']['namespace'] == b['build_id']
    assert all(b['evidence'][k] == 'not_run' for k in ('behavior','assembly','gpu','audio','save'))
print(f'PASS build catalog: {len(builds)} builds / {len(families)} families / 10 each')
