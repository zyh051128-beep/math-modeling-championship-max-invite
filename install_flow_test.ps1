param(
    [string]$PythonPath,
    [string]$ReportPath,
    [ValidateSet('', 'verify-only', 'verify-fragment', 'verify-query', 'verify-missing', 'verify-conflict', 'verify-case-mismatch', 'bootstrap-failed', 'bootstrap-start-failed', 'doctor-invalid', 'healthy')]
    [string]$ChildCase = '',
    [string]$CaseRoot,
    [string]$FixtureRoot
)

# The encryption, extraction, installer, Python invocation, and Doctor process are
# real. The package/Doctor/bootstrap are synthetic; Codex calls are mocked. This
# does not claim to test Codex itself, real dependencies, or account connections.
$ErrorActionPreference = 'Stop'
$testCode = 'SYNTHETIC-TEST-ONLY-MAXx-0123456789abcdef'
$profileLeaf = 'u-' + [char]0x4E2D + [char]0x6587

if ($ChildCase) {
    $env:USERPROFILE = Join-Path $CaseRoot $profileLeaf
    $env:LOCALAPPDATA = Join-Path $CaseRoot 'local'
    $env:APPDATA = Join-Path $CaseRoot 'roaming'
    $env:TEMP = Join-Path $CaseRoot 't'
    $env:TMP = $env:TEMP
    $env:PATH = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0'
    $env:PSModulePath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\Modules'
    Remove-Item Env:MATHMODEL_PYTHON -ErrorAction SilentlyContinue
    foreach ($directory in @($env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA, $env:TEMP)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $env:MAXX_TEST_DOCTOR = $ChildCase
    $env:MAXX_TEST_BOOTSTRAP = $ChildCase
    $env:MAXX_TEST_CASE_ROOT = $CaseRoot

    if ($ChildCase -like 'verify-*') {
        foreach ($command in @('python', 'python.exe', 'codex', 'winword', 'winword.exe')) {
            if (Get-Command $command -ErrorAction SilentlyContinue) {
                throw ('Isolation failed: command remains available: ' + $command)
            }
        }
        switch ($ChildCase) {
            'verify-only' {
                & (Join-Path $FixtureRoot 'install.ps1') -InviteCode $testCode -VerifyOnly
                exit $LASTEXITCODE
            }
            'verify-fragment' {
                & (Join-Path $FixtureRoot 'install.ps1') -InviteUrl ('https://example.invalid/repo#invite=' + [Uri]::EscapeDataString($testCode)) -VerifyOnly
                exit $LASTEXITCODE
            }
            'verify-query' {
                & (Join-Path $FixtureRoot 'install.ps1') -InviteUrl ('https://example.invalid/repo?invite=' + [Uri]::EscapeDataString($testCode)) -VerifyOnly
                exit $LASTEXITCODE
            }
            'verify-missing' {
                & (Join-Path $FixtureRoot 'install.ps1') -InviteUrl 'https://example.invalid/repo' -VerifyOnly
                exit $(if ($?) { 0 } else { 1 })
            }
            'verify-conflict' {
                & (Join-Path $FixtureRoot 'install.ps1') -InviteUrl ('https://example.invalid/repo?invite=' + $testCode + '#invite=conflicting-value') -VerifyOnly
                exit $(if ($?) { 0 } else { 1 })
            }
            'verify-case-mismatch' {
                & (Join-Path $FixtureRoot 'install.ps1') -InviteCode $testCode.ToLowerInvariant() -InviteUrl ('https://example.invalid/repo#invite=' + $testCode) -VerifyOnly
                exit $(if ($?) { 0 } else { 1 })
            }
        }
    }

    function global:codex {
        $request = $args -join ' '
        $log = Join-Path $env:MAXX_TEST_CASE_ROOT 'codex-calls.txt'
        [IO.File]::AppendAllText($log, $request + [Environment]::NewLine)
        $mockState = Join-Path $env:MAXX_TEST_CASE_ROOT 'mock-marketplace.txt'
        switch -Regex ($request) {
            '^plugin marketplace list --json$' {
                if (Test-Path -LiteralPath $mockState) {
                    '{"marketplaces":[{"name":"zyh-mathmodel-private"}]}'
                } else { '{"marketplaces":[]}' }
                break
            }
            '^plugin marketplace remove zyh-mathmodel-private$' {
                [IO.File]::Delete($mockState)
                break
            }
            '^plugin marketplace add ' {
                if (-not (Test-Path -LiteralPath $args[3] -PathType Container)) {
                    throw 'Mock Codex received a nonexistent marketplace.'
                }
                [IO.File]::WriteAllText($mockState, $args[3])
                break
            }
            '^plugin add math-modeling-championship-max@zyh-mathmodel-private$' { break }
            default { throw ('Unexpected mock Codex call: ' + $request) }
        }
        $global:LASTEXITCODE = 0
    }

    $installArgs = @{ InviteCode = $testCode }
    if ($ChildCase -like 'bootstrap-*') {
        $installArgs.SetupRuntime = $true
        $installArgs.PythonPath = $PythonPath
        if ($ChildCase -eq 'bootstrap-start-failed') {
            $installArgs.PythonPath = Join-Path $CaseRoot 'invalid-python.exe'
            [IO.File]::WriteAllText($installArgs.PythonPath, 'Synthetic invalid executable; never real Python.')
        }
    }
    $global:LASTEXITCODE = 0
    & (Join-Path $FixtureRoot 'install.ps1') @installArgs
    exit $LASTEXITCODE
}

if (-not $PythonPath) {
    $bundled = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    if (Test-Path -LiteralPath $bundled -PathType Leaf) { $PythonPath = $bundled }
    else {
        $command = Get-Command python.exe -ErrorAction SilentlyContinue
        if ($command -and $command.Source -notmatch '\\WindowsApps\\') { $PythonPath = $command.Source }
    }
}
if (-not $PythonPath -or -not (Test-Path -LiteralPath $PythonPath -PathType Leaf)) {
    throw 'Supply a real Python executable with -PythonPath for the bootstrap subprocess test.'
}
if ($ReportPath) {
    $ReportPath = [IO.Path]::GetFullPath($ReportPath)
    if (Test-Path -LiteralPath $ReportPath) { throw ('ReportPath already exists; choose a new path: ' + $ReportPath) }
    if (-not (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($ReportPath)) -PathType Container)) {
        throw 'ReportPath parent directory must exist.'
    }
}
$PythonPath = [IO.Path]::GetFullPath($PythonPath)
$shell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
# Keep the isolated profile short: Windows PowerShell 5.1 still applies MAX_PATH
# to Copy-Item. A long test-only prefix should not manufacture a product failure.
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('mift-' + [guid]::NewGuid().ToString('N').Substring(0, 12))
$testRoot = [IO.Path]::GetFullPath($testRoot)
$testParent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$results = [Collections.Generic.List[object]]::new()
$testRootCreated = $false

