---
title: "挖掘机拯救世界：从规格到 M0 可制作路线"
label: wayfinder:map
status: open
tracker: local-markdown
destination: "形成一条在进入 Godot M0 实现前没有关键决策空洞的路线，并把结果交接给后续原型与制作工作。"
---

## Governance note · 2026-09-24

This map is retained as the project's decision record. The implementation has since reached a verified M0/M1 slice, so this map is not evidence that every ticket or product requirement is complete. Open tickets remain open until their decisions are actually resolved; the current product contract and release gate are in `docs/spec.md`, `docs/requirements.md`, and `docs/governance-status.md`.

## Destination

完成《挖掘机拯救世界》的 M0-ready 规格：关键术语统一，参考事实与原创提案分开，模块组合、操控、Prefab 变化、数值、反馈、存档和验收顺序没有未表达的关键决策。到达终点时，后续执行者可以按规格制作 M0，不需要重新决定核心体验边界。

## Notes

- 领域：单人 Steam 载具动作 Roguelite；个人主导、AI 协作、必要外包。
- 主要技能：to-spec、wayfinder、domain-modeling；规格模板见 [docs/spec.md](../spec.md)。
- 当前验收边界已确认：装配 → 预览 → 确认 → 实战触发组合 → 升级/变形 → 存档恢复。
- 当前没有远程 tracker，因此票据使用本地 Markdown；文件名是票据名称，状态和阻塞关系记录在 front matter。
- 规则：路线票据解决一个决定或一项为决定准备的研究；不在本图内直接量产内容或实现完整游戏。

## Decisions so far

- 当前技术基线：Godot 4.7.2、静态类型 GDScript、3D 斜俯视、有限分块挖掘。
- 模块是第一体验支柱：必须改变动作、路线、节奏、空间、修复关系或车辆形态，不能只增加 DPS。
- M0 采用两个通用功能挂点，允许水炮与电弧同时装配；这是对旧版“一个自动副工具槽”提案的修正。
- 三条 M0 组合候选：宽斗 + 磁吸、水炮 + 电弧、惯性飞轮 + 冲刺。
- 用户已选择完整装配到存档恢复作为主验收边界，并选择规格只保留在本地项目。

## Not yet specified

- 三条组合在同一套输入中的最终按键/手柄映射与自动触发比例。
- M0 的具体空间尺寸、镜头距离、目标数量、硬度和组合触发参数。
- 哪一个幻想分支进入首个目标品质样件，以及它需要多少独有模型、动画和音频。
- 参考导出中模块、升级、载具阶段之间的完整引用矩阵；已知字段不能替代未知算法。
- M1 之后的首发内容冻结、最低配置、Steam 插件版本和真实硬件预算。
- 第一次外部试玩的招募、记录格式和判定阈值细节。

## Out of scope

- 本路线图不复制或发布 Wanderburg 的模型、音频、脚本或导出工程。
- 本路线图不决定联机、开放世界、任意体素、水体模拟、自由拼车编辑器或持续运营赛季。
- 本路线图不替代 M0/M1 的真实试玩、性能实测和存档故障注入。

## Frontier

未解决票据见 [tickets/](tickets/)。可先处理的开放票据是：

- [研究：建立模块与载具引用矩阵](tickets/研究：建立模块与载具引用矩阵.md)
- [原型：冻结 M0 双功能挂点与输入语义](tickets/原型：冻结 M0 双功能挂点与输入语义.md)

其它票据会在这两项结果明确后进入前沿。
