# codex-consult wave 30 (0.6.2), the quota windows of TECH_DEBT T15: UNIT - the rollout reader on
# rollouts shaped like codex-cli 0.155's (Get-CodexRolloutPath CODEX_HOME aware, the LAST token_count
# that names a window - the "premium" line after it has null windows -, one call per changed total,
# max_input, context_window, the fork baseline, the sub-agent rollouts and their newer window), the
# views (Format-QuotaWindows: "5h 96% until HH:mm; wk 15% until MMM d", a past reset "5h reset (last
# ...)"), the verdict from a ledger entry's quota (>= 98 % with its reset ahead: unavailable "5-hour
# window 99 % used, resets <iso>"; >= 80 %: "available (...; low quota: ...)"; a past reset: no
# change), a 0.6.1 entry without the keys, the machine-wide record (class '' with quota), the
# telemetry class of a budget stop, the replay guard's thresholds; LEDGER - a codex run's quota,
# tokens, subagents_allowed and budget appended after commit_wait_ms, -c features.multi_agent=false in
# the command; SUBAGENT - the sub-agent rollout summed (count, input, calls) and its newer window;
# NULL - null windows and a missing rollout; MULTI - -CodexConfig features.multi_agent=true wins, not
# refused; FORK - a parent rollout over CODEX_CONSULT_FORK_MAX_KB refused before anything starts (the
# dry run says so), under it warned (console, warnings[], the handoff header), a resume's tokens are
# its own share of the running total; BUDGET - the run stopped at -Budget (the partial kept, no
# continuation, provider_failure class operator, telemetry class quota), the partial's hint -Mode new
# for a thread over the limit, -Budget 0 and CODEX_CONSULT_QUOTA_BUDGET, a refused -Budget, a detached
# run; PROVIDERS - the QUOTA column, the verdicts (unavailable at 99 %, low quota at 84 %, a past
# reset), the roster walk and -Short, the refusal of a real run; MACHINE - the machine-wide record of a
# run without an outcome record read by another repository, the codex home's newest rollout as the
# live source; PROMPT - the reading discipline of acceptance, diff-review, checkpoint and
# core-contract; DOCS; GUARD.
# FAKES ONLY: fake-codex3.cmd (FAKE_CODEX_QUOTA* - tests/fake-rollout.ps1); CODEX_HOME points at
# scratch directories (the fakes write rollouts only there), CODEX_CONSULT_ROSTER at scratch files,
# CODEX_CONSULT_HEALTH is 'none' except in MACHINE (a scratch file), telemetry off and the intake a
# closed loopback port. Runs under the host it is started with (powershell 5.1 or pwsh 7, Windows).
# Work files: $env:TEMP\codex-consult-tests\harness-quota\<guid>, removed at the end.
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
$env:CODEX_CONSULT_HEALTH = 'none'
$env:CODEX_CONSULT_TELEMETRY = 'off'
$env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
$env:CODEX_CONSULT_TEST_MODE = '1'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
$commonPs = Join-Path $scripts 'codex-consult-common.ps1'
. $commonPs
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$providersPs = Join-Path $scripts 'codex-providers.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-quota') ([guid]::NewGuid().ToString('N'))
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
    if ($ev.Length -gt 600) { $ev = $ev.Substring(0, 600) + '...' }
    Write-Host ("{0} {1,-9} {2}{3}" -f $mark, $Id, $What, $(if ($ev) { "  | $ev" } else { '' }))
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
function New-Home {
    param([string]$Name)
    $h = Join-Path $work "home-$Name"
    [void][IO.Directory]::CreateDirectory($h)
    [IO.File]::WriteAllText((Join-Path $h 'config.toml'), $toml, $u8)
    return $h
}
$codexHome = New-Home 'main'
$savedCodexHome = $codexHome
$env:CODEX_HOME = $codexHome
function Write-Roster { param([string]$Name, [string]$Json) $p = Join-Path $work "roster-$Name.json"; [IO.File]::WriteAllText($p, $Json, $u8); return $p }
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ITEMS', 'FAKE_CODEX_TOOL_OPEN', 'FAKE_CODEX_RESUME_REPLY', 'FAKE_CODEX_QUOTA', 'FAKE_CODEX_QUOTA_PRIMARY', 'FAKE_CODEX_QUOTA_RESET_MIN', 'FAKE_CODEX_QUOTA_SECONDARY', 'FAKE_CODEX_QUOTA_NULL', 'FAKE_CODEX_QUOTA_CALLS', 'FAKE_CODEX_QUOTA_PAD_KB', 'FAKE_CODEX_QUOTA_SUBAGENT', 'FAKE_CODEX_QUOTA_SUBAGENT_PRIMARY', 'FAKE_CODEX_QUOTA_LOG')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CODEX_CONSULT_QUOTA_BUDGET', 'CODEX_CONSULT_FORK_MAX_KB', 'CODEX_CONSULT_TEST_BUDGET_POLL_MS', 'CODEX_CONSULT_TEST_WAIT_TICK_MS', 'CODEX_CONSULT_EXE')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    foreach ($k in (Get-HostMarkerNames)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $env:CODEX_CONSULT_HEALTH = 'none'
    $env:CODEX_CONSULT_TEST_MODE = '1'
    $env:CODEX_CONSULT_TELEMETRY = 'off'
    $env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
}
# (NB: never a parameter named $CodexHome here - PowerShell names are case-insensitive, it would hide the
# scratch $codexHome and the case would run without a CODEX_HOME)
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env, [string]$CaseHome = '')
    Clear-TestEnv
    $env:CODEX_HOME = $(if ($CaseHome) { $CaseHome } else { $codexHome })
    if (-not $env:CODEX_HOME) { throw 'harness-quota: no scratch CODEX_HOME for the case' }
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:CODEX_CONSULT_EXE = $fake
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env { Clear-TestEnv; $env:CODEX_HOME = $savedCodexHome }
# One bridge call (synchronous): { Code; Out; Sec }
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{}, [string]$CaseHome = '', [switch]$NoCodexExe)
    Set-CaseEnv $Roster $Env $CaseHome
    Push-Location $Repo
    $all = @()
    if (-not $NoCodexExe) { $all += @('-CodexExe', $fake) }
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task 't' @all @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return [pscustomobject]@{ Code = $code; Out = (($out | ForEach-Object { "$_" }) -join "`n"); Sec = [math]::Round($sw.Elapsed.TotalSeconds, 1) }
}
# codex-providers.ps1 in $Repo: { Code; Out }
function Providers {
    param([string]$Repo, [string[]]$ArgList = @(), [string]$Roster = '', [hashtable]$Env = @{}, [string]$CaseHome = '')
    Set-CaseEnv $Roster $Env $CaseHome
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $providersPs @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return [pscustomobject]@{ Code = $code; Out = (($out | ForEach-Object { "$_" }) -join "`n") }
}
function Get-Entries { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @((Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json).codex.consults) }
function Last-Entry { param([string]$Repo) return (@(Get-Entries $Repo) | Select-Object -Last 1) }
function J { param($V) return (ConvertTo-Json -Compress -Depth 6 -InputObject $V) }
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Join-Path $work 'advise.json'
[IO.File]::WriteAllText($advise, $adviseJson, $u8)
$acceptJson = '{"schema_version":"1","verdict":"ACCEPT","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$accept = Join-Path $work 'accept.json'
[IO.File]::WriteAllText($accept, $acceptJson, $u8)
# A rollout written here (unit cases): lines as the real CLI writes them
function Stamp { param([DateTimeOffset]$At) return $At.UtcDateTime.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture) }
function Win { param([double]$Used, [DateTimeOffset]$Reset, [int]$Minutes = 300) return '{"used_percent":' + $Used.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + ',"window_minutes":' + $Minutes + ',"resets_at":' + $Reset.ToUnixTimeSeconds() + '}' }
function TokenLine {
    param([DateTimeOffset]$At, [long]$In, [long]$Cached, [long]$Out, [long]$Last, [string]$Primary, [string]$Secondary, [string]$LimitId = 'codex')
    return '{"timestamp":"' + (Stamp $At) + '","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":' + $In + ',"cached_input_tokens":' + $Cached + ',"cache_write_input_tokens":0,"output_tokens":' + $Out + ',"reasoning_output_tokens":0,"total_tokens":' + ($In + $Out) + '},"last_token_usage":{"input_tokens":' + $Last + ',"cached_input_tokens":0,"cache_write_input_tokens":0,"output_tokens":5,"reasoning_output_tokens":0,"total_tokens":' + $Last + '},"model_context_window":258400},"rate_limits":{"limit_id":"' + $LimitId + '","limit_name":null,"primary":' + $Primary + ',"secondary":' + $Secondary + ',"credits":null,"plan_type":"plus"}}}'
}
function MetaLine { param([DateTimeOffset]$At, [string]$Id, [string]$Parent = '') $src = $(if ($Parent) { '{"subagent":{"thread_spawn":{"parent_thread_id":"' + $Parent + '","depth":1}}}' } else { '"exec"' }); return '{"timestamp":"' + (Stamp $At) + '","type":"session_meta","payload":{"id":"' + $Id + '","source":' + $src + ',"model_provider":"openai"}}' }
function Write-Rollout {
    param([string]$CodexHome, [string]$Id, [string[]]$Lines, [DateTimeOffset]$At = [DateTimeOffset]::Now)
    $d = Join-Path (Join-Path (Join-Path (Join-Path $CodexHome 'sessions') $At.ToString('yyyy')) $At.ToString('MM')) $At.ToString('dd')
    [void][IO.Directory]::CreateDirectory($d)
    $p = Join-Path $d "rollout-$($At.ToString('yyyy-MM-ddTHH-mm-ss'))-$Id.jsonl"
    [IO.File]::WriteAllText($p, (($Lines -join "`n") + "`n"), $u8)
    return $p
}
function V7 { param([DateTimeOffset]$At = [DateTimeOffset]::UtcNow) $ms = '{0:x12}' -f $At.ToUnixTimeMilliseconds(); $r = [guid]::NewGuid().ToString('N'); return "$($ms.Substring(0, 8))-$($ms.Substring(8, 4))-7$($r.Substring(0, 3))-8$($r.Substring(3, 3))-$($r.Substring(6, 12))" }
$inv = [Globalization.CultureInfo]::InvariantCulture
$sleepers = New-Object System.Collections.Generic.List[object]

