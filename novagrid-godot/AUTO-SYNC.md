NovaGrid Godot automatic updates

Run once in Windows PowerShell (no admin needed):

  & { $url='https://raw.githubusercontent.com/univcours/app/novagrid-cosmic-edition-20261108/novagrid-godot/scripts/auto-sync-godot.ps1'; $tmp=Join-Path $env:TEMP 'novagrid-auto-sync-bootstrap.ps1'; Invoke-WebRequest -Uri $url -OutFile $tmp; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tmp -Install -OpenEditor; if ($LASTEXITCODE -ne 0) { throw 'NovaGrid auto-sync installation failed' } }

What this does:
- Syncs the GitHub branch novagrid-cosmic-edition-20261108 now.
- Installs a current-user Windows Task Scheduler task "NovaGrid Godot AutoSync".
- Checks GitHub every one minute while Windows is running and internet is available.
- Godot Editor notices external changes and re-imports on focus. Press F5 to rerun a currently running game.
- No keystore, signing or Android export changes; those are independent.
- Never git reset, clean, stash, force or switch branches.
- Does not overwrite uncommitted code or untracked local Godot assets. If local files are modified, it pauses updates rather than losing work.
- If the network is offline, it retries on the next scheduled check.
- Status log: %LOCALAPPDATA%\NovaGrid\godot-auto-sync.log
- Disable/remove the task through Windows Task Scheduler to stop automatic updates.

To force a check manually:
  & "$env:USERPROFILE\AndroidStudioProjects\app\novagrid-godot\scripts\auto-sync-godot.ps1" -Once

Manual Godot edits are NOT auto-uploaded to GitHub. Save and commit them yourself if you want to preserve them alongside remote changes.
