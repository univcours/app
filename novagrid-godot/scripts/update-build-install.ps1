<#
 Runs from Android Studio PowerShell terminal: Git update -> Godot APK export ->
 ADB install -> launch. Build is Godot native, NOT Android Studio Gradle.
 Package com.novagrid.cosmicpuzzle.godotpreview remains independent of Play.
 Original production application, original signing key and data are untouched.
#>
param([switch]$SkipGitPull,[switch]$AdMobTest)
$ErrorActionPreference = 'Stop'

function CheckExit([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed (exit $LASTEXITCODE)." }
}

# Godot may print a GDScript error and still return zero. Reject both signals.
function InvokeGodotChecked([string[]]$Arguments, [string]$Step) {
    $output = @(& $godot @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0 -or ($output -match 'SCRIPT ERROR|Parse Error|Parser Error|ERROR:')) {
        throw "$Step failed (exit $exitCode). See Godot output above."
    }
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

    # Official portable engine, isolated from any other Godot installation.
    $destination = Join-Path $configDir 'Godot-4.5.1'
    New-Item -ItemType Directory -Force -Path $destination | Out-Null
    $zip = Join-Path $destination 'Godot-4.5.1-win64.zip'
    $url = 'https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/Godot_v4.5.1-stable_win64.exe.zip'
    Write-Host 'Downloading official portable Godot 4.5.1 for Windows...' -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $url -OutFile $zip -ErrorAction Stop
        if ((Get-Item $zip).Length -lt 5000000) { throw 'Godot ZIP is unexpectedly small.' }
        Expand-Archive -LiteralPath $zip -DestinationPath $destination -Force -ErrorAction Stop
        $exe = Get-ChildItem -LiteralPath $destination -File -Recurse |
            Where-Object { $_.Name -match '^Godot.*4\.5\.1.*\.exe$' -and $_.Name -notmatch '_console\.exe$' } |
            Select-Object -First 1
        if (!$exe) { throw 'No Godot executable found in official archive.' }
        return $exe.FullName
    } finally {
        if (Test-Path $zip) { Remove-Item -LiteralPath $zip -Force }
    }
}

$project = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$root = (Resolve-Path (Join-Path $project '..')).Path
$branch = 'novagrid-cosmic-edition-20261108'
$package = 'com.novagrid.cosmicpuzzle.godotpreview'
if (!(Test-Path (Join-Path $project 'project.godot'))) { throw 'Godot project missing.' }
if (!(Test-Path (Join-Path $root '.git'))) { throw 'Git repository missing.' }

