$scriptDir = Split-Path -Parent $PSCommandPath
$DSPProfilesDir = Join-Path -Path $scriptDir -ChildPath "DSPProfiles"
$ModulesDir = Join-Path -Path $scriptDir -ChildPath "Modules"
Remove-Module REW-EQ-CopyPaste-Assistant -ErrorAction SilentlyContinue
Remove-Module InputControls -ErrorAction SilentlyContinue
Import-Module "$ModulesDir\REW-EQ-CopyPaste-Assistant.psm1"
Import-Module "$ModulesDir\InputControls.psm1"

Write-Host "Script started" -ForegroundColor Yellow

# Set the console output encoding to UTF-8 to properly display Cyrillic characters
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Load DSP profiles
$DSPProfilesList = Get-ChildItem -Path $DSPProfilesDir -Filter "*.json"

# Check if any profiles found
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
}
else {
    Read-Host "Invalid selection. Hit ENTER to close powershell..."
    exit
}

# Load selected profile
$DSPConfig = Get-Content $selectedProfile -Raw | ConvertFrom-Json
$ProcessName = $DSPConfig.processName
if($DSPConfig.QDevider){
    $QDevider = $DSPConfig.QDevider
}
if($DSPConfig.DecimalSeparator){
    $DecimalSeparator = $DSPConfig.DecimalSeparator
} else {
    $DecimalSeparator = "."
}
if($null -ne $DSPConfig.QDecimals){
    $QDecimals = $DSPConfig.QDecimals
} else {
    $QDecimals = 1
}
if($null -ne $DSPConfig.GainDecimals){
    $GainDecimals = $DSPConfig.GainDecimals
} else {
    $GainDecimals = 1
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
Write-Host "Hint: When finished with EQ close PowerShell window or hit ctrl-c and confirm exit" -ForegroundColor Yellow
Write-Host "Waiting for EQ data from REW in clipboard  " -ForegroundColor Yellow -NoNewline
$spinner = @('/', '-', '\', '|')
$spinnerindex = 0

do {

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
        $bufferHeader = ""

        $UserInput = Show-ConfirmationDialog -StartingPositionHint $StartingPositionHint

        if ($UserInput -eq $true) {
            Write-Host "Proceeding with pasting EQ settings..." -ForegroundColor Yellow
            Show-DSPWindowToFront -processName $ProcessName | Out-Null

            write-host "Waiting $($DSPConfig.TimeoutBeforePasteSecs) seconds before auto-paste. $($DSPConfig.StartingPositionHint)" -ForegroundColor Yellow
            Start-Sleep -Seconds $DSPConfig.TimeoutBeforePasteSecs
            
            # Start pasting EQ bands with configured keystrokes and mouse actions
            foreach ($band in $bands) {
                foreach ($KeySet in $DSPConfig.KeystrokeSequence) {
                    $keyToSend = $KeySet.keys.Replace("FREQ", $band.freq).Replace("QVALUE", $band.Q).Replace("GAIN", $band.Gain)
                    [System.Windows.Forms.SendKeys]::SendWait($keyToSend)
                    Start-Sleep -Milliseconds $KeySet.delay_ms
                }
            }

            # Sort bands by frequency (if needed) - currently commented out to preserve original order
            # $bands = $bands | Sort-Object { [double]$_.Freq }

            # Prepare transposed table for display
           <# $bandsTable = [ordered]@{}
            for ($i = 0; $i -lt $bands.Count; $i++) {
                $bandName = "Band$($i + 1)"
                $bandsTable[$bandName] = $bands[$i]
            }

            # Transpose the table
            $transposed = @()
            foreach ($prop in "Freq", "Q", "Gain") {
                $row = [ordered]@{ Property = $prop }
                foreach ($band in $bandsTable.GetEnumerator()) {
                    $row[$band.Key] = $band.Value.$prop
                }
                $transposed += [pscustomobject]$row
            }

            # Display the transposed table
            Write-Host "`nPasted EQ Bands:" -ForegroundColor Green
            $transposed | Format-Table -AutoSize #>
            Show-TransposedTable -bands $bands | Format-Table -AutoSize
            Write-Host "Finished paste. Waiting for new data in clipboard  " -ForegroundColor Green -NoNewline
        }
        else {
            Write-Host "Cancelled by user. Waiting for new data in clipboard  " -ForegroundColor Yellow -NoNewline
            Set-Clipboard "Canceled"
        }

    }
    Write-Host -NoNewline ("`b" + $spinner[$spinnerindex])
    $spinnerindex = ($spinnerindex + 1) % $spinner.Length
    Start-Sleep -Seconds 1
} while (1)