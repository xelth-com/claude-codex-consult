# codex-consult wave 28b (0.5.0; the fix round of the waves 27c/28/27d acceptance - decisions D1-D19 of
# .collab/companions-2026-09-26/handoffs/39-...): TESTMODE - a run in test mode says so ("test mode
# is ON: test hooks are honoured", console and warnings[]); no ENGINE child - the main turn, the
# launcher probes - gets CODEX_CONSULT_TEST_MODE or a CODEX_CONSULT_TEST_* variable, while a panel
# member and a detached background (the bridge itself) keep them (D10); STALL - an open tool call
# suspends the stall cut only while the stream grows: 2 x stall without growth end it (no floor), the
# cut names the open call, a growing stream is never cut (D12); HEALTH - the journal beside the
# health file: written at the commit, applied (idempotently) by the retry after it or by the next
# run of any repository, the retry's outcome in the summary and the detached status (D13); KILL - the
# process-table parsers of the ps and /proc fallbacks, the descendants' start times, a recycled pid
# is no survivor (D14); CONTEXT - a roster context_tokens reaches codex as -c model_context_window and
# -c model_auto_compact_token_limit, recorded in the ledger (D15); DAYS - the local day directories
# across midnight, invariant digits under a non-Gregorian culture (D16); DOCS - the README.
# FAKES ONLY: fake-codex3.cmd; CODEX_HOME and CODEX_CONSULT_ROSTER point at scratch files,
# CODEX_CONSULT_HEALTH is 'none' (HEALTH: scratch paths), telemetry off; the host markers of the
# process that runs it are removed first; the API key variables hold dummy values. Runs under the
# host it is started with (powershell 5.1 or pwsh 7, Windows). Work files:
# $env:TEMP\codex-consult-tests\harness-fixes28b\<guid>, removed at the end.
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
$env:CODEX_CONSULT_HEALTH = 'none'
# (wave 28) telemetry off and the intake pointed at nothing reachable: no harness but
# harness-telemetry spools an event or contacts an intake
$env:CODEX_CONSULT_TELEMETRY = 'off'
$env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
# (wave 27c, D14) the test hooks (CODEX_CONSULT_TEST_*, CODEX_CONSULT_NOW) are honoured only in test mode
$env:CODEX_CONSULT_TEST_MODE = '1'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
. (Join-Path $scripts 'codex-consult-common.ps1')
$pluginDir = Split-Path -Parent $scripts
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-fixes28b') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 10; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
$savedCodexHome = $env:CODEX_HOME
$script:fails = 0
$script:passes = 0
$testModeLine = 'test mode is ON: test hooks are honoured'
function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 400) { $ev = $ev.Substring(0, 400) + '...' }
    Write-Host ("{0} {1,-8} {2}{3}" -f $mark, $Id, $What, $(if ($ev) { "  | $ev" } else { '' }))
}
function Want { param([string]$Name) return (-not $Only -or ($Only -split ',') -contains $Name) }
function G { param([string]$Repo, [string[]]$A) $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = & git -C $Repo @A 2>&1; $ErrorActionPreference = $p; return $o }
function New-Repo {
    param([string]$Name)
    $r = Join-Path $work $Name
    if (Test-Path $r) { Remove-Item $r -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($r)
    $null = G $r @('init', '-q'); $null = G $r @('config', 'user.email', 't@e.com'); $null = G $r @('config', 'user.name', 'T')
    [IO.File]::WriteAllText((Join-Path $r 'app.txt'), "one`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'init')
    return $r
}
$toml = "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n"
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml, $u8)
function Write-Roster { param([string]$Name, [string]$Json) $p = Join-Path $work "roster-$Name.json"; [IO.File]::WriteAllText($p, $Json, $u8); return $p }
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ENV_DUMP', 'FAKE_CODEX_TOOL_OPEN')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CODEX_CONSULT_TEST_PANEL_SEED', 'CODEX_CONSULT_TEST_WAIT_TICK_MS', 'CODEX_CONSULT_TEST_HEALTH_LOCK_SEC', 'CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST', 'CODEX_CONSULT_TEST_DETACH_GUIDS', 'CODEX_CONSULT_TEST_TOOL_CAP_SEC', 'CODEX_CONSULT_TEST_PROBE_SCRUB_FAIL', 'CODEX_CONSULT_TEST_XYZ')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    foreach ($k in (Get-HostMarkerNames)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $env:CODEX_CONSULT_HEALTH = 'none'
    $env:CODEX_CONSULT_TEST_MODE = '1'
}
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env { Clear-TestEnv; $env:CODEX_HOME = $savedCodexHome }
function Get-Previews {
    param([string]$Text)
    $list = New-Object System.Collections.Generic.List[object]
    $mark = 'sessions.json entry preview:'
    $at = $Text.IndexOf($mark)
    while ($at -ge 0) {
        $rest = $Text.Substring($at + $mark.Length)
        $next = $rest.IndexOf($mark)
        $chunk = $(if ($next -ge 0) { $rest.Substring(0, $next) } else { $rest })
        $lines = New-Object System.Collections.Generic.List[string]
        $depth = 0
        $started = $false
        foreach ($l in ($chunk -split "`n")) {
            $t = $l.TrimEnd("`r")
            if (-not $started) { if ($t.Trim() -eq '{') { $started = $true } else { continue } }
            $lines.Add($t)
            $depth += ([regex]::Matches($t, '[\{\[]')).Count - ([regex]::Matches($t, '[\}\]]')).Count
            if ($started -and $depth -le 0) { break }
        }
        try { $list.Add((($lines.ToArray() -join "`n") | ConvertFrom-Json)) } catch { $list.Add($null) }
        $at = $(if ($next -ge 0) { $at + $mark.Length + $next } else { -1 })
    }
    return , ($list.ToArray())
}
# One bridge call (synchronous): { Code; Out; First; Previews }
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{}, [switch]$NoCodexExe)
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $all = @('-Task', 't')
    if (-not $NoCodexExe) { $all += @('-CodexExe', $fake) }
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs @all @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1); Previews = (Get-Previews $text) }
}
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Text { param([string]$Path) if ($Path -and (Test-Path -LiteralPath $Path)) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
# The variable NAMES a fake engine child dumped (FAKE_CODEX_ENV_DUMP: <kind>-<pid>.env, NAME=VALUE lines)
function Read-EnvDumps {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { return }
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -File -Filter '*.env')) {
        $t = Text $f.FullName
        $names = @(($t -split "`n") | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=' } | ForEach-Object { $_.Substring(0, $_.IndexOf('=')) })
        [pscustomobject]@{ Kind = ($f.Name -replace '-\d+\.env$', ''); Names = [string[]]$names }
    }
}
function Has-TestVar { param($Dump) return (@($Dump.Names | Where-Object { ([string]$_).ToUpperInvariant().StartsWith('CODEX_CONSULT_TEST_') }).Count -gt 0) }
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Join-Path $work 'advise.json'
[IO.File]::WriteAllText($advise, $adviseJson, $u8)
$roster2 = Write-Roster 'two' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'

