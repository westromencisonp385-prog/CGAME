# Compact · 项目接续入口

更新时间：2026-09-28。本文是磁盘接续记录，不代表调用了宿主原生 /compact 命令。

## 当前一句话状态

Reclaimer 是 Godot 4.7.2 的单人幻想工程车 Roguelite。M0/M1 功能循环可运行；首轮已确认 15 分钟磁暴流派，从小型鲸口成长为移动回收工厂再到超大型吞噬机械，配套 4 种普通敌人、2 种精英和 BOSS01 断城巨神。A01/B01/C04/倒流河谷切片仍是候选，G1 视觉质量对标失败，正式 UIUX、贴图、场景、动作和首轮内容集成仍未完成。

## 唯一现役入口

- 产品规则：[docs/spec.md](spec.md)
- 全局质量门：[docs/project-guidance.md](project-guidance.md)
- 后续路线：[docs/roadmap.md](roadmap.md)
- F/P 执行索引：[docs/requirements.md](requirements.md)
- 本地决策路线：[docs/wayfinder/map.md](wayfinder/map.md)
- 美术生产：[docs/assets/concept-to-production-v1.md](assets/concept-to-production-v1.md)
- 百种构筑目录：[docs/builds/build-catalog-v1.md](builds/build-catalog-v1.md)
- 部件化幻想样件：[docs/assets/modular-fantasy-v1/README.md](assets/modular-fantasy-v1/README.md)
- UIUX：[docs/assets/g0-uiux-direction-v1.md](assets/g0-uiux-direction-v1.md)
- 质量基准：[docs/assets/wanderburg-quality-benchmark-v2.md](assets/wanderburg-quality-benchmark-v2.md)
- 缺口报告：[docs/assets/g1-quality-gap-report.md](assets/g1-quality-gap-report.md)

## 已确认事实

- 主验收流程：装配 → 预览 → 确认 → 实战触发组合 → 升级/变形 → 存档恢复。
- 图形漫画方向 C 已确认；用户提供的 A01/B01/C04 概念 PNG 是视觉真源，生产强调强轮廓、硬色块、夸张透视、非对称剪影和作者化笔触。
- 首轮战斗目标是高速清怪、重击、物理连锁和击败 BOSS01；修复发生在 Boss 战后，不替代战斗胜利。
- 首轮生产允许从概念 PNG 进入 3D candidate；真实游戏集成必须通过 Godot 实际镜头、碰撞、动作、LOD、UI 避让和缺陷复测。
- 正式内容质量门：风格化、高精度、去 AI 感、多种多样；首发规划至少 100 个可区分 build。
- A01/B01/C04/倒流河谷和 N01–N04/E01–E02/BOSS01 是首轮玩法样板目标，不代表正式资产或完整流派已通过。
- 当前 `candidate` 切片包含作者化 GLB、Blender 源、候选表面图集、VFX 图集、渲染改进、阶段 HUD 和 `magnetic_whale` 机制签名。
- 9 组 Godot 行为测试和真 GPU capture 通过，只证明流程/导入/事件可运行。

## 真实参考状态

- Wanderburg 原始发行包：`F:\SteamLibrary\steamapps\common\Wanderburg Game`。
- 正确 AssetRipper fresh export：`tmp/assetripper-wanderburg-20260927/ExportedProject`。
- fresh 统计：749 Prefab、5 场景、845 纹理、710 脚本；详情见质量基准。
- Steam 页面已直读：[Wanderburg](https://store.steampowered.com/app/3624140/_Wanderburg/)。
- 外部资产只作研究证据，不复制进 `game/`；IL2CPP 方法体不作为原算法。

## 当前阻塞

- G1/G2：UV/贴图绑定、损坏/修复材质、LOD/碰撞、动作三拍、首轮三阶段成长、场景密度、UIUX、普通/精英预告、Boss 弱点和修复状态。
- G2：连续喜剧动作、声音、低特效对照和外部试玩。
- 百种构筑：只有机制签名样例，100 个 build 目录和证据矩阵尚未完成。
- 发布：真实手柄、性能、release、Steam、Deck、完整战役和结算事务尚未验收。

## 状态边界

`whitebox → proposal → candidate → integrated → final`。当前白模、旧 GLB、Weaver 候选和新作者化候选都不能称 `final`。旧计划、旧导出和 wayfinder 未决票据保留为历史/决策材料，不自动删除或关闭。
