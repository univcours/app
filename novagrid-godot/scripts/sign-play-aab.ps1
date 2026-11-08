# Sign a verified official NovaGrid AAB with its EXISTING Play upload key.
# Private signing values are prompted, not committed, logged, or passed as CLI arguments.
param(
    [Parameter(Mandatory=$true)][string]$UnsignedAab,
    [Parameter(Mandatory=$true)][string]$OriginalKeystore,
    [Parameter(Mandatory=$true)][string]$KeyAlias,
    [string]$SignedOutput = ''
)
$ErrorActionPreference = 'Stop'
$unsigned = (Resolve-Path -LiteralPath $UnsignedAab).Path
$keystore = (Resolve-Path -LiteralPath $OriginalKeystore).Path
if ([IO.Path]::GetExtension($unsigned).ToLowerInvariant() -ne '.aab') {
    throw 'The input must be an Android App Bundle'
}
if ((Get-Item -LiteralPath $unsigned).Length -lt 100000) {
    throw 'AAB is too small or empty'
}
if ($KeyAlias -notmatch '^[a-zA-Z0-9_.-]+$') {
    throw 'Invalid alias characters'
}
if ([string]::IsNullOrWhiteSpace($SignedOutput)) {
    $SignedOutput = Join-Path (Split-Path -Parent $unsigned) 'NovaGrid-Cosmic-Play-SIGNED.aab'
}
$output = [IO.Path]::GetFullPath($SignedOutput)
if ($output -eq $unsigned -or (Test-Path -LiteralPath $output)) {
    throw 'Output exists or overlaps input; refusing overwrite'
}
function TemporaryPlaintext([Security.SecureString]$value) {
    $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
$storeSecret = Read-Host 'Existing upload-keystore password' -AsSecureString
$keySecret = Read-Host 'Existing upload-key password' -AsSecureString
try {
    $env:NOVAGRID_STORE_PASS=TemporaryPlaintext $storeSecret
    $env:NOVAGRID_KEY_PASS=TemporaryPlaintext $keySecret
    & keytool -list -keystore $keystore -alias $KeyAlias -storepass:env NOVAGRID_STORE_PASS | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Upload keystore or alias is invalid' }
    & jarsigner -keystore $keystore -storepass:env NOVAGRID_STORE_PASS -keypass:env NOVAGRID_KEY_PASS -signedjar $output $unsigned $KeyAlias
    if ($LASTEXITCODE -ne 0) { throw 'jarsigner failed to sign' }
    $verification = & jarsigner -verify -verbose $output 2>&1
    if ($LASTEXITCODE -ne 0 -or !($verification -match 'jar verified\.')) {
        throw 'The AAB signature did not verify'
    }
    Write-Host 'NovaGrid signed bundle verified:' -ForegroundColor Green
    Write-Host $output
    Write-Host 'Upload certificate SHA256 (compare with Google Play Console):'
    & keytool -list -v -keystore $keystore -alias $KeyAlias -storepass:env NOVAGRID_STORE_PASS | Select-String 'SHA256:'
    Get-FileHash -LiteralPath $output -Algorithm SHA256
} finally {
    Remove-Item Env:NOVAGRID_STORE_PASS -ErrorAction SilentlyContinue
    Remove-Item Env:NOVAGRID_KEY_PASS -ErrorAction SilentlyContinue
}