try {

# =============================================================== UNIT: the rollout reader and the views
if (Want 'UNIT') {
    $uh = New-Home 'unit'
    $now = [DateTimeOffset]::Now
    $reset5 = $now.AddMinutes(150)
    $resetWk = $now.AddDays(5)
    $parent = V7 $now.AddHours(-2)
    $pLines = @((MetaLine $now.AddHours(-2) $parent), (TokenLine $now.AddHours(-2) 100000 80000 500 50000 'null' 'null'), (TokenLine $now.AddHours(-2).AddSeconds(1) 100000 80000 500 50000 'null' 'null' 'premium'), (TokenLine $now.AddHours(-1) 200000 160000 900 100000 (Win 20 $reset5) (Win 10 $resetWk 10080)))
    $pPath = Write-Rollout $uh $parent $pLines $now.AddHours(-2)
    $fork = V7 $now.AddMinutes(-5)
    $start = $now.AddMinutes(-5)
    $fLines = @((MetaLine $start $fork), (TokenLine $start.AddSeconds(5) 260000 200000 950 60000 (Win 90 $reset5) (Win 12 $resetWk 10080)), (TokenLine $start.AddSeconds(5) 260000 200000 950 60000 'null' 'null' 'premium'), (TokenLine $start.AddSeconds(9) 330000 260000 990 70000 (Win 96 $reset5) (Win 15 $resetWk 10080)), (TokenLine $start.AddSeconds(9) 330000 260000 990 70000 'null' 'null' 'premium'))
    $fPath = Write-Rollout $uh $fork $fLines $start
    $sub = V7 $start.AddSeconds(6)
    $sLines = @((MetaLine $start.AddSeconds(6) $sub $fork), (TokenLine $start.AddSeconds(7) 30000 10000 50 30000 (Win 97 $reset5) (Win 15 $resetWk 10080)), (TokenLine $start.AddSeconds(11) 70000 40000 90 40000 (Win 99 $reset5) (Win 16 $resetWk 10080)))
    $null = Write-Rollout $uh $sub $sLines $start.AddSeconds(6)
    $env:CODEX_HOME = $uh
    $found = Get-CodexRolloutPath -ThreadId $fork
    $v4 = [guid]::NewGuid().ToString()
    $v4Path = Write-Rollout $uh $v4 @((MetaLine $now $v4)) $now.AddDays(-20)
    $foundV4 = Get-CodexRolloutPath -ThreadId $v4
    Check 'UNIT' 'Get-CodexRolloutPath: CODEX_HOME aware - a UUIDv7 thread found in its own day, a v4 thread found by the whole-tree search, an unknown thread ''''' ($found -eq $fPath -and $foundV4 -eq $v4Path -and (Get-CodexRolloutPath -ThreadId ([guid]::NewGuid().ToString())) -eq '') "$found | $foundV4"
    $u = Get-RolloutUsage -Path $fPath -Before $start
    Check 'UNIT' 'Get-RolloutUsage: the LAST line that names a window (96 %, not the premium line after it), the last total, 2 calls (the premium duplicates are no calls), max_input 70000, context_window 258400' ($u.Window.Primary.used_percent -eq 96 -and $u.Window.Secondary.used_percent -eq 15 -and $u.Window.Primary.window_minutes -eq 300 -and $u.Total.input -eq 330000 -and $u.Calls -eq 2 -and $u.MaxInput -eq 70000 -and $u.ContextWindow -eq 258400) "$(J $u.Window.Primary) calls=$($u.Calls) max=$($u.MaxInput)"
    Check 'UNIT' 'a window''s resets_at is ISO with the LOCAL offset (unix seconds converted)' ([string]$u.Window.Primary.resets_at -eq (Format-OffsetIso $reset5.ToLocalTime().AddTicks(-($reset5.Ticks % 10000000)))) ([string]$u.Window.Primary.resets_at)
    $q = Get-CodexRunQuota -ThreadId $fork -StartedAt $start.LocalDateTime -BaselineThreadId $parent
    Check 'UNIT' 'Get-CodexRunQuota of a fork: tokens = the run''s share (330000 - the parent''s 200000 = 130000 input, 100000 cached, 90 output), thread_input 330000 (the running total), calls 2, max_input 70000, context_window 258400' ($q.Tokens.input -eq 130000 -and $q.Tokens.cached -eq 100000 -and $q.Tokens.output -eq 90 -and $q.Tokens.thread_input -eq 330000 -and $q.Tokens.calls -eq 2 -and $q.Tokens.max_input -eq 70000 -and $q.Tokens.context_window -eq 258400) (J $q.Tokens)
    Check 'UNIT' 'the sub-agent rollout of the thread (session_meta parent_thread_id) is summed: subagents {count 1, input 70000, calls 2}; the quota is the NEWEST window - the sub-agent''s 99 % observed after the thread''s 96 %' ($q.Tokens.subagents.count -eq 1 -and $q.Tokens.subagents.input -eq 70000 -and $q.Tokens.subagents.calls -eq 2 -and $q.Quota.primary.used_percent -eq 99 -and $q.Quota.observed_at) "$(J $q.Tokens.subagents) $(J $q.Quota)"
    $qn = Get-CodexRunQuota -ThreadId $parent -StartedAt $now.AddHours(-3).LocalDateTime
    $qx = Get-CodexRunQuota -ThreadId ([guid]::NewGuid().ToString()) -StartedAt $now.LocalDateTime
    Check 'UNIT' 'a new thread: no baseline (tokens = the total); a thread without a rollout: quota {primary null, secondary null, observed_at null}, tokens null' ($qn.Tokens.input -eq 200000 -and $null -eq $qx.Tokens -and $null -eq $qx.Quota.primary -and $null -eq $qx.Quota.secondary -and ((@($qx.Quota.PSObject.Properties.Name) -join ',') -eq 'primary,secondary,observed_at')) "$(J $qn.Tokens) | $(J $qx)"
    $nullP = Write-Rollout $uh (V7) @((MetaLine $now 'x'), (TokenLine $now 10 0 1 10 'null' 'null'))
    $un = Get-RolloutUsage -Path $nullP
    Check 'UNIT' 'a rollout whose rate_limits name no window (2026-10-09 shape): Window with null Primary and Secondary' ($un.Window -and $null -eq $un.Window.Primary -and $null -eq $un.Window.Secondary) (J $un.Window)
    $env:CODEX_HOME = $savedCodexHome
    # the views at a fixed clock
    $clock = [datetime]'2026-10-13T12:00:00Z'
    $qv = [pscustomobject]@{ primary = [pscustomobject]@{ used_percent = 96.0; window_minutes = 300; resets_at = '2026-10-13T16:32:16+00:00' }; secondary = [pscustomobject]@{ used_percent = 15.0; window_minutes = 10080; resets_at = '2026-10-20T11:32:16+00:00' }; observed_at = '2026-10-13T11:35:49+00:00' }
    $lt = ([DateTimeOffset]'2026-10-13T16:32:16+00:00').ToLocalTime().ToString('HH:mm', $inv)
    $ld = ([DateTimeOffset]'2026-10-20T11:32:16+00:00').ToLocalTime().ToString('MMM d', $inv)
    $txt = Format-QuotaWindows -Quota $qv -UtcNow $clock
    Check 'UNIT' "Format-QuotaWindows: '5h 96% until $lt; wk 15% until $ld' (local times; a date beyond 24 h)" ($txt -eq "5h 96% until $lt; wk 15% until $ld") $txt
    $txtPast = Format-QuotaWindows -Quota $qv -UtcNow ([datetime]'2026-10-13T17:00:00Z')
    Check 'UNIT' "a reset in the past: '5h reset (last 96% until $lt)'" ($txtPast -like "5h reset (last 96% until $lt); wk 15% until *") $txtPast
    # the verdict from a ledger entry's quota
    $fpB = $script:BuiltinOpenAiFingerprint
    $mk = { param([double]$Used, [string]$Reset) [pscustomobject]@{ n = 1; when = '2026-10-13T11:30:00+00:00'; finished_at = '2026-10-13T11:36:00+00:00'; bridge_outcome = 'usable reply'; reviewer = [pscustomobject]@{ provider = 'openai'; provider_fingerprint = $fpB }; provider_failure = $null; quota = [pscustomobject]@{ primary = [pscustomobject]@{ used_percent = $Used; window_minutes = 300; resets_at = $Reset }; secondary = [pscustomobject]@{ used_percent = 15.0; window_minutes = 10080; resets_at = '2026-10-20T11:32:16+00:00' }; observed_at = '2026-10-13T11:35:49+00:00' } } }
    $id = [pscustomobject]@{ Provider = 'openai'; Model = 'gpt-5.1'; Engine = 'codex'; Resolved = $true; Error = ''; Note = ''; Fingerprint = $fpB }
    $login = @{}
    $h99 = Get-EndpointHealth -Consults @((& $mk 99.0 '2026-10-13T16:32:16+00:00')) -Fingerprint $fpB -UtcNow $clock -NoMachine
    Check 'UNIT' 'Get-EndpointHealth: a window at 99 % with its reset ahead -> Quota {class quota, FailureKind window, known reset = resets_at}, WindowText' ($h99.Quota -and $h99.QuotaKnown -and $h99.Quota.FailureKind -eq 'window' -and $h99.Quota.Until.UtcDateTime -eq ([DateTimeOffset]'2026-10-13T16:32:16+00:00').UtcDateTime -and $h99.WindowText -like '5h 99% until *') "$($h99.Quota.Message) until $($h99.Quota.RetryAfterIso); $($h99.WindowText)"
    $cfg = [pscustomobject]@{ Exists = $false; Ok = $true }
    $v99 = Get-PreflightVerdict -Identity $id -Config $cfg -Launcher $fake -Health $h99 -LoginCache $login -RosterWalk
    Check 'UNIT' 'the verdict: unavailable (5-hour window 99 % used, resets <iso>), Kind quota (the roster walk, -Require and -Short treat it as a usage limit with its reset)' ($v99.State -eq 'unavailable' -and $v99.Kind -eq 'quota' -and $v99.Reason -eq "5-hour window 99 % used, resets $($h99.Quota.RetryAfterIso)" -and $v99.Until -eq $h99.Quota.RetryAfter) $v99.Label
    $h84 = Get-EndpointHealth -Consults @((& $mk 84.0 '2026-10-13T16:32:16+00:00')) -Fingerprint $fpB -UtcNow $clock -NoMachine
    $v84 = Get-PreflightVerdict -Identity $id -Config $cfg -Launcher $fake -Health $h84 -LoginCache $login -RosterWalk
    Check 'UNIT' 'a window at 84 %: available, the verdict text says "low quota: 5-hour window 84 % until <local>"' (-not $h84.Quota -and $v84.State -eq 'available' -and $v84.QuotaWarning -eq "low quota: 5-hour window 84 % until $lt" -and $v84.Label -like "available (*; low quota: 5-hour window 84 % until $lt)") $v84.Label
    $hPast = Get-EndpointHealth -Consults @((& $mk 99.0 '2026-10-13T11:00:00+00:00')) -Fingerprint $fpB -UtcNow $clock -NoMachine
    $vPast = Get-PreflightVerdict -Identity $id -Config $cfg -Launcher $fake -Health $hPast -LoginCache $login -RosterWalk
    Check 'UNIT' 'a 99 % window whose reset lies in the past: no verdict change (available, no warning), shown "5h reset (last 99% until ...)"' (-not $hPast.Quota -and $vPast.State -eq 'available' -and -not $vPast.QuotaWarning -and $hPast.WindowText -like '5h reset (last 99% until *') "$($vPast.Label); $($hPast.WindowText)"
    $old = [pscustomobject]@{ n = 1; when = '2026-10-13T11:30:00+00:00'; bridge_outcome = 'usable reply'; reviewer = [pscustomobject]@{ provider = 'openai'; provider_fingerprint = $fpB }; provider_failure = $null }
    $hOld = Get-EndpointHealth -Consults @($old) -Fingerprint $fpB -UtcNow $clock -NoMachine
    Check 'UNIT' 'a 0.6.1 entry without quota/tokens keys stays valid: no Window, no Quota, the verdict available' (-not $hOld.Window -and -not $hOld.Quota -and (Get-PreflightVerdict -Identity $id -Config $cfg -Launcher $fake -Health $hOld -LoginCache $login -RosterWalk).State -eq 'available') ''
    $newer = [pscustomobject]@{ n = 2; when = '2026-10-13T11:40:00+00:00'; finished_at = '2026-10-13T11:41:00+00:00'; bridge_outcome = 'usable reply'; reviewer = [pscustomobject]@{ provider = 'openai'; provider_fingerprint = $fpB }; provider_failure = $null; quota = [pscustomobject]@{ primary = [pscustomobject]@{ used_percent = 30.0; window_minutes = 300; resets_at = '2026-10-13T16:40:00+00:00' }; secondary = $null; observed_at = '2026-10-13T11:41:00+00:00' } }
    $hNew = Get-EndpointHealth -Consults @((& $mk 99.0 '2026-10-13T16:32:16+00:00'), $newer) -Fingerprint $fpB -UtcNow $clock -NoMachine
    Check 'UNIT' 'the NEWEST observation decides: a later entry at 30 % lifts the 99 % one' (-not $hNew.Quota -and $hNew.WindowText -like '5h 30% until *') $hNew.WindowText
    # the machine-wide record
    $qrec = [pscustomobject]@{ primary = [pscustomobject]@{ used_percent = 99.0; window_minutes = 300; resets_at = (Format-OffsetIso ([DateTimeOffset]::Now.AddHours(2))) }; secondary = $null; observed_at = (Format-OffsetIso ([DateTimeOffset]::Now)) }
    $mrT = New-MachineHealthRecord -Fingerprint $fpB -Outcome 'failed: timeout after 60 s (process tree killed)' -Failure $null -Repo 'r' -Quota $qrec
    $mrOk = New-MachineHealthRecord -Fingerprint $fpB -Outcome 'usable reply' -Repo 'r' -Quota $qrec
    $mrOp = New-MachineHealthRecord -Fingerprint $fpB -Outcome 'failed: stopped at the quota budget: x' -Failure ([pscustomobject]@{ class = 'operator'; kind = ''; message = 'x' }) -Repo 'r' -Quota $qrec
    $mrNone = New-MachineHealthRecord -Fingerprint $fpB -Outcome 'failed: timeout after 60 s' -Failure $null -Repo 'r' -Quota ([pscustomobject]@{ primary = $null; secondary = $null; observed_at = $null })
    Check 'UNIT' 'New-MachineHealthRecord -Quota: a run without an outcome record (a timeout, an operator/budget stop) writes class '''' carrying quota; a usable one carries quota on its ok record; null windows add nothing' ($mrT -and $mrT.class -eq '' -and $mrT.quota.primary.used_percent -eq 99 -and $mrOk.class -eq 'ok' -and $mrOk.quota -and $mrOp.class -eq '' -and $mrOp.quota -and $null -eq $mrNone) "$(J $mrT) | ok=$($mrOk.class)"
    $budgetEntry = [pscustomobject]@{ bridge_outcome = 'failed: stopped at the quota budget: 5-hour window 91 % used, resets 18:32; the partial is kept'; provider_failure = [pscustomobject]@{ class = 'operator' } }
    $to = Get-TelemetryOutcome $budgetEntry
    Check 'UNIT' 'telemetry: a budget stop is the EXISTING class quota (failed:quota, warning) - no new class in the event contract' ($to.Outcome -eq 'failed:quota' -and $to.Class -eq 'quota' -and $to.Severity -eq 'warning' -and $script:TelemetryFailureClasses -notcontains 'budget') "$($to.Outcome) $($to.Severity)"
    # the replay guard
    $env:CODEX_HOME = $uh
    $big = V7
    $null = Write-Rollout $uh $big @((MetaLine $now $big), ('{"pad":"' + ('x' * (600 * 1024)) + '"}'))
    $mid = V7
    $null = Write-Rollout $uh $mid @((MetaLine $now $mid), ('{"pad":"' + ('x' * (200 * 1024)) + '"}'))
    Remove-Item env:CODEX_CONSULT_FORK_MAX_KB -ErrorAction SilentlyContinue
    $gBig = Get-ForkReplayGuard -ThreadId $big
    $gMid = Get-ForkReplayGuard -ThreadId $mid
    $gSmall = Get-ForkReplayGuard -ThreadId $parent
    $env:CODEX_CONSULT_FORK_MAX_KB = '1024'
    $gRaised = Get-ForkReplayGuard -ThreadId $big
    $env:CODEX_CONSULT_FORK_MAX_KB = 'lots'
    $gBad = Get-ForkReplayGuard -ThreadId $big
    Remove-Item env:CODEX_CONSULT_FORK_MAX_KB -ErrorAction SilentlyContinue
    $env:CODEX_HOME = $savedCodexHome
    Check 'UNIT' 'Get-ForkReplayGuard: 600 KB over the default 512 -> the refusal text; 200 KB -> a warning; a small rollout -> nothing; CODEX_CONSULT_FORK_MAX_KB=1024 -> a warning; a malformed value -> the default and a Problem' ($gBig.OverLimit -and $gBig.Refusal -eq "the parent thread $big replays 600 KB (~150 k tokens) on EVERY tool call of the run: use -Mode new, or raise CODEX_CONSULT_FORK_MAX_KB (now 512)" -and -not $gMid.Refusal -and $gMid.Warning -like "the parent thread $mid replays 200 KB (~50 k tokens) on EVERY tool call of the run (CODEX_CONSULT_FORK_MAX_KB 512)*" -and -not $gSmall.Refusal -and -not $gSmall.Warning -and -not $gRaised.Refusal -and $gRaised.Warning -and $gBad.Refusal -and $gBad.Problem) "$($gBig.Refusal) | $($gMid.Warning) | $($gBad.Problem)"
}

# =============================================================== LEDGER: a codex run's quota, tokens, sub-agents, budget
if (Want 'LEDGER') {
    $r = New-Repo 'ledger'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'one') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '42' }
    $e = Last-Entry $r
    $names = @($e.PSObject.Properties | ForEach-Object { $_.Name })
    Check 'LEDGER' 'a usable codex run: the four new keys are the LAST ones, after commit_wait_ms (quota, tokens, subagents_allowed, budget) - every key before keeps its place' ($x.Code -eq 0 -and (($names | Select-Object -Last 5) -join ',') -eq 'commit_wait_ms,quota,tokens,subagents_allowed,budget') (($names | Select-Object -Last 6) -join ',')
    $p = $e.quota.primary
    Check 'LEDGER' 'quota: primary {used_percent 42, window_minutes 300, resets_at ISO with an offset}, secondary {15, 10080}, observed_at' ($p.used_percent -eq 42 -and $p.window_minutes -eq 300 -and [string]$p.resets_at -match '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$' -and $e.quota.secondary.used_percent -eq 15 -and $e.quota.secondary.window_minutes -eq 10080 -and $e.quota.observed_at) (J $e.quota)
    Check 'LEDGER' 'tokens: input 6000, cached 3000, output 30, thread_input 6000, calls 3, max_input 3000, context_window 258400, subagents {0, 0, 0}' ($e.tokens.input -eq 6000 -and $e.tokens.cached -eq 3000 -and $e.tokens.output -eq 30 -and $e.tokens.thread_input -eq 6000 -and $e.tokens.calls -eq 3 -and $e.tokens.max_input -eq 3000 -and $e.tokens.context_window -eq 258400 -and $e.tokens.subagents.count -eq 0 -and $e.tokens.subagents.input -eq 0) (J $e.tokens)
    Check 'LEDGER' 'subagents_allowed false and `-c features.multi_agent=false` in the command; budget {percent 90, source default, stopped false}' ($e.subagents_allowed -eq $false -and $e.command -match ' -c features\.multi_agent=false ' -and $e.budget.percent -eq 90 -and $e.budget.source -eq 'default' -and $e.budget.stopped -eq $false) "$($e.subagents_allowed) $(J $e.budget)"
    $hdr = [IO.File]::ReadAllText((Join-Path $r '.collab\t\handoffs\01-codex-one.md'))
    Check 'LEDGER' 'the summary and the handoff header carry the windows and the run''s tokens' ($x.Out -match '(?m)^quota      : 5h 42% until \d\d:\d\d; wk 15% until \w{3} \d+; this run 6000 input tokens \(3000 cached\) in 3 calls, max 3000 per call of 258400; sub-agents 0$' -and $hdr -match 'Quota \(rollout\): 5h 42% until .*sub-agents off \(features\.multi_agent=false\); budget 90 % of the 5-hour window\.') (@(($x.Out -split "`n") | Where-Object { $_ -match '^quota' }) -join '')
}

