param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InviteCode,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CanonicalPluginRoot
)

$ErrorActionPreference = 'Stop'

if ($InviteCode.Length -lt 32 -or ($InviteCode.ToCharArray() | Select-Object -Unique).Count -lt 16) {
    throw 'InviteCode must contain at least 32 characters and at least 16 distinct characters.'
}
$root = $PSScriptRoot
$source = Join-Path $root 'build\marketplace'
$zip = Join-Path $root 'build\plugin-marketplace.zip'
$output = Join-Path $root 'payload\plugin-marketplace.aes'
$checksum = Join-Path $root 'payload\SHA256.txt'
$invitePluginRoot = Join-Path $source 'plugins\math-modeling-championship-max'

$canonicalResolved = [IO.Path]::GetFullPath($CanonicalPluginRoot).TrimEnd('\')
if (-not (Test-Path -LiteralPath $canonicalResolved -PathType Container)) {
    throw ('CanonicalPluginRoot does not exist: ' + $canonicalResolved)
}
$canonicalManifest = Join-Path $canonicalResolved '.codex-plugin\plugin.json'
if (-not (Test-Path -LiteralPath $canonicalManifest -PathType Leaf)) {
    throw ('Canonical plugin manifest is missing: ' + $canonicalManifest)
}

# Rebuild the encrypted marketplace from the canonical plugin every time so an
# old ignored build directory can never silently become the invited release.
$sourceResolved = [IO.Path]::GetFullPath($source)
$expectedBuildParent = [IO.Path]::GetFullPath((Join-Path $root 'build')).TrimEnd('\')
if ([IO.Path]::GetDirectoryName($sourceResolved).TrimEnd('\') -ne $expectedBuildParent) {
    throw ('Unsafe build source path: ' + $sourceResolved)
}
if (Test-Path -LiteralPath $sourceResolved) {
    Remove-Item -LiteralPath $sourceResolved -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $sourceResolved '.agents\plugins') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $sourceResolved 'plugins') | Out-Null
Copy-Item -LiteralPath $canonicalResolved -Destination $invitePluginRoot -Recurse
Get-ChildItem -LiteralPath $invitePluginRoot -Recurse -Directory -Filter '__pycache__' |
    Remove-Item -Recurse -Force
Get-ChildItem -LiteralPath $invitePluginRoot -Recurse -File -Filter '*.pyc' |
    Remove-Item -Force
$marketplace = [ordered]@{
    name = 'zyh-mathmodel-private'
    interface = [ordered]@{ displayName = '数模-MAXx 私有市场' }
    plugins = @(
        [ordered]@{
            name = 'math-modeling-championship-max'
            source = [ordered]@{ source = 'local'; path = './plugins/math-modeling-championship-max' }
            policy = [ordered]@{ installation = 'AVAILABLE'; authentication = 'ON_INSTALL' }
            category = 'Education'
        }
    )
}
$marketplacePath = Join-Path $sourceResolved '.agents\plugins\marketplace.json'
[IO.File]::WriteAllText(
    $marketplacePath,
    (($marketplace | ConvertTo-Json -Depth 8) + [Environment]::NewLine),
    [Text.UTF8Encoding]::new($false)
)

& (Join-Path $root 'parity_gate.ps1') -CanonicalPluginRoot $canonicalResolved -InvitePluginRoot $invitePluginRoot

Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path -LiteralPath $zip) {
    [IO.File]::Delete([IO.Path]::GetFullPath($zip))
}
[IO.Compression.ZipFile]::CreateFromDirectory(
    $source,
    $zip,
    [IO.Compression.CompressionLevel]::Optimal,
    $false
)

$plain = [IO.File]::ReadAllBytes($zip)
$sha = [Security.Cryptography.SHA256]::Create()
try {
    $key = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($InviteCode))
    $authKey = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('auth:' + $InviteCode))
}
finally {
    $sha.Dispose()
}

$iv = New-Object byte[] 16
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
try {
    $rng.GetBytes($iv)
}
finally {
    $rng.Dispose()
}
$aes = [Security.Cryptography.Aes]::Create()
try {
    $aes.Key = $key
    $aes.IV = $iv
    $aes.Mode = [Security.Cryptography.CipherMode]::CBC
    $aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
    $encryptor = $aes.CreateEncryptor()
    try {
        $cipher = $encryptor.TransformFinalBlock($plain, 0, $plain.Length)
    }
    finally {
        $encryptor.Dispose()
    }
}
finally {
    $aes.Dispose()
}

$magic = [Text.Encoding]::ASCII.GetBytes('MMCMAX1')
$prefix = New-Object byte[] ($magic.Length + $iv.Length + $cipher.Length)
[Array]::Copy($magic, 0, $prefix, 0, $magic.Length)
[Array]::Copy($iv, 0, $prefix, $magic.Length, $iv.Length)
[Array]::Copy($cipher, 0, $prefix, $magic.Length + $iv.Length, $cipher.Length)

$hmac = New-Object Security.Cryptography.HMACSHA256(,$authKey)
try {
    $mac = $hmac.ComputeHash($prefix)
}
finally {
    $hmac.Dispose()
}

$blob = New-Object byte[] ($prefix.Length + $mac.Length)
[Array]::Copy($prefix, 0, $blob, 0, $prefix.Length)
[Array]::Copy($mac, 0, $blob, $prefix.Length, $mac.Length)
[IO.File]::WriteAllBytes($output, $blob)
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $output).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($checksum, $hash + '  plugin-marketplace.aes' + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
Write-Host ('Encrypted invitation package: ' + $output)
Write-Host ('SHA-256: ' + $hash)
