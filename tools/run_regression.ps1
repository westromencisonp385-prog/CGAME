$godot = "C:\Users\jasonlyan\AppData\Local\Microsoft\WinGet\Links\godot.exe"
$repo = Split-Path -Parent $PSScriptRoot
$proj = Join-Path $repo "game"
New-Item -ItemType Directory -Force (Join-Path $repo "artifacts\qa") | Out-Null
$log = Join-Path $repo "artifacts\qa\regression_latest.txt"
"started $(Get-Date -Format s)" | Out-File $log -Encoding utf8
& $godot --headless --import --path $proj 2>&1 | Select-String "SCRIPT ERROR|Parse Error" | Select-Object -First 8 | Out-File $log -Append -Encoding utf8
$markers = [ordered]@{
	"asset_bake_flow.gd"="PASS asset_bake_flow:"; "biome_flow.gd"="PASS biome_flow:"; "c17_feel_flow.gd"="PASS c17_feel_flow:"
	"c9_roster_flow.gd"="PASS c9_roster_flow:"; "combat_flow.gd"="PASS combat_flow:"; "content_v2_flow.gd"="PASS content_v2_flow:"
	"contract_flow.gd"="CONTRACT FLOW PASS:"; "core_loop_flow.gd"="CORE LOOP PASS:"; "core_loop_m1_flow.gd"="CORE LOOP M1 PASS:"
	"enemy_roster_flow.gd"="PASS enemy_roster_flow:"; "gm_flow.gd"="GM FLOW PASS:"; "luck_flow.gd"="PASS luck_flow:"
	"m0_smoke.gd"="M0 smoke:"; "min_slice_flow.gd"="PASS min_slice_flow:"; "presentation_flow.gd"="PRESENTATION FLOW PASS:"
	"progression_flow.gd"="PASS progression_flow:"; "rig_ui_flow.gd"="PASS rig_ui_flow:"; "save_flow.gd"="SAVE FLOW PASS:"
	"whale_pack_flow.gd"="WHALE PACK FLOW PASS:"; "c19_3c_flow.gd"="C19 3C PASS:"; "c20_feel_flow.gd"="C20 FEEL PASS:"; "c21_vfx_flow.gd"="C21 VFX PASS:"; "c22_anim_flow.gd"="C22 ANIM PASS:"
}
$failed = 0
foreach ($t in $markers.Keys) {
	$out = (& $godot --headless --path $proj --script "res://tests/$t" 2>&1 | Out-String)
	if ($out.Contains($markers[$t]) -and -not ($out -match "SCRIPT ERROR")) { "ok   $t" | Out-File $log -Append -Encoding utf8 }
	else { $failed++; "FAIL $t" | Out-File $log -Append -Encoding utf8; ($out -split "`n" | Where-Object { $_ -match "SCRIPT ERROR|FAIL|\[0\] " } | Select-Object -First 4) | Out-File $log -Append -Encoding utf8 }
}
"=== REGRESSION total $($markers.Count) failed $failed ===" | Out-File $log -Append -Encoding utf8
$c13 = (& $godot --path $proj --resolution 1280x720 --script "res://tests/c13_ingame_check.gd" 2>&1 | Out-String)
"--- c13 ingame ---" | Out-File $log -Append -Encoding utf8
($c13 -split "`n" | Where-Object { $_ -match "PASS|FAIL|SCRIPT ERROR|C13" } | Select-Object -First 20) | Out-File $log -Append -Encoding utf8
$c18 = (& $godot --path $proj --resolution 1280x720 --script "res://tests/c18_whitebox_audit.gd" 2>&1 | Out-String)
"--- c18 whitebox audit ---" | Out-File $log -Append -Encoding utf8
($c18 -split "`n" | Where-Object { $_ -match "WHITEBOX|C18|SCRIPT ERROR" } | Select-Object -First 40) | Out-File $log -Append -Encoding utf8
$c23 = (& $godot --path $proj --resolution 1280x720 --script "res://tests/c23_click_audit.gd" 2>&1 | Out-String)
"--- c23 click audit ---" | Out-File $log -Append -Encoding utf8
($c23 -split "`n" | Where-Object { $_ -match "^FAIL|C23|SCRIPT ERROR" } | Select-Object -First 40) | Out-File $log -Append -Encoding utf8
$c24 = (& $godot --path $proj --resolution 1280x720 --script "res://tests/c24_levelup_flow.gd" 2>&1 | Out-String)
"--- c24 level-up ---" | Out-File $log -Append -Encoding utf8
($c24 -split "`n" | Where-Object { $_ -match "^FAIL|C24|SCRIPT ERROR" } | Select-Object -First 40) | Out-File $log -Append -Encoding utf8
"done $(Get-Date -Format s)" | Out-File $log -Append -Encoding utf8
