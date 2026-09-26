# codex-consult parallel panel (0.4.x wave 21, ROADMAP R11, decisions D1-D13 of the parallel
# panel design round): the plan (endpoint groups, the roster's "parallel", -PanelConcurrency),
# members running at the same time (overlap, the wall clock), the ledger sorted by n and the
# findings in id order whatever finishes first, no lost update under the commit write lock
# (reviewer checks of three members on one prior finding), per-member recovery records (the
# writer's liveness, no name rule for member records, several leftovers), the task lock held for
# the whole panel, the member's proof of its parent (D6) and its re-check before launching (D1),
# an agy member beside committing siblings (D7), the parent killed mid-panel, a member's timeout
# kill without survivors (no orphan process, no kept record - wave 23b) and with survivors, the
# kill guard (D11), a commit blocked by a held write lock (D3), a kill inside the
# commit (ORPHAN, D4/F03-11), Get-EndpointHealth by completion (D9). FAKES ONLY: fake-codex3.cmd
# (CODEX_CONSULT_EXE and -CodexExe) and fake-agy.cmd (CODEX_CONSULT_AGY_EXE); CODEX_HOME and
# CODEX_CONSULT_ROSTER point at scratch files; the API key variables hold dummy test values.
# Runs under the host it is started with (powershell 5.1 or pwsh 7, Windows) and launches the
# scripts with the same host. Work files: $env:TEMP\codex-consult-tests\harness-panel\<guid>,
# removed at the end.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$findingsPs = Join-Path $scripts 'codex-findings.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$fakeAgy = Join-Path $sp 'fake-agy.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-panel') ([guid]::NewGuid().ToString('N'))
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
$savedCodexHome = $env:CODEX_HOME
$script:fails = 0
$script:passes = 0
$cleanup = New-Object System.Collections.Generic.List[int]

