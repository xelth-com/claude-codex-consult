<#
.SYNOPSIS
    Consult OpenAI Codex from Claude Code and record the consultation as files.

.DESCRIPTION
    A thin, dependency-free bridge. You write a Markdown brief; this script runs

        codex exec --sandbox <s> --color never --json [-m <model>] \
                   -c model_reasoning_effort="<e>" -o <tmp> [fork|resume <thread>] -

    from the git repository root, captures the JSONL event stream and the last
    agent message, wraps the reply in a handoff file, and appends one entry to
    <CollabDir>/<task>/sessions.json. Failed runs are recorded as failures too.

    Invariants:
      * read-only sandbox by default; danger-full-access is refused outright
      * every exec-level option must precede the fork|resume subcommand
      * the prompt travels on stdin ('-'), never as an argument
      * the model is whatever you pass with -Model; with no -Model, Codex uses
        the model from the user's ~/.codex/config.toml

    Runs on Windows PowerShell 5.1 and on PowerShell 7 (pwsh) for macOS/Linux.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 `
        -Task cache-rewrite -Mode fork `
        -Brief .collab/cache-rewrite/handoffs/03-claude-invalidation.md `
        -Prompt "Judge the invalidation strategy." -ReplyName invalidation

.EXAMPLE
    pwsh -NoProfile -File codex-consult.ps1 -Task cache-rewrite -DryRun `
        -Prompt "Sanity-check the plan."
#>
[CmdletBinding()]
param(
    # Task id -> <CollabDir>/<Task>/ . Groups one conversation's briefs, replies and ledger.
    [Parameter(Mandatory = $true)]
    [string]$Task,

    # Where consultations are stored. Relative paths resolve against the git repo root.
    [string]$CollabDir = '.collab',

    # new | resume | fork. Default: fork when a thread is known, otherwise new.
    [string]$Mode = '',

    # Thread (session) uuid for resume/fork. Default: the newest thread in the ledger.
    [string]$Thread = '',

    # Path to an existing Markdown brief. This script never writes briefs.
    [string]$Brief = '',

    # Short one-line ask, prepended to the prompt.
    [string]$Prompt = '',

    # Codex model. Empty (the default) means: do not pass -m, let Codex use its own config.
    [string]$Model = '',

    # low | medium | high | xhigh
    [string]$Effort = 'high',

    # read-only | workspace-write. danger-full-access is refused.
    [string]$Sandbox = 'read-only',

    # Word cap requested from Codex.
    [int]$MaxWords = 700,

    # Hard wall-clock limit; the codex process is killed when it is exceeded.
    [int]$TimeoutSec = 900,

    # Slug for the reply file: handoffs/<NN>-codex-<slug>.md
    [string]$ReplyName = 'reply',

    # Explicit path to the codex launcher. Env override: CODEX_CONSULT_EXE.
    [string]$CodexExe = '',

    # Print the plan (argv, paths, ledger entry) without calling codex.
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# PowerShell 5.1 has no $IsWindows; an undefined variable is $null there.
$script:OnWindows = if ($null -ne $IsWindows) { [bool]$IsWindows } else { $true }
$script:LegacyPS = ($PSVersionTable.PSVersion.Major -lt 6)

# ----------------------------------------------------------------------------- helpers

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, $script:Utf8NoBom)
}

# Start-Process holds the stdout/stderr redirection handles for a short while after
# the child exits, so a plain Get-Content can fail with "the process cannot access
# the file ... because it is being used by another process" - observed on a
# fast-failing codex run. Read with FileShare.ReadWrite and retry briefly.
function Read-SharedText {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    for ($attempt = 1; $attempt -le 6; $attempt++) {
        try {
            $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $sr = New-Object System.IO.StreamReader($fs, (New-Object System.Text.UTF8Encoding($false)), $true)
                try { return $sr.ReadToEnd() } finally { $sr.Dispose() }
            } finally { $fs.Dispose() }
        } catch {
            Start-Sleep -Milliseconds 250
        }
    }
    return ''
}

