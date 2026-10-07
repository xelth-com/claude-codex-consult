# Demonstrates the fixes for review findings F04-1..F04-11 (and, wave 29, decision E27: the Codex
# desktop app's servers are no reviewer run; E28: a command line holding exec is never left out, Windows
# quoting, unbalanced quoting counts) against the CURRENT scripts.
# Every assertion prints "PASS" or "FAIL" with its evidence. Uses the fake codex only.
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
# (wave 26b, D13) the machine-wide health file stays out of these cases (every case its own
# repository; harness-fixes26b.ps1 points CODEX_CONSULT_HEALTH at scratch files of its own)
$env:CODEX_CONSULT_HEALTH = 'none'
# (wave 28) telemetry off and the intake pointed at nothing reachable: no harness but
# harness-telemetry spools an event or contacts an intake
$env:CODEX_CONSULT_TELEMETRY = 'off'
$env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
# (wave 27c, D14) the test hooks (CODEX_CONSULT_TEST_*, CODEX_CONSULT_NOW) are honoured only in test mode
$env:CODEX_CONSULT_TEST_MODE = '1'
# These cases use the Codex home of the machine; a reviewer roster there
# (<codex home>/codex-consult-roster.json) must not change what they test: none = no roster.
$env:CODEX_CONSULT_ROSTER = 'none'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# (wave 25, T4) the scripts under test: -ScriptsDir, else CODEX_CONSULT_SCRIPTS_DIR, else this checkout's
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$findingsPs = Join-Path $scripts 'codex-findings.ps1'
$fake = Join-Path $sp 'fake-codex.cmd'
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-fixes') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
try {
$u8 = New-Object System.Text.UTF8Encoding($false)
$script:fails = 0

function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if (-not $Ok) { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    Write-Host ("{0} {1,-7} {2}{3}" -f $mark, $Id, $What, $(if ($Evidence) { "  | $Evidence" } else { '' }))
}
function G { param([string]$Repo, [string[]]$A) $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $o = & git -C $Repo @A 2>&1; $ErrorActionPreference = $p; return $o }
function New-Repo {
    param([string]$Name)
    $r = Join-Path $work $Name
    if (Test-Path $r) { Remove-Item $r -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($r)
    $null = G $r @('init', '-q'); $null = G $r @('config', 'user.email', 't@e.com'); $null = G $r @('config', 'user.name', 'T')
    [IO.File]::WriteAllText((Join-Path $r 'app.txt'), "one`n", $u8)
    [IO.File]::WriteAllText((Join-Path $r '.gitignore'), "*.bin`n", $u8)
    $null = G $r @('add', '-A'); $null = G $r @('commit', '-q', '-m', 'init')
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    [IO.File]::WriteAllText((Join-Path $r '.collab\t\handoffs\01-claude-brief.md'), "# brief`n", $u8)
    return $r
}
function Clear-FakeEnv { foreach ($k in @('FAKE_CODEX_REPLY', 'FAKE_CODEX_SLEEP', 'FAKE_CODEX_FAIL', 'FAKE_CODEX_TOUCH', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_LOG', 'FAKE_CODEX_NOUSAGE')) { Remove-Item "env:$k" -ErrorAction SilentlyContinue } }
function Run-Consult {
    param([string]$Repo, [string[]]$ArgList, [hashtable]$Env = @{})
    Clear-FakeEnv
    foreach ($k in $Env.Keys) { Set-Item "env:$k" $Env[$k] }
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task t -CodexExe $fake @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Clear-FakeEnv
    return [pscustomobject]@{ Code = $code; Out = (($out | ForEach-Object { "$_" }) -join "`n") }
}
function Run-Findings {
    param([string]$Repo, [string[]]$ArgList)
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $findingsPs -Task t @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    return [pscustomobject]@{ Code = $code; Out = (($out | ForEach-Object { "$_" }) -join "`n") }
}
function Reply { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Last-Entry { param([string]$Repo) return @((Get-Content -Raw (Join-Path $Repo '.collab\t\sessions.json') | ConvertFrom-Json).codex.consults)[-1] }
function Sha { param([string]$Path) return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash }
function Test-LockHeld { param([string]$Path) if (-not (Test-Path $Path)) { return $false }; try { $f = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None); $f.Dispose(); return $false } catch { return $true } }
function Want { param([string]$Name) return (-not $Only -or ($Only -split ',') -contains $Name) }

$advise = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$blockerFinding = '{"severity":"blocker","locations":[{"path":"app.txt","line":1}],"claim":"prior blocker claim","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt:1","observation":"o"}],"verification":"verify it","remedy":"fix it","supersedes":[]}'

# =============================================================== F04-1 atomic stores, corruption refused
if (Want 'F04-1') {
    # (a) crash injection: a child rewrites a ~1.5 MB store in a loop and is killed at
    #     random moments; after every kill the store must parse completely. Each kill is
    #     judged on its own: a store found damaged or missing is re-seeded before the
    #     next kill, so one lost file counts once (the child needs the store to start).
    $store = Join-Path $work 'atomic-store.json'
    $big = [pscustomobject]@{ task_id = 't'; findings = [object[]]@(1..1500 | ForEach-Object { [pscustomobject]@{ id = "F01-$_"; claim = ('x' * 900) } }) }
    Write-JsonFile -Path $store -Object $big
    $writer = Join-Path $work 'writer.ps1'
    [IO.File]::WriteAllText($writer, @"
. '$scripts\codex-consult-common.ps1'
`$o = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText('$store'))
for (`$i = 0; `$i -lt 1000; `$i++) { `$o.task_id = "t`$i"; Write-JsonFile -Path '$store' -Object `$o }
"@, $u8)
    $rnd = New-Object System.Random 7
    $bad = 0
    $firstBad = ''
    $kills = 12
    for ($k = 0; $k -lt $kills; $k++) {
        $pw = Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $writer -PassThru -WindowStyle Hidden
        Start-Sleep -Milliseconds (1500 + $rnd.Next(0, 1500))
        Stop-Process -Id $pw.Id -Force -ErrorAction SilentlyContinue
        $pw.WaitForExit()
        $hit = $false
        try {
            $chk = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($store))
            $cnt = @($chk.findings).Count
            if ($cnt -ne 1500) { $hit = $true; if (-not $firstBad) { $firstBad = "kill $k`: $cnt findings, exited=$($pw.HasExited)" } }
        } catch {
            $hit = $true
            if (-not $firstBad) { $firstBad = "kill $k`: $($_.Exception.GetType().Name): $(($_.Exception.Message -replace '\s+', ' ').Trim()); exited=$($pw.HasExited)" }
        }
        if ($hit) {
            $bad++
            Write-JsonFile -Path $store -Object $big
        }
    }
    $leftTmp = @(Get-ChildItem -LiteralPath $work -Filter '.atomic-store.json.*.tmp' -Force).Count
    Check 'F04-1' "store parses completely after each of $kills hard kills mid-rewrite" ($bad -eq 0) "corrupt=$bad, stray temp files left by kills=$leftTmp$(if ($firstBad) { "; first: $firstBad" })"

    # (b) an existing but empty / unparseable store is refused, never replaced
    $r = New-Repo 'f1'
    [IO.File]::WriteAllText((Join-Path $r '.collab\t\findings.json'), '', $u8)
    $x = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'a') @{ FAKE_CODEX_REPLY = (Reply 'f1.json' $advise) }
    $len = (Get-Item (Join-Path $r '.collab\t\findings.json')).Length
    Check 'F04-1' 'empty findings.json -> consult refused, file untouched' ($x.Code -eq 1 -and $x.Out -match 'refusing to use .*findings\.json.*empty' -and $len -eq 0) (($x.Out -split "`n")[0])
    $y = Run-Findings $r @('-List')
    Check 'F04-1' 'empty findings.json -> codex-findings -List refused' ($y.Code -eq 1 -and $y.Out -match 'refusing') (($y.Out -split "`n")[0])
    Remove-Item (Join-Path $r '.collab\t\findings.json')
    [IO.File]::WriteAllText((Join-Path $r '.collab\t\sessions.json'), "{ truncated", $u8)
    $z = Run-Consult $r @('-DryRun', '-Prompt', 'x')
    Check 'F04-1' 'unparseable sessions.json -> refused (also in -DryRun)' ($z.Code -eq 1 -and $z.Out -match 'refusing to use .*sessions\.json.*does not parse') (($z.Out -split "`n")[0])
    $raw = Run-Consult $r @('-Raw', '-Prompt', 'x')
    Check 'F04-1' 'unparseable sessions.json -> -Raw run refused too, lock not held, no pending record' ($raw.Code -eq 1 -and -not (Test-LockHeld (Join-Path $r '.collab\t\.consult.lock')) -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) (($raw.Out -split "`n")[0])
}

# =============================================================== F04-2 held-handle lock: one owner under contention
if (Want 'F04-2') {
    $ld = Join-Path $work 'race'
    if (Test-Path $ld) { Remove-Item $ld -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($ld)
    # a stale leftover (holder gone, no live child) is present before the race
    $deadP = Start-Process cmd.exe -ArgumentList '/c', 'exit' -PassThru -WindowStyle Hidden; $deadP.WaitForExit()
    [IO.File]::WriteAllText((Join-Path $ld '.consult.lock'), (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ pid = $deadP.Id; host = [Environment]::MachineName; task = 't'; started = 'old'; n = 3; nn = '05'; child_pid = $deadP.Id; survivors = @() })), $u8)
    $go = Join-Path $ld 'go.flag'
    $contender = Join-Path $work 'contender.ps1'
    [IO.File]::WriteAllText($contender, @"
. '$scripts\codex-consult-common.ps1'
while (-not (Test-Path '$go')) { Start-Sleep -Milliseconds 5 }
try { `$l = Enter-TaskLock -TaskDir '$ld' -Task 't' } catch { [IO.File]::WriteAllText("$ld\result-`$PID.txt", "`$PID error: `$(`$_.Exception.Message)"); exit 2 }
if (`$l.Acquired) { [IO.File]::WriteAllText("$ld\result-`$PID.txt", "`$PID acquired"); Start-Sleep -Seconds 4; Exit-TaskLock -Lock `$l }
else { [IO.File]::WriteAllText("$ld\result-`$PID.txt", "`$PID refused: `$(`$l.Message)") }
"@, $u8)
    $procs = @(1..8 | ForEach-Object { Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $contender -PassThru -WindowStyle Hidden })
    Start-Sleep -Seconds 3
    [IO.File]::WriteAllText($go, 'go')
    foreach ($p in $procs) { $p.WaitForExit() }
    $log = @(Get-ChildItem -LiteralPath $ld -Filter 'result-*.txt' | ForEach-Object { [IO.File]::ReadAllText($_.FullName) })
    $owners = @($log | Where-Object { $_ -match 'acquired' }).Count
    $refusedMsg = @($log | Where-Object { $_ -match 'refused' } | Select-Object -First 1)
    Check 'F04-2' '8 simultaneous contenders over a stale leftover -> exactly one owner' ($owners -eq 1 -and $log.Count -eq 8) "owners=$owners of $($log.Count); e.g. $(if ($refusedMsg) { ($refusedMsg[0] -replace '^.*?held open by ', 'held open by ') })"
    $ownerPid = @($log | Where-Object { $_ -match 'acquired' } | ForEach-Object { ($_ -split ' ')[0] })[0]
    $refusals = @($log | Where-Object { $_ -match 'refused' })
    $wrongNamed = @($refusals | Where-Object { $_ -notmatch "held open by (pid $ownerPid on |a live process)" }).Count
    Check 'F04-2' "every refusal names the live owner (pid $ownerPid), never the dead previous holder (pid $($deadP.Id))" ($refusals.Count -eq 7 -and $wrongNamed -eq 0) "refusals=$($refusals.Count) naming someone else=$wrongNamed"
    Check 'F04-2' 'owner released by closing: lock file stays, not held' ((Test-Path (Join-Path $ld '.consult.lock')) -and -not (Test-LockHeld (Join-Path $ld '.consult.lock'))) ''
    $l1 = Enter-TaskLock -TaskDir $ld -Task 't'
    $held = Test-LockHeld (Join-Path $ld '.consult.lock')
    Exit-TaskLock -Lock $l1
    Check 'F04-2' 'Exit-TaskLock only closes: held while owned, file kept, free after' ($held -and (Test-Path (Join-Path $ld '.consult.lock')) -and -not (Test-LockHeld (Join-Path $ld '.consult.lock'))) ''
}

# =============================================================== F04-3 reservations and numbering
if (Want 'F04-3') {
    $r = New-Repo 'f3'
    $td = Join-Path $r '.collab\t'
    $ledger = [pscustomobject]@{ task_id = 't'; cwd = $r; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]@([pscustomobject]@{ n = 1; thread = '01a0c86e-5193-7d70-a644-63a5c3f224b3'; reply = 'handoffs/02-codex-a.md' }) } }
    Write-JsonFile -Path (Join-Path $td 'sessions.json') -Object $ledger
    $fs = [pscustomobject]@{ task_id = 't'; findings = [object[]]@([pscustomobject]@{ id = 'F02-1'; status = 'proposed'; severity = 'major'; claim = 'c'; source = [pscustomobject]@{ consult = 1; reply = 'handoffs/02-codex-a.md' }; reviewer_checks = [object[]]@([pscustomobject]@{ consult = 2; status = 'still-open'; note = 'checks-only orphan' }) }) }
    Write-JsonFile -Path (Join-Path $td 'findings.json') -Object $fs
    $d = Run-Consult $r @('-DryRun', '-Prompt', 'x')
    Check 'F04-3' 'reviewer check naming consult 2 (no ledger entry) -> next n is 3, not 2' ($d.Out -match 'consult n = 3') (($d.Out -split "`n" | Where-Object { $_ -match '^handoff' }) -join '')
    $l = Run-Findings $r @('-List')
    Check 'F04-3' '-List flags the orphan reviewer check' ($l.Out.Contains('[ORPHAN reviewer check: consult 2')) (($l.Out -split "`n" | Where-Object { $_ -match 'orphans' }) -join '')
    $fs.findings[0].source.consult = 5
    Write-JsonFile -Path (Join-Path $td 'findings.json') -Object $fs
    $dr = Run-Consult $r @('-DryRun', '-Raw', '-Prompt', 'x')
    Check 'F04-3' '-Raw numbering sees a finding sourced at consult 5 -> n = 6' ($dr.Out -match 'consult n = 6') (($dr.Out -split "`n" | Where-Object { $_ -match '^handoff' }) -join '')
    # an interrupted run's recovery record (reserved n=7, nn=09; its bridge is gone)
    $pend = Join-Path $td '.consult.pending.json'
    [IO.File]::WriteAllText($pend, '{"state":"reserved","n":7,"nn":"09","reply":"handoffs/09-codex-x.md","started":"2026-09-24T00:00:00+02:00","pid":1,"host":"' + [Environment]::MachineName + '","launcher":"","child_pid":null,"child_start_time":"","survivors":[],"note":""}', $u8)
    $pendHash = Sha $pend
    $dl = Run-Consult $r @('-DryRun', '-Prompt', 'x')
    Check 'F04-3' 'dry run reads the pending record -> handoff 10, n = 8' ($dl.Out -match 'handoff     : 10 \(consult n = 8\)' -and $dl.Out -match "state 'reserved', n=7, nn=09.*the next run recovers it") (($dl.Out -split "`n" | Where-Object { $_ -match '^handoff|^pending' }) -join ' / ')
    $fr = Run-Findings $r @('-Id', 'F02-1', '-Status', 'implemented')
    Check 'F04-3' 'codex-findings -Status leaves the pending record byte-identical' ($fr.Code -eq 0 -and (Sha $pend) -eq $pendHash) ''
    $run = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'rec') @{ FAKE_CODEX_REPLY = (Reply 'f3.json' $advise) }
    $e = Last-Entry $r
    Check 'F04-3' 'real run prints the recovery line, commits n=8 / 10-codex-rec.md, removes the pending record' ($run.Out -match 'recovered reservation n=7, nn=09' -and $e.n -eq 8 -and $e.reply -eq 'handoffs/10-codex-rec.md' -and -not (Test-Path $pend) -and -not (Test-LockHeld (Join-Path $td '.consult.lock'))) "n=$($e.n) reply=$($e.reply)"
}

# =============================================================== F04-4 prior blockers vs ACCEPT
if (Want 'F04-4') {
    $r = New-Repo 'f4'
    $seed = Reply 'f4-seed.json' ($advise -replace '"findings":\[\]', ('"findings":[' + $blockerFinding + ']'))
    $null = Run-Consult $r @('-Prompt', 'seed', '-ReplyName', 'seed') @{ FAKE_CODEX_REPLY = $seed }
    $acc = Reply 'f4-acc.json' '{"schema_version":"1","verdict":"ACCEPT","verdict_reason":"All good.","reply_markdown":"ok","findings":[],"prior_findings":[{"id":"F02-1","status":"still-open","note":"not fixed"}],"unproven":[],"first_run_checklist":["x"]}'
    $x = Run-Consult $r @('-Purpose', 'acceptance', '-Prompt', 'accept?', '-ReplyName', 'acc') @{ FAKE_CODEX_REPLY = $acc }
    $e = Last-Entry $r
    $md = [IO.File]::ReadAllText((Join-Path $r '.collab\t\handoffs\03-codex-acc.md'))
    $blk = ($md -split '### Blockers')[1]
    Check 'F04-4' 'ACCEPT + prior blocker reported still-open -> verdict blank + validation_error' ($e.verdict -eq '' -and $e.validation_error -eq 'verdict ACCEPT contradicts still-open prior blocker F02-1' -and $e.structured -eq $true) "verdict='$($e.verdict)' validation_error='$($e.validation_error)'"
    Check 'F04-4' 'rendered Blockers lists the retained prior blocker, marked' ($blk -match '\*\*F02-1\*\* \(prior, still-open\) `app.txt:1` - prior blocker claim\.') (($blk -split "`n" | Where-Object { $_ -match 'F02-1' }) -join '')
    $fsj = Get-Content -Raw (Join-Path $r '.collab\t\findings.json') | ConvertFrom-Json
    Check 'F04-4' 'no duplicate finding record for the retained blocker' (@($fsj.findings | Where-Object { $_.claim -eq 'prior blocker claim' }).Count -eq 1) "findings=$(@($fsj.findings).Count)"
    $omit = Reply 'f4-omit.json' '{"schema_version":"1","verdict":"ACCEPT","verdict_reason":"All good.","reply_markdown":"ok","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":["x"]}'
    $y = Run-Consult $r @('-Purpose', 'acceptance', '-Prompt', 'accept?', '-ReplyName', 'omit') @{ FAKE_CODEX_REPLY = $omit }
    $e2 = Last-Entry $r
    $md2 = [IO.File]::ReadAllText((Join-Path $r '.collab\t\handoffs\04-codex-omit.md'))
    Check 'F04-4' 'ACCEPT with the prior blocker omitted -> ACCEPT kept + WARNING + not-checked' ($e2.verdict -eq 'ACCEPT' -and $md2 -match 'WARNING: ACCEPT with 1 unchecked prior blocker\(s\) \(F02-1\)\.' -and @($e2.unchecked_prior_blockers)[0] -eq 'F02-1' -and $md2 -match '\*\*F02-1\*\* \(prior, not-checked\)') "verdict=$($e2.verdict) unchecked=$(@($e2.unchecked_prior_blockers) -join ',')"
}

# =============================================================== F04-5 overflow -> validation error, raw kept
if (Want 'F04-5') {
    $r = New-Repo 'f5'
    $bigLine = Reply 'f5.json' ($advise -replace '"findings":\[\]', '"findings":[{"severity":"major","locations":[{"path":"a","line":1e30}],"claim":"c","trigger":"t","evidence":[{"kind":"assumed","reference":"","observation":""}],"verification":"v","remedy":"r","supersedes":[]}]')
    $x = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'big') @{ FAKE_CODEX_REPLY = $bigLine }
    $e = Last-Entry $r
    $rj = Join-Path $r '.collab\t\handoffs\02-codex-big.reply.json'
    Check 'F04-5' 'line 1e30 -> exit 0, structured=false, validation_error, no findings.json' ($x.Code -eq 0 -and $e.structured -eq $false -and $e.validation_error -match "line '1E\+30' is outside 1\.\.2147483647" -and -not (Test-Path (Join-Path $r '.collab\t\findings.json'))) "validation_error='$($e.validation_error)'"
    Check 'F04-5' 'raw reply preserved byte for byte' ((Sha $rj) -eq (Sha $bigLine)) ''
    $cases = @(@('0', $false), @('-5', $false), @('2147483648', $false), @('2147483647', $true), @('1', $true), @('null', $true))
    $okAll = $true; $ev = @()
    foreach ($c in $cases) {
        $p = ConvertFrom-StructuredReply -Text ($advise -replace '"findings":\[\]', ('"findings":[{"severity":"major","locations":[{"path":"a","line":' + $c[0] + '}],"claim":"c","trigger":"t","evidence":[],"verification":"v","remedy":"r","supersedes":[]}]'))
        if ($p.Valid -ne $c[1]) { $okAll = $false }
        $ev += "$($c[0])->$($p.Valid)"
    }
    Check 'F04-5' 'line bounds 1..2147483647 (null allowed), no throw' $okAll ($ev -join ' ')
    # write order: .reply.json is written before the .md
    $t1 = (Get-Item $rj).LastWriteTimeUtc; $t2 = (Get-Item (Join-Path $r '.collab\t\handoffs\02-codex-big.md')).LastWriteTimeUtc
    Check 'F04-5' '.reply.json written before the .md' ($t1 -le $t2) "reply.json $($t1.ToString('HH:mm:ss.fff')) <= md $($t2.ToString('HH:mm:ss.fff'))"
}

# =============================================================== F04-6 verdict must fit the purpose
if (Want 'F04-6') {
    $r = New-Repo 'f6'
    $withMajor = Reply 'f6.json' ($advise -replace '"findings":\[\]', '"findings":[{"severity":"major","locations":[],"claim":"c","trigger":"t","evidence":[],"verification":"v","remedy":"r","supersedes":[]}]')
    $x = Run-Consult $r @('-Purpose', 'acceptance', '-Prompt', 'x', '-ReplyName', 'adv') @{ FAKE_CODEX_REPLY = $withMajor }
    $e = Last-Entry $r
    Check 'F04-6' 'acceptance + ADVISE -> verdict blank, validation_error, findings still ingested' ($e.verdict -eq '' -and $e.validation_error -eq 'verdict ADVISE is not allowed for purpose acceptance (expected ACCEPT|HOLD|REJECT)' -and @($e.finding_ids).Count -eq 1 -and $x.Code -eq 0) "validation_error='$($e.validation_error)' finding_ids=$(@($e.finding_ids) -join ',')"
    $hold = Reply 'f6b.json' ($advise -replace '"ADVISE"', '"HOLD"')
    $y = Run-Consult $r @('-Purpose', 'framing', '-Prompt', 'x', '-ReplyName', 'hold') @{ FAKE_CODEX_REPLY = $hold }
    $e2 = Last-Entry $r
    Check 'F04-6' 'framing + HOLD -> invalid' ($e2.verdict -eq '' -and $e2.validation_error -match 'verdict HOLD is not allowed for purpose framing') "validation_error='$($e2.validation_error)'"
    $p = ConvertFrom-StructuredReply -Text ($advise -replace '"ADVISE"', '"ACCEPT"') -Purpose ''
    Check 'F04-6' 'no purpose + ACCEPT -> invalid (only ADVISE allowed)' ($p.VerdictInvalid -and $p.ValidationError -match 'purpose none') $p.ValidationError
    $ok = ConvertFrom-StructuredReply -Text ($advise -replace '"ADVISE"', '"REJECT"') -Purpose 'diff-review'
    Check 'F04-6' 'diff-review + REJECT -> valid' ($ok.Valid -and -not $ok.VerdictInvalid -and $ok.Verdict -eq 'REJECT') ''
}

# =============================================================== F04-7 file modes in the manifest
if (Want 'F04-7') {
    $r = New-Repo 'f7'
    [IO.File]::AppendAllText((Join-Path $r 'app.txt'), "two`n", $u8); $null = G $r @('add', 'app.txt')
    $a = Get-RevisionInfo -Root $r -CollabRoot (Join-Path $r '.collab')
    $null = G $r @('update-index', '--chmod=+x', 'app.txt')
    $b = Get-RevisionInfo -Root $r -CollabRoot (Join-Path $r '.collab')
    $lineB = ($b.manifest -split "`n" | Where-Object { $_ -match 'app\.txt' })
    Check 'F04-7' 'executable-bit change (same content, same XY) changes tree_sha256' ($a.tree_sha256 -ne $b.tree_sha256 -and $lineB -match '^M  100644>100755 ') "before: $(($a.manifest -split "`n" | Where-Object { $_ -match 'app\.txt' })) / after: $lineB"
    [IO.File]::WriteAllText((Join-Path $r 'new.txt'), "u`n", $u8)
    $c = Get-RevisionInfo -Root $r -CollabRoot (Join-Path $r '.collab')
    Check 'F04-7' "untracked entry gets mode 'u'; note says so" ((($c.manifest -split "`n") -match '^\?\? u [0-9a-f]{40} new\.txt$').Count -eq 1 -and $c.fingerprint_note -match 'untracked file modes not recorded') $c.fingerprint_note
}

# =============================================================== F04-8 case-distinct paths
if (Want 'F04-8') {
    $m = New-PathMap
    $m['a.txt'] = 'hash_lower'; $m['A.txt'] = 'hash_upper'
    Check 'F04-8' 'path map is ordinal: a.txt + A.txt -> 2 keys' ($m.Count -eq 2 -and $m['a.txt'] -eq 'hash_lower') "key_count=$($m.Count), a.txt -> $($m['a.txt'])"
    $cs = Join-Path $work 'cs-repo'
    if (Test-Path $cs) { Remove-Item $cs -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($cs)
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; $fsu = & fsutil.exe file setCaseSensitiveInfo $cs enable 2>&1; $ErrorActionPreference = $p
    $null = G $cs @('init', '-q'); $null = G $cs @('config', 'user.email', 't@e.com'); $null = G $cs @('config', 'user.name', 'T')
    [IO.File]::WriteAllText((Join-Path $cs 'base.txt'), "b`n", $u8); $null = G $cs @('add', '-A'); $null = G $cs @('commit', '-q', '-m', 'i')
    [IO.File]::WriteAllText((Join-Path $cs 'a.txt'), "lower`n", $u8)
    [IO.File]::WriteAllText((Join-Path $cs 'A.txt'), "UPPER`n", $u8)
    $files = @(Get-ChildItem -LiteralPath $cs -File | ForEach-Object { $_.Name }) -join ','
    $f1 = Get-RevisionInfo -Root $cs
    $lines = @($f1.manifest -split "`n" | Where-Object { $_ -match '^\?\? ' })
    $blobs = @($lines | ForEach-Object { $_.Split(' ')[2] } | Select-Object -Unique)
    Check 'F04-8' 'case-sensitive dir: a.txt and A.txt get their own blob ids' ($lines.Count -eq 2 -and $blobs.Count -eq 2) "files=$files; $($lines -join ' | ')"
    [IO.File]::WriteAllText((Join-Path $cs 'a.txt'), "lower edited`n", $u8)
    $f2 = Get-RevisionInfo -Root $cs
    [IO.File]::WriteAllText((Join-Path $cs 'A.txt'), "UPPER edited`n", $u8)
    $f3 = Get-RevisionInfo -Root $cs
    Check 'F04-8' 'editing either case-twin changes tree_sha256' ($f1.tree_sha256 -ne $f2.tree_sha256 -and $f2.tree_sha256 -ne $f3.tree_sha256) "$($f1.tree_sha256.Substring(0,12)) -> $($f2.tree_sha256.Substring(0,12)) -> $($f3.tree_sha256.Substring(0,12))"
}

# =============================================================== F04-9 brief / artifact drift
if (Want 'F04-9') {
    $r = New-Repo 'f9'
    $brief = Join-Path $r '.collab\t\handoffs\01-claude-brief.md'
    $art = Join-Path $r 'build.bin'   # ignored by .gitignore: outside the tree fingerprint
    [IO.File]::WriteAllText($art, "binary`n", $u8)
    $x = Run-Consult $r @('-Brief', '.collab/t/handoffs/01-claude-brief.md', '-Artifact', 'build.bin', '-ReplyName', 'drift') @{ FAKE_CODEX_REPLY = (Reply 'f9.json' $advise); FAKE_CODEX_TOUCH = "$brief;$art" }
    $e = Last-Entry $r
    $md = [IO.File]::ReadAllText((Join-Path $r '.collab\t\handoffs\02-codex-drift.md'))
    Check 'F04-9' 'brief edited mid-run -> brief_changed_during_review + after-hash + header WARNING' ($e.brief_changed_during_review -eq $true -and $e.brief_sha256_after -eq (Sha $brief).ToLower() -and $e.brief_sha256 -ne $e.brief_sha256_after -and $md -match 'WARNING: the brief changed during the review') "tree_changed=$($e.tree_changed_during_review)"
    Check 'F04-9' 'ignored artifact edited mid-run -> artifacts_changed_during_review + sha256_after + WARNING' ($e.artifacts_changed_during_review -eq $true -and @($e.artifacts)[0].sha256_after -eq (Sha $art).ToLower() -and $md -match 'WARNING: artifact\(s\) changed during the review: build\.bin') "artifacts[0]: $(@($e.artifacts)[0].sha256.Substring(0,12)) -> $(@($e.artifacts)[0].sha256_after.Substring(0,12))"
    $y = Run-Consult $r @('-Brief', '.collab/t/handoffs/01-claude-brief.md', '-Artifact', 'build.bin', '-ReplyName', 'stable') @{ FAKE_CODEX_REPLY = (Reply 'f9b.json' $advise) }
    $e2 = Last-Entry $r
    Check 'F04-9' 'untouched inputs -> both drift flags false' ($e2.brief_changed_during_review -eq $false -and $e2.artifacts_changed_during_review -eq $false) ''
}

# =============================================================== F04-10 a surviving codex child keeps the task locked
if (Want 'F04-10') {
    $r = New-Repo 'f10'
    $td = Join-Path $r '.collab\t'
    $pidFile = Join-Path $work 'f10-child.pid'
    if (Test-Path $pidFile) { Remove-Item $pidFile }
    Clear-FakeEnv
    $env:FAKE_CODEX_REPLY = (Reply 'f10.json' $advise); $env:FAKE_CODEX_SLEEP = '25'; $env:FAKE_CODEX_PIDFILE = $pidFile
    $bridge = Start-Process powershell.exe -WorkingDirectory $r -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-CodexExe', $fake, '-Prompt', 'x', '-ReplyName', 'killed')
    Clear-FakeEnv
    for ($i = 0; $i -lt 60 -and -not (Test-Path $pidFile); $i++) { Start-Sleep -Milliseconds 250 }
    Start-Sleep -Milliseconds 500
    Stop-Process -Id $bridge.Id -Force      # the bridge dies; its codex child does not
    $bridge.WaitForExit()
    $pend = Join-Path $td '.consult.pending.json'
    $rec = (Read-PendingFile -Path $pend).Record
    $childAlive = [bool]($rec -and (Get-Process -Id $rec.child_pid -ErrorAction SilentlyContinue))
    Check 'F04-10' 'bridge killed: pending record says running with n/nn/reply/child_pid, child alive' ([bool]($rec -and $rec.state -eq 'running' -and $rec.n -eq 1 -and $rec.nn -eq '02' -and $rec.child_pid -gt 0 -and $childAlive)) "pending: state=$($rec.state) n=$($rec.n) nn=$($rec.nn) reply=$($rec.reply) child_pid=$($rec.child_pid)"
    $x = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'second') @{ FAKE_CODEX_REPLY = (Reply 'f10b.json' $advise) }
    Check 'F04-10' 'next consult refused while that codex child lives' ($x.Code -eq 1 -and $x.Out -match "a previous consultation's codex process \(pid $($rec.child_pid)\) is still running") (($x.Out -split "`n")[0])
    $f = Run-Findings $r @('-List')
    Check 'F04-10' '-List (read-only) still works meanwhile and shows the pending record' ($f.Code -eq 0 -and $f.Out -match 'pending: state=running, n=1, nn=02') (($f.Out -split "`n" | Where-Object { $_ -match '^pending' }) -join '')
    # the child ends (here: killed); the next run proceeds past the reservation
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; & taskkill.exe /PID $rec.child_pid /T /F 2>&1 | Out-Null; $ErrorActionPreference = $p
    Start-Sleep -Milliseconds 500
    $y = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'third') @{ FAKE_CODEX_REPLY = (Reply 'f10c.json' $advise) }
    $e = Last-Entry $r
    Check 'F04-10' 'after the child is gone: run proceeds, recovers n=1/nn=02, commits n=2 as 03-codex-third.md' ($y.Code -eq 0 -and $y.Out -match 'recovered reservation n=1, nn=02' -and $e.n -eq 2 -and $e.reply -eq 'handoffs/03-codex-third.md' -and -not (Test-Path $pend)) "n=$($e.n) reply=$($e.reply)"
    # a 'survivors' record (what the timeout branch writes when the kill leaves survivors)
    $sleeper = Start-Process powershell.exe -ArgumentList '-NoProfile', '-Command', 'Start-Sleep 30' -PassThru -WindowStyle Hidden
    Start-Sleep -Milliseconds 800
    # wave 3b: survivors are { pid, start_time, name } entries (a bare pid of a plain
    # powershell would correctly NOT count as a live codex survivor any more)
    $sleeperStart = (Get-Process -Id $sleeper.Id).StartTime.ToUniversalTime().ToString('o')
    [IO.File]::WriteAllText($pend, '{"state":"survivors","n":3,"nn":"04","reply":"handoffs/04-codex-z.md","started":"2026-09-24T00:00:00+02:00","pid":1,"host":"' + [Environment]::MachineName + '","launcher":"","child_pid":null,"child_start_time":"","survivors":[{"pid":' + $sleeper.Id + ',"start_time":"' + $sleeperStart + '","name":"powershell"}],"note":""}', $u8)
    $z = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'fourth') @{ FAKE_CODEX_REPLY = (Reply 'f10d.json' $advise) }
    Check 'F04-10' 'recorded timeout survivor alive -> next consult refused' ($z.Code -eq 1 -and $z.Out -match "\(pid $($sleeper.Id)\) is still running") (($z.Out -split "`n")[0])
    Stop-Process -Id $sleeper.Id -Force; $sleeper.WaitForExit()
    $w = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'fifth') @{ FAKE_CODEX_REPLY = (Reply 'f10e.json' $advise) }
    Check 'F04-10' 'survivor gone -> run proceeds' ($w.Code -eq 0 -and $w.Out -match 'recovered reservation n=3, nn=04') ''
    # the real timeout path: the whole tree is killed, nothing survives, no pending record left
    $t = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'timeout', '-TimeoutSec', '3') @{ FAKE_CODEX_REPLY = (Reply 'f10f.json' $advise); FAKE_CODEX_SLEEP = '40'; FAKE_CODEX_PIDFILE = $pidFile }
    $gpid = [int](Get-Content $pidFile)
    Check 'F04-10' 'timeout: tree killed, fake grandchild dead, pending removed, lock not held' ($t.Code -eq 1 -and $t.Out -match 'process tree killed\)' -and -not (Get-Process -Id $gpid -ErrorAction SilentlyContinue) -and -not (Test-Path $pend) -and -not (Test-LockHeld (Join-Path $td '.consult.lock'))) (($t.Out -split "`n")[0])
}

# =============================================================== F04-11 raw companion must be preserved
if (Want 'F04-11') {
    # (wave 28b, D19) every row reports FAIL with what was missing instead of stopping with an exception
    $r = New-Repo 'f11'
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs\02-codex-eleven.reply.json'))   # blocks the copy
    $withF = Reply 'f11.json' ($advise -replace '"findings":\[\]', '"findings":[{"severity":"major","locations":[],"claim":"c","trigger":"t","evidence":[],"verification":"v","remedy":"r","supersedes":[]}]')
    $why = ''
    $x = $null; $e = $null
    try { $x = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'eleven') @{ FAKE_CODEX_REPLY = $withF } } catch { $why += " | the run threw: $($_.Exception.Message)" }
    try { $e = Last-Entry $r } catch { $why += " | the ledger could not be read ($($_.Exception.Message))" }
    $outcome = $(if ($e) { [string]$e.bridge_outcome } else { '(no ledger entry)' })
    $kept = if ($outcome -match 'original kept at (\S+)$') { $Matches[1] } else { '' }
    $keptSame = $false
    try { $keptSame = ($kept -and (Test-Path $kept) -and (Sha $kept) -eq (Sha $withF)) } catch { $why += " | the kept original could not be compared ($($_.Exception.Message))" }
    Check 'F04-11' 'copy fails -> exit 1, failed outcome naming the kept original' ($null -ne $x -and $x.Code -eq 1 -and $outcome -match '^failed: could not preserve the raw reply \(.+\); original kept at ' -and $keptSame) "exit $(if ($x) { $x.Code } else { '(none)' }); bridge_outcome='$outcome'$why"
    $lockHeld = $true; try { $lockHeld = Test-LockHeld (Join-Path $r '.collab\t\.consult.lock') } catch { $why += " | the lock could not be tested ($($_.Exception.Message))" }
    Check 'F04-11' 'no findings, no verdict, reply_json empty, ledger entry appended, lock not held, pending removed' ($null -ne $e -and -not (Test-Path (Join-Path $r '.collab\t\findings.json')) -and $e.verdict -eq '' -and $e.reply_json -eq '' -and $e.n -eq 1 -and -not $lockHeld -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) "$(if ($e) { "verdict='$($e.verdict)' reply_json='$($e.reply_json)' n=$($e.n)" } else { 'no ledger entry' }); lock held=$lockHeld$why"
    $mdPath = Join-Path $r '.collab\t\handoffs\02-codex-eleven.md'
    $md = ''
    try { $md = [IO.File]::ReadAllText($mdPath) } catch { $why += " | the handoff $mdPath could not be read ($($_.Exception.Message))" }
    Check 'F04-11' 'header shows the failure, no link to a reply.json' ($md -and $md -match 'Bridge outcome: failed: could not preserve' -and $md -notmatch 'Structured reply: `handoffs') "$(if (-not $md) { 'no handoff' })$why"
    if ($kept) { Remove-Item $kept -ErrorAction SilentlyContinue }
}

