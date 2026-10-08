---
name: ai-asset-pipeline
description: >-
  Reclaimer(挖掘机拯救世界) AI 美术资产生产技能。统一封装内网 TIMIAI 平台两条线：
  image2 生图（Nano Banana 参考图一致性最强 / GPT-Image-2 纯文生图兜底）与 3D 生成
  （Tripo text2model / Meshy image2model 支持 base64 直传）。内置风格锁、一致性双锚、
  洋红抠图归一化像素帧管线，并与 CGAME 仓库的资产状态机（planned→...→integrated）和
  G1 缺口清单对齐。生成结果永远只是候选（api_candidate），必须经 Blender/Godot 验收才能 integrated。
---

# Reclaimer AI 美术资产生产管线

一个入口解决三类产出：**2D 概念图/立绘/像素帧**（image2），**3D 草模候选**（Tripo/Meshy），**量产规划对接**（资产队列与 G1 缺口）。生成产物一律落 `api_candidate` 状态，进入正式资产必须走 [asset-production-plan-v1](../../../docs/assets/asset-production-plan-v1.md) 的验收合同。

## 0. 前置检查（每次会话必做）

```powershell
python <skill>/scripts/timiai_client.py
```

输出「API key 有效」才可继续。若报「API key 已禁用」，停止并让用户去 TIMIAI 平台重新启用 key（key 文件在 `D:\工作\生图API\apikey.txt`，启用后无需改代码直接重跑）。注意：探测用全零 UUID（网关要求 task_id 为 UUID 格式），判断禁用要看响应消息内容而非 code（网关把格式错误也报成 304）。

## 1. 路线速查

| 需求 | 路线 | 原因 |
|---|---|---|
| 概念图/立绘/图标/三视图 | `gen_image_nano` + 全局风格锚点 | 参考图一致性最强 |
| 无参考图兜底 | `gen_image_gpt` | 纯文生图 |
| 3D 草模（有本地图） | `meshy_image2model`（base64 直传） | Tripo 只收 HTTP URL |
| 3D 草模（纯文字起稿） | `tripo_text2model` | 简单直接，5 分钟内出模 |
| 3D 精修 | Meshy preview→refine 两段式 | Tripo 草稿→精炼需两次调用 |
| 多视图生模 | `meshy_multiview2model` | 必须 [front,left,back,right] 顺序 |

## 2. 2D 生图三铁律（来自稷下学院已验证经验）

1. **风格段固定不动**：下方 `RECLAIMER_STYLE_LOCK` 是不可变前缀，逐字复用。
2. **只改变量段**：只替换资产模板里的 `{{...}}`。
3. **双锚一致性**：跨资产用全局风格锚点图；单资产系列用"定妆图"作 ref（图生图）。

```python
RECLAIMER_STYLE_LOCK = (
    "【美术风格·严格锁定】"
    "工业童话低多边形游戏美术：大负形、歪斜但有功能原因的机械结构、"
    "用户确认的鲸口/蟹/泵站方向，哑光色块、少量手绘笔触、强轮廓、夸张比例。"
    "基础色六类共享色板：石油蓝、赭黄、骨白、番茄红、灰紫、橡胶黑；"
    "一个资产最多 5 个主材质槽，发光只用于磁环/修复状态。"
    "磨损只保留少量手绘笔触，禁止金属噪声、螺栓堆积、泛光、通用科幻面板。"
    "干净纯色背景，光照柔和均匀，无强烈写实阴影。"
)
RECLAIMER_NEGATIVE = (
    "避免:写实风格、电影级镜头光晕、通用科幻面板、密集小螺栓、随机贴纸、"
    "画面文字、无法解释的漂浮部件、无描边、背景杂乱、肢体畸形。"
)
```

## 3. 2D 像素帧管线（生成→抠图→归一化）

洋红底单帧生成 → 洋红色度键抠图 → NEAREST 归一化（本体高统一、脚底对齐）。

已验证硬规格（对齐原作 swordman 量化规格，勿拍脑袋改）：
`画布 96x96、本体高 19px、脚底基线 y=57、NEAREST 缩放、硬边 alpha(阈值110)`。

```powershell
# 1) 洋红底逐帧（定妆锚作 ref，逐帧只改姿势描述，武器不举过头）
# 2) 归一化
python postprocess.py --hero xxx --pixel
```

姿势铁律：攻击帧武器横向挥不举过头（防污染高度）；die 横躺特判按长边缩放。

## 4. 3D 生成调用方式

```python
import sys; sys.path.insert(0, r"D:\工作\InverseGame\WaWa\CGAME\.agents\skills\ai-asset-pipeline\scripts")
from timiai_client import TimiaiClient
c = TimiaiClient(); c.check_key()

# 文字起稿（Tripo）
c.tripo_text2model("cute excavator robot with whale-jaw bucket", out_path=".../a01_draft.glb",
                   face_limit=8000, smart_low_poly=True)

# 本地图起稿（Meshy，base64 直传）
c.meshy_image2model(r"D:\...\a01_concept.png", out_path="示例", model_type="standard")

# 多视图（Meshy）：front, left, back, right 顺序
c.meshy_multiview2model([front, left, back, right], out_path=".../a01.glb")
```

**API 边界硬约束**：
- Tripo 模型 URL 5 分钟过期 → 轮询 success 后**立即** `download()`。
- Tripo `image2model` 只收 HTTP(S) URL；本地文件用 Meshy（base64 Data URI）。
- Meshy refine 的 `preview_task_id` 必须是 SUCCEEDED 的预览任务。
- 不打印凭证与签名 URL；本地产物记录 task_id + SHA256。

## 5. 与 CGAME 资产状态机衔接

生成产物放入 `artifacts/ai_candidates/<asset_id>/`，状态只标记 `api_candidate`。进入 `review` 前必须完成资产合同 7 项（概念输入/源文件/GLB+材质槽/状态表/动作表/截图检查/生产 manifest）；机械动作优先 Blender 枢轴关键帧，API 生成的动作只是候选。资产队列稳定 ID 见 [weaver-production-queue.json](../../../docs/assets/weaver-production-queue.json)。

## 6. 本 skill 的产物目录约定

```
CGAME/artifacts/ai_candidates/<asset_id>/
  concept/       # 生图概念图（nano + style_anchor）
  sprite/        # 洋红底原始帧 + _px_frames 归一化帧
  model/         # GLB 候选 + task_id 记录
  manifest.json  # task_id, prompt, ref hash, 输出 hash, 时间
```
