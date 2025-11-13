# ============================================
# Script: REW-EQ-CopyPaste-Assistant
# Description: Provides automated mouse & keyboard input to paste REW EQ settings into DSP software
# Author: Ivan Bakhmutov
# Date: 2025-11-12
# ============================================

$scriptDir = Split-Path -Parent $PSCommandPath
$DSPProfilesDir = Join-Path -Path $scriptDir -ChildPath "DSPProfiles"
$ModulesDir = Join-Path -Path $scriptDir -ChildPath "Modules"
$ResourcesDir = Join-Path -Path $scriptDir -ChildPath "Resources"
Remove-Module REW-EQ-CopyPaste-Assistant -ErrorAction SilentlyContinue
Remove-Module InputControls -ErrorAction SilentlyContinue
Import-Module "$ModulesDir\REW-EQ-CopyPaste-Assistant.psm1"
Import-Module "$ModulesDir\InputControls.psm1"

# Set the console output encoding to UTF-8 to properly display Cyrillic characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Write-Host "Script started" -ForegroundColor Yellow

# Load global config
$ConfigPath = Join-Path -Path $ResourcesDir -ChildPath "Config.json"
$GlobalConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$GlobalPerformActionHotkey = $GlobalConfig.GlobalPerformActionHotkey
$GlobalCancelActionHotkey = $GlobalConfig.GlobalCancelActionHotkey
$EffectivePerformActionHotkey = $GlobalPerformActionHotkey
$EffectiveCancelActionHotkey = $GlobalCancelActionHotkey

$selectedProfile = $null

# Load the XAML file
[xml]$xaml = (Get-Content -Path "$ResourcesDir\ChooseProfileGUI.xml" -Raw)

# Parse the XAML to create the GUI
Add-Type -AssemblyName PresentationFramework
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Set hotkey hint label
$hotkeyHintLabel = $window.FindName("HotkeyHint")
$hotkeyHintLabel.Content = "Hotkeys: Perform - $script:GlobalPerformActionHotkey, Cancel - $script:GlobalCancelActionHotkey"

# Populate the profiles list in the GUI
$profileListBox = $window.FindName("ProfileList")
$DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"
foreach ($profileFileName in $DSPProfilesList) {
    $profileListBox.Items.Add($profileFileName.Name.substring(0,$($profileFileName.Name.length -5))) | Out-Null
}

# Assign event handlers
$window.FindName("GitHub").Add_Click({ start-process "https://github.com/IvanBakhmutov/REW-EQ-CopyPaste-Assistant"})
$window.FindName("CloseBTN").Add_Click({
        $window.Close()
        exit
})

$window.FindName("OKBTN").Add_Click({
    $selectedProfileFileName = $window.FindName("ProfileList").SelectedItem
    if ($null -ne $selectedProfileFileName) {
        $script:selectedProfile = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedProfileFileName).json"
        Write-Host "Profile selected: $selectedProfile" -ForegroundColor Yellow
        $window.Close()
    }
})

