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
    current status of its findings; then a per-reviewer scoreboard - one line per
    lineage '<provider> :: <model>' (with ' [<engine>]' for an engine other than codex,
    0.4.0) (the reviewer of the ledger entry each finding was
    ingested from; entries recorded before 0.3.0 and findings without a ledger entry
    count as 'unknown provenance'): raised, verified, implemented, proposed, rejected,
    wontfix, superseded, and the judge's usefulness marks yes / partly / no.

    -Rate <n> -Useful yes|partly|no [-Note <why>] records the judge's mark for
    consultation n of the task (n must be a ledger entry; -Note is required for no):
    findings.json gets a top-level `ratings` array of { n, consult_id, lineage,
    provider, model, purpose, useful, note, when } (lineage, provider, model and
    purpose copied from that ledger entry; rating n again replaces its record). It
    takes the task lock like a status change. codex-scoreboard.ps1 sums the marks per
    reviewer and purpose across tasks.

    A status change takes the task lock (<task>/.consult.lock), so it is refused
    while a consultation (or a -Panel run) for the task runs, and also while an
    interrupted consultation's bridge or codex process may still be running (every
    recovery record <task>/.consult.pending.json and .consult.pending-<NN>.json,
    read but never changed here). Its write - like -Rate's - goes through the
    task's store commit (0.4.x wave 21): <task>/.consult.write.lock, findings.json
    RE-READ under it, the change applied to that fresh store, written, released.
    -List and -Stats only read; they show every interrupted consultation's record.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-findings.ps1 -Task cache-rewrite -List

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-findings.ps1 -Task cache-rewrite `
        -Id F04-1 -Status verified -Evidence "cargo test cache::invalidation -> 14 passed (log: target/t.log)"

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-findings.ps1 -Task cache-rewrite `
        -Rate 4 -Useful partly -Note "found the race, missed the retry path"
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
    [string]$Evidence = '',

    # Consultation n (a ledger entry of the task) to mark with -Useful.
    [int]$Rate = 0,

    # yes | partly | no - the judge's mark for the consultation -Rate names (-Note is
    # required for no).
    [string]$Useful = ''
)

$ErrorActionPreference = 'Stop'
$script:ToolName = 'codex-findings'

. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

# ----------------------------------------------------------------------------- validation

$actions = 0
if ($List) { $actions++ }
if ($Stats) { $actions++ }
if ($Id -or $Status) { $actions++ }
$rating = $PSBoundParameters.ContainsKey('Rate') -or [bool]$Useful
if ($rating) { $actions++ }
if ($actions -ne 1) {
    Stop-WithError "choose exactly one of: -List [-All], -Stats, -Id <F..> -Status <status>, or -Rate <n> -Useful yes|partly|no."
}
if ($All -and -not $List) { Stop-WithError "-All only goes with -List." }
if ($Evidence -and -not $Id) { Stop-WithError "-Evidence only goes with -Id/-Status." }
if ($Note -and -not $Id -and -not $rating) { Stop-WithError "-Note only goes with -Id/-Status or -Rate." }
if ($rating) {
    if (-not $PSBoundParameters.ContainsKey('Rate')) { Stop-WithError "-Useful needs -Rate <consult n>." }
    if ($Rate -le 0) { Stop-WithError "-Rate takes a consult number n greater than 0 (got $Rate)." }
    $Useful = $Useful.Trim().ToLowerInvariant()
    if (-not $Useful) { Stop-WithError "-Rate needs -Useful yes|partly|no." }
    if (@('yes', 'partly', 'no') -notcontains $Useful) { Stop-WithError "-Useful must be yes, partly or no (got '$Useful')." }
    if ($Useful -eq 'no' -and -not $Note.Trim()) { Stop-WithError "-Useful no needs -Note (why the consultation was not useful)." }
}
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