function Stop-WithError {
    param([string]$Message)
    Write-Host "codex-consult: $Message" -ForegroundColor Red
    exit 1
}

# Git is optional and every call here is allowed to fail (no repo, no commits yet,
# git not installed). Windows PowerShell turns a native command's stderr into a
# terminating NativeCommandError while $ErrorActionPreference is 'Stop', so relax it
# for the duration of the call and report failure as $null.
function Get-GitOutput {
    param([string]$Root, [string[]]$GitArgs)
    $all = @('-C', $Root) + $GitArgs
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git @all 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return $out
    } catch {
        return $null
    } finally {
        $ErrorActionPreference = $previous
    }
}

# Argument quoting: bare token when it is safe, otherwise wrap in double quotes and
# double any embedded quote. This is the Windows CRT rule, which is also what
# .NET's Process argument parser implements on macOS/Linux, so one form serves both.
# It is what survives the npm codex.cmd shim on Windows.
function ConvertTo-ProcArg {
    param([string]$Value)
    if ($Value -eq '-') { return $Value }
    if ($Value -match '^[A-Za-z0-9_.\-:\\/=]+$') { return $Value }
    return '"' + ($Value -replace '"', '""') + '"'
}

# Human-readable argv for the record in sessions.json.
function Format-Argv {
    param([string[]]$Argv)
    $parts = $Argv | ForEach-Object {
        if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
    }
    return ($parts -join ' ')
}

function Resolve-CodexLauncher {
    param([string]$Explicit)
    foreach ($candidate in @($Explicit, $env:CODEX_CONSULT_EXE)) {
        if ($candidate) {
            if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
            $cmd = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
        }
    }
    # On Windows, Get-Command 'codex' resolves to codex.ps1 (the npm shim), which
    # Start-Process cannot launch; ask for the native exe / cmd shim first.
    $names = if ($script:OnWindows) { @('codex.exe', 'codex.cmd', 'codex.bat', 'codex') } else { @('codex') }
    foreach ($name in $names) {
        $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Get-CodexHome {
    if ($env:CODEX_HOME) { return $env:CODEX_HOME }
    $home_ = $HOME
    if (-not $home_) { $home_ = $env:USERPROFILE }
    if (-not $home_) { return '' }
    return (Join-Path $home_ '.codex')
}

# Thread id from the `codex exec --json` event stream.
# Ground truth (codex-cli 0.155.x): the FIRST JSONL line of every run - new, resume
# and fork alike - is
#   {"type":"thread.started","thread_id":"01a0c86d-4d77-7c01-98b1-f682bf63c677"}
# i.e. the event named "thread.started" carries the resulting thread in its
# top-level "thread_id" field. The other shapes below are version-drift safety nets.
function Get-ThreadIdFromEvents {
    param([string]$Path)
    $text = Read-SharedText -Path $Path
    if (-not $text) { return '' }
    $uuidRe = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    foreach ($line in ($text -split "`r?`n")) {
        if (-not $line) { continue }
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = $trimmed | ConvertFrom-Json } catch { continue }
        # primary: the "thread.started" event
        if ($obj.PSObject.Properties['type'] -and $obj.type -eq 'thread.started') {
            if ($obj.PSObject.Properties['thread_id'] -and $obj.thread_id -match $uuidRe) {
                return [string]$obj.thread_id
            }
        }
        # drift net 1: any top-level thread/session/conversation id
        foreach ($field in @('thread_id', 'session_id', 'conversation_id')) {
            if ($obj.PSObject.Properties[$field] -and $obj.$field -match $uuidRe) {
                return [string]$obj.$field
            }
        }
        # drift net 2: the older msg-wrapped shape (session_configured)
        if ($obj.PSObject.Properties['msg']) {
            $msg = $obj.msg
            foreach ($field in @('session_id', 'thread_id')) {
                if ($msg -and $msg.PSObject.Properties[$field] -and $msg.$field -match $uuidRe) {
                    return [string]$msg.$field
                }
            }
        }
    }
    return ''
}

# Codex reports a failed turn on the JSON event stream (stdout), not on stderr:
#   {"type":"error","message":"You've hit your usage limit. ..."}
#   {"type":"turn.failed","error":{"message":"..."}}
# Without this, a quota or auth failure shows up only as a bare "codex exit 1".
function Get-ErrorFromEvents {
    param([string]$Path)
    $text = Read-SharedText -Path $Path
    if (-not $text) { return '' }
    $found = ''
    foreach ($line in ($text -split "`r?`n")) {
        if (-not $line) { continue }
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = $trimmed | ConvertFrom-Json } catch { continue }
        if (-not $obj.PSObject.Properties['type']) { continue }
        if ($obj.type -eq 'error' -and $obj.PSObject.Properties['message'] -and $obj.message) {
            $found = [string]$obj.message
        } elseif ($obj.type -eq 'turn.failed' -and $obj.PSObject.Properties['error']) {
            $err = $obj.error
            if ($err -and $err.PSObject.Properties['message'] -and $err.message) {
                $found = [string]$err.message
            }
        }
    }
    return ($found -replace '\s+', ' ').Trim()
}