# =============================================================== E27 the Codex desktop app's servers are no reviewer run
if (Want 'E27') {
    # (wave 29, E27) The machine-wide "looks like codex" rule (Get-CodexRule, Find-CodexProcesses) leaves
    # out a codex-named process whose command line shows it is one of the Codex desktop app's servers or
    # helpers - they run whenever the app is open and kept an interrupted task blocked (F04-10 failed with
    # the app open) - and still matches `codex exec ...` and a codex whose command line cannot be read.
    # UNIT: Get-CodexMatch / Get-CodexRule on synthetic (name, command line) pairs - the app's real lines.
    # SCAN: real processes NAMED codex.exe - copies of cmd.exe whose first arguments are the app's (cmd
    # skips them and runs its /c ping) - started after a 'launching' recovery record of the task.
    $unit = @(
        @('codex.exe', 'C:\Users\u\AppData\Local\OpenAI\Codex\bin\5ea2\codex.exe -c features.code_mode_host=true app-server --analytics-default-enabled -c plugins.x=1', '', '', 'codex app-server'),
        @('codex.exe', 'C:\Users\u\AppData\Local\OpenAI\Codex\bin\5ea2\codex.exe exec-server --remote https://codex-cloud-environments.chatgpt.com/api --environment-id e1', '', '', 'codex exec-server'),
        @('codex-computer-use-swift.exe', 'C:\Users\u\AppData\Local\OpenAI\Codex\runtimes\cua_node\x\codex-computer-use-swift.exe --parent-pid 22140', '', '', 'codex-computer-use-swift helper'),
        @('codex', 'codex mcp-server', '', '', 'codex mcp-server'),
        @('codex', 'codex login status', '', '', 'codex login'),
        @('codex.exe', '"C:\x y\codex.exe" app', '', '', 'codex app'),
        @('codex.exe', '"C:\x\codex.exe" --parent-pid 7', '', '', 'codex helper (--parent-pid, no exec)'),
        @('codex.exe', '"C:\t\codex.exe" app-server', 'C:\t\codex.exe', '', 'codex app-server'),
        @('codex.exe', 'codex.exe exec --json -', '', 'name codex', ''),
        @('codex', 'codex exec --sandbox read-only --color never --json -m m1 -c model_reasoning_effort="high" -o C:\t\last.txt -', '', 'name codex', ''),
        @('codex.exe', '"C:\x\codex.exe" exec --parent-pid 7', '', 'name codex', ''),
        @('codex.exe', 'codex.exe -c app-server=1 exec -', '', 'name codex', ''),
        @('codex.exe', 'codex.exe', '', 'name codex', ''),
        @('codex.exe', '', '', 'name codex', ''),
        @('codex', '[codex]', '', 'name codex', ''),
        @('node.exe', 'node C:\npm\node_modules\@openai\codex\bin\codex.js exec -', '', '@openai/codex in command line', ''),
        @('cmd.exe', 'cmd /c "C:\t\fake-codex.cmd" exec -', 'C:\t\fake-codex.cmd', 'launcher in command line', '')
    )
    $unitBad = @(foreach ($u in $unit) {
        $m = Get-CodexMatch -Name $u[0] -Cmd $u[1] -Launcher $u[2]
        $rr = Get-CodexRule -Name $u[0] -Cmd $u[1] -Launcher $u[2]
        if ([string]$m.Rule -cne $u[3] -or [string]$m.Excluded -cne $u[4] -or $rr -cne $u[3]) { "$($u[0]) '$($u[1])' -> rule '$($m.Rule)' / '$rr' excluded '$($m.Excluded)'" }
    })
    Check 'E27' 'UNIT Get-CodexMatch / Get-CodexRule: a codex-named app-server (after -c key=value), exec-server, mcp-server, login, app, codex-computer-use*, --parent-pid without exec - NOT matched, Excluded says what it is (the recorded launcher on it too); codex exec / codex.exe exec (also with --parent-pid, also -c app-server=1 before exec), a codex without arguments, an unreadable command line ('''' and ps''s [codex]), @openai/codex and the launcher in a command line - matched as before' ($unitBad.Count -eq 0) ($unitBad -join ' // ')
    # (wave 29, E28 / F37-1) the escaped-quote reviewer (astra's encoding and the coordinator's), exec hidden
    # by quoting, the word exec inside a server's value, Windows quoting (\" and "" inside a value) on a
    # real server, unbalanced quoting
    $unit28 = @(
        @('codex.exe', 'codex.exe -c "developer_instructions=\"please app-server check\"" exec --json -', '', 'name codex', ''),
        @('codex.exe', 'codex.exe -c developer_instructions="please \"app-server\" check" exec --json -', '', 'name codex', ''),
        @('codex.exe', 'codex.exe -c "a=\"app-server\"" e"x"ec -', '', 'name codex', ''),
        @('codex.exe', 'codex.exe -c "developer_instructions=never exec here" app-server', '', 'name codex', ''),
        @('codex.exe', 'codex.exe -c "x=\"y\"" app-server --analytics-default-enabled', '', '', 'codex app-server'),
        @('codex.exe', 'codex.exe -c "x=""y"" z" app-server', '', '', 'codex app-server'),
        @('codex.exe', 'codex.exe -c "x=\"y app-server', '', 'command line ambiguous - counted as codex', ''),
        @('codex.exe', '"C:\x\codex.exe app-server', '', 'command line ambiguous - counted as codex', ''),
        @('codex-command-runner.exe', 'codex-command-runner.exe "x', '', 'command line ambiguous - counted as codex', '')
    )
    $unit28Bad = @(foreach ($u in $unit28) {
        $m = Get-CodexMatch -Name $u[0] -Cmd $u[1] -Launcher $u[2]
        if ([string]$m.Rule -cne $u[3] -or [string]$m.Excluded -cne $u[4]) { "$($u[0]) '$($u[1])' -> rule '$($m.Rule)' excluded '$($m.Excluded)'" }
    })
    $split28 = Split-CommandLineTokens -Cmd 'codex.exe -c "developer_instructions=\"please app-server check\"" exec --json -'
    $splitU = Split-CommandLineTokens -Cmd 'codex.exe -c "x=\"y app-server'
    Check 'E28' 'UNIT (F37-1) Get-CodexMatch: a reviewer whose -c value carries backslash-escaped quotes around app-server (-c "developer_instructions=\"please app-server check\"" exec, and developer_instructions="please \"app-server\" check" exec), exec spelled e"x"ec, the word exec inside a server''s value - NEVER excluded (name codex); \" and "" inside a quoted value of a real app-server - still excluded; unbalanced quoting (in a value, in the program name, another codex-named program) - "command line ambiguous - counted as codex"; Split-CommandLineTokens gives the arguments the program sees' ($unit28Bad.Count -eq 0 -and ($split28.Tokens -join '|') -ceq 'codex.exe|-c|developer_instructions="please app-server check"|exec|--json|-' -and -not $split28.Ambiguous -and $splitU.Ambiguous -ceq 'unbalanced quoting (the command line ends inside quotes)') "$($unit28Bad -join ' // ') | tokens [$($split28.Tokens -join '|')] | ambiguous '$($splitU.Ambiguous)'"

    $r = New-Repo 'e27'
    $td = Join-Path $r '.collab\t'
    $pend = Join-Path $td '.consult.pending.json'
    $simDir = Join-Path $work 'e27-sim'
    [void][IO.Directory]::CreateDirectory($simDir)
    $simExe = Join-Path $simDir 'codex.exe'
    Copy-Item "$env:SystemRoot\System32\cmd.exe" $simExe -Force
    $sims = New-Object System.Collections.Generic.List[int]
    function Start-Sim { param([string]$Lead) $sp0 = Start-Process $simExe -ArgumentList "$Lead /d /c `"ping -n 300 127.0.0.1 >nul`"" -PassThru -WindowStyle Hidden; $sims.Add($sp0.Id); return $sp0 }
    function Stop-Sim { param([int]$Id) $p0 = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; & taskkill.exe /PID $Id /T /F 2>&1 | Out-Null; $ErrorActionPreference = $p0 }
    function Seed-Launching { param([int]$N, [string]$Nn) [IO.File]::WriteAllText($pend, '{"state":"launching","n":' + $N + ',"nn":"' + $Nn + '","reply":"handoffs/' + $Nn + '-codex-old.md","started":"' + $e27Started + '","pid":1,"host":"' + [Environment]::MachineName + '","launcher":' + (ConvertTo-Json $fake) + ',"child_pid":null,"child_start_time":"","survivors":[],"note":""}', $u8) }
    function Found-List { param([string]$Out) if ($Out -match 'may still have its codex process running: (.*?), found by ') { return $Matches[1] }; return '' }
    try {
        # (a) app-server and (b) exec-server: they run, the run proceeds and says what it left out. Every
        # record of this case starts BEFORE them: each scan below sees them and leaves them out by the rule.
        $scanStart = Get-Date
        $e27Started = Get-IsoTimestamp ($scanStart.AddSeconds(-2))
        Seed-Launching 4 '05'
        $srv = Start-Sim '-c features.code_mode_host=true app-server --analytics-default-enabled'
        $exs = Start-Sim 'exec-server --remote https://codex-cloud-environments.invalid/api --environment-id e27'
        Start-Sleep -Milliseconds 800
        $direct = Find-CodexProcesses -Since $scanStart.AddSeconds(-1) -Launcher $fake
        $dFound = @(@($direct.Found) | Where-Object { $_.pid -eq $srv.Id -or $_.pid -eq $exs.Id }).Count
        $dExcl = (@(@($direct.Excluded) | Where-Object { ($_.pid -eq $srv.Id -and $_.why -eq 'codex app-server') -or ($_.pid -eq $exs.Id -and $_.why -eq 'codex exec-server') }).Count -eq 2)
        Check 'E27' '(a)(b) Find-CodexProcesses (machine-wide): a running codex.exe -c ... app-server and a codex.exe exec-server --remote ... are not found; Excluded names them ({pid, name, why}) and Check says "excluded: pid <n> codex.exe [codex app-server], ..."' (-not $direct.Failed -and $dFound -eq 0 -and $dExcl -and $direct.Check -match ("excluded: .*pid $($srv.Id) codex\.exe \[codex app-server\]") -and $direct.Check -match ("pid $($exs.Id) codex\.exe \[codex exec-server\]")) "found $dFound of ours | $($direct.Check)"
        $x = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'servers') @{ FAKE_CODEX_REPLY = (Reply 'e27a.json' $advise) }
        $bothAlive = [bool]((Get-Process -Id $srv.Id -ErrorAction SilentlyContinue) -and (Get-Process -Id $exs.Id -ErrorAction SilentlyContinue))
        $rec = (($x.Out -split "`n") | Where-Object { $_ -match 'recovered reservation' }) -join ' '
        Check 'E27' '(a)(b) launching record + the app''s servers running (still alive afterwards): the run PROCEEDS (exit 0) - "recovered reservation n=4, nn=05 (... Win32_Process scan (...; excluded: pid <n> codex.exe [codex app-server], pid <n> codex.exe [codex exec-server]): none found)" - the record gone' ($x.Code -eq 0 -and $bothAlive -and $rec -match "recovered reservation n=4, nn=05 \(state 'launching' of an interrupted run; .*excluded: .*pid $($srv.Id) codex\.exe \[codex app-server\].*\): none found" -and $rec -match "pid $($exs.Id) codex\.exe \[codex exec-server\]" -and -not (Test-Path -LiteralPath $pend)) "exit $($x.Code) alive $bothAlive | $rec"
        # (c) codex.exe exec ...: refused while it runs, the servers still not counted
        Seed-Launching 10 '12'
        $ex = Start-Sim 'exec --json -'
        Start-Sleep -Milliseconds 800
        $y = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'exec') @{ FAKE_CODEX_REPLY = (Reply 'e27c.json' $advise) }
        $yl = Found-List $y.Out
        Check 'E27' '(c) a codex.exe exec --json - started after the record: REFUSED (exit 1) "may still have its codex process running: pid <n> codex.exe [name codex, task not verifiable], found by ... excluded: pid <n> codex.exe [codex app-server] ..."; the app-server and exec-server (started after the record too) not in that list but named as excluded; the record kept' ($y.Code -eq 1 -and $yl.Contains("pid $($ex.Id) codex.exe [name codex, task not verifiable]") -and -not $yl.Contains("pid $($srv.Id) ") -and -not $yl.Contains("pid $($exs.Id) ") -and $y.Out -match ("found by .*excluded: .*pid $($srv.Id) codex\.exe \[codex app-server\]") -and $y.Out -match ("pid $($exs.Id) codex\.exe \[codex exec-server\]") -and (Test-Path -LiteralPath $pend)) "exit $($y.Code) | found: $yl | $((($y.Out -split "`n") | Select-Object -First 1))"
        Stop-Sim $ex.Id
        Start-Sleep -Milliseconds 500
        $y2 = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'exec2') @{ FAKE_CODEX_REPLY = (Reply 'e27c2.json' $advise) }
        Check 'E27' '(c) that exec gone, the servers still running: the run proceeds (recovered reservation n=10, nn=12)' ($y2.Code -eq 0 -and $y2.Out -match 'recovered reservation n=10, nn=12' -and -not (Test-Path -LiteralPath $pend)) "exit $($y2.Code) | $((($y2.Out -split "`n") | Select-Object -First 1))"
        # (d) the same app-server command line, but unreadable (the hook): counted (fail-closed)
        Seed-Launching 20 '22'
        $hid = Start-Sim 'app-server --analytics-default-enabled'
        Start-Sleep -Milliseconds 800
        $z = $null
        try { $z = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'hidden') @{ FAKE_CODEX_REPLY = (Reply 'e27d.json' $advise); CODEX_CONSULT_TEST_CMDLINE_UNREADABLE = [string]$hid.Id } } finally { Remove-Item env:CODEX_CONSULT_TEST_CMDLINE_UNREADABLE -ErrorAction SilentlyContinue }
        $zl = Found-List $z.Out
        Check 'E27' '(d) a codex.exe app-server whose command line cannot be read (CODEX_CONSULT_TEST_CMDLINE_UNREADABLE=<pid>, honoured by the scan too): REFUSED (exit 1) "pid <n> codex.exe [name codex, task not verifiable]" - unknown stays suspicious; the readable servers not in that list; the record kept' ($z.Code -eq 1 -and $zl.Contains("pid $($hid.Id) codex.exe [name codex, task not verifiable]") -and -not $zl.Contains("pid $($srv.Id) ") -and (Test-Path -LiteralPath $pend)) "exit $($z.Code) | found: $zl"
        $w = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'readable') @{ FAKE_CODEX_REPLY = (Reply 'e27e.json' $advise) }
        $wr = (($w.Out -split "`n") | Where-Object { $_ -match 'recovered reservation' }) -join ' '
        Check 'E27' '(d) the same process with its command line read (no hook): excluded as codex app-server, with the other two - the run proceeds (recovered reservation n=20, nn=22)' ($w.Code -eq 0 -and $wr -match "recovered reservation n=20, nn=22 .*pid $($hid.Id) codex\.exe \[codex app-server\]" -and $wr -match "pid $($srv.Id) codex\.exe \[codex app-server\]" -and $wr -match "pid $($exs.Id) codex\.exe \[codex exec-server\]" -and -not (Test-Path -LiteralPath $pend)) "exit $($w.Code) | $wr"

        # (wave 29, E28 / F37-1) REAL reviewers whose global -c value carries backslash-escaped quotes around
        # app-server - astra's encoding -c "developer_instructions=\"please app-server check\"" (which E27
        # took for a codex app-server) and the coordinator's -c developer_instructions="please \"app-server\"
        # check" - followed by exec --json -, beneath a DEAD, UNRECORDED intermediate: launcher (recorded as
        # the child, stopped) -> intermediate (stopped) -> the two reviewers (alive). A panel member's record
        # with kill_unconfirmed: only the machine-wide check can see them (unknown-tree recovery, E23/E25).
        $r28 = New-Repo 'e28'
        $pend28 = Join-Path $r28 '.collab\t\.consult.pending-02.json'
        $chainDir = Join-Path $work 'e28-chain'
        [void][IO.Directory]::CreateDirectory($chainDir)
        [IO.File]::WriteAllText((Join-Path $chainDir 'args-a.txt'), '-c "developer_instructions=\"please app-server check\"" exec --json - /d /c "ping -n 300 127.0.0.1 >nul"', $u8)
        [IO.File]::WriteAllText((Join-Path $chainDir 'args-b.txt'), '-c developer_instructions="please \"app-server\" check" exec --json - /d /c "ping -n 300 127.0.0.1 >nul"', $u8)
        $chainPs = Join-Path $work 'e28-chain.ps1'
        [IO.File]::WriteAllText($chainPs, @'
param([string]$Role, [string]$Exe, [string]$Dir)
if ($Role -eq 'top') {
    $m = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'), 'mid', ('"' + $Exe + '"'), ('"' + $Dir + '"')) -PassThru -WindowStyle Hidden
    [IO.File]::WriteAllText((Join-Path $Dir 'mid.pid'), [string]$m.Id)
} else {
    $a = Start-Process -FilePath $Exe -ArgumentList ([IO.File]::ReadAllText((Join-Path $Dir 'args-a.txt'))) -PassThru -WindowStyle Hidden
    $b = Start-Process -FilePath $Exe -ArgumentList ([IO.File]::ReadAllText((Join-Path $Dir 'args-b.txt'))) -PassThru -WindowStyle Hidden
    [IO.File]::WriteAllText((Join-Path $Dir 'reviewers.tmp'), "$($a.Id),$($b.Id)")
    [IO.File]::Move((Join-Path $Dir 'reviewers.tmp'), (Join-Path $Dir 'reviewers.pid'))
}
Start-Sleep 300
'@, $u8)
        $top = Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$chainPs`"", 'top', "`"$simExe`"", "`"$chainDir`"") -PassThru -WindowStyle Hidden
        $wc = [Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Path -LiteralPath (Join-Path $chainDir 'reviewers.pid')) -and $wc.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 200 }
        $midId = 0; try { [void][int]::TryParse(([IO.File]::ReadAllText((Join-Path $chainDir 'mid.pid'))).Trim(), [ref]$midId) } catch { }
        $revIds = @(); try { $revIds = @(([IO.File]::ReadAllText((Join-Path $chainDir 'reviewers.pid'))).Split(',') | ForEach-Object { [int]$_ }) } catch { }
        foreach ($id in $revIds) { $sims.Add($id) }
        if ($midId -gt 0) { $sims.Add($midId) }
        $sims.Add($top.Id)
        $topStart = [string](Get-ProcessStartIso -ProcessId $top.Id)
        foreach ($id in @($top.Id, $midId)) { if ($id -gt 0) { try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch { } } }
        $wc = [Diagnostics.Stopwatch]::StartNew()
        while ((($midId -gt 0 -and (Get-Process -Id $midId -ErrorAction SilentlyContinue)) -or (Get-Process -Id $top.Id -ErrorAction SilentlyContinue)) -and $wc.Elapsed.TotalSeconds -lt 10) { Start-Sleep -Milliseconds 100 }
        $revA = $(if ($revIds.Count -ge 1) { $revIds[0] } else { 0 })
        $revB = $(if ($revIds.Count -ge 2) { $revIds[1] } else { 0 })
        $revCmdA = ''; $revCmdB = ''
        try { $revCmdA = [string](Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$revA" -ErrorAction Stop).CommandLine; $revCmdB = [string](Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$revB" -ErrorAction Stop).CommandLine } catch { }
        $revParent = 0; try { $revParent = [int](Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$revA" -ErrorAction Stop).ParentProcessId } catch { }
        $chainOk = ($revA -gt 0 -and $revB -gt 0 -and $midId -gt 0 -and $revParent -eq $midId -and -not (Get-Process -Id $midId -ErrorAction SilentlyContinue) -and (Get-Process -Id $revA -ErrorAction SilentlyContinue) -and (Get-Process -Id $revB -ErrorAction SilentlyContinue) -and $revCmdA.Contains('-c "developer_instructions=\"please app-server check\"" exec --json -') -and $revCmdB.Contains('-c developer_instructions="please \"app-server\" check" exec --json -'))
        # the scan itself: both reviewers found as codex, never excluded; the app-like servers excluded
        $scan28 = Find-CodexProcesses -Since $scanStart.AddSeconds(-2) -Launcher $fake
        $foundIds = @(@($scan28.Found) | ForEach-Object { [int]$_.pid })
        $exclIds = @(@($scan28.Excluded) | ForEach-Object { [int]$_.pid })
        $revRules = @(@($scan28.Found) | Where-Object { $_.pid -eq $revA -or $_.pid -eq $revB } | ForEach-Object { $_.rule } | Select-Object -Unique)
        Check 'E28' '(F37-1) Find-CodexProcesses with the two escaped-quote reviewers alive beneath their dead intermediate (their command lines read back as launched): both FOUND ([name codex, task not verifiable]), neither in Excluded or in "excluded: ..."; the app-like servers (a), (b), (d) still excluded as codex app-server / exec-server' ($chainOk -and $foundIds -contains $revA -and $foundIds -contains $revB -and ($revRules -join '|') -ceq 'name codex, task not verifiable' -and $exclIds -notcontains $revA -and $exclIds -notcontains $revB -and $scan28.Check -notmatch "pid ($revA|$revB) " -and $exclIds -contains $srv.Id -and $exclIds -contains $exs.Id -and $exclIds -contains $hid.Id -and $scan28.Check -match "pid $($srv.Id) codex\.exe \[codex app-server\]") "chain ok $chainOk (mid $midId, reviewers $revA $revB, parent $revParent) | found [$($foundIds -join ',')] rules [$($revRules -join '|')] excluded [$($exclIds -join ',')] | A: $revCmdA"
        $panelId = [guid]::NewGuid().ToString()
        [IO.File]::WriteAllText($pend28, '{"state":"survivors","n":2,"nn":"02","reply":"handoffs/02-codex-m-openai.md","events":"","consult_id":"","started":"' + $e27Started + '","pid":999998,"host":"' + [Environment]::MachineName + '","launcher":' + (ConvertTo-Json $fake) + ',"engine":"codex","child_pid":' + $top.Id + ',"child_start_time":"' + $topStart + '","survivors":[],"unverified":[],"kill_unconfirmed":"the children could not be enumerated (test)","note":"","panel":{"id":"' + $panelId + '","position":2,"of":2,"parent_pid":999997,"parent_start_time":""}}', $u8)
        $text28 = [IO.File]::ReadAllText($pend28)
        $log28 = Join-Path $work 'e28-fake.log'
        $q1 = Run-Consult $r28 @('-Prompt', 'x', '-ReplyName', 'q1') @{ FAKE_CODEX_REPLY = (Reply 'e28a.json' $advise); FAKE_CODEX_LOG = $log28 }
        $q1List = $(if ($q1.Out -match 'a codex-like process runs: (.*?) - this panel member''s unknown tree is released only when no such process runs') { $Matches[1] } else { '' })
        Check 'E28' '(F37-1) the unknown-tree recovery of that panel member''s record (kill_unconfirmed, the writer and the recorded launcher dead) while the reviewers live: REFUSED (exit 1) "... left an UNKNOWN process tree - ... - and a codex-like process runs: pid <A> codex.exe (task not verifiable), pid <B> codex.exe (task not verifiable) - this panel member''s unknown tree is released only when no such process runs"; no reviewer launched, the record byte-identical' ($chainOk -and $q1.Code -eq 1 -and $q1.Out -match 'left an UNKNOWN process tree - the kill of its codex run was not confirmed \(the children could not be enumerated \(test\)\)' -and $q1List.Contains("pid $revA codex.exe (task not verifiable)") -and $q1List.Contains("pid $revB codex.exe (task not verifiable)") -and -not (Test-Path -LiteralPath $log28) -and (Test-Path -LiteralPath $pend28) -and [IO.File]::ReadAllText($pend28) -ceq $text28) "exit $($q1.Code) | runs: $q1List | $((($q1.Out -split "`n") | Select-Object -First 1))"
        foreach ($id in @($revA, $revB)) { if ($id -gt 0) { Stop-Sim $id } }
        $wc = [Diagnostics.Stopwatch]::StartNew()
        while ((($revA -gt 0 -and (Get-Process -Id $revA -ErrorAction SilentlyContinue)) -or ($revB -gt 0 -and (Get-Process -Id $revB -ErrorAction SilentlyContinue))) -and $wc.Elapsed.TotalSeconds -lt 10) { Start-Sleep -Milliseconds 100 }
        $q2 = Run-Consult $r28 @('-Prompt', 'x', '-ReplyName', 'q2') @{ FAKE_CODEX_REPLY = (Reply 'e28b.json' $advise); FAKE_CODEX_LOG = $log28 }
        $q2r = (($q2.Out -split "`n") | Where-Object { $_ -match 'recovered reservation' }) -join ' '
        Check 'E28' '(F37-1) the reviewers gone, the app-like servers still running: the record is RELEASED - "recovered reservation n=2, nn=02 (.consult.pending-02.json: state ''survivors'' ...; unknown tree after an unconfirmed kill: the scan found no codex-like process under pid 999998, <launcher> since <started> - released (... excluded: pid <n> codex.exe [codex app-server] ...))" - the reviewer launched, the record gone' ($q2.Code -eq 0 -and $q2r -match ("recovered reservation n=2, nn=02 \(\.consult\.pending-02\.json: state 'survivors' of an interrupted run; .*unknown tree after an unconfirmed kill: the scan found no codex-like process under pid 999998, $($top.Id) since .* - released \(") -and $q2r -match "excluded: .*pid $($srv.Id) codex\.exe \[codex app-server\]" -and $q2r -notmatch "pid ($revA|$revB) " -and (Test-Path -LiteralPath $log28) -and -not (Test-Path -LiteralPath $pend28)) "exit $($q2.Code) | $q2r"
    } finally {
        foreach ($id in $sims) { Stop-Sim $id }
        Start-Sleep -Milliseconds 300
    }
}

} finally {
    Remove-TestWork $work
}

Write-Host ""
Write-Host "harness-fixes: $script:fails failure(s)."
if ($script:fails -gt 0) { exit 1 }
exit 0
