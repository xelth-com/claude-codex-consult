# codex-consult companions (0.5.0 wave 26, ROADMAP R14-R16; decisions D1-D12 of the companions design
# round): the roster's new keys (`lab`, `roles`, `require`, the extension point `ext`) and their
# fail-closed validation; the lab of an entry (the vendor table on the model id, never the provider
# label; canonical lowercase; a lab of its own); the reviewer matcher of -Require (#n, a label,
# `<provider> :: <model>` [` [<engine>]`]); the routing score (a rate with a prior scaled into
# [0.25, 2], the 90-day window by the CONSULTATION's time, the purpose/topic -> all-purpose ->
# neutral hierarchy, topic credit 1/t pooled - never a mean of means) over the ratings of every task
# (keyed by consult_id: task-local n collisions, re-rating recency, a legacy rating completed by its
# consult_id); the exact portable draw (fixed-seed golden sequences computed by an independent
# reference implementation, byte-identical on Windows PowerShell 5.1 and PowerShell 7; the
# exploration rate bounded over many seeds; the lab-diversity reserve and its quality gap); the
# panel's size per purpose, -PanelSize, -PanelAll, the `not-picked` state, asked/started/usable, the
# floor warning; -PanelOrder roster and the no-ratings fallback; the routing record in the ledger and
# the dry run (the same seats the real run takes); -Require (pinning, exit 5 before the start - the
# dry run too, a single -Provider run, the roster's default and -Require none, a weighty entry on a
# light purpose, a shared endpoint outage, the 60-minute unknown-reset transition, a required member
# failing after the start); roles (-Role, -Roles by score rank and willingness, the repository's
# roles over the plugin's, slug traversal refused, the block after the ask); -Topic; -Rate's new
# record; the scoreboard's SCORE, UNIQ and -By topic. FAKES ONLY: fake-codex3.cmd; CODEX_HOME and
# CODEX_CONSULT_ROSTER point at scratch files; the API key variables hold dummy test values. Runs
# under the host it is started with (powershell 5.1 or pwsh 7, Windows). Work files:
# $env:TEMP\codex-consult-tests\harness-companions\<guid>, removed at the end.
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
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# (wave 25, T4) the scripts under test: -ScriptsDir, else CODEX_CONSULT_SCRIPTS_DIR, else this checkout's
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$findingsPs = Join-Path $scripts 'codex-findings.ps1'
$scoreboardPs = Join-Path $scripts 'codex-scoreboard.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-companions') ([guid]::NewGuid().ToString('N'))
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