try {

# =============================================================== TESTMODE: said, and never handed to an engine child (D10)
if (Want 'TESTMODE') {
    Clear-TestEnv
    $env:CODEX_CONSULT_TEST_XYZ = 'x'; $env:CLAUDECODE = '1'
    $saved = Hide-HostMarkers -TestVars
    $during = @((Get-HostMarkerNames) + (Get-TestVarNames)) -join ','
    $tmDuring = [string]$env:CODEX_CONSULT_TEST_MODE
    Restore-HostMarkers -Saved $saved
    $after = (Get-TestVarNames) -join ','
    $saved2 = Hide-HostMarkers
    $keptPlain = (Get-TestVarNames) -join ','
    Restore-HostMarkers -Saved $saved2
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $scrub = Remove-HostMarkersFromStartInfo $psi
    $psiNames = @($psi.EnvironmentVariables.Keys | ForEach-Object { ([string]$_).ToUpperInvariant() })
    $psi2 = New-Object System.Diagnostics.ProcessStartInfo
    $scrub2 = Remove-HostMarkersFromStartInfo $psi2 -KeepTestVars
    $psi2Names = @($psi2.EnvironmentVariables.Keys | ForEach-Object { ([string]$_).ToUpperInvariant() })
    Clear-TestEnv
    Check 'TESTMODE' 'D10 (F36-5) Hide-HostMarkers -TestVars (an engine child) hides the host markers AND CODEX_CONSULT_TEST_MODE / every CODEX_CONSULT_TEST_* in one transaction and restores them; without -TestVars (the detached background) they stay; a probe''s start info loses them (Remove-HostMarkersFromStartInfo), -KeepTestVars keeps them' ($during -eq '' -and $tmDuring -eq '' -and $after -eq 'CODEX_CONSULT_TEST_MODE,CODEX_CONSULT_TEST_XYZ' -and $keptPlain -eq 'CODEX_CONSULT_TEST_MODE,CODEX_CONSULT_TEST_XYZ' -and -not $scrub -and @($psiNames | Where-Object { $_.StartsWith('CODEX_CONSULT_TEST_') -or $_ -eq 'CLAUDECODE' }).Count -eq 0 -and -not $scrub2 -and $psi2Names -contains 'CODEX_CONSULT_TEST_MODE' -and $psi2Names -notcontains 'CLAUDECODE') "during '$during' after '$after' plain '$keptPlain' probe [$(@($psiNames | Where-Object { $_ -like 'CODEX_CONSULT_TEST*' }) -join ',')] keep [$(@($psi2Names | Where-Object { $_ -like 'CODEX_CONSULT_TEST*' }) -join ',')]"
    # end to end: a run in test mode - the console, warnings[], the engine child and the probes
    $r = New-Repo 'testmode'
    $dump = Join-Path $work 'dump-tm'
    [void][IO.Directory]::CreateDirectory($dump)
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'tm') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_ENV_DUMP = $dump; CODEX_CONSULT_TEST_XYZ = 'x' }
    $e = @(Ledger $r)[-1]
    $dumps = @(Read-EnvDumps $dump)
    $exec = @($dumps | Where-Object { $_.Kind -eq 'exec' })
    $probes = @($dumps | Where-Object { $_.Kind -ne 'exec' })
    Check 'TESTMODE' 'D10 a run with CODEX_CONSULT_TEST_MODE=1 prints "WARNING: test mode is ON: test hooks are honoured" and puts the line into warnings[] (once); the engine child (exec) and the launcher probes (version, login status) saw NO CODEX_CONSULT_TEST_* variable - the fake needs none' ($x.Code -eq 0 -and $x.Out -match '(?m)^WARNING: test mode is ON: test hooks are honoured\r?$' -and @(@($e.warnings) | Where-Object { [string]$_ -eq $testModeLine }).Count -eq 1 -and $exec.Count -eq 1 -and $probes.Count -ge 1 -and @($dumps | Where-Object { Has-TestVar $_ }).Count -eq 0) "exit $($x.Code); dumps $($dumps.Count) ($(@($dumps | ForEach-Object { $_.Kind }) -join ',')); with test vars: $(@($dumps | Where-Object { Has-TestVar $_ } | ForEach-Object { $_.Kind }) -join ',')"
    $x0 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'tm0') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_TEST_MODE = '' }
    $e0 = @(Ledger $r)[-1]
    Check 'TESTMODE' 'D10 without test mode: no such line on the console or in warnings[]' ($x0.Code -eq 0 -and $x0.Out -notmatch 'test mode is ON' -and @(@($e0.warnings) | Where-Object { [string]$_ -eq $testModeLine }).Count -eq 0) "exit $($x0.Code); $(@($e0.warnings) -join ' | ')"
    # a panel: the members ARE the bridge (they keep test mode), their engine children do not get it
    $rp = New-Repo 'testmode-panel'
    $dumpP = Join-Path $work 'dump-tm-panel'
    [void][IO.Directory]::CreateDirectory($dumpP)
    $pr = Consult $rp $roster2 @('-Panel', '-PanelSize', '2', '-PanelOrder', 'roster', '-Prompt', 'x', '-ReplyName', 'pan') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_ENV_DUMP = $dumpP; CODEX_CONSULT_TEST_PANEL_SEED = '28' }
    $led = @(Ledger $rp)
    $execP = @(@(Read-EnvDumps $dumpP) | Where-Object { $_.Kind -eq 'exec' })
    Check 'TESTMODE' 'D10 a -Panel run: the panel run prints the line; both members (the bridge itself) ran in test mode - each warnings[] holds the line once; neither member''s engine child saw a CODEX_CONSULT_TEST_* variable' ($pr.Code -eq 0 -and $pr.Out -match '(?m)^WARNING: test mode is ON: test hooks are honoured' -and $led.Count -eq 2 -and @($led | Where-Object { @(@($_.warnings) | Where-Object { [string]$_ -eq $testModeLine }).Count -eq 1 }).Count -eq 2 -and $execP.Count -eq 2 -and @($execP | Where-Object { Has-TestVar $_ }).Count -eq 0) "exit $($pr.Code), entries $($led.Count), exec dumps $($execP.Count)"
}

