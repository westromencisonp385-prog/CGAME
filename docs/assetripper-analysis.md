# AssetRipper 深度分析记录

审计日期：2026-09-20。工具：[AssetRipper 官方仓库](https://github.com/AssetRipper/AssetRipper)，Windows x64 发行版 2.0.0。工具安装包曾下载到本地并运行；分析过程只读取 `F:\SteamLibrary\steamapps\common\Wanderburg Game`，导出写入工作区 `tmp/assetripper-export2`，没有改动 Steam 安装目录，也没有把参考资产复制到 Godot 工程。

导出当前位于 F:/WanderburgAssetRipperExport，文中临时目录为初次导出位置。六个样例已补可回查行号与hash，见 [结构证据](../evidence/reference_asset_contract.json)。

2026-09-21补充：本轮直接查看色板、载具展示图、模块图标和烟尘遮罩，并核对样例材质/shader引用与场景相机参数；见 [视觉证据](../evidence/reference_visual_study.json) 和 [整体美术研究与原创方向](assets/art-direction.md)。这是导出样例研究，尚未完成参考游戏的动态镜头/后处理/演出分析。

2026-09-24补充：`研究：建立模块与载具引用矩阵` 已整理为 [AssetRipper 引用矩阵](assetripper-reference-matrix.md)。矩阵逐项标记 observed / inferred / unknown，并明确三条 M0 组合可以借鉴的结构线索与不能从导出推断的运行时边界；它不替代原型和试玩。

## 1. 这次比元数据审计多看到了什么

AssetRipper 官方说明支持 Unity 3.5.0 到 6000.4.X；本包的 Unity 版本为 6000.0.63f1，因此导出成功。导出结果包含：

| 项目 | 数量/观察 | 意义 |
|---|---:|---|
| Unity 场景 | 5 | `Start Menu`、`Overworld`、`Preload`、`SplashScreens`、`MAIN SCENE`，流程有明确的菜单/世界地图/局内场景边界 |
| Prefab | 749 | 载具、模块、敌人、首领、村庄、特效和 UI 大量拆分为可复用预制体 |
| 纹理导出 | 845 | UI、材质、VFX 和输入提示都有独立视觉资源 |
| C# 导出文件 | 707 | 主要是类型/字段/方法签名；IL2CPP 免费导出的方法体为空或 stub，不能当作原始实现 |
| 导出大小 | 约 2.20 GB、14,008 个文件 | 完整工程恢复成本很高；对本项目应做“证据抽取”，不应把整个导出当新项目基础 |

导出证据 JSON：`evidence/assetripper_export_inventory.json`。复现脚本：`tools/analyze_assetripper_export.py`。

## 2. 模块组合的真实结构证据

### `Module2` 不是一个纯数值 Buff

AssetRipper 导出的 `Module2.cs` 显示，它同时承担：

- 稳定标识与展示：`moduleID`、`moduleName`、`moduleDescription`、`displayImage`、`InfoObject`。
- 槽位资格：`frontSlot`、`sideSlot`、`backSlot`、`topSlot`、`crewSlot`、`captainSlot`。
- 运行时 Prefab：`moduleSkin`、`activeEffectPrefab`、`activeEffectAlternative`、`passiveAbilityPrefab`、`legendaryActiveEffect`。
- 升级池：`UpgradesAddToPool`、`legendaryUpgrades`、`specialUpgrade0A/B`、`specialUpgrade1A/B`、`upgradesInstalled`。
- 双能力数值：主动和被动分别拥有基础伤害、冷却、持续时间、范围、弹药、尺寸、速度以及当前值。
- 视觉状态：`Module2SkinElement` 列表按尺寸、终极、被动、冷却、传奇 A/B 维护；另有安装闪光、轮廓动画、伤害材质和冷却恢复反馈。
- 装配生命周期：`InstallModule`、`PrepareForVehicleBaseSwap`、`DeleteModule`、`UpgradeModule`、`GetUpgradedVersionPreview`、`TryResolveMountTarget`、`MountTransform`。

因此，模块的真实抽象接近“**带槽位资格、主动/被动行为、升级池、Prefab 视觉状态和装配生命周期的运行时对象**”，不是一个只修改 `damage += 10` 的数据条目。

### Prefab 层级验证了“等级状态切换”

导出 Prefab 观察：

- `Module2_FrontCannon.prefab` 有 `Skin`、`S0_Elements`、主动/被动实例化点、`Generic_CooldownElement`，并包含 `T0` 到 `T5` 的炮体/升级层级；不同启用值的层级保留在同一Prefab中。按等级切换是结合命名和绑定的设计推断，具体运行顺序尚未验证。
- `Module2_BackDash.prefab` 有两组 `VFX_Dash_MuzzleFlash`、`VFX_Dash_Sparks`、可开关的 `VFX_Dash_Blast`、四个烟囱火焰和多层冷却/升级节点；模块升级同时改变动作反馈和可见结构。
- `Module2_TopMortar.prefab` 含 `Upgrades`、`T0`–`T5`、`Generic_Operator` 和多级炮手对象；升级可以是炮体、操作员、视觉层和表现节点的组合。
- `PV_Tank_Rank__0_.prefab` 与 `PV_Tank_Rank__3_.prefab` 的 GameObject 数量分别为 98 和 119；阶段高的 Prefab 不是简单换材质，而是多了轮廓、轨迹、火焰/反馈与层级对象。
- `PV_Spider_0.prefab` 有 207 个 GameObject，包含腿部 IK、`LegController_Small`、`SteeringGimbal`、驾驶反馈和多组状态 VFX；这解释了不同载具可以拥有不同的操作和视觉语法。

这直接支持我们的设计决定：阶段变化和模块组合要在 Prefab 层可见，但 Godot 中应将“玩法定义”和“视觉子树”分离，避免为每个组合复制整台车。

### `ModuleSelection` 是构筑生成器与预览器

导出的 `ModuleSelection.cs` 字段和方法显示：

- 有 `baseModulePrefabPool`、`baseModulePrefabEternalPool`、稀有度权重和模块升级池。
- 维护三选一模块、神器和载具升级选项，支持锁定、重掷、稀有/传奇/特殊选项。
- 生成 `generatedModuleUpgradePreviewObjects`，并记录 `allBonusStatsAdded`。
- 维护 `vehicleBasesPrefabsTier2` 到 `vehicleBasesPrefabsTier5`、车辆变体 A/B 标题与描述，说明载具阶段升级进入选择界面时会生成预览并替换基础载具。

本作可以借鉴这种“**候选生成 → 临时 Preview Prefab → 玩家确认 → 事务性安装**”链路，但把它做得更清楚：预览界面同时展示输入变化、数值变化、轮廓变化和组合标签。

## 3. 操控与底盘结构

导出的 `VM.cs` 给出了比发布包字符串更具体的操控证据：

- 有 `activeModule1` 到 `activeModule4` 和 front/side/back/top/crew/captain 槽位及已占用计数。
- 预制底盘通过 `vehicleSizeRank`、`canAbsorbVehiclesOfSizeRank`、`tierBasedCollider`、`harvesterCol`、`magnetCol`、`navMeshObstacle` 共同表达体量、吸收、采集、磁铁和导航占地。
- 输入动作至少分为移动、加速、刹车、4 个模块、执行、指针位置、瞄准和摇杆移动；控制器还有相对驾驶、自动刹车、摇杆死区和原地转向逻辑。
- 速度不是单个常数：有正向/倒车/加速/冲刺曲线、转向速度、刹车乘数、车辆相对驾驶权重、逐步最大速度曲线。
- 状态层包含护甲、护盾、Nitro、热/过热式的资源节奏、减速/眩晕/击飞/恐惧/燃烧、吸入和地形状态。

这说明我们应该把“驾驶风格”设计成模块可影响的可读维度：抓地、转向、倒车、冲刺、刹车、上装朝向和作业节奏，而不是只把模块加成塞进伤害公式。

## 4. 数值结构与局外进度

导出的 `Module2` 和 `ModuleSelection` 同时保存基础值、附加值、当前值、稀有度、等级、升级池和预览值；`BonusVehicleStats` 独立为 ScriptableObject，字段包括生命、速度、Nitro、质量、磁力范围、加速度和旋转速度。`SaveGame` 当前版本为 7，保存最后装配、解锁 ID、银币、统计、任务进度、已解锁群系；`SaveLoad` 具备主存档、备份、本地备份、备份前一版本、构建身份、进度代次和运行写入门。

对本作的建议是：

```text
VehicleBase + ToolProfile
→ 模块加法修正
→ 少量乘区与软上限
→ 速度/热量/货舱/修复等转换规则
→ 当局状态与组合标签
→ 预览、结算和统计从同一计算结果读取
```

不能把导出的脚本数量直接当“玩法复杂度”或把空方法当源码；但是字段组合足以证明：模块、载具阶段、槽位、Prefab 预览、主动/被动冷却和局外保存是相互关联的系统。

## 5. 对原创项目的改进

基于这次 AssetRipper 证据，原创项目已把模块规则升级为独立设计文档：[模块组合与幻想载具设计](module-combinatorics.md)。最重要的变化：

1. 模块分为 Tool、Drive、Reaction、Repair、Morph 五类，每类负责不同的操控、数值和表现。
2. 设计三层组合：直接组合、条件组合、转化组合；首发只生产 12–16 条有意命名的组合边。
3. 运行时用 `ModuleDef`、`ModuleVisual.tscn`、`ModuleRuntime`、`LoadoutAssembler` 分离定义、Prefab、状态和装配生命周期。
4. 每件模块必须说明主动作、成本、暴露、放大、输入变化、Prefab 变化、音效/VFX、反制和测试场景。
5. M0 先做三条组合：宽斗+磁吸、水炮+电弧、惯性飞轮+冲刺；如果试玩只感到数字变大，就不进入内容量产。

## 6. 证据边界与资产处理

AssetRipper 导出适合回答“有哪些 Prefab、哪些组件、哪些层级对象、哪些字段和方法签名、哪些资源命名”，不适合声称恢复原始算法。IL2CPP 免费导出的 `Assembly-CSharp` 方法体为空/stub；脚本和模型仍属于参考作品资产，不会被放进新 Godot 项目的发布内容。导出目录只作为本地研究缓存，后续可清理；新项目只保留本报告、统计 JSON 和原创实现。
