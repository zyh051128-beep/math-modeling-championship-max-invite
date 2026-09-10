param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InviteCode,

    [string]$RepositoryUrl = 'https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git'
)

$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('math-modeling-max-release-' + [guid]::NewGuid().ToString('N'))
$cloneRoot = Join-Path $testRoot 'anonymous-clone'

try {
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
    $env:GIT_TERMINAL_PROMPT = '0'
    & git -c credential.helper= clone --depth 1 $RepositoryUrl $cloneRoot
    if ($LASTEXITCODE -ne 0) { throw 'Anonymous clone of the public repository failed.' }

    $payloadPath = Join-Path $cloneRoot 'payload\plugin-marketplace.aes'
    $shaPath = Join-Path $cloneRoot 'payload\SHA256.txt'
    if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) { throw 'The encrypted plugin package is missing.' }
    if (-not (Test-Path -LiteralPath $shaPath -PathType Leaf)) { throw 'The package checksum is missing.' }

    $expectedSha = ((Get-Content -LiteralPath $shaPath -Raw).Trim() -split '\s+')[0].ToUpperInvariant()
    $actualSha = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($expectedSha -ne $actualSha) { throw 'The encrypted package checksum does not match.' }

    $installerPath = Join-Path $cloneRoot 'install.ps1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -InviteCode $InviteCode -VerifyOnly
    if ($LASTEXITCODE -ne 0) { throw 'The valid invitation code failed verification.' }

    $wrongCode = 'invalid-' + [guid]::NewGuid().ToString('N')
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -InviteCode $wrongCode -VerifyOnly 2>$null
    if ($LASTEXITCODE -eq 0) { throw 'An invalid invitation code was not rejected.' }

    $readme = Get-Content -LiteralPath (Join-Path $cloneRoot 'README.md') -Raw
    if ($readme -match 'raw\.githubusercontent\.com') { throw 'README still depends on GitHub Raw.' }
    if ($readme -match 'marketplacePath=|C:\\Users\\') { throw 'README leaks or depends on a sender-local path.' }

    Write-Host 'Release gate passed: anonymous clone, checksum, valid-code decrypt, and invalid-code rejection.'
}
finally {
    Remove-Item Env:GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue
    $resolvedTest = [IO.Path]::GetFullPath($testRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedTest.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedTest)) {
        Remove-Item -LiteralPath $resolvedTest -Recurse -Force
    }
}
