# codex-consult non-blocking consultation (0.5.0 wave 25, ROADMAP R12; decisions D1-D12 of its design
# round): -Detach for a single run and a panel - the foreground returns at once while the members run,
# the refusals a real run makes before its lock are made in the foreground (a missing launcher, an
# active recovery record, the preflight, the brief) with nothing written; the background's status
# file (starting -> running -> done, the members' states, the summary block) and its UTF-8 log;
# -Status (exit 0 / 1 / 2, the worst state of several runs, an ambiguous -Id refused with exit 4),
# -Wait (the summary block verbatim, as a blocking run of the same fakes prints it; exit 3 on its
# timeout), -Status -Prune; a refusal AFTER the start (the task lock held) recorded as the final
# status; the background killed mid-panel -> "died" in -Status, codex-findings -List and the
# SessionStart hook, and the next run recovers as always; the budget (D4), the cwd rule (D8), the
# id8 collision (D7), an agy member of a detached panel not failing on the status file and the log
# (D1 / F02-7), a non-ASCII summary (D10), git check-ignore on the .gitignore pattern (D1); and
# ROADMAP T4 - the -ScriptsDir / CODEX_CONSULT_SCRIPTS_DIR override of the harnesses and run-all.
# FAKES ONLY: fake-codex3.cmd (CODEX_CONSULT_EXE, -CodexExe and a `codex` shim first on PATH) and
# fake-agy.cmd (CODEX_CONSULT_AGY_EXE); PATH holds no real codex, agy or muse launcher; CODEX_HOME
# and CODEX_CONSULT_ROSTER point at scratch files; the API key variables hold dummy test values.
# Runs under the host it is started with (powershell 5.1 or pwsh 7, Windows); the background of a
# detached run uses the same host. Work files: $env:TEMP\codex-consult-tests\harness-detach\<guid>,
# removed at the end (every background it started is gone by then).
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# (wave 25, T4) the scripts under test: -ScriptsDir, else CODEX_CONSULT_SCRIPTS_DIR, else this checkout's
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$findingsPs = Join-Path $scripts 'codex-findings.ps1'
$hookPs = Join-Path $scripts 'codex-consult-hook.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$fakeAgy = Join-Path $sp 'fake-agy.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-detach') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
$inv = [Globalization.CultureInfo]::InvariantCulture
$realConfig = Join-Path (Join-Path $HOME '.codex') 'config.toml'
$realConfigHash = ''
if (Test-Path -LiteralPath $realConfig -PathType Leaf) { $realConfigHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash }
# The process environment the cases change and the end restores (values are never printed).
$savedEnv = @{}
foreach ($k in @('CODEX_HOME', 'Path', 'RT_ZAI_KEY', 'RT_MIMO_KEY')) { $savedEnv[$k] = [Environment]::GetEnvironmentVariable($k) }
$script:fails = 0
$script:passes = 0
$cleanup = New-Object System.Collections.Generic.List[int]

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
    $null = G $r @('init', '-q'); $null = G $r @('config', 'user.email', 't@e.com'); $null = G $r @('config', 'user.name', 'T'); $null = G $r @('config', 'core.autocrlf', 'false')
    [IO.File]::WriteAllText((Join-Path $r 'app.txt'), "one`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'init')
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
# The scratch Codex config: the built-in openai (top-level model gpt-5.1) plus ZAI and mimo.
$toml = "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.mimo]`nbase_url = `"https://token-plan-ams.xiaomimimo.com/v1`"`nenv_key = `"RT_MIMO_KEY`"`nwire_api = `"responses`"`n"
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml, $u8)
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
# PATH without any real codex, agy or muse launcher, and a `codex` shim of the fake first (the hook
# looks for codex on PATH; nothing can reach a real CLI).
$launcherNames = @('codex', 'codex.exe', 'codex.cmd', 'codex.ps1', 'agy', 'agy.exe', 'agy.cmd', 'muse', 'muse.exe', 'muse.cmd')
$noCliPath = (@(([string]$savedEnv['Path']) -split ';' | Where-Object { $d = $_; $d -and -not (@($launcherNames | Where-Object { Test-Path -LiteralPath (Join-Path $d $_) }).Count -gt 0) })) -join ';'
$bin = Join-Path $work 'bin'
[void][IO.Directory]::CreateDirectory($bin)
[IO.File]::WriteAllText((Join-Path $bin 'codex.cmd'), "@echo off`r`nset ""FAKE_CODEX_ARGS=%*""`r`npowershell -NoProfile -ExecutionPolicy Bypass -File ""$(Join-Path $sp 'fake-codex3.ps1')""`r`nexit /b %ERRORLEVEL%`r`n")
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_PIDDIR', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_FAIL_ON', 'FAKE_CODEX_HANG_ON', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_REPLY_MAP', 'FAKE_AGY_REPLY', 'FAKE_AGY_WRITE', 'FAKE_AGY_DELAY_MS', 'FAKE_AGY_STATUS', 'FAKE_AGY_ERROR')
$testVars = @('RT_ZAI_KEY', 'RT_MIMO_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_AGY_EXE', 'CODEX_CONSULT_MUSE_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_PANEL_GUARD_SEC', 'CODEX_CONSULT_TEST_DETACH_GUIDS', 'CODEX_CONSULT_TEST_WRITE_LOCK_SEC', 'CODEX_CONSULT_SCRIPTS_DIR', 'T4_MARKER')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
}
# The fakes are the launchers; '' in $Env removes a variable. $Roster '' = CODEX_CONSULT_ROSTER=none.
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:RT_MIMO_KEY = 'mimo-test-key'
    $env:CODEX_CONSULT_EXE = $fake
    $env:CODEX_CONSULT_AGY_EXE = $fakeAgy
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    $env:Path = "$bin;$noCliPath"
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env {
    Clear-TestEnv
    foreach ($k in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($k, $savedEnv[$k]) }
}
# One bridge call (the environment is the case's; the background of a -Detach inherits it):
# { Code; Out; First; Refusal; Sec }
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{}, [string]$Cwd = '', [switch]$NoCodexExe, [string]$Script = '')
    Set-CaseEnv $Roster $Env
    Push-Location $(if ($Cwd) { $Cwd } else { $Repo })
    $all = @()
    if (-not $NoCodexExe) { $all += @('-CodexExe', $fake) }
    $target = $(if ($Script) { $Script } else { $consultPs })
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $target -Task t @all @ArgList 2>&1
    $code = $LASTEXITCODE
    $sec = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1); Refusal = [string](@(($text -split "`n") | Where-Object { $_ -match '^codex-consult: ' }) | Select-Object -First 1); Sec = $sec }
}
# -Status / -Wait (no -CodexExe: they take only -Task, -CollabDir, -Id, -Prune, -WaitTimeoutSec)
function Status {
    param([string]$Repo, [string[]]$ArgList = @())
    return (Consult $Repo '' (@('-Status') + $ArgList) @{} -NoCodexExe)
}
function WaitRun {
    param([string]$Repo, [string[]]$ArgList = @())
    return (Consult $Repo '' (@('-Wait') + $ArgList) @{} -NoCodexExe)
}
function Run-Tool {
    param([string]$Script, [string]$Repo, [string[]]$ArgList, [string]$Roster = '', [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $Script @ArgList 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $c = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return [pscustomobject]@{ Code = $c; Out = $o; First = (($o -split "`n") | Select-Object -First 1) }
}
function Reply { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Td { param([string]$Repo) return (Join-Path $Repo '.collab\t') }
function Records {
    param([string]$Repo)
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($p in (Get-PendingPaths -TaskDir (Td $Repo))) { $rd = Read-PendingFile -Path $p; $out.Add([pscustomobject]@{ Name = [IO.Path]::GetFileName($p); Path = $p; Record = $rd.Record }) }
    return , ($out.ToArray())
}
function Wait-For { param([scriptblock]$Cond, [int]$TimeoutSec = 60) $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) { if (& $Cond) { return $true }; Start-Sleep -Milliseconds 250 }; return [bool](& $Cond) }
function Dead-Pid { $d = Start-Process cmd.exe -ArgumentList '/c', 'exit' -PassThru -WindowStyle Hidden; $d.WaitForExit(); return $d.Id }
function Start-Sleeper { param([int]$Sec = 180) $s = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-Command', "Start-Sleep -Seconds $Sec") -PassThru -WindowStyle Hidden; $cleanup.Add($s.Id); return $s }
function Iso { param($Dto) return ([DateTimeOffset]$Dto).ToString('yyyy-MM-ddTHH:mm:sszzz', $inv) }
function To-Dto { param($V) if ($V -is [DateTimeOffset]) { return $V }; if ($V -is [datetime]) { return [DateTimeOffset]$V }; return [DateTimeOffset]::Parse([string]$V, $inv) }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
# The detached runs of the test task: the status files (Read-DetachedRuns), and one by id8.
# (Read-DetachedRuns hands back the array itself - never @()-wrapped; returned here, it unrolls)
function Runs { param([string]$Repo) $all = Read-DetachedRuns -TaskDir (Td $Repo); return $all }
function Run8 { param([string]$Repo, [string]$Id8) return (@(Runs $Repo | Where-Object { $_.Id8 -eq $Id8 }) | Select-Object -First 1) }
# The id8 a -Detach printed ("Detached <id8>: ...").
function Id8Of { param([string]$Out) if ($Out -match '(?m)^Detached ([0-9a-f]{8}): ') { return $Matches[1] }; return '' }
function Wait-Done {
    param([string]$Repo, [string]$Id8, [int]$TimeoutSec = 120)
    return (Wait-For { $r = Run8 $Repo $Id8; $r -and $r.Record -and $r.Record.state -eq 'done' } $TimeoutSec)
}
# Stops a detached background and everything under it (a harness never leaves one behind).
function Stop-Background {
    param([string]$Repo)
    foreach ($r in (Runs $Repo)) {
        if (-not $r.Record -or -not $r.Record.pid) { continue }
        $p = Get-Process -Id ([int]$r.Record.pid) -ErrorAction SilentlyContinue
        if ($p -and (Test-PidAlive -ProcessId $p.Id -StartTime ([string]$r.Record.start_time))) { $null = Stop-ProcessTree -Process $p }
    }
}
# The summary block of a panel run's output (the last "Panel xxxxxxxx: " line and after).
function PanelSummary {
    param([string]$Out)
    $m = [regex]::Matches($Out, '(?m)^Panel [0-9a-f]{8}: .*$')
    if ($m.Count -eq 0) { return @('') }
    return @(($Out.Substring($m[$m.Count - 1].Index).TrimEnd() -split "`n") | ForEach-Object { $_.TrimEnd("`r") })
}
# The summary block of a single run's output: from its outcome line to `events file:`.
function RunSummary {
    param([string]$Out)
    $lines = @(($Out -split "`n") | ForEach-Object { $_.TrimEnd("`r") })
    $s = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^codex-consult: (usable reply|failed)') { $s = $i } }
    if ($s -lt 0) { return @('') }
    $e = $s
    while ($e -lt $lines.Count -and -not $lines[$e].StartsWith('events file:')) { $e++ }
    return @($lines[$s..([Math]::Min($e, $lines.Count - 1))])
}
# Numbers, ids and the repository directory out of a summary, so two runs can be compared.
function Norm {
    param([string[]]$Lines, [string]$Repo)
    return @($Lines | ForEach-Object {
            $l = $_
            if ($Repo) { $l = $l.Replace($Repo, '<repo>') }
            $l = $l -replace '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', '<guid>'
            $l = $l -replace '^Panel [0-9a-f]{8}:', 'Panel <id8>:'
            # every duration: "12.3 s", and a wall that rounded to a whole second ("2 s")
            $l -replace '(?<![\w.])[0-9]+(\.[0-9]+)? s\b', '<t> s'
        })
}
function Hook {
    param([string]$Repo, [string]$Roster)
    Set-CaseEnv $Roster @{}
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $hookPs 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return $out
}
function New-Fabricated {
    param([string]$TaskDir, [string]$Id, [string]$State, $Exit = $null, [DateTimeOffset]$Started, $Finished = $null, $Pid_ = $null, [string]$StartTime = '', [string]$HostName = '', [string]$Summary = '', [object[]]$Members = @(), $Updated = $null)
    $p = Get-DetachedPaths -TaskDir $TaskDir -Id $Id
    $rec = ConvertTo-DetachedRecord @{
        id = $Id; id8 = $p.Id8; task = 't'; kind = 'run'; state = $State; exit = $Exit; started = (Iso $Started); finished = $(if ($Finished) { Iso $Finished } else { $null })
        pid = $Pid_; start_time = $StartTime; host = $(if ($HostName) { $HostName } else { [Environment]::MachineName }); budget_sec = 300; reply_name = 'fab'
        members = $Members; summary = $Summary; log = $p.Log
    }
    [void][IO.Directory]::CreateDirectory($TaskDir)
    Write-JsonFile -Path $p.Status -Object $rec
    if ($null -ne $Updated) {
        # an old last write: rewrite `updated` after Write-JsonFile (Write-DetachedStatus would set now)
        $rec.updated = Iso $Updated
        Write-JsonFile -Path $p.Status -Object $rec
    }
    [IO.File]::WriteAllText($p.Log, "log of $Id`n", $u8)
    return $p
}

$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
$finding = '{"severity":"minor","locations":[{"path":"app.txt","line":1}],"claim":"c","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}'
$adviseF = Reply 'advise-finding.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$roster3 = Write-Roster 'three' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
$roster2 = Write-Roster 'two' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
$rosterZai2 = Write-Roster 'zai2' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"ZAI","model":"glm-5.3-flash"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
$rosterMixed = Write-Roster 'mixed' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"gemini","engine":"agy","model":"gemini-3.8-flash-high"}]}'
$repos = New-Object System.Collections.Generic.List[string]

