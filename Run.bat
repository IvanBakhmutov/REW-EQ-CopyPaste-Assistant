cls
@echo off
cd /d "%~dp0"
powershell -executionpolicy remotesigned  -NoProfile -command "Get-ChildItem -path .\* -filter '*' -Recurse | %% {Unblock-File $_.FullName}; . .\REW-EQ-CopyPaste-Assistant.ps1"