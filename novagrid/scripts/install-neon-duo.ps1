# NovaGrid Neon Duo: safe test build. Never overwrites the Play Store installation.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
function Check([string]$exe,[string[]]$arguments) {
    & $exe @arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed: $exe ($LASTEXITCODE)" }
}
if ((& git.exe branch --show-current).Trim() -ne 'novagrid-neon-duo') {
    throw 'Switch to novagrid-neon-duo before building this test edition.'
}
$cfg = Get-Content 'capacitor.config.json' -Raw | ConvertFrom-Json
if ($cfg.appId -cne 'com.novagrid.cosmicpuzzle') {
    throw 'Unexpected NovaGrid production package; build blocked.'
}
$env:ADMOB_LIVE_ADS = 'false'
Remove-Item Env:\ADMOB_ANDROID_APP_ID, Env:\ADMOB_INTERSTITIAL_UNIT_ID -ErrorAction SilentlyContinue
Check 'npm.cmd' @('install','--no-audit','--no-fund')
Check 'npm.cmd' @('test')
if (-not (Test-Path 'android\gradlew.bat')) { Check 'npx.cmd' @('cap','add','android') }
Check 'npm.cmd' @('run','android:sync')
# Use Android Studio's local Java runtime when the shell doesn't have a full JDK.
if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin\javac.exe'))) {
    $candidate = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr'
    if (Test-Path (Join-Path $candidate 'bin\javac.exe')) { $env:JAVA_HOME = $candidate }
}
Push-Location 'android'
try { Check '.\gradlew.bat' @(':app:assembleDebug','--no-daemon') }
finally { Pop-Location }
$apk = Join-Path (Get-Location) 'android\app\build\outputs\apk\debug\app-debug.apk'
if (-not (Test-Path $apk)) { throw 'Debug APK not found after build.' }
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$toolsDir = Join-Path $sdk 'build-tools'
$aapt = $null
if (Test-Path $toolsDir) {
    foreach ($dir in @(Get-ChildItem -LiteralPath $toolsDir -Directory | Sort-Object Name -Descending)) {
        $candidate = Join-Path $dir.FullName 'aapt.exe'
        if (Test-Path $candidate) { $aapt = $candidate; break }
    }
}
if (-not $aapt) { throw 'Cannot verify APK identity: Android SDK build-tools/aapt.exe missing.' }
$badging = (& $aapt dump badging $apk | Out-String)
if ($LASTEXITCODE -ne 0 -or $badging -notmatch "package:\s+name='com\.novagrid\.cosmicpuzzle\.candytest'") {
    throw 'Unsafe APK ID. Refusing install: production Play Store app must not be overwritten.'
}
Write-Host "Verified Neon Duo test APK: $apk" -ForegroundColor Green
$adb = Join-Path $sdk 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) { throw 'ADB not found; APK was built but cannot be installed.' }
$rows = @(& $adb devices -l | Where-Object { $_ -match '^\S+\s+device(?:\s|$)' })
$serials = @($rows | ForEach-Object { ($_ -split '\s+')[0] })
if ($serials.Count -eq 0) { Write-Warning 'No authorized phone found. APK ready; phone install skipped.'; return }
$serial = $env:NOVAGRID_ADB_SERIAL
if ($serial) {
    if ($serials -notcontains $serial) { throw 'Requested Android device is not connected/authorized.' }
} elseif ($serials.Count -eq 1) {
    $serial = $serials[0]
} else {
    Write-Host 'Choose the phone (other entries may be emulators):'
    for ($i=0;$i -lt $rows.Count;$i++) { Write-Host "$($i+1). $($rows[$i])" }
    $choice = Read-Host 'Device number'
    if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $serials.Count) {
        throw 'Invalid device choice; no installation attempted.'
    }
    $serial = $serials[[int]$choice-1]
}
& $adb -s $serial install -r $apk
if ($LASTEXITCODE -ne 0) { throw 'Beta installation failed; no apps were uninstalled and no data was cleared.' }
Check $adb @('-s',$serial,'shell','monkey','-p','com.novagrid.cosmicpuzzle.candytest','-c','android.intent.category.LAUNCHER','1')
Write-Host 'NovaGrid Neon Duo test edition launched. Original Play Store app/data is untouched.' -ForegroundColor Green
