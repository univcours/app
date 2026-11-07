# Pull latest playable NovaGrid Godot and open editor + game on Windows.
param([switch]$EditorOnly)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$branch='novagrid-godot-admob-test-20261107'
$root=Join-Path $env:USERPROFILE 'NovaGrid-Godot-Auto'
$project=Join-Path $root 'novagrid-godot'
function Check([string]$step) {if($LASTEXITCODE -ne 0){throw "$step failed (exit $LASTEXITCODE)"}}
Write-Host '1/4 Downloading or updating NovaGrid Godot...' -ForegroundColor Cyan
if(!(Get-Command git.exe -ErrorAction SilentlyContinue)){throw 'Git for Windows required.'}
if(Test-Path (Join-Path $root '.git')){
 $origin=(& git -C $root remote get-url origin | Out-String).Trim()
 Check 'Git remote check'
 if($origin -notmatch '(^|[/:])univcours/app(\.git)?$'){throw "Unexpected Git remote: $origin"}
 $current=(& git -C $root branch --show-current | Out-String).Trim()
 Check 'Git branch check'
 if($current -ne $branch){throw "Existing project on another branch: $current"}
 $changes=@(& git -C $root status --porcelain --untracked-files=no)
 Check 'Git changes'
 if($changes.Count -gt 0){throw 'Existing edits preserved; update not attempted.'}
 & git -C $root pull --ff-only origin $branch
 Check 'Git pull'
}else{
 if(Test-Path $root){throw "Existing non-Git directory: $root"}
 & git clone --depth 1 --filter=blob:none --sparse --branch $branch 'https://github.com/univcours/app.git' $root
 Check 'Git clone'
}
& git -C $root sparse-checkout set novagrid-godot
Check 'Sparse checkout'
if(!(Test-Path (Join-Path $project 'project.godot'))){throw 'Missing project.godot'}
Write-Host "Project source: $project"