# =============================================================== SUBAGENT / NULL / MULTI
if (Want 'SUBAGENT') {
    $r = New-Repo 'sub'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'sub') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '40'; FAKE_CODEX_QUOTA_SUBAGENT = '1'; FAKE_CODEX_QUOTA_SUBAGENT_PRIMARY = '55' }
    $e = Last-Entry $r
    Check 'SUBAGENT' 'a sub-agent rollout of the run''s thread: tokens.subagents {count 1, input 4000, calls 2}; the quota is its newer window (55 %, observed after the thread''s 40 %)' ($x.Code -eq 0 -and $e.tokens.subagents.count -eq 1 -and $e.tokens.subagents.input -eq 4000 -and $e.tokens.subagents.calls -eq 2 -and $e.tokens.input -eq 6000 -and $e.quota.primary.used_percent -eq 55) "$(J $e.tokens.subagents) $($e.quota.primary.used_percent)"
}
if (Want 'NULL') {
    $r = New-Repo 'null'
    $x1 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'n1') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_NULL = '1' }
    $e1 = Last-Entry $r
    $x2 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'n2', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise }
    $e2 = Last-Entry $r
    Check 'NULL' 'a rollout whose windows are null: quota {primary null, secondary null}, tokens recorded; no rollout at all: quota with null members, tokens null - both usable' ($x1.Code -eq 0 -and $x2.Code -eq 0 -and $null -eq $e1.quota.primary -and $null -eq $e1.quota.secondary -and $e1.tokens.input -eq 6000 -and $null -eq $e2.quota.primary -and $null -eq $e2.quota.secondary -and $null -eq $e2.quota.observed_at -and $null -eq $e2.tokens -and @($e2.PSObject.Properties.Name) -contains 'tokens') "$(J $e1.quota) | $(J $e2.quota) $(J $e2.tokens)"
    $x3 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'n3', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1' }
    Check 'NULL' 'the ledger with entries without the new keys and with them reads and appends (n 1..3)' ($x3.Code -eq 0 -and @(Get-Entries $r).Count -eq 3) "$(@(Get-Entries $r).Count)"
}
if (Want 'MULTI') {
    $r = New-Repo 'multi'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'm1', '-CodexConfig', 'features.multi_agent=true') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1' }
    $e = Last-Entry $r
    Check 'MULTI' '-CodexConfig features.multi_agent=true: not refused, theirs wins (=true in the command, no =false), subagents_allowed true, extra_config keeps it' ($x.Code -eq 0 -and $e.command -match 'features\.multi_agent=true' -and $e.command -notmatch 'features\.multi_agent=false' -and $e.subagents_allowed -eq $true -and @($e.extra_config) -contains 'features.multi_agent=true') "$($x.Code) $($e.subagents_allowed)"
    $d = Consult $r '' @('-Prompt', 'x', '-DryRun', '-ReplyName', 'm2')
    Check 'MULTI' 'the dry run prints the override: the command with -c features.multi_agent=false and "sub-agents  : off - -c features.multi_agent=false"' ($d.Code -eq 0 -and $d.Out -match 'command .*-c features\.multi_agent=false' -and $d.Out -match '(?m)^sub-agents  : off - -c features\.multi_agent=false') (@(($d.Out -split "`n") | Where-Object { $_ -match '^(sub-agents|budget|quota)' }) -join ' | ')
}