# =============================================================== STALL: the tool suspension needs growth (D12)
if (Want 'STALL') {
    $open = New-Object 'System.Collections.Generic.HashSet[string]'
    $labels = @{}
    Update-ToolFlight -Engine 'agy' -Line '{"event":"step_update","step_update":{"step_index":4,"step_type":"tool","state":"ACTIVE"}}' -Open $open -Labels $labels
    Update-ToolFlight -Engine 'muse' -Line '{"payload_type":"task.lifecycle.proposed","payload":{"event":{"task_id":"t1","task_kind":"tool.shell"}}}' -Open $open -Labels $labels
    Update-ToolFlight -Engine 'codex' -Line '{"type":"item.started","item":{"id":"item_3","type":"mcp_tool_call"}}' -Open $open -Labels $labels
    $names = @($open | Sort-Object | ForEach-Object { [string]$labels[$_] }) -join ', '
    Check 'STALL' 'D12 (F36-11) the open tool calls are NAMED for the cut: agy "agy tool step 4", muse "muse tool.shell t1", codex "codex mcp_tool_call item_3"' ($names -eq 'agy tool step 4, codex mcp_tool_call item_3, muse tool.shell t1') $names
    $env:CODEX_CONSULT_TEST_WAIT_TICK_MS = '200'
    $ef = Join-Path $work 'muse-tool.jsonl'
    [IO.File]::WriteAllText($ef, '{"payload_type":"task.lifecycle.proposed","payload":{"event":{"task_id":"t1","task_kind":"tool.shell"}}}' + "`n", $u8)
    $pl = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 40' -PassThru -WindowStyle Hidden
    $w1 = [Diagnostics.Stopwatch]::StartNew()
    $wm = Wait-EngineProcess -Process $pl -TimeoutSec 20 -StallSec 2 -EventsPath $ef -Engine 'muse'
    $w1.Stop()
    try { Stop-Process -Id $pl.Id -Force -ErrorAction SilentlyContinue } catch { }
    Check 'STALL' 'D12 a muse tool call open and the stream silent: the suspension ends after 2 x stall (4 s; no 1800 s floor, no completion event needed) - Reason stall, Silent >= 4, OpenTools "muse tool.shell t1", long before the 20 s timeout' ($wm.Reason -eq 'stall' -and $wm.Silent -ge 4 -and $wm.OpenTools -eq 'muse tool.shell t1' -and $w1.Elapsed.TotalSeconds -lt 10) "$($wm.Reason) silent $($wm.Silent) [$($wm.OpenTools)] in $([math]::Round($w1.Elapsed.TotalSeconds, 1)) s"
    # a tool call open while the stream GROWS (a line a second): never cut; the timeout ends it
    $eg = Join-Path $work 'grow.jsonl'
    [IO.File]::WriteAllText($eg, '{"type":"item.started","item":{"id":"item_1","type":"command_execution"}}' + "`n", $u8)
    $growPs1 = Join-Path $work 'grow.ps1'
    [IO.File]::WriteAllText($growPs1, 'for ($i = 0; $i -lt 12; $i++) { Start-Sleep -Milliseconds 700; [IO.File]::AppendAllText($args[0], (''{"type":"item.updated","n":'' + $i + ''}'' + [char]10)) }; Start-Sleep 30' + "`n", $u8)
    $pg = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$growPs1`"", "`"$eg`"" -PassThru -WindowStyle Hidden
    $wg = Wait-EngineProcess -Process $pg -TimeoutSec 7 -StallSec 2 -EventsPath $eg -Engine 'codex'
    try { Stop-Process -Id $pg.Id -Force -ErrorAction SilentlyContinue } catch { }
    Remove-Item env:CODEX_CONSULT_TEST_WAIT_TICK_MS -ErrorAction SilentlyContinue
    Check 'STALL' 'D12 a tool call open while the stream keeps growing (a line every 0.7 s): no stall cut - the 7 s timeout ends the wait (stall 2 s, bound 4 s)' ($wg.Reason -eq 'timeout' -and $wg.OpenTools -eq '') "$($wg.Reason) [$($wg.OpenTools)] events $($wg.Events)"
}

