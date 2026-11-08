<#
Safe NovaGrid GitHub-to-Godot auto-sync on Windows.
-Install works even when the local checkout contains edits.
The scheduled program is stored at %LOCALAPPDATA%\NovaGrid, not in Git.
#>
[CmdletBinding()]
param(
 [switch]$Install,
 [switch]$Once,
 [switch]$OpenEditor,
 [string]$Root=(Join-Path $env:USERPROFILE 'AndroidStudioProjects\app'),
 [string]$LogPath=(Join-Path $env:LOCALAPPDATA 'NovaGrid\godot-auto-sync.log'),
 [switch]$TestMode
)
$ErrorActionPreference='Stop'
$branch='novagrid-cosmic-edition-20261108'
$taskName='NovaGrid Godot AutoSync'
$Root=[IO.Path]::GetFullPath($Root)
$logDir=Split-Path -Parent $LogPath
if (!(Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Status([string]$message) {
 $line='[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$message
 Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
 Write-Host $line
}
function GitText([string[]]$Arguments) {
 # Windows PowerShell 5.1 may wrap native stderr as ErrorRecords.
 $previous=$ErrorActionPreference
 try {
  $ErrorActionPreference='Continue'
  $output=@(& git.exe -C $Root @Arguments 2>&1)
  $code=$LASTEXITCODE
 } finally { $ErrorActionPreference=$previous }
 if ($code -ne 0) { throw "Git failed ($code): $($Arguments[0]) $($output -join ' ')" }
 return @($output | ForEach-Object { [string]$_ })
}
function Update-NovaGrid {
 if (!(Get-Command git.exe -ErrorAction SilentlyContinue)) { throw 'Git for Windows is required.' }
 if (!(Test-Path -LiteralPath (Join-Path $Root '.git'))) { throw "Git checkout missing: $Root" }
 $top=@(GitText @('rev-parse','--show-toplevel'))
 if ($top.Count -ne 1 -or [IO.Path]::GetFullPath($top[0]).TrimEnd('\') -ine $Root.TrimEnd('\')) {
  throw 'Refusing to sync outside expected repository root.'
 }
 $current=@(GitText @('branch','--show-current'))
 if ($current.Count -ne 1 -or $current[0] -cne $branch) {
  throw "Wrong branch; expected $branch. No automatic branch switching."
 }
 if (!$TestMode) {
  $remote=@(GitText @('remote','get-url','origin'))
  if ($remote.Count -ne 1 -or $remote[0] -notmatch '^(https://github\.com/|git@github\.com:|ssh://git@github\.com/)(univcours/app)(\.git)?/?$') {
   throw 'Origin does not match univcours/app.'
  }
 }
 $remoteRef='refs/remotes/origin/'+$branch
 $refspec='+refs/heads/'+$branch+':'+$remoteRef
 [void](GitText @('fetch','--quiet','origin',$refspec))
 $local=@(GitText @('rev-parse','HEAD'))
 $target=@(GitText @('rev-parse',$remoteRef))
 if ($local[0] -eq $target[0]) { return 'up-to-date' }
 $base=@(GitText @('merge-base','HEAD',$remoteRef))
 if ($base[0] -ne $local[0]) {
  Status 'PAUSED: local and remote commit history diverged. Changes preserved.'
  return 'paused-diverged'
 }

 # Detect actual collisions, instead of blocking all updates whenever Godot
 # writes a local file. Non-overlapping changes may fast-forward safely.
 $incoming=@(GitText @('-c','core.quotepath=false','diff','--name-only','HEAD',$remoteRef))
 $modified=@(GitText @('-c','core.quotepath=false','diff','--name-only','HEAD'))
 $untracked=@(GitText @('-c','core.quotepath=false','ls-files','--others','--exclude-standard'))
 $protected=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
 foreach($path in $modified) { [void]$protected.Add($path) }
 foreach($path in $untracked) { [void]$protected.Add($path) }
 $collisions=[System.Collections.Generic.List[string]]::new()
 foreach($path in $incoming) {
  if ($protected.Contains($path)) { $collisions.Add($path) }
 }
 if ($collisions.Count -gt 0) {
  Status "PAUSED: GitHub conflicts with local files: $($collisions -join ', '). Nothing overwritten."
  return 'paused-conflicts'
 }
 # Git protects other colliding file/directory cases; never force, reset,
 # stash, clean, switch branches, or overwrite a user's uncommitted work.
 [void](GitText @('merge','--ff-only',$remoteRef))
 $newHead=@(GitText @('rev-parse','--short','HEAD'))
 Status "UPDATED HEAD to $($newHead[0]). Focus Godot Editor to import; press F5 to restart gameplay."
 return 'updated'
}
function Install-Watcher {
 if ($TestMode) { throw 'Cannot register a real task in tests.' }
 # First execution is downloaded into TEMP. Install from the currently
 # running script, not a not-yet-pulled repository file.
 $installed=Join-Path $env:LOCALAPPDATA 'NovaGrid\auto-sync-godot.ps1'
 $sourceScript=$PSCommandPath
 if (!(Test-Path -LiteralPath $sourceScript -PathType Leaf)) {
  throw 'Cannot locate downloaded bootstrap script.'
 }
 if ([IO.Path]::GetFullPath($sourceScript) -ine [IO.Path]::GetFullPath($installed)) {
  Copy-Item -LiteralPath $sourceScript -Destination $installed -Force
 }
 $account=[Security.Principal.WindowsIdentity]::GetCurrent().Name
 $principal=New-ScheduledTaskPrincipal -UserId $account -LogonType Interactive -RunLevel Limited
 $argument='-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+$installed+'" -Once -Root "'+$Root+'"'
 $action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argument
 $trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
 $settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -StartWhenAvailable
 Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
 Status "AUTOSYNC INSTALLED: $taskName, every 1 minute. Installed script: $installed"
}
try {
 # Install FIRST, even if a dirty working tree later pauses updates.
 if ($Install) { Install-Watcher }
 $state=Update-NovaGrid
 if ($OpenEditor) {
  $launcher=Join-Path $Root 'novagrid-godot\scripts\open-in-godot.ps1'
  if (Test-Path -LiteralPath $launcher -PathType Leaf) {
   $running=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '^Godot' })
   if ($running.Count -eq 0) {
    & $launcher
    Status 'Godot Editor opened.'
   } else { Status 'Godot already open. No second editor launched.' }
  } else { Status 'Godot launcher not yet downloaded; use your current Godot window.' }
 }
 if (!$Once -or $state -ne 'up-to-date') { Write-Host "NovaGrid sync state: $state" }
} catch {
 Status "SYNC ERROR: $($_.Exception.Message)"
 throw
}
