<#
Removes a UTF-8 byte-order mark (EF BB BF) from files beneath the project root.
It changes no file that does not begin with that exact three-byte sequence.

Usage:
  .\tools\remove-utf8-bom.ps1
  .\tools\remove-utf8-bom.ps1 -Root C:\path\to\project
#>

[CmdletBinding()]
param(
    [string[]]$Root = @((Split-Path -Parent $PSScriptRoot))
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

# The script is already recursive. Accept common shell wildcards as a request
# to scan this project, rather than treating them as a literal directory name.
if ($Root.Count -ne 1 -or [string]::IsNullOrWhiteSpace($Root[0]) -or $Root[0] -match '[*?]') {
    $Root = @($projectRoot)
}

$resolvedRoot = (Resolve-Path -LiteralPath $Root[0]).Path
$excludedDirectoryNames = @('.git', '.dart_tool', 'build', 'bin', 'obj')
$updated = [System.Collections.Generic.List[string]]::new()

Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse -Force |
    Where-Object {
        $relativePath = $_.FullName.Substring($resolvedRoot.Length).TrimStart('\', '/')
        $segments = $relativePath -split '[\\/]'
        -not ($segments | Where-Object { $_ -in $excludedDirectoryNames })
    } |
    ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        if ($bytes.Length -ge 3 -and
            $bytes[0] -eq 0xEF -and
            $bytes[1] -eq 0xBB -and
            $bytes[2] -eq 0xBF) {
            [System.IO.File]::WriteAllBytes($_.FullName, $bytes[3..($bytes.Length - 1)])
            $updated.Add($_.FullName)
        }
    }

if ($updated.Count -eq 0) {
    Write-Host 'No UTF-8 BOMs found.'
} else {
    Write-Host "Removed UTF-8 BOM from $($updated.Count) file(s):"
    $updated | ForEach-Object { Write-Host " - $_" }
}
