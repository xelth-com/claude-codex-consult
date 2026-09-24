<#
.SYNOPSIS
    Consult OpenAI Codex from Claude Code and record the consultation as files.

.DESCRIPTION
    A thin, dependency-free bridge. You write a Markdown brief; this script runs

        codex exec --sandbox <s> --color never --json [-m <model>] \
                   -c model_reasoning_effort="<e>" -o <tmp> \
                   [--output-schema <plugin>/schemas/consult-reply.schema.json] \
                   [fork|resume <thread>] -

    from the git repository root, captures the JSONL event stream and the last
    agent message, wraps the reply in a handoff file, and appends one entry to
    <CollabDir>/<task>/sessions.json. Failed runs are recorded as failures too.

    Structured mode (the default) asks Codex for one JSON object matching
    schemas/consult-reply.schema.json (verdict, reply_markdown, findings, ...),
    validates it locally, renders it into the handoff file, keeps the raw object as
    handoffs/NN-codex-<slug>.reply.json and tracks the findings by id in
    <CollabDir>/<task>/findings.json (statuses are moved by codex-findings.ps1).
    -Raw is the 0.1 plain-text consultation without any of that.

    Invariants:
      * read-only sandbox by default; danger-full-access is refused outright
      * every exec-level option must precede the fork|resume subcommand
      * the prompt travels on stdin ('-'), never as an argument
      * the model is whatever you pass with -Model; with no -Model, Codex uses
        the model from the user's ~/.codex/config.toml
      * one consultation per task directory at a time: <task>/.consult.lock is a
        permanent file held open while a run lasts (never delete it to "unlock";
        closing the process releases it). <task>/.consult.pending.json exists
        only while a run is in progress or after one was interrupted; the next
        run checks it and refuses while that run's codex process may still be
        running. One Codex thread belongs to one task directory (not enforced).

    Runs on Windows PowerShell 5.1 and on PowerShell 7 (pwsh) for macOS/Linux.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-consult.ps1 `
        -Task cache-rewrite -Mode fork -Purpose acceptance `
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

    # framing | decision | checkpoint | core-contract | acceptance | diff-review | stuck.
    # Sets the default effort and word cap and adds a purpose paragraph to the prompt.
    [string]$Purpose = '',

    # low | medium | high | xhigh. Empty (the default): the purpose preset.
    [string]$Effort = '',

    # read-only | workspace-write. danger-full-access is refused.
    [string]$Sandbox = 'read-only',

    # Word cap requested from Codex (reply_markdown only; findings are never cut to
    # fit it). 0 (the default): the purpose preset.
    [int]$MaxWords = 0,

    # Hard wall-clock limit; the codex process tree is killed when it is exceeded.
    [int]$TimeoutSec = 900,

    # Slug for the reply file: handoffs/<NN>-codex-<slug>.md
    [string]$ReplyName = 'reply',

    # Built artifacts (binaries, packages) to bind the review to: their SHA-256 goes
    # into the ledger. Relative to the current directory or the repo root. Several
    # paths: -Artifact a.exe,b.dll (with -File, one comma-separated string works too).
    [string[]]$Artifact = @(),

    # 0.1-style plain-text consultation: no --output-schema, no findings bookkeeping.
    [switch]$Raw,

    # Explicit path to the codex launcher. Env override: CODEX_CONSULT_EXE.
    [string]$CodexExe = '',

    # Print the plan (argv, prompt, paths, ledger entry) without calling codex and
    # without writing anything.
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

# ----------------------------------------------------------------------------- codex helpers

