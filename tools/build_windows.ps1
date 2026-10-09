# 一键打包 Windows 试玩版：build\windows\ExcavateTheWorld.exe（单文件，资源内嵌）
# 前置：Godot 4.7 导出模板已装在 %APPDATA%\Godot\export_templates\4.7.stable
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "C:\Users\jasonlyan\AppData\Local\Microsoft\WinGet\Links\godot.exe"
$out = Join-Path $root "build\windows"
New-Item -ItemType Directory -Force $out | Out-Null
& $godot --headless --path (Join-Path $root "game") --export-debug "Windows Desktop" ((Join-Path $out "ExcavateTheWorld.exe") -replace '\\', '/')
Copy-Item (Join-Path $root "game\config\3c_tuning.json") (Join-Path $out "3c_tuning.json") -Force
Get-ChildItem $out | Select-Object Name, Length