function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 300) { $ev = $ev.Substring(0, 300) + '...' }
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
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
# The scratch Codex config: the built-in openai (top-level model gpt-5.1) plus ZAI and mimo
# (env keys RT_ZAI_KEY / RT_MIMO_KEY, dummy values set per case).
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
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_PIDDIR', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_LOGIN_DELAY_MS', 'FAKE_CODEX_FAIL_ON', 'FAKE_CODEX_HANG_ON', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_REPLY_MAP', 'FAKE_CODEX_SLEEP', 'FAKE_AGY_REPLY', 'FAKE_AGY_WRITE', 'FAKE_AGY_DELAY_MS', 'FAKE_AGY_STATUS', 'FAKE_AGY_ERROR', 'FAKE_AGY_PIDFILE')
$testVars = @('RT_ZAI_KEY', 'RT_MIMO_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_AGY_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_SURVIVORS', 'CODEX_CONSULT_TEST_WRITE_LOCK_SEC', 'CODEX_CONSULT_TEST_COMMIT_PAUSE_MS', 'CODEX_CONSULT_TEST_PANEL_GUARD_SEC', 'CODEX_CONSULT_TEST_MEMBER_PAUSE_MS')
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
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env { Clear-TestEnv; $env:CODEX_HOME = $savedCodexHome }
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task t -CodexExe $fake @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1); Refusal = [string](@(($text -split "`n") | Where-Object { $_ -match '^codex-consult: ' }) | Select-Object -First 1) }
}
# A member run by hand: only -Task and -PanelSpec (what a panel run passes).
function Consult-Member {
    param([string]$Repo, [string]$Roster, [string]$Spec, [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task t -PanelSpec $Spec 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1); Refusal = [string](@(($text -split "`n") | Where-Object { $_ -match '^codex-consult: ' }) | Select-Object -First 1) }
}
# The MS C runtime rules (\" for a quote) for a hand-built command line.
function Quote-CArg {
    param([string]$S)
    if ($S -and $S -notmatch '[\s"]') { return $S }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    $bs = 0
    foreach ($ch in $S.ToCharArray()) {
        if ($ch -eq '\') { $bs++; continue }
        if ($ch -eq '"') { [void]$sb.Append(('\' * ($bs * 2 + 1)) + '"'); $bs = 0; continue }
        [void]$sb.Append(('\' * $bs) + $ch); $bs = 0
    }
    [void]$sb.Append(('\' * ($bs * 2)) + '"')
    return $sb.ToString()
}
# A consultation in the background: { Proc; Out (stdout file) }. The environment is the case's.
function Start-Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{}, [switch]$Member)
    Set-CaseEnv $Roster $Env
    $outFile = Join-Path $work ('bg-' + [guid]::NewGuid().ToString('N') + '.txt')
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't')
    if (-not $Member) { $all += @('-CodexExe', $fake) }
    $line = (($all + $ArgList) | ForEach-Object { Quote-CArg $_ }) -join ' '
    $proc = Start-Process -FilePath $psExe -ArgumentList $line -WorkingDirectory $Repo -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError "$outFile.err"
    if ($script:LegacyPS) { try { $null = $proc.Handle } catch { } }
    Restore-Env
    return [pscustomobject]@{ Proc = $proc; Out = $outFile }
}
function Bg-Output { param($Bg) return (((Read-SharedText -Path $Bg.Out) + "`n" + (Read-SharedText -Path "$($Bg.Out).err")) -replace "`r`n", "`n") }
function Run-Tool {
    param([string]$Script, [string]$Repo, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv '' $Env
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
function Findings { param([string]$Repo) $f = Join-Path $Repo '.collab\t\findings.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).findings) }
function Td { param([string]$Repo) return (Join-Path $Repo '.collab\t') }
# The recovery records of the task: { Name; Path; Record }
function Records {
    param([string]$Repo)
    $paths = Get-PendingPaths -TaskDir (Td $Repo)
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($p in $paths) { $rd = Read-PendingFile -Path $p; $out.Add([pscustomobject]@{ Name = [IO.Path]::GetFileName($p); Path = $p; Record = $rd.Record }) }
    return , ($out.ToArray())
}
function Test-LockHeld { param([string]$Path) if (-not (Test-Path $Path)) { return $false }; try { $f = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None); $f.Dispose(); return $false } catch { return $true } }
function Wait-For { param([scriptblock]$Cond, [int]$TimeoutSec = 60) $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) { if (& $Cond) { return $true }; Start-Sleep -Milliseconds 200 }; return [bool](& $Cond) }
function Iso { param($Dto) return ([DateTimeOffset]$Dto).ToString('yyyy-MM-ddTHH:mm:sszzz', $inv) }
function To-Dto { param($V) if ($V -is [DateTimeOffset]) { return $V }; if ($V -is [datetime]) { return [DateTimeOffset]$V }; return [DateTimeOffset]::Parse([string]$V, $inv) }
# The summary block of a panel run's output (the last "Panel xxxxxxxx: " line and after).
function Summary {
    param([string]$Out)
    $m = [regex]::Matches($Out, '(?m)^Panel [0-9a-f]{8}: .*$')
    if ($m.Count -eq 0) { return @('') }
    return @($Out.Substring($m[$m.Count - 1].Index) -split "`n")
}
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
function Dead-Pid { $d = Start-Process cmd.exe -ArgumentList '/c', 'exit' -PassThru -WindowStyle Hidden; $d.WaitForExit(); return $d.Id }
function Start-Sleeper { param([int]$Sec = 180, [string]$Tag = '') $s = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-Command', "Start-Sleep -Seconds $Sec $Tag") -PassThru -WindowStyle Hidden; $cleanup.Add($s.Id); return $s }

$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
$finding = '{"severity":"minor","locations":[{"path":"app.txt","line":1}],"claim":"c","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}'
$adviseF = Reply 'advise-finding.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$roster3 = Write-Roster 'three' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
$roster2 = Write-Roster 'two' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
$rosterZai2 = Write-Roster 'zai2' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"ZAI","model":"glm-5.3-flash"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
$rosterZaiPar = Write-Roster 'zai2par' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"ZAI","model":"glm-5.3-flash"},{"provider":"mimo","model":"mimo-v2.6-pro"}],"parallel":{"ZAI":2}}'
$rosterMixed = Write-Roster 'mixed' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"gemini","engine":"agy","model":"gemini-3.8-flash-high"}]}'

try {
# =============================================================== UNIT: plan, prefixes, numbering, ledger order, health, records, write lock, roster
if (Want 'UNIT') {
    function Rn { param([string]$Label, [int]$Pos, [string]$Fp) [pscustomobject]@{ Entry = [pscustomobject]@{ Provider = $Label; Position = $Pos; Engine = 'codex' }; Identity = [pscustomobject]@{ Resolved = [bool]$Fp; Fingerprint = $Fp } } }
    $p1 = Get-PanelPlan -Runners @((Rn 'openai' 1 'fa'), (Rn 'ZAI' 2 'fb'), (Rn 'mimo' 3 'fc'))
    $p2 = Get-PanelPlan -Runners @((Rn 'ZAI' 1 'fb'), (Rn 'ZAI' 2 'fb'), (Rn 'mimo' 3 'fc'))
    $par = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    $par['ZAI'] = 2
    $p3 = Get-PanelPlan -Runners @((Rn 'ZAI' 1 'fb'), (Rn 'ZAI' 2 'fb'), (Rn 'mimo' 3 'fc')) -Parallel $par
    $p4 = Get-PanelPlan -Runners @((Rn 'openai' 1 'fa'), (Rn 'ZAI' 2 'fb'), (Rn 'mimo' 3 'fc')) -Cap 1
    $p5 = Get-PanelPlan -Runners @((Rn 'gemini' 1 'fg'), (Rn 'gemini-pro' 2 'fg'), (Rn 'openai' 3 'fa'))
    $p6 = Get-PanelPlan -Runners @((Rn 'openai' 1 'fa'), (Rn 'ZAI' 2 'fb'), (Rn 'mimo' 3 'fc')) -Cap 2
    Check 'UNIT' 'Get-PanelPlan (D8): three endpoints -> "at once" (effective 3, limit 1 each); two entries of one label -> one group, one after another ("at most 2 at a time"); roster parallel ZAI 2 -> "at once"; -Cap 1 -> "one after another"; two labels on one fingerprint (agy labels share a sign-in) -> one group; -Cap 2 of 3 -> "at most 2 at a time"' ($p1.Text -eq 'at once' -and $p1.Effective -eq 3 -and @($p1.Groups).Count -eq 3 -and $p2.Text -eq 'at most 2 at a time' -and @($p2.Groups).Count -eq 2 -and $p2.Groups[0].Limit -eq 1 -and (@($p2.Groups[0].Positions) -join ',') -eq '1,2' -and $p2.GroupOf[1] -eq $p2.GroupOf[2] -and $p3.Text -eq 'at once' -and $p3.Limits['ZAI'] -eq 2 -and $p4.Text -eq 'one after another' -and $p4.Effective -eq 1 -and @($p5.Groups).Count -eq 2 -and (@($p5.Groups[0].Labels) -join '+') -eq 'gemini+gemini-pro' -and $p5.Text -eq 'at most 2 at a time' -and $p6.Text -eq 'at most 2 at a time') "p2=$($p2.Text); p5 groups: $(@($p5.Groups | ForEach-Object { @($_.Labels) -join '+' }) -join ' | ')"

    $none = Get-PanelIgnorePrefixes -Task 't' -SiblingNns @()
    $pfx = Get-PanelIgnorePrefixes -Task 't' -SiblingNns @('02', '03')
    $cs = Join-Path $work 'snap'
    [void][IO.Directory]::CreateDirectory((Join-Path $cs 't\handoffs'))
    foreach ($f in @('t\sessions.json', 't\findings.json', 't\state.md', 't\handoffs\01-agy-own.md')) { [IO.File]::WriteAllText((Join-Path $cs $f), "x`n", $u8) }
    $before = Get-CollabSnapshot -Dir $cs
    foreach ($f in @('t\sessions.json', 't\findings.json', 't\.sessions.json.0123abcd.tmp', 't\.findings.json.4567cdef.tmp', 't\handoffs\02-codex-x-openai.md', 't\handoffs\.02-agy-x-gemini.reply.json.89abcdef.tmp', 't\handoffs\03-codex-x-mimo.events.jsonl', 't\state.md', 't\handoffs\04-codex-other.md', 'other\x.md')) {
        $p = Join-Path $cs $f
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($p))
        [IO.File]::WriteAllText($p, "changed`n", $u8)
    }
    $diff = Compare-DirectorySnapshot -Before $before -After (Get-CollabSnapshot -Dir $cs) -IgnorePrefixes ([string[]](@('t/handoffs/01-agy-own.') + $pfx))
    Check 'UNIT' 'Get-PanelIgnorePrefixes (D7, F04-1): nothing without siblings; with siblings 02, 03 the task''s two stores, the siblings'' handoffs and each one''s Write-TextAtomic temp (.sessions.json.<guid>.tmp, handoffs/.02-....tmp) are left out, while state.md, a non-sibling handoff (04) and another task still count' ($none.Count -eq 0 -and $pfx.Count -eq 8 -and (@($diff) -join ',') -eq 'other/x.md,t/handoffs/04-codex-other.md,t/state.md') (@($diff) -join ',')

    $nx = Get-NextNumbers -Consults @([pscustomobject]@{ n = 1 }) -Store (New-FindingsStore -Task 't') -HandoffsDir '' -Leftovers @([pscustomobject]@{ n = 3; nn = '04' }, [pscustomobject]@{ n = 1; nn = '02' }, [pscustomobject]@{ n = 2; nn = '07' })
    Check 'UNIT' 'Get-NextNumbers (D5, F02-3): several leftover records -> n and NN past all of them; per record Recovered (its n has no ledger entry), in the order given' ($nx.N -eq 4 -and $nx.Nn -eq '08' -and @($nx.Items).Count -eq 3 -and $nx.Items[0].Recovered -and -not $nx.Items[1].Recovered -and $nx.Items[2].Recovered -and $nx.Recovered -and $nx.RecoveredN -eq 3) "N=$($nx.N) NN=$($nx.Nn)"

    $led = [pscustomobject]@{ codex = [pscustomobject]@{ consults = [object[]]@([pscustomobject]@{ n = 1 }, [pscustomobject]@{ n = 3 }) } }
    Add-LedgerEntry -Sessions $led -Entry ([pscustomobject]@{ n = 2 })
    Add-LedgerEntry -Sessions $led -Entry ([pscustomobject]@{ n = 4 })
    $st = [pscustomobject]@{ task_id = 't'; findings = [object[]]@([pscustomobject]@{ id = 'F02-1'; status = 'proposed' }, [pscustomobject]@{ id = 'F04-1'; status = 'proposed' }) }
    $rep = ConvertFrom-Json -InputObject ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
    $null = Add-ReplyFindings -Store $st -Reply $rep -Nn '03' -ConsultN 3 -ReplyRel 'handoffs/03-codex-x.md' -ThreadId '' -BaseCommit 'b' -TreeSha256 't'
    Check 'UNIT' 'Add-LedgerEntry (D10): an entry lands at its place by n (2 between 1 and 3; 4 appended); Add-ReplyFindings keeps findings.json in id order (F03-1 between F02-1 and F04-1)' ((@($led.codex.consults | ForEach-Object { $_.n }) -join ',') -eq '1,2,3,4' -and (@($st.findings | ForEach-Object { $_.id }) -join ',') -eq 'F02-1,F03-1,F04-1') "$(@($led.codex.consults | ForEach-Object { $_.n }) -join ',') / $(@($st.findings | ForEach-Object { $_.id }) -join ',')"

    $fpH = 'fp-health'
    $t0 = [DateTimeOffset]::Parse('2026-09-24T12:00:00+00:00', $inv)
    $quotaPf = [pscustomobject]@{ class = 'quota'; code = ''; message = 'usage limit reached'; when = (Iso $t0.AddSeconds(100)); retry_after = $null }
    function He {
        param([int]$N, [DateTimeOffset]$When, $Wall, $Finished, [string]$Outcome, $Pf)
        $e = [ordered]@{ n = $N; when = (Iso $When); reviewer = [pscustomobject]@{ provider = 'p'; model = 'm'; provider_fingerprint = $fpH }; bridge_outcome = $Outcome }
        if ($null -ne $Wall) { $e['wall_seconds'] = $Wall }
        if ($null -ne $Finished) { $e['finished_at'] = (Iso $Finished) }
        if ($null -ne $Pf) { $e['provider_failure'] = $Pf }
        return (New-Object PSObject -Property $e)
    }
    $nowU = $t0.AddMinutes(5).UtcDateTime
    $hA = Get-EndpointHealth -Consults @((He 1 $t0 100 $null 'failed: usage limit reached' $quotaPf), (He 2 ($t0.AddSeconds(10)) 5 $null 'usable reply' $null)) -Fingerprint $fpH -UtcNow $nowU
    $hB = Get-EndpointHealth -Consults @((He 1 $t0 100 ($t0.AddSeconds(5)) 'failed: usage limit reached' $quotaPf), (He 2 ($t0.AddSeconds(10)) 5 ($t0.AddSeconds(20)) 'usable reply' $null)) -Fingerprint $fpH -UtcNow $nowU
    $hC = Get-EndpointHealth -Consults @((He 2 $t0 $null ($t0.AddSeconds(30)) 'usable reply' $null), (He 3 $t0 $null ($t0.AddSeconds(30)) 'failed: usage limit reached' $quotaPf)) -Fingerprint $fpH -UtcNow $nowU
    Check 'UNIT' 'Get-EndpointHealth (D9, F03-3, F02-5): newest by COMPLETION - a quota failure that started first but ended last (when + wall_seconds) still blocks; finished_at decides when present (a later success clears); a tie is broken by n' ($null -ne $hA.Quota -and $null -eq $hB.Quota -and $null -ne $hC.Quota) "A=$([bool]$hA.Quota) B=$([bool]$hB.Quota) C=$([bool]$hC.Quota)"

    # recovery records: the writer (D1) and panel member records (F03-2, F04-5)
    $sleeper = Start-Sleeper 120
    Start-Sleep -Seconds 1
    $sStart = Get-ProcessStartIso -ProcessId $sleeper.Id
    function PRec { param([string]$State, [hashtable]$Extra) $r = New-PendingRecord -State $State -N 5 -Nn '07' -Reply 'handoffs/07-codex-x.md' -Started ((Get-Date).AddMinutes(-2).ToString('yyyy-MM-ddTHH:mm:sszzz', $inv)); foreach ($k in $Extra.Keys) { $r | Add-Member -NotePropertyName $k -NotePropertyValue $Extra[$k] -Force }; return $r }
    $w1 = Test-PendingActive -Record (PRec 'reserved' @{ pid = $sleeper.Id; start_time = $sStart }) -Path 'x.json'
    $w2 = Test-PendingActive -Record (PRec 'reserved' @{ pid = $sleeper.Id; start_time = '2001-01-01T00:00:00.0000000Z' }) -Path 'x.json'
    $w3 = Test-PendingActive -Record (PRec 'reserved' @{}) -Path 'x.json'
    Check 'UNIT' 'Test-PendingActive (D1, F03-1, F04-4): a RESERVED record whose writer (pid + start time) still runs -> active, naming that bridge; the same pid with another start time (reused) -> inactive; a record written by this very process -> not counted' ($w1.Active -and $w1.Message -match "its bridge \(pid $($sleeper.Id)\) wrote x\.json" -and -not $w2.Active -and -not $w3.Active) "$($w1.Check) | $($w2.Check) | $($w3.Check)"
    $lp = Start-Sleeper 120 '# C:\fake\codex.cmd'
    Start-Sleep -Seconds 1
    $deadW = Dead-Pid
    $pinfo = [pscustomobject]@{ id = [guid]::NewGuid().ToString(); position = 2; of = 3; parent_pid = 999999; parent_start_time = '' }
    $v1 = Test-PendingActive -Record (PRec 'launching' @{ pid = $deadW; start_time = '2001-01-01T00:00:00.0000000Z'; launcher = 'C:\fake\codex.cmd'; panel = $pinfo }) -Path 'x.json'
    $v2 = Test-PendingActive -Record (PRec 'launching' @{ pid = $deadW; start_time = '2001-01-01T00:00:00.0000000Z'; launcher = 'C:\fake\codex.cmd' }) -Path 'x.json'
    Check 'UNIT' 'Test-PendingActive (F03-2, F04-5): a panel member''s launching record with a dead writer is NOT kept active by a live process that merely looks like codex (a sibling''s reviewer) - no machine-wide name scan; the same record outside a panel still is ("task not verifiable")' (-not $v1.Active -and $v1.Check -match 'panel member record: no machine-wide name scan' -and $v2.Active -and $v2.Message -match 'task not verifiable') "$($v1.Check) | $($v2.Message)"
    $mid = Start-Process powershell.exe -ArgumentList '-NoProfile', '-Command', "Start-Process powershell -ArgumentList '-NoProfile','-Command','Start-Sleep 120' -WindowStyle Hidden" -PassThru -WindowStyle Hidden
    [void]$mid.WaitForExit(20000)
    Start-Sleep -Seconds 1
    $grand = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$($mid.Id)") | Select-Object -First 1
    if ($grand) { $cleanup.Add([int]$grand.ProcessId) }
    $v3 = Test-PendingActive -Record (PRec 'running' @{ pid = $mid.Id; start_time = '2001-01-01T00:00:00.0000000Z'; child_pid = 999997; child_start_time = '2001-01-01T00:00:00.0000000Z'; panel = $pinfo }) -Path 'x.json'
    Check 'UNIT' 'Test-PendingActive: a panel member''s record whose writer died and left a live child -> active by the recorded writer''s children (the ppid rule stays for member records)' ($null -ne $grand -and $v3.Active -and $v3.Message -match 'ppid') $v3.Check
    foreach ($id in @($sleeper.Id, $lp.Id)) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }

    $rd = Join-Path $work 'records'
    [void][IO.Directory]::CreateDirectory($rd)
    foreach ($n in @('.consult.pending-03.json', '.consult.pending.json', '.consult.pending-01.json', '..consult.pending.json.abc.tmp', '.consult.lock', '.consult.write.lock')) { [IO.File]::WriteAllText((Join-Path $rd $n), '{"state":"committing","n":1,"nn":"01"}', $u8) }
    $rdPaths = Get-PendingPaths -TaskDir $rd
    $names = @($rdPaths | ForEach-Object { [IO.Path]::GetFileName($_) })
    $committing = Read-PendingFile -Path (Join-Path $rd '.consult.pending-01.json')
    Check 'UNIT' 'Get-PendingPaths (D5): the single run''s record first, then the members'' records by name - no temp, no lock files; Read-PendingFile accepts the new state committing' (($names -join ',') -eq '.consult.pending.json,.consult.pending-01.json,.consult.pending-03.json' -and -not $committing.Error -and $committing.Record.state -eq 'committing') ($names -join ',')

    # the write lock (D2, F03-5a): an OS-held handle, waited for; a killed holder releases it
    $wl = Join-Path $work 'wlock'
    [void][IO.Directory]::CreateDirectory($wl)
    $holderPs = Join-Path $work 'wlock-holder.ps1'
    [IO.File]::WriteAllText($holderPs, ". '$scripts\codex-consult-common.ps1'`n`$l = Enter-WriteLock -TaskDir '$wl' -Task 't'`n[IO.File]::WriteAllText('$wl\held.flag', 'x')`nStart-Sleep -Seconds 60`n", $u8)
    $holder = Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $holderPs -PassThru -WindowStyle Hidden
    $cleanup.Add($holder.Id)
    $null = Wait-For { Test-Path (Join-Path $wl 'held.flag') } 30
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $l1 = Enter-WriteLock -TaskDir $wl -Task 't' -TimeoutSec 1.5
    $waited = $sw.Elapsed.TotalSeconds
    Stop-Process -Id $holder.Id -Force; $holder.WaitForExit()
    $l2 = Enter-WriteLock -TaskDir $wl -Task 't' -TimeoutSec 10
    $held = Test-LockHeld (Join-Path $wl '.consult.write.lock')
    $acq2 = [bool]$l2.Acquired
    Exit-TaskLock -Lock $l2
    Check 'UNIT' 'Enter-WriteLock (D2): a live holder -> not acquired after the wait (1.5 s), the message names the holder''s pid; the holder killed -> acquired at once (the OS released it); released = closed, the file stays' (-not $l1.Acquired -and $waited -ge 1.4 -and $l1.Message -match "was not acquired within 1\.5 s: it is held open by pid $($holder.Id) on " -and $acq2 -and $l2.Waited -lt 3 -and $held -and (Test-Path (Join-Path $wl '.consult.write.lock')) -and -not (Test-LockHeld (Join-Path $wl '.consult.write.lock'))) "$($l1.Message) | waited $([math]::Round($waited, 1)) s, then $($l2.Waited) s"

    $loc = { param($p) [pscustomobject]@{ Path = $p; FromEnv = $true; Disabled = $false } }
    $okR = Read-ReviewerRoster -Location (& $loc $rosterZaiPar)
    $bad = @()
    foreach ($case in @(
            @('{"ZAI":0}', 'parallel.ZAI must be an integer >= 1 (got 0)'),
            @('{"ZAI":"2"}', 'parallel.ZAI must be an integer >= 1 (got "2")'),
            @('{"ZAI":1.5}', 'parallel.ZAI must be an integer >= 1 (got 1.5)'),
            @('{"openai":1}', "parallel names the provider label 'openai', which no entry of the roster uses"),
            @('[1]', 'parallel must be an object'))) {
        $p = Write-Roster 'par-bad' ('{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"}],"parallel":' + $case[0] + '}')
        $rr = Read-ReviewerRoster -Location (& $loc $p)
        if (-not ($rr.Error -and $rr.Error.Contains($case[1]))) { $bad += "$($case[0]) -> $($rr.Error)" }
    }
    Check 'UNIT' 'roster "parallel" (D8): {"ZAI":2} is read; 0, "2", 1.5, a label the roster does not use and a non-object are refused naming the problem (fail-closed)' (-not $okR.Error -and $okR.Parallel['ZAI'] -eq 2 -and $bad.Count -eq 0) ($bad -join ' | ')
}

