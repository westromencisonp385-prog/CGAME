# 敌人、精英与首领梯度 v1

状态：设计提案，服务 G0→G2 与 M1/M2 内容冻结。未代表 AI、模型或生产任务已实现。

## 1. 设计原则

1. **敌人是工程故障长出腿**：先让玩家读懂它在施工什么，再让玩家选择铲、吸、撞、投、钻或修复的解法。
2. **一个敌人一个主剪影、一个主行为、一个反制**。副行为只能加强主行为，不能变成另一套教程。
3. **危险不夺取输入**。准备、接触、余韵三拍必须可复现；红区、尘圈、灯号、声音至少两种通道共同预告。
4. **梯度考验操作而非血量**：普通教单一动词，精英叠加两种工程约束，首领把群系规则、修复结果和构筑选择绑在一起。
5. **笑点来自因果**：玩家确实完成了工程动作，敌人却以过分认真的方式把结果搞得更荒唐。
6. **首发先锁最小集**：G1 只做 B01 施工蟹；M1 再加入一个精英和一个首领。其余设计保留到切片通过后。

## 2. 战斗梯度与分期

| 层级 | 作用 | 数量与阶段 | 设计门槛 |
|---|---|---:|---|
| 普通 | 单一行为教学、制造工程目标 | 6 个设计；B01 在 G1，B02–B06 在 M1/M2 | 3 秒内读剪影，5 秒内读预告；至少两种工程解法 |
| 精英 | 迫使玩家组合动作并管理空间/资源 | 4 个设计；E01 在 M1，E02–E04 在 M2 | 不靠加血；有阶段窗口和明确失败原因 |
| Boss | 合同的工程问题具象化 | 3 个设计；Boss01 在 M1，Boss02–03 在 M2/后续 | 至少两阶段；修复结果改变战场或下一合同 |

共享敌人状态：`idle / move / telegraph / attack / stagger / engineering_countered / defeat / retreat`。共享接口：`attack_origin / telegraph_origin / countermeasure_socket / hit_recoil_origin`。所有接触事件由 Godot gameplay 决定，动画只消费事件。

## 3. 普通敌人

### B01 施工蟹（G1 首发样件，原 B01 重写）

- **主剪影**：横向液压钳、双块宽挡板、顶部反光施工牌；四脚只服务横移，不堆细节。
- **工程行为**：横移铺墙，把可走区域切成窄道；受击后换一面墙，始终给玩家留一条回撤线。
- **可读预告**：停下→两侧钳臂抬起→地面出现黄黑墙线→侧冲。墙线与攻击方向先于伤害出现。
- **玩家反制**：铲斗推墙块，或绕到墙后拆锚点；磁吸只拉走轻墙板，不能无条件吸走蟹体。
- **笑点**：先插“请勿移动”牌，再亲自把墙挪到玩家脚下；被反制后盖章“位置已优化”。
- **状态与动作**：`idle / side_move / wall_preview / wall_place / side_charge / stagger / anchor_exposed / defeat / retreat`。
- **模型拆件**：`EnemyRoot, Chassis, Leg_FL/FR/BL/BR, Barrier_L/R, Beacon, Anchor_L/R, TelegraphSocket`。
- **Weaver 适用接口**：`multi_view(7) → high_model(3) → uv(9) → lod(2) → rigging(5,tetrapod) → skinning(6)`；沿用 `enemy_shared`，禁止生成文字和脸。
- **最终 Blender-Godot 验收**：128px 仍读横向剪影；挡板、腿、锚点独立枢轴；碰撞不含装饰牌；720p 可看见墙线和退路；同一 `engineering_countered` 事件驱动拆锚与余韵。

### B02 沥青吞吞兽（M1）

- **主剪影**：低矮黑色路面团，裂缝嘴，背插半根路牌。
- **工程行为**：吐出减速沥青并吞掉小路，短暂固定玩家路线。
- **可读预告**：嘴部鼓起、地面黄线扩张、路牌抖动后吐出；沥青边界持续发亮。
- **玩家反制**：铲走沥青块，或用水系湿润分解；追击只会把玩家引入收缩区。
- **笑点**：吞下路牌后仍举着“前方施工”指挥玩家绕行。
- **状态与动作**：`idle / ooze_spread / swallow_route / telegraph / spit_tar / soaked / stagger / defeat`。
- **模型拆件**：`EnemyRoot, TarBody, CrackMouth, SignHalf, TarPatches, TelegraphSocket, WeakCore`。
- **Weaver 适用接口**：`multi_view(7), mid_model(11), uv(9), lod(2)`；软体只做厚块，不生成流体模拟。
- **最终 Blender-Godot 验收**：沥青区碰撞与视觉边界一致；水击事件能切换 `soaked`；关闭材质后仍能读出吞路动作。

