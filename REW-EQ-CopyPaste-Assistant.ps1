# ============================================
# Script: REW-EQ-CopyPaste-Assistant.ps1
# Description: Provides automated mouse & keyboard input to paste REW EQ settings into DSP software
# Author: Ivan Bakhmutov
# Date: 2025-12-07
# ============================================

$scriptDir = Split-Path -Parent $PSCommandPath
$DSPProfilesDir = Join-Path -Path $scriptDir -ChildPath "DSPProfiles"
$ModulesDir = Join-Path -Path $scriptDir -ChildPath "Modules"
$ResourcesDir = Join-Path -Path $scriptDir -ChildPath "Resources"
# Clear previously loaded modules
Remove-Module Assistant-GUI -ErrorAction SilentlyContinue -Force
Remove-Module Input-Controls -ErrorAction SilentlyContinue -Force
Remove-Module Assistant-Functions -ErrorAction SilentlyContinue -Force
Remove-Module Import-Types -ErrorAction SilentlyContinue -Force
#region Load Modules
Import-Module "$ModulesDir\Assistant-Functions.psm1"
Import-Module "$ModulesDir\Input-Controls.psm1"
Import-Module "$ModulesDir\Assistant-GUI.psm1"
Import-Module "$ModulesDir\Import-Types.psm1"
Import-Types

# Set the console output encoding to UTF-8 to properly display Cyrillic characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "REW EQ CopyPaste Assistant started" -ForegroundColor Yellow

$hwnd = [Win]::GetConsoleWindow()
[Win]::ShowWindow($hwnd, 2) | Out-Null  # 2 = SW_MINIMIZE
#Endregion

# Load global config
$ConfigPath = Join-Path -Path $ResourcesDir -ChildPath "Config.json"
$GlobalConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$EffectivePerformActionHotkey = $null
$EffectiveCancelActionHotkey = $null

$Version = Join-Path -Path $ResourcesDir -ChildPath "version"
try {
    $AssistantVersion = Get-Content $Version -Raw -ErrorAction Stop
}
catch {
    $AssistantVersion = "n/a"
}
$selectedProfile = $null

$ProfileSelectionResult = Show-SelectProfileGui `
    -ResourcesDir $ResourcesDir `
    -GlobalPerformActionHotkey $GlobalConfig.GlobalPerformActionHotkey `
    -GlobalCancelActionHotkey $GlobalConfig.GlobalCancelActionHotkey `
    -DSPProfilesDir $DSPProfilesDir `
    -ModulesDir $ModulesDir `
    -LastSelectedProfile $GlobalConfig.LastSelectedProfile `
    -AssistantVersion $AssistantVersion


if ($ProfileSelectionResult.Action -eq "Cancel" -or $null -eq $ProfileSelectionResult.SelectedProfile) {
    Write-Host "No profile selected. Exiting script." -ForegroundColor Blue
    exit
}
elseif ( $ProfileSelectionResult.Action -eq "Open" -and $null -ne $ProfileSelectionResult.SelectedProfile) {
    $selectedProfile = $ProfileSelectionResult.SelectedProfile
    $EffectivePerformActionHotkey = $ProfileSelectionResult.EffectivePerformActionHotkey
    $EffectiveCancelActionHotkey = $ProfileSelectionResult.EffectiveCancelActionHotkey
}
else {
    Write-Host "Unexpected action from profile selection GUI. Exiting script." -ForegroundColor Red
    exit
}

write-host "Perform Action Hotkey = $effectivePerformActionHotkey and Cancel Action Hotkey = $EffectiveCancelActionHotkey"

# Save last selected profile to config
if (-not ($GlobalConfig.PSObject.Properties.Name -contains "LastSelectedProfile")) {
    $GlobalConfig | Add-Member -MemberType NoteProperty -Name "LastSelectedProfile" `
        -Value $(Get-Item -path $selectedProfile | Select-Object -ExpandProperty BaseName)
}
else {
    $GlobalConfig.LastSelectedProfile = $(Get-Item -path $selectedProfile | Select-Object -ExpandProperty BaseName)
}

try {
    $GlobalConfig | ConvertTo-Json -Depth 10 | Set-Content $ConfigPath -ErrorAction Stop | Out-Null
}
catch {
    Write-Host "Failed to save global config. Continuing without saving." -ForegroundColor Red
}

# Load selected profile
$DSPConfig = Get-Content $selectedProfile -Raw | ConvertFrom-Json

Show-PopupGUI -ResourcesDir $ResourcesDir -DSPConfig $DSPConfig -GlobalConfig $GlobalConfig
