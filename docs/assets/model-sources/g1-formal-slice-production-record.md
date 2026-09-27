# G1 formal slice production record

日期：2026-09-27。状态：`candidate`，未通过 G1 集成门。

## 目的

为首个高质量体验切片建立可以交接的作者化 3D 资产骨架。A01、B01、C04
均由 `game/assets/models/source/generate_g1_formal_slice.py` 从零生成；旧白模
和旧 GLB 只用于比例/接口研究，不进入导出选择。

## 概念还原

| ID | 还原要点 | 机制签名 | 关键结构 |
|---|---|---|---|
| A01 | 深石油蓝车体、赭黄驾驶室、骨白牙、紫磁环、履带、开放鲸口负形 | 聚拢 → 压缩 → 投掷 | `Jaw_Socket`、`Jaw_ContactPoint`、`Jaw_VFX_FieldOrigin`、上下颚独立枢轴、液压对 |
| B01 | 橙白路障板、红倒车灯、六条横向液压腿、后向警示面 | 横移冲撞 → 推墙或拆锚 | `TelegraphAim`、左右 `Weakpoint_*Anchor`、`Contact_SideCharge`、`Drop_Scrap` |
| C04 | 黄蓝泵体、压力表、红阀轮、蓝管口、维修密封环 | 拆解 → 换密封 → 加压 → 恢复 | `Pump_Interact`、`Pump_WaterOut`、`Pump_State_Broken/Repair/Restored` |

大形承担行为信息；细节使用可解释的护板、枢轴、液压、阀件和边缘倒角，
没有随机 greeble、连续噪声锈斑、贴图文字或无意义发光。文字仍由 Godot
本地化绘制，概念板文字未烘焙进模型。

## 材质与贴图清单

当前候选采用作者化色块材质，确保关闭 VFX/贴图时仍能读懂剪影。材质槽来自
`MAT_oil_blue`、`MAT_oil_blue_light`、`MAT_ochre`、`MAT_ochre_light`、
`MAT_bone`、`MAT_bone_shadow`、`MAT_tomato`、`MAT_tomato_dark`、`MAT_lilac`、
`MAT_lilac_dark`、`MAT_rubber`、`MAT_steel`、`MAT_steel_light`、`MAT_concrete`、
`MAT_water`、`MAT_glass`。这些是有意控制的半哑光 PBR 色块，不是白模默认材质。

`game/assets/models/formal_slice/painted_surface_atlas.png` 现在通过 Generated 坐标
和受控的 Multiply 混合绑定到四类表面材质，作为候选的手绘色块/边缘标记/警示条纹
层。它不是最终 UV 展开或损坏/维修遮罩；下一轮仍要补独立 UV、状态遮罩和低画质
材质变体，不用连续程序噪声或随机划痕替代作者决定。

## 生产与验收证据

- 生成器：`game/assets/models/source/generate_g1_formal_slice.py`
- 源场景：`docs/assets/model-sources/g1_formal_slice.blend`
- 输出与 hash：`game/assets/models/formal_slice/manifest.json`
- Blender 三视角审阅图：`game/assets/models/formal_slice/g1_formal_slice_preview.png`
- 目标引擎：Godot 4.7.2 stable，Mobile，Jolt

当前已验证：Blender **5.2.2 LTS** headless 生成成功，三件 GLB 有稳定命名拆件、
材质槽、候选手绘表面层、状态/挂点/LOD/碰撞合同，A01 带独立上下颚的准备→接触→余韵动作，
预览图无白模默认灰材质。Godot **4.7.2 stable** Mobile 导入通过。结构复核：
A01 128对象/97网格/13,913三角；B01 109对象/83网格/11,956三角；C04
51对象/25网格/4,406三角。QA结果保存在 `artifacts/qa/formal_slice/blender-validation.json`。

待验证：实际镜头避让、碰撞通路、LOD 成本、与权威事件同步的三拍动作，以及
损坏/维修状态遮罩和正式 UI/场景密度。A01 动作仅为资产端候选，不控制玩法结算。

## 不可宣称

本记录不把候选资产宣称为 `integrated`、`final` 或已关闭 G1。Godot gameplay
权威事件、碰撞、载荷、修复和存档仍由运行时负责，模型动画不能改变结果。
