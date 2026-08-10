[CmdletBinding()]
param(
    [string]$SourceDirectory = 'C:\Users\nhimn\Documents\APP Đọc truyện Offline\output\transcribe\source-docs\ta-chi-muon-an-tinh-choi-game',
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
if (-not $OutputPath) {
    $OutputPath = Join-Path (Split-Path -Parent $PSScriptRoot) '.automation\source-index.json'
}
$records = [System.Collections.Generic.List[object]]::new()

Get-ChildItem -LiteralPath $SourceDirectory -Filter '*.txt' -File | Sort-Object Name | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw -Encoding utf8
    $matches = [regex]::Matches($text, '第\s*(\d+)\s*章\s*([^\r\n]+)')
    for ($i = 0; $i -lt $matches.Count; $i++) {
        $start = $matches[$i].Index
        $end = if ($i + 1 -lt $matches.Count) { $matches[$i + 1].Index } else { $text.Length }
        $body = $text.Substring($start, $end - $start).Trim()
        $chapter = [int]$matches[$i].Groups[1].Value
        $title = $matches[$i].Groups[2].Value.Trim()
        $records.Add([ordered]@{
            chapter = $chapter
            sourceTitle = $title
            sourceFile = $_.Name
            characters = $body.Length
            sha256 = ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($body)))).ToLowerInvariant()
            status = if ($body.Length -ge 300) { 'READY_FOR_TRANSLATION' } else { 'BLOCKED_SHORT_SOURCE' }
        })
    }
}

$duplicates = @($records | Group-Object chapter | Where-Object Count -gt 1 | ForEach-Object { [int]$_.Name })
foreach ($record in $records) {
    if ($duplicates -contains $record.chapter) { $record.status = 'BLOCKED_DUPLICATE_CHAPTER' }
}

$payload = [ordered]@{
    generatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    sourceDirectory = $SourceDirectory
    chapters = @($records | Sort-Object chapter)
    duplicateChapters = $duplicates
}
$directory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $directory -Force | Out-Null
[IO.File]::WriteAllText($OutputPath, ($payload | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
$payload | ConvertTo-Json -Depth 5