# =============================================================== DRY: the plan, pre-assigned numbers, nothing written
if (Want 'DRY') {
    $r = New-Repo 'dry'
    $dead = Dead-Pid
    $left = [pscustomobject]@{ state = 'reserved'; n = 4; nn = '05'; reply = 'handoffs/05-codex-old-zai.md'; events = ''; consult_id = ''; started = (Get-IsoTimestamp); pid = $dead; start_time = '2001-01-01T00:00:00.0000000Z'; host = [Environment]::MachineName; launcher = ''; engine = 'codex'; child_pid = $null; child_start_time = ''; survivors = [object[]]@(); note = ''; panel = [pscustomobject]@{ id = 'x'; position = 2; of = 2; parent_pid = $dead; parent_start_time = '' } }
    Write-JsonFile -Path (Join-Path (Td $r) '.consult.pending-05.json') -Object $left
    $snap = { (@(Get-ChildItem -LiteralPath (Join-Path $r '.collab') -Recurse -Force | ForEach-Object { "$($_.FullName)|$($_.Length)" }) | Sort-Object) -join ';' }
    $s0 = & $snap
    $d = Consult $r $roster3 @('-Panel', '-DryRun', '-Prompt', 'x', '-ReplyName', 'd')
    $s1 = & $snap
    Check 'DRY' 'dry run: "3 of 3 roster entries would run, at once", every member with its PRE-ASSIGNED n and handoff (past an inactive leftover member record: n 5-7, NN 06-08), the concurrency line, the leftover reported as recovered by the real run' ($d.Code -eq 0 -and $d.First -match '^Panel [0-9a-f]{8} \(dry run - nothing is executed or written\): 3 of 3 roster entries would run, at once \(' -and $d.Out -match '(?m)^  #1 openai :: gpt-5\.1 - member, n=5, handoff 06$' -and $d.Out -match '(?m)^  #2 ZAI :: glm-5\.3 - member, n=6, handoff 07$' -and $d.Out -match '(?m)^  #3 mimo :: mimo-v2\.6-pro - member, n=7, handoff 08$' -and $d.Out -match '(?m)^Concurrency: at once - endpoint groups: openai x1, ZAI x1, mimo x1; -PanelConcurrency 0 \(no cap\)$' -and $d.Out -match '(?m)^pending     : .*\.consult\.pending-05\.json \(state ''reserved'', n=4, nn=05; .*\): the real run recovers it') (($d.Out -split "`n" | Select-Object -First 6) -join ' / ')
    Check 'DRY' 'each member''s own dry-run plan shows its assigned numbers (handoff 06..08, consult n 5..7) and reply names; summary "planned"; nothing written, no lock file created' ($d.Out -match 'handoff     : 06 \(consult n = 5\)' -and $d.Out -match 'handoff     : 07 \(consult n = 6\)' -and $d.Out -match 'handoff     : 08 \(consult n = 7\)' -and $d.Out -match '06-codex-d-openai\.md' -and $d.Out -match '(?m)^  mimo :: mimo-v2\.6-pro\s+planned$' -and $s0 -eq $s1 -and -not (Test-Path (Join-Path (Td $r) '.consult.lock'))) ''
    $d1 = Consult $r $roster3 @('-Panel', '-DryRun', '-PanelConcurrency', '1', '-Prompt', 'x')
    $d2 = Consult $r $roster3 @('-Panel', '-DryRun', '-PanelConcurrency', '2', '-Prompt', 'x')
    $d3 = Consult $r $rosterZai2 @('-Panel', '-DryRun', '-Prompt', 'x')
    $d4 = Consult $r $rosterZaiPar @('-Panel', '-DryRun', '-Prompt', 'x')
    Check 'DRY' 'the plan text: -PanelConcurrency 1 -> "one after another"; 2 of 3 -> "at most 2 at a time"; two entries of one label -> "ZAI x2 one after another"; roster "parallel": {"ZAI": 2} -> "ZAI x2 at once"' ($d1.First -match 'roster entries would run, one after another \(' -and $d2.First -match 'would run, at most 2 at a time \(' -and $d3.Out -match '(?m)^Concurrency: at most 2 at a time - endpoint groups: ZAI x2 one after another, mimo x1; -PanelConcurrency 0 \(no cap\)$' -and $d4.Out -match '(?m)^Concurrency: at once - endpoint groups: ZAI x2 at once, mimo x1;') "$($d1.First) | $(Line $d3.Out 'Concurrency') | $(Line $d4.Out 'Concurrency')"
    $v1 = Consult $r $roster3 @('-DryRun', '-Prompt', 'x', '-PanelConcurrency', '2')
    $v2 = Consult $r $roster3 @('-Panel', '-DryRun', '-Prompt', 'x', '-PanelConcurrency', '-1')
    Check 'DRY' '-PanelConcurrency without -Panel, or negative -> refused' ($v1.Code -eq 1 -and $v1.First -eq 'codex-consult: -PanelConcurrency goes with -Panel (or -PanelAll) only.' -and $v2.Code -eq 1 -and $v2.First -eq 'codex-consult: -PanelConcurrency must be 0 (no cap) or a positive number (got -1).') "$($v1.First) | $($v2.First)"
}