# Fallback: newest <codex home>/sessions/<yyyy>/<mm>/<dd>/rollout-*-<uuid>.jsonl
# created after the run started.
function Get-ThreadIdFromRollout {
    param([datetime]$StartedAt)
    $codexHome = Get-CodexHome
    if (-not $codexHome) { return '' }
    $root = Join-Path $codexHome 'sessions'
    if (-not (Test-Path -LiteralPath $root)) { return '' }
    $days = @($StartedAt, (Get-Date)) | ForEach-Object {
        Join-Path (Join-Path (Join-Path $root ('{0:yyyy}' -f $_)) ('{0:MM}' -f $_)) ('{0:dd}' -f $_)
    } | Select-Object -Unique
    $candidates = @()
    foreach ($day in $days) {
        if (Test-Path -LiteralPath $day) {
            $candidates += Get-ChildItem -LiteralPath $day -Filter 'rollout-*.jsonl' -File -ErrorAction SilentlyContinue
        }
    }
    $newest = $candidates |
        Where-Object { $_.LastWriteTime -ge $StartedAt.AddSeconds(-5) } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $newest) { return '' }
    if ($newest.Name -match '([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})') {
        return $Matches[1]
    }
    return ''
}

# ----------------------------------------------------------------------------- validation

$validEfforts = @('low', 'medium', 'high', 'xhigh')
if ($validEfforts -notcontains $Effort) {
    Stop-WithError "-Effort must be one of: $($validEfforts -join ', ') (got '$Effort')."
}
if ($Sandbox -eq 'danger-full-access') {
    Stop-WithError "-Sandbox danger-full-access is refused: consultations run without write access to your machine."
}
$validSandboxes = @('read-only', 'workspace-write')
if ($validSandboxes -notcontains $Sandbox) {
    Stop-WithError "-Sandbox must be one of: $($validSandboxes -join ', ') (got '$Sandbox')."
}
$validModes = @('', 'new', 'resume', 'fork')
if ($validModes -notcontains $Mode) {
    Stop-WithError "-Mode must be one of: new, resume, fork (got '$Mode')."
}
if (-not $Brief -and -not $Prompt) {
    Stop-WithError "Give at least one of -Brief <path> or -Prompt <text>."
}
if ($ReplyName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Stop-WithError "-ReplyName must be a slug (letters, digits, dot, dash, underscore)."
}
if ($Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Stop-WithError "-Task must be a slug (letters, digits, dot, dash, underscore)."
}

$modelLabel = if ($Model) { $Model } else { 'config default' }

# ----------------------------------------------------------------------------- repo + task

