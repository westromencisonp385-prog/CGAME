# 治理状态 · 2026-09-27

本文是项目知识与工程收口凭证，不是新的产品规格。产品规则以 `docs/spec.md` 为准，路线以 `docs/roadmap.md` 和 `docs/wayfinder/` 为准。

## 现役事实面

| 事实面 | 状态 | 证据与边界 |
| --- | --- | --- |
| 代码 | verified-current | 当前分支包含 M0/M1 功能循环、作者化候选切片接入、渲染候选改进、阶段 HUD 和构筑签名；9 组 Godot 行为测试通过。 |
| 运行态 | changed-and-verified | Godot 4.7.2 Mobile 真 GPU capture 通过；截图证明流程和导入运行，不证明达到 Wanderburg 视觉质量。G1 明确 failed。 |
| 文档 | changed-and-verified | README、COMPACT、spec、requirements、roadmap、project-guidance、质量基准和 G1 缺口报告已按 2026-09-27 事实重写。 |
| 参考研究 | changed-and-verified | 正确使用 AssetRipper GUI Free 1.3.5.0 对 Wanderburg 原始包重新导出；fresh inventory 记录 749 Prefab、5 场景、845 纹理、710 脚本。Steam 页面已直读。外部资产不进 Godot。 |
| 规则 | changed-and-verified | AGENTS/CONTEXT 已加入全局质量门、白模/正式资产边界和 100+ build 要求。 |
| 凭证 | changed-and-verified | Weaver 凭证已移出仓库并从可达 Git 历史清除；本机用户目录和环境变量优先，仓库只保留脱敏模板。 |
| 工作区 | pending | 当前代码工作树干净；`tmp/assetripper-wanderburg-20260927`、旧导出、旧计划和跟踪中的 artifacts 仍保留为研究/复核现场，未执行清场。 |
| 发布 | changed-and-verified | `origin/codex/governance-2026-09-24` 已推送至当前 HEAD；`origin/master` 未合并；未部署、未做 Steam/release/live 验证。 |
| 记忆 | not-applicable | 没有获准由本次收口维护的长期 Agent memory 文件。 |

## 当前 G1 结论

A01/B01/C04/倒流河谷已形成作者化候选切片和真实镜头证据，但以下仍未通过：UV/手绘贴图绑定、损坏/修复材质、LOD/碰撞实体、准备→接触→余韵动作、场景密度、UIUX、敌人预告和修复状态。因此不得宣称 `integrated` 或 `final`。

## 下一步唯一入口

1. 按 [docs/roadmap.md](roadmap.md) 关闭 G1 缺口。
2. G1 通过后，制作 G2 连续喜剧动作与修复反转。
3. 建立 100+ build 目录和机制→视觉证据矩阵，再扩充内容。
4. 完整战役、发布、Steam、Deck、真实手柄和性能验收排到 M1/M2 之后。

## 清场边界

旧导出、旧计划、`.blend1` 备份、跟踪 artifacts 和未决 wayfinder 票据均未删除或关闭。复核现场仍保留，等待用户在后续收尾汇报后明确确认，再决定是否清理。