# =============================================================== RUN: overlap, roster order, records, the wall clock
if (Want 'RUN') {
    $r = New-Repo 'run'
    $p = Consult $r $roster3 @('-Panel', '-Prompt', 'x', '-ReplyName', 'x') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_DELAY_MS = 'gpt-5.1=7000|glm-5.3=5000|mimo-v2.6-pro=5000' }
    $led = @(Ledger $r)
    $sum = @(Summary $p.Out)
    $starts = @($led | ForEach-Object { To-Dto $_.when })
    $ends = @($led | ForEach-Object { To-Dto $_.finished_at })
    $lastStart = ($starts | Sort-Object | Select-Object -Last 1)
    $firstEnd = ($ends | Sort-Object | Select-Object -First 1)
    $panelWall = 0.0
    if ($sum[0] -match 'wall clock ([0-9.]+) s') { $panelWall = [double]::Parse($Matches[1], $inv) }
    $memberWalls = 0.0
    foreach ($e in $led) { $memberWalls += [double]$e.wall_seconds }
    Check 'RUN' 'three members of 5-7 s each: exit 0, three ledger entries, every member''s reviewer ran at the same time (the last start before the first finish)' ($p.Code -eq 0 -and $led.Count -eq 3 -and $lastStart -lt $firstEnd) "starts $(@($starts | ForEach-Object { $_.ToString('HH:mm:ss') }) -join ',') ends $(@($ends | ForEach-Object { $_.ToString('HH:mm:ss') }) -join ',')"
    Check 'RUN' 'the panel''s wall clock (summary) is below the sum of the members'' own wall times (sequentially it would exceed it)' ($panelWall -gt 0 -and $panelWall -lt $memberWalls) "panel $panelWall s vs members $memberWalls s; $($sum[0])"
    Check 'RUN' 'the slowest member first in roster order: it finished LAST, yet the ledger is sorted by n in roster order (openai n=1 / 01, ZAI n=2 / 02, mimo n=3 / 03) and findings.json is in id order' ((@($led | ForEach-Object { $_.n }) -join ',') -eq '1,2,3' -and $led[0].reply -eq 'handoffs/01-codex-x-openai.md' -and $led[1].reply -eq 'handoffs/02-codex-x-zai.md' -and $led[2].reply -eq 'handoffs/03-codex-x-mimo.md' -and $ends[0] -ge $ends[1] -and $ends[0] -ge $ends[2] -and (@(Findings $r | ForEach-Object { $_.id }) -join ',') -eq 'F01-1,F02-1,F03-1') "$(@($led | ForEach-Object { "$($_.n):$($_.reply)" }) -join ' ')"
    $i1 = $p.Out.IndexOf('panel member 1 of 3 finished'); $i3 = $p.Out.IndexOf('panel member 3 of 3 finished')
    $o1 = $p.Out.IndexOf('=== panel '); $o2 = $p.Out.IndexOf(' member 2 of 3: ZAI'); $o3 = $p.Out.IndexOf(' member 3 of 3: mimo')
    Check 'RUN' 'the console: one progress line per member as it finishes (member 3 before member 1), then every member''s output in roster order, then the summary with the wall clock' ($i3 -ge 0 -and $i1 -gt $i3 -and $o1 -gt $i1 -and $o2 -gt $o1 -and $o3 -gt $o2 -and $sum[0] -match '^Panel [0-9a-f]{8}: 3 of 3 entries ran \(wall clock [0-9.]+ s; at once\)$' -and $sum[1] -match '^  openai :: gpt-5\.1\s+ADVISE\s+0 blocker, 0 major, 1 minor\s+prior: none') ($sum[0..1] -join ' | ')
    Check 'RUN' 'ledger panel record: concurrency 3 and the per-label limits (openai 1, ZAI 1, mimo 1); the same panel id and members list in every entry' ($led[0].panel.concurrency -eq 3 -and $led[0].panel.limits.openai -eq 1 -and $led[0].panel.limits.ZAI -eq 1 -and $led[0].panel.limits.mimo -eq 1 -and [string]$led[1].panel.id -eq [string]$led[0].panel.id -and (($led[2].panel.members | ConvertTo-Json -Compress) -eq ($led[0].panel.members | ConvertTo-Json -Compress))) (ConvertTo-Json -Compress -Depth 4 $led[0].panel.limits)
    $recs = Records $r
    Check 'RUN' 'after success: no recovery record left (per-member records removed), the task lock and the write lock free, the lock files kept' (@($recs).Count -eq 0 -and -not (Test-LockHeld (Join-Path (Td $r) '.consult.lock')) -and (Test-Path (Join-Path (Td $r) '.consult.write.lock')) -and -not (Test-LockHeld (Join-Path (Td $r) '.consult.write.lock'))) "$(@($recs).Count) records"
    $rate = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '2', '-Useful', 'yes')
    $fs = ([IO.File]::ReadAllText((Join-Path (Td $r) 'findings.json'), $u8) | ConvertFrom-Json)
    Check 'RUN' 'codex-findings -Rate goes through the store commit: rated, findings kept (3), the write lock free after' ($rate.Code -eq 0 -and @($fs.ratings).Count -eq 1 -and $fs.ratings[0].n -eq 2 -and @($fs.findings).Count -eq 3 -and -not (Test-LockHeld (Join-Path (Td $r) '.consult.write.lock'))) $rate.First
}

# =============================================================== NOLOSS: concurrent commits under the write lock (D2, D4)
if (Want 'NOLOSS') {
    $r = New-Repo 'noloss'
    $s = Consult $r $roster3 @('-Provider', 'mimo', '-Prompt', 'seed', '-ReplyName', 'seed') @{ FAKE_CODEX_REPLY = $adviseF }
    $check = Reply 'check-f01.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[{"id":"F01-1","status":"still-open","note":"seen"}],"unproven":[],"first_run_checklist":[]}')
    # equal delays and a pause inside every commit (4 s, longer than the members' start spread):
    # the three commits contend for the write lock
    $p = Consult $r $roster3 @('-Panel', '-Prompt', 'x', '-ReplyName', 'c') @{ FAKE_CODEX_REPLY = $check; FAKE_CODEX_DELAY_MS = '3000'; CODEX_CONSULT_TEST_COMMIT_PAUSE_MS = '4000' }
    $fs = @(Findings $r)
    $f01 = @($fs | Where-Object { $_.id -eq 'F01-1' })[0]
    $checks = @($f01.reviewer_checks | ForEach-Object { [int]$_.consult } | Sort-Object)
    $led = @(Ledger $r)
    Check 'NOLOSS' 'three members commit one after another under the write lock, each on the RE-READ stores: all four findings present (F01-1 seed, F02-1..F04-1 in id order) and the seed finding carries every member''s reviewer check (consults 2, 3, 4) - no lost update' ($s.Code -eq 0 -and $p.Code -eq 0 -and (@($fs | ForEach-Object { $_.id }) -join ',') -eq 'F01-1,F02-1,F03-1,F04-1' -and ($checks -join ',') -eq '2,3,4' -and @($f01.reviewer_checks | Where-Object { $_.status -eq 'still-open' }).Count -eq 3) "ids $(@($fs | ForEach-Object { $_.id }) -join ','); checks by consult $($checks -join ',')"
    $l = Run-Tool $findingsPs $r @('-Task', 't', '-List', '-All')
    Check 'NOLOSS' 'the ledger has all four entries sorted by n, each member''s prior_findings names F01-1 still-open, and -List -All finds no ORPHAN' ((@($led | ForEach-Object { $_.n }) -join ',') -eq '1,2,3,4' -and @($led[1..3] | Where-Object { @($_.prior_findings | Where-Object { $_.id -eq 'F01-1' -and $_.status -eq 'still-open' }).Count -eq 1 }).Count -eq 3 -and $l.Out -match 'orphans: 0 finding\(s\), 0 reviewer check\(s\)') (Line $l.Out 'codex-findings:')
    $waits = @($led[1..3] | ForEach-Object { [int]$_.commit_wait_ms })
    Check 'NOLOSS' 'the commits really CONTENDED (F11-3): at least one member waited for the write lock (ledger commit_wait_ms > 0, console "write lock : waited N ms for another commit of this task"); the uncontended seed run waited 0 ms' (@($waits | Where-Object { $_ -gt 0 }).Count -ge 1 -and $p.Out -match '(?m)^write lock : waited [0-9]+ ms for another commit of this task$' -and $led[0].PSObject.Properties['commit_wait_ms'] -and [int]$led[0].commit_wait_ms -eq 0) "commit_wait_ms of members 2-4: $($waits -join ', ')"
}

