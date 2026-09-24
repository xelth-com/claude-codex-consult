<#
.SYNOPSIS
    List the findings Codex raised in a task's consultations and move their status.

.DESCRIPTION
    codex-consult.ps1 (structured mode) appends every finding of a reply to
    <CollabDir>/<task>/findings.json as F<NN>-<k> with status 'proposed', and records
    the reviewer's later "fixed / still-open" reports as reviewer_checks. Only the
    coordinator moves a status - with this script. Every change appends a history
    record { when, status, by, note, evidence, base_commit, tree_sha256 } that
    carries the working-tree fingerprint of that moment.

    Statuses: proposed | implemented | verified | rejected | wontfix | superseded.
    Any status can follow any other; the history is the audit trail.
      * verified requires -Evidence (what was run, or where the proof is)
      * rejected requires -Note (why)
      * back to proposed (a reopen) requires -Note

    -List prints the open findings (proposed | implemented), -All every finding; a
    finding whose consultation has no ledger entry in sessions.json (a crash between
    the findings write and the ledger write) is flagged ORPHAN. -Stats prints one line
    per consultation: purpose, effort, wall time, output tokens, verdict and the
    current status of its findings.

    A status change takes the task lock (<task>/.consult.lock) around its
    read-modify-write, so it is refused while a consultation for the task runs,
    and also while an interrupted consultation's codex process may still be
    running (<task>/.consult.pending.json, read but never changed here).
    -List and -Stats only read; they show an interrupted consultation's record.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-findings.ps1 -Task cache-rewrite -List

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-findings.ps1 -Task cache-rewrite `
        -Id F04-1 -Status verified -Evidence "cargo test cache::invalidation -> 14 passed (log: target/t.log)"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    # Where consultations are stored. Relative paths resolve against the git repo root.
    [string]$CollabDir = '.collab',

    # Print open findings (proposed | implemented); with -All, every finding.
    [switch]$List,
    [switch]$All,

    # One line per consultation from sessions.json, with its findings by status.
    [switch]$Stats,

    # Finding id (F<NN>-<k>) whose status to set with -Status.
    [string]$Id = '',

    # proposed | implemented | verified | rejected | wontfix | superseded
    [string]$Status = '',

    # Why (required for rejected and for a reopen to proposed).
    [string]$Note = '',

    # What was run / where the proof is (required for verified).
    [string]$Evidence = ''
)

$ErrorActionPreference = 'Stop'
$script:ToolName = 'codex-findings'

. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

# ----------------------------------------------------------------------------- validation

$actions = 0
if ($List) { $actions++ }
if ($Stats) { $actions++ }
if ($Id -or $Status) { $actions++ }
if ($actions -ne 1) {
    Stop-WithError "choose exactly one of: -List [-All], -Stats, or -Id <F..> -Status <status>."
}
if ($All -and -not $List) { Stop-WithError "-All only goes with -List." }
if (($Note -or $Evidence) -and -not $Id) { Stop-WithError "-Note and -Evidence only go with -Id/-Status." }
if ($Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Stop-WithError "-Task must be a slug (letters, digits, dot, dash, underscore)."
}
if ($Id -or $Status) {
    if (-not $Id) { Stop-WithError "-Status needs -Id <finding id>." }
    if (-not $Status) { Stop-WithError "-Id needs -Status <$($script:FindingStatuses -join '|')>." }
    $Status = $Status.Trim().ToLowerInvariant()
    if ($script:FindingStatuses -notcontains $Status) {
        Stop-WithError "-Status must be one of: $($script:FindingStatuses -join ', ') (got '$Status')."
    }
    if ($Status -eq 'verified' -and -not $Evidence.Trim()) {
        Stop-WithError "-Status verified requires -Evidence (what was run, or where the proof is)."
    }
    if ($Status -eq 'rejected' -and -not $Note.Trim()) {
        Stop-WithError "-Status rejected requires -Note (why the finding is rejected)."
    }
}

# ----------------------------------------------------------------------------- paths

$callerCwd = (Get-Location).Path
$repoRoot = Resolve-RepoRoot -Cwd $callerCwd
$collabRoot = Resolve-CollabRoot -RepoRoot $repoRoot -CollabDir $CollabDir
$taskDir = Join-Path $collabRoot $Task
$findingsPath = Join-Path $taskDir 'findings.json'
$sessionsPath = Join-Path $taskDir 'sessions.json'
$pendingPath = Get-PendingPath -TaskDir $taskDir

# One line about an interrupted consultation, for -List / -Stats (no lock taken).
function Write-PendingLine {
    $p = Read-PendingFile -Path $pendingPath
    if (-not $p.Exists) { return }
    if ($p.Error) { Write-Host "pending: $($p.Error)" -ForegroundColor Yellow; return }
    $r = $p.Record
    Write-Host ("pending: state={0}, n={1}, nn={2}, reply={3}, started {4} - an interrupted consultation; the next consultation consumes it ({5})" -f `
            (Get-PropertyValue $r 'state' '?'), (Get-PropertyValue $r 'n' '?'), (Get-PropertyValue $r 'nn' '?'), (Get-PropertyValue $r 'reply' '?'), (Get-PropertyValue $r 'started' '?'), $pendingPath) -ForegroundColor Yellow
}