# =============================================================== FORK: the replay guard
if (Want 'FORK') {
    $r = New-Repo 'fork'
    $fh = New-Home 'fork'
    $x1 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'big', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PAD_KB = '600' } -CaseHome $fh
    $e1 = Last-Entry $r
    $n1 = @(Get-Entries $r).Count
    $x2 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'fk', '-Mode', 'fork') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1' } -CaseHome $fh
    Check 'FORK' 'a fork whose parent rollout is over CODEX_CONSULT_FORK_MAX_KB (default 512) is refused before anything starts: exit 1, the refusal names the thread, its KB and ~tokens, -Mode new; no ledger entry' ($x1.Code -eq 0 -and $x2.Code -eq 1 -and $x2.Out -match "the parent thread $($e1.thread) replays 6\d\d KB \(~1\d\d k tokens\) on EVERY tool call of the run: use -Mode new, or raise CODEX_CONSULT_FORK_MAX_KB \(now 512\); nothing was started" -and @(Get-Entries $r).Count -eq $n1) (@(($x2.Out -split "`n") | Where-Object { $_ -match 'replays' }) -join '')
    $d2 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'fk', '-Mode', 'fork', '-DryRun') @{} -CaseHome $fh
    Check 'FORK' 'the dry run never refuses: it warns "a real run is refused: the parent thread ... replays ..." and prints the replay line' ($d2.Code -eq 0 -and $d2.Out -match 'WARNING: a real run is refused: the parent thread .* replays 6\d\d KB' -and $d2.Out -match '(?m)^replay      : the parent thread''s rollout is 6\d\d KB \(CODEX_CONSULT_FORK_MAX_KB 512\) - a real run is refused') (@(($d2.Out -split "`n") | Where-Object { $_ -match 'replay' }) -join ' | ')
    $x3 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'fk2', '-Mode', 'fork') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; CODEX_CONSULT_FORK_MAX_KB = '2048' } -CaseHome $fh
    $e3 = Last-Entry $r
    $hdr3 = [IO.File]::ReadAllText((Join-Path $r ".collab\t\handoffs\$('{0:D2}' -f [int]$e3.n)-codex-fk2.md"))
    Check 'FORK' 'raised to 2048: the fork runs and is WARNED (console, warnings[], the handoff header) - 128 KB up to the limit' ($x3.Code -eq 0 -and $x3.Out -match 'WARNING: the parent thread .* replays 6\d\d KB .*CODEX_CONSULT_FORK_MAX_KB 2048' -and @($e3.warnings | Where-Object { $_ -match 'replays 6\d\d KB' }).Count -eq 1 -and $hdr3 -match 'Warnings: .*replays 6\d\d KB') (@($e3.warnings) -join ' | ')
    Check 'FORK' 'the fork''s tokens are its own share: the parent''s running total is inherited (thread_input 12000) and subtracted (input 6000)' ($e3.tokens.input -eq 6000 -and $e3.tokens.thread_input -eq 12000 -and $e3.parent_thread -eq $e1.thread) (J $e3.tokens)
    # a resume of a small thread continues its running total
    $rs = New-Repo 'resume'
    $rh = New-Home 'resume'
    $y1 = Consult $rs '' @('-Prompt', 'x', '-ReplyName', 'r1', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PAD_KB = '200' } -CaseHome $rh
    $ry1 = Last-Entry $rs
    $y2 = Consult $rs '' @('-Prompt', 'x', '-ReplyName', 'r2', '-Mode', 'resume') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1' } -CaseHome $rh
    $ry2 = Last-Entry $rs
    Check 'FORK' 'a resume of a 200 KB thread: warned (not refused); its tokens are this run''s share of the SAME rollout''s total (input 6000, thread_input 12000)' ($y1.Code -eq 0 -and $y2.Code -eq 0 -and $ry2.thread -eq $ry1.thread -and $ry2.tokens.input -eq 6000 -and $ry2.tokens.thread_input -eq 12000 -and $ry2.tokens.calls -eq 3 -and @($ry2.warnings | Where-Object { $_ -match 'replays 2\d\d KB' }).Count -eq 1) "$(J $ry2.tokens) | $(@($ry2.warnings) -join ' | ')"
}

