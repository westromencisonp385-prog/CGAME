# 《挖掘机拯救世界》技术架构

状态：2026-09-21更新。已有M0；本文包含后续目标，未验证条目不能当成完成。环境、GM与图形验收以README和CLI工作流为准。产品范围见 [游戏设计](game-design.md)，阶段安排见 [开发路线](roadmap.md)。

## 1. 已确认的环境与研究边界

- 本地引擎：`C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Links\godot_console.exe`，实际 `--version` 输出 `4.6.3.stable.official.7d41c59c4`。这是原始基线记录。当前采用 **Godot 4.7.2 stable**，配套相同版本 export templates；当前机器的 `AppData/Godot/export_templates` 尚未确认安装，M1 需通过 Export Template Manager 或离线包补齐并记录校验。
- 当前开发机记录为 Ryzen 7 9800X3D、RTX 4070 Ti SUPER、约 64 GB 内存；它只用于编辑器和开发基准，不能代表 Steam 最低配置或 Deck 性能。
- `F:\SteamLibrary\steamapps\common\Wanderburg Game` 是 Unity IL2CPP Windows 发布包：包含 `UnityPlayer.dll`、`GameAssembly.dll`、`Wanderburg_Data`，不是可直接打开的完整源工程。
- 其中 `ScriptingAssemblies.json` 可确认打包了 URP、Cinemachine、Input System、Addressables、Localization、FMOD、Steamworks.NET/Heathen、LeanPool 等程序集；`Plugins` 与 `StreamingAssets` 中存在 Steam API、FMOD DLL/音频 bank、Addressables 资源及多语言 bundle。
- **程序集存在只能证明被打包，不能证明某个玩法使用了它，也不能据此还原其类结构、算法或数据关系。** 本文不把这些线索当作已验证的 Wanderburg 源码架构，更不依赖其商业模型、音频或贴图开展新项目。
- 已进一步用 AssetRipper 2.0.0 对发布包做隔离导出：5 个场景、749 个 Prefab、845 个纹理和 707 个 C# 导出文件。导出方法体对 IL2CPP 仍是空/stub，但 Prefab 层级、字段、脚本签名和模块/载具资源命名可作为结构证据，详见 [AssetRipper 深度分析](assetripper-analysis.md) 与 `evidence/assetripper_export_inventory.json`。

## 2. 技术栈决策

| 项目 | 决策 | 原因与边界 |
|---|---|---|
| 引擎/语言 | Godot 4.7.2，静态类型 GDScript | 场景、Inspector、热迭代链路短，减少个人维护两种语言的成本。未证实的性能问题不提前用 C++ 重写。 |
| 画面 | 3D 斜俯视，固定旋转角度的正交/弱透视相机；低多边形模型 | 旋转机械臂、可换工具、体量成长在 3D 中更易统一；玩法主要在 XZ 平面进行。相机投影由原型实际可读性决定，切片前冻结。 |
| 渲染 | **Mobile 渲染器作为制作基线**，Vulkan 优先 | 适合简单风格化 3D；一盏主要方向光、有限阴影、基础雾与粒子。首版不依赖体积雾、SDFGI、屏幕空间反射。其他渲染器只在 M0 基准暴露阻碍时评估。 |
| 物理 | 内置 Jolt，固定 60 Hz；主要玩法由脚本状态控制 | 底盘使用 CharacterBody3D；动态刚体主要用于短寿命碎片、投掷反馈。机械臂不做完整液压与多关节刚体模拟。 |
| 数据 | 自定义 Resource `.tres` + PackedScene `.tscn`；稳定内容 ID | Inspector 可编辑、Git 可审查；每个资源定义的运行状态独立保存。 |
| 界面 | Godot Control、Container、Theme、原生焦点导航 | UI 与战斗分层；1920×1080 设计基准，同时检查 1280×800、16:9、16:10 与超宽屏。 |
| 音频 | 原生 AudioStreamPlayer/3D + AudioServer 总线 | 先建立引擎负载、履带、液压、材料撞击和音乐分层；首版不引入 FMOD 的额外依赖与工作流。 |
| 美术管线 | Blender → glTF/GLB；Krita 等绘图工具；源文件与导出文件分开 | 模型按统一米制、轴向、枢轴和插槽导出；以模型轮廓、材质与动作区分升级。 |
| 平台 | Windows x86_64 优先；Steam Deck/Proton 作为专项测试 | 原生 Linux 是增量平台，未通过真机/设备测试不在商店承诺支持。 |
| Steam | GodotSteam **GDExtension**，封装平台适配层 | 不需要自编引擎。具体插件版本在 M1 兼容性试验后锁定，和引擎、SDK、导出模板共同记录。 |
| 版本管理/构建 | Git；大二进制源资产用 Git LFS；脚本化 headless 导入/检查/导出 | 仓库保存 UID 文件，忽略 `.godot` 缓存、个人凭据、Steam 密钥、构建输出。 |