function Read-Ledger {
    $data = Read-JsonStore -Path $sessionsPath
    if ($null -eq $data -or -not $data.PSObject.Properties['codex'] -or -not $data.codex.PSObject.Properties['consults']) { return @() }
    return @($data.codex.consults | Where-Object { $_ })
}

# Consult numbers named by a finding's reviewer checks that have no ledger entry
# (a consultation that recorded checks and stopped before its ledger write).
function Get-OrphanCheckConsults {
    param($Finding, [hashtable]$LedgerNs)
    $out = New-Object System.Collections.Generic.List[int]
    foreach ($rc in @(Get-PropertyValue $Finding 'reviewer_checks' @())) {
        $v = 0
        if ($rc -and [int]::TryParse([string](Get-PropertyValue $rc 'consult' ''), [ref]$v) -and -not $LedgerNs.ContainsKey($v) -and -not $out.Contains($v)) { $out.Add($v) }
    }
    return , ([int[]]$out.ToArray())
}

function Get-FindingConsult {
    param($Finding)
    $src = Get-PropertyValue $Finding 'source' $null
    if (-not $src) { return $null }
    $v = 0
    if ([int]::TryParse([string](Get-PropertyValue $src 'consult' ''), [ref]$v)) { return $v }
    return $null
}

function ConvertTo-ComparablePath {
    param([string]$Path)
    return ($Path -replace '\\', '/').ToLowerInvariant()
}

# ----------------------------------------------------------------------------- -List

