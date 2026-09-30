# codex-consult wave 28c (0.5.0; the second fix round of the telemetry client and member control -
# decisions D1-D14 of .collab/companions-2026-09-26/handoffs/45-...): IDENTITY - no pid-only identity:
# a pid whose start time cannot be read is 'unknown' (Get-PidIdentity), a tree kill never kills such a
# descendant by its pid nor counts it as gone - the kill is "not confirmed: start time of pid <n>
# unreadable" and the process is left alone (D8); PGREP - the descendants outside Windows: pgrep's
# exit 1 is an empty child set, any other exit, a timeout or output that is not pids is a FAILED
# enumeration that goes on to ps, then /proc; denied only when all fail (D9); JOURNAL - the health
# journal loses nothing silently: an unreadable line is moved to <journal>.bad with the time and
# counted in a warning, the journal loses only the bytes applied or moved (D10); COMPACT - a
# reviewer's compaction reported in its event stream is recorded (ledger `compactions`) and warned
# about, a member with context_tokens gets `unknown` when none is reported, and its prompt names
# the brief again before the consultation id (D11); DOCS - the README, tests/README.md, run-all.
# FAKES ONLY: fake-codex3.cmd; CODEX_HOME and CODEX_CONSULT_ROSTER point at scratch files,
# CODEX_CONSULT_HEALTH is 'none' (JOURNAL: scratch paths), telemetry off; the host markers of the
# process that runs it are removed first; the API key variables hold dummy values; PGREP feeds a
# fake command runner and a fake /proc directory. Runs under the host it is started with
# (powershell 5.1 or pwsh 7, Windows). Work files: $env:TEMP\codex-consult-tests\harness-fixes28c\
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
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-fixes28c') ([guid]::NewGuid().ToString('N'))
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
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ENV_DUMP', 'FAKE_CODEX_PRELINE')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CODEX_CONSULT_TEST_START_UNREADABLE', 'CODEX_CONSULT_TEST_KILL_DENIED')
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
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Text { param([string]$Path) if ($Path -and (Test-Path -LiteralPath $Path)) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Join-Path $work 'advise.json'
[IO.File]::WriteAllText($advise, $adviseJson, $u8)

try {

# =============================================================== IDENTITY: no pid-only identity (D8)
if (Want 'IDENTITY') {
    Clear-TestEnv
    $own = [string](Get-ProcessStartIso -ProcessId $PID)
    $ids = @((Get-PidIdentity -ProcessId $PID -StartTime $own), (Get-PidIdentity -ProcessId $PID -StartTime '2000-01-01T00:00:00.0000000Z'), (Get-PidIdentity -ProcessId $PID -StartTime ''), (Get-PidIdentity -ProcessId 999999 -StartTime $own))
    $env:CODEX_CONSULT_TEST_START_UNREADABLE = [string]$PID
    $hooked = @([string](Get-ProcessStartIso -ProcessId $PID), (Get-PidIdentity -ProcessId $PID -StartTime $own), [string](Test-PidAlive -ProcessId $PID -StartTime $own))
    $env:CODEX_CONSULT_TEST_MODE = ''
    $noTm = [string](Get-ProcessStartIso -ProcessId $PID)
    Clear-TestEnv
    Check 'IDENTITY' 'D8 (F42-4) Get-PidIdentity: this process with its start time alive, with another gone (a reused pid), with none recorded UNKNOWN, a pid that does not exist gone; the test hook CODEX_CONSULT_TEST_START_UNREADABLE=<pid> makes its start time unreadable ('''') - identity unknown, and Test-PidAlive counts unknown as ALIVE (a holder is never taken over on a guess); without test mode the hook is ignored' (($ids -join ',') -eq 'alive,gone,unknown,gone' -and $hooked[0] -eq '' -and $hooked[1] -eq 'unknown' -and $hooked[2] -eq 'True' -and $noTm -eq $own) "ids $($ids -join ',') | hooked [$($hooked -join ',')] | no test mode '$noTm'"
    # a real tree: its child's start time unreadable (the hook), taskkill denied (so that only the
    # bridge's own pid kill could reach the child) - the child is NOT killed and the kill is not confirmed
    $treePs1 = Join-Path $work 'tree.ps1'
    [IO.File]::WriteAllText($treePs1, "`$c = Start-Process -FilePath `$args[0] -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 60' -PassThru -WindowStyle Hidden`n[IO.File]::WriteAllText(`$args[1], [string]`$c.Id)`nStart-Sleep 60`n", $u8)
    $pidFile = Join-Path $work 'tree-child.pid'
    $root = Start-Process -FilePath $psExe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$treePs1`"", "`"$psExe`"", "`"$pidFile`"" -PassThru -WindowStyle Hidden
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $root.Handle } catch { } }
    $wt = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath $pidFile) -and $wt.Elapsed.TotalSeconds -lt 30) { Start-Sleep -Milliseconds 200 }
    $childId = 0; [void][int]::TryParse((Text $pidFile).Trim(), [ref]$childId)
    # every descendant of the root (the child and the console hosts Windows gives the hidden processes)
    # reads as unreadable: none may be killed by its pid
    $all8 = @((Get-DescendantTree -RootId $root.Id).Pids)
    $env:CODEX_CONSULT_TEST_START_UNREADABLE = (@($all8) + @($childId) | Select-Object -Unique) -join ','
    $env:CODEX_CONSULT_TEST_KILL_DENIED = 'taskkill'
    try { $kill = Stop-ProcessTreeChecked -Process $root } finally { Clear-TestEnv }
    $childAlive = [bool](Get-Process -Id $childId -ErrorAction SilentlyContinue)
    $rootGone = $root.HasExited
    Check 'IDENTITY' 'D8 a tree kill whose descendants'' start times cannot be read: the root is killed, the descendant is NOT killed by its pid (left alone - still running) and counted neither as gone nor as a survivor: Confirmed false, Why "start time of pid <n>[, <n>] unreadable" naming it, Unverified holds it, Survivors []' ($childId -gt 0 -and $rootGone -and $childAlive -and -not $kill.Confirmed -and $kill.Why -match '^start time of pid [0-9, ]+ unreadable$' -and @($kill.Unverified) -contains $childId -and $kill.Why -match "\b$childId\b" -and @($kill.Survivors).Count -eq 0) "child $childId alive $childAlive root gone $rootGone | confirmed $($kill.Confirmed) why '$($kill.Why)' unverified [$(@($kill.Unverified) -join ',')] survivors [$(@($kill.Survivors) -join ',')]"
    foreach ($k8 in @(@($kill.Unverified) + @($all8) + @($childId) | Select-Object -Unique)) {
        $p8 = Get-Process -Id ([int]$k8) -ErrorAction SilentlyContinue
        if ($p8 -and @('powershell', 'pwsh', 'conhost') -contains $p8.ProcessName) { try { Stop-Process -Id ([int]$k8) -Force -ErrorAction SilentlyContinue } catch { } }
    }
    $cs = Text $consultPs
    Check 'IDENTITY' 'D8 the run tells an unverified kill as "(kill not confirmed: start time of pid <n> unreadable; pid <n> may still run)": Format-KillText and the kill warning name the unverified pid(s) (Get-KillMayRunPids), the root only when there are none' ($cs.Contains('function Get-KillMayRunPids') -and $cs.Contains('(kill not confirmed: $($Check.Why); pid $(Get-KillMayRunPids $Check) may still run)') -and $cs.Contains('pid $(Get-KillMayRunPids $Check) may still run - check it')) ''
}

# =============================================================== PGREP: a failed enumeration is no empty child set (D9)
if (Want 'PGREP') {
    function New-FakeRunner {
        param([hashtable]$Pgrep, [hashtable]$Ps)
        $pg = $Pgrep
        $pss = $Ps
        return {
            param([string]$File, [string[]]$ArgList, [int]$TimeoutMs)
            $a = $null
            if ($File -eq 'pgrep') {
                $key = [string]$ArgList[1]
                $a = $(if ($pg.ContainsKey($key)) { $pg[$key] } elseif ($pg.ContainsKey('*')) { $pg['*'] } else { @{ Exit = 1 } })
            } else { $a = $pss }
            if (-not $a) { $a = @{ Error = 'not found' } }
            return [pscustomobject]@{ Exit = $(if ($a.ContainsKey('Exit')) { [int]$a.Exit } else { -1 }); Lines = [string[]]@($a.Lines | Where-Object { $_ }); TimedOut = [bool]$a.TimedOut; Error = [string]$a.Error }
        }.GetNewClosure()
    }
    $psTable = @{ Exit = 0; Lines = @('    1     0', '  100     1', '  101   100', '  104   101', '  200     1') }
    $cases = [ordered]@{
        'tree'     = @((New-FakeRunner @{ '100' = @{ Exit = 0; Lines = @('101', '102') }; '101' = @{ Exit = 0; Lines = @('103') }; '*' = @{ Exit = 1 } } $psTable), 'pgrep', '101,102,103')
        'nochild'  = @((New-FakeRunner @{ '*' = @{ Exit = 1 } } $psTable), 'pgrep', '')
        'exit2'    = @((New-FakeRunner @{ '100' = @{ Exit = 0; Lines = @('101') }; '101' = @{ Exit = 2 } } $psTable), 'ps', '101,104')
        'timeout'  = @((New-FakeRunner @{ '*' = @{ TimedOut = $true } } $psTable), 'ps', '101,104')
        'notapid'  = @((New-FakeRunner @{ '100' = @{ Exit = 0; Lines = @('pgrep: cannot open /proc') } } $psTable), 'ps', '101,104')
    }
    $got = @(foreach ($k in $cases.Keys) { $c = $cases[$k]; $t = Get-UnixDescendantTree -RootId 100 -Runner $c[0] -ProcRoot (Join-Path $work 'no-proc'); "$k=$($t.Via):$(@($t.Pids) -join ',')" })
    $want = @(foreach ($k in $cases.Keys) { "$k=$($cases[$k][1]):$($cases[$k][2])" })
    $tE2 = Get-UnixDescendantTree -RootId 100 -Runner $cases['exit2'][0] -ProcRoot (Join-Path $work 'no-proc')
    Check 'PGREP' 'D9 (F42-5) pgrep -P: exit 0 - the pids (breadth first); exit 1 - NO child, an empty set (Via pgrep); any other exit (2), a timeout, output that is not a pid - a FAILED enumeration that goes on to `ps -A -o pid=,ppid=` (the tree from ps, the reason kept: "pgrep -P 101 exit 2")' (($got -join ' ') -eq ($want -join ' ') -and @($tE2.Tried) -contains 'pgrep -P 101 exit 2') "got $($got -join ' ') | tried $(@($tE2.Tried) -join '; ')"
    $procDir = Join-Path $work 'proc'
    foreach ($st in @(@('100', '100 (sh) S 1 100 100 0 -1'), @('101', '101 (my (odd) app) S 100 101 100 0 -1'), @('102', '102 (x y) R 101 102 100 0 -1'), @('300', '300 (other) S 1 300 300 0 -1'))) {
        [void][IO.Directory]::CreateDirectory((Join-Path $procDir $st[0]))
        [IO.File]::WriteAllText((Join-Path (Join-Path $procDir $st[0]) 'stat'), $st[1] + "`n", $u8)
    }
    $tP = Get-UnixDescendantTree -RootId 100 -Runner (New-FakeRunner @{ '*' = @{ Error = 'not found' } } @{ Exit = 1 }) -ProcRoot $procDir
    $tD = Get-UnixDescendantTree -RootId 100 -Runner (New-FakeRunner @{ '*' = @{ Error = 'permission denied' } } @{ TimedOut = $true }) -ProcRoot (Join-Path $work 'no-proc')
    Check 'PGREP' 'D9 no pgrep and a ps that fails (exit 1): /proc/<pid>/stat gives the tree (101,102 - Via proc); pgrep failing to run, ps timing out and no /proc: DENIED, naming every method''s reason ("pgrep failed (permission denied)", "ps timed out", "no <proc>") - the kill is then not confirmed' ($tP.Via -eq 'proc' -and (@($tP.Pids) -join ',') -eq '101,102' -and -not $tP.Denied -and $tD.Denied -match 'pgrep failed \(permission denied\)' -and $tD.Denied -match 'ps timed out' -and $tD.Denied -match 'no .*no-proc' -and @($tD.Pids).Count -eq 0) "proc: $($tP.Via) [$(@($tP.Pids) -join ',')] | denied: $($tD.Denied)"
    $wc = [Diagnostics.Stopwatch]::StartNew()
    $c1 = Invoke-CapturedCommand -File $psExe -ArgList @('-NoProfile', '-Command', 'Write-Output 7; exit 3') -TimeoutMs 30000
    $c2 = Invoke-CapturedCommand -File $psExe -ArgList @('-NoProfile', '-Command', 'Start-Sleep 20') -TimeoutMs 1500
    $wc.Stop()
    Check 'PGREP' 'D9 Invoke-CapturedCommand (the real runner): the exit code and the output lines of a command (exit 3, "7"); a command that outlives its bound is stopped and reported as timed out - well before its own 20 s' ($c1.Exit -eq 3 -and @($c1.Lines) -contains '7' -and -not $c1.TimedOut -and $c2.TimedOut -and $c2.Exit -eq -1 -and $wc.Elapsed.TotalSeconds -lt 15) "c1 exit $($c1.Exit) [$(@($c1.Lines) -join ',')] | c2 timed out $($c2.TimedOut) in $([Math]::Round($wc.Elapsed.TotalSeconds, 1)) s"
}

# =============================================================== JOURNAL: nothing lost silently (D10)
if (Want 'JOURNAL') {
    $hp = Join-Path $work 'health-j.json'
    $env:CODEX_CONSULT_HEALTH = $hp
    $jp = "$hp.journal"
    $recA = ConvertTo-Json -Compress -Depth 4 -InputObject (New-MachineHealthRecord -Fingerprint 'fp-a' -Outcome 'usable reply' -Repo 'C:\repo-a')
    $recB = ConvertTo-Json -Compress -Depth 4 -InputObject (New-MachineHealthRecord -Fingerprint 'fp-b' -Outcome 'usable reply' -Repo 'C:\repo-b')
    $torn1 = '{"endpoint":"fp-torn","cla'
    $torn2 = '{"endpoint":"fp-tail'
    [IO.File]::WriteAllText($jp, "$recA`n$torn1`n$recB`n$torn2", $u8)
    $null = Get-MachineHealthJournalNotes
    $ok1 = Update-MachineHealth
    $notes1 = @(Get-MachineHealthJournalNotes)
    $eps = @((Read-MachineHealth -Fresh).Endpoints)
    $badLines = @((Text "$jp.bad") -split "`n" | Where-Object { $_ })
    $badOk = ($badLines.Count -eq 2 -and $badLines[0] -match "^\S+`t" -and $badLines[0].EndsWith("`t$torn1") -and $badLines[1].EndsWith("`t$torn2"))
    Check 'JOURNAL' 'D10 (F42-6, F44-1) a journal with two good records and two torn ones (one in the middle, one at the end without a newline): the good ones are applied (fp-a, fp-b once each), the torn ones MOVED to <journal>.bad - "<time><tab><the exact bytes>" per line -, the journal emptied only by what was applied or moved, and the warning "health journal: 2 unreadable line(s) kept in <journal>.bad"' ($ok1 -and @($eps | Where-Object { $_.endpoint -eq 'fp-a' }).Count -eq 1 -and @($eps | Where-Object { $_.endpoint -eq 'fp-b' }).Count -eq 1 -and ([IO.FileInfo]$jp).Length -eq 0 -and $badOk -and ($notes1 -join '|') -eq "health journal: 2 unreadable line(s) kept in $jp.bad") "applied $ok1 eps $($eps.Count) | journal $(([IO.FileInfo]$jp).Length) bytes | bad [$($badLines -join ' // ')] | notes $($notes1 -join '|')"
    # the .bad cannot be written (a directory is in its place): the unreadable line and everything
    # after it stay in the journal - never truncated blindly - and a later update moves them
    Remove-Item -LiteralPath "$jp.bad" -Force
    [void][IO.Directory]::CreateDirectory("$jp.bad")
    $recC = ConvertTo-Json -Compress -Depth 4 -InputObject (New-MachineHealthRecord -Fingerprint 'fp-c' -Outcome 'usable reply' -Repo 'C:\repo-c')
    $recD = ConvertTo-Json -Compress -Depth 4 -InputObject (New-MachineHealthRecord -Fingerprint 'fp-d' -Outcome 'usable reply' -Repo 'C:\repo-d')
    [IO.File]::WriteAllText($jp, "$recC`ngarbage-line`n$recD`n", $u8)
    $ok2 = Update-MachineHealth
    $notes2 = @(Get-MachineHealthJournalNotes)
    $kept2 = Text $jp
    $eps2 = @((Read-MachineHealth -Fresh).Endpoints)
    Remove-Item -LiteralPath "$jp.bad" -Recurse -Force
    $ok3 = Update-MachineHealth
    $notes3 = @(Get-MachineHealthJournalNotes)
    $eps3 = @((Read-MachineHealth -Fresh).Endpoints)
    $env:CODEX_CONSULT_HEALTH = 'none'
    Check 'JOURNAL' 'D10 a .bad that cannot be written: the good records are applied, the journal KEEPS the unreadable line and what follows it ("garbage-line`n<fp-d>`n" - only the applied prefix removed), the warning says "could not be moved"; the next update moves it (journal empty) and applies fp-d again without a second record (idempotent)' ($ok2 -and $kept2 -eq "garbage-line`n$recD`n" -and ($notes2 -join '|') -match 'could not be moved to .*\.bad - kept in' -and @($eps2 | Where-Object { $_.endpoint -eq 'fp-c' }).Count -eq 1 -and $ok3 -and ([IO.FileInfo]$jp).Length -eq 0 -and ($notes3 -join '|') -eq "health journal: 1 unreadable line(s) kept in $jp.bad" -and @($eps3 | Where-Object { $_.endpoint -eq 'fp-d' }).Count -eq 1) "kept '$($kept2.Replace("`n", '\n'))' | notes2 $($notes2 -join '|') | notes3 $($notes3 -join '|') | fp-d $(@($eps3 | Where-Object { $_.endpoint -eq 'fp-d' }).Count)"
    # end to end: a run of another repository finds a torn line in the journal - its warnings[] says so
    $hE = Join-Path $work 'health-e2e.json'
    [IO.File]::WriteAllText("$hE.journal", '{"endpoint":"fp-x","cl' + "`n", $u8)
    $r = New-Repo 'journal-run'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'jr') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_HEALTH = $hE }
    $e = @(Ledger $r)[-1]
    $wantW = "health journal: 1 unreadable line(s) kept in $hE.journal.bad"
    Check 'JOURNAL' 'D10 end to end: a run whose health update meets a torn journal line keeps it in <journal>.bad and says "health journal: 1 unreadable line(s) kept in <file>" in its warnings[] and on the console; exit 0' ($x.Code -eq 0 -and @($e.warnings) -contains $wantW -and $x.Out.Contains($wantW) -and (Text "$hE.journal.bad") -match '\{"endpoint":"fp-x","cl') "exit $($x.Code); $(@($e.warnings) -join ' / ')"
}

# =============================================================== COMPACT: a reviewer that compacts is seen (D11)
if (Want 'COMPACT') {
    $ev = Join-Path $work 'compact-events.jsonl'
    [IO.File]::WriteAllText($ev, (@(
                '{"type":"thread.started","thread_id":"t"}',
                '{"type":"item.completed","item":{"id":"i1","type":"context_compaction"}}',
                '{"type":"context_compacted"}',
                '{"type":"item.started","item":{"id":"i2","type":"context_compaction"}}',
                '{"type":"item.completed","item":{"id":"i3","type":"agent_message","text":"we compacted nothing"}}',
                'not json with compact in it') -join "`n") + "`n", $u8)
    $cnt = Get-CompactionCount -Paths @($ev, (Join-Path $work 'missing.jsonl'), '')
    Check 'COMPACT' 'D11 (F43-3, F44-6) Get-CompactionCount counts what the engine REPORTED: an item.completed of a context_compaction and a context_compacted event (2); an item.started, an agent message that says "compacted", a line that is no JSON and a missing file count nothing' ($cnt -eq 2) "count $cnt"
    $rosterCt = Write-Roster 'ctx' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","context_tokens":256000}]}'
    $r = New-Repo 'compact'
    [IO.File]::WriteAllText((Join-Path $r 'brief-c.md'), "# brief`nlook at app.txt`n", $u8)
    $log = Join-Path $work 'compact-args.txt'
    $x = Consult $r $rosterCt @('-Provider', 'openai', '-Brief', 'brief-c.md', '-Prompt', 'x', '-ReplyName', 'cp') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log; FAKE_CODEX_PRELINE = '{"type":"item.completed","item":{"id":"item_c","type":"context_compaction"}}' }
    $e = @(Ledger $r)[-1]
    $warnC = 'the reviewer compacted its context 1 time(s) - the reply may rest on a summary of the brief'
    $promptLines = @(((Text $log) -split "PROMPT:`n", 2)[-1] -split "`r?`n" | Where-Object { $_.Trim() })
    $lastTwo = @($promptLines | Select-Object -Last 2)
    Check 'COMPACT' 'D11 a member with context_tokens whose stream reports a compaction: ledger compactions 1 (the key after usage), the warning "the reviewer compacted its context 1 time(s) - the reply may rest on a summary of the brief" in warnings[] and on the console; its prompt ends with "Before you answer, re-read the brief: `<brief>`." right before the consultation id (which stays last)' ($x.Code -eq 0 -and $e.compactions -eq 1 -and ((($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match ',usage,compactions,engine_run,') -and @($e.warnings) -contains $warnC -and $x.Out.Contains("warning    : $warnC") -and $lastTwo.Count -eq 2 -and $lastTwo[0] -ceq 'Before you answer, re-read the brief: `brief-c.md`.' -and $lastTwo[1] -match '^Consultation id: [0-9a-f-]{36}$') "exit $($x.Code); compactions $($e.compactions); last lines [$($lastTwo -join ' // ')]"
    $x2 = Consult $r $rosterCt @('-Provider', 'openai', '-Brief', 'brief-c.md', '-Prompt', 'x', '-ReplyName', 'cp2') @{ FAKE_CODEX_REPLY = $advise }
    $e2 = @(Ledger $r)[-1]
    Check 'COMPACT' 'D11 the same member, no compaction reported: compactions "unknown" (the installed codex''s exec --json reports none - none seen is not none happened), no compaction warning' ($x2.Code -eq 0 -and $e2.compactions -ceq 'unknown' -and -not (@($e2.warnings) | Where-Object { ([string]$_) -match 'compacted its context' })) "exit $($x2.Code); compactions '$($e2.compactions)'"
    $log3 = Join-Path $work 'compact-args3.txt'
    $x3 = Consult $r '' @('-Brief', 'brief-c.md', '-Prompt', 'x', '-ReplyName', 'cp3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log3 }
    $e3 = @(Ledger $r)[-1]
    Check 'COMPACT' 'D11 a member WITHOUT context_tokens: compactions null (the key present), no re-read line in the prompt' ($x3.Code -eq 0 -and $e3.PSObject.Properties['compactions'] -and $null -eq $e3.compactions -and (Text $log3) -notmatch 'Before you answer, re-read the brief') "exit $($x3.Code); compactions '$($e3.compactions)'"
}

# =============================================================== DOCS: the README, tests/README.md, run-all
if (Want 'DOCS') {
    $readme = (Text (Join-Path $repoRoot 'README.md')) -replace '\s+', ' '
    $miss = @(foreach ($k in @('start time of pid <n> unreadable', 'CODEX_CONSULT_TEST_START_UNREADABLE', 'CODEX_CONSULT_TEST_KILL_DENIED=taskkill', 'exit 1 (no match) is an empty child set', 'a failed enumeration', '<health file>.journal.bad', 'unreadable line(s) kept in', '`compactions`', '`unknown`', 'Before you answer, re-read the brief', 'context_compaction')) { if ($readme.IndexOf($k, [StringComparison]::Ordinal) -lt 0) { $k } })
    Check 'DOCS' 'README: the unverified kill and its hook (D8), pgrep''s exit codes and the failed enumeration (D9), the journal''s .bad and its warning (D10), the ledger''s compactions and unknown, the re-read line, the event names looked for (D11)' ($miss.Count -eq 0) "missing: $($miss -join ', ')"
    $tr = Text (Join-Path $sp 'README.md')
    $runAll = Text (Join-Path $sp 'run-all.ps1')
    Check 'DOCS' 'tests/README.md describes harness-fixes28c and run-all.ps1 registers it' ($tr.Contains('harness-fixes28c') -and $runAll -match "'harness-fixes28c'") ''
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
Write-Host ''
Write-Host ("harness-fixes28c ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
