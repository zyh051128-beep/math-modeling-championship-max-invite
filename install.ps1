param(
    [ValidateNotNullOrEmpty()]
    [string]$InviteCode,

    [ValidateNotNullOrEmpty()]
    [string]$InviteUrl,

    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($InviteCode) -and -not [string]::IsNullOrWhiteSpace($InviteUrl)) {
    try {
        $inviteUri = [Uri]$InviteUrl
        $fragment = $inviteUri.Fragment.TrimStart('#')
        foreach ($part in ($fragment -split '&')) {
            $pair = $part -split '=', 2
            if ($pair.Length -eq 2 -and $pair[0] -eq 'invite') {
                $InviteCode = [Uri]::UnescapeDataString($pair[1])
                break
            }
        }
    }
    catch {
        throw 'The supplied invitation URL is not valid.'
    }
}
if ([string]::IsNullOrWhiteSpace($InviteCode)) {
    throw 'Supply either -InviteUrl with the complete invitation link or -InviteCode with the invitation code.'
}

$payloadPath = Join-Path $PSScriptRoot 'payload\plugin-marketplace.aes'
$workRoot = Join-Path ([IO.Path]::GetTempPath()) ('math-modeling-max-' + [guid]::NewGuid().ToString('N'))
$zipPath = Join-Path $workRoot 'marketplace.zip'
$extractPath = Join-Path $workRoot 'marketplace'

function Get-Sha256Bytes([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
    }
    finally {
        $sha.Dispose()
    }
}