# =============================================================== HEALTH: the journal (D13)
if (Want 'HEALTH') {
    $hp = Join-Path $work 'health-unit.json'
    $env:CODEX_CONSULT_HEALTH = $hp
    $rec = New-MachineHealthRecord -Fingerprint 'fp-28b' -Outcome 'usable reply' -Repo 'C:\repo-a'
    $j1 = Add-MachineHealthJournal -Record $rec
    $jp = Get-MachineHealthJournalPath
    $jLines1 = @((Text $jp) -split "`n" | Where-Object { $_.Trim() }).Count
    $ok1 = Update-MachineHealth -AddRunning ([pscustomobject]@{ endpoint = 'fp-28b'; pid = $PID; start_time = [string](Get-ProcessStartIso -ProcessId $PID) })
    $eps1 = @((Read-MachineHealth -Fresh).Endpoints | Where-Object { $_.endpoint -eq 'fp-28b' })
    $jAfter = (Text $jp)
    # applying again: the same record once more in the journal, and once more directly
    $null = Add-MachineHealthJournal -Record $rec
    $ok2 = Update-MachineHealth -AddEndpoint $rec
    $eps2 = @((Read-MachineHealth -Fresh).Endpoints | Where-Object { $_.endpoint -eq 'fp-28b' })
    $env:CODEX_CONSULT_HEALTH = 'none'
    Check 'HEALTH' 'D13 (F36-6, F37-1) the journal beside the health file (<health>.journal, one NDJSON record per line, appended without the health lock): ANY later update - here a running row - applies it under the lock and empties it; applying the same record again (journal + direct) adds nothing (idempotent)' ($j1 -eq '' -and $jp -eq "$hp.journal" -and $jLines1 -eq 1 -and $ok1 -and $eps1.Count -eq 1 -and -not $jAfter.Trim() -and $ok2 -and $eps2.Count -eq 1) "journal '$j1' lines $jLines1, applied $ok1 ($($eps1.Count)), after '$($jAfter.Trim())', again $ok2 ($($eps2.Count))"
    # end to end, the retry after the commit succeeds (test hook: the run's first endpoint update fails)
    $hE = Join-Path $work 'health-e2e.json'
    $r = New-Repo 'health-retry'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'hr') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $hE; CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST = '1' }
    $e = @(Ledger $r)[-1]
    $want = 'machine-wide health not updated at the commit (lock timeout (test hook CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST)); the record is kept in the journal; a retry follows the commit'
    $saved = $env:CODEX_CONSULT_HEALTH; $env:CODEX_CONSULT_HEALTH = $hE
    $epE = @((Read-MachineHealth -Fresh).Endpoints)
    $env:CODEX_CONSULT_HEALTH = $saved
    Check 'HEALTH' 'D13 end to end: the update before the commit fails -> the entry says "... at the commit (<cause>); the record is kept in the journal; a retry follows the commit"; the retry after the commit applies the journal: the summary says "health     : machine-wide health updated by the retry after the commit", the health file holds the record ONCE, the journal is empty' ($x.Code -eq 0 -and @($e.warnings) -contains $want -and $x.Out -match '(?m)^health     : machine-wide health updated by the retry after the commit' -and $epE.Count -eq 1 -and -not (Text "$hE.journal").Trim()) "exit $($x.Code); $(@($e.warnings) -join ' / ') | $(Line $x.Out 'health     :') | records $($epE.Count)"
    # the crash window: the run dies after its commit - the journal keeps the record; the next run of ANOTHER repository applies it
    $hC = Join-Path $work 'health-crash.json'
    $env:CODEX_CONSULT_HEALTH = $hC
    $orphan = New-MachineHealthRecord -Fingerprint 'fp-crash' -Outcome 'failed: x' -Failure ([pscustomobject]@{ class = 'quota'; kind = ''; message = 'm'; when = (Get-IsoTimestamp) }) -Repo 'C:\repo-died'
    $null = Add-MachineHealthJournal -Record $orphan
    $env:CODEX_CONSULT_HEALTH = 'none'
    $r2 = New-Repo 'health-next'
    $x2 = Consult $r2 '' @('-Prompt', 'x', '-ReplyName', 'hn') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $hC }
    $env:CODEX_CONSULT_HEALTH = $hC
    $epC = @((Read-MachineHealth -Fresh).Endpoints | Where-Object { $_.endpoint -eq 'fp-crash' })
    $env:CODEX_CONSULT_HEALTH = 'none'
    Check 'HEALTH' 'D13 the crash window closed: a record left in the journal by a run that died after its commit (quota, fp-crash) is applied by the next run of ANOTHER repository - the health file holds it (class quota), the journal is empty' ($x2.Code -eq 0 -and $epC.Count -eq 1 -and $epC[0].class -eq 'quota' -and -not (Text "$hC.journal").Trim()) "exit $($x2.Code); records $($epC.Count); journal '$((Text "$hC.journal").Trim())'"
    # a detached run: its status record carries the retry's outcome
    $hD = Join-Path $work 'health-detach.json'
    $rd = New-Repo 'health-detach'
    $gid = '0000beef-0000-4000-8000-000000000028'
    $fd = Consult $rd '' @('-Prompt', 'x', '-ReplyName', 'hd', '-Detach') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $hD; CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST = '1'; CODEX_CONSULT_TEST_DETACH_GUIDS = $gid }
    $wd = Consult $rd '' @('-Wait', '-Id', '0000beef', '-WaitTimeoutSec', '120') @{} -NoCodexExe
    $st = $null; try { $st = Text (Join-Path $rd '.collab\t\.consult.detached-0000beef.status.json') | ConvertFrom-Json } catch { }
    $ed = @(Ledger $rd)[-1]
    Check 'HEALTH' 'D13 a detached run: its status record''s summary carries the outcome of the retry ("health     : machine-wide health updated by the retry after the commit"); (D10) the background kept test mode - its hook worked and its entry holds the test-mode line' ($fd.Code -eq 0 -and $wd.Code -eq 0 -and $st -and ([string]$st.summary) -match 'health     : machine-wide health updated by the retry after the commit' -and @(@($ed.warnings) | Where-Object { [string]$_ -eq $testModeLine }).Count -eq 1) "fg $($fd.Code) wait $($wd.Code) | $(if ($st) { (([string]$st.summary) -split "`n" | Where-Object { $_ -like 'health*' }) -join '' })"
}

# =============================================================== KILL: the process table fallbacks, start times (D14)
if (Want 'KILL') {
    $psText = @('    1     0', '  200     1', '  201   200', '  202   201', '  300     1', 'garbage line', '  203   200')
    $pairs = ConvertFrom-ProcessTable -Lines $psText -Format 'ps'
    $treePs = (Get-TreeFromPairs -Pairs $pairs -RootId 200) -join ','
    $procText = @('200 (bash) S 1 200 200 0 -1', '201 (my (odd) app) S 200 201 200 0 -1', '202 (x y) R 201 202 200 0 -1', '300 (other) S 1 300 300 0 -1', 'not a stat line')
    $pairs2 = ConvertFrom-ProcessTable -Lines $procText -Format 'proc'
    $treeProc = (Get-TreeFromPairs -Pairs $pairs2 -RootId 200) -join ','
    Check 'KILL' 'D14 (F37-3) without pgrep the children come from `ps -A -o pid=,ppid=` (two numbers a line), else /proc/<pid>/stat (the ppid after the LAST parenthesis - a command with blanks and parentheses): the tree of 200 is 201,203,202 from ps and 201,202 from /proc; the other process and junk lines are left out' ($pairs.Count -eq 6 -and $treePs -eq '201,203,202' -and $pairs2.Count -eq 4 -and $treeProc -eq '201,202') "ps [$treePs] proc [$treeProc]"
    # a real tree: its descendants and their start times; the confirmed kill
    $treePs1 = Join-Path $work 'tree.ps1'
    [IO.File]::WriteAllText($treePs1, "`$c = Start-Process -FilePath `$args[0] -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 60' -PassThru -WindowStyle Hidden`n[IO.File]::WriteAllText(`$args[1], [string]`$c.Id)`nStart-Sleep 60`n", $u8)
    $pidFile = Join-Path $work 'tree-child.pid'
    # (Start-Process joins its arguments with blanks: a path with a blank - pwsh under Program Files - is quoted)
    $root = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$treePs1`"", "`"$psExe`"", "`"$pidFile`"" -PassThru -WindowStyle Hidden
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $root.Handle } catch { } }
    $wt = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath $pidFile) -and $wt.Elapsed.TotalSeconds -lt 30) { Start-Sleep -Milliseconds 200 }
    $childId = 0; [void][int]::TryParse((Text $pidFile).Trim(), [ref]$childId)
    $tree = Get-DescendantTree -RootId $root.Id
    $childStart = [string](Get-ProcessStartIso -ProcessId $childId)
    $startOk = ($childId -gt 0 -and $tree.Pids -contains $childId -and [string]$tree.Starts[[int]$childId] -eq $childStart)
    $recycled = Test-PidAlive -ProcessId $childId -StartTime '2000-01-01T00:00:00.0000000Z'
    $live = Test-PidAlive -ProcessId $childId -StartTime $childStart
    $kill = Stop-ProcessTreeChecked -Process $root
    $childGone = -not (Get-Process -Id $childId -ErrorAction SilentlyContinue)
    Check 'KILL' 'D14 (F37-2) the enumeration records each descendant''s START TIME (Get-DescendantTree Starts, via cim here); the liveness probe compares it - the same pid with another start time (a recycled pid) is NOT alive, with its own it is; the real tree''s kill is confirmed (no survivor, the child gone)' ($startOk -and $tree.Via -eq 'cim' -and -not $recycled -and $live -and $kill.Confirmed -and @($kill.Survivors).Count -eq 0 -and $childGone) "child $childId start ok $startOk via $($tree.Via) recycled $recycled live $live confirmed $($kill.Confirmed) survivors $(@($kill.Survivors) -join ',')"
    if (-not $childGone) { try { Stop-Process -Id $childId -Force -ErrorAction SilentlyContinue } catch { } }
}

