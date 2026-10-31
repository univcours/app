# NovaGrid safe Android update: build, install, and optionally sign Play AAB.
# This script never uninstalls apps or deletes local game data.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
function Run($program, [string[]]$arguments) {
    & $program @arguments
    if ($LASTEXITCODE -ne 0) { throw "NovaGrid command failed: $program (exit $LASTEXITCODE)" }
}
$branch = (& git.exe branch --show-current).Trim()
if ($branch -ne 'novagrid-mvp') { throw "Wrong Git branch: $branch; use novagrid-mvp" }
$config = Get-Content capacitor.config.json -Raw | ConvertFrom-Json
if ($config.appName -cne 'NovaGrid' -or $config.appId -ne 'com.novagrid.cosmicpuzzle') { throw 'Wrong Android project!' }
Write-Host '[NovaGrid] Install dependencies and run tests.'
Run 'npm.cmd' @('install','--no-audit','--no-fund')
Run 'npm.cmd' @('test')
if (-not (Test-Path 'android\gradlew.bat')) {
    Run 'npm.cmd' @('run','build')
    Run 'npx.cmd' @('cap','add','android')
}
Write-Host '[NovaGrid] Sync Android app name and game files.'
Run 'npm.cmd' @('run','android:sync')
$strings = Get-Content 'android\app\src\main\res\values\strings.xml' -Raw
if ($strings -notmatch '<string\s+name="app_name"\s*>\s*NovaGrid\s*</string>' -or
    $strings -notmatch '<string\s+name="title_activity_main"\s*>\s*NovaGrid\s*</string>') {
    throw 'Android display name is not NovaGrid. Installation cancelled.'
}
$manifest = Get-Content 'android\app\src\main\AndroidManifest.xml' -Raw
if ($manifest -notmatch 'android:label="@string/app_name"') {
    throw 'AndroidManifest uses a different label. Installation cancelled.'
}
Write-Host '[NovaGrid] Build APK and release AAB.'
Push-Location android
try { Run '.\gradlew.bat' @(':app:assembleDebug',':app:bundleRelease','--no-daemon') }
finally { Pop-Location }
$apk = Join-Path (Get-Location) 'android\app\build\outputs\apk\debug\app-debug.apk'
$aab = Join-Path (Get-Location) 'android\app\build\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $apk) -or -not (Test-Path $aab)) { throw 'APK or AAB missing.' }
Write-Host "Debug APK: $apk"
Write-Host "Unsigned AAB: $aab"

# Optional signing, only if the owner has supplied a permanent upload key locally.
$vars = @('NOVAGRID_UPLOAD_KEYSTORE_PATH','NOVAGRID_UPLOAD_KEYSTORE_PASSWORD','NOVAGRID_UPLOAD_KEY_ALIAS','NOVAGRID_UPLOAD_KEY_PASSWORD')
$provided = @($vars | Where-Object { [Environment]::GetEnvironmentVariable($_) }).Count
if ($provided -eq 4) {
    $keyfile = $env:NOVAGRID_UPLOAD_KEYSTORE_PATH
    if (-not (Test-Path $keyfile)) { throw 'Upload keystore file not found.' }
    $signer = (Get-Command jarsigner.exe -ErrorAction Stop).Source
    $signed = Join-Path (Get-Location) 'android\app\build\outputs\bundle\release\NovaGrid-Play-Internal-signed.aab'
    Run $signer @('-keystore',$keyfile,
      '-storepass:env','NOVAGRID_UPLOAD_KEYSTORE_PASSWORD',
      '-keypass:env','NOVAGRID_UPLOAD_KEY_PASSWORD',
      '-signedjar',$signed,$aab,$env:NOVAGRID_UPLOAD_KEY_ALIAS)
    Run $signer @('-verify',$signed)
    Write-Host "SIGNED Play Internal Testing AAB: $signed"
} elseif ($provided -gt 0) {
    Write-Warning 'Some signing variables are missing; AAB remains unsigned.'
} else {
    Write-Warning 'No upload key configured. AAB remains UNSIGNED; not uploadable to Google Play.'
}
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $adb)) {
    $found = Get-Command adb.exe -ErrorAction SilentlyContinue
    if ($found) { $adb = $found.Source }
}
if (-not (Test-Path $adb)) { Write-Warning 'ADB missing; build completed, install skipped.'; exit 0 }
$devices = @(& $adb devices | Where-Object { $_ -match '^\S+\s+device(?:\s|$)' })
if ($devices.Count -ne 1) {
    Write-Warning "Expected exactly one Android device, found $($devices.Count). APK not installed."
    exit 0
}
Write-Host '[NovaGrid] Updating installed app without clearing its data.'
& $adb install -r $apk
if ($LASTEXITCODE -ne 0) {
    throw 'Install failed. Existing signing certificate may differ. No uninstall or data deletion performed.'
}
Run $adb @('shell','monkey','-p','com.novagrid.cosmicpuzzle','-c','android.intent.category.LAUNCHER','1')
Write-Host '[NovaGrid] App updated and launched. Play Console upload must be performed separately.'
