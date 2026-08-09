param(
    [Parameter(Mandatory = $true)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
$resolvedPath = (Resolve-Path -LiteralPath $Path).Path
$content = Get-Content -Raw -LiteralPath $resolvedPath -Encoding UTF8

$forbiddenVariants = [ordered]@{
    'WEI GE' = 'VI QUA'
}

$errors = @()
foreach ($variant in $forbiddenVariants.Keys) {
    if ($content -cmatch [regex]::Escape($variant)) {
        $errors += "Tên không thống nhất '$variant'; phải dùng '$($forbiddenVariants[$variant])'."
    }
}

if ($content -match '[\p{IsCJKUnifiedIdeographs}]') {
    $errors += 'Tệp chương còn chứa chữ Hán chưa biên tập.'
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "NAME_VALIDATION_OK path=$resolvedPath"
