param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InviteCode,

    [string]$RepositoryUrl = 'https://github.com/zyh051128-beep/math-modeling-championship-max-invite.git',

    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('math-modeling-max-release-' + [guid]::NewGuid().ToString('N'))
$cloneRoot = Join-Path $testRoot 'anonymous-clone'

function Test-ReleasePython([string]$Candidate) {
    if ([string]::IsNullOrWhiteSpace($Candidate) -or
        $Candidate -match '(?i)[\\/]Microsoft[\\/]WindowsApps[\\/]python(?:3)?\.exe$' -or
        -not (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
        return $false
    }
    $previousErrorAction = $ErrorActionPreference
    try {
        # A filesystem check is insufficient on Windows: the Microsoft Store
        # aliases are real .exe files but return 9009 instead of running Python.
        $ErrorActionPreference = 'Continue'
        & $Candidate -I -c "import platform,sys; import cryptography; raise SystemExit(0 if platform.python_implementation() == 'CPython' and sys.version_info >= (3, 11) else 2)" *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }
}

function Resolve-ReleasePython([string]$ExplicitPath) {
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        if (Test-ReleasePython $ExplicitPath) { return (Resolve-Path -LiteralPath $ExplicitPath).Path }
        throw 'The supplied -PythonPath is not a runnable CPython 3.11+ interpreter.'
    }

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:MATHMODEL_PYTHON)) {
        $candidates += $env:MATHMODEL_PYTHON
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $candidates += Join-Path $env:LOCALAPPDATA 'ShumoMAXx\runtime\venv\Scripts\python.exe'
        $programsPython = Join-Path $env:LOCALAPPDATA 'Programs\Python'
        if (Test-Path -LiteralPath $programsPython -PathType Container) {
            $candidates += Get-ChildItem -LiteralPath $programsPython -Filter python.exe -Recurse -File -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty FullName
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $bundled = Join-Path $env:USERPROFILE '.cache\codex-runtimes'
        if (Test-Path -LiteralPath $bundled -PathType Container) {
            $candidates += Get-ChildItem -LiteralPath $bundled -Filter python.exe -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match '\\dependencies\\python\\python\.exe$' } |
                Select-Object -ExpandProperty FullName
        }
    }
    foreach ($commandName in @('python3', 'python')) {
        $command = Get-Command $commandName -CommandType Application -ErrorAction SilentlyContinue
        if ($command) { $candidates += $command.Source }
    }
    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (Test-ReleasePython $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    throw 'Cross-platform release verification requires CPython 3.11+. Install it, set MATHMODEL_PYTHON, or supply -PythonPath.'
}