try {
# =============================================================== UNIT: judgement, budget, records, args, list line, hook phrase, snapshot
if (Want 'UNIT') {
    $now = [DateTimeOffset]::Now
    $me = [string](Get-ProcessStartIso -ProcessId $PID)
    function Rc { param([hashtable]$F) $base = @{ id = 'aaaaaaaa-0000-4000-8000-000000000001'; state = 'running'; started = (Iso $now.AddMinutes(-5)); members = @() }; foreach ($k in $F.Keys) { $base[$k] = $F[$k] }; return (ConvertTo-DetachedRecord $base) }
    $j1 = Get-DetachedJudgement -Record (Rc @{ state = 'done'; exit = 0 }) -Now $now
    $j2 = Get-DetachedJudgement -Record (Rc @{ state = 'done'; exit = 1 }) -Now $now
    $j3 = Get-DetachedJudgement -Record (Rc @{ pid = $PID; start_time = $me; host = [Environment]::MachineName; members = @((New-DetachedMember -Position 1 -Lineage 'a' -State 'usable'), (New-DetachedMember -Position 2 -Lineage 'b' -State 'running'), (New-DetachedMember -Position 3 -Lineage 'c' -State 'skipped' -Outcome 'missing: env X not set')) }) -Now $now
    $j4 = Get-DetachedJudgement -Record (Rc @{ pid = $PID; start_time = '2001-01-01T00:00:00.0000000Z'; host = [Environment]::MachineName }) -Now $now
    $j5 = Get-DetachedJudgement -Record (Rc @{ pid = (Dead-Pid); host = [Environment]::MachineName }) -Now $now
    $j6 = Get-DetachedJudgement -Record (Rc @{ state = 'starting'; started = (Iso $now.AddSeconds(-10)) }) -Now $now
    $j7 = Get-DetachedJudgement -Record (Rc @{ state = 'starting'; started = (Iso $now.AddMinutes(-2)) }) -Now $now
    $j8 = Get-DetachedJudgement -Record (Rc @{ pid = (Dead-Pid); host = 'OTHER-HOST-7' }) -Now $now
    $j9 = Get-DetachedJudgement -Record $null -Problem 'the status file x cannot be used: it does not parse' -Now $now
    Check 'UNIT' 'Get-DetachedJudgement (D5, D6, D11): done exit 0 -> 0, exit 1 -> 1; a live background (pid + start time) -> running 2 "1 of 2 members finished" (a roster-skipped entry is not counted); the pid with another start time or a dead pid -> died 1; starting without a pid 10 s ago -> starting 2, 2 min ago -> never-started 1; another host -> elsewhere 2, never judged (a dead pid there is not "died"); an unreadable file -> 1' ($j1.State -eq 'done' -and $j1.Exit -eq 0 -and $j2.Exit -eq 1 -and $j3.State -eq 'running' -and $j3.Exit -eq 2 -and $j3.Text -match '1 of 2 members finished$' -and $j4.State -eq 'died' -and $j4.Exit -eq 1 -and $j5.State -eq 'died' -and $j6.State -eq 'starting' -and $j6.Exit -eq 2 -and $j7.State -eq 'never-started' -and $j7.Exit -eq 1 -and $j8.State -eq 'elsewhere' -and $j8.Exit -eq 2 -and $j8.Text -match 'cannot be checked from this host' -and $j9.State -eq 'unreadable' -and $j9.Exit -eq 1) "$($j3.Text) | $($j4.Text) | $($j7.Text) | $($j8.Text)"

    $g100 = @{ 1 = 100; 2 = 100; 3 = 100 }
    $b1 = Get-DetachedBudget -Groups @([pscustomobject]@{ Limit = 1; Positions = @(1) }, [pscustomobject]@{ Limit = 1; Positions = @(2) }, [pscustomobject]@{ Limit = 1; Positions = @(3) }) -GuardOf $g100
    $b2 = Get-DetachedBudget -Groups @([pscustomobject]@{ Limit = 1; Positions = @(1, 2) }, [pscustomobject]@{ Limit = 1; Positions = @(3) }) -GuardOf $g100
    $b3 = Get-DetachedBudget -Groups @([pscustomobject]@{ Limit = 2; Positions = @(1, 2) }, [pscustomobject]@{ Limit = 1; Positions = @(3) }) -GuardOf $g100
    $b4 = Get-DetachedBudget -Groups @([pscustomobject]@{ Limit = 1; Positions = @(1) }, [pscustomobject]@{ Limit = 1; Positions = @(2) }, [pscustomobject]@{ Limit = 1; Positions = @(3) }) -GuardOf $g100 -Cap 1
    $b5 = Get-DetachedBudget -Groups @([pscustomobject]@{ Limit = 1; Positions = @(1, 2) }, [pscustomobject]@{ Limit = 1; Positions = @(3) }) -GuardOf @{ 1 = 100; 2 = 250; 3 = 400 }
    $b6 = Get-DetachedBudget -Groups @([pscustomobject]@{ Limit = 1; Positions = @(1) }) -GuardOf @{ 1 = (Get-PanelMemberGuard -TimeoutSec 900 -ContinueSec 900 -Repair) }
    Check 'UNIT' 'Get-DetachedBudget (D4): three endpoints at once -> guard + 120 (220); two members of one endpoint one after another -> 2 x guard + 120 (320); that group with "parallel" 2 -> 220; -PanelConcurrency 1 over three -> 3 x guard + 120 (420); per group the longest guard (2 x 250 = 500 beats 400) -> 620; a single run = one group of one (checkpoint-less defaults: 900 + 60 + 120 + 300 + 900 = 2280 -> 2400)' ($b1 -eq 220 -and $b2 -eq 320 -and $b3 -eq 220 -and $b4 -eq 420 -and $b5 -eq 620 -and $b6 -eq 2400) "$b1 $b2 $b3 $b4 $b5 $b6"

    $pp = Get-DetachedPaths -TaskDir 'C:\x\t' -Id 'ABCDEF12-3456-4000-8000-000000000000'
    $argsIn = @{ Task = 't'; Prompt = '2026-09-26T10:00:00'; Raw = [System.Management.Automation.SwitchParameter]::new($true); Artifact = [string[]]@('C:\a b\x.bin', 'y"z'); TimeoutSec = 3600; Brief = 'C:\p\b.md' }
    $argsOut = ConvertFrom-DetachArgs -Text (ConvertTo-DetachArgs -Arguments $argsIn)
    Check 'UNIT' 'Get-DetachedPaths: <task>/.consult.detached-<id8>.status.json and .log, id8 lowercase; ConvertTo-DetachArgs / ConvertFrom-DetachArgs round-trip the background''s parameters exactly - a -Prompt that looks like a date stays a string, a switch a bool, -Artifact a string array (a space and a quote kept), an int an int' ($pp.Id8 -eq 'abcdef12' -and $pp.Status -eq 'C:\x\t\.consult.detached-abcdef12.status.json' -and $pp.Log -eq 'C:\x\t\.consult.detached-abcdef12.log' -and $argsOut['Prompt'] -is [string] -and $argsOut['Prompt'] -eq '2026-09-26T10:00:00' -and $argsOut['Raw'] -is [bool] -and $argsOut['Raw'] -and $argsOut['Artifact'] -is [array] -and ($argsOut['Artifact'] -join '|') -eq 'C:\a b\x.bin|y"z' -and $argsOut['TimeoutSec'] -eq 3600 -and $argsOut['Brief'] -eq 'C:\p\b.md') "$($argsOut['Prompt'].GetType().Name) $(($argsOut['Artifact']) -join '|')"

    $cr = Rc @{ members = @((New-DetachedMember -Position 1 -Lineage 'a' -State 'usable' -Outcome 'usable reply'), (New-DetachedMember -Position 2 -Lineage 'b' -State 'pending'), (New-DetachedMember -Position 3 -Lineage 'c' -State 'running')) }
    Complete-DetachedRecord -Record $cr -Exit 1 -Line "codex-consult: another consultation or status update for task 't' is running: x"
    $cr2 = Rc @{ summary = 'Panel 1234abcd: 2 of 2 entries ran' }
    Complete-DetachedRecord -Record $cr2 -Exit 0 -Line 'codex-consult: ignored'
    Check 'UNIT' 'Complete-DetachedRecord (D3): done, the exit code, finished and wall_seconds set; no summary yet -> the error line; a pending member -> skipped "not started: <the line without the prefix>", a running one -> failed "stopped: the run ended (exit 1) ..."; a summary already there is kept over the line' ($cr.state -eq 'done' -and $cr.exit -eq 1 -and $cr.finished -and $null -ne $cr.wall_seconds -and $cr.summary -match '^codex-consult: another consultation' -and $cr.members[0].state -eq 'usable' -and $cr.members[1].state -eq 'skipped' -and $cr.members[1].outcome -eq "not started: another consultation or status update for task 't' is running: x" -and $cr.members[2].state -eq 'failed' -and $cr.members[2].outcome -match '^stopped: the run ended \(exit 1\)' -and $cr2.summary -eq 'Panel 1234abcd: 2 of 2 entries ran' -and $cr2.exit -eq 0) "$($cr.members[1].outcome) | $($cr.members[2].outcome)"

    # the list line and the hook phrase over fabricated status files
    $ucol = Join-Path $work 'unit-collab'
    $sleeper = Start-Sleeper 120
    Start-Sleep -Milliseconds 500
    $sStart = [string](Get-ProcessStartIso -ProcessId $sleeper.Id)
    $null = New-Fabricated -TaskDir (Join-Path $ucol 'ta') -Id 'a1a1a1a1-0000-4000-8000-000000000001' -State 'running' -Started $now.AddMinutes(-3) -Pid_ $sleeper.Id -StartTime $sStart -Members @((New-DetachedMember -Position 1 -Lineage 'x' -State 'usable'), (New-DetachedMember -Position 2 -Lineage 'y' -State 'running'))
    $null = New-Fabricated -TaskDir (Join-Path $ucol 'tb') -Id 'b2b2b2b2-0000-4000-8000-000000000002' -State 'done' -Exit 0 -Started $now.AddHours(-2) -Finished $now.AddHours(-1)
    $null = New-Fabricated -TaskDir (Join-Path $ucol 'tb') -Id 'c3c3c3c3-0000-4000-8000-000000000003' -State 'done' -Exit 0 -Started $now.AddDays(-3) -Finished $now.AddDays(-3)
    $null = New-Fabricated -TaskDir (Join-Path $ucol 'tc') -Id 'd4d4d4d4-0000-4000-8000-000000000004' -State 'running' -Started $now.AddMinutes(-9) -Pid_ (Dead-Pid) -StartTime '2001-01-01T00:00:00.0000000Z'
    $ph = Get-DetachedPhrase -CollabRoot $ucol -Now $now
    $runsA = Read-DetachedRuns -TaskDir (Join-Path $ucol 'ta')
    $la = Format-DetachedListLine -Run $runsA[0] -Task 'ta' -Now $now
    $runsB = Read-DetachedRuns -TaskDir (Join-Path $ucol 'tb')
    $lb = @($runsB | ForEach-Object { Format-DetachedListLine -Run $_ -Task 'tb' -Now $now }) -join ''
    $runsC = Read-DetachedRuns -TaskDir (Join-Path $ucol 'tc')
    $lc = Format-DetachedListLine -Run $runsC[0] -Task 'tc' -Now $now
    Stop-Process -Id $sleeper.Id -Force -ErrorAction SilentlyContinue
    $only1 = Get-DetachedPhrase -CollabRoot (Join-Path $ucol 'tb') -Now $now
    $ph1 = Get-DetachedPhrase -CollabRoot $ucol -Now $now.AddHours(30)
    Check 'UNIT' 'Get-DetachedPhrase (the hook, D6): one phrase over every task - "; detached consultations: 1 running (task ta), 1 finished (task tb), 1 died (task tc)" (the run finished 3 days ago is not counted; a dead background reads died); one category alone -> "; 1 detached consultation died (task tc)"; nothing to say -> ""' ($ph -eq '; detached consultations: 1 running (task ta), 1 finished (task tb), 1 died (task tc)' -and $ph1 -eq '; 2 detached consultations died (tasks ta, tc)' -and $only1 -eq '') "'$ph' | '$ph1'"
    Check 'UNIT' 'Format-DetachedListLine (-List, D6): a running run -> "detached a1a1a1a1: running since <t> (3 min), 1 of 2 members finished (codex-consult.ps1 -Task ta -Status -Id a1a1a1a1)"; a done run -> no line; a dead background -> "detached d4d4d4d4: died - its background process (pid N) is gone ..."' ($la -match '^detached a1a1a1a1: running since \S+ \(3 min\), 1 of 2 members finished \(codex-consult\.ps1 -Task ta -Status -Id a1a1a1a1\)$' -and $lb -eq '' -and $lc -match '^detached d4d4d4d4: died - its background process \(pid [0-9]+\) is gone without a final status') "$la | $lc"

    $snapDir = Join-Path $work 'snap'
    [void][IO.Directory]::CreateDirectory((Join-Path $snapDir 't'))
    [IO.File]::WriteAllText((Join-Path $snapDir 't\state.md'), "x`n", $u8)
    $before = Get-CollabSnapshot -Dir $snapDir
    foreach ($n in @('.consult.detached-abcd1234.status.json', '.consult.detached-abcd1234.log', '..consult.detached-abcd1234.status.json.0123abcd.tmp')) { [IO.File]::WriteAllText((Join-Path $snapDir "t\$n"), "changed`n", $u8) }
    $diff = Compare-DirectorySnapshot -Before $before -After (Get-CollabSnapshot -Dir $snapDir)
    Check 'UNIT' 'Get-CollabSnapshot (F02-7, D9): a detached run''s status file, its log and the atomic-write temp of the status file never enter an agy/muse member''s collab snapshot (the .consult. prefix rule) - no change reported' (@($diff).Count -eq 0) (@($diff) -join ',')
}

# =============================================================== IGNORE: .gitignore (D1)
if (Want 'IGNORE') {
    $gi1 = G $repoRoot @('check-ignore', '-v', '--no-index', '.collab/t/.consult.detached-abc12345.status.json')
    $c1 = $LASTEXITCODE
    $gi2 = G $repoRoot @('check-ignore', '-v', '--no-index', '.collab/some-task/.consult.detached-abc12345.log')
    $c2 = $LASTEXITCODE
    $gi3 = G $repoRoot @('check-ignore', '--no-index', '.collab/t/sessions.json')
    $c3 = $LASTEXITCODE
    Check 'IGNORE' 'D1: git check-ignore on this checkout - a detached run''s status file and log under .collab/<task>/ are ignored by the pattern .consult.detached-* (exit 0), sessions.json still is not (exit 1)' ($c1 -eq 0 -and "$gi1" -match '\.consult\.detached-\*' -and $c2 -eq 0 -and $c3 -eq 1) "$gi1 | $gi2 | exit $c3"
}

# =============================================================== REFUSE: refused in the foreground, nothing written (D2, D8)
if (Want 'REFUSE') {
    $r = New-Repo 'refuse'
    $repos.Add($r)
    $snap = { (@(Get-ChildItem -LiteralPath (Join-Path $r '.collab') -Recurse -Force | ForEach-Object { "$($_.FullName)|$($_.Length)" }) | Sort-Object) -join ';' }
    $s0 = & $snap
    $a1 = Consult $r '' @('-Detach', '-DryRun', '-Prompt', 'x')
    $a2 = Consult $r '' @('-Detach', '-Status')
    $a3 = Consult $r '' @('-Detach', '-Wait')
    $a4 = Consult $r '' @('-Detach', '-PanelSpec', 'eyJ4IjoxfQ==')
    $a5 = Consult $r '' @('-DetachId', 'aaaaaaaa-0000-4000-8000-000000000001', '-Prompt', 'x')
    $a6 = Consult $r '' @('-Prompt', 'x', '-Id', 'abcd')
    Check 'REFUSE' 'D8: -Detach with -DryRun (exit 1), with -Status or -Wait (exit 4, the query refused), with -PanelSpec (exit 1); -DetachId by hand -> "internal to -Detach" (no status file); -Id without -Status/-Wait -> refused' ($a1.Code -eq 1 -and $a1.First -eq 'codex-consult: -Detach does not go with -DryRun: a dry run starts nothing to detach - run -DryRun alone first.' -and $a2.Code -eq 4 -and $a2.First -match '^codex-consult: -Detach does not go with -Status or -Wait' -and $a3.Code -eq 4 -and $a4.Code -eq 1 -and $a4.First -eq 'codex-consult: -Detach does not go with -PanelSpec (internal to -Panel).' -and $a5.Code -eq 1 -and $a5.First -match '^codex-consult: -DetachId is internal to -Detach: there is no status file ' -and $a6.Code -eq 1 -and $a6.First -match '^codex-consult: -Id and -Prune go with -Status') "$($a1.First) | $($a2.First) | $($a5.First) | $($a6.First)"
    $b1 = Consult $r '' @('-Detach', '-Brief', 'missing-brief.md', '-Prompt', 'x')
    $b2 = Consult $r $roster3 @('-Detach', '-Panel', '-Brief', 'missing-brief.md', '-Prompt', 'x')
    Check 'REFUSE' 'a missing brief is refused in the foreground (single run and panel; exit 1, "brief ... not found"), nothing written, no status file' ($b1.Code -eq 1 -and $b1.First -match "^codex-consult: brief 'missing-brief\.md' not found" -and $b2.Code -eq 1 -and $b2.First -match "^codex-consult: brief 'missing-brief\.md' not found" -and (& $snap) -eq $s0) "$($b1.First) | $($b2.First)"
    $pf = Consult $r '' @('-Detach', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-Prompt', 'x') @{ RT_MIMO_KEY = '' }
    $pfd = Consult $r '' @('-DryRun', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-Prompt', 'x') @{ RT_MIMO_KEY = '' }
    $pn = Consult $r $roster2 @('-Detach', '-Panel', '-Prompt', 'x') @{ RT_MIMO_KEY = ''; FAKE_CODEX_LOGIN = 'out' }
    Check 'REFUSE' 'D2: an unavailable reviewer - the preflight a dry run only reports (exit 0) refuses -Detach in the foreground (exit 1, its refusal line); a panel with no available member is refused too; no status file' ($pfd.Code -eq 0 -and $pf.Code -eq 1 -and $pf.Refusal -match 'RT_MIMO_KEY' -and $pn.Code -eq 1 -and @(Runs $r).Count -eq 0 -and (& $snap) -eq $s0) "$($pf.Refusal) | $($pn.Refusal)"
    $lm = Consult $r '' @('-Detach', '-SkipPreflight', '-Prompt', 'x') @{ CODEX_CONSULT_EXE = ''; Path = $noCliPath } -NoCodexExe
    $lmd = Consult $r '' @('-DryRun', '-SkipPreflight', '-Prompt', 'x') @{ CODEX_CONSULT_EXE = ''; Path = $noCliPath } -NoCodexExe
    $lmp = Consult $r $roster2 @('-Detach', '-Panel', '-SkipPreflight', '-Prompt', 'x') @{ CODEX_CONSULT_EXE = ''; Path = $noCliPath } -NoCodexExe
    Check 'REFUSE' 'D2: no codex launcher (no -CodexExe, no CODEX_CONSULT_EXE, none on PATH) - the dry run reports "(codex not found on PATH)" and exits 0; -Detach is refused in the foreground as a real run is ("codex CLI not found on PATH"; single run and panel), nothing started' ($lmd.Code -eq 0 -and $lmd.Out -match 'launcher    : \(codex not found on PATH\)' -and $lm.Code -eq 1 -and $lm.First -eq 'codex-consult: codex CLI not found on PATH (set -CodexExe <path> or the CODEX_CONSULT_EXE environment variable).' -and $lmp.Code -eq 1 -and $lmp.First -eq $lm.First -and @(Runs $r).Count -eq 0) "$($lm.First) | $($lmp.First)"
    # an active recovery record: its writer (a live process with its start time) still runs
    $sl = Start-Sleeper 120
    Start-Sleep -Milliseconds 500
    $rec = New-PendingRecord -State 'reserved' -N 4 -Nn '04' -Reply 'handoffs/04-codex-x.md' -Started (Get-IsoTimestamp)
    $rec.pid = $sl.Id
    $rec.start_time = [string](Get-ProcessStartIso -ProcessId $sl.Id)
    Write-PendingFile -Path (Join-Path (Td $r) '.consult.pending.json') -Record $rec
    $ar = Consult $r '' @('-Detach', '-Prompt', 'x')
    $ard = Consult $r '' @('-DryRun', '-Prompt', 'x')
    $arp = Consult $r $roster2 @('-Detach', '-Panel', '-Prompt', 'x')
    Stop-Process -Id $sl.Id -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path (Td $r) '.consult.pending.json') -Force
    Check 'REFUSE' 'D2: an ACTIVE recovery record (its writer lives) - the dry run reports "the next run would be REFUSED" (exit 0); -Detach is refused in the foreground (exit 1, "a consultation of this task is still running"), single run and panel; no status file, no background' ($ard.Code -eq 0 -and $ard.Out -match 'the next run would be REFUSED' -and $ar.Code -eq 1 -and $ar.Refusal -match "a consultation of this task is still running: its bridge \(pid $($sl.Id)\)" -and $arp.Code -eq 1 -and $arp.Refusal -match 'still running' -and @(Runs $r).Count -eq 0) "$($ar.Refusal) | $($arp.Refusal)"
    $ro = Consult $r (Join-Path $work 'no-such-roster.json') @('-Detach', '-Prompt', 'x')
    Check 'REFUSE' 'an unusable roster (CODEX_CONSULT_ROSTER names a missing file) refuses -Detach like every run; nothing written' ($ro.Code -eq 1 -and $ro.First -match 'no-such-roster\.json' -and (& $snap) -eq $s0) $ro.First
}

# =============================================================== SINGLE: a detached single run, -Status, -List, the hook, -Wait (D1-D5)
if (Want 'SINGLE') {
    $r = New-Repo 'single'
    $repos.Add($r)
    $f = Consult $r '' @('-Detach', '-Prompt', 'x', '-ReplyName', 'sd') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_DELAY_MS = '12000' }
    $id8 = Id8Of $f.Out
    $run = Run8 $r $id8
    $st0 = $(if ($run -and $run.Record) { $run.Record.state } else { '' })
    $outLines = @($f.Out -split "`n")
    Check 'SINGLE' 'the foreground returns at once (well before the reviewer''s 12 s; exit 0) printing three lines - "Detached <id8>: a single run of openai :: gpt-5.1 (...) - it runs in the background (detach id <guid>; budget 2400 s).", the status file and the log, the come-back commands (-Status -Id <id8> / -Wait -Id <id8>)' ($f.Code -eq 0 -and $f.Sec -lt 10 -and $outLines.Count -eq 3 -and $outLines[0] -match "^Detached $id8`: a single run of openai :: gpt-5\.1 \(purpose none, timeout 900 s\) - it runs in the background \(detach id $id8-[0-9a-f-]{27}; budget 2400 s\)\.$" -and $outLines[1] -match "^status file: .*\\\.collab\\t\\\.consult\.detached-$id8\.status\.json \(console output: .*\\\.consult\.detached-$id8\.log\)$" -and $outLines[2] -match "^come back  : codex-consult\.ps1 -Task t -Status -Id $id8 .* -Wait -Id $id8 ") "$($f.Sec) s; $($outLines[0])"
    Check 'SINGLE' 'the status file right after: not done (starting or running), kind run, budget_sec 2400 (D4: the member guard 2280 + 120), one member pending/running with the lineage; the `args` of the starting record are gone once the background reported (D5)' ($run -and $run.Record -and @('starting', 'running') -contains $st0 -and $run.Record.kind -eq 'run' -and $run.Record.budget_sec -eq 2400 -and @($run.Record.members).Count -eq 1 -and $run.Record.members[0].lineage -eq 'openai :: gpt-5.1') "state $st0"
    $running = Wait-For { $x = Run8 $r $id8; $x -and $x.Record.state -eq 'running' -and $x.Record.members[0].state -eq 'running' } 60
    $x = Run8 $r $id8
    $s1 = Status $r
    $s1i = Status $r @('-Id', $id8)
    $l1 = Run-Tool $findingsPs $r @('-Task', 't', '-List')
    $h1 = Hook $r ''
    Check 'SINGLE' 'D5: the background''s self-report - state running, its own pid and start time (alive), this host, no args; the member running with n=1, handoff 01 (numbers taken under the lock)' ($running -and [int]$x.Record.pid -gt 0 -and (Test-PidAlive -ProcessId ([int]$x.Record.pid) -StartTime ([string]$x.Record.start_time)) -and $x.Record.host -eq [Environment]::MachineName -and -not $x.Record.args -and $x.Record.members[0].n -eq 1 -and $x.Record.members[0].handoff -eq '01') "pid $($x.Record.pid)"
    Check 'SINGLE' '-Status while it runs: exit 2, "detached <id8> (single run, reply name sd): running since <t> (<s>), 0 of 1 members finished", the member line "#1 openai :: gpt-5.1 - running (n=1, handoff 01)", the log path; -Id <id8> the same' ($s1.Code -eq 2 -and $s1.First -match "^detached $id8 \(single run, reply name sd\): running since \S+ \([0-9]+ s\), 0 of 1 members finished$" -and $s1.Out -match '(?m)^  #1 openai :: gpt-5\.1 - running \(n=1, handoff 01\)$' -and $s1.Out -match "(?m)^  log: .*\.consult\.detached-$id8\.log$" -and $s1i.Code -eq 2 -and $s1i.First -match "^detached $id8 \(single run, reply name sd\): running since ") $s1.First
    Check 'SINGLE' 'codex-findings -List shows the running detached run ("detached <id8>: running since ..., 0 of 1 members finished (codex-consult.ps1 -Task t -Status -Id <id8>)"); the SessionStart hook line ends "; 1 detached consultation running (task t)"' ($l1.Code -eq 0 -and $l1.Out -match "(?m)^detached $id8`: running since \S+ \([0-9]+ s\), 0 of 1 members finished \(codex-consult\.ps1 -Task t -Status -Id $id8\)$" -and $h1 -match '; 1 detached consultation running \(task t\)$') "$(Line $l1.Out 'detached') | $h1"
    $w = WaitRun $r @('-Id', $id8)
    $done = Run8 $r $id8
    $log = Read-SharedText -Path $done.Log
    $sum = @(([string]$done.Record.summary) -split "`n")
    $wLines = @($w.Out -split "`n" | ForEach-Object { $_.TrimEnd("`r") })
    $wTail = @($wLines | Select-Object -Last $sum.Count)
    $logLines = @($log -split "`r?`n")
    $li = [Array]::IndexOf($logLines, $sum[0])
    $logBlock = $(if ($li -ge 0) { @($logLines[$li..($li + $sum.Count - 1)]) } else { @() })
    Check 'SINGLE' '-Wait: waits ("codex-consult: waiting for 1 detached run of task ''t'' (<id8>) - up to 2400 s (the budget of the run), checking every 2 s"), exit 0, "done, exit 0", the member "usable: usable reply (n=1, handoff 01, <t> s)", then the summary block VERBATIM - the same lines the background printed to its log' ($w.Code -eq 0 -and $w.First -eq "codex-consult: waiting for 1 detached run of task 't' ($id8) - up to 2400 s (the budget of the run), checking every 2 s" -and $w.Out -match "(?m)^detached $id8 \(single run, reply name sd\): done, exit 0$" -and $w.Out -match '(?m)^  #1 openai :: gpt-5\.1 - usable: usable reply \(n=1, handoff 01, [0-9.]+ s\)$' -and $sum.Count -ge 5 -and ($wTail -join "`n") -eq ($sum -join "`n") -and ($logBlock -join "`n") -eq ($sum -join "`n")) "$($sum.Count) summary lines; first: $($sum[0])"
    $led = @(Ledger $r)
    Check 'SINGLE' 'the background was an ordinary run: one ledger entry (n=1, usable reply, handoffs/01-codex-sd.md), finding F01-1, no recovery record left, the task lock free; the status file done, exit 0, wall_seconds, finished, the member usable with its wall' ($led.Count -eq 1 -and $led[0].bridge_outcome -eq 'usable reply' -and $led[0].reply -eq 'handoffs/01-codex-sd.md' -and (Records $r).Count -eq 0 -and $done.Record.state -eq 'done' -and $done.Record.exit -eq 0 -and $null -ne $done.Record.wall_seconds -and $done.Record.finished -and $done.Record.members[0].state -eq 'usable' -and $null -ne $done.Record.members[0].wall_seconds) "wall $($done.Record.wall_seconds) s"
    # the same fakes, blocking, in a fresh repository: the same summary block (numbers, ids, paths aside)
    $rb = New-Repo 'single-blocking'
    $bl = Consult $rb '' @('-Prompt', 'x', '-ReplyName', 'sd') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_DELAY_MS = '1000' }
    $nb = Norm (RunSummary $bl.Out) $rb
    $nd = Norm $sum $r
    Check 'SINGLE' 'a blocking run of the same fakes prints the same summary block (thread id, wall and repository path normalised): -Wait returns what the blocking call would have' ($bl.Code -eq 0 -and $nb.Count -eq $nd.Count -and ($nb -join "`n") -eq ($nd -join "`n")) "$($nb[0]) || $($nd[0])"
    $l2 = Run-Tool $findingsPs $r @('-Task', 't', '-List')
    $h2 = Hook $r ''
    $s2 = Status $r
    Check 'SINGLE' 'once done: -Status exit 0 with the summary block; -List prints no detached line; the hook says "; 1 detached consultation finished (task t)"' ($s2.Code -eq 0 -and $s2.Out -match "(?m)^detached $id8 \(single run, reply name sd\): done, exit 0$" -and -not ($l2.Out -match '(?m)^detached ') -and $h2 -match '; 1 detached consultation finished \(task t\)$') $h2
}

