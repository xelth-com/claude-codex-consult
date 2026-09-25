<#
.SYNOPSIS
    Usefulness telemetry: which reviewer was useful on which kind of question.

.DESCRIPTION
    Reads the ledgers (<CollabDir>/<task>/sessions.json) and findings stores
    (<CollabDir>/<task>/findings.json) of EVERY task of this repository, or of one task
    with -Task, and prints one row per (reviewer lineage, purpose), a total row per
    lineage and a grand total. Nothing is written, no lock is taken; a store that cannot
    be read is reported and left out. Exit 0.

    Row key
      REVIEWER   '<provider> :: <model>' of the consultation (its ledger reviewer), with
                 ' [<engine>]' appended for an engine other than codex (0.4.0, e.g.
                 'gemini :: gemini-3.8-flash-high [agy]'; an absent reviewer.engine is
                 codex); 'unknown provenance' for entries recorded before 0.3.0 (no reviewer)
      PURPOSE    the consultation's purpose, '(none)' without one; '(total)' on a
                 lineage's total row; the grand total row is '(all) (total)'
    Columns (JSON field in brackets)
      CONSULTS   ledger entries [consults]
      USABLE     bridge_outcome 'usable reply' [usable]
      PROSE      usable, but no valid structured reply (-Raw, chore, invalid JSON) [prose]
      FAILED     every other outcome [failed]
      RAISED     findings raised by these consultations (a finding belongs to the
                 consultation it was ingested from: source.consult = the entry's n, in
                 the same task - the join codex-findings.ps1 -Stats uses) [raised]
      VERIFIED / REJECTED / WONTFIX / SUPERSEDED   their current status [verified,
                 rejected, wontfix, superseded]
      OPEN       proposed + implemented [open]
      HIT%       verified / (verified + rejected), rounded percent; '-' when both are 0
                 [hit_rate: a number, or null]
      A/H/R/D    verdicts ACCEPT / HOLD / REJECT / ADVISE [verdict_accept, verdict_hold,
                 verdict_reject, verdict_advise]
      Y/P/N      the judge's usefulness marks (codex-findings.ps1 -Rate): yes / partly /
                 no [rated_yes, rated_partly, rated_no]
      MEDIAN_S   median wall_seconds; '-' when none [median_wall_seconds: number or null]
      TOKENS     input tokens not served from the cache / output tokens [tokens_in,
                 tokens_out]
    Findings whose consultation has no ledger entry count as 'unknown provenance' /
    '(none)'. Rows are sorted by lineage (case-insensitive; unknown provenance last),
    then purpose. -Json prints an array of the same rows with numeric fields (plus
    `kind`: purpose | lineage | total).

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-scoreboard.ps1

.EXAMPLE
    pwsh -NoProfile -File codex-scoreboard.ps1 -Task cache-rewrite -Json
#>
[CmdletBinding()]
param(
    # Where consultations are stored. Relative paths resolve against the git repo root.
    [string]$CollabDir = '.collab',

    # One task only (its directory under <CollabDir>).
    [string]$Task = '',

    # An array of row objects instead of the table.
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$script:ToolName = 'codex-scoreboard'
. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

if ($Task -and $Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Stop-WithError "-Task must be a slug (letters, digits, dot, dash, underscore)."
}
$repoRoot = Resolve-RepoRoot -Cwd (Get-Location).Path
$collabRoot = Resolve-CollabRoot -RepoRoot $repoRoot -CollabDir $CollabDir

$taskDirs = @()
if ($Task) {
    $one = Join-Path $collabRoot $Task
    if (-not (Test-Path -LiteralPath $one -PathType Container)) { Stop-WithError "no task '$Task' under $collabRoot." }
    $taskDirs = @(Get-Item -LiteralPath $one)
} elseif (Test-Path -LiteralPath $collabRoot -PathType Container) {
    $taskDirs = @(Get-ChildItem -LiteralPath $collabRoot -Directory | Sort-Object Name)
}

# Tolerant reads: a store that does not parse is reported and left out.
$notes = New-Object System.Collections.Generic.List[string]
function Read-TolerantStore {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return (ConvertFrom-JsonKeepOffset -Text (Read-SharedText -Path $Path)) } catch {
        $notes.Add("left out: $Path does not parse ($(ConvertTo-OneLine $_.Exception.Message))")
        return $null
    }
}

