<#
 Safely release NovaGrid's uniquely named temporary QA directories.
 Windows Defender/indexers can briefly hold a GDScript-generated file after
 Godot tests have passed. Never delete live project data or player saves.
#>
function Remove-NovaGridTemporaryQAPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$LiteralPath,
        [ValidateRange(1,10)][int]$MaxAttempts = 5,
        [ValidateRange(0,2000)][int]$RetryDelayMilliseconds = 350
    )
    $full = [IO.Path]::GetFullPath($LiteralPath).TrimEnd([char[]]@('\','/'))
    $name = [IO.Path]::GetFileName($full)
    if ($name -cnotmatch '^NovaGrid-QA-[0-9a-fA-F]{32}$') {
        throw "Refusing to clean a non-QA directory: $full"
    }
    $parent = [IO.Path]::GetDirectoryName($full).TrimEnd([char[]]@('\','/'))
    $allowedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char[]]@('\','/'))
    $allowedSave = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'Godot\app_userdata')).TrimEnd([char[]]@('\','/'))
    if ($parent -ine $allowedTemp -and $parent -ine $allowedSave) {
        throw "Refusing to clean outside the isolated QA locations: $full"
    }
    if (!(Test-Path -LiteralPath $full)) { return $true }
    # Never recurse through a reparse point to another directory.
    if (((Get-Item -LiteralPath $full -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Refusing to clean a linked QA directory: $full"
    }
    $failure = ''
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction Stop
            if (!(Test-Path -LiteralPath $full)) { return $true }
            $failure = 'Path still exists after removal'
        } catch {
            $failure = $_.Exception.Message
        }
        if ($attempt -lt $MaxAttempts) {
            Start-Sleep -Milliseconds $RetryDelayMilliseconds
        }
    }
    # The folder is disposable and uniquely named; preserve it for manual
    # cleanup rather than killing processes, deleting saves, or hiding test errors.
    Write-Warning "Deferred cleanup of locked NovaGrid QA directory: $full ($failure)"
    return $false
}
