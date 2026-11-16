# Runs the headless unit tests. Usage: tools\run-tests.ps1 [name-filter]
# Locates Godot via $env:GODOT, then PATH, then ~\tools\godot.
param([string]$Filter = "")

$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot

$godot = $env:GODOT
if (-not $godot) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $godot = $cmd.Source }
}
if (-not $godot) {
    $candidate = Get-ChildItem "$env:USERPROFILE\tools\godot\Godot_v*_win64_console.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($candidate) { $godot = $candidate.FullName }
}
if (-not $godot) { throw "Godot not found. Set `$env:GODOT or add godot to PATH." }

# Build the script-class cache on a fresh checkout so class_name types resolve.
& $godot --headless --path $project --import --quit | Out-Null

$extra = @()
if ($Filter) { $extra = @("--", $Filter) }
& $godot --headless --path $project -s tests/run_tests.gd @extra
$unitExit = $LASTEXITCODE

# Integration: boots the real autoloads and drives the title screen.
& $godot --headless --path $project res://tests/integration/title_flow.tscn
$integrationExit = $LASTEXITCODE

if ($unitExit -ne 0 -or $integrationExit -ne 0) { exit 1 }
exit 0