# =============================================================== PANEL: a detached panel, member states, -Wait = the blocking summary (D4, D11)
if (Want 'PANEL') {
    $r = New-Repo 'panel'
    $repos.Add($r)
    $f = Consult $r $roster3 @('-Detach', '-Panel', '-Prompt', 'x', '-ReplyName', 'pd') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_DELAY_MS = 'gpt-5.1=14000|glm-5.3=4000|mimo-v2.6-pro=4000'; CODEX_CONSULT_TEST_PANEL_GUARD_SEC = '200' }
    $id8 = Id8Of $f.Out
    $run0 = Run8 $r $id8
    Check 'PANEL' 'the foreground of a panel returns at once (exit 0): "Detached <id8>: a review panel of 3 of 3 roster entries, at once (...)", budget_sec 320 (D4: three endpoints at once, the test guard 200 + 120), three members pending with their lineage in roster order' ($f.Code -eq 0 -and $f.Sec -lt 10 -and $f.First -match "^Detached $id8`: a review panel of 3 of 3 roster entries, at once \(purpose none, timeout 900 s per member\) - it runs in the background \(detach id .*; budget 320 s\)\.$" -and $run0.Record.kind -eq 'panel' -and $run0.Record.budget_sec -eq 320 -and (@($run0.Record.members | ForEach-Object { "$($_.position):$($_.lineage)" }) -join ',') -eq '1:openai :: gpt-5.1,2:ZAI :: glm-5.3,3:mimo :: mimo-v2.6-pro') "$($f.Sec) s; $($f.First)"
    $mid = Wait-For { $x = Run8 $r $id8; $x -and @($x.Record.members | Where-Object { $_.state -eq 'usable' }).Count -eq 2 -and $x.Record.members[0].state -eq 'running' } 90
    $s1 = Status $r @('-Id', $id8)
    Check 'PANEL' 'D11 while the slowest member runs: -Status exit 2, "running since ..., 2 of 3 members finished", openai running, ZAI and mimo usable with n, handoff and wall (in roster order, whatever finished first)' ($mid -and $s1.Code -eq 2 -and $s1.First -match "^detached $id8 \(review panel, reply name pd\): running since .*, 2 of 3 members finished$" -and $s1.Out -match '(?m)^  #1 openai :: gpt-5\.1 - running \(n=1, handoff 01\)$' -and $s1.Out -match '(?m)^  #2 ZAI :: glm-5\.3 - usable: usable reply \(n=2, handoff 02, [0-9.]+ s\)$' -and $s1.Out -match '(?m)^  #3 mimo :: mimo-v2\.6-pro - usable: usable reply \(n=3, handoff 03, [0-9.]+ s\)$') (($s1.Out -split "`n" | Select-Object -First 5) -join ' / ')
    $w = WaitRun $r @('-Id', $id8)
    $done = Run8 $r $id8
    $sum = @(([string]$done.Record.summary) -split "`n")
    $logSum = PanelSummary (Read-SharedText -Path $done.Log)
    $wSum = PanelSummary $w.Out
    Check 'PANEL' '-Wait: exit 0, the summary block "Panel <id8>: 3 of 3 entries ran (wall clock <t> s; at once)" + one row per member - VERBATIM the block the background printed last in its log; members usable with their numbers' ($w.Code -eq 0 -and $sum[0] -match '^Panel [0-9a-f]{8}: 3 of 3 entries ran \(wall clock [0-9.]+ s; at once\)$' -and $sum.Count -eq 4 -and ($wSum -join "`n") -eq ($sum -join "`n") -and ($logSum -join "`n") -eq ($sum -join "`n") -and (@($done.Record.members | ForEach-Object { "$($_.state):$($_.n):$($_.handoff)" }) -join ',') -eq 'usable:1:01,usable:2:02,usable:3:03') ($sum -join ' / ')
    $rb = New-Repo 'panel-blocking'
    $bl = Consult $rb $roster3 @('-Panel', '-Prompt', 'x', '-ReplyName', 'pd') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_DELAY_MS = '1000' }
    $nb = Norm (PanelSummary $bl.Out) ''
    $nd = Norm $sum ''
    Check 'PANEL' 'a blocking panel of the same fakes prints the same summary block (panel id and times normalised); the detached panel''s ledger has the three entries, findings F01-1..F03-1' ($bl.Code -eq 0 -and ($nb -join "`n") -eq ($nd -join "`n") -and @(Ledger $r).Count -eq 3) "$($nb[1]) || $($nd[1])"
    # the budget with two members of one endpoint one after another (D4): 2 x 200 + 120
    $rz = New-Repo 'panel-zai2'
    $repos.Add($rz)
    $fz = Consult $rz $rosterZai2 @('-Detach', '-Panel', '-Prompt', 'x', '-ReplyName', 'pz') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_TEST_PANEL_GUARD_SEC = '200' }
    $idz = Id8Of $fz.Out
    $okz = Wait-Done $rz $idz 120
    $rzr = Run8 $rz $idz
    Check 'PANEL' 'D4: a panel whose two ZAI entries run one after another -> budget_sec 520 (2 x the guard 200 + 120; "at most 2 at a time"); it completes (exit 0)' ($fz.Code -eq 0 -and $rzr.Record.budget_sec -eq 520 -and $okz -and $rzr.Record.exit -eq 0) "$($rzr.Record.budget_sec)"
}