function Assert-Test([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-Fixture([string]$RelativePath, [string]$Content) {
    $path = Join-Path $FixtureRoot $RelativePath
    New-Item -ItemType Directory -Force -Path ([IO.Path]::GetDirectoryName($path)) | Out-Null
    [IO.File]::WriteAllText($path, $Content, [Text.UTF8Encoding]::new($false))
}

function Write-TestPayload([string]$ZipPath, [string]$PayloadPath) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $key = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($testCode))
        $auth = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('auth:' + $testCode))
    } finally { $sha.Dispose() }
    $aes = [Security.Cryptography.Aes]::Create()
    try {
        $aes.Key = $key
        $aes.GenerateIV()
        $encryptor = $aes.CreateEncryptor()
        try {
            $plain = [IO.File]::ReadAllBytes($ZipPath)
            $cipher = $encryptor.TransformFinalBlock($plain, 0, $plain.Length)
        } finally { $encryptor.Dispose() }
        [byte[]]$prefix = [Text.Encoding]::ASCII.GetBytes('MMCMAX1') + $aes.IV + $cipher
    } finally { $aes.Dispose() }
    $hmac = New-Object Security.Cryptography.HMACSHA256(,$auth)
    try { [byte[]]$payload = $prefix + $hmac.ComputeHash($prefix) }
    finally { $hmac.Dispose() }
    [IO.File]::WriteAllBytes($PayloadPath, $payload)
    $hash = (Get-FileHash -LiteralPath $PayloadPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText((Join-Path ([IO.Path]::GetDirectoryName($PayloadPath)) 'SHA256.txt'), $hash + '  plugin-marketplace.aes' + "`n", [Text.UTF8Encoding]::new($false))
}

