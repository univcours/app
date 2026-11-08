<#
 Recover the Godot-generated UID checkout conflicts without discarding work.
 The bootstrap can be read with git show before switching the source branch.
 Close Godot first so it cannot regenerate UID files during checkout.
#>
param(
    [Parameter(Mandatory=$true)][string]$Root,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$branch = 'novagrid-cosmic-edition-20261108'
$Root = (Resolve-Path -LiteralPath $Root).Path
$backup = $null
$moved = [System.Collections.Generic.List[string]]::new()
$switchSucceeded = $false

function GitOutput([string[]]$Arguments) {
    # Windows PowerShell 5.1 otherwise treats native progress on stderr as a
    # terminating error before Git's real exit code can be checked.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& git -C $Root @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousPreference }
    if ($code -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "Git failed (exit $code): git $($Arguments -join ' ')"
    }
    return @($output | ForEach-Object { [string]$_ })
}

try {
    $actualRoot = @(GitOutput @('rev-parse','--show-toplevel'))
    if ($actualRoot.Count -ne 1 -or
        [IO.Path]::GetFullPath($actualRoot[0]) -ne [IO.Path]::GetFullPath($Root)) {
        throw 'Root must be the top-level app Git repository.'
    }
    GitOutput @('fetch','origin',"+refs/heads/${branch}:refs/remotes/origin/${branch}") |
        ForEach-Object { Write-Host $_ }
    $currentTracked = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in @(GitOutput @('-c','core.quotepath=false','ls-files','--','novagrid-godot'))) {
        [void]$currentTracked.Add($path)
    }
    $targetPaths = @(GitOutput @('-c','core.quotepath=false','ls-tree','-r','--name-only',"origin/$branch",'--','novagrid-godot'))
    foreach ($path in $targetPaths) {
        if (!$path.EndsWith('.uid',[StringComparison]::OrdinalIgnoreCase) -or $currentTracked.Contains($path)) { continue }
        $source = Join-Path $Root $path
        if (!(Test-Path -LiteralPath $source)) { continue }
        if (!(Test-Path -LiteralPath $source -PathType Leaf)) {
            throw "Expected a UID file, found another filesystem entry: $source"
        }
        if ($null -eq $backup) {
            $backup = Join-Path (Split-Path -Parent $Root) ('NovaGrid-UID-backup-' + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $backup | Out-Null
            Write-Host "UID backup: $backup" -ForegroundColor Yellow
        }
        $destination = Join-Path $backup $path
        $parent = Split-Path -Parent $destination
        if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Move-Item -LiteralPath $source -Destination $destination
        $moved.Add($path)
    }
    # Never overwrite ignored files, throw away local commits or reset changes.
    $localBranches = @(GitOutput @('for-each-ref','--format=%(refname)','refs/heads'))
    if ($localBranches -contains "refs/heads/$branch") {
        GitOutput @('switch','--no-overwrite-ignore',$branch) | ForEach-Object { Write-Host $_ }
    } else {
        # Explicit creation also works in single-branch clones whose fetch
        # refspec does not let checkout auto-discover the new remote branch.
        GitOutput @('switch','--no-overwrite-ignore','--no-track','-c',$branch,"origin/$branch") |
            ForEach-Object { Write-Host $_ }
    }
    $switchSucceeded = $true
    if ($moved.Count -gt 0) { Write-Host "Preserved $($moved.Count) UID file(s) at $backup" -ForegroundColor Green }
    if (!$SkipBuild) {
        $installer = Join-Path $Root 'novagrid-godot/scripts/update-build-install.ps1'
        if (!(Test-Path -LiteralPath $installer -PathType Leaf)) { throw "Installer missing: $installer" }
        & $installer
    }
} catch {
    if (!$switchSucceeded -and $null -ne $backup) {
        # Git refused the switch: restore only missing originals, keep backup.
        foreach ($path in $moved) {
            $original = Join-Path $Root $path
            if (!(Test-Path -LiteralPath $original)) {
                try {
                    [IO.File]::Copy((Join-Path $backup $path),$original,$false)
                } catch [IO.IOException] {
                    # A running editor may have regenerated it since Test-Path.
                    if (!(Test-Path -LiteralPath $original)) { throw }
                }
            }
        }
    }
    if ($null -ne $backup) { Write-Host "UID backup retained: $backup" -ForegroundColor Yellow }
    throw
}
