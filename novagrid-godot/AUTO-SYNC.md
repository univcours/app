NovaGrid - automatic updates in Godot

The previous installer failed because local Godot changes paused Git before
the auto-sync file had downloaded. This is fixed by installing the scheduled
worker from the downloaded bootstrap into LOCALAPPDATA (outside Git) FIRST.

Paste this once in PowerShell:
  & { $ErrorActionPreference='Stop'; $url='https://raw.githubusercontent.com/univcours/app/novagrid-cosmic-edition-20261108/novagrid-godot/scripts/auto-sync-godot.ps1'; $file=Join-Path $env:TEMP 'novagrid-auto-sync-bootstrap.ps1'; Invoke-WebRequest -Uri $url -OutFile $file; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file -Install -OpenEditor; if($LASTEXITCODE -ne 0){throw 'Install failed; see NovaGrid auto-sync log'} }

Windows Scheduled Task: NovaGrid Godot AutoSync, every minute (signed-in
user only, no admin password required). Worker:
  %LOCALAPPDATA%\NovaGrid\auto-sync-godot.ps1
Log:
  %LOCALAPPDATA%\NovaGrid\godot-auto-sync.log

It updates the exact univcours/app Godot branch via git fetch and fast-forward.
It preserves local files and commits: it can sync files unrelated to modified
local files; overlapping remote/local edits pause until resolved manually.
It never runs git reset, clean, stash, force, or switches branches.

Focus the Godot Editor to scan changed resources; press F5 to restart an
already running game. Auto-sync does not sign Android releases or install
missing export templates. Disable the task in Windows Task Scheduler anytime.