function Get-IntValue {
    param($Object, [string]$Name)
    $v = Get-PropertyValue $Object $Name $null
    $n = [long]0
    if ($null -ne $v -and [long]::TryParse([string]$v, [ref]$n)) { return $n }
    return $null
}

# One accumulator per row key.
$rows = @{}
function Get-Acc {
    param([string]$Lineage, [string]$Purpose)
    $key = "$Lineage`t$Purpose"
    if (-not $rows.ContainsKey($key)) {
        $rows[$key] = [pscustomobject]@{
            Lineage = $Lineage; Purpose = $Purpose; Consults = 0; Usable = 0; Prose = 0; Failed = 0
            Raised = 0; Verified = 0; Rejected = 0; Wontfix = 0; Superseded = 0; Open = 0
            Accept = 0; Hold = 0; Reject = 0; Advise = 0; Yes = 0; Partly = 0; No = 0
            Walls = (New-Object System.Collections.Generic.List[double]); TokensIn = [long]0; TokensOut = [long]0
        }
    }
    return $rows[$key]
}

foreach ($dir in $taskDirs) {
    $sessions = Read-TolerantStore -Path (Join-Path $dir.FullName 'sessions.json')
    $store = Read-TolerantStore -Path (Join-Path $dir.FullName 'findings.json')
    $keyOf = @{}
    foreach ($c in @(Get-PropertyValue (Get-PropertyValue $sessions 'codex' $null) 'consults' @())) {
        if ($null -eq $c) { continue }
        $rev = Get-PropertyValue $c 'reviewer' $null
        $lineage = 'unknown provenance'
        if ($null -ne $rev) { $lineage = Format-ReviewerLineage -Provider ([string](Get-PropertyValue $rev 'provider' '')) -Model ([string](Get-PropertyValue $rev 'model' '')) -Engine ([string](Get-PropertyValue $rev 'engine' '')) }
        $purpose = [string](Get-PropertyValue $c 'purpose' '')
        if (-not $purpose) { $purpose = '(none)' }
        $acc = Get-Acc $lineage $purpose
        $n = Get-IntValue $c 'n'
        if ($null -ne $n) { $keyOf[$n] = $acc }
        $acc.Consults++
        $outcome = [string](Get-PropertyValue $c 'bridge_outcome' (Get-PropertyValue $c 'outcome' ''))
        if ($outcome -eq 'usable reply') {
            $acc.Usable++
            if ((Get-PropertyValue $c 'structured' $false) -ne $true) { $acc.Prose++ }
        } else {
            $acc.Failed++
        }
        switch ([string](Get-PropertyValue $c 'verdict' '')) {
            'ACCEPT' { $acc.Accept++ }
            'HOLD' { $acc.Hold++ }
            'REJECT' { $acc.Reject++ }
            'ADVISE' { $acc.Advise++ }
        }
        $wall = Get-PropertyValue $c 'wall_seconds' $null
        $w = [double]0
        if ($null -ne $wall -and [double]::TryParse([string]$wall, [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$w)) { $acc.Walls.Add($w) }
        $usage = Get-PropertyValue $c 'usage' $null
        if ($null -ne $usage) {
            $in = Get-IntValue $usage 'input_tokens'
            $cached = Get-IntValue $usage 'cached_input_tokens'
            $out = Get-IntValue $usage 'output_tokens'
            if ($null -ne $in) { $acc.TokensIn += [Math]::Max([long]0, $in - $(if ($null -ne $cached) { $cached } else { 0 })) }
            if ($null -ne $out) { $acc.TokensOut += $out }
        }
    }
    foreach ($f in @(Get-PropertyValue $store 'findings' @())) {
        if ($null -eq $f) { continue }
        $n = Get-IntValue (Get-PropertyValue $f 'source' $null) 'consult'
        $acc = $null
        if ($null -ne $n -and $keyOf.ContainsKey($n)) { $acc = $keyOf[$n] } else { $acc = Get-Acc 'unknown provenance' '(none)' }
        $acc.Raised++
        switch ([string](Get-PropertyValue $f 'status' '')) {
            'verified' { $acc.Verified++ }
            'rejected' { $acc.Rejected++ }
            'wontfix' { $acc.Wontfix++ }
            'superseded' { $acc.Superseded++ }
            'proposed' { $acc.Open++ }
            'implemented' { $acc.Open++ }
        }
    }
    foreach ($rt in @(Get-PropertyValue $store 'ratings' @())) {
        if ($null -eq $rt) { continue }
        $n = Get-IntValue $rt 'n'
        $acc = $null
        if ($null -ne $n -and $keyOf.ContainsKey($n)) { $acc = $keyOf[$n] }
        else {
            $p = [string](Get-PropertyValue $rt 'purpose' '')
            $acc = Get-Acc ([string](Get-PropertyValue $rt 'lineage' 'unknown provenance')) $(if ($p) { $p } else { '(none)' })
        }
        switch ([string](Get-PropertyValue $rt 'useful' '')) {
            'yes' { $acc.Yes++ }
            'partly' { $acc.Partly++ }
            'no' { $acc.No++ }
        }
    }
}

function Get-Median {
    param([double[]]$Values)
    if ($Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $mid = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) { return [double]$sorted[$mid] }
    return ([double]$sorted[$mid - 1] + [double]$sorted[$mid]) / 2
}

$counters = @('Consults', 'Usable', 'Prose', 'Failed', 'Raised', 'Verified', 'Rejected', 'Wontfix', 'Superseded', 'Open', 'Accept', 'Hold', 'Reject', 'Advise', 'Yes', 'Partly', 'No', 'TokensIn', 'TokensOut')
function New-OutRow {
    param([string]$Kind, [string]$Lineage, [string]$Purpose, [object[]]$Parts)
    $sum = @{}
    foreach ($k in $counters) { $sum[$k] = [long]0 }
    $walls = New-Object System.Collections.Generic.List[double]
    foreach ($a in $Parts) {
        foreach ($k in $counters) { $sum[$k] += [long]$a.$k }
        foreach ($w in $a.Walls) { $walls.Add($w) }
    }
    $hit = $null
    if (($sum.Verified + $sum.Rejected) -gt 0) { $hit = [int][Math]::Round(100.0 * $sum.Verified / ($sum.Verified + $sum.Rejected), [MidpointRounding]::AwayFromZero) }
    $median = Get-Median -Values ([double[]]$walls.ToArray())
    return [pscustomobject]@{
        kind                = $Kind
        lineage             = $Lineage
        purpose             = $Purpose
        consults            = $sum.Consults
        usable              = $sum.Usable
        prose               = $sum.Prose
        failed              = $sum.Failed
        raised              = $sum.Raised
        verified            = $sum.Verified
        rejected            = $sum.Rejected
        wontfix             = $sum.Wontfix
        superseded          = $sum.Superseded
        open                = $sum.Open
        hit_rate            = $hit
        verdict_accept      = $sum.Accept
        verdict_hold        = $sum.Hold
        verdict_reject      = $sum.Reject
        verdict_advise      = $sum.Advise
        rated_yes           = $sum.Yes
        rated_partly        = $sum.Partly
        rated_no            = $sum.No
        median_wall_seconds = $median
        tokens_in           = $sum.TokensIn
        tokens_out          = $sum.TokensOut
    }
}

$all = @($rows.Values)
$lineages = @($all | ForEach-Object { $_.Lineage } | Select-Object -Unique | Sort-Object @{ Expression = { $_ -eq 'unknown provenance' } }, @{ Expression = { $_.ToLowerInvariant() } })
$out = New-Object System.Collections.Generic.List[object]
foreach ($lin in $lineages) {
    $mine = @($all | Where-Object { $_.Lineage -eq $lin } | Sort-Object @{ Expression = { $_.Purpose.ToLowerInvariant() } })
    foreach ($a in $mine) { $out.Add((New-OutRow -Kind 'purpose' -Lineage $lin -Purpose $a.Purpose -Parts @($a))) }
    $out.Add((New-OutRow -Kind 'lineage' -Lineage $lin -Purpose '(total)' -Parts $mine))
}
if ($all.Count -gt 0) { $out.Add((New-OutRow -Kind 'total' -Lineage '(all)' -Purpose '(total)' -Parts $all)) }

if ($Json) {
    Write-Output (ConvertTo-Json -InputObject ([object[]]$out.ToArray()) -Depth 4)
    exit 0
}

Write-Host "codex-scoreboard: $collabRoot$(if ($Task) { " (task $Task)" } else { " ($($taskDirs.Count) task(s))" })"
foreach ($note in $notes) { Write-Host $note -ForegroundColor Yellow }
if ($out.Count -eq 0) {
    Write-Host 'no consultations recorded.'
    exit 0
}
$header = [ordered]@{ reviewer = 'REVIEWER'; purpose = 'PURPOSE'; consults = 'CONSULTS'; usable = 'USABLE'; prose = 'PROSE'; failed = 'FAILED'; raised = 'RAISED'; verified = 'VERIFIED'; rejected = 'REJECTED'; wontfix = 'WONTFIX'; superseded = 'SUPERSEDED'; open = 'OPEN'; hit = 'HIT%'; verdicts = 'A/H/R/D'; ratings = 'Y/P/N'; median = 'MEDIAN_S'; tokens = 'TOKENS' }
$lines = New-Object System.Collections.Generic.List[object]
$lines.Add([pscustomobject]$header)
foreach ($r in $out) {
    $lines.Add([pscustomobject][ordered]@{
            reviewer   = $r.lineage
            purpose    = $r.purpose
            consults   = [string]$r.consults
            usable     = [string]$r.usable
            prose      = [string]$r.prose
            failed     = [string]$r.failed
            raised     = [string]$r.raised
            verified   = [string]$r.verified
            rejected   = [string]$r.rejected
            wontfix    = [string]$r.wontfix
            superseded = [string]$r.superseded
            open       = [string]$r.open
            hit        = $(if ($null -eq $r.hit_rate) { '-' } else { "$($r.hit_rate)%" })
            verdicts   = "$($r.verdict_accept)/$($r.verdict_hold)/$($r.verdict_reject)/$($r.verdict_advise)"
            ratings    = "$($r.rated_yes)/$($r.rated_partly)/$($r.rated_no)"
            median     = $(if ($null -eq $r.median_wall_seconds) { '-' } else { ([double]$r.median_wall_seconds).ToString('0.#', $script:Invariant) })
            tokens     = "$($r.tokens_in)/$($r.tokens_out)"
        })
}
$cols = @($header.Keys)
$numeric = @('consults', 'usable', 'prose', 'failed', 'raised', 'verified', 'rejected', 'wontfix', 'superseded', 'open', 'hit', 'median')
$width = @{}
foreach ($col in $cols) { $width[$col] = (@($lines | ForEach-Object { ([string]$_.$col).Length }) | Measure-Object -Maximum).Maximum }
foreach ($l in $lines) {
    $parts = foreach ($col in $cols) { if ($numeric -contains $col) { ([string]$l.$col).PadLeft($width[$col]) } else { ([string]$l.$col).PadRight($width[$col]) } }
    Write-Host (($parts -join '  ').TrimEnd())
}
exit 0