# The working directory of the caller is the project being discussed, not the
# directory this script lives in (a plugin installs it outside the project).
$callerCwd = (Get-Location).Path
$repoRoot = Get-GitOutput -Root $callerCwd -GitArgs @('rev-parse', '--show-toplevel')
if ($repoRoot) {
    $repoRoot = (Resolve-Path -LiteralPath (([string]$repoRoot).Trim())).Path
} else {
    # Not a git repository: fall back to the current directory.
    $repoRoot = $callerCwd
}

$collabRoot = $CollabDir
if (-not [IO.Path]::IsPathRooted($collabRoot)) { $collabRoot = Join-Path $repoRoot $CollabDir }

$taskDir = Join-Path $collabRoot $Task
$handoffsDir = Join-Path $taskDir 'handoffs'
$sessionsPath = Join-Path $taskDir 'sessions.json'

$shortSha = Get-GitOutput -Root $repoRoot -GitArgs @('rev-parse', '--short', 'HEAD')
if ($shortSha) { $shortSha = ([string]$shortSha).Trim() } else { $shortSha = 'unknown' }
$porcelain = Get-GitOutput -Root $repoRoot -GitArgs @('status', '--porcelain')
$reviewedRevision = $shortSha
if ($porcelain -and (@($porcelain).Count -gt 0)) { $reviewedRevision = "$shortSha + uncommitted" }

$codexExePath = Resolve-CodexLauncher -Explicit $CodexExe

$codexVersion = 'unknown'
if ($codexExePath) {
    try {
        $v = & $codexExePath --version 2>$null
        if ($v) { $codexVersion = ([string]@($v)[0]).Trim() }
    } catch { }
}
# "codex-cli 0.155.1" -> "0.155.1" for the prose header; sessions.json keeps the full string.
$codexVersionShort = $codexVersion -replace '^codex-cli\s+', ''

if (-not $DryRun) {
    if (-not (Test-Path -LiteralPath $handoffsDir)) {
        New-Item -ItemType Directory -Path $handoffsDir -Force | Out-Null
    }
}

# sessions.json: load or build the skeleton.
$sessions = $null
if (Test-Path -LiteralPath $sessionsPath) {
    try {
        $sessions = (Read-SharedText -Path $sessionsPath) | ConvertFrom-Json
    } catch {
        Stop-WithError "could not parse '$sessionsPath': $($_.Exception.Message)"
    }
} else {
    $sessions = [pscustomobject]@{
        task_id = $Task
        cwd     = $repoRoot
        codex   = [pscustomobject]@{
            tool     = $codexVersion
            consults = @()
        }
    }
    if (-not $DryRun) {
        Write-Utf8NoBom -Path $sessionsPath -Text (($sessions | ConvertTo-Json -Depth 10) + "`n")
    }
}
if (-not $sessions.PSObject.Properties['codex']) {
    $sessions | Add-Member -NotePropertyName 'codex' -NotePropertyValue ([pscustomobject]@{ tool = $codexVersion; consults = @() })
}
if (-not $sessions.codex.PSObject.Properties['consults']) {
    $sessions.codex | Add-Member -NotePropertyName 'consults' -NotePropertyValue @()
}
$sessions.codex.tool = $codexVersion

# ----------------------------------------------------------------------------- mode + thread

$consults = @($sessions.codex.consults | Where-Object { $_ })
$knownThread = ''
if ($Thread) {
    $knownThread = $Thread.Trim()
} else {
    for ($i = $consults.Count - 1; $i -ge 0; $i--) {
        $c = $consults[$i]
        if ($c.PSObject.Properties['thread'] -and $c.thread) { $knownThread = [string]$c.thread; break }
    }
}

if (-not $Mode) {
    if ($knownThread) { $Mode = 'fork' } else { $Mode = 'new' }
}
if ($Mode -ne 'new' -and -not $knownThread) {
    Stop-WithError "-Mode $Mode needs a thread: pass -Thread <uuid>, or make sure '$sessionsPath' has codex.consults[].thread."
}
$parentThread = ''
if ($Mode -ne 'new') { $parentThread = $knownThread }

# ----------------------------------------------------------------------------- brief + prompt

