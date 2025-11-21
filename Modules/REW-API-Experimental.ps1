$process = Get-WmiObject Win32_Process -Filter "name='roomeqwizard.exe'" 
if($null -ne $process) {
    $checkpREWargs = $process | Select-Object CommandLine
    if($checkpREWargs.CommandLine -notmatch "-api") {
        Write-Host "REW is not running with -api argument. Please restart REW with -api argument to enable API functionality." -ForegroundColor Yellow
    } else {
        $testapi = Invoke-RestMethod -Uri "http://127.0.0.1:4735/measurements" -Method Get -ErrorAction Stop
        if($null -eq $testapi) {
            Write-Host "REW API is not responding. Please ensure REW is running with -api argument." -ForegroundColor Yellow
        } else {
            Write-Host "REW API is active." -ForegroundColor Green
            $selectedMeasurementUID = Invoke-RestMethod -Uri "http://127.0.0.1:4735/measurements/selected-uuid" -Method Get
            if($null -eq $selectedMeasurementUID) {
                Write-Host "No measurement is selected in REW." -ForegroundColor Yellow
            } else {
                Write-Host "Selected measurement UUID: $selectedMeasurementUID" -ForegroundColor Green
                $eqBands = Invoke-RestMethod -Uri "http://127.0.0.1:4735/measurements/$selectedMeasurementUID/filters" -Method Get
                $eqBands | Where-Object { ($_.type -eq "PK") -and ($_.Enabled -eq "True") } | ForEach-Object {
                    Write-Host "Bandnumber: $($_.index), Freq: $($_.frequency) Hz, Gain: $($_.gaindB) dB, Q: $($_.q)" -ForegroundColor Cyan
                    #band number here is questionable as in REW can be in any order. better to be indexed inside of the script
                }
            }
        }
    }
} else {
    $checkpREWargs = $null
}