# =============================================================== INFLIGHT: the task lock for the whole panel, member records while it runs (D1, D12)
if (Want 'INFLIGHT') {
    $r = New-Repo 'inflight'
    $seed = Consult $r $roster3 @('-Provider', 'mimo', '-Prompt', 'seed', '-ReplyName', 'seed') @{ FAKE_CODEX_REPLY = $adviseF }
    $bg = Start-Consult $r $roster3 @('-Panel', '-Prompt', 'x', '-ReplyName', 'b') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_DELAY_MS = '12000' }
    $running = Wait-For { $rs = Records $r; @($rs).Count -eq 3 -and @($rs | Where-Object { $_.Record -and $_.Record.state -eq 'running' }).Count -eq 3 } 90
    $recs = Records $r
    $lockRec = Read-LockContent -Path (Join-Path (Td $r) '.consult.lock')
    $single = Consult $r $roster3 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'during') @{ FAKE_CODEX_REPLY = $advise }
    $status = Run-Tool $findingsPs $r @('-Task', 't', '-Id', 'F01-1', '-Status', 'implemented')
    $list = Run-Tool $findingsPs $r @('-Task', 't', '-List')
    [void]$bg.Proc.WaitForExit(120000)
    $bgOut = Bg-Output $bg
    $panelId = [string](Get-PropertyValue $lockRec 'panel' '')
    $panelShortId = if ($panelId.Length -ge 8) { $panelId.Substring(0, 8) } else { 'no-panel-in-lock' }
    $memberPids = @($recs | ForEach-Object { [int]$_.Record.pid })
    Check 'INFLIGHT' 'while the panel runs: .consult.lock is held by the panel run and its record names the panel; one record per member (.consult.pending-02/03/04.json), each naming the panel and the parent, rewritten by its member (pid + start time of the member, not the parent)' ($running -and [int](Get-PropertyValue $lockRec 'pid' 0) -eq $bg.Proc.Id -and $panelId -match '^[0-9a-f-]{36}$' -and (@($recs | ForEach-Object { $_.Name }) -join ',') -eq '.consult.pending-02.json,.consult.pending-03.json,.consult.pending-04.json' -and @($recs | Where-Object { [string]$_.Record.panel.id -eq $panelId -and [int]$_.Record.panel.parent_pid -eq $bg.Proc.Id -and [int]$_.Record.pid -ne $bg.Proc.Id -and [string]$_.Record.start_time }).Count -eq 3 -and @($memberPids | Select-Object -Unique).Count -eq 3) "lock $(ConvertTo-Json -Compress $lockRec); members $($memberPids -join ',')"
    Check 'INFLIGHT' 'a single run started during the panel is refused on the task lock (naming the panel run), and so is codex-findings -Status (D12); -List shows one pending line per member record' ($single.Code -eq 1 -and $single.Refusal -match "held open by pid $($bg.Proc.Id) on .* \(review panel $panelShortId\)" -and $status.Code -eq 1 -and $status.First -match 'held open by pid' -and @(($list.Out -split "`n") | Where-Object { $_ -match '^pending: state=running, n=\d, nn=0\d, .*\.consult\.pending-0\d\.json\)' }).Count -eq 3) "$($single.Refusal) | $($status.First)"
    Check 'INFLIGHT' 'the panel ends usable (exit 0): members n 2-4, no record left, the lock free' ($bg.Proc.ExitCode -eq 0 -and (@(Ledger $r | ForEach-Object { $_.n }) -join ',') -eq '1,2,3,4' -and (Records $r).Count -eq 0 -and -not (Test-LockHeld (Join-Path (Td $r) '.consult.lock'))) (($bgOut -split "`n" | Where-Object { $_ -match '^Panel [0-9a-f]{8}: ' }) -join ' / ')
}

# =============================================================== TIMEOUT: survivors keep the member's record; the others are not stopped
if (Want 'TIMEOUT') {
    # (wave 23b) the plain timeout kill of a member - no survivors: its process tree is gone
    # (no orphan fake codex: every exec turn's pid, checked with its start time) and its
    # recovery record is removed (nothing kept)
    $rc = New-Repo 'timeout-clean'
    $pidDir = Join-Path $work 'timeout-clean-pids'
    [void][IO.Directory]::CreateDirectory($pidDir)
    $q = Consult $rc $roster3 @('-Panel', '-Prompt', 'x', '-ReplyName', 'c', '-TimeoutSec', '5') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""ZAI""'; FAKE_CODEX_PIDDIR = $pidDir }
    $qled = @(Ledger $rc)
    $fakes = @(Get-ChildItem -LiteralPath $pidDir -Filter '*.pid' | ForEach-Object { $parts = @(([IO.File]::ReadAllText($_.FullName)).Trim() -split ' '); [pscustomobject]@{ Id = [int]$parts[0]; Ticks = [long]$parts[1] } })
    # (alive = that pid runs a process started within 2 s of the recorded start: not a reused pid)
    $alive = @($fakes | Where-Object { $gp = Get-Process -Id $_.Id -ErrorAction SilentlyContinue; $gp -and [Math]::Abs($gp.StartTime.ToUniversalTime().Ticks - $_.Ticks) -lt (2 * [TimeSpan]::TicksPerSecond) })
    $qrecs = Records $rc   # (the array itself: Records returns it with the unary comma - never @() it)
    Check 'TIMEOUT' 'a member''s timeout kill with NO survivors (wave 23b): "failed: timeout after 5 s (process tree killed)" and no survivor clause, members 1 and 3 usable, exit 1; no orphan: none of the 4 exec turns'' fake codex processes (3 members + the killed member''s timeout continuation, wave 24 - it hangs too) is alive; no recovery record kept' ($q.Code -eq 1 -and $qled.Count -eq 3 -and $qled[0].bridge_outcome -eq 'usable reply' -and $qled[1].bridge_outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $qled[1].timeout_continue.outcome -eq 'failed: timeout after 5 s (process tree killed)' -and $qled[2].bridge_outcome -eq 'usable reply' -and $fakes.Count -eq 4 -and $alive.Count -eq 0 -and @($qrecs).Count -eq 0) "$(if ($qled.Count -gt 1) { $qled[1].bridge_outcome }) | fakes $($fakes.Count), alive $($alive.Count), records $(@($qrecs).Count)$(foreach ($qr in $qrecs) { " [$($qr.Name): state $($qr.Record.state), n $($qr.Record.n), note $($qr.Record.note)]" })"
    $r = New-Repo 'timeout'
    $sleeper = Start-Sleeper 180
    try {
        $p = Consult $r $roster3 @('-Panel', '-Prompt', 'x', '-ReplyName', 's', '-TimeoutSec', '5') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""ZAI""'; CODEX_CONSULT_TEST_SURVIVORS = "$($sleeper.Id)"; FAKE_CODEX_DELAY_MS = '2000' }
        $led = @(Ledger $r)
        $recs = Records $r
        $sum = @(Summary $p.Out)
        Check 'TIMEOUT' 'member 2 times out leaving survivors: its record .consult.pending-02.json is KEPT (state survivors, naming the survivor), members 1 and 3 still ran and are usable (default concurrency - F15-3 applies to -PanelConcurrency 1 only), exit 1' ($p.Code -eq 1 -and $led.Count -eq 3 -and $led[0].bridge_outcome -eq 'usable reply' -and $led[1].bridge_outcome -match '^failed: timeout after 5 s \(process tree killed; 1 processes survived' -and $led[2].bridge_outcome -eq 'usable reply' -and @($recs).Count -eq 1 -and $recs[0].Name -eq '.consult.pending-02.json' -and $recs[0].Record.state -eq 'survivors' -and [int]$recs[0].Record.survivors[0].pid -eq $sleeper.Id -and $sum[2] -match '^  ZAI :: glm-5\.3\s+failed: timeout after 5 s') ($sum[0..3] -join ' | ')
        $x = Consult $r $roster3 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'refused') @{ FAKE_CODEX_REPLY = $advise }
        $rt = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '1', '-Useful', 'yes')
        Check 'TIMEOUT' 'the next run is refused while the survivor lives, naming the member''s record; so is codex-findings -Rate, which judges the recovery records like -Status (D5, F11-4)' ($x.Code -eq 1 -and $x.Refusal -match "\(pid $($sleeper.Id)\) is still running" -and $x.Refusal -match 'review panel [0-9a-f]{8} member 2' -and $rt.Code -eq 1 -and $rt.First -match "^codex-findings: a previous consultation's codex process \(pid $($sleeper.Id)\) is still running" -and -not (Test-Path (Join-Path (Td $r) 'findings.json'))) "$($x.Refusal) | $($rt.First)"
    } finally { Stop-Process -Id $sleeper.Id -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Milliseconds 500
    $y = Consult $r $roster3 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'after') @{ FAKE_CODEX_REPLY = $advise }
    $e = @(Ledger $r)[-1]
    Check 'TIMEOUT' 'survivor gone: the next run clears the member''s record (its ledger entry exists) and commits n=4 / 04-codex-after.md; no record left' ($y.Code -eq 0 -and $y.Out -match "cleared the recovery record of consult n=2, nn=02 \(\.consult\.pending-02\.json: state 'survivors'" -and $e.n -eq 4 -and $e.reply -eq 'handoffs/04-codex-after.md' -and (Records $r).Count -eq 0) (Line $y.Out 'codex-consult: cleared')
}

