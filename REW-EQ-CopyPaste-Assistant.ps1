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

#region Load Modules
# Clear previously loaded modules
Remove-Module Assistant-GUI -ErrorAction SilentlyContinue -Force
Remove-Module Input-Controls -ErrorAction SilentlyContinue -Force
Remove-Module Assistant-Functions -ErrorAction SilentlyContinue -Force
Remove-Module Import-Types -ErrorAction SilentlyContinue -Force
# Load modules
Import-Module "$ModulesDir\Assistant-Functions.psm1"
Import-Module "$ModulesDir\Input-Controls.psm1"
Import-Module "$ModulesDir\Assistant-GUI.psm1"
Import-Module "$ModulesDir\Import-Types.psm1"
Import-Types
#Endregion

# Set the console output encoding to UTF-8 to properly display Cyrillic characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "REW EQ CopyPaste Assistant started" -ForegroundColor Yellow
$hwnd = [Win]::GetConsoleWindow()
[Win]::ShowWindow($hwnd, 2) | Out-Null  # 2 = SW_MINIMIZE

# Load global config
$ConfigPath = Join-Path -Path $ResourcesDir -ChildPath "Config.json"
$GlobalConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$EffectivePerformActionHotkey = $null
$EffectiveCancelActionHotkey = $null

#Region Check updates
try {
    # Set a timeout for the request
    $webRequestOptions = @{
        Uri         = "https://raw.githubusercontent.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant/refs/heads/main/Resources/version"
        Method      = "Get"
        TimeoutSec  = 3
        ErrorAction = "Stop"
    }
    $LatestVersion = Invoke-RestMethod @webRequestOptions

    # Validate the version format (e.g., "1.0.0")
    if ($LatestVersion -notmatch "^\d+\.\d+\.\d+$") {
        throw "Invalid version format retrieved: $LatestVersion"
    }
}
catch {
    # Log the error and set a default value
    Write-Host "Failed to retrieve the latest version number: $($_.Exception.Message)" -ForegroundColor Red
    $LatestVersion = "Unknown"
}

if ($LatestVersion -ne "Unknown") {
    try {
        # Read the version from the local file
        $localVersionPath = Join-Path -Path $ResourcesDir -ChildPath "version"
        if (Test-Path -Path $localVersionPath) {
            $LocalVersion = Get-Content -Path $localVersionPath -Raw -Encoding UTF8
            if ($LocalVersion -notmatch "^\d+\.\d+\.\d+$") {
                throw "Invalid version format in local file: $LocalVersion"
            }

            # Compare the local version with the latest version
            if ($LocalVersion -lt $LatestVersion) {
                Write-Host "A newer version ($LatestVersion) is available." -ForegroundColor Yellow
                $AssistantVersion = "Version $LocalVersion (update available)"
            }
            elseif ($LocalVersion -gt $LatestVersion) {
                $AssistantVersion = "Version $LocalVersion (Future release)"
                Write-Host "Tool version ($LocalVersion) is ahead of the latest update online ($LatestVersion)." -ForegroundColor DarkRed
            }
            else {
                $AssistantVersion = "Version $LocalVersion (Latest)"
                Write-Host "Tool version is up-to-date." -ForegroundColor Cyan
            }
        }
        else {
            Write-Host "Tool version file not found." -ForegroundColor Red
        }
    }
    catch {
        Write-Host "Error checking updates: $($_.Exception.Message)" -ForegroundColor Red
    }
}
else {
    Write-Host "Skipping version comparison due to retrieval error." -ForegroundColor Red
    $AssistantVersion = "Version (n/a)"
}
#Endregion

do {
    $selectedProfile = $null

    $ProfileSelectionResult = Show-SelectProfileGui `
        -ResourcesDir $ResourcesDir `
        -GlobalPerformActionHotkey $GlobalConfig.GlobalPerformActionHotkey `
        -GlobalCancelActionHotkey $GlobalConfig.GlobalCancelActionHotkey `
        -DSPProfilesDir $DSPProfilesDir `
        -ModulesDir $ModulesDir `
        -LastSelectedProfile $GlobalConfig.LastSelectedProfile `
        -VersionLabelText $AssistantVersion

    if ($ProfileSelectionResult.Action -eq "Cancel" -or $null -eq $ProfileSelectionResult.SelectedProfile) {
        Write-Host "Finished. Exiting..." -ForegroundColor Blue
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

    $PopupResult = Show-PopupGUI -ResourcesDir $ResourcesDir -DSPConfig $DSPConfig -GlobalConfig $GlobalConfig
} while ($PopupResult -eq "SelectProfile")
Write-Host "`nFinished. Exiting..." -ForegroundColor Blue