# Reclaimer / 挖掘机拯救世界

单人 Steam 幻想工程车 Roguelite。玩家驾驶、挖掘、搬运、压缩、投掷、修复并改造一台不断成长的工程车；模块必须改变操作、剪影、路线、节奏、空间或修复关系。

## 当前一句话状态

M0/M1 功能循环可运行；首个 A01/B01/C04/倒流河谷体验切片已接入作者化候选模型和渲染候选，但 **G1 质量对标失败**。当前模型、贴图、UIUX、关卡和特效仍处于 `candidate`，不能当正式资源。

当前唯一后续路线见 [docs/roadmap.md](docs/roadmap.md)。项目质量门见 [docs/project-guidance.md](docs/project-guidance.md)，产品权威规格见 [docs/spec.md](docs/spec.md)。

## 运行与验证

```powershell
pwsh -File tools/godot.ps1 doctor
pwsh -File tools/godot.ps1 test
pwsh -File tools/godot.ps1 capture
```

固定环境：Godot 4.7.2 stable、GDScript、Mobile、Jolt。`test` 证明行为流程；`capture` 才能检查真实 GPU 画面。当前 9 组行为测试通过，但截图只证明流程运行，不证明美术质量。

## 当前切片

- 玩家：A01 磁暴鲸口，机制签名为聚拢 → 压缩 → 投送。
- 敌人：B01 施工蟹，机制签名为横移冲撞 → 推墙或拆锚。
- 设施：C04 修复泵，机制签名为拆解 → 换密封 → 加压 → 恢复。
- 场景：倒流河谷，修复应改变水流、桥和路线。
- 当前状态：作者化 GLB、Blender 源、候选手绘表面图集、VFX 图集和 Godot 接入均为 `candidate`。

## 现役文档

- [项目现役路线](docs/roadmap.md)
- [项目全局指导：风格化、高精度、反 AI 感与百种构筑](docs/project-guidance.md)
- [现役产品规格](docs/spec.md)
- [功能/表现需求索引](docs/requirements.md)
- [G1 质量对标缺口报告](docs/assets/g1-quality-gap-report.md)
- [Wanderburg 质量基准：AssetRipper 与 Steam 直读](docs/assets/wanderburg-quality-benchmark-v2.md)
- [概念图到正式资产还原计划](docs/assets/concept-to-production-v1.md)
- [UIUX 方向与验收](docs/assets/g0-uiux-direction-v1.md)
- [本地决策路线](docs/wayfinder/map.md)
- [接续入口](docs/COMPACT.md)

## 参考与安全边界

Wanderburg 原始包只通过本机 AssetRipper 做研究；正确的 Wanderburg fresh export 记录在 [质量基准](docs/assets/wanderburg-quality-benchmark-v2.md)，不进入 `game/`。Steam 页面是产品和视觉参考，不是源码或算法证据。

Weaver 凭证只在用户本机 `C:\Users\Administrator\.config\wanderberg\weaver-credentials.txt` 或进程环境中使用。仓库只保留脱敏模板和标准客户端工具。

正式资产要从概念图重新创作，必须经过真实镜头、材质、动作、碰撞、LOD、UI 避让、720p/1080p 和缺陷复测。历史立项估算、旧导出和旧计划均不代表当前承诺。
