# Wanderburg → Godot 完整映射蓝图（Mapping Blueprint v1）

日期：2026-10-07。依据：`docs/wanderburg-re-deep-dive.md` + 588 个反编译 C# 精读（ModuleSelection/Rarity/Module2/VMBaseStats/StringCipher/SaveGame/Artifact）。本文是逆向内容 → `game/` Godot 4.7.2 实现的唯一映射入口；所有实现以确证签名为准，方法体不抄袭（本项目重写算法，仅对齐结构与语义）。

## 1. 架构层映射（Unity → Godot 4）

| Unity 概念 | Wanderburg 实现 | Godot 4.7 对应 |
|---|---|---|
| MonoBehaviour 组件 | Module2 / VM / Boss… | Node 派生脚本（`class_name`） |
| ScriptableObject 数据 | VMBaseStats、InfoObject | `Resource`（`.tres`） |
| SerializedCollections | `SerializedDictionary<K,V>` | `Dictionary` + Resource 存储 |
| ProbabilityList<T>（RNGNeeds） | 加权抽取容器 | `ProbabilityList`（自研，见 §2.1） |
| AnimationCurve | 移动/成长曲线 | `Curve` |
| Vector4 upgradeState | 模块升级状态 | `Vector4`（Godot 同名类型） |
| Addressables 2.7.6 | bundle 加载 | `ResourceLoader` + `res://` 目录约定 |
| FMOD bank | 音频事件树 | AudioStreamPlayer + 事件名常量表（后置） |
| TMP_Text / Image | UI | Label / TextureRect |
| Coroutine | 协程 buff 到期 | `await` / Timer / 状态时间戳 |

## 2. 核心系统实现规格（按精读确证）

### 2.1 概率底座：ProbabilityList（源：RNGNeeds 引用 + ModuleSelection 用法）
- 语义：`(item, weight)` 集合；`total_weight` 归一化；`roll(rng)` 按权重抽取；支持拷贝（CopyArtifactPool 语义：临时池不影响原池）。
- Godot：`game/scripts/rng/probability_list.gd`（RefCounted，泛型用 Variant 项）。

### 2.2 Luck/稀有度引擎（源：ModuleSelection）
- Rarity 四档：`Common/Uncommon/Rare/Epic`（枚举 0-3，确证）。
- 字段确证：`LuckBaseWeights`、`PositiveLuckScaling`、`NegativeLuckScaling`（float[]，具体数值在原生码，首版用占位可调参数，留 GAP 标注）、`positiveLuckRamp`。
- API 复刻：`roll(luck) -> int`、`rarity_probabilities(luck) -> Vector4`（common/uncommon/rare/epic）、`calculate_luck_weights`、`effective_positive_luck`。
- Luck 单属性贯穿三池：新模块 / 模块升级 internalRarity / 神器（含 rare 池与 reroll 缩放，`GetUnlockedNewModuleCountForRerollScaling` 语义：未解锁模块数参与 reroll 权重）。

### 2.3 模块系统（源：Module2，1859 行）
- 身份：`module_id/module_name/module_description/display_image/rarity:float`。
- 槽位（确证枚举）：`None/Front/Side/Back/Top/Crew/Captain` → Godot 用位标志或 String 数组。
- 能力双轨（确证字段组）：主动 `active_*`（base_damage/base_cooldown/duration/range/ammo/size/speed + charges）；被动 `auto_*`（同名组）。冷却缩减累计值单独存（total_added_cooldown_reduction），升级后重缩放运行中冷却（RescaleRunningCooldowns 语义）。
- 升级体系：`upgrade_state: Vector4`（ult/passive/cooldown/size 四维计数）+ `legendary_a/b`、`special_0a/0b/1a/1b` 布尔；每个模块带 `upgrades_pool + legendary_pool + special×4`。
- 事件面（确证 20+ 个）：安装/激活开火/升级各维/冷却恢复/挂载 — Godot 用 `signal` 一一对应（首版建 8 个高频信号）。
- 挂载：slot 预留/枢轴/世界缩放捕获 → Godot `Marker3D` 槽位 + 安装时 scale 捕获。