function Write-PortableFixtureZip([string]$SourceRoot, [string]$ZipPath) {
    $archive = [IO.Compression.ZipFile]::Open($ZipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $prefix = [IO.Path]::GetFullPath($SourceRoot).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
        foreach ($file in (Get-ChildItem -LiteralPath $SourceRoot -Recurse -Force -File)) {
            $name = $file.FullName.Substring($prefix.Length).Replace('\', '/')
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, $name)
        }
    } finally { $archive.Dispose() }
}

function Write-UnsafeFixtureZip([string]$ZipPath, [string]$Kind) {
    $names = switch ($Kind) {
        'backslash' { @('folder\file.txt') }
        'nul' { @('nullXname.txt') }
        'traversal' { @('../escape.txt') }
        'absolute' { @('/absolute.txt') }
        'drive' { @('C:/escape.txt') }
        'collision' { @('same.txt', 'SAME.txt') }
        'parent-conflict' { @('parent', 'parent/child.txt') }
        'total-size' { @('size1', 'size2', 'size3', 'size4', 'size5') }
        default { @('safe.txt') }
    }
    $archive = [IO.Compression.ZipFile]::Open($ZipPath, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $names) {
            $entry = $archive.CreateEntry($name)
            $stream = $entry.Open()
            try { $stream.WriteByte(120) } finally { $stream.Dispose() }
        }
    } finally { $archive.Dispose() }
    $bytes = [IO.File]::ReadAllBytes($ZipPath)
    $end = $bytes.Length - 22
    $position = [int][BitConverter]::ToUInt32($bytes, $end + 16)
    for ($index = 0; $index -lt $names.Count; $index++) {
        $nameLength = [BitConverter]::ToUInt16($bytes, $position + 28)
        $extra = [BitConverter]::ToUInt16($bytes, $position + 30)
        $comment = [BitConverter]::ToUInt16($bytes, $position + 32)
        $local = [int][BitConverter]::ToUInt32($bytes, $position + 42)
        if ($Kind -eq 'nul') { $bytes[$position + 50] = 0; $bytes[$local + 34] = 0 }
        if ($Kind -eq 'symlink') { [Array]::Copy([BitConverter]::GetBytes([uint32]2717843456), 0, $bytes, $position + 38, 4) }
        if ($Kind -eq 'member-size') { [Array]::Copy([BitConverter]::GetBytes([uint32]536870913), 0, $bytes, $position + 24, 4) }
        if ($Kind -eq 'total-size') { [Array]::Copy([BitConverter]::GetBytes([uint32]536870912), 0, $bytes, $position + 24, 4) }
        if ($Kind -eq 'local-name-mismatch') { $bytes[$local + 30] = 88 }
        $position += 46 + $nameLength + $extra + $comment
    }
    if ($Kind -eq 'entry-count') {
        [Array]::Copy([BitConverter]::GetBytes([uint16]20001), 0, $bytes, $end + 8, 2)
        [Array]::Copy([BitConverter]::GetBytes([uint16]20001), 0, $bytes, $end + 10, 2)
    }
    [IO.File]::WriteAllBytes($ZipPath, $bytes)
}

function Invoke-Case([string]$Name, [string]$Directory) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $shell
    $start.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $PSCommandPath + '" -ChildCase "' + $Name + '" -CaseRoot "' + $Directory + '" -FixtureRoot "' + $FixtureRoot + '" -PythonPath "' + $PythonPath + '"'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(60000)) {
            $process.Kill()
            throw ('Installer test timed out: ' + $Name)
        }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.Result + $stderr.Result }
    } finally { $process.Dispose() }
}