# =============================================================== SEQ: -PanelConcurrency 1, one endpoint one after another
if (Want 'SEQ') {
    $r = New-Repo 'seq'
    $p = Consult $r $roster3 @('-Panel', '-PanelConcurrency', '1', '-Prompt', 'x', '-ReplyName', 'q') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_DELAY_MS = '2000' }
    $led = @(Ledger $r)
    $okSeq = ($led.Count -eq 3)
    for ($i = 0; $okSeq -and $i -lt 2; $i++) { if ((To-Dto $led[$i].finished_at) -gt (To-Dto $led[$i + 1].when)) { $okSeq = $false } }
    Check 'SEQ' '-PanelConcurrency 1: "one after another", strictly - every member''s reviewer starts after the previous member committed (finished_at <= next when), in roster order' ($p.Code -eq 0 -and $p.First -match ': 3 of 3 roster entries run, one after another \(' -and $okSeq) "$(@($led | ForEach-Object { "$($_.n) $((To-Dto $_.when).ToString('HH:mm:ss'))-$((To-Dto $_.finished_at).ToString('HH:mm:ss'))" }) -join ', ')"
    $r2 = New-Repo 'seq-endpoint'
    $p2 = Consult $r2 $rosterZai2 @('-Panel', '-Prompt', 'x', '-ReplyName', 'e') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_DELAY_MS = 'glm-5.3=4000|glm-5.3-flash=4000|mimo-v2.6-pro=7000' }
    $l2 = @(Ledger $r2)
    Check 'SEQ' 'two entries of one provider label (one endpoint) run one after another, the other endpoint beside them: ZAI glm-5.3 committed before ZAI glm-5.3-flash started, mimo ran during the first ZAI member ("at most 2 at a time")' ($p2.Code -eq 0 -and $p2.First -match ': 3 of 3 roster entries run, at most 2 at a time \(' -and $l2.Count -eq 3 -and $l2[0].model -eq 'glm-5.3' -and $l2[1].model -eq 'glm-5.3-flash' -and (To-Dto $l2[0].finished_at) -le (To-Dto $l2[1].when) -and (To-Dto $l2[2].when) -lt (To-Dto $l2[0].finished_at)) "$(@($l2 | ForEach-Object { "$($_.model) $((To-Dto $_.when).ToString('HH:mm:ss'))-$((To-Dto $_.finished_at).ToString('HH:mm:ss'))" }) -join ', ')"
}

# =============================================================== AGY: an agy member beside committing siblings (D7)
if (Want 'AGY') {
    $r = New-Repo 'agy'
    $p = Consult $r $rosterMixed @('-Panel', '-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'g') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_AGY_REPLY = $adviseF; FAKE_AGY_DELAY_MS = '10000'; FAKE_CODEX_DELAY_MS = '3000' }
    $led = @(Ledger $r)
    Check 'AGY' 'the codex member commits (stores + its handoffs) WHILE the agy member''s reviewer runs, and the agy member stays usable: its tree check leaves the siblings'' writes out (D7); findings F01-1 and F02-1' ($p.Code -eq 0 -and $led.Count -eq 2 -and $led[1].reviewer.engine -eq 'agy' -and $led[1].bridge_outcome -eq 'usable reply' -and (To-Dto $led[0].finished_at) -lt (To-Dto $led[1].finished_at) -and (To-Dto $led[1].when) -le (To-Dto $led[0].finished_at) -and (@(Findings $r | ForEach-Object { $_.id }) -join ',') -eq 'F01-1,F02-1') "$(@($led | ForEach-Object { "$($_.n) $($_.bridge_outcome)" }) -join ' | ')"
    $r2 = New-Repo 'agy-write'
    $p2 = Consult $r2 $rosterMixed @('-Panel', '-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'w') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_AGY_REPLY = $adviseF; FAKE_AGY_DELAY_MS = '8000'; FAKE_CODEX_DELAY_MS = '3000'; FAKE_AGY_WRITE = '.collab\t\state.md' }
    $l2 = @(Ledger $r2)
    Check 'AGY' '...but a write elsewhere in the collab root still fails the agy member ("1 file: .collab/t/state.md" - the siblings'' files are not listed), the codex member stays usable, exit 1' ($p2.Code -eq 1 -and $l2.Count -eq 2 -and $l2[0].bridge_outcome -eq 'usable reply' -and $l2[1].bridge_outcome -eq "failed: the collab directory changed during the run (by the reviewer or anyone else): 1 file: .collab/t/state.md - agy's sandbox does not block writes") $l2[1].bridge_outcome
}

# =============================================================== PARENT: the panel run killed mid-panel (D1, Q3)
if (Want 'PARENT') {
    $r = New-Repo 'parent'
    $bg = Start-Consult $r $roster2 @('-Panel', '-Prompt', 'x', '-ReplyName', 'k') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_DELAY_MS = '15000' }
    $running = Wait-For { $rs = Records $r; @($rs).Count -eq 2 -and @($rs | Where-Object { $_.Record -and $_.Record.state -eq 'running' }).Count -eq 2 } 90
    $recs = Records $r
    $memberPids = @($recs | ForEach-Object { [int]$_.Record.pid })
    $panelId = [string]$recs[0].Record.panel.id
    Stop-Process -Id $bg.Proc.Id -Force
    [void]$bg.Proc.WaitForExit(10000)
    $membersAlive = (@($memberPids | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }).Count -eq 2)
    $x = Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'during') @{ FAKE_CODEX_REPLY = $advise }
    $status = Run-Tool $findingsPs $r @('-Task', 't', '-List')
    Check 'PARENT' 'the panel run killed while both members run: the members live on, their records stay; a new single run gets the (now free) task lock but is REFUSED by the member records - their writers (the members, pid + start time) are alive' ($running -and $bg.Proc.HasExited -and $membersAlive -and $x.Code -eq 1 -and $x.Refusal -match "a consultation of this task is still running: its bridge \(pid $($memberPids[0])\) wrote .*\.consult\.pending-01\.json" -and @(($status.Out -split "`n") | Where-Object { $_ -match '^pending: state=running' }).Count -eq 2) $x.Refusal
    $gone = Wait-For { (Records $r).Count -eq 0 -and @($memberPids | Where-Object { Get-Process -Id $_ -ErrorAction SilentlyContinue }).Count -eq 0 } 120
    $led = @(Ledger $r)
    $y = Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'after') @{ FAKE_CODEX_REPLY = $advise }
    $e = @(Ledger $r)[-1]
    Check 'PARENT' 'the orphaned members committed on their own (entries n 1 and 2 of the panel, findings F01-1 and F02-1), removed their records; then the next run proceeds with n=3 / 03' ($gone -and $led.Count -eq 2 -and [string]$led[0].panel.id -eq $panelId -and $led[1].bridge_outcome -eq 'usable reply' -and (@(Findings $r | ForEach-Object { $_.id }) -join ',') -eq 'F01-1,F02-1' -and $y.Code -eq 0 -and $e.n -eq 3 -and $e.reply -eq 'handoffs/03-codex-after.md') "$($led.Count) entries; next n=$($e.n)"
    $tmpDir = Join-Path ([IO.Path]::GetTempPath()) "codex-consult-panel-$panelId"
    if ($panelId -and (Test-Path -LiteralPath $tmpDir)) { Remove-Item -LiteralPath $tmpDir -Recurse -Force -ErrorAction SilentlyContinue }
}

