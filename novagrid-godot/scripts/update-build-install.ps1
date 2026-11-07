<#
 Runs from Android Studio PowerShell terminal: Git update -> Godot APK export ->
 ADB install -> launch. Build is Godot native, NOT Android Studio Gradle.
 Package com.novagrid.cosmicpuzzle.godotpreview remains independent of Play.
 Original production application, original signing key and data are untouched.
#>
param([switch]$SkipGitPull)
$ErrorActionPreference = 'Stop'

function CheckExit([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed (exit $LASTEXITCODE)." }
}

function LocateGodot {
    $configDir = Join-Path $env:LOCALAPPDATA 'NovaGrid'
    $cache = Join-Path $configDir 'godot-exe.txt'
    if (Test-Path $cache) {
        $entry = (Get-Content $cache -Raw).Trim()
        if (Test-Path $entry -PathType Leaf) { return $entry }
    }

    $paths = @(
        (Join-Path $configDir 'Godot-4.5.1\Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Godot\Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $env:USERPROFILE 'Desktop\Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $env:ProgramFiles 'Godot\Godot_v4.5.1-stable_win64.exe')
    )
    foreach ($p in $paths) {
        if (Test-Path $p -PathType Leaf) { return $p }
    }

    $command = Get-Command 'godot.exe','Godot_v4.5.1-stable_win64.exe' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command.Source }

    # Godot is portable on Windows. Earlier download commands may have
    # extracted it inside a second folder, not installed it in Program Files.
    $roots = @(
        $configDir,
        (Join-Path $env:USERPROFILE 'Downloads'),
        (Join-Path $env:USERPROFILE 'Desktop'),
        (Join-Path $env:USERPROFILE 'Documents'),
        (Join-Path $env:LOCALAPPDATA 'Programs'),
        (Join-Path $env:ProgramFiles 'Godot')
    )
    foreach ($dir in $roots) {
        if (!(Test-Path $dir -PathType Container)) { continue }
        $exe = Get-ChildItem -LiteralPath $dir -File -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^Godot.*4\.5\.1.*\.exe$' -and $_.Name -notmatch '_console\.exe$' } |
            Select-Object -First 1
        if ($exe) {
            Write-Host "Found existing Godot: $($exe.FullName)" -ForegroundColor Green
            return $exe.FullName
        }
    }

    # A downloaded ZIP is not an installed executable. Unpack one locally
    # when already present, rather than downloading Godot a second time.
    foreach ($dir in $roots) {
        if (!(Test-Path $dir -PathType Container)) { continue }
        $archives = @(Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^Godot.*4\.5\.1.*win64.*\.zip$' } |
            Select-Object -First 1)
        foreach ($archive in $archives) {
            $destination = Join-Path $configDir 'Godot-4.5.1'
            New-Item -ItemType Directory -Force -Path $destination | Out-Null
            Write-Host "Unpacking already downloaded Godot: $($archive.FullName)" -ForegroundColor Cyan
            try {
                Expand-Archive -LiteralPath $archive.FullName -DestinationPath $destination -Force -ErrorAction Stop
            } catch {
                throw "Existing Godot ZIP cannot be extracted: $($archive.FullName). $($_.Exception.Message)"
            }
            $exe = Get-ChildItem -LiteralPath $destination -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^Godot.*4\.5\.1.*\.exe$' -and $_.Name -notmatch '_console\.exe$' } |
                Select-Object -First 1
            if ($exe) { return $exe.FullName }
        }
    }

    throw 'Godot 4.5.1 executable/ZIP could not be found automatically in Downloads, Desktop, Documents, AppData or Godot program folders. No new download was attempted.'
}

$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$root = (Resolve-Path (Join-Path $project '..')).Path
$branch = 'novagrid-godot-rebuild'
$package = 'com.novagrid.cosmicpuzzle.godotpreview'
if (!(Test-Path (Join-Path $project 'project.godot'))) { throw 'Godot project missing.' }
if (!(Test-Path (Join-Path $root '.git'))) { throw 'Git repository missing.' }

if (!$SkipGitPull) {
    $active = (git -C $root branch --show-current).Trim()
    if ($active -ne $branch) { throw "Wrong branch: $active" }
    Write-Host 'Updating NovaGrid from GitHub...' -ForegroundColor Cyan
    git -C $root pull --ff-only origin $branch
    CheckExit 'Git pull'
    git -C $root sparse-checkout set novagrid-godot
    CheckExit 'Sparse checkout'
}

