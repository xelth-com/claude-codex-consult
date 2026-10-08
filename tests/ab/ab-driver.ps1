# Wave 29c (E8): the paired A/B of one plan's two routes - the codex route (<CodexLabel>) and the
# Claude Code endpoint route (<ClaudeLabel>) - on the same briefs, order randomised per pair.
# Runs INSIDE one dedicated worktree of the repository (the claude engine's strict tree check
# fails a turn when the collab directory changes, so each plan's chain has its own worktree).
# Resumable: a pair's arm that already has a usable ledger entry (reply name ab-<NN>-<arm>) is skipped.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File ab-driver.ps1 -Repo C:\Users\Dmytro\cc-ab-zai `
#     -Task ab-zai-2026-10-07 -CodexLabel ZAI -ClaudeLabel ZAI-claude -Seed 29 -Log <log>
param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Task,
    [Parameter(Mandatory)][string]$CodexLabel,
    [Parameter(Mandatory)][string]$ClaudeLabel,
    [int]$Seed = 29,
    [int]$Pairs = 12,
    [int]$TimeoutSec = 1800,
    [int]$RetryMinutes = 20,
    [int]$MaxRetries = 9,
    [string]$Scripts = 'C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\scripts',
    [string]$Log = ''
)
$ErrorActionPreference = 'Stop'
if (-not $Log) { $Log = Join-Path $PSScriptRoot "ab-$Task.log" }
function Say([string]$t) { $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $t"; Write-Host $line; [IO.File]::AppendAllText($Log, $line + "`n") }
$bridge = Join-Path $Scripts 'codex-consult.ps1'
$ledger = Join-Path $Repo ".collab\$Task\sessions.json"
$handoffs = Join-Path $Repo ".collab\$Task\handoffs"
Set-Location $Repo
$briefs = @(Get-ChildItem -LiteralPath $handoffs -Filter '*-claude-ab-*.md' | Sort-Object Name | Select-Object -First $Pairs)
if ($briefs.Count -lt $Pairs) { throw "only $($briefs.Count) briefs in $handoffs (need $Pairs)" }
$rng = New-Object System.Random($Seed)
function Get-Done {
    $done = @{}
    if (-not (Test-Path -LiteralPath $ledger)) { return $done }
    $j = Get-Content -LiteralPath $ledger -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($c in @($j.codex.consults)) {
        $name = [string]$c.reply
        if ($name -match 'ab-(\d\d)-(codex|claude)') {
            $key = "$($Matches[1])-$($Matches[2])"
            $usable = ([string]$c.bridge_outcome) -like 'usable reply*'
            $failed = ([string]$c.bridge_outcome) -like 'failed:*'
            # a usable arm is done; a failed arm of class quota/transport is retried, any other failure is final
            if ($usable) { $done[$key] = 'usable' }
            elseif ($failed) {
                $cls = [string]$c.provider_failure.class
                if ($cls -in @('quota', 'transport', 'unknown', '')) { if (-not $done.ContainsKey($key)) { $done[$key] = 'retry' } }
                else { $done[$key] = "failed:$cls" }
            }
        }
    }
    return $done
}
Say "ab-driver: task $Task in $Repo; codex=$CodexLabel claude=$ClaudeLabel; $($briefs.Count) briefs; seed $Seed; log $Log"
$i = 0
foreach ($b in $briefs) {
    $i++
    $nn = '{0:00}' -f $i
    $rel = ".collab/$Task/handoffs/$($b.Name)"
    $first = if ($rng.Next(2) -eq 0) { 'codex' } else { 'claude' }
    $order = if ($first -eq 'codex') { @('codex', 'claude') } else { @('claude', 'codex') }
    Say "pair $nn ($($b.Name)): order $($order -join ' then ')"
    foreach ($arm in $order) {
        $label = if ($arm -eq 'codex') { $CodexLabel } else { $ClaudeLabel }
        $key = "$nn-$arm"
        $tries = 0
        while ($true) {
            $done = Get-Done
            if ($done.ContainsKey($key) -and $done[$key] -ne 'retry') { Say "  $key already $($done[$key]) - skip"; break }
            if ($tries -ge $MaxRetries) { Say "  $key gave up after $tries retries"; break }
            $tries++
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
            $out = @(& powershell -NoProfile -ExecutionPolicy Bypass -File $bridge -Task $Task -Provider $label -Mode new -Purpose checkpoint -TimeoutSec $TimeoutSec -Brief $rel -Prompt 'Read the brief and answer every numbered question in it.' -ReplyName "ab-$nn-$arm" 2>&1 | ForEach-Object { "$_" })
            $code = $LASTEXITCODE
            $ErrorActionPreference = $prev
            $sw.Stop()
            $tail = ($out | Select-Object -Last 3) -join ' | '
            Say "  $key ($label) try $tries exit $code $([int]$sw.Elapsed.TotalSeconds) s :: $tail"
            $done = Get-Done
            if ($done.ContainsKey($key) -and $done[$key] -ne 'retry') { break }
            # no entry (a preflight refusal: usage limit, plan out) or a retryable failure: wait, then again
            Say "  $key not usable yet - waiting $RetryMinutes min"
            Start-Sleep -Seconds ($RetryMinutes * 60)
        }
    }
}
Say "ab-driver: done"
