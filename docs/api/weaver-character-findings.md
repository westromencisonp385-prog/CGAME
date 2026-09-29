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
| 智能蒙皮 | `Model2026092900609415` | 成功 | [蒙皮输出包](../../artifacts/weaver/capability-study/characters/maintenance_driver/outputs/skinning_1.zip) |
| T2M 待机 | `Model2026092900609418` | 成功，4 个候选 | [动作验收记录](../../artifacts/qa/weaver/character-animation-validation.json) |
| T2M 跑步 | `Model2026092900609420` | 成功，4 个候选 | [动作验收记录](../../artifacts/qa/weaver/character-animation-validation.json) |
| T2M 重击 | `Model2026092900609424` | 成功，4 个候选 | [动作验收记录](../../artifacts/qa/weaver/character-animation-validation.json) |
| 三段 T2M | `Model2026092900610219` | 成功，4 个候选 | [动作验收记录](../../artifacts/qa/weaver/character-animation-validation.json) |
| 图生 Pose 批量 | `Model2026092900610221` | 成功 | [Pose 输出包](../../artifacts/weaver/capability-study/characters/maintenance_driver/outputs/pose_batch_1.zip) |

高模检查：GLB 约 88,970 顶点、119,776 三角面、1 个网格、1 个材质、3 张贴图、存在 UV；没有骨骼和动画，这是进入 node 5 前的预期状态。[检查记录](../../artifacts/weaver/capability-study/characters/maintenance_driver/asset-checks.json)

骨骼检查：Blender 能读出 1 个 `pelvis` 根的角色骨架，共 99 根骨骼，覆盖脊柱、头部、手指、双臂、双腿和头发骨骼。[骨骼列表](../../artifacts/weaver/capability-study/characters/maintenance_driver/rig-bones.txt)

## 当前验收结论

Blender 5.2.2 读取蒙皮和每类动作的首个 FBX 样本：均为 1 个网格、1 个材质、UV 存在、1 个 armature、119,776 三角。蒙皮文件没有动作；待机、跑步、重击、三段动作和 Pose 文件都含动作轨道，分别观察到 1、2、3、4、5 个 action。服务端返回的 4 个 T2M 候选已经落到本地，当前仍需人工看接触姿态和机械工具臂是否穿插，不能直接并入正式角色。

视觉抽查：角色动作候选的轮廓可读，但 Blender 默认转台材质偏白，尚未达到图形漫画 C 的硬色块标准；动作通过结构闸门，材质通过视觉闸门仍为 `pending`。

脚本会把任务 ID 先写入 [state.json](../../artifacts/weaver/capability-study/characters/state.json)，支持中断续跑，并且失败任务不会自动重复提交。继续扩展第二个角色时，顺序必须保持为：

`rigging → skinning → T2M/V2M/Pose → Blender 骨骼/权重/动画检查 → Godot 实机镜头`

## 当前判断

这条 API 已经实测完成“角色图 → 多视图 → 带 PBR 的高模候选 → 骨骼 → 蒙皮 → 动作/Pose”的角色链。它不会替我们决定角色拆件、工程动作、碰撞包络、游戏关节枢轴或最终风格；当前输出仍需检查机械工具臂、护肩线圈和衣物是否随骨骼发生合理变形。

本轮用于角色生产的参考图保存在 [references](../../artifacts/weaver/capability-study/characters/references/)；由内置图像工具生成，保持项目已确认的粗轮廓、硬色块、非对称工业童话语法。
