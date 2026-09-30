# codex-consult wave 27 (0.5.0; ROADMAP R13 host invariance + R19 the coordinator's manual -
# decisions D1-D9 of .collab/host-2026-09-26/handoffs/05-claude-r13-decisions.md): the root note and
# the `${CLAUDE_PLUGIN_ROOT}` / "Claude" greps of the skills, the README and the scripts (D2, D6);
# the reviewer matcher shared by -Require and CODEX_CONSULT_COORDINATOR, the coordinator's identity,
# its refusal and its warning (D3); the child environment without the host markers - a fake engine
# that writes what it inherited: the main turn, a format repair, the timeout continuation, a detached
# background and a panel's members (D4); -Explain and the hook's pointer line (D5); the brief prefix
# (D6); the coordinate skill, the agent files and the Codex agent examples (D7); the README's install
# section for three hosts and "For the coordinator" (D1, D8). (wave 27b) The completed scrub list -
# a host session's id, messaging socket and token, attendance, executable path, pid and effort, a Z
# Code session and project, every ZCODE_PLUGIN* - with the operator's CLAUDE_CODE_USE_BEDROCK and
# CLAUDE_PLUGIN_ROOT kept; the host hint zcode and its order; the README's Z Code and Kimi Code host
# sections and the documented lists. (wave 27d) The waiting rule, revision 5, in the coordinate skill
# and the README section "Waiting: keep the prompt cache or compact" - every number recomputed from the
# formula and the prices; the Qwen Code, OpenCode and Muse Code host sections, rows and host lines
# (documented, not run live). (wave 28c) D12 the test-mode line of a dry run and of a refused run
# (TESTLINE); D14 the waiting rule, revision 6 (SKILL, README, HOSTDOCS). FAKES ONLY: fake-codex3.cmd; CODEX_HOME
# and CODEX_CONSULT_ROSTER point at scratch files, CODEX_CONSULT_HEALTH is 'none'; the host markers of
# the process that runs the harness are removed first and every case sets its own; the API key
# variables hold dummy test values. Runs under the host it is started with (powershell 5.1 or pwsh 7,
# Windows). Work files: $env:TEMP\codex-consult-tests\harness-host\<guid>, removed at the end.
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
$pluginDir = Split-Path -Parent $scripts
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$hookPs = Join-Path $scripts 'codex-consult-hook.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-host') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
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
    return $r
}
$toml = "model = `"gpt-5.1`"`n`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"RT_ZAI_KEY`"`nwire_api = `"responses`"`n"
$codexHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), $toml, $u8)
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
# The host markers of D4 and (wave 27b) the completed list - dummy values only - and the variables
# that are NOT markers and must be kept (the operator's own setting, the plugin root)
$markerSet = [ordered]@{
    CODEX_SESSION_ID = '01a0e4bc-0000-7000-8000-000000000001'; CODEX_THREAD_ID = '01a0e4bc-0000-7000-8000-000000000001'; CODEX_CI = '1'
    CODEX_SANDBOX_NETWORK_DISABLED = '1'; CODEX_SANDBOX = 'seatbelt'; CLAUDECODE = '1'; CLAUDE_CODE_ENTRYPOINT = 'cli'; AI_AGENT = 'claude-code_9-9-9_agent'
    CLAUDE_CODE_SESSION_ID = 'cs-27b-dummy'; CLAUDE_CODE_BRIDGE_SESSION_ID = 'cb-27b-dummy'; CLAUDE_CODE_CHILD_SESSION = '1'
    CLAUDE_CODE_MESSAGING_SOCKET = 'fake-socket-27b'; CLAUDE_CODE_MESSAGING_TOKEN = 'tok-27b-dummy'; CLAUDE_CODE_SESSION_ATTENDED = '1'
    CLAUDE_CODE_EXECPATH = 'C:\fake-27b\host.exe'; CLAUDE_PID = '4242'; CLAUDE_EFFORT = 'high'
    ZCODE_SESSION_ID = 'zs-27b-dummy'; ZCODE_PROJECT_DIR = 'C:\fake-27b\project'; ZCODE_PLUGIN_ROOT = 'C:\fake-27b\zplugin'
    # (wave 27c, D21) two of the names read inside a Z Code session (2026-09-29) - the whole ZCODE_ prefix
    ZCODE_BASE_URL = 'https://fake-27c.invalid/zcode'; ZCODE_PERSONAL_PROVIDER_CONFIG_FILE = 'C:\fake-27c\providers.json'
}
$markerNamesSorted = [string[]]@($markerSet.Keys)
[Array]::Sort($markerNamesSorted, [StringComparer]::Ordinal)
$keptSet = [ordered]@{ CLAUDE_CODE_USE_BEDROCK = '0'; CLAUDE_PLUGIN_ROOT = 'C:\fake-27b\cplugin' }
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_RESUME_REPLY', 'FAKE_CODEX_HANG_NEW', 'FAKE_CODEX_DELAY_MS', 'FAKE_CODEX_ENV_DUMP')
$testVars = @('RT_ZAI_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_PANEL_SEED', 'CODEX_CONSULT_TEST_DETACH_GUIDS', 'CODEX_CONSULT_COORDINATOR', 'CODEX_CONSULT_BRIEF_PREFIX', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_PLUGIN_ROOT')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    # every host marker of this process (the harness may run inside an agent session)
    foreach ($k in (Get-HostMarkerNames)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    # (wave 27c, D20) the zcode hint's build facts (no markers) are removed too
    foreach ($k in @('ZCODE_APP_VERSION', 'ZCODE_ENV')) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    $env:CODEX_CONSULT_HEALTH = 'none'
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
# One bridge call: { Code; Out; First; Previews }
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{}, [switch]$NoCodexExe)
    Set-CaseEnv $Roster $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $all = @('-Task', 't')
    if (-not $NoCodexExe) { $all += @('-CodexExe', $fake) }
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs @all @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    return [pscustomobject]@{ Code = $code; Out = $text; First = (($text -split "`n") | Select-Object -First 1); Previews = (Get-Previews $text) }
}
# A script with arbitrary arguments (no -Task added): { Code; Out }
function Run-Raw {
    param([string]$Script, [string]$Repo, [string[]]$ArgList, [hashtable]$Env = @{})
    Set-CaseEnv '' $Env
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = (& $psExe -NoProfile -ExecutionPolicy Bypass -File $Script @ArgList 2>&1 | ForEach-Object { "$_" }) -join "`n"
    $c = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    return [pscustomobject]@{ Code = $c; Out = $o }
}
# stdout captured to a FILE (the exact bytes): { Code; Bytes; Text (UTF-8) }
function Run-ToFile {
    param([string]$Script, [string]$Repo, [string[]]$ArgList)
    Set-CaseEnv '' @{}
    $outP = Join-Path $work ("out-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + '.txt')
    $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Script) + @($ArgList)
    $argText = (@($all | ForEach-Object { if ([string]$_ -match '[\s"]' -or [string]$_ -eq '') { '"' + ([string]$_ -replace '"', '\"') + '"' } else { [string]$_ } }) -join ' ')
    $proc = Start-Process -FilePath $psExe -ArgumentList $argText -WorkingDirectory $Repo -NoNewWindow -PassThru -RedirectStandardOutput $outP -RedirectStandardError "$outP.err"
    if ($PSVersionTable.PSVersion.Major -lt 6) { try { $null = $proc.Handle } catch { } }
    $proc.WaitForExit()
    Restore-Env
    $bytes = [byte[]]@()
    if (Test-Path -LiteralPath $outP) { $bytes = [IO.File]::ReadAllBytes($outP) }
    return [pscustomobject]@{ Code = $proc.ExitCode; Bytes = $bytes; Text = $u8.GetString($bytes) }
}
function Reply { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Text { param([string]$Path) if ($Path -and (Test-Path -LiteralPath $Path)) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
# The environment dumps of the fake engine, one object each on the pipeline (wrap the call in
# @(...)): { Kind; Names (string[]); Text }
function Read-EnvDumps {
    param([string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir)) { return }
    foreach ($f in @(Get-ChildItem -LiteralPath $Dir -File -Filter '*.env')) {
        $t = Text $f.FullName
        $names = @(($t -split "`n") | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_]*=' } | ForEach-Object { $_.Substring(0, $_.IndexOf('=')) })
        [pscustomobject]@{ Kind = ($f.Name -replace '-\d+\.env$', ''); Names = [string[]]$names; Text = $t }
    }
}
function Has-Marker { param($Dump) return (@($Dump.Names | Where-Object { $markerSet.Contains([string]$_) }).Count -gt 0) }
# A SKILL.md's front matter as a hashtable (key: value lines) and its body
function Read-FrontMatter {
    param([string]$Path)
    $t = Text $Path
    $fm = @{}
    $body = $t
    if ($t -match '\A---\r?\n([\s\S]*?)\r?\n---\r?\n') {
        foreach ($l in ($Matches[1] -split "`r?`n")) { if ($l -match '^([A-Za-z-]+):\s*(.*)$') { $fm[$Matches[1]] = $Matches[2].Trim() } }
        $body = $t.Substring($Matches[0].Length)
    }
    return [pscustomobject]@{ Fm = $fm; Body = $body; Text = $t }
}
# (wave 27d) the arithmetic of the waiting rule (README "Waiting: keep the prompt cache or compact"),
# in [decimal] so that a half rounds as printed (away from zero): the API prices per token of
# 2026-09, the cache-read multiplier R and the one-hour cache-write multiplier W; the wake's turn
# (1K new input written to the cache, 300 output), the summary (10K output), the compact window (50K)
$waitModels = [ordered]@{
    'Claude Fable 5.1'  = @{ P = [decimal]'0.00001';  Pout = [decimal]'0.00005'; R = [decimal]'0.025'; W = [decimal]'2' }
    'Claude Opus 5.5'   = @{ P = [decimal]'0.000004'; Pout = [decimal]'0.00002'; R = [decimal]'0.05';  W = [decimal]'2' }
    'Claude Sonnet 5.5' = @{ P = [decimal]'0.000002'; Pout = [decimal]'0.00001'; R = [decimal]'0.1';   W = [decimal]'2' }
}
$waitContexts = [ordered]@{ '1M' = [decimal]1000000; '850K' = [decimal]850000; '500K' = [decimal]500000; '300K' = [decimal]300000; '150K' = [decimal]150000 }
# one wake = R*P*C + turn; compact = R*P*C + S*Pout + W*P*C2; the boundary = (S*Pout + W*P*C2) / one wake
# wakes, hours = wakes / 2 (keeping reads the context once too, at the resume)
function Get-WaitNumbers {
    param([hashtable]$M, [decimal]$C)
    $turn = [decimal]1000 * $M.W * $M.P + [decimal]300 * $M.Pout
    $read = $M.R * $M.P * $C
    $wake = $read + $turn
    $tail = [decimal]10000 * $M.Pout + $M.W * $M.P * [decimal]50000
    return [pscustomobject]@{ Read = $read; Wake = $wake; Compact = $read + $tail; Expire = $M.W * $M.P * $C; Hours = $tail / $wake / [decimal]2; Tail = $tail }
}
function Format-Dec {
    param([decimal]$V, [int]$Digits)
    $f = $(if ($Digits -gt 0) { '0.' + ('0' * $Digits) } else { '0' })
    return ([Math]::Round($V, $Digits, [MidpointRounding]::AwayFromZero)).ToString($f, [Globalization.CultureInfo]::InvariantCulture)
}

$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
$prose = Reply 'prose.md' ("1. The first answer: the invalidation path looks correct, because every writer takes the lock before it touches the cache entry and releases it after the write.`n" + "2. The second answer: the retry path has no test at all and should get one before the release, since a silent retry loop hides the real failure.`n")
$roster2 = Write-Roster 'two' '{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1"},{"provider":"ZAI","model":"glm-5.3"}]}'
$note = '`${CLAUDE_PLUGIN_ROOT}` is the plugin directory; from a plain shell set `CODEX_CONSULT_ROOT` to it and use that instead.'
$pointer = 'codex-consult: coordinator rules - skill codex-consult:coordinate (or codex-consult.ps1 -Explain coordinate)'
# (wave 27c, D13) the pointer line carries the full command of the plugin's own script
$pointerHead = 'codex-consult: coordinator rules - skill codex-consult:coordinate '
$warnText = "a second opinion from the coordinator's own model"
$readme = Text (Join-Path $repoRoot 'README.md')

try {

# =============================================================== GREP: the root note and the wording (D2, D6)
if (Want 'GREP') {
    $skillFiles = @(Get-ChildItem -LiteralPath (Join-Path $pluginDir 'skills') -Directory | ForEach-Object { Join-Path $_.FullName 'SKILL.md' } | Where-Object { Test-Path -LiteralPath $_ })
    $names = @($skillFiles | ForEach-Object { Split-Path -Leaf (Split-Path -Parent $_) } | Sort-Object)
    $noteMissing = New-Object System.Collections.Generic.List[string]
    $claudeHits = New-Object System.Collections.Generic.List[string]
    $rootHits = New-Object System.Collections.Generic.List[string]
    foreach ($f in $skillFiles) {
        $lines = @((Text $f) -split "`r?`n")
        $leaf = Split-Path -Leaf (Split-Path -Parent $f)
        $h1 = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^# ') { $h1 = $i; break } }
        $firstAfter = ''
        if ($h1 -ge 0) { for ($i = $h1 + 1; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim()) { $firstAfter = $lines[$i]; break } } }
        if ($firstAfter -cne $note) { $noteMissing.Add($leaf) }
        $section = ''
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            if ($l -match '^## ') { $section = $l }
            # (wave 27d) a model name (Claude Fable 5.1, the prices of the waiting rule) names no host
            if (($l -creplace '\bClaude (Fable|Opus|Sonnet|Haiku) \d+(\.\d+)?', '') -cmatch '\bClaude\b' -and $section -ne '## Means per host') { $claudeHits.Add("$($leaf):$($i + 1)") }
            if ($l -ceq $note) { continue }
            foreach ($m in [regex]::Matches($l, '\$\{CLAUDE_PLUGIN_ROOT\}(.{0,12})')) {
                if ($m.Groups[1].Value -notmatch '^/(scripts|templates|skills|schemas|install|hooks|agents)/') { $rootHits.Add("$($leaf):$($i + 1)") }
            }
            if ($l.Contains('../..')) { $rootHits.Add("$($leaf):$($i + 1) (../..)") }
        }
    }
    Check 'GREP' 'D2 every skill (consult-codex, coordinate, setup-providers) opens with the one-sentence root note right after its title: "`${CLAUDE_PLUGIN_ROOT}` is the plugin directory; from a plain shell set `CODEX_CONSULT_ROOT` to it and use that instead."' (($names -join ',') -eq 'consult-codex,coordinate,setup-providers' -and $noteMissing.Count -eq 0) "skills $($names -join ','); missing in $($noteMissing -join ',')"
    Check 'GREP' 'D2/D6 `${CLAUDE_PLUGIN_ROOT}` appears in the skills only in the root note and as a path prefix into the plugin (/scripts/, /templates/, /skills/, /install/ ...) - the `<skill dir>/../..` fallback is gone' ($rootHits.Count -eq 0) ($rootHits -join ', ')
    Check 'GREP' 'D6 "Claude" appears in the skills only in the coordinate skill''s "Means per host" section (the coordinator, the judge everywhere else) - (wave 27d) a model name such as "Claude Fable 5.1" in the waiting rule is no host' ($claudeHits.Count -eq 0) ($claudeHits -join ', ')
    # README: "Claude" only in the host sections - (wave 27d) and in "Waiting", whose prices are those of Claude models
    $allowed = '^## (Install|For the coordinator|Waiting: keep the prompt cache or compact|Engines|Alternatives|Roadmap|Tested on)'
    $readmeHits = New-Object System.Collections.Generic.List[string]
    $section = ''
    $rl = @($readme -split "`r?`n")
    for ($i = 0; $i -lt $rl.Count; $i++) {
        if ($rl[$i] -match '^## ') { $section = $rl[$i] }
        if ($rl[$i] -cmatch '\bClaude\b' -and $section -notmatch $allowed) { $readmeHits.Add("$($i + 1): $($rl[$i].Substring(0, [Math]::Min(60, $rl[$i].Length)))") }
    }
    Check 'GREP' 'D6 the README names "Claude" only in the host sections (Install, For the coordinator; the Engines, Alternatives, Roadmap and Tested-on product references; wave 27d: Waiting, the prices of the Claude models)' ($readmeHits.Count -eq 0) ($readmeHits -join ' || ')
    $scriptHits = @(Get-ChildItem -LiteralPath $scripts -Filter '*.ps1' | ForEach-Object { $sf = $_; $n = 0; foreach ($l in ((Text $sf.FullName) -split "`n")) { $n++; if ($l -cmatch '\bClaude\b') { "$($sf.Name):$n" } } })
    Check 'GREP' 'D6 no script says "Claude": the synopses, .DESCRIPTION/.EXAMPLE text and the hook header say the coordinator (codex-consult.ps1: "from any coordinator")' ($scriptHits.Count -eq 0 -and (Text $consultPs) -match 'from any coordinator' -and (Text $hookPs) -match "the coordinator's session") ($scriptHits -join ', ')
    # (wave 27c, D22) the brief templates name no host either
    $tplHits = @(Get-ChildItem -LiteralPath (Join-Path $pluginDir 'templates') -Filter '*.md' | ForEach-Object { $tf = $_; $n = 0; foreach ($l in ((Text $tf.FullName) -split "`n")) { $n++; if ($l -cmatch '\bClaude\b') { "$($tf.Name):$n" } } })
    Check 'GREP' '(wave 27c, D22) no brief template names a host: templates/*.md carry no "Claude" - "# Handoff <NN> - <coordinator>: <slug>" in brief-review.md and brief-framing.md' ($tplHits.Count -eq 0 -and (Text (Join-Path $pluginDir 'templates\brief-review.md')).Contains('# Handoff <NN> - <coordinator>: <slug>') -and (Text (Join-Path $pluginDir 'templates\brief-framing.md')).Contains('# Handoff <NN> - <coordinator>: <slug>')) ($tplHits -join ', ')
    Check 'GREP' 'D6 the brief name is documented as the coordinator''s brief prefix (README and consult-codex: <NN>-<prefix>-<slug>.md, default claude, -BriefPrefix / CODEX_CONSULT_BRIEF_PREFIX)' ($readme -match "coordinator's brief prefix" -and $readme.Contains('CODEX_CONSULT_BRIEF_PREFIX') -and (Text (Join-Path $pluginDir 'skills\consult-codex\SKILL.md')).Contains('<NN>-<prefix>-<slug>.md')) ''
}

# =============================================================== MATCHER: the one parser, the one comparison, the coordinator (D3)
if (Want 'MATCHER') {
    $kinds = @(foreach ($v in @('#2', 'openai', 'openai :: gpt-5.1', 'gemini :: g-3 [agy]')) { $m = ConvertFrom-ReviewerMatcher -Matcher $v; "$($m.Kind)/$($m.Position)/$($m.Provider)/$(if ($null -eq $m.Model) { '-' } else { $m.Model })/$($m.Engine)" })
    $bad = @(foreach ($v in @('', 'x [zzz]')) { (ConvertFrom-ReviewerMatcher -Matcher $v).Error })
    Check 'MATCHER' 'ConvertFrom-ReviewerMatcher: #2 -> position 2; openai -> label (model null); "openai :: gpt-5.1" -> lineage; "gemini :: g-3 [agy]" -> lineage with engine agy; an empty value and an unknown engine are errors' (($kinds -join ' ') -eq 'position/2//-/ label/0/openai/-/ lineage/0/openai/gpt-5.1/ lineage/0/gemini/g-3/agy' -and @($bad | Where-Object { $_ }).Count -eq 2) (($kinds -join ' ') + ' | ' + ($bad -join ' | '))
    $entries = @(
        [pscustomobject]@{ Position = 1; Provider = 'openai'; Model = 'gpt-5.1'; Engine = 'codex' },
        [pscustomobject]@{ Position = 2; Provider = 'gemini'; Model = 'g-3'; Engine = 'agy' },
        [pscustomobject]@{ Position = 3; Provider = 'mimo'; Model = ''; Engine = 'codex' }
    )
    $res = @(foreach ($v in @('#2', '#9', 'openai', 'gemini :: g-3 [agy]', 'gemini :: g-3 [codex]', 'mimo', 'OpenAI')) { $x = Resolve-ReviewerMatcher -Entries $entries -Matcher $v; "$(@($x.Positions) -join '+')$(if ($x.Error) { '!' })" })
    Check 'MATCHER' 'Resolve-ReviewerMatcher (-Require) on top of the parser behaves as in wave 26: #2 -> 2, #9 refused ("names no roster position"), openai -> 1, "gemini :: g-3 [agy]" -> 2, the same with [codex] -> no entry, a model-less entry by its label (mimo -> 3), the provider compared ordinal (OpenAI -> no entry)' (($res -join ' ') -eq '2 ! 1 2 ! 3 !') ($res -join ' ')
    $roster = [pscustomobject]@{ Exists = $true; Entries = $entries }
    Clear-TestEnv
    $c0 = Resolve-CoordinatorIdentity -Value '' -Roster $roster
    $env:CLAUDECODE = '1'
    $c1 = Resolve-CoordinatorIdentity -Value '' -Roster $roster
    Remove-Item env:CLAUDECODE
    $env:AI_AGENT = 'claude-code_9_agent'
    $c1b = Resolve-CoordinatorIdentity -Value '' -Roster $roster
    $env:CODEX_THREAD_ID = 'x'
    $c2 = Resolve-CoordinatorIdentity -Value 'openai :: gpt-5.1' -Roster $roster
    $c3 = Resolve-CoordinatorIdentity -Value '#2' -Roster $roster
    $c4 = Resolve-CoordinatorIdentity -Value 'openai' -Roster $roster
    Clear-TestEnv
    Check 'MATCHER' 'D3 the host - a hint only: none -> {host unknown, source none}; CLAUDECODE -> claude-code (source inferred); AI_AGENT claude-code* -> claude-code; CODEX_THREAD_ID with the Claude markers -> codex (the innermost host); no identity is inferred (provider, model, engine null)' ($c0.Record.host -eq 'unknown' -and $c0.Record.source -eq 'none' -and $c1.Record.host -eq 'claude-code' -and $c1.Record.source -eq 'inferred' -and $null -eq $c1.Record.provider -and $null -eq $c1.Record.model -and $c1b.Record.host -eq 'claude-code' -and $c2.Record.host -eq 'codex') "$($c0.Record | ConvertTo-Json -Compress) $($c1.Record | ConvertTo-Json -Compress) $($c2.Record.host)"
    # (wave 27b) the zcode hint and the order: codex markers, then zcode, then claude-code
    $hh = New-Object System.Collections.Generic.List[string]
    foreach ($case in @(
            @{ ZCODE_SESSION_ID = 'zs-1' },
            @{ ZCODE_PROJECT_DIR = 'C:\p' },
            @{ ZCODE_SESSION_ID = 'zs-1'; CLAUDECODE = '1'; CLAUDE_CODE_ENTRYPOINT = 'cli'; AI_AGENT = 'claude-code_9_agent' },
            @{ ZCODE_PROJECT_DIR = 'C:\p'; CODEX_THREAD_ID = 'x' },
            @{ ZCODE_SESSION_ID = 'zs-1'; CODEX_SESSION_ID = 'y'; CLAUDECODE = '1' },
            @{ ZCODE_PLUGIN_ROOT = 'C:\z'; CLAUDE_PLUGIN_ROOT = 'C:\c'; CLAUDE_CODE_USE_BEDROCK = '0' },
            @{ CLAUDE_PLUGIN_ROOT = 'C:\c'; CLAUDE_CODE_USE_BEDROCK = '0' })) {
        Clear-TestEnv
        foreach ($k in $case.Keys) { Set-Item "env:$k" $case[$k] }
        $hr = (Resolve-CoordinatorIdentity -Value '' -Roster $roster).Record
        $hh.Add("$($hr.host)/$($hr.source)")
        foreach ($k in $case.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    }
    Clear-TestEnv
    Check 'MATCHER' 'wave 27b the host hint zcode: ZCODE_SESSION_ID -> zcode; ZCODE_PROJECT_DIR alone -> zcode (source inferred); zcode wins over the claude-code markers (CLAUDECODE, CLAUDE_CODE_ENTRYPOINT, AI_AGENT claude-code*); codex (CODEX_THREAD_ID, CODEX_SESSION_ID) wins over zcode; (wave 27c, D20) ANY ZCODE_ variable is the zcode hint (a ZCODE_PLUGIN_ROOT too); CLAUDE_PLUGIN_ROOT or an operator setting is no hint -> unknown / none' (($hh -join ',') -eq 'zcode/inferred,zcode/inferred,zcode/inferred,codex/inferred,codex/inferred,zcode/inferred,unknown/none') ($hh -join ',')
    Check 'MATCHER' 'D3 CODEX_CONSULT_COORDINATOR parsed by the matcher: "openai :: gpt-5.1" -> {openai, gpt-5.1, engine null, explicit}; "#2" -> the roster entry resolved {gemini, g-3, agy}; (wave 27c, D9) a RESOLVED triple - the lineage''s engine from its roster entry (codex); a label -> the model of its one roster entry {openai, gpt-5.1, codex}; the ledger record has exactly provider, model, engine, host, host_by, source, in_roster, unresolved' ($c2.Record.provider -eq 'openai' -and $c2.Record.model -eq 'gpt-5.1' -and $c2.Record.engine -eq 'codex' -and $c2.Record.source -eq 'explicit' -and $c3.Record.provider -eq 'gemini' -and $c3.Record.model -eq 'g-3' -and $c3.Record.engine -eq 'agy' -and $c4.Record.provider -eq 'openai' -and $c4.Record.model -eq 'gpt-5.1' -and $c4.Record.engine -eq 'codex' -and (($c2.Record.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -eq 'provider,model,engine,host,host_by,source,in_roster,unresolved') "$($c2.Record | ConvertTo-Json -Compress) $($c3.Record | ConvertTo-Json -Compress)"
    $refusals = @(foreach ($v in @('openai [bogus]', 'x :: ', 'a::b', 'p :: m|x')) { $r = Resolve-CoordinatorIdentity -Value $v -Roster $roster; [bool]($r.Error -and -not $r.Record -and $r.Error.Contains('cannot be used') -and $r.Error.EndsWith('nothing was started.')) })
    Check 'MATCHER' '(wave 27c, D10, D12) only a value that cannot be PARSED is refused: an unknown engine, a lineage without a model, a delimiter of the roster''s character rule inside a provider or a model (''::'', ''|'')' (@($refusals | Where-Object { $_ }).Count -eq 4) ($refusals -join ',')
    $accepted = @(foreach ($v in @('#7', 'open ai', 'openai :: gpt 5')) { $r = Resolve-CoordinatorIdentity -Value $v -Roster $roster; if ($r.Error) { "!$v" } else { "$($r.Record.provider)/$($r.Record.model)/$($r.Record.in_roster)/$($r.Record.unresolved)" } })
    Check 'MATCHER' '(wave 27c, D10-D12) no longer refused: #7 (no such position here - unresolved, with a warning), a provider with an interior blank and a model with one (the roster''s own character rule) - recorded, in_roster false' (($accepted -join ' ') -eq '//False/#7 open ai//False/ openai/gpt 5/False/') ($accepted -join ' ')
    $cmp = @(
        (Test-CoordinatorReviewer -Coordinator $c2.Record -Provider 'openai' -Model 'gpt-5.1' -Engine 'codex'),
        (Test-CoordinatorReviewer -Coordinator $c2.Record -Provider 'openai' -Model 'gpt-5.2' -Engine 'codex'),
        (Test-CoordinatorReviewer -Coordinator $c2.Record -Provider 'OpenAI' -Model 'gpt-5.1' -Engine 'codex'),
        (Test-CoordinatorReviewer -Coordinator $c3.Record -Provider 'gemini' -Model 'g-3' -Engine 'agy'),
        (Test-CoordinatorReviewer -Coordinator $c3.Record -Provider 'gemini' -Model 'g-3' -Engine 'codex'),
        (Test-CoordinatorReviewer -Coordinator $c4.Record -Provider 'openai' -Model 'gpt-5.1' -Engine 'codex'),
        (Test-CoordinatorReviewer -Coordinator $c1.Record -Provider 'openai' -Model 'gpt-5.1' -Engine 'codex')
    )
    Check 'MATCHER' 'D3 compared on the RESOLVED identity field by field (Test-ReviewerMatch - the -Require comparison): the same model -> yes; another model, another spelling of the provider -> no; an engine-qualified identity only on that engine; (wave 27c, D9) a label -> the model it resolved to; an inferred host alone never' (($cmp -join ',') -eq 'True,False,False,True,False,True,False') ($cmp -join ',')
    foreach ($k in $markerSet.Keys) { Set-Item "env:$k" $markerSet[$k] }
    foreach ($k in $keptSet.Keys) { Set-Item "env:$k" $keptSet[$k] }
    $before = (Get-HostMarkerNames) -join ','
    $saved = Hide-HostMarkers
    $during = (Get-HostMarkerNames) -join ','
    $goneDuring = @($markerSet.Keys | Where-Object { $null -ne [Environment]::GetEnvironmentVariable($_) }).Count -eq 0
    $keptDuring = @($keptSet.Keys | Where-Object { [Environment]::GetEnvironmentVariable($_) -ceq $keptSet[$_] }).Count -eq $keptSet.Count
    Restore-HostMarkers -Saved $saved
    $after = (Get-HostMarkerNames) -join ','
    $valuesBack = (@($markerSet.Keys | Where-Object { [Environment]::GetEnvironmentVariable($_) -ceq $markerSet[$_] }).Count -eq $markerSet.Count)
    Clear-TestEnv
    Check 'MATCHER' "D4/wave 27b Hide-HostMarkers ($hostTag): the $($markerSet.Count) markers (every CODEX_SANDBOX* and ZCODE_PLUGIN* included; the session ids, the messaging socket and token, CLAUDE_PID, CLAUDE_EFFORT, the Z Code session and project) are really gone from the process environment - not left empty - and CLAUDE_CODE_USE_BEDROCK and CLAUDE_PLUGIN_ROOT (no markers: exact names, not the CLAUDE_CODE_ prefix) stay; Restore-HostMarkers puts every value back" ($before -eq ($markerNamesSorted -join ',') -and $during -eq '' -and $goneDuring -and $keptDuring -and $after -eq $before -and $valuesBack) "before $before | during '$during' | kept $keptDuring | after $after"
}

# =============================================================== REFUSE: an unparseable coordinator refuses before anything starts (D3)
if (Want 'REFUSE') {
    $r = New-Repo 'refuse'
    $d = Consult $r '' @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_COORDINATOR = 'open::ai' }
    $x = Consult $r '' @('-Prompt', 'x') @{ CODEX_CONSULT_COORDINATOR = 'openai :: gpt|5'; FAKE_CODEX_REPLY = $advise }
    $p = Consult $r $roster2 @('-Panel', '-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_COORDINATOR = '#5' }
    Check 'REFUSE' 'D3 CODEX_CONSULT_COORDINATOR that does not parse: the dry run and a real run exit 1 with "codex-consult: CODEX_CONSULT_COORDINATOR=''...'' cannot be used: ... nothing was started." - nothing written (no task directory); (wave 27c, D12) a panel with a roster position the roster does not have (#5) is NO refusal: exit 0, the warning "CODEX_CONSULT_COORDINATOR ''#5'' names no roster position here"' ($d.Code -eq 1 -and $d.First -match "^codex-consult: CODEX_CONSULT_COORDINATOR='open::ai' cannot be used: the provider 'open::ai' must not contain '::'" -and $x.Code -eq 1 -and $x.First -match "cannot be used: the model 'gpt\|5' must not contain '\|'" -and -not (Test-Path (Join-Path $r '.collab')) -and $p.Code -eq 0 -and $p.Out -match "CODEX_CONSULT_COORDINATOR '#5' names no roster position here") "$($d.First) || $($x.First) || $($p.First)"
}

# =============================================================== WARN: the coordinator's own model seated as the reviewer (D3)
if (Want 'WARN') {
    $r = New-Repo 'warn'
    $d = Consult $r '' @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_COORDINATOR = 'openai :: gpt-5.1'; CODEX_SESSION_ID = 's-1' }
    $pv = @($d.Previews)[0]
    $wl = @(($d.Out -split "`n") | Where-Object { $_ -match '^WARNING: coordinator: ' })
    Check 'WARN' 'D3 dry run, the reviewer (openai :: gpt-5.1 from the config) IS the coordinator: "WARNING: coordinator: openai :: gpt-5.1 is the coordinator''s own model (CODEX_CONSULT_COORDINATOR) - a second opinion from the coordinator''s own model, ..." (not refused, exit 0); the preview''s warnings[] carries it; "coordinator : openai :: gpt-5.1; host codex (inferred, a hint); source explicit"' ($d.Code -eq 0 -and $wl.Count -eq 1 -and $wl[0].Contains($warnText) -and @($pv.warnings | Where-Object { ([string]$_).Contains($warnText) }).Count -eq 1 -and $d.Out -match '(?m)^coordinator : openai :: gpt-5\.1; host codex \(inferred, a hint\); source explicit$') ($wl -join ' || ')
    Check 'WARN' 'D3/F04-10 the preview''s `coordinator` {provider openai, model gpt-5.1, engine codex (wave 27c, D9: resolved - no roster entry names another), host codex, source explicit} right after `lineage` - a NEW key, `host` stays the machine name elsewhere; `child_env_scrubbed` [CODEX_SESSION_ID] right after `command`' ($pv.coordinator.provider -eq 'openai' -and $pv.coordinator.model -eq 'gpt-5.1' -and $pv.coordinator.engine -eq 'codex' -and $pv.coordinator.host -eq 'codex' -and $pv.coordinator.source -eq 'explicit' -and (($pv.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match 'reviewer,lineage,coordinator,preflight' -and (($pv.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match 'command,child_env_scrubbed,brief' -and (@($pv.child_env_scrubbed) -join ',') -eq 'CODEX_SESSION_ID') ($pv.coordinator | ConvertTo-Json -Compress)
    $d2 = Consult $r '' @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_COORDINATOR = 'ZAI :: glm-5.3' }
    Check 'WARN' 'D3 another coordinator model (ZAI :: glm-5.3) seats no warning; no host marker -> host unknown, source explicit (the identity is given)' ($d2.Code -eq 0 -and $d2.Out -notmatch 'WARNING: coordinator:' -and @($d2.Previews)[0].coordinator.host -eq 'unknown' -and @($d2.Previews)[0].coordinator.source -eq 'explicit') ''
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'w') @{ CODEX_CONSULT_COORDINATOR = 'openai'; CLAUDECODE = '1'; FAKE_CODEX_REPLY = $advise }
    $e = @(Ledger $r)[-1]
    Check 'WARN' 'D3 a real run, coordinator given as a label (openai) in a claude-code host: exit 0 (a warning, never a refusal), ledger coordinator {openai, gpt-5.1 (wave 27c, D9: the config''s model - no roster), codex, claude-code, explicit}, warnings[] holds the coordinator warning, the console printed it' ($x.Code -eq 0 -and $e.coordinator.provider -eq 'openai' -and $e.coordinator.model -eq 'gpt-5.1' -and $e.coordinator.host -eq 'claude-code' -and $e.coordinator.source -eq 'explicit' -and @($e.warnings | Where-Object { ([string]$_).Contains($warnText) }).Count -eq 1 -and $x.Out -match 'WARNING: coordinator: openai :: gpt-5\.1 is the coordinator') ($e.coordinator | ConvertTo-Json -Compress)
    $y = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'n') @{ FAKE_CODEX_REPLY = $advise }
    $e2 = @(Ledger $r)[-1]
    Check 'WARN' 'D3 neither a value nor a marker: coordinator {null, null, null, unknown, none}, child_env_scrubbed [], no warning' ($y.Code -eq 0 -and $null -eq $e2.coordinator.provider -and $e2.coordinator.host -eq 'unknown' -and $e2.coordinator.source -eq 'none' -and @($e2.child_env_scrubbed).Count -eq 0 -and @(Get-RealWarnings $e2.warnings).Count -eq 0 -and (Test-TestModeWarning $e2.warnings)) ($e2.coordinator | ConvertTo-Json -Compress)
    # (wave 27b) a Z Code session: its markers name the host; the plugin roots and the operator's setting are no markers
    $z = Consult $r '' @('-DryRun', '-Prompt', 'x') @{ ZCODE_SESSION_ID = 'zs-27b-dummy'; ZCODE_PROJECT_DIR = 'C:\fake-27b\project'; ZCODE_PLUGIN_ROOT = 'C:\fake-27b\zplugin'; ZCODE_PLUGIN_DATA = 'C:\fake-27b\zdata'; CLAUDE_PLUGIN_ROOT = 'C:\fake-27b\zplugin'; CLAUDE_CODE_USE_BEDROCK = '0' }
    $zp = @($z.Previews)[0]
    Check 'WARN' 'wave 27b dry run in a Z Code session (ZCODE_SESSION_ID, ZCODE_PROJECT_DIR, ZCODE_PLUGIN_ROOT, ZCODE_PLUGIN_DATA, plus CLAUDE_PLUGIN_ROOT and CLAUDE_CODE_USE_BEDROCK): "coordinator : (no identity given ...); host zcode (inferred, a hint); source inferred"; the preview''s child_env_scrubbed [ZCODE_PLUGIN_DATA, ZCODE_PLUGIN_ROOT, ZCODE_PROJECT_DIR, ZCODE_SESSION_ID] - the plugin root and the operator''s setting are not in it' ($z.Code -eq 0 -and $z.Out -match '(?m)^coordinator : \(no identity given[^\n]*; host zcode \(inferred, a hint\); source inferred$' -and $zp.coordinator.host -eq 'zcode' -and $zp.coordinator.source -eq 'inferred' -and (@($zp.child_env_scrubbed) -join ',') -eq 'ZCODE_PLUGIN_DATA,ZCODE_PLUGIN_ROOT,ZCODE_PROJECT_DIR,ZCODE_SESSION_ID') "$($zp.coordinator | ConvertTo-Json -Compress) scrubbed $(@($zp.child_env_scrubbed) -join ',')"
}

# =============================================================== ENV: the engine children never get the host markers (D4)
if (Want 'ENV') {
    # a main turn with prose, then the format repair (resume)
    $r = New-Repo 'env'
    $dump = Join-Path $work 'dump-repair'
    [void][IO.Directory]::CreateDirectory($dump)
    $envR = @{ FAKE_CODEX_REPLY = $prose; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_ENV_DUMP = $dump }
    foreach ($k in $markerSet.Keys) { $envR[$k] = $markerSet[$k] }
    foreach ($k in $keptSet.Keys) { $envR[$k] = $keptSet[$k] }
    $x = Consult $r '' @('-Prompt', 'x', '-ReplyName', 'rep') $envR
    $e = @(Ledger $r)[-1]
    $dumps = @(Read-EnvDumps $dump)
    $exec = @($dumps | Where-Object { $_.Kind -eq 'exec' })
    $probes = @($dumps | Where-Object { $_.Kind -ne 'exec' })
    $keptIn = { param($Dump) @($keptSet.Keys | Where-Object { $Dump.Names -contains $_ }).Count -eq $keptSet.Count }
    Check 'ENV' "D4/wave 27b (fake engine that writes its environment) the main turn and the format-repair turn: neither child saw any of the $($markerSet.Count) host markers (the wave 27 eight; CLAUDE_CODE_SESSION_ID, CLAUDE_CODE_BRIDGE_SESSION_ID, CLAUDE_CODE_CHILD_SESSION, CLAUDE_CODE_MESSAGING_SOCKET, CLAUDE_CODE_MESSAGING_TOKEN, CLAUDE_CODE_SESSION_ATTENDED, CLAUDE_CODE_EXECPATH, CLAUDE_PID, CLAUDE_EFFORT, ZCODE_SESSION_ID, ZCODE_PROJECT_DIR, ZCODE_PLUGIN_ROOT); both kept CODEX_HOME, CODEX_CONSULT_ROSTER, CLAUDE_CODE_USE_BEDROCK and CLAUDE_PLUGIN_ROOT; the repair succeeded" ($x.Code -eq 0 -and $e.format_retry.succeeded -eq $true -and $exec.Count -eq 2 -and @($exec | Where-Object { Has-Marker $_ }).Count -eq 0 -and @($exec | Where-Object { $_.Names -contains 'CODEX_HOME' -and $_.Names -contains 'CODEX_CONSULT_ROSTER' -and (& $keptIn $_) }).Count -eq 2) "exec dumps $($exec.Count): $((@($exec | ForEach-Object { $_.Names -join '+' })) -join ' | ')"
    Check 'ENV' 'D4 the launcher probes (`codex --version`, `codex login status`) get no marker either, and keep CLAUDE_CODE_USE_BEDROCK and CLAUDE_PLUGIN_ROOT' ($probes.Count -ge 1 -and @($probes | Where-Object { Has-Marker $_ }).Count -eq 0 -and @($probes | Where-Object { & $keptIn $_ }).Count -eq $probes.Count) "$($probes.Count) probe dump(s)"
    Check 'ENV' 'D4/wave 27b ledger child_env_scrubbed = the removed NAMES, sorted (never a value - neither the messaging token nor a session id is in the ledger): every marker set, ZCODE_PLUGIN_ROOT among them, and neither CLAUDE_CODE_USE_BEDROCK nor CLAUDE_PLUGIN_ROOT; coordinator.host codex (inferred from the markers of the BRIDGE - the child has none; codex wins over zcode and claude-code)' ((@($e.child_env_scrubbed) -join ',') -eq ($markerNamesSorted -join ',') -and ((Text (Join-Path $r '.collab\t\sessions.json')) -notmatch 'seatbelt|claude-code_9|tok-27b-dummy|zs-27b-dummy|cs-27b-dummy|fake-socket-27b') -and $e.coordinator.host -eq 'codex' -and $e.coordinator.source -eq 'inferred') (@($e.child_env_scrubbed) -join ',')
    # the timeout continuation
    $r2 = New-Repo 'env-cont'
    $dump2 = Join-Path $work 'dump-cont'
    [void][IO.Directory]::CreateDirectory($dump2)
    $envC = @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_RESUME_REPLY = $advise; FAKE_CODEX_HANG_NEW = '1'; FAKE_CODEX_ENV_DUMP = $dump2 }
    foreach ($k in $markerSet.Keys) { $envC[$k] = $markerSet[$k] }
    $c = Consult $r2 '' @('-Prompt', 'x', '-ReplyName', 'cont', '-TimeoutSec', '5', '-ContinueSec', '60') $envC
    $ec = @(Ledger $r2)[-1]
    $execC = @(@(Read-EnvDumps $dump2) | Where-Object { $_.Kind -eq 'exec' })
    Check 'ENV' 'D4 the main turn killed on its timeout, the continuation answered (usable reply after a timeout continuation): neither the killed turn nor the continuation turn saw a marker' ([string]$ec.bridge_outcome -match '^usable reply' -and $null -ne $ec.timeout_continue -and $execC.Count -eq 2 -and @($execC | Where-Object { Has-Marker $_ }).Count -eq 0) "outcome $($ec.bridge_outcome); exec dumps $($execC.Count)"
    # a detached run: the background and its engine child
    $r3 = New-Repo 'env-detach'
    $dump3 = Join-Path $work 'dump-detach'
    [void][IO.Directory]::CreateDirectory($dump3)
    $gid = '0000cafe-0000-4000-8000-000000000027'
    $envD = @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_ENV_DUMP = $dump3; CODEX_CONSULT_TEST_DETACH_GUIDS = $gid; CODEX_CONSULT_COORDINATOR = 'openai :: gpt-5.1' }
    foreach ($k in $markerSet.Keys) { $envD[$k] = $markerSet[$k] }
    $f = Consult $r3 '' @('-Prompt', 'x', '-ReplyName', 'det', '-Detach') $envD
    $w = Consult $r3 '' @('-Wait', '-Id', '0000cafe', '-WaitTimeoutSec', '120') @{} -NoCodexExe
    $ed = @(Ledger $r3)[-1]
    $st = Text (Join-Path $r3 '.collab\t\.consult.detached-0000cafe.status.json') | ConvertFrom-Json
    $execD = @(@(Read-EnvDumps $dump3) | Where-Object { $_.Kind -eq 'exec' })
    Check 'ENV' 'D4 a detached run: the background (and its engine child) started without the markers - the child saw none; the run took the coordinator and the scrubbed names from its foreground (status file `coordinator`, `child_env_scrubbed`): ledger coordinator {openai, gpt-5.1, host codex, explicit}, child_env_scrubbed every marker name set, the coordinator warning in warnings[]' ($f.Code -eq 0 -and $w.Code -eq 0 -and $execD.Count -eq 1 -and -not (Has-Marker $execD[0]) -and $ed.coordinator.host -eq 'codex' -and $ed.coordinator.source -eq 'explicit' -and $ed.coordinator.model -eq 'gpt-5.1' -and (@($ed.child_env_scrubbed) -join ',') -eq ($markerNamesSorted -join ',') -and @($ed.warnings | Where-Object { ([string]$_).Contains($warnText) }).Count -eq 1 -and $st.coordinator.host -eq 'codex' -and (@($st.child_env_scrubbed) -join ',') -eq ($markerNamesSorted -join ',')) "fg $($f.Code) wait $($w.Code); dumps $($execD.Count); ledger $($ed.coordinator | ConvertTo-Json -Compress)"
    # a panel: the members take the panel run's coordinator (PanelSpec), the seated coordinator warns
    $r4 = New-Repo 'env-panel'
    $dump4 = Join-Path $work 'dump-panel'
    [void][IO.Directory]::CreateDirectory($dump4)
    $envP = @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_ENV_DUMP = $dump4; CODEX_CONSULT_COORDINATOR = 'ZAI :: glm-5.3'; CODEX_THREAD_ID = 't-1'; CODEX_CONSULT_TEST_PANEL_SEED = '27' }
    $pd = Consult $r4 $roster2 @('-Panel', '-PanelSize', '2', '-PanelOrder', 'roster', '-Prompt', 'x', '-ReplyName', 'pan', '-DryRun') $envP
    $pr = Consult $r4 $roster2 @('-Panel', '-PanelSize', '2', '-PanelOrder', 'roster', '-Prompt', 'x', '-ReplyName', 'pan') $envP
    $led = @(Ledger $r4)
    $zai = @($led | Where-Object { $_.reviewer.provider -eq 'ZAI' })[0]
    $oai = @($led | Where-Object { $_.reviewer.provider -eq 'openai' })[0]
    $execP = @(@(Read-EnvDumps $dump4) | Where-Object { $_.Kind -eq 'exec' })
    Check 'ENV' 'D3/D4 a panel: its plan (dry run and real run) warns "WARNING: coordinator: ZAI :: glm-5.3 is the coordinator''s own model ..." once; both members'' entries carry the panel run''s coordinator {ZAI, glm-5.3, host codex, explicit} and child_env_scrubbed [CODEX_THREAD_ID]; only the ZAI member''s warnings[] holds the coordinator warning; neither member''s engine child saw CODEX_THREAD_ID' ($pd.Code -eq 0 -and @(($pd.Out -split "`n") | Where-Object { $_ -match '^WARNING: coordinator: ZAI :: glm-5\.3 is the coordinator' }).Count -ge 1 -and $pr.Code -eq 0 -and $led.Count -eq 2 -and $zai.coordinator.provider -eq 'ZAI' -and $oai.coordinator.provider -eq 'ZAI' -and $oai.coordinator.host -eq 'codex' -and (@($zai.child_env_scrubbed) -join ',') -eq 'CODEX_THREAD_ID' -and (@($oai.child_env_scrubbed) -join ',') -eq 'CODEX_THREAD_ID' -and @($zai.warnings | Where-Object { ([string]$_).Contains($warnText) }).Count -eq 1 -and @($oai.warnings | Where-Object { ([string]$_).Contains($warnText) }).Count -eq 0 -and $execP.Count -eq 2 -and @($execP | Where-Object { $_.Names -contains 'CODEX_THREAD_ID' }).Count -eq 0) "dry $($pd.Code), run $($pr.Code), entries $($led.Count), dumps $($execP.Count)"
}

# =============================================================== EXPLAIN / HOOK: skill texts for a host without skills, the pointer line (D5)
if (Want 'EXPLAIN') {
    $r = New-Repo 'explain'
    $okAll = $true
    $ev = New-Object System.Collections.Generic.List[string]
    foreach ($pair in @(@('coordinate', 'coordinate'), @('consult', 'consult-codex'), @('providers', 'setup-providers'))) {
        $o = Run-ToFile $consultPs $r @('-Explain', $pair[0])
        $skillText = Text (Join-Path $pluginDir "skills\$($pair[1])\SKILL.md")
        # (wave 27c, D13) ${CLAUDE_PLUGIN_ROOT} replaced by the plugin directory: runnable as written
        $body = ($skillText -replace '\A---\r?\n[\s\S]*?\r?\n---\r?\n', '').TrimStart("`r", "`n").TrimEnd().Replace('${CLAUDE_PLUGIN_ROOT}', $pluginDir)
        $first = ($o.Text -split "`n")[0]
        $ok = ($o.Code -eq 0 -and $first.StartsWith("codex-consult -Explain $($pair[0]): the $($pair[1]) skill, ") -and $first.Contains('${CLAUDE_PLUGIN_ROOT} in it is replaced by the plugin directory') -and $o.Text -ceq ($first + "`n`n" + $body + "`n") -and -not $o.Text.Substring($first.Length).Contains('${CLAUDE_PLUGIN_ROOT}'))
        if (-not $ok) { $okAll = $false }
        $ev.Add("$($pair[0]) exit $($o.Code) $($o.Bytes.Length) bytes")
    }
    Check 'EXPLAIN' 'D5 -Explain coordinate|consult|providers: exit 0, one line naming the skill and the plugin directory, then the SKILL.md body without its front matter - byte for byte, UTF-8 (the em dashes and arrows intact) - (wave 27c, D13) with every ${CLAUDE_PLUGIN_ROOT} replaced by the plugin directory' $okAll ($ev -join ', ')
    $b = Run-Raw $consultPs $r @('-Explain', 'bogus')
    $t = Run-Raw $consultPs $r @('-Explain', 'consult', '-Task', 't')
    $dd = Run-Raw $consultPs $r @('-Explain', 'consult', '-DryRun')
    $nt = Run-Raw $consultPs $r @('-DryRun', '-Prompt', 'x')
    $ps = Run-Raw $consultPs $r @('-Task', 't', '-Status', 'abcd1234')
    $clean = (@(G $r @('status', '--porcelain')) | Where-Object { $_ }).Count -eq 0 -and -not (Test-Path (Join-Path $r '.collab'))
    Check 'EXPLAIN' 'D5 -Explain bogus -> exit 1 ("-Explain takes coordinate, consult or providers"); with -Task and with -DryRun -> refused ("takes no other parameter"); read-only: the repository is untouched, no .collab' ($b.Code -eq 1 -and $b.Out -match '-Explain takes coordinate, consult or providers' -and $t.Code -eq 1 -and $t.Out -match '-Explain takes no other parameter' -and $dd.Code -eq 1 -and $dd.Out -match '-Explain takes no other parameter' -and $clean) "$($b.Out.Split("`n")[0]) || exit $($t.Code) || $($dd.Out.Split("`n")[0])"
    Check 'EXPLAIN' 'every other form still needs -Task (refused "-Task <id> is required", exit 1 - no prompt), and the automatic positional binding is intact (no parameter sets): -Status abcd1234 binds the id to -CollabDir as before (exit 4 with the -Id hint)' ($nt.Code -eq 1 -and $nt.Out -match '-Task <id> is required' -and $ps.Code -eq 4 -and $ps.Out -match "-CollabDir 'abcd1234' does not exist") "$($nt.Out.Split("`n")[0]) || $($ps.Out.Split("`n")[0])"
}
if (Want 'HOOK') {
    $r = New-Repo 'hook'
    # the hook finds `codex` on PATH: a fake one first (never the machine's codex)
    $bin = Join-Path $work 'bin'
    [void][IO.Directory]::CreateDirectory($bin)
    [IO.File]::WriteAllText((Join-Path $bin 'codex.cmd'), "@echo off`r`nset ""FAKE_CODEX_ARGS=%*""`r`npowershell -NoProfile -ExecutionPolicy Bypass -File ""$(Join-Path $sp 'fake-codex3.ps1')""`r`nexit /b %ERRORLEVEL%`r`n")
    $savedPath = $env:Path
    $env:Path = "$bin;$savedPath"
    try { $h = Run-Raw $hookPs $r @() @{ CODEX_CONSULT_ROSTER = $roster2; CODEX_HOME = $codexHome; RT_ZAI_KEY = 'zai-test-key' } } finally { $env:Path = $savedPath }
    $hl = @(($h.Out -split "`n") | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ })
    Check 'HOOK' 'D5 the SessionStart hook prints the availability line, then ONE pointer line: "codex-consult: coordinator rules - skill codex-consult:coordinate (or codex-consult.ps1 -Explain coordinate)" - (wave 28) ending "; telemetry: off" (every harness but harness-telemetry runs with CODEX_CONSULT_TELEMETRY=off); exit 0' ($h.Code -eq 0 -and $hl.Count -eq 2 -and $hl[0].StartsWith('codex-consult: ') -and -not $hl[0].StartsWith($pointerHead) -and $hl[1] -ceq ($pointerHead + '(or powershell -NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $scripts 'codex-consult.ps1') + '" -Explain coordinate); telemetry: off')) ($hl -join ' || ')
    $hooksJson = Text (Join-Path $pluginDir 'hooks\hooks.json')
    Check 'HOOK' 'D5 the documented one-liner carries -ExecutionPolicy Bypass: hooks.json''s Windows branch and the README''s hook one-liner for a host without hooks (wave 28b, D17: on $env:CODEX_CONSULT_ROOT)' ($hooksJson.Contains('powershell -NoProfile -ExecutionPolicy Bypass -File \"${CLAUDE_PLUGIN_ROOT}/scripts/codex-consult-hook.ps1\"') -and $readme -match 'powershell -NoProfile -ExecutionPolicy Bypass -File "?\$env:CODEX_CONSULT_ROOT/scripts/codex-consult-hook\.ps1') ''
}

# =============================================================== PREFIX: the coordinator's brief prefix (D6)
if (Want 'PREFIX') {
    $r = New-Repo 'prefix'
    $refused = @(foreach ($pfx in @('codex', 'agy', 'muse')) { $x = Consult $r '' @('-DryRun', '-Prompt', 'x', '-BriefPrefix', $pfx); [bool]($x.Code -eq 1 -and $x.First -match "^codex-consult: the brief prefix '$pfx' \(-BriefPrefix\) is a reply prefix") })
    $envRef = Consult $r '' @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_BRIEF_PREFIX = 'agy' }
    $slug = Consult $r '' @('-DryRun', '-Prompt', 'x', '-BriefPrefix', 'Bad_Prefix')
    Check 'PREFIX' 'D6 a reply prefix (codex, agy, muse) is refused as the brief prefix - -BriefPrefix and CODEX_CONSULT_BRIEF_PREFIX alike, the dry run too (exit 1, nothing written); a prefix that is not a lowercase slug too' (@($refused | Where-Object { $_ }).Count -eq 3 -and $envRef.Code -eq 1 -and $envRef.First -match "'agy' \(CODEX_CONSULT_BRIEF_PREFIX\) is a reply prefix" -and $slug.Code -eq 1 -and $slug.First -match 'must be a lowercase slug' -and -not (Test-Path (Join-Path $r '.collab'))) "$($refused -join ',') || $($envRef.First) || $($slug.First)"
    $def = Consult $r '' @('-DryRun', '-Prompt', 'x')
    $own = Consult $r '' @('-DryRun', '-Prompt', 'x') @{ CODEX_CONSULT_BRIEF_PREFIX = 'codexhost' }
    Check 'PREFIX' 'D6 the default stays claude ("brief prefix: claude (the default) - the coordinator''s briefs are handoffs/<NN>-claude-<slug>.md, this reply 01-codex-reply.*"); CODEX_CONSULT_BRIEF_PREFIX=codexhost names another host''s briefs' ($def.Code -eq 0 -and $def.Out -match "(?m)^brief prefix: claude \(the default\) - the coordinator's briefs are handoffs/<NN>-claude-<slug>\.md, this reply 01-codex-reply\.\*$" -and $own.Code -eq 0 -and $own.Out -match '(?m)^brief prefix: codexhost \(CODEX_CONSULT_BRIEF_PREFIX\)') ''
}

# =============================================================== SKILL / AGENTS: the coordinate skill, the agent files, the Codex examples (D7)
if (Want 'SKILL') {
    $cs = Read-FrontMatter (Join-Path $pluginDir 'skills\coordinate\SKILL.md')
    $fmOk = ($cs.Fm['name'] -eq 'coordinate' -and $cs.Fm['description'].Length -gt 80 -and $cs.Fm.ContainsKey('argument-hint') -and $cs.Fm.ContainsKey('allowed-tools') -and $cs.Fm['disable-model-invocation'] -eq 'false')
    Check 'SKILL' 'D7 the coordinate skill: front matter name coordinate, a description, argument-hint, allowed-tools, disable-model-invocation false (the same shape as the other skills)' $fmOk (($cs.Fm.Keys | Sort-Object) -join ',')
    $b = $cs.Body
    $needles = @('## Invariants', 'One objective per worker', 'A fresh worker per wave', 'STATE.md', 'Wait without blocking', 'the idle watchdog', 'at wave boundaries', "Never redo a worker's work", 'English to reviewers', 'The live-member rule', 'Rate every consultation', 'required reviewer', "## The bridge's own means", '-Detach', '-Status', '-Wait', '-Kick', '## Worker tiers (the contract)', 'deep reasoning', 'default execution', 'cheap read-only recon', '## Means per host', '**Claude Code.**', '**Codex CLI.**', '**Z Code.**', '**Kimi Code.**', '**Qwen Code.**', '**OpenCode.**', '**Muse Code.**', '**A plain shell', '~/.codex/agents/<tier>.toml', 'SubagentStop', 'PreCompact', 'install/examples/codex-agents/')
    $missing = @($needles | Where-Object { -not $b.Contains($_) })
    $order = @($b.IndexOf('## Invariants'), $b.IndexOf("## The bridge's own means"), $b.IndexOf('## Worker tiers'), $b.IndexOf('## Means per host'))
    Check 'SKILL' 'D7 its body: the invariants (one objective per worker, a fresh worker per wave with its STATE.md, polling instead of a blocking wait, the idle watchdog, compaction at wave boundaries, never redo a worker''s work, English, the live-member rule, rating, the required reviewer), the bridge''s own means (-Detach, -Status, -Wait, -Kick), the tier contract, then the means per host (Claude Code, Codex CLI, wave 27b Z Code and Kimi Code, wave 27d Qwen Code, OpenCode and Muse Code, a plain shell) - in that order' ($missing.Count -eq 0 -and ($order -join ',') -eq ((@($order) | Sort-Object) -join ',') -and $order[0] -ge 0) ("missing: " + ($missing -join ' | '))
    # (wave 27d) rule 3: waiting without losing the cache (the operator's rule, revision 5) and COMPACT per host
    $r3 = [regex]::Match($b, '(?s)\n3\. \*\*Wait without blocking; keep the cache warm or compact \(the idle watchdog\)\.\*\*(.*?)\r?\n4\. \*\*').Groups[1].Value
    $r3n = $r3 -replace '\s+', ' '
    $idleNeedles = @('prompt cache', 'cold resume', 'refresh', '*Running work*', 'running work', 'has not reported', 'background `-Wait`', 'long shell job', 'ANOTHER session', 'named end', 'retry_after', 'Idle is only', 'ONE recurring wake every 30 minutes', 'off the round minutes', 'FIRST delegation or wait', 'kept when the work ends', 'small reads only', 'one line without a tool call', 'restarts at zero', 'middle of a wave', 'wave boundary', 'known length', 'idle wake 1', 'idle wake 2', '*No means to compact*', 'revision 6', 'TWO states only', 'keep the context warm ALWAYS', 'REMOVE the wake', 'the cheap ways back', 'a fresh session from the state file', 'a cheaper model whose window holds the context -> compact there -> back', '`--autocompact <tokens>`', 'while the cache is warm', 'auto-compact threshold', '*The boundary*', 'https://github.com/xelth-com/claude-codex-consult', '"Waiting: keep the prompt cache or compact"')
    $idleMissing = @($idleNeedles | Where-Object { -not $r3n.Contains($_) })
    $itemAt = @(foreach ($mk in @('*Running work*', '*The wake:*', '*The rule:*', '1. While running work', '2. At a wave boundary', '3. A wait of known length', '4. Idle:', '5. *No means to compact*', '6. Compact only while the cache is warm', '7. The operator''s lever', '*The boundary*')) { $r3n.IndexOf($mk) })
    $mph = $(if ($b.IndexOf('## Means per host') -ge 0) { $b.Substring($b.IndexOf('## Means per host')) } else { '' })
    $hostParas = [ordered]@{}
    foreach ($hn in @('**Claude Code.**', '**Codex CLI.**', '**Z Code.**', '**Kimi Code.**', '**Qwen Code.**', '**OpenCode.**', '**Muse Code.**')) { $at = $mph.IndexOf($hn); $next = $mph.IndexOf("`n**", [Math]::Max(0, $at) + 1); $hostParas[$hn] = $(if ($at -ge 0) { ($mph.Substring($at, $(if ($next -gt $at) { $next - $at } else { $mph.Length - $at }))) -replace '\s+', ' ' } else { '' }) }
    $hostCompact = @(foreach ($hn in $hostParas.Keys) { [bool]([string]$hostParas[$hn]).Contains('COMPACT:') })
    $ccPara = [string]$hostParas['**Claude Code.**']
    # (wave 28c, D14) revision 6: the no-means branch has two states (warm while work runs or is
    # awaited; idle: handover at idle wake 2, the wake removed, the cheap ways back) - the "40/20/10
    # wakes" branch is gone from the skill
    $r3Gone = @(@('KEEP the wake', '40 wakes on Claude Fable 5.1', 'half the refreshes') | Where-Object { $r3n.Contains($_) })
    Check 'SKILL' 'wave 27d rule 3 is the waiting rule (wave 28c, D14: revision 6), in order: the goal (a prompt cache never lost by oversight; a cold resume writes the whole context, a refresh reads it), the six cases of running work, the wake (ONE every 30 minutes, off the round minutes, armed at the FIRST delegation or wait, kept; small reads; one line without a tool call), the rule''s seven items (keep the wake, no compaction mid-wave; the wave boundary; a wait of known length; idle wakes 1 and 2; no means to compact - revision 6: TWO states only, the context kept warm ALWAYS while work runs or is awaited, idle: the handover at idle wake 2, the wake REMOVED, the cheap ways back - a fresh session, a cheaper model -> compact -> back, --autocompact <tokens>; NO "keep the wake for 40/20/10 wakes" any more; compact while warm; the auto-compact threshold), the boundary and the pointer to the README section with its URL; "Means per host" gives COMPACT for every host (Claude Code: no means, verified 2026-09-29, a scheduled /compact arrives as ordinary text)' ($r3 -and $idleMissing.Count -eq 0 -and $r3Gone.Count -eq 0 -and ($itemAt -join ',') -eq ((@($itemAt) | Sort-Object) -join ',') -and $itemAt[0] -ge 0 -and @($hostCompact | Where-Object { $_ }).Count -eq 7 -and $ccPara.Contains('no means') -and $ccPara.Contains('2026-09-29') -and $ccPara.Contains('ordinary text')) ("missing: " + ($idleMissing -join ' | ') + " | still there: " + ($r3Gone -join ' | ') + " | items at $($itemAt -join ',') | COMPACT per host $($hostCompact -join ',')")
    # (wave 27d) the skill's boundary table and its line for the other two models, recomputed from the formula
    $skRows = @(foreach ($cn in $waitContexts.Keys) { $x = Get-WaitNumbers $waitModels['Claude Fable 5.1'] $waitContexts[$cn]; "| $cn | $(Format-Dec $x.Hours 1) hours | $(Format-Dec $x.Wake 2) USD | $(Format-Dec $x.Compact 2) USD |" })
    $skLines = @(foreach ($mn in @('Claude Opus 5.5', 'Claude Sonnet 5.5')) { "$($mn): " + ((@(foreach ($cn in $waitContexts.Keys) { Format-Dec (Get-WaitNumbers $waitModels[$mn] $waitContexts[$cn]).Hours 1 })) -join ', ') + ' hours' })
    $skMissing = @(@($skRows | Where-Object { -not $r3.Contains($_) }) + @($skLines | Where-Object { -not $r3n.Contains($_) }))
    Check 'SKILL' 'wave 27d (A3) the skill''s boundary rows (Claude Fable 5.1: keep up to, one wake, compact) and the line for Claude Opus 5.5 and Claude Sonnet 5.5 are the numbers the formula gives (API prices of 2026-09, a wake every 30 minutes, turn 1K new input written + 300 output, summary 10K, compact window 50K)' ($skMissing.Count -eq 0) ("missing: " + ($skMissing -join ' || '))
    $newHosts = @(foreach ($hn in @('**Qwen Code.**', '**OpenCode.**', '**Muse Code.**')) { $p = [string]$hostParas[$hn]; [bool]($p.Contains('not run live') -and $p.Contains('-Detach') -and $p.Contains('hook one-liner')) })
    Check 'SKILL' 'wave 27d (B3) "Means per host" has Qwen Code, OpenCode and Muse Code - documented, not run live; each with the hook one-liner and -Detach (tool limit unknown for Qwen Code and OpenCode; Muse Code PowerShell at most 300 s, the skills at PROJECT scope because Muse Code is also a reviewer engine)' (@($newHosts | Where-Object { $_ }).Count -eq 3 -and ([string]$hostParas['**Qwen Code.**']).Contains('unknown') -and ([string]$hostParas['**OpenCode.**']).Contains('unknown') -and ([string]$hostParas['**Muse Code.**']).Contains('300 s') -and ([string]$hostParas['**Muse Code.**']).Contains('PROJECT scope') -and ([string]$hostParas['**Muse Code.**']).Contains('reviewer engine')) ($newHosts -join ',')
    $forCoord = [regex]::Match($readme, '(?ms)^## For the coordinator\r?\n(.*?)(?=^## )').Groups[1].Value
    Check 'SKILL' 'wave 27b (B9) README "For the coordinator" names the idle watchdog (the coordinate skill''s rule 3) and the operator''s lever, the host''s auto-compact threshold; (wave 27d, A4) it points at "Waiting: keep the prompt cache or compact", and so does the plugin''s own README' ($forCoord -match 'idle watchdog' -and $forCoord -match 'auto-compact threshold' -and ($forCoord -replace '\s+', ' ').Contains('"Waiting: keep the prompt cache or compact"') -and ((Text (Join-Path $pluginDir 'README.md')) -replace '\s+', ' ').Contains('"Waiting: keep the prompt cache or compact"')) ''
    $cc = Text (Join-Path $pluginDir 'skills\consult-codex\SKILL.md')
    Check 'SKILL' 'D7 consult-codex cross-links coordinate (its path and -Explain coordinate)' ($cc.Contains('${CLAUDE_PLUGIN_ROOT}/skills/coordinate/SKILL.md') -and $cc.Contains('-Explain coordinate')) ''
}
if (Want 'AGENTS') {
    $agentFiles = @(Get-ChildItem -LiteralPath (Join-Path $pluginDir 'agents') -Filter '*.md' | Sort-Object Name)
    $tierModel = @{ 'opus-worker' = 'opus'; 'sonnet-worker' = 'sonnet'; 'haiku-worker' = 'haiku' }
    $bad = New-Object System.Collections.Generic.List[string]
    foreach ($af in $agentFiles) {
        $base = [IO.Path]::GetFileNameWithoutExtension($af.Name)
        $a = Read-FrontMatter $af.FullName
        if ($a.Fm['name'] -ne $base -or -not $tierModel.ContainsKey($base) -or $a.Fm['model'] -cne $tierModel[$base] -or $a.Fm['description'].Length -lt 60 -or -not $a.Body.Trim()) { $bad.Add("$base (model '$($a.Fm['model'])')") }
    }
    $haiku = Read-FrontMatter (Join-Path $pluginDir 'agents\haiku-worker.md')
    Check 'AGENTS' 'D7 the plugin''s Claude Code agent files: exactly opus-worker, sonnet-worker, haiku-worker; front matter name = the file, model = the tier ALIAS (opus, sonnet, haiku - never a version), a description, a body from the tier contract; the read-only tier has no Edit/Write tool' ((@($agentFiles | ForEach-Object { $_.BaseName }) -join ',') -eq 'haiku-worker,opus-worker,sonnet-worker' -and $bad.Count -eq 0 -and $haiku.Fm['tools'] -and $haiku.Fm['tools'] -notmatch 'Edit|Write') (($bad -join ', ') + " tools: $($haiku.Fm['tools'])")
    $tomls = @(Get-ChildItem -LiteralPath (Join-Path $pluginDir 'install\examples\codex-agents') -Filter '*.toml' | Sort-Object Name)
    $tbad = New-Object System.Collections.Generic.List[string]
    foreach ($tf in $tomls) {
        $base = [IO.Path]::GetFileNameWithoutExtension($tf.Name)
        $keys = New-Object System.Collections.Generic.List[string]
        $inMulti = $false
        $nameVal = ''
        foreach ($l in ((Text $tf.FullName) -split "`r?`n")) {
            if ($inMulti) { if ($l.Contains("'''")) { $inMulti = $false }; continue }
            if ($l -match '^\s*#' -or -not $l.Trim()) { continue }
            if ($l -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
                $keys.Add($Matches[1])
                $v = $Matches[2]
                if ($Matches[1] -eq 'name' -and $v -match '^"(.*)"$') { $nameVal = $Matches[1] }
                if ($v.StartsWith("'''") -and -not $v.Substring(3).Contains("'''")) { $inMulti = $true }
            } else { $keys.Add("?$l") }
        }
        if ((@($keys | Sort-Object) -join ',') -ne 'description,developer_instructions,name' -or $nameVal -ne $base) { $tbad.Add("$base keys $($keys -join ',') name '$nameVal'") }
    }
    Check 'AGENTS' 'D7 the Codex agent EXAMPLES (install/examples/codex-agents/<tier>.toml, never installed by the plugin): exactly the three tiers, each with name (= the file), description, developer_instructions and NO model key' ((@($tomls | ForEach-Object { $_.BaseName }) -join ',') -eq 'haiku-worker,opus-worker,sonnet-worker' -and $tbad.Count -eq 0) ($tbad -join ' || ')
}

# =============================================================== README: install on three hosts, the coordinator (D1, D8)
if (Want 'README') {
    Check 'README' 'D1 README "## Install" covers three hosts: Claude Code (/plugin marketplace add xelth-com/claude-codex-consult, /plugin install codex-consult@claude-codex-consult), Codex CLI (the operator''s `codex plugin marketplace add xelth-com/claude-codex-consult` and `codex plugin add codex-consult@claude-codex-consult`), any shell (a clone, CODEX_CONSULT_ROOT=<clone>/plugins/codex-consult)' ($readme -match '(?m)^## Install' -and $readme.Contains('/plugin marketplace add xelth-com/claude-codex-consult') -and $readme.Contains('/plugin install codex-consult@claude-codex-consult') -and $readme.Contains('codex plugin marketplace add xelth-com/claude-codex-consult') -and $readme.Contains('codex plugin add codex-consult@claude-codex-consult') -and $readme -match 'CODEX_CONSULT_ROOT\s*=\s*"?<clone>/plugins/codex-consult') ''
    Check 'README' 'D1/F04-2 no install script and no copies: the README names no install-codex-host.ps1 and no ~/.codex/skills copy; the plugin carries no install script' (-not $readme.Contains('install-codex-host') -and -not $readme.Contains('AGENTS.snippet.md') -and @(Get-ChildItem -LiteralPath $pluginDir -Recurse -File -Filter 'install*.ps1').Count -eq 0) ''
    $snip = [regex]::Match($readme, '(?s)```text\r?\n(codex-consult: [^\n]*\n[^\n]*\n[^\n]*)\r?\n```')
    Check 'README' 'D7 the three-line AGENTS.md snippet the operator pastes on the Codex host: the coordinate skill (or -Explain coordinate), the hook one-liner when no codex-consult line is in the context, consult-codex and CODEX_CONSULT_COORDINATOR' ($snip.Success -and @($snip.Groups[1].Value -split "`n").Count -eq 3 -and $snip.Groups[1].Value.Contains('codex-consult:coordinate') -and $snip.Groups[1].Value.Contains('codex-consult-hook.ps1') -and $snip.Groups[1].Value.Contains('CODEX_CONSULT_COORDINATOR')) $(if ($snip.Success) { $snip.Groups[1].Value } else { 'no snippet' })
    Check 'README' 'D8 "## For the coordinator": the migration of a private CLAUDE.md delegation block to a pointer, and the plugin never edits a CLAUDE.md' ($readme -match '(?m)^## For the coordinator' -and $readme -match 'never edits a CLAUDE\.md') ''
    $jsonAt = $readme.IndexOf('"lineage": "ZAI :: glm-5.3",')
    Check 'README' 'D3/D4 the ledger reference: the example entry has "coordinator" right after "lineage" and "child_env_scrubbed" right after "command"; the field table has both rows and says `host` is the machine, `coordinator.host` the agent host' ($jsonAt -gt 0 -and $readme.Substring($jsonAt, 200) -match '^"lineage": "ZAI :: glm-5\.3",\s*\n\s*"coordinator": \{' -and $readme -match '"command": "[^\n]*",\s*\n\s*"child_env_scrubbed": \[' -and $readme -match '(?m)^\| `coordinator` \|' -and $readme -match '(?m)^\| `child_env_scrubbed` \|' -and $readme -match 'machine') ''
    Check 'README' 'the options and variables tables: -Explain, -BriefPrefix, CODEX_CONSULT_COORDINATOR, CODEX_CONSULT_BRIEF_PREFIX, CODEX_CONSULT_ROOT' ($readme -match '(?m)^\| `-Explain ' -and $readme -match '(?m)^\| `-BriefPrefix ' -and $readme -match '(?m)^\| `CODEX_CONSULT_COORDINATOR` \|' -and $readme -match '(?m)^\| `CODEX_CONSULT_BRIEF_PREFIX` \|' -and $readme -match '(?m)^\| `CODEX_CONSULT_ROOT` \|') ''
    # (wave 27b) the two more host sections
    $inst = [regex]::Match($readme, '(?ms)^## Install\r?\n(.*?)(?=^## )').Groups[1].Value
    $subs = [ordered]@{}
    foreach ($m in [regex]::Matches($inst, '(?ms)^### ([^\r\n]+)\r?\n(.*?)(?=^### |\z)')) { $subs[$m.Groups[1].Value.Trim()] = $m.Groups[2].Value }
    $heads = (@($subs.Keys) -join ' | ')
    $zs = [string]$subs['Z Code']
    $ks = [string]$subs['Kimi Code']
    $hs = [string]$subs['Hooks on each host']
    $zOk = ($zs.Contains('plugins marketplace add xelth-com/claude-codex-consult') -and $zs.Contains('plugins install codex-consult@claude-codex-consult') -and $zs.Contains('${ZCODE_PLUGIN_ROOT}') -and $zs.Contains('${CLAUDE_PLUGIN_ROOT}') -and $zs.Contains('AGENTS.md'))
    $kOk = ($ks.Contains('--skills-dir') -and $ks.Contains('CODEX_CONSULT_ROOT') -and $ks.Contains('/plugins/codex-consult/skills') -and $ks.Contains('AGENTS.md') -and $ks.Contains('-Explain coordinate') -and $ks.Contains('codex-consult-hook.ps1') -and $ks.Contains('CODEX_CONSULT_COORDINATOR'))
    Check 'README' 'wave 27b "## Install" has its host sections in order - Claude Code, Codex CLI, Z Code, Kimi Code, (wave 27d) Qwen Code, OpenCode, Muse Code, Any shell (a clone), Hooks on each host; Z Code: the two plugin commands (plugins marketplace add xelth-com/claude-codex-consult, plugins install codex-consult@claude-codex-consult), both root variables (${CLAUDE_PLUGIN_ROOT}, ${ZCODE_PLUGIN_ROOT}), AGENTS.md; Kimi Code: a clone, CODEX_CONSULT_ROOT, --skills-dir <clone>/plugins/codex-consult/skills, the AGENTS.md snippet, no hook (the hook one-liner, -Explain coordinate), CODEX_CONSULT_COORDINATOR; "Hooks on each host" names both' ($heads -eq 'Claude Code | Codex CLI | Z Code | Kimi Code | Qwen Code | OpenCode | Muse Code | Any shell (a clone) | Hooks on each host' -and $zOk -and $kOk -and $hs.Contains('Z Code') -and $hs.Contains('Kimi Code')) "sections: $heads; Z Code $zOk; Kimi Code $kOk"
    $lines = @($readme -split "`r?`n")
    $ledRow = [string](@($lines | Where-Object { $_ -match '^\| `child_env_scrubbed` \|' }) | Select-Object -First 1)
    $varRow = [string](@($lines | Where-Object { $_ -match '^\| `CODEX_SESSION_ID`, ' }) | Select-Object -First 1)
    $coordRow = [string](@($lines | Where-Object { $_ -match '^\| `coordinator` \|' }) | Select-Object -First 1)
    $missingDoc = New-Object System.Collections.Generic.List[string]
    foreach ($pair in @(@('ledger', $ledRow), @('variables', $varRow))) {
        foreach ($n in $script:HostMarkerNames) { if (-not ([string]$pair[1]).Contains('`' + $n + '`')) { $missingDoc.Add("$($pair[0]):$n") } }
        foreach ($p in $script:HostMarkerPrefixes) { if (-not ([string]$pair[1]).Contains('`' + $p + '*`')) { $missingDoc.Add("$($pair[0]):$p*") } }
    }
    $iCodex = $coordRow.IndexOf('`codex`'); $iZ = $coordRow.IndexOf('`zcode`'); $iC = $coordRow.IndexOf('`claude-code`')
    $ccSkill = Text (Join-Path $pluginDir 'skills\consult-codex\SKILL.md')
    Check 'README' 'wave 27b the documented lists match the code: the ledger''s child_env_scrubbed row and the variables table name every exact marker name and every prefix of the script (ZCODE_PLUGIN* included), the ledger row keeps CLAUDE_CODE_USE_BEDROCK and CLAUDE_PLUGIN_ROOT (exact names, not the prefix); the coordinator row lists the host values in the hint''s order codex, zcode, claude-code; the consult-codex skill names zcode' ($ledRow -and $varRow -and $missingDoc.Count -eq 0 -and $ledRow.Contains('CLAUDE_CODE_USE_BEDROCK') -and $ledRow.Contains('CLAUDE_PLUGIN_ROOT') -and $iCodex -ge 0 -and $iZ -gt $iCodex -and $iC -gt $iZ -and $ccSkill.Contains('`zcode`')) ("missing: " + ($missingDoc -join ', ') + " | order $iCodex/$iZ/$iC")
    # (wave 27d, B1, B4) three more coordinator hosts, documented and not run live
    $hostNeedles = [ordered]@{
        'Qwen Code' = @('qwen extensions install https://github.com/xelth-com/claude-codex-consult:codex-consult --consent', '~/.qwen/extensions/codex-consult', 'qwen extensions list', '${CLAUDE_PLUGIN_ROOT}', 'hooks/hooks.json', 'qwen extensions update codex-consult', 'qwen extensions uninstall codex-consult', 'AGENTS.md', '`-y`', '-Detach')
        'OpenCode'  = @('opencode.ai/docs/skills', '.opencode/skills/<name>/SKILL.md', '~/.config/opencode/skills', 'mklink /J', 'ln -s', 'never a copy', 'CODEX_CONSULT_ROOT', 'AGENTS.md', 'opencode run', '-Detach')
        'Muse Code' = @('muse skills install', 'muse skills update', 'muse skills list', 'muse skills import --from claude|codex', 'REVIEWER engine', 'PROJECT scope', '--scope user', 'CODEX_CONSULT_ROOT', 'AGENTS.md', 'muse exec --prompt-file', '300 s', '-Detach')
    }
    $hostMiss = New-Object System.Collections.Generic.List[string]
    foreach ($hn in $hostNeedles.Keys) {
        $hsec = ([string]$subs[$hn]) -replace '\s+', ' '
        foreach ($nd in $hostNeedles[$hn]) { if (-not $hsec.Contains($nd)) { $hostMiss.Add("$($hn): $nd") } }
        $paras = @(([string]$subs[$hn]).Trim() -split '\r?\n\s*\r?\n')
        if (-not (($paras[-1] -replace '\s+', ' ') -match 'Not run live by the maintainer( as a coordinator)?: \S')) { $hostMiss.Add("$($hn): no closing 'Not run live by the maintainer: <reason>'") }
        if (-not $hs.Contains($hn)) { $hostMiss.Add("Hooks on each host: $hn") }
    }
    Check 'README' 'wave 27d (B1) "### Qwen Code" (the extension installed from the repository''s marketplace, its path, the list, the plugin root substituted, hooks.json copied but no hook, update and removal, AGENTS.md, -y), "### OpenCode" (the skill directories of its documentation, one LINK per skill - a junction or a symbolic link, never a copy -, CODEX_CONSULT_ROOT, AGENTS.md, opencode run) and "### Muse Code" (muse skills install/update/list/import, the reviewer-engine warning - PROJECT scope, never --scope user -, CODEX_CONSULT_ROOT, AGENTS.md, muse exec, the 300 s shell tool); each closes with "Not run live by the maintainer: <reason>" and -Detach for the unknown or short tool limit; "Hooks on each host" names all three' ($hostMiss.Count -eq 0) ($hostMiss -join ' || ')
    $tested = [regex]::Match($readme, '(?ms)^## Tested on\r?\n(.*?)(?=^## )').Groups[1].Value
    $rowsB2 = @(foreach ($rh in @('| Coordinator host: Qwen Code 0.15.6 |', '| Coordinator host: OpenCode 1.17.18 |', '| Coordinator host: Muse Code 1.4.0 |')) { $row = [string](@($tested -split "`r?`n" | Where-Object { $_.StartsWith($rh) }) | Select-Object -First 1); [bool]($row -and $row -match 'Live coordinator run: none \(') })
    Check 'README' 'wave 27d (B2) "Tested on" has one row per new host - Qwen Code 0.15.6 (the install and what the extension list showed), OpenCode 1.17.18 (nothing on the machine; the paths from its documentation of 2026-09-29), Muse Code 1.4.0 (the commands exist, the headless mode answers) - each with "Live coordinator run: none (<reason>)"' (@($rowsB2 | Where-Object { $_ }).Count -eq 3 -and $tested.Contains('qwen extensions list') -and $tested.Contains('opencode.ai/docs/skills') -and $tested.Contains('muse exec --prompt-file')) ($rowsB2 -join ',')
    # (wave 27d, A2, A5) the waiting section: its place, its terms, both tables, the rule, what was measured, the caveats
    $heads2 = [string[]]@([regex]::Matches($readme, '(?m)^## ([^\r\n]+)') | ForEach-Object { $_.Groups[1].Value.Trim() })
    $wi = [array]::IndexOf($heads2, 'Waiting: keep the prompt cache or compact')
    $wsec = [regex]::Match($readme, '(?ms)^## Waiting: keep the prompt cache or compact\r?\n(.*?)(?=^---|^## )').Groups[1].Value
    $wn = $wsec -replace '\s+', ' '
    $wNeedles = @('prompt cache', 'lifetime', 'one hour', 'five minutes by default on the API', 'cache read', 'cache write', 'refresh', 'cold resume', 'compact window', 'running work', 'max_tokens: 0', 'has not reported', 'background `-Wait`', 'long shell job', 'ANOTHER session', 'named end', 'retry_after', 'Idle is only', 'one wake', 'keep, n wakes', 'let it expire', 'boundary', 'Worked example', 'What the money does not show', '**The rule**', 'wave boundary', '**Measured, taken, estimated.**', 'none is read from a bill', '**Caveats.**', 'pricing page', 'Subscription plans')
    $wMissing = @($wNeedles | Where-Object { -not $wn.Contains($_) })
    $t1 = '| Model of the coordinator | Input / output | Cache read | Cache write, 1 h lifetime | One cold resume costs as much as |'
    $t2 = '| Context C | Claude Fable 5.1: keep is cheaper up to | one wake | compact | let it expire | Claude Opus 5.5: keep up to | Claude Sonnet 5.5: keep up to |'
    $ruleBlock = [regex]::Match($wsec, '(?s)\*\*The rule\*\*(.*?)\*\*Measured').Groups[1].Value
    $ruleAt = @(foreach ($k in 1..7) { $m = [regex]::Match($ruleBlock, "(?m)^$k\. "); if ($m.Success) { $m.Index } else { -1 } })
    Check 'README' 'wave 27d (A2, A5) "## Waiting: keep the prompt cache or compact" right after "For the coordinator": the prompt cache and its lifetime (one hour in the sessions measured, five minutes by default on the API), the three prices, the refresh (the recurring wake; max_tokens: 0 on the API), the six cases of running work, the compact window and the cold resume, the formula, both tables, the worked example, what the money does not show, the rule in seven lines, what was measured and what is computed, the caveats with the vendor''s pricing page' ($wi -gt 0 -and $heads2[$wi - 1] -eq 'For the coordinator' -and $wsec -and $wMissing.Count -eq 0 -and $wsec.Contains($t1) -and $wsec.Contains($t2) -and ($ruleAt -join ',') -eq ((@($ruleAt) | Sort-Object) -join ',') -and $ruleAt[0] -ge 0) ("missing: " + ($wMissing -join ' | ') + " | heading at $wi | rule items at $($ruleAt -join ',')")
    # (wave 27d, A3) every number of the section recomputed from the formula and the prices
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $numMiss = New-Object System.Collections.Generic.List[string]
    $halves = New-Object System.Collections.Generic.List[string]
    foreach ($mn in $waitModels.Keys) {
        $m = $waitModels[$mn]
        $ratio = $m.W / $m.R
        $halves.Add((Format-Dec ($ratio / 2) 0))
        $row = "| $mn | $(Format-Dec ($m.P * 1000000) 0) / $(Format-Dec ($m.Pout * 1000000) 0) | $(Format-Dec ($m.R * $m.P * 1000000) 2) ($($m.R.ToString('0.###', $inv)) x input) | $(Format-Dec ($m.W * $m.P * 1000000) 0) ($(Format-Dec $m.W 0) x input) | $(Format-Dec $ratio 0) cache reads - $(Format-Dec ($ratio / 2) 0) hours"
        if (-not $wsec.Contains($row)) { $numMiss.Add($row) }
    }
    $fab = $waitModels['Claude Fable 5.1']
    foreach ($cn in $waitContexts.Keys) {
        $f = Get-WaitNumbers $fab $waitContexts[$cn]
        $o = Get-WaitNumbers $waitModels['Claude Opus 5.5'] $waitContexts[$cn]
        $s = Get-WaitNumbers $waitModels['Claude Sonnet 5.5'] $waitContexts[$cn]
        $row = "| $cn | $(Format-Dec $f.Hours 1) hours | $(Format-Dec $f.Wake 2) | $(Format-Dec $f.Compact 2) | $(Format-Dec $f.Expire 0) | $(Format-Dec $o.Hours 1) hours | $(Format-Dec $s.Hours 1) hours |"
        if (-not $wsec.Contains($row)) { $numMiss.Add($row) }
    }
    $n850 = Get-WaitNumbers $fab ([decimal]850000)
    $wantText = @(
        "16 wakes x $(Format-Dec $n850.Wake 4) = $(Format-Dec (16 * $n850.Wake) 2) USD, plus $(Format-Dec $n850.Read 2) USD for the read at the resume: about $(Format-Dec (16 * $n850.Wake + $n850.Read) 1) USD",
        "reading the compact window cold in the morning costs $(Format-Dec $n850.Compact 2) USD",
        "one cold resume: $(Format-Dec $n850.Expire 0) USD",
        "($(Format-Dec ($fab.R * $fab.P * 50000) 2) instead of $(Format-Dec $n850.Read 2) USD a turn in the example)")
    # (wave 28c, D14) revision 6 removed the rule's "40/20/10 wakes" branch: its numbers are gone from
    # the rule (the price table's last column - W/R cache reads - stays and is checked above)
    $ruleBlock6 = ([regex]::Match($wsec, '(?s)\*\*The rule\*\*(.*?)\*\*When the moment was missed').Groups[1].Value) -replace '\s+', ' '
    $gone6 = "($($halves[0]) wakes on Claude Fable 5.1, $($halves[1]) on Claude Opus 5.5, $($halves[2]) on Claude Sonnet 5.5)"
    if (-not $ruleBlock6 -or $ruleBlock6.Contains($gone6) -or -not $ruleBlock6.Contains('revision 6') -or -not $ruleBlock6.Contains('`--autocompact <tokens>`')) { $numMiss.Add("rule 5 still counts $gone6, or names no revision 6 / --autocompact") }
    foreach ($wt in $wantText) { if (-not $wn.Contains($wt)) { $numMiss.Add($wt) } }
    $cross = @(foreach ($mn in $waitModels.Keys) { $m = $waitModels[$mn]; [Math]::Round((Get-WaitNumbers $m ([decimal]1)).Tail / (($m.W - $m.R) * $m.P), 0) })
    if (@($cross | Where-Object { $_ -lt 70000 -or $_ -gt 80000 }).Count -gt 0 -or -not $wn.Contains('Above about 80K tokens')) { $numMiss.Add("the expire/compact crossover $($cross -join ', ')") }
    Check 'README' 'wave 27d (A3) every number of the waiting section is the formula''s: table 1 (input / output, cache read and write per million tokens, one cold resume = W/R cache reads = W/R/2 hours of refreshes), table 2 (Claude Fable 5.1: keep up to, one wake, compact, let it expire; Claude Opus 5.5 and Claude Sonnet 5.5: keep up to), the worked example (8 hours at 850K on Claude Fable 5.1), a working turn after a compaction, (wave 28c, D14) the rule WITHOUT the 40/20/10 wakes of revision 5 (revision 6, the launch option --autocompact <tokens> named) and "above about 80K tokens" (compacting cheaper than letting the cache expire)' ($numMiss.Count -eq 0) ("missing: " + ($numMiss -join ' || '))
}

# =============================================================== PATHHINT: the host hint by path, anchored (wave 28b, D11)
if (Want 'PATHHINT') {
    Clear-TestEnv
    $hHome = 'C:\Users\u'
    $hCodex = 'D:\ch'
    $hcases = [ordered]@{
        'C:\Users\u\.claude\plugins\cache\claude-codex-consult\codex-consult\0.5.0\scripts'     = 'claude-code/path'
        'C:\Users\u\.codex\plugins\cache\claude-codex-consult\codex-consult\0.5.0\scripts'      = 'codex/path'
        'D:\ch\plugins\cache\claude-codex-consult\codex-consult\0.5.0\scripts'                  = 'codex/path'
        'C:\Users\u\.zcode\cli\plugins\cache\claude-codex-consult\codex-consult\0.5.0\scripts'  = 'zcode/path'
        'C:\Users\u\.qwen\extensions\codex-consult\scripts'                                     = 'qwen-code/path'
        'c:\users\U\.CLAUDE\Plugins\Cache\x\scripts'                                            = 'claude-code/path'
        'C:\Users\u\src\.codex\plugins\cache\x\scripts'                                         = 'unknown/none'
        'C:\work\.claude\plugins\cache\claude-codex-consult\codex-consult\0.5.0\scripts'        = 'unknown/none'
        'C:\Users\u\.zcode\plugins\cache\x\scripts'                                             = 'unknown/none'
        'C:\Users\u\.claude\plugins\cache'                                                      = 'unknown/none'
        'C:\repo\.claude\worktrees\x\plugins\codex-consult\scripts'                             = 'unknown/none'
    }
    $hbad = @(foreach ($k in $hcases.Keys) { $x = Get-CoordinatorHostHint -ScriptPath $k -HomeDir $hHome -CodexHome $hCodex; if ("$($x.Host)/$($x.By)" -ne $hcases[$k]) { "$k -> $($x.Host)/$($x.By) (want $($hcases[$k]))" } })
    # (Get-HostPluginRoots hands back the array itself: assigned first, then enumerated)
    $rootList = Get-HostPluginRoots -HomeDir $hHome -CodexHome $hCodex
    $roots = @($rootList | ForEach-Object { "$($_.Host)=$($_.Root)" })
    Check 'PATHHINT' 'D11 (F36-4) the host hint by path is ANCHORED: the script root must lie UNDER a host''s plugin directory of the home (<home>\.claude\plugins\cache -> claude-code, <home>\.codex\plugins\cache and <codex home>\plugins\cache -> codex, <home>\.zcode\cli\plugins\cache -> zcode, <home>\.qwen\extensions -> qwen-code; case-insensitive on Windows); a path that merely CONTAINS such a name (a clone, another directory called .codex, the old .zcode\plugins, the plugin directory itself) gives no hint' ($hbad.Count -eq 0 -and $roots.Count -eq 5) (($hbad + $roots) -join ' || ')
}

# =============================================================== TESTLINE: where the test-mode line appears (wave 28c, D12)
if (Want 'TESTLINE') {
    $r = New-Repo 'testline'
    $dry = Consult $r '' @('-DryRun', '-Prompt', 'x')
    $refused = Consult $r '' @('-DryRun', '-Prompt', 'x', '-BriefPrefix', 'codex')
    $nLines = @(($dry.Out -split "`n") | Where-Object { $_.TrimEnd("`r") -ceq "WARNING: $testModeLine" }).Count
    $pv = $(if (@($dry.Previews).Count -gt 0) { @($dry.Previews)[0] } else { $null })
    Check 'TESTLINE' 'D12 (F44-5) the DRY RUN in test mode prints "WARNING: test mode is ON: test hooks are honoured" once, and its preview''s warnings[] holds the line once; a REFUSED run (the brief prefix codex, refused before anything starts) prints no such line' ($dry.Code -eq 0 -and $nLines -eq 1 -and $pv -and (Test-TestModeWarning $pv.warnings) -and $refused.Code -eq 1 -and $refused.Out -notmatch 'test mode is ON') "dry exit $($dry.Code), lines $nLines; refused exit $($refused.Code): $($refused.First)"
    $tmRow = (([regex]::Match($readme, '(?m)^\| `CODEX_CONSULT_NOW`[^\r\n]*')).Value) -replace '\s+', ' '
    Check 'TESTLINE' 'D12 README (the test hooks row) says WHERE the test-mode line appears - a committed run (after the commit), a dry run, a -Panel run, a detached run''s foreground - and where it does not: a refused run' ($tmRow.Contains('(wave 28c, D12)') -and $tmRow.Contains('a dry run') -and $tmRow.Contains('a -Panel run') -and $tmRow.Contains('a detached run') -and $tmRow.Contains('NOT on a refused run')) ''
}

# =============================================================== HOSTDOCS: the host blocks and the waiting prices (wave 28b, D17, D18)
if (Want 'HOSTDOCS') {
    $inst = [regex]::Match($readme, '(?ms)^## Install\r?\n(.*?)(?=^## )').Groups[1].Value
    $blockMiss = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($inst, '(?ms)^### ([^\r\n]+)\r?\n(.*?)(?=^### |\z)')) {
        $sec = $m.Groups[1].Value.Trim()
        foreach ($b in [regex]::Matches($m.Groups[2].Value, '(?ms)^```([a-z]*)\r?\n(.*?)^```')) {
            # (a ```text block is the AGENTS.md snippet the operator pastes, with its <plugin> placeholder - no command block)
            if ($b.Groups[1].Value -eq 'text') { continue }
            $code = $b.Groups[2].Value
            if ($code -match '\$P\b') { $blockMiss.Add("$($sec): uses `$P") }
            $usesDir = ($code -match 'CODEX_CONSULT_ROOT' -or $code -match '<clone>[\\/]plugins' -or $code -match '/scripts/codex-consult')
            if (-not $usesDir) { continue }
            $defines = ($code -match '\$env:CODEX_CONSULT_ROOT\s*=' -or $code -match '(?m)^\s*export CODEX_CONSULT_ROOT=')
            if (-not $defines) { $blockMiss.Add("$($sec): a block uses the plugin directory without defining CODEX_CONSULT_ROOT") }
            if ($code -match '<clone>[\\/]plugins[\\/]codex-consult[\\/]' ) { $blockMiss.Add("$($sec): a block spells the plugin directory out instead of CODEX_CONSULT_ROOT") }
        }
    }
    Check 'HOSTDOCS' 'D17 (F36-10) every command block of a host section of "## Install" that needs the plugin directory uses ONE name for it - CODEX_CONSULT_ROOT - and defines it in the same block (no $P from another section, no spelled-out <clone>/plugins/codex-consult/... path)' ($blockMiss.Count -eq 0) ($blockMiss -join ' || ')
    # the hook block, copied as written, runs: once with CODEX_CONSULT_ROOT set, once found in a plugin cache
    $hsec = [regex]::Match($inst, '(?ms)^### Hooks on each host\r?\n(.*?)(?=^### |\z)').Groups[1].Value
    $hb = [regex]::Match($hsec, '(?ms)^```powershell\r?\n(.*?)^```').Groups[1].Value
    $hbFile = Join-Path $work 'hook-block.ps1'
    [IO.File]::WriteAllText($hbFile, $hb, $u8)
    $rH = New-Repo 'hookblock'
    $binH = Join-Path $work 'bin-hb'
    [void][IO.Directory]::CreateDirectory($binH)
    [IO.File]::WriteAllText((Join-Path $binH 'codex.cmd'), "@echo off`r`nset ""FAKE_CODEX_ARGS=%*""`r`npowershell -NoProfile -ExecutionPolicy Bypass -File ""$(Join-Path $sp 'fake-codex3.ps1')""`r`nexit /b %ERRORLEVEL%`r`n")
    $cacheHome = Join-Path $work 'hb-codex-home'
    $copyDir = Join-Path $cacheHome 'plugins\cache\claude-codex-consult\codex-consult\0.5.0'
    [void][IO.Directory]::CreateDirectory($copyDir)
    foreach ($item in @(Get-ChildItem -LiteralPath $pluginDir -Force)) { Copy-Item -LiteralPath $item.FullName -Destination $copyDir -Recurse -Force }
    $savedPath = $env:Path
    $env:Path = "$binH;$savedPath"
    try {
        $hbSet = Run-Raw $hbFile $rH @() @{ CODEX_CONSULT_ROOT = $pluginDir; CODEX_HOME = $codexHome }
        $hbFound = Run-Raw $hbFile $rH @() @{ CODEX_CONSULT_ROOT = ''; CODEX_HOME = $cacheHome }
    } finally { $env:Path = $savedPath; Remove-Item env:CODEX_CONSULT_ROOT -ErrorAction SilentlyContinue }
    $setLines = @(($hbSet.Out -split "`n") | ForEach-Object { $_.TrimEnd("`r").Replace('/', '\') } | Where-Object { $_ })
    $foundLines = @(($hbFound.Out -split "`n") | ForEach-Object { $_.TrimEnd("`r").Replace('/', '\') } | Where-Object { $_ })
    $wantSet = Join-Path $scripts 'codex-consult.ps1'
    $wantFound = Join-Path $copyDir 'scripts\codex-consult.ps1'
    Check 'HOSTDOCS' 'D17 the hook block of "Hooks on each host" run AS WRITTEN: with CODEX_CONSULT_ROOT set it runs that plugin''s hook (two lines, the pointer names that codex-consult.ps1); with it unset it finds the newest install in a host''s plugin cache (here <codex home>\plugins\cache\...\0.5.0) and runs its hook - never "\scripts\codex-consult-hook.ps1"' ($hb -and $hbSet.Code -eq 0 -and $setLines.Count -eq 2 -and $setLines[1].StartsWith($pointerHead) -and $setLines[1].IndexOf($wantSet, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and $hbFound.Code -eq 0 -and $foundLines.Count -eq 2 -and $foundLines[1].IndexOf($wantFound, [StringComparison]::OrdinalIgnoreCase) -ge 0) "set: $($setLines -join ' / ') || found: $($foundLines -join ' / ')"
    # D18: the waiting section names its two refresh prices and the compaction after the expiry
    $wsec = [regex]::Match($readme, '(?ms)^## Waiting: keep the prompt cache or compact\r?\n(.*?)(?=^---|^## )').Groups[1].Value
    $wn = $wsec -replace '\s+', ' '
    # (wave 28c, D14) 'counted as cache reads' went with the rule's removed 40/20/10 branch
    $d18 = @('a *cache read* alone', 'a *full wake*', 'counts cache reads', 'fewer full wakes', 'compact after expiry = w x P x C + S x Pout + w x P x C2', 'a cold resume PLUS the summary')
    $d18Miss = @($d18 | Where-Object { -not $wn.Contains($_) })
    Check 'HOSTDOCS' 'D18 (F36-10) the waiting section says which price is a FULL WAKE (the cache read plus the wake''s turn) and which a CACHE READ alone (the last column of the price table counts cache reads), and that a compaction after the cache expired costs a cold resume PLUS the summary (the formula "compact after expiry")' ($d18Miss.Count -eq 0) ("missing: " + ($d18Miss -join ' | '))
    # (wave 28c, D14) the rule, revision 6, in the README: two states until the host lets the agent
    # compact itself; the 40/20/10 branch removed; the boundary tables stay; the launch option named
    $d14 = @('revision 6', 'two states only', 'kept warm ALWAYS', 'removes the wake', 'the cheap ways back', 'a fresh session from the state file', 'the boundary tables above stay', '`--autocompact <tokens>`', 'Claude Code 2.1.285')
    $d14Miss = @($d14 | Where-Object { -not $wn.Contains($_) })
    $forCoord14 = ([regex]::Match($readme, '(?ms)^## For the coordinator\r?\n(.*?)(?=^## )').Groups[1].Value) -replace '\s+', ' '
    Check 'HOSTDOCS' 'D14 (wave 28c) the README''s rule 5 is revision 6: two states only (the context kept warm ALWAYS while work runs or is awaited; idle: the handover at idle wake 2, the wake removed, the cheap ways back), revision 5''s 40/20/10 branch named as removed, the boundary tables kept for a manual compaction, the launch option --autocompact <tokens> (Claude Code 2.1.285); "For the coordinator" says the same and no longer "the wake kept"' ($d14Miss.Count -eq 0 -and $forCoord14.Contains('revision 6') -and $forCoord14.Contains('--autocompact <tokens>') -and -not $forCoord14.Contains('the wake kept')) ("missing: " + ($d14Miss -join ' | '))
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-host ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
