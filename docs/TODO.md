# Reclaimer TODO · 从2D筛选到Steam垂直切片

更新时间：2026-09-25。当前阶段：2D设计冻结，正式3D生产暂停。

## 已完成

- Godot 4.7.2 Mobile/Jolt固定CLI。
- M0核心循环与M1修复路线/蓝图小合同。
- 20张2D候选设计稿：A01-A08机器、B01-B06怪物、C01-C06挑战/修复。
- Blender 5.2.1结构样件，含拆件、阶段、挂点、冷却和VFX合同节点。
- 9组行为测试、Godot导入检查、真GPU捕获。

## P0：2D选择，用户筛选前不推进正式3D

- 选择至少1台主机器和1台备用机器。
- 选择至少1个普通敌人、1个环境对手。
- 选择1个群系挑战和1个修复设施。
- 选择1套喜剧动作三拍：准备、接触、余韵。
- 记录保留、合并、删除和重做候选。
- 冻结正交三视图、俯视游戏镜头、成长剪影、颜色、材质、负形和接口。

## P1：Meshy/Tripo生成输入

- 使用 docs/assets/mesh-generation-queue.json 的稳定资产ID。
- 输入：选中的2D设计图、正交视图、俯视图、局部结构图。
- 参数：米制、X宽度/Y前进/Z向上；输出GLB；保留材质槽、挂点、可拆件和原始API回执。
- 负面约束：不要角色脸、不要随机武器、不要密集小零件、不要浮空部件、不要复制商业资产、不要把概念文字烘进贴图。
- 生成后在Blender 5.2.1重拓扑、修比例、补枢轴、碰撞、LOD和材质槽。
- 每个资产保存源文件、GLB、预览图、hash、版本、提示词和许可证。

## P2：首个正式3D垂直切片

- 一车：选中的主机器基础态、成长态、损坏态。
- 一模块：鲸口/主工程头，开合、压缩、释放动画。
- 一敌人：待机、攻击准备、执行、失败/撤退。
- 一设施：泵站或桥的损坏、施工、修复三态。
- 一合同：倒流河谷，约10分钟，包含资源、构筑、组合、修复、路线和奖励。
- Godot接入：预览、实装、战斗、修复、存档、无VFX对照。

## 动画清单

### 所有玩家机器

- idle_hydraulic
- drive_forward
- drive_reverse
- brake
- turn_in_place
- aim_left_right
- primary_prepare
- primary_contact
- primary_recover
- load_scrap
- throw_scrap
- dash_start
- dash_contact
- hit_recoil
- repair_work
- defeat
- stage_transform

### 鲸口回收铲

- jaw_idle
- jaw_open
- jaw_close_compress
- magnetic_pull
- payload_hold
- payload_release
- coil_spin
- repair_brick_stack

### 雨伞鼹鼠

- drill_spin
- shield_deploy
- shield_absorb
- burrow_enter
- burrow_loop
- burrow_exit
- surface_pop

### 铁轨蜗牛

- drum_spin
- rail_deploy
- rail_snap_connect
- grappler_extend
- grappler_pull
- rail_retract

### 普通敌人

- idle
- move
- telegraph
- attack
- stagger
- engineering_countered
- defeat
- retreat

### 设施和世界

- pump_cough
- pump_repair
- pump_flow
- bridge_closed_open
- turbine_anchor_spin
- air_pump_start
- camp_service_unlock

## 验收顺序

1. 2D设计稿在320px仍读得清。
2. Meshy/Tripo输出在Blender中可旋转、可拆、可挂点。
3. GLB在Godot Mobile中导入无错误。
4. 无VFX截图仍能看懂结构和危险。
5. 动画关键帧和权威事件一致。
6. 碰撞、通路、存档、低画质和720p/1080p检查通过。
7. 真GPU截图和机器可读manifest保存。

完整战役、Steam、Deck、手柄、蓝图效果树和量产资产继续保留为后续阶段。
