# ============================================
# Module: REW-EQ-CopyPaste-Assistant
# Description: Main module for REW-EQ-CopyPaste-Assistant
# Author: Ivan Bakhmutov
# Date: 2025-11-25
# ============================================

# Parse copied EQ text data from clipboard and return an array of objects with Freq, Q, Gain, Type and bandNumber properties.
<#
.SYNOPSIS
   Parses EQ text data from the clipboard.
.DESCRIPTION
   This function processes text data containing EQ settings, extracts relevant information, and returns an array of objects with properties: Frequency, Q, Gain, Type and bandNumber.
.EXAMPLE
   $bands = Read-EQText -Text $clipboardText -QDivider 2.0
   This example parses the EQ data from the clipboard text with a Q Divider of 2.0.
.INPUTS
   [string] $Text - The EQ text data to parse.
   [double] $QDivider - The Divider value for Q.
.OUTPUTS
   [array] - An array of objects with Freq, Q, Gain, Type and bandNumber properties.
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
    if ($lines.Count -lt 2) { return @() }

    $bands = $lines[1..($lines.Count - 1)] | ConvertFrom-Csv -Delimiter "`t" -ErrorAction SilentlyContinue
    if (-not $bands) { return @() }

    $validTypes = 'PK','HS','LS','HP','LP'
    $foundTypes = $bands | ForEach-Object { $_.Type } | Where-Object { $_ -in $validTypes } | Select-Object -Unique
    $alignment = $null
    if ($foundTypes -contains 'HP' -or $foundTypes -contains 'LP') {
        $alignment = Show-CrossoverTypeDialog
        if (-not $alignment) {
            Write-Verbose -Message 'Crossover selection cancelled. Using Butterworth fallback.'
            $alignment = 'Butterworth'
        }
    }

    $results = @()
    $bandNumber = 1
    foreach ($band in $bands) {
        if (-not ($band.Type -in $validTypes)) { continue }

        $type = $band.Type
        $gain = 0.0
        $freq = 0.0
        $qValue = $null

        try { $gain = [double]($band.'Gain(dB)' -replace ',', '.') } catch { }
        try { $freq = [double]($band.'Frequency(Hz)' -replace ',', '.') } catch { }

        $rawQ = $null
        if ($band.PSObject.Properties.Match('Q')) {
            $rawQ = $band.Q
        }

        switch ($type) {
            'PK' {
                if ($rawQ -ne $null -and $rawQ -ne '') {
                    $qValue = [double]($rawQ -replace ',', '.')
                }
                if ($QDivider -ne 1 -and $qValue -ne $null) {
                    $qValue = $qValue / $QDivider
                }
            }
            'HS' {
                $qValue = Get-ComputedQForHSLS -Gain $gain
            }
            'LS' {
                $qValue = Get-ComputedQForHSLS -Gain $gain
            }
            'HP' {
                if ($alignment) {
                    $qValue = Get-CrossoverQ -Alignment $alignment
                }
                else {
                    $qValue = 0.7071
                }
            }
            'LP' {
                if ($alignment) {
                    $qValue = Get-CrossoverQ -Alignment $alignment
                }
                else {
                    $qValue = 0.7071
                }
            }
        }

        if ($qValue -eq $null -or [double]::IsNaN($qValue) -or [double]::IsInfinity($qValue)) {
            $qValue = 0.7071
        }

        $adjustedQ = [math]::round($qValue, $QDecimals)
        $adjustedFreq = [math]::round($freq, $FreqDecimals)
        $adjustedGain = [math]::round($gain, $GainDecimals)

        if ($DecimalSeparator -eq ',') {
            $adjustedFreq = $adjustedFreq.ToString() -replace '\.', ','
            $adjustedGain = $adjustedGain.ToString() -replace '\.', ','
            $adjustedQ = $adjustedQ.ToString() -replace '\.', ','
        }

        $results += [PSCustomObject]@{
            Freq       = [string]($adjustedFreq)
            Q          = [string]($adjustedQ)
            Gain       = [string]($adjustedGain)
            bandNumber = [string]($bandNumber)
            Type       = $type
        }
        $bandNumber++
    }

    if ($results.Count -gt 0) {
        Write-Verbose -Message "Parsed $($results.Count) bands from clipboard: $($foundTypes -join ', ')"
        return [array]$results
    }

    Write-Verbose -Message 'No supported EQ bands found in clipboard.'
    return @()
}

