# Set the console output encoding to UTF-8 to properly display Cyrillic characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8


$scriptDir = Split-Path -Parent $PSCommandPath
$DSPProfilesDir = Join-Path -Path $scriptDir -ChildPath "DSPProfiles"
$DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"


if ($DSPProfilesList.Count -eq 0) {
    Write-Host "No JSON profiles found in $profilesPath"
    exit
}

# Display numbered list
Write-Host "`nAvailable DSP Profiles:`n"
for ($i = 0; $i -lt $DSPProfilesList.Count; $i++) {
    Write-Host "[$($i+1)] $($DSPProfilesList[$i].Name)"
}

# Ask user to choose
$choice = Read-Host "`nEnter the number of the profile you want to use"

# Validate and get selected file
if ($choice -match '^\d+$' -and $choice -ge 1 -and $choice -le $DSPProfilesList.Count) {
    $selectedProfile = $DSPProfilesList[$choice - 1].FullName
    Write-Host "`nYou selected: $selectedProfile"
} else {
    Read-Host "Invalid selection. Hit ENTER to close powershell..."
    exit
}

$DSPConfig = Get-Content $selectedProfile -Raw | ConvertFrom-Json

# DSP Software window process name
$ProcessName = $DSPConfig.processName

# Q divider
$QDevider = $DSPConfig.QDevider

Write-Host "`nUsing DSP Profile: $($DSPConfig.Description)`nQ devider value: $($DSPConfig.QDevider)" -ForegroundColor Green

#    Parses Configurable PEQ text data from clipboard and returns an array of objects with Freq, Q, and Gain properties.
function Parse-ConfigurablePEQText {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [Parameter(Mandatory=$true)][double]$QDevider,
        [Parameter(Mandatory=$true)][int]$testOrNot
    )

    if (-not $Text) { return @() }

    $lines = $Text -split "`r?`n"
    $firstNonEmpty = ($lines | Where-Object { $_.Trim() -ne "" } | Select-Object -First 1)
    if ($firstNonEmpty.Trim() -ne 'Configurable_PEQ') { return @() }
   
    $bands = $lines[1..$lines.count] | ConvertFrom-Csv -Delimiter "`t"

    $results = @()

    $bands | where-Object {$_.Type -eq 'PK'} | ForEach-Object {
        $results += [PSCustomObject]@{
            Freq = [double]$_.'Frequency(Hz)'
            Q    = [math]::round($([double]($_.Q -replace ",",".") / $QDevider),1)
            Gain = ([double]($_.'Gain(dB)' -replace ",",".")) * $testOrNot
        }
    }
    
    if ($results.count -gt 0) {
        Write-Verbose -Message "Parsed $($results.count) PEQ bands from clipboard."
        return [array]$results
    }
    else { 
        return @() 
    }
}

function Show-ConfirmationDialog {
    Add-Type -AssemblyName System.Windows.Forms

    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "EQ Paste Confirmation"
    $form.Size = New-Object System.Drawing.Size(320,150)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true  # Make it stay on top

    # Create a label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Ready to paste EQ settings to DSP. Proceed?"
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(40,20)
    $form.Controls.Add($label)

    # Create Yes button
    $yesButton = New-Object System.Windows.Forms.Button
    $yesButton.Text = "Yes"
    $yesButton.Location = New-Object System.Drawing.Point(70,70)
    $yesButton.Add_Click({
        $global:confirmation = $true
        $form.Close()
    })
    $form.Controls.Add($yesButton)

    # Create No button
    $noButton = New-Object System.Windows.Forms.Button
    $noButton.Text = "No"
    $noButton.Location = New-Object System.Drawing.Point(170,70)
    $noButton.Add_Click({
        $global:confirmation = $false
        $form.Close()
    })
    $form.Controls.Add($noButton)

    # Show the form
    $form.ShowDialog() | Out-Null

    if ($confirmation) {
        Write-Host "Proceeding with pasting EQ settings..." -ForegroundColor Yellow
    } else {
        Write-Host "Cancelled by user. Waiting for new data in clipboard" -ForegroundColor Yellow
    }
    return $confirmation
}