$briefRef = ''
if ($Brief) {
    $briefPath = $Brief
    if (-not [IO.Path]::IsPathRooted($briefPath)) {
        foreach ($base in @($callerCwd, $repoRoot)) {
            $candidate = Join-Path $base $briefPath
            if (Test-Path -LiteralPath $candidate) { $briefPath = $candidate; break }
        }
    }
    if (-not (Test-Path -LiteralPath $briefPath)) {
        Stop-WithError "brief '$Brief' not found (this script never writes briefs; write it first)."
    }
    $briefPath = (Resolve-Path -LiteralPath $briefPath).Path
    if ($briefPath.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $briefRef = $briefPath.Substring($repoRoot.Length).TrimStart([char]'\', [char]'/').Replace('\', '/')
    } else {
        # Outside the repository: Codex still reads it (read-only sandbox reads are
        # not path-limited), but the prompt must carry the absolute path.
        $briefRef = $briefPath
    }
}

$promptParts = New-Object System.Collections.ArrayList
if ($Prompt) { [void]$promptParts.Add($Prompt.Trim()) }
if ($briefRef) {
    [void]$promptParts.Add("Read the brief at ``$briefRef`` (path relative to the repository root, which is your working directory) and answer every numbered question in it.")
}
[void]$promptParts.Add("Constraints: write NO files and make no edits - this is a read-only consultation; answer in English; keep the answer under $MaxWords words.")
$promptText = [string]::Join("`r`n`r`n", $promptParts.ToArray())

# ----------------------------------------------------------------------------- file names

$maxN = 0
if (Test-Path -LiteralPath $handoffsDir) {
    Get-ChildItem -LiteralPath $handoffsDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -match '^(\d{2})-') {
            $n = [int]$Matches[1]
            if ($n -gt $maxN) { $maxN = $n }
        }
    }
}
$nn = '{0:D2}' -f ($maxN + 1)
# NB: PowerShell variable names are case-insensitive - never call these $replyName,
# that would silently clobber the -ReplyName parameter.
$replyFileName = "$nn-codex-$ReplyName.md"
$eventsFileName = "$nn-codex-$ReplyName.events.jsonl"
$replyPath = Join-Path $handoffsDir $replyFileName
$eventsPath = Join-Path $handoffsDir $eventsFileName
$replyRel = "handoffs/$replyFileName"
$eventsRel = "handoffs/$eventsFileName"

$tmpRoot = [System.IO.Path]::GetTempPath()
$tmpId = [guid]::NewGuid().ToString('N')
$lastMsgPath = Join-Path $tmpRoot "codex-consult-last-$tmpId.md"
$promptPath = Join-Path $tmpRoot "codex-consult-prompt-$tmpId.txt"
$stderrPath = Join-Path $tmpRoot "codex-consult-stderr-$tmpId.txt"

# ----------------------------------------------------------------------------- argv

# Exec-level options MUST precede the fork|resume subcommand: `codex exec fork --help`
# has no --sandbox/--color, and placing them after the subcommand fails with
# "unexpected argument".
$argv = @(
    'exec',
    '--sandbox', $Sandbox,
    '--color', 'never',
    '--json'
)
if ($Model) { $argv += @('-m', $Model) }
$argv += @(
    '-c', ('model_reasoning_effort="' + $Effort + '"'),
    '-o', $lastMsgPath
)
if ($Mode -eq 'fork') { $argv += @('fork', $knownThread) }
elseif ($Mode -eq 'resume') { $argv += @('resume', $knownThread) }
# The prompt is piped on stdin ('-'): a prompt passed as a positional argument
# would travel through the npm codex.cmd shim on Windows, where cmd.exe still
# expands %VAR% inside double quotes and would corrupt briefs that mention
# %APPDATA% & co.
$argv += '-'

$commandStr = 'codex ' + (Format-Argv $argv)