# =============================================================== WAITTIME: -Wait's timeout (exit 3) leaves the run alone; a failing member (exit 1)
if (Want 'WAITTIME') {
    $r = New-Repo 'waittime'
    $repos.Add($r)
    $f = Consult $r $roster2 @('-Detach', '-Panel', '-Prompt', 'x', '-ReplyName', 'wt') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_DELAY_MS = '15000'; FAKE_CODEX_FAIL_ON = 'model_provider=""mimo""' }
    $id8 = Id8Of $f.Out
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $w1 = WaitRun $r @('-Id', $id8, '-WaitTimeoutSec', '2')
    $w1sec = $sw.Elapsed.TotalSeconds
    $x1 = Run8 $r $id8
    Check 'WAITTIME' '-Wait -WaitTimeoutSec 2 while the panel runs: exit 3 after about 2 s, the -Status report (running) and "codex-consult: still running after 2 s (-WaitTimeoutSec); the run was not touched - -Wait again, or -Status later."; the run goes on (not done)' ($w1.Code -eq 3 -and $w1sec -lt 12 -and $w1.Out -match "(?m)^detached $id8 \(review panel, reply name wt\): (running|starting)" -and $w1.Out -match '(?m)^codex-consult: still running after 2 s \(-WaitTimeoutSec\); the run was not touched - -Wait again, or -Status later\.$' -and $x1.Record.state -ne 'done') "$([math]::Round($w1sec, 1)) s"
    $w2 = WaitRun $r
    $x2 = Run8 $r $id8
    Check 'WAITTIME' '-Wait (no -Id, the budget as the limit): exit 1 - a member failed (mimo: its reviewer refused), openai usable; the member states usable / failed with the outcome; summary rows "failed: ..."' ($w2.Code -eq 1 -and $x2.Record.exit -eq 1 -and $x2.Record.members[0].state -eq 'usable' -and $x2.Record.members[1].state -eq 'failed' -and $x2.Record.members[1].outcome -match '^failed: ' -and ([string]$x2.Record.summary) -match '(?m)^  mimo :: mimo-v2\.6-pro\s+failed: ') ($x2.Record.members[1].outcome)
}