# =============================================================== BUDGET: the stop at -Budget
if (Want 'BUDGET') {
    $r = New-Repo 'budget'
    $bh = New-Home 'budget'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'b1', '-TimeoutSec', '120', '-Budget', '90') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '95'; FAKE_CODEX_ITEMS = '1'; FAKE_CODEX_TOOL_OPEN = '60'; CODEX_CONSULT_TEST_BUDGET_POLL_MS = '500' } -CaseHome $bh
    $e = Last-Entry $r
    Check 'BUDGET' 'a 5-hour window at 95 % during the run, -Budget 90: the main turn is stopped (exit 1, long before its 60 s), "failed: stopped at the quota budget: 5-hour window 95 % used, resets HH:mm; the partial is kept"' ($x.Code -eq 1 -and $x.Sec -lt 45 -and [string]$e.bridge_outcome -match '^failed: stopped at the quota budget: 5-hour window 95 % used, resets \d\d:\d\d; the partial is kept$') "$($x.Sec) s: $($e.bridge_outcome)"
    $partial = $(if ($e.partial_reply) { Join-Path $r ".collab\t\$($e.partial_reply)" } else { '' })
    Check 'BUDGET' 'the partial is kept (partial_reply, the salvaged agent message), no timeout continuation, budget {percent 90, source -Budget, stopped true, used_percent 95, resets_at}' ($partial -and (Test-Path -LiteralPath $partial) -and ([IO.File]::ReadAllText($partial)) -match 'Q1 so far' -and $null -eq $e.timeout_continue -and $e.budget.stopped -eq $true -and $e.budget.percent -eq 90 -and $e.budget.source -eq '-Budget' -and $e.budget.used_percent -eq 95 -and $e.budget.resets_at) "$($e.partial_reply) $(J $e.budget) tc=$(J $e.timeout_continue)"
    Check 'BUDGET' 'provider_failure class operator (the endpoint is not marked out at the budget), its hint says budget; the telemetry outcome is the existing class quota' ($e.provider_failure.class -eq 'operator' -and [string]$e.provider_failure.hint -match 'quota budget' -and (Get-TelemetryOutcome $e).Outcome -eq 'failed:quota') "$(J $e.provider_failure) -> $((Get-TelemetryOutcome $e).Outcome)"
    Check 'BUDGET' 'the partial''s footer continues the (small) thread: -Mode resume -Thread <id> ... -Budget 90' ([string]$x.Out -match "continue with ``-Task t -Mode resume -Thread $($e.thread) .*-Budget 90 -Prompt ""finish your review""``") (@(($x.Out -split "`n") | Where-Object { $_ -match '^partial' }) -join '')
    $x2 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'b2', '-TimeoutSec', '120', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '95'; FAKE_CODEX_QUOTA_PAD_KB = '600'; FAKE_CODEX_ITEMS = '1'; FAKE_CODEX_TOOL_OPEN = '60'; CODEX_CONSULT_TEST_BUDGET_POLL_MS = '500'; CODEX_CONSULT_QUOTA_BUDGET = '93' } -CaseHome $bh
    $e2 = Last-Entry $r
    Check 'BUDGET' 'CODEX_CONSULT_QUOTA_BUDGET=93: budget {93, source CODEX_CONSULT_QUOTA_BUDGET}; a thread over CODEX_CONSULT_FORK_MAX_KB: the partial''s footer continues in a NEW thread (-Mode new -Provider -Model, the partial named) instead of resume' ($x2.Code -eq 1 -and $e2.budget.percent -eq 93 -and $e2.budget.source -eq 'CODEX_CONSULT_QUOTA_BUDGET' -and $e2.budget.stopped -eq $true -and [string]$x2.Out -match "replays 6\d\d KB on every tool call \(over CODEX_CONSULT_FORK_MAX_KB 512\) - continue in a new thread with ``-Task t -Mode new -Provider openai -Model gpt-5\.1 .*-Prompt ""the previous run was stopped; its partial reply is handoffs/\d\d-codex-b2\.partial\.md - finish the review""``" -and [string]$x2.Out -notmatch "-Mode resume -Thread $($e2.thread)") (@(($x2.Out -split "`n") | Where-Object { $_ -match '^partial' }) -join '')
    $x3 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'b3', '-Mode', 'new', '-Budget', '0') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '95'; FAKE_CODEX_DELAY_MS = '2500'; CODEX_CONSULT_TEST_BUDGET_POLL_MS = '500' } -CaseHome $bh
    $e3 = Last-Entry $r
    Check 'BUDGET' '-Budget 0 = off: the same 95 % run completes usable (budget {percent 0, stopped false})' ($x3.Code -eq 0 -and $e3.bridge_outcome -eq 'usable reply' -and $e3.budget.percent -eq 0 -and $e3.budget.stopped -eq $false) "$($e3.bridge_outcome) $(J $e3.budget)"
    $x4 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'b4', '-Mode', 'new', '-Budget', '150', '-DryRun')
    $x5 = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'b5', '-Mode', 'new', '-DryRun') @{ CODEX_CONSULT_QUOTA_BUDGET = 'most' }
    Check 'BUDGET' 'a -Budget outside 0..100 and a malformed CODEX_CONSULT_QUOTA_BUDGET are refused' ($x4.Code -eq 1 -and $x4.Out -match '-Budget must be 0 \(off\) or a share' -and $x5.Code -eq 1 -and $x5.Out -match 'CODEX_CONSULT_QUOTA_BUDGET must be 0') "$($x4.Code) $($x5.Code)"
    # the detached runner: the same run code in the background (-Budget travels with the arguments)
    $rd = New-Repo 'budget-detach'
    $dx = Consult $rd '' @('-Detach', '-Prompt', 'x', '-ReplyName', 'bd', '-TimeoutSec', '120', '-Budget', '90') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '96'; FAKE_CODEX_ITEMS = '1'; FAKE_CODEX_TOOL_OPEN = '60'; CODEX_CONSULT_TEST_BUDGET_POLL_MS = '500' } -CaseHome $bh
    $dw = Consult $rd '' @('-Wait') @{} -NoCodexExe
    $ed = Last-Entry $rd
    Check 'BUDGET' 'a DETACHED run stops at the budget the same way (the background runs the same turn code): -Wait returns, the entry is a budget stop with its partial' ($dx.Code -eq 0 -and [string]$ed.bridge_outcome -like 'failed: stopped at the quota budget: 5-hour window 96 % used*' -and $ed.budget.stopped -eq $true -and $ed.partial_reply) "detach=$($dx.Code) wait=$($dw.Code): $($ed.bridge_outcome)"
}

