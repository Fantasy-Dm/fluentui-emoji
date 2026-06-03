@echo off
powershell.exe -ExecutionPolicy Bypass -File "%~dp0reorganize_emojis.ps1" -Limit 99999
pause
