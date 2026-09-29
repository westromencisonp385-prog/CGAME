# Weaver 能力实测清单

实测日期：2026-09-29。凭证只从本机 `~/.config/wanderberg/weaver-credentials.txt` 读取；本页不保存凭证、临时 COS 信息或签名 URL。

## 配额与算法

只读配额检查返回：模型 1000、动画 1000、图片处理 100。算法接口按 node_type 逐项返回：

| node_type | 能力 | 当前可用算法 |
|---:|---|---|
| 1 | 重拓扑 | VV-RTP-V1.5.0、Hy3D-RTP-v2.0、Hy3D-RTP-v1.5 |
| 2 | LOD | VV-LOD-V1.0.0 |
| 3 | 图生高模 | Hy3D-3.5-0515、Hy3D-3.5-0315、VV-ShapeGen-V1.0.0 |
| 4 | 3D 动画 | MotusAI-V2M-V2.0 Pre、V1.5、T2M-V1.5、T2M-V1.1 |
| 5 | 骨骼架设 | MotusAI-Rigging-V2.0 |
| 6 | 蒙皮 | MotusAI-Skinning-V1.0 |
| 7 | 图生360 | VV-MultiView-V1.0.0、Hy3D-MultiView-v3.0 |
| 8 | 贴图纹理 | Hy3D-TEX-v3.5-preview、Hy3D-TEX-v2.0 |
| 9 | UV | Hy3D-UV-v3.0、Hy3D-UV-v2.0、VV-UV-v2.6.0 |
| 10 | 布线重建 | VV-MeshRefine-V1.0.0 |
| 11 | 图生中模 | VV-MeshGen-V1.5.0 |
| 12 | 图生Pose | MotusAI-Posing-V1.0 |
| 13 | 图生低模 | 当前返回空列表；文档标为本期未开放 |
| 14 | 2D 拆分 | VV-SplitMask-V1.0.0 |
| 15 | 2UV | VV-AutoLUV-V2.6.0 |
| 16 | 2D 预处理 | VV-Pre2D-V1.0.0、GPT image2、GPT image2.5、Nano Banana2、Nano BananaPro |

文生动作 Demo 列表的中英文接口都返回 11 条单段提示词；多段 Demo 当前为空。

## 已完成的真实样本

`docs/assets/comic-whale-v1/weaver-candidate-report.json` 对应 7 个成功的图生360→高模任务：N01–N04、E01、E02、BOSS01。Blender 结构检查显示它们都是单网格、单材质、无 UV、无动作，因此只保留为形体 candidate。

已验证的角色链：B01 使用 FBX + `model.json(config.mesh_category, config.algo_name, selection)` 成功骨骼架设和蒙皮；文生动作返回 991002，暂保留 Blender 机械动作。

## 接口行为边界

- `get_model_list` 按文档需要过滤条件；空筛选请求可能返回空 data。轮询应传 `model_id_list` 和正常分页参数。
- 图生高模、中模、360、UV、LOD、纹理和骨骼都是独立异步任务；每个返回 ID 都要单独记录、轮询、下载和验证。
- API 候选必须经过 Blender 的网格/UV/材质/骨骼/动作检查，再进入 Godot 真镜头；服务端 `status=3` 不等于游戏资产通过。
