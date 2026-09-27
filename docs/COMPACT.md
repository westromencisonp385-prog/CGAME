# Compact · 项目接续入口

更新时间：2026-09-27。本文是磁盘接续记录，不代表调用了宿主原生 /compact 命令。

## 当前一句话状态

Reclaimer 是 Godot 4.7.2 的单人幻想工程车 Roguelite。M0/M1 功能循环可运行；首个 A01/B01/C04/倒流河谷切片已形成作者化候选，但 G1 视觉质量对标失败，正式 UIUX、贴图、场景和动作仍未完成。

## 唯一现役入口

- 产品规则：[docs/spec.md](spec.md)
- 全局质量门：[docs/project-guidance.md](project-guidance.md)
- 后续路线：[docs/roadmap.md](roadmap.md)
- F/P 执行索引：[docs/requirements.md](requirements.md)
- 本地决策路线：[docs/wayfinder/map.md](wayfinder/map.md)
- 美术生产：[docs/assets/concept-to-production-v1.md](assets/concept-to-production-v1.md)
- UIUX：[docs/assets/g0-uiux-direction-v1.md](assets/g0-uiux-direction-v1.md)
- 质量基准：[docs/assets/wanderburg-quality-benchmark-v2.md](assets/wanderburg-quality-benchmark-v2.md)
- 缺口报告：[docs/assets/g1-quality-gap-report.md](assets/g1-quality-gap-report.md)

## 已确认事实

- 主验收流程：装配 → 预览 → 确认 → 实战触发组合 → 升级/变形 → 存档恢复。
- 工业童话方向已确认；用户提供的 A01/B01/C04 概念图是视觉真源。
- 正式内容质量门：风格化、高精度、去 AI 感、多种多样；首发规划至少 100 个可区分 build。
- A01/B01/C04/倒流河谷是玩法样板目标，不代表正式资产已通过。
- 当前 `candidate` 切片包含作者化 GLB、Blender 源、候选表面图集、VFX 图集、渲染改进、阶段 HUD 和 `magnetic_whale` 机制签名。
- 9 组 Godot 行为测试和真 GPU capture 通过，只证明流程/导入/事件可运行。

## 真实参考状态

- Wanderburg 原始发行包：`F:\SteamLibrary\steamapps\common\Wanderburg Game`。
- 正确 AssetRipper fresh export：`tmp/assetripper-wanderburg-20260927/ExportedProject`。
- fresh 统计：749 Prefab、5 场景、845 纹理、710 脚本；详情见质量基准。
- Steam 页面已直读：[Wanderburg](https://store.steampowered.com/app/3624140/_Wanderburg/)。
- 外部资产只作研究证据，不复制进 `game/`；IL2CPP 方法体不作为原算法。

## 当前阻塞

- G1：UV/贴图绑定、损坏/修复材质、LOD/碰撞、动作三拍、场景密度、UIUX、敌人预告和修复状态。
- G2：连续喜剧动作、声音、低特效对照和外部试玩。
- 百种构筑：只有机制签名样例，100 个 build 目录和证据矩阵尚未完成。
- 发布：真实手柄、性能、release、Steam、Deck、完整战役和结算事务尚未验收。

## 状态边界

`whitebox → proposal → candidate → integrated → final`。当前白模、旧 GLB、Weaver 候选和新作者化候选都不能称 `final`。旧计划、旧导出和 wayfinder 未决票据保留为历史/决策材料，不自动删除或关闭。