# =============================================================== AGY: an agy member of a detached panel (D1, F02-7)
if (Want 'AGY') {
    $r = New-Repo 'agy'
    $repos.Add($r)
    $f = Consult $r $rosterMixed @('-Detach', '-Panel', '-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'ag') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_AGY_REPLY = $adviseF; FAKE_AGY_DELAY_MS = '12000'; FAKE_CODEX_DELAY_MS = '2000' }
    $id8 = Id8Of $f.Out
    $ok = Wait-Done $r $id8 150
    $x = Run8 $r $id8
    $led = @(Ledger $r)
    Check 'AGY' 'D1/F02-7: the codex member finishes first and the background rewrites the status file (and writes its log) WHILE the agy member''s reviewer runs; the agy member''s collab-directory check does not see them (the .consult. prefix) - it stays usable, the panel exits 0' ($f.Code -eq 0 -and $ok -and $x.Record.exit -eq 0 -and $led.Count -eq 2 -and $led[1].reviewer.engine -eq 'agy' -and $led[1].bridge_outcome -eq 'usable reply' -and (To-Dto $led[0].finished_at) -lt (To-Dto $led[1].finished_at) -and (@($x.Record.members | ForEach-Object { $_.state }) -join ',') -eq 'usable,usable') "$(@($led | ForEach-Object { "$($_.n) $($_.bridge_outcome)" }) -join ' | ')"
}

# =============================================================== REFUSEDBG: refused AFTER the start - the final status says so (D3)
if (Want 'REFUSEDBG') {
    $r = New-Repo 'refusedbg'
    $repos.Add($r)
    $holderPs = Join-Path $work 'lock-holder.ps1'
    [IO.File]::WriteAllText($holderPs, ". '$scripts\codex-consult-common.ps1'`n`$l = Enter-TaskLock -TaskDir '$(Td $r)' -Task 't'`n[IO.File]::WriteAllText('$(Td $r)\held.flag', 'x')`nStart-Sleep -Seconds 90`n", $u8)
    $holder = Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $holderPs -PassThru -WindowStyle Hidden
    $cleanup.Add($holder.Id)
    $held = Wait-For { Test-Path (Join-Path (Td $r) 'held.flag') } 30
    Remove-Item -LiteralPath (Join-Path (Td $r) 'held.flag') -Force -ErrorAction SilentlyContinue
    $f = Consult $r '' @('-Detach', '-Prompt', 'x', '-ReplyName', 'rb') @{ FAKE_CODEX_REPLY = $advise }
    $id8 = Id8Of $f.Out
    $ok = Wait-Done $r $id8 90
    $x = Run8 $r $id8
    $s = Status $r @('-Id', $id8)
    Stop-Process -Id $holder.Id -Force -ErrorAction SilentlyContinue
    Check 'REFUSEDBG' 'D2/D3: the task lock is not probed in the foreground (exit 0); the background is refused on it and records that as its FINAL status - done, exit 1, the summary = the refusal line ("codex-consult: another consultation or status update for task ''t'' is running: ... held open by pid <holder>"), the member skipped "not started: ..."; -Status exit 1 prints it (never "died"); nothing recorded' ($held -and $f.Code -eq 0 -and $ok -and $x.Record.state -eq 'done' -and $x.Record.exit -eq 1 -and ([string]$x.Record.summary) -match "^codex-consult: another consultation or status update for task 't' is running: .* held open by pid $($holder.Id) " -and $x.Record.members[0].state -eq 'skipped' -and $x.Record.members[0].outcome -match '^not started: another consultation' -and $s.Code -eq 1 -and $s.First -match "^detached $id8 \(single run, reply name rb\): done, exit 1$" -and $s.Out -match '(?m)^codex-consult: another consultation' -and @(Ledger $r).Count -eq 0 -and (Records $r).Count -eq 0) ([string]$x.Record.summary)
}

# =============================================================== KILL: the background killed mid-panel - died; the next run recovers (D6)
if (Want 'KILL') {
    $r = New-Repo 'kill'
    $repos.Add($r)
    $f = Consult $r $roster2 @('-Detach', '-Panel', '-Prompt', 'x', '-ReplyName', 'kd') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_DELAY_MS = '25000' }
    $id8 = Id8Of $f.Out
    $bothRun = Wait-For { $x = Run8 $r $id8; $recs = Records $r; $x -and @($x.Record.members | Where-Object { $_.state -eq 'running' }).Count -eq 2 -and @($recs | Where-Object { $_.Record -and $_.Record.state -eq 'running' }).Count -eq 2 } 90
    $x = Run8 $r $id8
    $recsK = Records $r
    $panelId = [string](@($recsK | Where-Object { $_.Record -and $_.Record.PSObject.Properties['panel'] }) | Select-Object -First 1).Record.panel.id
    $bg = Get-Process -Id ([int]$x.Record.pid) -ErrorAction SilentlyContinue
    $survivors = @()
    if ($bg) { $survivors = Stop-ProcessTree -Process $bg }
    $s = Status $r
    $l = Run-Tool $findingsPs $r @('-Task', 't', '-List')
    $h = Hook $r $roster2
    $w = WaitRun $r @('-Id', $id8)
    Check 'KILL' 'D6: the background (and its members) killed while both members run: -Status exit 1 "died - its background process (pid <p>) is gone without a final status, 0 of 2 members finished; its recovery records are judged by the next run of the task as usual"; -Wait stops at once (exit 1); -List "detached <id8>: died ..."; the hook "; 1 detached consultation died (task t)"' ($bothRun -and $bg -and $survivors.Count -eq 0 -and $s.Code -eq 1 -and $s.First -eq "detached $id8 (review panel, reply name kd): died - its background process (pid $($x.Record.pid)) is gone without a final status, 0 of 2 members finished; its recovery records are judged by the next run of the task as usual" -and $w.Code -eq 1 -and $l.Out -match "(?m)^detached $id8`: died - its background process" -and $h -match '; 1 detached consultation died \(task t\)$') "$($s.First) | $h"
    $y = Consult $r '' @('-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-Prompt', 'y', '-ReplyName', 'after') @{ FAKE_CODEX_REPLY = $advise }
    $e = @(Ledger $r)[-1]
    Check 'KILL' 'the next run recovers as always: the members'' records (writers gone) are consumed ("recovered reservation n=1, nn=01 ... n=2, nn=02"), the task lock is free, the run proceeds with n=3 / 03 (exit 0)' ($y.Code -eq 0 -and $y.Out -match "recovered reservation n=1, nn=01 \(\.consult\.pending-01\.json: state 'running'" -and $y.Out -match "recovered reservation n=2, nn=02 \(\.consult\.pending-02\.json: state 'running'" -and $e.n -eq 3 -and $e.reply -eq 'handoffs/03-codex-after.md' -and (Records $r).Count -eq 0) (Line $y.Out 'codex-consult: recovered')
    # the killed panel run's temp directory (its finally never ran)
    $tmpDir = Join-Path ([IO.Path]::GetTempPath()) "codex-consult-panel-$panelId"
    if ($panelId -match '^[0-9a-f-]{36}$' -and (Test-Path -LiteralPath $tmpDir)) { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
}

# =============================================================== FABRIC: -Status over fabricated records - exit codes, ids, prune (D5-D7)
if (Want 'FABRIC') {
    $r = New-Repo 'fabric'
    $repos.Add($r)
    $td = Td $r
    $now = [DateTimeOffset]::Now
    $sl = Start-Sleeper 150
    Start-Sleep -Milliseconds 500
    $slStart = [string](Get-ProcessStartIso -ProcessId $sl.Id)
    $m1 = @(New-DetachedMember -Position 1 -Lineage 'openai :: gpt-5.1' -State 'usable' -Outcome 'usable reply' -Wall 3.2 -N 1 -Handoff '01' -Reply 'handoffs/01-codex-x.md')
    $pA = New-Fabricated -TaskDir $td -Id 'abcd1234-0000-4000-8000-000000000001' -State 'done' -Exit 0 -Started $now.AddMinutes(-30) -Finished $now.AddMinutes(-29) -Summary "codex-consult: usable reply - fabricated`nverdict    : ADVISE - r" -Members $m1
    $pB = New-Fabricated -TaskDir $td -Id 'abcd5678-0000-4000-8000-000000000002' -State 'done' -Exit 1 -Started $now.AddMinutes(-20) -Finished $now.AddMinutes(-19) -Summary 'codex-consult: failed: fabricated'
    $pC = New-Fabricated -TaskDir $td -Id 'cccc0000-0000-4000-8000-000000000003' -State 'running' -Started $now.AddMinutes(-10) -Pid_ $sl.Id -StartTime $slStart
    $all = Status $r
    $order = @([regex]::Matches($all.Out, '(?m)^detached ([0-9a-f]{8}) ') | ForEach-Object { $_.Groups[1].Value })
    Check 'FABRIC' 'D7: -Status without -Id prints every run of the task, newest first (cccc0000, abcd5678, abcd1234), and exits with the WORST state: one running -> 2; a done run prints its summary block after its lines' ($all.Code -eq 2 -and ($order -join ',') -eq 'cccc0000,abcd5678,abcd1234' -and $all.Out -match '(?m)^codex-consult: usable reply - fabricated$' -and $all.Out -match '(?m)^verdict    : ADVISE - r$' -and $all.Out -match '(?m)^  #1 openai :: gpt-5\.1 - usable: usable reply \(n=1, handoff 01, 3\.2 s\)$') ($order -join ',')
    Stop-Process -Id $sl.Id -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $pC.Status, $pC.Log -Force
    $e1 = Status $r
    Remove-Item -LiteralPath $pB.Status, $pB.Log -Force
    $e0 = Status $r
    Check 'FABRIC' 'D7: without the running one the worst is a done run with exit 1 -> 1; with only the usable one -> 0' ($e1.Code -eq 1 -and $e0.Code -eq 0 -and $e0.First -match '^detached abcd1234 \(single run, reply name fab\): done, exit 0$') "$($e1.Code) $($e0.Code)"
    $pB = New-Fabricated -TaskDir $td -Id 'abcd5678-0000-4000-8000-000000000002' -State 'done' -Exit 1 -Started $now.AddMinutes(-20) -Finished $now.AddMinutes(-19) -Summary 'codex-consult: failed: fabricated'
    $amb = Status $r @('-Id', 'abcd')
    $one = Status $r @('-Id', 'abcd1234')
    $long = Status $r @('-Id', 'abcd5678-0000')
    $none = Status $r @('-Id', 'ffff')
    $bad = Status $r @('-Id', 'xyz!')
    Check 'FABRIC' 'D7: an -Id prefix that matches several runs is refused with exit 4 naming them ("-Id ''abcd'' matches 2 detached runs of task ''t'': abcd5678, abcd1234; give more of the id."); a full id8 selects one (exit 0); a longer prefix is matched against the full detach id (exit 1 for that failed run); an unknown id -> exit 4 naming the task''s runs; a malformed id -> exit 4' ($amb.Code -eq 4 -and $amb.First -eq "codex-consult: -Id 'abcd' matches 2 detached runs of task 't': abcd5678, abcd1234; give more of the id." -and $one.Code -eq 0 -and $one.First -match '^detached abcd1234 ' -and $long.Code -eq 1 -and $long.First -match '^detached abcd5678 ' -and $none.Code -eq 4 -and $none.First -eq "codex-consult: no detached run of task 't' has an id starting with 'ffff' (its detached runs: abcd5678, abcd1234)." -and $bad.Code -eq 4) "$($amb.First) | $($none.First)"
    # stamped now, not from $now: the calls above take a while
    $pS = New-Fabricated -TaskDir $td -Id 'eeee0001-0000-4000-8000-000000000004' -State 'starting' -Started ([DateTimeOffset]::Now.AddSeconds(-5))
    $st = Status $r @('-Id', 'eeee0001')
    $pN = New-Fabricated -TaskDir $td -Id 'eeee0002-0000-4000-8000-000000000005' -State 'starting' -Started $now.AddMinutes(-3)
    $ns = Status $r @('-Id', 'eeee0002')
    $pE = New-Fabricated -TaskDir $td -Id 'eeee0003-0000-4000-8000-000000000006' -State 'running' -Started $now.AddMinutes(-3) -Pid_ (Dead-Pid) -StartTime '2001-01-01T00:00:00.0000000Z' -HostName 'OTHER-HOST-7'
    $el = Status $r @('-Id', 'eeee0003')
    [IO.File]::WriteAllText((Join-Path $td '.consult.detached-eeee0004.status.json'), '{ not json', $u8)
    $ur = Status $r @('-Id', 'eeee0004')
    Check 'FABRIC' 'D5/D11: `starting` without a pid 5 s ago -> exit 2 "starting - the background has not reported yet"; 3 min ago -> exit 1 "never started - no background process reported within 60 s ..."; a run on another host -> exit 2 "running on host OTHER-HOST-7 ... cannot be checked from this host" (never judged died); an unreadable status file -> exit 1 naming it' ($st.Code -eq 2 -and $st.First -match '^detached eeee0001 \(single run, reply name fab\): starting - the background has not reported yet' -and $ns.Code -eq 1 -and $ns.First -match 'never started - no background process reported within 60 s of ' -and $el.Code -eq 2 -and $el.First -match 'running on host OTHER-HOST-7 since .* its liveness cannot be checked from this host$' -and $ur.Code -eq 1 -and $ur.First -match "^detached eeee0004: the status file '.*' cannot be used: it does not parse") "$($st.First) | $($ns.First) | $($ur.First)"
    foreach ($p in @($pS, $pN, $pE)) { Remove-Item -LiteralPath $p.Status, $p.Log -Force }
    Remove-Item -LiteralPath (Join-Path $td '.consult.detached-eeee0004.status.json') -Force
    # -Prune (D6): done and died runs last written more than 7 days ago go; the rest stays
    $sl2 = Start-Sleeper 150
    Start-Sleep -Milliseconds 500
    $pOldDone = New-Fabricated -TaskDir $td -Id 'f0f00001-0000-4000-8000-000000000007' -State 'done' -Exit 0 -Started $now.AddDays(-9) -Finished $now.AddDays(-9) -Updated $now.AddDays(-9)
    $pOldDied = New-Fabricated -TaskDir $td -Id 'f0f00002-0000-4000-8000-000000000008' -State 'running' -Started $now.AddDays(-8) -Pid_ (Dead-Pid) -StartTime '2001-01-01T00:00:00.0000000Z' -Updated $now.AddDays(-8)
    $pNewDone = New-Fabricated -TaskDir $td -Id 'f0f00003-0000-4000-8000-000000000009' -State 'done' -Exit 0 -Started $now.AddDays(-1) -Finished $now.AddDays(-1) -Updated $now.AddDays(-1)
    $pOldRun = New-Fabricated -TaskDir $td -Id 'f0f00004-0000-4000-8000-00000000000a' -State 'running' -Started $now.AddDays(-9) -Pid_ $sl2.Id -StartTime ([string](Get-ProcessStartIso -ProcessId $sl2.Id)) -Updated $now.AddDays(-9)
    $pr = Status $r @('-Prune')
    $gone = @($pOldDone, $pOldDied | Where-Object { (Test-Path -LiteralPath $_.Status) -or (Test-Path -LiteralPath $_.Log) }).Count -eq 0
    $kept = @($pNewDone, $pOldRun, $pA, $pB | Where-Object { (Test-Path -LiteralPath $_.Status) -and (Test-Path -LiteralPath $_.Log) }).Count -eq 4
    Stop-Process -Id $sl2.Id -Force -ErrorAction SilentlyContinue
    Check 'FABRIC' 'D6: -Status -Prune (the one writing form) removes the status file and the log of the run done 9 days ago and of the one that died 8 days ago ("pruned     : detached f0f00001 (done, ...)", "... f0f00002 (died, ...)"); a run done yesterday and a run still running (last written 9 days ago) stay; then the report of what is left (exit 2: one runs)' ($gone -and $kept -and $pr.Code -eq 2 -and $pr.Out -match '(?m)^pruned     : detached f0f00001 \(done, last written \S+\): its status file and log were removed$' -and $pr.Out -match '(?m)^pruned     : detached f0f00002 \(died, last written ' -and -not ($pr.Out -match 'pruned     : detached f0f00003') -and -not ($pr.Out -match 'pruned     : detached f0f00004')) (@(($pr.Out -split "`n") | Where-Object { $_ -match '^pruned' }) -join ' / ')
    $q1 = Status $r @('-Wait')
    $q2 = Status $r @('-WaitTimeoutSec', '5')
    $q3 = WaitRun $r @('-Prune')
    $q4 = WaitRun $r @('-WaitTimeoutSec', '0')
    $q5 = Status $r @('-Brief', 'b.md')
    $q6 = Consult $r '' @('-Status', 'abcd1234') @{} -NoCodexExe
    $q7 = Consult $r '' @('-Prune') @{} -NoCodexExe
    $rEmpty = New-Repo 'fabric-empty'
    $q8 = Status $rEmpty
    Check 'FABRIC' 'the query''s options: -Status -Wait = -Wait; -WaitTimeoutSec without -Wait, -Wait -Prune, -WaitTimeoutSec 0, -Status with a run option (-Brief) -> exit 4; `-Status abcd1234` (the id bound positionally to -CollabDir, which does not exist) -> exit 4 with the -Id hint; -Prune alone -> refused (exit 1); a task without detached runs -> "codex-consult: no detached consultation in task ''t'' (...)" exit 0' ($q1.Code -ne 4 -and $q2.Code -eq 4 -and $q2.First -eq 'codex-consult: -WaitTimeoutSec goes with -Wait.' -and $q3.Code -eq 4 -and $q4.Code -eq 4 -and $q5.Code -eq 4 -and $q5.First -match 'not -Brief\.$' -and $q6.Code -eq 4 -and $q6.First -match "^codex-consult: -CollabDir 'abcd1234' does not exist .*the id of a detached run goes with -Id" -and $q7.Code -eq 1 -and $q8.Code -eq 0 -and $q8.First -match "^codex-consult: no detached consultation in task 't' ") "$($q5.First) | $($q6.First) | $($q8.First)"
}

# =============================================================== OUTER: the background's own try/finally (D3, D5)
if (Want 'OUTER') {
    $r = New-Repo 'outer'
    $repos.Add($r)
    $collabAbs = Join-Path $r '.collab'
    $oid = 'dddddddd-0000-4000-8000-00000000000d'
    $po = New-Fabricated -TaskDir (Td $r) -Id $oid -State 'starting' -Started ([DateTimeOffset]::Now) -Members @(New-DetachedMember -Position 1 -Lineage 'openai :: gpt-5.1')
    $orec = (Read-DetachedStatus -Path $po.Status).Record
    $orec.args = 'bm90IGNsaXhtbA=='
    Write-JsonFile -Path $po.Status -Object $orec
    # the background run by hand, in this process's view (blocking): its arguments cannot be read
    $bgRun = Consult $r '' @('-CollabDir', $collabAbs, '-DetachId', $oid) @{} -NoCodexExe
    $ox = Run8 $r 'dddddddd'
    $again = Consult $r '' @('-CollabDir', $collabAbs, '-DetachId', $oid) @{} -NoCodexExe
    $os = Status $r @('-Id', 'dddddddd')
    Check 'OUTER' 'D3/D5: a background whose run throws (its arguments are not CLIXML) - it reported first (pid, start time, this host), then its try/finally wrote the FINAL status: done, exit 1, the summary "codex-consult: the detached run stopped on an error: ...", the pending member skipped "not started: ..."; its process exit code is the run''s (1); -Status exit 1; the same -DetachId again (state done now) -> refused "not this process''s"' ($bgRun.Code -eq 1 -and $ox.Record.state -eq 'done' -and $ox.Record.exit -eq 1 -and [int]$ox.Record.pid -gt 0 -and $ox.Record.start_time -and $ox.Record.host -eq [Environment]::MachineName -and -not $ox.Record.args -and ([string]$ox.Record.summary) -match '^codex-consult: the detached run stopped on an error: ' -and $ox.Record.members[0].state -eq 'skipped' -and $ox.Record.members[0].outcome -match '^not started: the detached run stopped on an error' -and $os.Code -eq 1 -and $again.Code -eq 1 -and $again.First -match "is in state done \(pid [0-9]+\), not this process's\.$") "$([string]$ox.Record.summary) | $($again.First)"
}

# =============================================================== COLLIDE: a new detach id never reuses a taken id8 (D7)
if (Want 'COLLIDE') {
    $r = New-Repo 'collide'
    $repos.Add($r)
    $pOld = New-Fabricated -TaskDir (Td $r) -Id 'aaaaaaaa-1111-4000-8000-000000000001' -State 'done' -Exit 0 -Started ([DateTimeOffset]::Now.AddHours(-1)) -Finished ([DateTimeOffset]::Now.AddHours(-1)) -Summary 'codex-consult: usable reply - old'
    $h0 = (Get-FileHash -Algorithm SHA256 -LiteralPath $pOld.Status).Hash
    $f = Consult $r '' @('-Detach', '-Prompt', 'x', '-ReplyName', 'co') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_TEST_DETACH_GUIDS = 'aaaaaaaa-2222-4000-8000-000000000002,bbbbbbbb-3333-4000-8000-000000000003' }
    $id8 = Id8Of $f.Out
    $ok = Wait-Done $r $id8 90
    Check 'COLLIDE' 'D7: the first candidate id (aaaaaaaa-2222-...) has the id8 of an existing run - it is skipped, the run gets bbbbbbbb (detach id bbbbbbbb-3333-...); the old run''s status file is untouched; both are listed' ($f.Code -eq 0 -and $id8 -eq 'bbbbbbbb' -and $f.First -match 'detach id bbbbbbbb-3333-4000-8000-000000000003;' -and $ok -and (Get-FileHash -Algorithm SHA256 -LiteralPath $pOld.Status).Hash -eq $h0 -and @(Runs $r).Count -eq 2) $f.First
}

