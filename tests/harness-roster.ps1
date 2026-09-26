# codex-consult reviewer roster (0.3.x): roster file validation, the three selection rules
# (-Provider, -Thread, the roster walk), quota semantics with a known reset time
# (Get-RetryAfter, provider_failure.retry_after, Get-EndpointHealth), the F12-2 classifier
# order, UTF-8 capture of codex's stderr and `login status`, -SchemaTransport, the roster
# view of codex-providers.ps1, the review panel (-Panel) and the per-reviewer scoreboard of
# codex-findings.ps1 -Stats. Fake codex only (fake-codex3.cmd); CODEX_HOME always points at
# a SCRATCH directory, CODEX_CONSULT_ROSTER at scratch roster files and CODEX_CONSULT_NOW
# freezes the clock of the endpoint-health reading where a case seeds ledgers. Runs under
# the host it is started with (powershell 5.1 or pwsh 7, Windows) and launches the scripts
# with the same host. Work files: $env:TEMP\codex-consult-tests\harness-roster\<guid>,
# removed at the end.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$providersPs = Join-Path $scripts 'codex-providers.ps1'
$findingsPs = Join-Path $scripts 'codex-findings.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-roster') ([guid]::NewGuid().ToString('N'))
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
$apos = [string][char]0x2019
$realConfig = Join-Path (Join-Path $HOME '.codex') 'config.toml'
$realConfigHash = ''
if (Test-Path -LiteralPath $realConfig -PathType Leaf) { $realConfigHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash }
$savedCodexHome = $env:CODEX_HOME
$script:fails = 0
$script:passes = 0

function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 300) { $ev = $ev.Substring(0, 300) + '...' }
    Write-Host ("{0} {1,-7} {2}{3}" -f $mark, $Id, $What, $(if ($ev) { "  | $ev" } else { '' }))
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
# The scratch Codex config: builtin openai (top-level model gpt-5.1) plus three custom
# providers - ZAI (env RT_ZAI_KEY), mimo (env RT_MIMO_KEY) and local (no credential).
$toml = "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.mimo]`nbase_url = `"https://token-plan-ams.xiaomimimo.com/v1`"`nenv_key = `"RT_MIMO_KEY`"`nwire_api = `"responses`"`n`n[model_providers.local]`nbase_url = `"http://localhost:8080/v1`"`nwire_api = `"responses`"`n"
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml, $u8)
$cfgPath = Join-Path $codexHome 'config.toml'
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
# CODEX_CONSULT_ROSTER=none: no roster at all (a path that does not exist is refused)
$noRoster = 'none'
$missingRoster = Join-Path $work 'no-such-roster.json'

