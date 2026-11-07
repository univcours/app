@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\open-in-godot.ps1"
if errorlevel 1 (
 echo.
 echo Could not start Godot. See the message above.
 pause
)