Godot 官方区分 Mobile、Forward+、Compatibility 的特性和硬件范围；切换渲染器可能需要重调材质与光照，因此应在切片前做选择，不能把最终自动回退当作经过验证的兼容模式。[渲染器说明](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)

### Godot 模块、GDExtension、C# 的取舍

1. 游戏玩法默认用 GDScript 和场景节点。先让数据、事件与生命周期清晰，再做实测优化。
2. Steam 用 GDExtension：更新第三方二进制即可，不把团队绑定到自编 Godot。使用普通 Godot 导出模板，不能混装 GodotSteam module 与 GDExtension 两种实现。
3. 不引入自定义引擎 module。只有正式版出现引擎缺陷或性能瓶颈，且官方接口与 GDExtension 均无法解决，才建立引擎分支。
4. 不以“以后可能很多敌人”为理由引入 C#。若采样明确显示某纯计算模块是瓶颈，可独立比较优化 GDScript、批处理和 GDExtension；保留相同数据接口，避免重写整个游戏。
5. 原生扩展必须有来源、版本、许可证、支持平台、重建方式和回滚包。插件升级只在开发分支进行，并重跑导出验收。

GodotSteam 当前资产页明确说明两种集成方式不能混用，GDExtension 应使用标准导出模板；其 GitHub 仓库已迁至 Codeberg。资产页当前版本标记为 unstable，因此不把“最新版”直接写进生产依赖。[GodotSteam 资产页](https://store.godotengine.org/asset/godotsteam/godotsteam-gdextension/) · [官方仓库迁移说明](https://github.com/GodotSteam/GodotSteam)

## 3. 主程序结构

```text
AppRoot
├─ AppFlow                  启动/主菜单/营地/出击/结算状态切换
├─ Services
│  ├─ SaveService           存档事务、校验、迁移与恢复
│  ├─ SettingsService       音量/画面/输入/辅助功能
│  ├─ ContentCatalog        ID → 只读定义、合法性校验
│  ├─ PlatformService       SteamAdapter / OfflineAdapter
│  └─ AudioDirector         总线、音乐状态与限流
├─ Session                  单次合同的所有权边界
│  ├─ RunController         当前目标、失败/撤离/胜利
│  ├─ World                 关卡块、地面状态、修复对象
│  ├─ EncounterDirector     敌人预算、波次、难度节奏
│  ├─ EntityRegistry        稳定 ID → 活跃实体
│  ├─ PlayerVehicle         底盘/转台/工具/货舱/受击
│  └─ RunState              随机种子、阶段、奖励、变更集
└─ UI                       菜单/HUD/升级选择/结算/弹窗
```

推荐让 AppRoot 注入服务。确需跨场景存续的设置、存档和平台服务可使用少量 Autoload；局内敌人、掉落、任务和升级不做全局单例。退出 Session 就应结束其计时器、信号连接、异步任务与效果。

模块访问规则：外部不能直接改另一个系统的内部状态。操作由命令表达（如 `request_equip`、`apply_damage`、`commit_run_result`），完成后发带稳定 ID 的事件。高频物理查询直接调用明确接口，低频跨系统通知使用信号；不建立一个承载全部玩法的无类型全局事件总线。

Godot 官方建议把子场景做成可独立实例化的单元，并根据对象的实际生命周期组织场景树；节点执行行为，Resources 承载数据。[场景组织](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html) · [Resources](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)

### 模块职责及验收

| 模块 | 自己负责的数据/行为 | 首次验收 |
|---|---|---|
| VehicleMotor | 速度、加速度、转弯、碰撞、负载减速 | 键鼠和手柄均能绕桩、倒车、脱困，镜头不眩晕 |
| ToolController | 扫击、抓取、挖掘、投掷的状态、时机和目标筛选 | 一次攻击对同一目标不重复结算；打击与音画同步 |
| Harvest/Destruction | 材料、硬度、剩余量、地块状态、产出 | 同一土堆不能无限领取；清除后路径正确开放 |
| Cargo | 容量、携带内容、收集/倾倒 | 视觉货物与真实资源账一致，取消动作不复制物品 |
| Combat | 伤害、韧性、击退、状态效果、死亡 | 一次死亡只发一条权威死亡事件 |
| Upgrade/Economy | 定义、前置、局内/局外货币、装配 | 同种构筑可重建；替换组件数值不累计泄漏 |
| WorldRepair | 修复节点的前置、消耗、阶段与外观 | 材料扣除与世界状态更新在同一事务中提交 |
| Encounter/AI | 威胁预算、刷怪点、敌人状态和路径 | 出生点不在镜头中心/阻塞处；任务不因敌人卡住停摆 |
| Mission/Run | 主目标、可选目标、撤离/失败/结束 | 所有结局都能安全返回营地，不会重复结算 |
| UI/Accessibility | 输入焦点、提示、可读性、字幕、辅助模式 | 全流程可用手柄完成，支持缩放、震动/闪光强度设置 |
| Platform/Build | 成就、云存档配置、日志、导出版本 | 从 Steam 客户端启动实际导出包成功，不依赖编辑器 |

## 4. 挖掘机的实现方式

### 底盘与机械臂

- **街机驾驶**：CharacterBody3D 沿地面移动，代码控制加速度、刹车、转向和击退。履带贴地用采样射线/视觉倾斜表现，碰撞体保持简单；动画与玩法坐标分开。CharacterBody3D 本来就是供脚本控制、具有墙体和坡面检测的物理体。[官方类说明](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- **底盘与上装独立**：底盘朝运动方向转，上装朝鼠标投影点/右摇杆方向转。底盘大小、转台、动臂、斗杆、斗/作业头的插槽是资产规范的一部分。
- **操作抽象**：玩家输入的是“在这里扫击/挖起/投掷”，脚本控制可达范围、角速度和动作阶段；不要求同时操作真实挖掘机的多个液压轴。
- **机械臂动画**：两段解析 IK 或预制动作配合目标修正，关节角夹限；伸展、动作重量和液压杆由表现层处理。攻击时机与命中查询按固定物理步执行。固定主挖斗始终负责手动铲击/挖掘/投掷；6 个可换作业工具共享一个自动作业槽，2 个辅助槽装 8 个模块。不存在自由拼接载具，插槽组合必须由定义验证器批准。
- **判定**：扇形/胶囊扫掠 + 空间查询，按 `attack_id + target_id` 去重。抓取物通过临时附着点表现，真正库存归 Cargo 管理；投掷物伤害由明确弹道/碰撞逻辑负责。
- **成长体量**：仅 3 个经过校验的车体尺寸阶段；切换时验证通行宽度、工具射程、相机范围和拾取半径。不可直接无限放大根节点及其物理形状。

内置 Jolt 可用，但其部分关节参数与 Godot Physics 行为不同，因此不会把真实关节机械臂作为核心控制方案。[Jolt 官方说明](https://docs.godotengine.org/en/stable/tutorials/physics/using_jolt_physics.html)

### 浅层挖掘、破坏与世界修复

可交付基线是 **固定地面 + 可清除覆盖层 + 有限高度层 + 预制可破坏物**。玩家清理废土、拆除障碍、开出道路、露出埋藏物，世界由污染态变成修复态。它支持清晰的战斗反馈，不包含任意地下洞穴、悬崖开洞、连续土壤流动或流体模拟。

建议原型从 1 m 逻辑格、16×16 格一块开始，用实测决定是否需要更细。格子只存材料、层数/剩余量、硬度、污染/修复标记、占用状态。一个格不等于一个 Node：静态视觉使用分块网格或批次，交互对象才有节点。

处理顺序：

```text
输入工具动作
→ 物理步查询候选格/对象
→ 校验射程、工具等级、资源余量、攻击去重
→ 权威逻辑更新格子/物体与产出账
→ 标记 chunk 的视觉/碰撞/导航为 dirty
→ 按每帧预算更新受影响区域
→ 播放少量碎片、尘土、音效和吸收动画
```

碎片是表现，不是每块矿物的权威库存。铲走 20 单位废铁不需要创建 20 个持久刚体。大型预制物使用完整/破损/移除几种状态，资源掉落由同一次逻辑结算产生。

导航采用 XZ 平面的可行走网格作为清障区域真值，A* 路径在占用变化时局部更新；只在需要复杂静态地形的区域补充 Godot 导航网格。近距离避让与全局寻路分开。NavigationObstacle 的 avoidance 并不等同于动态重建全局路径，不能把移除障碍后的路径正确性交给视觉碰撞体自动完成。[导航障碍说明](https://docs.godotengine.org/en/4.4/tutorials/navigation/navigation_using_navigationobstacles.html)

## 5. 内容定义、运行状态与稳定 ID

| 定义 | 关键字段 |
|---|---|
| VehicleDef | `id`、基础属性、尺寸阶段、模型、插槽、解锁条件 |
| ToolDef | `id`、标签、动作类型、范围、冷却、材料效率、表现资源 |
| ModuleDef | `id`、兼容槽、属性修正、触发器、装配限制 |
| UpgradeDef | `id`、层级、前置、代价、修正操作、最大叠层 |
| EnemyDef | `id`、生命/韧性、移动类型、攻击集合、奖励表 |
| MissionDef | `id`、biome、地图块池、目标、节奏、奖励、首领 |
| RepairDef | `id`、消耗、前置、结果状态、解锁影响 |
| DropTable | `id`、候选项、权重、上限、保底规则 |

每个定义使用固定字符串 ID，例如 `tool.magnetic_claw`、`mission.quarry_01`。代码不靠文件路径或展示名称认物品。资源路径可随整理变化，存档中的 ID 不能无迁移地改名或复用。

运行状态使用独立 RefCounted/数据对象，保存当前血量、叠层、冷却、库存和任务进度。**加载出来的 Resource 可能被实例共享，禁止把当局血量写回共享定义。** 属性从基础值和修正列表重算，例如“基础值→加法→百分比→封顶”；不要在装备/卸装时反复相加相减导致漂移。

对象 ID 建议：

- 手工放置关键对象：关卡/合同 ID + 编辑器生成的稳定 GUID。
- 程序生成对象：`run_id + chunk_coord + spawn_slot_id`；`spawn_slot_id` 在对应生成算法版本内稳定。
- 土地状态：`chunk_x/chunk_z/cell_index`；只保存改变的格与预制物状态。
- 不保存 `Object.get_instance_id()`、RID、NodePath 或整棵 SceneTree 作为持久标识。
- 存档记录 `content_version`、`generator_version`。种子只能重建同版本生成结果，不保证不同版本、平台或物理过程完全相同。

自动数据验证覆盖：ID 唯一、引用存在、升级依赖无环、费用非负、掉落概率合法、所有合同有可达目标和结束路径、缺翻译、模型插槽缺失、许可证登记缺失。

## 6. 存档、崩溃恢复与防重复结算

### 存什么

使用 `user://`，由三个类别组成：

1. `settings.cfg`：画面、输入、音量、窗口位置；与进度分开，默认不云同步机器特有的显示设置。
2. 玩家档案：永久货币、解锁、装备、修复节点、成就待同步记录、完成的合同、事务历史。
3. 当前 run：`run_id`、合同/生成版本、随机流状态、检查点、车辆状态、局内构筑、任务进度、地图变更集、奖励账、结束状态。

为避免跨文件部分成功，**玩家档案与当前 run 一起写入一个带版本的权威存档 envelope**；地图变更初期也包含其中。若未来必须拆大文件，先完成 manifest/事务设计，不能直接把每个系统各写一个 JSON。

首版支持在合同的安全检查点继续，退出/休眠时提示已保存位置。检查点保存 seed、生成/内容版本、装配、标量进度与改变的格子状态，续玩时重建动态敌人、碎片和表现对象；不承诺恢复每一粒飞行碎屑或逐帧物理。**持久世界的修复/清障只在合同胜利结算时提交；合同失败不会撤销此前已经成功提交的世界修复。** 当前合同未成功提交的变更只属于该 run，可从最近检查点重建或随失败丢弃。不能默默显示“已保存”而实际只保存营地。

### 双槽与恢复

每个档案使用 A/B 两个槽，保存 envelope 包含 `schema_version`、`save_sequence`、`profile_id`、`parent_commit_id`、`commit_id`、内容版本及 payload 校验值。每次写非当前槽：完整序列化→写临时文件→flush/close→重新读回校验→替换目标槽。启动时读取两个槽，选序号最高且校验通过、结构可迁移的一份；损坏槽保留供诊断。文件重命名和本地磁盘故障不能被描述成无条件安全，双槽是恢复保障的一部分。

格式先用 JSON，字段明确且便于迁移；地图差异过大再采用有界的压缩数据段。只读取允许的基本类型，不从存档反序列化任意脚本对象。校验值用于发现意外损坏，不被当作防修改或反作弊机制。Godot 的保存教程可作 API 起点，但商业存档还需要上述事务与迁移层。[存档官方教程](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)

### 一次结算只到账一次

Run 状态机：`ACTIVE → RESULT_PENDING → RESULT_COMMITTED`。

- 关卡胜利/失败先冻结 run，生成唯一 `result_tx_id`，稳定奖励清单和待解锁内容，保存 `RESULT_PENDING`。
- 结算事务在一个新 envelope 中同时写入：奖励到账、永久解锁/修复状态、run 标记已提交、已处理事务 ID、成就待同步事件。
- 保存成功后才播放到账动画、显示最终结算和返回营地按钮。重复触发、重读同一 pending 或重新进入结算页时，检查 `result_tx_id`，已处理则直接显示结果。
- 崩溃发生在 pending 后，恢复时重试同一事务；发生在 commit 后但 UI 显示前，读到已提交状态，不再发钱。
- 成就和 Steam 调用在本地提交之后异步处理，可重试。外部平台不可用不得阻塞离线存档。
- 修复世界、购买永久升级也用“校验→同时扣款与修改状态→提交→表现”的事务模式。

这保证的是同一档案时间线内的崩溃恢复与幂等结算，不承诺解决用户主动复制旧存档或多设备并发分支的经济合并问题。

### Steam Cloud

先使用 Steam Auto-Cloud 同步指定进度路径；云端不是本地事务数据库。测试新机器下载、离线玩后恢复联网、两台设备同档分叉、损坏槽、跨版本迁移。遇到分叉保留两份并让玩家选择，不简单相加货币或只比较本地时钟；显示合同进度/游玩时长/最近检查点帮助选择。上线前确保 Steam 配置的路径与 Godot 的实际 user 数据目录一致。[Steam Cloud 官方说明](https://partner.steamgames.com/doc/features/cloud)

## 7. 输入、可访问性与表现系统

- 输入只定义动作：移动、瞄准、主工具、作业头、倾倒/投掷、主动模块、互动、暂停、UI 确认/返回。设置中可重绑定；初始值与用户覆盖分开。
- 鼠标用地面投影指定操作点；手柄使用双摇杆与轻度目标吸附，吸附对救援/材料目标有类型优先级。最后使用的设备只影响提示，不应重置正在执行的动作。
- 支持震动强度、镜头震动、闪光强度、伤害数字、按住/切换、字幕和 UI 缩放。关键攻击不用红绿两色作为唯一提示。
- Steam Input 与 Godot 输入明确选一条权威事件路径，避免双输入。开发阶段先支持标准手柄输入，再专项验证 Steam 配置、热插拔、Overlay 返回和 Deck 睡眠唤醒。
- 音频按 Music、SFX、Vehicle、UI、Ambience 总线分组；连续挖掘音限并发，同材质随机小幅变调，避免几十个碎片同时发声。负载、速度、液压动作驱动循环层。
- VFX、音效、震动与镜头响应订阅已确认的 gameplay 事件；关闭表现不会改变伤害、奖励和任务结果。

## 8. 性能预算与 benchmark 验收

以下是**设计目标，不是本机实测数据或最低配置承诺**。M0 先记录本机 CPU/GPU/内存/驱动，在目标较低配置设备上建立基准。最低配置待实机测试后发布。

| 项目 | 初始预算/验收目标 |
|---|---|
| Windows | 1920×1080，中画质，持续 60 fps 目标；10 分钟代表性导出场景 p95 frame ≤16.7 ms、p99 ≤25 ms |
| Deck 专项 | 1280×800，低/中预设，40 fps 候选目标；必须由实机验证，未测不宣传 Verified |
| 可交互敌人 | 常规 30–50、压力场景 80；大首领按更高预算占比计算 |
| 物理碎片 | 峰值约 64 个活跃刚体，短时休眠/回收；其他碎片用粒子或批次 |
| 持续内存 | 初始目标进程驻留 ≤2 GB；重复 20 次合同加载卸载后无持续增长趋势 |
| 卡顿 | 正常战斗不发生 >100 ms 的单帧；记录原因，首次编译/加载也不能从体验报告删除 |
| 保存 | 保存表现不冻结主循环；单次主线程准备时间候选 ≤4 ms，大变更分阶段构建快照 |
| 读档/切图 | SSD 冷启动到主菜单候选 ≤10 s，合同切换 ≤5 s；实际时长按内容量复核 |

固定 4 个 benchmark 场景，每个记录版本、seed、预设、硬件、帧时间分位数和内存：

1. **作业场**：连续 10 分钟挖掘、吸收、抛掷、清除障碍，检查 dirty chunk 更新、碰撞/导航一致性。
2. **战斗场**：80 敌人 + 首领招式 + 极端工具组合，连续移动和升级，记录脚本、物理、GPU 分项。
3. **破坏峰值**：连锁拆除大型障碍、最高粒子并发、64 刚体，检查帧尖峰和音效限流。
4. **生命周期/存档场**：20 次进入退出、反复暂停、热插拔、每个结算阶段强制结束进程、损坏最新槽、旧版迁移。

验收以**导出的 release 包**为主，编辑器数字只用于定位。先查瓶颈再优化：关闭表现辨别 GPU/CPU、减少高频 Node 回调、分帧 AI 思考、空间哈希候选、预载工具/敌人、合并静态材质、批量渲染重复物、限制阴影与透明叠加。MultiMesh 可批量绘制重复内容，但应按可见空间块划分，避免一个巨型批次无法细粒度剔除。[MultiMesh 官方说明](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html)

没有 profiler 证据不引入 ECS、复杂多线程或自编物理。线程只处理纯数据；SceneTree 与物理对象的变更在允许的主线程/物理阶段执行。

## 9. 构建、验证与首发流程

仓库建议结构：

```text
game/                 project.godot 与可导入资源
  app/                启动、流程、服务
  features/           vehicle/combat/harvest/repair/mission/ui
  content/            definitions/scenes/biomes/localization
  addons/             审核并锁版本的插件
  tests/              数值、存档、生成器与集成场景
source_assets/        Blender、分层图、音频工程，LFS
tools/                数据验证、资产导入、构建与发布脚本
docs/                 设计、资产台账、决策、验收记录
```

日常验证只覆盖高价值风险：数值叠层、概率边界、升级依赖、ID 校验、交易幂等、旧存档迁移、地图连通性、流程出口。动作手感、美术层次和手柄体验需要人工试玩，不能用单位测试代替。

M1 就导出 Windows 包并运行干净安装测试，加入构建号与日志。Steam 接入在独立适配器上进行：初始化失败时离线继续；成就先存本地待同步；Overlay 必须用实际导出构建验证。App ID、凭据和 SteamPipe 上传配置不进入公开仓库。

首次公开 demo 前完成：完整闭环、输入重绑、手柄菜单、设置保存、异常退出恢复、最低一轮外部测试、许可证台账、实际游戏画面截图与预告素材。首发前另验 Steam 安装/更新/卸载、云存档、成就、离线、发布与 demo 档案互相兼容策略。

发布日不能只按开发完成日期倒推。Steam 官方要求商店和构建审核，并存在缴费后等待及 Coming Soon 展示要求；应提前完成账户与商店准备，具体政策发布前再次核对。[Steam Direct](https://partner.steamgames.com/steamdirect) · [Windows 导出](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html)

## 10. 必须优先关闭的技术风险

| 风险 | 最早验证 | 失败后的缩减 |
|---|---|---|
| 战斗/作业互相抢控制，像自动射击游戏换了模型 | M0，键鼠与手柄同测 | 保留一个有重量的主斗动作；作业头先自动触发 |
| 自由挖掘扩大到体素引擎项目 | M0，3 种覆盖层原型 | 限定可清理土堆、路障与固定修复节点 |
| 车体成长导致路径卡死 | M0，3 尺寸灰盒通道 | 只改变轮廓与手臂范围，冻结底盘碰撞占地 |
| 破坏后导航失效或持续烘焙卡顿 | M1，压力场 | 使用格子通行性与局部更新，减少可动态改变的区域 |
| 存档重复结算、回滚丢失永久进度 | M1，故障注入 | 先统一权威 envelope 与事务，不扩内容 |
| Steam 插件与导出版本不兼容 | M1，导出包运行 | 先离线适配器；锁定已验证插件组合，避免引擎分支 |
| 美术素材不统一、工具变体成本失控 | M2，完整切片 | 共享骨架/插槽、缩减底盘与皮肤、外包英雄资产 |
| 只有开发机跑得快 | M0 建基准，M2 目标设备 | 降低敌人/透明粒子/动态阴影，再评估渲染器 |

本文的验收数字和结构决策在 M0/M1 允许调整，但必须记录证据与影响；进入量产后先修改设计范围，再考虑拆换技术底座。
