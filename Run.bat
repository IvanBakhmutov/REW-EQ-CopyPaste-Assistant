cls
@echo off
cd /d "%~dp0"
powershell -NoProfile -executionpolicy remotesigned -command "Get-ChildItem -path .\* -filter '*' -Recurse | %% {Unblock-File $_.FullName}; . .\REW-EQ-CopyPaste-Assistant.ps1"