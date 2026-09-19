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

function Assert-PayloadChecksum([string]$Path) {
    $checksumPath = Join-Path ([IO.Path]::GetDirectoryName($Path)) 'SHA256.txt'
    foreach ($inputPath in @($Path, $checksumPath)) {
        if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf) -or
            ((Get-Item -LiteralPath $inputPath).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'The invitation payload or SHA256 checksum file is missing or unsafe.'
        }
    }
    if ((Get-Item -LiteralPath $Path).Length -gt 536870912) { throw 'The encrypted invitation payload exceeds the allowed size.' }
    $lines = @([IO.File]::ReadAllLines($checksumPath) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -ne 1 -or $lines[0].Trim() -notmatch '^([0-9a-fA-F]{64})\s+\*?plugin-marketplace\.aes$') {
        throw 'The invitation SHA256 checksum must have exactly one correctly named entry.'
    }
    $expected = $Matches[1]
    if ((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -ine $expected) {
        throw 'The encrypted invitation payload does not match its published SHA256 checksum.'
    }
}

function Assert-PortableMember([string]$Name) {
    if ([string]::IsNullOrEmpty($Name) -or $Name.Contains([string][char]0) -or $Name.Contains('\') -or
        $Name.StartsWith('/') -or $Name.Contains(':')) { throw 'Unsafe ZIP member path.' }
    $logical = $Name.TrimEnd('/')
    if ([string]::IsNullOrEmpty($logical) -or $Name.EndsWith('//')) { throw 'Unsafe ZIP member path.' }
    foreach ($part in ($logical -split '/')) {
        if ($part -eq '' -or $part -eq '.' -or $part -eq '..' -or $part -match '[. ]$' -or
            $part -match '[\x00-\x1f<>"|?*]' -or $part -match '^(?i:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)') {
            throw 'Unsafe ZIP member path.'
        }
    }
}

function Get-RawZipInventory([byte[]]$Bytes) {
    # Inspect the original central-directory and local names before any ZIP
    # library can normalize platform separators or truncate NUL-containing names.
    $end = -1
    for ($offset = $Bytes.Length - 22; $offset -ge [Math]::Max(0, $Bytes.Length - 65557); $offset--) {
        if ([BitConverter]::ToUInt32($Bytes, $offset) -eq 0x06054b50 -and
            $offset + 22 + [BitConverter]::ToUInt16($Bytes, $offset + 20) -eq $Bytes.Length) { $end = $offset; break }
    }
    if ($end -lt 0) { throw 'Invalid ZIP end directory.' }
    $count = [int][BitConverter]::ToUInt16($Bytes, $end + 10)
    [long]$directorySize = [BitConverter]::ToUInt32($Bytes, $end + 12)
    [long]$position = [BitConverter]::ToUInt32($Bytes, $end + 16)
    if ([BitConverter]::ToUInt16($Bytes, $end + 4) -ne 0 -or [BitConverter]::ToUInt16($Bytes, $end + 6) -ne 0 -or
        [BitConverter]::ToUInt16($Bytes, $end + 8) -ne $count -or $count -le 0 -or $count -gt 20000 -or
        $position + $directorySize -ne $end) { throw 'Invalid ZIP directory count, size or unsupported multi-disk/ZIP64 archive.' }
    $members = [Collections.Generic.List[object]]::new()
    $paths = [Collections.Generic.Dictionary[string,bool]]::new([StringComparer]::OrdinalIgnoreCase)
    [long]$total = 0
    for ($index = 0; $index -lt $count; $index++) {
        if ($position + 46 -gt $end -or [BitConverter]::ToUInt32($Bytes, [int]$position) -ne 0x02014b50) { throw 'Invalid ZIP central directory entry.' }
        $flags = [BitConverter]::ToUInt16($Bytes, [int]$position + 8)
        $method = [BitConverter]::ToUInt16($Bytes, [int]$position + 10)
        [long]$compressed = [BitConverter]::ToUInt32($Bytes, [int]$position + 20)
        [long]$length = [BitConverter]::ToUInt32($Bytes, [int]$position + 24)
        $nameSize = [BitConverter]::ToUInt16($Bytes, [int]$position + 28)
        $extraSize = [BitConverter]::ToUInt16($Bytes, [int]$position + 30)
        $commentSize = [BitConverter]::ToUInt16($Bytes, [int]$position + 32)
        [long]$attributes = [BitConverter]::ToUInt32($Bytes, [int]$position + 38)
        [long]$local = [BitConverter]::ToUInt32($Bytes, [int]$position + 42)
        if ($position + 46 + $nameSize + $extraSize + $commentSize -gt $end -or $nameSize -eq 0 -or
            ($flags -band 1) -ne 0 -or $method -notin @(0, 8) -or
            [BitConverter]::ToUInt16($Bytes, [int]$position + 34) -ne 0) { throw 'Invalid or unsupported ZIP member metadata.' }
        $encoding = if ($flags -band 2048) { [Text.UTF8Encoding]::new($false, $true) } else { [Text.Encoding]::GetEncoding(437) }
        $name = $encoding.GetString($Bytes, [int]$position + 46, $nameSize)
        Assert-PortableMember $name
        $isDirectory = $name.EndsWith('/')
        $type = ($attributes -shr 16) -band 61440
        if ($type -notin @(0, 32768, 16384) -or ($attributes -band 1024) -ne 0 -or
            ($type -eq 16384 -and -not $isDirectory) -or ($type -eq 32768 -and $isDirectory)) {
            throw 'Links, special files or inconsistent ZIP member types are forbidden.'
        }
        if ($length -gt 536870912 -or $compressed -gt 536870912 -or ($isDirectory -and $length -ne 0)) { throw 'ZIP member exceeds the allowed size.' }
        $total += $length
        if ($total -gt 2147483648) { throw 'ZIP archive exceeds the allowed expanded size.' }
        $key = $name.TrimEnd('/')
        if ($paths.ContainsKey($key)) { throw 'Duplicate or case-colliding ZIP paths are forbidden.' }
        $paths.Add($key, $isDirectory)
        if ($local + 30 -gt $Bytes.Length -or [BitConverter]::ToUInt32($Bytes, [int]$local) -ne 0x04034b50) { throw 'Invalid ZIP local file header.' }
        $localNameSize = [BitConverter]::ToUInt16($Bytes, [int]$local + 26)
        $localExtraSize = [BitConverter]::ToUInt16($Bytes, [int]$local + 28)
        if ($localNameSize -ne $nameSize -or $local + 30 + $localNameSize + $localExtraSize + $compressed -gt [BitConverter]::ToUInt32($Bytes, $end + 16) -or
            [BitConverter]::ToUInt16($Bytes, [int]$local + 6) -ne $flags -or [BitConverter]::ToUInt16($Bytes, [int]$local + 8) -ne $method) {
            throw 'ZIP local and central metadata disagree.'
        }
        for ($character = 0; $character -lt $nameSize; $character++) {
            if ($Bytes[[int]$local + 30 + $character] -ne $Bytes[[int]$position + 46 + $character]) { throw 'ZIP local and central member names disagree.' }
        }
        $members.Add([pscustomobject]@{ Name=$name; IsDirectory=$isDirectory; Length=$length; CompressedLength=$compressed })
        $position += 46 + $nameSize + $extraSize + $commentSize
    }
    if ($position -ne $end) { throw 'ZIP directory length does not match its entries.' }
    foreach ($key in $paths.Keys) {
        $parts = $key -split '/'
        for ($level = 1; $level -lt $parts.Count; $level++) {
            $ancestor = ($parts[0..($level - 1)] -join '/')
            if ($paths.ContainsKey($ancestor) -and -not $paths[$ancestor]) { throw 'ZIP file and directory paths conflict.' }
        }
    }
    return $members.ToArray()
}

function Expand-PortableArchive([string]$Path, [string]$Destination, [object[]]$Inventory) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        if ($archive.Entries.Count -ne $Inventory.Count) { throw 'ZIP parser entry counts disagree.' }
        for ($index = 0; $index -lt $Inventory.Count; $index++) {
            $entry, $item = $archive.Entries[$index], $Inventory[$index]
            if ($entry.FullName -cne $item.Name -or $entry.Length -ne $item.Length -or $entry.CompressedLength -ne $item.CompressedLength) { throw 'ZIP parser metadata disagree.' }
        }
        if (Test-Path -LiteralPath $Destination) { throw 'ZIP extraction requires a new directory.' }
        New-Item -ItemType Directory -Path $Destination | Out-Null
        $prefix = [IO.Path]::GetFullPath($Destination).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        for ($index = 0; $index -lt $Inventory.Count; $index++) {
            $entry, $item = $archive.Entries[$index], $Inventory[$index]
            $target = [IO.Path]::GetFullPath((Join-Path $Destination $item.Name.Replace('/', [string][IO.Path]::DirectorySeparatorChar)))
            if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'ZIP extraction escaped its destination.' }
            if ($item.IsDirectory) { New-Item -ItemType Directory -Path $target -Force | Out-Null; continue }
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
            $source = $entry.Open()
            try {
                $output = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
                try {
                    $buffer = New-Object byte[] 65536
                    [long]$written = 0
                    while (($read = $source.Read($buffer, 0, $buffer.Length)) -gt 0) {
                        $written += $read
                        if ($written -gt $item.Length -or $written -gt 536870912) { throw 'ZIP expanded member exceeds its declared size.' }
                        $output.Write($buffer, 0, $read)
                    }
                    if ($written -ne $item.Length) { throw 'ZIP expanded member has an unexpected length.' }
                } finally { $output.Dispose() }
            } finally { $source.Dispose() }
        }
    } finally { $archive.Dispose() }
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

    Assert-PayloadChecksum $payloadPath
    $blob = [IO.File]::ReadAllBytes($payloadPath)
    $magic = [Text.Encoding]::ASCII.GetBytes('MMCMAX1')
    if ($blob.Length -lt 56) { throw 'The invitation package is incomplete or corrupted.' }
    for ($i = 0; $i -lt $magic.Length; $i++) {
        if ($blob[$i] -ne $magic[$i]) { throw 'Unsupported invitation package format.' }
    }

    $iv = New-Object byte[] 16
    [Array]::Copy($blob, 7, $iv, 0, 16)
    $cipherLength = $blob.Length - 7 - 16 - 32
    if ($cipherLength -le 0 -or $cipherLength % 16 -ne 0) { throw 'The invitation ciphertext has an invalid length.' }
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
    $inventory = @(Get-RawZipInventory $plain)
    Expand-PortableArchive $zipPath $extractPath $inventory
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