# =============================================================== PROVIDERS: the QUOTA column and the verdicts
if (Want 'PROVIDERS') {
    $r = New-Repo 'prov'
    $ph = New-Home 'prov'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'p1') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '99' } -CaseHome $ph
    $e = Last-Entry $r
    $resetIso = [string]$e.quota.primary.resets_at
    $resetLocal = ([DateTimeOffset]$resetIso).ToLocalTime().ToString('HH:mm', $inv)
    $pt = Providers $r @() '' @{} $ph
    $oline = @(($pt.Out -split "`n") | Where-Object { $_ -match '^unavailable .*\bopenai\b' }) | Select-Object -First 1
    $hdr = @(($pt.Out -split "`n") | Where-Object { $_ -match '^VERDICT' }) | Select-Object -First 1
    Check 'PROVIDERS' "the table: QUOTA is the last column; openai 'unavailable (5-hour window 99 % used, resets <iso>)' and '5h 99% until $resetLocal; wk 15% until ...'" ($x.Code -eq 0 -and $hdr -match 'LAST FAILURE\s+QUOTA$' -and $oline -and $oline.StartsWith("unavailable (5-hour window 99 % used, resets $resetIso)") -and $oline -match "5h 99% until $resetLocal; wk 15% until \w{3} \d+$") "$hdr || $oline"
    $pj = Providers $r @('-Json', '-Provider', 'openai') '' @{} $ph
    $row = @($pj.Out | ConvertFrom-Json)[0]
    Check 'PROVIDERS' '-Json: quota {text, primary, secondary, observed_at, source recorded}; -Provider openai exits 2 (unavailable)' ($pj.Code -eq 2 -and $row.quota.text -like '5h 99% until *' -and $row.quota.primary.used_percent -eq 99 -and $row.quota.source -eq 'recorded') "$($pj.Code) $(J $row.quota)"
    $roster = Write-Roster 'prov' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'
    $pr = Providers $r @() $roster @{} $ph
    $ps = Providers $r @('-Short') $roster @{} $ph
    Check 'PROVIDERS' 'the roster walk skips openai like a usage limit, with the window and its reset; -Short says "out - openai :: gpt-5.1 (until HH:mm, in ...)"' ($pr.Out.Contains("roster: $roster -> would select ZAI :: glm-5.3 (skipped: openai :: gpt-5.1 (5-hour window 99 % used, resets $resetIso))") -and $ps.Out -match "out - openai :: gpt-5\.1 \(until $resetLocal, in \d") (@(($pr.Out -split "`n") | Where-Object { $_ -match '^roster:' }) -join '') + ' || ' + $ps.Out
    $xr = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'p2', '-Provider', 'openai', '-Model', 'gpt-5.1', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise } -CaseHome $ph
    Check 'PROVIDERS' 'a real run on that endpoint is refused before launch: "its 5-hour window 99 % used ... until the window resets at <iso>"' ($xr.Code -eq 1 -and $xr.Out -match "provider openai is not usable: its 5-hour window 99 % used \(observed at .*\) until the window resets at $([regex]::Escape($resetIso)); nothing was started") "$($xr.Code): $((@(($xr.Out -split "`n") | Where-Object { $_ -match 'not usable|codex-consult:' }) | Select-Object -First 3) -join ' / ')"
    $xw = Consult $r $roster @('-Prompt', 'x', '-ReplyName', 'p3', '-Mode', 'new', '-DryRun') @{} -CaseHome $ph
    Check 'PROVIDERS' 'a roster run (no -Provider) walks past it to ZAI: the dry run names the skip with the window' ($xw.Code -eq 0 -and $xw.Out -match 'skipped openai :: gpt-5\.1 \(5-hour window 99 % used, resets ') (@(($xw.Out -split "`n") | Where-Object { $_ -match 'Roster:|skipped' }) -join ' | ')
    $r84 = New-Repo 'prov84'
    $x84 = Consult $r84 '' @('-Prompt', 'x', '-ReplyName', 'p84') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '84' } -CaseHome $ph
    $p84 = Providers $r84 @('-Provider', 'openai') '' @{} $ph
    Check 'PROVIDERS' 'a window at 84 %: "available (low quota: 5-hour window 84 % until HH:mm)", -Provider exits 0' ($p84.Code -eq 0 -and $p84.Out -match '(?m)^available \(low quota: 5-hour window 84 % until \d\d:\d\d\)\s+openai') (@(($p84.Out -split "`n") | Where-Object { $_ -match 'openai' }) | Select-Object -First 1)
    $rP = New-Repo 'provpast'
    $xP = Consult $rP '' @('-Prompt', 'x', '-ReplyName', 'pp') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '99'; FAKE_CODEX_QUOTA_RESET_MIN = '-30' } -CaseHome $ph
    $pP = Providers $rP @('-Provider', 'openai') '' @{} $ph
    Check 'PROVIDERS' 'a 99 % window whose resets_at lies in the past: available, QUOTA "5h reset (last 99% until HH:mm)"' ($pP.Code -eq 0 -and $pP.Out -match '(?m)^available\s+openai' -and $pP.Out -match '5h reset \(last 99% until \d\d:\d\d\); wk 15% until') (@(($pP.Out -split "`n") | Where-Object { $_ -match 'openai' }) | Select-Object -First 1)
}

