# codex-consult wave 28e (the 0.6.0 candidate, with wave 29; the four small items E1-E4 of the 0.5.0
# verdict, .collab/companions-2026-09-26/handoffs/56-...; findings F54-1..F54-4 and F53-1): RECORD - the
# recovery record keeps the descendants a kill could not verify (`unverified[]` {pid, why} beside
# `survivors[]`; the gated test hook CODEX_CONSULT_TEST_UNVERIFIED=<pid> fakes such a descendant at the
# main turn's kill), the next run names them and checks them again: gone - dropped, the run goes on;
# still unreadable - it blocks as a survivor (fail-closed); readable and codex-like - it blocks;
# readable but started before that run - dropped (E1); NOTSPOOLED - the not-spooled count is one file
# per producer process (telemetry-not-spooled-<pid>-<start ticks>.ndjson), appended without contention
# (two processes appending at once: two files, nothing lost), -Status sums them with the legacy single
# file, a flush folds the files of gone producers (and the legacy file) into ONE line of .last notes and
# removes them, keeps a live producer's, -Forget -Local removes every one (E2); MARKER - the forgetting
# marker's owner judged on pid AND its start time in ticks (`start_ticks`): wrong ticks - gone, removed;
# the right ticks - alive, refuses; an older marker without ticks as before (E3); ANCHOR - the inline
# re-read anchor of a context_tokens member keeps the FIRST line of a multi-line ask whole (cut at 300)
# and the count of the remaining lines (E4); DOCS; GUARD.
# The 0.6.0 acceptance (.collab/claude-engine-2026-09-30/handoffs/27-..., F27-1..F27-3; decisions
# E18-E20): RECORD - a kill with NO survivor but a descendant it could not verify keeps the record too
# (state survivors, survivors [], unverified [{pid, why}]) and the next run is refused while that pid's
# identity cannot be read (E18); a recorded unverified pid that started after the record and whose
# command line cannot be read (the gated test hook CODEX_CONSULT_TEST_CMDLINE_UNREADABLE=<pid>) counts
# as running, the same pid with a command line read and not codex-like is dropped - and so is a survivor
# recorded without a start time: unreadable command line refused, read and not codex-like dropped
# (E19); NOTSPOOLED -
# the fold saves .last (its note, not_spooled_seen, not_spooled_folded[]) BEFORE it deletes the files: a
# crash between the two (the gated test hook CODEX_CONSULT_TEST_FOLD_CRASH=1, a real process exit) and
# the next flush deletes them without counting them again; a .last that cannot be written (read-only)
# folds nothing and warns (E20). The second round (handoff 30, F30-1, F30-2; decisions E23, E24): RECORD -
# a timeout kill NOT confirmed that names no pid (the children cannot be enumerated and taskkill fails:
# CODEX_CONSULT_TEST_KILL_DENIED=1, the fake reviewer an orphan) keeps the record with kill_unconfirmed; the
# next run scans by parent pid and is refused while the orphan runs, releases the record once it is gone;
# outside Windows or from another host such a record is refused (E23); NOTSPOOLED - not_spooled_folded[]
# holds {name, bytes}: a legacy line appended between the crash and the restarted flush is counted exactly
# once, a shorter file under a recorded name is folded afresh, a bare name of the E20 build is not counted
# (E24).
# FAKES ONLY: fake-codex3.cmd; CODEX_HOME points at scratch directories, CODEX_CONSULT_ROSTER at
# scratch files, CODEX_CONSULT_HEALTH is 'none', telemetry off and the intake a closed loopback port
# (http://127.0.0.1:9/ - nothing is ever sent anywhere); the host markers of the process that runs it
# are removed first; the API key variables hold dummy values. Runs under the host it is started with
# (powershell 5.1 or pwsh 7, Windows). Work files: $env:TEMP\codex-consult-tests\harness-fixes28e\
# <guid>, removed at the end.
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
$commonPs = Join-Path $scripts 'codex-consult-common.ps1'
. $commonPs
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$telemetryPs = Join-Path $scripts 'codex-telemetry.ps1'
$findingsPs = Join-Path $scripts 'codex-findings.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$psName = (Get-Process -Id $PID).ProcessName
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-fixes28e') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 10; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
$script:fails = 0
$script:passes = 0
function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 400) { $ev = $ev.Substring(0, 400) + '...' }
    Write-Host ("{0} {1,-10} {2}{3}" -f $mark, $Id, $What, $(if ($ev) { "  | $ev" } else { '' }))
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
# every restore returns to a SCRATCH codex home: nothing in this harness can reach the operator's own
# ~/.codex (its spool, its .last, its locks)
$savedCodexHome = $codexHome
$env:CODEX_HOME = $codexHome
# the operator's real codex home: its telemetry* names before and after (read only - GUARD)
$realHome = Join-Path $HOME '.codex'
$realTelemetry = { (@(if (Test-Path -LiteralPath $realHome) { Get-ChildItem -LiteralPath $realHome -Force | Where-Object { $_.Name -like 'telemetry*' } | ForEach-Object { $_.Name } }) | Sort-Object) -join ',' }
$realBefore = & $realTelemetry
# A scratch codex home of its own (telemetry cases)
function New-Home {
    param([string]$Name)
    $h = Join-Path $work "home-$Name"
    [void][IO.Directory]::CreateDirectory($h)
    [IO.File]::WriteAllText((Join-Path $h 'config.toml'), $toml, $u8)
    return $h
}
function Write-Roster { param([string]$Name, [string]$Json) $p = Join-Path $work "roster-$Name.json"; [IO.File]::WriteAllText($p, $Json, $u8); return $p }
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ENV_DUMP', 'FAKE_CODEX_PRELINE', 'FAKE_CODEX_HANG_ON', 'FAKE_CODEX_HANG_NEW', 'FAKE_CODEX_PIDDIR')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CODEX_CONSULT_TEST_SURVIVORS', 'CODEX_CONSULT_TEST_UNVERIFIED', 'CODEX_CONSULT_TEST_START_UNREADABLE', 'CODEX_CONSULT_TEST_CMDLINE_UNREADABLE', 'CODEX_CONSULT_TEST_FOLD_CRASH', 'CODEX_CONSULT_TEST_KILL_DENIED')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    foreach ($k in (Get-HostMarkerNames)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $env:CODEX_CONSULT_HEALTH = 'none'
    $env:CODEX_CONSULT_TEST_MODE = '1'
    $env:CODEX_CONSULT_TELEMETRY = 'off'
    $env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
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
# One bridge call (synchronous): { Code; Out; First }
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task 't' -CodexExe $fake @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1) }
}
# A PowerShell script run in a child process with the telemetry home $CodexHome and extra variables
# ('' removes one): { Code; Out }
function Run-Child {
    param([string]$Script, [string[]]$ArgList, [string]$CodexHome, [hashtable]$Env = @{})
    $prevHome = $env:CODEX_HOME
    Clear-TestEnv
    $env:CODEX_HOME = $CodexHome
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $Script @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Restore-Env
    # the case's own home again (the in-process calls that follow it use it)
    $env:CODEX_HOME = $prevHome
    return [pscustomobject]@{ Code = $code; Out = (($out | ForEach-Object { "$_" }) -join "`n") }
}
# (E23) A bridge call in the BACKGROUND, its output in files - an orphan that inherited a pipe would hold
# a synchronous caller until it exits: { Proc; OutP }; Wait-Bg: { Code; Out }
function Start-Bg {
    param([string]$Repo, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv '' $Env
    $tag = [guid]::NewGuid().ToString('N').Substring(0, 8)
    $outP = Join-Path $work "bg-$tag.txt"
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-CodexExe', $fake) + @($ArgList)
    $argText = (@($all | ForEach-Object { if ([string]$_ -match '[\s"]' -or [string]$_ -eq '') { '"' + ([string]$_ -replace '"', '\"') + '"' } else { [string]$_ } }) -join ' ')
    $proc = Start-Process -FilePath $psExe -ArgumentList $argText -WorkingDirectory $Repo -NoNewWindow -PassThru -RedirectStandardOutput $outP -RedirectStandardError "$outP.err"
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $proc.Handle } catch { } }
    Restore-Env
    return [pscustomobject]@{ Proc = $proc; OutP = $outP }
}
function Wait-Bg {
    param($Bg, [int]$TimeoutSec = 120)
    if (-not $Bg.Proc.WaitForExit($TimeoutSec * 1000)) { try { $null = Stop-ProcessTree -Process $Bg.Proc } catch { } }
    $o = ''
    foreach ($f in @($Bg.OutP, "$($Bg.OutP).err")) { if (Test-Path -LiteralPath $f) { $o += (Read-SharedText -Path $f) } }
    return [pscustomobject]@{ Code = $Bg.Proc.ExitCode; Out = $o }
}
# A script run in a repository with the arguments given: its output text
function Run-InRepo {
    param([string]$Repo, [string]$Script, [string[]]$ArgList)
    Set-CaseEnv '' @{}
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $Script @ArgList 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return $o
}
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Text { param([string]$Path) if ($Path -and (Test-Path -LiteralPath $Path)) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
function Lines { param([string]$Path) return , ([string[]]@((Text $Path) -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ })) }
function LastNotes { param([string]$CodexHome) $f = Join-Path (Join-Path $CodexHome 'telemetry-spool') '.last'; if (-not (Test-Path -LiteralPath $f)) { return , ([string[]]@()) }; return , ([string[]]@(@((ConvertFrom-Json (Text $f)).notes) | Where-Object { $_ } | ForEach-Object { [string]$_ })) }
function NsNames { param([string]$CodexHome) return (@(Get-ChildItem -LiteralPath $CodexHome -File -Force -Filter 'telemetry-not-spooled*' -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object { $_.Name }) -join ',') }
function StatusLine { param([string]$Out, [string]$Prefix) return ((($Out -split "`n") | Where-Object { $_ -like "$Prefix*" }) -join ' // ') }
# A hidden sleeper process (a stand-in for a process a kill left behind): the Process object
function Start-Sleeper {
    $pr = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 150' -PassThru -WindowStyle Hidden
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $pr.Handle } catch { } }
    return $pr
}
$sleepers = New-Object System.Collections.Generic.List[object]
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Join-Path $work 'advise.json'
[IO.File]::WriteAllText($advise, $adviseJson, $u8)
$sw = [pscustomobject]@{ On = $true; Text = 'on'; Source = 'test' }
$entry = [pscustomobject]@{ bridge_outcome = 'usable reply'; reviewer = [pscustomobject]@{ engine = 'codex'; model = 'gpt-5.1'; provider_config = [pscustomobject]@{ builtin = 'openai' } } }

