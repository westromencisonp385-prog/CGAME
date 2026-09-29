# 场景组件 API 实测

日期：2026-09-29。Weaver 可以生成单个场景组件或小型 diorama 候选，但场景的路线、碰撞、任务状态和 Godot 组装仍由项目负责。

## 河岸泵站样本

- 输入：`river_mouth_pump_yard.png`，由 C01/C04 概念和图形漫画方向整理。
- node_type=3，算法 `Hy3D-3.5-0515`，`enable_pbr=true`。
- task：`Model2026092900610162`，终态 `3`。
- 输出 ZIP 约 201.8 MB，包含 FBX、GLB、OBJ、MTL、PBR base/metallic/normal/roughness 图。
- 同一输入的 node_type=11 中模任务 `Model2026092900610168` 已完成（`status=3`），输出为约 430 KiB 的 FBX；账本保留成员名、大小和 SHA-256。
- Blender 5.2.2 结构检查：高模 GLB 约 131,802 顶点/148,672 三角、1 网格、1 材质、UV 存在；中模 FBX 约 27,901 顶点/54,004 三角、1 网格、无材质/UV。两者都没有骨骼或动作，仍是组件候选。

## 其他场景输入

已准备：`snap_pipe_bridge_kit.png`、`salt_sea_wind_farm.png`。它们先作为后续桥模块和风机设施的输入，不能把概念图直接当可玩场景。

## 结论

场景生产应采用“组件候选 → Blender 拆件/碰撞 → Godot 组装”的链路。单次高模输出不能替代关卡路线、动态修复状态、镜头避让、LOD 和真实 GPU 验收。PBR 输出确实包含完整材质图，但是否符合图形漫画方向要经过实机材质对照。
