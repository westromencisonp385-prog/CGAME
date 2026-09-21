# Wanderburg 发布包审计说明

审计日期：2026-09-20。目标目录：`F:\SteamLibrary\steamapps\common\Wanderburg Game`。

## 结论

该目录是 Windows Unity IL2CPP 发布包，不是 Unity 编辑器工程，也不是 Godot 工程。文件包括 `UnityPlayer.dll`、`GameAssembly.dll`、`Wanderburg_Data`、`il2cpp_data/Metadata/global-metadata.dat` 和 `StreamingAssets`。审计未发现 `project.godot`、`ProjectVersion.txt`、`.unity`、`.prefab`、`.cs` 或 `.tscn` 源项目标记。

`data.unity3d` 头部嵌入 Unity `6000.0.63f1`。目录共 87 个文件，约 703 MiB。打包程序集名称显示该版本部署了 URP、Cinemachine、Input System、Addressables、Localization、FMOD、Steamworks.NET/Heathen、LeanPool 和相关 UI/特效库；这是依赖证据，不是核心玩法的调用图。

## 可复现审计

在工作区运行：

```powershell
& 'C:\Users\Administrator\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' `
  tools/audit_reference_release.py `
  --reference 'F:\SteamLibrary\steamapps\common\Wanderburg Game' `
  --output evidence/wanderburg_release_audit.json
