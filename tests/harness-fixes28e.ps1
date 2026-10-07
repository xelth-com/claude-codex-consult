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
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ENV_DUMP', 'FAKE_CODEX_PRELINE', 'FAKE_CODEX_HANG_ON')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CODEX_CONSULT_TEST_SURVIVORS', 'CODEX_CONSULT_TEST_UNVERIFIED', 'CODEX_CONSULT_TEST_START_UNREADABLE')
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
    $env:CODEX_HOME = $savedCodexHome
    $cm = Text $commonPs
    $fnN = $(if ($cm -match '(?s)\nfunction Add-TelemetryNotSpooled \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    $fnF = $(if ($cm -match '(?s)\nfunction Invoke-TelemetryFlush \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    Check 'NOTSPOOLED' 'E2 the code: Add-TelemetryNotSpooled appends to this process''s own file (NotSpooledOwn) and takes no lock; the flush folds (Merge-TelemetryNotSpooled) only while it holds the telemetry lock' ($fnN -and $fnN -notmatch 'Enter-TelemetryLock' -and $fnN.Contains('AppendAllText($p.NotSpooledOwn') -and $fnF -match '(?s)if \(\$lkLast\.Ok\) \{\s*\$fold = Merge-TelemetryNotSpooled') ''
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