# =============================================================== MACHINE: the machine-wide record and the live rollout
if (Want 'MACHINE') {
    $mh = New-Home 'machine'
    $healthFile = Join-Path $work 'machine-health.json'
    $rA = New-Repo 'machA'
    $xa = Consult $rA '' @('-Prompt', 'x', '-ReplyName', 'ma', '-TimeoutSec', '120', '-Budget', '90') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_QUOTA = '1'; FAKE_CODEX_QUOTA_PRIMARY = '99'; FAKE_CODEX_ITEMS = '1'; FAKE_CODEX_TOOL_OPEN = '60'; CODEX_CONSULT_HEALTH = $healthFile; CODEX_CONSULT_TEST_BUDGET_POLL_MS = '500' } -CaseHome $mh
    $hdata = $(if (Test-Path $healthFile) { Get-Content -LiteralPath $healthFile -Raw | ConvertFrom-Json } else { $null })
    $wrec = @($hdata.endpoints | Where-Object { [string]$_.class -eq '' -and $_.quota })
    Check 'MACHINE' 'a run with no outcome record for the endpoint (stopped at its budget: provider_failure class operator) writes a machine-wide record of class '''' carrying its quota (a reader before wave 30 skips it)' ($xa.Code -eq 1 -and $wrec.Count -ge 1 -and $wrec[0].quota.primary.used_percent -eq 99) "$($xa.Code) $(J $hdata.endpoints)"
    $rB = New-Repo 'machB'
    $pB = Providers $rB @('-Provider', 'openai') '' @{ CODEX_CONSULT_HEALTH = $healthFile } $mh
    Check 'MACHINE' 'ANOTHER repository (no ledger of its own) sees the window through the machine-wide file: unavailable (5-hour window 99 % used ...)' ($pB.Code -eq 2 -and $pB.Out -match '(?m)^unavailable \(5-hour window 99 % used, resets ') (@(($pB.Out -split "`n") | Where-Object { $_ -match 'openai' }) | Select-Object -First 1)
    $lh = New-Home 'live'
    $lid = V7
    $null = Write-Rollout $lh $lid @((MetaLine ([DateTimeOffset]::Now) $lid), (TokenLine ([DateTimeOffset]::Now) 5000 0 10 5000 (Win 96 ([DateTimeOffset]::Now.AddMinutes(200))) (Win 15 ([DateTimeOffset]::Now.AddDays(4)) 10080)), (TokenLine ([DateTimeOffset]::Now) 5000 0 10 5000 'null' 'null' 'premium'))
    $rC = New-Repo 'machC'
    $liveHealth = Join-Path $work 'live-health.json'
    $pC = Providers $rC @('-Json', '-Provider', 'openai') '' @{ CODEX_CONSULT_HEALTH = $liveHealth } $lh
    $rowC = @($pC.Out | ConvertFrom-Json)[0]
    $pCoff = Providers $rC @('-Json', '-Provider', 'openai') '' @{ CODEX_CONSULT_HEALTH = 'none' } $lh
    $rowCoff = @($pCoff.Out | ConvertFrom-Json)[0]
    $dC = Consult $rC '' @('-Prompt', 'x', '-DryRun') @{ CODEX_CONSULT_HEALTH = $liveHealth } -CaseHome $lh
    Check 'MACHINE' 'the live source: the codex home''s newest rollout (provider openai) is the built-in openai''s window with no ledger at all - "available (low quota: 5-hour window 96 % ...)", source rollout; the dry run prints it; CODEX_CONSULT_HEALTH=none reads no rollout' ($pC.Code -eq 0 -and $rowC.verdict -match '^available \(low quota: 5-hour window 96 % until \d\d:\d\d\)$' -and $rowC.quota.source -eq 'rollout' -and $null -eq $rowCoff.quota -and $rowCoff.verdict -eq 'available' -and $dC.Out -match '(?m)^quota       : 5h 96% until \d\d:\d\d; wk 15% until \w{3} \d+ \(observed \d\d:\d\d, rollout\)$') "$($rowC.verdict) | $(J $rowC.quota) | off: $($rowCoff.verdict) | $(@(($dC.Out -split "`n") | Where-Object { $_ -match '^quota' }) -join '')"
}

# =============================================================== PROMPT: the reading discipline
if (Want 'PROMPT') {
    $r = New-Repo 'prompt'
    $sentence = 'Reading discipline: never print whole files. Run `git diff <range> --stat` first, then read the hunks of ONE path at a time with a line cap'
    $tail = 'Read the documents the brief names before the code. Give your verdict even when your reading is incomplete, and list what you did not read.'
    $have = @{}
    foreach ($pp in @('acceptance', 'diff-review', 'checkpoint', 'core-contract', 'framing', 'decision')) {
        $log = Join-Path $work "prompt-$pp.txt"
        $x = Consult $r '' @('-Prompt', 'x', '-Purpose', $pp, '-ReplyName', "pr-$pp", '-Mode', 'new') @{ FAKE_CODEX_REPLY = $(if ($pp -eq 'acceptance') { $accept } else { $advise }); FAKE_CODEX_LOG = $log }
        $t = $(if (Test-Path $log) { [IO.File]::ReadAllText($log) } else { '' })
        $have[$pp] = [bool]($t.Contains($sentence) -and $t.Contains($tail))
    }
    Check 'PROMPT' 'the reading discipline (git diff --stat first, one path at a time with a line cap, the documents first, the verdict even on an incomplete read) in the purpose paragraph of acceptance, diff-review, checkpoint and core-contract - not of framing or decision' ($have['acceptance'] -and $have['diff-review'] -and $have['checkpoint'] -and $have['core-contract'] -and -not $have['framing'] -and -not $have['decision']) (($have.Keys | Sort-Object | ForEach-Object { "$_=$($have[$_])" }) -join ' ')
}

# =============================================================== DOCS
if (Want 'DOCS') {
    $readme = [IO.File]::ReadAllText((Join-Path $repoRoot 'README.md'))
    $cl = [IO.File]::ReadAllText((Join-Path $repoRoot 'CHANGELOG.md'))
    $td = [IO.File]::ReadAllText((Join-Path $repoRoot 'TECH_DEBT.md'))
    $tr = [IO.File]::ReadAllText((Join-Path $sp 'README.md'))
    $runAll = [IO.File]::ReadAllText((Join-Path $sp 'run-all.ps1'))
    $skC = [IO.File]::ReadAllText((Join-Path $repoRoot 'plugins\codex-consult\skills\consult-codex\SKILL.md'))
    $skO = [IO.File]::ReadAllText((Join-Path $repoRoot 'plugins\codex-consult\skills\coordinate\SKILL.md'))
    $miss = @(foreach ($k in @('## Quota windows and the reading budget', '-Budget', 'CODEX_CONSULT_QUOTA_BUDGET', 'CODEX_CONSULT_FORK_MAX_KB', 'features.multi_agent=false', 'subagents_allowed', '5h 96% until 18:32', 'low quota', 'Reading discipline')) { if (-not $readme.Contains($k)) { $k } })
    Check 'DOCS' 'README: the section "Quota windows and the reading budget" (the rollout, the verdict rules, -Budget, CODEX_CONSULT_FORK_MAX_KB, multi_agent, the reading discipline)' ($miss.Count -eq 0) "missing: $($miss -join ', ')"
    $un = $(if ($cl -match '(?s)## \[Unreleased\](.*?)(\n## \[)') { $Matches[1] } else { '' })
    Check 'DOCS' 'CHANGELOG [Unreleased]: "Wave 30 - quota windows" with the measured numbers' ($un -match 'Wave 30 - quota windows' -and $un -match '96 %' -and $un -match '186 s') ''
    Check 'DOCS' 'TECH_DEBT T15 marked implemented in wave 30 (0.6.2); the consult-codex and coordinate skills name the quota windows' ($td -match '(?s)\*\*T15 .*?implemented in wave 30 \(0\.6\.2\)' -and $skC -match 'features\.multi_agent' -and $skC -match '-Budget' -and $skO -match 'quota window') ''
    Check 'DOCS' 'tests/README.md describes harness-quota and run-all.ps1 registers it' ($tr.Contains('harness-quota') -and $runAll -match "'harness-quota'") ''
}

# =============================================================== GUARD
if (-not $Only) {
    Check 'GUARD' 'every case ran in a scratch CODEX_HOME: the fakes write rollouts only under the CODEX_HOME a harness sets (fake-rollout.ps1 never without one)' ([IO.File]::ReadAllText((Join-Path $sp 'fake-rollout.ps1')).Contains("if (`$env:FAKE_CODEX_QUOTA -ne '1' -or -not `$env:CODEX_HOME -or -not `$Thread) { return }")) ''
}

} finally {
    foreach ($s in $sleepers) { try { if (-not $s.HasExited) { $s.Kill() } } catch { } }
    Restore-Env
    Remove-TestWork $work
}
Write-Host ''
Write-Host ("harness-quota ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
