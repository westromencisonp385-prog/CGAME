# Godot 4.7.2 CLI 与真实渲染 QA 工作流

本项目固定以 Godot 4.7.2 stable 作为正式运行时，保留机器上的 Godot 4.6.3 只做显式兼容诊断。runner 使用绝对路径，不修改系统 `PATH`，所以 AI 或 CI 不会因为 shell 环境漂移而调用到别的 Godot 版本。

## 一条命令

在仓库根目录运行：

```powershell
pwsh -NoProfile -File .\tools\godot.ps1 doctor
pwsh -NoProfile -File .\tools\godot.ps1 check
pwsh -NoProfile -File .\tools\godot.ps1 test
pwsh -NoProfile -File .\tools\godot.ps1 capture -CaptureDir "$pwd\artifacts\qa\capture-local"
pwsh -NoProfile -File .\tools\godot.ps1 export-debug
pwsh -NoProfile -File .\tools\godot.ps1 capture-build -CaptureDir "$pwd\artifacts\qa\capture-build-local"
pwsh -NoProfile -File .\tools\godot.ps1 launch4.7.2
pwsh -NoProfile -File .\tools\test-godot-cli-contract.ps1
```

`launch4.7.2` 是 `run` 的别名，会使用配置中的 4.7.2，并通过 `--` 传入 `--gm`。交互调试可用 Godot 窗口或编辑器查看；runner 启动的是独立进程并返回 PID。若要诊断旧版兼容性，必须显式传入 `-EnginePath`；runner 不会静默回退。

## 命令含义

- `doctor` 强制检查 4.7.2 的绝对路径、版本、项目 `config/features=4.7`、Mobile renderer、截图脚本、回退引擎和导出模板目录。它不会读取 PATH，也不会自动安装另一个版本。
- `import` / `check` 使用 `--headless --import` 做资源扫描和脚本/场景导入验证。它们只报告 Godot 进程自己的退出码和日志，并在成功行中打印实际解析出的版本；因此可显式传入 4.6.3 做兼容性诊断。
- `test` 对 `game/tests/*.gd` 逐个启动 Godot。每个测试必须在 `tools/godot-runtime.json` 的 `test_markers` 中登记显式输出标记，并同时满足：进程退出码为 0、对应标记出现、输出中没有 `SCRIPT ERROR` 或 `ERROR`。未登记的测试会直接失败，不能用普通的 `PASS` 文本蒙混通过。
- `capture` **必须启用 GM 且禁止 headless**，直接运行 Mobile/Vulkan 窗口并从真实 root viewport 取得图像；没有 GPU/窗口时失败。传入 `-NoGM` 会在启动前明确失败，因为八个场景都通过公开 `main.gm.execute(command,args)` 驱动。runner 会显式传 `--audio-driver Dummy`，避免本机 WASAPI 设备状态污染图形 QA；报告中的 `audio.verified=false` 表示声音未验收。`--quit-after` 的单位是渲染迭代/帧，不是秒，例如 `-QuitAfter 240`。截图脚本会加载真实 `res://scenes/main.tscn`，不创建替代场景或 dummy screenshot。
- `export-debug` 检查调用的引擎确实是完整的 4.7.2 版本前缀（不会把 4.7.20 当成 4.7.2）、模板和 `game/export_presets.cfg` 后执行 Windows Desktop debug 导出。输出位于 `builds/reclaimer-debug-4.7.2.exe`，模板缺失时显示官方 URL 并失败，不会误用其他版本。正式 `capture` 与 `export-debug` 都拒绝显式传入 4.6.3。
- `capture-build` 先执行同一套 debug 导出，再启动导出的 exe 做图形截图。导出 exe 只接收 `--audio-driver Dummy -- --gm --qa-capture=<png>`，禁止使用编辑器专属 `--path` 或 `--script`。它写入 `build-capture-evidence.json` 和一张真实窗口截图；报告同样标记 `audio.verified=false`，不能当作声音通过。

`test-godot-cli-contract.ps1` 建立临时 Godot fixture，验证未知测试缺少 marker 时失败、`capture -NoGM` 早拒绝、`check` 可以记录显式 4.6.3 诊断，以及 4.6.3 不能用于正式截图或导出。fixture 会在结束时删除，不写入项目。

## 真实截图场景

`game/tests/runtime_capture.gd` 目前按顺序记录：

1. `clean`：新合同的真实 HUD、车辆、河岸和目标。
2. `built`：GM `preset=magnet` 后切到结构阶段 2，验证挂点和车辆视觉升级。
3. `whale`：公开 `whale_demo` 后用正常主作业打包轻型目标，验证第一条整蛊动作的实机表现。
4. `preview`：打开改装台并以公开 `preview` 命令显示水炮幽灵预览。
5. `gm`：通过公开 `panel open=true` 打开 GM 测试工作台，再读取 `status`；面板必须真实可见。
6. `repair`：GM `repair` 启动水泵，验证世界修复可见状态。
7. `effects`：GM `vfx enabled=true`，验证 Godot 原生特效开关。
8. `restored`：GM `save` → `preset=ram` → `load`，验证装配和世界恢复。

每个已捕获场景都必须生成非零尺寸 PNG；缺少命令、空 viewport 或无法保存图片会把该场景标为 `skipped/failed` 并令总体验证失败。截图目录同时写 `runtime-evidence.json`，字段包括 `engine`、`commit`、`renderer`、`gpu`、`scenario`、`frames`、`screenshots`、`logs`、`passed`。runner 在进程结束后补入当前 Git 短 commit 和 runner log。

已验证的一次真实运行：

```text
artifacts/qa/capture-final1/runtime-evidence.json
GPU: NVIDIA GeForce RTX 4070 Ti SUPER
Vulkan 1.4.351 / Forward Mobile
scenarios: clean, built, whale, preview, gm, repair, effects, restored
passed: true
```

## Godot 4.7.2 模板

官方归档下载地址：

`https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=export_templates.tpz&platform=templates`

完整 `.tpz` 约 1.28 GB。当前机器已解压 Windows x86_64 debug 所需文件到：

`%APPDATA%\Godot\export_templates\4.7.2.stable\`

其中包括 `windows_debug_x86_64.exe`、`windows_debug_x86_64_console.exe` 和 `version.txt`。仓库不提交模板二进制；新机器运行 `doctor` 会显示缺失，`export-debug` 会给出该官方链接。

## 证据和故障定位

所有 runner 日志和真实截图写入根目录 `artifacts/qa/`，该目录已加入 `.gitignore`。每次 Godot 进程只由当前 runner PID 启动和终止；超时不会杀掉无关进程。日志保留 stdout、stderr、完整参数、退出码和是否超时，便于 AI 按同一输入重放。

不要把 `--benchmark-file` 的结果当作真实 FPS 性能结论；它只能作为引擎阶段 benchmark 记录。性能验收仍需在目标硬件和正式场景上采样。

如果需要诊断 4.6.3 的兼容性，可以显式传入绝对路径运行 `check`（正式截图和导出会拒绝该版本）：

```powershell
pwsh -NoProfile -File .\tools\godot.ps1 check -EnginePath "C:\Users\Administrator\AppData\Local\Microsoft\WinGet\Links\godot_console.exe"
```

回退只用于诊断兼容性；正式截图和导出应保持 4.7.2。