function Resolve-CodexLauncher {
    param([string]$Explicit)
    # An explicit launcher (-CodexExe, then CODEX_CONSULT_EXE) that does not resolve is an
    # error, never a silent fall-through to whatever `codex` is on PATH.
    $explicitSources = @(@{ value = $Explicit; label = '-CodexExe' }, @{ value = $env:CODEX_CONSULT_EXE; label = 'CODEX_CONSULT_EXE' })
    foreach ($source in $explicitSources) {
        $candidate = [string]$source.value
        if ($candidate) {
            if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
            $cmd = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
            if ($cmd) { return $cmd.Source }
            Stop-WithError "$($source.label) '$candidate' is not a file and not an application on PATH."
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

# Token usage from the last `turn.completed` event:
#   {"type":"turn.completed","usage":{"input_tokens":206772,"cached_input_tokens":163840,
#    "cache_write_input_tokens":0,"output_tokens":1581,"reasoning_output_tokens":113}}
# The four recorded fields are copied when present; a missing field is $null, and a
# run without a turn.completed event has usage $null.
function Get-UsageFromEvents {
    param([string]$Path)
    $text = Read-SharedText -Path $Path
    if (-not $text) { return $null }
    $usage = $null
    foreach ($line in ($text -split "`r?`n")) {
        if ($line.IndexOf('turn.completed') -lt 0) { continue }
        $trimmed = $line.Trim()
        if (-not $trimmed.StartsWith('{')) { continue }
        $obj = $null
        try { $obj = ConvertFrom-Json -InputObject $trimmed } catch { continue }
        if (-not $obj.PSObject.Properties['type'] -or $obj.type -ne 'turn.completed') { continue }
        $u = $null
        if ($obj.PSObject.Properties['usage']) { $u = $obj.usage }
        $values = [ordered]@{}
        foreach ($field in @('input_tokens', 'cached_input_tokens', 'output_tokens', 'reasoning_output_tokens')) {
            $values[$field] = $null
            if ($u -and $u.PSObject.Properties[$field] -and $null -ne $u.$field) { $values[$field] = [long]$u.$field }
        }
        $usage = [pscustomobject]$values
    }
    return $usage
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

function Format-Usage {
    param($Usage)
    if ($null -eq $Usage) { return 'unknown' }
    $v = @{}
    foreach ($field in @('input_tokens', 'cached_input_tokens', 'output_tokens', 'reasoning_output_tokens')) {
        $v[$field] = '?'
        if ($null -ne $Usage.$field) { $v[$field] = "$($Usage.$field)" }
    }
    return "in $($v.input_tokens) (cached $($v.cached_input_tokens)), out $($v.output_tokens), reasoning $($v.reasoning_output_tokens)"
}

# ----------------------------------------------------------------------------- presets + prompt text

$validPurposes = @('framing', 'decision', 'checkpoint', 'core-contract', 'acceptance', 'diff-review', 'stuck')
$presetEffort = @{
    ''              = 'high'
    'framing'       = 'high'
    'decision'      = 'high'
    'checkpoint'    = 'medium'
    'core-contract' = 'xhigh'
    'acceptance'    = 'high'
    'diff-review'   = 'high'
    'stuck'         = 'xhigh'
}
$presetWords = @{
    ''              = 700
    'framing'       = 700
    'decision'      = 700
    'checkpoint'    = 500
    'core-contract' = 900
    'acceptance'    = 900
    'diff-review'   = 700
    'stuck'         = 700
}
$purposeText = @{
    'framing'       = 'Surface the options the brief does not list and challenge the framing itself before answering inside it. Say what you would need to know to choose between the options.'
    'decision'      = 'Rank the alternatives. For each one, name the deciding factor and its failure mode.'
    'checkpoint'    = 'Verify the CURRENT invariants the brief claims against the code as it is now, and report any drift between what is claimed and what exists. Keep it short.'
    'core-contract' = 'This review runs BEFORE dependent work is built on the core. Cover the interfaces, recovery and persistence paths and the state machines NAMED IN THE BRIEF and their immediate dependency boundaries - not the whole system. For each state machine: states, transitions, the failure at each transition. Name what the evidence does not show. Expect this review to be re-run whenever recovery, persistence or interfaces change.'
    'acceptance'    = 'Decide whether the result can be accepted. The verdict, the blockers, the unproven scenarios and an OBSERVABLE first-run checklist (what must be seen in logs or output on the first real run before an exit code 0 is believed) are mandatory.'
    'diff-review'   = 'Read the change adversarially: what breaks, what it does not cover, what the tests do not prove.'
    'stuck'         = 'The coordinator is stuck. Look for the angle they are missing and question their assumptions before proposing fixes.'
}

# ----------------------------------------------------------------------------- validation

$validEfforts = @('low', 'medium', 'high', 'xhigh')
if ($Effort) {
    $Effort = $Effort.Trim().ToLowerInvariant()
    if ($validEfforts -notcontains $Effort) {
        Stop-WithError "-Effort must be one of: $($validEfforts -join ', ') (got '$Effort')."
    }
}
$Purpose = $Purpose.Trim().ToLowerInvariant()
if ($Purpose -and $validPurposes -notcontains $Purpose) {
    Stop-WithError "-Purpose must be one of: $($validPurposes -join ', ') (got '$Purpose')."
}
if ($PSBoundParameters.ContainsKey('MaxWords') -and $MaxWords -le 0) {
    Stop-WithError "-MaxWords must be greater than 0 (got $MaxWords)."
}
if ($TimeoutSec -le 0) {
    Stop-WithError "-TimeoutSec must be greater than 0 (got $TimeoutSec)."
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

# Explicit -Effort / -MaxWords win over the purpose preset.
$effortResolved = $presetEffort[$Purpose]
if ($Effort) { $effortResolved = $Effort }
$maxWordsResolved = $presetWords[$Purpose]
if ($MaxWords -gt 0) { $maxWordsResolved = $MaxWords }
$purposeLabel = if ($Purpose) { $Purpose } else { 'none' }
$verdictRule = if (@('acceptance', 'diff-review') -contains $Purpose) { 'ACCEPT, HOLD or REJECT' } else { 'ADVISE' }

$modelLabel = if ($Model) { $Model } else { 'config default' }

# ----------------------------------------------------------------------------- repo + task

$callerCwd = (Get-Location).Path
$repoRoot = Resolve-RepoRoot -Cwd $callerCwd
$collabRoot = Resolve-CollabRoot -RepoRoot $repoRoot -CollabDir $CollabDir

$taskDir = Join-Path $collabRoot $Task
$handoffsDir = Join-Path $taskDir 'handoffs'
$sessionsPath = Join-Path $taskDir 'sessions.json'
$findingsPath = Join-Path $taskDir 'findings.json'
$lockPath = Join-Path $taskDir '.consult.lock'
$pendingPath = Get-PendingPath -TaskDir $taskDir
$runStarted = Get-IsoTimestamp

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

# ----------------------------------------------------------------------------- brief, artifacts, schema

# Paths are resolved (and a missing one refused) here; the bytes are hashed under the
# task lock right before the run and again after it (binding drift, see below).
$briefRef = ''
$briefPath = ''
if ($Brief) {
    $briefPath = $Brief
    if (-not [IO.Path]::IsPathRooted($briefPath)) {
        foreach ($base in @($callerCwd, $repoRoot)) {
            $candidate = Join-Path $base $briefPath
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $briefPath = $candidate; break }
        }
    }
    if (-not (Test-Path -LiteralPath $briefPath -PathType Leaf)) {
        Stop-WithError "brief '$Brief' not found (this script never writes briefs; write it first)."
    }
    $briefPath = (Resolve-Path -LiteralPath $briefPath).Path
    $briefRel = Get-RepoRelativePath -Root $repoRoot -Path $briefPath
    if ($briefRel) {
        $briefRef = $briefRel
    } else {
        # Outside the repository: Codex still reads it (read-only sandbox reads are
        # not path-limited), but the prompt must carry the absolute path.
        $briefRef = $briefPath
    }
}

# -Artifact a,b arrives as ONE string through `powershell -File`; split on commas
# unless the whole string names an existing file.
$artifactList = New-Object System.Collections.Generic.List[string]
foreach ($a in @($Artifact)) {
    if (-not $a -or -not $a.Trim()) { continue }
    $a = $a.Trim()
    $whole = -not $a.Contains(',')
    if (-not $whole) {
        if ([IO.Path]::IsPathRooted($a)) { $whole = Test-Path -LiteralPath $a -PathType Leaf }
        else {
            foreach ($base in @($callerCwd, $repoRoot)) {
                if (Test-Path -LiteralPath (Join-Path $base $a) -PathType Leaf) { $whole = $true; break }
            }
        }
    }
    if ($whole) { $artifactList.Add($a) }
    else { foreach ($piece in $a.Split(',')) { if ($piece.Trim()) { $artifactList.Add($piece.Trim()) } } }
}
$artifactItems = @(Resolve-ArtifactPaths -Paths $artifactList.ToArray() -Bases @($callerCwd, $repoRoot))

$schemaPath = ''
if (-not $Raw) {
    $schemaPath = [IO.Path]::GetFullPath((Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'schemas') 'consult-reply.schema.json'))
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        Stop-WithError "output schema not found at '$schemaPath' (reinstall the plugin, or pass -Raw for a plain-text consultation)."
    }
}

if (-not $DryRun -and -not $codexExePath) {
    Stop-WithError "codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable)."
}

$tmpRoot = [System.IO.Path]::GetTempPath()
$tmpId = [guid]::NewGuid().ToString('N')
$lastMsgPath = Join-Path $tmpRoot "codex-consult-last-$tmpId.md"
$promptPath = Join-Path $tmpRoot "codex-consult-prompt-$tmpId.txt"
$stderrPath = Join-Path $tmpRoot "codex-consult-stderr-$tmpId.txt"

function Format-ShortHash {
    param([string]$Hash)
    if ($Hash.Length -ge 12) { return $Hash.Substring(0, 12) }
    return $Hash
}

# ----------------------------------------------------------------------------- lock + run
#
# Everything from here to the end runs while <task>/.consult.lock is HELD OPEN (not in
# -DryRun, which writes nothing at all): the lock is taken BEFORE the recovery record,
# sessions.json and findings.json are read and before the consult number n and the
# handoff number NN are allocated, and released in `finally` by closing the handle
# (an `exit` inside `try` still runs it; the lock file itself is permanent).
#
# Recovery record <task>/.consult.pending.json (atomic replace, only under the lock):
#   1. read it first: unusable -> refuse; a live codex process of an interrupted run
#      -> refuse; otherwise its reservation is consumed (numbering skips past it)
#   2. {state: reserved, n, nn, reply}  after allocation - replaces the old record
#   3. {state: launching}               right before Start-Process (a failed write
#                                       aborts the run before codex exists)
#   4. {state: running, child_pid}      right after Start-Process; if this write fails
#                                       the codex tree is killed, the run is recorded
#                                       as failed and the record stays 'launching'
#   5. {state: survivors, survivors[]}  after a timeout kill that left survivors; kept
#   6. deleted after the ledger commit when codex is known to be gone
# If this process dies at any point, the record tells the next run what to check.
#
# Write order after the run:
#   1. handoffs/NN-codex-<slug>.reply.json  byte-for-byte copy of Codex's last message,
#                                           BEFORE any parsing (a failed copy is a
#                                           bridge failure; the temp original is kept)
#   2. handoffs/NN-codex-<slug>.md          header + verbatim reply (+ rendered section)
#   3. findings.json                        new findings, reviewer checks
#   4. sessions.json                        the ledger entry - the commit point
# Both JSON stores are replaced atomically (temp file + replace), and an existing
# store that is empty or unparseable is refused as corruption. A crash between 3 and
# 4 leaves findings or reviewer checks whose consult has no ledger entry;
# `codex-findings.ps1 -List` flags them as ORPHAN, and numbering never reuses a
# number that any finding, reviewer check, handoff file or reservation names.

$lock = $null
$keepPending = $false
$keepLastMsg = $false
if (-not $DryRun) {
    [void][IO.Directory]::CreateDirectory($handoffsDir)
    $lock = Enter-TaskLock -TaskDir $taskDir -Task $Task
    if (-not $lock.Acquired) { Stop-WithError $lock.Message }
}

try {
    # ------------------------------------------------------------------------- recovery record

    # Read and judged BEFORE anything is written (a dry run only reports).
    $pendingOld = $null
    $pendingCheck = $null
    $pendingRefusal = ''
    $pendingRead = Read-PendingFile -Path $pendingPath
    if ($pendingRead.Error) { Stop-WithError $pendingRead.Error }
    if ($pendingRead.Exists) {
        $pendingOld = $pendingRead.Record
        $pendingCheck = Test-PendingActive -Record $pendingOld -Path $pendingPath
        if ($pendingCheck.Active) {
            if ($DryRun) { $pendingRefusal = $pendingCheck.Message } else { Stop-WithError $pendingCheck.Message }
        }
    }

    # ------------------------------------------------------------------------- ledgers

    $sessions = Read-JsonStore -Path $sessionsPath
    if ($null -eq $sessions) {
        $sessions = [pscustomobject]@{
            task_id = $Task
            cwd     = $repoRoot
            codex   = [pscustomobject]@{
                tool     = $codexVersion
                consults = [object[]]@()
            }
        }
        if (-not $DryRun) { Write-JsonFile -Path $sessionsPath -Object $sessions }
    }
    if (-not $sessions.PSObject.Properties['codex']) {
        $sessions | Add-Member -NotePropertyName 'codex' -NotePropertyValue ([pscustomobject]@{ tool = $codexVersion; consults = [object[]]@() })
    }
    if (-not $sessions.codex.PSObject.Properties['consults']) {
        $sessions.codex | Add-Member -NotePropertyName 'consults' -NotePropertyValue ([object[]]@())
    }
    $sessions.codex.tool = $codexVersion

    # findings.json is read in both modes - numbering must see every finding and
    # reviewer check - but only structured mode lists open findings and ingests.
    $findingsStore = Read-FindingsFile -Path $findingsPath -Task $Task
    $openFindings = @()
    if (-not $Raw) {
        $openFindings = @($findingsStore.findings | Where-Object { $script:OpenStatuses -contains [string](Get-PropertyValue $_ 'status' '') })
    }
    $listedIds = [string[]]@($openFindings | ForEach-Object { [string]$_.id })
    # { id; severity; status } of the listed prior findings, for verdict validation.
    $priorInfo = @($openFindings | ForEach-Object {
            [pscustomobject]@{ id = [string]$_.id; severity = [string](Get-PropertyValue $_ 'severity' ''); status = [string](Get-PropertyValue $_ 'status' '') }
        })

    # ------------------------------------------------------------------------- mode + thread

    # Older ledger entries (0.1: `outcome`, no `purpose`, ...) are left untouched; only
    # `thread` is read from them.
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

    # ------------------------------------------------------------------------- numbering

    # The old recovery record's reservation is consumed here: numbering skips past its
    # n / nn (and past everything else on disk that names a number).
    $numbers = Get-NextNumbers -Consults $consults -Store $findingsStore -HandoffsDir $handoffsDir -Leftover $pendingOld
    $consultN = $numbers.N
    $nn = $numbers.Nn
    $recoveredLine = ''
    if ($pendingOld) {
        $state = [string](Get-PropertyValue $pendingOld 'state' '')
        if ($DryRun) {
            if ($pendingRefusal) { $recoveredLine = "$pendingPath (state '$state', n=$($numbers.RecoveredN), nn=$($numbers.RecoveredNn)): the next run would be REFUSED - $pendingRefusal" }
            else { $recoveredLine = "$pendingPath (state '$state', n=$($numbers.RecoveredN), nn=$($numbers.RecoveredNn); $($pendingCheck.Check)): the next run recovers it; numbering continues past it." }
        } elseif ($numbers.Recovered) {
            $recoveredLine = "recovered reservation n=$($numbers.RecoveredN), nn=$($numbers.RecoveredNn) (state '$state' of an interrupted run; $($pendingCheck.Check)); numbering continues past it."
            Write-Host "codex-consult: $recoveredLine" -ForegroundColor Yellow
        } else {
            # Its consultation reached the ledger (e.g. a failed registration or timeout
            # survivors that have exited since): nothing to recover, only to clear.
            $recoveredLine = "cleared the recovery record of consult n=$($numbers.RecoveredN), nn=$($numbers.RecoveredNn) (state '$state'; $($pendingCheck.Check)); its ledger entry exists."
            Write-Host "codex-consult: $recoveredLine" -ForegroundColor Yellow
        }
    }
    # NB: PowerShell variable names are case-insensitive - never call these $replyName,
    # that would silently clobber the -ReplyName parameter.
    $replyFileName = "$nn-codex-$ReplyName.md"
    $eventsFileName = "$nn-codex-$ReplyName.events.jsonl"
    $replyJsonFileName = "$nn-codex-$ReplyName.reply.json"
    $replyPath = Join-Path $handoffsDir $replyFileName
    $eventsPath = Join-Path $handoffsDir $eventsFileName
    $replyJsonPath = Join-Path $handoffsDir $replyJsonFileName
    $replyRel = "handoffs/$replyFileName"
    $eventsRel = "handoffs/$eventsFileName"
    $replyJsonPlanned = ''
    if (-not $Raw) { $replyJsonPlanned = "handoffs/$replyJsonFileName" }
    # This run's reservation replaces the consumed record (atomically; if the write
    # fails the old record is left intact and nothing was started).
    $pendingRecord = $null
    if (-not $DryRun) {
        $pendingRecord = New-PendingRecord -State 'reserved' -N $consultN -Nn $nn -Reply $replyRel -Started $runStarted -Launcher ([string]$codexExePath)
        try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
            Stop-WithError "could not write the recovery record '$pendingPath': $(ConvertTo-OneLine $_.Exception.Message); nothing was started."
        }
    }

    # ------------------------------------------------------------------------- prompt

    $nl = "`r`n"
    $promptParts = New-Object System.Collections.ArrayList
    if ($Prompt) { [void]$promptParts.Add($Prompt.Trim()) }
    if ($briefRef) {
        [void]$promptParts.Add("Read the brief at ``$briefRef`` (path relative to the repository root, which is your working directory) and answer every numbered question in it.")
    }
    if ($Raw) {
        [void]$promptParts.Add("Constraints: write NO files and make no edits - this is a read-only consultation; answer in English; keep the answer under $maxWordsResolved words.")
    } else {
        if ($Purpose) {
            [void]$promptParts.Add("Review purpose: $Purpose. $($purposeText[$Purpose])")
        }
        if ($openFindings.Count -gt 0) {
            $lines = New-Object System.Collections.Generic.List[string]
            $lines.Add('Findings from earlier consultations in this task that are still open (id - status - locations - claim - trigger - verify):')
            foreach ($f in $openFindings) {
                $line = "- $($f.id) - $($f.status) - $(Format-Locations -Locations (Get-PropertyValue $f 'locations' @())) - $(ConvertTo-OneLine ([string](Get-PropertyValue $f 'claim' '')))"
                $trigger = ConvertTo-OneLine ([string](Get-PropertyValue $f 'trigger' ''))
                if ($trigger) { $line += " - trigger: $trigger" }
                $verify = ConvertTo-OneLine ([string](Get-PropertyValue $f 'verification' ''))
                if ($verify) { $line += " - verify: $verify" }
                $lines.Add($line)
            }
            $lines.Add('Report each listed id in `prior_findings` as fixed, still-open or not-checked (unknown-id if you cannot find it). Do not file a still-open one again as a new finding unless the claim changed; when a new finding replaces a listed one (a split, a merge, a corrected claim), name the old id in its `supersedes`.')
            [void]$promptParts.Add(($lines.ToArray() -join $nl))
        }
        $priorLine = '- prior_findings: an empty array (no earlier findings are open in this task).'
        if ($openFindings.Count -gt 0) {
            $priorLine = '- prior_findings: one entry {id, status, note} per id listed above; status fixed | still-open | not-checked | unknown-id.'
        }
        $schemaLines = @(
            'Reply format: your final message must be exactly one JSON object matching the output schema you were given (schema_version "1"). Field meaning:',
            '- reply_markdown: your full answer in Markdown, answering every numbered question by number. This is what people read; write it exactly as you would a normal reply. The word limit below applies to reply_markdown only - never shorten, merge or drop findings to fit it.',
            '- findings: one item per concrete defect or risk you assert; an empty array is a valid answer.',
            '  - severity: blocker (must be fixed before acceptance) | major | minor | note.',
            '  - locations: every place the finding concerns, each {path, line} with the path relative to the repository root and line null when no single line applies; an empty array when the finding is not tied to a place (e.g. a missing interface).',
            '  - claim: the assertion, self-contained. trigger: the input or state that exposes it.',
            '  - evidence: what you ALREADY did to support the claim, one entry per source: kind (read-code: you read the code there | ran-command: you ran something and saw the result | inferred: deduced from other evidence | assumed: not checked), reference (the file, command or log you looked at), observation (what you saw there). At least one entry; use kind "assumed" when you checked nothing.',
            '  - verification: one step the coordinator can run next to confirm the claim (prospective - not what you already did).',
            '  - remedy: the fix you propose.',
            '  - supersedes: ids of earlier findings this one replaces (a split, a merge, a corrected claim); otherwise an empty array.',
            "- verdict: ACCEPT, HOLD or REJECT for acceptance and diff-review consultations, ADVISE for every other consultation; this one takes $verdictRule. verdict_reason: one sentence.",
            $priorLine,
            '- unproven: scenarios the evidence does not cover (an empty array if none).',
            '- first_run_checklist: for an acceptance consultation, what must be observed in logs or output on the first real run before an exit code 0 is believed; an empty array for other purposes.',
            '- schema_version: always "1".'
        )
        [void]$promptParts.Add(($schemaLines -join $nl))
        [void]$promptParts.Add("Constraints: write NO files and make no edits - this is a read-only consultation; answer in English; keep reply_markdown under $maxWordsResolved words.")
    }
    $promptText = [string]::Join("$nl$nl", $promptParts.ToArray())

    # ------------------------------------------------------------------------- argv

    # Exec-level options MUST precede the fork|resume subcommand: `codex exec fork --help`
    # has no --sandbox/--color, and placing them after the subcommand fails with
    # "unexpected argument". --output-schema is exec-level too.
    $argv = @(
        'exec',
        '--sandbox', $Sandbox,
        '--color', 'never',
        '--json'
    )
    if ($Model) { $argv += @('-m', $Model) }
    $argv += @(
        '-c', ('model_reasoning_effort="' + $effortResolved + '"'),
        '-o', $lastMsgPath
    )
    if (-not $Raw) { $argv += @('--output-schema', $schemaPath) }
    if ($Mode -eq 'fork') { $argv += @('fork', $knownThread) }
    elseif ($Mode -eq 'resume') { $argv += @('resume', $knownThread) }
    # The prompt is piped on stdin ('-'): a prompt passed as a positional argument
    # would travel through the npm codex.cmd shim on Windows, where cmd.exe still
    # expands %VAR% inside double quotes and would corrupt briefs that mention
    # %APPDATA% & co.
    $argv += '-'

    $commandStr = 'codex ' + (Format-Argv $argv)

    # ------------------------------------------------------------------------- bindings

    # Hashed now, under the lock (and again after the run): the brief and the artifacts
    # live outside the tree fingerprint (collab dir / ignored or external files).
    $briefSha = ''
    if ($briefPath) { $briefSha = Get-FileSha256OrMissing -Path $briefPath }
    $artifactHashes = @(Get-ArtifactHashes -Artifacts $artifactItems)
    # Fingerprint of the tree under review, before the run (and again after it).
    $revBefore = Get-RevisionInfo -Root $repoRoot -CollabRoot $collabRoot

    # ------------------------------------------------------------------------- dry run

    if ($DryRun) {
        $previewFindings = [pscustomobject]@{ blocker = 0; major = 0; minor = 0; note = 0 }
        $previewIds = @()
        if (-not $Raw) { $previewIds = @("F$nn-1", '...') }
        $previewArtifacts = @($artifactHashes | ForEach-Object { [pscustomobject]@{ path = $_.path; sha256 = $_.sha256; sha256_after = '<computed after the run>' } })
        $preview = [pscustomobject]@{
            n                               = $consultN
            when                            = (Get-IsoTimestamp)
            purpose                         = $Purpose
            parent_thread                   = $parentThread
            thread                          = '<filled from the event stream>'
            thread_source                   = 'events|rollout|unknown'
            mode                            = $Mode
            command                         = $commandStr
            brief                           = $briefRef
            prompt_chars                    = $promptText.Length
            reply                           = $replyRel
            reply_json                      = $replyJsonPlanned
            events                          = $eventsRel
            model                           = $modelLabel
            effort                          = $effortResolved
            max_words                       = $maxWordsResolved
            sandbox                         = $Sandbox
            structured                      = $(if ($Raw) { $false } else { '<true when the reply validates>' })
            schema                          = $(if ($Raw) { '' } else { 'consult-reply v1' })
            validation_error                = $(if ($Raw) { '' } else { '<"" or the first validation error>' })
            base_commit                     = $revBefore.base_commit
            reviewed_revision               = $revBefore.reviewed_revision
            tree_sha256                     = $revBefore.tree_sha256
            tree_sha256_after               = '<computed after the run>'
            tree_changed_during_review      = '<true|false>'
            changed_files                   = $revBefore.changed_files
            brief_sha256                    = $briefSha
            brief_sha256_after              = $(if ($briefPath) { '<computed after the run>' } else { '' })
            brief_changed_during_review     = '<true|false>'
            fingerprint_note                = $revBefore.fingerprint_note
            artifacts                       = [object[]]$previewArtifacts
            artifacts_changed_during_review = '<true|false>'
            bridge_outcome                  = '<usable reply | failed: ...>'
            verdict                         = $(if ($Raw) { '' } else { "<$($verdictRule -replace ', | or ', '|'), or '' when unavailable>" })
            verdict_reason                  = $(if ($Raw) { '' } else { '<one sentence>' })
            findings                        = $previewFindings
            finding_ids                     = [object[]]$previewIds
            prior_findings                  = [object[]]@($listedIds | ForEach-Object { [pscustomobject]@{ id = $_; status = '<fixed|still-open|not-checked|unknown-id>' } })
            unchecked_prior_blockers        = [object[]]@()
            usage                           = [pscustomobject]@{ input_tokens = '<n>'; cached_input_tokens = '<n>'; output_tokens = '<n>'; reasoning_output_tokens = '<n>' }
            wall_seconds                    = 0
        }
        Write-Host "DRY RUN - nothing was executed and no file was written." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "repo root   : $repoRoot"
        Write-Host "task dir    : $taskDir"
        Write-Host "sessions    : $sessionsPath"
        if (-not $Raw) { Write-Host "findings    : $findingsPath ($($openFindings.Count) open finding(s) listed in the prompt)" }
        Write-Host "lock        : $lockPath (held open for the run; not in a dry run)"
        if ($recoveredLine) { Write-Host "pending     : $recoveredLine" -ForegroundColor Yellow }
        if ($codexExePath) { Write-Host "launcher    : $codexExePath" }
        else { Write-Host "launcher    : (codex not found on PATH)" -ForegroundColor Yellow }
        Write-Host "codex       : $codexVersion"
        Write-Host "model       : $modelLabel"
        Write-Host "purpose     : $purposeLabel (effort $effortResolved, max words $maxWordsResolved)"
        if ($Raw) { Write-Host "reply format: raw text (-Raw: no schema, no findings bookkeeping)" }
        else { Write-Host "schema      : $schemaPath" }
        Write-Host "mode        : $Mode"
        if ($Mode -eq 'new') { Write-Host "thread      : (a new thread will be created)" }
        else { Write-Host "thread      : $knownThread (parent for $Mode)" }
        Write-Host "handoff     : $nn (consult n = $consultN)"
        Write-Host "reviewed    : $($revBefore.reviewed_revision), base $($revBefore.base_commit), $($revBefore.changed_files) changed files"
        $treeShown = $revBefore.tree_sha256
        if (-not $treeShown) { $treeShown = '(none)' }
        Write-Host "tree sha256 : $treeShown ($($revBefore.fingerprint_note))"
        if ($briefSha) { Write-Host "brief sha256: $briefSha" }
        foreach ($art in $artifactHashes) { Write-Host "artifact    : $($art.path) sha256 $($art.sha256)" }
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
        if (-not $Raw) { Write-Host "reply json  : $replyJsonPath" }
        Write-Host "events file : $eventsPath"
        Write-Host "last message: $lastMsgPath (temp)"
        Write-Host ""
        Write-Host "sessions.json entry preview:"
        Write-Host (ConvertTo-Json -InputObject $preview -Depth 10)
        exit 0
    }

    # ------------------------------------------------------------------------- run

    Write-Utf8NoBom -Path $promptPath -Text $promptText

    # (3) launching - from the next statement on, a crash may leave a codex process
    # whose pid is not recorded; the next run then scans for one (Test-PendingActive).
    $pendingRecord.state = 'launching'
    $pendingRecord.note = 'codex is being started; its pid is not recorded yet'
    try { Write-PendingFile -Path $pendingPath -Record $pendingRecord } catch {
        Stop-WithError "could not write the recovery record '$pendingPath': $(ConvertTo-OneLine $_.Exception.Message); codex was not started."
    }

    $startedAt = Get-Date
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = -1
    $bridgeOutcome = ''
    $argStr = (($argv | ForEach-Object { ConvertTo-ProcArg $_ }) -join ' ')

    $proc = $null
    try {
        $proc = Start-Process -FilePath $codexExePath -ArgumentList $argStr `
            -WorkingDirectory $repoRoot -NoNewWindow -PassThru `
            -RedirectStandardOutput $eventsPath `
            -RedirectStandardError $stderrPath `
            -RedirectStandardInput $promptPath
    } catch {
        $bridgeOutcome = "failed: could not start codex - $($_.Exception.Message)"
    }
    if ($proc) {
        # PS 5.1: touching .Handle before the process exits caches it, otherwise
        # .ExitCode comes back empty on a -PassThru process.
        if ($script:LegacyPS) { try { $null = $proc.Handle } catch { } }
        # (4) running - register the child before waiting on it.
        $registerError = ''
        try {
            $pendingRecord.state = 'running'
            $pendingRecord.child_pid = $proc.Id
            $pendingRecord.child_start_time = [string](Get-ProcessStartIso -ProcessId $proc.Id)
            $pendingRecord.note = ''
            Write-PendingFile -Path $pendingPath -Record $pendingRecord
        } catch {
            $registerError = ConvertTo-OneLine $_.Exception.Message
        }
        if ($registerError) {
            # An unregistered codex must not outlive this run: stop it now. The record
            # on disk stays 'launching', so the next run checks for a codex process.
            $survivors = Stop-ProcessTree -Process $proc   # [int[]]; never wrap in @(): that nests the array
            $bridgeOutcome = "failed: could not register the codex process ($registerError); codex was stopped"
            if ($survivors.Count -gt 0) { $bridgeOutcome += "; $($survivors.Count) processes survived: pid $($survivors -join ', ')" }
            $keepPending = $true
        } else {
            $finished = $proc.WaitForExit($TimeoutSec * 1000)
            if (-not $finished) {
                # The launcher is usually a shim (codex.cmd -> node -> codex.exe): kill
                # the whole tree, or the real codex keeps running after we give up.
                $survivors = Stop-ProcessTree -Process $proc   # [int[]]; never wrap in @(): that nests the array
                $bridgeOutcome = "failed: timeout after $TimeoutSec s (process tree killed)"
                if ($survivors.Count -gt 0) {
                    $bridgeOutcome = "failed: timeout after $TimeoutSec s (process tree killed; $($survivors.Count) processes survived: pid $($survivors -join ', '); the next run for this task is refused until they exit)"
                    # (5) survivors - kept after this run.
                    $keepPending = $true
                    try {
                        $pendingRecord.state = 'survivors'
                        # { pid, start_time, name } per survivor, so a reused pid is not
                        # mistaken for the survivor later (New-SurvivorEntries streams
                        # objects; @() is correct here - it does not return ", $array").
                        $pendingRecord.survivors = [object[]]@(New-SurvivorEntries -Pids $survivors)
                        Write-PendingFile -Path $pendingPath -Record $pendingRecord
                    } catch {
                        $bridgeOutcome += "; WARNING: the survivors could not be recorded ($(ConvertTo-OneLine $_.Exception.Message)) - $pendingPath still names only child pid $($proc.Id)"
                    }
                }
            } else {
                $exitCode = $proc.ExitCode
            }
        }
    }
    $stopwatch.Stop()
    $wallSeconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 1)

    $revAfter = Get-RevisionInfo -Root $repoRoot -CollabRoot $collabRoot
    $treeChanged = ($revBefore.tree_sha256 -ne $revAfter.tree_sha256)
    $briefShaAfter = ''
    if ($briefPath) { $briefShaAfter = Get-FileSha256OrMissing -Path $briefPath }
    $briefChanged = ($briefSha -ne $briefShaAfter)
    # Rehash the exact resolved path each hash was taken from (no lookup by name).
    $artifactsFinal = @($artifactHashes | ForEach-Object {
            [pscustomobject]@{ path = $_.path; sha256 = $_.sha256; sha256_after = (Get-FileSha256OrMissing -Path $_.full) }
        })
    $changedArtifacts = @($artifactsFinal | Where-Object { $_.sha256 -ne $_.sha256_after } | ForEach-Object { $_.path })
    $artifactsChanged = ($changedArtifacts.Count -gt 0)

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
    $usage = $null
    try { $usage = Get-UsageFromEvents -Path $eventsPath } catch { $usage = $null }

    if (-not $bridgeOutcome) {
        if ($exitCode -ne 0) {
            $detail = $eventError
            if (-not $detail -and $stderrText) {
                $detail = ($stderrText.Trim() -split "`r?`n" | Select-Object -Last 1)
            }
            $tail = ''
            if ($detail) { $tail = ' - ' + $detail }
            $bridgeOutcome = "failed: codex exit $exitCode$tail"
        } elseif (-not $rawReply) {
            $detail = ''
            if ($eventError) { $detail = ' - ' + $eventError }
            $bridgeOutcome = "failed: empty reply$detail"
        } else {
            $bridgeOutcome = 'usable reply'
        }
    }

    # ------------------------------------------------------------------------- 1. reply.json

    # The first write after the run, before anything parses the reply: Codex's last
    # message copied BYTE FOR BYTE (never re-serialized, never trimmed). If it cannot
    # be preserved, the run is a bridge failure and the temp original is kept.
    $replyJsonRel = ''
    if (-not $Raw -and (Test-Path -LiteralPath $lastMsgPath -PathType Leaf)) {
        $copyError = ''
        for ($attempt = 1; $attempt -le 6; $attempt++) {
            try {
                [IO.File]::Copy($lastMsgPath, $replyJsonPath, $true)
                $copyError = ''
                break
            } catch {
                $copyError = ConvertTo-OneLine $_.Exception.Message
                Start-Sleep -Milliseconds 250
            }
        }
        if ($copyError) {
            $keepLastMsg = $true
            $note = "could not preserve the raw reply ($copyError); original kept at $lastMsgPath"
            if ($bridgeOutcome -eq 'usable reply') { $bridgeOutcome = "failed: $note" }
            else { $bridgeOutcome += "; $note" }
        } else {
            $replyJsonRel = $replyJsonPlanned
        }
    }

    # ------------------------------------------------------------------------- structured reply

    # A reply that is not valid JSON or breaks the schema is NOT a bridge failure: the
    # raw text is kept as the reply, but there is no verdict and no finding is recorded.
    # A structurally valid reply whose verdict does not fit the purpose or contradicts
    # a blocker keeps its findings but records no verdict.
    $structured = $false
    $parse = $null
    $ingest = $null
    $validationError = ''
    $verdict = ''
    $verdictReason = ''
    $replyBody = $rawReply
    $counts = [pscustomobject]@{ blocker = 0; major = 0; minor = 0; note = 0 }
    $findingIds = @()
    $priorForLedger = @()
    $uncheckedPrior = @()
    if (-not $Raw -and $bridgeOutcome -eq 'usable reply') {
        try {
            $parse = ConvertFrom-StructuredReply -Text $rawReply -Purpose $Purpose -PriorFindings $priorInfo
            $validationError = $parse.ValidationError
            if ($parse.Valid) {
                $ingest = Add-ReplyFindings -Store $findingsStore -Reply $parse.Reply -Nn $nn -ConsultN $consultN `
                    -ReplyRel $replyRel -ThreadId $threadId -BaseCommit $revBefore.base_commit `
                    -TreeSha256 $revBefore.tree_sha256 -ListedIds $listedIds
                $structured = $true
                $replyBody = $parse.Reply.reply_markdown
                $verdict = $parse.Verdict
                if (-not $parse.VerdictInvalid) { $verdictReason = $parse.Reply.verdict_reason }
                $counts = $ingest.Counts
                $findingIds = @($ingest.NewIds)
                $priorForLedger = @($ingest.PriorEntries | ForEach-Object { [pscustomobject]@{ id = $_.id; status = $_.status } })
                $uncheckedPrior = @($parse.UncheckedPriorBlockers)
            }
        } catch {
            # Never lose the reply over a bridge bug: record it as unprocessable.
            $structured = $false
            $ingest = $null
            $verdict = ''
            $verdictReason = ''
            $replyBody = $rawReply
            $validationError = "bridge could not process the reply: $(ConvertTo-OneLine $_.Exception.Message)"
            $parse = [pscustomobject]@{ Valid = $false; ValidationError = $validationError; Reply = $null; UncheckedPriorBlockers = @() }
        }
    }

    # ------------------------------------------------------------------------- 2. reply file

    $parentLine = 'Parent thread: (none - new thread).'
    if ($parentThread) { $parentLine = "Parent thread: ``$parentThread``." }
    $resultThread = '(unknown)'
    if ($threadId) { $resultThread = "``$threadId``" }
    $briefLine = 'Brief: (none, prompt only).'
    if ($briefRef) { $briefLine = "Brief: ``$briefRef`` (sha256 $(Format-ShortHash $briefSha))." }
    $treeText = 'tree sha256 none (no git)'
    if ($revBefore.tree_sha256) { $treeText = "tree sha256 $(Format-ShortHash $revBefore.tree_sha256)" }
    $reviewedLine = "Reviewed: $($revBefore.reviewed_revision), base $($revBefore.base_commit), $treeText, $($revBefore.changed_files) changed files"
    if ($artifactHashes.Count -gt 0) {
        $reviewedLine += ', artifacts: ' + (($artifactHashes | ForEach-Object { "$($_.path)=$(Format-ShortHash $_.sha256)" }) -join ', ')
    }
    $reviewedLine += '.'
    $driftLines = New-Object System.Collections.Generic.List[string]
    if ($treeChanged) { $driftLines.Add('WARNING: working tree changed during the review (fingerprint before/after differ).') }
    if ($briefChanged) { $driftLines.Add("WARNING: the brief changed during the review (sha256 $(Format-ShortHash $briefSha) before, $(Format-ShortHash $briefShaAfter) after).") }
    if ($artifactsChanged) { $driftLines.Add("WARNING: artifact(s) changed during the review: $($changedArtifacts -join ', ').") }
    $verdictWarning = ''
    if ($structured) { $verdictWarning = Format-VerdictWarning -Parse $parse }

    $headerLines = New-Object System.Collections.Generic.List[string]
    $headerLines.Add("# Handoff $nn - Codex: $ReplyName")
    $headerLines.Add('')
    $headerLines.Add("Date: $($startedAt.ToString('yyyy-MM-dd HH:mm', $script:Invariant)) local. Author: Codex (model $modelLabel, effort $effortResolved), Codex CLI $codexVersionShort.")
    $headerLines.Add("Invocation: ``codex-consult.ps1`` (mode: $Mode, sandbox: $Sandbox, purpose: $purposeLabel). Argv: ``$commandStr`` (prompt on stdin).")
    $headerLines.Add("$parentLine Result thread: $resultThread (source: $threadSource).")
    $headerLines.Add("$briefLine $reviewedLine")
    foreach ($d in $driftLines) { $headerLines.Add($d) }
    $headerLines.Add("Bridge outcome: $bridgeOutcome. Wall time: $wallSeconds s. Tokens: $(Format-Usage $usage).")
    if ($parse) { $headerLines.Add((Format-StructuredStatusLine -Parse $parse -Ingest $ingest -ReplyJsonRel $replyJsonRel)) }
    if ($verdictWarning) { $headerLines.Add($verdictWarning) }
    $headerLines.Add("Raw event stream: ``$eventsRel``.")
    $headerLines.Add('Verbatim reply follows.')
    $headerLines.Add('')
    $headerLines.Add('---')
    $headerLines.Add('')
    $header = $headerLines.ToArray() -join "`n"

    $body = $replyBody
    if (-not $rawReply) {
        $body = "_(no reply captured)_"
        if ($eventError) {
            $body += "`n`nCodex reported: $eventError"
        }
        if ($stderrText.Trim()) {
            $body += "`n`n```````n" + $stderrText.Trim() + "`n``````"
        }
    } elseif (-not $body) {
        $body = '_(empty reply_markdown)_'
    }
    $section = ''
    if ($structured) { $section = Format-StructuredSection -Parse $parse -Ingest $ingest }
    $replyText = $header + "`n" + ($body -replace "`r`n", "`n") + "`n"
    if ($section) { $replyText += "`n---`n`n" + ($section -replace "`r`n", "`n") + "`n" }
    Write-Utf8NoBom -Path $replyPath -Text $replyText

    # ------------------------------------------------------------------------- 3. findings.json

    if ($ingest -and $ingest.Changed) {
        Write-FindingsFile -Path $findingsPath -Store $findingsStore
    }

    # ------------------------------------------------------------------------- 4. sessions.json

    $entry = [pscustomobject]@{
        n                               = $consultN
        when                            = (Get-IsoTimestamp $startedAt)
        purpose                         = $Purpose
        parent_thread                   = $parentThread
        thread                          = $threadId
        thread_source                   = $threadSource
        mode                            = $Mode
        command                         = $commandStr
        brief                           = $briefRef
        prompt_chars                    = $promptText.Length
        reply                           = $replyRel
        reply_json                      = $replyJsonRel
        events                          = $eventsRel
        model                           = $modelLabel
        effort                          = $effortResolved
        max_words                       = $maxWordsResolved
        sandbox                         = $Sandbox
        structured                      = $structured
        schema                          = $(if ($Raw) { '' } else { 'consult-reply v1' })
        validation_error                = $validationError
        base_commit                     = $revBefore.base_commit
        reviewed_revision               = $revBefore.reviewed_revision
        tree_sha256                     = $revBefore.tree_sha256
        tree_sha256_after               = $revAfter.tree_sha256
        tree_changed_during_review      = $treeChanged
        changed_files                   = $revBefore.changed_files
        brief_sha256                    = $briefSha
        brief_sha256_after              = $briefShaAfter
        brief_changed_during_review     = $briefChanged
        fingerprint_note                = $revBefore.fingerprint_note
        artifacts                       = [object[]]$artifactsFinal
        artifacts_changed_during_review = $artifactsChanged
        bridge_outcome                  = $bridgeOutcome
        verdict                         = $verdict
        verdict_reason                  = $verdictReason
        findings                        = [pscustomobject]@{ blocker = $counts.blocker; major = $counts.major; minor = $counts.minor; note = $counts.note }
        finding_ids                     = [object[]]$findingIds
        prior_findings                  = [object[]]$priorForLedger
        unchecked_prior_blockers        = [object[]]$uncheckedPrior
        usage                           = $usage
        wall_seconds                    = $wallSeconds
    }
    $newConsults = @()
    $newConsults += $consults
    $newConsults += $entry
    $sessions.codex.consults = [object[]]$newConsults
    Write-JsonFile -Path $sessionsPath -Object $sessions

    # (6) The ledger is committed and codex is known to be gone: the recovery record
    # has nothing left to protect (still under the lock). Kept after a failed
    # registration ('launching') or with timeout survivors.
    $pendingNote = ''
    if ($keepPending) {
        $pendingNote = "recovery record kept: $pendingPath (state '$($pendingRecord.state)')"
    } else {
        $rmError = Remove-PendingFile -Path $pendingPath
        if ($rmError) { $pendingNote = "could not remove $pendingPath ($rmError); the next run will find codex gone and consume it" }
    }

    # ------------------------------------------------------------------------- output

    if ($bridgeOutcome -ne 'usable reply') {
        Write-Host "codex-consult: $bridgeOutcome (wall $wallSeconds s)" -ForegroundColor Red
        if ($pendingNote) { Write-Host "pending    : $pendingNote" -ForegroundColor Yellow }
        foreach ($d in $driftLines) { Write-Host $d -ForegroundColor Yellow }
        Write-Host "reply file : $replyPath"
        if ($replyJsonRel) { Write-Host "reply json : $replyJsonPath" }
        Write-Host "events file: $eventsPath"
        if ($stderrText.Trim()) {
            Write-Host "--- codex stderr (tail) ---"
            Write-Host (($stderrText.Trim() -split "`r?`n" | Select-Object -Last 20) -join "`n")
        }
        exit 1
    }

    Write-Host "codex-consult: $bridgeOutcome - mode $Mode, thread $threadId (source: $threadSource), wall $wallSeconds s"
    if ($parse) {
        if ($structured) {
            if ($parse.VerdictInvalid) { Write-Host "verdict    : (invalid: $validationError)" -ForegroundColor Yellow }
            else { Write-Host "verdict    : $verdict - $(ConvertTo-OneLine $verdictReason)" }
            if ($verdictWarning) { Write-Host $verdictWarning -ForegroundColor Yellow }
            if ($findingIds.Count -gt 0) { Write-Host "findings   : $(Format-SeverityCounts $counts) -> $(Format-IdRange $findingIds) in findings.json" }
            else { Write-Host "findings   : none" }
            if (@($ingest.PriorEntries).Count -gt 0) {
                Write-Host ("prior      : " + ((@($ingest.PriorEntries) | ForEach-Object { "$($_.id) $($_.status)" }) -join ', '))
            }
            if (@($ingest.UnknownIds).Count -gt 0) {
                Write-Host "unknown ids: $(@($ingest.UnknownIds) -join ', ') (not in findings.json; ignored)" -ForegroundColor Yellow
            }
            if (@($ingest.UnknownSupersedes).Count -gt 0) {
                Write-Host "supersedes : $(@($ingest.UnknownSupersedes) -join ', ') not in findings.json (kept on the new finding only)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "structured : INVALID ($validationError) - raw text kept; no findings recorded" -ForegroundColor Yellow
        }
    }
    if ($pendingNote) { Write-Host "pending    : $pendingNote" -ForegroundColor Yellow }
    foreach ($d in $driftLines) { Write-Host $d -ForegroundColor Yellow }
    Write-Host "reply file : $replyPath"
    if ($replyJsonRel) { Write-Host "reply json : $replyJsonPath" }
    Write-Host "events file: $eventsPath"
    Write-Host ""
    Write-Host $replyBody
    if ($section) {
        Write-Host ""
        Write-Host $section
    }
    exit 0
} finally {
    foreach ($tmp in @($promptPath, $stderrPath)) {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
    if (-not $keepLastMsg -and (Test-Path -LiteralPath $lastMsgPath)) {
        Remove-Item -LiteralPath $lastMsgPath -Force -ErrorAction SilentlyContinue
    }
    Exit-TaskLock -Lock $lock
}
