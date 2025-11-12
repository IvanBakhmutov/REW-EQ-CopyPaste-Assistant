echo "Running REW-EQ-CopyPaste-Assistant.ps1..."
cd /d "%~dp0"
powershell -executionpolicy remotesigned -command "Get-ChildItem -path .\* -filter '*' -Recurse | %% {Unblock-File $_.FullName}; . .\REW-EQ-CopyPaste-Assistant.ps1"