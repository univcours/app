# Windows regression: retries, locked disposable folders and deletion safety.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\scripts\qa-cleanup.ps1')
function Require([bool]$Condition,[string]$Message) {
    if (!$Condition) { throw "QA CLEANUP TEST FAILED: $Message" }
}
$prefix = 'NovaGrid-QA-'
$folder = Join-Path ([IO.Path]::GetTempPath()) ($prefix + [Guid]::NewGuid().ToString('N'))
$file = Join-Path $folder 'still-open.txt'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
[IO.File]::WriteAllText($file,'test')
$stream = $null
try {
    # Windows must refuse deleting an opened handle with FileShare.None.
    $stream = [IO.File]::Open($file,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $deleted = Remove-NovaGridTemporaryQAPath -LiteralPath $folder -MaxAttempts 2 -RetryDelayMilliseconds 25 -WarningAction SilentlyContinue
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        Require (!$deleted) 'Locked folder should defer its cleanup without throwing'
    }
} finally {
    if ($null -ne $stream) { $stream.Dispose() }
}
Require (Remove-NovaGridTemporaryQAPath -LiteralPath $folder -MaxAttempts 4 -RetryDelayMilliseconds 50) 'Unlocked QA folder cleanup must succeed'
Require (!(Test-Path -LiteralPath $folder)) 'QA folder must be absent after success'
$refused = $false
try {
    [void](Remove-NovaGridTemporaryQAPath -LiteralPath (Join-Path ([IO.Path]::GetTempPath()) 'NovaGrid-QA-not-a-guid'))
} catch { $refused = $true }
Require $refused 'Malformed QA folder name must be rejected'
$refused = $false
try {
    [void](Remove-NovaGridTemporaryQAPath -LiteralPath (Join-Path (Get-Location) ($prefix + [Guid]::NewGuid().ToString('N'))))
} catch { $refused = $true }
Require $refused 'Unexpected QA parent directory must be rejected'
Write-Host 'NOVAGRID WINDOWS LOCKED QA CLEANUP TESTS PASSED' -ForegroundColor Green
