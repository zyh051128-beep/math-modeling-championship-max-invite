param(
    [ValidateNotNullOrEmpty()]
    [string]$InviteCode,

    [ValidateNotNullOrEmpty()]
    [string]$InviteUrl,

    [switch]$VerifyOnly,

    [switch]$SetupRuntime,

    [ValidateSet('core', 'extended')]
    [string]$RuntimeProfile = 'extended',

    [ValidateSet('word', 'latex', 'both')]
    [string]$Delivery = 'word',

    [string]$PythonPath
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

if (-not [string]::IsNullOrWhiteSpace($InviteUrl)) {
    try {
        $inviteUri = [Uri]$InviteUrl
        $urlCodes = @()
        foreach ($component in @($inviteUri.Fragment.TrimStart('#'), $inviteUri.Query.TrimStart('?'))) {
            foreach ($part in ($component -split '&')) {
                $pair = $part -split '=', 2
                if ($pair.Length -eq 2 -and $pair[0] -eq 'invite') {
                    $decoded = [Uri]::UnescapeDataString($pair[1])
                    if (-not [string]::IsNullOrWhiteSpace($decoded)) { $urlCodes += $decoded }
                }
            }
        }
        $uniqueUrlCodes = @($urlCodes | Select-Object -Unique)
        if ($uniqueUrlCodes.Count -gt 1) { throw 'The invitation URL contains conflicting invite values.' }
        if ($uniqueUrlCodes.Count -eq 1) {
            if (-not [string]::IsNullOrWhiteSpace($InviteCode) -and $InviteCode -cne $uniqueUrlCodes[0]) {
                throw 'InviteUrl and InviteCode contain different invitation credentials.'
            }
            if ([string]::IsNullOrWhiteSpace($InviteCode)) { $InviteCode = $uniqueUrlCodes[0] }
        }
    }
    catch {
        throw ('The supplied invitation URL is not valid or has conflicting credentials: ' + $_.Exception.Message)
    }
}
if ([string]::IsNullOrWhiteSpace($InviteCode)) {
    throw 'No invitation credential was found. Supply -InviteUrl with #invite= (preferred) or ?invite=, or use -InviteCode with the separately supplied invitation code.'
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

function Find-RealPython {
    $candidates = @()
    if ($PythonPath) { $candidates += $PythonPath }
    if ($env:MATHMODEL_PYTHON) { $candidates += $env:MATHMODEL_PYTHON }
    $bundled = Join-Path $env:USERPROFILE '.cache\codex-runtimes'
    if (Test-Path -LiteralPath $bundled) {
        $candidates += Get-ChildItem -LiteralPath $bundled -Filter python.exe -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\dependencies\\python\\python\.exe$' } |
            Select-Object -ExpandProperty FullName
    }
    $command = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source -notmatch '\\WindowsApps\\') { $candidates += $command.Source }
    return $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}

function Write-InstallJson([string]$Path, [object]$Value) {
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
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
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\SKILL.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-max\SKILL.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\huawei_cup_audit.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\evidence_consistency_audit.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\ai_content_audit.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\scispace_evidence.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\bootstrap_runtime.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\render_flowcharts.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\presentation_audit.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\export_word_pdf.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\word_source_audit.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\build_delivery_zip.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\page_budget_audit.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\algorithm_verification_audit.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\scripts\edit_figure_spec.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\references\word-delivery-contract.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\references\word-delivery-manifest-template.json'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\references\runtime-profiles.json'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\references\external-installation.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\references\flowchart-spec-example.json'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\references\presentation-manifest-template.json'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\references\presentation-contract.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship-maxx\references\presentation-workflow.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship\SKILL.md'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship\scripts\doctor.py'),
        (Join-Path $pluginRoot 'skills\math-modeling-championship\scripts\state_manager.py')
    )
    foreach ($requiredEntrypoint in $requiredEntrypoints) {
        if (-not (Test-Path -LiteralPath $requiredEntrypoint -PathType Leaf)) {
            throw ('The decrypted package is incomplete. Missing: ' + $requiredEntrypoint.Substring($pluginRoot.Length).TrimStart('\'))
        }
    }
    $version = (Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json).version
    if ($VerifyOnly) {
        Write-Host ('Invitation package verified (decryption and required files only): Shumo-MAXx ' + $version)
        return
    }
    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        throw 'Codex CLI is not available. Install/open Codex first; see DEPENDENCIES.md.'
    }
    $installParent = Join-Path $env:USERPROFILE 'codex-invited-marketplaces'
    # Keep the prefix short for Windows PowerShell 5.1 path limits. The manifest
    # and installation-state.json retain the full release version.
    $installRoot = Join-Path $installParent ('maxx-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $installParent | Out-Null
    New-Item -ItemType Directory -Path $installRoot | Out-Null
    Get-ChildItem -LiteralPath $extractPath -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $installRoot -Recurse
    }

    $existingMarketplaceNames = @()
    $previousMarketplaceRoot = $null
    try {
        $marketplaceListJson = (& codex plugin marketplace list --json | Out-String)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($marketplaceListJson)) {
            $marketplaceList = $marketplaceListJson | ConvertFrom-Json
            $existingMarketplaceNames = @($marketplaceList.marketplaces | ForEach-Object { $_.name })
            $previousMarketplaceRoot = @($marketplaceList.marketplaces | Where-Object { $_.name -eq 'zyh-mathmodel-private' } | Select-Object -First 1 | ForEach-Object { $_.root }) | Select-Object -First 1
        }
    }
    catch {
        Write-Host 'Could not read existing plugin marketplaces; continuing with installation.'
    }

    $newMarketplaceAdded = $false
    try {
        if ($existingMarketplaceNames -contains 'zyh-mathmodel-private') {
            & codex plugin marketplace remove 'zyh-mathmodel-private'
            if ($LASTEXITCODE -ne 0) { throw 'Unable to replace the previous invited marketplace.' }
        }
        & codex plugin marketplace add $installRoot
        if ($LASTEXITCODE -ne 0) { throw 'Unable to add the invited plugin marketplace.' }
        $newMarketplaceAdded = $true
        & codex plugin add 'math-modeling-championship-max@zyh-mathmodel-private'
        if ($LASTEXITCODE -ne 0) { throw 'Unable to install the MAXx plugin.' }
    }
    catch {
        $registrationError = $_.Exception.Message
        $restored = $false
        if ($previousMarketplaceRoot -and (Test-Path -LiteralPath $previousMarketplaceRoot -PathType Container)) {
            try {
                if ($newMarketplaceAdded) { & codex plugin marketplace remove 'zyh-mathmodel-private' }
                & codex plugin marketplace add $previousMarketplaceRoot
                if ($LASTEXITCODE -eq 0) {
                    & codex plugin add 'math-modeling-championship-max@zyh-mathmodel-private'
                    $restored = $LASTEXITCODE -eq 0
                }
            }
            catch { $restored = $false }
        }
        Write-InstallJson (Join-Path $installRoot 'registration-failure.json') ([ordered]@{status='FAIL';error=$registrationError;previous_marketplace_restored=$restored})
        throw ('Plugin registration failed. Previous marketplace restored: ' + $restored + '. Details: ' + (Join-Path $installRoot 'registration-failure.json'))
    }
    $maxxRoot = Join-Path $installRoot 'plugins\math-modeling-championship-max\skills\math-modeling-championship-maxx'
    $runtimeStatus = 'NOT_REQUESTED'
    $runtimeReportPath = $null
    if ($PythonPath) { $env:MATHMODEL_PYTHON = $PythonPath }
    if ($SetupRuntime) {
        $runtimeReportPath = Join-Path $installRoot 'runtime-setup.json'
        try {
            $runtimePython = Find-RealPython
            if (-not $runtimePython) { throw 'No usable Python was found. Install Python 3.11+ or supply -PythonPath.' }
            $runtimeJson = (& $runtimePython -I (Join-Path $maxxRoot 'scripts\bootstrap_runtime.py') --profile $RuntimeProfile | Out-String)
            $runtimeExitCode = $LASTEXITCODE
            $runtimeReport = $runtimeJson | ConvertFrom-Json
            if ($null -eq $runtimeReport) { throw 'Python setup returned no JSON report.' }
            Write-InstallJson $runtimeReportPath $runtimeReport
            if ($runtimeExitCode -eq 0 -and $runtimeReport.status -eq 'VERIFIED' -and $runtimeReport.execution_verified -eq $true -and (Test-Path -LiteralPath $runtimeReport.python -PathType Leaf)) {
                $runtimeStatus = 'VERIFIED'
                $env:MATHMODEL_PYTHON = $runtimeReport.python
            }
            else {
                $runtimeStatus = 'FAILED'
                Write-Warning 'Python dependency setup failed; inspect its retained report and DEPENDENCIES.md.'
            }
        }
        catch {
            $runtimeStatus = 'FAILED'
            Write-InstallJson $runtimeReportPath ([ordered]@{status='NOT_READY';execution_verified=$false;error=$_.Exception.Message})
            Write-Warning 'Could not complete Python setup; plugin files remain installed. See runtime-setup.json and DEPENDENCIES.md.'
        }
    }
    $doctorPath = Join-Path $maxxRoot 'scripts\max_doctor.ps1'
    $doctorOutputPath = Join-Path $installRoot 'maxx-install-doctor.json'
    $doctorReport = $null
    try {
        $doctorJson = (& powershell -NoProfile -ExecutionPolicy Bypass -File $doctorPath -Delivery $Delivery -Profile championship -Output $doctorOutputPath | Out-String)
        $doctorExitCode = $LASTEXITCODE
        if (Test-Path -LiteralPath $doctorOutputPath -PathType Leaf) {
            $doctorReport = Get-Content -LiteralPath $doctorOutputPath -Raw -Encoding UTF8 | ConvertFrom-Json
        }
        elseif (-not [string]::IsNullOrWhiteSpace($doctorJson)) {
            $doctorReport = $doctorJson | ConvertFrom-Json
            Write-InstallJson $doctorOutputPath $doctorReport
        }
    }
    catch { $doctorExitCode = 1 }
    if ($null -eq $doctorReport) {
        $doctorReport = [pscustomobject]@{ready=$false;blocking_failures=@('doctor:no_valid_report')}
        Write-InstallJson $doctorOutputPath $doctorReport
    }
    $ready = $doctorExitCode -eq 0 -and $null -ne $doctorReport -and $doctorReport.ready -eq $true -and @($doctorReport.blocking_failures).Count -eq 0
    if ($SetupRuntime -and $runtimeStatus -ne 'VERIFIED') { $ready = $false }
    $state = [ordered]@{
        plugin_installed = $true
        version = $version
        environment_ready = $ready
        delivery = $Delivery
        requested_runtime_profile = $(if ($SetupRuntime) { $RuntimeProfile } else { $null })
        runtime_setup = $runtimeStatus
        runtime_verified = ($runtimeStatus -eq 'VERIFIED')
        runtime_report = $runtimeReportPath
        doctor_report = $doctorOutputPath
        installation_guide = (Join-Path $maxxRoot 'references\external-installation.md')
        external_account_connections_verified = $false
        all_optional_applications_executed = $false
    }
    Write-InstallJson (Join-Path $installRoot 'installation-state.json') $state
    Write-Host ('Plugin installed: Shumo-MAXx ' + $version)
    Write-Host ('Installation guide: ' + $state.installation_guide)
    Write-Host ('Readiness report: ' + $doctorOutputPath)
    if ($ready) {
        Write-Host 'Doctor passed for the selected delivery. Optional applications and account connections require their own checks.'
    }
    else {
        Write-Warning 'Plugin installed; environment is INCOMPLETE. Follow the readiness report and installation guide to enable missing capabilities.'
    }
    Write-Host 'Create a new Codex task before using the updated plugin.'
    if (-not $ready) { exit 2 }
}
finally {
    $resolvedWork = [IO.Path]::GetFullPath($workRoot)
    $resolvedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($resolvedWork.StartsWith($resolvedTemp, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $resolvedWork)) {
        Remove-Item -LiteralPath $resolvedWork -Recurse -Force
    }
}