# =============================================================== CONTEXT: the window reaches codex (D15)
if (Want 'CONTEXT') {
    $rosterCt = Write-Roster 'ctx' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","context_tokens":256000},{"provider":"ZAI","model":"glm-5.3","context_tokens":200000,"codex_config":["model_context_window=100000"]}]}'
    $r = New-Repo 'context'
    $log = Join-Path $work 'ctx-args.txt'
    $x = Consult $r $rosterCt @('-Provider', 'openai', '-Prompt', 'x', '-ReplyName', 'ct') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log }
    $e = @(Ledger $r)[-1]
    $args1 = Line (Text $log) 'ARGS:'
    Check 'CONTEXT' 'D15 a roster entry with context_tokens 256000 gives codex "-c model_context_window=256000" and "-c model_auto_compact_token_limit=204800" (0.8 n); the ledger records context_window {tokens 256000, auto_compact_limit 204800, items [both]}' ($x.Code -eq 0 -and $args1 -match '(^| )-c model_context_window=256000( |$)' -and $args1 -match '(^| )-c model_auto_compact_token_limit=204800( |$)' -and $e.context_window.tokens -eq 256000 -and $e.context_window.auto_compact_limit -eq 204800 -and (@($e.context_window.items) -join ',') -eq 'model_context_window=256000,model_auto_compact_token_limit=204800') "exit $($x.Code) | $args1 | $($e.context_window | ConvertTo-Json -Compress)"
    $log2 = Join-Path $work 'ctx-args2.txt'
    $x2 = Consult $r $rosterCt @('-Provider', 'ZAI', '-Prompt', 'x', '-ReplyName', 'ct2') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log2 }
    $e2 = @(Ledger $r)[-1]
    $args2 = Line (Text $log2) 'ARGS:'
    Check 'CONTEXT' 'D15 the operator''s own value wins: an entry whose codex_config sets model_context_window=100000 keeps it - only "-c model_auto_compact_token_limit=160000" is added; items lists that one' ($x2.Code -eq 0 -and $args2 -match 'model_context_window=100000' -and $args2 -notmatch 'model_context_window=200000' -and $args2 -match '(^| )-c model_auto_compact_token_limit=160000( |$)' -and (@($e2.context_window.items) -join ',') -eq 'model_auto_compact_token_limit=160000') "exit $($x2.Code) | $args2"
    $log3 = Join-Path $work 'ctx-args3.txt'
    $x3 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'ct3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log3 }
    $e3 = @(Ledger $r)[-1]
    Check 'CONTEXT' 'D15 without a roster context_tokens: no such -c option, ledger context_window null' ($x3.Code -eq 0 -and (Line (Text $log3) 'ARGS:') -notmatch 'model_context_window|model_auto_compact_token_limit' -and $null -eq $e3.context_window -and $e3.PSObject.Properties['context_window']) "exit $($x3.Code)"
}