# =============================================================== CWD: relative paths and the caller's working directory (D8)
if (Want 'CWD') {
    $r = New-Repo 'cwd'
    $repos.Add($r)
    $sub = Join-Path $r 'sub'
    [void][IO.Directory]::CreateDirectory($sub)
    [IO.File]::WriteAllText((Join-Path $sub 'only-here.md'), "# brief`n", $u8)
    [IO.File]::WriteAllText((Join-Path $sub 'art.bin'), "binary`n", $u8)
    $artSha = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $sub 'art.bin')).Hash.ToLowerInvariant()
    $f = Consult $r '' @('-Detach', '-Brief', 'only-here.md', '-Artifact', 'art.bin', '-Prompt', 'x', '-ReplyName', 'cw') @{ FAKE_CODEX_REPLY = $advise } -Cwd $sub
    $id8 = Id8Of $f.Out
    $ok = Wait-Done $r $id8 90
    $x = Run8 $r $id8
    $e = @(Ledger $r)[-1]
    Check 'CWD' 'D8: started from a subdirectory with a brief and an artifact that exist only relative to it: the foreground resolves them (the status file''s brief is absolute); the background runs in the caller''s directory with absolute paths - usable (exit 0), ledger brief sub/only-here.md, the artifact bound by its absolute path and hash' ($f.Code -eq 0 -and $ok -and $x.Record.exit -eq 0 -and $x.Record.brief -eq (Join-Path $sub 'only-here.md') -and $e.brief -eq 'sub/only-here.md' -and @($e.artifacts).Count -eq 1 -and $e.artifacts[0].path -eq (Join-Path $sub 'art.bin') -and $e.artifacts[0].sha256 -ieq $artSha) "$($e.brief) | $(@($e.artifacts)[0].path)"
}

