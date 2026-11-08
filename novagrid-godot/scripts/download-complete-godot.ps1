# NovaGrid Godot full source + premium artwork. No manual ZIP required.
param([switch]$DownloadOnly,[switch]$EditorOnly)
$ErrorActionPreference='Stop'
$ProgressPreference='SilentlyContinue'
$branch='novagrid-godot-admob-test-20261107'
$root=Join-Path $env:USERPROFILE ('NovaGrid-Godot-Full\Run-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $root | Out-Null

function Grab([string]$url,[string]$dest) {
 New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent)|Out-Null
 for($i=1;$i -le 3;$i++){
  try {
   Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 180
   if((Get-Item $dest).Length -lt 100){throw 'Empty or truncated download'}
   return
  }catch{
   if($i -eq 3){throw "Download failed from $url : $_"}
   Start-Sleep -Seconds ($i*2)
  }
 }
}
function CheckPng([string]$p,[int]$w,[int]$h){
 [byte[]]$b=[IO.File]::ReadAllBytes($p)
 if($b.Length -lt 33 -or $b[0] -ne 137 -or $b[1] -ne 80 -or $b[2] -ne 78 -or $b[3] -ne 71){throw "Invalid PNG $p"}
 $pw=([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
 $ph=([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
 if($pw -ne $w -or $ph -ne $h){throw "Image dimensions are incorrect: $p"}
}
Write-Host '[1/4] Downloading latest Godot game from GitHub...' -ForegroundColor Cyan
$sourceZip=Join-Path $root 'novagrid-code.zip'
Grab "https://github.com/univcours/app/archive/refs/heads/$branch.zip" $sourceZip
# Extract only the Godot app from this GitHub branch ZIP to avoid
# case-insensitive Windows collisions and Expand-Archive cleanup bugs.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$project=Join-Path $root 'novagrid-godot'
New-Item -ItemType Directory -Path $project -Force | Out-Null
$archive=[System.IO.Compression.ZipFile]::OpenRead($sourceZip)
$extracted=0
try{
 foreach($entry in $archive.Entries){
  $name=$entry.FullName.Replace('\','/')
  if($name -notmatch '^[^/]+/novagrid-godot/(.+)$'){continue}
  $rel=$Matches[1]
  if($rel.EndsWith('/')){continue}
  $file=Join-Path $project ($rel.Replace('/','\'))
  $safeRoot=[IO.Path]::GetFullPath($project).TrimEnd('\')+'\'
  $safeFile=[IO.Path]::GetFullPath($file)
  if(!$safeFile.StartsWith($safeRoot,[StringComparison]::OrdinalIgnoreCase)){
   throw "Unsafe archive path: $rel"
  }
  if(Test-Path -LiteralPath $safeFile){continue}
  New-Item -ItemType Directory -Force -Path (Split-Path $safeFile -Parent)|Out-Null
  $inputStream=$entry.Open()
  $outputStream=[IO.File]::Create($safeFile)
  try{$inputStream.CopyTo($outputStream)}finally{$outputStream.Dispose();$inputStream.Dispose()}
  $extracted++
 }
}finally{$archive.Dispose()}
if($extracted -lt 15 -or !(Test-Path (Join-Path $project 'project.godot'))){
 throw "Incomplete Godot source extraction: $extracted files"
}

Write-Host '[2/4] Downloading ORIGINAL RESTORED Blockfall reference and 7 clean candy sprites from RibhLab HTTPS...' -ForegroundColor Cyan
$cdn='https://ribhlab.wordpress.com/wp-content/uploads/2026/11'
$skins=Join-Path $project 'assets\skins'
$menu=Join-Path $project 'assets\menu'
$gems=Join-Path $skins 'gems'
$neon=Join-Path $skins 'neon_exact'
New-Item -ItemType Directory -Force -Path $skins,$menu,$gems,$neon|Out-Null
$assets=@(
 @('novagrid_cosmic_candy_arcade.png',(Join-Path $menu 'novagrid_cosmic_candy_arcade.png'),941,1672),
 @('novagrid_blockfall_reference_restored_20261108.png',(Join-Path $skins 'blockfall_playable_chrome.png'),941,1672),
 @('blockpuzzle_playable_chrome.png',(Join-Path $skins 'blockpuzzle_playable_chrome.png'),941,2091),
 @('blockpuzzle_cosmic_backdrop.png',(Join-Path $skins 'blockpuzzle_cosmic_backdrop.png'),941,2091),
 @('novagrid_candy_atlas7_v2.png',(Join-Path $root 'candy_atlas7.png'),700,100),
 @('novagrid_exact_neon_board_asset.png',(Join-Path $neon 'neon_block_puzzle_empty_941x1672.png'),941,1672),
 @('novagrid_clean_7_gems_atlas_20261108.png',(Join-Path $root 'neon_reference_atlas7.png'),1792,256)
)
foreach($a in $assets){
 Grab "$cdn/$($a[0])" $a[1]
 CheckPng $a[1] $a[2] $a[3]
 Write-Host "  + $($a[0])" -ForegroundColor Green
}
Add-Type -AssemblyName System.Drawing
$atlas=[System.Drawing.Bitmap]::new((Join-Path $root 'candy_atlas7.png'))
try{
 $names=@('ruby','gold','turquoise','grapes','emerald','citrus','sapphire')
 for($i=0;$i -lt 7;$i++){
  $piece=[System.Drawing.Bitmap]::new(100,100)
  $graphic=[System.Drawing.Graphics]::FromImage($piece)
  try{
   $srcRect=[System.Drawing.Rectangle]::new($i*100,0,100,100)
   $dstRect=[System.Drawing.Rectangle]::new(0,0,100,100)
   $graphic.DrawImage($atlas,$dstRect,$srcRect,[System.Drawing.GraphicsUnit]::Pixel)
   $file=Join-Path $gems ('candy_'+($i+1)+'_'+$names[$i]+'.png')
   $piece.Save($file,[System.Drawing.Imaging.ImageFormat]::Png)
   CheckPng $file 100 100
  }finally{$graphic.Dispose();$piece.Dispose()}
 }
 }finally{$atlas.Dispose()}
# The seven vivid transparent crystals are taken directly from the exact
# Block Puzzle image selected by the owner. Retain legacy atlas for Blockfall.
$neonAtlas=[System.Drawing.Bitmap]::new((Join-Path $root 'neon_reference_atlas7.png'))
try{
 for($i=0;$i -lt 7;$i++){
  $piece=[System.Drawing.Bitmap]::new(256,256)
  $graphic=[System.Drawing.Graphics]::FromImage($piece)
  try{
   $srcRect=[System.Drawing.Rectangle]::new($i*256,0,256,256)
   $dstRect=[System.Drawing.Rectangle]::new(0,0,256,256)
   $graphic.DrawImage($neonAtlas,$dstRect,$srcRect,[System.Drawing.GraphicsUnit]::Pixel)
   $file=Join-Path $neon ('gem_'+($i+1)+'.png')
   $piece.Save($file,[System.Drawing.Imaging.ImageFormat]::Png)
   CheckPng $file 256 256
  }finally{$graphic.Dispose();$piece.Dispose()}
 }
}finally{$neonAtlas.Dispose()}
foreach($f in @('project.godot','scripts\Main.gd','assets\skins\blockfall_playable_chrome.png',
 'assets\skins\blockpuzzle_playable_chrome.png','assets\skins\gems\candy_7_sapphire.png',
 'assets\skins\neon_exact\neon_block_puzzle_empty_941x1672.png',
 'assets\skins\neon_exact\gem_7.png')){
 if(!(Test-Path -LiteralPath (Join-Path $project $f))){throw "Missing file $f"}
}
Write-Host "FULL NOVAGRID SOURCE + ART VERIFIED: $project" -ForegroundColor Green
if($DownloadOnly){return}

Write-Host '[3/4] Finding existing Godot 4.5.1 or installing official portable...' -ForegroundColor Cyan
$choices=@()
if($env:GODOT_EXE){$choices+=$env:GODOT_EXE}
$cache=Join-Path $env:LOCALAPPDATA 'NovaGrid\godot-exe.txt'
if(Test-Path $cache){$choices+=(Get-Content $cache -Raw).Trim()}
foreach($n in @('godot.exe','Godot_v4.5.1-stable_win64.exe')){
 $cmd=Get-Command $n -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
 if($cmd){$choices+=$cmd.Source}
}
foreach($dir in @((Join-Path $env:USERPROFILE 'Downloads'),
 (Join-Path $env:USERPROFILE 'Desktop'),(Join-Path $env:LOCALAPPDATA 'NovaGrid'))){
 if(Test-Path $dir){
  $choices+=@(Get-ChildItem -LiteralPath $dir -Recurse -File -ErrorAction SilentlyContinue|
   Where-Object {$_.Name -match 'Godot.*4\.5\.1.*\.exe$' -and $_.Name -notmatch '_console\.exe$'}|
   Select-Object -First 3 -ExpandProperty FullName)
 }
}
$godot=$null
foreach($p in $choices){
 if(!$p -or !(Test-Path $p -PathType Leaf)){continue}
 $v=(& $p --version | Out-String).Trim()
 if($LASTEXITCODE -eq 0 -and $v -match '^4\.5\.1\.'){$godot=$p;break}
}
if(!$godot){
 $dir=Join-Path $env:LOCALAPPDATA 'NovaGrid\Godot-4.5.1'
 New-Item -ItemType Directory -Force -Path $dir | Out-Null
 $zip=Join-Path $dir 'godot451.zip'
 Grab 'https://github.com/godotengine/godot-builds/releases/download/4.5.1-stable/Godot_v4.5.1-stable_win64.exe.zip' $zip
 Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
 $exe=Get-ChildItem -LiteralPath $dir -Recurse -File |
  Where-Object {$_.Name -match 'Godot.*4\.5\.1.*win64\.exe$' -and $_.Name -notmatch '_console\.exe$'}|
  Select-Object -First 1
 if(!$exe){throw 'Godot executable missing from official download'}
 $godot=$exe.FullName
}
$v=(& $godot --version | Out-String).Trim()
if($LASTEXITCODE -ne 0 -or $v -notmatch '^4\.5\.1\.'){throw "Godot version must be 4.5.1; found $v"}
New-Item -ItemType Directory -Force -Path (Split-Path $cache -Parent)|Out-Null
Set-Content -LiteralPath $cache -Value $godot

Write-Host '[4/4] Importing artwork and starting Godot Editor + game...' -ForegroundColor Cyan
& $godot --headless --editor --path $project --quit
if($LASTEXITCODE -ne 0){throw 'Godot import failed'}
$q='"'+$project+'"'
Start-Process -FilePath $godot -ArgumentList @('--editor','--path',$q) -WorkingDirectory $project
if(!$EditorOnly){Start-Process -FilePath $godot -ArgumentList @('--path',$q) -WorkingDirectory $project}
Write-Host "NOVAGRID READY! PROJECT: $project" -ForegroundColor Green