# (wave 28b, D10) every bridge run in test mode carries "test mode is ON: test hooks are honoured" in
# warnings[] (and on the console): a comparison of warnings[] takes the other entries
# (Get-RealWarnings) and expects that line once (Test-TestModeWarning)
$testModeLine = 'test mode is ON: test hooks are honoured'
function Get-RealWarnings { param($List) @($List) | Where-Object { [string]$_ -ne $testModeLine } }
function Test-TestModeWarning { param($List) return (@(@($List) | Where-Object { [string]$_ -eq $testModeLine }).Count -eq 1) }
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
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
# The scratch Codex config: the built-in openai (top-level model gpt-5.1), ZAI (env RT_ZAI_KEY), mimo
# (env RT_MIMO_KEY), byteplus and alibaba (no credential; their roster entries say auth none) - every
# endpoint one that caps-v1 declares (an effort vocabulary), so each member can plan its run.
$toml = "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n`n[model_providers.mimo]`nbase_url = `"https://token-plan-ams.xiaomimimo.com/v1`"`nenv_key = `"RT_MIMO_KEY`"`nwire_api = `"responses`"`n`n[model_providers.byteplus]`nbase_url = `"https://ark.ap-southeast.bytepluses.com/api/coding/v3`"`nwire_api = `"responses`"`n`n[model_providers.alibaba]`nbase_url = `"https://token-plan.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1`"`nwire_api = `"responses`"`n"
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml, $u8)
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_FAIL_ON', 'FAKE_CODEX_HANG_ON', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_REPLY_MAP')
$testVars = @('RT_ZAI_KEY', 'RT_MIMO_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_PANEL_SEED', 'CODEX_CONSULT_TEST_PANEL_GUARD_SEC')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
}
# Both keys are set unless a case removes one ('' removes a variable).
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:RT_ZAI_KEY = 'zai-test-key'
    $env:RT_MIMO_KEY = 'mimo-test-key'
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env { Clear-TestEnv; $env:CODEX_HOME = $savedCodexHome }
# One bridge call: { Code; Out; First; Previews (every dry-run ledger preview, in output order) }
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
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1); Previews = (Get-Previews $text) }
}
# The ledger previews of a dry run (a panel prints one per member, after its `=== panel` line).
function Get-Previews {
    param([string]$Text)
    $list = New-Object System.Collections.Generic.List[object]
    $mark = 'sessions.json entry preview:'
    $at = $Text.IndexOf($mark)
    while ($at -ge 0) {
        $rest = $Text.Substring($at + $mark.Length)
        $next = $rest.IndexOf($mark)
        $chunk = $(if ($next -ge 0) { $rest.Substring(0, $next) } else { $rest })
        $lines = New-Object System.Collections.Generic.List[string]
        $depth = 0
        $started = $false
        foreach ($l in ($chunk -split "`n")) {
            $t = $l.TrimEnd("`r")
            if (-not $started) { if ($t.Trim() -eq '{') { $started = $true } else { continue } }
            $lines.Add($t)
            $depth += ([regex]::Matches($t, '[\{\[]')).Count - ([regex]::Matches($t, '[\}\]]')).Count
            if ($started -and $depth -le 0) { break }
        }
        try { $list.Add((($lines.ToArray() -join "`n") | ConvertFrom-Json)) } catch { $list.Add($null) }
        $at = $(if ($next -ge 0) { $at + $mark.Length + $next } else { -1 })
    }
    return , ($list.ToArray())
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
function Ledger { param([string]$Repo, [string]$TaskName = 't') $f = Join-Path $Repo ".collab\$TaskName\sessions.json"; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Iso { param($Dto) return ([DateTimeOffset]$Dto).ToString('yyyy-MM-ddTHH:mm:sszzz', $inv) }
function Guid-Of { param([int]$K) return ('00000000-0000-4000-8000-{0:D12}' -f $K) }
# A rating record as -Rate writes it (wave 26 fields); $Legacy: a pre-wave-26 record (no engine,
# topics or consult_when).
function Rt {
    param([string]$Provider, [string]$Model, [string]$Useful, [string]$Purpose = 'framing', [string[]]$Topics = @(), [DateTimeOffset]$ConsultWhen = ([DateTimeOffset]::Now.AddDays(-1)), [string]$Cid = '', [int]$N = 1, [string]$Engine = 'codex', [DateTimeOffset]$RatedWhen = ([DateTimeOffset]::Now), [switch]$Legacy)
    if (-not $Cid) { $script:ridSeq++; $Cid = Guid-Of (900000 + $script:ridSeq) }
    $h = [ordered]@{ n = $N; consult_id = $Cid; lineage = (Format-ReviewerLineage -Provider $Provider -Model $Model -Engine $Engine); provider = $Provider; model = $Model }
    if (-not $Legacy) { $h['engine'] = $Engine }
    $h['purpose'] = $Purpose
    if (-not $Legacy) { $h['topics'] = [object[]]@($Topics); $h['consult_when'] = (Iso $ConsultWhen) }
    $h['useful'] = $Useful; $h['note'] = ''; $h['when'] = (Iso $RatedWhen)
    return [pscustomobject]$h
}
$script:ridSeq = 0
function Seed-Ratings {
    param([string]$Repo, [string]$TaskName, [object[]]$Ratings, [object[]]$Findings = @())
    $dir = Join-Path $Repo ".collab\$TaskName"
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
    Write-JsonFile -Path (Join-Path $dir 'findings.json') -Object ([pscustomobject]@{ task_id = $TaskName; findings = [object[]]@($Findings); ratings = [object[]]@($Ratings) })
}
function Seed-Ledger {
    param([string]$Repo, [string]$TaskName, [object[]]$Entries)
    $dir = Join-Path $Repo ".collab\$TaskName"
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
    Write-JsonFile -Path (Join-Path $dir 'sessions.json') -Object ([pscustomobject]@{ task_id = $TaskName; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$Entries } })
}
$zaiFp = Get-Sha256Hex ($u8.GetBytes('cc-provider-v1|base_url=https://api.z.ai/api/v1|wire_api=responses'))
function New-Entry {
    param([int]$N, [string]$Provider, [string]$Model, [string]$Fp, [DateTimeOffset]$When, [string]$Outcome = 'usable reply', $Failure = $null, [string]$Cid = '', [string]$Purpose = '', [string[]]$Topics = @(), $Panel = $null)
    $e = [ordered]@{ n = $N; when = (Iso $When); purpose = $Purpose; topics = [object[]]@($Topics); consult_id = $(if ($Cid) { $Cid } else { Guid-Of (800000 + $N) }); reviewer = [pscustomobject]@{ provider = $Provider; model = $Model; engine = 'codex'; provider_fingerprint = $Fp }; panel = $Panel; thread = ''; thread_source = 'events'; mode = 'new'; reply = ('handoffs/{0:D2}-x.md' -f $N); bridge_outcome = $Outcome; wall_seconds = 1; finished_at = (Iso $When.AddSeconds(1)) }
    if ($null -ne $Failure) { $e['provider_failure'] = $Failure }
    return [pscustomobject]$e
}
function Quota { param([DateTimeOffset]$When, [string]$Message) return [pscustomobject]@{ class = 'quota'; kind = ''; code = ''; message = $Message; when = (Iso $When); retry_after = $null; hint = '' } }
function Picks { param($Routing) return (@($Routing.picked | ForEach-Object { "$($_.position)/$($_.rule)" }) -join ' ') }

$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
# Five reviewers of five labs on five endpoints: openai (openai), ZAI glm (zhipu), mimo (xiaomi),
# byteplus kimi (moonshot - never "byteplus"), alibaba qwen (alibaba).
$roster5 = Write-Roster 'five' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo","model":"mimo-v2.6-pro"},{"provider":"byteplus","model":"kimi-k2.5","auth":"none"},{"provider":"alibaba","model":"qwen3.8-max","auth":"none"}]}'
# The ratings of the routed cases (purpose framing, one day old): ZAI 4 yes -> 1.7083; mimo 3 no -> 0.6;
# kimi 3 yes 1 partly -> 1.5625; openai and qwen none -> neutral 1.125.
function Routing-Ratings {
    $list = New-Object System.Collections.Generic.List[object]
    for ($i = 1; $i -le 4; $i++) { $list.Add((Rt 'ZAI' 'glm-5.3' 'yes' -N $i)) }
    for ($i = 5; $i -le 7; $i++) { $list.Add((Rt 'mimo' 'mimo-v2.6-pro' 'no' -N $i)) }
    for ($i = 8; $i -le 10; $i++) { $list.Add((Rt 'byteplus' 'kimi-k2.5' 'yes' -N $i)) }
    $list.Add((Rt 'byteplus' 'kimi-k2.5' 'partly' -N 11))
    return , ($list.ToArray())
}

try {
# =============================================================== ROSTER: the new keys, fail-closed
if (Want 'ROSTER') {
    $loc = { param($p) [pscustomobject]@{ Path = $p; FromEnv = $true; Disabled = $false } }
    $okR = Write-Roster 'newkeys' '{"roster_version":1,"ext":{"c3":{"x":1}},"require":{"acceptance":["#1","ZAI :: glm-5.3"],"framing":["gemini [agy]"]},"reviewers":[{"provider":"openai","model":"gpt-5.1","lab":"OpenAI","roles":["Security","tests"],"ext":{"weight":2}},{"provider":"ZAI","model":"glm-5.3"},{"provider":"gemini","engine":"agy","model":"gemini-3.1-pro-high"}]}'
    $rr = Read-ReviewerRoster (& $loc $okR)
    Check 'ROSTER' 'D12/D1/D8/D7: lab (canonical lowercase "openai"), roles (slugs, lowercased), ext (top level and per entry, ignored), require (validated at load: #1, a lineage, a label with an engine) are accepted; roster_version stays 1' (-not $rr.Error -and $rr.Entries[0].Lab -eq 'openai' -and (@($rr.Entries[0].Roles) -join ',') -eq 'security,tests' -and $rr.Entries[1].Lab -eq '' -and (@($rr.Require['acceptance']) -join '|') -eq '#1|ZAI :: glm-5.3' -and (@($rr.Require['framing']) -join '|') -eq 'gemini [agy]' -and -not $rr.Entries[0].PSObject.Properties['Ext']) $rr.Error
    $bad = @{
        'lab-number'   = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","lab":7}]}', 'entry 1: lab must be a non-empty string')
        'lab-blank'    = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","lab":" x "}]}', 'entry 1: lab must be a non-empty string')
        'roles-string' = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","roles":"security"}]}', 'entry 1: roles must be an array of role names')
        'roles-slug'   = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","roles":["../x"]}]}', "entry 1: roles: role '../x' is not a slug")
        'ext-array'    = @('{"roster_version":1,"ext":[1],"reviewers":[{"provider":"ZAI","model":"glm-5.3"}]}', 'ext must be an object')
        'ext-entry'    = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","ext":"x"}]}', 'entry 1: ext must be an object')
        'req-purpose'  = @('{"roster_version":1,"require":{"release":["#1"]},"reviewers":[{"provider":"ZAI","model":"glm-5.3"}]}', "require names the purpose 'release'")
        'req-nomatch'  = @('{"roster_version":1,"require":{"acceptance":["openai :: gpt-6-astra"]},"reviewers":[{"provider":"ZAI","model":"glm-5.3"}]}', "require.acceptance: 'openai :: gpt-6-astra' matches no roster entry")
        'req-position' = @('{"roster_version":1,"require":{"acceptance":["#4"]},"reviewers":[{"provider":"ZAI","model":"glm-5.3"}]}', "require.acceptance: '#4' names no roster position")
        'req-empty'    = @('{"roster_version":1,"require":{"acceptance":[]},"reviewers":[{"provider":"ZAI","model":"glm-5.3"}]}', 'require.acceptance must be a non-empty array')
        'req-object'   = @('{"roster_version":1,"require":["#1"],"reviewers":[{"provider":"ZAI","model":"glm-5.3"}]}', 'require must be an object')
        'unknown-key'  = @('{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3","labs":"x"}]}', "entry 1 has an unknown key 'labs' (allowed: provider, model, codex_config, auth, endpoint, plan, panel, engine, lab, roles, timeout_sec, stall_sec, context_tokens, ext)")
    }
    $failsR = @()
    foreach ($k in $bad.Keys) {
        $x = Read-ReviewerRoster (& $loc (Write-Roster "bad-$k" $bad[$k][0]))
        if (-not $x.Error.Contains($bad[$k][1])) { $failsR += "$k -> $($x.Error)" }
    }
    Check 'ROSTER' 'fail-closed: a non-string or blank lab, roles not an array or not slugs, ext not an object (top level, entry), require with an unknown purpose, a matcher naming no entry or no position, an empty list, not an object, and an unknown entry key are each refused with their reason' ($failsR.Count -eq 0) ($failsR -join ' | ')
    $r = New-Repo 'roster-ext'
    $xr = Consult $r $okR @('-DryRun', '-Provider', 'ZAI', '-Prompt', 'x')
    Check 'ROSTER' 'a roster carrying ext, lab, roles and require runs (a dry run of a -Provider run: exit 0, the entry used)' ($xr.Code -eq 0 -and $xr.Out -match 'Roster: .* - entry 2 of 3 for -Provider ZAI') $xr.First
}

# =============================================================== UNIT: labs, matcher, slugs, sizes
if (Want 'UNIT') {
    $vend = @{ 'qwen3.8-max' = 'alibaba'; 'deepseek-v4.1-flash' = 'deepseek'; 'kimi-k2.5' = 'moonshot'; 'k3' = 'moonshot'; 'glm-5.3' = 'zhipu'; 'GLM-4.6' = 'zhipu'; 'dola-seed-2.0-pro' = 'bytedance'; 'seed-oss' = 'bytedance'; 'mimo-v2.6-pro' = 'xiaomi'; 'gemini-3.1-pro-high' = 'google'; 'muse-spark-1.3' = 'meta'; 'gpt-6-astra' = 'openai'; 'llama-4' = '' }
    $badV = @(foreach ($m in $vend.Keys) { if ((Get-ModelLab $m) -cne $vend[$m]) { "$m -> $(Get-ModelLab $m)" } })
    $e1 = [pscustomobject]@{ Provider = 'byteplus'; Model = 'kimi-k2.5'; Engine = 'codex'; Lab = '' }
    $e2 = [pscustomobject]@{ Provider = 'byteplus'; Model = 'deepseek-v4.1-flash'; Engine = 'codex'; Lab = '' }
    $e3 = [pscustomobject]@{ Provider = 'local'; Model = 'Llama-4'; Engine = 'codex'; Lab = '' }
    $e4 = [pscustomobject]@{ Provider = 'local'; Model = 'llama-4'; Engine = 'codex'; Lab = 'meta' }
    $e5 = [pscustomobject]@{ Provider = 'openai'; Model = ''; Engine = 'codex'; Lab = '' }
    $l1 = Get-EntryLab $e1; $l2 = Get-EntryLab $e2; $l3 = Get-EntryLab $e3; $l4 = Get-EntryLab $e4; $l5 = Get-EntryLab $e5 -Model 'gpt-5.1'
    Check 'UNIT' 'D1: the lab from the vendor table on the model id prefix, case-insensitive (qwen alibaba, deepseek, kimi/k3 moonshot, glm zhipu, dola/seed bytedance, mimo xiaomi, gemini google, muse meta, gpt openai); NEVER the provider label (byteplus :: kimi -> moonshot, byteplus :: deepseek -> deepseek); an unknown prefix -> a singleton lab (its lineage, lowercase); the roster''s lab wins; a model-less entry by its resolved model' ($badV.Count -eq 0 -and $l1.Lab -eq 'moonshot' -and $l1.Source -eq 'vendor' -and $l2.Lab -eq 'deepseek' -and $l3.Lab -eq 'local :: llama-4' -and $l3.Source -eq 'singleton' -and $l4.Lab -eq 'meta' -and $l4.Source -eq 'roster' -and $l5.Lab -eq 'openai') "$($badV -join ', ') $($l1.Lab) $($l2.Lab) $($l3.Lab)/$($l3.Source) $($l4.Lab) $($l5.Lab)"
    $ents = @(
        [pscustomobject]@{ Position = 1; Provider = 'openai'; Model = ''; Engine = 'codex' },
        [pscustomobject]@{ Position = 2; Provider = 'gemini'; Model = 'gemini-3.8-flash-high'; Engine = 'agy' },
        [pscustomobject]@{ Position = 3; Provider = 'gemini'; Model = 'gemini-3.1-pro-high'; Engine = 'agy' },
        [pscustomobject]@{ Position = 4; Provider = 'ZAI'; Model = 'glm-5.3'; Engine = 'codex' })
    $m = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($q in @('#3', 'gemini', 'gemini [agy]', 'gemini :: gemini-3.1-pro-high', 'gemini :: gemini-3.1-pro-high [agy]', 'gemini :: gemini-3.1-pro-high [codex]', 'openai', 'openai :: gpt-5.1', 'ZAI :: glm-5.3', 'zai :: glm-5.3', '#9', 'gemini [foo]', ' ZAI :: glm-5.3 ')) {
        $res = Resolve-ReviewerMatcher -Entries $ents -Matcher $q
        $m[$q] = $(if ($res.Error) { "E:$($res.Error)" } else { (@($res.Positions) -join ',') })
    }
    Check 'UNIT' 'D7 matcher: #3 -> 3; a label -> every entry of it (gemini -> 2,3); with [agy] too; "<provider> :: <model>" with or without its engine suffix -> 3, with another engine -> no match; a model-less entry by label (openai -> 1) but not by a model it does not name; case-sensitive like the roster (zai :: glm-5.3 -> no match); #9 and an unknown engine refused; blanks trimmed' ($m['#3'] -eq '3' -and $m['gemini'] -eq '2,3' -and $m['gemini [agy]'] -eq '2,3' -and $m['gemini :: gemini-3.1-pro-high'] -eq '3' -and $m['gemini :: gemini-3.1-pro-high [agy]'] -eq '3' -and $m['gemini :: gemini-3.1-pro-high [codex]'] -like 'E:*matches no roster entry' -and $m['openai'] -eq '1' -and $m['openai :: gpt-5.1'] -like 'E:*' -and $m['ZAI :: glm-5.3'] -eq '4' -and $m['zai :: glm-5.3'] -like 'E:*' -and $m['#9'] -like 'E:*names no roster position*' -and $m['gemini [foo]'] -like "E:*names the engine 'foo'*" -and $m[' ZAI :: glm-5.3 '] -eq '4') (($m.Keys | Sort-Object | ForEach-Object { "$_=$($m[$_])" }) -join '; ')
    $s1 = ConvertTo-SlugList -Values @('Security, tests,security', 'DOCS') -What 'topic'
    $s2 = ConvertTo-SlugList -Values @('../x') -What 'role'
    $s3 = ConvertTo-SlugList -Values @('a\b') -What 'role'
    $s4 = ConvertTo-SlugList -Values @('ok', ('x' * 42)) -What 'topic'
    Check 'UNIT' 'slugs (D3, D8): split at commas, trimmed, lowercased, deduplicated in order (security,tests,docs); "../x", "a\b" and 42 characters refused' ((@($s1.Items) -join ',') -eq 'security,tests,docs' -and -not $s1.Error -and $s2.Error -like "role '../x' is not a slug*" -and $s3.Error -like "role 'a\b' is not a slug*" -and $s4.Error -like 'topic*is not a slug*') "$(@($s1.Items) -join ',') | $($s2.Error)"
    $sizes = (@('', 'chore', 'checkpoint', 'diff-review', 'framing', 'decision', 'core-contract', 'acceptance', 'stuck') | ForEach-Object { "$(if ($_) { $_ } else { 'none' })=$(Get-PanelDefaultSize $_)" }) -join ' '
    Check 'UNIT' 'D6: the default sizes - none 1, chore 1, checkpoint 1, diff-review 2, framing 3, decision 3, core-contract 4, acceptance 4, stuck 0 (every eligible member)' ($sizes -eq 'none=1 chore=1 checkpoint=1 diff-review=2 framing=3 decision=3 core-contract=4 acceptance=4 stuck=0') $sizes
}

# =============================================================== SCORE: the routing score and the ratings reader
if (Want 'SCORE') {
    $now = [datetime]::Parse('2026-09-27T12:00:00Z', $inv).ToUniversalTime()
    $nowO = [DateTimeOffset]::Parse('2026-09-27T12:00:00+00:00', $inv)
    $d1 = $nowO.AddDays(-1)
    $sc = { param($List, [string]$Purpose, [string[]]$Topics = @()) Get-RoutingScore -Ratings $List -Provider 'ZAI' -Model 'glm-5.3' -Purpose $Purpose -Topics $Topics -UtcNow $now }
    $norm = { param($List) @($List | ForEach-Object { [pscustomobject]@{ Provider = $_.provider; Model = $_.model; Engine = 'codex'; Purpose = $_.purpose; Topics = [string[]]@($_.topics); ConsultWhen = [DateTimeOffset]::Parse($_.consult_when, $inv); Useful = $_.useful } }) }
    $four = & $norm @(1..4 | ForEach-Object { Rt 'ZAI' 'glm-5.3' 'yes' -ConsultWhen $d1 })
    $noOne = & $norm @(Rt 'ZAI' 'glm-5.3' 'no' -ConsultWhen $d1)
    $noThree = & $norm @(1..3 | ForEach-Object { Rt 'ZAI' 'glm-5.3' 'no' -ConsultWhen $d1 })
    $many = & $norm @(@(1..16 | ForEach-Object { Rt 'ZAI' 'glm-5.3' 'yes' -ConsultWhen $d1 }) + @(1..4 | ForEach-Object { Rt 'ZAI' 'glm-5.3' 'no' -ConsultWhen $d1 }))
    $few = & $norm @(1..3 | ForEach-Object { Rt 'ZAI' 'glm-5.3' 'yes' -ConsultWhen $d1 })
    $a = & $sc $four 'framing'; $b = & $sc $noOne 'framing'; $c = & $sc $noThree 'framing'; $dm = & $sc $many 'framing'; $df = & $sc $few 'framing'; $z = & $sc @() 'framing'
    Check 'UNIT' 'D3: w = (yes + 0.5 partly + 1) / (n + 2) scaled 0.25 + 1.75 w: 4 yes -> 1.7083; 3 no -> 0.6; ONE no -> neutral 1.125 (fewer than 3 ratings: never below an unrated reviewer); no ratings -> neutral; 20 at 80% (1.6023) rank below 3 at 100% (1.65) - volume does not dominate' ([Math]::Abs($a.Score - 1.708333) -lt 1e-5 -and $a.Basis -eq 'purpose' -and [Math]::Abs($c.Score - 0.6) -lt 1e-9 -and $b.Score -eq 1.125 -and $b.Basis -eq 'neutral' -and $z.Score -eq 1.125 -and [Math]::Abs($dm.Score - (0.25 + 1.75 * 17 / 22)) -lt 1e-9 -and [Math]::Abs($df.Score - 1.65) -lt 1e-9 -and $df.Score -gt $dm.Score) ("{0} {1} {2} {3} {4}" -f $a.Score, $b.Score, $c.Score, $dm.Score, $df.Score)
    $old = & $norm @(1..3 | ForEach-Object { Rt 'ZAI' 'glm-5.3' 'yes' -ConsultWhen $nowO.AddDays(-91) -RatedWhen $nowO.AddDays(-1) })
    $mixed = & $norm @(@(1..3 | ForEach-Object { Rt 'ZAI' 'glm-5.3' 'no' -Purpose 'decision' -ConsultWhen $d1 }) + @(Rt 'ZAI' 'glm-5.3' 'yes' -Purpose 'framing' -ConsultWhen $d1))
    $o = & $sc $old 'framing'; $mp = & $sc $mixed 'framing'
    Check 'UNIT' 'D3: the 90-day window by the CONSULTATION''s time - 3 yes on consultations 91 days old, re-rated yesterday, count nothing (neutral, All 0); the hierarchy: 1 rating on framing, 3 on decision -> the all-purpose rate of all 4 (1 yes 3 no: 0.8333)' ($o.Score -eq 1.125 -and $o.All -eq 0 -and $mp.Basis -eq 'all-purpose' -and [Math]::Abs($mp.Score - (0.25 + 1.75 * (2.0 / 6))) -lt 1e-9 -and $mp.All -eq 4) "$($o.Score)/$($o.All) $($mp.Basis) $($mp.Score)"
    $top = & $norm @((Rt 'ZAI' 'glm-5.3' 'yes' -Topics @('a', 'b') -ConsultWhen $d1), (Rt 'ZAI' 'glm-5.3' 'no' -Topics @('a') -ConsultWhen $d1), (Rt 'ZAI' 'glm-5.3' 'yes' -Topics @('b') -ConsultWhen $d1), (Rt 'ZAI' 'glm-5.3' 'partly' -Topics @('a') -ConsultWhen $d1), (Rt 'ZAI' 'glm-5.3' 'no' -Topics @() -ConsultWhen $d1))
    $t2 = & $sc $top 'framing' @('a', 'b')
    $t1 = & $sc $top 'framing' @('b')
    Check 'UNIT' 'D3 topics: a rating credits each of its t topics 1/t, a request pools the credited counts over its topics (a,b: n 4, yes 2, partly 1 -> 1.2708 - never a mean of means); too little topic evidence (b: 1.5) falls back to the purpose (5 ratings: 2 yes 1 partly 2 no -> 1.125)' ($t2.Basis -eq 'purpose+topics' -and [Math]::Abs($t2.Ratings - 4) -lt 1e-9 -and [Math]::Abs($t2.Score - (0.25 + 1.75 * (3.5 / 6))) -lt 1e-9 -and $t1.Basis -eq 'purpose' -and [Math]::Abs($t1.Score - (0.25 + 1.75 * (3.5 / 7))) -lt 1e-9) "$($t2.Basis) $($t2.Ratings) $($t2.Score) | $($t1.Basis) $($t1.Score)"
    # the reader: task-local n collisions, re-rating recency, a legacy rating completed by consult_id
    $r = New-Repo 'ratings'
    $cidA = Guid-Of 1; $cidB = Guid-Of 2; $cidL = Guid-Of 3
    Seed-Ledger $r 'alpha' @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp $d1 -Cid $cidA -Purpose 'framing' -Topics @('security')))
    Seed-Ledger $r 'beta' @((New-Entry 1 'mimo' 'mimo-v2.6-pro' 'x' $nowO.AddDays(-200) -Cid $cidB -Purpose 'decision'), (New-Entry 2 'ZAI' 'glm-5.3' $zaiFp $nowO.AddDays(-2) -Cid $cidL -Purpose 'acceptance' -Topics @('tests')))
    Seed-Ratings $r 'alpha' @((Rt 'ZAI' 'glm-5.3' 'no' -Cid $cidA -N 1 -RatedWhen $nowO.AddHours(-5)), (Rt 'ZAI' 'glm-5.3' 'yes' -Cid $cidA -N 1 -RatedWhen $nowO.AddHours(-1)))
    $legacy = Rt '' '' 'partly' -Cid $cidL -N 2 -Purpose 'acceptance' -Legacy
    $legacy.lineage = 'ZAI :: glm-5.3'; $legacy.provider = ''; $legacy.model = ''
    Seed-Ratings $r 'beta' @((Rt 'mimo' 'mimo-v2.6-pro' 'no' -Cid $cidB -N 1 -Purpose 'decision' -ConsultWhen $nowO.AddDays(-200)), $legacy)
    $all = Read-AllTaskRatings -CollabRoot (Join-Path $r '.collab')
    $ra = @($all | Where-Object { $_.ConsultId -eq $cidA })
    $rb = @($all | Where-Object { $_.ConsultId -eq $cidB })
    $rl = @($all | Where-Object { $_.ConsultId -eq $cidL })
    Check 'UNIT' 'D2 reader: two tasks with n=1 each keep their own reviewer (alpha ZAI, beta mimo - keyed by consult_id, no join by n); the same consultation rated twice -> ONE record, the later mark (yes); a legacy mark (no provider, engine, topics or consult_when) is completed from the ledger entry WITH ITS consult_id (ZAI, acceptance, topics tests, its own when) - not from beta''s n=1' ($all.Count -eq 3 -and $ra.Count -eq 1 -and $ra[0].Useful -eq 'yes' -and $ra[0].Provider -eq 'ZAI' -and $rb.Count -eq 1 -and $rb[0].Provider -eq 'mimo' -and $rl.Count -eq 1 -and $rl[0].Provider -eq 'ZAI' -and $rl[0].Model -eq 'glm-5.3' -and $rl[0].Purpose -eq 'acceptance' -and (@($rl[0].Topics) -join ',') -eq 'tests' -and $rl[0].Engine -eq 'codex' -and [Math]::Abs(($rl[0].ConsultWhen - $nowO.AddDays(-2)).TotalMinutes) -lt 1) (($all | ForEach-Object { "$($_.ConsultId.Substring(30)):$($_.Provider):$($_.Purpose):$($_.Useful)" }) -join ' ')
}

