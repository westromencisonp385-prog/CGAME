# Wanderburg 操控研究（C27，2026-10-10）

证据：原作 `data.unity3d` 里的 InputActionAsset、270 个 AttackModuleV2、43 个 Module2、9 个 AutoTurret 的序列化值（提取脚本 `tools/asset_pipeline/re_extract_controls.py`、`re_extract_module_cd.py`，原始结果 `wanderburg-controls.json`、`wanderburg-modules-cooldowns.json`），以及 il2cpp 反编译类定义。

## 原作怎么操控

原作战斗用的 Vehicle 动作表：

| 动作 | 键盘 | 手柄 |
|---|---|---|
| Move | WASD | 左摇杆 / 十字键 |
| Module 1~4（主动技能） | Q / E / R / 空格 | Y / B / A / X |
| Boost（加速） | Shift | LT |
| Aim（可选） | 方向键 | 右摇杆 |
| Controls / Menu | Tab / Esc | Select / Start |

战斗里没有攻击键，鼠标只用于菜单和大地图。

攻击全自动：
- 每个模块有两套冷却：`autoAbilityBaseCooldown` 是自动攻击，常见 2~10 秒；`activeAbilityBaseCooldown` 是主动技能，常见 15~60 秒。主动技能“不常用”，正是因为冷却长。
- AttackModuleV2 的瞄准模式有 Locked、Rotate、LimitedRotate、FreeRandomInArea。Rotate 模式下炮塔按 `turretRotationSpeed`（15~50°/s）转向目标，偏差在 `targetAlignmentTolerance`（2~10°）以内才开火。
- AutoTurret 每 0.2 秒刷新一次目标，打范围内最近的敌人。
- 有一类神器只在自动攻击上做文章，比如“站着不动时自动攻击冷却恢复快 20%”。原作的玩法就是“开车走位 + 自动输出 + 偶尔放大招”。

## 我们的对应

| 原作 | 我们 |
|---|---|
| WASD 移动 | WASD（方向键也行） |
| Q / E / R / 空格 主动技能 | 同样 4 个键，数字 1~4 也行；技能槽角标显示 Q E R 空格 |
| Shift 加速 | Shift 冲刺（无敌） |
| 自动攻击 | 挖斗自动锁定：13m 内最近的敌人，当前目标有粘性；没有敌人时锁 5m 内的废料堆。以 540°/s 转向，偏差 26° 以内、进入咬合距离就咬，每 0.42 秒一口，三段连击照旧 |
| 自动投掷（原作无货物，补的） | 鲸口装满或打包了敌人时，自动扔向 3.5~10m 的敌人 |
| 修理 | 带够废料开到水泵旁就自动修 |
| 召唤（我们独有） | Z / X / C（数字 5~7 也行） |
| 菜单 | 不用鼠标也能操作：选卡时按 A/D 切换、空格或回车确认、1~3 直选、R 重掷；Esc 打开菜单后 W/S 移动、空格确认；鼠标 2.5 秒不动就隐藏光标 |

自动咬合每口加 3.5 点热量，冷却速度是每秒 12 点，所以一直咬也不会过热。

验收：`game/tests/c27_controls_flow.gd`，共 31 项检查，已并入一键回归。