$godot = LocateGodot
$version = (& $godot --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1\.') {
    throw "Godot 4.5.1 required for this project. Found: $version"
}

$configDir = Join-Path $env:LOCALAPPDATA 'NovaGrid'
New-Item -ItemType Directory -Force -Path $configDir | Out-Null
Set-Content -LiteralPath (Join-Path $configDir 'godot-exe.txt') -Value $godot -Encoding UTF8

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
if (!(Test-Path $adb)) { throw "Android SDK adb.exe not found at: $adb" }

$javaHomes = @()
if ($env:JAVA_HOME) { $javaHomes += $env:JAVA_HOME }
$javaHomes += (Join-Path $env:ProgramFiles 'Android\Android Studio\jbr')
$javaHomes += (Join-Path $env:ProgramFiles 'Android\Android Studio\jre')
$jdk = $null
foreach ($dir in $javaHomes) {
    if (Test-Path (Join-Path $dir 'bin\keytool.exe')) { $jdk = $dir; break }
}
if (!$jdk) { throw 'Java SDK not found. Set JAVA_HOME to JDK 17 or install Android Studio JBR.' }

$keystore = Join-Path $configDir 'novagrid-native-debug.keystore'
if (!(Test-Path $keystore)) {
    Write-Host 'Generating a reusable local DEBUG signing key (not your Play key)...' -ForegroundColor Yellow
    & (Join-Path $jdk 'bin\keytool.exe') -genkeypair -keystore $keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 4000 -dname 'CN=NovaGrid Preview,O=Development,C=MA' -noprompt
    CheckExit 'Debug key generation'
}

$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $keystore
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
$env:NOVAGRID_ANDROID_SDK = $sdk
$env:NOVAGRID_JAVA_SDK = $jdk
$env:ANDROID_HOME = $sdk
$env:JAVA_HOME = $jdk

Write-Host 'Configuring Godot Android SDK and Java SDK paths...' -ForegroundColor Cyan
& $godot --headless --editor --path $project --script 'res://scripts/configure_android_editor.gd'
CheckExit 'Godot editor SDK configuration'

$templates = Join-Path $env:APPDATA 'Godot\export_templates\4.5.1.stable'
if (!(Test-Path (Join-Path $templates 'android_debug.apk'))) {
    throw 'Godot Android export templates missing. Open Godot 4.5.1 > Editor > Manage Export Templates > Download and Install, then rerun. No app was modified.'
}

$build = Join-Path $project 'build'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$apk = Join-Path $build 'NovaGrid-Godot-Preview.apk'
$fresh = Join-Path $build 'NovaGrid-Godot-Preview-fresh.apk'
if (Test-Path $fresh) { Remove-Item -LiteralPath $fresh -Force }

Write-Host 'Exporting latest native Godot Android debug APK...' -ForegroundColor Cyan
& $godot --headless --path $project --export-debug 'Android Preview' $fresh
CheckExit 'Godot APK export'
if (!(Test-Path $fresh) -or (Get-Item $fresh).Length -lt 100000) { throw 'Godot did not produce a valid APK.' }
Move-Item -LiteralPath $fresh -Destination $apk -Force

$devices = @(& $adb devices | ForEach-Object {
    if ($_ -match '^(\S+)\s+device(?:\s|$)') { $Matches[1] }
})
if ($devices.Count -eq 0) { throw 'No authorized phone. Connect USB, enable USB debugging, accept USB authorization.' }
$serial = $devices[0]
if ($devices.Count -gt 1) {
    for ($i = 0; $i -lt $devices.Count; $i++) { Write-Host "$($i+1). $($devices[$i])" }
    $choice = Read-Host 'Select device number'
    if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $devices.Count) {
        throw 'Invalid device selection.'
    }
    $serial = $devices[[int]$choice-1]
}
Write-Host "Installing preview on $serial..." -ForegroundColor Cyan
$installOutput = (& $adb -s $serial install -r $apk 2>&1 | Out-String)
Write-Host $installOutput
if ($LASTEXITCODE -ne 0) {
    if ($installOutput -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE|INCONSISTENT_CERTIFICATES') {
        throw 'Different debug signing key for an existing preview: installation stopped to PROTECT preview game data. No app was uninstalled.'
    }
    throw 'ADB install failed. No app was uninstalled.'
}
& $adb -s $serial shell monkey -p $package -c android.intent.category.LAUNCHER 1
CheckExit 'Starting preview on phone'
Write-Host "SUCCESS: NovaGrid preview installed and launched. APK: $apk" -ForegroundColor Green