# =============================================================== DRAW: the exact portable draw (golden sequences)
if (Want 'DRAW') {
    # golden values from the independent reference implementation of D4 - tests/reference-draw.py
    # (Python hashlib; wave 26b, D3: the length-prefixed seed text - the values changed then)
    $seed = Get-PanelSeed -Task 't' -Purpose 'framing' -BriefSha 'abc' -Lineages @('b :: y', 'a :: x', 'c :: z') -Nonce '42'
    $u1 = Get-SlotUniforms -Seed $seed.Bytes -Slot 1
    Check 'DRAW' 'D4 (wave 26b D3: every field length-prefixed): seed = SHA-256("1:t|7:framing|3:abc|26:6:a :: x,6:b :: y,6:c :: z|2:42") (lineages sorted ordinally, each <len>:<lineage>) = 7469dd58...f0801a; slot 1: SHA-256(seed || 00000001) -> pick 0.8404728740802851, explore 0.5005193721267926 (top 53 bits / 2^53, exact)' ($seed.Hex -eq '7469dd588269f0ea17af01de6564223f99e6a84d4c4395b22c009e2fe2f0801a' -and $seed.Text -eq '1:t|7:framing|3:abc|26:6:a :: x,6:b :: y,6:c :: z|2:42' -and $u1.Pick -eq 0.8404728740802851 -and $u1.Explore -eq 0.5005193721267926) "$($seed.Hex) $($u1.Pick.ToString('R', $inv)) $($u1.Explore.ToString('R', $inv))"
    $cands = @(
        [pscustomobject]@{ Position = 1; Lab = 'openai'; Weight = 1.125; Pinned = $false },
        [pscustomobject]@{ Position = 2; Lab = 'zhipu'; Weight = 1.9; Pinned = $false },
        [pscustomobject]@{ Position = 3; Lab = 'zhipu'; Weight = 0.6; Pinned = $false },
        [pscustomobject]@{ Position = 4; Lab = 'xiaomi'; Weight = 1.5; Pinned = $false })
    $golden = @('1/lab-draw 4/lab-draw 2/lab-draw', '1/lab-draw 2/lab-draw 4/lab-draw', '1/lab-draw 2/lab-draw 4/lab-explore', '4/lab-draw 2/lab-draw 1/lab-draw', '2/lab-draw 4/lab-draw 1/lab-explore')
    $got = @(foreach ($n in 1..5) {
            $s = Get-PanelSeed -Task 't' -Purpose 'framing' -BriefSha '' -Lineages @('x') -Nonce "$n"
            # (Invoke-PanelDraw hands back the array itself: assigned, then enumerated)
            $seats = Invoke-PanelDraw -Candidates $cands -K 3 -Seed $s.Bytes
            ($seats | ForEach-Object { "$($_.Candidate.Position)/$($_.Rule)" }) -join ' '
        })
    Check 'DRAW' 'D4 golden sequences: four candidates of three labs (zhipu twice, one below neutral), k=3, nonces 1..5 - exactly the reference implementation''s seats and rules on both runtimes; the below-neutral zhipu entry never seated' (($got -join ' ; ') -eq ($golden -join ' ; ')) ($got -join ' ; ')
    $exp = 0
    for ($n = 1; $n -le 2000; $n++) { $s = Get-PanelSeed -Task 't' -Purpose 'x' -BriefSha '' -Lineages @('x') -Nonce "$n"; if ((Get-SlotUniforms -Seed $s.Bytes -Slot 1).Explore -lt 0.2) { $exp++ } }
    Check 'DRAW' 'D4 statistical bound: over 2000 seeds the exploration share of a slot is 0.2 within 0.17..0.23 (exactly 408 here - deterministic; 419 before the length-prefixed seed)' ($exp -ge 340 -and $exp -le 460 -and $exp -eq 408) "$exp of 2000"
    $gap = @([pscustomobject]@{ Position = 1; Lab = 'a'; Weight = 2.0; Pinned = $false }, [pscustomobject]@{ Position = 2; Lab = 'a'; Weight = 1.9; Pinned = $false }, [pscustomobject]@{ Position = 3; Lab = 'b'; Weight = 0.4; Pinned = $false })
    $gapBad = 0; $bLab = 0
    for ($n = 1; $n -le 50; $n++) {
        $s = Get-PanelSeed -Task 't' -Purpose 'decision' -BriefSha '' -Lineages @('x') -Nonce "$n"
        $st = Invoke-PanelDraw -Candidates $gap -K 2 -Seed $s.Bytes
        if (-not ($st[0].Rule -like 'lab-*' -and $st[0].Candidate.Lab -eq 'a')) { $gapBad++ }
        foreach ($x in $st) { if ($x.Candidate.Lab -eq 'b' -and $x.Rule -like 'lab-*') { $bLab++ } }
    }
    Check 'DRAW' 'D1 quality gap: lab a (2.0, 1.9) and lab b (0.4, below neutral), k=2, 50 seeds - the lab reserve is ONE seat (only a has an entry >= neutral), always filled from a; b never earns a lab seat (only a rank seat by weight or exploration)' ($gapBad -eq 0 -and $bLab -eq 0) "bad $gapBad, b by lab $bLab"
    $pin = @([pscustomobject]@{ Position = 1; Lab = 'x'; Weight = 1.125; Pinned = $false }, [pscustomobject]@{ Position = 2; Lab = 'y'; Weight = 0.3; Pinned = $true }, [pscustomobject]@{ Position = 3; Lab = 'z'; Weight = 1.125; Pinned = $false })
    $sp1 = Invoke-PanelDraw -Candidates $pin -K 2 -Seed (Get-PanelSeed -Task 't' -Purpose 'x' -BriefSha '' -Lineages @('x') -Nonce '1').Bytes
    Check 'DRAW' 'D7: a pinned (required) candidate takes the first seat before the draw (rule required), even below neutral; the size counts it' ($sp1.Count -eq 2 -and $sp1[0].Candidate.Position -eq 2 -and $sp1[0].Rule -eq 'required' -and $sp1[1].Rule -like 'lab-*') (($sp1 | ForEach-Object { "$($_.Candidate.Position)/$($_.Rule)" }) -join ' ')
}