# =============================================================== ENC: a non-ASCII summary - the log and the status file are UTF-8 (D10)
if (Want 'ENC') {
    $r = New-Repo 'enc'
    $repos.Add($r)
    $reason = 'J' + [char]0x00FC + 'rgen' + [char]0x2019 + 's plan ' + [char]0x2013 + ' ok ' + [char]0x0416
    $encReply = Reply 'advise-enc.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"' + $reason + '","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
    $f = Consult $r '' @('-Detach', '-Prompt', 'x', '-ReplyName', 'en') @{ FAKE_CODEX_REPLY = $encReply }
    $id8 = Id8Of $f.Out
    $ok = Wait-Done $r $id8 90
    $x = Run8 $r $id8
    $logText = ''
    # the bytes, read beside the background that may still hold the log open (it exits after its final write)
    try {
        $fs = New-Object System.IO.FileStream($x.Log, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
        try { $ms = New-Object System.IO.MemoryStream; $fs.CopyTo($ms); $logBytes = $ms.ToArray() } finally { $fs.Dispose() }
        $logText = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($logBytes)
    } catch { $logText = "(unreadable or not valid UTF-8: $($_.Exception.Message))" }
    $want = "verdict    : ADVISE - $reason"
    Check 'ENC' "D10 ($hostTag): a verdict reason with u-umlaut, a curly apostrophe, an en dash and a Cyrillic letter - the background's log is valid UTF-8 holding the summary line exactly, and the status file's summary holds it too" ($f.Code -eq 0 -and $ok -and $logText.Contains($want) -and ([string]$x.Record.summary).Contains($want)) "log has it: $($logText.Contains($want)); status has it: $(([string]$x.Record.summary).Contains($want)); $(if (-not $logText.Contains($want)) { $logText.Substring(0, [Math]::Min(200, $logText.Length)) })"
}

# =============================================================== T4: -ScriptsDir / CODEX_CONSULT_SCRIPTS_DIR (ROADMAP T4)
if (Want 'T4') {
    $copy = Join-Path $work 't4-plugin\scripts'
    [void][IO.Directory]::CreateDirectory($copy)
    Copy-Item -Path (Join-Path $scripts '*') -Destination $copy -Force
    $schemasSrc = Join-Path (Split-Path -Parent $scripts) 'schemas'
    if (Test-Path -LiteralPath $schemasSrc) { Copy-Item -Path $schemasSrc -Destination (Join-Path $work 't4-plugin') -Recurse -Force }
    $marker = Join-Path $work 't4-marker.txt'
    [IO.File]::AppendAllText((Join-Path $copy 'codex-consult-common.ps1'), "`nif (`$env:T4_MARKER) { [IO.File]::AppendAllText(`$env:T4_MARKER, `"loaded `$PSScriptRoot`n`") }`n", $u8)
    $runAll = Join-Path $sp 'run-all.ps1'
    $h3b = Join-Path $sp 'harness-3b.ps1'
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $env:T4_MARKER = $marker
    $ra = @(& $psExe -NoProfile -ExecutionPolicy Bypass -File $runAll -Only harness-3b -ScriptsDir $copy 2>&1 | ForEach-Object { "$_" })
    $raCode = $LASTEXITCODE
    $m1 = @(Get-Content -LiteralPath $marker -ErrorAction SilentlyContinue).Count
    $env:CODEX_CONSULT_SCRIPTS_DIR = $copy
    $hb = @(& $psExe -NoProfile -ExecutionPolicy Bypass -File $h3b 2>&1 | ForEach-Object { "$_" })
    $hbCode = $LASTEXITCODE
    Remove-Item env:CODEX_CONSULT_SCRIPTS_DIR -ErrorAction SilentlyContinue
    $m2 = @(Get-Content -LiteralPath $marker -ErrorAction SilentlyContinue).Count
    $hc = @(& $psExe -NoProfile -ExecutionPolicy Bypass -File $h3b 2>&1 | ForEach-Object { "$_" })
    $hcCode = $LASTEXITCODE
    $m3 = @(Get-Content -LiteralPath $marker -ErrorAction SilentlyContinue).Count
    Remove-Item env:T4_MARKER -ErrorAction SilentlyContinue
    $ErrorActionPreference = $p
    $raLog = [string](@($ra | Where-Object { $_ -match '^run-all: .*logs in ' }) | Select-Object -First 1)
    if ($raLog -match 'logs in (.+)$') { $d = $Matches[1].Trim(); if ($d -and (Test-Path -LiteralPath $d) -and $d -like '*codex-consult-tests*') { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue } }
    $raSum = [string](@($ra | Where-Object { $_ -match '^run-all: [0-9]+ harness' }) | Select-Object -Last 1)
    $raLine = [string](@($ra | Where-Object { $_ -match '^(ok  |FAIL) harness-3b ' }) | Select-Object -First 1)
    $hbEnd = [string](@($hb | Where-Object { $_ -match '^harness-3b: [0-9]+ failure' }) | Select-Object -Last 1)
    $hcEnd = [string](@($hc | Where-Object { $_ -match '^harness-3b: [0-9]+ failure' }) | Select-Object -Last 1)
    # (what harness-3b itself concludes is not the point here - its process-scan cases also see a
    # real codex.exe of the machine; the override is: which scripts ran, and what run-all names)
    Check 'T4' 'ROADMAP T4: run-all.ps1 -ScriptsDir <a copy of the scripts> passes it to the harness (harness-3b ran to its end against the copy: its common file, marked, was loaded) and names the directory in its summary line; CODEX_CONSULT_SCRIPTS_DIR does the same for a harness started directly; without either the checkout''s scripts are used (the marker is not written)' ($raLine -match 'harness-3b: [0-9]+ failure' -and $raSum -match ('^run-all: 1 harness\(es\), [01] failed; scripts: ' + [regex]::Escape($copy) + '$') -and $m1 -eq 1 -and $hbEnd -and $m2 -eq 2 -and $hcEnd -and $m3 -eq 2 -and (@(Get-Content -LiteralPath $marker) | Where-Object { $_ -ne "loaded $copy" }).Count -eq 0) "run-all: $raSum | harness-3b: $hbEnd / $hcEnd (exit $raCode, $hbCode, $hcCode) | marker lines $m1 / $m2 / $m3"
}

} finally {
    Restore-Env
    foreach ($rp in $repos) { try { Stop-Background $rp } catch { } }
    foreach ($id in $cleanup) { try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch { } }
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-detach ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
