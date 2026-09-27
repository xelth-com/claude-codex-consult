<#
.SYNOPSIS
    Usefulness telemetry: which reviewer was useful on which kind of question.

.DESCRIPTION
    Reads the ledgers (<CollabDir>/<task>/sessions.json) and findings stores
    (<CollabDir>/<task>/findings.json) of EVERY task of this repository, or of one task
    with -Task, and prints one row per (reviewer lineage, purpose) - or (wave 26) per
    (reviewer lineage, topic) with -By topic -, a total row per lineage and a grand total.
    Nothing is written, no lock is taken; a store that cannot be read is reported and left
    out. Exit 0.

    Row key
      REVIEWER   '<provider> :: <model>' of the consultation (its ledger reviewer), with
                 ' [<engine>]' appended for an engine other than codex (0.4.0, e.g.
                 'gemini :: gemini-3.8-flash-high [agy]'; an absent reviewer.engine is
                 codex); 'unknown provenance' for entries recorded before 0.3.0 (no reviewer)
      PURPOSE    the consultation's purpose, '(none)' without one; '(total)' on a
                 lineage's total row; the grand total row is '(all) (total)'
      TOPIC      (-By topic, wave 26) each topic of the consultation (ledger topics[], set
                 with codex-consult.ps1 -Topic) - a consultation with two topics counts on both
                 rows, once on its lineage's total row; '(none)' without topics
    Columns (JSON field in brackets)
      CONSULTS   ledger entries [consults]
      USABLE     bridge_outcome 'usable reply' - or (wave 24) 'usable reply (after a timeout
                 continuation)' [usable]
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
                 no [rated_yes, rated_partly, rated_no]; a mark belongs to the consultation
                 whose consult_id it carries (wave 26; a mark recorded before: its n in the task)
      SCORE      (wave 26) the ROUTING score a routed -Panel gives this reviewer for this
                 purpose (a lineage's total row: its all-purpose score) - the shared function
                 of codex-consult-common.ps1 (Get-RoutingScore) over the marks of EVERY task of
                 the repository from the last 90 days: (yes + 0.5 partly + 1) / (n + 2) scaled
                 into [0.25, 2], 1.125 without 3 marks; '-' on a topic row [score: a number, or
                 null]
      UNIQ       (wave 26) findings this reviewer raised as a panel member that no other member
                 of the same panel raised at the same location (path and line; a finding
                 without a location counts as unique), of all it raised in panels - the measure
                 behind "diminishing returns past about five members" [unique, panel_raised]
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
    [switch]$Json,

    # (wave 26) purpose (the default): one row per (lineage, purpose); topic: one row per
    # (lineage, topic) of the consultations' topics[].
    [string]$By = 'purpose'
)

$ErrorActionPreference = 'Stop'
$script:ToolName = 'codex-scoreboard'
. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

if ($Task -and $Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
    Stop-WithError "-Task must be a slug (letters, digits, dot, dash, underscore)."
}
$By = $By.Trim().ToLowerInvariant()
if (@('purpose', 'topic') -notcontains $By) { Stop-WithError "-By must be purpose or topic (got '$By')." }
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

# One accumulator per row key - (lineage, purpose), or (-By topic) (lineage, topic) - and one per
# lineage for its total row: a consultation counts there ONCE, whatever rows it is on (wave 26).
function New-Acc {
    param([string]$Lineage, [string]$Key)
    return [pscustomobject]@{
        Lineage = $Lineage; Purpose = $Key; Consults = 0; Usable = 0; Prose = 0; Failed = 0
        Raised = 0; Verified = 0; Rejected = 0; Wontfix = 0; Superseded = 0; Open = 0
        Accept = 0; Hold = 0; Reject = 0; Advise = 0; Yes = 0; Partly = 0; No = 0; Unique = 0; PanelRaised = 0
        Walls = (New-Object System.Collections.Generic.List[double]); TokensIn = [long]0; TokensOut = [long]0
    }
}
$rows = @{}
$totalRows = @{}
# (wave 26) lineage -> its reviewer identity { Provider; Model; Engine } (the routing score's key)
$identityOf = @{}
function Get-Accs {
    param([string]$Lineage, [string[]]$Keys)
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($k in $Keys) {
        $key = "$Lineage`t$k"
        if (-not $rows.ContainsKey($key)) { $rows[$key] = New-Acc $Lineage $k }
        $list.Add($rows[$key])
    }
    if (-not $totalRows.ContainsKey($Lineage)) { $totalRows[$Lineage] = New-Acc $Lineage '(total)' }
    $list.Add($totalRows[$Lineage])
    return , ([object[]]$list.ToArray())
}
# The row keys of a consultation (or of a mark without one): its purpose, or (-By topic) each of
# its topics; '(none)' without.
function Get-RowKeys {
    param([string]$Purpose, [object[]]$Topics)
    if ($By -eq 'topic') {
        $t = @(@($Topics) | Where-Object { $_ } | ForEach-Object { ([string]$_).ToLowerInvariant() } | Select-Object -Unique)
        if ($t.Count -eq 0) { return , ([string[]]@('(none)')) }
        return , ([string[]]$t)
    }
    if (-not $Purpose) { $Purpose = '(none)' }
    return , ([string[]]@($Purpose))
}
# A finding's location keys ("path:line"; "path:" without a line) for the unique-findings measure.
function Get-LocationKeys {
    param($Finding)
    $keys = New-Object System.Collections.Generic.List[string]
    foreach ($l in @(Get-PropertyValue $Finding 'locations' @() | Where-Object { $null -ne $_ })) {
        $path = [string](Get-PropertyValue $l 'path' '')
        if (-not $path) { continue }
        $line = Get-PropertyValue $l 'line' $null
        $keys.Add("$($path.Replace('\', '/')):$(if ($null -ne $line) { [string]$line } else { '' })")
    }
    return , ([string[]]$keys.ToArray())
}