$window.FindName("ProfileList").Add_SelectionChanged({
    $selectedItem = $window.FindName("ProfileList").SelectedItem
    if ($null -ne $selectedItem) {
        $profilePath = Join-Path -Path $DSPProfilesDir -ChildPath "$($selectedItem).json"
        $profileContent = Get-Content -Path $profilePath -Raw
        $window.FindName("ProfileText").Text = $profileContent
        $window.FindName("OKBTN").IsEnabled = $true
       # $window.FindName("EditBTN").IsEnabled = $true
        switch(($profileContent | convertfrom-json).HotkeyOrDelayPreference) {
            "Hotkey" {
                $hotkeyHintLabel.Visibility = "Visible"
            }
            "Delay" {
                $hotkeyHintLabel.Visibility = "Hidden"
            }
            Default {
                $hotkeyHintLabel.Visibility = "Hidden"
            }
        }

        if((($profileContent | convertfrom-json).ProfilePerformActionHotkey -ne $script:GlobalPerformActionHotkey) -and `
            ($null -ne ($profileContent | convertfrom-json).ProfilePerformActionHotkey)) {
                $script:EffectivePerformActionHotkey = ($profileContent | convertfrom-json).ProfilePerformActionHotkey
        } else {
            $script:EffectivePerformActionHotkey = $script:GlobalPerformActionHotkey
        }
        if((($profileContent | convertfrom-json).ProfileCancelActionHotkey -ne $script:GlobalCancelActionHotkey) -and `
            ($null -ne ($profileContent | convertfrom-json).ProfileCancelActionHotkey)) {
                $script:EffectiveCancelActionHotkey = ($profileContent | convertfrom-json).ProfileCancelActionHotkey
        } else {
            $script:EffectiveCancelActionHotkey = $script:GlobalCancelActionHotkey
        }

        $hotkeyHintLabel.Content = "Hotkeys: Perform - $script:EffectivePerformActionHotkey, Cancel - $script:EffectiveCancelActionHotkey"
        if(($script:GlobalPerformActionHotkey -ne $script:EffectivePerformActionHotkey) -or ($script:GlobalCancelActionHotkey -ne $script:EffectiveCancelActionHotkey)) {
            $hotkeyHintLabel.Content += " (override)"
        }
    } else {
        $window.FindName("ProfileText").Text = "Please select a profile"
        $window.FindName("OKBTN").IsEnabled = $false
       # $window.FindName("EditBTN").IsEnabled = $false
    }
})
# to be added doubleclick
#$window.FindName("ProfileList").Add_mouseDoubleClick({
#    $window.FindName("ProfileList").selectio
#}
# Show the GUI
$window.ShowDialog() | Out-Null

write-host "Perform Action Hotkey = $effectivePerformActionHotkey and Cancel Action Hotkey = $EffectiveCancelActionHotkey"

# Load selected profile
$DSPConfig = Get-Content $selectedProfile -Raw | ConvertFrom-Json
$ProcessName = $DSPConfig.processName
if($null -ne $DSPConfig.QDevider){
    $QDevider = $DSPConfig.QDevider
}
if($null -ne $DSPConfig.DecimalSeparator){
    $DecimalSeparator = $DSPConfig.DecimalSeparator
} else {
    $DecimalSeparator = $GlobalConfig.DecimalSeparator
}
if($null -ne $DSPConfig.QDecimals){
    $QDecimals = $DSPConfig.QDecimals
} else {
    $QDecimals = $GlobalConfig.QDecimals
}
if($null -ne $DSPConfig.GainDecimals){
    $GainDecimals = $DSPConfig.GainDecimals
} else {
    $GainDecimals = $GlobalConfig.GainDecimals
}
if($null -ne $DSPConfig.HotkeyOrDelayPreference) {
    $HotkeyOrDelayPreference = $DSPConfig.HotkeyOrDelayPreference
} else {
    $HotkeyOrDelayPreference = $GlobalConfig.HotkeyOrDelayPreference
}
if($null -ne $DSPConfig.TimeoutBeforePasteSecs) {
    $TimeoutBeforePasteSecs = $DSPConfig.TimeoutBeforePasteSecs
} else {
    $TimeoutBeforePasteSecs = $GlobalConfig.TimeoutBeforePasteSecs
}
$StartingPositionHint = $DSPConfig.StartingPositionHint

Write-Host "`nUsing DSP Profile: $($DSPConfig.Description)`nQ devider value: $($DSPConfig.QDevider)" -ForegroundColor Green

# find DSP Software processes with window
$processes = Get-Process | Where-Object {
    $_.ProcessName -like $ProcessName -and $_.ProcessName -ne "conhost" -and $_.MainWindowHandle -ne [IntPtr]::Zero
}

if ($processes.Count -eq 0) {
    Write-Host "No $ProcessName process found running. Please run $($DSPConfig.Description) before proceeding.`nHit ENTER to close PowerShell..." -ForegroundColor Yellow
    Read-host
    return
}
Write-Host "Found $($DSPConfig.Description) process: $($processes[0].ProcessName)" -ForegroundColor Green
Show-Notification -Title "REW EQ CopyPaste Assistant" -Message "Found $($DSPConfig.Description) process: $($processes[0].ProcessName)`nWaiting for EQ data from REW in clipboard" 
Write-Host "Hint: When finished with EQ close PowerShell window or hit ctrl-c and confirm exit" -ForegroundColor Yellow
Write-Host "Hotkey Or Delay Preference: $HotkeyOrDelayPreference" -ForegroundColor Cyan
Write-Host "Waiting for EQ data from REW in clipboard  " -ForegroundColor Yellow -NoNewline

