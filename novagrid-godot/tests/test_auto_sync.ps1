# Safe NovaGrid auto-sync regressions on disposable Windows Git checkouts.
$ErrorActionPreference='Stop'
$sync=Join-Path $PSScriptRoot '..\scripts\auto-sync-godot.ps1'
$base=Join-Path $env:RUNNER_TEMP ('novagrid-autosync-'+[Guid]::NewGuid().ToString('N'))
$origin=Join-Path $base 'origin.git'
$seed=Join-Path $base 'seed'
$clone=Join-Path $base 'clone'
$log=Join-Path $base 'sync.log'
$branch='novagrid-cosmic-edition-20261108'
New-Item -ItemType Directory -Force -Path $base | Out-Null
function FixtureGit([string[]]$Arguments) {
 & git.exe @Arguments 2>&1 | Out-Null
 if ($LASTEXITCODE -ne 0) { throw "Fixture Git failure: $($Arguments -join ' ')" }
}
function Assert([bool]$condition,[string]$description) {
 if (!$condition) { throw "NovaGrid automatic sync test failed: $description" }
}
function SyncOnce { & $sync -Once -Root $clone -LogPath $log -TestMode }
try {
 $scriptText=Get-Content -LiteralPath $sync -Raw
 Assert ($scriptText.Contains('NovaGrid\auto-sync-godot.ps1')) 'permanent script stored outside Git'
 Assert ($scriptText.IndexOf('if ($Install) { Install-Watcher }') -lt $scriptText.IndexOf('$state=Update-NovaGrid')) 'install occurs before a paused Git update'
 $schedule=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
 Assert ($null -ne $schedule) 'one-minute Windows task trigger is valid'

 FixtureGit @('init','--bare',$origin)
 FixtureGit @('clone',$origin,$seed)
 FixtureGit @('-C',$seed,'checkout','-b',$branch)
 FixtureGit @('-C',$seed,'config','user.email','test@local.invalid')
 FixtureGit @('-C',$seed,'config','user.name','NovaGrid CI')
 $project=Join-Path $seed 'novagrid-godot'
 New-Item -ItemType Directory -Path $project -Force | Out-Null
 Set-Content -LiteralPath (Join-Path $project 'project.godot') -Value 'initial'
 FixtureGit @('-C',$seed,'add','novagrid-godot')
 FixtureGit @('-C',$seed,'commit','-m','initial')
 FixtureGit @('-C',$seed,'push','-u','origin',$branch)
 FixtureGit @('clone','--branch',$branch,$origin,$clone)

 # Clean update succeeds.
 Set-Content -LiteralPath (Join-Path $project 'project.godot') -Value 'upstream neon design'
 FixtureGit @('-C',$seed,'add','-A')
 FixtureGit @('-C',$seed,'commit','-m','upstream')
 FixtureGit @('-C',$seed,'push','origin',$branch)
 SyncOnce
 Assert ((Get-Content (Join-Path $clone 'novagrid-godot\project.godot') -Raw).Trim() -eq 'upstream neon design') 'fast-forward sync'

 # Local edits do not block unrelated incoming files.
 Set-Content -LiteralPath (Join-Path $clone 'novagrid-godot\project.godot') -Value 'MY GODOT EDIT'
 Set-Content -LiteralPath (Join-Path $project 'new-neon.gd') -Value 'new code'
 FixtureGit @('-C',$seed,'add','-A')
 FixtureGit @('-C',$seed,'commit','-m','unrelated remote change')
 FixtureGit @('-C',$seed,'push','origin',$branch)
 SyncOnce
 Assert ((Get-Content (Join-Path $clone 'novagrid-godot\project.godot') -Raw).Trim() -eq 'MY GODOT EDIT') 'local changes preserved'
 Assert ((Get-Content (Join-Path $clone 'novagrid-godot\new-neon.gd') -Raw).Trim() -eq 'new code') 'nonconflicting file synced'

 # Same-file conflicts pause without a HEAD update.
 $priorHead=(& git.exe -C $clone rev-parse HEAD | Out-String).Trim()
 Set-Content -LiteralPath (Join-Path $project 'project.godot') -Value 'remote conflicts'
 FixtureGit @('-C',$seed,'add','-A')
 FixtureGit @('-C',$seed,'commit','-m','conflict')
 FixtureGit @('-C',$seed,'push','origin',$branch)
 SyncOnce
 Assert ((Get-Content (Join-Path $clone 'novagrid-godot\project.godot') -Raw).Trim() -eq 'MY GODOT EDIT') 'conflict preserves user file'
 Assert ((& git.exe -C $clone rev-parse HEAD | Out-String).Trim() -eq $priorHead) 'HEAD unaffected by conflict'

 # Never switch branches without user approval.
 FixtureGit @('-C',$clone,'checkout','-b','another-branch')
 $refused=$false
 try { SyncOnce } catch { $refused=$true }
 Assert $refused 'wrong branch must be rejected'
 Write-Host 'ALL NOVAGRID AUTO SYNC REGRESSION TESTS PASSED'
} finally {
 if (Test-Path -LiteralPath $base) {
  Remove-Item -LiteralPath $base -Force -Recurse -ErrorAction SilentlyContinue
 }
}
