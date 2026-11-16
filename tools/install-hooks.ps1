# Points git at the tracked hooks in tools/hooks so every clone gets the same
# local test gate. Safe to run more than once. Usage: tools\install-hooks.ps1
$ErrorActionPreference = "Stop"
$project = Split-Path -Parent $PSScriptRoot
git -C $project config core.hooksPath tools/hooks
Write-Host "Hooks installed: core.hooksPath = tools/hooks (pre-push runs the test suite)."