# =============================================================== ROUTE: Select-PanelRouting in process
if (Want 'ROUTE') {
    $now = [datetime]::UtcNow
    $mk = { param([int]$Pos, [string]$Prov, [string]$Model, [string]$State = 'run', [string]$SkipKind = '', [string]$Lab = '', [string[]]$Roles = @()) [pscustomobject]@{ Entry = [pscustomobject]@{ Position = $Pos; Provider = $Prov; Model = $Model; Engine = 'codex'; Lab = $Lab; Roles = $Roles }; Identity = [pscustomobject]@{ Provider = $Prov; Model = $Model; Engine = 'codex' }; State = $State; Reason = $(if ($State -eq 'skipped') { 'x' } else { '' }); SkipKind = $SkipKind; Verdict = $null } }
    $five = { @((& $mk 1 'openai' 'gpt-5.1'), (& $mk 2 'ZAI' 'glm-5.3'), (& $mk 3 'mimo' 'mimo-v2.6-pro'), (& $mk 4 'byteplus' 'kimi-k2.5'), (& $mk 5 'local' 'odd-model')) }
    $r0 = Select-PanelRouting -Members (& $five) -Size 2 -Purpose 'diff-review' -Order 'routed' -Task 't' -Nonce 'n' -UtcNow $now
    Check 'ROUTE' 'D5: routed without any rating -> roster order (mode roster, fallback "no ratings"), size 2: #1 and #2 seated (rule roster), #3..#5 not-picked "panel size 2"' ($r0.Routing.mode -eq 'roster' -and $r0.Routing.fallback -eq 'no ratings' -and (Picks $r0.Routing) -eq '1/roster 2/roster' -and (@($r0.Members | ForEach-Object { $_.State }) -join ',') -eq 'run,run,not-picked,not-picked,not-picked' -and $r0.Members[2].Reason -eq 'panel size 2' -and @($r0.Warnings).Count -eq 0) "$($r0.Routing.mode)/$($r0.Routing.fallback) $(Picks $r0.Routing)"
    $rq = Select-PanelRouting -Members @((& $mk 1 'openai' 'gpt-5.1'), (& $mk 2 'ZAI' 'glm-5.3'), (& $mk 3 'mimo' 'mimo-v2.6-pro' -State 'skipped' -SkipKind 'weighty')) -Size 1 -Order 'roster' -Required @(3) -Purpose 'chore' -Task 't' -UtcNow $now
    Check 'ROUTE' 'D7 in roster order: a required entry held back only by the weighty gate is eligible and pinned; the size 1 is raised to the required count - only #3 runs; the rest not-picked' ($rq.K -eq 1 -and (Picks $rq.Routing) -eq '3/required' -and $rq.Members[2].State -eq 'run' -and $rq.Members[0].State -eq 'not-picked' -and (@($rq.Routing.required) -join ',') -eq 'mimo :: mimo-v2.6-pro') "$(Picks $rq.Routing) k=$($rq.K)"
    $rAll = Select-PanelRouting -Members (& $five) -Size 0 -SizeSource '-PanelAll' -Order 'roster' -Task 't' -UtcNow $now
    $rBig = Select-PanelRouting -Members @((& $mk 1 'openai' 'gpt-5.1'), (& $mk 2 'ZAI' 'glm-5.3' -State 'skipped' -SkipKind 'unavailable')) -Size 9 -SizeSource '-PanelSize' -Order 'roster' -Task 't' -UtcNow $now
    Check 'ROUTE' 'D6 size precedence: size 0 (-PanelAll / stuck) seats every eligible member (5); -PanelSize 9 is capped at the eligible count (1 - an unavailable entry stays skipped, never not-picked)' ($rAll.K -eq 5 -and @($rAll.Picked).Count -eq 5 -and $rBig.K -eq 1 -and $rBig.Members[1].State -eq 'skipped') "$($rAll.K) $($rBig.K)"
    $rf = Select-PanelRouting -Members @((& $mk 1 'openai' 'gpt-5.1'), (& $mk 2 'ZAI' 'glm-5.3' -State 'skipped' -SkipKind 'unavailable')) -Size 3 -SizeSource 'purpose' -Purpose 'framing' -Order 'roster' -Task 't' -UtcNow $now
    $rf2 = Select-PanelRouting -Members @((& $mk 1 'openai' 'gpt-5.1')) -Size 1 -SizeSource '-PanelSize' -Purpose 'decision' -Order 'roster' -Task 't' -UtcNow $now
    Check 'ROUTE' 'D6 floor: a framing panel that seats 1 member warns ("panel floor: a framing panel runs 1 member ..."), after (wave 26b, D2) "panel size reduced: asked 3, eligible 1"; -PanelSize 1 on a decision panel does not' (@($rf.Warnings).Count -eq 2 -and $rf.Warnings[0] -eq 'panel size reduced: asked 3, eligible 1' -and $rf.Warnings[1] -like 'panel floor: a framing panel runs 1 member - framing questions should hear at least 2 reviewers*' -and $rf.Routing.size_asked -eq 3 -and $rf.Routing.size -eq 1 -and @($rf2.Warnings).Count -eq 0) ($rf.Warnings -join ' | ')
    $ratings = @(foreach ($x in (Routing-Ratings)) { [pscustomobject]@{ Provider = $x.provider; Model = $x.model; Engine = 'codex'; Purpose = 'framing'; Topics = [string[]]@(); ConsultWhen = [DateTimeOffset]::Parse($x.consult_when, $inv); Useful = $x.useful } })
    $rr = Select-PanelRouting -Members (& $five) -Size 3 -Purpose 'framing' -Order 'routed' -Ratings $ratings -Task 't' -Nonce '11' -NonceSource '-PanelSeed' -UtcNow $now
    Check 'ROUTE' 'D1: routed with evidence - no fallback; an entry whose model has no known vendor prefix is a lab of its own and a routed panel warns ("routing: no lab known for #5 local :: odd-model ..."); the eligible record carries lab, lab_source, score, basis, ratings' ($rr.Routing.mode -eq 'routed' -and -not $rr.Routing.fallback -and $rr.Members[4].Lab -eq 'local :: odd-model' -and @($rr.Warnings | Where-Object { $_ -like 'routing: no lab known for #5 local :: odd-model*' }).Count -eq 1 -and $rr.Routing.eligible[1].lab -eq 'zhipu' -and $rr.Routing.eligible[1].score -eq 1.7083 -and $rr.Routing.eligible[1].basis -eq 'purpose' -and $rr.Routing.eligible[1].ratings -eq 4 -and $rr.Routing.eligible[0].basis -eq 'neutral' -and $rr.Routing.nonce_source -eq '-PanelSeed') ($rr.Warnings -join ' | ')
    # roles: by score rank, willingness, more roles than members refused
    $members3 = @(& $five)[0..3]
    $rr3 = Select-PanelRouting -Members $members3 -Size 3 -Purpose 'framing' -Order 'roster' -Ratings $ratings -Task 't' -UtcNow $now
    $ra = Select-RoleAssignment -Members $rr3.Picked -Roles @('security', 'tests')
    $w1 = (& $mk 1 'openai' 'gpt-5.1' -Roles @('tests'))
    $w2 = (& $mk 2 'ZAI' 'glm-5.3')
    $rrW = Select-PanelRouting -Members @($w1, $w2) -Size 2 -Purpose 'framing' -Order 'roster' -Ratings $ratings -Task 't' -UtcNow $now
    $rw = Select-RoleAssignment -Members $rrW.Picked -Roles @('tests', 'security')
    $rx = Select-RoleAssignment -Members $rrW.Picked -Roles @('a', 'b', 'c')
    Check 'ROUTE' 'D8 roles: -Roles security,tests go by SCORE RANK among the seated (security -> #2 ZAI 1.708, tests -> #1 openai 1.125 over #3 mimo 0.6); -Roles tests,security: the willing entry (roster roles ["tests"], openai 1.125) takes tests although ZAI ranks higher; three roles for two members refused' ($ra.Of[2] -eq 'security' -and $ra.Of[1] -eq 'tests' -and -not $ra.Of.ContainsKey(3) -and $rw.Of[1] -eq 'tests' -and $rw.Of[2] -eq 'security' -and $rx.Error -like '-Roles names 3 roles for 2 panel members*') "$(($ra.Of.Keys | Sort-Object | ForEach-Object { "$_=$($ra.Of[$_])" }) -join ',') / $(($rw.Of.Keys | Sort-Object | ForEach-Object { "$_=$($rw.Of[$_])" }) -join ',') / $($rx.Error)"
    $rp = Join-Path $work 'roles-repo\.collab'
    [void][IO.Directory]::CreateDirectory((Join-Path $rp 'roles'))
    [IO.File]::WriteAllText((Join-Path $rp 'roles\security.md'), "Repository security role.`n", $u8)
    $pr = Split-Path -Parent $scripts
    $f1 = Resolve-RoleFile -Name 'security' -CollabRoot $rp -PluginRoot $pr
    $f2 = Resolve-RoleFile -Name 'tests' -CollabRoot $rp -PluginRoot $pr
    $f3 = Resolve-RoleFile -Name '../roles/security' -CollabRoot $rp -PluginRoot $pr
    $f4 = Resolve-RoleFile -Name 'nope' -CollabRoot $rp -PluginRoot $pr
    Check 'ROUTE' 'D8 role files: the repository''s <CollabDir>/roles/security.md wins over the plugin''s; tests from templates/role-tests.md; "../roles/security" refused as no slug before any path is built; an unknown role lists the known ones (docs, edge-cases, security, tests)' ($f1.Source -eq 'repository' -and $f1.Text -eq 'Repository security role.' -and $f2.Source -eq 'plugin' -and $f2.Path -like '*templates*role-tests.md' -and $f3.Error -like "role '../roles/security' is not a slug*" -and -not $f3.Path -and $f4.Error -like "unknown role 'nope'*known: docs, edge-cases, security, tests*") "$($f1.Source) $($f2.Source) | $($f3.Error) | $($f4.Error)"
}

