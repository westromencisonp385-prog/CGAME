# Weaver 角色、骨骼、蒙皮与动作实测

日期：2026-09-29
范围：两个图形漫画人物的角色管线验证；不代表正式 NPC 资产放行。

## 这次实际验证了什么

Weaver 在角色链路中是多个异步节点的组合：

1. **图生 360（node 7）**：把单张角色图扩成主/背/左/右视图，可选输出 A-Pose、旋转视频和帧包。
2. **图生高模（node 3）**：使用单视图或四视图生成带 UV/材质的高模候选；`enable_pbr=true` 才会输出 PBR 贴图。
3. **智能骨骼架设（node 5）**：输入 zip，zip 内必须有同 stem 的 `model.fbx` 与 `model.json`；JSON 的 `config.mesh_category` 和 `config.algo_name` 是关键字段。角色用 `humanoid`。
4. **智能蒙皮（node 6）**：输入带骨骼模型的同 stem FBX/JSON zip，JSON 要声明算法、网格名和骨骼名。
5. **3D 动画（node 4）**：使用蒙皮后的模型 zip；T2M 通过 `prompt` 或 `segments`，V2M 通过视频。单段 T2M 返回一个任务，任务内部包含多个候选动画。
6. **批量图生 Pose**：`POST /weaver/resource/batch_gen_pose`，输入 FBX zip 和 1–10 张人物姿态图；只适用于标准人物角色。

`status=3` 只表示服务器任务完成。本项目仍要求下载结果后，用 Blender 检查骨骼、权重、动作片段和接触姿态，再进入 Godot。

## 本次实测结果

凭证从本机 `C:\Users\jasonlyan\.config\wanderberg\weaver-credentials.txt` 读取，没有写入仓库。查询到的配额为：模型 999、图像处理 100、动画 1000。可用算法已查询并记录在本地状态文件；状态文件只保留脱敏后的记录和任务 ID。

### 维修驾驶员

| 节点 | 任务 ID | 结果 | 本地证据 |
|---|---|---|---|
| 图生 360 | `Model2026092900610161` | 成功，约 96 秒 | [四视图与 contact sheet](../../artifacts/weaver/capability-study/characters/maintenance_driver/multi_view/contact_sheet.png) |
| 图生高模 | `Model2026092900610165` | 成功，约 449 秒 | [高模输出目录](../../artifacts/weaver/capability-study/characters/maintenance_driver/high_model/extracted/) |
| 智能骨骼 | `Model2026092900609360` | 成功 | [骨骼 FBX](../../artifacts/weaver/capability-study/characters/maintenance_driver/rigging/extracted/CGAME_maintenance_driver_rig.fbx) |

高模检查：GLB 约 88,970 顶点、119,776 三角面、1 个网格、1 个材质、3 张贴图、存在 UV；没有骨骼和动画，这是进入 node 5 前的预期状态。[检查记录](../../artifacts/weaver/capability-study/characters/maintenance_driver/asset-checks.json)

骨骼检查：Blender 能读出 1 个 `pelvis` 根的角色骨架，共 99 根骨骼，覆盖脊柱、头部、手指、双臂、双腿和头发骨骼。[骨骼列表](../../artifacts/weaver/capability-study/characters/maintenance_driver/rig-bones.txt)

## 尚未提交的节点

为避免在没有先检查上游模型的情况下继续消耗任务，当前停在“高模 + 骨骼”样本。以下调用已在 `tools/weaver_character_checks.py` 中按原始 schema 写好，但本轮没有提交：

- node 6 智能蒙皮；
- node 4 T2M 的原地待机、原地跑步、原地重击、三段 `segments`；
- `batch_gen_pose` 的 A-Pose + 行走/攻击双参考图；
- 第二个废土机械师的同一套任务。

脚本会把任务 ID 先写入 [state.json](../../artifacts/weaver/capability-study/characters/state.json)，支持中断续跑，并且失败任务不会自动重复提交。继续时的顺序必须保持为：

`rigging → skinning → T2M/V2M/Pose → Blender 骨骼/权重/动画检查 → Godot 实机镜头`

## 当前判断

这条 API 能可靠地完成“角色图 → 多视图 → 带 PBR 的高模候选 → 自动骨骼”的前半段。它不会替我们决定角色拆件、工程动作、碰撞包络、游戏关节枢轴或最终风格；当前高模仍是一个整体网格，不能直接当作游戏正式角色。node 6 之后才能判断动作管线是否真正可用，尤其要检查机械工具臂、护肩线圈和衣物是否随骨骼发生合理变形。

本轮用于角色生产的参考图保存在 [references](../../artifacts/weaver/capability-study/characters/references/)；由内置图像工具生成，保持项目已确认的粗轮廓、硬色块、非对称工业童话语法。
