@echo off
setlocal
title NovaGrid Godot 4.5.1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\open-in-godot.ps1"
if errorlevel 1 (
  echo.
  echo Could not open Godot. Read the error above, then press any key.
  pause >nul
  exit /b 1
)
endlocal
