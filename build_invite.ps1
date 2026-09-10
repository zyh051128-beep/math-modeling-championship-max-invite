param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InviteCode
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$source = Join-Path $root 'build\marketplace'
$zip = Join-Path $root 'build\plugin-marketplace.zip'
$output = Join-Path $root 'payload\plugin-marketplace.aes'
$checksum = Join-Path $root 'payload\SHA256.txt'

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
[Security.Cryptography.RandomNumberGenerator]::Fill($iv)
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