$spinner = @('/', '-', '\', '|')
$spinnerindex = 0

do {
    $MouseX = $null
    $MouseY = $null
    $keyToSend = $null
    $UserHasConfirmedAction = $false
    $bufferHeader = $null

    # Check clipboard content
    $buffer = get-clipboard
    $bufferHeader = $($buffer -split "`n")[0]
    if ($bufferHeader -in "Configurable_PEQ", "Generic", "Extended") {
        [array]$bands = Read-EQText `
            -Text ($buffer | Out-String) `
            -QDevider $QDevider `
            -QDecimals $QDecimals `
            -GainDecimals $GainDecimals `
            -DecimalSeparator $DecimalSeparator
        Set-Clipboard "Data has been read. Waiting for user confirmation to paste..."

        Write-host "`nFound EQ data in clipboard ( $bufferHeader ) with $($bands.count) PK bands. Confirm in dialog to paste it to DSP" -ForegroundColor Yellow
 
        Show-DSPWindowToFront -processName $ProcessName | Out-Null
        if(($null -ne $DSPConfig.HotkeyOrDelayPreference) -and ($DSPConfig.HotkeyOrDelayPreference -eq "Hotkey")) {
            Show-Notification -Title "REW EQ CopyPaste Assistant - Confirm" `
               -Message "Found EQ data in clipboard ( $bufferHeader ) with $($bands.count) PK bands. $StartingPositionHint`nPress '$PerformActionHotkey' to proceed or '$CancelActionHotkey' to cancel."

            Write-Host "Waiting for user to press '$PerformActionHotkey' to proceed or '$CancelActionHotkey' to cancel. Timeout in $($GlobalConfig.HotkeyTimeoutSecs) seconds..." -ForegroundColor Yellow
            $hotkeyResult = $(Wait-HotkeyInput -TimeoutSecs $GlobalConfig.HotkeyTimeoutSecs -KeysToMonitor $($PerformActionHotkey,$CancelActionHotkey) )
            switch ($hotkeyResult) {
                "$EffectivePerformActionHotkey" {
                    $UserHasConfirmedAction = $true
                }
                "$EffectiveCancelActionHotkey" {
                    $UserHasConfirmedAction = $false
                }
            }
        } else {
            Show-Notification -Title "REW EQ CopyPaste Assistant - Confirm" `
               -Message "Found EQ data in clipboard ( $bufferHeader ) with $($bands.count) PK bands. Confirm in dialog to paste it to DSP"
            Write-Host "Waiting for user confirmation dialog to proceed with paste..." -ForegroundColor Yellow
            $UserHasConfirmedAction = Show-ConfirmationDialog -StartingPositionHint $StartingPositionHint
        }

        if ($UserHasConfirmedAction -eq $true) {
            Write-Host "Proceeding with pasting EQ settings..." -ForegroundColor Yellow


            # Check if mouse actions are defined in the profile
            $hasMouseAction = $DSPConfig.KeystrokeSequence | Where-Object {
               $_.PSObject.Properties.Name -match '^mouse'
            }

            if($null -ne $hasMouseAction) {
                Write-Host "Mouse actions detected in profile. Make sure the DSP window is visible and not covered by other windows." -ForegroundColor Yellow
                Show-Notification -Title "REW EQ CopyPaste Assistant - CopyPaste started" `
                     -Message "Make sure the DSP window is visible and not covered by other windows."
                $MouseX, $MouseY = Get-MousePosition
                Write-Host "Current mouse position: X=$MouseX, Y=$MouseY" -foregroundColor blue
            } else {
                Write-Host "No mouse actions detected in profile. Proceeding with keyboard input only." -ForegroundColor Yellow
                Show-Notification -Title "REW EQ CopyPaste Assistant - CopyPaste started" -Message "Keyboard input started." -Timeout 1000
            }

            if((($null -ne $DSPConfig.HotkeyOrDelayPreference) -and ($DSPConfig.HotkeyOrDelayPreference -ne "Hotkey")) `
            -or (($null -eq $DSPConfig.HotkeyOrDelayPreference))) {
                write-host "Waiting $($TimeoutBeforePasteSecs) seconds before auto-paste. $($DSPConfig.StartingPositionHint)" -ForegroundColor Yellow
                Start-Sleep -Seconds $TimeoutBeforePasteSecs
            }
            # Start pasting EQ bands with configured keystrokes and mouse actions
            foreach ($band in $bands) {
                foreach ($KeySet in $DSPConfig.KeystrokeSequence) {
                    switch($KeySet.PSObject.Properties.Name) {
                        "mouseChangePositionY" {
                            $MouseY += [int]$KeySet.mouseChangePositionY
                            Start-Sleep -Milliseconds $KeySet.delay_ms
                            Write-Host -ForegroundColor Blue "New MouseY: $MouseY"
                        }
                        "mouseChangePositionX" {
                            $MouseX += [int]$KeySet.mouseChangePositionX
                            Start-Sleep -Milliseconds $KeySet.delay_ms
                            Write-Host -ForegroundColor Blue "New MouseX: $MouseX"
                        }
                        "mouseClick" {
                            switch ($KeySet.mouseClick.ToLower()) {
                                "left" {
                                    Invoke-MouseClickLeftAt -X $MouseX -Y $MouseY
                                    Start-Sleep -Milliseconds $KeySet.delay_ms
                                    Write-Host -ForegroundColor Blue "Left click at X:$MouseX Y:$MouseY"
                                }
                                "right" {
                                    Invoke-MouseClickRightAt -X $MouseX -Y $MouseY
                                    Start-Sleep -Milliseconds $KeySet.delay_ms
                                    Write-Host -ForegroundColor Blue "Right click at X:$MouseX Y:$MouseY"
                                }
                            }
                        }
                        "MouseScrollUp" {
                            Invoke-MouseScrollUp -Amount $KeySet.MouseScrollUp
                            Start-Sleep -Milliseconds $KeySet.delay_ms
                            Write-Host -ForegroundColor Blue "Mouse scroll up by $($KeySet.MouseScrollUp)"
                        }
                        "Invoke-MouseScrollDown" {
                            Invoke-MouseScrollDown -Amount $KeySet.MouseScrollDown
                            Start-Sleep -Milliseconds $KeySet.delay_ms
                            Write-Host -ForegroundColor Blue "Mouse scroll down by $($KeySet.MouseScrollDown)"
                        }
                        "keys" {
                            $keyToSend = $KeySet.keys.Replace("FREQ", $band.freq).Replace("QVALUE", $band.Q).Replace("GAIN", $band.Gain)
                            Invoke-KeyStroke -Keys $keyToSend
                            Start-Sleep -Milliseconds $KeySet.delay_ms
                            Write-Host -ForegroundColor Blue "Sent keystrokes: $keyToSend"
                        }
                    }
                }
            }

            # Show transposed table of pasted bands
            Show-TransposedTable -bands $bands | Format-Table -AutoSize
            Write-Host "Finished paste. Waiting for new data in clipboard  " -ForegroundColor Yellow -NoNewline
            Show-Notification -Title "REW EQ CopyPaste Assistant - CopyPaste finished" -Message "Waiting for new data in clipboard"
        }
        else {
            Write-Host "Cancelled by user or timedout. Waiting for new data in clipboard  " -ForegroundColor Yellow -NoNewline
            Show-Notification -Title "REW EQ CopyPaste Assistant - CopyPaste canceled" -Message "Cancelled by user or timedout. Waiting for new data in clipboard"
            Set-Clipboard "Canceled"
        }

    }
    Write-Host -NoNewline ("`b" + $spinner[$spinnerindex])
    $spinnerindex = ($spinnerindex + 1) % $spinner.Length
    Start-Sleep -Seconds 1
} while (1)