### 2.4 载具（源：VM 3016 行 + VMBaseStats）
- 基础属性（确证）：collider/navmesh/harvester/magnet 四组变换 + mass、maxHP、vehicleSize(+rank)、nextUpgrade 链、maxNitro/消耗/回复、maxVelocity(±reverse)、4 条移动曲线、鼠标转向容差、对齐强度、`active_slots_capacity`（确证 4 槽）、`can_absorb_vehicles_of_size_rank` + `collector_radius`（吞噬成长）、敌方 range_add、蜘蛛践踏伤害。
- 输入三态：mouse/keyboard/controller（确证）；状态机：burning/fear/stun/slow/invincible/shield/nitro/overheat（协程到期 → Godot 时间戳 + process 检查）。
- 现状对齐：`vehicle_controller.gd` 已有载具控制，按 VMBaseStats schema 扩展属性并接吞噬成长。

### 2.5 升级选择流（源：ModuleSelection 四套选择）
1. 新模块 3 选 1（locked 预览可选显示）、2. 模块升级 3 选 1（internalRarity 池 + reroll）、3. 神器 3 选 1（普通/rare 双池 + fallback 保底 + reroll）、4. 载具升级 2 选 1（Tier2-5 底盘池 + A/B 变体 + 8 项属性快照对比行）。
- 传奇/特殊升级三档标题（normal/legendary/special）+ 四档颜色（previous/new/rare/veryRare/veryveryRare）。
- 神器保底语义（确证）：`artifact_fallbacks + rare_artifact_fallbacks`，缺失槽位从 fallback 填充；rare 选择有独立标记。

### 2.6 神器（源：ArtifactSystem 50KB + ArtifactOption + Artifact）
- 数据面：`rare: bool`、`artifact_factor: float`、icon、infoObject（名称/描述/本地化）、effect 实现。
- 效果面：Tag 体系（ArtifactTag/Grant/Requirement/SlotRequirement/BuildRequirement）→ Godot 用 `tags: Array[StringName]` + 修饰器模式；reroll 次数与 luck 缩放挂钩（确证 Reroll 目录存在 luck 缩放）。

### 2.7 存档（源：SaveGame v7 + StringCipher）
- 字段（确证 v7）：save_version、save_channel、progress_reset_generation、last_saved_utc_ticks、last_loadout:int[]、last_deco:int[]、unlocked_ids、unlocked_and_new、silver、silver_before_last_run、statistics、lifetime_statistics、last_completed_run_statistics、achieved_quests、quest_progress:Dict、unlocked_biome_ids。含 Normalize/迁移/去重与 build identity 校验（MatchesBuildIdentity）。
- 加密（确证）：AES-256 + 1000 轮派生 + 随机熵；口令硬编码（仅作研究）。Godot：`save_service.gd` 升级为 envelope v7 结构 + 版本迁移 + 校验和；加密用 `crypto.gd`（AES-CBC，ProjectSettings 密钥，不硬编码，留 GAP）。
- 反作弊参考：GoldScoreLegitimacyTracker（金币合法性）→ 首版记录收益流水。

### 2.8 经济/任务/群系（确证类）
- 双货币 Silver/Gold；磁吸收集（VehicleItemMagnetDrop + dropChance 走 ProbabilityList）。
- Quest：achieved_quests + quest_progress 字典 + ProgressionGoals。
- Biome：BiomeData/BiomeLock + DesertKey/SwampKey/SandstormSpawner（锁钥 + 环境事件）。
- 船长 15+（被动天赋载体）、Boss 10+（阶段控制器类：CannonPhase/ClubKing/Davinci/Kanoningen/Mortar/Pyramid/TankSpinner/RammeMortar/Mouth/GraveCross）。

### 2.9 内容规模目标（对齐 data.unity3d 统计的"玩法等价物"）
- 模块 40+（FrontCannon/SideCannon/TopCannonTower/TopMortar/TopArcher/Ballista/BackDash/BackMineLayer/BackTrail/Ramme/Repair/Teleporter/SideFlamethrower/四系法师/船员系/Barracks×2/Arms/TurretLayer…）
- 主动技能 13、神器 ≥30（含 rare 池）、Boss 10、船长 15、群系 3+（草地/沙漠/沼泽）、任务 20+。
- 首批里程碑见 §4。

## 3. 目录规划（game/ 内）

