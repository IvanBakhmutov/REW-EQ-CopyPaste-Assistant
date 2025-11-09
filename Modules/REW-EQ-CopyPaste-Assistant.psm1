# ============================================
# Module: REW-EQ-CopyPaste-Assistant
# Description: Main module for REW-EQ-CopyPaste-Assistant
# Author: Ivan Bakhmutov
# Date: 2024-06-10
# ============================================

# Parse copied EQ text data from clipboard and return an array of objects with Freq, Q, and Gain properties.
<#
.SYNOPSIS
   Parses EQ text data from the clipboard.
.DESCRIPTION
   This function processes text data containing EQ settings, extracts relevant information, and returns an array of objects with properties: Frequency, Q, and Gain.
.EXAMPLE
   $bands = Read-EQText -Text $clipboardText -QDevider 2.0
   This example parses the EQ data from the clipboard text with a Q divider of 2.0.
.INPUTS
   [string] $Text - The EQ text data to parse.
   [double] $QDevider - The divider value for Q.
.OUTPUTS
   [array] - An array of objects with Freq, Q, and Gain properties.
.NOTES
   Ensure the input text is in the expected format for proper parsing.
#>
function Read-EQText {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][double]$QDevider,
        [Parameter(Mandatory = $true)][int]$QDecimals,
        [Parameter(Mandatory = $true)][int]$GainDecimals,
        [Parameter(Mandatory = $true)][string]$Delimiter
    )

    if (-not $Text) { return @() }

    $lines = $Text -split "`r?`n"

    $bands = $lines[1..$lines.count] | ConvertFrom-Csv -Delimiter "`t"

    $results = @()

    $bands | where-Object { $_.Type -eq 'PK' } | ForEach-Object {

        if($QDevider -ne 1){
            # Adjust Q value based on QDevider and round to specified decimals
            $adjustedQ = ([math]::round($([double]($_.Q -replace ",", ".") / $QDevider), $QDecimals)).toString()
        } else {
            $adjustedQ = ([math]::round([double]($_.Q -replace ",", "."), $QDecimals)).toString()
        }

        # Round Gain to specified decimals
        $adjustedGain = ([math]::round([double]($_.'Gain(dB)' -replace ",", "."), $GainDecimals)).toString()

        # Replace decimal separator if needed
        if($Delimiter -eq ","){
            $adjustedGain = $adjustedGain -replace "\.", ","
            $adjustedQ = $adjustedQ -replace "\.", ","
        }

        $results += [PSCustomObject]@{
            Freq = [string]($_.'Frequency(Hz)')
            Q    = [string]($adjustedQ)
            Gain = [string]($adjustedGain)
        }
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
    Add-Type -AssemblyName System.Windows.Forms

    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "EQ Paste Confirmation"
    $form.Size = New-Object System.Drawing.Size(320, 150)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true  # Make it stay on top

    # Create a label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Ready to paste EQ settings to DSP.`n$StartingPositionHint`nProceed?"
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(40, 20)
    $form.Controls.Add($label)

    # Create Yes button
    $yesButton = New-Object System.Windows.Forms.Button
    $yesButton.Text = "Yes"
    $yesButton.Location = New-Object System.Drawing.Point(70, 70)
    $yesButton.Add_Click({
            $global:confirmation = $true
            $form.Close()
        })
    $form.Controls.Add($yesButton)

    # Create No button
    $noButton = New-Object System.Windows.Forms.Button
    $noButton.Text = "No"
    $noButton.Location = New-Object System.Drawing.Point(170, 70)
    $noButton.Add_Click({
            $global:confirmation = $false
            $form.Close()
        })
    $form.Controls.Add($noButton)

    # Show the form
    $form.ShowDialog() | Out-Null

    return $confirmation
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

    Add-Type -AssemblyName System.Windows.Forms

    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class NativeMethods {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    public static readonly IntPtr HWND_TOP = new IntPtr(0);
    public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
    public static readonly IntPtr HWND_NOTOPMOST = new IntPtr(-2);
    public const uint SWP_NOMOVE = 0x0002;
    public const uint SWP_NOSIZE = 0x0001;
}
"@ -ErrorAction Stop

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

Export-ModuleMember -Function `
    Read-EQText, `
    Show-ConfirmationDialog, `
    Show-DSPWindowToFront