# Recover copyrighted/AI reference PNG assets from previously delivered ZIPs
# on THIS user's PC. Github source has gameplay code but not the original PNGs.
Write-Host '2/4 Checking available NovaGrid reference artwork...' -ForegroundColor Cyan
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$assetRoot=Join-Path $project 'assets'
$dirs=@((Join-Path $env:USERPROFILE 'Downloads'),(Join-Path $env:USERPROFILE 'Desktop'))
$archives=@()
foreach($dir in $dirs){
 if(Test-Path $dir){
  $archives+=@(Get-ChildItem -LiteralPath $dir -File -Recurse -Filter 'NovaGrid*.zip' -ErrorAction SilentlyContinue)
 }
}
foreach($file in @($archives|Sort-Object LastWriteTime -Descending|Select-Object -First 25)){
 try{
  $zip=[IO.Compression.ZipFile]::OpenRead($file.FullName)
  try{
   foreach($entry in $zip.Entries){
    $name=$entry.FullName.Replace('\','/')
    if($name -notmatch '(?:^|/)assets/(skins/(?:gems/)?[A-Za-z0-9_-]+\.png|menu/novagrid_cosmic_candy_arcade\.png)$'){continue}
    $rel=$Matches[1]
    if($rel -notmatch '^skins/(blockfall_exact_reference|blockfall_playable_chrome|blockpuzzle_cosmic_backdrop)\.png -and
       $rel -notmatch '^skins/gems/candy_[1-7]_[a-z]+\.png$' -and
       $rel -ne 'menu/novagrid_cosmic_candy_arcade.png'){continue}
    if($entry.Length -lt 200 -or $entry.Length -gt 12000000){continue}
    $dest=Join-Path $assetRoot ($rel.Replace('/','\'))
    if(Test-Path $dest){continue}
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent)|Out-Null
    $a=$entry.Open()
    $b=[IO.File]::Create($dest)
    try{$a.CopyTo($b)}finally{$b.Dispose();$a.Dispose()}
    Write-Host "Recovered: $rel"
   }
  }finally{$zip.Dispose()}
 }catch{Write-Warning "Cannot inspect $($file.Name): $($_.Exception.Message)"}
}
$menu=Test-Path (Join-Path $assetRoot 'menu\novagrid_cosmic_candy_arcade.png')
$fall=Test-Path (Join-Path $assetRoot 'skins\blockfall_playable_chrome.png')
if(!$menu -or !$fall){
 Write-Warning 'Exact original images not on this computer. Source-only shader design will be used for missing images.'
}
Write-Host "Reference assets: menu=$menu, Blockfall=$fall"

Write-Host '3/4 Finding installed Godot 4.5.1...' -ForegroundColor Cyan
$cache=Join-Path $env:LOCALAPPDATA 'NovaGrid\godot-exe.txt'
$candidates=@()
if($env:GODOT_EXE){$candidates+=$env:GODOT_EXE}
if(Test-Path $cache){$candidates+=(Get-Content $cache -Raw).Trim()}
foreach($name in @('godot.exe','Godot_v4.5.1-stable_win64.exe')){
 $cmd=Get-Command $name -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
 if($cmd){$candidates+=$cmd.Source}
}
foreach($d in @((Join-Path $env:USERPROFILE 'Downloads'),(Join-Path $env:USERPROFILE 'Desktop'),
 (Join-Path $env:LOCALAPPDATA 'NovaGrid'),(Join-Path $env:LOCALAPPDATA 'Programs\Godot'))){
 if(!(Test-Path $d)){continue}
 $candidates+=@(Get-ChildItem -LiteralPath $d -File -Recurse -ErrorAction SilentlyContinue|
  Where-Object {$_.Name -match '^Godot.*4\.5\.1.*\.exe$' -and $_.Name -notmatch '_console\.exe$'}|
  Select-Object -First 3 -ExpandProperty FullName)
}
$godot=$null
foreach($candidate in $candidates){
 if(!$candidate -or !(Test-Path $candidate -PathType Leaf)){continue}
 $v=(& $candidate --version | Out-String).Trim()
 if($LASTEXITCODE -eq 0 -and $v -match '^4\.5\.1\.'){$godot=$candidate;break}
}
if(!$godot){
 $folder=Join-Path $env:LOCALAPPDATA 'NovaGrid\Godot-4.5.1'
 New-Item -ItemType Directory -Path $folder -Force|Out-Null
 $zipFile=Join-Path $folder 'Godot-4.5.1.zip'
 Write-Host 'Downloading official portable Godot 4.5.1...' -ForegroundColor Yellow
 Invoke-WebRequest -Uri 'https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/Godot_v4.5.1-stable_win64.exe.zip' -OutFile $zipFile
 Expand-Archive -LiteralPath $zipFile -DestinationPath $folder -Force
 $found=Get-ChildItem -LiteralPath $folder -File -Recurse|
  Where-Object {$_.Name -match '^Godot.*4\.5\.1.*win64\.exe$' -and $_.Name -notmatch '_console\.exe$'}|
  Select-Object -First 1
 if(!$found){throw 'Official Godot executable not found'}
 $godot=$found.FullName
}
$version=(& $godot --version | Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1\.'){throw "Wrong Godot version: $version"}
New-Item -ItemType Directory -Path (Split-Path $cache -Parent) -Force|Out-Null
Set-Content -LiteralPath $cache -Value $godot -Encoding UTF8

Write-Host '4/4 Importing and opening NovaGrid Editor AND game...' -ForegroundColor Cyan
& $godot --headless --editor --path $project --quit
Check 'Godot import'
$quoted='"'+$project+'"'
Start-Process -FilePath $godot -ArgumentList @('--editor','--path',$quoted) -WorkingDirectory $project
if(!$EditorOnly){Start-Process -FilePath $godot -ArgumentList @('--path',$quoted) -WorkingDirectory $project}
Write-Host "SUCCESS! NovaGrid opened: $project" -ForegroundColor Green
 -and
       $rel -notmatch '^skins/gems/candy_[1-7]_[a-z]+\.png$' -and
       $rel -ne 'menu/novagrid_cosmic_candy_arcade.png'){continue}
    if($entry.Length -lt 200 -or $entry.Length -gt 12000000){continue}
    $dest=Join-Path $assetRoot ($rel.Replace('/','\'))
    if(Test-Path $dest){continue}
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent)|Out-Null
    $a=$entry.Open()
    $b=[IO.File]::Create($dest)
    try{$a.CopyTo($b)}finally{$b.Dispose();$a.Dispose()}
    Write-Host "Recovered: $rel"
   }
  }finally{$zip.Dispose()}
 }catch{Write-Warning "Cannot inspect $($file.Name): $($_.Exception.Message)"}
}
$menu=Test-Path (Join-Path $assetRoot 'menu\novagrid_cosmic_candy_arcade.png')
$fall=Test-Path (Join-Path $assetRoot 'skins\blockfall_playable_chrome.png')
if(!$menu -or !$fall){
 Write-Warning 'Exact original images not on this computer. Source-only shader design will be used for missing images.'
}
Write-Host "Reference assets: menu=$menu, Blockfall=$fall"