```
game/
  scripts/rng/probability_list.gd, luck_engine.gd
  scripts/selection/selection_engine.gd（四套选择的纯逻辑层）
  scripts/content/module_definition.gd(v2 扩展), artifact_definition.gd, vehicle_stats.gd, upgrade_definition.gd
  scripts/systems/save_v7.gd, quest_system.gd, economy.gd, biome_lock.gd
  content/modules/*.tres（40+）, content/artifacts/*.tres, content/vehicles/*.tres
  content/quests/*.tres, content/biomes/*.tres
  scenes/selection_ui.tscn（四套选择面板）
  tests/luck_flow.gd, selection_flow.gd, save_v7_flow.gd
```

## 4. 实施批次（子工作流 C）

- C1（2026-10-07 完成）：概率/Luck 引擎 + Module2 对齐 schema v2 + 神器/载具/升级 schema + 四套选择纯逻辑 + 存档 v7 envelope + 行为测试（`luck_flow` PASS）。
- C2（2026-10-07 完成）：选择 UI（`selection_ui.gd`，四色卡片 + reroll）+ v2 内容目录首批 12 模块（法师 4/船员 4/炮塔 4，`content_v2_catalog.gd`，`content_v2_flow` PASS）。
- C3（2026-10-07 完成）：载具成长运行时（`vehicle_progression.gd`：Tier 链 + 吞噬升阶 + 4 主动槽状态机，`progression_flow` PASS）。
- C4（2026-10-07 完成）：单局系统束（`run_systems.gd`：双货币 + 流水审计 + 任务 + 磁吸掉落 + 神器 Tag 修饰聚合，`progression_flow` PASS）。
- 主干接线（2026-10-07 完成）：main.gd 挂载 SelectionEngine/SelectionUI/RunSystems/VehicleProgression；F7 触发新模块 3 选 1；回收事件驱动任务与吞噬成长。全量回归 11/11 PASS。
- C5（2026-10-07 完成）：Boss 阶段框架 + 首个 Boss「卡诺宁鲸王」（`boss_entity.gd`：三阶段状态机 + 王冠呈现，复用 EnemyDummy 战斗协议，F8 召唤）；群系锁钥延后（GAP）。
- C6（2026-10-07 完成）：音频事件表（`audio_event_table.gd` 19 事件语义名对齐 FMOD 树）+ `wanderburg_audio.gd` 事件驱动节点（兼容旧 play_feedback API）。
- 最小切片（2026-10-07 完成）：S3 桥接（`content_bridge.gd`：12 个 v2 模块过旧目录校验、进装配器可预览可安装）+ 技能施放（1-4 数字键走成长系统冷却闸门 → AbilityEffects 战斗映射 → try_engineering_hit）+ `module_visual.gd` 通用 v2 视觉分支。全量回归 12/12 PASS + m0_smoke PASS。
- 群系锁钥机制（沙漠/沼泽）：C7（2026-10-07 完成）——`scripts/systems/biome_system.gd`（BiomeData/BiomeLock/DesertKey/SwampKey 签名对齐：锁门查钥匙、钥匙即神器、持钥匙永久解锁）+ `biome_gate.gd`（锁门世界物）+ `biome_key_pickup.gd`（钥匙拾取）+ `biome_weather.gd`（沙暴/气泡粒子）+ arena_visual.apply_biome 群系调色；G 键轮换切换、F5/F9 快照含 `unlocked_biome_ids`、GM `biome/goto/grant_key` 命令；`tests/biome_flow.gd` PASS（marker 已注册）。
- 技能召唤分支：C7（2026-10-07 完成）——`scripts/systems/summon_entity.gd`（炮塔/EMP/营地三形态，对齐 TurretLayer/Barracks/ForcePush 语义重写）；5/6/7 施放 + 9/14/16 秒冷却；GM `summon` 命令 + 面板按钮；修复 `vehicle_progression.tick()` 冷却从未递减的既有缺陷（现每帧接线）。
- C7 验收：全量回归 14/14 PASS（headless）+ RTX 5080 真 GPU 截图验收（GM 面板群系行 / 沙漠琥珀调色 + 沙暴带 / 炮塔召唤在场），截图在 `artifacts/qa/c7_*.png`。
- C8 资产烘焙流水线（2026-10-07 完成，口径修正：GameObject ≠ 资产——运行时代码拼装的实体此前磁盘为 0 文件）：`procedural_visuals.gd` 共享几何库（运行时兜底与烘焙器同源）+ `tools/bake_assets.gd` 烘焙器 → `assets/generated/props/` 8 个 tscn（炮塔/EMP/营地/双门/双钥匙/Boss王冠）+ `assets/generated/audio/` 19 个 wav（全事件表）；运行时四类实体改为资产优先加载、缺失才代码重建；音频合成提升为 AudioEventTable.synth_stream 静态共享（删除双实现）。测试 `asset_bake_flow.gd`（产物在盘/可加载/运行时确走资产）PASS；真机截图 `artifacts/qa/c8_baked_assets.png` 验收烘焙实例渲染。回归 15/15 PASS。
- C6 实机音频资产：已落 WAV 资产底座（19 事件烘焙文件，资产优先加载）；GAP：人工录制/采样级音效替换合成波形。
- C9-C16（2026-10-08 完成，补记）：Boss 花名册 11 / 神器 30 / 船长 15；Weaver 部件化资产 49 件（v3 风格统一）；UI P5 v2；敌人花名册（小怪 5 / 精英 2 / 新 Boss 吞河蟾）。
- C17 完整交互 + 手感（2026-10-08 完成）：
  - 手感层 `scripts/feel/game_feel.gd`：顿帧 / trauma 震屏（camera h/v_offset）/ FOV 冲击 / 伤害数字（暴击·灼烧·冰·电·治疗·受伤六色）/ 受击闪白（material_overlay）/ 受伤暗角 / 慢动作 / 冲击环；相机改为紧跟 + 瞄准前瞻，Boss 在场拉远。
  - 状态机 `scripts/systems/status_effects.gd`：burning/fear/stun/slow/invincible/shield/nitro/overheat 八态，载具与敌人共用；受击无敌帧 0.4s、冲刺 = 氮气 + 0.28s 无敌（完美闪避计数）、热量满过热 2.2s、Boss 控制抗性。
  - 战斗读招：近战前摇（站定 + 赭黄闪）、远程可躲弹道 `combat/projectile.gd`、地面预警 `combat/telegraph.gd`（精英犀牛直线、电鳗圆圈、Boss 全部招式）、击退。
  - 内容：模块 40（`content_v2_catalog.gd`）× 38 种施放行为（`systems/ability_library.gd`）；模块升级池 11 项（UpgradeDefinition，含传奇/回响/必暴）；载具 2 选 1（rank 2/4 触发，重装/迅捷两档变体）；选择排队；任务 24（`run_systems.gd` + HUD 追踪）；Boss 11 个各 3 招按阶段解锁（`systems/boss_patterns.gd`）；磁吸掉落 `combat/loot_pickup.gd`；地面区域 `combat/area_hazard.gd`（地雷/火墙/焦油/电磁塔/治疗）。
  - 存档：`systems/save_crypto.gd`（AES-256-CBC + SHA-256×1000 派生 + HMAC 防篡改，盐走 ProjectSettings `reclaimer/save/salt` + 本机 ID，不硬编码口令）+ `systems/profile_store.gd`（SaveV7 envelope 原子写，合同结算写生涯档）。
  - HUD `ui/combat_hud.gd`：Boss 血条（延迟扣血尾巴 + 阶段刻度）、状态签、HEAT 警告、任务追踪、招式喊话、技能名。
  - 验收：19/19 回归 PASS（新增 `tests/c17_feel_flow.gd`）；真机截图 `artifacts/qa/c17_feel/`。
- 剩余 TODO（C17 后）：Luck/掉落/重抽原生精确数值（需 Java + Ghidra）；真实采样音效；GM 面板以外的局外菜单（档案银币的花费出口）；模型减面/LOD；B03/B04 等腿部拆分精度；营地服务板 v3 重做。

## 5. GAP 与合规

- `LuckBaseWeights/PositiveLuckScaling/NegativeLuckScaling` 数值在原生码中，首版用可调占位（在 luck_engine.gd 顶部集中定义 + 单测约束总和=1），后续 Ghidra 反汇编 RVA `0x5E9A50` 一带可精确还原。
- 所有算法为语义级重写，不复制 Wanderburg 代码/资产；加密密钥不入库。
- 方法体细节（协程真实逻辑、随机种子策略）标注 GAP，按动态验证补。
