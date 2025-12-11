# ============================================
# Module: REW-EQ-CopyPaste-Assistant
# Description: Main module for REW-EQ-CopyPaste-Assistant
# Author: Ivan Bakhmutov
# Date: 2025-11-25
# ============================================

# Parse copied EQ text data from clipboard and return an array of objects with Freq, Q, and Gain properties.
<#
.SYNOPSIS
   Parses EQ text data from the clipboard.
.DESCRIPTION
   This function processes text data containing EQ settings, extracts relevant information, and returns an array of objects with properties: Frequency, Q, and Gain.
.EXAMPLE
   $bands = Read-EQText -Text $clipboardText -QDivider 2.0
   This example parses the EQ data from the clipboard text with a Q Divider of 2.0.
.INPUTS
   [string] $Text - The EQ text data to parse.
   [double] $QDivider - The Divider value for Q.
.OUTPUTS
   [array] - An array of objects with Freq, Q, and Gain properties.
.NOTES
   Ensure the input text is in the expected format for proper parsing.
#>
function Read-EQText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][double]$QDivider,
        [Parameter(Mandatory = $true)][int]$FreqDecimals,
        [Parameter(Mandatory = $true)][int]$QDecimals,
        [Parameter(Mandatory = $true)][int]$GainDecimals,
        [Parameter(Mandatory = $true)][string]$DecimalSeparator
    )

    if (-not $Text) { return @() }

    $lines = $Text -split "`r?`n"
    $bands = $lines[1..$lines.count] | ConvertFrom-Csv -Delimiter "`t"

    $results = @()
    $bandNumber = 1
    $bands | where-Object { $_.Type -eq 'PK' } | ForEach-Object {
        if ($QDivider -ne 1) {
            # Adjust Q value based on QDivider and round to specified decimals
            $adjustedQ = [math]::round($([double]($_.Q -replace ",", ".") / $QDivider), $QDecimals)
        }
        else {
            $adjustedQ = [math]::round([double]($_.Q -replace ",", "."), $QDecimals)
        }

        # Round Frequency to specified decimals
        $adjustedFreq = [math]::round([double]($_.'Frequency(Hz)' -replace ",", "."), $FreqDecimals)

        # Round Gain to specified decimals
        $adjustedGain = [math]::round([double]($_.'Gain(dB)' -replace ",", "."), $GainDecimals)

        # Replace decimal separator if needed
        if ($DecimalSeparator -eq ",") {
            $adjustedFreq = $adjustedFreq.tostring() -replace "\.", ","
            $adjustedGain = $adjustedGain.tostring() -replace "\.", ","
            $adjustedQ = $adjustedQ.tostring() -replace "\.", ","
        }

        $results += [PSCustomObject]@{
            Freq       = [string]($adjustedFreq)
            Q          = [string]($adjustedQ)
            Gain       = [string]($adjustedGain)
            bandNumber = [string]($bandNumber)
        }
        $bandNumber++
    }

    if ($results.count -gt 0) {
        Write-Verbose -Message "Parsed $($results.count) PK bands from clipboard."
        return [array]$results
    }
    else {
        Write-Verbose -Message "No PK bands found in clipboard."
        return @()
    }
}
# debug start
# Read-EQText -text $(get-clipboard -raw) -QDivider 1 -QDecimals 1 -GainDecimals 1 -DecimalSeparator "." -FreqDecimals 1 | Format-Table -AutoSize
# debug end

# Show a confirmation dialog to the user and return their response as a boolean.
<#
.SYNOPSIS
   Displays a confirmation dialog for user input.
.DESCRIPTION
   This function creates a graphical confirmation dialog with "Yes" and "No" buttons. It returns the user's choice as a boolean value.
.EXAMPLE
   $UserInput = Show-ConfirmationDialog
   This example shows a confirmation dialog and stores the user's response in $UserInput.
.INPUTS
   None.
.OUTPUTS
   [bool] - True if the user clicks "Yes", False otherwise.
.NOTES
   The dialog is always displayed on top of other windows.
