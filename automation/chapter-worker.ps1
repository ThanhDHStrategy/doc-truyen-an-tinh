[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Inspect', 'Acquire', 'Stage', 'Complete', 'Release')]
    [string]$Action,

    [string]$RepoPath,
    [string]$StatePath,
    [string]$RunId,
    [string]$Stage,
    [int]$Chapter,
    [string]$Commit,
    [int]$LeaseMinutes = 20
)

$ErrorActionPreference = 'Stop'

if (-not $RepoPath) {
    $RepoPath = Split-Path -Parent $PSScriptRoot
}
$RepoPath = [IO.Path]::GetFullPath($RepoPath)

if (-not $StatePath) {
    $StatePath = Join-Path $RepoPath '.automation'
}
$StatePath = [IO.Path]::GetFullPath($StatePath)

$libraryPath = Join-Path $RepoPath 'data\library.json'
$contentPath = Join-Path $RepoPath 'content\ta-chi-muon-an-tinh-choi-game'
$lockPath = Join-Path $StatePath 'chapter-worker.lock.json'
$checkpointPath = Join-Path $StatePath 'chapter-checkpoint.json'

function Write-JsonResult {
    param([hashtable]$Value)
    $Value | ConvertTo-Json -Depth 8 -Compress
}

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-JsonAtomic {
    param([string]$Path, [object]$Value)
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $tempPath = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    $json = $Value | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($tempPath, $json, [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
}

function New-LockExclusive {
    param([string]$Path, [object]$Value)
    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $json = $Value | ConvertTo-Json -Depth 8
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
}

function Get-RepositoryState {
    if (-not (Test-Path -LiteralPath $libraryPath)) {
        throw "library.json not found: $libraryPath"
    }

    $library = Read-JsonFile $libraryPath
    $published = [int]$library.chapterCount
    $next = $published + 1
    $nextFile = Join-Path $contentPath ('{0:D4}.html' -f $next)
    $htmlCount = @(Get-ChildItem -LiteralPath $contentPath -Filter '*.html' -File).Count
    $gitStatus = @(& git -C $RepoPath status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read Git status.' }

    [ordered]@{
        publishedChapter = $published
        nextChapter = $next
        nextFileExists = Test-Path -LiteralPath $nextFile
        htmlCount = $htmlCount
        libraryMatchesHtml = ($published -eq $htmlCount)
        gitTrackedClean = ($gitStatus.Count -eq 0)
        gitChanges = $gitStatus
        headCommit = (& git -C $RepoPath rev-parse --short HEAD).Trim()
    }
}

function Get-LockState {
    $lock = Read-JsonFile $lockPath
    if (-not $lock) { return $null }
    $leaseTimestamp = if ($lock.updatedAt) { $lock.updatedAt } else { $lock.startedAt }
    $lastActivity = [DateTimeOffset]::Parse($leaseTimestamp)
    $ageMinutes = ([DateTimeOffset]::UtcNow - $lastActivity).TotalMinutes
    [ordered]@{
        data = $lock
        inactiveMinutes = [Math]::Round($ageMinutes, 2)
        valid = ($ageMinutes -lt $LeaseMinutes)
    }
}

switch ($Action) {
    'Inspect' {
        $repo = Get-RepositoryState
        $lock = Get-LockState
        $checkpoint = Read-JsonFile $checkpointPath
        Write-JsonResult ([ordered]@{
            decision = if ($lock -and $lock.valid) { 'LOCKED' } elseif (-not $repo.libraryMatchesHtml) { 'BLOCKED_INCONSISTENT_COUNT' } elseif (-not $repo.gitTrackedClean) { 'BLOCKED_GIT_DIRTY' } elseif ($repo.nextFileExists) { 'VERIFY_EXISTING_TARGET' } else { 'READY' }
            repository = $repo
            lock = $lock
            checkpoint = $checkpoint
        })
    }

    'Acquire' {
        if (-not $RunId) { $RunId = [Guid]::NewGuid().ToString('N') }
        $repo = Get-RepositoryState
        $existing = Get-LockState
        if ($existing -and $existing.valid) {
            Write-JsonResult ([ordered]@{ acquired = $false; decision = 'LOCKED'; lock = $existing })
            exit 2
        }
        if (-not $repo.libraryMatchesHtml) { throw 'chapterCount does not match the HTML file count.' }
        if (-not $repo.gitTrackedClean) { throw 'Tracked Git changes exist; automatic processing is blocked.' }
        if ($repo.nextFileExists) { throw 'Target chapter already exists; verify it instead of recreating it.' }

        if (-not (Test-Path -LiteralPath $StatePath)) {
            New-Item -ItemType Directory -Path $StatePath -Force | Out-Null
        }
        if (Test-Path -LiteralPath $lockPath) {
            Remove-Item -LiteralPath $lockPath -Force
        }

        $lock = [ordered]@{
            runId = $RunId
            chapter = $repo.nextChapter
            stage = 'ACQUIRED'
            startedAt = [DateTimeOffset]::UtcNow.ToString('o')
            updatedAt = [DateTimeOffset]::UtcNow.ToString('o')
            baseCommit = $repo.headCommit
        }
        try {
            New-LockExclusive -Path $lockPath -Value $lock
        }
        catch [IO.IOException] {
            $racedLock = Get-LockState
            Write-JsonResult ([ordered]@{ acquired = $false; decision = 'LOCKED'; lock = $racedLock })
            exit 2
        }
        Write-JsonResult ([ordered]@{ acquired = $true; decision = 'PROCESS'; lock = $lock; repository = $repo })
    }

    'Stage' {
        if (-not $RunId -or -not $Stage) { throw 'Stage requires RunId and Stage.' }
        $lock = Read-JsonFile $lockPath
        if (-not $lock) { throw 'No active lock exists.' }
        if ($lock.runId -ne $RunId) { throw 'RunId does not own the lock.' }
        $lock.stage = $Stage
        $lock.updatedAt = [DateTimeOffset]::UtcNow.ToString('o')
        Write-JsonAtomic -Path $lockPath -Value $lock
        Write-JsonResult ([ordered]@{ updated = $true; lock = $lock })
    }

    'Complete' {
        if (-not $RunId -or $Chapter -le 0 -or -not $Commit) { throw 'Complete requires RunId, Chapter, and Commit.' }
        $lock = Read-JsonFile $lockPath
        if (-not $lock -or $lock.runId -ne $RunId) { throw 'RunId does not own the lock.' }
        $repo = Get-RepositoryState
        $chapterFile = Join-Path $contentPath ('{0:D4}.html' -f $Chapter)
        if ($repo.publishedChapter -ne $Chapter) { throw 'library.json does not contain the completed chapter.' }
        if (-not (Test-Path -LiteralPath $chapterFile)) { throw 'Completed chapter file does not exist.' }
        if ($repo.headCommit -ne $Commit) { throw 'Checkpoint commit does not match HEAD.' }

        $checkpoint = [ordered]@{
            lastPublishedChapter = $Chapter
            lastCommit = $Commit
            nextChapter = $Chapter + 1
            stage = 'READY'
            blockedReason = $null
            verifiedAt = [DateTimeOffset]::UtcNow.ToString('o')
        }
        Write-JsonAtomic -Path $checkpointPath -Value $checkpoint
        Write-JsonResult ([ordered]@{ completed = $true; checkpoint = $checkpoint })
    }

    'Release' {
        if (-not $RunId) { throw 'Release requires RunId.' }
        $lock = Read-JsonFile $lockPath
        if (-not $lock) {
            Write-JsonResult ([ordered]@{ released = $true; alreadyAbsent = $true })
            break
        }
        if ($lock.runId -ne $RunId) { throw 'RunId does not own the lock.' }
        Remove-Item -LiteralPath $lockPath -Force
        Write-JsonResult ([ordered]@{ released = $true; alreadyAbsent = $false })
    }
}
