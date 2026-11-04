# NovaGrid safe Android update: build, install, and optionally sign Play AAB.
# This script never uninstalls apps or deletes local game data.
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
function Run($program, [string[]]$arguments) {
    & $program @arguments
    if ($LASTEXITCODE -ne 0) { throw "NovaGrid command failed: $program (exit $LASTEXITCODE)" }
}
$branch = (& git.exe branch --show-current).Trim()
if ($branch -ne 'novagrid-original-1-0-0') { throw "Wrong Git branch: $branch; use novagrid-original-1-0-0" }
$config = Get-Content capacitor.config.json -Raw | ConvertFrom-Json
if ($config.appName -cne 'NovaGrid' -or $config.appId -ne 'com.novagrid.cosmicpuzzle') { throw 'Wrong Android project!' }
$env:ADMOB_LIVE_ADS = 'false' # Local test builds only.
Remove-Item Env:\ADMOB_ANDROID_APP_ID -ErrorAction SilentlyContinue
Remove-Item Env:\ADMOB_INTERSTITIAL_UNIT_ID -ErrorAction SilentlyContinue
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
# Gradle launched from PowerShell may not inherit the JDK bundled with Android Studio.
# Detect it locally; do not alter machine-wide environment variables.
function Enable-AndroidStudioJava {
    $candidates = @()
    if ($env:JAVA_HOME) { $candidates += $env:JAVA_HOME }
    if ($env:STUDIO_JDK) { $candidates += $env:STUDIO_JDK }
    if ($env:JDK_HOME) { $candidates += $env:JDK_HOME }
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles 'Eclipse Adoptium\jdk-21.0.13.9-hotspot')
        $candidates += (Join-Path $env:ProgramFiles 'Android\Android Studio\jbr')
        $candidates += (Join-Path $env:ProgramFiles 'Android\Android Studio\jre')
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Android\Android Studio\jbr')
    }
    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Android Studio\jbr')
        $candidates += (Join-Path $env:LOCALAPPDATA 'Android\Android Studio\jbr')
    }
    # Also support Android Studio installed on a custom drive through its shortcut.
    $links = @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Android Studio.lnk'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\Android Studio.lnk')
    )
    foreach ($link in $links) {
        if (-not (Test-Path -LiteralPath $link)) { continue }
        try {
            $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($link)
            if ($shortcut.TargetPath) {
                $root = Split-Path -Parent (Split-Path -Parent $shortcut.TargetPath)
                $candidates += (Join-Path $root 'jbr')
                $candidates += (Join-Path $root 'jre')
            }
        } catch { }
    }
    $knownJava = Get-Command 'java.exe' -ErrorAction SilentlyContinue
    if ($knownJava) {
        $candidates += (Split-Path -Parent (Split-Path -Parent $knownJava.Source))
    }
    foreach ($candidate in $candidates) {
        if (-not $candidate) { continue }
        $javaExe = Join-Path $candidate 'bin\java.exe'
        $compiler = Join-Path $candidate 'bin\javac.exe'
        if ((Test-Path -LiteralPath $javaExe) -and (Test-Path -LiteralPath $compiler)) {
            $env:JAVA_HOME = (Resolve-Path -LiteralPath $candidate).Path
            $env:Path = (Join-Path $env:JAVA_HOME 'bin') + ';' + $env:Path
            Write-Host "[NovaGrid] JAVA_HOME detected: $env:JAVA_HOME"
            return
        }
    }
    throw 'Java JDK not found. Find Gradle JDK in Android Studio Settings > Build Tools > Gradle (usually C:\Program Files\Android\Android Studio\jbr). Set JAVA_HOME to that directory and rerun.'
}
Enable-AndroidStudioJava

Write-Host '[NovaGrid] Build APK and release AAB.'
Push-Location android
try { Run '.\gradlew.bat' @(':app:assembleDebug',':app:bundleRelease','--no-daemon') }
finally { Pop-Location }
$apk = Join-Path (Get-Location) 'android\app\build\outputs\apk\debug\app-debug.apk'
$aab = Join-Path (Get-Location) 'android\app\build\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $apk) -or -not (Test-Path $aab)) { throw 'APK or AAB missing.' }
# The generated Debug APK must never replace the Play-signed NovaGrid application.
$aapt = $null
$buildTools = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools'
if (Test-Path $buildTools) {
    foreach ($directory in @(Get-ChildItem -LiteralPath $buildTools -Directory | Sort-Object Name -Descending)) {
        $candidate = Join-Path $directory.FullName 'aapt.exe'
        if (Test-Path $candidate) { $aapt = $candidate; break }
    }
}
if (-not $aapt) { throw 'Android aapt missing; cannot safely verify APK package.' }
$details = (& $aapt dump badging $apk | Out-String)
if ($LASTEXITCODE -ne 0 -or $details -notmatch "package:\s+name='com\.novagrid\.cosmicpuzzle\.candytest'") {
    throw 'Expected Candy test package. Refusing installation to protect Play Store app.'
}
$dest = Join-Path $env:USERPROFILE 'Downloads\NovaGrid-Candy-Arcade-3-Stages-TEST.apk'
Copy-Item -LiteralPath $apk -Destination $dest -Force
Write-Host "[NovaGrid] Verified test APK ready: $dest" -ForegroundColor Green
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
Write-Host '[NovaGrid] Installing separate Candy Arcade TEST; original Play app stays untouched.'
& $adb install -r $apk
if ($LASTEXITCODE -ne 0) {
    throw 'Install failed. Existing signing certificate may differ. No uninstall or data deletion performed.'
}
Run $adb @('shell','monkey','-p','com.novagrid.cosmicpuzzle.candytest','-c','android.intent.category.LAUNCHER','1')
Write-Host '[NovaGrid] Candy Arcade TEST launched. Play Store game/data untouched.'
