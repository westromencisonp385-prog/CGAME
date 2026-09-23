# Compact · 项目接续入口

更新时间：2026-09-24。磁盘接续记录；不以此宣称调用了宿主原生 /compact 命令。

- 目标：个人 + AI + 必要外包，Steam单机幻想工程车游戏；战斗、挖掘升级、世界修复、模块改变操控/剪影/规则。幻想不受真实车型约束。
- 最新指示：用to-spec拆需求；整体必须整蛊、搞笑、有趣。明确F功能/P表现；当前白模视觉不合格。先学习解包视觉、从整体做美学设计，确认调性后才制作内容。
- 已确认：本地交付；主验收流程为装配→预览→确认→实战组合→升级/变形→存档恢复。不重复询问tracker或验收边界。
- 当前入口：docs/spec.md v0.4为唯一产品规格；docs/requirements.md为17项F/16项P执行索引；docs/assets/art-direction.md为方向A提案，v2概念板待用户确认。
- 内容扩展：docs/world-bible.md 新增三条机器谱系、9类怪物/环境对手、8种合同模板、三群系与叙事呈现；docs/assets/expansion-concept-board-v1.png 是概念方向板，均为提案，不代表已进入主玩法。
- 关口：G0参考/调性确认→G1一车一敌一段河岸实机样板→G2一条完整喜剧动作与修复演出→G3扩三构筑/合同。图中最终巨兽不是已批准的近期内容。
- 当前实现已包含 M0/M1 核心循环、鲸口打包、真实修复捷径、蓝图奖励，以及 Blender 5.2.1 的 122对象/77网格鲸口资产样件。概念图仍是方向提案；图像实际生成版本未知，manifest保留image2.5目标与unknown实际版本。
- 代码：本次治理从已提交基线62ddeb0开始，治理配置、决策路线和研究快照已在治理分支提交并推送。不要把大量未跟踪缓存、工具二进制和第三方导出一并提交。
- 引擎：固定Godot4.7.2 stable、GDScript、Mobile、Jolt；用项目CLI，PATH可能仍是4.6.3。Windows debug模板与导出已有，release模板和发行验收未完成。
- M0已有驾驶/主斗/投掷/冲刺、核心/动力/两功能槽、三代表组合、局部修复、胜负重试和A/B快照；GM共享命令、独立存档、面板暂停等基础已实现。正式3D、完整AI/战役/结算事务/Steam未完成。
- 既有QA：9组逻辑测试通过；M1有修复前后路线真GPU截图（4070Ti SUPER，Mobile），捕获流程有8个场景并记录来源hash。它们证明流程和捕获可运行，不证明美术合格或好玩。真实手柄、声音听感、性能与真人试玩仍待验收。
- 参考包：F:/SteamLibrary/steamapps/common/Wanderburg Game是Unity IL2CPP发行包；AssetRipper导出在F:/WanderburgAssetRipperExport/ExportedProject。5场景、749Prefab、845纹理、707C#文件不等于全部可玩内容，方法体不能作为原算法。
- 研究：evidence/reference_asset_contract.json为六结构样例；reference_visual_study.json为图像/色板/材质/shader/相机12条来源记录。本轮实际查看4张导出图；运行镜头/动态切换/后处理仍未知。商业参考资产不放入game。
- 视觉制作：先读art-direction再读production-guide。Image2.5目标生成位图，Blender/程序几何做3D，Godot做原生材质/动画/特效/UI；先无特效实机读图，再叠演出。
- 本轮实现：F-05最小鲸口打包、P-09技术样件、Blender 5.2.1鲸口GLB、F-15 CLI合同，以及 M1 小合同（修复前后真实路线门禁、蓝图奖励、GM/F5/F9恢复）。P-03/P-04/P-05/P-06/P-11 的正式 G1 样板仍待制作，当前9组 Godot行为测试通过；完整战役和蓝图效果树仍未完成。
- 不自动关闭旧wayfinder/tickets，不把规格条目视作已完成；旧PDF及月份/人日预算为历史立项估算。
- 治理凭证：[docs/governance-status.md](governance-status.md)；删除候选和未验证发布面保留为 pending，不在本次自动清场。
