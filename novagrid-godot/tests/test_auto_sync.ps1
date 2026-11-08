# Disposable Git repositories test safe automatic NovaGrid/Godot sync on Windows.
$ErrorActionPreference='Stop'
$sync=Join-Path $PSScriptRoot '..\scripts\auto-sync-godot.ps1'
$base=Join-Path $env:RUNNER_TEMP ('novagrid-autosync-'+[Guid]::NewGuid().ToString('N'))
$origin=Join-Path $base 'origin.git'
$seed=Join-Path $base 'seed'
$clone=Join-Path $base 'clone'
$log=Join-Path $base 'auto-sync.log'
$branch='novagrid-cosmic-edition-20261108'
New-Item -ItemType Directory -Force -Path $base | Out-Null
function Invoke-FixtureGit([string[]]$arguments) {
 & git.exe @arguments 2>&1 | Out-Null
 if ($LASTEXITCODE -ne 0) { throw "Fixture Git error: $($arguments -join ' ')" }
}
function Require([bool]$ok,[string]$message) {
 if (!$ok) { throw "NOVAGRID AUTO SYNC FAILURE: $message" }
}
try {
 # Check that the Windows Task Scheduler trigger can be constructed without
 # actually registering a task or altering the GitHub Actions runner.
 $schedule=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
 $principal=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
 $settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -StartWhenAvailable
 Require ($null -ne $schedule -and $null -ne $principal -and $null -ne $settings) 'per-user one-minute schedule constructs correctly'
 Invoke-FixtureGit @('init','--bare',$origin)
 Invoke-FixtureGit @('clone',$origin,$seed)
 Invoke-FixtureGit @('-C',$seed,'checkout','-b',$branch)
 Invoke-FixtureGit @('-C',$seed,'config','user.email','test@local.invalid')
 Invoke-FixtureGit @('-C',$seed,'config','user.name','NovaGrid CI')
 $source=Join-Path $seed 'novagrid-godot'
 New-Item -ItemType Directory -Path $source -Force | Out-Null
 Set-Content -LiteralPath (Join-Path $source 'project.godot') -Value 'initial'
 Invoke-FixtureGit @('-C',$seed,'add','novagrid-godot')
 Invoke-FixtureGit @('-C',$seed,'commit','-m','initial')
 Invoke-FixtureGit @('-C',$seed,'push','-u','origin',$branch)
 Invoke-FixtureGit @('clone','--branch',$branch,$origin,$clone)
 Set-Content -LiteralPath (Join-Path $source 'project.godot') -Value 'new GitHub design'
 Invoke-FixtureGit @('-C',$seed,'add','-A')
 Invoke-FixtureGit @('-C',$seed,'commit','-m','updated')
 Invoke-FixtureGit @('-C',$seed,'push','origin',$branch)
 & $sync -Once -Root $clone -LogPath $log -TestMode
 Require ((Get-Content (Join-Path $clone 'novagrid-godot\project.godot') -Raw).Trim() -eq 'new GitHub design') 'fast-forward update downloaded'
 $head=(& git.exe -C $clone rev-parse HEAD | Out-String).Trim()

 # Local edits are never stashed, reset or overwritten.
 Set-Content -LiteralPath (Join-Path $clone 'novagrid-godot\project.godot') -Value 'MY LOCAL UNSAVED GODOT WORK'
 Set-Content -LiteralPath (Join-Path $source 'project.godot') -Value 'future update'
 Invoke-FixtureGit @('-C',$seed,'add','-A')
 Invoke-FixtureGit @('-C',$seed,'commit','-m','future')
 Invoke-FixtureGit @('-C',$seed,'push','origin',$branch)
 & $sync -Once -Root $clone -LogPath $log -TestMode
 Require ((Get-Content (Join-Path $clone 'novagrid-godot\project.godot') -Raw).Trim() -eq 'MY LOCAL UNSAVED GODOT WORK') 'preserved local Godot changes'
 Require ((& git.exe -C $clone rev-parse HEAD | Out-String).Trim() -eq $head) 'did not move branch over local edits'

 # Switching to any other branch must halt; no auto branch reset allowed.
 Invoke-FixtureGit @('-C',$clone,'checkout','-b','another-branch')
 $denied=$false
 try { & $sync -Once -Root $clone -LogPath $log -TestMode } catch { $denied=$true }
 Require $denied 'wrong branch rejected'
 Write-Host 'ALL NOVAGRID AUTOMATIC GODOT SYNC TESTS PASSED' -ForegroundColor Green
} finally {
 if (Test-Path -LiteralPath $base) { Remove-Item -LiteralPath $base -Force -Recurse -ErrorAction SilentlyContinue }
}