function Show-TestOrNotDialog {
    Add-Type -AssemblyName System.Windows.Forms

    # Create the form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Flip bands Q?"
    $form.Size = New-Object System.Drawing.Size(340,170)
    $form.StartPosition = "CenterScreen"
    $form.TopMost = $true  # Make it stay on top

    # Create a label
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Flip Q values to compare visually with REW?`nYes - Flipped Q (Inverted graph)`nNo - Normal Q"
    $label.AutoSize = $true
    $label.Location = New-Object System.Drawing.Point(40,20)
    $form.Controls.Add($label)

    # Create Yes button
    $yesButton = New-Object System.Windows.Forms.Button
    $yesButton.Text = "Yes"
    $yesButton.Location = New-Object System.Drawing.Point(70,90)
    $yesButton.Add_Click({
        $global:confirmation = -1
        $form.Close()
    })
    $form.Controls.Add($yesButton)

    # Create No button
    $noButton = New-Object System.Windows.Forms.Button
    $noButton.Text = "No"
    $noButton.Location = New-Object System.Drawing.Point(170,90)
    $noButton.Add_Click({
        $global:confirmation = 1
        $form.Close()
    })
    $form.Controls.Add($noButton)

    # Show the form
    $form.ShowDialog() | Out-Null

    if ($confirmation -eq -1) {
        Write-Host "Testing mode: Q values multiplied by -1 (flipped)" -ForegroundColor Yellow
    } else {
        Write-Host "Normal mode: Q value will be pasted as they are" -ForegroundColor Yellow
    }
    return $confirmation
}
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
        } finally {
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

Add-Type -AssemblyName System.Windows.Forms
Write-Host "Script started" -ForegroundColor Yellow

# Gain multiplier to flip graph and compare with REW
# (Inverted gain value -1, normal is 1)
$testOrNot = Show-TestOrNotDialog

# find DSP Software processes with window
$processes = Get-Process | Where-Object {
    $_.ProcessName -like $ProcessName -and $_.ProcessName -ne "conhost" -and $_.MainWindowHandle -ne [IntPtr]::Zero
}

if ($processes.Count -eq 0) {
    Write-Host "No $ProcessName process found running. Please run $($DSPConfig.Description) before proceeding.`nHit ENTER to close powershell..." -ForegroundColor Yellow
    Read-host
    return
} 
Write-Host "Found $($DSPConfig.Description) process: $($processes[0].ProcessName)" -ForegroundColor Green
Write-Host "Waiting for EQ data from REW in clipboard" -ForegroundColor Yellow

do {

    $buffer = get-clipboard -TextFormatType UnicodeText
    if($($buffer -split "`n")[0] -eq "Configurable_PEQ"){
        Write-host "Found EQ in clipboard. Confirm in dialog to paste it to DSP" -ForegroundColor Yellow
        $bands = Parse-ConfigurablePEQText  -Text ($buffer | Out-String) -QDevider $QDevider -testOrNot $testOrNot
        $UserInput = Show-ConfirmationDialog
        if($UserInput -eq $true){
            Set-Clipboard "Processed"
            Show-DSPWindowToFront -processName $ProcessName | Out-Null
            
            write-host "Waiting $($DSPConfig.TimeoutBeforePasteSecs) seconds before auto-paste. Please select 1 band Freq box"
            Start-Sleep -Seconds $DSPConfig.TimeoutBeforePasteSecs
            [System.Windows.Forms.SendKeys]::SendWait('^a')
            foreach($band in $bands){
                foreach($KeySet in $DSPConfig.KeystrokeSequence){
                    $keyToSend = $KeySet.keys.Replace("FREQ",$band.freq).Replace("QVALUE",$band.Q).Replace("GAIN",$band.Gain)
                    [System.Windows.Forms.SendKeys]::SendWait($keyToSend)
                    Start-Sleep -Milliseconds $KeySet.delay_ms
                }
            }
            # Prepare transposed table for display
            $bands = $bands | Sort-Object {[double]$_.Freq}

            $bandsTable = [ordered]@{}
            
            for ($i = 0; $i -lt $bands.Count; $i++) {
                $bandName = "Band$($i + 1)"
                $bandsTable[$bandName] = $bands[$i]
            }
            
            $transposed = @()
            
            foreach ($prop in "Freq","Q","Gain") {
                $row = [ordered]@{ Property = $prop }
                foreach ($band in $bandsTable.GetEnumerator()) {
                    $row[$band.Key] = $band.Value.$prop
                }
                $transposed += [pscustomobject]$row
            }
            
            # Display the transposed table
            Write-Host "`nPasted EQ Bands:" -ForegroundColor Green
            $transposed | Format-Table -AutoSize 
            Write-Host "Finished paste. Waiting for new data in clipboard" -ForegroundColor Green
        } else {
            Set-Clipboard "Canceled"
        }
        Start-Sleep -Seconds 2
    }

} while (1)