# =============================================================== SPEC: the member's proof of its parent (D6) and its re-check before launching (D1)
if (Want 'SPEC') {
    function New-Spec {
        param([int]$ParentPid, [string]$ParentStart, [string]$PanelId, [int]$N = 1, [string]$Nn = '01')
        $spec = [pscustomobject]@{
            id = $PanelId; position = 1; of = 2
            members = [object[]]@([pscustomobject]@{ provider = 'openai'; model = 'gpt-5.1'; state = 'run'; reason = '' }, [pscustomobject]@{ provider = 'mimo'; model = 'mimo-v2.6-pro'; state = 'run'; reason = '' })
            roster_position = 1; provider = 'openai'; model = 'gpt-5.1'; engine = 'codex'; skipped = [object[]]@(); listed_ids = [object[]]@()
            n = $N; nn = $Nn; consult_id = [guid]::NewGuid().ToString(); parent_pid = $ParentPid; parent_start_time = $ParentStart
            sibling_nns = [object[]]@('02'); concurrency = 2; limits = [pscustomobject]@{ openai = 1; mimo = 1 }
            args = [pscustomobject]@{ collab_dir = '.collab'; mode = ''; brief = ''; prompt = 'x'; purpose = ''; effort = ''; sandbox = 'read-only'; max_words = 0; timeout_sec = 900; reply_name = 'm-openai'; artifact = [object[]]@(); raw = $false; codex_exe = $fake; native_effort = ''; off_peak_only = $false; skip_preflight = $false; codex_config = [object[]]@(); schema_transport = ''; format_retry = 1; engine = ''; engine_exe = ''; denial_retry = 1; dry_run = $false }
        }
        return [Convert]::ToBase64String($u8.GetBytes((ConvertTo-Json -InputObject $spec -Depth 8 -Compress)))
    }
    function Write-MemberRecord {
        param([string]$Repo, [int]$ParentPid, [string]$ParentStart, [string]$PanelId, [int]$N = 1, [string]$Nn = '01')
        $rec = [pscustomobject]@{ state = 'reserved'; n = $N; nn = $Nn; reply = "handoffs/$Nn-codex-m-openai.md"; events = ''; consult_id = ''; started = (Get-IsoTimestamp); pid = $ParentPid; start_time = $ParentStart; host = [Environment]::MachineName; launcher = $fake; engine = 'codex'; child_pid = $null; child_start_time = ''; survivors = [object[]]@(); note = ''; panel = [pscustomobject]@{ id = $PanelId; position = 1; of = 2; parent_pid = $ParentPid; parent_start_time = $ParentStart } }
        $path = Join-Path (Td $Repo) ".consult.pending-$Nn.json"
        Write-JsonFile -Path $path -Object $rec
        return $path
    }
    $pidFile = Join-Path $work 'spec-fake.pid'
    $r = New-Repo 'spec'
    $pid0 = Dead-Pid
    $gid = [guid]::NewGuid().ToString()
    $recPath = Write-MemberRecord $r $pid0 '2001-01-01T00:00:00.0000000Z' $gid
    $h0 = (Get-FileHash -Algorithm SHA256 -LiteralPath $recPath).Hash
    $a = Consult-Member $r $roster2 (New-Spec $pid0 '2001-01-01T00:00:00.0000000Z' $gid) @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFile }
    Check 'SPEC' 'a member whose panel run is dead refuses (D6) - found AFTER it rewrote its record with its own pid (F07-1, F11-6): "the review panel run that launched this member (pid N) is gone; this panel member was not started - nothing was started and its recovery record ''...'' was withdrawn"; no reviewer, no ledger, the record gone' ($a.Code -eq 1 -and $a.Refusal -match "^codex-consult: the review panel run that launched this member \(pid $pid0\) is gone; this panel member was not started - nothing was started and its recovery record '.*\.consult\.pending-01\.json' was withdrawn\.$" -and -not (Test-Path $pidFile) -and @(Ledger $r).Count -eq 0 -and -not (Test-Path $recPath)) $a.Refusal
    Remove-Item $recPath -ErrorAction SilentlyContinue
    $meStart = Get-ProcessStartIso -ProcessId $PID
    $b = Consult-Member $r $roster2 (New-Spec $PID $meStart $gid) @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFile }
    $null = Write-MemberRecord $r $PID $meStart $gid -N 7
    $c = Consult-Member $r $roster2 (New-Spec $PID $meStart $gid) @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFile }
    Check 'SPEC' 'a live parent but no record -> refused ("does not exist"); a record that names another n -> refused naming the mismatch ("n 7 in the record, 1 in the spec"); nothing started either time' ($b.Code -eq 1 -and $b.Refusal -match "recovery record '.*\.consult\.pending-01\.json' does not exist" -and $c.Code -eq 1 -and $c.Refusal -match 'does not match its spec \(n 7 in the record, 1 in the spec\)' -and -not (Test-Path $pidFile)) "$($b.Refusal) | $($c.Refusal)"
    Remove-Item (Join-Path (Td $r) '.consult.pending-01.json') -ErrorAction SilentlyContinue
    # D1: the parent dies while the member prepares -> the member stops before launching
    $parent = Start-Sleeper 120
    Start-Sleep -Milliseconds 500
    $pStart = Get-ProcessStartIso -ProcessId $parent.Id
    $recPath = Write-MemberRecord $r $parent.Id $pStart $gid
    $bg = Start-Consult $r $roster2 @('-PanelSpec', (New-Spec $parent.Id $pStart $gid)) @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFile; FAKE_CODEX_LOGIN_DELAY_MS = '6000' } -Member
    $rewritten = Wait-For { $rd = Read-PendingFile -Path $recPath; $rd.Record -and [int]$rd.Record.pid -eq $bg.Proc.Id } 60
    Stop-Process -Id $parent.Id -Force
    [void]$bg.Proc.WaitForExit(90000)
    $out = Bg-Output $bg
    Check 'SPEC' 'the member rewrites its record with its own pid first (D1); its panel run dies during its preflight -> it stops right before launching: "the review panel run that launched this member (pid N) is gone; this member stopped before starting codex - nothing was started", record withdrawn, no reviewer, no ledger' ($rewritten -and $bg.Proc.ExitCode -eq 1 -and $out -match "the review panel run that launched this member \(pid $($parent.Id)\) is gone; this member stopped before starting codex - nothing was started" -and -not (Test-Path $recPath) -and -not (Test-Path $pidFile) -and @(Ledger $r).Count -eq 0) (($out -split "`n" | Where-Object { $_ -match '^codex-consult' }) -join ' | ')
    # F07-1 / F11-6: the panel run dies AFTER the member rewrote its record and BEFORE the member
    # checks it (TEST HOOK: a pause there). The record names the live member all the while, so a
    # new run is refused - no moment in which it reads inactive while the member runs; the
    # member then finds its parent gone, withdraws the record and stops.
    $parent2 = Start-Sleeper 120
    Start-Sleep -Milliseconds 500
    $p2Start = Get-ProcessStartIso -ProcessId $parent2.Id
    $recPath2 = Write-MemberRecord $r $parent2.Id $p2Start $gid
    if (Test-Path $pidFile) { Remove-Item $pidFile }
    $bg2 = Start-Consult $r $roster2 @('-PanelSpec', (New-Spec $parent2.Id $p2Start $gid)) @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFile; CODEX_CONSULT_TEST_MEMBER_PAUSE_MS = '15000' } -Member
    $rewritten2 = Wait-For { $rd = Read-PendingFile -Path $recPath2; $rd.Record -and [int]$rd.Record.pid -eq $bg2.Proc.Id } 60
    Stop-Process -Id $parent2.Id -Force
    $during = Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'during') @{ FAKE_CODEX_REPLY = $advise }
    [void]$bg2.Proc.WaitForExit(90000)
    $out2 = Bg-Output $bg2
    $after = Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'after') @{ FAKE_CODEX_REPLY = $advise }
    Check 'SPEC' 'F07-1/F11-6: the parent killed between the member''s rewrite and its parent check: a new run meanwhile is REFUSED by the record (its writer, the member, runs); the member then withdraws the record and stops, nothing started; the next run proceeds (n=1)' ($rewritten2 -and $during.Code -eq 1 -and $during.Refusal -match "a consultation of this task is still running: its bridge \(pid $($bg2.Proc.Id)\) wrote .*\.consult\.pending-01\.json" -and $bg2.Proc.ExitCode -eq 1 -and $out2 -match "the review panel run that launched this member \(pid $($parent2.Id)\) is gone; this panel member was not started - nothing was started and its recovery record '.*' was withdrawn" -and -not (Test-Path $recPath2) -and -not (Test-Path $pidFile) -and $after.Code -eq 0 -and @(Ledger $r).Count -eq 1 -and @(Ledger $r)[0].n -eq 1) "$($during.Refusal) | $(($out2 -split "`n" | Where-Object { $_ -match '^codex-consult' }) -join ' | ')"
}

# =============================================================== BLOCKED: the write lock never acquired (D3)
if (Want 'BLOCKED') {
    $r = New-Repo 'blocked'
    $wlock = Join-Path (Td $r) '.consult.write.lock'
    $hold = Enter-WriteLock -TaskDir (Td $r) -Task 't'
    try {
        $p = Consult $r $roster2 @('-Panel', '-Prompt', 'x', '-ReplyName', 'b') @{ FAKE_CODEX_REPLY = $adviseF; CODEX_CONSULT_TEST_WRITE_LOCK_SEC = '2' }
        $recs = Records $r
        $sum = @(Summary $p.Out)
    } finally { Exit-TaskLock -Lock $hold }
    $rj1 = Join-Path (Td $r) 'handoffs\01-codex-b-openai.reply.json'
    Check 'BLOCKED' 'the write lock held past the (test) 2 s wait: both members give up WITHOUT touching the stores - no sessions.json, no findings.json, no handoff .md - keep their reply.json and their record (state committing, reply_json named), exit 1; the summary says "commit blocked"' ($p.Code -eq 1 -and -not (Test-Path (Join-Path (Td $r) 'sessions.json')) -and -not (Test-Path (Join-Path (Td $r) 'findings.json')) -and -not (Test-Path (Join-Path (Td $r) 'handoffs\01-codex-b-openai.md')) -and (Test-Path $rj1) -and @($recs).Count -eq 2 -and @($recs | Where-Object { $_.Record.state -eq 'committing' -and $_.Record.reply_json -match '^\.collab/t/handoffs/0\d-codex-b-\w+\.reply\.json$' }).Count -eq 2 -and $sum[1] -match "^  openai :: gpt-5\.1\s+commit blocked: the write lock '.*\.consult\.write\.lock' of task 't' was not acquired within 2 s: it is held open by pid $PID " -and $sum[2] -match '^  mimo :: mimo-v2\.6-pro\s+commit blocked: ') ($sum[0..2] -join ' | ')
    $l = Run-Tool $findingsPs $r @('-Task', 't', '-List')
    $x = Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'next') @{ FAKE_CODEX_REPLY = $advise }
    $e = @(Ledger $r)[-1]
    Check 'BLOCKED' 'afterwards -List names each kept reply; the next run consumes both records ("recovered reservation n=1, nn=01 (.consult.pending-01.json: state ''committing''...; the reply of that run is kept at ...)"), numbering past them (n=3 / 03), records removed' (@(($l.Out -split "`n") | Where-Object { $_ -match "^pending: state=committing, .*the reply of that run is kept at \.collab/t/handoffs/0\d-codex-b-\w+\.reply\.json \(its commit did not complete\)" }).Count -eq 2 -and $x.Code -eq 0 -and $x.Out -match "recovered reservation n=1, nn=01 \(\.consult\.pending-01\.json: state 'committing' of an interrupted run; .*the reply of that run is kept at \.collab/t/handoffs/01-codex-b-openai\.reply\.json" -and $x.Out -match 'recovered reservation n=2, nn=02' -and $e.n -eq 3 -and $e.reply -eq 'handoffs/03-codex-next.md' -and (Records $r).Count -eq 0) (Line $x.Out 'codex-consult: recovered')
    # a single run and codex-findings -Status take the same write lock
    $r2 = New-Repo 'blocked-single'
    $seed = Consult $r2 $roster2 @('-Provider', 'mimo', '-Prompt', 'seed', '-ReplyName', 'seed') @{ FAKE_CODEX_REPLY = $adviseF }
    $hold = Enter-WriteLock -TaskDir (Td $r2) -Task 't'
    try {
        $st = Run-Tool $findingsPs $r2 @('-Task', 't', '-Id', 'F01-1', '-Status', 'implemented') @{ CODEX_CONSULT_TEST_WRITE_LOCK_SEC = '2' }
        $sx = Consult $r2 $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'blk') @{ FAKE_CODEX_REPLY = $adviseF; CODEX_CONSULT_TEST_WRITE_LOCK_SEC = '2' }
    } finally { Exit-TaskLock -Lock $hold }
    $pend = Read-PendingFile -Path (Join-Path (Td $r2) '.consult.pending.json')
    Check 'BLOCKED' 'with the write lock held: codex-findings -Status is refused ("... not acquired within 2 s ...; nothing was changed"), a single run ends "commit blocked" (exit 1) with its .consult.pending.json in state committing; the ledger and findings unchanged' ($st.Code -eq 1 -and $st.First -match "^codex-findings: the write lock '.*' of task 't' was not acquired within 2 s: .*; nothing was changed\.$" -and @(Findings $r2)[0].status -eq 'proposed' -and $sx.Code -eq 1 -and $sx.Out -match '(?m)^codex-consult: commit blocked: ' -and $pend.Record.state -eq 'committing' -and @(Ledger $r2).Count -eq 1 -and @(Findings $r2).Count -eq 1) "$($st.First) | $(Line $sx.Out 'codex-consult: commit')"
    $st2 = Run-Tool $findingsPs $r2 @('-Task', 't', '-Id', 'F01-1', '-Status', 'implemented')
    Check 'BLOCKED' 'the lock released: -Status goes through (the fresh store written)' ($st2.Code -eq 0 -and @(Findings $r2)[0].status -eq 'implemented') $st2.First
}

