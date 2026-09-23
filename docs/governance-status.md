# 治理状态 · 2026-09-24

本文件是一次项目知识与工程收口的凭证，不是新的产品规格。产品规则仍以 `docs/spec.md` 为准；决策路线仍以 `docs/wayfinder/map.md` 为准。

## 现役事实面

| 事实面 | 状态 | 证据与边界 |
| --- | --- | --- |
| 代码 | verified-current | `62ddeb0` 是本次治理的代码基线；治理提交已包含文档和规则收口，M0/M1 运行代码、Godot 资源和测试入口均在仓库内。 |
| 运行态 | verified-current | 2026-09-24 用 Godot `4.7.2.stable.official.ed1daf0bf`、Mobile、NVIDIA RTX 4070 Ti SUPER 完成一次真 GPU capture；8 个场景均生成截图和 `runtime-evidence.json`。Dummy 音频只证明图形流程，不证明听感、延迟或设备输出。 |
| 文档 | changed-and-verified | `docs/spec.md` 是产品规格；`docs/requirements.md` 是 F/P 执行索引；`docs/wayfinder/` 是本地决策路线；本次补齐 `docs/agents/` 与本文件。历史计划和概念图仍明确标为提案/历史输入。 |
| 规则 | changed-and-verified | `AGENTS.md` 增加工程技能、票据和领域文档入口；规则继续要求固定 Godot、真实 GPU 图形验收和不把参考导出当算法。 |
| 记忆 | not-applicable | 仓库没有获准由本次收口维护的长期 Agent memory 文件。 `CONTEXT.md` 仅作为项目领域词汇表。 |
| 工作区 | changed-and-verified | 治理配置、wayfinder 路线、研究快照和历史计划已提交；`artifacts/`、`builds/`、`tmp/` 仍由 `.gitignore` 排除。删除候选未自动清理，等待用户在最终汇报后决定。 |
| 发布 | changed-and-verified | 治理提交已推送到 `origin/master` 和 `origin/codex/governance-2026-09-24`；没有创建或合并 PR，也没有部署。GitHub Issues 不是本项目当前的决策 tracker，避免产生第二套票据。 |

## 本次收口改动

- 加入 `docs/agents/issue-tracker.md`、`docs/agents/triage-labels.md`、`docs/agents/domain.md`，把现有 `docs/wayfinder/` 本地 Markdown 约定写成工程技能可读取的规则。
- 更新 `AGENTS.md`，让后续会话从同一套 tracker、领域词汇和验证边界开始。
- 修正 `docs/COMPACT.md` 中过时的“47f3a3a + 未提交修改”描述，改为以当前 Git 历史和本次治理分支为准。
- 保留 `docs/wanderburg-to-excavator-plan.md/.pdf` 作为历史研究快照，不把其中的月数、预算和内容上限升级为当前承诺。
- 保留 `docs/wayfinder/` 的未决票据：双功能挂点原型、组合预算、首个幻想载具样件和 M0 切片边界仍不能伪造为已决策；引用矩阵票据已按证据完成并记录答案。

## 验证记录

- `pwsh -File tools/godot.ps1 doctor`：通过，固定引擎和导出模板可用。
- `pwsh -File tools/godot.ps1 test`：通过，9 组测试全部退出码为 0、发出明确完成标记且没有 `SCRIPT ERROR`/`ERROR`。
- `pwsh -File tools/godot.ps1 capture`：通过，真实 GPU 生成 `clean`、`built`、`whale`、`preview`、`gm`、`repair`、`effects`、`restored` 八个场景；截图只证明当前图形流程，不证明最终美术质量。
- `pwsh -File tools/test-godot-cli-contract.ps1`：通过，CLI 标记、引擎版本拒绝和 GM 前置条件契约均通过。
- `pwsh -File tools/godot.ps1 export-debug` 与 `capture-build`：通过，Windows debug 导出可启动并生成构建截图；这不是 release/Steam 验收。
- Markdown 本地链接检查：通过，当前可扫描文档没有缺失的相对链接。
- Git 交付：`origin` 已加入用户给出的仓库，治理提交已推送到 `master` 和 `codex/governance-2026-09-24`；当前状态仍是 pushed，未宣称 merged/deployed/live verified。
- 尚未完成：真实手柄玩家流程、声音听感、性能 benchmark、release/Steam 验收、完整战役和方向 A v2 的用户确认。

## 下一步唯一入口

1. 由用户确认方向 A v2 的 G0 调性关口。
2. 处理 `docs/wayfinder/tickets/原型：冻结 M0 双功能挂点与输入语义.md`，再进入组合预算和首件样件决策。
3. 只有决策路线清空后，才将结果压缩回规格、拆成实现票据并扩展玩法或正式资产。
