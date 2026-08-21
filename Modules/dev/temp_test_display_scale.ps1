Set-Location 'c:\workspace\REW-EQ-CopyPaste-Assistant'
Import-Module '.\Modules\Import-Types.psm1' -Force
Import-Module '.\Modules\Input-Controls.psm1' -Force
$s = Get-WindowsDisplayScale
Write-Host ('ScaleFactor=' + $s.ScaleFactor)
Write-Host ('ScalePercent=' + $s.ScalePercent)