# One line per interrupted consultation (every recovery record of the task: the single
# run's .consult.pending.json and a panel's .consult.pending-<NN>.json), for -List / -Stats
# (no lock taken).
function Write-PendingLine {
    foreach ($path in (Get-PendingPaths -TaskDir $taskDir)) {
        $p = Read-PendingFile -Path $path
        if (-not $p.Exists) { continue }
        if ($p.Error) { Write-Host "pending: $($p.Error)" -ForegroundColor Yellow; continue }
        $r = $p.Record
        $line = ("pending: state={0}, n={1}, nn={2}, reply={3}, started {4} - an interrupted consultation; the next consultation consumes it ({5})" -f `
                (Get-PropertyValue $r 'state' '?'), (Get-PropertyValue $r 'n' '?'), (Get-PropertyValue $r 'nn' '?'), (Get-PropertyValue $r 'reply' '?'), (Get-PropertyValue $r 'started' '?'), $path)
        # stopped during a format-repair turn: the prose it had saved (and the like)
        $originalNote = Get-PendingOriginalNote $r
        if ($originalNote) { $line += "; $originalNote" }
        Write-Host $line -ForegroundColor Yellow
    }
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
    $findingsStoreForBoard = $null
    if (Test-Path -LiteralPath $findingsPath) {
        $findingsStoreForBoard = Read-FindingsFile -Path $findingsPath -Task $Task
        $findings = @($findingsStoreForBoard.findings)
    }
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
    # Per-reviewer scoreboard: every finding counted for the lineage '<provider> :: <model>'
    # of the ledger entry it was ingested from (its source.consult = the entry's n). An
    # entry without a reviewer object (recorded before 0.3.0), or a finding whose consult
    # has no ledger entry, is 'unknown provenance'. Lineages in ledger order, one line each
    # (also a reviewer that raised nothing), unknown provenance last.
    $lineageOf = @{}
    $lineageOrder = New-Object System.Collections.Generic.List[string]
    foreach ($c in $ledger) {
        $v = 0
        if (-not ($c.PSObject.Properties['n'] -and [int]::TryParse([string]$c.n, [ref]$v))) { continue }
        $rev = Get-PropertyValue $c 'reviewer' $null
        $label = 'unknown provenance'
        if ($null -ne $rev) { $label = Format-ReviewerLineage -Provider ([string](Get-PropertyValue $rev 'provider' '')) -Model ([string](Get-PropertyValue $rev 'model' '')) -Engine ([string](Get-PropertyValue $rev 'engine' '')) }
        $lineageOf[$v] = $label
        if ($label -ne 'unknown provenance' -and -not $lineageOrder.Contains($label)) { $lineageOrder.Add($label) }
    }
    $board = @{}
    foreach ($f in $findings) {
        $fn = Get-FindingConsult $f
        $label = 'unknown provenance'
        if ($null -ne $fn -and $lineageOf.ContainsKey($fn)) { $label = $lineageOf[$fn] }
        if (-not $board.ContainsKey($label)) { $board[$label] = New-Object System.Collections.Generic.List[object] }
        $board[$label].Add($f)
    }
    if ($board.ContainsKey('unknown provenance')) { $lineageOrder.Add('unknown provenance') }
    if ($lineageOrder.Count -gt 0) {
        $wName = [Math]::Max(8, (@($lineageOrder | ForEach-Object { $_.Length }) | Measure-Object -Maximum).Maximum)
        $boardFmt = '{0,-' + $wName + '}  {1,6}  {2,8}  {3,11}  {4,8}  {5,8}  {6,7}  {7,10}  {8,3}  {9,6}  {10,2}'
        # The judge's marks (-Rate), counted for the lineage recorded with each mark.
        $marks = @{}
        foreach ($mk in @(Get-PropertyValue $findingsStoreForBoard 'ratings' @())) {
            if ($null -eq $mk) { continue }
            $ml = [string](Get-PropertyValue $mk 'lineage' 'unknown provenance')
            if (-not $marks.ContainsKey($ml)) { $marks[$ml] = @{ yes = 0; partly = 0; no = 0 } }
            $mu = [string](Get-PropertyValue $mk 'useful' '')
            if ($marks[$ml].ContainsKey($mu)) { $marks[$ml][$mu]++ }
        }
        Write-Host ""
        Write-Host "reviewers (findings by the lineage of the consultation that raised them; ratings = the judge's marks, -Rate):"
        Write-Host ($boardFmt -f 'reviewer', 'raised', 'verified', 'implemented', 'proposed', 'rejected', 'wontfix', 'superseded', 'yes', 'partly', 'no')
        foreach ($label in $lineageOrder) {
            $mineB = @()
            if ($board.ContainsKey($label)) { $mineB = @($board[$label].ToArray()) }
            $cntB = @{}
            foreach ($s in $script:FindingStatuses) { $cntB[$s] = @($mineB | Where-Object { [string](Get-PropertyValue $_ 'status' '') -eq $s }).Count }
            $mkB = if ($marks.ContainsKey($label)) { $marks[$label] } else { @{ yes = 0; partly = 0; no = 0 } }
            Write-Host ($boardFmt -f $label, $mineB.Count, $cntB['verified'], $cntB['implemented'], $cntB['proposed'], $cntB['rejected'], $cntB['wontfix'], $cntB['superseded'], $mkB['yes'], $mkB['partly'], $mkB['no'])
        }
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

# ----------------------------------------------------------------------------- -Rate

if ($rating) {
    if (-not (Test-Path -LiteralPath $sessionsPath -PathType Leaf)) {
        Stop-WithError "no consultations recorded for task '$Task' ($sessionsPath does not exist); -Rate takes the n of a ledger entry."
    }
    $lock = Enter-TaskLock -TaskDir $taskDir -Task $Task
    if (-not $lock.Acquired) { Stop-WithError $lock.Message }
    $commit = $null
    try {
        # The store commit (write lock, both stores re-read under it): the mark goes into the
        # FRESH findings.json.
        $commit = Enter-StoreCommit -TaskDir $taskDir -Task $Task -TimeoutSec (Get-WriteLockTimeout)
        if (-not $commit.Acquired) { Stop-WithError "$($commit.Message); nothing was changed." }
        $entry = $null
        $ledgerData = $commit.Sessions
        $ledgerConsults = @()
        if ($null -ne $ledgerData -and $ledgerData.PSObject.Properties['codex'] -and $ledgerData.codex.PSObject.Properties['consults']) { $ledgerConsults = @($ledgerData.codex.consults | Where-Object { $_ }) }
        foreach ($c in $ledgerConsults) {
            $v = 0
            if ($c.PSObject.Properties['n'] -and [int]::TryParse([string]$c.n, [ref]$v) -and $v -eq $Rate) { $entry = $c }
        }
        if (-not $entry) {
            Stop-WithError "no consultation n=$Rate in $sessionsPath; -Rate takes the n of a ledger entry (see -Stats)."
        }
        $rev = Get-PropertyValue $entry 'reviewer' $null
        $provider = ''
        $model = [string](Get-PropertyValue $entry 'model' '')
        $lineage = 'unknown provenance'
        if ($null -ne $rev) {
            $provider = [string](Get-PropertyValue $rev 'provider' '')
            $model = [string](Get-PropertyValue $rev 'model' '')
            $lineage = Format-ReviewerLineage -Provider $provider -Model $model -Engine ([string](Get-PropertyValue $rev 'engine' ''))
        }
        $mark = [pscustomobject]@{
            n          = $Rate
            consult_id = [string](Get-PropertyValue $entry 'consult_id' '')
            lineage    = $lineage
            provider   = $provider
            model      = $model
            purpose    = [string](Get-PropertyValue $entry 'purpose' '')
            useful     = $Useful
            note       = $Note.Trim()
            when       = (Get-IsoTimestamp)
        }
        # (created on the first mark; a findings.json that exists but does not parse is refused)
        $store = $commit.Findings
        $kept = New-Object System.Collections.Generic.List[object]
        $previous = ''
        $replaced = $false
        foreach ($old in @(Get-PropertyValue $store 'ratings' @())) {
            if ($null -eq $old) { continue }
            if ([string](Get-PropertyValue $old 'n' '') -eq [string]$Rate) {
                if (-not $replaced) { $kept.Add($mark); $replaced = $true; $previous = [string](Get-PropertyValue $old 'useful' '') }
                continue
            }
            $kept.Add($old)
        }
        if (-not $replaced) { $kept.Add($mark) }
        if ($store.PSObject.Properties['ratings']) { $store.ratings = [object[]]$kept.ToArray() }
        else { $store | Add-Member -NotePropertyName 'ratings' -NotePropertyValue ([object[]]$kept.ToArray()) }
        Complete-StoreCommit -Commit $commit -Findings
        Exit-StoreCommit -Commit $commit
        $purposeText = if ($mark.purpose) { $mark.purpose } else { 'no purpose' }
        if ($replaced) { Write-Host "codex-findings: consult n=$Rate ($lineage, $purposeText) re-rated $Useful (was $previous)." }
        else { Write-Host "codex-findings: consult n=$Rate ($lineage, $purposeText) rated $Useful." }
        exit 0
    } finally {
        Exit-StoreCommit -Commit $commit
        Exit-TaskLock -Lock $lock
    }
}

# ----------------------------------------------------------------------------- -Id -Status

if (-not (Test-Path -LiteralPath $findingsPath)) {
    Stop-WithError "no findings recorded for task '$Task' ($findingsPath does not exist)."
}

$lock = Enter-TaskLock -TaskDir $taskDir -Task $Task
if (-not $lock.Acquired) { Stop-WithError $lock.Message }
$commit = $null
try {
    # The recovery records of interrupted consultations are read only to refuse while
    # their bridge or codex process may still be running; they are never modified or
    # deleted here (the next consultation consumes them).
    $pendingAll = Read-TaskPendingRecords -TaskDir $taskDir
    if ($pendingAll.Error) { Stop-WithError $pendingAll.Error }
    if ($pendingAll.Active) { Stop-WithError $pendingAll.Active.Check.Message }

    # The store commit (write lock, findings.json re-read under it): the change goes into
    # the FRESH store.
    $commit = Enter-StoreCommit -TaskDir $taskDir -Task $Task -TimeoutSec (Get-WriteLockTimeout) -NoSessions
    if (-not $commit.Acquired) { Stop-WithError "$($commit.Message); nothing was changed." }
    $store = $commit.Findings
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
    Complete-StoreCommit -Commit $commit -Findings
    Exit-StoreCommit -Commit $commit

    Write-Host "codex-findings: $($target.id) $current -> $Status (history: $(@($target.history).Count) records; tree sha256 $(if ($rev.tree_sha256) { $rev.tree_sha256.Substring(0, 12) } else { 'none (no git)' }))."
    Write-Host (Format-FindingLine -Finding $target)
    exit 0
} finally {
    Exit-StoreCommit -Commit $commit
    Exit-TaskLock -Lock $lock
}
