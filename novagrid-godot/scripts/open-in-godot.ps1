<# Open editable NovaGrid with Godot 4.5.1 from any current directory. No Android SDK needed. #>
param([switch]$Play)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(!(Test-Path (Join-Path $project 'project.godot') -PathType Leaf)){throw "Missing project.godot: $project"}
$paths=@()
if($env:GODOT_EXE){$paths+=$env:GODOT_EXE}
$cache=Join-Path $env:LOCALAPPDATA 'NovaGrid\godot-exe.txt'
if(Test-Path $cache){$paths+=(Get-Content $cache -Raw).Trim()}
$paths+=@(
 (Join-Path $env:LOCALAPPDATA 'NovaGrid\Godot-4.5.1\Godot_v4.5.1-stable_win64.exe'),
 (Join-Path $env:USERPROFILE 'Downloads\Godot_v4.5.1-stable_win64.exe'),
 (Join-Path $env:USERPROFILE 'Desktop\Godot_v4.5.1-stable_win64.exe'),
 (Join-Path $env:LOCALAPPDATA 'Programs\Godot\Godot_v4.5.1-stable_win64.exe'),
 (Join-Path $env:ProgramFiles 'Godot\Godot_v4.5.1-stable_win64.exe')
)
foreach($name in @('godot.exe','Godot_v4.5.1-stable_win64.exe')){
 $found=Get-Command $name -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
 if($found){$paths+=$found.Source}
}
$godot=$null
foreach($candidate in $paths){
 if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){$godot=(Resolve-Path -LiteralPath $candidate).Path;break}
}
if(!$godot){
 foreach($folder in @((Join-Path $env:USERPROFILE 'Downloads'),(Join-Path $env:USERPROFILE 'Desktop'),(Join-Path $env:LOCALAPPDATA 'NovaGrid'))){
  if(!(Test-Path -LiteralPath $folder -PathType Container)){continue}
  $match=Get-ChildItem -LiteralPath $folder -Recurse -File -ErrorAction SilentlyContinue|
   Where-Object {$_.Name -match '^Godot.*4\.5\.1.*\.exe$' -and $_.Name -notmatch '_console\.exe$'}|Select-Object -First 1
  if($match){$godot=$match.FullName;break}
 }
}
if(!$godot){
 Write-Host 'Get Godot 4.5.1 Standard from https://godotengine.org/download/archive/4.5.1-stable/' -ForegroundColor Yellow
 throw 'Godot executable not found. Unzip it to Downloads and retry. No game files changed.'
}
$version=(& $godot --version|Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1\.'){throw "Godot 4.5.1 required; found $version"}
New-Item -ItemType Directory -Force -Path (Split-Path $cache -Parent)|Out-Null
Set-Content -LiteralPath $cache -Value $godot -Encoding UTF8
Write-Host "Opening NovaGrid with Godot $version" -ForegroundColor Green
$arguments=if($Play){@('--path',('"' + $project + '"'))}else{@('--editor','--path',('"' + $project + '"'))}
Start-Process -FilePath $godot -ArgumentList $arguments -WorkingDirectory $project -ErrorAction Stop
if(!$Play){Write-Host 'Godot Editor launched. Press F5 to play.' -ForegroundColor Green}
