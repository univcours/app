<#
 Fixture regression tests for the UID-safe branch bootstrap.
 All remotes, commits and application files are temporary local fixtures.
#>
$ErrorActionPreference = 'Stop'
$branch = 'novagrid-cosmic-edition-20261108'
$switchScript = (Resolve-Path (Join-Path $PSScriptRoot '../scripts/switch-cosmic.ps1')).Path
$shellExe = (Get-Process -Id $PID).Path
$passed = 0
$failed = 0
$base = if ($env:NOVAGRID_SWITCH_TEST_ROOT) { $env:NOVAGRID_SWITCH_TEST_ROOT } else { [IO.Path]::GetTempPath() }
$suiteRoot = Join-Path $base ('novagrid-switch-tests-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $suiteRoot -Force | Out-Null

function Check([bool]$Value, [string]$Description) {
    if ($Value) { $script:passed++ }
    else {
        $script:failed++
        Write-Host "FAIL: $Description" -ForegroundColor Red
    }
}

function GitResult([string]$Repo, [string[]]$Arguments) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $Repo @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    return [PSCustomObject]@{ Code=$code; Output=($output | Out-String).TrimEnd() }
}

function GitChecked([string]$Repo, [string[]]$Arguments) {
    $result = GitResult $Repo $Arguments
    if ($result.Code -ne 0) { throw "Fixture Git failed: $($Arguments -join ' ')`n$($result.Output)" }
    return $result.Output
}

function WriteFixture([string]$Root, [string]$Path, [string]$Content) {
    $full = Join-Path $Root $Path
    $parent = Split-Path -Parent $full
    if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($full, $Content, [Text.UTF8Encoding]::new($false))
}