# (wave 26, D2) every task's findings.json is read ONCE per run: the rows of the tasks shown, and the
# routing scores over the marks of every task of the repository
$storeOf = @{}
if (Test-Path -LiteralPath $collabRoot -PathType Container) {
    foreach ($d in @(Get-ChildItem -LiteralPath $collabRoot -Directory | Sort-Object Name)) { $storeOf[$d.Name] = Read-TolerantStore -Path (Join-Path $d.FullName 'findings.json') }
}
foreach ($dir in $taskDirs) {
    $sessions = Read-TolerantStore -Path (Join-Path $dir.FullName 'sessions.json')
    $store = $(if ($storeOf.ContainsKey($dir.Name)) { $storeOf[$dir.Name] } else { Read-TolerantStore -Path (Join-Path $dir.FullName 'findings.json') })
    # a consultation's rows by its n (the findings' join, within the task) and by its consult_id
    # (the marks' join); its panel id (the unique-findings measure)
    $keyOf = @{}
    $keyOfId = New-Object System.Collections.Hashtable ([StringComparer]::OrdinalIgnoreCase)
    $panelOf = @{}
    foreach ($c in @(Get-PropertyValue (Get-PropertyValue $sessions 'codex' $null) 'consults' @())) {
        if ($null -eq $c) { continue }
        $rev = Get-PropertyValue $c 'reviewer' $null
        $lineage = 'unknown provenance'
        if ($null -ne $rev) {
            $engine = [string](Get-PropertyValue $rev 'engine' '')
            if (-not $engine) { $engine = 'codex' }
            $lineage = Format-ReviewerLineage -Provider ([string](Get-PropertyValue $rev 'provider' '')) -Model ([string](Get-PropertyValue $rev 'model' '')) -Engine $engine
            if (-not $identityOf.ContainsKey($lineage)) { $identityOf[$lineage] = [pscustomobject]@{ Provider = [string](Get-PropertyValue $rev 'provider' ''); Model = [string](Get-PropertyValue $rev 'model' ''); Engine = $engine } }
        }
        $accs = Get-Accs $lineage (Get-RowKeys -Purpose ([string](Get-PropertyValue $c 'purpose' '')) -Topics @(Get-PropertyValue $c 'topics' @()))
        $n = Get-IntValue $c 'n'
        if ($null -ne $n) { $keyOf[$n] = $accs }
        $cid = [string](Get-PropertyValue $c 'consult_id' '')
        if ($cid) { $keyOfId[$cid] = $accs }
        $panelId = [string](Get-PropertyValue (Get-PropertyValue $c 'panel' $null) 'id' '')
        if ($null -ne $n -and $panelId) { $panelOf[$n] = $panelId }
        $outcome = [string](Get-PropertyValue $c 'bridge_outcome' (Get-PropertyValue $c 'outcome' ''))
        $usable = Test-UsableOutcome $outcome
        $prose = ($usable -and (Get-PropertyValue $c 'structured' $false) -ne $true)
        $verdict = [string](Get-PropertyValue $c 'verdict' '')
        $wall = Get-PropertyValue $c 'wall_seconds' $null
        $w = [double]0
        $hasWall = ($null -ne $wall -and [double]::TryParse([string]$wall, [System.Globalization.NumberStyles]::Float, $script:Invariant, [ref]$w))
        $tin = [long]0; $tout = [long]0
        $usage = Get-PropertyValue $c 'usage' $null
        if ($null -ne $usage) {
            $in = Get-IntValue $usage 'input_tokens'
            $cached = Get-IntValue $usage 'cached_input_tokens'
            $out = Get-IntValue $usage 'output_tokens'
            if ($null -ne $in) { $tin = [Math]::Max([long]0, $in - $(if ($null -ne $cached) { $cached } else { 0 })) }
            if ($null -ne $out) { $tout = $out }
        }
        foreach ($acc in $accs) {
            $acc.Consults++
            if ($usable) { $acc.Usable++; if ($prose) { $acc.Prose++ } } else { $acc.Failed++ }
            switch ($verdict) {
                'ACCEPT' { $acc.Accept++ }
                'HOLD' { $acc.Hold++ }
                'REJECT' { $acc.Reject++ }
                'ADVISE' { $acc.Advise++ }
            }
            if ($hasWall) { $acc.Walls.Add($w) }
            $acc.TokensIn += $tin
            $acc.TokensOut += $tout
        }
    }
    $findingsList = @(@(Get-PropertyValue $store 'findings' @()) | Where-Object { $null -ne $_ })
    # (wave 26, D10) the unique-findings measure: a finding raised by a panel member is unique when
    # no finding of ANOTHER member of the same panel shares one of its locations
    $locsOf = @{}
    for ($i = 0; $i -lt $findingsList.Count; $i++) { $locsOf[$i] = Get-LocationKeys $findingsList[$i] }
    for ($i = 0; $i -lt $findingsList.Count; $i++) {
        $f = $findingsList[$i]
        $n = Get-IntValue (Get-PropertyValue $f 'source' $null) 'consult'
        $accs = $null
        if ($null -ne $n -and $keyOf.ContainsKey($n)) { $accs = $keyOf[$n] } else { $accs = Get-Accs 'unknown provenance' @('(none)') }
        $inPanel = ($null -ne $n -and $panelOf.ContainsKey($n))
        $unique = $false
        if ($inPanel) {
            $unique = $true
            $mine = @($locsOf[$i])
            if ($mine.Count -gt 0) {
                for ($j = 0; $j -lt $findingsList.Count; $j++) {
                    if ($j -eq $i) { continue }
                    $nj = Get-IntValue (Get-PropertyValue $findingsList[$j] 'source' $null) 'consult'
                    if ($null -eq $nj -or $nj -eq $n -or -not $panelOf.ContainsKey($nj) -or $panelOf[$nj] -ne $panelOf[$n]) { continue }
                    if (@($locsOf[$j] | Where-Object { $mine -contains $_ }).Count -gt 0) { $unique = $false; break }
                }
            }
        }
        foreach ($acc in $accs) {
            $acc.Raised++
            switch ([string](Get-PropertyValue $f 'status' '')) {
                'verified' { $acc.Verified++ }
                'rejected' { $acc.Rejected++ }
                'wontfix' { $acc.Wontfix++ }
                'superseded' { $acc.Superseded++ }
                'proposed' { $acc.Open++ }
                'implemented' { $acc.Open++ }
            }
            if ($inPanel) { $acc.PanelRaised++; if ($unique) { $acc.Unique++ } }
        }
    }
    foreach ($rt in @(Get-PropertyValue $store 'ratings' @())) {
        if ($null -eq $rt) { continue }
        # (wave 26, D2) a mark belongs to the consultation whose consult_id it carries; a mark
        # recorded without one, to its n in this task
        $accs = $null
        $cid = [string](Get-PropertyValue $rt 'consult_id' '')
        $n = Get-IntValue $rt 'n'
        if ($cid -and $keyOfId.ContainsKey($cid)) { $accs = $keyOfId[$cid] }
        elseif (-not $cid -and $null -ne $n -and $keyOf.ContainsKey($n)) { $accs = $keyOf[$n] }
        else { $accs = Get-Accs ([string](Get-PropertyValue $rt 'lineage' 'unknown provenance')) (Get-RowKeys -Purpose ([string](Get-PropertyValue $rt 'purpose' '')) -Topics @(Get-PropertyValue $rt 'topics' @())) }
        foreach ($acc in $accs) {
            switch ([string](Get-PropertyValue $rt 'useful' '')) {
                'yes' { $acc.Yes++ }
                'partly' { $acc.Partly++ }
                'no' { $acc.No++ }
            }
        }
    }
}