if ($List) {
    if (-not (Test-Path -LiteralPath $findingsPath)) {
        Write-Host "codex-findings: no findings recorded for task '$Task' ($findingsPath does not exist)."
        Write-PendingLine
        exit 0
    }
    $store = Read-FindingsFile -Path $findingsPath -Task $Task
    $ledger = @(Read-Ledger)
    # consult n -> reply path of its ledger entry
    $ledgerReplies = @{}
    foreach ($c in $ledger) {
        $v = 0
        if ($c.PSObject.Properties['n'] -and [int]::TryParse([string]$c.n, [ref]$v)) {
            $ledgerReplies[$v] = [string](Get-PropertyValue $c 'reply' '')
        }
    }
    $findings = @($store.findings)
    $ledgerNs = @{}
    foreach ($k in $ledgerReplies.Keys) { $ledgerNs[$k] = $true }
    $shown = 0
    $orphans = 0
    $orphanChecks = 0
    $byStatus = [ordered]@{}
    foreach ($s in $script:FindingStatuses) { $byStatus[$s] = 0 }
    $other = 0
    foreach ($f in $findings) {
        $st = [string](Get-PropertyValue $f 'status' '')
        if ($byStatus.Contains($st)) { $byStatus[$st] = $byStatus[$st] + 1 } else { $other++ }
        $n = Get-FindingConsult $f
        $srcReply = [string](Get-PropertyValue (Get-PropertyValue $f 'source' $null) 'reply' '')
        $orphan = $true
        if ($null -ne $n -and $ledgerReplies.ContainsKey($n)) {
            $ledgerReply = $ledgerReplies[$n]
            $orphan = ($srcReply -and $ledgerReply -and (ConvertTo-ComparablePath $srcReply) -ne (ConvertTo-ComparablePath $ledgerReply))
        }
        if ($orphan) { $orphans++ }
        $badChecks = Get-OrphanCheckConsults -Finding $f -LedgerNs $ledgerNs
        $orphanChecks += $badChecks.Count
        if (-not $All -and $script:OpenStatuses -notcontains $st -and $badChecks.Count -eq 0) { continue }
        $line = Format-FindingLine -Finding $f -Orphan:$orphan
        if ($badChecks.Count -gt 0) { $line += "  [ORPHAN reviewer check: consult $($badChecks -join ', ') has no ledger entry]" }
        Write-Host $line
        $shown++
    }
    $parts = @(foreach ($k in $byStatus.Keys) { "$k $($byStatus[$k])" })
    if ($other -gt 0) { $parts += "other $other" }
    $scope = if ($All) { 'all' } else { 'open only, plus any with an orphan check; -All for every finding' }
    Write-Host ""
    Write-Host "codex-findings: $shown shown ($scope); total $($findings.Count): $($parts -join ', '); orphans: $orphans finding(s), $orphanChecks reviewer check(s)."
    Write-PendingLine
    exit 0
}

# ----------------------------------------------------------------------------- -Stats

if ($Stats) {
    $ledger = @(Read-Ledger)
    $findings = @()
    if (Test-Path -LiteralPath $findingsPath) { $findings = @((Read-FindingsFile -Path $findingsPath -Task $Task).findings) }
    if ($ledger.Count -eq 0) {
        Write-Host "codex-findings: no consultations recorded for task '$Task' ($sessionsPath)."
        Write-PendingLine
        exit 0
    }
    $fmt = '{0,4}  {1,-13}  {2,-6}  {3,7}  {4,11}  {5,-7}  {6}'
    Write-Host ($fmt -f 'n', 'purpose', 'effort', 'wall_s', 'tokens(out)', 'verdict', 'findings: proposed/implemented/verified/rejected')
    $seen = @{}
    foreach ($c in $ledger) {
        $n = $null
        $v = 0
        if ($c.PSObject.Properties['n'] -and [int]::TryParse([string]$c.n, [ref]$v)) { $n = $v }
        $mine = @($findings | Where-Object { $null -ne $n -and (Get-FindingConsult $_) -eq $n })
        if ($null -ne $n) { $seen[$n] = $true }
        $cnt = @{}
        foreach ($s in @('proposed', 'implemented', 'verified', 'rejected')) {
            $cnt[$s] = @($mine | Where-Object { [string](Get-PropertyValue $_ 'status' '') -eq $s }).Count
        }
        $purpose = [string](Get-PropertyValue $c 'purpose' '')
        if (-not $purpose) { $purpose = '-' }
        $effort = [string](Get-PropertyValue $c 'effort' '-')
        $wall = [string](Get-PropertyValue $c 'wall_seconds' '-')
        $tokens = '-'
        $u = Get-PropertyValue $c 'usage' $null
        if ($u -and $null -ne (Get-PropertyValue $u 'output_tokens' $null)) { $tokens = [string]$u.output_tokens }
        $verdict = [string](Get-PropertyValue $c 'verdict' '')
        if (-not $verdict) {
            $verdict = '-'
            $outcome = [string](Get-PropertyValue $c 'bridge_outcome' (Get-PropertyValue $c 'outcome' ''))
            if ($outcome -like 'failed*') { $verdict = 'failed' }
            elseif ([string](Get-PropertyValue $c 'validation_error' '')) { $verdict = 'invalid' }
        }
        $label = '-'
        if ($null -ne $n) { $label = [string]$n }
        $findingsText = "$($cnt.proposed)/$($cnt.implemented)/$($cnt.verified)/$($cnt.rejected)"
        if ($mine.Count -gt 0) { $findingsText += " ($($mine.Count) total)" }
        Write-Host ($fmt -f $label, $purpose, $effort, $wall, $tokens, $verdict, $findingsText)
    }
    $orphanCount = @($findings | Where-Object { $n = Get-FindingConsult $_; $null -eq $n -or -not $seen.ContainsKey($n) }).Count
    $orphanCheckCount = 0
    foreach ($f in $findings) { $orphanCheckCount += (Get-OrphanCheckConsults -Finding $f -LedgerNs $seen).Count }
    if ($orphanCount -gt 0 -or $orphanCheckCount -gt 0) {
        Write-Host ""
        Write-Host "codex-findings: $orphanCount finding(s) and $orphanCheckCount reviewer check(s) belong to no ledger entry (ORPHAN; see -List -All)." -ForegroundColor Yellow
    }
    Write-PendingLine
    exit 0
}

