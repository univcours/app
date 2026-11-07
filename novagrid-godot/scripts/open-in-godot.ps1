<# Open the NATIVE NovaGrid Godot editor project from any folder.
   No APK, ADB, npm, Android Studio, Google Play, or signing key needed.
   Does not modify other applications, installed games, or user saves.
#>
param([switch]$Play)
$ErrorActionPreference = 'Stop'

$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {
    throw "NovaGrid Godot source missing. Run this helper from an extracted Godot project ZIP."
}

function Locate-Godot {
    $cachePath = Join-Path (Join-Path $env:LOCALAPPDATA 'NovaGrid') 'godot-exe.txt'
    if (Test-Path -LiteralPath $cachePath) {
        $saved = (Get-Content -LiteralPath $cachePath -Raw).Trim()
        if (Test-Path -LiteralPath $saved -PathType Leaf) { return $saved }
    }
    $paths = @(
        (Join-Path $env:LOCALAPPDATA 'NovaGrid\Godot-4.5.1\Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $env:USERPROFILE 'Desktop\Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $env:ProgramFiles 'Godot\Godot_v4.5.1-stable_win64.exe')
    )
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
    $app = Get-Command 'godot.exe','Godot_v4.5.1-stable_win64.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($app) { return $app.Source }
    foreach ($folder in @((Join-Path $env:USERPROFILE 'Downloads'),(Join-Path $env:USERPROFILE 'Desktop'),(Join-Path $env:LOCALAPPDATA 'NovaGrid'))) {
        if (-not (Test-Path -LiteralPath $folder -PathType Container)) { continue }
        $found = Get-ChildItem -LiteralPath $folder -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^Godot.*4\.5\.1.*\.exe$' -and $_.Name -notmatch '_console\.exe$' } |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    Add-Type -AssemblyName System.Windows.Forms
    $picker = New-Object System.Windows.Forms.OpenFileDialog
    $picker.Title = 'Select Godot 4.5.1 (Windows Standard) executable'
    $picker.Filter = 'Godot executable (Godot*.exe)|Godot*.exe|Executable files (*.exe)|*.exe'
    $picker.CheckFileExists = $true
    if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'Godot not selected. Download Godot 4.5.1 Standard from https://godotengine.org/download/archive/4.5.1-stable and extract its ZIP, then try again.'
    }
    return $picker.FileName
}

$godot = Locate-Godot
if (-not (Test-Path -LiteralPath $godot -PathType Leaf)) { throw "Godot executable not found at $godot" }
$version = (& $godot --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1\.') {
    throw "This NovaGrid project needs Godot 4.5.1. Selected executable reports: $version"
}
$cacheFolder = Join-Path $env:LOCALAPPDATA 'NovaGrid'
New-Item -ItemType Directory -Path $cacheFolder -Force | Out-Null
Set-Content -LiteralPath (Join-Path $cacheFolder 'godot-exe.txt') -Value $godot -Encoding UTF8
Write-Host "Godot: $godot" -ForegroundColor Green
Write-Host "NovaGrid source: $project" -ForegroundColor Cyan

$arguments = if ($Play) { @('--path',('"' + $project + '"')) } else { @('--editor','--path',('"' + $project + '"')) }
Write-Host $(if ($Play) { 'Launching NovaGrid game.' } else { 'Opening Godot editor. Press F5 to play.' }) -ForegroundColor Green
Start-Process -FilePath $godot -ArgumentList $arguments