function ReadFixture([string]$Root, [string]$Path) {
    $full = Join-Path $Root $Path
    if (!(Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
    return [IO.File]::ReadAllText($full)
}

function SameBytes([string]$Left, [string]$Right) {
    if (!(Test-Path -LiteralPath $Left -PathType Leaf) -or !(Test-Path -LiteralPath $Right -PathType Leaf)) { return $false }
    return [Convert]::ToBase64String([IO.File]::ReadAllBytes($Left)) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($Right))
}

function Fixture([string]$Name, [switch]$IgnoreUid, [switch]$SingleBranch) {
    $fixtureHome = Join-Path $suiteRoot $Name
    New-Item -ItemType Directory -Path $fixtureHome | Out-Null
    GitChecked $fixtureHome @('init','--bare','origin.git') | Out-Null
    GitChecked $fixtureHome @('init','--initial-branch=legacy','seed') | Out-Null
    $seed = Join-Path $fixtureHome 'seed'
    GitChecked $seed @('config','user.name','NovaGrid Fixture') | Out-Null
    GitChecked $seed @('config','user.email','fixture@example.invalid') | Out-Null
    GitChecked $seed @('config','commit.gpgsign','false') | Out-Null
    GitChecked $seed @('config','core.autocrlf','false') | Out-Null
    WriteFixture $seed '.gitignore' ("ignored.dat`n" + $(if ($IgnoreUid) { "*.uid`n" } else { '' }))
    WriteFixture $seed 'novagrid-godot/project.godot' "config_version=5`n"
    WriteFixture $seed 'novagrid-godot/scripts/Main.gd' "legacy main`n"
    WriteFixture $seed 'novagrid-godot/scripts/Falling.gd' "legacy falling`n"
    WriteFixture $seed 'novagrid-godot/scripts/update-build-install.ps1' "throw 'SkipBuild fixture must never invoke the installer.'`n"
    WriteFixture $seed 'tracked.txt' "legacy tracked`n"
    WriteFixture $seed 'unrelated-tracked.txt' "unchanged on both branches`n"
    GitChecked $seed @('add','.') | Out-Null
    GitChecked $seed @('commit','-m','legacy fixture') | Out-Null
    GitChecked $seed @('remote','add','origin',(Join-Path $fixtureHome 'origin.git')) | Out-Null
    GitChecked $seed @('push','origin','legacy') | Out-Null
    GitChecked $seed @('switch','-c',$branch) | Out-Null
    WriteFixture $seed 'novagrid-godot/scripts/Main.gd' "cosmic main`n"
    WriteFixture $seed 'tracked.txt' "cosmic tracked`n"
    WriteFixture $seed 'novagrid-godot/scripts/Main.gd.uid' "uid://target-main`n"
    WriteFixture $seed 'novagrid-godot/scripts/Falling.gd.uid' "uid://target-falling`n"
    WriteFixture $seed 'novagrid-godot/ignored.dat' "target ignored-path data`n"
    GitChecked $seed @('add','.') | Out-Null
    GitChecked $seed @('add','-f','novagrid-godot/scripts/Main.gd.uid','novagrid-godot/scripts/Falling.gd.uid','novagrid-godot/ignored.dat') | Out-Null
    GitChecked $seed @('commit','-m','cosmic fixture') | Out-Null
    GitChecked $seed @('push','origin',$branch) | Out-Null
    $cloneArgs = @('clone','--config','core.autocrlf=false','--branch','legacy')
    if ($SingleBranch) { $cloneArgs += '--single-branch' }
    $cloneArgs += @((Join-Path $fixtureHome 'origin.git'),'consumer')
    GitChecked $fixtureHome $cloneArgs | Out-Null
    $repo = Join-Path $fixtureHome 'consumer'
    GitChecked $repo @('config','user.name','NovaGrid Fixture') | Out-Null
    GitChecked $repo @('config','user.email','fixture@example.invalid') | Out-Null
    GitChecked $repo @('config','commit.gpgsign','false') | Out-Null
    return [PSCustomObject]@{ Home=$fixtureHome; Seed=$seed; Repo=$repo }
}

function InvokeSwitch([string]$Repo) {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $shellExe -NoProfile -ExecutionPolicy Bypass -File $switchScript -Root $Repo -SkipBuild 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    $log = ($output | Out-String)
    [IO.File]::WriteAllText((Join-Path (Split-Path -Parent $Repo) 'bootstrap.log'), $log)
    return [PSCustomObject]@{ Code=$code; Output=$log }
}

function Backups([string]$FixtureDirectory) {
    return @(Get-ChildItem -LiteralPath $FixtureDirectory -Directory -Filter 'NovaGrid-UID-backup-*')
}

try {
    # Two real checkout conflicts plus unrelated user files, including a UID
    # that does not exist in the requested remote branch.
    $f = Fixture 'uid-conflicts-and-retry'
    WriteFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid' "uid://local-main`r`n"
    WriteFixture $f.Repo 'novagrid-godot/scripts/Falling.gd.uid' "uid://local-falling`n"
    WriteFixture $f.Repo 'novagrid-godot/scripts/Custom.gd.uid' "uid://custom-user-file`n"
    WriteFixture $f.Repo 'personal-notes.txt' "preserve these notes`n"
    $originalMain = Join-Path $f.Home 'expected-main.uid'
    Copy-Item -LiteralPath (Join-Path $f.Repo 'novagrid-godot/scripts/Main.gd.uid') -Destination $originalMain
    $originalFalling = Join-Path $f.Home 'expected-falling.uid'
    Copy-Item -LiteralPath (Join-Path $f.Repo 'novagrid-godot/scripts/Falling.gd.uid') -Destination $originalFalling
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -eq 0) 'UID conflict bootstrap succeeds'
    Check ((GitChecked $f.Repo @('branch','--show-current')) -eq $branch) 'requested source branch checked out'
    $backups = @(Backups $f.Home)
    Check ($backups.Count -eq 1) 'one unique sibling UID backup created'
    if ($backups.Count -eq 1) {
        Check (SameBytes $originalMain (Join-Path $backups[0].FullName 'novagrid-godot/scripts/Main.gd.uid')) 'Main UID backup is byte-for-byte including CRLF'
        Check (SameBytes $originalFalling (Join-Path $backups[0].FullName 'novagrid-godot/scripts/Falling.gd.uid')) 'Falling UID backup is byte-for-byte'
    }
    Check ((ReadFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid') -ceq "uid://target-main`n") 'tracked source UID installed from remote branch'
    Check ((ReadFixture $f.Repo 'novagrid-godot/scripts/Custom.gd.uid') -ceq "uid://custom-user-file`n") 'unrelated untracked UID preserved'
    Check ((ReadFixture $f.Repo 'personal-notes.txt') -ceq "preserve these notes`n") 'unrelated untracked file preserved'
    $head = GitChecked $f.Repo @('rev-parse','HEAD')
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -eq 0) 'same-branch retry succeeds'
    Check (@(Backups $f.Home).Count -eq 1) 'retry does not create spurious UID backups'
    Check ((GitChecked $f.Repo @('rev-parse','HEAD')) -eq $head) 'retry preserves current commit'
    Check ((ReadFixture $f.Repo 'novagrid-godot/scripts/Custom.gd.uid') -ceq "uid://custom-user-file`n") 'retry still preserves unrelated UID'

    $f = Fixture 'ignored-uid-conflict' -IgnoreUid
    WriteFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid' "uid://ignored-local`n"
    Check ((GitResult $f.Repo @('check-ignore','novagrid-godot/scripts/Main.gd.uid')).Code -eq 0) 'fixture UID is actually ignored by Git'
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -eq 0) 'ignored UID checkout conflict succeeds safely'
    $backups = @(Backups $f.Home)
    Check ($backups.Count -eq 1) 'ignored UID gets its own backup'
    if ($backups.Count -eq 1) {
        Check ((ReadFixture $backups[0].FullName 'novagrid-godot/scripts/Main.gd.uid') -ceq "uid://ignored-local`n") 'ignored UID contents preserved'
    }

    # An ignored non-UID file must block checkout rather than be overwritten.
    # Any UID already moved must return to its original path after refusal.
    $f = Fixture 'ignored-non-uid-refusal'
    WriteFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid' "uid://restore-after-refusal`n"
    WriteFixture $f.Repo 'novagrid-godot/ignored.dat' "irreplaceable ignored user data`n"
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -ne 0) 'ignored non-UID collision stops checkout'
    Check ((GitChecked $f.Repo @('branch','--show-current')) -eq 'legacy') 'ignored collision keeps original branch'
    Check ((ReadFixture $f.Repo 'novagrid-godot/ignored.dat') -ceq "irreplaceable ignored user data`n") 'ignored non-UID data never overwritten'
    Check ((ReadFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid') -ceq "uid://restore-after-refusal`n") 'moved UID restored after refused checkout'
    $backups = @(Backups $f.Home)
    Check ($backups.Count -eq 1) 'refused checkout retains recovery backup'
    if ($backups.Count -eq 1) {
        Check ((ReadFixture $backups[0].FullName 'novagrid-godot/scripts/Main.gd.uid') -ceq "uid://restore-after-refusal`n") 'recovery backup retains UID copy after restoration'
    }

    $f = Fixture 'tracked-edit-refusal'
    WriteFixture $f.Repo 'tracked.txt' "uncommitted user work`n"
    WriteFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid' "uid://preserve-on-tracked-conflict`n"
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -ne 0) 'conflicting tracked edits stop ordinary Git switch'
    Check ((GitChecked $f.Repo @('branch','--show-current')) -eq 'legacy') 'tracked conflict keeps original branch'
    Check ((ReadFixture $f.Repo 'tracked.txt') -ceq "uncommitted user work`n") 'tracked work preserved on refusal'
    Check ((ReadFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid') -ceq "uid://preserve-on-tracked-conflict`n") 'UID original present after tracked conflict'

    $f = Fixture 'single-branch-clone' -SingleBranch
    Check ((GitChecked $f.Repo @('config','--get-all','remote.origin.fetch')) -notmatch '\*') 'fixture really uses a restricted single-branch fetch refspec'
    WriteFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid' "uid://single-branch-local`n"
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -eq 0) 'explicit remote ref works in single-branch clone'
    Check ((GitChecked $f.Repo @('branch','--show-current')) -eq $branch) 'single-branch clone reaches requested branch'
    $backups = @(Backups $f.Home)
    Check ($backups.Count -eq 1) 'single-branch clone preserves conflicting UID'

    # Already-local commits must survive even when origin has diverged.
    $f = Fixture 'divergent-local-target'
    GitChecked $f.Repo @('switch',$branch) | Out-Null
    WriteFixture $f.Repo 'local-only.txt' "local branch commit`n"
    GitChecked $f.Repo @('add','local-only.txt') | Out-Null
    GitChecked $f.Repo @('commit','-m','local-only fixture commit') | Out-Null
    $localHead = GitChecked $f.Repo @('rev-parse','HEAD')
    WriteFixture $f.Seed 'remote-only.txt' "remote branch commit`n"
    GitChecked $f.Seed @('add','remote-only.txt') | Out-Null
    GitChecked $f.Seed @('commit','-m','remote-only fixture commit') | Out-Null
    GitChecked $f.Seed @('push','origin',$branch) | Out-Null
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -eq 0) 'SkipBuild safely selects an existing divergent local branch'
    Check ((GitChecked $f.Repo @('rev-parse','HEAD')) -eq $localHead) 'divergent local branch commit is never reset'
    Check ((ReadFixture $f.Repo 'local-only.txt') -ceq "local branch commit`n") 'local committed file preserved'
    Check (!(Test-Path -LiteralPath (Join-Path $f.Repo 'remote-only.txt'))) 'divergent remote tree never replaces local work'
    Check ((GitResult $f.Repo @('merge-base','--is-ancestor',"origin/$branch",'HEAD')).Code -eq 1) 'fixture remains divergent for later explicit fast-forward refusal'

    $f = Fixture 'tracked-uid-remains-user-work'
    GitChecked $f.Repo @('switch',$branch) | Out-Null
    WriteFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid' "uid://user-edited-tracked`n"
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -eq 0) 'same-branch tracked UID edit is allowed by ordinary Git behavior'
    Check ((ReadFixture $f.Repo 'novagrid-godot/scripts/Main.gd.uid') -ceq "uid://user-edited-tracked`n") 'already tracked UID is not moved or overwritten'
    Check (@(Backups $f.Home).Count -eq 0) 'tracked UID never mistaken for untracked conflict'

    $f = Fixture 'unrelated-tracked-edit-can-carry'
    WriteFixture $f.Repo 'unrelated-tracked.txt' "safe unrelated tracked change`n"
    $result = InvokeSwitch $f.Repo
    Check ($result.Code -eq 0) 'nonconflicting tracked change can carry through normal Git switch'
    Check ((ReadFixture $f.Repo 'unrelated-tracked.txt') -ceq "safe unrelated tracked change`n") 'nonconflicting tracked work remains byte-for-byte'

    Write-Host "NOVAGRID SWITCH FIXTURES: $passed passed, $failed failed"
    if ($failed -gt 0) { throw "$failed UID bootstrap fixture checks failed. Fixtures retained: $suiteRoot" }
    Remove-Item -LiteralPath $suiteRoot -Recurse -Force
} catch {
    Write-Host "Fixture diagnostics retained: $suiteRoot" -ForegroundColor Yellow
    throw
}
