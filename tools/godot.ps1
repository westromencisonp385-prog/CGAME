[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('doctor', 'import', 'check', 'test', 'run', 'capture', 'export-debug', 'launch4.7.2')]
    [string]$Command = 'doctor',
    [string]$EnginePath,
    [string]$ProjectPath,
    [int]$QuitAfter = 240,
    [int]$TimeoutSeconds = 120,
    [string]$CaptureDir,
    [switch]$NoGM
)

$ErrorActionPreference = 'Stop'
$ToolRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ToolRoot
$RuntimeConfigPath = Join-Path $ToolRoot 'godot-runtime.json'
$RuntimeConfig = Get-Content -Raw -LiteralPath $RuntimeConfigPath | ConvertFrom-Json
$DefaultProject = Join-Path $RepoRoot ([string]$RuntimeConfig.project)
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = $DefaultProject
}
$ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
$ArtifactsRoot = Join-Path $RepoRoot 'artifacts\qa'
New-Item -ItemType Directory -Force -Path $ArtifactsRoot | Out-Null

$PreferredEngine = [string]$RuntimeConfig.engine.preferred
$FallbackEngine = [string]$RuntimeConfig.engine.fallback

function Resolve-Engine([bool]$ForcePreferred = $false) {
    if (-not [string]::IsNullOrWhiteSpace($EnginePath)) {
        if (-not (Test-Path -LiteralPath $EnginePath)) {
            throw "指定的 Godot 引擎不存在: $EnginePath"
        }
        return (Resolve-Path -LiteralPath $EnginePath).Path
    }
    if (Test-Path -LiteralPath $PreferredEngine) {
        return (Resolve-Path -LiteralPath $PreferredEngine).Path
    }
    if ($ForcePreferred) {
        throw "Godot 4.7.2 未安装。doctor 强制验证 4.7.2，不会从 PATH 静默切换。预期路径: $PreferredEngine"
    }
    throw "找不到固定的 Godot 4.7.2。仅在显式传入 -EnginePath 时执行其他版本诊断，不从 PATH 自动切换。"
}