# =============================================================== SIZE: the panel's size end to end (dry runs)
if (Want 'SIZE') {
    $r = New-Repo 'size'
    $cases = [ordered]@{ 'none' = @(@(), 1); 'diff-review' = @(@('-Purpose', 'diff-review'), 2); 'acceptance' = @(@('-Purpose', 'acceptance'), 4); 'stuck' = @(@('-Purpose', 'stuck'), 5); '-PanelSize 2' = @(@('-PanelSize', '2'), 2); '-PanelSize 9' = @(@('-PanelSize', '9'), 5); '-PanelAll' = @(@(), 5) }
    $badZ = @()
    foreach ($k in $cases.Keys) {
        $a = @('-DryRun', '-Prompt', 'x') + @($cases[$k][0])
        $a = $(if ($k -eq '-PanelAll') { @('-PanelAll') + $a } else { @('-Panel') + $a })
        $o = Consult $r $roster5 $a
        $want = [int]$cases[$k][1]
        $np = @([regex]::Matches($o.Out, '(?m)^  #\d .* - not picked: panel size \d+$')).Count
        if (-not ($o.Code -eq 0 -and $o.First -match ": $want of 5 roster entries would run" -and $np -eq (5 - $want) -and @($o.Previews).Count -eq $want)) { $badZ += "$k -> $($o.Code) '$($o.First)' not-picked $np previews $(@($o.Previews).Count)" }
    }
    Check 'SIZE' 'D6 end to end (5 eligible, no ratings): no purpose 1, diff-review 2, acceptance 4, stuck 5, -PanelSize 2 -> 2, -PanelSize 9 -> 5 (capped), -PanelAll 5; the header "k of 5 roster entries would run", one "not picked: panel size k" line per other entry, one member plan each' ($badZ.Count -eq 0) ($badZ -join ' | ')
    $v1 = Consult $r $roster5 @('-PanelAll', '-PanelSize', '2', '-DryRun', '-Prompt', 'x')
    $v2 = Consult $r $roster5 @('-Panel', '-PanelSize', '0', '-DryRun', '-Prompt', 'x')
    $v3 = Consult $r $roster5 @('-PanelSize', '2', '-DryRun', '-Prompt', 'x')
    $v4 = Consult $r $roster5 @('-Panel', '-PanelOrder', 'best', '-DryRun', '-Prompt', 'x')
    $v5 = Consult $r $roster5 @('-Panel', '-PanelSeed', 'a b', '-DryRun', '-Prompt', 'x')
    $v6 = Consult $r $roster5 @('-Roles', 'tests', '-DryRun', '-Prompt', 'x')
    Check 'SIZE' 'refusals: -PanelSize with -PanelAll, -PanelSize 0, -PanelSize without -Panel, -PanelOrder best, a -PanelSeed with a blank, -Roles without -Panel (exit 1 each, nothing started)' ($v1.Code -eq 1 -and $v1.First -like '*-PanelSize does not go with -PanelAll*' -and $v2.Code -eq 1 -and $v2.First -like '*-PanelSize must be 1 or more*' -and $v3.Code -eq 1 -and $v3.First -eq 'codex-consult: -PanelSize goes with -Panel (or -PanelAll) only.' -and $v4.Code -eq 1 -and $v4.First -like '*-PanelOrder must be roster or routed*' -and $v5.Code -eq 1 -and $v5.First -like '*-PanelSeed must be*' -and $v6.Code -eq 1 -and $v6.First -eq 'codex-consult: -Roles goes with -Panel (or -PanelAll) only.') "$($v1.First) | $($v2.First) | $($v3.First) | $($v4.First) | $($v5.First) | $($v6.First)"
    $one = Write-Roster 'one' '{"roster_version":1,"reviewers":[{"provider":"ZAI","model":"glm-5.3"}]}'
    $fl = Consult $r $one @('-Panel', '-Purpose', 'framing', '-DryRun', '-Prompt', 'x')
    $fl2 = Consult $r $one @('-Panel', '-Purpose', 'framing', '-PanelSize', '1', '-DryRun', '-Prompt', 'x')
    $pw = @($fl.Previews)[0]
    Check 'SIZE' 'D6 floor end to end: a framing panel with one eligible member warns (console "WARNING: panel floor: ...", the member''s ledger warnings[]); with -PanelSize 1 no warning' ($fl.Code -eq 0 -and $fl.Out -match '(?m)^WARNING: panel floor: a framing panel runs 1 member' -and @($pw.warnings | Where-Object { $_ -like 'panel floor:*' }).Count -eq 1 -and $fl2.Out -notmatch 'panel floor' -and @(Get-RealWarnings @($fl2.Previews)[0].warnings).Count -eq 0 -and (Test-TestModeWarning @($fl2.Previews)[0].warnings)) "$(@($pw.warnings) -join ' | ')"
}

