# codex-consult wave 28d (0.5.0; a small fix round of the telemetry client and one warning -
# decisions D1-D8 of .collab/companions-2026-09-26/handoffs/51-...): REWRITE - the spool is rewritten
# atomically: the kept lines go to <spool file>.tmp, flushed, and the temporary file replaces the spool
# in one step; a crash between the two (the gated test hook CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH,
# a real process exit) leaves the spool whole, and the next rewrite replaces the stray .tmp (D1);
# MARKER - the forgetting marker heals itself: one whose owner is gone (or that names none) is removed
# by a producer or a sender (one line in .last notes), one whose owner lives blocks; -Forget removes
# it in `finally` (D2); LOCK - the flush lock is born with its owner (a temporary file moved into
# place; four racing processes: one lock), an ownerless lock is held for 30 s and removed after, a
# dead owner's at once, a living owner's never - 30 minutes old it is "sender stuck" in .last and
# -Status (D3); NOTSPOOLED - the not-spooled count is append-only, written without the telemetry
# lock, counted since the last flush (D4); KILL - survivors AND unverified descendants: the warning
# and the outcome text name both groups (D5); MODEL - the model comparison lower-cases both sides
# (D6); REREAD - the one-line ask repeated for a context_tokens member without a brief (D7), the
# re-read line outside the context estimate that decides thread reuse (D8); DOCS.
# FAKES ONLY: fake-codex3.cmd; CODEX_HOME points at scratch directories, CODEX_CONSULT_ROSTER at
# scratch files, CODEX_CONSULT_HEALTH is 'none', telemetry off and the intake a closed loopback port
# (http://127.0.0.1:9/ - nothing is ever sent anywhere); the host markers of the process that runs it
# are removed first; the API key variables hold dummy values. Runs under the host it is started with
# (powershell 5.1 or pwsh 7, Windows). Work files: $env:TEMP\codex-consult-tests\harness-fixes28d\
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
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-fixes28d') ([guid]::NewGuid().ToString('N'))
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
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ENV_DUMP', 'FAKE_CODEX_PRELINE')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH')
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
function Spool-Line { param([string]$Tag) return (ConvertTo-Json -Compress -InputObject ([pscustomobject]@{ v = 1; kind = 'complaint'; queued_unix = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); body = ('{"text":"' + $Tag + '"}') })) }
function LastNotes { param([string]$CodexHome) $f = Join-Path (Join-Path $CodexHome 'telemetry-spool') '.last'; if (-not (Test-Path -LiteralPath $f)) { return , ([string[]]@()) }; return , ([string[]]@(@((ConvertFrom-Json (Text $f)).notes) | Where-Object { $_ } | ForEach-Object { [string]$_ })) }
function Own-Record { param([string]$Token = '', [string]$Since = '') $o = [ordered]@{ pid = $PID; start_time = [string](Get-ProcessStartIso -ProcessId $PID) }; if ($Token) { $o['token'] = $Token }; $o['since'] = $(if ($Since) { $Since } else { Get-IsoTimestamp }); return (ConvertTo-Json -Compress -InputObject ([pscustomobject]$o)) }
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Join-Path $work 'advise.json'
[IO.File]::WriteAllText($advise, $adviseJson, $u8)
$sw = [pscustomobject]@{ On = $true; Text = 'on'; Source = 'test' }
$entry = [pscustomobject]@{ bridge_outcome = 'usable reply'; reviewer = [pscustomobject]@{ engine = 'codex'; model = 'gpt-5.1'; provider_config = [pscustomobject]@{ builtin = 'openai' } } }