$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_SLEEP', 'FAKE_CODEX_LOG', 'FAKE_CODEX_NOTHREAD', 'FAKE_CODEX_ROLLOUT', 'FAKE_CODEX_ROLLOUT_LOG', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_PRELINE', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_STDERR', 'FAKE_CODEX_EXIT', 'FAKE_CODEX_FAIL_ON', 'FAKE_CODEX_HANG_ON')
$testVars = @('RT_ZAI_KEY', 'RT_MIMO_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_SURVIVORS')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
}
# Both keys are set unless a case removes one ('' removes a variable). $Roster '' leaves
# CODEX_CONSULT_ROSTER unset (the default path <codex home>/codex-consult-roster.json).
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:RT_MIMO_KEY = 'mimo-test-key'
    if ($Roster) { $env:CODEX_CONSULT_ROSTER = $Roster }
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
    $preview = $null
    $mark = 'sessions.json entry preview:'
    $at = $text.IndexOf($mark)
    if ($at -ge 0) { try { $preview = $text.Substring($at + $mark.Length) | ConvertFrom-Json } catch { $preview = $null } }
    return [pscustomobject]@{ Code = $code; Out = $text; Preview = $preview; First = (($text -split "`n") | Select-Object -First 1) }
}
function Providers {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList = @(), [hashtable]$Env = @{})
    Set-CaseEnv $Roster $Env
    $env:CODEX_CONSULT_EXE = $fake
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $providersPs @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    $json = $null
    if ($ArgList -contains '-Json') { try { $parsed = $text | ConvertFrom-Json; $json = @($parsed | ForEach-Object { $_ }) } catch { $json = $null } }
    return [pscustomobject]@{ Code = $code; Out = $text; Json = $json }
}
# codex-findings.ps1 / codex-scoreboard.ps1 in $Repo: { Code; Out; First }
function Run-Tool {
    param([string]$Script, [string]$Repo, [string[]]$ArgList)
    Set-CaseEnv $noRoster @{}
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
function Ledger { param([string]$Repo, [string]$Task = 't') $f = Join-Path $Repo ".collab\$Task\sessions.json"; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Last-Entry { param([string]$Repo) return (Ledger $Repo)[-1] }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
function Iso { param($Dto) return ([DateTimeOffset]$Dto).ToString('yyyy-MM-ddTHH:mm:sszzz', $inv) }
function To-Offset { param($V) if ($V -is [DateTimeOffset]) { return $V }; if ($V -is [datetime]) { return [DateTimeOffset]$V }; return [DateTimeOffset]::Parse([string]$V, $inv) }
function Seed-Task {
    param([string]$Repo, [string]$Task, [object[]]$Entries)
    $dir = Join-Path $Repo ".collab\$Task"
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
    Write-JsonFile -Path (Join-Path $dir 'sessions.json') -Object ([pscustomobject]@{ task_id = $Task; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$Entries } })
}
# A failed (or successful) consultation of $Provider/$Model on endpoint $Fp, $MinutesAgo
# before $Now; $Failure is its provider_failure (or $null for an older entry / a success).
function New-SeedEntry {
    param([int]$N, [string]$Provider, [string]$Model, [string]$Fp, [DateTimeOffset]$Now, [int]$MinutesAgo, [string]$Outcome, $Failure)
    $when = Iso ($Now.AddMinutes(-$MinutesAgo))
    $e = [ordered]@{ n = $N; when = $when; purpose = ''; reviewer = [pscustomobject]@{ provider = $Provider; model = $Model; provider_fingerprint = $Fp }; lineage = "$Provider :: $Model"; thread = ''; thread_source = 'unknown'; mode = 'new'; reply = ('handoffs/{0:D2}-codex-seed.md' -f ($N + 1)); bridge_outcome = $Outcome }
    if ($null -ne $Failure) { $e['provider_failure'] = $Failure }
    return (New-Object PSObject -Property $e)
}

$advise = Reply 'advise.json' '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
# The frozen consult clock for the seeded cases, in this machine's offset on that date (so
# pwsh, which reads ISO strings of a ledger back as local DateTime, prints the same text).
$nowLocal = New-Object DateTime(2026, 9, 24, 14, 0, 0)
$nowOffset = [TimeZoneInfo]::Local.GetUtcOffset($nowLocal)
$now = New-Object DateTimeOffset($nowLocal, $nowOffset)
$nowIso = Iso $now
$builtinFp = $script:BuiltinOpenAiFingerprint
$zaiFp = (Resolve-ReviewerIdentity -Config (Read-CodexConfigSubset -Path $cfgPath) -Provider 'ZAI' -Model 'glm-5.3').Fingerprint
$codexLimit = "You${apos}ve hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro), visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at Sep 28th, 2026 8:35 PM."
$codexLimitIso = Iso (New-Object DateTimeOffset((New-Object DateTime(2026, 9, 28, 20, 35, 0)), $nowOffset))

try {
# =============================================================== UNIT: Get-RetryAfter, New-ProviderFailure, Get-EndpointHealth, F12-2
if (Want 'UNIT') {
    # A fixed zone with daylight saving for the write-time rules (F15-1): Berlin by its
    # Windows or IANA id, else a custom zone with the EU rules.
    $berlin = $null
    foreach ($tzId in @('W. Europe Standard Time', 'Europe/Berlin')) { if (-not $berlin) { try { $berlin = [TimeZoneInfo]::FindSystemTimeZoneById($tzId) } catch { } } }
    if (-not $berlin) {
        $dstStart = [TimeZoneInfo+TransitionTime]::CreateFloatingDateRule((New-Object DateTime(1, 1, 1, 2, 0, 0)), 3, 5, [DayOfWeek]::Sunday)
        $dstEnd = [TimeZoneInfo+TransitionTime]::CreateFloatingDateRule((New-Object DateTime(1, 1, 1, 3, 0, 0)), 10, 5, [DayOfWeek]::Sunday)
        $euRule = [TimeZoneInfo+AdjustmentRule]::CreateAdjustmentRule([datetime]::MinValue.Date, [datetime]::MaxValue.Date, [TimeSpan]::FromHours(1), $dstStart, $dstEnd)
        $berlin = [TimeZoneInfo]::CreateCustomTimeZone('Test/Berlin', [TimeSpan]::FromHours(1), 'Test Berlin', 'CET', 'CEST', [TimeZoneInfo+AdjustmentRule[]]@($euRule))
    }
    $ref = [DateTimeOffset]::Parse('2026-09-24T12:54:23+02:00', $inv)
    $cases = @(
        @{ Name = 'Codex wording, curly apostrophe'; Msg = $codexLimit; Ref = $ref; Want = '2026-09-28T20:35:00+02:00' },
        @{ Name = 'read time (-ReferenceOffset): Codex wording read in the reference offset (-05:00)'; Msg = $codexLimit; Ref = [DateTimeOffset]::Parse('2026-09-24T12:54:23-05:00', $inv); Want = '2026-09-28T20:35:00-05:00'; RefOffset = $true },
        @{ Name = 'DST: Berlin failure 2026-10-25T01:00+02:00, reset "Oct 26th, 2026 8:35 PM" -> +01:00 (19:35Z)'; Msg = "You${apos}ve hit your usage limit ... try again at Oct 26th, 2026 8:35 PM."; Ref = [DateTimeOffset]::Parse('2026-10-25T01:00:00+02:00', $inv); Want = '2026-10-26T20:35:00+01:00' },
        @{ Name = 'DST, read time (-ReferenceOffset): the reference offset +02:00 (the documented fallback)'; Msg = 'try again at Oct 26th, 2026 8:35 PM.'; Ref = [DateTimeOffset]::Parse('2026-10-25T01:00:00+02:00', $inv); Want = '2026-10-26T20:35:00+02:00'; RefOffset = $true },
        @{ Name = 'DST gap: 2026-03-29 02:30 does not exist in Berlin -> the offset after (+02:00)'; Msg = 'try again at Mar 29th, 2026 2:30 AM'; Ref = [DateTimeOffset]::Parse('2026-03-28T12:00:00+01:00', $inv); Want = '2026-03-29T02:30:00+02:00' },
        @{ Name = 'DST overlap: 2026-10-25 02:30 is ambiguous in Berlin -> the offset before (+02:00)'; Msg = 'try again at Oct 25th, 2026 2:30 AM'; Ref = [DateTimeOffset]::Parse('2026-10-24T12:00:00+02:00', $inv); Want = '2026-10-25T02:30:00+02:00' },
        @{ Name = 'a duration across the DST change is shown in the zone offset then (same instant)'; Msg = 'try again in 2 days'; Ref = [DateTimeOffset]::Parse('2026-10-24T12:00:00+02:00', $inv); Want = '2026-10-26T11:00:00+01:00' },
        @{ Name = 'straight apostrophe, full month, no ordinal'; Msg = "You've hit your usage limit ... try again at September 28, 2026 8:35 PM"; Ref = $ref; Want = '2026-09-28T20:35:00+02:00' },
        @{ Name = 'resets at, 12 AM = midnight'; Msg = 'Limit reached; resets at Oct 1st, 2026 12:05 AM.'; Ref = $ref; Want = '2026-10-01T00:05:00+02:00' },
        @{ Name = 'until + 24-hour clock'; Msg = 'blocked until Sep 30, 2026 17:45'; Ref = $ref; Want = '2026-09-30T17:45:00+02:00' },
        @{ Name = 'missing year -> the reference year'; Msg = 'try again at Sep 28th 8:35 PM.'; Ref = $ref; Want = '2026-09-28T20:35:00+02:00' },
        @{ Name = 'missing year, date already past -> next year'; Msg = 'try again at Jan 3rd, 9:00 AM'; Ref = [DateTimeOffset]::Parse('2026-12-30T10:00:00+01:00', $inv); Want = '2027-01-03T09:00:00+01:00' },
        @{ Name = 'ISO after "until" keeps its own offset'; Msg = 'rate limited until 2026-09-25T08:00:00Z'; Ref = $ref; Want = '2026-09-25T10:00:00+02:00' },
        @{ Name = 'ISO without offset -> a wall-clock time of the zone'; Msg = 'Retry at 2026-09-25 08:00:00 please'; Ref = $ref; Want = '2026-09-25T08:00:00+02:00' },
        @{ Name = 'Retry after 30 seconds'; Msg = 'Rate limit exceeded. Retry after 30 seconds.'; Ref = $ref; Want = '2026-09-24T12:54:53+02:00' },
        @{ Name = 'Retry-After: 120 (no unit = seconds)'; Msg = '429 Too Many Requests; Retry-After: 120'; Ref = $ref; Want = '2026-09-24T12:56:23+02:00' },
        @{ Name = 'try again in 5 minutes'; Msg = 'Please try again in 5 minutes.'; Ref = $ref; Want = '2026-09-24T12:59:23+02:00' },
        @{ Name = 'resets in 1 hour 30 minutes'; Msg = 'quota resets in 1 hour 30 minutes'; Ref = $ref; Want = '2026-09-24T14:24:23+02:00' },
        @{ Name = 'nothing -> null'; Msg = 'the model produced nothing'; Ref = $ref; Want = '' },
        @{ Name = 'mixed days + hours + minutes are summed'; Msg = "You've hit your usage limit. Upgrade to Pro or try again in 3 days 1 hour 7 minutes."; Ref = $ref; Want = '2026-09-27T14:01:23+02:00' },
        @{ Name = 'resets in 2 days'; Msg = 'Your quota resets in 2 days.'; Ref = $ref; Want = '2026-09-26T12:54:23+02:00' },
        @{ Name = 'retry after 1 week'; Msg = 'Plan exhausted - retry after 1 week'; Ref = $ref; Want = '2026-10-01T12:54:23+02:00' },
        @{ Name = 'try again in 2 weeks, 1 day'; Msg = 'try again in 2 weeks, 1 day'; Ref = $ref; Want = '2026-10-09T12:54:23+02:00' },
        @{ Name = 'no reset time named -> null'; Msg = "You've hit your usage limit. Upgrade to Pro or try again later."; Ref = $ref; Want = '' }
    )
    $bad = @()
    foreach ($c in $cases) {
        if ($c.RefOffset) { $got = Get-RetryAfter -Message $c.Msg -Reference $c.Ref -ReferenceOffset }
        else { $got = Get-RetryAfter -Message $c.Msg -Reference $c.Ref -TimeZone $berlin }
        $gotText = if ($null -eq $got) { '' } else { Iso $got }
        if ($gotText -ne $c.Want) { $bad += "$($c.Name): got '$gotText', want '$($c.Want)'" }
    }
    Check 'UNIT' "Get-RetryAfter: $($cases.Count) samples in zone $($berlin.Id) (Codex wording, curly apostrophe, DST change/gap/overlap, read-time reference offset, missing year, ISO, durations, nothing)" ($bad.Count -eq 0) ($bad -join ' | ')

    $pf = New-ProviderFailure -Texts @($codexLimit)
    $pfWall = New-Object DateTime(2026, 9, 28, 20, 35, 0)
    $pfExpect = Iso (New-Object DateTimeOffset($pfWall, [TimeZoneInfo]::Local.GetUtcOffset($pfWall)))
    Check 'UNIT' 'New-ProviderFailure: class quota, message keeps the curly apostrophe, retry_after 2026-09-28T20:35 in the offset of its `when`, field order class,code,message,when,retry_after' ($pf.class -eq 'quota' -and $pf.message.Contains("You${apos}ve") -and $pf.retry_after -eq $pfExpect -and (($pf.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'class,code,message,when,retry_after') "$($pf.class) / $($pf.retry_after)"
    $pf2 = New-ProviderFailure -Texts @('the model produced nothing')
    Check 'UNIT' 'New-ProviderFailure without a reset time -> retry_after null' ($pf2.PSObject.Properties['retry_after'] -and $null -eq $pf2.retry_after) ''

    # Get-EndpointHealth: a KNOWN reset time blocks beyond 60 min; a past one clears
    $mk = { param($ago, $failure) New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now $ago 'failed: codex exit 1 - x' $failure }
    $future = [pscustomobject]@{ class = 'quota'; code = ''; message = 'limit'; when = ''; retry_after = (Iso $now.AddDays(2)) }
    $h1 = Get-EndpointHealth -Consults @((& $mk 120 $future)) -Fingerprint $builtinFp -UtcNow $now.UtcDateTime
    Check 'UNIT' 'health: quota 120 min old with retry_after in the future -> Quota (blocking), QuotaKnown, Until = RetryAfter' ($null -ne $h1.Quota -and $h1.QuotaKnown -and $h1.Quota.RetryAfterIso -eq (Iso $now.AddDays(2)) -and $h1.Quota.Until -eq $h1.Quota.RetryAfter) "QuotaKnown=$($h1.QuotaKnown)"
    $past = [pscustomobject]@{ class = 'quota'; code = ''; message = 'limit'; when = ''; retry_after = (Iso $now.AddMinutes(-5)) }
    $h2 = Get-EndpointHealth -Consults @((& $mk 30 $past)) -Fingerprint $builtinFp -UtcNow $now.UtcDateTime
    Check 'UNIT' 'health: retry_after in the past -> not blocking (Quota null, QuotaKnown false), still LastLimit' ($null -eq $h2.Quota -and -not $h2.QuotaKnown -and $null -ne $h2.LastLimit) ''
    $none = [pscustomobject]@{ class = 'quota'; code = ''; message = 'limit'; when = '' }
    $h3 = Get-EndpointHealth -Consults @((& $mk 10 $none)) -Fingerprint $builtinFp -UtcNow $now.UtcDateTime
    $h4 = Get-EndpointHealth -Consults @((& $mk 61 $none)) -Fingerprint $builtinFp -UtcNow $now.UtcDateTime
    Check 'UNIT' 'health: no reset time -> blocking only <= 60 min (Until = When + 60 min), QuotaKnown false' ($null -ne $h3.Quota -and -not $h3.QuotaKnown -and $h3.Quota.Until -eq $h3.Quota.At.AddMinutes(60) -and $null -eq $h4.Quota) ''
    $legacyMsg = New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now 10 "failed: codex exit 1 - $codexLimit" $null
    $h5 = Get-EndpointHealth -Consults @($legacyMsg) -Fingerprint $builtinFp -UtcNow $now.UtcDateTime
    Check 'UNIT' 'health: an entry without provider_failure -> the reset time is read from its bridge_outcome in the when''s offset; RetryAfterBasis "message (reference offset)"' ($h5.QuotaKnown -and $h5.Quota.RetryAfterIso -eq $codexLimitIso -and $h5.Quota.RetryAfterBasis -eq 'message (reference offset)') "$($h5.Quota.RetryAfterIso) / $($h5.Quota.RetryAfterBasis)"
    Check 'UNIT' 'health: a recorded provider_failure.retry_after -> RetryAfterBasis "ledger"' ($h1.Quota.RetryAfterBasis -eq 'ledger') $h1.Quota.RetryAfterBasis

    # F15-4: a failure stamped in the future counts as now (never skipped)
    $futAuth = New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now -6 'failed: codex exit 1 - 401 Unauthorized' ([pscustomobject]@{ class = 'auth'; code = ''; message = '401 Unauthorized'; when = '' })
    $h6 = Get-EndpointHealth -Consults @($futAuth) -Fingerprint $builtinFp -UtcNow $now.UtcDateTime
    Check 'F15-4' 'health: an auth failure stamped 6 min in the future -> Auth set, AgeMinutes 0' ($null -ne $h6.Auth -and $h6.Auth.AgeMinutes -eq 0) "Auth=$($null -ne $h6.Auth)"

    # F15-2: a legacy entry's `when` keeps its recorded offset (-05:00) when read back
    $rj = New-Repo 'json-offset'
    Seed-Task $rj 'other' @((New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now 10 "failed: codex exit 1 - You've hit your usage limit. try again at Sep 24th, 2026 11:00 PM." $null))
    $sj = Join-Path $rj '.collab\other\sessions.json'
    $whenM5 = Iso ($now.ToOffset([TimeSpan]::FromHours(-5)).AddMinutes(-10))
    $tj = ([IO.File]::ReadAllText($sj, $u8)) -replace '"when":\s*"[^"]*"', ('"when": "' + $whenM5 + '"')
    [IO.File]::WriteAllText($sj, $tj, $u8)
    $hj = Get-EndpointHealth -Consults (Read-AllTaskConsults -CollabRoot (Join-Path $rj '.collab')) -Fingerprint $builtinFp -UtcNow $now.UtcDateTime
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) {
        Check 'F15-2' 'pwsh: a legacy entry with when=...-05:00 read back keeps -05:00 in the health record''s When, and the message fallback reads the wall clock in -05:00' ($hj.LastLimit.When -eq $whenM5 -and $hj.LastLimit.RetryAfterIso -eq '2026-09-24T23:00:00-05:00' -and $hj.LastLimit.RetryAfterBasis -eq 'message (reference offset)') "When=$($hj.LastLimit.When) RetryAfter=$($hj.LastLimit.RetryAfterIso)"
    } else {
        Check 'F15-2' "$($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion): ISO timestamps stay strings (the -DateKind case runs on pwsh >= 7.5) - When keeps -05:00" ($hj.LastLimit.When -eq $whenM5) "When=$($hj.LastLimit.When)"
    }

    # F12-2: capability before auth/quota; auth on word boundaries
    $samples = [ordered]@{
        'Your token plan does not support response_format' = 'capability'
        'text authored by the reviewer' = 'unknown'
        '401 Unauthorized' = 'auth'
        'insufficient balance' = 'quota'
        "text.format type 'json_schema' is not supported" = 'capability'
        "this endpoint doesn${apos}t support tools" = 'capability'
        'missing api key' = 'auth'
        'rate_limit_exceeded' = 'quota'
    }
    $badC = @($samples.Keys | Where-Object { (Get-ProviderFailureClass $_) -ne $samples[$_] } | ForEach-Object { "$_ -> $(Get-ProviderFailureClass $_)" })
    Check 'F12-2' 'Get-ProviderFailureClass: capability first, auth on word boundaries (8 samples)' ($badC.Count -eq 0) ($badC -join ' | ')

    # Two live provider failures of the parallel panel's ledger (2026-09-26), verbatim: Kimi
    # Code's 5-hour limit sent with a 403 (recorded as auth, no reset time) and the agy quota
    # with a relative reset time (recorded as quota, no reset time).
    $kimiText = "unexpected status 403 Forbidden: You've reached your 5-hour usage limit. Your quota will reset when the current 5-hour window ends. To continue now, purchase extra usage or upgrade your plan: https://www.kimi.com/membership/subscription?tab=quota"
    $kimiLedgerMsg = "unexpected status 403 Forbidden: You've reached your 5-hour usage limit. Your quota will reset when the current 5-hour window ends. To continue now, purchase extra usage or upgrade your plan: https://"
    $kimiOutcome = "failed: codex exit 1 - $kimiText, url: https://api.kimi.ai/coding/v1/responses, cf-ray: a40d6d4c38c3d3c1-FRA"
    $agyText = 'Individual quota reached. Please upgrade your subscription to increase your limits. Resets in 68h58m18s.'
    $liveC = [ordered]@{ $kimiText = 'quota'; $kimiLedgerMsg = 'quota'; $agyText = 'quota'; '403 Forbidden' = 'auth'; 'unexpected status 401 Unauthorized: invalid api key' = 'auth'; 'unexpected status 403 Forbidden: rate limit reached for this key' = 'quota' }
    $badL = @($liveC.Keys | Where-Object { (Get-ProviderFailureClass $_) -ne $liveC[$_] } | ForEach-Object { "$($_.Substring(0, [Math]::Min(40, $_.Length))) -> $(Get-ProviderFailureClass $_)" })
    Check 'LIVE' 'Get-ProviderFailureClass: a usage limit said in words is quota even under a 401/403 status (Kimi Code''s live 403 "You''ve reached your 5-hour usage limit", full and as cut to 200 characters in the ledger); a plain 401/403 stays auth' ($badL.Count -eq 0) ($badL -join ' | ')
    $kRef = [DateTimeOffset]::Parse('2026-09-26T00:22:57+02:00', $inv)
    $aRef = [DateTimeOffset]::Parse('2026-09-26T00:32:37+02:00', $inv)
    $liveR = @(
        @{ Name = 'Kimi 5-hour window (upper bound)'; Msg = $kimiText; Ref = $kRef; Want = '2026-09-26T05:22:57+02:00' },
        @{ Name = 'Kimi, the 200-character ledger message'; Msg = $kimiLedgerMsg; Ref = $kRef; Want = '2026-09-26T05:22:57+02:00' },
        @{ Name = 'agy "Resets in 68h58m18s"'; Msg = $agyText; Ref = $aRef; Want = '2026-09-28T21:30:55+02:00' },
        @{ Name = 'resets in 2d3h'; Msg = 'Your quota resets in 2d3h.'; Ref = $aRef; Want = '2026-09-28T03:32:37+02:00' },
        @{ Name = 'try again in 45m'; Msg = 'Please try again in 45m.'; Ref = $aRef; Want = '2026-09-26T01:17:37+02:00' },
        @{ Name = 'Resets in 30s'; Msg = 'Quota reached. Resets in 30s.'; Ref = $aRef; Want = '2026-09-26T00:33:07+02:00' },
        @{ Name = 'resets in 1.5h (decimals)'; Msg = 'limit hit; resets in 1.5h'; Ref = $aRef; Want = '2026-09-26T02:02:37+02:00' }
    )
    $badR = @()
    foreach ($c in $liveR) {
        $got = Get-RetryAfter -Message $c.Msg -Reference $c.Ref -ReferenceOffset
        $gotText = if ($null -eq $got) { '' } else { Iso $got }
        if ($gotText -ne $c.Want) { $badR += "$($c.Name): got '$gotText', want '$($c.Want)'" }
    }
    Check 'LIVE' "Get-RetryAfter: Kimi's rolling window -> the failure + 5 h (an upper bound); a compact relative duration ""Resets in 68h58m18s"" (also 2d3h, 45m, 30s, 1.5h) -> the failure + it ($($liveR.Count) samples)" ($badR.Count -eq 0) ($badR -join ' | ')
    $pfK = New-ProviderFailure -Texts @('', ($kimiOutcome -replace '^failed:\s*', ''))
    $pfA = New-ProviderFailure -Texts @($agyText)
    $spanK = if ($pfK.retry_after) { ((To-Offset $pfK.retry_after) - (To-Offset $pfK.when)).TotalSeconds } else { -1 }
    $spanA = if ($pfA.retry_after) { ((To-Offset $pfA.retry_after) - (To-Offset $pfA.when)).TotalSeconds } else { -1 }
    Check 'LIVE' 'New-ProviderFailure on the live texts: Kimi -> class quota, retry_after = its when + 5 h; agy -> class quota, retry_after = its when + 68h58m18s' ($pfK.class -eq 'quota' -and $spanK -eq 18000 -and $pfA.class -eq 'quota' -and $spanA -eq 248298) "kimi $($pfK.class) +$spanK s; agy $($pfA.class) +$spanA s"
    # The two entries as the ledger holds them (read-time rules: nobody edits the ledger)
    $n11 = New-Object PSObject -Property ([ordered]@{ n = 11; when = '2026-09-26T00:19:25+02:00'; purpose = 'acceptance'; reviewer = [pscustomobject]@{ provider = 'kimi'; model = 'k3'; provider_fingerprint = 'fp-kimi-live' }; lineage = 'kimi :: k3'; bridge_outcome = $kimiOutcome; provider_failure = [pscustomobject]@{ class = 'auth'; code = ''; message = $kimiLedgerMsg; when = '2026-09-26T00:22:57+02:00'; retry_after = $null }; wall_seconds = 212.8; finished_at = '2026-09-26T00:22:58+02:00' })
    $n7 = New-Object PSObject -Property ([ordered]@{ n = 7; when = '2026-09-26T00:27:43+02:00'; purpose = 'acceptance'; reviewer = [pscustomobject]@{ provider = 'gemini'; model = 'gemini-3.1-pro-high'; engine = 'agy'; provider_fingerprint = 'fp-agy-live' }; lineage = 'gemini :: gemini-3.1-pro-high'; bridge_outcome = "failed: agy exit 3 - $agyText"; provider_failure = [pscustomobject]@{ class = 'quota'; code = ''; message = $agyText; when = '2026-09-26T00:32:37+02:00'; retry_after = $null }; wall_seconds = 293.9; finished_at = '2026-09-26T00:32:37+02:00' })
    $at1 = [DateTimeOffset]::Parse('2026-09-26T01:00:00+02:00', $inv).UtcDateTime
    $at6 = [DateTimeOffset]::Parse('2026-09-26T06:00:00+02:00', $inv).UtcDateTime
    $hk1 = Get-EndpointHealth -Consults @($n11) -Fingerprint 'fp-kimi-live' -UtcNow $at1
    $hk6 = Get-EndpointHealth -Consults @($n11) -Fingerprint 'fp-kimi-live' -UtcNow $at6
    $ha1 = Get-EndpointHealth -Consults @($n7) -Fingerprint 'fp-agy-live' -UtcNow $at1
    Check 'LIVE' 'Get-EndpointHealth READS the live entries with the new rules: n=11 (recorded class auth) is no auth failure but a quota one until 05:22:57 (its when + 5 h) and clears after it; n=7 blocks until 2026-09-28T21:30:55+02:00 (its when + 68h58m18s), a known reset time' ($null -eq $hk1.Auth -and $null -ne $hk1.Quota -and $hk1.QuotaKnown -and $hk1.Quota.RetryAfterIso -eq '2026-09-26T05:22:57+02:00' -and $null -eq $hk6.Auth -and $null -eq $hk6.Quota -and $null -eq $ha1.Auth -and $ha1.QuotaKnown -and $ha1.Quota.RetryAfterIso -eq '2026-09-28T21:30:55+02:00') "kimi@01:00 auth=$([bool]$hk1.Auth) quota until $($hk1.Quota.RetryAfterIso); @06:00 quota=$([bool]$hk6.Quota); agy until $($ha1.Quota.RetryAfterIso)"
}

# =============================================================== FILE: roster file validation (fail-closed)
if (Want 'FILE') {
    $r = New-Repo 'file'
    $expMissing = "codex-consult: the reviewer roster '$missingRoster' named by CODEX_CONSULT_ROSTER does not exist; unset CODEX_CONSULT_ROSTER to use <codex home>/codex-consult-roster.json when it exists, or set it to none for no roster."
    $dm = Consult $r $missingRoster @('-DryRun', '-Prompt', 'x')
    $pidFileM = Join-Path $work 'file-missing.pid'
    $dmr = Consult $r $missingRoster @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFileM }
    $pm = Providers $r $missingRoster @()
    Check 'FILE' 'CODEX_CONSULT_ROSTER names a file that does not exist -> refused (dry run and real run: no child, no ledger), codex-providers exit 1' ($dm.Code -eq 1 -and $dm.First -eq $expMissing -and $dmr.Code -eq 1 -and $dmr.First -eq $expMissing -and -not (Test-Path $pidFileM) -and -not (Test-Path (Join-Path $r '.collab\t\sessions.json')) -and $pm.Code -eq 1 -and (($pm.Out -split "`n")[0]) -eq ($expMissing -replace '^codex-consult:', 'codex-providers:')) $dm.First
    $d0 = Consult $r $noRoster @('-DryRun', '-Prompt', 'x')
    Check 'FILE' 'CODEX_CONSULT_ROSTER=none -> no roster: no Roster line, ledger roster null, extra_config_source "", provider from codex default' ($d0.Code -eq 0 -and $d0.Out -notmatch '(?m)^Roster:' -and $d0.Preview.PSObject.Properties['roster'] -and $null -eq $d0.Preview.roster -and $d0.Preview.extra_config_source -eq '' -and $d0.Preview.reviewer.provider_source -eq 'codex default') (Line $d0.Out 'reviewer')
    $d1 = Consult $r '' @('-DryRun', '-Prompt', 'x')
    Check 'FILE' 'no CODEX_CONSULT_ROSTER and no <codex home>/codex-consult-roster.json -> the same, silently (and nothing is created)' ($d1.Code -eq 0 -and $null -eq $d1.Preview.roster -and $d1.Out -notmatch '(?m)^Roster:' -and $d1.Out -notmatch 'does not exist' -and -not (Test-Path (Join-Path $codexHome 'codex-consult-roster.json'))) ''
    $d2 = Consult $r $noRoster @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI')
    Check 'FILE' 'no roster: -Provider without -Model is refused as before' ($d2.Code -eq 1 -and $d2.First -eq 'codex-consult: -Provider needs -Model: the bridge cannot know which model a provider serves by default (e.g. -Provider ZAI -Model <model>).') $d2.First
    $bad = [ordered]@{
        'corrupt'   = @('{"roster_version":1,"reviewers":[', 'it does not parse')
        'version2'  = @('{"roster_version":2,"reviewers":[{"provider":"ZAI"}]}', 'roster_version must be 1 \(got 2\)')
        'duplicate' = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo"},{"provider":"ZAI","model":"glm-5.3"}]}', 'entries 1 and 3 are the same reviewer ZAI :: glm-5\.3')
        'unknownkey' = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","modle":"glm-5.3"}]}', "entry 1 has an unknown key 'modle'")
        'topkey'    = @('{"roster_version":1,"reviewers":[{"provider":"ZAI"}],"extra":true}', "unknown key 'extra' at the top level")
        'empty'     = @('{"roster_version":1,"reviewers":[]}', 'reviewers is empty')
        'notarray'  = @('{"roster_version":1,"reviewers":{"provider":"ZAI"}}', 'reviewers is not an array')
        'noprov'    = @('{"roster_version":1,"reviewers":[{"model":"glm-5.3"}]}', 'entry 1 needs a provider')
        'auth'      = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","auth":"key"}]}', 'entry 1: auth may only be "none"')
        'cfgkey'    = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","codex_config":["model=x"]}]}', "entry 1: codex_config 'model=x' is refused: model is part of the reviewer identity")
        'cfgtype'   = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","codex_config":"a=b"}]}', 'entry 1: codex_config must be an array of key=value strings')
    }
    $failed = @()
    foreach ($k in $bad.Keys) {
        $path = Write-Roster "bad-$k" $bad[$k][0]
        $o = Consult $r $path @('-DryRun', '-Prompt', 'x')
        $want = '^codex-consult: the reviewer roster ''' + [regex]::Escape($path) + ''' is not usable: ' + $bad[$k][1]
        if (-not ($o.Code -eq 1 -and $o.First -match $want)) { $failed += "$k -> $($o.First)" }
    }
    Check 'FILE' "unusable roster files refused (-DryRun too), message names the path: $(@($bad.Keys) -join ', ')" ($failed.Count -eq 0) ($failed -join ' | ')
    $bad2 = Write-Roster 'bad-real' '{"roster_version":2,"reviewers":[{"provider":"ZAI"}]}'
    $pidFile = Join-Path $work 'file-real.pid'
    $o2 = Consult $r $bad2 @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFile }
    Check 'FILE' 'a real run with an unusable roster is refused even with -Provider: no child, no ledger, no pending record' ($o2.Code -eq 1 -and $o2.First -match 'is not usable: roster_version must be 1' -and -not (Test-Path $pidFile) -and -not (Test-Path (Join-Path $r '.collab\t\sessions.json')) -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) $o2.First
    $home2 = Join-Path $codexHome 'codex-consult-roster.json'
    [IO.File]::WriteAllText($home2, '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"}]}', $u8)
    $o3 = Consult $r '' @('-DryRun', '-Prompt', 'x')
    $o4 = Consult $r 'none' @('-DryRun', '-Prompt', 'x')
    Remove-Item $home2
    Check 'FILE' 'CODEX_CONSULT_ROSTER=none ignores an existing default roster file too' ($o4.Code -eq 0 -and $null -eq $o4.Preview.roster -and $o4.Preview.reviewer.provider -eq 'openai') (Line $o4.Out 'reviewer')
    Check 'FILE' 'default path <codex home>/codex-consult-roster.json is read when CODEX_CONSULT_ROSTER is unset' ($o3.Code -eq 0 -and $o3.Preview.reviewer.provider -eq 'ZAI' -and $o3.Preview.roster.path -eq $home2) (Line $o3.Out 'Roster:')
}

# =============================================================== WALK: rule 3 - the first available entry
if (Want 'WALK') {
    $roster2 = Write-Roster 'zai-mimo' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
    $r = New-Repo 'walk'
    $log = Join-Path $work 'walk-log.txt'
    $x = Consult $r $roster2 @('-Prompt', 'x', '-ReplyName', 'walk') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log; RT_ZAI_KEY = '' }
    $e = Last-Entry $r
    $args1 = ([IO.File]::ReadAllText($log) -split "`n")[0]
    $md = [IO.File]::ReadAllText((Join-Path $r ".collab\t\$($e.reply)"), $u8)
    $expLine = "Roster: $roster2 - position 2 of 2; skipped ZAI :: glm-5.3 (missing: env RT_ZAI_KEY not set)"
    Check 'WALK' 'env key of entry 1 missing -> entry 2 selected: reviewer mimo from roster, argv -c model_provider="mimo", ledger roster {path, position 2, skipped [ZAI missing], applied [model]}' ($x.Code -eq 0 -and $e.reviewer.provider -eq 'mimo' -and $e.reviewer.model -eq 'mimo-v2.6-pro' -and $e.reviewer.provider_source -eq 'roster' -and $e.reviewer.model_source -eq 'roster' -and $e.command.Contains('-c model_provider="mimo"') -and $args1.Contains('model_provider=""mimo""') -and $e.roster.path -eq $roster2 -and $e.roster.position -eq 2 -and @($e.roster.skipped).Count -eq 1 -and $e.roster.skipped[0].provider -eq 'ZAI' -and $e.roster.skipped[0].model -eq 'glm-5.3' -and $e.roster.skipped[0].reason -eq 'missing: env RT_ZAI_KEY not set' -and (@($e.roster.applied) -join ',') -eq 'model') ($e.roster | ConvertTo-Json -Compress -Depth 5)
    Check 'WALK' 'console and handoff header carry the Roster line' ($x.Out.Contains($expLine) -and $md.Contains($expLine + '.')) (Line $x.Out 'Roster:')
    $names = ($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
    Check 'WALK' 'ledger order: roster and panel after preflight_warning, extra_config_source after extra_config, schema_transport_source after schema_transport; panel null outside a panel' ($names -match 'preflight_warning,roster,panel,parent_thread' -and $null -eq $e.panel -and $names -match 'extra_config,extra_config_source,peak' -and $names -match 'schema_transport,schema_transport_source,validation_error') $names

    $r2 = New-Repo 'walk-none'
    $td2 = Join-Path $r2 '.collab\t'
    $pidFile = Join-Path $work 'walk-none.pid'
    $n = Consult $r2 $roster2 @('-Prompt', 'x', '-ReplyName', 'none') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFile; RT_ZAI_KEY = ''; RT_MIMO_KEY = '' }
    $expNone = "codex-consult: no reviewer of the roster '$roster2' is available; nothing was started: #1 ZAI :: glm-5.3 (missing: env RT_ZAI_KEY not set); #2 mimo :: mimo-v2.6-pro (missing: env RT_MIMO_KEY not set) (run codex-providers.ps1 for the full picture)"
    Check 'WALK' 'no entry available -> refusal listing every entry with its reason; no child, no ledger, no pending record, lock file untouched' ($n.Code -eq 1 -and $n.First -eq $expNone -and -not (Test-Path $pidFile) -and -not (Test-Path (Join-Path $td2 'sessions.json')) -and -not (Test-Path (Join-Path $td2 '.consult.pending.json')) -and -not (Test-Path (Join-Path $td2 '.consult.lock'))) $n.First
    $nd = Consult $r2 $roster2 @('-DryRun', '-Prompt', 'x') @{ RT_ZAI_KEY = ''; RT_MIMO_KEY = '' }
    Check 'WALK' '-DryRun with no entry available -> the same refusal (nothing to plan)' ($nd.Code -eq 1 -and $nd.First -eq $expNone) $nd.First
    $ns = Consult $r2 $roster2 @('-DryRun', '-Prompt', 'x', '-SkipPreflight') @{ RT_ZAI_KEY = ''; RT_MIMO_KEY = '' }
    Check 'WALK' '-SkipPreflight -> the first entry unchecked, preflight "skipped", nothing skipped' ($ns.Code -eq 0 -and $ns.Preview.reviewer.provider -eq 'ZAI' -and $ns.Preview.preflight -eq 'skipped' -and @($ns.Preview.roster.skipped).Count -eq 0 -and $ns.Out.Contains("Roster: $roster2 - position 1 of 2 (-SkipPreflight: taken unchecked)")) (Line $ns.Out 'Roster:')
    $nm = Consult $r2 $roster2 @('-DryRun', '-Prompt', 'x', '-Model', 'mimo-v2.6-pro')
    Check 'WALK' '-Model without -Provider restricts the walk to entries of that model (ZAI is not considered, not skipped)' ($nm.Code -eq 0 -and $nm.Preview.reviewer.provider -eq 'mimo' -and $nm.Preview.reviewer.model_source -eq '-Model' -and @($nm.Preview.roster.skipped).Count -eq 0 -and $nm.Preview.roster.position -eq 2) (Line $nm.Out 'Roster:')
    $nx = Consult $r2 $roster2 @('-DryRun', '-Prompt', 'x', '-Model', 'gpt-5.1')
    Check 'WALK' '-Model that no entry resolves to -> refused, naming the roster' ($nx.Code -eq 1 -and $nx.First -match "^codex-consult: -Model gpt-5\.1: no entry of the reviewer roster '.*' resolves to that model") $nx.First

    # an entry without a model resolves the model as without a roster (the config's model)
    $rosterNoModel = Write-Roster 'openai-nomodel' '{"roster_version":1,"reviewers":[{"provider":"openai"}]}'
    $om = Consult $r2 $rosterNoModel @('-DryRun', '-Prompt', 'x')
    Check 'WALK' 'entry without model -> the config model (model_source config), applied []' ($om.Code -eq 0 -and $om.Preview.reviewer.model -eq 'gpt-5.1' -and $om.Preview.reviewer.model_source -eq 'config' -and $om.Preview.reviewer.provider_source -eq 'roster' -and @($om.Preview.roster.applied).Count -eq 0) (Line $om.Out 'reviewer')
}

# =============================================================== QUOTA: known reset times in the roster walk and the preflight
if (Want 'QUOTA') {
    $roster3 = Write-Roster 'openai-zai' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'
    $until = Iso $now.AddDays(4)
    # (a) retry_after recorded in ANOTHER task's ledger
    $r = New-Repo 'quota-field'
    Seed-Task $r 'other' @((New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now 10 'failed: codex exit 1 - limit' ([pscustomobject]@{ class = 'quota'; code = ''; message = 'limit'; when = (Iso $now.AddMinutes(-10)); retry_after = $until })))
    $a = Consult $r $roster3 @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'QUOTA' 'future provider_failure.retry_after in another task -> openai skipped "usage limit until <iso>", ZAI selected' ($a.Code -eq 0 -and $a.Preview.reviewer.provider -eq 'ZAI' -and $a.Preview.roster.skipped[0].reason -eq "usage limit until $until" -and $a.Out.Contains("Roster: $roster3 - position 2 of 2; skipped openai :: gpt-5.1 (usage limit until $until)")) (Line $a.Out 'Roster:')
    $ae = Consult $r $roster3 @('-Prompt', 'x', '-Provider', 'openai', '-Model', 'gpt-5.1', '-ReplyName', 'refused') @{ CODEX_CONSULT_NOW = $nowIso; FAKE_CODEX_REPLY = $advise }
    Check 'QUOTA' '... and an explicit -Provider openai is refused until then (exact message), nothing recorded' ($ae.Code -eq 1 -and $ae.First -eq "codex-consult: provider openai is not usable: its usage limit (hit at $(Iso $now.AddMinutes(-10)): limit) lasts until $until; nothing was started (pass -SkipPreflight to launch anyway)" -and -not (Test-Path (Join-Path $r '.collab\t\sessions.json'))) $ae.First
    $ad = Consult $r $roster3 @('-DryRun', '-Prompt', 'x', '-Provider', 'openai', '-Model', 'gpt-5.1') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'QUOTA' '-DryRun -Provider openai: preflight label unavailable (usage limit until <iso>), ledger preflight "unavailable: usage limit until <iso>", no warning' ($ad.Code -eq 0 -and $ad.Out -match ('preflight   : unavailable \(usage limit until ' + [regex]::Escape($until) + '\) - a real run is refused') -and $ad.Preview.preflight -eq "unavailable: usage limit until $until" -and $ad.Preview.preflight_warning -eq '') (Line $ad.Out 'preflight')
    $as = Consult $r $roster3 @('-DryRun', '-Prompt', 'x', '-Provider', 'openai', '-Model', 'gpt-5.1', '-SkipPreflight') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'QUOTA' '-SkipPreflight: not refused, warns that the limit lasts until <iso>' ($as.Code -eq 0 -and $as.Preview.preflight_warning -eq "provider openai hit a usage limit 10 min ago that lasts until ${until}: limit") $as.Preview.preflight_warning
    # the frozen clock matters: 5 days later the reset time has passed
    $later = Iso $now.AddDays(5)
    $al = Consult $r $roster3 @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = $later }
    Check 'QUOTA' 'CODEX_CONSULT_NOW 5 days later -> the reset time has passed: openai selected again' ($al.Code -eq 0 -and $al.Preview.reviewer.provider -eq 'openai' -and @($al.Preview.roster.skipped).Count -eq 0) (Line $al.Out 'Roster:')

    # (b) reset time only in the message (older entry without the field), 2 h old
    $r2 = New-Repo 'quota-msg'
    Seed-Task $r2 'other' @((New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now 120 "failed: codex exit 1 - $codexLimit" ([pscustomobject]@{ class = 'quota'; code = ''; message = $codexLimit; when = (Iso $now.AddMinutes(-120)) })))
    $b = Consult $r2 $roster3 @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'QUOTA' 'reset time only in the message (no retry_after field), 120 min old -> still skipped until 2026-09-28T20:35' ($b.Code -eq 0 -and $b.Preview.reviewer.provider -eq 'ZAI' -and $b.Preview.roster.skipped[0].reason -eq "usage limit until $codexLimitIso") (Line $b.Out 'Roster:')

    # (c) retry_after in the past -> not skipped, no warning
    $r3 = New-Repo 'quota-past'
    Seed-Task $r3 'other' @((New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now 30 'failed: codex exit 1 - limit' ([pscustomobject]@{ class = 'quota'; code = ''; message = 'limit'; when = (Iso $now.AddMinutes(-30)); retry_after = (Iso $now.AddMinutes(-5)) })))
    $c = Consult $r3 $roster3 @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'QUOTA' 'retry_after in the past (30 min old failure) -> openai selected, no skip, no warning' ($c.Code -eq 0 -and $c.Preview.reviewer.provider -eq 'openai' -and @($c.Preview.roster.skipped).Count -eq 0 -and $c.Preview.preflight_warning -eq '') (Line $c.Out 'Roster:')

    # (d) quota WITHOUT a reset time, 10 min old: the walk skips, an explicit -Provider warns and runs
    $r4 = New-Repo 'quota-noreset'
    Seed-Task $r4 'other' @((New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now 10 'failed: codex exit 1 - credits exhausted' ([pscustomobject]@{ class = 'quota'; code = ''; message = 'credits exhausted'; when = '' })))
    $d = Consult $r4 $roster3 @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = $nowIso }
    # (wave 24, T3/D14) the shared verdict's wording: out for 60 minutes after the limit was hit
    $noResetReason = "usage limit hit $(Iso $now.AddMinutes(-10)), reset unknown; retry after $(Iso $now.AddMinutes(50))"
    Check 'QUOTA' 'quota without a reset time 10 min ago -> the walk skips openai ("usage limit hit <iso>, reset unknown; retry after <iso + 60 min>")' ($d.Code -eq 0 -and $d.Preview.reviewer.provider -eq 'ZAI' -and $d.Preview.roster.skipped[0].reason -eq $noResetReason) (Line $d.Out 'Roster:')
    $dn = Consult $r4 $noRoster @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'QUOTA' '... and without a roster: the existing warning only' ($dn.Code -eq 0 -and $dn.Preview.reviewer.provider -eq 'openai' -and $dn.Preview.preflight_warning -eq 'provider openai hit a usage limit 10 min ago: credits exhausted') $dn.Preview.preflight_warning
    $dAll = Write-Roster 'openai-only' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"}]}'
    $dz = Consult $r4 $dAll @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'QUOTA' 'nothing else to fall back to -> refused with that reason' ($dz.Code -eq 1 -and $dz.First.Contains("#1 openai :: gpt-5.1 ($noResetReason)")) $dz.First
    # (a real run records a ledger entry stamped with the REAL clock - later than the frozen
    # one, so it counts as now and would clear the limit: it runs last)
    $dx = Consult $r4 $roster3 @('-Prompt', 'x', '-Provider', 'openai', '-Model', 'gpt-5.1', '-ReplyName', 'explicit') @{ CODEX_CONSULT_NOW = $nowIso; FAKE_CODEX_REPLY = $advise }
    $de = Last-Entry $r4
    Check 'QUOTA' '... an explicit -Provider openai only warns and runs; Roster line "entry 1 of 2 for -Provider openai (nothing applied)"' ($dx.Code -eq 0 -and $dx.Out -match 'WARNING: provider openai hit a usage limit 10 min ago: credits exhausted' -and $de.preflight_warning -eq 'provider openai hit a usage limit 10 min ago: credits exhausted' -and $dx.Out.Contains("Roster: $roster3 - entry 1 of 2 for -Provider openai (nothing applied)") -and $de.roster.position -eq 1) (Line $dx.Out 'Roster:')

    # (e) F15-4: failures stamped 6 min in the FUTURE count as now
    $r5 = New-Repo 'quota-future'
    Seed-Task $r5 'other' @((New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now -6 'failed: codex exit 1 - credits exhausted' ([pscustomobject]@{ class = 'quota'; code = ''; message = 'credits exhausted'; when = '' })))
    $f1 = Consult $r5 $roster3 @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'F15-4' 'a quota failure stamped 6 min in the future, no reset time -> it counts as now: the roster skips openai ("usage limit hit <now>, reset unknown; retry after <now + 60 min>")' ($f1.Code -eq 0 -and $f1.Preview.reviewer.provider -eq 'ZAI' -and $f1.Preview.roster.skipped[0].reason -eq "usage limit hit $nowIso, reset unknown; retry after $(Iso $now.AddMinutes(60))") (Line $f1.Out 'Roster:')
    $r6f = New-Repo 'auth-future'
    Seed-Task $r6f 'other' @((New-SeedEntry 1 'openai' 'gpt-5.1' $builtinFp $now -6 'failed: codex exit 1 - 401 Unauthorized' ([pscustomobject]@{ class = 'auth'; code = ''; message = '401 Unauthorized'; when = '' })))
    $f2 = Consult $r6f $noRoster @('-Prompt', 'x', '-ReplyName', 'fut') @{ CODEX_CONSULT_NOW = $nowIso; FAKE_CODEX_REPLY = $advise }
    $f2p = Providers $r6f $noRoster @('-Provider', 'openai') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'F15-4' 'an auth failure stamped 6 min in the future -> refused as unauthenticated; codex-providers -Provider openai exit 2' ($f2.Code -eq 1 -and $f2.First -match '^codex-consult: provider openai is not usable: the last run on this endpoint was rejected as unauthenticated at ' -and $f2p.Code -eq 2) $f2.First

    # codex-providers.ps1 with a roster
    $roster4 = Write-Roster 'three' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
    $pj = Providers $r $roster4 @('-Json') @{ CODEX_CONSULT_NOW = $nowIso }
    $by = @{}
    foreach ($row in @($pj.Json)) { $by[$row.name] = $row }
    Check 'PROV' 'codex-providers -Json: openai roster_position 1, not selected, unavailable (usage limit until <iso>), last_failure.retry_after; ZAI position 2 selected; local null/false' ($pj.Code -eq 0 -and $by.openai.roster_position -eq 1 -and $by.openai.roster_selected -eq $false -and $by.openai.verdict -eq "unavailable (usage limit until $until)" -and $by.openai.last_failure.retry_after -eq $until -and $by.openai.last_limit.retry_after -eq $until -and $by.ZAI.roster_position -eq 2 -and $by.ZAI.roster_selected -eq $true -and $null -eq $by.local.roster_position -and $by.local.roster_selected -eq $false) "openai: $($by.openai.verdict)"
    $pt = Providers $r $roster4 @() @{ CODEX_CONSULT_NOW = $nowIso }
    $hdr = @($pt.Out -split "`n" | Where-Object { $_ -match '^VERDICT' })[0]
    $oline = @($pt.Out -split "`n" | Where-Object { $_ -match '^unavailable.*\bopenai\b' })[0]
    Check 'PROV' 'table: ROSTER column after PROVIDER, LAST FAILURE "quota until <iso>", final line "roster: <path> -> would select ZAI :: glm-5.3 (skipped: ...)"' ($pt.Code -eq 0 -and $hdr -match '^VERDICT\s+PROVIDER\s+ROSTER\s+KIND\s+ENDPOINT' -and $oline -match ('quota until ' + [regex]::Escape($until) + ': ') -and $pt.Out.Contains("roster: $roster4 -> would select ZAI :: glm-5.3 (skipped: openai :: gpt-5.1 (usage limit until $until))")) ((($pt.Out -split "`n") | Where-Object { $_ -match '^roster:' }) -join '')
    $po = Providers $r $roster4 @('-Provider', 'openai') @{ CODEX_CONSULT_NOW = $nowIso }
    $pz = Providers $r $roster4 @('-Provider', 'ZAI') @{ CODEX_CONSULT_NOW = $nowIso }
    Check 'PROV' 'exit codes with -Provider: openai (future reset) 2, ZAI 0' ($po.Code -eq 2 -and $pz.Code -eq 0) "openai=$($po.Code) ZAI=$($pz.Code)"
    $pn = Providers $r $roster4 @() @{ CODEX_CONSULT_NOW = $nowIso; RT_ZAI_KEY = ''; RT_MIMO_KEY = '' }
    Check 'PROV' 'nothing available -> "roster: <path> -> no entry is available"' ($pn.Out -match ('(?m)^roster: ' + [regex]::Escape($roster4) + ' -> no entry is available')) ((($pn.Out -split "`n") | Where-Object { $_ -match '^roster:' }) -join '')
    $pNo = Providers $r $noRoster @('-Json')
    Check 'PROV' 'without a roster: roster_position null, roster_selected false, no roster line' ($pNo.Code -eq 0 -and @($pNo.Json | Where-Object { $null -ne $_.roster_position -or $_.roster_selected }).Count -eq 0) ''
    $pBad = Providers $r (Write-Roster 'prov-bad' '{"roster_version":1}') @()
    Check 'PROV' 'an unusable roster -> codex-providers refuses too (exit 1)' ($pBad.Code -eq 1 -and $pBad.Out -match "codex-providers: the reviewer roster '.*' is not usable: reviewers is missing") (($pBad.Out -split "`n") | Select-Object -First 1)
}

# =============================================================== RULES: -Provider (rule 1), -Thread (rule 2), auto fork of the selected lineage
if (Want 'RULES') {
    $roster5 = Write-Roster 'openai-mimo' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"mimo","model":"mimo-v2.6-pro","codex_config":["model_catalog_json=~/.codex/model-catalogs.json"]}]}'
    $homeFwd = ($(if ($HOME) { $HOME } else { $env:USERPROFILE })).TrimEnd([char]'\', [char]'/') -replace '\\', '/'
    $catalog = 'model_catalog_json="' + $homeFwd + '/.codex/model-catalogs.json"'
    $r = New-Repo 'rules'
    # rule 1: -Provider mimo without -Model -> the roster entry supplies model + codex_config
    $m = Consult $r $roster5 @('-Prompt', 'x', '-Provider', 'mimo', '-ReplyName', 'mimo') @{ FAKE_CODEX_REPLY = $advise }
    $me = Last-Entry $r
    Check 'RULE1' '-Provider mimo (no -Model, no -CodexConfig) -> model and codex_config from the roster; sources recorded' ($m.Code -eq 0 -and $me.reviewer.provider -eq 'mimo' -and $me.reviewer.provider_source -eq '-Provider' -and $me.reviewer.model -eq 'mimo-v2.6-pro' -and $me.reviewer.model_source -eq 'roster' -and @($me.extra_config)[0] -eq $catalog -and $me.extra_config_source -eq 'roster' -and (@($me.roster.applied) -join ',') -eq 'model,codex_config' -and $me.roster.position -eq 2 -and @($me.roster.skipped).Count -eq 0 -and $m.Out.Contains("Roster: $roster5 - entry 2 of 2 for -Provider mimo (model, codex_config applied)")) (Line $m.Out 'Roster:')
    $tMimo = [string]$me.thread
    $p1 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v2.6-flash', '-CodexConfig', 'hide_agent_reasoning=true')
    Check 'RULE1' '-Provider mimo -Model x -CodexConfig y -> nothing applied, sources -Model / -CodexConfig' ($p1.Code -eq 0 -and $p1.Preview.reviewer.model -eq 'mimo-v2.6-flash' -and $p1.Preview.reviewer.model_source -eq '-Model' -and $p1.Preview.extra_config_source -eq '-CodexConfig' -and (@($p1.Preview.extra_config) -join ',') -eq 'hide_agent_reasoning=true' -and @($p1.Preview.roster.applied).Count -eq 0 -and $p1.Out.Contains("Roster: $roster5 - entry 2 of 2 for -Provider mimo (nothing applied)")) (Line $p1.Out 'Roster:')
    $p2 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v2.6-flash')
    Check 'RULE1' '-Provider mimo -Model x (no -CodexConfig) -> only codex_config applied' ($p2.Code -eq 0 -and $p2.Preview.reviewer.model_source -eq '-Model' -and $p2.Preview.extra_config_source -eq 'roster' -and (@($p2.Preview.roster.applied) -join ',') -eq 'codex_config') (Line $p2.Out 'Roster:')
    $p3 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3')
    Check 'RULE1' '-Provider with no roster entry -> used as given, position null, "no entry for -Provider ZAI"' ($p3.Code -eq 0 -and $p3.Preview.reviewer.provider -eq 'ZAI' -and $null -eq $p3.Preview.roster.position -and $p3.Out.Contains("Roster: $roster5 - no entry for -Provider ZAI (nothing applied)")) (Line $p3.Out 'Roster:')
    $p4 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI')
    Check 'RULE1' '-Provider without -Model and without a roster model -> the old refusal' ($p4.Code -eq 1 -and $p4.First -match '^codex-consult: -Provider needs -Model') $p4.First

    # an openai thread (the walk picks openai first)
    $o = Consult $r $roster5 @('-Prompt', 'x', '-ReplyName', 'openai') @{ FAKE_CODEX_REPLY = $advise }
    $oe = Last-Entry $r
    $tOpenai = [string]$oe.thread
    Check 'AUTO' 'walk -> openai (position 1), a new thread (no openai thread yet; the mimo thread is not its lineage)' ($o.Code -eq 0 -and $oe.reviewer.provider -eq 'openai' -and $oe.mode -eq 'new' -and $oe.roster.position -eq 1 -and $tOpenai) "mode=$($oe.mode)"
    $a1 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x')
    Check 'AUTO' 'next walk -> openai again, auto-fork of the NEWEST openai thread' ($a1.Code -eq 0 -and $a1.Preview.mode -eq 'fork' -and $a1.Preview.parent_thread -eq $tOpenai) "parent=$($a1.Preview.parent_thread)"
    $a2 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x') @{ FAKE_CODEX_LOGIN = 'out' }
    Check 'AUTO' 'openai logged out -> the walk selects mimo and forks the newest MIMO thread' ($a2.Code -eq 0 -and $a2.Preview.reviewer.provider -eq 'mimo' -and $a2.Preview.mode -eq 'fork' -and $a2.Preview.parent_thread -eq $tMimo -and $a2.Preview.roster.skipped[0].reason -eq 'missing: Not logged in') "parent=$($a2.Preview.parent_thread) skipped=$($a2.Preview.roster.skipped[0].reason)"

    # rule 2: -Thread fixes the identity; the roster supplies codex_config
    $t1 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x', '-Thread', $tMimo)
    Check 'RULE2' '-Thread <mimo thread> -> reviewer mimo :: mimo-v2.6-pro from the thread (sources -Thread), codex_config from the roster, fork of that thread' ($t1.Code -eq 0 -and $t1.Preview.reviewer.provider -eq 'mimo' -and $t1.Preview.reviewer.model -eq 'mimo-v2.6-pro' -and $t1.Preview.reviewer.provider_source -eq '-Thread' -and $t1.Preview.reviewer.model_source -eq '-Thread' -and @($t1.Preview.extra_config)[0] -eq $catalog -and $t1.Preview.extra_config_source -eq 'roster' -and (@($t1.Preview.roster.applied) -join ',') -eq 'codex_config' -and $t1.Preview.mode -eq 'fork' -and $t1.Preview.parent_thread -eq $tMimo -and $t1.Out.Contains("Roster: $roster5 - entry 2 of 2 for -Thread $tMimo, mimo :: mimo-v2.6-pro (codex_config applied)")) (Line $t1.Out 'Roster:')
    $t1r = Consult $r $roster5 @('-Prompt', 'x', '-Thread', $tMimo, '-Mode', 'resume', '-ReplyName', 'resume') @{ FAKE_CODEX_REPLY = $advise }
    Check 'RULE2' '... a real resume of it runs; ledger mode resume, parent the mimo thread' ($t1r.Code -eq 0 -and (Last-Entry $r).mode -eq 'resume' -and (Last-Entry $r).parent_thread -eq $tMimo) ''
    $t2 = Consult $r $roster5 @('-Prompt', 'x', '-Thread', $tMimo, '-ReplyName', 'blocked') @{ FAKE_CODEX_REPLY = $advise; RT_MIMO_KEY = '' }
    Check 'RULE2' 'the thread''s provider is unavailable -> refused, naming what the roster would select for a new thread' ($t2.Code -eq 1 -and $t2.First -eq 'codex-consult: provider mimo is not usable: env RT_MIMO_KEY not set; nothing was started (run codex-providers.ps1 for the full picture); to continue with another reviewer, start a new thread: -Mode new; the roster would select openai :: gpt-5.1') $t2.First
    $t3 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x', '-Thread', '00000000-0000-0000-0000-000000000000')
    Check 'RULE2' 'an unknown thread -> the unknown-provenance refusal' ($t3.Code -eq 1 -and $t3.First -eq "codex-consult: thread 00000000-0000-0000-0000-000000000000 has unknown provenance: it is not in this task's ledger; use -Mode new") $t3.First
    $t4 = Consult $r $roster5 @('-DryRun', '-Prompt', 'x', '-Thread', $tMimo, '-Provider', 'openai', '-Model', 'gpt-5.1')
    Check 'RULE2' '-Thread with an explicit -Provider of another lineage -> rule 1 applies and the lineage check refuses' ($t4.Code -eq 1 -and $t4.First -match "thread $tMimo belongs to lineage mimo :: mimo-v2\.6-pro") $t4.First
}

# =============================================================== AUTH: "auth": "none"
if (Want 'AUTH') {
    $r = New-Repo 'auth'
    $rA = Write-Roster 'local-anon' '{"roster_version":1,"reviewers":[{"provider":"local","model":"m1","auth":"none"}]}'
    $a = Consult $r $rA @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high')
    Check 'AUTH' 'auth none on a table without env_key -> "ok: declared anonymous in the roster"' ($a.Code -eq 0 -and $a.Preview.reviewer.provider -eq 'local' -and $a.Preview.preflight -eq 'ok: declared anonymous in the roster' -and $a.Out -match 'preflight   : available \(ok: declared anonymous in the roster\)') (Line $a.Out 'preflight')
    $rB = Write-Roster 'local-plain' '{"roster_version":1,"reviewers":[{"provider":"local","model":"m1"}]}'
    $b = Consult $r $rB @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high')
    Check 'AUTH' 'without it -> missing (the only entry: refused)' ($b.Code -eq 1 -and $b.First -match '#1 local :: m1 \(missing: no env_key/bearer token in the table\)') $b.First
    $rC = Write-Roster 'zai-anon' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","auth":"none"}]}'
    $c = Consult $r $rC @('-DryRun', '-Prompt', 'x') @{ RT_ZAI_KEY = '' }
    Check 'AUTH' 'auth none on a table WITH env_key -> the variable is still required' ($c.Code -eq 1 -and $c.First -match '#1 ZAI :: glm-5\.3 \(missing: env RT_ZAI_KEY not set\)') $c.First
    $d = Consult $r $rA @('-DryRun', '-Prompt', 'x', '-Provider', 'local', '-NativeEffort', 'high')
    Check 'AUTH' '-Provider local: the entry''s auth none applies too (and its model)' ($d.Code -eq 0 -and $d.Preview.preflight -eq 'ok: declared anonymous in the roster' -and $d.Preview.reviewer.model -eq 'm1') $d.Preview.preflight
    $pj = Providers $r $rA @('-Json')
    Check 'AUTH' 'codex-providers: local available (ok: declared anonymous in the roster), selected' (@($pj.Json | Where-Object { $_.name -eq 'local' -and $_.credentials -eq 'ok: declared anonymous in the roster' -and $_.verdict -eq 'available' -and $_.roster_selected }).Count -eq 1) ''
}

# =============================================================== SCHEMA: -SchemaTransport
if (Want 'SCHEMA') {
    $r = New-Repo 'schema'
    $a = Consult $r $noRoster @('-DryRun', '-Prompt', 'x', '-SchemaTransport', 'prompt-only')
    Check 'SCHEMA' '-SchemaTransport prompt-only on the builtin openai -> no --output-schema, schema in the prompt, ledger prompt-only / -SchemaTransport, dry run says so' ($a.Code -eq 0 -and $a.Preview.command -notmatch '--output-schema' -and $a.Preview.schema_transport -eq 'prompt-only' -and $a.Preview.schema_transport_source -eq '-SchemaTransport' -and $a.Out.Contains('JSON Schema of the reply:') -and $a.Out -match 'transport   : prompt-only \(-SchemaTransport; caps-v1: builtin:openai would use output-schema\)') (Line $a.Out 'transport')
    $b = Consult $r $noRoster @('-DryRun', '-Prompt', 'x')
    $c = Consult $r $noRoster @('-DryRun', '-Prompt', 'x', '-Raw')
    Check 'SCHEMA' 'default -> schema_transport_source caps-v1; -Raw -> ""' ($b.Preview.schema_transport -eq 'output-schema' -and $b.Preview.schema_transport_source -eq 'caps-v1' -and $c.Preview.schema_transport -eq '' -and $c.Preview.schema_transport_source -eq '') "$($b.Preview.schema_transport_source) / '$($c.Preview.schema_transport_source)'"
    $d = Consult $r $noRoster @('-DryRun', '-Prompt', 'x', '-SchemaTransport', 'json')
    $e = Consult $r $noRoster @('-DryRun', '-Prompt', 'x', '-SchemaTransport', 'prompt-only', '-Raw')
    Check 'SCHEMA' 'an invalid value and -Raw are refused' ($d.Code -eq 1 -and $d.First -match "^codex-consult: -SchemaTransport must be output-schema or prompt-only \(got 'json'\)" -and $e.Code -eq 1 -and $e.First -match '^codex-consult: -SchemaTransport does not apply to -Raw') "$($d.First) | $($e.First)"
    $f = Consult $r $noRoster @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-SchemaTransport', 'output-schema')
    Check 'SCHEMA' '-SchemaTransport output-schema on MiMo (prompt-only by caps-v1) -> --output-schema passed' ($f.Code -eq 0 -and $f.Preview.command -match '--output-schema ' -and $f.Preview.schema_transport_source -eq '-SchemaTransport') ''
    $log = Join-Path $work 'schema-log.txt'
    $x = Consult $r $noRoster @('-Prompt', 'x', '-SchemaTransport', 'prompt-only', '-ReplyName', 'po') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log }
    $xe = Last-Entry $r
    Check 'SCHEMA' 'real run: codex gets no --output-schema; ledger schema_transport prompt-only, schema_transport_source -SchemaTransport' ($x.Code -eq 0 -and ([IO.File]::ReadAllText($log) -split "`n")[0] -notmatch '--output-schema' -and $xe.schema_transport -eq 'prompt-only' -and $xe.schema_transport_source -eq '-SchemaTransport' -and $xe.structured -eq $true) ''
}

# =============================================================== UTF8: codex's stderr and `login status` decoded as UTF-8
if (Want 'UTF8') {
    $r = New-Repo 'utf8'
    # a reset time a few days ahead of the REAL clock (this case records a real failure)
    $resetAt = (Get-Date).Date.AddDays(3).AddHours(20).AddMinutes(35)
    $day = $resetAt.Day
    $suffix = if ($day -in 11, 12, 13) { 'th' } elseif ($day % 10 -eq 1) { 'st' } elseif ($day % 10 -eq 2) { 'nd' } elseif ($day % 10 -eq 3) { 'rd' } else { 'th' }
    $msg = "You${apos}ve hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro), visit https://chatgpt.com/codex/settings/usage to purchase more credits or try again at $($resetAt.ToString('MMM', $inv)) $day$suffix, $($resetAt.Year) $($resetAt.ToString('h:mm tt', $inv))."
    $x = Consult $r $noRoster @('-Prompt', 'x', '-ReplyName', 'limit') @{ FAKE_CODEX_STDERR = $msg; FAKE_CODEX_EXIT = '1' }
    $e = Last-Entry $r
    $bad = [string][char]0xFFFD
    $expectIso = Iso ([DateTimeOffset]$resetAt)
    Check 'UTF8' 'stderr in UTF-8 -> bridge_outcome and provider_failure.message keep the curly apostrophe (no U+FFFD); class quota; retry_after parsed' ($x.Code -eq 1 -and $e.bridge_outcome.Contains("You${apos}ve hit") -and $e.provider_failure.message.Contains("You${apos}ve hit") -and -not $e.bridge_outcome.Contains($bad) -and -not $e.provider_failure.message.Contains($bad) -and $e.provider_failure.class -eq 'quota' -and $e.provider_failure.retry_after -eq $expectIso) "$($e.provider_failure.message.Substring(0, 12)) / retry_after=$($e.provider_failure.retry_after)"
    $md = [IO.File]::ReadAllText((Join-Path $r ".collab\t\$($e.reply)"), $u8)
    Check 'UTF8' 'the handoff file carries the same text' ($md.Contains("Provider failure: quota - You${apos}ve hit your usage limit")) ''
    $y = Consult $r $noRoster @('-Prompt', 'x', '-ReplyName', 'again') @{ FAKE_CODEX_REPLY = $advise }
    Check 'UTF8' 'the next consultation on that endpoint is refused until the parsed reset time' ($y.Code -eq 1 -and $y.First -match ('^codex-consult: provider openai is not usable: its usage limit \(hit at .*\) lasts until ' + [regex]::Escape($expectIso))) $y.First
    # (read back from the ledger file: console output goes through the console code page)
    $rl = New-Repo 'utf8-login'
    $z = Consult $rl $noRoster @('-Prompt', 'x', '-ReplyName', 'login') @{ FAKE_CODEX_LOGIN = 'utf8'; FAKE_CODEX_REPLY = $advise }
    $loginLine = 'Logged in using ChatGPT ' + [char]0x2013 + ' J' + [char]0x00FC + 'rgen' + $apos + 's plan'
    $zp = if ($z.Code -eq 0) { [string](Last-Entry $rl).preflight } else { $z.First }
    Check 'UTF8' '`codex login status` output decoded as UTF-8 (en dash, u-umlaut, curly apostrophe survive into the ledger preflight)' ($z.Code -eq 0 -and $zp -eq "ok: $loginLine") ('ASCII-escaped: ' + (($zp.ToCharArray() | ForEach-Object { if ([int]$_ -gt 126) { 'U+{0:X4}' -f [int]$_ } else { [string]$_ } }) -join ''))
}

# =============================================================== PANEL: -Panel runs every available reviewer
if (Want 'PANEL') {
    $finding = '{"severity":"minor","locations":[{"path":"app.txt","line":1}],"claim":"c","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}'
    $adviseF = Reply 'advise-finding.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
    $roster6 = Write-Roster 'panel3' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo","model":"mimo-v2.6-pro"}]}'
    $r = New-Repo 'panel'
    $log = Join-Path $work 'panel-log.txt'
    $p1 = Consult $r $roster6 @('-Panel', '-Prompt', 'x', '-ReplyName', 'x') @{ FAKE_CODEX_REPLY = $adviseF; FAKE_CODEX_LOG = $log; RT_ZAI_KEY = '' }
    $led = @(Ledger $r)
    $e1 = $led[0]; $e2 = $led[1]
    $pid1 = [string]$e1.panel.id
    $m1 = ($e1.panel.members | ConvertTo-Json -Compress -Depth 5)
    $m2 = ($e2.panel.members | ConvertTo-Json -Compress -Depth 5)
    Check 'PANEL' '3 entries, ZAI unavailable -> 2 ledger entries, same panel.id, positions 1 and 2 of 2, identical members lists, exit 0' ($p1.Code -eq 0 -and $led.Count -eq 2 -and $pid1 -and [string]$e2.panel.id -eq $pid1 -and $e1.panel.position -eq 1 -and $e2.panel.position -eq 2 -and $e1.panel.of -eq 2 -and $e2.panel.of -eq 2 -and $m1 -eq $m2) $m1
    $mem = @($e1.panel.members)
    Check 'PANEL' 'members: openai run, ZAI skipped (missing: env RT_ZAI_KEY not set), mimo run - in roster order, fields provider/model/state/reason' ($mem.Count -eq 3 -and $mem[0].provider -eq 'openai' -and $mem[0].state -eq 'run' -and $mem[0].reason -eq '' -and $mem[1].provider -eq 'ZAI' -and $mem[1].state -eq 'skipped' -and $mem[1].reason -eq 'missing: env RT_ZAI_KEY not set' -and $mem[2].provider -eq 'mimo' -and $mem[2].model -eq 'mimo-v2.6-pro' -and $mem[2].state -eq 'run' -and (($mem[0].PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'provider,model,state,reason') ''
    Check 'PANEL' 'each member is its own consultation: reviewer from its roster entry, reply files suffixed by provider, own consult ids, roster record (position, skipped ZAI)' ($e1.reviewer.provider -eq 'openai' -and $e2.reviewer.provider -eq 'mimo' -and $e1.reply -match '^handoffs/\d\d-codex-x-openai\.md$' -and $e2.reply -match '^handoffs/\d\d-codex-x-mimo\.md$' -and $e1.consult_id -ne $e2.consult_id -and $e1.roster.position -eq 1 -and $e2.roster.position -eq 3 -and $e2.roster.skipped[0].provider -eq 'ZAI' -and $e1.reviewer.provider_source -eq 'roster' -and (Test-Path (Join-Path $r ".collab\t\$($e2.reply)"))) "$($e1.reply) / $($e2.reply)"
    $names = ($e1.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
    Check 'PANEL' 'ledger: panel right after roster' ($names -match 'preflight_warning,roster,panel,parent_thread') ''
    $prompt2 = [IO.File]::ReadAllText($log)
    Check 'PANEL' 'the second member is not shown the first member''s new finding (the prompt lists what was open when the panel started: nothing)' ($e1.finding_ids.Count -eq 1 -and $prompt2 -notmatch 'Findings from earlier consultations') "member 1 raised $(@($e1.finding_ids) -join ',')"
    $short = $pid1.Substring(0, 8)
    $sumAt = $p1.Out.LastIndexOf("Panel ${short}: 2 of 3 entries ran")
    $sum = if ($sumAt -ge 0) { $p1.Out.Substring($sumAt) } else { '' }
    $sl = @($sum -split "`n")
    Check 'PANEL' 'summary block: header, one line per entry (verdict, counts, prior, wall, reply file; skipped with its reason)' ($sumAt -ge 0 -and $sl[1] -match '^  openai :: gpt-5\.1\s+ADVISE\s+0 blocker, 0 major, 1 minor\s+prior: none\s+[0-9.]+ s  handoffs/\d\d-codex-x-openai\.md$' -and $sl[2] -match '^  ZAI :: glm-5\.3\s+skipped\s+missing: env RT_ZAI_KEY not set$' -and $sl[3] -match '^  mimo :: mimo-v2\.6-pro\s+ADVISE\s+0 blocker, 0 major, 1 minor\s+prior: none\s+[0-9.]+ s  handoffs/\d\d-codex-x-mimo\.md$') ($sl[0..3] -join ' | ')
    $tOpen = [string]$e1.thread; $tMimo = [string]$e2.thread

    # a second panel: every member forks the newest thread of its OWN lineage; -Mode new: new for all
    $p2 = Consult $r $roster6 @('-Panel', '-Prompt', 'x', '-ReplyName', 'y') @{ FAKE_CODEX_REPLY = $advise; RT_ZAI_KEY = '' }
    $led2 = @(Ledger $r)
    Check 'PANEL' 'second panel: openai forks the openai thread, mimo the mimo thread' ($p2.Code -eq 0 -and $led2.Count -eq 4 -and $led2[2].mode -eq 'fork' -and $led2[2].parent_thread -eq $tOpen -and $led2[3].mode -eq 'fork' -and $led2[3].parent_thread -eq $tMimo -and [string]$led2[2].panel.id -ne $pid1) "$($led2[2].parent_thread) / $($led2[3].parent_thread)"
    $p3 = Consult $r $roster6 @('-Panel', '-Prompt', 'x', '-ReplyName', 'z', '-Mode', 'new') @{ FAKE_CODEX_REPLY = $advise; RT_ZAI_KEY = '' }
    $led3 = @(Ledger $r)
    Check 'PANEL' '-Mode new -> new threads for all members' ($p3.Code -eq 0 -and $led3.Count -eq 6 -and $led3[4].mode -eq 'new' -and $led3[5].mode -eq 'new') ''
    $p4 = Consult $r $roster6 @('-Prompt', 'x', '-ReplyName', 'single') @{ FAKE_CODEX_REPLY = $advise; RT_ZAI_KEY = ''; FAKE_CODEX_LOG = $log }
    Check 'PANEL' 'a later single consultation lists the panel''s findings again (the baseline applies to panel members only)' ($p4.Code -eq 0 -and [IO.File]::ReadAllText($log) -match 'Findings from earlier consultations') ''

    # one member fails: the other still runs, exit 1
    $rf = New-Repo 'panel-fail'
    $pf = Consult $rf $roster6 @('-Panel', '-Prompt', 'x', '-ReplyName', 'f') @{ FAKE_CODEX_REPLY = $advise; RT_ZAI_KEY = ''; FAKE_CODEX_FAIL_ON = 'model_provider=""openai""' }
    $lf = @(Ledger $rf)
    $pfShort = if ($lf.Count -gt 0) { ([string]$lf[0].panel.id).Substring(0, 8) } else { '?' }
    $pfSum = @(($pf.Out.Substring([Math]::Max(0, $pf.Out.LastIndexOf("Panel ${pfShort}: 2 of 3 entries ran")))) -split "`n")
    Check 'PANEL' 'the first member''s codex fails -> the second still runs; the failed one is recorded as failed; exit 1; summary "failed: ..."' ($pf.Code -eq 1 -and $lf.Count -eq 2 -and $lf[0].bridge_outcome -match '^failed: codex exit 1' -and $lf[1].bridge_outcome -eq 'usable reply' -and $pfSum[1] -match '^  openai :: gpt-5\.1\s+failed: codex exit 1 - stream error: provider refused the request\s+[0-9.]+ s  handoffs/') ($pfSum[0..3] -join ' | ')

    # refusals
    $bad = @()
    foreach ($case in @(@('-Provider', 'openai', '-Model', 'gpt-5.1'), @('-Thread', $tOpen), @('-Mode', 'resume'))) {
        $o = Consult $r $roster6 (@('-Panel', '-DryRun', '-Prompt', 'x') + $case)
        if (-not ($o.Code -eq 1 -and $o.First -match '^codex-consult: -Panel ')) { $bad += "$($case[0]) -> $($o.First)" }
    }
    $o = Consult $r '' @('-Panel', '-DryRun', '-Prompt', 'x')
    if (-not ($o.Code -eq 1 -and $o.First -eq "codex-consult: -Panel needs a reviewer roster: '$(Join-Path $codexHome 'codex-consult-roster.json')' does not exist (CODEX_CONSULT_ROSTER, else <codex home>/codex-consult-roster.json).")) { $bad += "no roster -> $($o.First)" }
    $o = Consult $r 'none' @('-Panel', '-DryRun', '-Prompt', 'x')
    if (-not ($o.Code -eq 1 -and $o.First -eq 'codex-consult: -Panel needs a reviewer roster, and CODEX_CONSULT_ROSTER=none switches it off.')) { $bad += "none -> $($o.First)" }
    Check 'PANEL' '-Panel with -Provider / -Thread / -Mode resume, without a roster file, or with CODEX_CONSULT_ROSTER=none -> refused' ($bad.Count -eq 0) ($bad -join ' | ')
    $rb = New-Repo 'panel-brief'
    $pb = Consult $rb $roster6 @('-Panel', '-Brief', 'no-such-brief.md', '-ReplyName', 'b') @{ FAKE_CODEX_REPLY = $advise; RT_ZAI_KEY = '' }
    Check 'PANEL' 'a missing brief is refused once, before any member starts (no ledger)' ($pb.Code -eq 1 -and $pb.First -eq "codex-consult: brief 'no-such-brief.md' not found (this script never writes briefs; write it first)." -and -not (Test-Path (Join-Path $rb '.collab\t\sessions.json'))) $pb.First
    $none = Consult $r $roster6 @('-Panel', '-Prompt', 'x') @{ RT_ZAI_KEY = ''; RT_MIMO_KEY = ''; FAKE_CODEX_LOGIN = 'out' }
    Check 'PANEL' 'no entry available -> the A.3 refusal listing every entry' ($none.Code -eq 1 -and $none.First -match "^codex-consult: no reviewer of the roster '.*' is available; nothing was started: #1 openai :: gpt-5\.1 \(missing: Not logged in\); #2 ZAI :: glm-5\.3 \(missing: env RT_ZAI_KEY not set\); #3 mimo :: mimo-v2\.6-pro \(missing: env RT_MIMO_KEY not set\)") $none.First

    # F15-3: a member's timeout survivors hold the task's reservation -> the rest are not
    # started. (CODEX_CONSULT_TEST_SURVIVORS: nothing can make a real process outlive the kill.)
    # 0.4.x wave 21: the rule holds for a panel run one member after another (-PanelConcurrency
    # 1); the member's record is its own .consult.pending-<NN>.json.
    $rs = New-Repo 'panel-survivors'
    $sleeper = Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep -Seconds 180') -PassThru -WindowStyle Hidden
    try {
        $ps = Consult $rs $roster6 @('-Panel', '-PanelConcurrency', '1', '-Prompt', 'x', '-ReplyName', 's', '-TimeoutSec', '4') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""ZAI""'; CODEX_CONSULT_TEST_SURVIVORS = "$($sleeper.Id)" }
    } finally { Stop-Process -Id $sleeper.Id -Force -ErrorAction SilentlyContinue }
    $ls = @(Ledger $rs)
    $psShort = if ($ls.Count -gt 0) { ([string]$ls[0].panel.id).Substring(0, 8) } else { '?' }
    $psAt = $ps.Out.LastIndexOf("Panel ${psShort}: 2 of 3 entries ran")
    $psSum = if ($psAt -ge 0) { @($ps.Out.Substring($psAt) -split "`n") } else { @('') }
    Check 'F15-3' 'member 2 times out leaving survivors -> member 3 is NOT started (-PanelConcurrency 1): summary "skipped  not started: ...", header "2 of 3 entries ran", ledger has members 1 and 2 only, exit 1' ($ps.Code -eq 1 -and $ls.Count -eq 2 -and $ls[0].bridge_outcome -eq 'usable reply' -and $ls[1].bridge_outcome -match '^failed: timeout after 4 s \(process tree killed; 1 processes survived' -and $psAt -ge 0 -and $psSum[3] -match '^  mimo :: mimo-v2\.6-pro\s+skipped\s+not started: the previous member \(ZAI :: glm-5\.3\) left surviving processes \(\.consult\.pending-\d\d\.json state survivors\); recover the task first$') ($psSum[0..3] -join ' | ')
    $rt = New-Repo 'panel-timeout'
    $pt2 = Consult $rt $roster6 @('-Panel', '-Prompt', 'x', '-ReplyName', 't', '-TimeoutSec', '4') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_HANG_ON = 'model_provider=""ZAI""' }
    $lt = @(Ledger $rt)
    Check 'F15-3' 'a timeout WITHOUT survivors -> member 3 still runs; exit 1 (member 2 failed)' ($pt2.Code -eq 1 -and $lt.Count -eq 3 -and $lt[1].bridge_outcome -eq 'failed: timeout after 4 s (process tree killed)' -and $lt[2].reviewer.provider -eq 'mimo' -and $lt[2].bridge_outcome -eq 'usable reply') "$($lt.Count) entries"

    # -DryRun -Panel: the members and each plan, nothing written
    $rd = New-Repo 'panel-dry'
    $snapBefore = (@(Get-ChildItem -LiteralPath (Join-Path $rd '.collab') -Recurse -Force | ForEach-Object { $_.FullName }) | Sort-Object) -join '|'
    $pd = Consult $rd $roster6 @('-Panel', '-DryRun', '-Prompt', 'x', '-ReplyName', 'd') @{ RT_ZAI_KEY = '' }
    $snapAfter = (@(Get-ChildItem -LiteralPath (Join-Path $rd '.collab') -Recurse -Force | ForEach-Object { $_.FullName }) | Sort-Object) -join '|'
    $plans = ([regex]::Matches($pd.Out, 'DRY RUN - nothing was executed')).Count
    Check 'PANEL' '-DryRun -Panel: the member list, one dry-run plan per member (reply names suffixed), summary "planned", exit 0, nothing written' ($pd.Code -eq 0 -and $pd.First -match '^Panel [0-9a-f]{8} \(dry run - nothing is executed or written\): 2 of 3 roster entries would run' -and $plans -eq 2 -and $pd.Out -match 'codex-d-openai\.md' -and $pd.Out -match 'codex-d-mimo\.md' -and $pd.Out -match '(?m)^  openai :: gpt-5\.1\s+planned$' -and $snapBefore -eq $snapAfter) "plans=$plans"
}

# =============================================================== WEIGHT: "panel": "weighty" and -PanelAll; CHORE: the chore purpose
if (Want 'WEIGHT') {
    $roster7 = Write-Roster 'weighty' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"mimo","model":"mimo-v2.6-pro","panel":"weighty"}]}'
    $r = New-Repo 'weight'
    $w1 = Consult $r $roster7 @('-Panel', '-DryRun', '-Prompt', 'x', '-Purpose', 'diff-review')
    Check 'WEIGHT' '-Panel -Purpose diff-review -> the weighty entry is left out with its reason' ($w1.Code -eq 0 -and $w1.First -match ': 1 of 2 roster entries would run' -and $w1.Out -match '(?m)^  #2 mimo :: mimo-v2\.6-pro - skipped: weighty reviewer; purpose diff-review is light \(use -PanelAll\)$' -and $w1.Out -match '(?m)^  mimo :: mimo-v2\.6-pro\s+skipped\s+weighty reviewer; purpose diff-review is light \(use -PanelAll\)$') (Line $w1.Out '  #2')
    $w2 = Consult $r $roster7 @('-Panel', '-DryRun', '-Prompt', 'x', '-Purpose', 'acceptance')
    Check 'WEIGHT' '-Panel -Purpose acceptance -> both entries' ($w2.Code -eq 0 -and $w2.First -match ': 2 of 2 roster entries would run') $w2.First
    $w3 = Consult $r $roster7 @('-PanelAll', '-DryRun', '-Prompt', 'x', '-Purpose', 'diff-review')
    Check 'WEIGHT' '-PanelAll -Purpose diff-review -> both entries (implies -Panel)' ($w3.Code -eq 0 -and $w3.First -match ': 2 of 2 roster entries would run') $w3.First
    $w4 = Consult $r $roster7 @('-Panel', '-DryRun', '-Prompt', 'x')
    Check 'WEIGHT' 'no purpose -> light ("purpose none is light")' ($w4.Code -eq 0 -and $w4.Out -match 'weighty reviewer; purpose none is light \(use -PanelAll\)') ''
    $wx = Consult $r $roster7 @('-Panel', '-Prompt', 'x', '-Purpose', 'diff-review', '-ReplyName', 'w') @{ FAKE_CODEX_REPLY = (Reply 'accept.json' '{"schema_version":"1","verdict":"ACCEPT","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}') }
    $lw = @(Ledger $r)
    Check 'WEIGHT' 'a real light panel: one member ran; its panel.members records the weighty one as skipped with the reason' ($wx.Code -eq 0 -and $lw.Count -eq 1 -and $lw[0].panel.of -eq 1 -and @($lw[0].panel.members)[1].state -eq 'skipped' -and @($lw[0].panel.members)[1].reason -eq 'weighty reviewer; purpose diff-review is light (use -PanelAll)') ''
    $ws = Consult $r $roster7 @('-DryRun', '-Prompt', 'x', '-Purpose', 'diff-review') @{ FAKE_CODEX_LOGIN = 'out' }
    Check 'WEIGHT' 'the single-reviewer walk ignores the weight (openai logged out -> mimo selected)' ($ws.Code -eq 0 -and $ws.Preview.reviewer.provider -eq 'mimo') (Line $ws.Out 'Roster:')
    $wb = Consult $r (Write-Roster 'weight-bad' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1","panel":"sometimes"}]}') @('-DryRun', '-Prompt', 'x')
    Check 'WEIGHT' '"panel": "sometimes" -> the roster refusal naming the path and the entry' ($wb.Code -eq 1 -and $wb.First -match "^codex-consult: the reviewer roster '.*roster-weight-bad\.json' is not usable: entry 1: panel must be ""always"" or ""weighty"" \(got ""sometimes""\)") $wb.First

    # CHORE: plain text like -Raw, effort low, 400 words, the chore paragraph
    $c1 = Consult $r $noRoster @('-DryRun', '-Prompt', 'find x', '-Purpose', 'chore')
    Check 'CHORE' '-Purpose chore -> no --output-schema, -c model_reasoning_effort="low", ledger purpose chore / structured false / schema "" / schema_transport "", max words 400, the chore paragraph in the prompt' ($c1.Code -eq 0 -and $c1.Preview.command -notmatch '--output-schema' -and $c1.Preview.command.Contains('-c model_reasoning_effort="low"') -and $c1.Preview.purpose -eq 'chore' -and $c1.Preview.structured -eq $false -and $c1.Preview.schema -eq '' -and $c1.Preview.schema_transport -eq '' -and $c1.Preview.max_words -eq 400 -and $c1.Out.Contains('Review purpose: chore. This is a chore: a bounded search or extraction task. Report facts with file paths and line numbers, quote what you found, say what you did not find. No verdict, no findings, no recommendations beyond the ask.') -and -not $c1.Out.Contains('Reply format:') -and $c1.Out -match 'keep the answer under 400 words') (Line $c1.Out 'reply format')
    $c2 = Consult $r $noRoster @('-DryRun', '-Prompt', 'find x', '-Purpose', 'chore', '-Effort', 'high')
    $c3 = Consult $r $noRoster @('-DryRun', '-Prompt', 'find x', '-Purpose', 'chore', '-Raw')
    Check 'CHORE' '-Effort overrides the chore preset; -Purpose chore -Raw is fine' ($c2.Code -eq 0 -and $c2.Preview.command.Contains('-c model_reasoning_effort="high"') -and $c3.Code -eq 0 -and $c3.Preview.purpose -eq 'chore') ''
    $c4 = Consult $r $noRoster @('-DryRun', '-Prompt', 'x', '-Purpose', 'nonsense')
    Check 'CHORE' 'the purpose list in the refusal names chore' ($c4.Code -eq 1 -and $c4.First -match 'must be one of: framing, decision, checkpoint, core-contract, acceptance, diff-review, stuck, chore') $c4.First
    $rc = New-Repo 'chore'
    $chore = Reply 'chore.txt' 'app.txt:1: one'
    $cx = Consult $rc $noRoster @('-Prompt', 'find x', '-Purpose', 'chore', '-ReplyName', 'chore') @{ FAKE_CODEX_REPLY = $chore }
    $ce = Last-Entry $rc
    Check 'CHORE' 'a real chore: usable reply, purpose chore, structured false, no reply.json, no findings.json' ($cx.Code -eq 0 -and $ce.purpose -eq 'chore' -and $ce.structured -eq $false -and $ce.reply_json -eq '' -and -not (Test-Path (Join-Path $rc '.collab\t\findings.json'))) $ce.bridge_outcome
    $cp = Consult $r $roster7 @('-Panel', '-DryRun', '-Prompt', 'x', '-Purpose', 'chore')
    Check 'CHORE' '-Purpose chore -Panel -> only the "always" entries' ($cp.Code -eq 0 -and $cp.First -match ': 1 of 2 roster entries would run' -and $cp.Out -match 'weighty reviewer; purpose chore is light') $cp.First
}

# =============================================================== BOARD: codex-findings.ps1 -Stats per-reviewer scoreboard
if (Want 'BOARD') {
    $r = New-Repo 'board'
    $td = Join-Path $r '.collab\t'
    $sess = [pscustomobject]@{ task_id = 't'; cwd = $r; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]@(
                [pscustomobject]@{ n = 1; when = (Iso $now); purpose = 'decision'; reviewer = [pscustomobject]@{ provider = 'openai'; model = 'gpt-5.1'; provider_fingerprint = $builtinFp }; bridge_outcome = 'usable reply'; verdict = 'ADVISE'; reply = 'handoffs/02-codex-a.md' },
                [pscustomobject]@{ n = 2; when = (Iso $now); purpose = 'diff-review'; reviewer = [pscustomobject]@{ provider = 'ZAI'; model = 'glm-5.3'; provider_fingerprint = $zaiFp }; bridge_outcome = 'usable reply'; verdict = 'HOLD'; reply = 'handoffs/04-codex-b.md' },
                [pscustomobject]@{ n = 3; when = (Iso $now); purpose = ''; bridge_outcome = 'usable reply'; verdict = 'ADVISE'; reply = 'handoffs/06-codex-c.md' },
                [pscustomobject]@{ n = 4; when = (Iso $now); purpose = ''; reviewer = [pscustomobject]@{ provider = 'mimo'; model = 'mimo-v2.6-pro'; provider_fingerprint = 'x' }; bridge_outcome = 'usable reply'; verdict = 'ADVISE'; reply = 'handoffs/08-codex-d.md' }
            ) } }
    Write-JsonFile -Path (Join-Path $td 'sessions.json') -Object $sess
    function F { param([string]$Id, [int]$N, [string]$Status) return [pscustomobject]@{ id = $Id; status = $Status; severity = 'minor'; claim = 'c'; source = [pscustomobject]@{ consult = $N; reply = 'x' }; history = [object[]]@(); reviewer_checks = [object[]]@() } }
    Write-JsonFile -Path (Join-Path $td 'findings.json') -Object ([pscustomobject]@{ task_id = 't'; findings = [object[]]@((F 'F02-1' 1 'verified'), (F 'F02-2' 1 'proposed'), (F 'F02-3' 1 'rejected'), (F 'F04-1' 2 'implemented'), (F 'F04-2' 2 'wontfix'), (F 'F04-3' 2 'superseded'), (F 'F06-1' 3 'proposed'), (F 'F10-1' 9 'proposed')) })
    # -Rate: the judge's marks
    $ra = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '1', '-Useful', 'yes')
    $fs1 = [IO.File]::ReadAllText((Join-Path $td 'findings.json'), $u8) | ConvertFrom-Json
    $mk = @($fs1.ratings)
    Check 'RATE' '-Rate 1 -Useful yes -> findings.json ratings [{n, consult_id, lineage, provider, model, purpose, useful, note, when}] copied from ledger entry 1; findings untouched' ($ra.Code -eq 0 -and $ra.First -eq 'codex-findings: consult n=1 (openai :: gpt-5.1, decision) rated yes.' -and $mk.Count -eq 1 -and (($mk[0].PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'n,consult_id,lineage,provider,model,purpose,useful,note,when' -and $mk[0].n -eq 1 -and $mk[0].lineage -eq 'openai :: gpt-5.1' -and $mk[0].provider -eq 'openai' -and $mk[0].model -eq 'gpt-5.1' -and $mk[0].purpose -eq 'decision' -and $mk[0].useful -eq 'yes' -and @($fs1.findings).Count -eq 8) $ra.First
    $rb = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '1', '-Useful', 'partly', '-Note', 'half of it')
    $mk2 = @(([IO.File]::ReadAllText((Join-Path $td 'findings.json'), $u8) | ConvertFrom-Json).ratings)
    Check 'RATE' 're-rating n=1 replaces its record ("re-rated partly (was yes)")' ($rb.Code -eq 0 -and $rb.First -eq 'codex-findings: consult n=1 (openai :: gpt-5.1, decision) re-rated partly (was yes).' -and $mk2.Count -eq 1 -and $mk2[0].useful -eq 'partly' -and $mk2[0].note -eq 'half of it') $rb.First
    $rc = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '2', '-Useful', 'no')
    $rd = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '99', '-Useful', 'yes')
    $re = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '1', '-Useful', 'maybe')
    Check 'RATE' 'refused: -Useful no without -Note, an unknown n, a value other than yes|partly|no' ($rc.Code -eq 1 -and $rc.First -eq 'codex-findings: -Useful no needs -Note (why the consultation was not useful).' -and $rd.Code -eq 1 -and $rd.First -eq "codex-findings: no consultation n=99 in $(Join-Path $td 'sessions.json'); -Rate takes the n of a ledger entry (see -Stats)." -and $re.Code -eq 1 -and $re.First -eq "codex-findings: -Useful must be yes, partly or no (got 'maybe').") "$($rc.First) | $($rd.First) | $($re.First)"
    $null = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '2', '-Useful', 'no', '-Note', 'missed the race')
    $null = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '3', '-Useful', 'yes')
    $mk3 = @(([IO.File]::ReadAllText((Join-Path $td 'findings.json'), $u8) | ConvertFrom-Json).ratings)
    Check 'RATE' 'a legacy entry (no reviewer) is rated as unknown provenance' ($mk3.Count -eq 3 -and $mk3[2].lineage -eq 'unknown provenance' -and $mk3[2].provider -eq '') ''
    $st = Run-Tool $findingsPs $r @('-Task', 't', '-Stats')
    $bl = @($st.Out -split "`n")
    $hdrAt = [Array]::IndexOf($bl, @($bl | Where-Object { $_ -match '^reviewer\s+raised\s+verified\s+implemented\s+proposed\s+rejected\s+wontfix\s+superseded\s+yes\s+partly\s+no$' })[0])
    $rowsB = if ($hdrAt -ge 0) { @($bl[($hdrAt + 1)..($hdrAt + 4)]) } else { @() }
    Check 'BOARD' '-Stats: scoreboard header (+ ratings yes/partly/no) and one line per lineage in ledger order (a reviewer without findings too), unknown provenance last (legacy entry + orphan)' ($st.Code -eq 0 -and $hdrAt -gt 0 -and $bl[$hdrAt - 1] -match '^reviewers \(findings by the lineage' -and $rowsB[0] -match '^openai :: gpt-5\.1\s+3\s+1\s+0\s+1\s+1\s+0\s+0\s+0\s+1\s+0$' -and $rowsB[1] -match '^ZAI :: glm-5\.3\s+3\s+0\s+1\s+0\s+0\s+1\s+1\s+0\s+0\s+1$' -and $rowsB[2] -match '^mimo :: mimo-v2\.6-pro\s+0\s+0\s+0\s+0\s+0\s+0\s+0\s+0\s+0\s+0$' -and $rowsB[3] -match '^unknown provenance\s+2\s+0\s+0\s+2\s+0\s+0\s+0\s+1\s+0\s+0$') ($rowsB -join ' | ')
    $li = Run-Tool $findingsPs $r @('-Task', 't', '-List', '-All')
    Check 'RATE' '-List shows nothing new (no rating lines)' ($li.Code -eq 0 -and $li.Out -notmatch 'rated|useful|partly') ''
}

# =============================================================== SCORE: codex-scoreboard.ps1 across tasks
if (Want 'SCORE') {
    $r = New-Repo 'score'
    function Seed-Consult {
        param([int]$N, [string]$Provider, [string]$Model, [string]$Purpose, [string]$Outcome, $Structured, [string]$Verdict, [double]$Wall, $Usage)
        $e = [ordered]@{ n = $N; when = (Iso $now); purpose = $Purpose }
        if ($Provider) { $e['reviewer'] = [pscustomobject]@{ provider = $Provider; model = $Model; provider_fingerprint = 'x' } }
        $e['bridge_outcome'] = $Outcome; $e['structured'] = $Structured; $e['verdict'] = $Verdict; $e['wall_seconds'] = $Wall; $e['usage'] = $Usage
        return (New-Object PSObject -Property $e)
    }
    function U { param([long]$In, [long]$Cached, [long]$Out) return [pscustomobject]@{ input_tokens = $In; cached_input_tokens = $Cached; output_tokens = $Out; reasoning_output_tokens = 0 } }
    function Fd { param([string]$Id, [int]$N, [string]$Status) return [pscustomobject]@{ id = $Id; status = $Status; severity = 'minor'; claim = 'c'; source = [pscustomobject]@{ consult = $N }; history = [object[]]@(); reviewer_checks = [object[]]@() } }
    Seed-Task $r 'alpha' @(
        (Seed-Consult 1 'openai' 'gpt-5.1' 'decision' 'usable reply' $true 'ADVISE' 10 (U 1000 200 300)),
        (Seed-Consult 2 'ZAI' 'glm-5.3' 'diff-review' 'usable reply' $true 'HOLD' 20 (U 500 0 100)),
        (Seed-Consult 3 'ZAI' 'glm-5.3' 'diff-review' 'usable reply' $false '' 30 $null),
        (Seed-Consult 4 'openai' 'gpt-5.1' 'decision' 'failed: codex exit 1 - x' $false '' 5 $null))
    Seed-Task $r 'beta' @(
        (Seed-Consult 1 'openai' 'gpt-5.1' 'acceptance' 'usable reply' $true 'ACCEPT' 40 (U 2000 1500 50)),
        (Seed-Consult 2 '' '' '' 'usable reply' $true 'ADVISE' 50 $null),
        (Seed-Consult 3 'ZAI' 'glm-5.3' '' 'usable reply' $true 'ADVISE' 60 $null))
    Write-JsonFile -Path (Join-Path $r '.collab\alpha\findings.json') -Object ([pscustomobject]@{ task_id = 'alpha'; findings = [object[]]@((Fd 'F02-1' 1 'verified'), (Fd 'F02-2' 1 'rejected'), (Fd 'F04-1' 2 'verified'), (Fd 'F04-2' 2 'verified'), (Fd 'F04-3' 2 'wontfix'), (Fd 'F04-4' 2 'proposed')) })
    Write-JsonFile -Path (Join-Path $r '.collab\beta\findings.json') -Object ([pscustomobject]@{ task_id = 'beta'; findings = [object[]]@((Fd 'F02-1' 1 'superseded'), (Fd 'F02-2' 1 'implemented'), (Fd 'F04-1' 2 'rejected')) })
    $rateCodes = @()
    foreach ($a in @(@('alpha', '1', 'yes', ''), @('alpha', '2', 'partly', ''), @('alpha', '3', 'no', 'prose only'), @('beta', '1', 'yes', ''))) {
        $argsR = @('-Task', $a[0], '-Rate', $a[1], '-Useful', $a[2])
        if ($a[3]) { $argsR += @('-Note', $a[3]) }
        $rateCodes += (Run-Tool $findingsPs $r $argsR).Code
    }
    $before = (@(Get-ChildItem -LiteralPath (Join-Path $r '.collab') -Recurse -File | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }) | Sort-Object) -join "`n"
    $sj = Run-Tool (Join-Path $scripts 'codex-scoreboard.ps1') $r @('-Json')
    $st = Run-Tool (Join-Path $scripts 'codex-scoreboard.ps1') $r @()
    $after = (@(Get-ChildItem -LiteralPath (Join-Path $r '.collab') -Recurse -File | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }) | Sort-Object) -join "`n"
    $jr = @()
    try { $jr = @(($sj.Out | ConvertFrom-Json) | ForEach-Object { $_ }) } catch { }
    $f = 'consults,usable,prose,failed,raised,verified,rejected,wontfix,superseded,open,hit_rate,verdict_accept,verdict_hold,verdict_reject,verdict_advise,rated_yes,rated_partly,rated_no,median_wall_seconds,tokens_in,tokens_out'.Split(',')
    $want = [ordered]@{
        'openai :: gpt-5.1|acceptance'     = @(1, 1, 0, 0, 2, 0, 0, 0, 1, 1, $null, 1, 0, 0, 0, 1, 0, 0, 40, 500, 50)
        'openai :: gpt-5.1|decision'       = @(2, 1, 0, 1, 2, 1, 1, 0, 0, 0, 50, 0, 0, 0, 1, 1, 0, 0, 7.5, 800, 300)
        'openai :: gpt-5.1|(total)'        = @(3, 2, 0, 1, 4, 1, 1, 0, 1, 1, 50, 1, 0, 0, 1, 2, 0, 0, 10, 1300, 350)
        'ZAI :: glm-5.3|(none)'            = @(1, 1, 0, 0, 0, 0, 0, 0, 0, 0, $null, 0, 0, 0, 1, 0, 0, 0, 60, 0, 0)
        'ZAI :: glm-5.3|diff-review'       = @(2, 2, 1, 0, 4, 2, 0, 1, 0, 1, 100, 0, 1, 0, 0, 0, 1, 1, 25, 500, 100)
        'ZAI :: glm-5.3|(total)'           = @(3, 3, 1, 0, 4, 2, 0, 1, 0, 1, 100, 0, 1, 0, 1, 0, 1, 1, 30, 500, 100)
        'unknown provenance|(none)'        = @(1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 50, 0, 0)
        'unknown provenance|(total)'       = @(1, 1, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 50, 0, 0)
        '(all)|(total)'                    = @(7, 6, 1, 1, 9, 3, 2, 1, 1, 2, 60, 1, 1, 0, 3, 2, 1, 1, 30, 1800, 450)
    }
    $order = @($jr | ForEach-Object { "$($_.lineage)|$($_.purpose)" }) -join ' ; '
    $badS = @()
    foreach ($k in $want.Keys) {
        $row = @($jr | Where-Object { "$($_.lineage)|$($_.purpose)" -eq $k }) | Select-Object -First 1
        if (-not $row) { $badS += "missing row $k"; continue }
        for ($i = 0; $i -lt $f.Count; $i++) {
            $got = $row.($f[$i]); $exp = $want[$k][$i]
            if (($null -eq $exp -and $null -ne $got) -or ($null -ne $exp -and ($null -eq $got -or [double]$got -ne [double]$exp))) { $badS += "$k $($f[$i]): got '$got', want '$exp'" }
        }
    }
    Check 'SCORE' 'codex-scoreboard -Json over two tasks: every (lineage, purpose) row, lineage totals and the grand total with the right counts, hit rates, verdicts, ratings, medians, tokens' ((@($rateCodes | Where-Object { $_ -ne 0 }).Count -eq 0) -and $sj.Code -eq 0 -and $jr.Count -eq 9 -and $badS.Count -eq 0) ($badS -join ' | ')
    Check 'SCORE' 'row order: lineage (case-insensitive, unknown provenance last), then purpose, the lineage total after its purposes, the grand total last' ($order -eq 'openai :: gpt-5.1|acceptance ; openai :: gpt-5.1|decision ; openai :: gpt-5.1|(total) ; ZAI :: glm-5.3|(none) ; ZAI :: glm-5.3|diff-review ; ZAI :: glm-5.3|(total) ; unknown provenance|(none) ; unknown provenance|(total) ; (all)|(total)') $order
    $tl = @($st.Out -split "`n")
    $hdrS = @($tl | Where-Object { $_ -match '^REVIEWER' })[0]
    Check 'SCORE' 'table: header REVIEWER PURPOSE CONSULTS USABLE PROSE FAILED RAISED VERIFIED REJECTED WONTFIX SUPERSEDED OPEN HIT% A/H/R/D Y/P/N MEDIAN_S TOKENS; the (none) row, the grand total row; nothing written' ($st.Code -eq 0 -and $hdrS -match '^REVIEWER\s+PURPOSE\s+CONSULTS\s+USABLE\s+PROSE\s+FAILED\s+RAISED\s+VERIFIED\s+REJECTED\s+WONTFIX\s+SUPERSEDED\s+OPEN\s+HIT%\s+A/H/R/D\s+Y/P/N\s+MEDIAN_S\s+TOKENS$' -and @($tl | Where-Object { $_ -match '^ZAI :: glm-5\.3\s+\(none\)\s+1\s+1\s+0\s+0\s+0\s+0\s+0\s+0\s+0\s+0\s+-\s+0/0/0/1\s+0/0/0\s+60\s+0/0$' }).Count -eq 1 -and @($tl | Where-Object { $_ -match '^\(all\)\s+\(total\)\s+7\s+6\s+1\s+1\s+9\s+3\s+2\s+1\s+1\s+2\s+60%\s+1/1/0/3\s+2/1/1\s+30\s+1800/450$' }).Count -eq 1 -and @($tl | Where-Object { $_ -match '^openai :: gpt-5\.1\s+decision\s+2\s+1\s+0\s+1\s+2\s+1\s+1\s+0\s+0\s+0\s+50%\s+0/0/0/1\s+1/0/0\s+7\.5\s+800/300$' }).Count -eq 1 -and $before -eq $after) (($tl | Where-Object { $_ -match '^\(all\)' }) -join '')
    $sa = Run-Tool (Join-Path $scripts 'codex-scoreboard.ps1') $r @('-Task', 'beta', '-Json')
    $ja = @()
    try { $ja = @(($sa.Out | ConvertFrom-Json) | ForEach-Object { $_ }) } catch { }
    $tot = @($ja | Where-Object { $_.kind -eq 'total' })[0]
    Check 'SCORE' '-Task beta: only that task (grand total 3 consults, 3 raised, ratings 1/0/0)' ($sa.Code -eq 0 -and $tot.consults -eq 3 -and $tot.raised -eq 3 -and $tot.rated_yes -eq 1 -and $tot.rated_no -eq 0) "consults=$($tot.consults)"
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-roster ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
