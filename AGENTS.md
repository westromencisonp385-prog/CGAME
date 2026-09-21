# Wanderberg / Reclaimer

单人 Steam 幻想工程车原型。模块要改变操作、剪影与战术，不能只增加 DPS。

## 入口

- 接续先读 docs/COMPACT.md、README.md。
- 改玩法前读 docs/spec.md；做美术前读 docs/assets/production-guide.md。
- 以 tools/godot-runtime.json 和 tools/godot.ps1 选择引擎，不依赖系统 PATH。
- 常用：pwsh -File tools/godot.ps1 doctor / test / run / capture。

## 工程约定

- Godot 4.7.2 stable，GDScript，Mobile，Jolt；项目在 game/。
- .tres 保存只读模块定义，运行状态单独保存；UID入库，.godot/不入库。
- GM UI 和自动化共用 execute/get_state；GM测试存档与正常进度分开。
- 行为测试走已确认的玩家流程；退出码、错误日志与完成标记一起判定。
- headless 不能验收图形。shader/资产/UI更改后用真GPU截图并查看结果。
- 捕获产物在 artifacts/qa/；固定帧录制不能作为实时性能证明。
- Wanderburg解包目录是研究输入。发布资产重新创作，外部导出不进游戏。
- 图像目标为用户要求的Image2.5；实际版本未知必须如实记录。

## 状态

- 当前是M0及开发测试工具，正式战役、Steam、真机手柄/Deck尚未完成。
- 先复现、修复和截图验证已有流程，再扩量；避免新增平行现役规格。
- docs/wayfinder是决策路线；任务拆分尚未全部确认，不自动关单。