try {

# =============================================================== REWRITE: the spool rewritten atomically (D1)
if (Want 'REWRITE') {
    $h = New-Home 'rewrite'
    $env:CODEX_HOME = $h
    $sd = Join-Path $h 'telemetry-spool'
    [void][IO.Directory]::CreateDirectory($sd)
    $sf = Join-Path $sd '2026-09-30.ndjson'
    $tmpF = "$sf.tmp"
    $all = @(1..4 | ForEach-Object { Spool-Line "r$_" })
    [IO.File]::WriteAllText($sf, (($all -join "`n") + "`n"), $u8)
    $before = Get-FileSha256 -Path $sf
    # the child removes the file's first line (read by itself: no JSON on a command line)
    $childPs = Join-Path $work 'rewrite-child.ps1'
    [IO.File]::WriteAllText($childPs, "param([string]`$Common, [string]`$Spool)`n. `$Common`n`$first = @([IO.File]::ReadAllText(`$Spool) -split ""``n"" | Where-Object { `$_.Trim() })[0]`n`$r = Remove-TelemetrySpoolLines -Path `$Spool -Lines @(`$first) -WaitMs 3000`nWrite-Output ('returned:[' + `$r + ']')`nexit 0`n", $u8)
    $crash = Run-Child $childPs @($commonPs, $sf) $h @{ CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH = '1' }
    $afterCrash = Get-FileSha256 -Path $sf
    $tmpLines = Lines $tmpF
    Check 'REWRITE' 'D1 (F48-1, F49-3) a crash between the temporary file and the replace (test hook CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH=1: the process exits 86 there): the spool file is WHOLE (byte-identical, 4 lines - nothing truncated in place), <spool file>.tmp holds the 3 kept lines, flushed' ($crash.Code -eq 86 -and $crash.Out -notmatch 'returned:' -and $afterCrash -eq $before -and (Lines $sf).Count -eq 4 -and $tmpLines.Count -eq 3 -and ($tmpLines -join '|') -eq (($all[1..3]) -join '|')) "exit $($crash.Code) | spool same $($afterCrash -eq $before) | tmp $($tmpLines.Count) line(s) | $($crash.Out)"
    # the stray .tmp holds something else (as a crash in an older rewrite could leave it): replaced
    [IO.File]::WriteAllText($tmpF, "garbage left by a crash`n" * 20, $u8)
    $r1 = Remove-TelemetrySpoolLines -Path $sf -Lines @($all[0]) -WaitMs 2000
    $now1 = Lines $sf
    Check 'REWRITE' 'D1 the next rewrite (no hook) replaces the stray .tmp: the spool holds exactly the 3 kept lines (nothing of the stray file), no .tmp is left, and it returns ''''' ($r1 -eq '' -and ($now1 -join '|') -eq (($all[1..3]) -join '|') -and -not (Test-Path -LiteralPath $tmpF)) "returned '$r1' | $($now1.Count) line(s) | tmp left $(Test-Path -LiteralPath $tmpF)"
    $gated = Run-Child $childPs @($commonPs, $sf) $h @{ CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH = '1'; CODEX_CONSULT_TEST_MODE = '' }
    $now2 = Lines $sf
    Check 'REWRITE' 'D1 the hook is gated: without CODEX_CONSULT_TEST_MODE=1 it is ignored - the child rewrites (exit 0, returned []), the spool holds lines 3 and 4, no .tmp' ($gated.Code -eq 0 -and $gated.Out -match 'returned:\[\]' -and ($now2 -join '|') -eq (($all[2..3]) -join '|') -and -not (Test-Path -LiteralPath $tmpF)) "exit $($gated.Code) | $($gated.Out) | $($now2.Count) line(s)"
    # under the telemetry lock: held elsewhere, the rewrite does not start (nothing half-done)
    $holdT = New-Object System.IO.FileStream((Join-Path $h 'telemetry.lock'), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $wt = [Diagnostics.Stopwatch]::StartNew()
    try { $r3 = Remove-TelemetrySpoolLines -Path $sf -Lines @($all[2]) -WaitMs 400 } finally { $holdT.Dispose() }
    $wt.Stop()
    $now3 = Lines $sf
    Check 'REWRITE' 'D1 the rewrite runs under the telemetry lock (no producer appends while the file is replaced): with the lock held by another handle it waits at most its bound (0.4 s) BEFORE starting and does nothing - "was not rewritten (the telemetry lock ... stayed busy ...)", the spool unchanged' ($r3 -match 'was not rewritten \(the telemetry lock .* stayed busy' -and $wt.Elapsed.TotalSeconds -lt 2 -and ($now3 -join '|') -eq (($all[2..3]) -join '|')) "'$r3' in $([Math]::Round($wt.Elapsed.TotalSeconds, 2)) s"
    $r4 = Remove-TelemetrySpoolLines -Path $sf -Lines @($all[2], $all[3]) -WaitMs 2000
    Check 'REWRITE' 'D1 a rewrite that keeps nothing deletes the spool file (no .tmp written)' ($r4 -eq '' -and -not (Test-Path -LiteralPath $sf) -and -not (Test-Path -LiteralPath $tmpF)) "returned '$r4'"
    $env:CODEX_HOME = $savedCodexHome
    $cm = Text $commonPs
    $fnText = $(if ($cm -match '(?s)\nfunction Remove-TelemetrySpoolLines \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    Check 'REWRITE' 'D1 the code: Remove-TelemetrySpoolLines never truncates in place (no SetLength), writes "$Path.tmp" with Flush($true) and replaces the file with a Move (MoveFileEx 0x9 on 5.1) under Enter-TelemetryLock' ($fnText -and $fnText -notmatch 'SetLength' -and $fnText.Contains('"$Path.tmp"') -and $fnText.Contains('Flush($true)') -and $fnText.Contains('[IO.File]::Move($tmp, $Path, $true)') -and $fnText.Contains('MoveFileEx($tmp, $Path, 0x9)') -and $fnText.Contains('Enter-TelemetryLock -WaitMs $WaitMs -IgnoreMarker')) ''
}

# =============================================================== MARKER: the forgetting marker heals itself (D2)
if (Want 'MARKER') {
    $h = New-Home 'marker'
    $env:CODEX_HOME = $h
    $mk = Join-Path $h 'telemetry-forgetting'
    [IO.File]::WriteAllText($mk, '{"pid":999999,"start_time":"2000-01-01T00:00:00.0000000Z","since":"2026-09-30T00:00:00+02:00"}' + "`n", $u8)
    $a = Add-TelemetryEvent -Entry $entry -Switch $sw -WaitMs 1000
    $spoolA = @(Get-ChildItem -LiteralPath (Join-Path $h 'telemetry-spool') -Filter '*.ndjson' -File -ErrorAction SilentlyContinue).Count
    $notesA = LastNotes $h
    Check 'MARKER' 'D2 (F48-2) a marker whose owner is gone (pid 999999): the producer REMOVES it under the telemetry lock and goes on - the event is spooled (Why ''''), the marker is gone, one line in .last notes "removed the forgetting marker of pid 999999 (gone) since <t> - a -Forget -Local that did not finish ..."' (-not $a.Why -and -not $a.Forgetting -and -not (Test-Path -LiteralPath $mk) -and $spoolA -eq 1 -and $notesA.Count -eq 1 -and $notesA[0] -match '^\S+ removed the forgetting marker of pid 999999 \(gone\) since 2026-09-30T00:00:00\+02:00 - a -Forget -Local that did not finish') "why '$($a.Why)' | notes: $($notesA -join ' // ')"
    [IO.File]::WriteAllText($mk, 'garb', $u8)
    $b = Add-TelemetryEvent -Entry $entry -Switch $sw -WaitMs 1000
    $notesB = LastNotes $h
    Check 'MARKER' 'D2 a marker that names no owner (a -Forget that died while writing it - it writes it under the telemetry lock, so none is writing it now): removed too, the event spooled, a second line in .last notes ("of no named owner")' (-not $b.Why -and -not (Test-Path -LiteralPath $mk) -and $notesB.Count -eq 2 -and $notesB[1] -match 'removed the forgetting marker of no named owner') "why '$($b.Why)' | notes: $($notesB -join ' // ')"
    [IO.File]::WriteAllText($mk, (Own-Record -Since '2026-09-30T01:00:00+02:00') + "`n", $u8)
    $c = Add-TelemetryEvent -Entry $entry -Switch $sw -WaitMs 1000
    $spoolLinesC = (Get-TelemetrySpoolCounts).Events
    Check 'MARKER' 'D2 a marker whose owner LIVES (this process stands in for a running -Forget): it blocks as before - the event is dropped (Forgetting, "codex-telemetry.ps1 -Forget -Local is deleting the local telemetry data (pid <n>, since <t>; the marker ...)"), the marker stays, the spool keeps its 2 events' ($c.Forgetting -and $c.Why -match "^codex-telemetry\.ps1 -Forget -Local is deleting the local telemetry data \(pid $PID, since 2026-09-30T01:00:00\+02:00; the marker " -and (Test-Path -LiteralPath $mk) -and $spoolLinesC -eq 2) "why '$($c.Why)' | spool $spoolLinesC"
    # the sender: a marker whose owner lives stops the flush; one whose owner is gone is removed
    $fl = Invoke-TelemetryFlush -FlushMs 20000
    Check 'MARKER' 'D2 the sender meets a marker whose owner lives: the flush stops before sending anything (exit 1, "not delivered: codex-telemetry.ps1 -Forget -Local is deleting ..."), the spool and the marker stay' ($fl.Exit -eq 1 -and $fl.Result -match '^not delivered: codex-telemetry\.ps1 -Forget -Local is deleting' -and $fl.Delivered -eq 0 -and (Test-Path -LiteralPath $mk) -and (Get-TelemetrySpoolCounts).Events -eq 2) "exit $($fl.Exit) | $($fl.Result)"
    $st1 = Run-Child $telemetryPs @('-Status') $h
    [IO.File]::WriteAllText($mk, '{"pid":999999,"start_time":"2000-01-01T00:00:00.0000000Z","since":"2026-09-30T02:00:00+02:00"}' + "`n", $u8)
    $st2 = Run-Child $telemetryPs @('-Status') $h
    $fl2 = Invoke-TelemetryFlush -FlushMs 20000
    $notesF = LastNotes $h
    Check 'MARKER' 'D2 the sender meets a marker whose owner is gone: it removes it (the heal line carried into the new .last notes) and goes on to the intake (here a closed port: not delivered, exit 1, the spool kept)' (-not (Test-Path -LiteralPath $mk) -and $fl2.Exit -eq 1 -and $fl2.Result -notmatch 'Forget -Local is deleting' -and @($notesF | Where-Object { $_ -match 'removed the forgetting marker of pid 999999 \(gone\) since 2026-09-30T02:00:00\+02:00' }).Count -eq 1 -and $notesF.Count -eq 3) "exit $($fl2.Exit) | $($fl2.Result) | notes: $($notesF -join ' // ')"
    Check 'MARKER' 'D2 -Status names the marker''s owner: "forgetting : the marker ... - its owner pid <n> lives (a -Forget -Local runs now ...)" for a living one, "its owner pid 999999 is gone ... the next event or sender removes it" for a dead one; the heal lines as "note       : ..."' ($st1.Code -eq 0 -and $st1.Out -match "(?m)^forgetting : the marker .* - its owner pid $PID lives \(a -Forget -Local runs now" -and $st2.Out -match '(?m)^forgetting : the marker .* - its owner pid 999999 is gone \(a -Forget -Local that did not finish\): the next event or sender removes it' -and $st1.Out -match '(?m)^note       : \S+ removed the forgetting marker of pid 999999') (($st1.Out -split "`n" | Where-Object { $_ -match '^(forgetting|note)' }) -join ' // ')
    $env:CODEX_HOME = $savedCodexHome
    # -Forget removes its marker in `finally`: a local deletion that fails halfway (a spool file held
    # open by another process) says so - and leaves no marker behind
    $hF = New-Home 'forget-finally'
    $env:CODEX_HOME = $hF
    $null = Get-TelemetryInstanceId -Create
    $env:CODEX_HOME = $savedCodexHome
    $sdF = Join-Path $hF 'telemetry-spool'
    [void][IO.Directory]::CreateDirectory($sdF)
    $heldF = Join-Path $sdF '2026-09-29.ndjson'
    [IO.File]::WriteAllText($heldF, (Spool-Line 'held') + "`n", $u8)
    $holdF = New-Object System.IO.FileStream($heldF, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try { $fx = Run-Child $telemetryPs @('-Forget', '-Local', '-Yes') $hF } finally { $holdF.Dispose() }
    $markerLeft = Test-Path -LiteralPath (Join-Path $hF 'telemetry-forgetting')
    $fy = Run-Child $telemetryPs @('-Forget', '-Local', '-Yes') $hF
    Check 'MARKER' 'D2 -Forget -Local whose deletion fails halfway (a spool file held by another process): exit 1 "the local deletion did not finish (...); run codex-telemetry.ps1 -Forget -Local again to finish it" - and NO marker is left (removed in finally); run again it finishes (exit 0, no marker)' ($fx.Code -eq 1 -and $fx.Out -match 'the local deletion did not finish .*run codex-telemetry\.ps1 -Forget -Local again to finish it' -and -not $markerLeft -and $fy.Code -eq 0 -and $fy.Out -match 'removed locally - ' -and -not (Test-Path -LiteralPath (Join-Path $hF 'telemetry-forgetting'))) "first exit $($fx.Code) marker left $markerLeft | again exit $($fy.Code)"
}

# =============================================================== LOCK: the flush lock born with its owner (D3)
if (Want 'LOCK') {
    $h = New-Home 'lock'
    $env:CODEX_HOME = $h
    $sd = Join-Path $h 'telemetry-spool'
    [void][IO.Directory]::CreateDirectory($sd)
    $lk = Join-Path $sd '.flush.lock'
    $a = Enter-TelemetryFlushLock -Path $lk
    $rec = $null; try { $rec = ConvertFrom-Json (Text $lk) } catch { }
    $tmpsA = @(Get-ChildItem -LiteralPath $sd -Force -File | Where-Object { $_.Name -like '*.tmp' }).Count
    Exit-TelemetryFlushLock -Path $lk -Token $a.Token
    Check 'LOCK' 'D3 (F48-3, F49-4) a lock is BORN with its owner: taken, it holds the whole record {pid (this process), start_time, token (the one returned), since}; no temporary file is left; released, it is gone' ($a.Ok -and $rec -and [int]$rec.pid -eq $PID -and [string]$rec.start_time -and [string]$rec.token -ceq $a.Token -and [string]$rec.since -and $tmpsA -eq 0 -and -not (Test-Path -LiteralPath $lk)) "ok $($a.Ok) | $(Text $lk) | tmp $tmpsA"
    $cm = Text $commonPs
    $fnL = $(if ($cm -match '(?s)\nfunction Enter-TelemetryFlushLock \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    Check 'LOCK' 'D3 the code: the record goes to a temporary file first (CreateNew, Flush($true)) which is moved into place WITHOUT overwriting ([IO.File]::Move($tmp, $Path)) - the lock itself is never created empty (no CreateNew on the lock path) and never rewritten in place (no SetLength)' ($fnL -and $fnL.Contains('[IO.File]::Move($tmp, $Path)') -and $fnL -notmatch 'FileStream\(\$Path, \[System\.IO\.FileMode\]::CreateNew' -and $fnL -notmatch 'SetLength') ''
    # four processes race for the lock at the same moment: exactly one takes it
    $raceDir = Join-Path $work 'race'
    [void][IO.Directory]::CreateDirectory($raceDir)
    $raceHome = New-Home 'race'
    [void][IO.Directory]::CreateDirectory((Join-Path $raceHome 'telemetry-spool'))
    $raceLock = Join-Path (Join-Path $raceHome 'telemetry-spool') '.flush.lock'
    $racePs = Join-Path $work 'race-child.ps1'
    [IO.File]::WriteAllText($racePs, "param([string]`$Common, [string]`$Lock, [string]`$Dir, [string]`$Id)`n. `$Common`n[IO.File]::WriteAllText((Join-Path `$Dir ""ready-`$Id""), 'r')`n`$w = [Diagnostics.Stopwatch]::StartNew()`nwhile (-not (Test-Path -LiteralPath (Join-Path `$Dir 'go')) -and `$w.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 5 }`n`$r = Enter-TelemetryFlushLock -Path `$Lock`n[IO.File]::WriteAllText((Join-Path `$Dir ""result-`$Id""), [string]`$r.Ok)`nStart-Sleep -Seconds 3`nif (`$r.Ok) { Exit-TelemetryFlushLock -Path `$Lock -Token `$r.Token }`nexit 0`n", $u8)
    $procs = @(foreach ($i in 1..4) {
            $pr = Start-Process -FilePath $psExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$racePs`"", "`"$commonPs`"", "`"$raceLock`"", "`"$raceDir`"", "$i") -PassThru -WindowStyle Hidden
            if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $pr.Handle } catch { } }
            $pr
        })
    $wr = [Diagnostics.Stopwatch]::StartNew()
    while (@(Get-ChildItem -LiteralPath $raceDir -Filter 'ready-*').Count -lt 4 -and $wr.Elapsed.TotalSeconds -lt 60) { Start-Sleep -Milliseconds 100 }
    [IO.File]::WriteAllText((Join-Path $raceDir 'go'), 'go', $u8)
    foreach ($pr in $procs) { if (-not $pr.WaitForExit(60000)) { try { $pr.Kill() } catch { } } }
    $results = @(foreach ($i in 1..4) { (Text (Join-Path $raceDir "result-$i")).Trim() })
    $leftRace = @(Get-ChildItem -LiteralPath (Join-Path $raceHome 'telemetry-spool') -Force -File | ForEach-Object { $_.Name })
    Check 'LOCK' 'D3 four processes started together (a barrier) race for the lock: EXACTLY ONE takes it (the others are refused), and afterwards neither the lock nor a temporary file is left' (@($results | Where-Object { $_ -eq 'True' }).Count -eq 1 -and @($results | Where-Object { $_ -eq 'False' }).Count -eq 3 -and $leftRace.Count -eq 0) "results [$($results -join ',')] | left [$($leftRace -join ',')]"
    # a lock that names no owner: HELD while younger than 30 s, removed after
    [IO.File]::WriteAllText($lk, 'garbage', $u8)
    $b = Enter-TelemetryFlushLock -Path $lk
    $keptB = (Text $lk) -eq 'garbage'
    [IO.File]::SetLastWriteTimeUtc($lk, [DateTime]::UtcNow.AddSeconds(-31))
    $c = Enter-TelemetryFlushLock -Path $lk
    $recC = $null; try { $recC = ConvertFrom-Json (Text $lk) } catch { }
    Exit-TelemetryFlushLock -Path $lk -Token $c.Token
    Check 'LOCK' 'D3 a lock that names no owner: HELD while younger than 30 s (refused "its lock names no owner yet - held while younger than 30 s", the lock untouched); 31 s old it is REMOVED and the sender starts over - taken (TookOver "it named no owner for 31 s"), the new lock with its owner record' (-not $b.Ok -and $b.Why -match 'its lock names no owner yet - held while younger than 30 s' -and $keptB -and $c.Ok -and $c.TookOver -match '^it named no owner for 3\d s$' -and $recC -and [string]$recC.token -ceq $c.Token) "young: '$($b.Why)' | old: ok $($c.Ok) '$($c.TookOver)'"
    [IO.File]::WriteAllText($lk, '', $u8)
    $e0 = Enter-TelemetryFlushLock -Path $lk
    [IO.File]::SetLastWriteTimeUtc($lk, [DateTime]::UtcNow.AddSeconds(-45))
    $e1 = Enter-TelemetryFlushLock -Path $lk
    Exit-TelemetryFlushLock -Path $lk -Token $e1.Token
    Check 'LOCK' 'D3 an EMPTY lock (unreadable) counts the same: held while young, removed at 45 s' (-not $e0.Ok -and $e0.Why -match 'names no owner yet' -and $e1.Ok -and $e1.TookOver -match '^it named no owner for 4\d s$') "young '$($e0.Why)' | old '$($e1.TookOver)'"
    [IO.File]::WriteAllText($lk, '{"pid":999999,"start_time":"2000-01-01T00:00:00.0000000Z","token":"gone","since":"2026-09-30T00:00:00+02:00"}', $u8)
    $d = Enter-TelemetryFlushLock -Path $lk
    Exit-TelemetryFlushLock -Path $lk -Token $d.Token
    Check 'LOCK' 'D3 a fresh lock whose owner is gone: removed at once and taken (TookOver "its owner pid 999999 is gone")' ($d.Ok -and $d.TookOver -eq 'its owner pid 999999 is gone') "ok $($d.Ok) '$($d.TookOver)'"
    # a living owner: never taken over; 30 minutes old - "sender stuck"
    [IO.File]::WriteAllText($lk, (Own-Record -Token 'other' -Since '2026-09-30T03:00:00+02:00'), $u8)
    $f1 = Enter-TelemetryFlushLock -Path $lk
    [IO.File]::SetLastWriteTimeUtc($lk, [DateTime]::UtcNow.AddMinutes(-31))
    $f2 = Enter-TelemetryFlushLock -Path $lk
    $keptF = (Text $lk) -match '"token":"other"'
    Check 'LOCK' 'D3 a lock whose owner LIVES: refused and never taken over - young "sender busy since <t> (pid <n> holds its lock, ...)" (Stuck empty); 31 minutes old "sender stuck since <t> (pid <n>) - its lock is 31 min old and its owner lives: it is never taken over; stop pid <n> if it hangs, or delete <lock> when no such process runs" (Stuck set); the lock untouched' (-not $f1.Ok -and $f1.Why -match "sender busy since 2026-09-30T03:00:00\+02:00 \(pid $PID holds its lock" -and -not $f1.Stuck -and -not $f2.Ok -and $f2.Stuck -eq "sender stuck since 2026-09-30T03:00:00+02:00 (pid $PID)" -and $f2.Why -match 'its lock is 31 min old and its owner lives: it is never taken over; stop pid \d+ if it hangs, or delete .*\.flush\.lock when no such process runs' -and $keptF) "young '$($f1.Why)' | old '$($f2.Why)'"
    [IO.File]::WriteAllText((Join-Path $sd '2026-09-30.ndjson'), (Spool-Line 'stuck') + "`n", $u8)
    [IO.File]::SetLastWriteTimeUtc($lk, [DateTime]::UtcNow.AddMinutes(-31))
    $g1 = Invoke-TelemetryFlush -FlushMs 20000
    $g2 = Invoke-TelemetryFlush -FlushMs 20000
    $notesG = LastNotes $h
    $stG = Run-Child $telemetryPs @('-Status') $h
    Check 'LOCK' 'D3 the refused sender (exit 2) writes "sender stuck since <t> (pid <n>)" into .last notes - ONCE however often it is refused - and -Status says it: "sender     : sender stuck since <t> (pid <n>) ..." and the note' ($g1.Exit -eq 2 -and $g2.Exit -eq 2 -and $notesG.Count -eq 1 -and $notesG[0] -match "^\S+ sender stuck since 2026-09-30T03:00:00\+02:00 \(pid $PID\)$" -and $stG.Out -match "(?m)^sender     : sender stuck since 2026-09-30T03:00:00\+02:00 \(pid $PID\) - its lock .* is 31 min old" -and $stG.Out -match '(?m)^note       : \S+ sender stuck since ') "exits $($g1.Exit),$($g2.Exit) | notes: $($notesG -join ' // ') | $((($stG.Out -split "`n") | Where-Object { $_ -match '^(sender|note)' }) -join ' // ')"
    Remove-Item -LiteralPath $lk -Force
    $g3 = Invoke-TelemetryFlush -FlushMs 20000
    $notesG3 = LastNotes $h
    Check 'LOCK' 'D3 once the stuck sender''s lock is gone, the next flush takes the lock and its .last drops the stale "sender stuck" line' ($g3.Exit -eq 1 -and $notesG3.Count -eq 0) "exit $($g3.Exit) | $($g3.Result) | notes: $($notesG3 -join ' // ')"
    $holdL = New-Object System.IO.FileStream((Join-Path $sd '.flush.lock'), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try { $hl = Enter-TelemetryFlushLock -Path $lk } finally { $holdL.Dispose() }
    Remove-Item -LiteralPath $lk -Force -ErrorAction SilentlyContinue
    Check 'LOCK' 'D3 a lock another process holds open: refused ("its lock is held"), nothing removed' (-not $hl.Ok -and $hl.Why -match 'its lock is held') "'$($hl.Why)'"
    $env:CODEX_HOME = $savedCodexHome
}

# =============================================================== NOTSPOOLED: the count cannot be lost (D4)
if (Want 'NOTSPOOLED') {
    $h = New-Home 'ns'
    $env:CODEX_HOME = $h
    # (wave 28e, E2) the count is this producer's own file telemetry-not-spooled-<pid>-<start ticks>.ndjson
    $nsF = (Get-TelemetryPaths).NotSpooledOwn
    $holdT = New-Object System.IO.FileStream((Join-Path $h 'telemetry.lock'), [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $wn = [Diagnostics.Stopwatch]::StartNew()
    try { $null = Add-TelemetryNotSpooled -Why 'w1 (the telemetry lock held)' } finally { $holdT.Dispose() }
    $wn.Stop()
    $n1 = Get-TelemetryNotSpooled
    Check 'NOTSPOOLED' 'D4 (F49-2) the count is written WITHOUT the telemetry lock: with the lock held by another handle (a -Forget in flight, a slow append) the line is appended at once - nothing is lost; -Status''s count 1' ((Lines $nsF).Count -eq 1 -and (Text $nsF) -match 'w1 \(the telemetry lock held\)' -and $wn.Elapsed.TotalSeconds -lt 1 -and $n1.Count -eq 1 -and $n1.Total -eq 1) "$((Lines $nsF).Count) line(s) in $([Math]::Round($wn.Elapsed.TotalSeconds, 2)) s | count $($n1.Count)"
    $null = Add-TelemetryNotSpooled -Why 'w2'
    [void][IO.Directory]::CreateDirectory((Join-Path $h 'telemetry-spool'))
    [IO.File]::WriteAllText((Join-Path (Join-Path $h 'telemetry-spool') '2026-09-30.ndjson'), (Spool-Line 'ns') + "`n", $u8)
    $fl = Invoke-TelemetryFlush -FlushMs 20000
    $last = ConvertFrom-Json (Text (Join-Path (Join-Path $h 'telemetry-spool') '.last'))
    $n2 = Get-TelemetryNotSpooled
    $null = Add-TelemetryNotSpooled -Why 'w3 after the flush'
    $n3 = Get-TelemetryNotSpooled
    $st = Run-Child $telemetryPs @('-Status') $h
    Check 'NOTSPOOLED' 'D4 the file is APPEND-ONLY: a flush deletes nothing of a LIVE producer (this process; wave 28e, E2: the files of gone producers are folded - harness-fixes28e) - both lines stay - and records how many lines it saw (.last not_spooled_seen 2); the count since the last flush is 0 ("none since the last flush"), a line added after it counts 1 (-Status "not spooled: 1 event(s) since the last flush - the latest <t>: w3 after the flush"), the file holds 3' ($fl.Exit -eq 1 -and [int]$last.not_spooled_seen -eq 2 -and $n2.Count -eq 0 -and $n2.Total -eq 2 -and $n3.Count -eq 1 -and $n3.Last -eq 'w3 after the flush' -and $n3.Total -eq 3 -and (Lines $nsF).Count -eq 3 -and $st.Out -match '(?m)^not spooled: 1 event\(s\) since the last flush - the latest \S+: w3 after the flush') "seen $($last.not_spooled_seen) | after flush $($n2.Count)/$($n2.Total) | then $($n3.Count)/$($n3.Total) | $((($st.Out -split "`n") | Where-Object { $_ -like 'not spooled*' }) -join '')"
    [IO.File]::AppendAllText($nsF, '{"time":"2026-09-30T10:00:00+02:00","why":"half', $u8)
    $n4 = Get-TelemetryNotSpooled
    Check 'NOTSPOOLED' 'D4 only complete lines count: an append in progress (no line end yet) is not counted' ($n4.Count -eq 1 -and $n4.Total -eq 3) "count $($n4.Count) total $($n4.Total)"
    $env:CODEX_HOME = $savedCodexHome
    $cm = Text $commonPs
    $fnN = $(if ($cm -match '(?s)\nfunction Add-TelemetryNotSpooled \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    $fnF = $(if ($cm -match '(?s)\nfunction Invoke-TelemetryFlush \{(.*?)\n\}\r?\n') { $Matches[1] } else { '' })
    Check 'NOTSPOOLED' 'D4 the code: Add-TelemetryNotSpooled takes no lock (no Enter-TelemetryLock) and appends; the flush never deletes by the legacy path (wave 28e: it folds only the files of gone producers, Merge-TelemetryNotSpooled)' ($fnN -and $fnN -notmatch 'Enter-TelemetryLock' -and $fnN.Contains('AppendAllText') -and $fnF -and $fnF -notmatch 'Delete\(\$p\.NotSpooled\)') ''
}

# =============================================================== KILL: both groups named (D5)
if (Want 'KILL') {
    $astConsult = [System.Management.Automation.Language.Parser]::ParseFile($consultPs, [ref]$null, [ref]$null)
    foreach ($fd in @($astConsult.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and @('Add-KillCheck', 'Get-KillMayRunPids', 'Get-KillUnverifiedText', 'Format-KillText') -contains $n.Name }, $true))) { . ([scriptblock]::Create($fd.Extent.Text)) }
    $script:KillChecks = New-Object System.Collections.Generic.List[object]
    $script:KillWarnings = New-Object System.Collections.Generic.List[string]
    $both = [pscustomobject]@{ Survivors = [int[]]@(111, 222); Confirmed = $false; Why = 'start time of pid 333 unreadable'; RootPid = 100; Unverified = [int[]]@(333) }
    Add-KillCheck -Check $both -Turn 'main turn'
    $wBoth = @($script:KillWarnings)
    $tBoth = Format-KillText $both
    Check 'KILL' 'D5 (F49-1) a kill with survivors AND a descendant whose identity could not be read: the warning names both groups ("kill not confirmed (main turn): 2 processes survived: pid 111, 222; start time of pid 333 unreadable; pid 333 may still run - check them, ...") and so does the outcome text ("(process tree killed; 2 processes survived: pid 111, 222; start time of pid 333 unreadable; pid 333 may still run)")' ($wBoth.Count -eq 1 -and $wBoth[0] -eq 'kill not confirmed (main turn): 2 processes survived: pid 111, 222; start time of pid 333 unreadable; pid 333 may still run - check them, and stop them by hand if they do' -and $tBoth -eq '(process tree killed; 2 processes survived: pid 111, 222; start time of pid 333 unreadable; pid 333 may still run)') "warning: $($wBoth -join ' // ') | text: $tBoth"
    $script:KillWarnings.Clear()
    $survOnly = [pscustomobject]@{ Survivors = [int[]]@(111); Confirmed = $false; Why = ''; RootPid = 100; Unverified = [int[]]@() }
    $unvOnly = [pscustomobject]@{ Survivors = [int[]]@(); Confirmed = $false; Why = 'start time of pid 333 unreadable'; RootPid = 100; Unverified = [int[]]@(333) }
    $okK = [pscustomobject]@{ Survivors = [int[]]@(); Confirmed = $true; Why = ''; RootPid = 100; Unverified = [int[]]@() }
    Add-KillCheck -Check $survOnly -Turn 'format repair'
    $wS = $script:KillWarnings.Count
    Add-KillCheck -Check $unvOnly -Turn 'format repair'
    Add-KillCheck -Check $okK -Turn 'main turn'
    $wAll = @($script:KillWarnings)
    Check 'KILL' 'D5 the other shapes are unchanged: survivors only - no warning, "(process tree killed; 1 processes survived: pid 111)"; unverified only - the wave 28c warning and "(kill not confirmed: start time of pid 333 unreadable; pid 333 may still run)"; a confirmed kill - "(process tree killed)", no warning' ($wS -eq 0 -and (Format-KillText $survOnly) -eq '(process tree killed; 1 processes survived: pid 111)' -and $wAll.Count -eq 1 -and $wAll[0] -eq 'kill not confirmed (format repair): start time of pid 333 unreadable; pid 333 may still run - check it, and stop it by hand if it does' -and (Format-KillText $unvOnly) -eq '(kill not confirmed: start time of pid 333 unreadable; pid 333 may still run)' -and (Format-KillText $okK) -eq '(process tree killed)') "$($wAll -join ' // ')"
    $cs = Text $consultPs
    Check 'KILL' 'D5 the three places that tell survivors (a turn, the main turn, the format repair) append the unverified group (Get-KillUnverifiedText) to their text' ($cs.Contains('processes survived: pid $($surv -join '', '')$(Get-KillUnverifiedText $turnKill))') -and $cs.Contains('processes survived: pid $($survivors -join '', '')$(Get-KillUnverifiedText $mainKill); the next run for this task is refused until they exit)') -and $cs.Contains('processes survived: pid $($repairSurvivors -join '', '')$(Get-KillUnverifiedText $repairKill))')) ''
}

# =============================================================== MODEL: both sides lower-cased (D6)
if (Want 'MODEL') {
    $vt = [pscustomobject]@{ Class = 'test'; Models = @('K3-Ultra', 'glm-5.3') }
    $got = @(foreach ($m in @('k3-ultra', 'K3-ULTRA', ' K3-Ultra ', 'k3-ultra-2', 'GLM-5.3', '')) { Get-TelemetryModelToken -Vendor $vt -Model $m })
    Check 'MODEL' 'D6 (F50-1) Get-TelemetryModelToken lower-cases BOTH sides: a table entry with upper-case letters (K3-Ultra) matches k3-ultra, K3-ULTRA and " K3-Ultra " and returns the table''s own text; k3-ultra-2 stays other; GLM-5.3 reads glm-5.3; '''' unknown' (($got -join ',') -ceq 'K3-Ultra,K3-Ultra,K3-Ultra,other,glm-5.3,unknown') ($got -join ',')
}

# =============================================================== REREAD: the ask repeated (D7), not in the estimate (D8)
if (Want 'REREAD') {
    $rosterCt = Write-Roster 'ctx' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","context_tokens":256000}]}'
    $r = New-Repo 'reread'
    $log = Join-Path $work 'reread-args.txt'
    $x = Consult $r $rosterCt @('-Provider', 'openai', '-Prompt', "Check app.txt `t for   typos.", '-ReplyName', 'ra') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log }
    $e = @(Ledger $r)[-1]
    $pl = @(((Text $log) -split "PROMPT:`n", 2)[-1] -split "`r?`n" | Where-Object { $_.Trim() })
    $last2 = @($pl | Select-Object -Last 2)
    Check 'REREAD' 'D7 (F50-2) a member with context_tokens and an inline -Prompt (no brief file): the prompt ends with the one-line ask repeated - "Before you answer, re-read the ask: Check app.txt for typos." (whitespace folded) - right before the consultation id (still last); compactions "unknown"' ($x.Code -eq 0 -and $last2.Count -eq 2 -and $last2[0] -ceq 'Before you answer, re-read the ask: Check app.txt for typos.' -and $last2[1] -match '^Consultation id: [0-9a-f-]{36}$' -and $e.compactions -ceq 'unknown') "exit $($x.Code) | last lines [$($last2 -join ' // ')]"
    $log2 = Join-Path $work 'reread-args2.txt'
    $longAsk = 'a' * 400 + ' ' + 'b' * 300
    $x2 = Consult $r $rosterCt @('-Provider', 'openai', '-Prompt', $longAsk, '-ReplyName', 'rb') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log2 }
    $pl2 = @(((Text $log2) -split "PROMPT:`n", 2)[-1] -split "`r?`n" | Where-Object { $_.Trim() })
    $re2 = @($pl2 | Select-Object -Last 2)[0]
    Check 'REREAD' 'D7 an ask longer than 300 characters (500 before wave 28e, E4) is repeated cut at 300 and points to the top of the prompt ("... (cut here: the whole ask is at the top of this prompt)")' ($x2.Code -eq 0 -and $re2 -ceq ('Before you answer, re-read the ask: ' + $longAsk.Substring(0, 300) + '... (cut here: the whole ask is at the top of this prompt)')) "exit $($x2.Code) | $($re2.Length) chars"
    $log3 = Join-Path $work 'reread-args3.txt'
    $x3 = Consult $r '' @('-Prompt', 'Check app.txt', '-ReplyName', 'rc') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log3 }
    Check 'REREAD' 'D7 a member WITHOUT context_tokens gets no re-read line' ($x3.Code -eq 0 -and (Text $log3) -notmatch 'Before you answer, re-read') "exit $($x3.Code)"
    # D8: the re-read line takes no part in the context estimate that decides whether the thread is
    # continued (fork) or a new one starts - the threshold sits exactly where the prompt WITHOUT it puts it
    $r8 = New-Repo 'estimate'
    [IO.File]::WriteAllText((Join-Path $r8 'b.md'), "# brief`nlook at app.txt`n", $u8)
    # the prior thread's recorded tokens (the fake reports 1000) set to 30000 in the ledger, so that a
    # window of the allowed size (>= 32000) puts the threshold within reach
    $sess8 = Join-Path $r8 '.collab\t\sessions.json'
    $setPrior = { param([int]$Tokens) $j = ConvertFrom-JsonKeepOffset -Text (Text $sess8); $le = @($j.codex.consults)[-1]; if ($le.usage) { $le.usage.input_tokens = $Tokens } else { $le | Add-Member -NotePropertyName usage -NotePropertyValue ([pscustomobject]@{ input_tokens = $Tokens }) -Force }; Write-JsonFile -Path $sess8 -Object $j }
    $ro1 = Write-Roster 'est1' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","context_tokens":99999}]}'
    $y1 = Consult $r8 $ro1 @('-Provider', 'openai', '-Brief', 'b.md', '-Prompt', 'x', '-ReplyName', 'e1') @{ FAKE_CODEX_REPLY = $advise }
    $l1 = @(Ledger $r8)[-1]
    $L = [int]$l1.prompt_chars
    $B = [int](Get-Item -LiteralPath (Join-Path $r8 'b.md')).Length
    $rr = ('Before you answer, re-read the brief: `b.md`.').Length + 4
    $prior = 30000
    & $setPrior $prior
    $eWithout = [int][Math]::Ceiling(($L - $rr + $B) / 4.0)
    $eWith = [int][Math]::Ceiling(($L + $B) / 4.0)
    # the smallest window (plus one token of margin) where the estimate WITHOUT the line still fits 80%
    $cStar = [int][Math]::Ceiling(($prior + $eWithout) / 0.8) + 1
    $ro2 = Write-Roster 'est2' ('{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","context_tokens":' + $cStar + '}]}')
    $y2 = Consult $r8 $ro2 @('-Provider', 'openai', '-Brief', 'b.md', '-Prompt', 'x', '-ReplyName', 'e2') @{ FAKE_CODEX_REPLY = $advise }
    $l2 = @(Ledger $r8)[-1]
    & $setPrior $prior
    $ro3 = Write-Roster 'est3' ('{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","context_tokens":' + ($cStar - 3) + '}]}')
    $y3 = Consult $r8 $ro3 @('-Provider', 'openai', '-Brief', 'b.md', '-Prompt', 'x', '-ReplyName', 'e3') @{ FAKE_CODEX_REPLY = $advise }
    $l3 = @(Ledger $r8)[-1]
    Check 'REREAD' 'D8 (F48-4) the re-read line is outside the estimate that decides thread reuse: with context_tokens chosen so that (prior tokens + the prompt estimate WITHOUT the line) just fits 80% while WITH the line it would not, the automatic fork is kept (mode fork, no mode_fallback - the prompt, the line included, the same length as before); 3 tokens smaller the fallback to a new thread happens (the threshold is live)' ($y1.Code -eq 0 -and [int]$l1.prompt_chars -gt 0 -and ($prior + $eWith) -gt (0.8 * $cStar) -and ($cStar).ToString().Length -eq 5 -and $y2.Code -eq 0 -and $l2.mode -eq 'fork' -and $null -eq $l2.mode_fallback -and [int]$l2.prompt_chars -eq $L -and $y3.Code -eq 0 -and $l3.mode -eq 'new' -and $l3.mode_fallback.from -eq 'fork') "L $L B $B line $rr prior $prior est $eWithout/$eWith window $cStar | 2: $($l2.mode) fb $($l2.mode_fallback.from) chars $($l2.prompt_chars) | 3: $($l3.mode) fb $($l3.mode_fallback.from)"
    $cs = Text $consultPs
    Check 'REREAD' 'D8 the code: no hash of the prompt text exists (thread reuse, lineage and finding ids never read it); the estimate subtracts the re-read line' ($cs -notmatch 'Get-Sha256Hex[^\r\n]*promptText' -and $cs -notmatch 'SHA256[^\r\n]*promptText' -and $cs.Contains('$newEstimate = [int][Math]::Ceiling(($promptText.Length - $rereadChars + $briefChars) / 4.0)')) ''
}

# =============================================================== DOCS: the README, CHANGELOG, tests/README.md, run-all
if (Want 'DOCS') {
    $readme = (Text (Join-Path $repoRoot 'README.md')) -replace '\s+', ' '
    $miss = @(foreach ($k in @('<spool file>.tmp', 'replaces the spool file in one step', 'CODEX_CONSULT_TEST_TELEMETRY_REWRITE_CRASH', 'removes it in `finally`', 'whose owner is gone', 'one line in `.last` `notes`', 'born with its owner', 'HELD while it is younger than 30 s', 'sender stuck since <t> (pid <n>)', 'append-only', 'without the telemetry lock', '`not_spooled_seen`', 'Before you answer, re-read the ask', 'both groups')) { if ($readme.IndexOf($k, [StringComparison]::Ordinal) -lt 0) { $k } })
    Check 'DOCS' 'README: the atomic rewrite and its hook (D1), the marker removed in finally and healed (D2), the lock born with its owner, the 30 s and the stuck sender (D3), the append-only count (D4), both groups of a kill (D5), the re-read ask (D7)' ($miss.Count -eq 0) "missing: $($miss -join ', ')"
    $cl = Text (Join-Path $repoRoot 'CHANGELOG.md')
    $clSec = $(if ($cl -match '(?s)\n- \*\*Wave 28d - the third fix round\*\*(.*?)\n### ') { $Matches[1] } else { '' })
    Check 'DOCS' 'CHANGELOG [0.5.0] "Wave 28d - the third fix round" (under Fixed): an entry per D item and what D8 found' ($clSec -and @(1..8 | Where-Object { $clSec -notmatch "\bD$_\b" }).Count -eq 0 -and $clSec -match 'prompt') ''
    $tr = Text (Join-Path $sp 'README.md')
    $runAll = Text (Join-Path $sp 'run-all.ps1')
    Check 'DOCS' 'tests/README.md describes harness-fixes28d and run-all.ps1 registers it' ($tr.Contains('harness-fixes28d') -and $runAll -match "'harness-fixes28d'") ''
}

# =============================================================== GUARD: the operator's codex home untouched
if (-not $Only) {
    Check 'GUARD' 'the operator''s real codex home got no telemetry file from this harness (its telemetry* names compared before and after, read only; every case runs in a scratch CODEX_HOME)' ((& $realTelemetry) -eq $realBefore) "before [$realBefore] after [$(& $realTelemetry)]"
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
Write-Host ''
Write-Host ("harness-fixes28d ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
