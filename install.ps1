param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InviteCode,

    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
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
        if ($LASTEXITCODE -ne 0) { throw '无法克隆公开邀请仓库，请检查 GitHub 网络连接。' }
        $payloadPath = Join-Path $distributionPath 'payload\plugin-marketplace.aes'
        if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            throw '邀请仓库缺少加密插件包。'
        }
    }

    $blob = [IO.File]::ReadAllBytes($payloadPath)
    $magic = [Text.Encoding]::ASCII.GetBytes('MMCMAX1')
    if ($blob.Length -lt 56) { throw '邀请包损坏或不完整。' }
    for ($i = 0; $i -lt $magic.Length; $i++) {
        if ($blob[$i] -ne $magic[$i]) { throw '邀请包格式不受支持。' }
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
    if (-not [Security.Cryptography.CryptographicOperations]::FixedTimeEquals($actualMac, $expectedMac)) {
        throw '邀请链接无效、已撤销，或邀请包已损坏。'
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
    $manifestPath = Join-Path $extractPath 'plugins\math-modeling-championship-max\.codex-plugin\plugin.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw '解密包缺少插件清单。' }
    $version = (Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json).version
    if ($VerifyOnly) {
        Write-Host ('邀请包验证通过：数学建模竞赛超级套件 MAX ' + $version)
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

    & codex plugin marketplace add $installRoot
    if ($LASTEXITCODE -ne 0) { throw '添加邀请插件市场失败。' }
    & codex plugin add 'math-modeling-championship-max@zyh-mathmodel-private'
    if ($LASTEXITCODE -ne 0) { throw '安装 MAX 插件失败。' }
    Write-Host ('安装成功：数学建模竞赛超级套件 MAX ' + $version)
    Write-Host '请新建一个 Codex 任务后开始使用。'
}
finally {
    $resolvedWork = [IO.Path]::GetFullPath($workRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedWork.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedWork)) {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force
    }
}