if ($DryRun) {
    $preview = [pscustomobject]@{
        n                 = $consults.Count + 1
        when              = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        parent_thread     = $parentThread
        thread            = '<filled from the event stream>'
        thread_source     = 'events|rollout|unknown'
        mode              = $Mode
        command           = $commandStr
        brief             = $briefRef
        prompt_chars      = $promptText.Length
        reply             = $replyRel
        events            = $eventsRel
        model             = $modelLabel
        effort            = $Effort
        sandbox           = $Sandbox
        reviewed_revision = $reviewedRevision
        outcome           = '<usable reply | failed: ...>'
        wall_seconds      = 0
    }
    Write-Host "DRY RUN - nothing was executed and no file was written." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "repo root   : $repoRoot"
    Write-Host "task dir    : $taskDir"
    Write-Host "sessions    : $sessionsPath"
    if ($codexExePath) { Write-Host "launcher    : $codexExePath" }
    else { Write-Host "launcher    : (codex not found on PATH)" -ForegroundColor Yellow }
    Write-Host "codex       : $codexVersion"
    Write-Host "model       : $modelLabel"
    Write-Host "mode        : $Mode"
    if ($Mode -eq 'new') { Write-Host "thread      : (a new thread will be created)" }
    else { Write-Host "thread      : $knownThread (parent for $Mode)" }
    Write-Host ""
    Write-Host "argv        :"
    $argv | ForEach-Object { Write-Host "    $_" }
    Write-Host ""
    Write-Host "command     : $commandStr"
    Write-Host "prompt (stdin, $($promptText.Length) chars):"
    Write-Host "----"
    Write-Host $promptText
    Write-Host "----"
    Write-Host ""
    Write-Host "reply file  : $replyPath"
    Write-Host "events file : $eventsPath"
    Write-Host "last message: $lastMsgPath (temp)"
    Write-Host ""
    Write-Host "sessions.json entry preview:"
    Write-Host ($preview | ConvertTo-Json -Depth 10)
    exit 0
}

# ----------------------------------------------------------------------------- run

if (-not $codexExePath) {
    Stop-WithError "codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable)."
}

Write-Utf8NoBom -Path $promptPath -Text $promptText

$startedAt = Get-Date
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$exitCode = -1
$outcome = ''
$argStr = (($argv | ForEach-Object { ConvertTo-ProcArg $_ }) -join ' ')