function Show-CrossoverTypeDialog {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Choose Crossover Alignment'
    $form.ClientSize = [System.Drawing.Size]::new(360, 150)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true

    $label = New-Object System.Windows.Forms.Label
    $label.Text = 'Select the crossover alignment for HP/LP bands:'
    $label.AutoSize = $true
    $label.Location = [System.Drawing.Point]::new(12, 15)
    $form.Controls.Add($label)

    $combo = New-Object System.Windows.Forms.ComboBox
    $combo.DropDownStyle = 'DropDownList'
    $combo.Items.AddRange(@('Butterworth','Linkwitz','Bessel'))
    $combo.SelectedIndex = 0
    $combo.Location = [System.Drawing.Point]::new(12, 45)
    $combo.Width = 330
    $form.Controls.Add($combo)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'OK'
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $okButton.Location = [System.Drawing.Point]::new(180, 90)
    $form.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $cancelButton.Location = [System.Drawing.Point]::new(270, 90)
    $form.Controls.Add($cancelButton)

    $form.AcceptButton = $okButton
    $form.CancelButton = $cancelButton

    $result = $form.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $combo.SelectedItem
    }

    return $null
}

function Get-CrossoverQ {
    param(
        [Parameter(Mandatory = $true)][string]$Alignment
    )

    switch ($Alignment) {
        'Bessel'     { return 0.5774 }
        'Linkwitz'   { return 0.5000 }
        'Butterworth'{ return 0.7071 }
        default      { return 0.7071 }
    }
}

function Get-ComputedQForHSLS {
    param(
        [Parameter(Mandatory = $true)][double]$Gain
    )

    $S = 0.9
    $A = [math]::Pow(10.0, ($Gain / 40.0))
    $term1 = $A + (1.0 / $A)
    $term2 = (1.0 / $S) - 1.0
    $denominator = [math]::Sqrt(($term1 * $term2) + 2.0)

    if ($denominator -eq 0 -or [double]::IsNaN($denominator) -or [double]::IsInfinity($denominator)) {
        return 0.7071
    }

    $q = 1.0 / $denominator
    if ([double]::IsNaN($q) -or [double]::IsInfinity($q) -or $q -le 0) {
        return 0.7071
    }

    if ($q -lt 0.30) {
        $q = 0.30
    }

    return [math]::Round($q, 4)
}

# debug start
# Read-EQText -text $(get-clipboard -raw) -QDivider 1 -QDecimals 1 -GainDecimals 1 -DecimalSeparator '.' -FreqDecimals 1 | Format-Table -AutoSize
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
        [Parameter(Mandatory = $true)][string]$StartingPositionHint,
        [string]$ResourcesDir
    )

    if (-not $ResourcesDir) {
        $moduleRoot = Split-Path -Parent $PSScriptRoot
        $ResourcesDir = Join-Path -Path $moduleRoot -ChildPath "Resources"
    }

    $xamlPath = Join-Path -Path $ResourcesDir -ChildPath "Confirmation-GUI.xml"
    if (-not (Test-Path $xamlPath)) {
        throw "Confirmation XAML not found: $xamlPath"
    }

    $fs = [System.IO.File]::OpenRead($xamlPath)
    try {
        $context = New-Object System.Windows.Markup.ParserContext
        $context.BaseUri = [Uri]$xamlPath
        $window = [Windows.Markup.XamlReader]::Load($fs, $context)
    }
    finally {
        $fs.Close()
    }

    $window.Topmost = $true
    try {
        $iconPath = Join-Path -Path $ResourcesDir -ChildPath "Icons\Title.png"
        if (Test-Path $iconPath) { $window.Icon = $iconPath }
    }
    catch { }

    $message = "Ready to paste EQ settings to DSP.`n$StartingPositionHint`n`nProceed?"

    try {
        $msg = $window.FindName("MessageTextBlock")
        if ($null -ne $msg) { $msg.Text = $message }

        $yes = $window.FindName("YesBTN")
        $no  = $window.FindName("NoBTN")

        # Make window draggable by its main grid (match popup behavior)
        try {
            $mainGrid = $window.FindName("MainGrid")
            if ($null -ne $mainGrid) {
                $mainGrid.Add_MouseDown({ if ($_.LeftButton -eq 'Pressed') { $window.DragMove() } })
            }
        }
        catch { }

        $result = $false

        if ($null -ne $yes) {
            $yes.Add_Click({ $window.DialogResult = $true; $window.Close() })
        }
        if ($null -ne $no) {
            $no.Add_Click({ $window.DialogResult = $false; $window.Close() })
        }

        $dialogResult = $window.ShowDialog()
        if ($dialogResult -eq $true) { return $true }
        return $false
    }
    catch {
        Write-Host "Confirmation dialog failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
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