param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$CanonicalPluginRoot,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvitePluginRoot
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedHash([IO.FileInfo]$File) {
    $bytes = [IO.File]::ReadAllBytes($File.FullName)
    if ($File.Extension -in @('.json', '.md', '.py', '.txt', '.yaml', '.yml', '.toml')) {
        $content = [Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF).Replace("`r`n", "`n")
        $bytes = [Text.Encoding]::UTF8.GetBytes($content)
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $digest = $sha.ComputeHash($bytes)
        return -join ($digest | ForEach-Object { $_.ToString('x2') })
    }
    finally {
        $sha.Dispose()
    }
}

function Get-FunctionalManifest([string]$Root) {
    $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw ('Plugin root does not exist: ' + $resolvedRoot)
    }
    return @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\__pycache__\\' -and $_.Extension -ne '.pyc' } |
        ForEach-Object {
            [pscustomobject]@{
                Relative = $_.FullName.Substring($resolvedRoot.Length).TrimStart('\')
                Hash = Get-NormalizedHash $_
            }
        } |
        Sort-Object Relative)
}

$canonical = @(Get-FunctionalManifest $CanonicalPluginRoot)
$invite = @(Get-FunctionalManifest $InvitePluginRoot)
$differences = @(Compare-Object -ReferenceObject $canonical -DifferenceObject $invite -Property Relative, Hash)
if ($differences.Count -ne 0) {
    $differences | Format-Table -AutoSize
    throw ('Capability parity failed with ' + $differences.Count + ' file differences.')
}

Write-Host ('Capability parity passed: ' + $canonical.Count + ' functional files are identical.')