try {
    New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
    $env:GIT_TERMINAL_PROMPT = '0'
    & git -c credential.helper= clone $RepositoryUrl $cloneRoot
    if ($LASTEXITCODE -ne 0) { throw 'Anonymous clone of the public repository failed.' }

    $trackedLeak = & git -C $cloneRoot grep -I -F -l -- $InviteCode 2>$null
    if ($LASTEXITCODE -eq 0 -or $trackedLeak) { throw 'The invitation code appears in the public tracked tree.' }
    if ($LASTEXITCODE -notin @(0, 1)) { throw 'Could not scan the public tracked tree for invitation-code leakage.' }
    $historyText = (& git -C $cloneRoot log --all -p --format=fuller | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Could not scan public Git history for invitation-code leakage.' }
    if ($historyText.IndexOf($InviteCode, [StringComparison]::Ordinal) -ge 0) {
        throw 'The invitation code appears in public Git history.'
    }

    $payloadPath = Join-Path $cloneRoot 'payload\plugin-marketplace.aes'
    $shaPath = Join-Path $cloneRoot 'payload\SHA256.txt'
    if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) { throw 'The encrypted plugin package is missing.' }
    if (-not (Test-Path -LiteralPath $shaPath -PathType Leaf)) { throw 'The package checksum is missing.' }

    $expectedSha = ((Get-Content -LiteralPath $shaPath -Raw).Trim() -split '\s+')[0].ToUpperInvariant()
    $actualSha = (Get-FileHash -LiteralPath $payloadPath -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($expectedSha -ne $actualSha) { throw 'The encrypted package checksum does not match.' }

    $installerPath = Join-Path $cloneRoot 'install.ps1'
    $crossInstallerPath = Join-Path $cloneRoot 'install.py'
    $crossInstallerTest = Join-Path $cloneRoot 'test_install_py.py'
    $shellInstallerPath = Join-Path $cloneRoot 'install.sh'
    foreach ($required in @($installerPath, $crossInstallerPath, $crossInstallerTest, $shellInstallerPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw ('A required installer is missing: ' + [IO.Path]::GetFileName($required)) }
    }
    $PythonPath = Resolve-ReleasePython $PythonPath
    $invitePage = ($RepositoryUrl -replace '\.git$', '') + '#invite=' + [Uri]::EscapeDataString($InviteCode)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -InviteUrl $invitePage -VerifyOnly
    if ($LASTEXITCODE -ne 0) { throw 'The valid invitation code failed verification.' }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -InviteCode $InviteCode -VerifyOnly
    if ($LASTEXITCODE -ne 0) { throw 'The direct invitation-code fallback failed verification.' }

    $queryInvitePage = ($RepositoryUrl -replace '\.git$', '') + '?invite=' + [Uri]::EscapeDataString($InviteCode)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -InviteUrl $queryInvitePage -VerifyOnly
    if ($LASTEXITCODE -ne 0) { throw 'The query-form invitation fallback failed verification.' }

    & $PythonPath -I $crossInstallerPath --invite-url $invitePage --verify-only *> $null
    if ($LASTEXITCODE -ne 0) { throw 'The cross-platform installer failed fragment-link verification.' }
    & $PythonPath -I $crossInstallerPath --invite-url $queryInvitePage --verify-only *> $null
    if ($LASTEXITCODE -ne 0) { throw 'The cross-platform installer failed query-link verification.' }
    & $PythonPath -I $crossInstallerPath --invite-code $InviteCode --verify-only *> $null
    if ($LASTEXITCODE -ne 0) { throw 'The cross-platform installer failed direct-code verification.' }

    $env:MAXX_TEST_INVITE_CODE = $InviteCode
    try {
        # unittest writes progress to stderr even when every test passes. Windows
        # PowerShell turns that benign stream into NativeCommandError under Stop.
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        & $PythonPath -I $crossInstallerTest *> $null
        $crossTestExit = $LASTEXITCODE
        $ErrorActionPreference = $previousErrorAction
        if ($crossTestExit -ne 0) { throw 'Cross-platform installer tests failed against the published payload.' }
    }
    finally {
        $ErrorActionPreference = 'Stop'
        Remove-Item Env:MAXX_TEST_INVITE_CODE -ErrorAction SilentlyContinue
    }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $fragmentMissingPage = ($RepositoryUrl -replace '\.git$', '')
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -InviteUrl $fragmentMissingPage -VerifyOnly *> $null
    $fragmentMissingExit = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($fragmentMissingExit -eq 0) { throw 'A URL without invitation credentials was incorrectly accepted.' }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $conflictingPage = $invitePage + '&invite=conflicting-value'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -InviteUrl $conflictingPage -VerifyOnly *> $null
    $conflictingExit = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($conflictingExit -eq 0) { throw 'Conflicting invitation values were incorrectly accepted.' }

    $wrongCode = 'invalid-' + [guid]::NewGuid().ToString('N')
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $wrongInvitePage = ($RepositoryUrl -replace '\.git$', '') + '#invite=' + [Uri]::EscapeDataString($wrongCode)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $installerPath -InviteUrl $wrongInvitePage -VerifyOnly *> $null
    $wrongCodeExit = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($wrongCodeExit -eq 0) { throw 'An invalid invitation code was not rejected.' }

    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & $PythonPath -I $crossInstallerPath --invite-code $wrongCode --verify-only *> $null
    $crossWrongCodeExit = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorAction
    if ($crossWrongCodeExit -eq 0) { throw 'The cross-platform installer did not reject an invalid invitation code.' }

    $readme = Get-Content -LiteralPath (Join-Path $cloneRoot 'README.md') -Raw -Encoding UTF8
    $codexInstallPath = Join-Path $cloneRoot 'CODEX_INSTALL.md'
    if (-not (Test-Path -LiteralPath $codexInstallPath -PathType Leaf)) { throw 'CODEX_INSTALL.md is missing.' }
    $codexInstall = Get-Content -LiteralPath $codexInstallPath -Raw -Encoding UTF8
    $troubleshootingPath = Join-Path $cloneRoot 'TROUBLESHOOTING.md'
    if (-not (Test-Path -LiteralPath $troubleshootingPath -PathType Leaf)) { throw 'TROUBLESHOOTING.md is missing.' }
    $troubleshooting = Get-Content -LiteralPath $troubleshootingPath -Raw -Encoding UTF8
    $dependenciesPath = Join-Path $cloneRoot 'DEPENDENCIES.md'
    if (-not (Test-Path -LiteralPath $dependenciesPath -PathType Leaf)) { throw 'DEPENDENCIES.md is missing.' }
    $dependencies = Get-Content -LiteralPath $dependenciesPath -Raw -Encoding UTF8
    if ($readme -match 'https?://raw\.githubusercontent\.com') { throw 'README still depends on GitHub Raw.' }
    if ($codexInstall -match 'https?://raw\.githubusercontent\.com') { throw 'CODEX_INSTALL.md still depends on GitHub Raw.' }
    if ($readme -match 'marketplacePath=|C:\\Users\\') { throw 'README leaks or depends on a sender-local path.' }
    if ($codexInstall -match 'marketplacePath=|C:\\Users\\') { throw 'CODEX_INSTALL.md leaks or depends on a sender-local path.' }
    if ($troubleshooting -match 'marketplacePath=|C:\\Users\\') { throw 'TROUBLESHOOTING.md leaks or depends on a sender-local path.' }
    if ($dependencies -match 'marketplacePath=|C:\\Users\\') { throw 'DEPENDENCIES.md leaks or depends on a sender-local path.' }

    Write-Host 'Release gate passed: anonymous clone, public-history leak scan, Windows and cross-platform fragment/query/direct-code verification, credential rejection, and installer tests.'
    $global:LASTEXITCODE = 0
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