# =============================================================== DAYS: local calendar days (D16)
if (Want 'DAYS') {
    $root = 'C:\h\sessions'
    $late = [datetime]::new(2026, 9, 29, 23, 59, 50, [DateTimeKind]::Local)
    $early = [datetime]::new(2026, 9, 30, 0, 0, 10, [DateTimeKind]::Local)
    $across = (Get-LocalDayDirs -Root $root -StartedAt $late -Now $early) -join ' | '
    $same = (Get-LocalDayDirs -Root $root -StartedAt $late.AddHours(-2) -Now $late) -join ' | '
    $utcLate = $late.ToUniversalTime()
    $viaUtc = (Get-LocalDayDirs -Root $root -StartedAt $utcLate -Now $early.ToUniversalTime()) -join ' | '
    Check 'DAYS' 'D16 a run ACROSS MIDNIGHT (started 23:59:50, looked at 00:00:10 local) looks in both day directories <root>\2026\09\29 and \30; the same day gives one; UTC instants are taken as their LOCAL days (as the engine names its session directories)' ($across -eq "$root\2026\09\29 | $root\2026\09\30" -and $same -eq "$root\2026\09\29" -and $viaUtc -eq $across) "across [$across] same [$same] utc [$viaUtc]"
    $savedCulture = [Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [Threading.Thread]::CurrentThread.CurrentCulture = New-Object Globalization.CultureInfo('th-TH')
        $thai = (Get-LocalDayDirs -Root $root -StartedAt $late -Now $late) -join ''
        $oldWay = '{0:yyyy}' -f $late
        $spoolThai = Get-TelemetrySpoolName -At $late
    } finally { [Threading.Thread]::CurrentThread.CurrentCulture = $savedCulture }
    Check 'DAYS' ('D16 invariant digits under a culture with another calendar (th-TH): <root>\2026\09\29 and the spool file 2026-09-29.ndjson - where a culture-bound format would say the year ' + $oldWay) ($thai -eq "$root\2026\09\29" -and $spoolThai -eq '2026-09-29.ndjson') "dirs [$thai] spool [$spoolThai] culture-bound year $oldWay"
}

