echo "Running REW-EQ-CopyPaste-Assistant.ps1..."
cd "%~dp0"
powershell -executionpolicy remotesigned -command "Get-ChildItem -path .\* -include '*.ps1','*.psm1' -Recurse | % {Unblock-File $_.FullName}; . .\REW-EQ-CopyPaste-Assistant.ps1"