if (!$SkipGitPull) {
    $active = (git -C $root branch --show-current).Trim()
    if ($active -ne $branch) { throw "Wrong branch: $active" }
    Write-Host 'Updating NovaGrid from GitHub...' -ForegroundColor Cyan
    git -C $root pull --ff-only origin $branch
    CheckExit 'Git pull'
    # Preserve all unrelated repository files and local worktrees. Do NOT enable sparse-checkout.
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

Write-Host 'Importing source in Godot 4.5.1...' -ForegroundColor Cyan
InvokeGodotChecked @('--headless','--editor','--path',$project,'--quit') 'Godot project import'

# Run real tests on an isolated copy with a unique application data directory.
# Tests drive scenes and write saves, so they must not use the player's save.
$qaId = 'NovaGrid-QA-' + [Guid]::NewGuid().ToString('N')
$qaProject = Join-Path ([IO.Path]::GetTempPath()) $qaId
try {
    New-Item -ItemType Directory -Force -Path $qaProject | Out-Null
    Get-ChildItem -LiteralPath $project -Force |
        Where-Object { $_.Name -notin @('.godot','build','android','.git') } |
        Copy-Item -Destination $qaProject -Recurse -Force
    $qaConfig = Join-Path $qaProject 'project.godot'
    $qaText = [IO.File]::ReadAllText($qaConfig)
    $qaText = $qaText -replace '(?m)^config/name="[^"]*"', ('config/name="' + $qaId + '"')
    $qaText = $qaText -replace '(?m)^config/use_custom_user_dir=.*$', 'config/use_custom_user_dir=false'
    [IO.File]::WriteAllText($qaConfig, $qaText)
    InvokeGodotChecked @('--headless','--editor','--path',$qaProject,'--quit') 'Isolated QA import'
    foreach ($suite in @('game','progression','touch','layout','audio','back_navigation','cosmic','integrity','open_source','menu')) {
        Write-Host "Running Godot test suite: $suite" -ForegroundColor Cyan
        InvokeGodotChecked @('--headless','--audio-driver','Dummy','--path',$qaProject,'--script',"res://tests/test_$suite.gd") "Godot $suite tests"
    }
} finally {
    if (Test-Path -LiteralPath $qaProject) { Remove-Item -LiteralPath $qaProject -Recurse -Force }
    $qaData = Join-Path $env:APPDATA ("Godot\app_userdata\" + $qaId)
    if (Test-Path -LiteralPath $qaData) { Remove-Item -LiteralPath $qaData -Recurse -Force }
}


Write-Host 'Configuring Godot Android SDK and Java SDK paths...' -ForegroundColor Cyan
InvokeGodotChecked @('--headless','--editor','--path',$project,'--script','res://scripts/configure_android_editor.gd') 'Godot editor SDK configuration'

$templates = Join-Path $env:APPDATA 'Godot\export_templates\4.5.1.stable'
if (!(Test-Path (Join-Path $templates 'android_debug.apk'))) {
    # Godot official TPZ is a ZIP; unpack only the exact 4.5.1 templates.
    $tplUrl = 'https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/Godot_v4.5.1-stable_export_templates.tpz'
    $tplZip = Join-Path $configDir 'godot-android-templates-4.5.1.zip'
    $extract = Join-Path $configDir 'godot-templates-unpacked'
    Write-Host 'Downloading official Godot 4.5.1 Android export templates...' -ForegroundColor Cyan
    try {
        Invoke-WebRequest -Uri $tplUrl -OutFile $tplZip -ErrorAction Stop
        if ((Get-Item $tplZip).Length -lt 10000000) { throw 'Export template archive is unexpectedly small.' }
        if (Test-Path $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
        Expand-Archive -LiteralPath $tplZip -DestinationPath $extract -Force -ErrorAction Stop
        $src = Join-Path $extract 'templates'
        if (!(Test-Path (Join-Path $src 'android_debug.apk'))) { throw 'Missing Android template inside official archive.' }
        New-Item -ItemType Directory -Force -Path $templates | Out-Null
        Copy-Item -Path (Join-Path $src '*') -Destination $templates -Recurse -Force
    } finally {
        if (Test-Path $tplZip) { Remove-Item -LiteralPath $tplZip -Force }
        if (Test-Path $extract) { Remove-Item -LiteralPath $extract -Recurse -Force }
    }
}
if (!(Test-Path (Join-Path $templates 'android_debug.apk'))) { throw 'Godot Android export templates still missing.' }

$build = Join-Path $project 'build'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$apk = Join-Path $build $(if ($AdMobTest) { 'NovaGrid-Godot-AdMob-TEST.apk' } else { 'NovaGrid-Godot-Preview.apk' })
$fresh = Join-Path $build $(if ($AdMobTest) { 'NovaGrid-Godot-AdMob-TEST-fresh.apk' } else { 'NovaGrid-Godot-Preview-fresh.apk' })
if (Test-Path $fresh) { Remove-Item -LiteralPath $fresh -Force }

$presetName='Android Preview'
$exportArgs=@('--headless','--path',$project)
if($AdMobTest){
 if(!(Test-Path (Join-Path $project 'addons\admob\plugin.cfg'))){throw 'Native AdMob plugin missing'}
 if(!(Test-Path (Join-Path $project 'ads\AdMobRuntime.gd'))){throw 'Native AdMob controller missing'}
 $presetName='Android AdMob Test'
 $exportArgs+=@('--install-android-build-template')
 Write-Host 'Installing Gradle Android build template for Poing native plugin...' -ForegroundColor Cyan
}
Write-Host "Exporting Godot Android debug APK: $presetName" -ForegroundColor Cyan
$exportArgs+=@('--export-debug',$presetName,$fresh)
InvokeGodotChecked $exportArgs 'Godot APK export'
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