# =============================================================== ROUTED: the seeded draw end to end
if (Want 'ROUTED') {
    $r = New-Repo 'routed'
    Seed-Ratings $r 'rated' (Routing-Ratings)
    # golden: the reference implementation over the eligible five, purpose framing, no brief, nonce 15
    $d1 = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-PanelSeed', '15', '-DryRun', '-Prompt', 'x')
    $d2 = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-PanelSeed', '15', '-DryRun', '-Prompt', 'x')
    $p1 = @($d1.Previews)[0]
    $rt1 = $p1.panel.routing
    Check 'ROUTED' 'D4 end to end: -PanelSeed 15 over the five (ZAI 1.708, kimi 1.5625, openai and qwen neutral, mimo 0.6) seats exactly #2 (lab-draw), #4 (lab-explore), #1 (lab-draw) - the reference implementation''s seats (tests/reference-draw.py); the same command again seats the same; the dry run prints the routing ("Routing: routed ...", "picked  : 1. #2 ZAI :: glm-5.3 (lab-draw), ...")' ($d1.Code -eq 0 -and (Picks $rt1) -eq '2/lab-draw 4/lab-explore 1/lab-draw' -and (Picks (@($d2.Previews)[0].panel.routing)) -eq (Picks $rt1) -and $rt1.seed.StartsWith('6ed796265174') -and $rt1.nonce -eq '15' -and $rt1.nonce_source -eq '-PanelSeed' -and $d1.Out -match '(?m)^Routing: routed by the ratings - size 3 \(the default of purpose framing\); seed 6ed796265174' -and $d1.Out -match '(?m)^  picked  : 1\. #2 ZAI :: glm-5\.3 \(lab-draw\), 2\. #4 byteplus :: kimi-k2\.5 \(lab-explore\), 3\. #1 openai :: gpt-5\.1 \(lab-draw\)$') "$(Picks $rt1) seed $($rt1.seed.Substring(0, 12)) code $($d1.Code)"
    Check 'ROUTED' 'D6/D9: the members get n and NN in SEAT order (#2 n=1, #4 n=2, #1 n=3); #3 and #5 "not picked: panel size 3"; the ledger preview''s panel.members carry state not-picked; roster.skipped lists no not-picked entry; routing.eligible has all five with lab and score' ($d1.Out -match '(?m)^  #2 ZAI :: glm-5\.3 - member, n=1, handoff 01$' -and $d1.Out -match '(?m)^  #4 byteplus :: kimi-k2\.5 - member, n=2, handoff 02$' -and $d1.Out -match '(?m)^  #1 openai :: gpt-5\.1 - member, n=3, handoff 03$' -and $d1.Out -match '(?m)^  #5 alibaba :: qwen3\.8-max - not picked: panel size 3$' -and (@($p1.panel.members | ForEach-Object { $_.state }) -join ',') -eq 'run,run,not-picked,run,not-picked' -and @($p1.roster.skipped).Count -eq 0 -and @($rt1.eligible).Count -eq 5 -and $rt1.eligible[3].lab -eq 'moonshot' -and $rt1.eligible[3].score -eq 1.5625) "$(@($p1.panel.members | ForEach-Object { $_.state }) -join ',')"
    $d3 = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_TEST_PANEL_SEED = '18' }
    $d4 = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = '2026-09-27T10:00:00+00:00' }
    $d5 = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-PanelOrder', 'roster', '-PanelSeed', '15', '-DryRun', '-Prompt', 'x')
    $rt3 = @($d3.Previews)[0].panel.routing
    $rt4 = @($d4.Previews)[0].panel.routing
    $rt5 = @($d5.Previews)[0].panel.routing
    Check 'ROUTED' 'D4 the nonce: CODEX_CONSULT_TEST_PANEL_SEED 18 -> #1 (lab-explore) #4 #5 (lab-draw; nonce_source CODEX_CONSULT_TEST_PANEL_SEED); without either, the UTC date of the consult clock (2026-09-27, nonce_source date); D5 -PanelOrder roster -> #1 #2 #3 (rule roster), mode roster, no fallback' ((Picks $rt3) -eq '1/lab-explore 4/lab-draw 5/lab-draw' -and $rt3.nonce_source -eq 'CODEX_CONSULT_TEST_PANEL_SEED' -and $rt4.nonce -eq '2026-09-27' -and $rt4.nonce_source -eq 'date' -and $rt5.mode -eq 'roster' -and -not $rt5.fallback -and (Picks $rt5) -eq '1/roster 2/roster 3/roster') "$(Picks $rt3) | $($rt4.nonce)/$($rt4.nonce_source) | $(Picks $rt5)"
    # the real run of the same command takes the seats the dry run printed
    $real = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-PanelSeed', '15', '-Prompt', 'x', '-ReplyName', 'rt') @{ FAKE_CODEX_REPLY = $advise }
    $led = @(Ledger $r)
    $sumAll = [regex]::Matches($real.Out, '(?m)^Panel [0-9a-f]{8}: .*$')
    $sumAt = $sumAll[$sumAll.Count - 1]
    Check 'ROUTED' 'the REAL run (same seed): exit 0; three ledger entries in seat order (n 1..3 = ZAI, kimi, openai), each with the identical panel.routing (picked #2 #4 #1), panel asked 3, started 3, usable 3 (written when the panel ended); the summary "3 of 5 entries ran (asked 3, started 3, usable 3; ...)" and "not picked (panel size 3): mimo :: mimo-v2.6-pro, alibaba :: qwen3.8-max"' ($real.Code -eq 0 -and $led.Count -eq 3 -and (@($led | ForEach-Object { "$($_.n):$($_.reviewer.model)" }) -join ',') -eq '1:glm-5.3,2:kimi-k2.5,3:gpt-5.1' -and @($led | Where-Object { (Picks $_.panel.routing) -eq '2/lab-draw 4/lab-explore 1/lab-draw' }).Count -eq 3 -and @($led | Where-Object { $_.panel.asked -eq 3 -and $_.panel.started -eq 3 -and $_.panel.usable -eq 3 }).Count -eq 3 -and $sumAt.Value -match '^Panel [0-9a-f]{8}: 3 of 5 entries ran \(asked 3, started 3, usable 3; wall clock [0-9.]+ s; ' -and $real.Out -match '(?m)^  not picked \(panel size 3\): mimo :: mimo-v2\.6-pro, alibaba :: qwen3\.8-max$') "$($real.Code) $(@($led | ForEach-Object { "$($_.n):$($_.reviewer.model):$($_.panel.started)/$($_.panel.usable)" }) -join ',') | $($sumAt.Value)"
    # roles by score rank in the routed panel (-Roles), in the prompt and the ledger
    $rl = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-PanelSeed', '18', '-Roles', 'security,tests', '-DryRun', '-Prompt', 'x', '-Brief', 'app.txt')
    $pvs = @($rl.Previews)
    $roleOf = @{}; foreach ($pv in $pvs) { $roleOf[[int]$pv.roster.position] = [string]$pv.role }
    # (the brief is part of the seed: the seats come from the recorded routing; the roles go by score)
    $rtR = $pvs[0].panel.routing
    $seated = @($rtR.picked | ForEach-Object { $p = $_.position; [pscustomobject]@{ Position = [int]$p; Score = [double](@($rtR.eligible | Where-Object { $_.position -eq $p })[0].score); Slot = [int]$_.slot } } | Sort-Object -Property @{ Expression = { $_.Score }; Descending = $true }, @{ Expression = { $_.Slot }; Descending = $false })
    $wantRoles = @{}; $wantRoles[$seated[0].Position] = 'security'; $wantRoles[$seated[1].Position] = 'tests'; $wantRoles[$seated[2].Position] = ''
    $txt = $rl.Out
    $iAsk = $txt.IndexOf("`nx`n"); $iRole = $txt.IndexOf('Your role in this review: '); $iBrief = $txt.IndexOf('Read the brief at `app.txt`')
    Check 'ROUTED' 'D8 end to end: -Roles security,tests over the seated three - security to the best score, tests to the next, none for the third (by the recorded routing.eligible scores); ledger role; the role block sits after the ask and before the brief line' ($rl.Code -eq 0 -and $pvs.Count -eq 3 -and @($seated).Count -eq 3 -and $roleOf[$seated[0].Position] -eq 'security' -and $roleOf[$seated[1].Position] -eq 'tests' -and $roleOf[$seated[2].Position] -eq '' -and $iRole -gt $iAsk -and $iBrief -gt $iRole) "$(($roleOf.Keys | Sort-Object | ForEach-Object { "#$_=$($roleOf[$_])" }) -join ', ') seats $(Picks $rtR)"
}

