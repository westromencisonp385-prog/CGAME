[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Runner = Join-Path $PSScriptRoot 'godot.ps1'
$Runtime = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'godot-runtime.json') | ConvertFrom-Json
$Fixture = Join-Path ([IO.Path]::GetTempPath()) ("wanderberg-godot-cli-contract-{0}" -f ([guid]::NewGuid().ToString('N')))

function Remove-FixtureSafely([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $fullPath = [IO.Path]::GetFullPath($Path)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $parent = [IO.Path]::GetDirectoryName($fullPath)
    $leaf = [IO.Path]::GetFileName($fullPath)
    $sameParent = [StringComparer]::OrdinalIgnoreCase.Equals($parent, $tempRoot)
    if (-not $sameParent -or -not $leaf.StartsWith('wanderberg-godot-cli-contract-', [StringComparison]::Ordinal)) {
        throw "Refusing recursive fixture cleanup outside task temp fixture: $fullPath"
    }
    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-Runner([string[]]$Arguments) {
    $output = & pwsh -NoProfile -File $Runner @Arguments 2>&1 | Out-String
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $output }
}

try {
    New-Item -ItemType Directory -Force -Path (Join-Path $Fixture 'tests') | Out-Null
    @'
[application]
config/name="Godot CLI contract fixture"
[display]
window/size/viewport_width=64
window/size/viewport_height=64
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -LiteralPath (Join-Path $Fixture 'project.godot') -Encoding UTF8
    @'
extends SceneTree

func _init() -> void:
	print("PASS unregistered fixture")
	quit(0)
'@ | Set-Content -LiteralPath (Join-Path $Fixture 'tests\unregistered.gd') -Encoding UTF8

    $unknown = Invoke-Runner @('test', '-ProjectPath', $Fixture, '-TimeoutSeconds', '30')
    if ($unknown.ExitCode -eq 0 -or $unknown.Output -notmatch 'missing explicit marker configuration') {
        throw "Unregistered marker fixture did not fail as required. exit=$($unknown.ExitCode)`n$($unknown.Output)"
    }
    Write-Host 'PASS marker contract: unregistered test fails without explicit marker configuration'

    $noGm = Invoke-Runner @('capture', '-NoGM', '-ProjectPath', $Fixture)
    if ($noGm.ExitCode -eq 0 -or $noGm.Output -notmatch 'capture requires GM') {
        throw "capture -NoGM did not fail with the GM contract message. exit=$($noGm.ExitCode)`n$($noGm.Output)"
    }
    Write-Host 'PASS capture contract: -NoGM fails before starting a capture'

    $noGmBuild = Invoke-Runner @('capture-build', '-NoGM', '-ProjectPath', $Fixture)
    if ($noGmBuild.ExitCode -eq 0 -or $noGmBuild.Output -notmatch 'capture-build requires GM') {
        throw "capture-build -NoGM did not fail with the debug-build GM contract message. exit=$($noGmBuild.ExitCode)`n$($noGmBuild.Output)"
    }
    Write-Host 'PASS build capture contract: -NoGM fails before exporting or launching a build'

    $fallback = [string]$Runtime.engine.fallback
    if (Test-Path -LiteralPath $fallback) {
        $oldCheck = Invoke-Runner @('check', '-EnginePath', $fallback, '-ProjectPath', $Fixture, '-TimeoutSeconds', '30')
        if ($oldCheck.ExitCode -ne 0 -or $oldCheck.Output -notmatch 'PASS check \(Godot 4\.6\.3') {
            throw "check did not preserve explicit compatibility diagnostics. exit=$($oldCheck.ExitCode)`n$($oldCheck.Output)"
        }
        Write-Host 'PASS engine contract: check diagnoses explicit compatibility engine'

        $oldCapture = Invoke-Runner @('capture', '-EnginePath', $fallback, '-ProjectPath', $Fixture, '-TimeoutSeconds', '30')
        if ($oldCapture.ExitCode -eq 0 -or $oldCapture.Output -notmatch 'capture requires Godot 4\.7\.2') {
            throw "capture accepted the compatibility engine. exit=$($oldCapture.ExitCode)`n$($oldCapture.Output)"
        }
        Write-Host 'PASS engine contract: capture rejects explicit compatibility engine'

        $oldExport = Invoke-Runner @('export-debug', '-EnginePath', $fallback, '-ProjectPath', $Fixture, '-TimeoutSeconds', '30')
        if ($oldExport.ExitCode -eq 0 -or $oldExport.Output -notmatch 'export-debug requires Godot 4\.7\.2') {
            throw "export-debug accepted the compatibility engine. exit=$($oldExport.ExitCode)`n$($oldExport.Output)"
        }
        Write-Host 'PASS engine contract: export-debug rejects explicit compatibility engine'
    } else {
        Write-Host 'SKIP engine contract: configured 4.6.3 compatibility engine is not installed'
    }
    Write-Host 'PASS godot CLI contract fixture'
    exit 0
} finally {
    Remove-FixtureSafely $Fixture
}