#>
function Show-ConfirmationDialog {
    param(
        [Parameter(Mandatory = $true)][string]$StartingPositionHint
    )

    # Set initial global confirmation state
    $global:confirmation = $false

    # Constants for Layout and Padding
    $ButtonWidth = 80
    $ButtonHeight = 25
    $ButtonSpacing = 20
    $PaddingX = 30  # Padding on the left/right of the widest element
    $PaddingY = 15  # Padding between label and buttons, and below the buttons
    $LabelMarginTop = 15
    $LabelMarginLeft = 15

    # Form and Label Text
    $Message = "Ready to paste EQ settings to DSP.`n$StartingPositionHint`n`nProceed?"

    # Create Controls

    # 1. Create the Form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "EQ Paste Confirmation"
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
    $form.TopMost = $true
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog

    # 2. Create the Label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Message
    $label.Location = New-Object System.Drawing.Point($LabelMarginLeft, $LabelMarginTop)
    $label.AutoSize = $true # Crucial for dynamic sizing
    $form.Controls.Add($label)

    # Initial Layout to Calculate Label Size
    # This ensures the label calculates its required width/height based on $Message
    $form.PerformLayout()

    # Dynamic Size Calculation and Button Placement

    # 1. Calculate the required client width
    $MinContentWidth = ($ButtonWidth * 2) + $ButtonSpacing + ($PaddingX * 2)
    $RequiredWidth = [Math]::Max($label.Width + ($LabelMarginLeft * 2), $MinContentWidth)

    # 2. Calculate the button starting X-position for centering
    $TotalButtonAreaWidth = ($ButtonWidth * 2) + $ButtonSpacing
    $StartButtonX = ($RequiredWidth - $TotalButtonAreaWidth) / 2

    # 3. Calculate the button Y-position (below the dynamically sized label)
    $ButtonY = $label.Bottom + $PaddingY

    # 4. Calculate the required client height
    $RequiredHeight = $label.Top + $label.Height + $PaddingY + $ButtonHeight + $PaddingY

    # Apply the calculated size to the form
    $form.ClientSize = New-Object System.Drawing.Size($RequiredWidth, $RequiredHeight)

    # 5. Create Yes button
    $yesButton = New-Object System.Windows.Forms.Button
    $yesButton.Text = "Yes"
    $yesButton.Size = New-Object System.Drawing.Size($ButtonWidth, $ButtonHeight)
    # Location X is the calculated center start point
    $yesButton.Location = New-Object System.Drawing.Point($StartButtonX, $ButtonY)
    $yesButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $yesButton.Add_Click({
            $global:confirmation = $true
            $form.Close()
        })
    $form.Controls.Add($yesButton)

    # 6. Calculate No button X-position robustly
    # No Button X = Yes Button Start X + Yes Button Width + Spacing
    $NoButtonX = $StartButtonX + $ButtonWidth + $ButtonSpacing

    # 7. Create No button
    $noButton = New-Object System.Windows.Forms.Button
    $noButton.Text = "No"
    $noButton.Size = New-Object System.Drawing.Size($ButtonWidth, $ButtonHeight)
    # Use the calculated pixel location, not control properties
    $noButton.Location = New-Object System.Drawing.Point($NoButtonX, $ButtonY)
    $noButton.DialogResult = [System.Windows.Forms.DialogResult]::No
    $noButton.Add_Click({
            $global:confirmation = $false
            $form.Close()
        })
    $form.Controls.Add($noButton)

    # Final Form Setup
    $form.AcceptButton = $yesButton
    $form.CancelButton = $noButton

    # Show the Form
    $form.ShowDialog() | Out-Null

    return $global:confirmation
}

# Bring the DSP software window to the front based on the provided process name.
<#
.SYNOPSIS
   Brings the DSP software window to the foreground.
.DESCRIPTION
   This function identifies the DSP software process by its name and attempts to bring its window to the foreground using various techniques.
.EXAMPLE
   Show-DSPWindowToFront -ProcessName "DSPSoftware_V*"
   This example brings the DSP software window with the specified process name to the foreground.
.INPUTS
   [string] $ProcessName - The name of the DSP software process. Wildcards are supported.
.OUTPUTS
   [bool] - True if the window was successfully brought to the foreground, False otherwise.
.NOTES
   Requires the DSP software to be running with a visible window.
#>
function Show-DSPWindowToFront {
    param(
        [string]$ProcessName
    )



    # find DSP software processes with window
    $processes = Get-Process | Where-Object {
        $_.ProcessName -like $ProcessName -and $_.ProcessName -ne "conhost" -and $_.MainWindowHandle -ne [IntPtr]::Zero
    }

    if ($processes.Count -eq 0) {
        Write-Host "No $ProcessName process found running. No action taken" -ForegroundColor Yellow
        return $false
    }

    $targetProcess = $processes[0]
    $handle = $targetProcess.MainWindowHandle

    # If minimized, restore first
    $SW_RESTORE = 9
    [void][NativeMethods]::ShowWindowAsync($handle, $SW_RESTORE)
    Start-Sleep -Milliseconds 200

    # Try simple SetForegroundWindow first
    if ([NativeMethods]::SetForegroundWindow($handle)) {
        Start-Sleep -Milliseconds 100
        return $true
    }

    # If SetForegroundWindow failed, try attaching thread input trick
    $dummy = 0
    $fgWindow = [NativeMethods]::GetForegroundWindow()
    $fgThread = [NativeMethods]::GetWindowThreadProcessId($fgWindow, [ref]$dummy)
    $curThread = [NativeMethods]::GetCurrentThreadId()
    if ($fgThread -ne 0 -and [NativeMethods]::AttachThreadInput($curThread, $fgThread, $true)) {
        try {
            [NativeMethods]::BringWindowToTop($handle) | Out-Null
            [NativeMethods]::SetForegroundWindow($handle) | Out-Null
        }
        finally {
            [NativeMethods]::AttachThreadInput($curThread, $fgThread, $false) | Out-Null
        }

        if ([NativeMethods]::SetForegroundWindow($handle)) {
            Start-Sleep -Milliseconds 100
            return $true
        }
    }

    # As a last resort, temporarily set topmost on the window then remove topmost
    [NativeMethods]::SetWindowPos($handle, [NativeMethods]::HWND_TOPMOST, 0, 0, 0, 0, [NativeMethods]::SWP_NOMOVE -bor [NativeMethods]::SWP_NOSIZE) | Out-Null
    Start-Sleep -Milliseconds 100
    [NativeMethods]::SetWindowPos($handle, [NativeMethods]::HWND_NOTOPMOST, 0, 0, 0, 0, [NativeMethods]::SWP_NOMOVE -bor [NativeMethods]::SWP_NOSIZE) | Out-Null

    # Final attempt to bring to front
    [NativeMethods]::BringWindowToTop($handle) | Out-Null
    [NativeMethods]::SetForegroundWindow($handle) | Out-Null
    Start-Sleep -Milliseconds 200

    return $true
}

