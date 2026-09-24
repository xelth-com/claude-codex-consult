# Demonstrates the fixes for review findings F04-1..F04-11 against the CURRENT scripts.
# Every assertion prints "PASS" or "FAIL" with its evidence. Uses the fake codex only.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
# These cases use the Codex home of the machine; a reviewer roster there
# (<codex home>/codex-consult-roster.json) must not change what they test: none = no roster.
$env:CODEX_CONSULT_ROSTER = 'none'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
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
    $r = New-Repo 'f11'
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs\02-codex-eleven.reply.json'))   # blocks the copy
    $withF = Reply 'f11.json' ($advise -replace '"findings":\[\]', '"findings":[{"severity":"major","locations":[],"claim":"c","trigger":"t","evidence":[],"verification":"v","remedy":"r","supersedes":[]}]')
    $x = Run-Consult $r @('-Prompt', 'x', '-ReplyName', 'eleven') @{ FAKE_CODEX_REPLY = $withF }
    $e = Last-Entry $r
    $kept = if ($e.bridge_outcome -match 'original kept at (\S+)$') { $Matches[1] } else { '' }
    Check 'F04-11' 'copy fails -> exit 1, failed outcome naming the kept original' ($x.Code -eq 1 -and $e.bridge_outcome -match '^failed: could not preserve the raw reply \(.+\); original kept at ' -and $kept -and (Test-Path $kept) -and (Sha $kept) -eq (Sha $withF)) "bridge_outcome='$($e.bridge_outcome)'"
    Check 'F04-11' 'no findings, no verdict, reply_json empty, ledger entry appended, lock not held, pending removed' (-not (Test-Path (Join-Path $r '.collab\t\findings.json')) -and $e.verdict -eq '' -and $e.reply_json -eq '' -and $e.n -eq 1 -and -not (Test-LockHeld (Join-Path $r '.collab\t\.consult.lock')) -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) ''
    $md = [IO.File]::ReadAllText((Join-Path $r '.collab\t\handoffs\02-codex-eleven.md'))
    Check 'F04-11' 'header shows the failure, no link to a reply.json' ($md -match 'Bridge outcome: failed: could not preserve' -and $md -notmatch 'Structured reply: `handoffs') ''
    if ($kept) { Remove-Item $kept -ErrorAction SilentlyContinue }
}

} finally {
    Remove-TestWork $work
}

Write-Host ""
Write-Host "harness-fixes: $script:fails failure(s)."
if ($script:fails -gt 0) { exit 1 }
exit 0