### B03 反向铲鬼（M1）

- **主剪影**：半透明旧挖臂与倒装铲斗，车体方向和工具方向相反。
- **工程行为**：延迟复制玩家上一次主动作，在原位置执行。
- **可读预告**：地面残影、倒计时刻度、铲斗朝错误方向预摆；一次只复制一个动作。
- **玩家反制**：看残影换站位，或在准备段撞击打断。
- **笑点**：认真复刻玩家的无效空铲，随后递出“动作已完成”小票。
- **状态与动作**：`record / ghost_preview / copy_prepare / copy_contact / recover / stagger / defeat`。
- **模型拆件**：`EnemyRoot, ArmRoot, Bucket_Inverted, GhostTrailSocket, CopyMarker, HitProxy`。
- **Weaver 适用接口**：`mid_model(11), uv(9), lod(2)`；半透明只由 Godot shader 做，模型不烘透明。
- **最终 Blender-Godot 验收**：残影位置来自权威事件；复制不重复消耗玩家资源；预告不被透明材质遮挡。

### B04 管线寄生虫（M1）

- **主剪影**：细长管道身躯、水表头、两只过大的检修脚。
- **工程行为**：沿真实管线吸走修复进度，优先逃向节点。
- **可读预告**：与节点之间亮起单色连线，吸取时压力表逆转；假管线无声音。
- **玩家反制**：先切断连线再处理本体；磁吸把它拉离管线后可铲击。
- **笑点**：被打断就打印“节水成功”收据，收据比身体还长。
- **状态与动作**：`crawl / link_preview / siphon / severed / flee / stagger / defeat`。
- **模型拆件**：`EnemyRoot, PipeBody, MeterHead, ServiceLeg_L/R, CableSocket, ReceiptSlot`。
- **Weaver 适用接口**：`multi_view(7), mid_model(11), uv(9), lod(2)`；`cable_socket` 必须单独可挂。
- **最终 Blender-Godot 验收**：连线由 gameplay 目标生成；切断后修复进度停止损失；小尺寸仍分辨水表头。

### B05 垃圾龙卷（M2）

- **主剪影**：旋转压缩机核心，外围三件大件垃圾和一把办公椅。
- **工程行为**：吸入可移动物，周期性向外抛出；核心短时暴露。
- **可读预告**：尘圈半径、道具轨迹和中心灯号共同提示风向。
- **玩家反制**：逆风放置重物，或磁场改向；核心暴露时铲击。
- **笑点**：每轮都把同一把办公椅摆回最显眼位置。
- **状态与动作**：`spin / wind_preview / intake / eject / core_open / stagger / defeat`。
- **模型拆件**：`EnemyRoot, CompressorCore, Fan, Chair, Barrel, Sign, DebrisSockets`。
- **Weaver 适用接口**：`mid_model(11), uv(9), lod(2)`；外围道具用实例挂点，不生成无限碎片。
- **最终 Blender-Godot 验收**：风向和吸入半径与碰撞一致；并发效果遵守 20 实例预算；核心窗口可复现。

### B06 投诉云（M2）

- **主剪影**：纸张、印章、红章组成的低云团，底部有投递塔。
- **工程行为**：延迟投放工单，形成禁行区和遮挡压力，不直接改玩家输入。
- **可读预告**：纸张阴影、落点圆环、投递塔闪灯；落点至少提前一拍。
- **玩家反制**：清理投递塔，或用铲/磁把云推离工程区。
- **笑点**：被纸砸中播报“已记录您的不满”。
- **状态与动作**：`hover / order_preview / deliver / zone_active / tower_exposed / retreat / defeat`。
- **模型拆件**：`EnemyRoot, CloudVolume, PaperCluster, Stamp, RedSeal, DeliveryTower, TelegraphSocket`。
- **Weaver 适用接口**：`mid_model(11), uv(9), lod(2)`；文字不烘进模型，字幕由 UI 本地化。
- **最终 Blender-Godot 验收**：禁行区与落点一致；阴影不遮危险边界；降低特效后仍能看懂投递顺序。

## 4. 精英敌人

### E01 逆坡水母（M1 首发精英，倒流河谷）

- **主剪影**：倒挂浮标、水滴核心、三根管线触手；核心始终在玩家可见侧。
- **工程行为**：局部逆转水流，推走轻物并改变投掷轨迹；每次只控制一个水道区。
- **可读预告**：浮标倒挂、波纹反向、蓝白水线标出边界；转换前有低频泵鸣。
- **玩家反制**：关闭浮标或修复导流阀；用重物压闸，鲸口只可搬运浮标不能吞核心。
- **笑点**：持续把水送回已经干涸的水箱，完成后严肃报“回收率 100%”。
- **状态与动作**：`idle / current_preview / invert_start / invert_loop / anchor_exposed / valve_countered / stagger / retreat / defeat`。
- **模型拆件**：`EliteRoot, BuoyCore, WaterDrop, Tentacle_01/02/03, FloatValve, TelegraphRing`。
- **Weaver 适用接口**：`multi_view(7), mid_model(11), uv(9), lod(2)`；水流用 Godot shader，触手枢轴独立。
- **最终 Blender-Godot 验收**：逆流只影响授权区域和投掷结果；修阀事件改变路线；精英不靠血量拖时长；首发目标以 B01 + E01 + C04 完成 G1/G2。

