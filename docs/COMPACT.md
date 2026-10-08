# Compact · 项目接续入口

更新时间：2026-10-08。本文是磁盘接续记录，不代表调用了宿主原生 /compact 命令。

## 当前一句话状态

Reclaimer 是 Godot 4.7.2 的单人幻想工程车 Roguelite。2026-10-07~08 按 Wanderburg 逆向结构完成 C1-C17：四套选择流 + Luck、40 模块 × 38 种施放行为、模块升级与载具 2 选 1、八态状态机、11 个 Boss 各 3 招、小怪 5 / 精英 2、24 任务、群系锁钥、加密长期档案，以及顿帧/震屏/伤害数字/读招预警等手感层；3D 资产 31 件全部走「部件分开生成 + 程序化动画」并统一 v3 风格；UI 为程序绘制的 P5 v2。可完整打一局，节奏参数尚未经人工试玩调校。

## 唯一现役入口

- 逆向 → Godot 映射与批次 TODO：[docs/wanderburg-to-godot-mapping.md](wanderburg-to-godot-mapping.md)（C1-C17 状态与剩余项以此为准）
- 逆向报告：[docs/wanderburg-re-deep-dive.md](wanderburg-re-deep-dive.md)
- 3D 资产生产：`.agents/skills/weaver-asset-production/SKILL.md`（部件分开生成，平面切割已废弃）
- 产品规则：[docs/spec.md](spec.md)
- 全局质量门：[docs/project-guidance.md](project-guidance.md)
- 后续路线：[docs/roadmap.md](roadmap.md)
- F/P 执行索引：[docs/requirements.md](requirements.md)
- 本地决策路线：[docs/wayfinder/map.md](wayfinder/map.md)
- 百种构筑目录：[docs/builds/build-catalog-v1.md](builds/build-catalog-v1.md)
- 质量基准：[docs/assets/wanderburg-quality-benchmark-v2.md](assets/wanderburg-quality-benchmark-v2.md)

## 现役资产与目录（2026-10-08 整理后）

- 3D：`game/assets/models/rigged/`（31 件部件化 GLB + `rig_manifest.json`，运行时 `ProceduralRig.attach` 优先加载）。`formal_slice/` 只保留已入库的 A01/B01/C04 作者化候选（被 preload 作兜底）。
- 已归档（移出 `game/`，在已忽略的 `artifacts/archive/2026-10-08/`）：P2 整块正式模型 23 件（约 1.9GB，已被 rigged 版完全取代）、v1 AI 位图 UI 49 张（毛边，已被程序绘制 v2 取代）。
- UI：`game/scripts/ui/p5_*.gd` 程序绘制，图标在 `game/assets/ui/v2/`。字体 `game/assets/fonts/`（Anton + 得意黑，OFL）。
- 资产工具脚本：`tools/asset_pipeline/`（33 个 Weaver/TiMi/Blender 脚本，2026-10-09 收进仓库，说明见该目录 README；仓库外旧目录 `tools_re\` 只是历史副本）。
- 逆向原始产物在仓库外 `D:\工作\InverseGame\WaWa\wanderburg_re\`。

## 验证方式

- 一键回归：`powershell -NoProfile -ExecutionPolicy Bypass -File tools\run_regression.ps1` → `artifacts/qa/regression_latest.txt`（19 项 headless 测试 + 真机入场检查 c13）。
- 截图验收脚本：`game/tests/c1x_*_capture.gd`（需真 GPU，输出到 `artifacts/qa/`）。
- 本机无 pwsh，Godot 用 `C:\Users\jasonlyan\AppData\Local\Microsoft\WinGet\Links\godot.exe` 直接调用。

## 已确认事实

- 资产 = 磁盘上可复用的资源文件；运行时代码拼出的实体不算资产（2026-10-07 口径纠正）。
- 可动资产一律「部件分开生成」再按枢轴组装（2026-10-08 用户指令）。
- 主验收流程：装配 → 预览 → 确认 → 实战触发组合 → 升级/变形 → 存档恢复。
- 正式内容质量门：风格化、高精度、去 AI 感、多种多样；首发规划至少 100 个可区分 build。

## 真实参考状态

- Wanderburg 原始发行包：`F:\SteamLibrary\steamapps\common\Wanderburg Game`。
- 正确 AssetRipper fresh export：`tmp/assetripper-wanderburg-20260927/ExportedProject`。
- fresh 统计：749 Prefab、5 场景、845 纹理、710 脚本；详情见质量基准。
- Steam 页面已直读：[Wanderburg](https://store.steampowered.com/app/3624140/_Wanderburg/)。
- 2026-10-07 深度逆向：Il2CppDumper + ilspycmd 完成 588 个 C# 反编译、20,441 条字符串、data.unity3d 全量资源统计；报告见 [docs/wanderburg-re-deep-dive.md](wanderburg-re-deep-dive.md)，原始 dump 在 `D:\工作\InverseGame\WaWa\wanderburg_re\`。
- AI 资产生成：技能 `.agents/skills/ai-asset-pipeline/`（TIMIAI 生图 + Tripo/Meshy 3D + 像素帧），规划见 [docs/assets/ai-asset-generation-plan-v1.md](assets/ai-asset-generation-plan-v1.md)；API key 在 `D:\工作\生图API\apikey.txt`。
- 外部资产只作研究证据，不复制进 `game/`；IL2CPP 方法体不作为原算法。

## 当前阻塞 / 剩余

- 手感参数（顿帧、慢动作、Boss 出招间隔）与 40 技能数值未经人工试玩调校。
- 原作 Luck 权重 / 掉落 / 重抽公式仍是占位（需装 Java 跑 Ghidra，RVA 已备）。
- 音效为程序合成；真实采样未替换。
- 长期档案银币无局外花费出口（缺局外菜单）。
- 模型每件 20-33MB，未减面 / 无 LOD；B03/B04 腿部拆分精度不足；营地服务板未按 v3 重做。
- 版本控制：C1-C17 全部改动（约 490 个新文件 + 约 30 个修改，新文件约 1.55GB，主要是 rigged 模型和抽取贴图）尚未提交，当前分支 `codex/governance-2026-09-24`，仓库未启用 Git LFS。
- 发布：真实手柄、性能、release、Steam、Deck 尚未验收。

## 状态边界

`whitebox → proposal → candidate → integrated → final`。当前白模、旧 GLB、Weaver 候选和新作者化候选都不能称 `final`。旧计划、旧导出和 wayfinder 未决票据保留为历史/决策材料，不自动删除或关闭。
