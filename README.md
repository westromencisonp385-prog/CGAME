# 回收者 / Reclaimer

“挖掘机拯救世界”的本地 M0：驾驶、铲击、投掷、模块装配、磁吸/水电/惯性组合、河岸修复与检查点恢复。

当前重点：**先确认整蛊、搞笑的整体美术方向，再制作真实镜头里的样板**。游戏仍是功能白模；方向图不是实机。需求已拆为17项功能实现和16项表现优化。

- [需求拆分与开工顺序](docs/requirements.md)
- [整体美术方向 A：一本正经的胡闹工程队](docs/assets/art-direction.md)
- [方向板 v2（待确认）](docs/assets/art-direction-a-v2.png)

## 开始

在项目根目录运行 PowerShell：

~~~powershell
pwsh -File tools/godot.ps1 doctor
pwsh -File tools/godot.ps1 run
~~~

工具固定使用 Godot **4.7.2 stable**，无需改系统 PATH。运行/截图与导出状态见 [CLI 工作流](docs/godot-cli-workflow.md)。

## 测试

~~~powershell
pwsh -File tools/godot.ps1 test
pwsh -File tools/godot.ps1 capture
~~~

日志、状态报告和真实GPU截图写到 artifacts/qa/。逻辑与图形检查分开，不把 headless 成功称作画面正确。真实手柄、Steam Deck和发行性能仍需专门验收。

## 操作

- WASD / 左摇杆移动，鼠标 / 右摇杆瞄准。
- 左键 / RT作业，右键 / LT投掷，Shift / LB冲刺。
- R / A修复；B / Y改装，选择挂点A/B，预览后确认。
- F1或界面GM入口打开测试台；无敌、冻结、调速、补充与预设状态明确显示。
- F5/F9为正常检查点；GM保存/读取使用独立检查点。F6重新出击。

## 参考与美术

解包指导挂点、等级显隐、主动/被动发射点和多层反馈；原创模型与图片不直接复制参考作品。

- [现役规格](docs/spec.md)
- [具体资产制作](docs/assets/production-guide.md)
- [生成图片与提示词](docs/assets/image-generation-manifest.json)
- [解包结构证据](evidence/reference_asset_contract.json)
- [解包视觉证据](evidence/reference_visual_study.json)
- [Compact 接续记录](docs/COMPACT.md)

首批烟尘精灵用于原生GPU粒子；磁暴鲸口卡面用于概念插画。磁场、电弧、修复环和水流由 Godot 实时绘制。车体仍为程序化灰盒，插画不代表最终3D模型。

旧立项PDF为历史快照，最新状态以本README、现役规格与QA结果为准。
