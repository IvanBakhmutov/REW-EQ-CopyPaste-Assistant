# ============================================
# Script: REW-EQ-CopyPaste-Assistant
# Description: Provides automated mouse & keyboard input to paste REW EQ settings into DSP software
# Author: Ivan Bakhmutov
# Date: 2025-11-25
# ============================================

$scriptDir = Split-Path -Parent $PSCommandPath
$DSPProfilesDir = Join-Path -Path $scriptDir -ChildPath "DSPProfiles"
$ModulesDir = Join-Path -Path $scriptDir -ChildPath "Modules"
$ResourcesDir = Join-Path -Path $scriptDir -ChildPath "Resources"
Remove-Module REW-EQ-CopyPaste-Assistant -ErrorAction SilentlyContinue -Force
Remove-Module InputControls -ErrorAction SilentlyContinue -Force
Remove-Module AssistantGUI -ErrorAction SilentlyContinue -Force
Import-Module "$ModulesDir\REW-EQ-CopyPaste-Assistant.psm1"
Import-Module "$ModulesDir\InputControls.psm1"
Import-Module "$ModulesDir\AssistantGUI.psm1"

# Set the console output encoding to UTF-8 to properly display Cyrillic characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "Script started" -ForegroundColor Yellow

#Region Minimize parent cmd.exe window
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

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
} else {
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

<#if ($null -ne $DSPConfig.AdminRightsRequired) {
    if ($DSPConfig.AdminRightsRequired -eq "true") {
        if (Get-RunningAsAdminFlag) {
            Write-Host "Running with administrative privileges as required by the DSP profile." -ForegroundColor Yellow
        }
        else {
            Write-Host "This DSP profile requires administrative privileges. Please run the script as an administrator." -ForegroundColor Red
            start-sleep -Seconds 3
            exit
        }
    }
}
else {
    Write-Host "No AdminRightsRequired flag found in profile. Proceeding without admin rights." -ForegroundColor Yellow
} #>
