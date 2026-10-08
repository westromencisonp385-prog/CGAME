# Wanderburg 深度逆向报告：IL2CPP 元数据 + 反编译 + 资源全量清单

日期：2026-10-07。本轮在 AssetRipper 静态导出（见 [assetripper-analysis.md](assetripper-analysis.md)）之上，完成了此前缺失的**代码逻辑层还原**，形成"结构 + 签名 + 内容 + 资源"四层完整证据链。

## 0. 本轮新增能力（相对 AssetRipper）

| 层 | AssetRipper（旧） | 本轮 Il2CppDumper + ilspycmd（新） |
|---|---|---|
| 类型/字段 | 有 | 有（等价） |
| 方法签名 | 有 | 有，且带 `metadata token` 与 `RVA/VA` 原生地址 |
| 方法体 | 空/stub | 仍为原生码，但每个方法可通过 RVA 在 `GameAssembly.dll` 中定位（可供 Ghidna/IDA 反汇编） |
| 字符串常量 | 无 | `stringliteral.json` 全量 20,441 条 |
| 原生方法映射 | 无 | `script.json` 121.9 MB，全部 18,000+ 方法地址 |
| 资源清单 | 845 纹理等 | `data.unity3d` 全量对象统计（见 §5） |

工具链：Il2CppDumper 6.7.46（Metadata v31 / Il2Cpp v31）+ ilspycmd 9.0。**复现命令**：

```powershell
Il2CppDumper.exe <GameAssembly.dll> <global-metadata.dat> <outdir>
ilspycmd -p -lv CSharp10_0 -o <outdir> <DummyDll>\Assembly-CSharp.dll
```

## 1. 引擎与部署事实（确证）

- Unity **6000.0.63f1**，IL2CPP，Windows x64，URP 渲染管线
- Metadata 版本 31；CodeRegistration/MetadataRegistration 均自动定位成功
- Addressables 2.7.6（`catalog.bin` + 本地 bundle）；FMOD 音频（5 个 bank：Master/FX/Music/Ambience + strings）
- 第三方栈：Steamworks.NET + Heathen、MoreMountains（Corgi 风格工具集）、NaughtyAttributes、SerializedCollections、EPOOutline、ChocDino.UIFX、TMPEffects、TextMeshPro、Unity Localization（18 语言）、Burst/Collections/Mathematics、Newtonsoft.Json

## 2. 代码还原结果

- 反编译 C# 文件：**588 个**（Assembly-CSharp，约 400 个游戏逻辑类 + 编译器生成类）
- DummyDll 全程序集 87+ 个；主逻辑集中在 `Assembly-CSharp`（2.0 MB）与 `MoreMountains.Tools`（2.0 MB）
- 所有方法带 `[Address(RVA=..., VA=...)]`：如 `ModuleSelection.Roll(luck)` @ RVA `0x5E9A50`，可导入 Ghidra 直接反汇编（本机暂无 Java，未执行，路径已铺好）

### 内容花名册（从类名完全恢复）

- **模块（Module2 系列 40+）**：FrontCannon、SideCannon、TopCannonTower、TopMortar、TopArcher、Ballista、BackDash、BackMineLayer、BackTrail、Ramme、Repair、Teleporter、SideFlamethrower、四系法师（Electric/Fire/Force/Laser）、船员系（CrewArcher/Fire/Melee/Racing/Wizard）、Barracks（Front/Back）、Arms、TurretLayer 等
- **主动技能（ActiveModule 系列 13）**：Cannon、Archer、Dash、Flamethrower、ForcePush、MineLayer、Mortar、Ramme、Saw、Shield、Teleport、WallLayer、DamageZone
- **Boss（10+）**：Big Jaw、Crocodile、King Klopp、RostenSchild、Davinci、Kanoningen、Pyramid、TankSpinner、ClubKing、RocketCastle、RammeMortarPhases 等（FMOD 事件名交叉确证）
- **船长（Captain 15+）**：DJCaptain、DieterTheDrunk、Duelist、Empress、Farmer、KapitalistusMaximus、Lumberjack、PatchyThePirate、RacerRuth、RitterRost、TheCount、TheHuntress、TimeWitch、Tankbert 等
- **群系**：Biome/BiomeData/BiomeLock + DesertKey/SwampKey/SandstormSpawner（沙漠、沼泽等有锁与钥匙机制）
- **神器（Artifact）**：完整体系——ArtifactSystem（50 KB 类）、Tag/Requirement/Chooser/Dice/Reroll、传奇池与保底（Fallback）
- **任务**：QuestSystem + QuestData/QuestRunResult/ProgressionGoals
- **存档**：SaveGame v7 + SaveLoad + **AES-256 加密**（`StringCipher`，Keysize=256，1000 轮派生；硬编码口令 `edugfhseufgoqwuiehrieutahl`——已实锤，存档可解）
- **统计/成就**：StatisticsManager（Run/Lifetime 双层）+ AchievementManager + 金币合法性追踪（GoldScoreLegitimacyTracker，反作弊）
- **Debug 工具**：GM.cs、MC.cs、AM.cs（管理员面板 + 波次/难度控制 + RunBalancing 录制器）