### E02 加压河马（M2，售后盐海）

- **主剪影**：锅炉腹部、短腿、超大泄压阀和两只护耳。
- **工程行为**：蓄压后直线冲撞，撞坏路锥并留下高温区。
- **可读预告**：压力表三档升色、耳罩抬起、地面直线刻度。
- **玩家反制**：绕到泄压阀，水系降压；用路锥反弹路线，不和它正面对撞。
- **笑点**：每次泄压先响验收铃，再把自己喷出半个车身。
- **状态与动作**：`patrol / pressure_build / charge_preview / charge / vent / overheated / stagger / defeat`。
- **模型拆件**：`EliteRoot, BoilerBody, Valve, EarGuard_L/R, PressureGauge, Exhaust, WheelProxy`。
- **Weaver 适用接口**：`multi_view(7), high_model(3), uv(9), lod(2), rigging(5)`。
- **最终 Blender-Godot 验收**：压力三档不依赖材质发光；高温区可绕行；风向合同中路锥与冲撞结果稳定。

### E03 折叠桥卫（M2，呼吸山城）

- **主剪影**：三段错位工地桥，折叠时像走路的纸桥。
- **工程行为**：平面/折叠状态切换，改变通行区和受击面。
- **可读预告**：三段支撑节点按顺序亮起，折叠方向有箭头和铰链声。
- **玩家反制**：先拆支撑节点，或用钻掘顶开一段制造窗口。
- **笑点**：每次展开都露出写着“此处不可通行”的小门。
- **状态与动作**：`stand / fold_preview / fold / unfold / support_exposed / countered / stagger / retreat / defeat`。
- **模型拆件**：`EliteRoot, Deck_A/B/C, Hinge_A/B, SupportNode_A/B/C, DoorSign, TelegraphSocket`。
- **Weaver 适用接口**：`multi_view(7), mid_model(11), uv(9), lod(2)`；各段独立根节点，碰撞由状态切换。
- **最终 Blender-Godot 验收**：每状态共享外包络和退路；错误顺序只损失位置不秒杀；摄像机内能读支撑顺序。

### E04 旧维护官（M2/后续）

- **主剪影**：黄色涂料桶、起重臂、多层警示灯组成高大但窄的轮廓。
- **工程行为**：按固定顺序给物体刷漆并加固，错误封路；不能靠纯伤害击败。
- **可读预告**：扫描框锁定目标、施工线落地、加固倒计时。
- **玩家反制**：引导它施工到正确目标，或拆掉刚完成的加固件；打断窗口短而稳定。
- **笑点**：被打到只盖章“外观合格”。
- **状态与动作**：`inspect / target_lock / paint_prepare / paint / reinforce / redirected / stagger / retreat / defeat`。
- **模型拆件**：`EliteRoot, PaintTank, CraneArm, Roller, BeaconStack, Stamp, TargetScanner`。
- **Weaver 适用接口**：`multi_view(7), high_model(3), uv(9), lod(2), rigging(5)`；扫描线和漆雾由 Godot 表现层提供。
- **最终 Blender-Godot 验收**：目标选择与工单目标一致；加固状态可拆且可恢复；没有随机锁死主路线。

## 5. 首领

### Boss01 逆流泵王「附件 B」（M1 首发，倒流河谷）

- **绑定群系与修复结果**：河水沿旧河床逆坡上流；击败并修复泵站后，水流顺坡、桥开启、湿地捷径出现。Boss 不是大血条，而是“泵组错误合同”本身。
- **主剪影**：超大泵体、反向叶轮、两根河道管臂、顶部黄色验收铃；玩家能看见四个阀区。
- **工程行为**：阶段一把水道切成三段逆流区；阶段二吸入河岸障碍并把它们错误送回泵站；阶段三暴露泵芯，要求玩家完成一次鲸口分类或铲斗导流。
- **可读预告**：阀门按顺序亮起、河纹反转、管臂指向和水压声递进；每次攻击前保留回撤走廊。
- **玩家反制**：按工单顺序关阀→用工程动作清障→在泵芯开放时投递正确载荷；三条机器谱系均有保底解法。
- **笑点**：泵王每次失败都响两声咳嗽，吐出一张被水泡过的“附件 B”；修复后仍坚持铃响验收。
- **状态与动作**：`dormant / contract_scan / stage_01_invert / valve_attack / stage_02_suction / debris_return / core_open / stage_03_repair_window / restored / defeat`。
- **模型拆件**：`BossRoot, PumpBody, ReverseImpeller, PipeArm_L/R, Valve_A/B/C, PressureGauge, Bell, Core, RiverSockets`。
- **Weaver 适用接口**：`multi_view(7), high_model(3), uv(9), lod(2), rigging(5), skinning(6)`；分件生成优先，河水和水雾不烘入模型；接口复用 `repair_pump` 与 `enemy_shared`。
- **最终 Blender-Godot 验收**：镜头内能读阀顺序、危险区和泵芯；阶段转换由权威合同事件触发；Boss 失败原因可归因到阀序、站位或载荷资格；胜利提交一次修复事务并恢复桥/水流/捷径，读档后仍一致。