function Get-RunStamp() {
    return (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss-fff')
}

function Invoke-GodotProcess {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][int]$Timeout,
        [string]$LogPrefix = 'godot'
    )
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Executable
    $psi.WorkingDirectory = $ProjectPath
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        [void]$psi.ArgumentList.Add([string]$argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi
    try {
        [void]$process.Start()
    } catch {
        throw "无法启动 Godot: $Executable`n$($_.Exception.Message)"
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    if (-not $process.WaitForExit($Timeout * 1000)) {
        $timedOut = $true
        # 只终止本次启动、且仍然属于当前 runner 的 Godot PID。
        try { $process.Kill() } catch { }
        [void]$process.WaitForExit(5000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $logPath = Join-Path $ArtifactsRoot ("{0}-{1}.log" -f $LogPrefix, (Get-RunStamp))
    $text = @(
        "executable=$Executable"
        "arguments=$($Arguments -join ' ')"
        "exit_code=$($process.ExitCode)"
        "timed_out=$timedOut"
        '--- stdout ---'
        $stdout
        '--- stderr ---'
        $stderr
    ) -join [Environment]::NewLine
    Set-Content -LiteralPath $logPath -Value $text -Encoding UTF8
    [pscustomobject]@{
        ExitCode = $process.ExitCode
        TimedOut = $timedOut
        Stdout = $stdout
        Stderr = $stderr
        Log = $logPath
        Pid = $process.Id
    }
}

function Test-EngineErrors([string]$Text) {
    return [regex]::IsMatch($Text, '(?im)(SCRIPT ERROR:|^ERROR:)')
}

function Test-PreferredEngineVersion([string]$Version) {
    # Match the complete semantic version prefix. A simple StartsWith would
    # accidentally accept versions such as 4.7.20 as the fixed 4.7.2 tool.
    return -not [string]::IsNullOrWhiteSpace($Version) -and $Version.Trim() -match '^4\.7\.2(?:\.|$)'
}

function Get-EngineVersion([string]$Executable) {
    $result = Invoke-GodotProcess -Executable $Executable -Arguments @('--version') -Timeout 15 -LogPrefix 'version'
    return [pscustomobject]@{ Result = $result; Version = ($result.Stdout.Trim() -split "`r?`n" | Select-Object -First 1) }
}

function Format-EngineVersion([string]$Version) {
    if ([string]::IsNullOrWhiteSpace($Version)) { return '<unavailable>' }
    return $Version.Trim()
}

function Find-ExportTemplate([string]$Version) {
    $root = Join-Path $env:APPDATA 'Godot\export_templates'
    if (-not (Test-Path -LiteralPath $root)) { return $null }
    $directories = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue
    return $directories | Where-Object { $_.Name -like "$Version*" } | Select-Object -First 1
}

function Invoke-Doctor {
    try {
        $engine = Resolve-Engine $true
        $version = Get-EngineVersion $engine
        $projectFile = Join-Path $ProjectPath 'project.godot'
        $projectText = Get-Content -Raw -LiteralPath $projectFile
        $template = Find-ExportTemplate '4.7.2'
        $gitCommit = (& git -C $RepoRoot rev-parse --short HEAD 2>$null).Trim()
        $payload = [ordered]@{
            engine = $engine
            version = $version.Version
            preferred_version = '4.7.2.stable.official'
            preferred_path_exists = (Test-Path -LiteralPath $PreferredEngine)
            fallback_path_exists = (Test-Path -LiteralPath $FallbackEngine)
            project = $ProjectPath
            project_feature_4_7 = $projectText.Contains('"4.7"')
            renderer = ([regex]::Match($projectText, 'rendering_method="([^"]+)"')).Groups[1].Value
            export_templates_4_7_2 = if ($null -ne $template) { $template.FullName } else { $null }
            export_templates_required_url = [string]$RuntimeConfig.export.template_url
            git_commit = $gitCommit
            path_mutated = $false
            runtime_capture = (Test-Path -LiteralPath (Join-Path $ProjectPath 'tests\runtime_capture.gd'))
        }
        Write-Host ($payload | ConvertTo-Json -Depth 6)
        if ($version.Result.ExitCode -ne 0 -or -not (Test-PreferredEngineVersion $version.Version)) { return 1 }
        return 0
    } catch {
        Write-Error $_
        return 1
    }
}

function Invoke-Check([string]$Mode) {
    $engine = Resolve-Engine
    $args = @('--headless', '--import', '--path', $ProjectPath)
    $result = Invoke-GodotProcess -Executable $engine -Arguments $args -Timeout $TimeoutSeconds -LogPrefix $Mode
    $combined = "$($result.Stdout)`n$($result.Stderr)"
    Write-Host $combined
    if ($result.TimedOut -or $result.ExitCode -ne 0 -or (Test-EngineErrors $combined)) {
        Write-Error "$Mode 失败，日志: $($result.Log)"
        return 1
    }
    $engineVersion = Get-EngineVersion $engine
    Write-Host "PASS $Mode (Godot $($engineVersion.Version); log=$($result.Log))"
    return 0
}

function Invoke-Tests {
    $engine = Resolve-Engine
    $engineVersion = Get-EngineVersion $engine
    $tests = Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'tests') -Filter '*.gd' -File | Where-Object { $_.Name -ne 'runtime_capture.gd' } | Sort-Object Name
    if ($tests.Count -eq 0) { Write-Error '没有找到 game/tests/*.gd'; return 1 }
    $allPassed = $true
    $markerConfig = $null
    $markerConfigProperty = $RuntimeConfig.PSObject.Properties['test_markers']
    if ($null -ne $markerConfigProperty) { $markerConfig = $markerConfigProperty.Value }
    foreach ($test in $tests) {
        $markerProperty = if ($null -ne $markerConfig) { $markerConfig.PSObject.Properties[$test.Name] } else { $null }
        if ($null -eq $markerProperty -or [string]::IsNullOrWhiteSpace([string]$markerProperty.Value)) {
            $allPassed = $false
            Write-Host "FAIL $($test.Name): missing explicit marker configuration in tools/godot-runtime.json"
            continue
        }
        $marker = [string]$markerProperty.Value
        $args = @('--headless', '--path', $ProjectPath, '--script', ("res://tests/{0}" -f $test.Name))
        $result = Invoke-GodotProcess -Executable $engine -Arguments $args -Timeout $TimeoutSeconds -LogPrefix ("test-{0}" -f $test.BaseName)
        $combined = "$($result.Stdout)`n$($result.Stderr)"
        $hasMarker = $combined.Contains($marker)
        $hasError = Test-EngineErrors $combined
        $passed = (-not $result.TimedOut) -and ($result.ExitCode -eq 0) -and $hasMarker -and (-not $hasError)
        if ($passed) {
            Write-Host "PASS $($test.Name): marker '$marker' (Godot $(Format-EngineVersion $engineVersion.Version); log=$($result.Log))"
        } else {
            $allPassed = $false
            Write-Host "FAIL $($test.Name): exit=$($result.ExitCode), timed_out=$($result.TimedOut), marker=$hasMarker, engine_error=$hasError (log=$($result.Log))"
        }
    }
    if (-not $allPassed) { return 1 }
    Write-Host "PASS test: every test exited 0, emitted its required marker, and emitted no SCRIPT ERROR/ERROR (Godot $(Format-EngineVersion $engineVersion.Version))"
    return 0
}

function Invoke-Run {
    $engine = Resolve-Engine
    $engineVersion = Get-EngineVersion $engine
    $args = @('--path', $ProjectPath, '--')
    if (-not $NoGM) { $args += '--gm' } else { $args += '--no-gm' }
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $engine
    $start.WorkingDirectory = $ProjectPath
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    foreach ($argument in $args) { [void]$start.ArgumentList.Add($argument) }
    $process = [System.Diagnostics.Process]::Start($start)
    Write-Host "Started Godot $engine (version $(Format-EngineVersion $engineVersion.Version), PID $($process.Id)); GM=$(-not $NoGM)"
    return 0
}

function Invoke-Capture {
    if ($NoGM) {
        Write-Error 'capture requires GM: the runtime capture contract uses main.gm.execute for every scenario. Remove -NoGM.'
        return 1
    }
    $engine = Resolve-Engine
    $engineVersion = Get-EngineVersion $engine
    if (-not (Test-PreferredEngineVersion $engineVersion.Version)) {
        Write-Error "capture requires Godot 4.7.2 stable; resolved $($engineVersion.Version) at $engine. Use the configured preferred engine."
        return 1
    }
    if ([string]::IsNullOrWhiteSpace($CaptureDir)) {
        $CaptureDir = Join-Path $ArtifactsRoot ("capture-{0}" -f (Get-RunStamp))
    }
    New-Item -ItemType Directory -Force -Path $CaptureDir | Out-Null
    $args = @('--path', $ProjectPath, '--script', [string]$RuntimeConfig.capture.script, '--', ("--capture-dir={0}" -f ((Resolve-Path -LiteralPath $CaptureDir).Path)), ("--quit-after={0}" -f $QuitAfter))
    $args += '--gm'
    $result = Invoke-GodotProcess -Executable $engine -Arguments $args -Timeout $TimeoutSeconds -LogPrefix 'capture'
    $combined = "$($result.Stdout)`n$($result.Stderr)"
    Write-Host $combined
    if ($result.TimedOut -or $result.ExitCode -ne 0 -or (Test-EngineErrors $combined)) {
        Write-Error "capture 失败，日志: $($result.Log)"
        return 1
    }
    $evidence = Join-Path ((Resolve-Path -LiteralPath $CaptureDir).Path) 'runtime-evidence.json'
    if (-not (Test-Path -LiteralPath $evidence)) {
        Write-Error "capture 未生成 runtime-evidence.json；拒绝把运行日志当作截图证据。"
        return 1
    }
    $doc = Get-Content -Raw -LiteralPath $evidence | ConvertFrom-Json
    if (-not $doc.passed -or @($doc.scenario | Where-Object status -ne 'captured').Count -gt 0) {
        throw 'Capture report contains failed/skipped required scenarios.'
    }
    $doc.commit = ((& git -C $RepoRoot rev-parse --short HEAD 2>$null).Trim())
    $sourceFiles = Get-ChildItem -LiteralPath $ProjectPath -File -Recurse | Where-Object { $_.FullName -notmatch '[\\/]\.godot[\\/]' } | Sort-Object FullName
    $hashes = @($sourceFiles | ForEach-Object { [ordered]@{ path = [IO.Path]::GetRelativePath($ProjectPath, $_.FullName); sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash } })
    $doc | Add-Member -NotePropertyName source_dirty -NotePropertyValue ([bool](& git -C $RepoRoot status --porcelain -- game)) -Force
    $doc | Add-Member -NotePropertyName source_files -NotePropertyValue $hashes -Force
    $doc.logs = @($result.Log)
    $doc.engine = [ordered]@{ path = $engine; version = $engineVersion.Version }
    $doc.renderer = if ($doc.renderer) { [string]$doc.renderer } else { 'unknown' }
    $doc | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $evidence -Encoding UTF8
    Write-Host "PASS capture: $evidence (Godot $(Format-EngineVersion $engineVersion.Version); log=$($result.Log))"
    return 0
}

function Invoke-ExportDebug {
    $engine = Resolve-Engine
    $engineVersion = Get-EngineVersion $engine
    if (-not (Test-PreferredEngineVersion $engineVersion.Version)) {
        Write-Error "export-debug requires Godot 4.7.2 stable; resolved $($engineVersion.Version) at $engine. Use the configured preferred engine."
        return 1
    }
    $template = Find-ExportTemplate '4.7.2'
    if ($null -eq $template) {
        $message = "缺少 Godot 4.7.2 export templates。请下载并解压官方包: $([string]$RuntimeConfig.export.template_url) 到 $env:APPDATA\Godot\export_templates\4.7.2.stable。"
        Write-Error $message
        return 1
    }
    $preset = [string]$RuntimeConfig.export.preset
    $presetFile = Join-Path $ProjectPath 'export_presets.cfg'
    if (-not (Test-Path -LiteralPath $presetFile)) {
        Write-Error "缺少 $presetFile；先在 Godot 4.7.2 Editor 创建 '$preset' 导出预设，避免 wrapper 猜测项目导出选项。"
        return 1
    }
    $buildDir = Join-Path $RepoRoot 'builds'
    New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
    $output = Join-Path $buildDir 'reclaimer-debug-4.7.2.exe'
    $args = @('--headless', '--path', $ProjectPath, '--export-debug', $preset, $output)
    $result = Invoke-GodotProcess -Executable $engine -Arguments $args -Timeout $TimeoutSeconds -LogPrefix 'export-debug'
    $combined = "$($result.Stdout)`n$($result.Stderr)"
    Write-Host $combined
    if ($result.TimedOut -or $result.ExitCode -ne 0 -or (Test-EngineErrors $combined) -or -not (Test-Path -LiteralPath $output)) {
        Write-Error "export-debug 失败，日志: $($result.Log)"
        return 1
    }
    Write-Host "PASS export-debug: $output (Godot $(Format-EngineVersion $engineVersion.Version); log=$($result.Log))"
    return 0
}

$exit = switch ($Command) {
    'doctor' { Invoke-Doctor }
    'import' { Invoke-Check 'import' }
    'check' { Invoke-Check 'check' }
    'test' { Invoke-Tests }
    'run' { Invoke-Run }
    'launch4.7.2' { Invoke-Run }
    'capture' { Invoke-Capture }
    'export-debug' { Invoke-ExportDebug }
}
exit ([int]$exit)