function Get-InstallRoots([string]$Directory) {
    $parent = Join-Path (Join-Path $Directory $profileLeaf) 'codex-invited-marketplaces'
    if (Test-Path -LiteralPath $parent) {
        Get-ChildItem -LiteralPath $parent -Directory | Select-Object -ExpandProperty FullName
    }
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    $testRootCreated = $true
    $FixtureRoot = Join-Path $testRoot 'fixture'
    New-Item -ItemType Directory -Path $FixtureRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.ps1') -Destination (Join-Path $FixtureRoot 'install.ps1')
    $plugin = 'marketplace\plugins\math-modeling-championship-max'
    $maxx = $plugin + '\skills\math-modeling-championship-maxx'
    Write-Fixture 'marketplace\.agents\plugins\marketplace.json' '{"name":"zyh-mathmodel-private","plugins":[{"name":"math-modeling-championship-max","source":{"source":"local","path":"./plugins/math-modeling-championship-max"}}]}'
    Write-Fixture ($plugin + '\.codex-plugin\plugin.json') '{"name":"math-modeling-championship-max","version":"0.0.0","skills":"./skills"}'
    foreach ($name in @('math-modeling-championship-maxx', 'math-modeling-championship-max', 'math-modeling-championship')) {
        Write-Fixture ($plugin + '\skills\' + $name + '\SKILL.md') ('---' + "`nname: " + $name + "`ndescription: Synthetic installer fixture.`n---`nFixture only.")
    }
    foreach ($name in @('huawei_cup_audit.py', 'evidence_consistency_audit.py', 'ai_content_audit.py', 'scispace_evidence.py', 'render_flowcharts.py', 'presentation_audit.py', 'export_word_pdf.py', 'word_source_audit.py', 'build_delivery_zip.py', 'page_budget_audit.py', 'algorithm_verification_audit.py', 'edit_figure_spec.py')) {
        Write-Fixture ($maxx + '\scripts\' + $name) '# Synthetic required-entrypoint fixture; not a functional model.'
    }
    foreach ($name in @('doctor.py', 'state_manager.py')) {
        Write-Fixture ($plugin + '\skills\math-modeling-championship\scripts\' + $name) '# Synthetic required-entrypoint fixture.'
    }
    Write-Fixture ($maxx + '\references\runtime-profiles.json') '{"fixture":true}'
    Write-Fixture ($maxx + '\references\external-installation.md') '# Synthetic installation guide'
    foreach ($name in @('flowchart-spec-example.json', 'presentation-manifest-template.json', 'word-delivery-manifest-template.json')) {
        Write-Fixture ($maxx + '\references\' + $name) '{"fixture":true}'
    }
    foreach ($name in @('presentation-contract.md', 'presentation-workflow.md', 'word-delivery-contract.md')) {
        Write-Fixture ($maxx + '\references\' + $name) '# Synthetic presentation requirements'
    }
    Write-Fixture ($maxx + '\scripts\bootstrap_runtime.py') @'
import json, os, sys
failed = os.environ.get("MAXX_TEST_BOOTSTRAP") == "bootstrap-failed"
print(json.dumps({"status": "FAILED" if failed else "VERIFIED", "execution_verified": not failed,
                  "python": sys.executable, "fixture": True}))
sys.exit(9 if failed else 0)
'@
    Write-Fixture ($maxx + '\scripts\max_doctor.ps1') @'
param([string]$Delivery, [string]$Profile, [string]$Output)
if ($env:MAXX_TEST_DOCTOR -eq 'doctor-invalid') {
    [IO.File]::WriteAllText($Output, 'This is deliberately invalid JSON.')
    'Also invalid JSON on stdout.'
} else {
    $report = '{"ready":true,"blocking_failures":[],"fixture":true}'
    [IO.File]::WriteAllText($Output, $report)
    $report
}
exit 0
'@

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    $zip = Join-Path $FixtureRoot 'fixture.zip'
    Write-PortableFixtureZip (Join-Path $FixtureRoot 'marketplace') $zip
    New-Item -ItemType Directory -Path (Join-Path $FixtureRoot 'payload') | Out-Null
    Write-TestPayload $zip (Join-Path $FixtureRoot 'payload\plugin-marketplace.aes')

    $portableFixture = $FixtureRoot
    foreach ($unsafeKind in @('backslash', 'nul', 'traversal', 'absolute', 'drive', 'collision', 'parent-conflict', 'symlink', 'member-size', 'total-size', 'entry-count', 'local-name-mismatch')) {
        $negativeRoot = Join-Path $testRoot ('zip-' + $unsafeKind)
        New-Item -ItemType Directory -Path (Join-Path $negativeRoot 'payload') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $portableFixture 'install.ps1') -Destination (Join-Path $negativeRoot 'install.ps1')
        $negativeZip = Join-Path $negativeRoot 'unsafe.zip'
        Write-UnsafeFixtureZip $negativeZip $unsafeKind
        Write-TestPayload $negativeZip (Join-Path $negativeRoot 'payload\plugin-marketplace.aes')
        $FixtureRoot = $negativeRoot
        $case = Join-Path $testRoot ('reject-' + $unsafeKind)
        try { $run = Invoke-Case 'healthy' $case } finally { $FixtureRoot = $portableFixture }
        Assert-Test ($run.ExitCode -ne 0 -and $run.ExitCode -ne 2 -and $run.Output -match 'ZIP') ('Unsafe ZIP was not rejected: ' + $unsafeKind + ': ' + $run.Output)
        Assert-Test (@(Get-InstallRoots $case).Count -eq 0) ('Unsafe ZIP left installed files: ' + $unsafeKind)
        Assert-Test (-not (Test-Path -LiteralPath (Join-Path $case 'codex-calls.txt'))) ('Unsafe ZIP reached registration: ' + $unsafeKind)
        Assert-Test (-not (Test-Path -LiteralPath (Join-Path $case 't\escape.txt'))) 'Traversal wrote outside its extraction directory.'
        $results.Add([pscustomobject]@{ test = ('raw ZIP ' + $unsafeKind + ' rejected before extraction and registration'); status = 'PASS' })
    }
    foreach ($checksumKind in @('missing', 'wrong-hash', 'wrong-filename', 'extra-entry')) {
        $negativeRoot = Join-Path $testRoot ('sha-' + $checksumKind)
        New-Item -ItemType Directory -Path (Join-Path $negativeRoot 'payload') -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $portableFixture 'install.ps1') -Destination (Join-Path $negativeRoot 'install.ps1')
        Copy-Item -LiteralPath (Join-Path $portableFixture 'payload\plugin-marketplace.aes') -Destination (Join-Path $negativeRoot 'payload\plugin-marketplace.aes')
        $checksumPath = Join-Path $negativeRoot 'payload\SHA256.txt'
        $goodChecksum = [IO.File]::ReadAllText((Join-Path $portableFixture 'payload\SHA256.txt'))
        switch ($checksumKind) {
            'wrong-hash' { [IO.File]::WriteAllText($checksumPath, ('0' * 64) + '  plugin-marketplace.aes') }
            'wrong-filename' { [IO.File]::WriteAllText($checksumPath, $goodChecksum.Replace('plugin-marketplace.aes', 'other.aes')) }
            'extra-entry' { [IO.File]::WriteAllText($checksumPath, $goodChecksum + $goodChecksum) }
        }
        $FixtureRoot = $negativeRoot
        $case = Join-Path $testRoot ('reject-sha-' + $checksumKind)
        try { $run = Invoke-Case 'healthy' $case } finally { $FixtureRoot = $portableFixture }
        Assert-Test ($run.ExitCode -ne 0 -and $run.ExitCode -ne 2 -and $run.Output -match 'SHA256') ('Bad checksum was not rejected: ' + $checksumKind + ': ' + $run.Output)
        Assert-Test (@(Get-InstallRoots $case).Count -eq 0) 'Bad checksum installed files.'
        Assert-Test (-not (Test-Path -LiteralPath (Join-Path $case 'codex-calls.txt'))) 'Bad checksum reached registration.'
        $results.Add([pscustomobject]@{ test = ('payload checksum ' + $checksumKind + ' rejected'); status = 'PASS' })
    }

    $case = Join-Path $testRoot 'v'
    $run = Invoke-Case 'verify-only' $case
    Assert-Test ($run.ExitCode -eq 0) ('VerifyOnly failed: ' + $run.Output)
    Assert-Test ($run.Output -match 'Invitation package verified') 'VerifyOnly did not actually verify the package.'
    Assert-Test (@(Get-InstallRoots $case).Count -eq 0) 'VerifyOnly installed plugin files.'
    $results.Add([pscustomobject]@{ test = 'VerifyOnly without Python, Codex, or Word commands'; status = 'PASS' })

    foreach ($variant in @('verify-fragment', 'verify-query')) {
        $case = Join-Path $testRoot $variant
        $run = Invoke-Case $variant $case
        Assert-Test ($run.ExitCode -eq 0 -and $run.Output -match 'Invitation package verified') ($variant + ' did not verify the authenticated package: ' + $run.Output)
        Assert-Test (@(Get-InstallRoots $case).Count -eq 0) ($variant + ' installed plugin files during VerifyOnly.')
        $results.Add([pscustomobject]@{ test = ($variant + ' URL transport verifies without installation'); status = 'PASS' })
    }
    foreach ($variant in @('verify-missing', 'verify-conflict', 'verify-case-mismatch')) {
        $case = Join-Path $testRoot $variant
        $run = Invoke-Case $variant $case
        Assert-Test ($run.ExitCode -ne 0) ($variant + ' was incorrectly accepted: ' + $run.Output)
        Assert-Test (@(Get-InstallRoots $case).Count -eq 0) ($variant + ' left plugin files behind.')
        $results.Add([pscustomobject]@{ test = ($variant + ' credentials are rejected'); status = 'PASS' })
    }

    $caseIndex = 0
    foreach ($name in @('bootstrap-failed', 'bootstrap-start-failed', 'doctor-invalid')) {
        $caseIndex++
        $case = Join-Path $testRoot ([string]$caseIndex)
        $run = Invoke-Case $name $case
        Assert-Test ($run.ExitCode -eq 2) ($name + ' expected exit 2: ' + $run.Output)
        $roots = @(Get-InstallRoots $case)
        Assert-Test ($roots.Count -eq 1) ($name + ' did not retain exactly one installation.')
        $state = Get-Content -LiteralPath (Join-Path $roots[0] 'installation-state.json') -Encoding UTF8 -Raw | ConvertFrom-Json
        $doctor = Get-Content -LiteralPath $state.doctor_report -Encoding UTF8 -Raw | ConvertFrom-Json
        Assert-Test ($state.plugin_installed -eq $true -and $state.environment_ready -eq $false) ($name + ' reported misleading installation readiness.')
        Assert-Test ($state.doctor_report.Contains($profileLeaf) -and (Test-Path -LiteralPath $state.doctor_report)) ($name + ' did not preserve the Chinese profile path in its JSON receipt.')
        Assert-Test (Test-Path -LiteralPath (Join-Path $roots[0] 'plugins\math-modeling-championship-max\.codex-plugin\plugin.json')) ($name + ' lost installed plugin files.')
        if ($name -like 'bootstrap-*') {
            $runtime = Get-Content -LiteralPath $state.runtime_report -Encoding UTF8 -Raw | ConvertFrom-Json
            Assert-Test ($state.runtime_setup -eq 'FAILED' -and $state.runtime_verified -eq $false -and $runtime.execution_verified -eq $false) ($name + ' lost bootstrap failure state.')
            Assert-Test ($doctor.ready -eq $true) ($name + ' did not continue through Doctor after bootstrap failure.')
            if ($name -eq 'bootstrap-start-failed') { Assert-Test (-not [string]::IsNullOrWhiteSpace($runtime.error)) 'Bootstrap startup failure lacks an error report.' }
            else { Assert-Test ($runtime.python -eq $PythonPath) 'Bootstrap receipt did not preserve the real Python path.' }
        } else {
            Assert-Test ($doctor.ready -eq $false -and $doctor.blocking_failures -contains 'doctor:no_valid_report') 'Invalid Doctor JSON did not produce a retained failure report.'
        }
        $results.Add([pscustomobject]@{ test = $name + ' retains installation and failure evidence'; status = 'PASS' })
    }

    $case = Join-Path $testRoot 'r'
    $first = Invoke-Case 'healthy' $case
    Assert-Test ($first.ExitCode -eq 0) ('First healthy installation failed: ' + $first.Output)
    $firstRoots = @(Get-InstallRoots $case)
    Assert-Test ($firstRoots.Count -eq 1) 'First installation did not create exactly one root.'
    $firstRoot = $firstRoots[0]
    $originalHashes = @{}
    Get-ChildItem -LiteralPath $firstRoot -Recurse -File | ForEach-Object {
        $originalHashes[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
    $sentinel = Join-Path $firstRoot 'first-install-preserved.txt'
    [IO.File]::WriteAllText($sentinel, 'Do not overwrite or copy this into the new release.')
    $second = Invoke-Case 'healthy' $case
    Assert-Test ($second.ExitCode -eq 0) ('Second healthy installation failed: ' + $second.Output)
    $bothRoots = @(Get-InstallRoots $case)
    Assert-Test ($bothRoots.Count -eq 2) 'Same-version update did not create a separate installation root.'
    $secondRoot = @($bothRoots | Where-Object { $_ -ne $firstRoot })[0]
    foreach ($path in $originalHashes.Keys) {
        Assert-Test ((Test-Path -LiteralPath $path) -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $originalHashes[$path]) ('Previous installation was modified: ' + $path)
    }
    Assert-Test ((Get-Content -LiteralPath $sentinel -Encoding UTF8 -Raw) -eq 'Do not overwrite or copy this into the new release.') 'Old installation sentinel was altered.'
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $secondRoot 'first-install-preserved.txt'))) 'Old installation content was nested or copied into the new one.'
    $manifests = @(Get-ChildItem -LiteralPath $secondRoot -Recurse -File -Filter plugin.json)
    Assert-Test ($manifests.Count -eq 1) 'New installation contains nested or duplicate plugin trees.'
    $expectedManifest = Join-Path $secondRoot 'plugins\math-modeling-championship-max\.codex-plugin\plugin.json'
    Assert-Test ($manifests[0].FullName -eq $expectedManifest) 'New plugin is not at the expected marketplace depth.'
    $secondState = Get-Content -LiteralPath (Join-Path $secondRoot 'installation-state.json') -Encoding UTF8 -Raw | ConvertFrom-Json
    Assert-Test ($secondState.environment_ready -eq $true) 'Healthy synthetic Doctor did not produce ready state.'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $case 'mock-marketplace.txt') -Encoding UTF8 -Raw) -eq $secondRoot) 'Codex mock did not switch to the new installation.'
    Assert-Test ((Get-Content -LiteralPath (Join-Path $case 'codex-calls.txt') -Encoding UTF8 -Raw) -match 'plugin marketplace remove zyh-mathmodel-private') 'Repeated installation did not replace the marketplace registration.'
    $results.Add([pscustomobject]@{ test = 'same-version repeated installation preserves old files and avoids nesting'; status = 'PASS' })

    # A correctly authenticated package must still be rejected if a new critical
    # presentation feature is absent. Use a separate fixture, not real files.
    $completeFixture = $FixtureRoot
    foreach ($missingFeature in @('render_flowcharts.py', 'word_source_audit.py', 'page_budget_audit.py', 'algorithm_verification_audit.py', 'edit_figure_spec.py')) {
    $incompleteFixture = Join-Path $testRoot ('bad-' + $missingFeature)
    New-Item -ItemType Directory -Path (Join-Path $incompleteFixture 'payload') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $completeFixture 'install.ps1') -Destination (Join-Path $incompleteFixture 'install.ps1')
    $incompleteZip = Join-Path $incompleteFixture 'fixture.zip'
    Copy-Item -LiteralPath $zip -Destination $incompleteZip
    $archive = [IO.Compression.ZipFile]::Open($incompleteZip, [IO.Compression.ZipArchiveMode]::Update)
    try {
        $missingPath = 'plugins/math-modeling-championship-max/skills/math-modeling-championship-maxx/scripts/' + $missingFeature
        $entry = @($archive.Entries | Where-Object { $_.FullName.Replace('\', '/') -eq $missingPath })
        Assert-Test ($entry.Count -eq 1) 'Negative fixture must remove exactly one critical presentation file.'
        $entry[0].Delete()
    } finally { $archive.Dispose() }
    Write-TestPayload $incompleteZip (Join-Path $incompleteFixture 'payload\plugin-marketplace.aes')
    $FixtureRoot = $incompleteFixture
    $case = Join-Path $testRoot ('n-' + $missingFeature)
    try { $run = Invoke-Case 'healthy' $case }
    finally { $FixtureRoot = $completeFixture }
    Assert-Test ($run.ExitCode -ne 0 -and $run.ExitCode -ne 2) ('Missing critical feature was not rejected before installation: ' + $run.Output)
    Assert-Test ($run.Output -match 'The decrypted package is incomplete' -and $run.Output.Contains($missingFeature)) 'Missing-feature error did not identify the incomplete package and absent file.'
    Assert-Test (@(Get-InstallRoots $case).Count -eq 0) 'Incomplete presentation package left an installation directory.'
    Assert-Test (-not (Test-Path -LiteralPath (Join-Path $case 'codex-calls.txt'))) 'Incomplete presentation package reached Codex registration.'
    $results.Add([pscustomobject]@{ test = ('missing ' + $missingFeature + ' rejects authenticated package before installation'); status = 'PASS' })
    }

    $report = [pscustomobject]@{
        status = 'PASS'
        test_count = $results.Count
        cases = $results.ToArray()
        chinese_profile_path_verified = $true
        host_powershell_version = [string]$PSVersionTable.PSVersion
        child_powershell_executable = $shell
        boundary = 'Real copied installer, encryption/extraction and subprocesses; synthetic payload/bootstrap/Doctor; mocked Codex; no real accounts, optional applications, or package downloads tested.'
        installer_sha256 = (Get-FileHash -LiteralPath (Join-Path $FixtureRoot 'install.ps1') -Algorithm SHA256).Hash.ToLowerInvariant()
    } | ConvertTo-Json -Depth 6
    if ($ReportPath) {
        $reportStream = [IO.File]::Open($ReportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try {
            $reportBytes = [Text.UTF8Encoding]::new($false).GetBytes($report + [Environment]::NewLine)
            $reportStream.Write($reportBytes, 0, $reportBytes.Length)
        } finally { $reportStream.Dispose() }
    }
    $report
} finally {
    $resolvedRoot = [IO.Path]::GetFullPath($testRoot).TrimEnd('\', '/')
    if ([IO.Path]::GetDirectoryName($resolvedRoot).TrimEnd('\', '/') -ne $testParent -or
        [IO.Path]::GetFileName($resolvedRoot) -notmatch '^mift-[a-f0-9]{12}$') {
        throw ('Refusing cleanup outside the exclusive test root: ' + $resolvedRoot)
    }
    if ($testRootCreated -and (Test-Path -LiteralPath $resolvedRoot)) {
        $reparse = @(Get-ChildItem -LiteralPath $resolvedRoot -Force -Recurse | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint })
        if ($reparse.Count -gt 0) { throw 'Refusing recursive cleanup: test root contains a reparse point.' }
        Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
    }
}