# ----------------------------------------------------------------------------- -Id -Status

if (-not (Test-Path -LiteralPath $findingsPath)) {
    Stop-WithError "no findings recorded for task '$Task' ($findingsPath does not exist)."
}

$lock = Enter-TaskLock -TaskDir $taskDir -Task $Task
if (-not $lock.Acquired) { Stop-WithError $lock.Message }
try {
    # The recovery record of an interrupted consultation is read only to refuse while
    # its codex process may still be running; it is never modified or deleted here
    # (the next consultation consumes it).
    $pendingRead = Read-PendingFile -Path $pendingPath
    if ($pendingRead.Error) { Stop-WithError $pendingRead.Error }
    if ($pendingRead.Exists) {
        $pendingCheck = Test-PendingActive -Record $pendingRead.Record -Path $pendingPath
        if ($pendingCheck.Active) { Stop-WithError $pendingCheck.Message }
    }

    $store = Read-FindingsFile -Path $findingsPath -Task $Task
    $target = $null
    foreach ($f in @($store.findings)) {
        if ([string](Get-PropertyValue $f 'id' '') -eq $Id.Trim()) { $target = $f; break }
    }
    if (-not $target) {
        Stop-WithError "unknown finding id '$Id' in $findingsPath (codex-findings.ps1 -Task $Task -List -All shows every id)."
    }
    $current = [string](Get-PropertyValue $target 'status' '')
    if ($Status -eq 'proposed' -and $current -ne 'proposed' -and -not $Note.Trim()) {
        Stop-WithError "reopening $($target.id) ($current -> proposed) requires -Note (why it is open again)."
    }

    $rev = Get-RevisionInfo -Root $repoRoot -CollabRoot $collabRoot
    $record = [pscustomobject]@{
        when        = (Get-IsoTimestamp)
        status      = $Status
        by          = 'coordinator'
        note        = $Note.Trim()
        evidence    = $Evidence.Trim()
        base_commit = $rev.base_commit
        tree_sha256 = $rev.tree_sha256
    }
    Add-ArrayItem -Object $target -Name 'history' -Item $record
    if ($target.PSObject.Properties['status']) { $target.status = $Status }
    else { $target | Add-Member -NotePropertyName 'status' -NotePropertyValue $Status }
    Write-FindingsFile -Path $findingsPath -Store $store

    Write-Host "codex-findings: $($target.id) $current -> $Status (history: $(@($target.history).Count) records; tree sha256 $(if ($rev.tree_sha256) { $rev.tree_sha256.Substring(0, 12) } else { 'none (no git)' }))."
    Write-Host (Format-FindingLine -Finding $target)
    exit 0
} finally {
    Exit-TaskLock -Lock $lock
}
