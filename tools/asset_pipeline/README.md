# 资产生产脚本（asset_pipeline）

2026-10-09 从仓库外 `D:\工作\InverseGame\WaWa\tools_re\` 收进仓库。仓库路径已改为相对脚本自身推导（`Path(__file__).resolve().parents[2]`），仓库换位置也能用。旧目录保留不动，以本目录为准。

## 现役流程（按资产生产顺序）

| 步骤 | 脚本 | 作用 |
|---|---|---|
| 1 原画风格统一 | `style_v3_concepts.py` | TiMi 多图融合：原画 + 主视觉锚点 → v3 原画 |
| 2 部件规划 | `v3_parts_plan.py`、`weaver_parts.py`（PARTS 表、360 质检） | 每件资产拆哪些部件、提示词 |
| 3 批量生成 | `weaver_v3_batch.py --asset <IDs>` | 360 → 2D 拆分 → 联合中模 → 贴图 → 组装 → 安装 |
| 3' 单步 | `weaver_parts_joint.py`、`weaver_texture.py`、`weaver_resume_download.py` | 分步执行 / 断点续取 |
| 4 Blender 组装 | `blender_joint_rig.py` | 部件改名为 ProceduralRig 节点名、设枢轴、导出 `game/assets/models/rigged/<slot>_rig.glb`、写 `rig_manifest.json` |
| 5 验收 | `blender_verify.py`、`blender_part_sheet.py` | 无头渲染预览、部件清单图 |
| 敌人新设计 | `enemy_roster_v3.py` | 小怪 / 精英 / Boss 原画生成 |
| UI 图标 | `ui_icon_batch_v2.py` | v2 切面图标（TiMi），硬边抠图 256px |

规则：可动资产一律「部件分开生成」（见 `.agents/skills/weaver-asset-production/SKILL.md`）。

## 历史 / 兜底（不再作为正式管线）

- `blender_componentize.py`、`componentize_all.py`：整块中模平面切割拆件（已废弃，只作兜底）。
- `weaver_p1_batch.py`、`weaver_p2_batch.py`、`weaver_p2_parallel.py`、`weaver_p2_v2.py`、`weaver_mid_retry.py`、`import_formal_models.py`、`blender_to_game_glb.py`、`finalize_textured.py`：P1/P2 整块模型流程，产物已归档。
- `blender_assemble_parts.py`、`blender_register_parts.py`、`blender_parts_probe.py`：「每部件单独生成再拼」的尝试（各部件被重新归一化，无法对位，已放弃）。
- `ui_asset_batch.py`、`ui_contact_sheet.py`：v1 位图 UI（已废弃）。
- `analyze_wanderburg.py`、`extract_docs.py`、`crop_subject.py`、`weaver_probe*.py`：逆向分析与接口探测。

## 本机依赖（不在仓库里，换机器要改）

- Blender：`F:\SteamLibrary\steamapps\common\Blender\blender.exe`
- TiMi 生图技能脚本：`C:\Users\jasonlyan\.bg-agent\config-with-app\skills\timi-image\scripts`
- Weaver 鉴权：`D:\工作\生图API\weaver\鉴权.txt`（不进仓库）
- Wanderburg 安装目录（仅逆向分析用）：`F:\SteamLibrary\steamapps\common\Wanderburg Game`

脚本不打印、不落盘任何凭据。运行日志写到本目录 `logs/`（已忽略）。