## 3. 核心玩法机制（签名级证据）

### 抽卡/升级概率体系

- `ModuleSelection`：`Roll(float luck)`、`GetRarityProbabilities(luck, out common/uncommon/rare/epic)`、`CalculateLuckWeights`、`GetEffectivePositiveLuck`、`LuckBaseWeights` 基础表
- 稀有度四档：`Rarity { Common, Uncommon, Rare, Epic }`；`RarityEntry.baseWeight` + `ProbabilityList<T>` 通用加权抽取容器
- Luck 属性同时影响模块、神器（含 reroll 缩放目录）、载具升级三套池
- 神器有独立 `rareArtifacts` 池 + Fallback 保底机制（防抽不到关键神器）

### 载具与模块运行时

- `VM`（Vehicle Motor，3016 行）：输入三态（mouse/keyboard/controller）、4 个 activeModule 槽、状态机（燃烧/恐惧/眩晕/减速/无敌/护盾/Nitro/过热）、协程驱动 buff 到期
- 模块是运行时对象而非数据条目（详见 [assetripper-analysis.md](assetripper-analysis.md) §2，本轮类结构完全吻合）
- 载具阶段成长：`vehicleSizeRank` + `canAbsorbVehiclesOfSizeRank`（吞噬升级）+ Tier2–5 底盘池

### 经济与掉落

- 双货币：Silver（银币，`VehicleSilverDropChance`）+ Gold；`VehicleItemMagnetDrop` 磁吸收集
- `Agent.dropChance`、`ResourceScriptV2.dropChance` 全走 ProbabilityList

## 4. 音频内容（FMOD 事件全表 69 条）

完整事件树揭示音频设计语法：`Enemies/*`（命中/死亡/步伐按敌人类型分）、`GUI/*`（按钮/升级按稀有度四档不同音效/Loadout 购买/余额不足）、`Music/Jingles/*`（Run Start、BossSpawn 两首 Jingle）、`Projectiles/*`。升级音效随稀有度分级是可借鉴的反馈设计。

## 5. 资源全量清单（data.unity3d，UnityPy 实测）

| 类型 | 数量 | 说明 |
|---|---:|---|
| GameObject | 108,547 | 含 UI/预制/场景内对象 |
| Mesh | 1,490 | 3D 模型网格 |
| Texture2D | 854 | 与 AssetRipper 845 张统计吻合 |
| Sprite | 716 | UI 图标/2D |
| Material | 901 | |
| Shader | 259 | |
| ParticleSystem | 12,631 | 粒子特效（AssetRipper 未覆盖） |
| VisualEffect | 624 | VFX Graph 特效 |
| NavMeshAgent | 1,694 | 敌人导航 |
| MonoScript | 5,168 | 脚本引用 |

加上 AssetRipper 已证的 5 场景（Start Menu/Overworld/Preload/SplashScreens/MAIN SCENE）+ 749 Prefab，内容规模画像完整。

## 6. 交付物与路径

| 产物 | 路径 |
|---|---|
| IL2CPP dump（dump.cs/il2cpp.h/script.json/stringliteral.json/DummyDll） | `D:\工作\InverseGame\WaWa\wanderburg_re\il2cpp_dump\` |
| 反编译 C#（588 文件） | `D:\工作\InverseGame\WaWa\wanderburg_re\decompiled\Assembly-CSharp\` |
| 字符串/资源分析 JSON | `D:\工作\InverseGame\WaWa\wanderburg_re\analysis\` |
| 工具（Il2CppDumper + 分析脚本） | `D:\工作\InverseGame\WaWa\tools_re\` |

## 7. 边界声明

- 方法体仍是原生机器码；签名/RVA/字段/字符串是确证事实，**算法实现需 Ghidra 反汇编才可读**（script.json 已提供 Ghidra 脚本与地址映射）
- 未运行游戏做动态 dump；协程真实逻辑、随机种子、数值曲线需动态分析或反汇编
- 所有 Wanderburg 资产/代码仍是参考作品，只作研究证据，不进入 `game/`

## 8. 对 Reclaimer 的三条直接启示

1. **概率系统分层**：Wanderburg 用统一的 `ProbabilityList<T>` + Rarity 四档 + Luck 单属性贯穿模块/神器/载具升级三套池——比多套独立随机更可平衡、可测试。我们的 100+ build 目录可直接采用该结构。
2. **稀有度反馈分级**：升级音效按 Common→Epic 四档变化 + Jingle 标记 Boss/开局，是低成本高感知的设计。
3. **存档加密是常识级防线**：AES-256 + PBKDF 风格派生（虽然口令硬编码可解）。我们的存档 envelope 应加校验值与版本迁移（已在 spec 中），加密可后置。