# Show transposed table of EQ bands
<#
.SYNOPSIS
   Displays a transposed table of EQ bands.
.DESCRIPTION
   This function takes an array of EQ band objects and transposes the data for better readability in the console.
.EXAMPLE
Show-TransposedTable -Bands $bands | Format-Table -AutoSize
   This example transposes the EQ bands and formats the output as a table.
   Output will be similar to:
    Property   Band1   Band2   Band3   ...
    -------    -----   -----   -----   ...
    Freq       100     200     300     ...
    Q          1.0     1.5     2.0     ...
    Gain       3.0     -2.0    0.0     ...
.INPUTS
   [array] $Bands - An array of EQ band objects with properties Freq, Q, and Gain.
.OUTPUTS
   [array] - An array of transposed objects for display.

#>
function Show-TransposedTable {
    param(
        [Parameter(Mandatory = $true)][array]$Bands
    )

    $bandsTable = [ordered]@{}

    for ($i = 0; $i -lt $bands.Count; $i++) {
        $bandName = "Band$($i + 1)"
        $bandsTable[$bandName] = $bands[$i]
    }

    $transposed = @()

    foreach ($prop in "Freq", "Q", "Gain") {
        $row = [ordered]@{ Property = $prop }
        foreach ($band in $bandsTable.GetEnumerator()) {
            $row[$band.Key] = $band.Value.$prop
        }
        $transposed += [pscustomobject]$row
    }
    return $transposed
}

# Show a desktop notification with specified title and message.
<#
.SYNOPSIS
   Displays a desktop notification.
.DESCRIPTION
   This function creates a desktop notification with a specified title and message for a given timeout duration.
.EXAMPLE
   Show-Notification -Title "EQ Paste Assistant" -Message "Paste started" -Timeout 5000
   This example shows a notification with the title "EQ Paste Assistant" and the message "Paste started" for 5 seconds.
.INPUTS
   [string] $Title - The title of the notification.
   [string] $Message - The message body of the notification.
   [int] $Timeout - The duration in milliseconds for which the notification is displayed.  Default is 5000 ms.
.OUTPUTS
   None.
#>
<# function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [int]$Timeout = 3000
    )

    Start-Job -ScriptBlock {
        param($Title, $Message, $Timeout)
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipTitle = $Title
        $notify.BalloonTipText = $Message
        $notify.Visible = $true
        $notify.ShowBalloonTip($Timeout)
        Start-Sleep -Milliseconds $Timeout
        $notify.Dispose()
    } -ArgumentList $Title, $Message, $Timeout | Out-Null
} #>


<#
.SYNOPSIS
   Checks if the current script is running with administrative privileges.
.DESCRIPTION
   This function determines if the current PowerShell session has administrative rights. If not, it displays an error message prompting the user to run the script as an administrator.
.EXAMPLE
   $isAdmin = Get-RunningAsAdminFlag
   This example checks if the script is running with administrative privileges and stores the result in $isAdmin.
.INPUTS
   None.
.OUTPUTS
   [bool] - True if running as administrator, False otherwise.
#>
function Get-RunningAsAdminFlag {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    return $isAdmin
}

# Read and validate JSON file format
function Read-JSONFile {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    if (-not (Test-Path -Path $FilePath)) {
        throw "Read-JSONFile: File not found: $FilePath"
    }

    try {
        $raw = Get-Content -Path $FilePath -Raw -ErrorAction Stop
    }
    catch {
        throw "Read-JSONFile: Failed to read file '$FilePath'. $_"
    }

    try {
        $obj = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Read-JSONFile: Invalid JSON in '$FilePath'. $($_.Exception.Message)"
    }

    return $obj
}

Export-ModuleMember -Function `
    Read-EQText, `
    Show-ConfirmationDialog, `
    Show-DSPWindowToFront, `
    Show-TransposedTable, `
    Get-RunningAsAdminFlag, `
    Read-JSONFile
# Show-Notification