# =============================================================== DOCS: the README
if (Want 'DOCS') {
    $readme = Text (Join-Path $repoRoot 'README.md')
    $miss = @(foreach ($k in @('test mode is ON: test hooks are honoured', 'CODEX_CONSULT_TEST_REGISTER_FAIL', 'CODEX_CONSULT_TEST_HEALTH_FAIL_FIRST', '<health file>.journal', 'a retry follows the commit', '2 x `-StallSec`', 'model_context_window', 'model_auto_compact_token_limit', 'context_window', 'guards only the start', 'the LOCAL date', 'ps -A -o pid=,ppid=', '/proc')) { if ($readme.IndexOf($k, [StringComparison]::Ordinal) -lt 0) { $k } })
    Check 'DOCS' 'README: the test-mode line and the new hooks (D10, D19), the health journal and "a retry follows the commit" (D13), the 2 x -StallSec bound (D12), the two codex keys and the ledger''s context_window, agy/muse "guards only the start" (D15), the local date (D16), the ps and /proc fallbacks (D14)' ($miss.Count -eq 0) "missing: $($miss -join ', ')"
    $tr = Text (Join-Path $sp 'README.md')
    $runAll = Text (Join-Path $sp 'run-all.ps1')
    Check 'DOCS' 'tests/README.md describes harness-fixes28b and run-all.ps1 registers it' ($tr.Contains('harness-fixes28b') -and $runAll -match "'harness-fixes28b'") ''
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
Write-Host ''
Write-Host ("harness-fixes28b ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