try {
    $proc = Start-Process -FilePath $codexExePath -ArgumentList $argStr `
        -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
        -RedirectStandardOutput $eventsPath `
        -RedirectStandardError $stderrPath `
        -RedirectStandardInput $promptPath
    # PS 5.1: touching .Handle before the process exits caches it, otherwise
    # .ExitCode comes back empty on a -PassThru process.
    if ($script:LegacyPS) { try { $null = $proc.Handle } catch { } }
    $finished = $proc.WaitForExit($TimeoutSec * 1000)
    if (-not $finished) {
        try { $proc.Kill() } catch { }
        $null = $proc.WaitForExit(10000)
        $outcome = "failed: timeout after $TimeoutSec s"
    } else {
        $exitCode = $proc.ExitCode
    }
} catch {
    $outcome = "failed: could not start codex - $($_.Exception.Message)"
}
$stopwatch.Stop()
$wallSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)

$stderrText = Read-SharedText -Path $stderrPath
$rawReply = (Read-SharedText -Path $lastMsgPath).Trim()

# thread id - never let a parse/IO problem here swallow the sessions.json record
$threadId = ''
$threadSource = 'unknown'
try {
    $threadId = Get-ThreadIdFromEvents -Path $eventsPath
    if ($threadId) {
        $threadSource = 'events'
    } else {
        $threadId = Get-ThreadIdFromRollout -StartedAt $startedAt
        if ($threadId) { $threadSource = 'rollout' }
    }
} catch {
    $threadId = ''
    $threadSource = 'unknown'
}

$eventError = ''
try { $eventError = Get-ErrorFromEvents -Path $eventsPath } catch { $eventError = '' }

if (-not $outcome) {
    if ($exitCode -ne 0) {
        $detail = $eventError
        if (-not $detail -and $stderrText) {
            $detail = ($stderrText.Trim() -split "`r?`n" | Select-Object -Last 1)
        }
        $tail = ''
        if ($detail) { $tail = ' - ' + $detail }
        $outcome = "failed: codex exit $exitCode$tail"
    } elseif (-not $rawReply) {
        $detail = ''
        if ($eventError) { $detail = ' - ' + $eventError }
        $outcome = "failed: empty reply$detail"
    } else {
        $outcome = 'usable reply'
    }
}

# ----------------------------------------------------------------------------- reply file

$parentLine = 'Parent thread: (none - new thread).'
if ($parentThread) { $parentLine = "Parent thread: ``$parentThread``." }
$resultThread = '(unknown)'
if ($threadId) { $resultThread = "``$threadId``" }
$briefLine = 'Brief: (none, prompt only).'
if ($briefRef) { $briefLine = "Brief: ``$briefRef``." }

$header = @"
# Handoff $nn - Codex: $ReplyName

Date: $($startedAt.ToString('yyyy-MM-dd HH:mm')) local. Author: Codex (model $modelLabel, effort $Effort), Codex CLI $codexVersionShort.
Invocation: ``codex-consult.ps1`` (mode: $Mode, sandbox: $Sandbox). Argv: ``$commandStr`` (prompt on stdin).
$parentLine Result thread: $resultThread (source: $threadSource).
$briefLine Reviewed revision: $reviewedRevision. Outcome: $outcome. Wall time: $wallSeconds s.
Raw event stream: ``$eventsRel``.
Verbatim reply follows.

---

"@

$body = $rawReply
if (-not $body) {
    $body = "_(no reply captured)_"
    if ($eventError) {
        $body += "`n`nCodex reported: $eventError"
    }
    if ($stderrText.Trim()) {
        $body += "`n`n```````n" + $stderrText.Trim() + "`n``````"
    }
}
Write-Utf8NoBom -Path $replyPath -Text (($header -replace "`r`n", "`n") + "`n" + ($body -replace "`r`n", "`n") + "`n")

# ----------------------------------------------------------------------------- sessions.json

$entry = [pscustomobject]@{
    n                 = $consults.Count + 1
    when              = $startedAt.ToString('yyyy-MM-ddTHH:mm:sszzz')
    parent_thread     = $parentThread
    thread            = $threadId
    thread_source     = $threadSource
    mode              = $Mode
    command           = $commandStr
    brief             = $briefRef
    prompt_chars      = $promptText.Length
    reply             = $replyRel
    events            = $eventsRel
    model             = $modelLabel
    effort            = $Effort
    sandbox           = $Sandbox
    reviewed_revision = $reviewedRevision
    outcome           = $outcome
    wall_seconds      = $wallSeconds
}
$newConsults = @()
$newConsults += $consults
$newConsults += $entry
$sessions.codex.consults = [object[]]$newConsults
Write-Utf8NoBom -Path $sessionsPath -Text ((($sessions | ConvertTo-Json -Depth 10) -replace "`r`n", "`n") + "`n")

# ----------------------------------------------------------------------------- cleanup + output

foreach ($tmp in @($lastMsgPath, $promptPath, $stderrPath)) {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

if ($outcome -ne 'usable reply') {
    Write-Host "codex-consult: $outcome (wall $wallSeconds s)" -ForegroundColor Red
    Write-Host "reply file : $replyPath"
    Write-Host "events file: $eventsPath"
    if ($stderrText.Trim()) {
        Write-Host "--- codex stderr (tail) ---"
        Write-Host (($stderrText.Trim() -split "`r?`n" | Select-Object -Last 20) -join "`n")
    }
    exit 1
}

Write-Host "codex-consult: $outcome - mode $Mode, thread $threadId (source: $threadSource), wall $wallSeconds s"
Write-Host "reply file : $replyPath"
Write-Host "events file: $eventsPath"
Write-Host ""
Write-Host $rawReply
exit 0
