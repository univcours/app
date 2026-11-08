<#
NovaGrid Developer — safe GitHub to Godot updates on Windows.
Run -Install once to create an automatic per-user one-minute scheduled task.
Never resets/cleans/forces Git or overwrites local Godot edits.
#>
[CmdletBinding()]
param(
 [switch]$Install,
 [switch]$Once,
 [switch]$OpenEditor,
 [string]$Root = (Join-Path $env:USERPROFILE 'AndroidStudioProjects\app'),
 [string]$LogPath = (Join-Path $env:LOCALAPPDATA 'NovaGrid\godot-auto-sync.log'),
 [switch]$TestMode
)
$ErrorActionPreference='Stop'
$branch='novagrid-cosmic-edition-20261108'
$taskName='NovaGrid Godot AutoSync'
$Root=[IO.Path]::GetFullPath($Root)
$logDir=Split-Path -Parent $LogPath
if (!(Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Write-SyncStatus([string]$message) {
 $line='[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$message
 Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
 Write-Host $line
}
function GitText([string[]]$Arguments) {
 # Windows PowerShell 5.1 sometimes surfaces native stderr as ErrorRecord.
 $previous=$ErrorActionPreference
 try {
  $ErrorActionPreference='Continue'
  $output=@(& git.exe -C $Root @Arguments 2>&1)
  $code=$LASTEXITCODE
 } finally { $ErrorActionPreference=$previous }
 if ($code -ne 0) {
  throw "Git step failed (exit $code): $($Arguments[0]). $($output -join ' ')"
 }
 return @($output | ForEach-Object { [string]$_ })
}
function Update-NovaGrid {
 if (!(Get-Command git.exe -ErrorAction SilentlyContinue)) { throw 'Git for Windows is required.' }
 if (!(Test-Path -LiteralPath (Join-Path $Root '.git'))) { throw "Expected Git checkout at $Root" }
 $top=@(GitText @('rev-parse','--show-toplevel'))
 if ($top.Count -ne 1 -or [IO.Path]::GetFullPath($top[0]).TrimEnd('\') -ine $Root.TrimEnd('\')) {
  throw 'Refusing to update outside the selected Git repository root.'
 }
 $current=@(GitText @('branch','--show-current'))
 if ($current.Count -ne 1 -or $current[0] -cne $branch) {
  throw "Wrong branch. Expected $branch; never switch user branches automatically."
 }
 if (!$TestMode) {
  $remote=@(GitText @('remote','get-url','origin'))
  if ($remote.Count -ne 1 -or $remote[0] -notmatch '^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)(univcours/app)(\.git)?/?$') {
   throw 'Origin is not the approved univcours/app repository.'
  }
 }
 $remoteRef='refs/remotes/origin/'+$branch
 $refspec='+refs/heads/'+$branch+':'+$remoteRef
 [void](GitText @('fetch','--quiet','origin',$refspec))
 $local=@(GitText @('rev-parse','HEAD'))
 $target=@(GitText @('rev-parse',$remoteRef))
 if ($local[0] -eq $target[0]) { return 'up-to-date' }

 # Any edited tracked file or untracked NovaGrid asset blocks this fast-forward.
 $tracked=@(GitText @('status','--porcelain=v1','--untracked-files=no'))
 $projectFiles=@(GitText @('status','--porcelain=v1','--untracked-files=normal','--','novagrid-godot'))
 if ($tracked.Count -gt 0 -or $projectFiles.Count -gt 0) {
  Write-SyncStatus 'PAUSED: local edits exist. Commit or back up local changes to resume Git updates.'
  return 'paused-local-edits'
 }
 $base=@(GitText @('merge-base','HEAD',$remoteRef))
 if ($base[0] -ne $local[0]) {
  Write-SyncStatus 'PAUSED: local branch diverged. No history was rewritten.'
  return 'paused-diverged'
 }
 [void](GitText @('merge','--ff-only',$remoteRef))
 $newHead=@(GitText @('rev-parse','--short','HEAD'))
 Write-SyncStatus "UPDATED $($local[0]) -> $($target[0]) [$($newHead[0])]. Focus Godot Editor; press F5 to restart the running game."
 return 'updated'
}
function Install-AutoSync {
 if ($TestMode) { throw 'Do not install real scheduled tasks during CI tests.' }
 $installed=Join-Path $Root 'novagrid-godot\scripts\auto-sync-godot.ps1'
 if (!(Test-Path -LiteralPath $installed -PathType Leaf)) {
  throw 'Local auto-sync script not present yet. Check branch and local edits.'
 }
 $account=[Security.Principal.WindowsIdentity]::GetCurrent().Name
 $principal=New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive -RunLevel Limited
 $arguments='-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$installed+'" -Once -Root "'+$Root+'"'
 $action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
 $trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
 $settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -StartWhenAvailable
 Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
 Write-SyncStatus "AUTO-SYNC ENABLED: every minute as $account. Task: $taskName."
}
try {
 $state=Update-NovaGrid
 if ($Install) { Install-AutoSync }
 if ($OpenEditor) {
  $launcher=Join-Path $Root 'novagrid-godot\scripts\open-in-godot.ps1'
  if (!(Test-Path -LiteralPath $launcher)) { throw 'Godot launcher missing.' }
  $running=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Godot' })
  if ($running.Count -eq 0) {
   & $launcher
   Write-SyncStatus 'Godot Editor opened. Externally updated resources rescan when editor regains focus.'
  } else {
   Write-SyncStatus 'Godot already open; keep the existing editor window.'
  }
 }
 if (!$Once -or $state -ne 'up-to-date') { Write-Host "NovaGrid sync state: $state" }
} catch {
 Write-SyncStatus "SYNC ERROR: $($_.Exception.Message)"
 throw
}