try {

# =============================================================== RECORD: unverified[] beside survivors[] (E1)
if (Want 'RECORD') {
    # the mixed kill, end to end: A survives (CODEX_CONSULT_TEST_SURVIVORS), B is a descendant whose
    # start time could not be read (CODEX_CONSULT_TEST_UNVERIFIED)
    $sA = Start-Sleeper; $sleepers.Add($sA)
    $sB = Start-Sleeper; $sleepers.Add($sB)
    # (the record's started is cut to the second: B must start well before the run)
    Start-Sleep -Seconds 2
    $r = New-Repo 'record'
    $pend = Join-Path $r '.collab\t\.consult.pending.json'
    $x1 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'k1', '-TimeoutSec', '4') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json'; CODEX_CONSULT_TEST_SURVIVORS = [string]$sA.Id; CODEX_CONSULT_TEST_UNVERIFIED = [string]$sB.Id }
    $rec1 = $null; try { $rec1 = ConvertFrom-Json (Text $pend) } catch { }
    $e1 = @(Ledger $r)[-1]
    $uv1 = @($(if ($rec1) { $rec1.unverified } else { @() }))
    $whyB = "start time of pid $($sB.Id) unreadable"
    Check 'RECORD' 'E1 (F54-1) a timeout kill with a survivor AND a descendant whose start time could not be read: the recovery record (state survivors) keeps survivors[] {pid A, start_time, name} AND unverified[] [{pid B, why "start time of pid B unreadable"}]; the outcome names both groups' ($rec1 -and $rec1.state -eq 'survivors' -and @($rec1.survivors).Count -eq 1 -and [int]@($rec1.survivors)[0].pid -eq $sA.Id -and [string]@($rec1.survivors)[0].start_time -and $uv1.Count -eq 1 -and [int]$uv1[0].pid -eq $sB.Id -and [string]$uv1[0].why -ceq $whyB -and [string]$e1.bridge_outcome -match ([regex]::Escape("1 processes survived: pid $($sA.Id); $whyB; pid $($sB.Id) may still run; the next run for this task is refused until they exit"))) "exit $($x1.Code) | record $(Text $pend) | outcome $($e1.bridge_outcome)"
    Stop-Process -Id $sA.Id -Force -ErrorAction SilentlyContinue
    try { $null = $sA.WaitForExit(10000) } catch { }
    # the survivor is gone; B's start time still cannot be read: it blocks, fail-closed, and is named
    $x2 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'k2') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_TEST_START_UNREADABLE = [string]$sB.Id }
    Check 'RECORD' 'E1 the next run, the survivor gone but B''s start time STILL unreadable (CODEX_CONSULT_TEST_START_UNREADABLE=B): refused (exit 1) - "a previous consultation''s codex run left a process its kill could not verify (...): pid B [its start time still cannot be read - counted as running (fail-closed); at the kill: start time of pid B unreadable] - it blocks the task as a survivor does"; the record stays' ($x2.Code -eq 1 -and $x2.Out -match ([regex]::Escape("left a process its kill could not verify (")) -and $x2.Out -match ([regex]::Escape("pid $($sB.Id) [its start time still cannot be read - counted as running (fail-closed); at the kill: $whyB] - it blocks the task as a survivor does")) -and (Test-Path -LiteralPath $pend)) "exit $($x2.Code) | $($x2.First)"
    # readable now: B started before that run - not its descendant: dropped, said, and the run goes on
    $x3 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'k3') @{ FAKE_CODEX_REPLY = $advise }
    $e3 = @(Ledger $r)[-1]
    Check 'RECORD' 'E1 B''s start time readable again (no hook): B started before that run, so it is no descendant of it - "unverified pid(s) B [started <t>, before that run: not its process] dropped" in the line that clears the record; the run goes on (exit 0, a usable reply, the record gone)' ($x3.Code -eq 0 -and $x3.Out -match ("cleared the recovery record of consult n=1, nn=01 \(state 'survivors'; .*unverified pid\(s\) $($sB.Id) \[started \S+, before that run: not its process\] dropped") -and $e3.bridge_outcome -eq 'usable reply' -and -not (Test-Path -LiteralPath $pend)) "exit $($x3.Code) | $((($x3.Out -split "`n") | Where-Object { $_ -match 'recovery record|recovered' }) -join ' // ')"
    Stop-Process -Id $sB.Id -Force -ErrorAction SilentlyContinue
    # a seeded record: the unverified pid is gone (999999, never a Windows pid) - dropped, the run goes on
    $rg = New-Repo 'record-gone'
    $tdG = Join-Path $rg '.collab\t'
    [void][IO.Directory]::CreateDirectory($tdG)
    $pendG = Join-Path $tdG '.consult.pending.json'
    [IO.File]::WriteAllText($pendG, '{"state":"survivors","n":4,"nn":"05","reply":"handoffs/05-codex-old.md","events":"","consult_id":"","started":"' + (Get-IsoTimestamp) + '","pid":999998,"host":"' + [Environment]::MachineName + '","launcher":' + (ConvertTo-Json $fake) + ',"engine":"codex","child_pid":null,"child_start_time":"","survivors":[],"unverified":[{"pid":999999,"why":"start time of pid 999999 unreadable"}],"note":""}', $u8)
    $xg = Consult $rg '' @('-Prompt', 'x', '-ReplyName', 'g1') @{ FAKE_CODEX_REPLY = $advise }
    $eg = @(Ledger $rg)[-1]
    Check 'RECORD' 'E1 a record whose only unverified pid is gone (999999): the next run names it - "recovered reservation n=4, nn=05 (state ''survivors'' of an interrupted run; unverified pid(s) 999999 [gone] dropped; ...)" - and goes on (exit 0, n=5 / handoff 06, the record gone)' ($xg.Code -eq 0 -and $xg.Out -match "recovered reservation n=4, nn=05 \(state 'survivors' of an interrupted run; unverified pid\(s\) 999999 \[gone\] dropped" -and [int]$eg.n -eq 5 -and $eg.reply -eq 'handoffs/06-codex-g1.md' -and -not (Test-Path -LiteralPath $pendG)) "exit $($xg.Code) | $((($xg.Out -split "`n") | Where-Object { $_ -match 'recovered' }) -join ' // ')"
    # a seeded record whose unverified pid is THIS process (alive, its start time readable, and it looks
    # like the recorded launcher - this host's own executable): it blocks as a survivor would
    $rl = New-Repo 'record-live'
    $tdL = Join-Path $rl '.collab\t'
    [void][IO.Directory]::CreateDirectory($tdL)
    $pendL = Join-Path $tdL '.consult.pending.json'
    [IO.File]::WriteAllText($pendL, '{"state":"survivors","n":2,"nn":"03","reply":"handoffs/03-codex-old.md","events":"","consult_id":"","started":"2020-01-01T00:00:00+00:00","pid":999998,"host":"' + [Environment]::MachineName + '","launcher":' + (ConvertTo-Json $psExe) + ',"engine":"codex","child_pid":null,"child_start_time":"","survivors":[],"unverified":[{"pid":' + $PID + ',"why":"start time of pid ' + $PID + ' unreadable"}],"note":""}', $u8)
    $before = Text $pendL
    $xl = Consult $rl '' @('-Prompt', 'x', '-ReplyName', 'l1') @{ FAKE_CODEX_REPLY = $advise }
    Check 'RECORD' 'E1 a record whose unverified pid is alive, readable and codex-like (this process; the record''s launcher is its executable): the next run is REFUSED (exit 1) naming it - "...left a process its kill could not verify (...): pid <n> [start time readable now; name <host> (the recorded launcher); at the kill: start time of pid <n> unreadable] - it blocks the task as a survivor does"; the record untouched, no ledger' ($xl.Code -eq 1 -and $xl.Out -match ([regex]::Escape("pid $PID [start time readable now; name $psName (the recorded launcher); at the kill: start time of pid $PID unreadable] - it blocks the task as a survivor does")) -and (Text $pendL) -ceq $before -and @(Ledger $rl).Count -eq 0) "exit $($xl.Code) | $($xl.First)"
    # the re-check itself, in this process
    $since = [DateTimeOffset]::Parse('2020-01-01T00:00:00+00:00', $script:Invariant)
    $tGone = Test-UnverifiedProcess -ProcessId 999999 -Since $since
    $tCodex = Test-UnverifiedProcess -ProcessId $PID -Since $since -Launcher $psExe
    $tOther = Test-UnverifiedProcess -ProcessId $PID -Since $since -Launcher 'C:\nowhere\codex.cmd'
    $tBefore = Test-UnverifiedProcess -ProcessId $PID -Since ([DateTimeOffset]::UtcNow) -Launcher $psExe
    $env:CODEX_CONSULT_TEST_START_UNREADABLE = [string]$PID
    try { $tUnread = Test-UnverifiedProcess -ProcessId $PID -Since ([DateTimeOffset]::UtcNow) -Launcher '' } finally { Remove-Item env:CODEX_CONSULT_TEST_START_UNREADABLE -ErrorAction SilentlyContinue }
    Check 'RECORD' 'E1 Test-UnverifiedProcess: a pid that is gone - not alive (gone); readable and codex-like - alive; readable but not codex-like - not alive (never by pid alone); readable but started before the run - not alive; its start time unreadable - ALIVE whatever else (fail-closed)' (-not $tGone.Alive -and $tGone.How -eq 'gone' -and $tCodex.Alive -and $tCodex.How -eq "start time readable now; name $psName (the recorded launcher)" -and -not $tOther.Alive -and $tOther.How -match "^start time readable now; pid $PID runs $psName, not codex$" -and -not $tBefore.Alive -and $tBefore.How -match ', before that run: not its process$' -and $tUnread.Alive -and $tUnread.How -eq 'its start time still cannot be read - counted as running (fail-closed)') "$($tGone.How) | $($tCodex.How) | $($tOther.How) | $($tBefore.How) | $($tUnread.How)"
    $recOther = [pscustomobject]@{ state = 'survivors'; n = 1; nn = '02'; reply = 'r'; started = (Get-IsoTimestamp); pid = 999998; host = 'OTHER-HOST-28E'; launcher = ''; child_pid = $null; child_start_time = ''; survivors = [object[]]@(); unverified = [object[]]@([pscustomobject]@{ pid = 4242; why = 'start time of pid 4242 unreadable' }); note = '' }
    $vo = Test-PendingActive -Record $recOther -Path 'x.json'
    $ue = @(New-UnverifiedEntries -Check ([pscustomobject]@{ Survivors = [int[]]@(7); Confirmed = $false; Why = 'start time of pid 8, 9 unreadable'; RootPid = 1; Unverified = [int[]]@(8, 9) }))
    $ue0 = @(New-UnverifiedEntries -Check ([pscustomobject]@{ Survivors = [int[]]@(7); Confirmed = $false; Why = ''; RootPid = 1; Unverified = [int[]]@() }))
    Check 'RECORD' 'E1 a record from another host whose only pids are unverified ones: active, naming them ("... left codex process(es) pid 4242 ...; they cannot be checked from this host"); New-UnverifiedEntries makes {pid, why} per unverified pid of a kill check (none: no entry)' ($vo.Active -and $vo.Message -match 'on host OTHER-HOST-28E left codex process\(es\) pid 4242 .*cannot be checked from this host' -and $ue.Count -eq 2 -and [int]$ue[0].pid -eq 8 -and [int]$ue[1].pid -eq 9 -and $ue[1].why -ceq 'start time of pid 8, 9 unreadable' -and $ue0.Count -eq 0) "$($vo.Message) | $(ConvertTo-Json -Compress -InputObject $ue)"
    $cs = Text $consultPs
    $rk = New-PendingRecord -State 'reserved' -N 1 -Nn '02' -Reply 'r' -Started (Get-IsoTimestamp)
    Check 'RECORD' 'E1 the code: the three places that record survivors (a turn, the main turn, the format repair) record unverified[] from their kill check beside them; a new record carries unverified [] after survivors; the test hook CODEX_CONSULT_TEST_UNVERIFIED is read through Get-TestHookValue (test mode only)' ($cs.Contains('New-UnverifiedEntries -Check $turnKill') -and $cs.Contains('New-UnverifiedEntries -Check $mainKill') -and $cs.Contains('New-UnverifiedEntries -Check $repairKill') -and (($rk.PSObject.Properties.Name -join ',') -match ',survivors,unverified,note$') -and $cs.Contains("Get-TestHookValue 'CODEX_CONSULT_TEST_UNVERIFIED'")) (($rk.PSObject.Properties.Name) -join ',')
    # (wave 28e, E18 / F27-1) a timeout kill with NO survivor and one descendant it could not verify
    # (CODEX_CONSULT_TEST_UNVERIFIED alone): the record is kept all the same
    $sC = Start-Sleeper; $sleepers.Add($sC)
    $ru = New-Repo 'record-unverified'
    $pendU = Join-Path $ru '.collab\t\.consult.pending.json'
    $xu1 = Consult $ru '' @('-Prompt', 'x', '-ReplyName', 'u1', '-TimeoutSec', '4') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = '--json'; CODEX_CONSULT_TEST_UNVERIFIED = [string]$sC.Id }
    $recU = $null; try { $recU = ConvertFrom-Json (Text $pendU) } catch { }
    $eu1 = @(Ledger $ru)[-1]
    $uvU = @($(if ($recU) { $recU.unverified } else { @() }))
    $whyC = "start time of pid $($sC.Id) unreadable"
    Check 'RECORD' 'E18 (F27-1) a timeout kill with ZERO survivors and one descendant whose start time could not be read: the recovery record is KEPT - state survivors, survivors [], unverified [{pid, why}] ("recovery record kept: ... (state ''survivors'')"); the outcome "(kill not confirmed: start time of pid <n> unreadable; pid <n> may still run; the next run for this task is refused until it exits)"' ($recU -and $recU.state -eq 'survivors' -and @($recU.survivors).Count -eq 0 -and $uvU.Count -eq 1 -and [int]$uvU[0].pid -eq $sC.Id -and [string]$uvU[0].why -ceq $whyC -and [string]$eu1.bridge_outcome -match ([regex]::Escape("(kill not confirmed: $whyC; pid $($sC.Id) may still run; the next run for this task is refused until it exits)")) -and $xu1.Out -match "recovery record kept: .*\(state 'survivors'\)") "exit $($xu1.Code) | record $(Text $pendU) | outcome $($eu1.bridge_outcome)"
    $logU = Join-Path $work 'record-unverified-exec.log'
    $beforeU = Text $pendU
    $xu2 = Consult $ru '' @('-Prompt', 'x', '-ReplyName', 'u2') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $logU; CODEX_CONSULT_TEST_START_UNREADABLE = [string]$sC.Id }
    Check 'RECORD' 'E18 the next run names that pid and, while its identity cannot be read (CODEX_CONSULT_TEST_START_UNREADABLE), is REFUSED (exit 1) - "... left a process its kill could not verify (...): pid <n> [its start time still cannot be read - counted as running (fail-closed); at the kill: ...] - it blocks the task as a survivor does"; NO reviewer launched (the fake''s exec log not written), no ledger entry added, the record untouched' ($xu2.Code -eq 1 -and $xu2.Out -match ([regex]::Escape("pid $($sC.Id) [its start time still cannot be read - counted as running (fail-closed); at the kill: $whyC] - it blocks the task as a survivor does")) -and -not (Test-Path -LiteralPath $logU) -and @(Ledger $ru).Count -eq 1 -and (Text $pendU) -ceq $beforeU) "exit $($xu2.Code) | $($xu2.First)"
    Stop-Process -Id $sC.Id -Force -ErrorAction SilentlyContinue
    try { $null = $sC.WaitForExit(10000) } catch { }
    $xu3 = Consult $ru '' @('-Prompt', 'x', '-ReplyName', 'u3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $logU }
    $eu3 = @(Ledger $ru)[-1]
    Check 'RECORD' 'E18 once that pid is gone the next run clears the record naming it ("cleared the recovery record of consult n=1, nn=01 (state ''survivors''; ... unverified pid(s) <n> [gone] dropped") and goes on (exit 0, a usable reply, the reviewer launched)' ($xu3.Code -eq 0 -and $xu3.Out -match ("cleared the recovery record of consult n=1, nn=01 \(state 'survivors'; .*unverified pid\(s\) $($sC.Id) \[gone\] dropped") -and $eu3.bridge_outcome -eq 'usable reply' -and (Test-Path -LiteralPath $logU) -and -not (Test-Path -LiteralPath $pendU)) "exit $($xu3.Code) | $((($xu3.Out -split "`n") | Where-Object { $_ -match 'recovery record|recovered' }) -join ' // ')"
    # (wave 28e, E19 / F27-2) a recorded unverified pid that started AFTER the record - a generic runtime
    # (this host's executable) - whose command line cannot be read (CODEX_CONSULT_TEST_CMDLINE_UNREADABLE)
    $rcl = New-Repo 'record-cmdline'
    $tdC = Join-Path $rcl '.collab\t'
    [void][IO.Directory]::CreateDirectory($tdC)
    $pendC = Join-Path $tdC '.consult.pending.json'
    # (the record's started is cut to the second: the sleeper starts well after it)
    $startedC = Get-IsoTimestamp
    Start-Sleep -Milliseconds 1500
    $sD = Start-Sleeper; $sleepers.Add($sD)
    [IO.File]::WriteAllText($pendC, '{"state":"survivors","n":2,"nn":"03","reply":"handoffs/03-codex-old.md","events":"","consult_id":"","started":"' + $startedC + '","pid":999998,"host":"' + [Environment]::MachineName + '","launcher":' + (ConvertTo-Json $fake) + ',"engine":"codex","child_pid":null,"child_start_time":"","survivors":[],"unverified":[{"pid":' + $sD.Id + ',"why":"start time of pid ' + $sD.Id + ' unreadable"}],"note":""}', $u8)
    $beforeC = Text $pendC
    $logC = Join-Path $work 'record-cmdline-exec.log'
    $xc1 = Consult $rcl '' @('-Prompt', 'x', '-ReplyName', 'c1') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $logC; CODEX_CONSULT_TEST_CMDLINE_UNREADABLE = [string]$sD.Id }
    Check 'RECORD' 'E19 (F27-2) a recorded unverified pid that is a generic runtime (powershell), alive, its start time readable and AFTER the record''s started, its command line NOT readable (CODEX_CONSULT_TEST_CMDLINE_UNREADABLE): counted as running - REFUSED (exit 1) "pid <n> [start time readable now; pid <n> runs <host>; command line not readable - counted as running (fail-closed); at the kill: ...] - it blocks the task as a survivor does"; no reviewer launched, the record untouched, no ledger' ($xc1.Code -eq 1 -and $xc1.Out -match ([regex]::Escape("pid $($sD.Id) [start time readable now; pid $($sD.Id) runs $psName; command line not readable - counted as running (fail-closed); at the kill: start time of pid $($sD.Id) unreadable] - it blocks the task as a survivor does")) -and -not (Test-Path -LiteralPath $logC) -and (Text $pendC) -ceq $beforeC -and @(Ledger $rcl).Count -eq 0) "exit $($xc1.Code) | $($xc1.First)"
    $xc2 = Consult $rcl '' @('-Prompt', 'x', '-ReplyName', 'c2') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $logC }
    $ec2 = @(Ledger $rcl)[-1]
    Check 'RECORD' 'E19 the same pid with its command line READ (no hook) and not codex-like (-NoProfile -Command Start-Sleep ...; the recorded launcher nowhere on it), not a child of a recorded pid: proven unrelated - "recovered reservation n=2, nn=03 (state ''survivors'' of an interrupted run; unverified pid(s) <n> [start time readable now; pid <n> runs <host>, not codex] dropped; ...)" - and the run goes on (exit 0, a usable reply, the reviewer launched, the record gone)' ($xc2.Code -eq 0 -and $xc2.Out -match ("recovered reservation n=2, nn=03 \(state 'survivors' of an interrupted run; unverified pid\(s\) $($sD.Id) \[start time readable now; pid $($sD.Id) runs $([regex]::Escape($psName)), not codex\] dropped") -and $ec2.bridge_outcome -eq 'usable reply' -and (Test-Path -LiteralPath $logC) -and -not (Test-Path -LiteralPath $pendC)) "exit $($xc2.Code) | $((($xc2.Out -split "`n") | Where-Object { $_ -match 'recovered' }) -join ' // ')"
    Stop-Process -Id $sD.Id -Force -ErrorAction SilentlyContinue
    # the E19 rules in this process: a fresh sleeper (it started after $sinceE)
    $sE = Start-Sleeper; $sleepers.Add($sE)
    $bare = Start-Process -FilePath (Join-Path ([Environment]::SystemDirectory) 'cmd.exe') -PassThru -WindowStyle Hidden
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $bare.Handle } catch { } }
    $sleepers.Add($bare)
    Start-Sleep -Milliseconds 500
    $sinceE = [DateTimeOffset]::UtcNow.AddMinutes(-5)
    $nowhere = 'C:\nowhere\codex.cmd'
    $tRead = Test-UnverifiedProcess -ProcessId $sE.Id -Since $sinceE -Launcher $nowhere
    $tChild = Test-UnverifiedProcess -ProcessId $sE.Id -Since $sinceE -Launcher $nowhere -RecordedPids @(999998, $PID)
    $tBare = Test-UnverifiedProcess -ProcessId $bare.Id -Since $sinceE -Launcher $nowhere
    $env:CODEX_CONSULT_TEST_CMDLINE_UNREADABLE = [string]$sE.Id
    try {
        $tCmdU = Test-UnverifiedProcess -ProcessId $sE.Id -Since $sinceE -Launcher $nowhere
        $tCmdBefore = Test-UnverifiedProcess -ProcessId $sE.Id -Since ([DateTimeOffset]::UtcNow.AddMinutes(5)) -Launcher $nowhere
        $env:CODEX_CONSULT_TEST_MODE = ''
        $tCmdGated = Test-UnverifiedProcess -ProcessId $sE.Id -Since $sinceE -Launcher $nowhere
    } finally { Remove-Item env:CODEX_CONSULT_TEST_CMDLINE_UNREADABLE -ErrorAction SilentlyContinue; $env:CODEX_CONSULT_TEST_MODE = '1' }
    try { Stop-Process -Id $bare.Id -Force -ErrorAction SilentlyContinue } catch { }
    Stop-Process -Id $sE.Id -Force -ErrorAction SilentlyContinue
    $gaps = @((Get-CommandLineGap -Name 'node' -Cmd ''), (Get-CommandLineGap -Name 'node' -Cmd '[node]'), (Get-CommandLineGap -Name 'node.exe' -Cmd '"C:\Program Files\nodejs\node.exe" '), (Get-CommandLineGap -Name 'pwsh' -Cmd 'pwsh'), (Get-CommandLineGap -Name 'node' -Cmd '"C:\Program Files\nodejs\node.exe" C:\x\cli.js'), (Get-CommandLineGap -Name 'notepad' -Cmd 'notepad.exe'))
    Check 'RECORD' 'E19 Test-UnverifiedProcess, started after the run: the command line read and not codex-like - dropped ("..., not codex"); the same process a child of a recorded pid (-RecordedPids) - counted as running; a generic runtime with no arguments (a bare cmd.exe) - counted as running; the command line unreadable - counted as running unless it started before the run (dropped); the hook ignored without test mode. Get-CommandLineGap: empty and "[node]" unreadable, a generic runtime with only its executable "no arguments", with arguments or another program none' (-not $tRead.Alive -and $tRead.How -ceq "start time readable now; pid $($sE.Id) runs $psName, not codex" -and $tChild.Alive -and $tChild.How -ceq "start time readable now; pid $($sE.Id) runs $psName, a child of the recorded pid $PID - counted as running" -and $tBare.Alive -and $tBare.How -ceq "start time readable now; pid $($bare.Id) runs cmd (a generic runtime, no arguments on its command line); command line not readable - counted as running (fail-closed)" -and $tCmdU.Alive -and $tCmdU.How -ceq "start time readable now; pid $($sE.Id) runs $psName; command line not readable - counted as running (fail-closed)" -and -not $tCmdBefore.Alive -and $tCmdBefore.How -match ', before that run: not its process$' -and -not $tCmdGated.Alive -and ($gaps -join '|') -eq 'unreadable|unreadable|no arguments|no arguments||') "$($tRead.How) | $($tChild.How) | $($tBare.How) | $($tCmdU.How) | $($tCmdBefore.How) | gated $($tCmdGated.Alive) | gaps [$($gaps -join '|')]"
    # (wave 28e, E19) the same rule for a SURVIVOR recorded without a start time (Test-RecordedProcess):
    # a sleeper that started after the record, its command line unreadable - then read and not codex-like
    $rsv = New-Repo 'record-survivor'
    $tdS = Join-Path $rsv '.collab\t'
    [void][IO.Directory]::CreateDirectory($tdS)
    $pendS = Join-Path $tdS '.consult.pending.json'
    $startedS = Get-IsoTimestamp
    Start-Sleep -Milliseconds 1500
    $sG = Start-Sleeper; $sleepers.Add($sG)
    [IO.File]::WriteAllText($pendS, '{"state":"survivors","n":2,"nn":"03","reply":"handoffs/03-codex-old.md","events":"","consult_id":"","started":"' + $startedS + '","pid":999998,"host":"' + [Environment]::MachineName + '","launcher":' + (ConvertTo-Json $fake) + ',"engine":"codex","child_pid":null,"child_start_time":"","survivors":[{"pid":' + $sG.Id + ',"start_time":"","name":"' + $psName + '"}],"unverified":[],"note":""}', $u8)
    $beforeS = Text $pendS
    $logS = Join-Path $work 'record-survivor-exec.log'
    $xs1 = Consult $rsv '' @('-Prompt', 'x', '-ReplyName', 's1') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $logS; CODEX_CONSULT_TEST_CMDLINE_UNREADABLE = [string]$sG.Id }
    Check 'RECORD' 'E19 a SURVIVOR recorded without a start time (Test-RecordedProcess), alive, started after the record, its command line NOT readable (CODEX_CONSULT_TEST_CMDLINE_UNREADABLE): the same rule as an unverified pid - REFUSED (exit 1) "a previous consultation''s codex process (pid <n> [start time readable now; pid <n> runs <host>; command line not readable - counted as running (fail-closed)]) is still running"; no reviewer launched, the record untouched' ($xs1.Code -eq 1 -and $xs1.Out -match ([regex]::Escape("a previous consultation's codex process (pid $($sG.Id) [start time readable now; pid $($sG.Id) runs $psName; command line not readable - counted as running (fail-closed)]) is still running")) -and -not (Test-Path -LiteralPath $logS) -and (Text $pendS) -ceq $beforeS -and @(Ledger $rsv).Count -eq 0) "exit $($xs1.Code) | $($xs1.First)"
    $xs2 = Consult $rsv '' @('-Prompt', 'x', '-ReplyName', 's2') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $logS }
    $es2 = @(Ledger $rsv)[-1]
    Check 'RECORD' 'E19 the same survivor with its command line READ (no hook) and not codex-like, not a child of a recorded pid: dropped - "recovered reservation n=2, nn=03 (state ''survivors'' of an interrupted run; codex pid(s) <n> [start time readable now; pid <n> runs <host>, not codex] no longer running; ...)" - and the run goes on (exit 0, a usable reply, the reviewer launched, the record gone)' ($xs2.Code -eq 0 -and $xs2.Out -match ("recovered reservation n=2, nn=03 \(state 'survivors' of an interrupted run; codex pid\(s\) $($sG.Id) \[start time readable now; pid $($sG.Id) runs $([regex]::Escape($psName)), not codex\] no longer running") -and $es2.bridge_outcome -eq 'usable reply' -and (Test-Path -LiteralPath $logS) -and -not (Test-Path -LiteralPath $pendS)) "exit $($xs2.Code) | $((($xs2.Out -split "`n") | Where-Object { $_ -match 'recovered' }) -join ' // ')"
    Stop-Process -Id $sG.Id -Force -ErrorAction SilentlyContinue
    # (wave 28e, E23 / F30-1) an UNCONFIRMED kill that names no pid: the children cannot be enumerated and
    # the tree-kill fallback fails (CODEX_CONSULT_TEST_KILL_DENIED=1 - process inspection and taskkill
    # denied, as in a restricted host); the fake reviewer outlives the kill (an orphan under the killed
    # launcher). In the background, its output in files: an orphan that inherited a pipe would hold a
    # synchronous caller until it exits.
    $rq = New-Repo 'record-unknown'
    $pendQ = Join-Path $rq '.collab\t\.consult.pending.json'
    $pidDirQ = Join-Path $work 'unknown-pids'
    [void][IO.Directory]::CreateDirectory($pidDirQ)
    $bgQ = Start-Bg $rq @('-Prompt', 'x', '-ReplyName', 'q1', '-TimeoutSec', '4') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_PIDDIR = $pidDirQ; CODEX_CONSULT_TEST_KILL_DENIED = '1' }
    $xq1 = Wait-Bg $bgQ
    $orphQ = @(Get-ChildItem -LiteralPath $pidDirQ -Filter '*.pid' -ErrorAction SilentlyContinue | ForEach-Object { [int]$_.BaseName } | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue })
    foreach ($o in $orphQ) { $po = Get-Process -Id $o -ErrorAction SilentlyContinue; if ($po) { $sleepers.Add($po) } }
    $textQ = Text $pendQ
    $recQ = $null; try { $recQ = ConvertFrom-Json $textQ } catch { }
    $startedQ = $(if ($textQ -match '"started":\s*"([^"]+)"') { $Matches[1] } else { '?' })
    $eq1 = @(Ledger $rq)[-1]
    Check 'RECORD' 'E23 (F30-1) a timeout kill NOT confirmed that names no pid (enumeration and taskkill denied: CODEX_CONSULT_TEST_KILL_DENIED=1; the fake reviewer still runs, an orphan): the recovery record is KEPT - state survivors, survivors [], unverified [], kill_unconfirmed "the children could not be enumerated (...) ..." ("recovery record kept: ... (state ''survivors'')"); the outcome as before "(kill not confirmed: ...; pid <n> may still run)"' ($xq1.Code -eq 1 -and $recQ -and $recQ.state -eq 'survivors' -and @($recQ.survivors).Count -eq 0 -and @($recQ.unverified).Count -eq 0 -and [string]$recQ.kill_unconfirmed -match '^the children could not be enumerated \(process inspection denied \(test hook CODEX_CONSULT_TEST_KILL_DENIED\)\)' -and [string]$eq1.bridge_outcome -match '^failed: timeout after 4 s \(kill not confirmed: the children could not be enumerated .*; pid \d+ may still run\)$' -and $xq1.Out -match "recovery record kept: .*\(state 'survivors'\)" -and $orphQ.Count -ge 1) "exit $($xq1.Code) | kill_unconfirmed '$(if ($recQ) { $recQ.kill_unconfirmed })' | outcome $($eq1.bridge_outcome) | orphans [$($orphQ -join ',')]"
    $lsQ = Run-InRepo $rq $findingsPs @('-Task', 't', '-List')
    $logQ = Join-Path $work 'record-unknown-exec.log'
    $xq2 = Consult $rq '' @('-Prompt', 'x', '-ReplyName', 'q2') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $logQ }
    $orph1 = $(if ($orphQ.Count -gt 0) { $orphQ[0] } else { 0 })
    $childQ = $(if ($recQ) { [int]$recQ.child_pid } else { 0 })
    Check 'RECORD' 'E23 the next run while the orphan runs: the scan by parent pid (the recorded bridge, then the recorded child - Windows keeps an orphan''s parent id) finds it - REFUSED (exit 1) "an interrupted consultation (...) left an UNKNOWN process tree - the kill of its codex run was not confirmed (...) - and a codex-like process of it may still run: pid <orphan> powershell.exe [child of the interrupted bridge (ppid <child>)], found by ..."; no reviewer launched, the record untouched; codex-findings -List names the record and why' ($xq2.Code -eq 1 -and $xq2.Out -match 'left an UNKNOWN process tree - the kill of its codex run was not confirmed \(the children could not be enumerated ' -and $xq2.Out -match "a codex-like process of it may still run: pid $orph1 \S+ \[child of the interrupted bridge \(ppid $childQ\)\]" -and -not (Test-Path -LiteralPath $logQ) -and (Text $pendQ) -ceq $textQ -and $lsQ -match 'pending: state=survivors, .*; the kill of that run was not confirmed \(the children could not be enumerated .*: its process tree is unknown') "exit $($xq2.Code) | $($xq2.First) | list: $((($lsQ -split "`n") | Where-Object { $_ -match '^pending' }) -join ' // ')"
    foreach ($o in $orphQ) { try { Stop-Process -Id $o -Force -ErrorAction SilentlyContinue } catch { } }
    foreach ($o in $orphQ) { try { $po = Get-Process -Id $o -ErrorAction SilentlyContinue; if ($po) { $null = $po.WaitForExit(10000) } } catch { } }
    $xq3 = Consult $rq '' @('-Prompt', 'x', '-ReplyName', 'q3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $logQ }
    $eq3 = @(Ledger $rq)[-1]
    $writerQ = $(if ($recQ) { [int]$recQ.pid } else { 0 })
    Check 'RECORD' 'E23 once the orphan is gone the scan runs clean: the record is RELEASED - "cleared the recovery record of consult n=1, nn=01 (state ''survivors''; ... unknown tree after an unconfirmed kill: the scan found no codex-like process under pid <bridge>, <child> since <started> - released (...))" - and the run goes on (exit 0, a usable reply, the reviewer launched, the record gone)' ($xq3.Code -eq 0 -and $xq3.Out -match ("cleared the recovery record of consult n=1, nn=01 \(state 'survivors'; .*unknown tree after an unconfirmed kill: the scan found no codex-like process under pid $writerQ, $childQ since " + [regex]::Escape($startedQ) + ' - released \(') -and $eq3.bridge_outcome -eq 'usable reply' -and (Test-Path -LiteralPath $logQ) -and -not (Test-Path -LiteralPath $pendQ)) "exit $($xq3.Code) | $((($xq3.Out -split "`n") | Where-Object { $_ -match 'recovery record|recovered' }) -join ' // ')"
    # outside Windows (no scan by parent pid) and from another host: refused - only the operator releases it
    $recNw = [pscustomobject]@{ state = 'survivors'; n = 1; nn = '02'; reply = 'r'; started = (Get-IsoTimestamp); pid = 999998; host = [Environment]::MachineName; launcher = ''; child_pid = $null; child_start_time = ''; survivors = [object[]]@(); unverified = [object[]]@(); kill_unconfirmed = 'the children could not be enumerated (test)'; note = '' }
    $savedOnWindows = $script:OnWindows
    $script:OnWindows = $false
    try { $vNw = Test-PendingActive -Record $recNw -Path 'C:\r\.collab\t\.consult.pending.json' } finally { $script:OnWindows = $savedOnWindows }
    $recOh = [pscustomobject]@{ state = 'survivors'; n = 1; nn = '02'; reply = 'r'; started = (Get-IsoTimestamp); pid = 999998; host = 'OTHER-HOST-28E'; launcher = ''; child_pid = $null; child_start_time = ''; survivors = [object[]]@(); unverified = [object[]]@(); kill_unconfirmed = 'the children could not be enumerated (test)'; note = '' }
    $vOh = Test-PendingActive -Record $recOh -Path 'x.json'
    $kw = @((Get-KillUnconfirmedWhy -Check ([pscustomobject]@{ Confirmed = $false; Why = 'w1'; Survivors = [int[]]@(); Unverified = [int[]]@() })), (Get-KillUnconfirmedWhy -Check ([pscustomobject]@{ Confirmed = $true; Why = ''; Survivors = [int[]]@(); Unverified = [int[]]@() })), (Get-KillUnconfirmedWhy -Check ([pscustomobject]@{ Confirmed = $false; Why = 'w2'; Survivors = [int[]]@(5); Unverified = [int[]]@() })), (Get-KillUnconfirmedWhy -Check ([pscustomobject]@{ Confirmed = $false; Why = 'w3'; Survivors = [int[]]@(); Unverified = [int[]]@(6) })), (Get-KillUnconfirmedWhy -Check ([pscustomobject]@{ Confirmed = $false; Why = ''; Survivors = [int[]]@(); Unverified = [int[]]@() })))
    Check 'RECORD' 'E23 outside Windows (no scan by parent pid) such a record is REFUSED - released only by the operator: "... left an UNKNOWN process tree - the kill of its codex run was not confirmed (...) - and this host cannot scan for its processes by parent pid (...). Make sure no codex process of that run still runs, then delete <record> to release it."; from another host likewise; Get-KillUnconfirmedWhy: the why only for an unconfirmed kill with neither survivors nor unverified pids' ($vNw.Active -and $vNw.Message -match 'left an UNKNOWN process tree - the kill of its codex run was not confirmed \(the children could not be enumerated \(test\)\) - and this host cannot scan for its processes by parent pid' -and $vNw.Message.Contains('then delete C:\r\.collab\t\.consult.pending.json to release it.') -and $vOh.Active -and $vOh.Message -match 'on host OTHER-HOST-28E .*left an UNKNOWN process tree' -and ($kw -join '|') -eq 'w1||||the kill was not confirmed') "$($vNw.Message) | $($vOh.Message) | [$($kw -join '|')]"
    Check 'RECORD' 'E18, E23 the code: the three places keep the record (state survivors) for survivors OR unverified pids OR (E23) an unconfirmed kill with neither (Get-KillUnconfirmedWhy - kill_unconfirmed) - a turn, the main turn, the format repair; the main turn''s outcome says the refusal for the unverified group too' ($cs.Contains("if (`$surv.Count -gt 0 -or @(Get-PropertyValue `$turnKill 'Unverified' @()).Count -gt 0 -or `$turnUnconfirmed)") -and $cs.Contains("if (`$survivors.Count -gt 0 -or `$mainUnverified.Count -gt 0 -or `$mainUnconfirmed)") -and $cs.Contains("if (`$repairSurvivors.Count -gt 0 -or @(Get-PropertyValue `$repairKill 'Unverified' @()).Count -gt 0 -or `$repairUnconfirmed)") -and ([regex]::Matches($cs, [regex]::Escape("Add-Member -NotePropertyName 'kill_unconfirmed'"))).Count -eq 3 -and $cs.Contains('may still run; the next run for this task is refused until')) ''
}

# =============================================================== NOTSPOOLED: one file per producer, folded (E2)
if (Want 'NOTSPOOLED') {
    $h = New-Home 'ns'
    $env:CODEX_HOME = $h
    $own = (Get-TelemetryPaths).NotSpooledOwn
    $ownTicks = Get-ProcessStartTicks -ProcessId $PID
    $w1 = Add-TelemetryNotSpooled -Why 'own-1'
    # a producer that is gone, a pid now held by another process (this one, with another start), the
    # legacy single file of an older version, and a name that is not one of them
    $goneF = Join-Path $h 'telemetry-not-spooled-999999-639000000000000000.ndjson'
    [IO.File]::WriteAllText($goneF, '{"time":"2026-10-01T10:00:00+02:00","why":"gone-1"}' + "`n" + '{"time":"2026-10-01T10:01:00+02:00","why":"gone-2"}' + "`n", $u8)
    $reuseF = Join-Path $h "telemetry-not-spooled-$PID-$($ownTicks - 10000000).ndjson"
    [IO.File]::WriteAllText($reuseF, '{"time":"2026-10-02T10:00:00+02:00","why":"reused-1"}' + "`n" + '{"time":"2026-10-02T10:01:00+02:00","why":"half', $u8)
    $legacyF = Join-Path $h 'telemetry-not-spooled.ndjson'
    [IO.File]::WriteAllText($legacyF, '{"time":"2026-09-01T10:00:00+02:00","why":"legacy-1"}' + "`n" + '{"time":"2026-09-01T10:01:00+02:00","why":"legacy-2"}' + "`n" + '{"time":"2026-09-01T10:02:00+02:00","why":"legacy-3"}' + "`n", $u8)
    $oddF = Join-Path $h 'telemetry-not-spooled-notes.ndjson'
    [IO.File]::WriteAllText($oddF, '{"time":"2026-10-03T10:00:00+02:00","why":"not a count"}' + "`n", $u8)
    $n1 = Get-TelemetryNotSpooled
    $st1 = Run-Child $telemetryPs @('-Status') $h
    Check 'NOTSPOOLED' 'E2 (F54-2) the count goes to THIS producer''s own file telemetry-not-spooled-<pid>-<start ticks>.ndjson (its pid and its start time in ticks; Add-TelemetryNotSpooled returns '''' - written)' ($w1 -eq '' -and [IO.Path]::GetFileName($own) -ceq "telemetry-not-spooled-$PID-$ownTicks.ndjson" -and (Lines $own).Count -eq 1 -and (Text $own) -match '"why":"own-1"') "returned '$w1' | $([IO.Path]::GetFileName($own))"
    Check 'NOTSPOOLED' 'E2 -Status SUMS every producer''s file and the legacy single file (complete lines: 1 + 2 + 1 + 3 = 7; a partial last line and a name that is not a producer''s are not counted): "not spooled: 7 event(s) since the last flush - the latest <t>: own-1 (7 line(s) in 4 file(s), one per producer ...)"' ($n1.Count -eq 7 -and $n1.Total -eq 7 -and $n1.Files -eq 4 -and $n1.Last -eq 'own-1' -and $st1.Code -eq 0 -and $st1.Out -match '(?m)^not spooled: 7 event\(s\) since the last flush - the latest \S+: own-1 \(7 line\(s\) in 4 file\(s\), one per producer') "count $($n1.Count) total $($n1.Total) files $($n1.Files) last '$($n1.Last)' | $(StatusLine $st1.Out 'not spooled')"
    $sd = Join-Path $h 'telemetry-spool'
    [void][IO.Directory]::CreateDirectory($sd)
    $fl = Invoke-TelemetryFlush -FlushMs 20000
    $last = ConvertFrom-Json (Text (Join-Path $sd '.last'))
    $notes1 = LastNotes $h
    $n2 = Get-TelemetryNotSpooled
    $st2 = Run-Child $telemetryPs @('-Status') $h
    Check 'NOTSPOOLED' 'E2 (F53-1) a flush FOLDS the files of gone producers - pid 999999, the reused pid (this pid with another start), the legacy file - into ONE line of .last notes ("folded 7 not-spooled line(s) of 3 gone producer(s)": a gone producer''s last line without a line end counts too) and removes them; the live producer''s file (this process) and the foreign name stay; .last not_spooled_seen 1 (the lines kept)' ($fl.Exit -eq 0 -and [int]$last.not_spooled_seen -eq 1 -and @($notes1 | Where-Object { $_ -match '^\S+ folded \d+ not-spooled' }).Count -eq 1 -and @($notes1 | Where-Object { $_ -match '^\S+ folded 7 not-spooled line\(s\) of 3 gone producer\(s\)$' }).Count -eq 1 -and (NsNames $h) -ceq ((@([IO.Path]::GetFileName($own), 'telemetry-not-spooled-notes.ndjson') | Sort-Object) -join ',')) "exit $($fl.Exit) $($fl.Result) | seen $($last.not_spooled_seen) | notes $($notes1 -join ' // ') | left $(NsNames $h)"
    Check 'NOTSPOOLED' 'E2 after the fold nothing counts as since the last flush: -Status "not spooled: none since the last flush (1 line(s) in 1 file(s), ...)" and shows the fold as a note' ($n2.Count -eq 0 -and $n2.Total -eq 1 -and $st2.Out -match '(?m)^not spooled: none since the last flush \(1 line\(s\) in 1 file\(s\)' -and $st2.Out -match '(?m)^note       : \S+ folded 7 not-spooled line\(s\) of 3 gone producer\(s\)$') "$(StatusLine $st2.Out 'not spooled') // $(StatusLine $st2.Out 'note')"
    $null = Add-TelemetryNotSpooled -Why 'own-2'
    $n3 = Get-TelemetryNotSpooled
    $fl2 = Invoke-TelemetryFlush -FlushMs 20000
    $last2 = ConvertFrom-Json (Text (Join-Path $sd '.last'))
    $notes2 = LastNotes $h
    $n4 = Get-TelemetryNotSpooled
    Check 'NOTSPOOLED' 'E2 a line the live producer adds after the flush counts 1 (the latest: own-2); the next flush folds nothing (no new note - one fold line in all), keeps the file (2 lines) and records not_spooled_seen 2: none since' ($n3.Count -eq 1 -and $n3.Last -eq 'own-2' -and $fl2.Exit -eq 0 -and [int]$last2.not_spooled_seen -eq 2 -and @($notes2 | Where-Object { $_ -match ' folded \d+ not-spooled' }).Count -eq 1 -and (Lines $own).Count -eq 2 -and $n4.Count -eq 0 -and $n4.Total -eq 2) "after add $($n3.Count) '$($n3.Last)' | seen $($last2.not_spooled_seen) | notes $($notes2 -join ' // ')"
    # two producers append at the same moment (a barrier): each to its own file - nothing waits, nothing is lost
    $raceDir = Join-Path $work 'ns-race'
    [void][IO.Directory]::CreateDirectory($raceDir)
    $racePs = Join-Path $work 'ns-race-child.ps1'
    [IO.File]::WriteAllText($racePs, @'
param([string]$Common, [string]$Dir, [string]$Id, [int]$N)
. $Common
[IO.File]::WriteAllText((Join-Path $Dir "ready-$Id"), 'r')
$w = [Diagnostics.Stopwatch]::StartNew()
while (-not (Test-Path -LiteralPath (Join-Path $Dir 'go')) -and $w.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 5 }
$bad = 0
for ($i = 1; $i -le $N; $i++) { if (Add-TelemetryNotSpooled -Why "child $Id line $i") { $bad++ } }
[IO.File]::WriteAllText((Join-Path $Dir "result-$Id"), ([IO.Path]::GetFileName((Get-TelemetryPaths).NotSpooledOwn) + '|' + $bad + '|' + $PID))
exit 0
'@, $u8)
    $procs = @(foreach ($i in 1..2) {
            $pr = Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$racePs`"", "`"$commonPs`"", "`"$raceDir`"", "$i", '40') -PassThru -WindowStyle Hidden
            if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $pr.Handle } catch { } }
            $pr
        })
    $wr = [Diagnostics.Stopwatch]::StartNew()
    while (@(Get-ChildItem -LiteralPath $raceDir -Filter 'ready-*').Count -lt 2 -and $wr.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 100 }
    [IO.File]::WriteAllText((Join-Path $raceDir 'go'), 'go', $u8)
    foreach ($pr in $procs) { if (-not $pr.WaitForExit(60000)) { try { $pr.Kill() } catch { } } }
    $res = @(foreach ($i in 1..2) { (Text (Join-Path $raceDir "result-$i")).Trim() })
    $childFiles = @($res | ForEach-Object { ($_ -split '\|')[0] })
    $childBad = @($res | ForEach-Object { ($_ -split '\|')[1] })
    $childPids = @($res | ForEach-Object { ($_ -split '\|')[2] })
    $perFile = @($childFiles | ForEach-Object { if ($_) { (Lines (Join-Path $h $_)).Count } else { -1 } })
    $n5 = Get-TelemetryNotSpooled
    Check 'NOTSPOOLED' 'E2 two producer processes appending 40 lines each at the same moment (a barrier): two files, each named by its own pid, 40 lines each, no append failed; -Status''s sum 2 + 80' ($res.Count -eq 2 -and $childFiles[0] -ne $childFiles[1] -and $childFiles[0] -match "^telemetry-not-spooled-$($childPids[0])-\d+\.ndjson$" -and $childFiles[1] -match "^telemetry-not-spooled-$($childPids[1])-\d+\.ndjson$" -and ($perFile -join ',') -eq '40,40' -and ($childBad -join ',') -eq '0,0' -and $n5.Total -eq 82 -and $n5.Count -eq 80) "results [$($res -join ' ; ')] | per file $($perFile -join ',') | total $($n5.Total) count $($n5.Count)"
    $fl3 = Invoke-TelemetryFlush -FlushMs 20000
    $notes3 = LastNotes $h
    Check 'NOTSPOOLED' 'E2 once both producers have exited, the next flush folds their files ("folded 80 not-spooled line(s) of 2 gone producer(s)") and removes them' ($fl3.Exit -eq 0 -and @($notes3 | Where-Object { $_ -match '^\S+ folded 80 not-spooled line\(s\) of 2 gone producer\(s\)$' }).Count -eq 1 -and -not (Test-Path -LiteralPath (Join-Path $h $childFiles[0])) -and -not (Test-Path -LiteralPath (Join-Path $h $childFiles[1])) -and (Get-TelemetryNotSpooled).Count -eq 0) "notes $($notes3 -join ' // ') | left $(NsNames $h)"
    # -Forget -Local: every producer's file (a live one too) and the legacy file
    [IO.File]::WriteAllText($legacyF, '{"time":"2026-09-01T10:00:00+02:00","why":"legacy-again"}' + "`n", $u8)
    [IO.File]::WriteAllText($goneF, '{"time":"2026-10-01T10:00:00+02:00","why":"gone-again"}' + "`n", $u8)
    $fg = Run-Child $telemetryPs @('-Forget', '-Local', '-Yes') $h
    Check 'NOTSPOOLED' 'E2 -Forget -Local -Yes removes EVERY not-spooled file - this live producer''s, a gone one''s, the legacy file (named in "removed locally - ...") - and leaves a foreign name alone' ($fg.Code -eq 0 -and $fg.Out -match 'removed locally - ' -and $fg.Out.Contains([IO.Path]::GetFileName($own)) -and $fg.Out.Contains('telemetry-not-spooled.ndjson') -and $fg.Out.Contains([IO.Path]::GetFileName($goneF)) -and (NsNames $h) -ceq 'telemetry-not-spooled-notes.ndjson') "exit $($fg.Code) | left $(NsNames $h) | $($fg.Out)"
    # (wave 28e, E20 / F27-3) .last FIRST, then the deletes: a crash between the two, and a .last that
    # cannot be written
    $hf = New-Home 'fold'
    $env:CODEX_HOME = $hf
    $null = Add-TelemetryNotSpooled -Why 'live-1'
    $null = Add-TelemetryNotSpooled -Why 'live-2'
    $sdf = Join-Path $hf 'telemetry-spool'
    [void][IO.Directory]::CreateDirectory($sdf)
    $lastF = Join-Path $sdf '.last'
    $flA = Invoke-TelemetryFlush -FlushMs 20000
    $seenA = -1; try { $seenA = [int](ConvertFrom-Json (Text $lastF)).not_spooled_seen } catch { }
    $goneA = Join-Path $hf 'telemetry-not-spooled-999999-639000000000000001.ndjson'
    [IO.File]::WriteAllText($goneA, '{"time":"2026-10-07T10:00:00+02:00","why":"gone-a1"}' + "`n" + '{"time":"2026-10-07T10:01:00+02:00","why":"gone-a2"}' + "`n" + '{"time":"2026-10-07T10:02:00+02:00","why":"gone-a3"}' + "`n", $u8)
    $legacyA = Join-Path $hf 'telemetry-not-spooled.ndjson'
    [IO.File]::WriteAllText($legacyA, '{"time":"2026-09-01T10:00:00+02:00","why":"legacy-a1"}' + "`n" + '{"time":"2026-09-01T10:01:00+02:00","why":"legacy-a2"}' + "`n", $u8)
    $nA = Get-TelemetryNotSpooled
    $crashF = Run-Child $telemetryPs @('-Flush', '-Telemetry', 'on') $hf @{ CODEX_CONSULT_TEST_FOLD_CRASH = '1' }
    $lastC = $null; try { $lastC = ConvertFrom-Json (Text $lastF) } catch { }
    $notesC = LastNotes $hf
    $foldLinesC = @($notesC | Where-Object { $_ -match ' folded \d+ not-spooled' })
    $nC = Get-TelemetryNotSpooled
    $stC = Run-Child $telemetryPs @('-Status') $hf
    $namesA = (@("$([IO.Path]::GetFileName($goneA))=$((Get-Item -LiteralPath $goneA).Length)", "telemetry-not-spooled.ndjson=$((Get-Item -LiteralPath $legacyA).Length)") | Sort-Object) -join ','
    Check 'NOTSPOOLED' 'E20 (F27-3) a nonzero baseline (not_spooled_seen 2: this live producer''s two lines), two gone producers'' files (999999: 3 lines, the legacy file: 2 - 5 since the last flush), and a crash BETWEEN the save of .last and the deletes (test hook CODEX_CONSULT_TEST_FOLD_CRASH=1: the -Flush child exits 87 there): .last is SAVED - one note "folded 5 not-spooled line(s) of 2 gone producer(s)", not_spooled_seen 2, not_spooled_folded [both files as {name, bytes} - (E24) their lengths at the save] - and both files are still there' ($flA.Exit -eq 0 -and $seenA -eq 2 -and $nA.Count -eq 5 -and $crashF.Code -eq 87 -and $lastC -and [int]$lastC.not_spooled_seen -eq 2 -and ((@($lastC.not_spooled_folded | ForEach-Object { "$($_.name)=$($_.bytes)" }) | Sort-Object) -join ',') -eq $namesA -and $foldLinesC.Count -eq 1 -and $foldLinesC[0] -match '^\S+ folded 5 not-spooled line\(s\) of 2 gone producer\(s\)$' -and (Test-Path -LiteralPath $goneA) -and (Test-Path -LiteralPath $legacyA)) "baseline $seenA | before $($nA.Count) | exit $($crashF.Code) | folded [$(@($lastC.not_spooled_folded | ForEach-Object { "$($_.name)=$($_.bytes)" }) -join ',')] seen $($lastC.not_spooled_seen) | notes $($notesC -join ' // ')"
    Check 'NOTSPOOLED' 'E20 meanwhile -Status leaves out the files .last names (their lines are in the note): "not spooled: none since the last flush (2 line(s) in 1 file(s), ...)"' ($nC.Count -eq 0 -and $nC.Total -eq 2 -and $nC.Files -eq 1 -and $stC.Out -match '(?m)^not spooled: none since the last flush \(2 line\(s\) in 1 file\(s\)') "$(StatusLine $stC.Out 'not spooled')"
    $restart = Run-Child $telemetryPs @('-Flush', '-Telemetry', 'on') $hf
    $lastR = $null; try { $lastR = ConvertFrom-Json (Text $lastF) } catch { }
    $notesR = LastNotes $hf
    $foldLinesR = @($notesR | Where-Object { $_ -match ' folded \d+ not-spooled' })
    $null = Add-TelemetryNotSpooled -Why 'live-3'
    $stR = Run-Child $telemetryPs @('-Status') $hf
    Check 'NOTSPOOLED' 'E20 the restarted flush DELETES the files .last names WITHOUT counting them again: both gone, the folded note kept ONCE (the same line, no new fold note), not_spooled_seen 2, not_spooled_folded [] (a name leaves once its file is gone); one line appended after it: "not spooled: 1 event(s) since the last flush - the latest <t>: live-3 (3 line(s) in 1 file(s), ..."' ($restart.Code -eq 0 -and -not (Test-Path -LiteralPath $goneA) -and -not (Test-Path -LiteralPath $legacyA) -and $lastR -and [int]$lastR.not_spooled_seen -eq 2 -and $null -ne $lastR.PSObject.Properties['not_spooled_folded'] -and @($lastR.not_spooled_folded | Where-Object { $_ }).Count -eq 0 -and $foldLinesR.Count -eq 1 -and $foldLinesC.Count -eq 1 -and $foldLinesR[0] -ceq $foldLinesC[0] -and $stR.Out -match '(?m)^not spooled: 1 event\(s\) since the last flush - the latest \S+: live-3 \(3 line\(s\) in 1 file\(s\)') "exit $($restart.Code) $($restart.Out) | folded [$(@($lastR.not_spooled_folded) -join ',')] seen $($lastR.not_spooled_seen) | notes $($notesR -join ' // ') | $(StatusLine $stR.Out 'not spooled')"
    $goneB = Join-Path $hf 'telemetry-not-spooled-999999-639000000000000002.ndjson'
    [IO.File]::WriteAllText($goneB, '{"time":"2026-10-07T11:00:00+02:00","why":"gone-b1"}' + "`n" + '{"time":"2026-10-07T11:01:00+02:00","why":"gone-b2"}' + "`n", $u8)
    $beforeW = Text $lastF
    $nW0 = Get-TelemetryNotSpooled
    [IO.File]::SetAttributes($lastF, [IO.FileAttributes]::ReadOnly)
    try { $flW = Invoke-TelemetryFlush -FlushMs 20000 } finally { [IO.File]::SetAttributes($lastF, [IO.FileAttributes]::Normal) }
    $nW = Get-TelemetryNotSpooled
    Check 'NOTSPOOLED' 'E20 a .last that cannot be written (made read-only): the flush folds NOTHING - the gone producer''s file stays, .last is byte-identical (the old baseline, no new note), "since the last flush" still 3 (1 + 2) - and its result carries the warning "; warning: <spool>/.last could not be written (...) - nothing was folded: the not-spooled files and the last baseline stay, the next flush counts them"' ($nW0.Count -eq 3 -and [string]$flW.Result -match ('; warning: ' + [regex]::Escape($lastF) + ' could not be written \(.+\) - nothing was folded: the not-spooled files and the last baseline stay, the next flush counts them$') -and (Test-Path -LiteralPath $goneB) -and (Text $lastF) -ceq $beforeW -and $nW.Count -eq 3 -and $nW.Total -eq 5) "before $($nW0.Count) | $($flW.Result) | after $($nW.Count)/$($nW.Total)"
    $flOk = Invoke-TelemetryFlush -FlushMs 20000
    $notesOk = LastNotes $hf
    $nOk = Get-TelemetryNotSpooled
    $seenOk = -1; try { $seenOk = [int](ConvertFrom-Json (Text $lastF)).not_spooled_seen } catch { }
    Check 'NOTSPOOLED' 'E20 writable again, the next flush folds it ("folded 2 not-spooled line(s) of 1 gone producer(s)", the file gone, not_spooled_seen 3): none since the last flush' ($flOk.Exit -eq 0 -and [string]$flOk.Result -notmatch 'warning' -and -not (Test-Path -LiteralPath $goneB) -and @($notesOk | Where-Object { $_ -match '^\S+ folded 2 not-spooled line\(s\) of 1 gone producer\(s\)$' }).Count -eq 1 -and $seenOk -eq 3 -and $nOk.Count -eq 0) "$($flOk.Result) | seen $seenOk | notes $($notesOk -join ' // ')"
    # (wave 28e, E24 / F30-2) not_spooled_folded[] holds {name, bytes}: a legacy line an older bridge
    # appends AFTER the crash (before the restarted flush) is counted exactly once
    $hg = New-Home 'fold2'
    $env:CODEX_HOME = $hg
    $null = Add-TelemetryNotSpooled -Why 'live-g1'
    $sdg = Join-Path $hg 'telemetry-spool'
    [void][IO.Directory]::CreateDirectory($sdg)
    $lastG = Join-Path $sdg '.last'
    $flG = Invoke-TelemetryFlush -FlushMs 20000
    $legacyG = Join-Path $hg 'telemetry-not-spooled.ndjson'
    [IO.File]::WriteAllText($legacyG, '{"time":"2026-09-02T10:00:00+02:00","why":"legacy-g1"}' + "`n" + '{"time":"2026-09-02T10:01:00+02:00","why":"legacy-g2"}' + "`n", $u8)
    $lenG = (Get-Item -LiteralPath $legacyG).Length
    $crashG = Run-Child $telemetryPs @('-Flush', '-Telemetry', 'on') $hg @{ CODEX_CONSULT_TEST_FOLD_CRASH = '1' }
    $lastGC = $null; try { $lastGC = ConvertFrom-Json (Text $lastG) } catch { }
    $entG = @($(if ($lastGC) { $lastGC.not_spooled_folded } else { @() }) | Where-Object { $_ })
    # an older bridge appends one more line to the legacy file
    [IO.File]::AppendAllText($legacyG, '{"time":"' + (Get-IsoTimestamp ((Get-Date).AddMinutes(1))) + '","why":"legacy-g3 after the crash"}' + "`n", $u8)
    $nG = Get-TelemetryNotSpooled
    Check 'NOTSPOOLED' 'E24 (F30-2) the crash replay with a legacy line appended between the crash (exit 87) and the restarted flush: .last named the legacy file WITH its length at the save ({name, bytes}: the 2 lines folded), and meanwhile -Status counts exactly the appended line ("since the last flush" 1, the latest legacy-g3 ...)' ($flG.Exit -eq 0 -and $crashG.Code -eq 87 -and $entG.Count -eq 1 -and [string]$entG[0].name -eq 'telemetry-not-spooled.ndjson' -and [long]$entG[0].bytes -eq $lenG -and $nG.Count -eq 1 -and $nG.Last -eq 'legacy-g3 after the crash') "exit $($crashG.Code) | entries $(ConvertTo-Json -Compress -InputObject $entG) (length at the save $lenG) | count $($nG.Count) '$($nG.Last)'"
    $restartG = Run-Child $telemetryPs @('-Flush', '-Telemetry', 'on') $hg
    $lastGR = $null; try { $lastGR = ConvertFrom-Json (Text $lastG) } catch { }
    $notesG = LastNotes $hg
    $nG2 = Get-TelemetryNotSpooled
    Check 'NOTSPOOLED' 'E24 the restarted flush counts that line EXACTLY ONCE: the original note "folded 2 not-spooled line(s) of 1 gone producer(s)" unchanged (once), one new note "folded 1 not-spooled line(s) of 1 gone producer(s)" (the tail beyond the recorded bytes), the file gone, not_spooled_folded [], not_spooled_seen 1, none since the last flush' ($restartG.Code -eq 0 -and -not (Test-Path -LiteralPath $legacyG) -and @($notesG | Where-Object { $_ -match '^\S+ folded 2 not-spooled line\(s\) of 1 gone producer\(s\)$' }).Count -eq 1 -and @($notesG | Where-Object { $_ -match '^\S+ folded 1 not-spooled line\(s\) of 1 gone producer\(s\)$' }).Count -eq 1 -and @($notesG | Where-Object { $_ -match ' folded \d+ not-spooled' }).Count -eq 2 -and $lastGR -and $null -ne $lastGR.PSObject.Properties['not_spooled_folded'] -and @($lastGR.not_spooled_folded | Where-Object { $_ }).Count -eq 0 -and [int]$lastGR.not_spooled_seen -eq 1 -and $nG2.Count -eq 0) "exit $($restartG.Code) | notes $($notesG -join ' // ') | folded [$(ConvertTo-Json -Compress -InputObject @($lastGR.not_spooled_folded))] seen $($lastGR.not_spooled_seen) | count $($nG2.Count)"
    # a name whose recorded bytes are MORE than its file holds (another file under that name), and a bare
    # name of the E20 build (bytes unknown)
    $mkLast = { param($Folded) Write-JsonFile -Path $lastG -Object ([pscustomobject]@{ time = (Get-IsoTimestamp); result = 'seeded'; delivered = 0; kept = 0; dropped = 0; rejected = [object[]]@(); http = $null; not_spooled_seen = 1; not_spooled_folded = [object[]]$Folded; notes = [object[]]@() }) }
    [IO.File]::WriteAllText($legacyG, '{"time":"2026-09-03T10:00:00+02:00","why":"legacy-new"}' + "`n", $u8)
    & $mkLast @([pscustomobject]@{ name = 'telemetry-not-spooled.ndjson'; bytes = 99999 })
    $nS = Get-TelemetryNotSpooled
    $flS = Invoke-TelemetryFlush -FlushMs 20000
    $notesS = LastNotes $hg
    [IO.File]::WriteAllText($legacyG, '{"time":"2026-09-04T10:00:00+02:00","why":"legacy-bare"}' + "`n", $u8)
    & $mkLast @('telemetry-not-spooled.ndjson')
    $nB = Get-TelemetryNotSpooled
    $flB = Invoke-TelemetryFlush -FlushMs 20000
    $notesB = LastNotes $hg
    Check 'NOTSPOOLED' 'E24 a named file SHORTER than its recorded bytes is another file under that name: -Status counts it whole (1) and the flush folds it afresh ("folded 1 not-spooled line(s) of 1 gone producer(s)"); a bare name of the E20 build (bytes unknown): counted nothing, deleted without a note' ($nS.Count -eq 1 -and $flS.Exit -eq 0 -and @($notesS | Where-Object { $_ -match '^\S+ folded 1 not-spooled line\(s\) of 1 gone producer\(s\)$' }).Count -eq 1 -and $nB.Count -eq 0 -and $flB.Exit -eq 0 -and @($notesB | Where-Object { $_ -match ' folded \d+ not-spooled' }).Count -eq 0 -and -not (Test-Path -LiteralPath $legacyG)) "shorter: count $($nS.Count), notes $($notesS -join ' // ') | bare: count $($nB.Count), notes $($notesB -join ' // '), file left $(Test-Path -LiteralPath $legacyG)"
    $env:CODEX_HOME = $savedCodexHome
    $cm = Text $commonPs
    $fnN = $(if ($cm -match '(?s)\nfunction Add-TelemetryNotSpooled \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    $fnF = $(if ($cm -match '(?s)\nfunction Invoke-TelemetryFlush \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    Check 'NOTSPOOLED' 'E2 the code: Add-TelemetryNotSpooled appends to this process''s own file (NotSpooledOwn) and takes no lock; the flush folds (Merge-TelemetryNotSpooled) only while it holds the telemetry lock' ($fnN -and $fnN -notmatch 'Enter-TelemetryLock' -and $fnN.Contains('AppendAllText($p.NotSpooledOwn') -and $fnF -match '(?s)if \(\$lkLast\.Ok\) \{\s*\$fold = Merge-TelemetryNotSpooled') ''
    $fnM = $(if ($cm -match '(?s)\nfunction Merge-TelemetryNotSpooled \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    Check 'NOTSPOOLED' 'E20 the code: Merge-TelemetryNotSpooled deletes nothing (it counts and holds the files open); the flush saves .last (Write-JsonFile ... $lastNew) BEFORE Complete-TelemetryNotSpooledFold -Delete, with the crash hook between the two read through Get-TestHookValue (test mode only)' ($fnM -and $fnM -notmatch '\[IO\.File\]::Delete' -and $fnF -match "(?s)Write-JsonFile -Path \`$p\.Last -Object \`$lastNew.*Get-TestHookValue 'CODEX_CONSULT_TEST_FOLD_CRASH'.*Complete-TelemetryNotSpooledFold -Fold \`$fold -Delete") ''
}

# =============================================================== MARKER: the owner on pid and ticks (E3)
if (Want 'MARKER') {
    $h = New-Home 'marker'
    $env:CODEX_HOME = $h
    $mk = Join-Path $h 'telemetry-forgetting'
    $ownTicks = Get-ProcessStartTicks -ProcessId $PID
    $ownIso = [string](Get-ProcessStartIso -ProcessId $PID)
    $mkText = { param($o) (ConvertTo-Json -Compress -InputObject ([pscustomobject]$o)) + "`n" }
    [IO.File]::WriteAllText($mk, (& $mkText ([ordered]@{ pid = $PID; start_ticks = ($ownTicks + 1); since = '2026-10-07T01:00:00+02:00' })), $u8)
    $stW = Run-Child $telemetryPs @('-Status') $h
    $a = Add-TelemetryEvent -Entry $entry -Switch $sw -WaitMs 1000
    $notesA = LastNotes $h
    Check 'MARKER' 'E3 (F54-3) a marker whose owner is THIS pid but with another start in ticks (start_ticks + 1 - a reused pid at the full resolution): the owner is GONE - -Status says so, and a producer removes the marker (one line in .last notes "removed the forgetting marker of pid <n> (gone) since <t> ...") and spools its event' ($stW.Out -match "(?m)^forgetting : the marker .* - its owner pid $PID is gone" -and -not $a.Why -and -not $a.Forgetting -and -not (Test-Path -LiteralPath $mk) -and @($notesA | Where-Object { $_ -match "^\S+ removed the forgetting marker of pid $PID \(gone\) since 2026-10-07T01:00:00\+02:00 - " }).Count -eq 1) "status $(StatusLine $stW.Out 'forgetting') | why '$($a.Why)' | notes $($notesA -join ' // ')"
    [IO.File]::WriteAllText($mk, (& $mkText ([ordered]@{ pid = $PID; start_time = $ownIso; start_ticks = ($ownTicks - 1); since = '2026-10-07T01:30:00+02:00' })), $u8)
    $mBoth = Get-TelemetryForgettingOwner -Path $mk
    Remove-Item -LiteralPath $mk -Force
    Check 'MARKER' 'E3 a marker with BOTH: the right start_time string but wrong ticks - the ticks decide (gone)' (-not $mBoth.Alive -and $mBoth.Pid -eq $PID) "alive $($mBoth.Alive)"
    [IO.File]::WriteAllText($mk, (& $mkText ([ordered]@{ pid = $PID; start_time = $ownIso; start_ticks = $ownTicks; since = '2026-10-07T02:00:00+02:00' })), $u8)
    $c = Add-TelemetryEvent -Entry $entry -Switch $sw -WaitMs 1000
    $stR = Run-Child $telemetryPs @('-Status') $h
    Check 'MARKER' 'E3 the right pid AND ticks: the owner LIVES - the producer is refused (Forgetting, "... -Forget -Local is deleting the local telemetry data (pid <n>, since <t>; ..."), the marker stays; -Status "its owner pid <n> lives"' ($c.Forgetting -and $c.Why -match "^codex-telemetry\.ps1 -Forget -Local is deleting the local telemetry data \(pid $PID, since 2026-10-07T02:00:00\+02:00; the marker " -and (Test-Path -LiteralPath $mk) -and $stR.Out -match "(?m)^forgetting : the marker .* - its owner pid $PID lives") "why '$($c.Why)' | $(StatusLine $stR.Out 'forgetting')"
    $env:CODEX_CONSULT_TEST_START_UNREADABLE = [string]$PID
    try { $mU = Get-TelemetryForgettingOwner -Path $mk } finally { Remove-Item env:CODEX_CONSULT_TEST_START_UNREADABLE -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $mk -Force
    [IO.File]::WriteAllText($mk, (& $mkText ([ordered]@{ pid = $PID; start_time = $ownIso; since = '2026-10-07T03:00:00+02:00' })), $u8)
    $mOld = Get-TelemetryForgettingOwner -Path $mk
    [IO.File]::WriteAllText($mk, (& $mkText ([ordered]@{ pid = $PID; start_time = '2000-01-01T00:00:00.0000000Z'; since = '2026-10-07T03:00:00+02:00' })), $u8)
    $mOldW = Get-TelemetryForgettingOwner -Path $mk
    [IO.File]::WriteAllText($mk, (& $mkText ([ordered]@{ pid = 999999; start_ticks = $ownTicks; since = '2026-10-07T03:00:00+02:00' })), $u8)
    $mGone = Get-TelemetryForgettingOwner -Path $mk
    Remove-Item -LiteralPath $mk -Force
    Check 'MARKER' 'E3 the owner''s start unreadable now (CODEX_CONSULT_TEST_START_UNREADABLE): identity unknown - ALIVE (never removed on a guess); an OLDER marker without start_ticks is judged as before by its start_time (the right one alive, another gone); a pid that does not run - gone' ($mU.Alive -and $mOld.Alive -and -not $mOldW.Alive -and -not $mGone.Alive) "unreadable $($mU.Alive) | old right $($mOld.Alive) | old wrong $($mOldW.Alive) | no pid $($mGone.Alive)"
    $env:CODEX_HOME = $savedCodexHome
    $cm = Text $commonPs
    $fnFg = $(if ($cm -match '(?s)\nfunction Invoke-TelemetryForget \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    $fnOw = $(if ($cm -match '(?s)\nfunction Get-TelemetryForgettingOwner \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    Check 'MARKER' 'E3 the code: -Forget writes start_ticks (Get-ProcessStartTicks of itself) beside start_time; the owner is judged by Get-PidIdentityTicks when the marker has them (an exact comparison on Windows), else by Test-PidAlive' ($fnFg -and $fnFg.Contains('$ownTicks = Get-ProcessStartTicks -ProcessId $PID') -and $fnFg.Contains('start_ticks = ') -and $fnOw.Contains('Get-PidIdentityTicks -ProcessId $m.Pid -StartTicks') -and $fnOw.Contains('Test-PidAlive -ProcessId $m.Pid')) ''
    $idn = @((Get-PidIdentityTicks -ProcessId $PID -StartTicks $ownTicks), (Get-PidIdentityTicks -ProcessId $PID -StartTicks ($ownTicks + 1)), (Get-PidIdentityTicks -ProcessId $PID -StartTicks 0), (Get-PidIdentityTicks -ProcessId 999999 -StartTicks $ownTicks))
    Check 'MARKER' 'E3 Get-PidIdentityTicks: this pid with its ticks alive, one tick off gone (Windows: exact), no ticks recorded unknown, a pid that does not run gone; Get-ProcessStartTicks: $null for no process' (($idn -join ',') -eq 'alive,gone,unknown,gone' -and $null -eq (Get-ProcessStartTicks -ProcessId 999999) -and $ownTicks -gt 0) ($idn -join ',')
}

# =============================================================== ANCHOR: the first line whole, the rest counted (E4)
if (Want 'ANCHOR') {
    $rosterCt = Write-Roster 'ctx' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","context_tokens":256000}]}'
    $r = New-Repo 'anchor'
    $reread = { param([string]$Log) $pl = @(((Text $Log) -split "PROMPT:`n", 2)[-1] -split "`r?`n" | Where-Object { $_.Trim() }); return , ([string[]]@($pl | Select-Object -Last 2)) }
    $log1 = Join-Path $work 'anchor-1.txt'
    $ask1 = "Review app.txt for   typos.`nThen check the README.`n`n   And the CHANGELOG.  "
    $x1 = Consult $r $rosterCt @('-Provider', 'openai', '-Prompt', $ask1, '-ReplyName', 'a1') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log1 }
    $l1 = & $reread $log1
    Check 'ANCHOR' 'E4 (F54-4) a multi-line inline ask: the re-read line keeps its FIRST line whole (whitespace inside it folded) and counts the remaining non-blank lines - "Before you answer, re-read the ask: Review app.txt for typos. (+2 more lines)" - right before the consultation id; the ask itself is at the top of the prompt, every line of it' ($x1.Code -eq 0 -and $l1.Count -eq 2 -and $l1[0] -ceq 'Before you answer, re-read the ask: Review app.txt for typos. (+2 more lines)' -and $l1[1] -match '^Consultation id: [0-9a-f-]{36}$' -and (Text $log1).Contains("Then check the README.") -and (Text $log1).Contains('And the CHANGELOG.')) "exit $($x1.Code) | [$($l1 -join ' // ')]"
    $log2 = Join-Path $work 'anchor-2.txt'
    $x2 = Consult $r $rosterCt @('-Provider', 'openai', '-Prompt', "Fix the typo.`nNothing else.", '-ReplyName', 'a2') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log2 }
    $l2 = & $reread $log2
    Check 'ANCHOR' 'E4 one more line: "(+1 more line)"' ($x2.Code -eq 0 -and $l2[0] -ceq 'Before you answer, re-read the ask: Fix the typo. (+1 more line)') "exit $($x2.Code) | $($l2[0])"
    $log3 = Join-Path $work 'anchor-3.txt'
    $longFirst = 'c' * 200 + ' ' + 'd' * 200
    $x3 = Consult $r $rosterCt @('-Provider', 'openai', '-Prompt', ($longFirst + "`nsecond line`nthird line"), '-ReplyName', 'a3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log3 }
    $l3 = & $reread $log3
    Check 'ANCHOR' 'E4 a first line longer than 300 characters is cut at 300 with the pointer to the top of the prompt, the count still follows: "<300 chars>... (cut here: the whole ask is at the top of this prompt) (+2 more lines)"' ($x3.Code -eq 0 -and $l3[0] -ceq ('Before you answer, re-read the ask: ' + $longFirst.Substring(0, 300) + '... (cut here: the whole ask is at the top of this prompt) (+2 more lines)')) "exit $($x3.Code) | $($l3[0].Length) chars"
    $log4 = Join-Path $work 'anchor-4.txt'
    $x4 = Consult $r $rosterCt @('-Provider', 'openai', '-Prompt', $longFirst, '-ReplyName', 'a4') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log4 }
    $l4 = & $reread $log4
    Check 'ANCHOR' 'E4 a one-line ask longer than 300 characters: cut at 300 with the pointer, no count' ($x4.Code -eq 0 -and $l4[0] -ceq ('Before you answer, re-read the ask: ' + $longFirst.Substring(0, 300) + '... (cut here: the whole ask is at the top of this prompt)')) "exit $($x4.Code) | $($l4[0].Length) chars"
}

# =============================================================== DOCS: the README, CHANGELOG, tests/README.md, run-all
if (Want 'DOCS') {
    $readme = (Text (Join-Path $repoRoot 'README.md')) -replace '\s+', ' '
    $miss = @(foreach ($k in @('unverified[]', 'counted as running (fail-closed)', 'telemetry-not-spooled-<pid>-<start ticks>.ndjson', 'folded <n> not-spooled line(s) of <m> gone producer(s)', '`start_ticks`', '(+<n> more lines)')) { if ($readme.IndexOf($k, [StringComparison]::Ordinal) -lt 0) { $k } })
    Check 'DOCS' 'README: the recovery record''s unverified[] and its fail-closed re-check (E1), one not-spooled file per producer and the fold (E2), the marker''s start_ticks (E3), the anchor''s line count (E4)' ($miss.Count -eq 0) "missing: $($miss -join ', ')"
    $cl = Text (Join-Path $repoRoot 'CHANGELOG.md')
    $clSec = $(if ($cl -match '(?s)\n- \*\*Wave 28e - the four small items of the 0\.5\.0 verdict\*\*(.*?)\n(### |## |- \*\*Wave )') { $Matches[1] } else { '' })
    Check 'DOCS' 'CHANGELOG [Unreleased] "Wave 28e - the four small items of the 0.5.0 verdict": E1-E4 with their findings (F54-1..F54-4, F53-1) and the new names' ($clSec -and @(1..4 | Where-Object { $clSec -notmatch "\bE$_\b" -or $clSec -notmatch "\bF54-$_\b" }).Count -eq 0 -and $clSec -match '\bF53-1\b' -and $clSec.Contains('telemetry-not-spooled-<pid>-<start ticks>.ndjson') -and $clSec.Contains('unverified[]') -and $clSec.Contains('start_ticks')) ''
    $tr = Text (Join-Path $sp 'README.md')
    $runAll = Text (Join-Path $sp 'run-all.ps1')
    $miss2 = @(foreach ($k in @('`not_spooled_folded[]`', 'command line not readable - counted as running (fail-closed)', 'CODEX_CONSULT_TEST_CMDLINE_UNREADABLE', 'CODEX_CONSULT_TEST_FOLD_CRASH', '`survivors: []`', 'the next run for this task is refused until it exits')) { if ($readme.IndexOf($k, [StringComparison]::Ordinal) -lt 0) { $k } })
    Check 'DOCS' 'README: a kill with only unverified descendants keeps the record (E18), the fail-closed command-line rule (E19), .last saved before the deletes and not_spooled_folded[] (E20), the two new test hooks' ($miss2.Count -eq 0) "missing: $($miss2 -join ', ')"
    Check 'DOCS' 'CHANGELOG [0.6.0] wave 28e bullet: E18-E20 with their findings F27-1..F27-3 and the new names' ($clSec -and @(18..20 | Where-Object { $clSec -notmatch "\bE$_\b" }).Count -eq 0 -and @(1..3 | Where-Object { $clSec -notmatch "\bF27-$_\b" }).Count -eq 0 -and $clSec.Contains('not_spooled_folded') -and $clSec.Contains('CODEX_CONSULT_TEST_CMDLINE_UNREADABLE') -and $clSec.Contains('CODEX_CONSULT_TEST_FOLD_CRASH')) ''
    $miss3 = @(foreach ($k in @('`kill_unconfirmed`', 'unknown tree after an unconfirmed kill: the scan found no codex-like process under pid', '`{name, bytes}`')) { if ($readme.IndexOf($k, [StringComparison]::Ordinal) -lt 0) { $k } })
    Check 'DOCS' 'README: the unknown tree of an unconfirmed kill and its release (E23), not_spooled_folded[] {name, bytes} and the replay of a longer file (E24)' ($miss3.Count -eq 0) "missing: $($miss3 -join ', ')"
    Check 'DOCS' 'CHANGELOG [0.6.0] wave 28e bullet: E23 and E24 with their findings F30-1, F30-2' ($clSec -and $clSec -match '\bE23\b' -and $clSec -match '\bE24\b' -and $clSec -match '\bF30-1\b' -and $clSec -match '\bF30-2\b' -and $clSec.Contains('kill_unconfirmed') -and $clSec.Contains('{name, bytes}')) ''
    Check 'DOCS' 'tests/README.md describes harness-fixes28e and run-all.ps1 registers it between harness-fixes28d and harness-claude' ($tr.Contains('harness-fixes28e') -and $runAll -match "'harness-fixes28d', 'harness-fixes28e', 'harness-claude'") ''
}

# =============================================================== GUARD: the operator's codex home untouched
if (-not $Only) {
    Check 'GUARD' 'the operator''s real codex home got no telemetry file from this harness (its telemetry* names compared before and after, read only; every case runs in a scratch CODEX_HOME)' ((& $realTelemetry) -eq $realBefore) "before [$realBefore] after [$(& $realTelemetry)]"
}

} finally {
    foreach ($s in $sleepers) { try { if (-not $s.HasExited) { $s.Kill() } } catch { } }
    Restore-Env
    Remove-TestWork $work
}
Write-Host ''
Write-Host ("harness-fixes28e ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
