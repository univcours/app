# Native Godot AdMob Android TEST bootstrap. No Play production changes.
param([switch]$PrepareOnly)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(!(Test-Path (Join-Path $project 'project.godot'))){throw 'Godot project.godot missing'}
if(!(Test-Path (Join-Path $project 'ads\AdMobRuntime.gd.txt'))){throw 'AdMob runtime template missing'}
$cache=Join-Path $env:LOCALAPPDATA 'NovaGrid\PoingAdMob-5.1.0'
New-Item -ItemType Directory -Force -Path $cache|Out-Null
$base='https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0'
function FetchPinned([string]$filename,[string]$expected){
 $path=Join-Path $cache $filename
 if(!(Test-Path $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected){
  Write-Host "Getting verified Poing Studios v5.1.0 asset: $filename" -ForegroundColor Cyan
  Invoke-WebRequest -Uri "$base/$filename" -OutFile $path -ErrorAction Stop
 }
 $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
 if($hash -ne $expected){Remove-Item -LiteralPath $path -Force;throw "Checksum mismatch: $filename"}
 return $path
}
$zip=FetchPinned 'poing-godot-admob-v5.1.0.zip' '8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f'
$androidZip=FetchPinned 'android-template-v4.5.1.zip' 'f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee'
$stage=Join-Path $cache 'extracted'
if(Test-Path $stage){Remove-Item -LiteralPath $stage -Recurse -Force}
Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
$manifest=Get-ChildItem -LiteralPath $stage -Recurse -Filter plugin.cfg -File |
 Where-Object {$_.Directory.Name -eq 'admob'}|Select-Object -First 1
if(!$manifest){throw 'Official plugin.cfg missing in pinned ZIP'}
$destination=Join-Path $project 'addons\admob'
New-Item -ItemType Directory -Path $destination -Force|Out-Null
Copy-Item -Path (Join-Path $manifest.Directory.FullName '*') -Destination $destination -Recurse -Force
$bin=Join-Path $destination 'android\bin'
New-Item -ItemType Directory -Path $bin -Force|Out-Null
Expand-Archive -LiteralPath $androidZip -DestinationPath $bin -Force
if(@(Get-ChildItem -LiteralPath $bin -Recurse -File|Where-Object {$_.Extension -eq '.aar'}).Count -lt 1){
 throw 'AdMob Android AAR missing in official release'
}
Copy-Item -LiteralPath (Join-Path $project 'ads\AdMobRuntime.gd.txt') -Destination (Join-Path $project 'ads\AdMobRuntime.gd') -Force
$cfgPath=Join-Path $project 'project.godot'
$cfg=[IO.File]::ReadAllText($cfgPath)
if($cfg -notmatch '(?m)^\[editor_plugins\]'){
 $cfg+=[Environment]::NewLine+@'
[editor_plugins]
enabled=PackedStringArray("res://addons/admob/plugin.cfg")
'@
}elseif($cfg -notmatch 'res://addons/admob/plugin.cfg'){
 throw 'Other editor plugins already configured; refusing automatic overwrite'
}
if($cfg -notmatch '(?m)^\[admob\]'){
 $cfg+=[Environment]::NewLine+@'
[admob]
general/android/enabled=true
general/android/app_id="ca-app-pub-3940256099942544~3347511713"
'@
}elseif($cfg -notmatch '3940256099942544~3347511713'){
 throw 'Non-demo AdMob ID detected in TEST project; refusing overwrite'
}
[IO.File]::WriteAllText($cfgPath,$cfg,[Text.UTF8Encoding]::new($false))
$preset=Join-Path $project 'export_presets.cfg'
$current=[IO.File]::ReadAllText($preset)
if($current -notmatch 'name="Android AdMob Test"'){
 if($current -notmatch '\[preset\.0\]' -or $current -notmatch '\[preset\.0\.options\]' -or $current -match '\[preset\.1\]'){
  throw 'Android export preset collision'
 }
 $extra=$current.Replace('[preset.0]','[preset.1]').Replace('[preset.0.options]','[preset.1.options]')
 $extra=$extra.Replace('name="Android Preview"','name="Android AdMob Test"')
 $extra=$extra.Replace('gradle_build/use_gradle_build=false','gradle_build/use_gradle_build=true')
 $extra=$extra.Replace('build/NovaGrid-Godot-Preview.apk','build/NovaGrid-Godot-AdMob-TEST.apk')
 # Both preview variants share the same monotonically increased debug code.
 $extra=$extra.Replace('version/name="0.4.0-cosmic-preview"','version/name="0.4.0-cosmic-test"')
 $extra=$extra.Replace('package/name="NovaGrid Godot Preview"','package/name="NovaGrid Godot AdMob Test"')
 [IO.File]::AppendAllText($preset,[Environment]::NewLine+$extra,[Text.UTF8Encoding]::new($false))
}
if(!$PrepareOnly){
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'update-build-install.ps1') -SkipGitPull -AdMobTest
 if($LASTEXITCODE -ne 0){throw 'Native Android AdMob Gradle export / install failed'}
}
Write-Host 'Poing v5.1.0 native AdMob TEST configured; no production ads were requested.' -ForegroundColor Green