# =============================================================== ORPHAN: a kill inside the commit (D4, F03-11)
if (Want 'ORPHAN') {
    $r = New-Repo 'orphan'
    $bg = Start-Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'x', '-ReplyName', 'o') @{ FAKE_CODEX_REPLY = $adviseF; CODEX_CONSULT_TEST_COMMIT_PAUSE_MS = '30000' }
    $inCommit = Wait-For { @(Findings $r | Where-Object { $_.id -eq 'F01-1' }).Count -eq 1 } 90
    $wlHeld = Test-LockHeld (Join-Path (Td $r) '.consult.write.lock')
    Stop-Process -Id $bg.Proc.Id -Force
    [void]$bg.Proc.WaitForExit(10000)
    $l = Run-Tool $findingsPs $r @('-Task', 't', '-List', '-All')
    $pend = Read-PendingFile -Path (Join-Path (Td $r) '.consult.pending.json')
    Check 'ORPHAN' 'a bridge killed inside its commit (between findings.json and sessions.json): the finding is ORPHAN (-List -All), no ledger entry, the record left in state committing, the write lock released with the process' ($inCommit -and $wlHeld -and @(Ledger $r).Count -eq 0 -and $l.Out -match 'orphans: 1 finding\(s\)' -and $pend.Record.state -eq 'committing' -and -not (Test-LockHeld (Join-Path (Td $r) '.consult.write.lock'))) (Line $l.Out 'codex-findings:')
    $y = Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'next') @{ FAKE_CODEX_REPLY = $advise }
    $e = @(Ledger $r)[-1]
    Check 'ORPHAN' 'the next run recovers the reservation (state committing) and numbers past the orphan: n=2 / 02-codex-next.md' ($y.Code -eq 0 -and $y.Out -match "recovered reservation n=1, nn=01 \(state 'committing' of an interrupted run" -and $e.n -eq 2 -and $e.reply -eq 'handoffs/02-codex-next.md') (Line $y.Out 'codex-consult: recovered')
}

# =============================================================== MEMBERKILL: a panel member killed inside its commit (F11-2, D4)
if (Want 'MEMBERKILL') {
    $r = New-Repo 'memberkill'
    # only member 2 (mimo) pauses inside its commit (a model-keyed test hook); it gets there first
    $bg = Start-Consult $r $roster2 @('-Panel', '-Prompt', 'x', '-ReplyName', 'mk') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_DELAY_MS = 'mimo-v2.6-pro=500|gpt-5.1=6000'; CODEX_CONSULT_TEST_COMMIT_PAUSE_MS = 'mimo-v2.6-pro=60000' }
    $inCommit = Wait-For { @(Findings $r | Where-Object { $_.id -eq 'F02-1' }).Count -eq 1 } 90
    $rec2 = (Read-PendingFile -Path (Join-Path (Td $r) '.consult.pending-02.json')).Record
    $mPid = 0
    if ($rec2) { $mPid = [int]$rec2.pid }
    if ($mPid -gt 0) { Stop-Process -Id $mPid -Force -ErrorAction SilentlyContinue }
    [void]$bg.Proc.WaitForExit(120000)
    $out = Bg-Output $bg
    $sum = @(Summary $out)
    $led = @(Ledger $r)
    $recs = Records $r
    $l = Run-Tool $findingsPs $r @('-Task', 't', '-List', '-All')
    Check 'MEMBERKILL' 'a PANEL MEMBER killed inside its commit (between findings.json and sessions.json): the sibling still commits (n=1 usable), the killed member''s finding stays ORPHAN (F02-1, no ledger entry), its record is kept in state committing naming its kept reply, the summary says "stopped inside its commit", exit 1' ($inCommit -and $rec2 -and $rec2.state -eq 'committing' -and $mPid -ne $bg.Proc.Id -and $bg.Proc.ExitCode -eq 1 -and $led.Count -eq 1 -and $led[0].n -eq 1 -and $led[0].bridge_outcome -eq 'usable reply' -and (@(Findings $r | ForEach-Object { $_.id }) -join ',') -eq 'F01-1,F02-1' -and $l.Out -match 'orphans: 1 finding\(s\)' -and @($recs).Count -eq 1 -and $recs[0].Name -eq '.consult.pending-02.json' -and $recs[0].Record.state -eq 'committing' -and $recs[0].Record.reply_json -eq '.collab/t/handoffs/02-codex-mk-mimo.reply.json' -and $sum[2] -match '^  mimo :: mimo-v2\.6-pro\s+failed: stopped inside its commit') ($sum[0..2] -join ' | ')
    $y = Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'next') @{ FAKE_CODEX_REPLY = $advise }
    $e = @(Ledger $r)[-1]
    Check 'MEMBERKILL' 'the next run recovers the killed member''s record ("recovered reservation n=2, nn=02 (.consult.pending-02.json: state ''committing''...; the reply of that run is kept at ... (its commit did not complete)"), numbers past the orphan (n=3 / 03), the record removed' ($y.Code -eq 0 -and $y.Out -match "recovered reservation n=2, nn=02 \(\.consult\.pending-02\.json: state 'committing' of an interrupted run; .*the reply of that run is kept at \.collab/t/handoffs/02-codex-mk-mimo\.reply\.json \(its commit did not complete\)" -and $e.n -eq 3 -and $e.reply -eq 'handoffs/03-codex-next.md' -and (Records $r).Count -eq 0) (Line $y.Out 'codex-consult: recovered')
}

# =============================================================== GUARD: the parent's kill guard (D11)
if (Want 'GUARD') {
    $r = New-Repo 'guard'
    $p = Consult $r $roster2 @('-Panel', '-Prompt', 'x', '-ReplyName', 'gd', '-TimeoutSec', '300') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""mimo""'; CODEX_CONSULT_TEST_PANEL_GUARD_SEC = '15' }
    $led = @(Ledger $r)
    $recs = Records $r
    $sum = @(Summary $p.Out)
    Check 'GUARD' 'a member still alive past its guard (test: 15 s) is stopped by the panel run: summary "killed by the panel after N s (its guard: 15 s)", its record kept (state running), the other member usable, exit 1' ($p.Code -eq 1 -and $led.Count -eq 1 -and $led[0].bridge_outcome -eq 'usable reply' -and $sum[2] -match '^  mimo :: mimo-v2\.6-pro\s+killed by the panel after [0-9.]+ s \(its guard: 15 s\)' -and @($recs).Count -eq 1 -and $recs[0].Name -eq '.consult.pending-02.json' -and $recs[0].Record.state -eq 'running') ($sum[0..2] -join ' | ')
    $y = Consult $r $roster2 @('-Provider', 'mimo', '-Prompt', 'y', '-ReplyName', 'next') @{ FAKE_CODEX_REPLY = $advise }
    Check 'GUARD' 'the next run recovers the killed member''s reservation (n=2, nn=02; the member and its reviewer are gone)' ($y.Code -eq 0 -and $y.Out -match "recovered reservation n=2, nn=02 \(\.consult\.pending-02\.json: state 'running' of an interrupted run" -and @(Ledger $r)[-1].n -eq 3) (Line $y.Out 'codex-consult: recovered')
}

} finally {
    Restore-Env
    foreach ($id in $cleanup) { try { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } catch { } }
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-panel ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
