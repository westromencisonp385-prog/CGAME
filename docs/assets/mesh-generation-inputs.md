# Meshy / Tripo 输入准备

当前仓库不绑定具体供应商SDK。使用 Meshy、Tripo 或同类 API 时，按 mesh-generation-queue.json 的资产ID提交，保留原始请求和响应，不把供应商输出直接当最终资产。

## 每个模型请求必须包含

- asset_id
- selected_design_image：用户选中的 A/B/C PNG
- design_phase：2d_design_freeze
- prompt：资产专属提示词
- negative_prompt：随机添加武器、脸、文字、漂浮零件、密集小零件、商业参考复制、错误轴向
- units：meters
- axis：X width, Y forward, Z up
- camera_checks：side, top, three_quarter
- required_sockets：模块接口、VFX起点/终点、瞄准点、碰撞包络
- required_states：base, upgrade, damaged, repaired
- output_format：GLB
- output_files：source response, GLB, textures, preview, manifest
- provenance：provider, model version, task id, prompt hash, source image hash, output hash

## 玩家机器提交格式

asset_id: player.machine.primary
design_candidate: A01-whale-jaw-reclaimer.png
root: VehicleRoot
parts: Chassis, Track_L, Track_R, Cabin, Boom, Tool, ModuleSockets
sockets: socket_tool, socket_support_l, socket_support_r, socket_fx_exhaust, socket_vfx_origin, socket_aim_origin
states: base, stage_02, damaged, repaired
lod: LOD0, LOD1, LOD2
animations: idle_hydraulic, drive_forward, drive_reverse, brake, turn_in_place, aim_left_right, primary_prepare, primary_contact, primary_recover, load_scrap, throw_scrap, dash_start, dash_contact, hit_recoil, repair_work, defeat, stage_transform

## 模块提交格式

每个模块必须是可拆 GLB 子树，不要把整台车和模块焊成不可替换的一件模型。

- root：ModuleRoot
- visual layers：Skin、S0_Elements、Skin_Elements
- stage layers：T0、T1、T2、T3、T4、T5
- active/passive：InstantiationPoint_Active、InstantiationPoint_Passive_A、InstantiationPoint_Passive_B
- feedback：Generic_CooldownElement、VFX_InstallFlash、VFX_DamageMaterial
- gameplay-facing markers：Jaw_Socket、Jaw_ContactPoint、Jaw_VFX_FieldOrigin
- collision：separate static proxy, never infer collision from decorative teeth or hoses

## 动画命名

动画名称必须稳定，API输出导入后在 Blender 中检查，Godot只订阅事件，不依赖供应商自动命名。

- 玩家共通：idle_hydraulic、drive_forward、drive_reverse、brake、turn_in_place、aim_left_right、primary_prepare、primary_contact、primary_recover、load_scrap、throw_scrap、dash_start、dash_contact、hit_recoil、repair_work、defeat、stage_transform。
- 鲸口：jaw_idle、jaw_open、jaw_close_compress、magnetic_pull、payload_hold、payload_release、coil_spin、repair_brick_stack。
- 雨伞鼹鼠：drill_spin、shield_deploy、shield_absorb、burrow_enter、burrow_loop、burrow_exit、surface_pop。
- 铁轨蜗牛：drum_spin、rail_deploy、rail_snap_connect、grappler_extend、grappler_pull、rail_retract。
- 敌人：idle、move、telegraph、attack、stagger、engineering_countered、defeat、retreat。
- 设施：pump_cough、pump_repair、pump_flow、bridge_closed_open、turbine_anchor_spin、air_pump_start、camp_service_unlock。

## Blender 二次处理

1. 检查轴向、米制、原点、父子关系和模块接口。
2. 删除供应商添加的随机零件和不可解释材质。
3. 补 LOD、碰撞、挂点、状态可见组和动画剪辑。
4. 将材质合并到工程黄、石油蓝、骨白、珊瑚、磁紫、修复青绿六类。
5. 导出 GLB，保存 Blender 源文件和预览图。
6. 用 Blender 再导入检查对象层级；用 Godot 4.7.2 import/check 导入。
7. 运行行为测试和真GPU截图；无VFX截图必须仍能读懂结构。

## 首批API生成顺序

1. 用户选中的主玩家机器 A 候选。
2. 用户选中的鲸口/主工具模块。
3. 用户选中的普通敌人 B 候选。
4. C04 维修泵。
5. C01 河流桥/路线组件。
6. 其余机器、怪物和群系在首个垂直切片通过后再提交。