### Boss02 折叠山城「通风总包」（M2，呼吸山城）

- **绑定群系与修复结果**：叠层道路和通风井堵塞；完成后窗户点亮、吊桥展开并开放垂直捷径。
- **主剪影**：三层折叠道路、巨大风扇肺叶、可见通风井，核心像一栋认真走路的楼。
- **工程行为**：折叠道路改变高低层连接；释放气压把玩家和碎片推向错误楼层；玩家必须重排支撑并启动风机。
- **可读预告**：楼层灯、气流箭头、支撑节点顺序；每次折叠前保留一条上下层退路。
- **玩家反制**：铲/钻拆支撑，轨道或磁吸搬运风阀，最后在风机稳定窗修复。
- **笑点**：每次换层都播报“终于可以呼吸”，下一层立刻亮起投诉灯。
- **状态与动作**：`blocked / floor_preview / fold / pressure_burst / support_exposed / vent_start / repair_window / restored / defeat`。
- **模型拆件**：`BossRoot, Floor_01/02/03, FanLung, VentShaft, Support_A/B/C, BridgeSocket, ComplaintLamp`。
- **Weaver 适用接口**：`multi_view(7), high_model(3), uv(9), lod(2), rigging(5)`；大楼分层拆件，碰撞状态由 Godot 管理。
- **最终 Blender-Godot 验收**：上下层路线与镜头一致；风压不造成不可读位移；修复后至少一条新捷径和一项营地/地图状态可见且可恢复。

### Boss03 黄色规范「行星维护总监」（M2 终局候选）

- **绑定群系与修复结果**：维护局把所有问题都刷成黄色并加盖章；击败后把三群系的修复设施接成统一服务链，地图显示世界重新连通。
- **主剪影**：超大起重臂、三枚旋转合同印章、可拆卸涂料仓；没有脸，用姿态和灯号表达“官僚自信”。
- **工程行为**：轮换调用三群系已学规则（逆流、风向、折叠路线），并把“错误修复”加固成临时障碍；玩家逐段拆除错误工程。
- **可读预告**：下一条合同条款投影在地面，颜色对应群系；印章落下前有明确矩形危险区。
- **玩家反制**：识别当前条款，使用对应工程动作；完成三次正确反修复后暴露总监核心，不能只打本体。
- **笑点**：每个阶段结束盖章“符合规范”，最后发现印章把自己钉在地上。
- **状态与动作**：`audit / clause_preview / river_clause / salt_clause / city_clause / false_repair / core_exposed / final_repair / restored / defeat`。
- **模型拆件**：`BossRoot, CraneArm, Stamp_A/B/C, PaintTank, ContractProjector, Core, AnchorFeet, BiomeSockets`。
- **Weaver 适用接口**：`multi_view(7), high_model(3), uv(9), lod(2), rigging(5), skinning(6)`；群系装饰用独立实例，禁止把三套材质烘成不可拆单体。
- **最终 Blender-Godot 验收**：每阶段沿用已学预告语法；规则切换不改输入映射；终局修复一次性提交并在世界地图、营地服务和三群系实景留下可见结果。

## 6. 首发锁定与排产边界

- **G1/G2 最小样件**：玩家 A01 磁暴鲸口 + B01 施工蟹 + C04 修复泵 + 倒流河谷；验证横移筑墙、鲸口分类、泵站修复三拍。
- **M1 首发敌人集**：B01、B02、B03、B04，加 E01 逆坡水母和 Boss01 逆流泵王。B05、B06、E02–E04、Boss02–03 先不进生产队列。
- 每个新敌人进入生产前必须有行为原型、预告时序、反制测试和一张 Blender/Godot 无 VFX 截图；Weaver 队列只在 G0 风格通过后填写实际任务。
- 当前文档不调用生产 API，不把概念图、`weaver-production-queue.json` 中的 `pending` 或旧 B01 模型当作已完成资产。