try {
    New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
    if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
        $distributionPath = Join-Path $workRoot 'distribution'
        & git clone --depth 1 'https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git' $distributionPath
        if ($LASTEXITCODE -ne 0) { throw 'Unable to clone the public invitation repository. Check GitHub connectivity.' }
        $payloadPath = Join-Path $distributionPath 'payload\plugin-marketplace.aes'
        if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            throw 'The invitation repository does not contain the encrypted plugin package.'
        }
    }

    $blob = [IO.File]::ReadAllBytes($payloadPath)
    $magic = [Text.Encoding]::ASCII.GetBytes('MMCMAX1')
    if ($blob.Length -lt 56) { throw 'The invitation package is incomplete or corrupted.' }
    for ($i = 0; $i -lt $magic.Length; $i++) {
        if ($blob[$i] -ne $magic[$i]) { throw 'Unsupported invitation package format.' }
    }

    $iv = New-Object byte[] 16
    [Array]::Copy($blob, 7, $iv, 0, 16)
    $cipherLength = $blob.Length - 7 - 16 - 32
    $cipher = New-Object byte[] $cipherLength
    [Array]::Copy($blob, 23, $cipher, 0, $cipherLength)
    $expectedMac = New-Object byte[] 32
    [Array]::Copy($blob, 23 + $cipherLength, $expectedMac, 0, 32)

    $authKey = Get-Sha256Bytes ('auth:' + $InviteCode)
    $hmac = New-Object Security.Cryptography.HMACSHA256(,$authKey)
    try {
        $actualMac = $hmac.ComputeHash($blob, 0, 23 + $cipherLength)
    }
    finally {
        $hmac.Dispose()
    }
    $macDifference = 0
    if ($actualMac.Length -ne $expectedMac.Length) {
        $macDifference = 1
    }
    else {
        for ($i = 0; $i -lt $actualMac.Length; $i++) {
            $macDifference = $macDifference -bor ($actualMac[$i] -bxor $expectedMac[$i])
        }
    }
    if ($macDifference -ne 0) {
        throw 'The invitation is invalid, revoked, or the package is corrupted.'
    }

    $aes = [Security.Cryptography.Aes]::Create()
    try {
        $aes.Key = Get-Sha256Bytes $InviteCode
        $aes.IV = $iv
        $aes.Mode = [Security.Cryptography.CipherMode]::CBC
        $aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
        $decryptor = $aes.CreateDecryptor()
        try {
            $plain = $decryptor.TransformFinalBlock($cipher, 0, $cipher.Length)
        }
        finally {
            $decryptor.Dispose()
        }
    }
    finally {
        $aes.Dispose()
    }

    [IO.File]::WriteAllBytes($zipPath, $plain)
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath
    $pluginRoot = Join-Path $extractPath 'plugins\math-modeling-championship-max'
    $manifestPath = Join-Path $pluginRoot '.codex-plugin\plugin.json'
    $requiredEntrypoints = @(
        $manifestPath,
        (Join-Path $pluginRoot 'skills\math-modeling-championship-max\SKILL.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship\SKILL.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship\scripts\doctor.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship\scripts\state_manager.py')
    )
    foreach ($requiredEntrypoint in $requiredEntrypoints) {
        if (-not (Test-Path -LiteralPath $requiredEntrypoint -PathType Leaf)) {
            throw ('The decrypted package is incomplete. Missing: ' + $requiredEntrypoint.Substring($pluginRoot.Length).TrimStart('\'))
        }
    }
    $version = (Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json).version
    if ($VerifyOnly) {
        Write-Host ('Invitation package verified: Math Modeling Championship MAX ' + $version)
        return
    }
    $safeVersion = $version -replace '[^A-Za-z0-9._-]', '-'
    $installParent = Join-Path $env:USERPROFILE 'codex-invited-marketplaces'
    $installRoot = Join-Path $installParent ('math-modeling-championship-max-' + $safeVersion)
    if (Test-Path -LiteralPath $installRoot) {
        $installRoot += '-' + (Get-Date -Format 'yyyyMMddHHmmss')
    }
    New-Item -ItemType Directory -Force -Path $installParent | Out-Null
    Copy-Item -LiteralPath $extractPath -Destination $installRoot -Recurse

    $existingMarketplaceNames = @()
    try {
        $marketplaceListJson = (& codex plugin marketplace list --json | Out-String)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($marketplaceListJson)) {
            $marketplaceList = $marketplaceListJson | ConvertFrom-Json
            $existingMarketplaceNames = @($marketplaceList.marketplaces | ForEach-Object { $_.name })
        }
    }
    catch {
        Write-Host 'Could not read existing plugin marketplaces; continuing with installation.'
    }

    if ($existingMarketplaceNames -contains 'zyh-mathmodel-private') {
        & codex plugin marketplace remove 'zyh-mathmodel-private'
        if ($LASTEXITCODE -ne 0) { throw 'Unable to replace the previous invited marketplace.' }
    }

    & codex plugin marketplace add $installRoot
    if ($LASTEXITCODE -ne 0) { throw 'Unable to add the invited plugin marketplace.' }
    & codex plugin add 'math-modeling-championship-max@zyh-mathmodel-private'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to install the MAX plugin.' }
    $doctorPath = Join-Path $installRoot 'plugins\math-modeling-championship-max\skills\math-modeling-championship-max\scripts\max_doctor.ps1'
    $doctorJson = (& powershell -NoProfile -ExecutionPolicy Bypass -File $doctorPath -Delivery word -Profile core | Out-String)
    $doctorExitCode = $LASTEXITCODE
    if ($doctorExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($doctorJson)) {
        throw 'The plugin was copied, but its built-in Doctor did not complete successfully.'
    }
    $doctorReport = $doctorJson | ConvertFrom-Json
    if (-not $doctorReport.ready -or
        -not $doctorReport.base_suite.available -or
        @($doctorReport.blocking_failures).Count -ne 0) {
        throw 'The plugin installation is incomplete according to the built-in Doctor.'
    }
    Write-Host ('Installed: Math Modeling Championship MAX ' + $version)
    Write-Host 'Doctor passed: MAX and the bundled base suite are complete.'
    Write-Host 'Create a new Codex task before using the updated plugin.'
}
finally {
    $resolvedWork = [IO.Path]::GetFullPath($workRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedWork.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedWork)) {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force
    }
}