# =============================================================== REQUIRE: required reviewers, exit 5
if (Want 'REQUIRE') {
    $r = New-Repo 'require'
    $x1 = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-Require', 'mimo', '-Prompt', 'x', '-ReplyName', 'q') @{ RT_MIMO_KEY = ''; FAKE_CODEX_REPLY = $advise }
    $x1d = Consult $r $roster5 @('-Panel', '-Purpose', 'framing', '-Require', 'mimo', '-DryRun', '-Prompt', 'x') @{ RT_MIMO_KEY = '' }
    Check 'REQUIRE' 'D7: a required reviewer that is out (-Require mimo; its key unset) refuses the panel BEFORE anything starts - exit 5, "required reviewer not available (-Require): #3 mimo :: mimo-v2.6-pro (missing: env RT_MIMO_KEY not set); nothing was started ..."; no ledger, no handoff, no record; the dry run the same (exit 5)' ($x1.Code -eq 5 -and $x1.First -like 'codex-consult: required reviewer not available (-Require): #3 mimo :: mimo-v2.6-pro (*RT_MIMO_KEY*); nothing was started - wait for it, or run without that -Require (exit 5).' -and @(Ledger $r).Count -eq 0 -and @(Get-ChildItem (Join-Path $r '.collab\t\handoffs')).Count -eq 0 -and (Get-PendingPaths -TaskDir (Join-Path $r '.collab\t')).Count -eq 0 -and $x1d.Code -eq 5 -and $x1d.First -eq $x1.First) $x1.First
    $reqR = Write-Roster 'require' '{"roster_version":1,"require":{"acceptance":["#3"]},"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"mimo","model":"mimo-v2.6-pro","panel":"weighty"}]}'
    $x2 = Consult $r $reqR @('-Panel', '-Purpose', 'acceptance', '-DryRun', '-Prompt', 'x') @{ RT_MIMO_KEY = '' }
    $x3 = Consult $r $reqR @('-Panel', '-Purpose', 'acceptance', '-Require', 'none', '-DryRun', '-Prompt', 'x') @{ RT_MIMO_KEY = '' }
    $x4 = Consult $r $reqR @('-Panel', '-Purpose', 'checkpoint', '-Require', '#3', '-DryRun', '-Prompt', 'x')
    $p4 = @($x4.Previews)[0]
    Check 'REQUIRE' 'D7: the roster''s require.acceptance (#3) is the default of an acceptance panel - out -> exit 5 naming "(roster require.acceptance)" and "-Require none"; -Require none drops it (exit 0, 2 of 3 run); a required WEIGHTY entry on a light purpose (checkpoint, size 1) is pinned: the only seat is #3 (rule required), routing.required names it' ($x2.Code -eq 5 -and $x2.First -like '*required reviewer not available (roster require.acceptance): #3 mimo :: mimo-v2.6-pro*-Require none*' -and $x3.Code -eq 0 -and $x3.First -match ': 2 of 3 roster entries would run' -and $x4.Code -eq 0 -and $x4.First -match ': 1 of 3 roster entries would run' -and (Picks $p4.panel.routing) -eq '3/required' -and (@($p4.panel.routing.required) -join ',') -eq 'mimo :: mimo-v2.6-pro' -and $x4.Out -match '(?m)^  #3 mimo :: mimo-v2\.6-pro - member, n=1, handoff 01, required$') "$($x2.First) | $($x3.First) | $($x4.First)"
    $x5 = Consult $r $roster5 @('-Panel', '-Require', 'openai :: gpt-6-astra', '-DryRun', '-Prompt', 'x')
    $x6 = Consult $r $roster5 @('-Require', '#2', '-DryRun', '-Prompt', 'x')
    $x7 = Consult $r $roster5 @('-Panel', '-Require', 'none,#2', '-DryRun', '-Prompt', 'x')
    $x8 = Consult $r $roster5 @('-Panel', '-Engine', 'codex', '-Model', 'glm-5.3', '-Require', '#3', '-DryRun', '-Prompt', 'x')
    Check 'REQUIRE' 'D7 refusals: a matcher that names no entry (exit 1: "-Require: ''openai :: gpt-6-astra'' matches no roster entry"); -Require on a roster walk (no -Panel, no -Provider; exit 1); "none" combined with a reviewer (exit 1); a required entry outside the -Model filter -> exit 5 "(not in this panel: -Engine codex -Model glm-5.3)"' ($x5.Code -eq 1 -and $x5.First -eq "codex-consult: -Require: 'openai :: gpt-6-astra' matches no roster entry." -and $x6.Code -eq 1 -and $x6.First -like 'codex-consult: -Require goes with -Panel, or with -Provider*' -and $x7.Code -eq 1 -and $x7.First -like '*-Require none stands alone*' -and $x8.Code -eq 5 -and $x8.First -like '*#3 mimo :: mimo-v2.6-pro (not in this panel: -Engine codex -Model glm-5.3)*') "$($x5.First) | $($x6.First) | $($x7.First) | $($x8.First)"
    # a single -Provider run: roster-walk semantics (a usage limit without a reset is out for 60 min)
    $rs = New-Repo 'require-single'
    $hit = [DateTimeOffset]::Parse('2026-09-27T10:00:00+00:00', $inv)
    Seed-Ledger $rs 'other' @((New-Entry 1 'ZAI' 'glm-5.3' $zaiFp $hit -Outcome 'failed: usage limit' -Failure (Quota $hit "You've hit your usage limit.")))
    $zai2 = Write-Roster 'zai-two' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"},{"provider":"ZAI","model":"glm-5.3-flash"}]}'
    $s1 = Consult $rs $zai2 @('-Provider', 'openai', '-Require', 'ZAI :: glm-5.3-flash', '-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = '2026-09-27T10:30:00+00:00' }
    $s2 = Consult $rs $zai2 @('-Provider', 'openai', '-Require', 'ZAI :: glm-5.3-flash', '-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_NOW = '2026-09-27T11:01:00+00:00' }
    $s3 = Consult $rs $zai2 @('-Provider', 'openai', '-Require', '#1', '-Prompt', 'x', '-ReplyName', 's') @{ CODEX_CONSULT_NOW = '2026-09-27T10:30:00+00:00'; FAKE_CODEX_REPLY = $advise }
    Check 'REQUIRE' 'D7/D9 single -Provider run: a SHARED endpoint outage (the limit was recorded on ZAI :: glm-5.3, the required glm-5.3-flash shares its endpoint) and the unknown-reset transition - 30 min after the hit: exit 5 "(usage limit hit ..., reset unknown; retry after ...; back ...)"; 61 min after: available (exit 0, "required    : #3 available"); a required reviewer that is available lets the run proceed (a real run, exit 0, usable)' ($s1.Code -eq 5 -and $s1.First -like '*required reviewer not available (-Require, judged like the roster walk): #3 ZAI :: glm-5.3-flash (usage limit hit *reset unknown*; back *' -and $s2.Code -eq 0 -and $s2.Out -match '(?m)^required    : #3 available \(-Require\)$' -and $s3.Code -eq 0 -and @(Ledger $rs).Count -eq 1 -and (Ledger $rs)[0].bridge_outcome -eq 'usable reply') "$($s1.First) | $($s2.Code) | $($s3.Code)"
    # a required member failing AFTER the start: the next members are not started, exit 5
    $rf = New-Repo 'require-fail'
    $x9 = Consult $rf $roster5 @('-Panel', '-Purpose', 'framing', '-PanelOrder', 'roster', '-Require', '#2', '-PanelConcurrency', '1', '-Prompt', 'x', '-ReplyName', 'f') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_FAIL_ON = 'model_provider=""ZAI""' }
    $l9 = @(Ledger $rf)
    Check 'REQUIRE' 'D7 after the start: the required #2 takes the first seat (n=1); it fails -> no further member starts ("skipped  not started: the required member ZAI :: glm-5.3 produced no usable reply - the panel stops (exit 5)"), the summary names it, exit 5; the ledger has the one entry with routing.required' ($x9.Code -eq 5 -and $l9.Count -eq 1 -and $l9[0].reviewer.provider -eq 'ZAI' -and (@($l9[0].panel.routing.required) -join ',') -eq 'ZAI :: glm-5.3' -and $x9.Out -match 'not started: the required member ZAI :: glm-5\.3 produced no usable reply - the panel stops \(exit 5\)' -and $x9.Out -match '(?m)^  required member without a usable reply: ZAI :: glm-5\.3 - exit 5$' -and $l9[0].panel.usable -eq 0 -and $l9[0].panel.started -eq 1) "$($x9.Code) entries $($l9.Count)"
}

# =============================================================== ROLE: -Role on a single run
if (Want 'ROLE') {
    $r = New-Repo 'role'
    [IO.File]::WriteAllText((Join-Path $r 'brief.md'), "# brief`n", $u8)
    $o = Consult $r '' @('-Role', 'Edge-Cases', '-DryRun', '-Prompt', 'ask this', '-Brief', 'brief.md', '-Topic', 'Security,tests,security')
    $t = $o.Out
    $iAsk = $t.IndexOf("`nask this`n"); $iRole = $t.IndexOf('Your role in this review: edge-cases.'); $iBrief = $t.IndexOf('Read the brief at `brief.md`'); $iContract = $t.IndexOf('FINAL OUTPUT CONTRACT')
    $pv = @($o.Previews)[0]
    $bad1 = Consult $r '' @('-Role', '../brief', '-DryRun', '-Prompt', 'x')
    $bad2 = Consult $r '' @('-Role', 'nope', '-DryRun', '-Prompt', 'x')
    $bad3 = Consult $r '' @('-Panel', '-Role', 'docs', '-Roles', 'tests', '-DryRun', '-Prompt', 'x')
    $bad4 = Consult $r '' @('-Topic', 'a/b', '-DryRun', '-Prompt', 'x')
    Check 'ROLE' 'D8 single run: -Role Edge-Cases (canonical edge-cases) - the plugin''s block after the ask and before the brief, never before the output contract; ledger role "edge-cases"; -Topic canonical (security,tests); "../brief", an unknown role, -Role with -Roles and a topic "a/b" refused (exit 1)' ($o.Code -eq 0 -and $iContract -ge 0 -and $iAsk -gt $iContract -and $iRole -gt $iAsk -and $iBrief -gt $iRole -and $pv.role -eq 'edge-cases' -and (@($pv.topics) -join ',') -eq 'security,tests' -and $t -match '(?m)^role        : edge-cases \(plugin: .*role-edge-cases\.md\) - in the prompt after the ask$' -and $bad1.Code -eq 1 -and $bad1.First -like "*-Role: role '../brief' is not a slug*" -and $bad2.Code -eq 1 -and $bad2.First -like "*-Role: unknown role 'nope'*" -and $bad3.Code -eq 1 -and $bad3.First -like '*-Role and -Roles exclude each other*' -and $bad4.Code -eq 1 -and $bad4.First -like "*-Topic 'a/b' is not a slug*") "$($o.Code) $iContract<$iAsk<$iRole<$iBrief | $($bad1.First) | $($bad2.First)"
    $names = ($o.Previews[0].PSObject.Properties | Select-Object -First 7 | ForEach-Object { $_.Name }) -join ','
    Check 'ROLE' 'the ledger field order: n, when, purpose, topics, role, consult_id, reviewer' ($names -eq 'n,when,purpose,topics,role,consult_id,reviewer') $names
}

# =============================================================== RATE: -Rate keyed by consult_id; the scoreboard
if (Want 'RATE') {
    $r = New-Repo 'rate'
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'a', '-Topic', 'tests', '-Purpose', 'checkpoint') @{ FAKE_CODEX_REPLY = $advise }
    $e = @(Ledger $r)[0]
    $a1 = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '1', '-Useful', 'no', '-Note', 'n')
    $a2 = Run-Tool $findingsPs $r @('-Task', 't', '-Rate', '1', '-Useful', 'yes')
    $st = [IO.File]::ReadAllText((Join-Path $r '.collab\t\findings.json'), $u8) | ConvertFrom-Json
    $rt = @($st.ratings)
    $names = ($rt[0].PSObject.Properties | ForEach-Object { $_.Name }) -join ','
    Check 'RATE' 'D2 -Rate: the record {n, consult_id, lineage, provider, model, engine, purpose, topics, consult_when, useful, note, when} copies the ledger entry (consult_id, engine codex, purpose checkpoint, topics [tests], consult_when = the entry''s when); rating it again replaces it by consult_id (one record, yes)' ($x.Code -eq 0 -and $a1.Code -eq 0 -and $a2.Code -eq 0 -and $rt.Count -eq 1 -and $names -eq 'n,consult_id,lineage,provider,model,engine,purpose,topics,consult_when,useful,note,when' -and $rt[0].consult_id -eq $e.consult_id -and $rt[0].engine -eq 'codex' -and $rt[0].purpose -eq 'checkpoint' -and (@($rt[0].topics) -join ',') -eq 'tests' -and (Iso ([DateTimeOffset]$rt[0].consult_when)) -eq (Iso ([DateTimeOffset]$e.when)) -and $rt[0].useful -eq 'yes' -and $a2.Out -match 're-rated yes \(was no\)') "$names | $($rt[0].useful)"
    # the scoreboard: SCORE (the routing score), UNIQ over a panel's findings, -By topic
    $rb = New-Repo 'board'
    $pid1 = 'aaaaaaaa-0000-4000-8000-000000000001'
    $now = [DateTimeOffset]::Now.AddHours(-2)
    Seed-Ledger $rb 'b' @(
        (New-Entry 1 'ZAI' 'glm-5.3' $zaiFp $now -Purpose 'framing' -Topics @('security') -Panel ([pscustomobject]@{ id = $pid1; position = 1; of = 2 })),
        (New-Entry 2 'mimo' 'mimo-v2.6-pro' 'x' $now -Purpose 'framing' -Topics @('security', 'tests') -Panel ([pscustomobject]@{ id = $pid1; position = 2; of = 2 })))
    $fd = { param([string]$Id, [int]$N, [string]$Path, $Line) [pscustomobject]@{ id = $Id; status = 'proposed'; severity = 'minor'; claim = 'c'; locations = [object[]]@(if ($Path) { [pscustomobject]@{ path = $Path; line = $Line } }); source = [pscustomobject]@{ consult = $N }; history = [object[]]@(); reviewer_checks = [object[]]@() } }
    Seed-Ratings $rb 'b' @((Rt 'ZAI' 'glm-5.3' 'yes' -Cid (Guid-Of 800001) -N 1 -Topics @('security')), (Rt 'ZAI' 'glm-5.3' 'yes' -N 5 -Topics @('security')), (Rt 'ZAI' 'glm-5.3' 'yes' -N 6 -Topics @('security'))) -Findings @((& $fd 'F01-1' 1 'app.txt' 1), (& $fd 'F01-2' 1 'app.txt' 9), (& $fd 'F01-3' 1 '' $null), (& $fd 'F02-1' 2 'app.txt' 1), (& $fd 'F02-2' 2 'b.txt' 3))
    $sj = Run-Tool $scoreboardPs $rb @('-Json')
    $jr = @(); try { $jr = @(($sj.Out | ConvertFrom-Json) | ForEach-Object { $_ }) } catch { }
    $zr = @($jr | Where-Object { $_.lineage -eq 'ZAI :: glm-5.3' -and $_.purpose -eq 'framing' })[0]
    $zt = @($jr | Where-Object { $_.lineage -eq 'ZAI :: glm-5.3' -and $_.purpose -eq '(total)' })[0]
    $mr = @($jr | Where-Object { $_.lineage -eq 'mimo :: mimo-v2.6-pro' -and $_.purpose -eq 'framing' })[0]
    Check 'RATE' 'D2/D10 scoreboard -Json: SCORE = the routing score (ZAI framing: 3 yes -> 1.65; its total row the all-purpose 1.65; mimo unrated 1.125); UNIQ: ZAI raised 3 in the panel, 2 unique (app.txt:1 was raised by mimo too; a finding without a location counts unique), mimo 1 of 2' ($sj.Code -eq 0 -and $zr.score -eq 1.65 -and $zt.score -eq 1.65 -and $mr.score -eq 1.125 -and $zr.unique -eq 2 -and $zr.panel_raised -eq 3 -and $mr.unique -eq 1 -and $mr.panel_raised -eq 2 -and $zr.rated_yes -eq 3) "ZAI $($zr.score)/$($zt.score) u $($zr.unique)/$($zr.panel_raised); mimo $($mr.score) u $($mr.unique)/$($mr.panel_raised)"
    $sb = Run-Tool $scoreboardPs $rb @('-By', 'topic', '-Json')
    $tj = @(); try { $tj = @(($sb.Out | ConvertFrom-Json) | ForEach-Object { $_ }) } catch { }
    $keys = @($tj | ForEach-Object { "$($_.lineage)|$($_.purpose)|$($_.consults)" }) -join ' ; '
    $mt = @($tj | Where-Object { $_.lineage -eq 'mimo :: mimo-v2.6-pro' -and $_.purpose -eq '(total)' })[0]
    $st2 = Run-Tool $scoreboardPs $rb @('-By', 'topic')
    $hdr = @(($st2.Out -split "`n") | Where-Object { $_ -match '^REVIEWER' })[0]
    $bad = Run-Tool $scoreboardPs $rb @('-By', 'model')
    Check 'RATE' '-By topic: rows per (lineage, topic) - mimo on security AND tests, once on its total (1 consult); the table header REVIEWER TOPIC ... Y/P/N SCORE UNIQ MEDIAN_S TOKENS; topic rows have no score; -By model refused' ($sb.Code -eq 0 -and $keys -like 'mimo :: mimo-v2.6-pro|security|1 ; mimo :: mimo-v2.6-pro|tests|1 ; mimo :: mimo-v2.6-pro|(total)|1 ; ZAI :: glm-5.3|security|1 ; ZAI :: glm-5.3|(total)|1 ; (all)|(total)|2' -and $mt.consults -eq 1 -and $null -eq @($tj | Where-Object { $_.purpose -eq 'security' })[0].score -and $hdr -match '^REVIEWER\s+TOPIC\s+CONSULTS\s+USABLE\s+PROSE\s+FAILED\s+RAISED\s+VERIFIED\s+REJECTED\s+WONTFIX\s+SUPERSEDED\s+OPEN\s+HIT%\s+A/H/R/D\s+Y/P/N\s+SCORE\s+UNIQ\s+MEDIAN_S\s+TOKENS$' -and $bad.Code -eq 1 -and $bad.First -like '*-By must be purpose or topic*') "$keys | $hdr"
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-companions ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