```

脚本只读取文件清单、Unity 配置 JSON、Addressables link、发布包头和 IL2CPP 元数据的名称表。它不提取贴图、模型或场景，不修改发布包，不恢复方法体，也不声称得到源代码。`evidence/wanderburg_release_audit.json` 保存了 SHA-256、文件大小、程序集名、运行时初始化器、Addressables 设置、保留类型、1263 个 Assembly-CSharp 类型记录和嵌入的 `Assets/...cs` 路径名。

## 有用的名称线索

元数据名称表中出现了可用于系统假设的类别：

- 地图与流程：`Biome`、`BiomeData`、`MapGenerator`、`OverworldLevel`、`OverworldManager`、`PointOfInterest`、`EventCompound`。
- 载具与战斗：`OverworldVehicleController`、`AgentVehicle`、`VehicleModuleTransfer`、`AttackModuleV2`、`AttackModuleRam`、`ProjectileV2`、`Boss...`。
- 波次与敌人：`WaveSpawner`、`EnemySpawner`、`EnemyType`、`SpawnPattern`、`SpawnRarity`、`NavAgent`。
- 构筑与局外：`ModuleUpgrade`、`ModuleSubUpgrade`、`ArtifactSystem`、`Artifact...`、`Captain...`、`VehicleUpgrade`、`SimpleUnlocker`。
- 任务与统计：`QuestSystem`、`QuestData`、`QuestChecker`、`GameStatisticsTracker`、`StatisticsManager`、`AchievementManager`。
- 存档与平台：`SaveGame`、`SaveLoad`、`SteamTools.Game`、`Leaderboards`、`Achievements`、`Steamworks`。

这些名称能够支持“移动载具 + 地图/群系 + 波次/首领 + 模块/神器/船长 + 任务/统计 + 局外解锁 + Steam”的高层假设；它们不能证明字段含义、数值、节点关系、Prefab 布局或内部算法。嵌入的路径还包含测试和过时脚本，因此不应把数量当作运行时内容数量。

## 不能做的事

不要从这个目录复制二进制、模型、贴图、声音、文本、类名或实现；不要尝试把 `GameAssembly.dll` 当作可维护源码；不要把社区 Wiki 对玩法的补充当成官方内部实现。新项目只借鉴公开商店页面和可观察的体验结构，所有美术、代码、命名和数据重新制作并进入自己的授权台账。

## 与原创项目的映射

原项目中的 `WaveSpawner`、`ModuleUpgrade`、`QuestSystem`、`SaveLoad` 等命名提示我们要尽早定义系统边界；原创项目对应为 `EncounterDirector`、`UpgradeService`、`MissionService` 和事务化 `SaveService`。这是架构类比，不是代码移植。原创项目的技术基线、挖掘分块和稳定 ID 规则见 [technical-architecture.md](technical-architecture.md)。

已进一步使用 AssetRipper 2.0.0 做隔离导出。导出资源的结构证据、模块 Prefab 层级、车辆阶段、操控字段、升级预览和 IL2CPP 方法体边界见 [assetripper-analysis.md](assetripper-analysis.md)，统计结果见 `evidence/assetripper_export_inventory.json`。导出缓存不属于原创项目资产，不进入 Godot 发布工程。

## 可复用的系统边界证据

下表来自 `global-metadata.dat` 的 `Assembly-CSharp` 类型、字段和方法名称。它是命名证据，不是源代码调用图；方法体、场景层级和序列化数值都不在发布包中。

| 边界 | 直接证据 | 对 Godot 原创项目的建议 |
| --- | --- | --- |
| 运行流程 | `GM` 有 `StartRound`、`EnterGameplay`、`ExitGameplay`、暂停/统计/控制/主菜单、升级队列、加时、胜负和场景加载方法。 | 用一个显式 run state machine 管理 `PreRun → Dig → Event/Upgrade → Boss → Results`，UI 只订阅状态事件。 |
| 载具 | `VM` 有输入、加速/转向、刹车、Nitro、HP/护盾/治疗、无敌、减速/眩晕/燃烧、地图边界恢复、模块槽；`VMBaseStats` 有 49 个基础统计字段。 | 建立 `VehicleStats` Resource 与 `VehicleController`，按“基础车体 + 挖掘机升级 + 工具/附件 + 永久解锁”计算当前值。 |
| 模块/升级 | `Module2` 有主动、被动、冷却、尺寸、传奇/特殊升级、挂载和槽位计数；`ModuleSelection` 生成新模块、模块升级、神器和载具变体选项及重掷。 | 把 `ModuleDefinition`、`UpgradeDefinition`、选择池和预览计算做成纯数据服务，场景只负责表现。 |
| 战斗/波次 | `AgentVehicle` 处理 NavAgent、目标、友军跟随、冲撞、攻击模块、受伤/死亡/吸收；`AttackModuleV2` 有目标、攻击循环、投射物池、多炮管/激光/火箭；`WaveSpawner` 有预编程、群体、常规、加时和 Boss 生成。 | 将 `DamageReceiver`、`Targetable`、`Harvester`、`Poolable` 设为接口；Encounter Director 以数据表控制波次并支持固定种子。 |
| 地图/群系 | `Biome`、`BiomeData`、`MapGenerator`（种子、NavMesh、环境、spawners）、`OverworldManager`、`PointOfInterest`、`BiomeLock`。 | 世界地图和单局矿区分离；矿层按种子生成，挖掘网格/区块只加载玩家邻域。 |
| 资源/吸收 | `Harvester` 处理资源、特殊掉落和敌人吸收；`ResourceScriptV2` 支持治疗、Nitro、磁铁、残骸、掉率、满血反弹和血包抑制；另有 `ResourceHolder`、`Mine`、`Coin`、`Magnet`。 | 统一 `PickupPayload`/`HarvestService`，把资源规则做成数据，粒子、音效和 UI 订阅事件。 |
| 构筑与标签 | `ArtifactSystem`（83 方法、211 字段）有神器池、稀有度、重掷、掉落和击杀/吞噬钩子；`ArtifactTagSystem` 有 `HasTag/HasAll/HasAny`、source 增删和 `TagsChanged`。 | 用可组合 Modifier + Tag predicate，载入/替换神器后重建标签，避免把加成硬编码进车体。 |
| 任务/存档 | `QuestSystem` 生成日常任务、注册 checker、排队 UI 和记录本局结果；`SaveLoad`/`SaveGame` 有版本、备份、加密键和默认 loadout；另有解锁器/成就。 | 用事件驱动 Mission checkers；Profile 存档和 Run 存档分离，带版本迁移与原子备份写入。 |
| 统计/平衡 | `GameStatisticsTracker`、`StatisticsManager`、`RunBalancingRecorder`、`ModuleDamageContext` 记录局内/生涯数据、伤害和采样。 | 记录不可变 run events，统计和任务由事件派生；调试采样与发布版本开关隔离。 |
| UI/输入/反馈 | Unity Input System、重绑定脚本、模块/载具/神器/任务/结束/统计屏幕、Localization/TMP、More Mountains Feel、对象池、EPO/UI SoftMask、FMOD。 | 先定义 move/aim/boost/interact/menu/reroll action map；集中反馈事件，池化敌人、投射物、数字和掉落物，特效完成不阻塞玩法。 |

## 发布配置证据

`ScriptingAssemblies.json` 包含 Unity Input System、Cinemachine、Addressables、Localization、Timeline、Animation Rigging、AI Navigation、URP、TextMeshPro、FMODUnity、Steamworks.NET/Heathen 等程序集；`StreamingAssets/aa/settings.json` 报告 Addressables `2.7.6`、本地 `catalog.bin`、启动时不更新 catalog、并发请求上限 3。`link.xml` 保留 Localization 表/locale、ResourceManager providers、TMP 字体和核心 Sprite/Texture/Shader/Material 类型。`RuntimeInitializeOnLoads.json` 共 152 项，包含 `SteamTools.Game.ResetStatics`、`Heathen.GameFramework.GameFramework.Boot`、Heathen Steamworks 的好友/Overlay/Inventory/RemoteStorage/Leaderboard/Stats/UGC 客户端、Input System、Cinemachine、NavMesh 与对象池/反馈初始化。发布包还含 FMOD `Master/Music/FX/Ambience` banks 和 Steam API DLL。

`evidence/wanderburg_release_audit.json` 的 `metadata.application_types` 可复核关键计数：`GM` 125 方法/98 字段、`VM` 134/247、`Module2` 125/158、`ModuleSelection` 83/71、`WaveSpawner` 87/97、`AgentVehicle` 79/96、`ArtifactSystem` 83/211、`QuestSystem` 22/13、`SaveLoad` 90/29、`AttackModuleV2` 29/111。`metadata.source_path_names` 是嵌入路径字符串（563 条，含插件、示例、测试和过时代码），不能按数量推断运行时内容。
