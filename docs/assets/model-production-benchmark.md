# Blender 3D 资产生产精度对标

日期：2026-09-23。本文回答“当前资产为什么跟不上，以及这次怎样按解包生产精度重做”。它对标的是**制作结构和可维护性**，不是复制 Wanderburg 的美术风格或资产。

## 参考包观察

AssetRipper 导出的代表结构提供了可回查的生产基准：

| 参考对象 | 观察到的结构 | 本作的原创转译 |
|---|---|---|
| `Module2_FrontCannon` | 175 个 GameObject、95 个 MonoBehaviour 引用；`Skin`、`S0_Elements`、`Skin_Elements`、`T0–T5`、主动/被动实例化点、冷却节点重复组织 | GLB 具备 `Skin`、`S0_Elements`、`Skin_Elements`、`T0–T5`、主动/被动挂点、冷却与安装/伤害/VFX合同节点 |
| `PV_Tank_Rank__0_` / `__3_` | 98 → 119 个 GameObject；阶段变化增加结构层，而不只是换材质 | 基础车与二阶段颚模块分离；升级层保留在同一可复用资产合同中，实际 M0 只显示 `T2` |
| `PV_Spider_0` | 207 个 GameObject；`Drive`、`SteeringGimbal`、`Feedback`、腿控制与多组状态 VFX | 当前样件用液压桶/杆、轨道/履带段、控制面板、机械挂点和状态合同补齐机械层；完整可动骨骼仍是后续资产任务 |

参考导出中的 GameObject 数量不代表质量目标，也不能把空方法体当原算法。它说明正式资产应有可管理的拆件、状态、挂点和表现层，而不是一块带颜色的盒子。

## 当前原创样件

`game/assets/models/reclaimer_whale_jaw.glb` 由 Blender **5.2.1 LTS** 使用 `--background --python` 生成，源文件在 `docs/assets/model-sources/reclaimer_whale_jaw.blend`，可重复脚本在 `game/assets/models/source/generate_reclaimer_whale_jaw.py`。

当前样件报告：

- 122 个对象、77 个网格对象、7 个材质。
- 基础工程车：底盘、履带护板、8 段履带、轮毂、驾驶室窗/顶、保险杠、液压桶/杆/软管、控制面板、主臂和接口。
- 鲸口模块：安装环、磁能线圈、上下颚、左右枢轴、牙齿、螺栓、接触点和 VFX 挂点。
- 结构合同：`Skin`、`S0_Elements`、`Skin_Elements`、`T0–T5`、`InstantiationPoint_Active`、两个被动挂点、`Generic_CooldownElement`、压缩/释放反馈节点。
- Godot 只把它作为二阶段视觉子树接入；碰撞、伤害、装载和存档仍由 gameplay 负责。

这让样件进入“可以交给另一位美术继续制作”的状态：他能找到接口、阶段、发射点和状态反馈，不需要猜一块网格要挂在哪里。它仍不是最终量产资产，缺少正式动画、LOD、碰撞专用网格、完整损坏态和多平台性能验收。

## 资产验收门槛

一件正式模块交付前必须同时有：

1. Blender 可编辑源文件和稳定 GLB 导出。
2. 基础态、成长态、损坏/维修态的层级或状态表。
3. 可回查的主动/被动挂点、冷却、命中和安装反馈挂点。
4. 真实镜头中的无特效截图、特效截图和低画质截图。
5. 碰撞包络、通路测试和装配预览检查。
6. 资产 ID、Blender/Godot 版本、文件 hash、授权和生成脚本记录。

下一台机器和第一个正式怪物必须沿这份合同制作。概念图只能决定方向，不能直接进入主场景。