# (wave 26, D2) the routing score of every row - the bridge's own function over the marks of EVERY
# task of the repository (read once), at the consult clock (CODEX_CONSULT_NOW in tests)
$scoreClock = Get-ConsultClock -Peek
$scoreNow = $(if ($scoreClock.Error) { [datetime]::UtcNow } else { $scoreClock.Now.UtcDateTime })
$allRatings = Read-AllTaskRatings -CollabRoot $collabRoot -Stores $storeOf
function Get-RowScore {
    param([string]$Lineage, [string]$Key, [switch]$Total)
    if (-not $identityOf.ContainsKey($Lineage)) { return $null }
    if ($By -eq 'topic' -and -not $Total) { return $null }
    $id = $identityOf[$Lineage]
    if ($Total) { $sc = Get-RoutingScore -Ratings $allRatings -Provider $id.Provider -Model $id.Model -Engine $id.Engine -AllPurpose -UtcNow $scoreNow }
    else { $sc = Get-RoutingScore -Ratings $allRatings -Provider $id.Provider -Model $id.Model -Engine $id.Engine -Purpose $(if ($Key -eq '(none)') { '' } else { $Key }) -UtcNow $scoreNow }
    return [Math]::Round([double]$sc.Score, 3)
}

function Get-Median {
    param([double[]]$Values)
    if ($Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $mid = [int][Math]::Floor($sorted.Count / 2)
    if ($sorted.Count % 2 -eq 1) { return [double]$sorted[$mid] }
    return ([double]$sorted[$mid - 1] + [double]$sorted[$mid]) / 2
}

$counters = @('Consults', 'Usable', 'Prose', 'Failed', 'Raised', 'Verified', 'Rejected', 'Wontfix', 'Superseded', 'Open', 'Accept', 'Hold', 'Reject', 'Advise', 'Yes', 'Partly', 'No', 'Unique', 'PanelRaised', 'TokensIn', 'TokensOut')
function New-OutRow {
    param([string]$Kind, [string]$Lineage, [string]$Purpose, [object[]]$Parts, $Score = $null)
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
        score               = $Score
        unique              = $sum.Unique
        panel_raised        = $sum.PanelRaised
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
    foreach ($a in $mine) { $out.Add((New-OutRow -Kind $(if ($By -eq 'topic') { 'topic' } else { 'purpose' }) -Lineage $lin -Purpose $a.Purpose -Parts @($a) -Score (Get-RowScore -Lineage $lin -Key $a.Purpose))) }
    $out.Add((New-OutRow -Kind 'lineage' -Lineage $lin -Purpose '(total)' -Parts @($totalRows[$lin]) -Score (Get-RowScore -Lineage $lin -Key '' -Total)))
}
if ($all.Count -gt 0) { $out.Add((New-OutRow -Kind 'total' -Lineage '(all)' -Purpose '(total)' -Parts @($totalRows.Values))) }

if ($Json) {
    Write-Output (ConvertTo-Json -InputObject ([object[]]$out.ToArray()) -Depth 4)
    exit 0
}

Write-Host "codex-scoreboard: $collabRoot$(if ($Task) { " (task $Task)" } else { " ($($taskDirs.Count) task(s))" })$(if ($By -eq 'topic') { '; rows by topic' })"
foreach ($note in $notes) { Write-Host $note -ForegroundColor Yellow }
if ($out.Count -eq 0) {
    Write-Host 'no consultations recorded.'
    exit 0
}
$header = [ordered]@{ reviewer = 'REVIEWER'; purpose = $(if ($By -eq 'topic') { 'TOPIC' } else { 'PURPOSE' }); consults = 'CONSULTS'; usable = 'USABLE'; prose = 'PROSE'; failed = 'FAILED'; raised = 'RAISED'; verified = 'VERIFIED'; rejected = 'REJECTED'; wontfix = 'WONTFIX'; superseded = 'SUPERSEDED'; open = 'OPEN'; hit = 'HIT%'; verdicts = 'A/H/R/D'; ratings = 'Y/P/N'; score = 'SCORE'; uniq = 'UNIQ'; median = 'MEDIAN_S'; tokens = 'TOKENS' }
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
            score      = $(if ($null -eq $r.score) { '-' } else { ([double]$r.score).ToString('0.###', $script:Invariant) })
            uniq       = "$($r.unique)/$($r.panel_raised)"
            median     = $(if ($null -eq $r.median_wall_seconds) { '-' } else { ([double]$r.median_wall_seconds).ToString('0.#', $script:Invariant) })
            tokens     = "$($r.tokens_in)/$($r.tokens_out)"
        })
}
$cols = @($header.Keys)
$numeric = @('consults', 'usable', 'prose', 'failed', 'raised', 'verified', 'rejected', 'wontfix', 'superseded', 'open', 'hit', 'score', 'median')
$width = @{}
foreach ($col in $cols) { $width[$col] = (@($lines | ForEach-Object { ([string]$_.$col).Length }) | Measure-Object -Maximum).Maximum }
foreach ($l in $lines) {
    $parts = foreach ($col in $cols) { if ($numeric -contains $col) { ([string]$l.$col).PadLeft($width[$col]) } else { ([string]$l.$col).PadRight($width[$col]) } }
    Write-Host (($parts -join '  ').TrimEnd())
}
exit 0
