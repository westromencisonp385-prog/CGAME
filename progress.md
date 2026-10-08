# Progress

2026-10-08：仓库整理。归档已被取代的资产（移到 artifacts/archive/2026-10-08/，未删除）：P2 整块正式模型 23 件约 1.9GB、v1 AI 位图 UI 49 张；P5Theme 去掉 v1 兜底目录；28 个新模块补上模型槽位（按挂件组共用 8 个部件化模块模型）；新增一键回归 tools/run_regression.ps1；COMPACT.md 按现状重写。

2026-10-08：C17 完整交互 + 手感：GameFeel（顿帧/震屏/伤害数字/闪白/暗角/慢动作）、八态状态机、近战前摇 + 可躲弹道 + 地面预警、40 模块 × 38 种施放、模块升级 + 载具 2 选 1 + 选择排队、11 Boss × 3 招、24 任务、磁吸掉落、AES-256 + HMAC 加密档案、战斗 HUD；相机改为紧跟。回归 19/19。

2026-10-08：C10-C16 资产与表现：Weaver 部件分开生成（2D 拆分 + 联合中模 + 贴图 + Blender 组装）31 件、v3 风格统一（TiMi 原画重绘 + toon/描边）、程序化动画；UI 重做为程序绘制 P5 v2；敌人花名册小怪 5 / 精英 2 / 新 Boss 吞河蟾。

2026-10-07：C1-C9 逆向结构复刻：概率/Luck、四套选择流、v2 模块、载具成长、单局系统、Boss 阶段框架、音频事件表 + WAV 烘焙、群系锁钥、召唤、Boss/神器/船长花名册。详见 docs/wanderburg-to-godot-mapping.md。

2026-10-07：Weaver P1 试产与放量完成：A01/B01/C04 走通"概念图→图生360→图生中模 FBX→下载→Blender 无头验收"全链（约15分钟/资产）。稳定参数固化进 weaver-asset-production 技能：中模必须显式 input_view + fbx 输出（model_id_360 与 glb 均触发 990017）；130400 主体占比过低需先裁剪单视图面板。产物与 manifest 在 artifacts/ai_candidates/{A01,B01,C04}/weaver/，面数 28k-38k tri，大形目检通过；中模无材质，PBR 走 node_type=8 待跑。工具：tools_re/weaver_p1_batch.py、weaver_mid_retry.py、blender_verify.py（Blender 5.2.2 F:\SteamLibrary\steamapps\common\Blender）。

2026-09-27：完成一次文档与治理收口：正确 AssetRipper Wanderburg 重导出、Steam 直读、G1 截图对标和现役路线重写。

2026-09-27：当前功能事实：Godot 4.7.2 Mobile/Jolt，M0/M1 循环和 9 组行为测试通过；A01/B01/C04/倒流河谷作者化候选已接入真实镜头，G1 视觉质量仍失败。

2026-09-27：当前下一步：关闭 G1 贴图/材质/动作/场景/UIUX/LOD/碰撞缺口；G1 通过后进入 G2 连续喜剧动作，再建立 100+ build 目录。

2026-10-07：完成 Wanderburg IL2CPP 深度逆向（Il2CppDumper 6.7.46 + ilspycmd 9.0）：588 个 C# 反编译、全部方法签名带 RVA、20,441 条字符串、data.unity3d 全量对象统计、存档加密方式确证。报告：docs/wanderburg-re-deep-dive.md；dump 与源码在 D:\工作\InverseGame\WaWa\wanderburg_re\。

2026-10-07：新增 ai-asset-pipeline 技能（.agents/skills/ai-asset-pipeline/）：封装 TIMIAI 生图（Nano Banana/GPT-Image-2）与 Tripo/Meshy 3D 生成客户端、Reclaimer 通用像素帧管线；API key 验证通过（用户当日重新启用）。资产生成与规划见 docs/assets/ai-asset-generation-plan-v1.md：P0 概念图 5 项（服务 G1 条款 1-4）→ P1 草模试产（Meshy base64 直传）→ P2 像素帧 UI 素材；与 Weaver 链分工：本技能出草模候选与概念输入，Weaver 出结构化后处理。