Write-Host '3/4 Finding installed Godot 4.5.1...' -ForegroundColor Cyan
$cache=Join-Path $env:LOCALAPPDATA 'NovaGrid\godot-exe.txt'
$candidates=@()
if($env:GODOT_EXE){$candidates+=$env:GODOT_EXE}
if(Test-Path $cache){$candidates+=(Get-Content $cache -Raw).Trim()}
foreach($name in @('godot.exe','Godot_v4.5.1-stable_win64.exe')){
 $cmd=Get-Command $name -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
 if($cmd){$candidates+=$cmd.Source}
}
foreach($d in @((Join-Path $env:USERPROFILE 'Downloads'),(Join-Path $env:USERPROFILE 'Desktop'),
 (Join-Path $env:LOCALAPPDATA 'NovaGrid'),(Join-Path $env:LOCALAPPDATA 'Programs\Godot'))){
 if(!(Test-Path $d)){continue}
 $candidates+=@(Get-ChildItem -LiteralPath $d -File -Recurse -ErrorAction SilentlyContinue|
  Where-Object {$_.Name -match '^Godot.*4\.5\.1.*\.exe$' -and $_.Name -notmatch '_console\.exe$'}|
  Select-Object -First 3 -ExpandProperty FullName)
}
$godot=$null
foreach($candidate in $candidates){
 if(!$candidate -or !(Test-Path $candidate -PathType Leaf)){continue}
 $v=(& $candidate --version | Out-String).Trim()
 if($LASTEXITCODE -eq 0 -and $v -match '^4\.5\.1\.'){$godot=$candidate;break}
}
if(!$godot){
 $folder=Join-Path $env:LOCALAPPDATA 'NovaGrid\Godot-4.5.1'
 New-Item -ItemType Directory -Path $folder -Force|Out-Null
 $zipFile=Join-Path $folder 'Godot-4.5.1.zip'
 Write-Host 'Downloading official portable Godot 4.5.1...' -ForegroundColor Yellow
 Invoke-WebRequest -Uri 'https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/Godot_v4.5.1-stable_win64.exe.zip' -OutFile $zipFile
 Expand-Archive -LiteralPath $zipFile -DestinationPath $folder -Force
 $found=Get-ChildItem -LiteralPath $folder -File -Recurse|
  Where-Object {$_.Name -match '^Godot.*4\.5\.1.*win64\.exe$' -and $_.Name -notmatch '_console\.exe$'}|
  Select-Object -First 1
 if(!$found){throw 'Official Godot executable not found'}
 $godot=$found.FullName
}
$version=(& $godot --version | Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.5\.1\.'){throw "Wrong Godot version: $version"}
New-Item -ItemType Directory -Path (Split-Path $cache -Parent) -Force|Out-Null
Set-Content -LiteralPath $cache -Value $godot -Encoding UTF8

Write-Host '4/4 Importing and opening NovaGrid Editor AND game...' -ForegroundColor Cyan
& $godot --headless --editor --path $project --quit
Check 'Godot import'
$quoted='"'+$project+'"'
Start-Process -FilePath $godot -ArgumentList @('--editor','--path',$quoted) -WorkingDirectory $project
if(!$EditorOnly){Start-Process -FilePath $godot -ArgumentList @('--path',$quoted) -WorkingDirectory $project}
Write-Host "SUCCESS! NovaGrid opened: $project" -ForegroundColor Green
