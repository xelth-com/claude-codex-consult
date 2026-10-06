# codex-consult wave 29: the `claude` engine (Claude Code headless, `claude -p`; ROADMAP R10 with R22,
# the design of the task claude-engine-2026-09-30 as amended by its decisions D1-D12) - the engine
# row and its adapter (argv, stdin, the stream-json parser, the turn rules, the salvage, the tool
# flight), the lineage (a minted session id, resume, fork), the per-turn proof of the init event (the
# read-only tools, no MCP server, dontAsk; apiKeySource for the billing), one resolved model per
# thread (D4), the ALLOW-listed child environment (D2) for the preflight, the version probe and every
# turn (D3), the sign-in check through `claude auth status`, the failure classes (auth, quota with its
# reset time, capability, transport, permission - D6, D8), the strict tree check (D1), the prompt
# bound (D9), the panel's scheduling group (D5), the health key (D7), the coordinator rule, the
# telemetry class, the roster validation and the providers listing. (Wave 29b) ENDPOINT: auth endpoint -
# a third-party Anthropic-compatible endpoint (decisions E1-E7 of handoff 12 of that task): the roster
# shapes, the child environment, the local preflight, the route and plan identities, telemetry and the
# lab by host, the plan's scheduling group, the 401 and the model proof (the fake's endpoint mode).
# FAKES ONLY: fake-claude.cmd (CODEX_CONSULT_CLAUDE_EXE) and fake-codex3.cmd. GUARD: the real claude is
# never resolvable - every child gets a scratch USERPROFILE/HOME (no ~/.local/bin/claude.exe) and a
# scratch LOCALAPPDATA, a PATH without any directory that holds a claude (or muse / agy) launcher, and
# the harness refuses to run when a claude launcher still resolves; every start of the fake appends a
# line to its argv log (FAKE_CLAUDE_ARGV_LOG), and a claude turn of the ledger without its line fails
# the GUARD check (a real CLI writes none); the harness string names the fake's version.
# Runs under the host it is started with (powershell 5.1 or pwsh 7, Windows). Work files:
# $env:TEMP\codex-consult-tests\harness-claude\<guid>, removed at the end.
param([string]$Only = '', [string]$ScriptsDir = '')
$ErrorActionPreference = 'Stop'
# (wave 26b, D13) the machine-wide health file stays out of these cases
$env:CODEX_CONSULT_HEALTH = 'none'
# (wave 28) telemetry off and the intake pointed at nothing reachable
$env:CODEX_CONSULT_TELEMETRY = 'off'
$env:CODEX_CONSULT_TELEMETRY_URL = 'http://127.0.0.1:9/'
# (wave 27c, D14) the test hooks are honoured only in test mode
$env:CODEX_CONSULT_TEST_MODE = '1'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $ScriptsDir) { $ScriptsDir = [string]$env:CODEX_CONSULT_SCRIPTS_DIR }
$scripts = if ($ScriptsDir) { (Resolve-Path -LiteralPath $ScriptsDir).Path } else { Join-Path $repoRoot 'plugins\codex-consult\scripts' }
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$providersPs = Join-Path $scripts 'codex-providers.ps1'
$schemaPath = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $scripts) 'schemas\consult-reply.schema.json'))
$fakeClaude = Join-Path $sp 'fake-claude.cmd'
$fakeCodex = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-claude') ([guid]::NewGuid().ToString('N'))
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
$savedEnv = @{}
foreach ($k in @('CODEX_HOME', 'Path', 'USERPROFILE', 'HOME', 'LOCALAPPDATA', 'TEMP', 'TMP', 'ANTHROPIC_API_KEY', 'CLAUDE_CONFIG_DIR')) { $savedEnv[$k] = [Environment]::GetEnvironmentVariable($k) }
$script:fails = 0
$script:passes = 0
$script:guardProblems = New-Object System.Collections.Generic.List[string]
$script:claudeTurnsSeen = 0
$testModeLine = 'test mode is ON: test hooks are honoured'
function Get-RealWarnings { param($List) @($List) | Where-Object { [string]$_ -ne $testModeLine } }
function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 300) { $ev = $ev.Substring(0, 300) + '...' }
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
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\t\handoffs'))
    return $r
}
$codexHome = Join-Path $work 'codexhome'
[void][IO.Directory]::CreateDirectory($codexHome)
[IO.File]::WriteAllText((Join-Path $codexHome 'config.toml'), "model = `"gpt-5.1`"`n", $u8)
# The scratch home of every child (USERPROFILE and HOME): no ~/.local/bin/claude.exe, no ~/.claude of
# the operator; with an AppData\Local (Windows PowerShell 5.1 needs it - see harness-muse).
$claudeHome = Join-Path $work 'home'
[void][IO.Directory]::CreateDirectory((Join-Path $claudeHome 'AppData\Local'))
$claudeConfig = Join-Path $work 'claude-config'
[void][IO.Directory]::CreateDirectory($claudeConfig)
$lad = Join-Path $work 'localappdata'
[void][IO.Directory]::CreateDirectory($lad)
# a PATH without any directory that holds a claude, agy or muse launcher (GUARD)
$realNames = @('claude', 'claude.exe', 'claude.cmd', 'claude.ps1', 'agy', 'agy.exe', 'agy.cmd', 'muse', 'muse.exe', 'muse.cmd')
$safePath = (@(([string]$savedEnv['Path']) -split ';' | Where-Object { $d = $_; $d -and -not (@($realNames | Where-Object { Test-Path -LiteralPath (Join-Path $d $_) }).Count -gt 0) })) -join ';'
function Write-Roster {
    param([string]$Name, [string]$Json)
    $p = Join-Path $work "roster-$Name.json"
    [IO.File]::WriteAllText($p, $Json, $u8)
    return $p
}
$fakeVarPrefix = 'FAKE_CLAUDE_'
$testVars = @('CODEX_CONSULT_EXE', 'CODEX_CONSULT_CLAUDE_EXE', 'CODEX_CONSULT_AGY_EXE', 'CODEX_CONSULT_MUSE_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER', 'OPENAI_BASE_URL', 'CODEX_CONSULT_TEST_LOGIN_TIMEOUT', 'CODEX_CONSULT_TEST_CHILD_ENV_PASS', 'CODEX_CONSULT_TEST_TOOL_CAP_SEC', 'CODEX_CONSULT_COORDINATOR', 'ANTHROPIC_API_KEY', 'ANTHROPIC_BASE_URL', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_MODEL', 'CLAUDE_CONFIG_DIR', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_EFFORT_LEVEL', 'CLAUDE_CODE_SKIP_PROMPT_HISTORY', 'CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT', 'CODEX_SESSION_ID', 'W29_OPERATOR_VAR', 'FAKE_CODEX_REPLY', 'FAKE_CODEX_LOG', 'W29B_FAKE_ZAI_TOKEN', 'W29B_FAKE_MIMO_TOKEN', 'API_TIMEOUT_MS', 'ANTHROPIC_DEFAULT_SONNET_MODEL', 'ANTHROPIC_SMALL_FAST_MODEL')
function Clear-TestEnv {
    foreach ($k in $testVars) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    # (the host markers of the environment the harness was started from - a coordinator's session -
    # never reach a case: child_env_scrubbed is compared exactly)
    foreach ($k in (Get-HostMarkerNames)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like "$fakeVarPrefix*" -or $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
}
# Every case: the fakes are the launchers, the scratch home / LOCALAPPDATA / PATH above, the test hook
# that lets FAKE_CLAUDE_* through the claude child's allow list, a scratch CLAUDE_CONFIG_DIR and the
# call's own argv log. '' in $Env removes a variable. $Roster '' = CODEX_CONSULT_ROSTER=none.
function Set-CaseEnv {
    param([string]$Roster, [hashtable]$Env, [string]$ArgvLog)
    Clear-TestEnv
    $env:CODEX_HOME = $codexHome
    $env:CODEX_CONSULT_CLAUDE_EXE = $fakeClaude
    $env:CODEX_CONSULT_EXE = $fakeCodex
    $env:CODEX_CONSULT_TEST_CHILD_ENV_PASS = 'FAKE_CLAUDE_'
    $env:CODEX_CONSULT_ROSTER = $(if ($Roster) { $Roster } else { 'none' })
    $env:USERPROFILE = $claudeHome
    $env:HOME = $claudeHome
    $env:LOCALAPPDATA = $lad
    $env:CLAUDE_CONFIG_DIR = $claudeConfig
    $env:TEMP = $savedEnv['TEMP']
    $env:TMP = $savedEnv['TMP']
    $env:Path = $safePath
    if ($ArgvLog) { $env:FAKE_CLAUDE_ARGV_LOG = $ArgvLog }
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
}
function Restore-Env {
    Clear-TestEnv
    foreach ($k in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($k, $savedEnv[$k]) }
}
function Ledger { param([string]$Repo) $f = Join-Path $Repo '.collab\t\sessions.json'; if (-not (Test-Path $f)) { return @() }; return @(([IO.File]::ReadAllText($f, $u8) | ConvertFrom-Json).codex.consults) }
function Last-Entry { param([string]$Repo) return (Ledger $Repo)[-1] }
# The argv log of one call: its JSON lines.
function Read-ArgvLog {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return @() }
    return @(([IO.File]::ReadAllText($Path, $u8) -split "`n") | Where-Object { $_.Trim() } | ForEach-Object { ConvertFrom-Json $_ })
}
function ConvertFrom-RunOutput {
    param($Out, [int]$Code)
    $text = (($Out | ForEach-Object { "$_" }) -join "`n")
    $preview = $null
    $mark = 'sessions.json entry preview:'
    $at = $text.IndexOf($mark)
    if ($at -ge 0) { try { $preview = $text.Substring($at + $mark.Length) | ConvertFrom-Json } catch { $preview = $null } }
    return [pscustomobject]@{ Code = $Code; Out = $text; Preview = $preview; First = (($text -split "`n") | Select-Object -First 1); Log = @(); LogPath = ''; GuardOk = $true }
}
# One bridge call. GUARD: every claude turn the call added to the ledger (engine_run.turns) must have
# its line in the call's argv log (the fake writes one per start; a real CLI would not).
function Consult {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList, [hashtable]$Env = @{}, [string]$Script = $consultPs)
    $log = Join-Path $work ("argv-" + [guid]::NewGuid().ToString('N').Substring(0, 10) + '.jsonl')
    $before = @(Ledger $Repo).Count
    Set-CaseEnv $Roster $Env $log
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $Script -Task t @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Restore-Env
    $r = ConvertFrom-RunOutput $out $code
    $r.LogPath = $log
    $r.Log = @(Read-ArgvLog $log)
    $new = @(Ledger $Repo | Select-Object -Skip $before | Where-Object { $_.reviewer.engine -eq 'claude' })
    $turns = 0
    foreach ($e in $new) { $turns += [int](Get-PropertyValue $e.engine_run 'turns' 0) }
    $logged = @($r.Log | Where-Object { $_.kind -eq 'turn' }).Count
    $script:claudeTurnsSeen += $turns
    if ($turns -ne $logged) {
        $r.GuardOk = $false
        $script:guardProblems.Add("$([IO.Path]::GetFileName($Repo)) $($ArgList -join ' '): $turns claude turn(s) in the ledger, $logged in the argv log")
    }
    return $r
}
function Providers {
    param([string]$Repo, [string]$Roster, [string[]]$ArgList = @(), [hashtable]$Env = @{})
    $log = Join-Path $work ("argv-p-" + [guid]::NewGuid().ToString('N').Substring(0, 10) + '.jsonl')
    Set-CaseEnv $Roster $Env $log
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
    return [pscustomobject]@{ Code = $code; Out = $text; Json = $json; Log = @(Read-ArgvLog $log) }
}
function Reply { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
function Td { param([string]$Repo, [string]$Rel) return (Join-Path (Join-Path $Repo '.collab\t') ($Rel -replace '/', '\')) }
function Text { param([string]$Path) if (Test-Path -LiteralPath $Path) { return [IO.File]::ReadAllText($Path, $u8) }; return '' }
function Seed-Task {
    param([string]$Repo, [object[]]$Entries)
    $dir = Join-Path $Repo '.collab\t'
    [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
    Write-JsonFile -Path (Join-Path $dir 'sessions.json') -Object ([pscustomobject]@{ task_id = 't'; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$Entries } })
}
function Uuid { return [guid]::NewGuid().ToString() }
$uuidRe = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
# the argument after a flag in one logged argv
function ArgOf { param($Rec, [string]$Flag) $a = @($Rec.argv); for ($i = 0; $i -lt $a.Count - 1; $i++) { if ([string]$a[$i] -ceq $Flag) { return [string]$a[$i + 1] } }; return '' }
function Turns { param($Res) return @($Res.Log | Where-Object { $_.kind -eq 'turn' }) }
function Has-Name { param($Rec, [string]$Name) return (@(@($Rec.env) | Where-Object { [string]$_ -ieq $Name }).Count -gt 0) }

$sonnetFp = Get-Sha256Hex ($u8.GetBytes('cc-engine-v1|claude|subscription|sonnet'))
$claudeArgs = @('-Engine', 'claude', '-Model', 'sonnet')
function New-ClaudeEntry {
    param([int]$N, [string]$Thread, [string]$Resolved = 'claude-sonnet-5-5', [string]$Model = 'sonnet')
    return [pscustomobject]@{ n = $N; when = (Get-IsoTimestamp); purpose = ''; reviewer = [pscustomobject]@{ provider = 'anthropic'; model = $Model; engine = 'claude'; provider_fingerprint = $sonnetFp }; lineage = "anthropic :: $Model"; thread = $Thread; thread_source = 'events'; mode = 'new'; reply = ('handoffs/{0:D2}-claudecode-seed.md' -f $N); bridge_outcome = 'usable reply'; engine_run = [pscustomobject]@{ turns = 1; model_resolved = $Resolved } }
}
$adviseJson = '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$advise = Reply 'advise.json' $adviseJson
$finding = '{"severity":"minor","locations":[{"path":"app.txt","line":1}],"claim":"c","trigger":"t","evidence":[{"kind":"read-code","reference":"app.txt","observation":"o"}],"verification":"v","remedy":"r","supersedes":[]}'
$adviseF = Reply 'advise-finding.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[' + $finding + '],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$prose = "**Q1.** The engine row keeps the other engines unchanged and adds one row for claude.`n**Q2.** The session rules close the resume gap because a minted session is the only parent.`n`nVerdict: ADVISE`n"
$proseFile = Reply 'prose.md' $prose
$proseMd = $prose -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n'
$repairedFile = Reply 'repaired.json' ('{"schema_version":"1","verdict":"ADVISE","verdict_reason":"the rules hold","reply_markdown":"' + $proseMd + '","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}')
$rosterClaude = Write-Roster 'claude' '{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"sonnet"}]}'
$rosterClaudeCodex = Write-Roster 'claude-codex' '{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"sonnet"},{"provider":"openai","model":"gpt-5.1"}]}'
$fakeVersion = 'claude-cli 2.1.285-fake'
$fakeEmail = 'fake-person@example.invalid'
$fakeOrg = 'FAKE-ORG-NAME-7c2'

# GUARD: with the harness environment and no CODEX_CONSULT_CLAUDE_EXE, no claude launcher may resolve
# (PATH, the install location) - otherwise the harness refuses to run at all.
Set-CaseEnv '' @{ CODEX_CONSULT_CLAUDE_EXE = '' } ''
$realClaude = Resolve-EngineLauncher -Engine 'claude'
Restore-Env
if ($realClaude) {
    Write-Host "FAIL SAFETY   a real claude launcher resolves in the test environment ($realClaude); the harness refuses to run."
    Remove-TestWork $work
    Write-Host ("harness-claude ({0} {1}): 0 passed, 1 failure(s)." -f $hostTag, $PSVersionTable.PSVersion)
    exit 1
}

try {
# =============================================================== UNIT: the adapter functions in-process
if (Want 'UNIT') {
    $spec = Get-EngineSpec 'claude'
    $fnMissing = @(foreach ($k in @('Argv', 'Stdin', 'Events', 'Outcome', 'Credential', 'Harness', 'IdentityConfig', 'Salvage', 'ChildEnv')) { $fn = [string]$spec.Adapter.$k; if (-not $fn -or -not (Get-Command $fn -ErrorAction SilentlyContinue)) { $k } })
    Check 'UNIT' 'engine row claude: label "Claude (claude)", reply prefix claudecode (the brief prefix claude stays the coordinator''s), command claude, CODEX_CONSULT_CLAUDE_EXE, launchers claude.exe claude.cmd claude + %USERPROFILE%\.local\bin\claude.exe, modes new/resume/fork (default new), native|prompt-only, engine:claude, provider anthropic, denial retry, prompt on stdin, --max-turns, WriteDisabled false (D1), auth modes subscription|api-key (wave 29b: |endpoint, checked locally - LocalAuthModes), parallel scope engine (D5), 1 MiB (D9); every adapter function exists; EngineNames ends with claude' ($spec.Label -eq 'Claude (claude)' -and $spec.Prefix -eq 'claudecode' -and $spec.Command -eq 'claude' -and $spec.ExeEnv -eq 'CODEX_CONSULT_CLAUDE_EXE' -and (@($spec.LauncherNames) -join ',') -eq 'claude.exe,claude.cmd,claude' -and $spec.InstallLaunchers[0].Rel -eq '.local\bin\claude.exe' -and (@($spec.Modes) -join ',') -eq 'new,resume,fork' -and $spec.DefaultMode -eq 'new' -and (@($spec.Transports) -join ',') -eq 'native,prompt-only' -and $spec.HostName -eq 'engine:claude' -and $spec.DefaultProvider -eq 'anthropic' -and $spec.DenialRetry -and $spec.PromptTransport -eq 'stdin' -and $spec.StepsFlag -eq '--max-turns' -and $spec.WriteDisabled -eq $false -and (@($spec.AuthModes) -join ',') -eq 'subscription,api-key,endpoint' -and (@($spec.LocalAuthModes) -join ',') -eq 'endpoint' -and $spec.ParallelScope -eq 'engine' -and $spec.MaxPromptBytes -eq 1048576 -and $fnMissing.Count -eq 0 -and ($script:EngineNames -join ',') -eq 'codex,agy,muse,claude') "missing: $($fnMissing -join ',')"
    $u = Uuid
    $new = Get-ClaudeArgs -Turn (New-EngineTurnOptions -Model 'sonnet' -Schema $schemaPath -Effort 'high' -NewThread $u -AddDirs @('D:\outside dir') -MaxSteps 12)
    $res = Get-ClaudeArgs -Turn (New-EngineTurnOptions -Model 'claude-sonnet-5-5' -Mode 'format-repair' -Thread $u -Effort 'low')
    $frk = Get-ClaudeArgs -Turn (New-EngineTurnOptions -Model 'claude-sonnet-5-5' -Mode 'fork' -Thread $u)
    Check 'UNIT' 'item 1: Get-ClaudeArgs - "-p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model <m> [--effort] [--json-schema <TEXT>] [--max-turns] [--add-dir]" then --session-id <minted> (new) | --resume <t> (a secondary turn) | --resume <p> --fork-session (fork); no prompt in argv; the schema text is one line and parses' ((@($new | Select-Object -First 15) -join ' ') -eq '-p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools Read,Grep,Glob --permission-mode dontAsk --model sonnet --effort high' -and $new[15] -eq '--json-schema' -and $new[16] -notmatch "`n" -and (ConvertFrom-Json $new[16]).title -eq 'codex-consult reply v1' -and (@($new | Select-Object -Skip 17) -join '|') -eq "--max-turns|12|--add-dir|D:\outside dir|--session-id|$u" -and (@($res | Select-Object -Last 4) -join ' ') -eq "--effort low --resume $u" -and (@($frk | Select-Object -Last 3) -join ' ') -eq "--resume $u --fork-session" -and (ConvertTo-ClaudeStdin -Prompt 'p x') -eq 'p x') ($new -join ' ').Substring(0, 120)
    Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class W29HarnessArgv {
  [DllImport("shell32.dll", SetLastError = true)] static extern IntPtr CommandLineToArgvW([MarshalAs(UnmanagedType.LPWStr)] string cmd, out int n);
  [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr h);
  public static string[] Split(string cmd) { int n; IntPtr p = CommandLineToArgvW(cmd, out n); string[] r = new string[n]; for (int i = 0; i < n; i++) { r[i] = Marshal.PtrToStringUni(Marshal.ReadIntPtr(p, i * IntPtr.Size)); } LocalFree(p); return r; }
}
'@
    $back = [W29HarnessArgv]::Split('x.exe ' + ((@($new) | ForEach-Object { ConvertTo-CrtArg $_ }) -join ' '))
    $same = ($back.Count -eq $new.Count + 1)
    if ($same) { for ($i = 0; $i -lt $new.Count; $i++) { if ($back[$i + 1] -cne $new[$i]) { $same = $false } } }
    Check 'UNIT' 'the argv is quoted by the C runtime rules (ConvertTo-CrtArg: \" and doubled backslashes) - CommandLineToArgvW gives back every argument, the schema text byte for byte; a trailing backslash and an empty value survive' ($same -and (ConvertTo-CrtArg 'C:\a b\') -eq '"C:\a b\\"' -and (ConvertTo-CrtArg '') -eq '""') "$($back.Count) vs $($new.Count + 1)"
    # the stream and the turn rules
    function Ev { param([string]$Name, [string[]]$Lines) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, (($Lines -join "`n") + "`n"), $u8); return $p }
    $init = '{"type":"system","subtype":"init","cwd":"C:\\r","session_id":"' + $u + '","tools":["Glob","Grep","Read","StructuredOutput"],"mcp_servers":[],"model":"claude-sonnet-5-5","permissionMode":"dontAsk","apiKeySource":"none"}'
    $asst = '{"type":"assistant","message":{"model":"claude-sonnet-5-5","content":[{"type":"thinking","thinking":"plan"},{"type":"text","text":"reading"},{"type":"tool_use","id":"toolu_1","name":"Read","input":{"file_path":"C:\\r\\a.txt"}}]},"session_id":"' + $u + '"}'
    $user = '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"toolu_1","content":"ok"}]},"session_id":"' + $u + '"}'
    $res1 = '{"type":"result","subtype":"success","is_error":false,"num_turns":2,"result":"done","session_id":"' + $u + '","total_cost_usd":0.012,"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":50},"modelUsage":{"claude-sonnet-5-5":{"outputTokens":50}},"permission_denials":[],"structured_output":{"schema_version":"1","verdict":"ADVISE"}}'
    $tNew = New-EngineTurnOptions -Model 'sonnet' -NewThread $u -Auth 'subscription'
    $e1 = Read-ClaudeEvents -Path (Ev 'u-ok.jsonl' @($init, $asst, $user, $res1))
    $o1 = Get-ClaudeTurnOutcome -Events $e1 -ExitCode 0 -Turn $tNew
    Check 'UNIT' 'item 3: a well-formed stream - usable, thread = the minted id, the reply = structured_output, ModelResolved = the init''s id (the alias resolved), usage {input = input + cache read + cache creation 1110, cached 1000, creation 100, output 50, reasoning null}, cost kept, one init, tools read' ($o1.Ok -and $o1.Thread -eq $u -and $o1.Structured -and $o1.Reply -eq '{"schema_version":"1","verdict":"ADVISE"}' -and $o1.ModelResolved -eq 'claude-sonnet-5-5' -and $e1.Usage.input_tokens -eq 1110 -and $e1.Usage.cached_input_tokens -eq 1000 -and $e1.Usage.cache_creation_input_tokens -eq 100 -and $e1.Usage.output_tokens -eq 50 -and $null -eq $e1.Usage.reasoning_output_tokens -and $e1.CostUsd -eq 0.012 -and $e1.InitCount -eq 1 -and (@($e1.InitTools) -join ',') -eq 'Glob,Grep,Read,StructuredOutput') "$($o1.Outcome) $($o1.Reply)"
    $rules = [ordered]@{
        'extra tool'        = @(@(($init -replace '"StructuredOutput"', '"StructuredOutput","Bash"'), $res1), $tNew, 'permission', 'tools outside Read, Grep, Glob, StructuredOutput: Bash')
        'an MCP server'     = @(@(($init -replace '"mcp_servers":\[\]', '"mcp_servers":[{"name":"x","status":"connected"}]'), $res1), $tNew, 'permission', 'MCP server\(s\) \(x\)')
        'another mode'      = @(@(($init -replace 'dontAsk', 'default'), $res1), $tNew, 'permission', "permission mode 'default', not dontAsk")
        'api key billing'   = @(@(($init -replace '"apiKeySource":"none"', '"apiKeySource":"ANTHROPIC_API_KEY"'), $res1), $tNew, 'auth', 'apiKeySource ANTHROPIC_API_KEY, not none')
        'no init'           = @(@($res1), $tNew, 'permission', 'no init event')
        'another session'   = @(@($init, $res1), (New-EngineTurnOptions -Model 'sonnet' -NewThread (Uuid)), 'unknown', 'not the minted')
        'model drift'       = @(@($init, $res1), (New-EngineTurnOptions -Model 'claude-opus-5-5' -NewThread $u), 'capability', 'model drift: asked claude-opus-5-5, served claude-sonnet-5-5')
        'usage drift'       = @(@($init, ($res1 -replace '"modelUsage":\{"claude-sonnet-5-5":\{"outputTokens":50\}\}', '"modelUsage":{"claude-sonnet-5-5":{"outputTokens":5},"claude-opus-5-5":{"outputTokens":300}}')), $tNew, 'capability', 'modelUsage names claude-opus-5-5')
        'fork on parent'    = @(@($init, $res1), (New-EngineTurnOptions -Model 'sonnet' -Mode 'fork' -Thread $u), 'unknown', 'fork came back on its parent')
        'max turns'         = @(@($init, ('{"type":"result","subtype":"error_max_turns","is_error":true,"result":"","session_id":"' + $u + '"}')), $tNew, 'capability', 'max turns reached')
        'two results'       = @(@($init, $res1, $res1), $tNew, 'transport', '2 result events')
        'event after result' = @(@($init, $res1, $asst), $tNew, 'transport', 'follows the result event')
    }
    $bad = @()
    $k = 0
    foreach ($name in $rules.Keys) {
        $k++
        $o = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev "u-r$k.jsonl" $rules[$name][0])) -ExitCode 0 -Turn $rules[$name][1]
        if (-not (-not $o.Ok -and $o.Class -eq $rules[$name][2] -and $o.Outcome -match $rules[$name][3])) { $bad += "$name -> [$($o.Outcome)] $($o.Class)" }
    }
    Check 'UNIT' "items 3, 4, 6, D4: every rule fails the turn with its class - $(@($rules.Keys) -join ', ')" ($bad.Count -eq 0) ($bad -join ' | ')
    $apiOk = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev 'u-api.jsonl' @(($init -replace '"apiKeySource":"none"', '"apiKeySource":"ANTHROPIC_API_KEY"'), $res1))) -ExitCode 0 -Turn (New-EngineTurnOptions -Model 'sonnet' -NewThread $u -Auth 'api-key')
    $two = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev 'u-two.jsonl' @($init, ($res1 -replace '"modelUsage":\{"claude-sonnet-5-5":\{"outputTokens":50\}\}', '"modelUsage":{"claude-sonnet-5-5":{"outputTokens":50},"claude-haiku-4-5":{"outputTokens":3}}')))) -ExitCode 0 -Turn $tNew
    $den = $res1 -replace '"permission_denials":\[\]', '"permission_denials":[{"tool_name":"Read","tool_use_id":"t","tool_input":{"file_path":"C:\\outside\\x.txt"}}]'
    $denUse = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev 'u-den.jsonl' @($init, $den))) -ExitCode 0 -Turn $tNew
    $denEmpty = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev 'u-den2.jsonl' @($init, ($den -replace ',"structured_output":\{"schema_version":"1","verdict":"ADVISE"\}', '' -replace '"result":"done"', '"result":""')))) -ExitCode 0 -Turn $tNew
    Check 'UNIT' 'auth api-key takes apiKeySource ANTHROPIC_API_KEY; a second modelUsage key -> usable, OtherModels + a warning (D4); a denial beside a reply -> usable + "permission denials beside the reply: ... Read C:\outside\x.txt"; a denial and no reply -> DeniedEmpty, class permission (the denial retry, D6)' ($apiOk.Ok -and $two.Ok -and (@($two.OtherModels) -join ',') -eq 'claude-haiku-4-5' -and @($two.Warnings | Where-Object { $_ -match 'other models in the turn' }).Count -eq 1 -and $denUse.Ok -and @($denUse.Warnings | Where-Object { $_ -match 'permission denials beside the reply: 1 tool call\(s\) denied under --permission-mode dontAsk: Read C:\\outside\\x\.txt' }).Count -eq 1 -and -not $denEmpty.Ok -and $denEmpty.DeniedEmpty -and $denEmpty.Class -eq 'permission') "$($denEmpty.Outcome)"
    $rl = '{"type":"rate_limit_event","rate_limit_info":{"status":"rejected","resetsAt":' + [DateTimeOffset]::UtcNow.AddHours(2).ToUnixTimeSeconds() + ',"rateLimitType":"five_hour"},"session_id":"' + $u + '"}'
    $q = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev 'u-q.jsonl' @($init, $rl, ('{"type":"result","subtype":"success","is_error":true,"result":"Claude AI usage limit reached","session_id":"' + $u + '"}')))) -ExitCode 1 -Turn $tNew
    $qpf = New-ProviderFailure -Texts @($q.Texts) -Class $q.Class
    $au = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev 'u-au.jsonl' @('{"type":"result","subtype":"success","is_error":true,"result":"Not logged in - Please run /login","session_id":"' + $u + '"}'))) -ExitCode 1 -Turn $tNew
    $killed = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev 'u-k.jsonl' @($init, $asst, '{"type":"assis')) -AllowPartialLast) -ExitCode -1 -Pre 'failed: timeout after 5 s' -Turn $tNew
    $killedQ = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (Ev 'u-kq.jsonl' @($init, $rl)) -AllowPartialLast) -ExitCode -1 -Pre 'failed: timeout after 5 s' -Turn $tNew
    Check 'UNIT' 'D6: a rejecting rate_limit_event -> class quota, retry_after = its resetsAt; "Not logged in ... /login" -> class auth; a killed turn: the thread candidate is the minted id its init confirmed, ModelResolved from that init (the continuation pins it), a partial last line tolerated; killed after a rejecting rate_limit_event -> class quota (no continuation)' ($q.Class -eq 'quota' -and $qpf.retry_after -and $au.Class -eq 'auth' -and $killed.ThreadCandidate -eq $u -and $killed.ModelResolved -eq 'claude-sonnet-5-5' -and $killedQ.Class -eq 'quota') "$($q.Outcome) | $($qpf.retry_after) | $($au.Outcome)"
    $sal = Read-TurnSalvage -Engine 'claude' -Path (Ev 'u-s.jsonl' @($init, $asst, $user))
    $open = New-Object 'System.Collections.Generic.HashSet[string]'
    $labels = @{}
    Update-ToolFlight -Engine 'claude' -Line $asst -Open $open -Labels $labels
    $opened = $open.Count
    Update-ToolFlight -Engine 'claude' -Line $user -Open $open
    Check 'UNIT' 'item 7: the salvage (Read-TurnSalvage -> Read-ClaudeSalvage): the thinking and the text in stream order, the tool call "Read: C:\r\a.txt"; the tool flight: a tool_use opens "claude Read toolu_1", its tool_result closes it; a system/compact_boundary counts as a compaction' ((@($sal.Items | ForEach-Object { $_.Kind }) -join ',') -eq 'reasoning,message' -and (@($sal.Tools) -join ',') -eq 'Read: C:\r\a.txt' -and $opened -eq 1 -and $labels['claude:toolu_1'] -eq 'claude Read toolu_1' -and $open.Count -eq 0 -and (Get-CompactionCount -Paths @((Ev 'u-c.jsonl' @($init, '{"type":"system","subtype":"compact_boundary","session_id":"x"}', $res1)))) -eq 1) "$(@($sal.Items).Count) items, $($sal.Tools -join ',')"
    $cl = { param([string]$M) [pscustomobject]@{ HostName = 'engine:claude'; Model = $M; ModelSource = '-Model' } }
    $sent = @(foreach ($lvl in @('low', 'medium', 'high', 'xhigh')) { (Resolve-EffortPlan -Identity (& $cl 'sonnet') -Requested $lvl).Sent })
    Check 'UNIT' 'effort: caps-v1 engine:claude = vocabulary claude (mapping claude-v1) for any model - low medium high xhigh as is; -NativeEffort max verbatim; the repair effort low; schema transport native' (($sent -join ',') -eq 'low,medium,high,xhigh' -and (Resolve-EffortPlan -Identity (& $cl 'claude-opus-5-5') -Requested 'high').Mapping -eq 'claude-v1' -and (Resolve-EffortPlan -Identity (& $cl 'x') -Requested 'high' -Native 'max').Sent -eq 'max' -and (Get-RepairEffort -Identity (& $cl 'sonnet') -EffortPlan (Resolve-EffortPlan -Identity (& $cl 'sonnet') -Requested 'xhigh')) -eq 'low' -and (Get-SchemaTransport -Identity (& $cl 'x')).Transport -eq 'native') ($sent -join ',')
    $cfg = [pscustomobject]@{ Exists = $false; Ok = $false; Path = ''; Tables = @{} }
    $iOpus = Resolve-ReviewerIdentity -Config $cfg -Provider 'anthropic' -Model 'opus' -Engine 'claude'
    $iOpusId = Resolve-ReviewerIdentity -Config $cfg -Provider 'x' -Model 'claude-opus-5-5[1m]' -Engine 'claude' -Auth 'subscription'
    $iSonnet = Resolve-ReviewerIdentity -Config $cfg -Provider 'anthropic' -Model 'sonnet' -Engine 'claude'
    $iApi = Resolve-ReviewerIdentity -Config $cfg -Provider 'anthropic' -Model 'opus' -Engine 'claude' -Auth 'api-key'
    Check 'UNIT' 'D7: the endpoint (fingerprint) of a claude entry = engine + auth + model family - opus and claude-opus-5-5[1m] share cc-engine-v1|claude|subscription|opus, sonnet and the api-key route are other endpoints; provider_config.credential_mechanism = the auth' ($iOpus.Fingerprint -eq $iOpusId.Fingerprint -and $iOpus.CompatString -eq 'cc-engine-v1|claude|subscription|opus' -and $iSonnet.Fingerprint -eq $sonnetFp -and $iApi.CompatString -eq 'cc-engine-v1|claude|api-key|opus' -and $iApi.ProviderConfig.credential_mechanism -eq 'api-key' -and $iOpus.ProviderConfig.credential_mechanism -eq 'subscription') "$($iOpus.CompatString) / $($iApi.CompatString)"
    $coord = [pscustomobject]@{ provider = 'Anthropic'; model = 'claude-sonnet-5-5'; engine = 'codex'; source = 'explicit' }
    $cr = Resolve-CoordinatorIdentity -Value 'anthropic :: claude-opus-5-5[1m]'
    $vend = @($script:TelemetryVendors | Where-Object { $_.Class -eq 'anthropic' })[0]
    Check 'UNIT' 'item 9: a claude reviewer is the coordinator''s own model when the coordinator names anthropic (any case, whatever the roster label) and the same model after normalising (the alias sonnet = claude-sonnet-5-5); another family is not; the coordinator''s [1m] is stripped; item 10 / D4: telemetry class anthropic for engine claude, the model from the table ([1m] stripped), else other; lab anthropic for the aliases and ids' ((Get-CoordinatorMatch -Coordinator $coord -Provider 'my-label' -Model 'sonnet' -Engine 'claude') -eq 'own' -and (Get-CoordinatorMatch -Coordinator $coord -Provider 'anthropic' -Model 'opus' -Engine 'claude') -eq '' -and -not $cr.Error -and $cr.Record.model -eq 'claude-opus-5-5' -and (Get-TelemetryVendor ([pscustomobject]@{ engine = 'claude'; provider = 'x' })).Class -eq 'anthropic' -and (Get-TelemetryModelToken -Vendor $vend -Model 'Claude-Opus-5-5[1m]') -eq 'claude-opus-5-5' -and (Get-TelemetryModelToken -Vendor $vend -Model 'claude-opus-9') -eq 'other' -and (Get-ModelLab 'haiku') -eq 'anthropic' -and (Get-ModelLab 'claude-fable-5-1') -eq 'anthropic') "$($cr.Error)"
    # D2: the allow list (in-process, this harness's environment)
    Set-CaseEnv '' @{ ANTHROPIC_BASE_URL = 'http://127.0.0.1:9/'; CLAUDE_CODE_EFFORT_LEVEL = 'max'; W29_OPERATOR_VAR = 'x'; ANTHROPIC_API_KEY = 'fake-key-0815' } ''
    $ceS = Get-ClaudeChildEnvironment -Auth 'subscription'
    $ceA = Get-ClaudeChildEnvironment -Auth 'api-key'
    $env:CODEX_CONSULT_TEST_CHILD_ENV_PASS = 'ANTHROPIC_'
    $ceBad = Get-ClaudeChildEnvironment
    Restore-Env
    $has = { param($ce, [string]$n) @($ce.Names | Where-Object { $_ -ieq $n }).Count -gt 0 }
    Check 'UNIT' 'D2: the child environment is an ALLOW list - PATH, USERPROFILE, CLAUDE_CONFIG_DIR, the FAKE_CLAUDE_ test prefix and DISABLE_AUTOUPDATER=1 pass; ANTHROPIC_BASE_URL, CLAUDE_CODE_EFFORT_LEVEL, an operator variable and the test-mode variables do not; ANTHROPIC_API_KEY only with auth api-key; a test prefix of ANTHROPIC is refused' ((& $has $ceS 'Path') -and (& $has $ceS 'USERPROFILE') -and (& $has $ceS 'CLAUDE_CONFIG_DIR') -and (& $has $ceS 'DISABLE_AUTOUPDATER') -and $ceS.Env['DISABLE_AUTOUPDATER'] -eq '1' -and -not (& $has $ceS 'ANTHROPIC_BASE_URL') -and -not (& $has $ceS 'CLAUDE_CODE_EFFORT_LEVEL') -and -not (& $has $ceS 'W29_OPERATOR_VAR') -and -not (& $has $ceS 'CODEX_CONSULT_TEST_MODE') -and -not (& $has $ceS 'ANTHROPIC_API_KEY') -and (& $has $ceA 'ANTHROPIC_API_KEY') -and -not (& $has $ceA 'ANTHROPIC_BASE_URL') -and -not (& $has $ceBad 'ANTHROPIC_BASE_URL') -and @($ceS.Removed) -contains 'W29_OPERATOR_VAR') ($ceS.Names -join ',')
    # D5: one scheduling group for the claude members, whatever their labels; the roster raises it
    $pm = { param([int]$Pos, [string]$Prov, [string]$Mod, [string]$Eng) [pscustomobject]@{ Entry = [pscustomobject]@{ Position = $Pos; Provider = $Prov; Model = $Mod; Engine = $Eng }; Identity = (Resolve-ReviewerIdentity -Config $cfg -Provider $Prov -Model $Mod -Engine $Eng) } }
    $runners = @((& $pm 1 'anthropic' 'opus' 'claude'), (& $pm 2 'anthropic-fast' 'sonnet' 'claude'), (& $pm 3 'openai' 'gpt-5.1' 'codex'))
    $plan1 = Get-PanelPlan -Runners $runners -Parallel (New-Object System.Collections.Hashtable) -Cap 0
    $par = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal); $par['anthropic'] = 2; $par['anthropic-fast'] = 2
    $plan2 = Get-PanelPlan -Runners $runners -Parallel $par -Cap 0
    $avail = Get-EndpointGroups -Members $runners
    Check 'UNIT' 'D5: two claude members of two labels and two families share ONE scheduling group (limit 1: "at most 2 at a time" with a codex member); "parallel" 2 on both labels -> "at once"; the availability view keeps them apart (D7: an Opus outage does not mark Sonnet)' ($plan1.GroupOf[1] -eq $plan1.GroupOf[2] -and $plan1.GroupOf[3] -ne $plan1.GroupOf[1] -and $plan1.Text -eq 'at most 2 at a time' -and $plan2.Text -eq 'at once' -and $avail.GroupOf[1] -ne $avail.GroupOf[2]) "$($plan1.Text) / $($plan2.Text)"
    $cc = [IO.File]::ReadAllText($consultPs, $u8)
    Check 'UNIT' 'D2 of wave 23 kept: codex-consult.ps1 names no claude parser, outcome or argv function (every turn through $engineSpec.Adapter)' ([regex]::Matches($cc, 'Read-ClaudeEvents|Get-ClaudeTurnOutcome|Get-ClaudeArgs|ConvertTo-ClaudeStdin').Count -eq 0) ''
    # the install location (no process is started: an empty file is found, never run)
    $ib = Join-Path $claudeHome '.local\bin'
    [void][IO.Directory]::CreateDirectory($ib)
    [IO.File]::WriteAllText((Join-Path $ib 'claude.exe'), '', $u8)
    Set-CaseEnv '' @{ CODEX_CONSULT_CLAUDE_EXE = '' } ''
    $inst = Resolve-EngineLauncher -Engine 'claude'
    Restore-Env
    Remove-Item -LiteralPath (Join-Path $ib 'claude.exe') -Force
    Check 'UNIT' 'item 7: with no launcher on PATH the native install location %USERPROFILE%\.local\bin\claude.exe is found (a bridge started before the install)' ($inst -eq (Join-Path $ib 'claude.exe')) $inst
}

# =============================================================== ROSTER: the claude entry (item 8, D4)
if (Want 'ROSTER') {
    $rp = Join-Path $work 'roster-unit.json'
    $rd = { param([string]$Json) [IO.File]::WriteAllText($rp, $Json, $u8); Read-ReviewerRoster -Location ([pscustomobject]@{ Path = $rp; FromEnv = $true; Disabled = $false }) }
    $ok = & $rd '{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"claude-opus-5-5[1m]","auth":"subscription","panel":"weighty","lab":"anthropic","context_tokens":1000000,"timeout_sec":1800},{"provider":"anthropic","engine":"claude","model":"sonnet","auth":"api-key"},{"provider":"anthropic","engine":"claude","model":"haiku"}],"parallel":{"anthropic":2}}'
    Check 'ROSTER' 'a claude roster: the model of the table (an id with [1m], an alias), auth subscription | api-key, the default subscription; parallel, lab, context_tokens as for every entry' (-not $ok.Error -and $ok.Entries[0].Model -eq 'claude-opus-5-5[1m]' -and $ok.Entries[0].Auth -eq 'subscription' -and $ok.Entries[1].Auth -eq 'api-key' -and $ok.Entries[2].Auth -eq 'subscription' -and $ok.Parallel['anthropic'] -eq 2) $ok.Error
    $refuse = [ordered]@{
        'a model outside the table' = @('{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"gpt-5.1"}]}', "the claude model 'gpt-5.1' is not in the claude engine's model table")
        'a future id'               = @('{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"claude-opus-9"}]}', "the claude model 'claude-opus-9' is not in")
        'no model'                  = @('{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude"}]}', 'engine claude needs a model')
        'auth none'                 = @('{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"opus","auth":"none"}]}', 'auth of engine claude must be "subscription"')
        'codex_config'              = @('{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"opus","codex_config":["a=b"]}]}', 'codex_config does not apply to engine claude')
        'auth on agy'               = @('{"roster_version":1,"reviewers":[{"provider":"g","engine":"agy","model":"gemini-3.8-flash-high","auth":"api-key"}]}', 'auth may only be "none"')
        '[1m] on codex'             = @('{"roster_version":1,"reviewers":[{"provider":"openai","model":"gpt-5.1[1m]"}]}', "model must not contain '\['")
    }
    $bad = @()
    foreach ($n in $refuse.Keys) { $rr = & $rd $refuse[$n][0]; if (-not ($rr.Error -and $rr.Error -match $refuse[$n][1])) { $bad += "$n -> $($rr.Error)" } }
    Check 'ROSTER' "refused: $(@($refuse.Keys) -join ', ')" ($bad.Count -eq 0) ($bad -join ' | ')
}

# =============================================================== DRYRUN: the plan of a claude run
if (Want 'DRYRUN') {
    $r = New-Repo 'dry'
    $d = Consult $r '' (@('-DryRun') + $claudeArgs + @('-Prompt', 'Check the %APPDATA% words'))
    $pv = $d.Preview
    $minted = [string](@($pv.command -split ' ') | Select-Object -Last 1)
    $auth = @($d.Log | Where-Object { $_.kind -eq 'auth' })
    $ver = @($d.Log | Where-Object { $_.kind -eq 'version' })
    Check 'DRYRUN' 'a dry run: engine claude, provider anthropic (the default label), harness "claude-cli 2.1.285-fake" (the fake''s --version: no file version on a .cmd), preflight available through `claude auth status` ("ok: signed in (claude.ai subscription)"), provider_config {credential_mechanism subscription, auth_method claude.ai, api_provider firstParty} and neither the account''s e-mail nor its organisation anywhere, mode new, the command ends with --session-id <a minted uuid>, schema native, effort claude-v1, reply handoffs/NN-claudecode-*, the alias warning; no claude turn' ($d.Code -eq 0 -and $pv.reviewer.engine -eq 'claude' -and $pv.reviewer.provider -eq 'anthropic' -and $pv.reviewer.harness -eq $fakeVersion -and $pv.preflight -eq 'ok: signed in (claude.ai subscription)' -and $pv.reviewer.provider_config.credential_mechanism -eq 'subscription' -and $pv.reviewer.provider_config.auth_method -eq 'claude.ai' -and $pv.reviewer.provider_config.api_provider -eq 'firstParty' -and -not $d.Out.Contains($fakeEmail) -and -not $d.Out.Contains($fakeOrg) -and $pv.mode -eq 'new' -and $pv.command.StartsWith('claude -p --output-format stream-json --verbose --restricted --strict-mcp-config --disable-slash-commands --tools') -and $pv.command -match ' --session-id [0-9a-f-]{36}$' -and $minted -match $uuidRe -and $pv.schema_transport -eq 'native' -and $pv.effort_mapping -eq 'claude-v1' -and $pv.reply -match '^handoffs/\d\d-claudecode-' -and @(Get-RealWarnings $pv.warnings | Where-Object { $_ -match 'is an alias: the alias floats' }).Count -eq 1 -and @(Turns $d).Count -eq 0 -and $auth.Count -eq 1 -and $ver.Count -eq 1) "$($d.First) | $($pv.preflight) | $($pv.reviewer.harness)"
    Check 'DRYRUN' 'the dry run''s text: "child env   : an allow list (auth subscription): ..." without ANTHROPIC_ names; "sandbox     : read-only (requested; claude --restricted --tools Read,Grep,Glob ..."; "denial retry: 1 attempt ..."; "max steps   : the claude CLI''s default (no --max-turns)"; the preview''s engine_run names switched_off and child_env_allowed' ($d.Out -match '(?m)^child env   : an allow list \(auth subscription\): .*CLAUDE_CONFIG_DIR' -and (Line $d.Out 'child env') -notmatch 'ANTHROPIC_[A-Z]' -and $d.Out -match '(?m)^sandbox     : read-only \(requested; claude --restricted --tools Read,Grep,Glob' -and $d.Out -match '(?m)^denial retry: 1 attempt' -and $d.Out -match "(?m)^max steps   : the claude CLI's default \(no --max-turns\)$" -and (@($pv.engine_run.switched_off) -join ',') -match 'instruction-files' -and @($pv.engine_run.child_env_allowed) -contains 'DISABLE_AUTOUPDATER') (Line $d.Out 'child env')
    $refused = [ordered]@{
        'workspace-write'   = @(($claudeArgs + @('-Sandbox', 'workspace-write')), '^codex-consult: -Sandbox workspace-write is refused for the claude engine: consultations are read-only there')
        'codex_config'      = @(($claudeArgs + @('-CodexConfig', 'a=b')), '^codex-consult: -CodexConfig does not apply to the claude engine')
        'output-schema'     = @(($claudeArgs + @('-SchemaTransport', 'output-schema')), '^codex-consult: -SchemaTransport output-schema is refused for the claude engine: it takes native or prompt-only')
        'a foreign model'   = @(@('-Engine', 'claude', '-Model', 'gpt-5.1'), "^codex-consult: the claude model 'gpt-5\.1' is not in the claude engine's model table")
        'no model'          = @(@('-Engine', 'claude'), '^codex-consult: the claude engine needs a model')
    }
    $bad = @()
    foreach ($n in $refused.Keys) { $x = Consult $r '' (@('-DryRun', '-Prompt', 'x') + $refused[$n][0]); if (-not ($x.Code -eq 1 -and $x.First -match $refused[$n][1])) { $bad += "$n -> $($x.First)" } }
    $m1 = Consult $r '' @('-DryRun', '-Prompt', 'x', '-Engine', 'claude', '-Model', 'claude-opus-5-5[1m]', '-MaxModelSteps', '7', '-NativeEffort', 'max')
    Check 'DRYRUN' "refused before anything starts: $(@($refused.Keys) -join ', '); an id with [1m] runs, -MaxModelSteps 7 -> --max-turns 7 (D8), -NativeEffort max -> --effort max, no alias warning" ($bad.Count -eq 0 -and $m1.Code -eq 0 -and $m1.Preview.command -match ' --model "?claude-opus-5-5\[1m\]"? --effort max ' -and $m1.Preview.command -match ' --max-turns 7 ' -and $m1.Preview.engine_run.max_model_steps -eq 7 -and @(Get-RealWarnings $m1.Preview.warnings | Where-Object { $_ -match 'alias' }).Count -eq 0) (($bad -join ' | ') + " | $($m1.First)")
    # (a command line cannot carry 1 MiB: the prompt grows through a role file, which the prompt inlines)
    [void][IO.Directory]::CreateDirectory((Join-Path $r '.collab\roles'))
    [IO.File]::WriteAllText((Join-Path $r '.collab\roles\big.md'), ('y ' * 560000), $u8)
    $bd = Consult $r '' (@('-DryRun') + $claudeArgs + @('-Prompt', 'x', '-Role', 'big'))
    $br = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-Role', 'big'))
    Check 'DRYRUN' 'D9: a prompt over 1 MiB - the dry run says "a real run is refused before launch - brief too large for this engine: ..."; the real run is refused before anything starts (no claude turn, no ledger entry)' ($bd.Code -eq 0 -and $bd.Out -match '(?m)^launch      : a real run is refused before launch - brief too large for this engine: the prompt is \d+ bytes, the claude engine takes at most 1048576 bytes on stdin' -and $br.Code -eq 1 -and $br.Out -match '(?m)^codex-consult: brief too large for this engine' -and @(Turns $br).Count -eq 0 -and @(Ledger $r).Count -eq 0) "$(Line $br.Out 'codex-consult:') | $(Line $bd.Out 'launch      :')"
}

# =============================================================== ENGINEEXE: the launcher chain
if (Want 'ENGINEEXE') {
    $r = New-Repo 'exe'
    $none = Consult $r '' (@('-DryRun') + $claudeArgs + @('-Prompt', 'x')) @{ CODEX_CONSULT_CLAUDE_EXE = '' }
    $copyDir = Join-Path $work 'launcher dir with spaces'
    [void][IO.Directory]::CreateDirectory($copyDir)
    Copy-Item -LiteralPath $fakeClaude -Destination (Join-Path $copyDir 'fake-claude.cmd') -Force
    Copy-Item -LiteralPath (Join-Path $sp 'fake-claude.ps1') -Destination (Join-Path $copyDir 'fake-claude.ps1') -Force
    $copy = Join-Path $copyDir 'fake-claude.cmd'
    $via = Consult $r '' (@('-DryRun') + $claudeArgs + @('-Prompt', 'x', '-EngineExe', $copy)) @{ CODEX_CONSULT_CLAUDE_EXE = '' }
    Check 'ENGINEEXE' 'no launcher anywhere -> the dry run''s preflight says a real run is refused ("claude CLI not found on PATH"); -EngineExe <a copy in a directory with spaces> is taken and named in the ledger preview (provider_config.launcher)' ($none.Code -eq 0 -and $none.Out -match 'unavailable \(claude CLI not found on PATH\) - a real run is refused' -and $via.Code -eq 0 -and $via.Preview.reviewer.provider_config.launcher -eq $copy) "$($none.First) | $($via.First)"
}

# =============================================================== RUN: one structured consultation end to end
if (Want 'RUN') {
    $r = New-Repo 'run'
    $marks = @{ ANTHROPIC_BASE_URL = 'http://127.0.0.1:9/'; ANTHROPIC_AUTH_TOKEN = 'fake-token-0815'; CLAUDE_CODE_USE_BEDROCK = '1'; CLAUDE_CODE_EFFORT_LEVEL = 'max'; CLAUDE_CODE_SKIP_PROMPT_HISTORY = '1'; CLAUDECODE = '1'; CLAUDE_CODE_ENTRYPOINT = 'cli'; CODEX_SESSION_ID = 'sess-29'; W29_OPERATOR_VAR = 'x'; ANTHROPIC_API_KEY = 'fake-key-0815' }
    $envR = @{ FAKE_CLAUDE_REPLY = $adviseF }
    foreach ($k in $marks.Keys) { $envR[$k] = $marks[$k] }
    $x = Consult $r '' ($claudeArgs + @('-Prompt', 'Check the %APPDATA% words', '-ReplyName', 'run')) $envR
    $e = Last-Entry $r
    $t = @(Turns $x)
    $t0 = $(if ($t.Count -gt 0) { $t[0] } else { $null })
    $minted = $(if ($t0) { ArgOf $t0 '--session-id' } else { '' })
    Check 'RUN' 'a structured run: usable, the finding ingested; thread = the minted --session-id the fake got, thread_source events; ledger reviewer {engine claude, harness claude-cli 2.1.285-fake, provider_config {credential_mechanism subscription, auth_method claude.ai, api_provider firstParty}}; usage {input 12 + 9000 + 3000 = 12012, cached 9000, output 480}; effort_mapping claude-v1, schema_transport native, no format retry; one turn (GUARD: logged)' ($x.Code -eq 0 -and $x.GuardOk -and $e.bridge_outcome -eq 'usable reply' -and @($e.finding_ids).Count -eq 1 -and $minted -match $uuidRe -and $e.thread -eq $minted -and $e.thread_source -eq 'events' -and $e.reviewer.engine -eq 'claude' -and $e.reviewer.harness -eq $fakeVersion -and $e.reviewer.provider_config.credential_mechanism -eq 'subscription' -and $e.reviewer.provider_config.auth_method -eq 'claude.ai' -and $e.reviewer.provider_config.api_provider -eq 'firstParty' -and $e.usage.input_tokens -eq 12012 -and $e.usage.cached_input_tokens -eq 9000 -and $e.usage.output_tokens -eq 480 -and $e.effort_mapping -eq 'claude-v1' -and $e.schema_transport -eq 'native' -and $null -eq $e.format_retry -and $t.Count -eq 1) "$($x.First) | $($e.bridge_outcome) | $($e.thread) vs $minted"
    Check 'RUN' 'ledger engine_run {turns 1, auth subscription, init_tools Glob Grep Read StructuredOutput, mcp_servers 0, permission_mode dontAsk, api_key_source none, model_resolved claude-sonnet-5-5, other_models [], permission_denials 0, rate_limit null, cost_usd, child_env_allowed (names, DISABLE_AUTOUPDATER among them, no ANTHROPIC_ / CLAUDE_CODE_ name), switched_off}; the key order of a codex entry' ($e.engine_run.turns -eq 1 -and $e.engine_run.auth -eq 'subscription' -and (@($e.engine_run.init_tools) -join ',') -eq 'Glob,Grep,Read,StructuredOutput' -and $e.engine_run.mcp_servers -eq 0 -and $e.engine_run.permission_mode -eq 'dontAsk' -and $e.engine_run.api_key_source -eq 'none' -and $e.engine_run.model_resolved -eq 'claude-sonnet-5-5' -and @($e.engine_run.other_models).Count -eq 0 -and $e.engine_run.permission_denials -eq 0 -and $null -eq $e.engine_run.rate_limit -and $e.engine_run.cost_usd -gt 0 -and @($e.engine_run.child_env_allowed) -contains 'DISABLE_AUTOUPDATER' -and @(@($e.engine_run.child_env_allowed) | Where-Object { $_ -match '^(ANTHROPIC|CLAUDE_CODE)_' }).Count -eq 0 -and @($e.engine_run.switched_off).Count -eq 11 -and ((($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match 'command,child_env_scrubbed,brief' -and (($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ',') -match 'usage,compactions,engine_run,wall_seconds')) ($e.engine_run | ConvertTo-Json -Compress -Depth 4).Substring(0, 200)
    # HYGIENE (R22, D2): what the child got
    $hy = $t0
    $absent = @('ANTHROPIC_BASE_URL', 'ANTHROPIC_AUTH_TOKEN', 'ANTHROPIC_API_KEY', 'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_EFFORT_LEVEL', 'CLAUDE_CODE_SKIP_PROMPT_HISTORY', 'CLAUDECODE', 'CLAUDE_CODE_ENTRYPOINT', 'CODEX_SESSION_ID', 'W29_OPERATOR_VAR', 'CODEX_CONSULT_TEST_MODE', 'CODEX_CONSULT_TEST_CHILD_ENV_PASS', 'CODEX_HOME')
    $leaked = @($absent | Where-Object { $hy -and (Has-Name $hy $_) })
    $authRec = @($x.Log | Where-Object { $_.kind -eq 'auth' }) | Select-Object -First 1
    $leakedAuth = @($absent | Where-Object { $authRec -and (Has-Name $authRec $_) })
    Check 'HYGIENE' 'D2/D3: the turn''s child and the `claude auth status` child got the ALLOW list - none of ANTHROPIC_BASE_URL, ANTHROPIC_AUTH_TOKEN, ANTHROPIC_API_KEY (auth subscription), CLAUDE_CODE_USE_BEDROCK, CLAUDE_CODE_EFFORT_LEVEL, CLAUDE_CODE_SKIP_PROMPT_HISTORY, the host markers, an operator variable, the test-mode variables, CODEX_HOME; CLAUDE_CONFIG_DIR and PATH passed; DISABLE_AUTOUPDATER=1; the ledger''s child_env_scrubbed names the host markers that were set' ($hy -and $leaked.Count -eq 0 -and $authRec -and $leakedAuth.Count -eq 0 -and (Has-Name $hy 'CLAUDE_CONFIG_DIR') -and (Has-Name $hy 'PATH') -and $hy.autoupdater -eq '1' -and (Has-Name $authRec 'CLAUDE_CONFIG_DIR') -and (@($e.child_env_scrubbed) -join ',') -eq 'CLAUDECODE,CLAUDE_CODE_ENTRYPOINT,CODEX_SESSION_ID') "leaked: $($leaked -join ',') | auth leaked: $($leakedAuth -join ',') | scrubbed $(@($e.child_env_scrubbed) -join ',')"
    Check 'HYGIENE' 'item 1/5: the prompt on stdin whole (length = prompt_chars, the last line the consultation id, %APPDATA% unexpanded, the claude tools line), never in argv; the schema TEXT arrived through the .cmd chain intact (it parses); the working directory is the repository root; the values of the removed variables appear nowhere in the collab directory or on the console' ($hy.stdin_len -eq [int]$e.prompt_chars -and ([string]$hy.stdin).EndsWith("Consultation id: $($e.consult_id)") -and ([string]$hy.stdin).Contains('Check the %APPDATA% words') -and ([string]$hy.stdin).Contains('Tools: you may read files of the repository (Read, Grep, Glob); no shell, web or write tool exists') -and @(@($hy.argv) | Where-Object { ([string]$_).Contains('%APPDATA%') }).Count -eq 0 -and $hy.schema_ok -eq $true -and ([IO.Path]::GetFullPath([string]$hy.cwd).TrimEnd('\')) -ieq ([IO.Path]::GetFullPath($r).TrimEnd('\')) -and -not $x.Out.Contains('fake-token-0815') -and -not $x.Out.Contains('fake-key-0815') -and @(Get-ChildItem -LiteralPath (Join-Path $r '.collab') -Recurse -File | Where-Object { (Text $_.FullName) -match 'fake-token-0815|fake-key-0815|fake-person@example|FAKE-ORG-NAME' }).Count -eq 0) "len $($hy.stdin_len)/$($e.prompt_chars) schema_ok $($hy.schema_ok) cwd $($hy.cwd)"
    $md = Text (Td $r $e.reply)
    Check 'RUN' 'handoffs NN-claudecode-run.{md,reply.json,events.jsonl}; the header "# Handoff NN - Claude (claude): run", "Engine turns: 1 (claude -p, auth subscription; model claude-sonnet-5-5; init tools Glob, Grep, Read, StructuredOutput; permission denials 0)", tokens reported' ($e.reply -match '^handoffs/\d\d-claudecode-run\.md$' -and (Test-Path (Td $r $e.events)) -and (ConvertFrom-Json (Text (Td $r $e.reply_json))).verdict -eq 'ADVISE' -and $md -match '(?m)^# Handoff \d\d - Claude \(claude\): run$' -and $md.Contains('Engine turns: 1 (claude -p, auth subscription; model claude-sonnet-5-5; init tools Glob, Grep, Read, StructuredOutput; permission denials 0).') -and -not $md.Contains('not reported by claude')) (($md -split "`n") | Where-Object { $_ -like 'Engine turns*' })
    # the coordinator rule on a real run (item 9)
    $co = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'co')) @{ FAKE_CLAUDE_REPLY = $advise; CODEX_CONSULT_COORDINATOR = 'anthropic :: claude-sonnet-5-5[1m]' }
    $eco = Last-Entry $r
    Check 'RUN' 'item 9: a Claude Code coordinator (CODEX_CONSULT_COORDINATOR "anthropic :: claude-sonnet-5-5[1m]") reviewed by the alias sonnet: ledger coordinator {anthropic, claude-sonnet-5-5}, warnings[] "coordinator: anthropic :: sonnet [claude] is the coordinator''s own model" - a warning, the run is usable' ($co.Code -eq 0 -and $eco.bridge_outcome -eq 'usable reply' -and $eco.coordinator.provider -eq 'anthropic' -and $eco.coordinator.model -eq 'claude-sonnet-5-5' -and @($eco.warnings | Where-Object { $_ -match "^coordinator: anthropic :: sonnet \[claude\] is the coordinator's own model" }).Count -eq 1) "$($co.First) | $(@(Get-RealWarnings $eco.warnings) -join ' / ')"
}

# =============================================================== BILLING: the credential the turn took (item 6)
if (Want 'BILLING') {
    $r = New-Repo 'billing'
    $rosterApi = Write-Roster 'api' '{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"sonnet","auth":"api-key"}]}'
    $a = Consult $r $rosterApi @('-Prompt', 'x', '-ReplyName', 'api') @{ FAKE_CLAUDE_REPLY = $advise; ANTHROPIC_API_KEY = 'fake-key-0815' }
    $ea = Last-Entry $r
    $ta = @(Turns $a) | Select-Object -First 1
    Check 'BILLING' 'auth api-key with ANTHROPIC_API_KEY set: the child gets ANTHROPIC_API_KEY (the name - never printed), init apiKeySource ANTHROPIC_API_KEY -> usable; provider_config.credential_mechanism api-key, engine_run.api_key_source ANTHROPIC_API_KEY; the value appears nowhere' ($a.Code -eq 0 -and $ea.bridge_outcome -eq 'usable reply' -and $ta -and (Has-Name $ta 'ANTHROPIC_API_KEY') -and $ea.reviewer.provider_config.credential_mechanism -eq 'api-key' -and $ea.engine_run.api_key_source -eq 'ANTHROPIC_API_KEY' -and -not $a.Out.Contains('fake-key-0815') -and @(Get-ChildItem -LiteralPath (Join-Path $r '.collab') -Recurse -File | Where-Object { (Text $_.FullName).Contains('fake-key-0815') }).Count -eq 0) "$($a.First) | $($ea.bridge_outcome)"
    $b = Consult $r $rosterApi @('-DryRun', '-Prompt', 'x', '-Provider', 'anthropic') @{ ANTHROPIC_API_KEY = '' }
    Check 'BILLING' 'auth api-key without ANTHROPIC_API_KEY: the preflight says a real run is refused ("ANTHROPIC_API_KEY is not set (roster auth api-key)") - although a usable api-key reply of this endpoint is in the ledger (the local check comes before the 60-minute short-circuit); no `claude auth status` either' ($b.Code -eq 0 -and $b.Out -match 'ANTHROPIC_API_KEY is not set \(roster auth api-key\)' -and $b.Out -match '(?m)^preflight   : unavailable' -and @($b.Log | Where-Object { $_.kind -eq 'auth' }).Count -eq 0) (Line $b.Out 'preflight')
    $c = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'sub-key')) @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_APIKEYSOURCE = 'ANTHROPIC_API_KEY' }
    $ec = Last-Entry $r
    Check 'BILLING' 'F09-1: auth subscription but the init names apiKeySource ANTHROPIC_API_KEY (the turn billed a key) -> FAILED, class auth, nothing ingested (evidence first)' ($c.Code -eq 1 -and $ec.bridge_outcome -match '^failed: the init event names apiKeySource ANTHROPIC_API_KEY, not none' -and $ec.provider_failure.class -eq 'auth' -and @($ec.finding_ids).Count -eq 0) $ec.bridge_outcome
}

# =============================================================== PREFLIGHT: `claude auth status` (item 6, D3)
if (Want 'PREFLIGHT') {
    $r = New-Repo 'pre'
    $states = [ordered]@{
        'out'     = @('out', '^unavailable: .*not signed in \(`claude auth status`: loggedIn false; run `claude auth login`\)|^missing: not signed in')
        'console' = @('console', 'signed in with authMethod console, not the claude\.ai subscription')
        'gateway' = @('gateway', 'apiProvider bedrock - routes other than Anthropic''s own API')
        'nojson'  = @('nojson', 'not checked - `claude auth status` printed no JSON object')
    }
    $bad = @()
    foreach ($n in $states.Keys) {
        $x = Consult $r '' (@('-DryRun') + $claudeArgs + @('-Prompt', 'x')) @{ FAKE_CLAUDE_AUTH_STATUS = $states[$n][0] }
        $y = Consult $r '' ($claudeArgs + @('-Prompt', 'x')) @{ FAKE_CLAUDE_AUTH_STATUS = $states[$n][0]; FAKE_CLAUDE_REPLY = $advise }
        if (-not ($x.Code -eq 0 -and ([string]$x.Preview.preflight) -match $states[$n][1] -and $y.Code -eq 1 -and @(Turns $y).Count -eq 0)) { $bad += "$n -> [$($x.Preview.preflight)] run $($y.Code) $($y.First)" }
    }
    $h = Consult $r '' (@('-DryRun') + $claudeArgs + @('-Prompt', 'x')) @{ FAKE_CLAUDE_AUTH_STATUS = 'hang'; CODEX_CONSULT_TEST_LOGIN_TIMEOUT = '2' }
    Check 'PREFLIGHT' "D3/F03-9: the JSON before the exit code - signed out (exit 1) -> out; another authMethod, another apiProvider -> out; no JSON -> not checked; each refuses the real run before a turn (none started); a hang -> not checked after the timeout: $(@($states.Keys) -join ', ')" ($bad.Count -eq 0 -and $h.Code -eq 0 -and $h.Preview.preflight -match 'did not finish within 2 s') (($bad -join ' | ') + " | $($h.Preview.preflight)")
    $skip = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-SkipPreflight', '-ReplyName', 'skip')) @{ FAKE_CLAUDE_AUTH_STATUS = 'out'; FAKE_CLAUDE_REPLY = $advise }
    Check 'PREFLIGHT' '-SkipPreflight: no `claude auth status` at all; the run goes on (the per-turn proof still applies) and provider_config.auth_method is null' ($skip.Code -eq 0 -and @($skip.Log | Where-Object { $_.kind -eq 'auth' }).Count -eq 0 -and $null -eq (Last-Entry $r).reviewer.provider_config.auth_method) $skip.First
    $inside = Join-Path $r 'cfg-inside'
    $pd = Consult $r '' ($claudeArgs + @('-Prompt', 'x')) @{ CLAUDE_CONFIG_DIR = $inside; FAKE_CLAUDE_REPLY = $advise }
    # (a repository of its own: the usable -SkipPreflight run above would let the next preflight
    # short-circuit on the ledger, and `claude auth status` - which reports the directory - would not run)
    $rj = New-Repo 'pre-projdir'
    $pj = Consult $rj '' ($claudeArgs + @('-Prompt', 'x')) @{ FAKE_CLAUDE_AUTH_STATUS = "projdir=$(Join-Path $rj 'projects')"; FAKE_CLAUDE_REPLY = $advise }
    Check 'PREFLIGHT' 'item 2: CLAUDE_CONFIG_DIR, or the projectsDirectory `claude auth status` reports, inside the repository under review -> the run is refused before a turn (the transcripts would change the tree)' ($pd.Code -eq 1 -and $pd.First -match '^codex-consult: the claude engine is refused: CLAUDE_CONFIG_DIR .* lies inside the repository under review' -and $pj.Code -eq 1 -and $pj.First -match 'projectsDirectory .* lies inside the repository under review' -and @(Turns $pd).Count -eq 0 -and @(Turns $pj).Count -eq 0) "$($pd.First) | $($pj.First)"
}

# =============================================================== FAIL + TOOLSET: the turn rules end to end
if (Want 'FAIL') {
    $r = New-Repo 'fail'
    $cases = [ordered]@{
        'not logged in'  = @(@{ FAKE_CLAUDE_IS_ERROR = 'Not logged in - Please run /login' }, '^failed: claude exit 1 - Not logged in - Please run /login$', 'auth')
        'usage limit'    = @(@{ FAKE_CLAUDE_RATE_LIMIT = 'rejected' }, '^failed: claude exit 1 - Claude AI usage limit reached\|\d+$', 'quota')
        'max turns'      = @(@{ FAKE_CLAUDE_SUBTYPE = 'error_max_turns'; FAKE_CLAUDE_EXIT = '0' }, '^failed: claude error_max_turns - max turns reached', 'capability')
        'session mismatch' = @(@{ FAKE_CLAUDE_SESSION = 'mismatch' }, '^failed: session id mismatch: init ', 'unknown')
        'not a uuid'     = @(@{ FAKE_CLAUDE_SESSION = 'notuuid' }, "^failed: the new session is session-1, not the minted ", 'unknown')
        'no result'      = @(@{ FAKE_CLAUDE_NORESULT = '1' }, '^failed: no result event in the claude event stream', 'unknown')
        'two results'    = @(@{ FAKE_CLAUDE_TWORESULTS = '1' }, '^failed: malformed event stream: 2 result events', 'transport')
        'a bad line'     = @(@{ FAKE_CLAUDE_BADLINE = '1' }, '^failed: malformed event stream: line \d+ is not a JSON object$', 'transport')
        'garbage'        = @(@{ FAKE_CLAUDE_TRAILING = '{"type":"assis' }, '^failed: malformed event stream: line \d+ is not a JSON object$', 'transport')
        'model drift'    = @(@{ FAKE_CLAUDE_INIT_MODEL = 'claude-opus-5-5' }, '^failed: model drift: asked sonnet, served claude-opus-5-5$', 'capability')
        'usage drift'    = @(@{ FAKE_CLAUDE_MODEL_USAGE = 'claude-sonnet-5-5=5,claude-opus-5-5=400' }, 'modelUsage names claude-opus-5-5 as the main model', 'capability')
        'no init'        = @(@{ FAKE_CLAUDE_NOINIT = '1' }, 'no init event - the turn''s tools, MCP servers and permission mode are not proven', 'permission')
    }
    $bad = @()
    $k = 0
    foreach ($name in $cases.Keys) {
        $k++
        $envK = @{ FAKE_CLAUDE_REPLY = $adviseF }
        foreach ($kk in $cases[$name][0].Keys) { $envK[$kk] = $cases[$name][0][$kk] }
        # (an auth or a quota failure marks the endpoint out for the next preflight of the same
        # repository: those cases run in a repository of their own)
        $rk = $(if ($cases[$name][2] -eq 'auth' -or $cases[$name][2] -eq 'quota') { New-Repo "fail-$k" } else { $r })
        $o = Consult $rk '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', "f$k")) $envK
        $e = Last-Entry $rk
        $ok = ($o.Code -eq 1 -and $o.GuardOk -and $e.bridge_outcome -match $cases[$name][1] -and $e.provider_failure.class -eq $cases[$name][2] -and @($e.finding_ids).Count -eq 0 -and $e.engine_run.turns -eq 1)
        if ($name -eq 'usage limit' -and -not $e.provider_failure.retry_after) { $ok = $false }
        if ($name -eq 'usage limit' -and -not ($e.engine_run.rate_limit -and $e.engine_run.rate_limit.status -eq 'rejected')) { $ok = $false }
        if ($name -eq 'model drift' -and -not ($e.thread -eq '' -and $e.thread_candidate -match $uuidRe)) { $ok = $false }
        if (-not $ok) { $bad += "$name -> code $($o.Code) [$($e.bridge_outcome)] class $($e.provider_failure.class)" }
    }
    Check 'FAIL' "every rule fails the run with its class, nothing ingested, one turn: $(@($cases.Keys) -join ', ') (the usage limit: retry_after from resetsAt, engine_run.rate_limit raw; drift: a candidate only)" ($bad.Count -eq 0) ($bad -join ' | ')
    $warn = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'rlw')) @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_RATE_LIMIT = 'warning' }
    $ew = Last-Entry $r
    Check 'FAIL' 'a rate_limit_event with a warning status beside a normal answer: usable, warnings[] "claude rate limit status allowed_warning (five_hour); resets at ...", engine_run.rate_limit recorded' ($warn.Code -eq 0 -and $ew.bridge_outcome -eq 'usable reply' -and @($ew.warnings | Where-Object { $_ -match '^claude rate limit status allowed_warning \(five_hour\); resets at ' }).Count -eq 1 -and $ew.engine_run.rate_limit.status -eq 'allowed_warning') (@(Get-RealWarnings $ew.warnings) -join ' / ')
}
if (Want 'TOOLSET') {
    $r = New-Repo 'toolset'
    $cases = [ordered]@{
        'Bash in the init'  = @(@{ FAKE_CLAUDE_INIT_TOOLS = 'Glob,Grep,Read,StructuredOutput,Bash' }, '^failed: the init event lists tools outside Read, Grep, Glob, StructuredOutput: Bash')
        'Write in the init' = @(@{ FAKE_CLAUDE_INIT_TOOLS = 'Read,Write' }, '^failed: the init event lists tools outside Read, Grep, Glob, StructuredOutput: Write')
        'an MCP server'     = @(@{ FAKE_CLAUDE_INIT_MCP = 'filesystem' }, '^failed: the init event lists MCP server\(s\) \(filesystem\)')
        'another mode'      = @(@{ FAKE_CLAUDE_INIT_MODE = 'acceptEdits' }, "^failed: the init event names the permission mode 'acceptEdits', not dontAsk")
    }
    $bad = @()
    $k = 0
    foreach ($name in $cases.Keys) {
        $k++
        $envK = @{ FAKE_CLAUDE_REPLY = $adviseF }
        foreach ($kk in $cases[$name][0].Keys) { $envK[$kk] = $cases[$name][0][$kk] }
        $o = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', "ts$k")) $envK
        $e = Last-Entry $r
        if (-not ($o.Code -eq 1 -and $e.bridge_outcome -match $cases[$name][1] -and $e.provider_failure.class -eq 'permission' -and @($e.finding_ids).Count -eq 0)) { $bad += "$name -> [$($e.bridge_outcome)] $($e.provider_failure.class)" }
    }
    Check 'TOOLSET' "item 4 (evidence first): an init event that does not prove the read-only capability fails the run with class permission though a usable reply came: $(@($cases.Keys) -join ', ')" ($bad.Count -eq 0) ($bad -join ' | ')
}

# =============================================================== TREE: the strict tree check (D1)
if (Want 'TREE') {
    $r = New-Repo 'tree'
    $x = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'w')) @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_WRITE = 'probe.txt' }
    $e = Last-Entry $r
    Check 'TREE' 'D1 (F02-1, F03-1): probe.txt appears during a claude run -> FAILED like agy (managed hooks still apply: the init proves the tools, not the absence of a writer) - "failed: the working tree changed during the run (by the reviewer or anyone else): 1 file: probe.txt - claude ran with --restricted and read tools only, but managed settings and their hooks still apply", class permission, tree_check {failed, [probe.txt]}, nothing ingested' ($x.Code -eq 1 -and $e.bridge_outcome -eq 'failed: the working tree changed during the run (by the reviewer or anyone else): 1 file: probe.txt - claude ran with --restricted and read tools only, but managed settings and their hooks still apply' -and $e.provider_failure.class -eq 'permission' -and $e.tree_check.outcome -eq 'failed' -and (@($e.tree_check.files) -join ',') -eq 'probe.txt' -and @($e.finding_ids).Count -eq 0) $e.bridge_outcome
}

# =============================================================== RESUME + FORK: the lineage (item 2, D4)
if (Want 'RESUME') {
    $r = New-Repo 'resume'
    $t0 = Uuid
    Seed-Task $r @((New-ClaudeEntry 1 $t0))
    $a = Consult $r $rosterClaude @('-Prompt', 'x', '-Mode', 'resume', '-ReplyName', 'res') @{ FAKE_CLAUDE_REPLY = $advise }
    $ea = Last-Entry $r
    $ta = @(Turns $a) | Select-Object -First 1
    Check 'RESUME' '-Mode resume: --resume <the newest thread of the lineage> and --model <the id the thread resolved> (the parent''s engine_run.model_resolved, never the floating alias); the same session comes back -> usable, parent = thread = t0' ($a.Code -eq 0 -and $ea.mode -eq 'resume' -and $ea.parent_thread -eq $t0 -and $ea.thread -eq $t0 -and $ea.bridge_outcome -eq 'usable reply' -and $ta -and (ArgOf $ta '--resume') -eq $t0 -and (ArgOf $ta '--model') -eq 'claude-sonnet-5-5' -and (ArgOf $ta '--session-id') -eq '' -and $ea.engine_run.model_resolved -eq 'claude-sonnet-5-5') "$($a.First) | --model $(if ($ta) { ArgOf $ta '--model' })"
    $b = Consult $r $rosterClaude @('-Prompt', 'x', '-Mode', 'resume', '-ReplyName', 'gone') @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_SESSION = 'other' }
    $eb = Last-Entry $r
    $nf = Consult $r $rosterClaude @('-Prompt', 'x', '-Mode', 'resume', '-ReplyName', 'nf') @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_SESSION = 'notfound' }
    $enf = Last-Entry $r
    Check 'RESUME' 'a resume that lands on ANOTHER session -> FAILED "parent session <p> not found, claude answered on <s>" (class unknown), thread "" and the new id a candidate only; an unknown session (exit 1, "No conversation found") -> failed, never a silent new thread' ($b.Code -eq 1 -and $eb.bridge_outcome -match "^failed: parent session $t0 not found, claude answered on [0-9a-f-]{36}$" -and $eb.provider_failure.class -eq 'unknown' -and $eb.thread -eq '' -and $eb.thread_candidate -match $uuidRe -and $nf.Code -eq 1 -and $enf.bridge_outcome -match '^failed: claude exit 1 - No conversation found with session ID' -and $enf.thread -eq '') "$($eb.bridge_outcome) | $($enf.bridge_outcome)"
    $f = Consult $r $rosterClaude @('-Prompt', 'x', '-Mode', 'fork', '-ReplyName', 'fork') @{ FAKE_CLAUDE_REPLY = $advise }
    $ef = Last-Entry $r
    $tf = @(Turns $f) | Select-Object -First 1
    Check 'FORK' '-Mode fork: --resume <t0> --fork-session (no --session-id: whether it pins a fork is open, Q5), --model the resolved id; the fork''s NEW uuid (not t0) is the thread, t0 the parent' ($f.Code -eq 0 -and $ef.mode -eq 'fork' -and $ef.parent_thread -eq $t0 -and $ef.thread -match $uuidRe -and $ef.thread -ne $t0 -and $tf -and (ArgOf $tf '--resume') -eq $t0 -and @($tf.argv) -contains '--fork-session' -and (ArgOf $tf '--model') -eq 'claude-sonnet-5-5') "$($f.First) | $($ef.thread)"
    $fp = Consult $r $rosterClaude @('-Prompt', 'x', '-Mode', 'fork', '-ReplyName', 'forkp') @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_SESSION = 'parent' }
    $efp = Last-Entry $r
    $th = Consult $r $rosterClaude @('-DryRun', '-Prompt', 'x', '-Thread', $t0)
    Check 'FORK' 'a fork that answers on its parent -> FAILED ("the fork came back on its parent session", class unknown); -Thread <a claude thread> fixes reviewer and engine (mode resume: "thread      : <t0> (session resumed with --resume)")' ($fp.Code -eq 1 -and $efp.bridge_outcome -match '^failed: the fork came back on its parent session' -and $efp.provider_failure.class -eq 'unknown' -and $th.Code -eq 0 -and $th.Preview.mode -eq 'resume' -and $th.Preview.reviewer.engine -eq 'claude' -and $th.Out -match "(?m)^thread      : $t0 \(session resumed with --resume\)$") "$($efp.bridge_outcome) | $(Line $th.Out 'thread ')"
}

# =============================================================== REPAIR + DENIAL: the secondary turns (item 3, D6)
if (Want 'REPAIR') {
    $r = New-Repo 'repair'
    $x = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'pr')) @{ FAKE_CLAUDE_REPLY = $proseFile; FAKE_CLAUDE_PROSE = '1'; FAKE_CLAUDE_RESUME_REPLY = $repairedFile }
    $e = Last-Entry $r
    $t = @(Turns $x)
    $rep = $(if ($t.Count -ge 2) { $t[1] } else { $null })
    Check 'REPAIR' 'prose first, JSON on the repair turn: structured, format_retry {succeeded, events NN-claudecode-pr.repair.events.jsonl}; the repair turn resumes THE session (--resume <thread>), sends the RESOLVED model (claude-sonnet-5-5, not the alias), effort low, the schema text (the main turn''s transport), its own prompt on stdin; engine_run.turns 2 (GUARD: both logged)' ($x.Code -eq 0 -and $x.GuardOk -and $e.structured -eq $true -and $e.format_retry.succeeded -eq $true -and $e.format_retry.events -match '^handoffs/\d\d-claudecode-pr\.repair\.events\.jsonl$' -and $e.engine_run.turns -eq 2 -and $rep -and (ArgOf $rep '--resume') -eq $e.thread -and (ArgOf $rep '--model') -eq 'claude-sonnet-5-5' -and (ArgOf $rep '--effort') -eq 'low' -and $rep.schema_ok -eq $true -and ([string]$rep.stdin).Contains('Your last message was prose, not the required JSON.')) "$($e.bridge_outcome) turns=$($e.engine_run.turns)"
    $d = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'den')) @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_DENIALS = 'empty' }
    $ed = Last-Entry $r
    $td = @(Turns $d)
    Check 'REPAIR' 'D6: a denied Read and NO reply (DeniedEmpty) -> one denial-retry turn on the session (--resume), which answers: usable, denial_retry {attempted, succeeded}, the warning "denial notice ...", engine_run {turns 2, permission_denials 1, denied_tools [Read]}' ($d.Code -eq 0 -and $d.GuardOk -and $ed.bridge_outcome -eq 'usable reply' -and $ed.denial_retry.attempted -eq $true -and $ed.denial_retry.succeeded -eq $true -and $td.Count -eq 2 -and (ArgOf $td[1] '--resume') -eq $ed.thread -and $ed.engine_run.turns -eq 2 -and $ed.engine_run.permission_denials -eq 1 -and (@($ed.engine_run.denied_tools) -join ',') -eq 'Read' -and @($ed.warnings | Where-Object { $_ -match '^denial notice' }).Count -eq 1) "$($ed.bridge_outcome) | $(@(Get-RealWarnings $ed.warnings) -join ' / ')"
    $d2 = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'den2')) @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_DENIALS = '1' }
    $ed2 = Last-Entry $r
    Check 'REPAIR' 'D6: a denial BESIDE a usable reply -> usable, one turn, the warning names the tool and the path ("permission denials beside the reply: 1 tool call(s) denied under --permission-mode dontAsk: Read C:\outside\secret.txt")' ($d2.Code -eq 0 -and $ed2.bridge_outcome -eq 'usable reply' -and $ed2.engine_run.turns -eq 1 -and $null -eq $ed2.denial_retry.attempted -and @($ed2.warnings | Where-Object { $_ -eq 'permission denials beside the reply: 1 tool call(s) denied under --permission-mode dontAsk: Read C:\outside\secret.txt' }).Count -eq 1) (@(Get-RealWarnings $ed2.warnings) -join ' / ')
}

# =============================================================== TIMEOUT + STALL: the killed turn and its continuation (item 7)
if (Want 'TIMEOUT') {
    $r = New-Repo 'timeout'
    $x = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'to', '-TimeoutSec', '8', '-ContinueSec', '60')) @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_HANG = 'new'; FAKE_CLAUDE_TEXT = '1' }
    $e = Last-Entry $r
    $t = @(Turns $x)
    $minted = $(if ($t.Count -gt 0) { ArgOf $t[0] '--session-id' } else { '' })
    Check 'TIMEOUT' 'the main turn hangs and is killed at 8 s; the continuation resumes the MINTED session (--resume <the uuid of --session-id>, known before the first byte) with the model the killed turn''s init resolved -> "usable reply (after a timeout continuation)", timeout_continue.thread = the minted id, thread = it, two turns logged' ($x.Code -eq 0 -and $x.GuardOk -and $e.bridge_outcome -eq 'usable reply (after a timeout continuation)' -and $minted -match $uuidRe -and $e.timeout_continue.thread -eq $minted -and $e.thread -eq $minted -and $t.Count -eq 2 -and (ArgOf $t[1] '--resume') -eq $minted -and (ArgOf $t[1] '--model') -eq 'claude-sonnet-5-5') "$($e.bridge_outcome) | $($e.timeout_continue.outcome)"
    $y = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'to2', '-TimeoutSec', '6', '-ContinueSec', '0')) @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_HANG = '1'; FAKE_CLAUDE_TEXT = '1' }
    $ey = Last-Entry $r
    $part = Text (Td $r ([string]$ey.partial_reply))
    Check 'TIMEOUT' 'no continuation (-ContinueSec 0): "failed: timeout after 6 s (process tree killed)", the salvage .partial.md holds the thinking, the text and "Read: app.txt"; the minted id a candidate' ($y.Code -eq 1 -and $ey.bridge_outcome -match '^failed: timeout after 6 s \(process tree killed' -and $ey.partial_reply -match '\.partial\.md$' -and $part.Contains('Planning the review (first turn).') -and $part.Contains('Reading the brief (first turn).') -and $part.Contains('Read: app.txt') -and $ey.thread_candidate -match $uuidRe) $ey.bridge_outcome
}
if (Want 'STALL') {
    $r = New-Repo 'stall'
    $x = Consult $r '' ($claudeArgs + @('-Prompt', 'x', '-ReplyName', 'st', '-TimeoutSec', '40', '-StallSec', '3', '-ContinueSec', '0')) @{ FAKE_CLAUDE_REPLY = $adviseF; FAKE_CLAUDE_TOOL_OPEN = '1'; FAKE_CLAUDE_HANG = '1'; CODEX_CONSULT_TEST_TOOL_CAP_SEC = '5' }
    $e = Last-Entry $r
    Check 'STALL' 'a tool_use without its tool_result suspends the stall timer; once the stream stops growing past the cap the cut names the open call ("claude Grep toolu_open") - "failed: stalled after 3 s without an event - no output for ... (a tool call open for ... s: claude Grep toolu_open)"' ($x.Code -eq 1 -and $e.bridge_outcome -match '^failed: stalled after 3 s without an event - no output for [\d.,]+ s \(a tool call open for [\d.,]+ s: claude Grep toolu_open\)' -and $e.stall.seconds -eq 3) $e.bridge_outcome
}

# =============================================================== PANEL: claude members one at a time (D5)
if (Want 'PANEL') {
    $r = New-Repo 'panel'
    $roster3 = Write-Roster 'panel3' '{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"sonnet"},{"provider":"anthropic-deep","engine":"claude","model":"opus"},{"provider":"openai","model":"gpt-5.1"}]}'
    $pd = Consult $r $roster3 @('-Panel', '-PanelSize', '3', '-DryRun', '-Prompt', 'x')
    $roster3p = Write-Roster 'panel3p' '{"roster_version":1,"reviewers":[{"provider":"anthropic","engine":"claude","model":"sonnet"},{"provider":"anthropic-deep","engine":"claude","model":"opus"},{"provider":"openai","model":"gpt-5.1"}],"parallel":{"anthropic":2,"anthropic-deep":2}}'
    $pp = Consult $r $roster3p @('-Panel', '-PanelSize', '3', '-DryRun', '-Prompt', 'x')
    Check 'PANEL' 'D5: a panel of two claude members (two labels, two families) and a codex member plans "at most 2 at a time" (the claude members one after another); "parallel" 2 on both claude labels -> "at once"' ($pd.Code -eq 0 -and $pd.Out -match 'at most 2 at a time' -and $pp.Code -eq 0 -and $pp.Out -match '(?m)^Concurrency: at once') "$(Line $pd.Out 'Concurrency') | $(Line $pp.Out 'Concurrency')"
    $p = Consult $r $roster3 @('-Panel', '-PanelSize', '3', '-Prompt', 'x', '-Purpose', 'framing', '-ReplyName', 'px') @{ FAKE_CODEX_REPLY = $advise; FAKE_CLAUDE_REPLY = $advise }
    $led = @(Ledger $r)
    $cl = @($led | Where-Object { $_.reviewer.engine -eq 'claude' })
    Check 'PANEL' 'a real panel: both claude members and the codex member usable; the claude members'' replies handoffs/NN-claudecode-px-*.md, each on its own minted session, each with its resolved model (claude-sonnet-5-5, claude-opus-5-5); GUARD: every claude turn logged' ($p.Code -eq 0 -and $p.GuardOk -and $led.Count -eq 3 -and @($led | Where-Object { $_.bridge_outcome -ne 'usable reply' }).Count -eq 0 -and $cl.Count -eq 2 -and @($cl | Where-Object { $_.reply -notmatch '^handoffs/\d\d-claudecode-px-' }).Count -eq 0 -and $cl[0].thread -ne $cl[1].thread -and (@($cl | ForEach-Object { $_.engine_run.model_resolved } | Sort-Object) -join ',') -eq 'claude-opus-5-5,claude-sonnet-5-5') "$($p.First) | $(@($led | ForEach-Object { $_.bridge_outcome }) -join ' / ')"
}

# =============================================================== LISTING: codex-providers.ps1
if (Want 'LISTING') {
    $r = New-Repo 'listing'
    $j = Providers $r $rosterClaudeCodex @('-Json')
    $m = @($j.Json | Where-Object { $_.name -eq 'anthropic' })[0]
    Check 'LISTING' 'JSON: the claude row - engine claude, kind "engine claude", endpoint "claude (<launcher>)", credentials "ok: signed in (claude.ai subscription)" (`claude auth status` in the child environment: logged), effort vocabulary claude, any model, transport native, roster_selected, available' ($j.Code -eq 0 -and $m.engine -eq 'claude' -and $m.kind -eq 'engine claude' -and $m.endpoint -eq "claude ($fakeClaude)" -and $m.credentials -eq 'ok: signed in (claude.ai subscription)' -and $m.effort_vocabulary -eq 'claude' -and $m.schema_transport -eq 'native' -and $m.roster_selected -eq $true -and $m.verdict -eq 'available' -and @($j.Log | Where-Object { $_.kind -eq 'auth' }).Count -eq 1 -and -not $j.Out.Contains($fakeEmail)) "$($m.credentials) | $($m.verdict)"
    $nn = Providers $r $rosterClaudeCodex @('-Json', '-NoNetwork')
    $m2 = @($nn.Json | Where-Object { $_.name -eq 'anthropic' })[0]
    Check 'LISTING' '-NoNetwork (the SessionStart hook): `claude auth status` is not started (not a local file read) - "not checked"; nothing logged' ($nn.Code -eq 0 -and ([string]$m2.credentials) -match 'not checked' -and @($nn.Log).Count -eq 0) "$($m2.credentials) | $($m2.verdict)"
    $out = Providers $r $rosterClaudeCodex @('-Json') @{ FAKE_CLAUDE_AUTH_STATUS = 'out' }
    $m3 = @($out.Json | Where-Object { $_.name -eq 'anthropic' })[0]
    Check 'LISTING' 'signed out: the claude row "unavailable (not signed in ...)"; the roster walk selects openai' ($out.Code -eq 0 -and ([string]$m3.verdict) -match '^unavailable \(not signed in' -and $m3.roster_selected -eq $false) $m3.verdict
}

# =============================================================== ENDPOINT: auth endpoint (wave 29b, E1-E7 of handoff 12)
# A claude entry against a third-party Anthropic-compatible endpoint: the roster shapes (E1), the
# open model id and its proof by equality (E2), the local preflight without `claude auth status`
# (E3), the child environment (E4), the route and plan identities (E5), telemetry and the lab by host
# (E6), the plan's scheduling group (E7). The base URLs are real-shaped but nothing is ever sent:
# the fake CLI answers; the token is a made-up value in a made-up variable.
if (Want 'ENDPOINT') {
    $epVar = 'W29B_FAKE_ZAI_TOKEN'
    $epToken = 'fake-token-w29b-0001'
    $epUrl = 'https://api.z.ai/api/anthropic'
    $epCanon = "cc-engine-v1|claude|endpoint|$epUrl|$epVar"
    $epFp = Get-Sha256Hex ($u8.GetBytes($epCanon))
    $epEntry = '{"provider":"ZAI-claude","engine":"claude","model":"glm-5.3","auth":"endpoint","endpoint":{"base_url":"' + $epUrl + '","env_key":"' + $epVar + '","timeout_ms":3000000},"plan":"zai"}'
    $epEntryNoPlan = '{"provider":"ZAI-claude","engine":"claude","model":"glm-5.3","auth":"endpoint","endpoint":{"base_url":"' + $epUrl + '","env_key":"' + $epVar + '"}}'
    $zaiEntry = '{"provider":"ZAI","model":"glm-5.3","plan":"zai"}'
    $zaiEntryNoPlan = '{"provider":"ZAI","model":"glm-5.3"}'
    $oaiEntry = '{"provider":"openai","model":"gpt-5.1"}'
    $rosterOf = { param([string[]]$Items, [string]$Tail = '') '{"roster_version":1,"reviewers":[' + ($Items -join ',') + ']' + $Tail + '}' }
    # a Codex home of its own: the ZAI table - the codex route to the same plan, the same token variable
    $epHome = Join-Path $work 'codexhome-endpoint'
    [void][IO.Directory]::CreateDirectory($epHome)
    [IO.File]::WriteAllText((Join-Path $epHome 'config.toml'), "model = `"gpt-5.1`"`n[model_providers.ZAI]`nname = `"Z.ai GLM Coding Plan`"`nbase_url = `"https://api.z.ai/api/coding/paas/v4`"`nenv_key = `"$epVar`"`nwire_api = `"responses`"`n", $u8)
    $savedCodexHome = $codexHome
    $codexHome = $epHome
    try {
        $cfgEp = Read-CodexConfigSubset -Path (Join-Path $epHome 'config.toml')
        $zaiFp = (Resolve-ReviewerIdentity -Config $cfgEp -Provider 'ZAI' -Model 'glm-5.3').Fingerprint
        $mkEp = { param([string]$Url, [string]$Key, [string]$Plan = 'zai') (ConvertFrom-ClaudeEndpointValue -Value ([pscustomobject]@{ base_url = $Url; env_key = $Key }) -Plan $Plan).Endpoint }
        $row = { param($J, [string]$Name) @(@($J) | Where-Object { $_.name -ceq $Name })[0] }
        $isoOf = { param($D) ([DateTimeOffset]$D).ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture) }
        $nowE = [DateTimeOffset]::UtcNow
        # a ledger entry of a recorded outcome on an endpoint (fingerprint): a failure of $Class, or a usable reply
        $seedE = { param([int]$N, [string]$Prov, [string]$Eng, [string]$Fp, [string]$Class, [string]$Msg, $Retry, [int]$AgoMin = 5)
            $w = & $isoOf $nowE.AddMinutes(-$AgoMin)
            $o = [pscustomobject]@{ n = $N; when = $w; finished_at = $w; purpose = ''; reviewer = [pscustomobject]@{ provider = $Prov; model = 'glm-5.3'; engine = $Eng; provider_fingerprint = $Fp }; lineage = "$Prov :: glm-5.3"; thread = ''; mode = 'new'; reply = ''; bridge_outcome = 'usable reply'; provider_failure = $null }
            if ($Class) {
                $o.bridge_outcome = "failed: $Msg"
                $o.provider_failure = [pscustomobject]@{ class = $Class; kind = ''; code = $(if ($Class -eq 'quota') { '429' } else { '401' }); message = $Msg; when = $w; retry_after = $(if ($Retry) { & $isoOf $Retry } else { $null }); hint = '' }
            }
            $o
        }
        function EvE { param([string]$Name, [string[]]$Lines) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, (($Lines -join "`n") + "`n"), $u8); return $p }

        # ---- E1: the roster shapes
        $rpE = Join-Path $work 'roster-endpoint-unit.json'
        $rdE = { param([string]$Json) [IO.File]::WriteAllText($rpE, $Json, $u8); Read-ReviewerRoster -Location ([pscustomobject]@{ Path = $rpE; FromEnv = $true; Disabled = $false }) }
        # (Windows PowerShell 5.1 reads JSON keys case-insensitively: a "parallel" key "zai" beside "ZAI" does not parse there)
        $okE = & $rdE (& $rosterOf @($epEntry, $zaiEntry, '{"provider":"MIMO-claude","engine":"claude","model":"mimo-v2.6-pro[1m]","auth":"endpoint","endpoint":{"base_url":"https://token-plan-ams.xiaomimimo.com/anthropic","env_key":"W29B_FAKE_MIMO_TOKEN"}}', '{"provider":"anthropic","engine":"claude","model":"sonnet","plan":"claude-max"}') ',"parallel":{"zai":2,"anthropic":1}')
        $e0 = $okE.Entries[0]; $e2 = $okE.Entries[2]
        Check 'ENDPOINT' 'E1: a roster with auth endpoint is read - endpoint {base_url (as written; canonical form beside it), env_key (the NAME), timeout_ms 3000000}, plan zai; timeout_ms omitted -> 3000000; a provider id with [1m] outside the claude table (mimo-v2.6-pro[1m]); plan on a codex entry and on a subscription entry; "parallel" keys naming a plan (zai) and a label (anthropic)' (-not $okE.Error -and $e0.Auth -eq 'endpoint' -and $e0.Endpoint.BaseUrl -eq $epUrl -and $e0.Endpoint.Canonical -eq $epUrl -and $e0.Endpoint.EnvKey -eq $epVar -and $e0.Endpoint.TimeoutMs -eq 3000000 -and $e0.Plan -eq 'zai' -and $okE.Entries[1].Plan -eq 'zai' -and $okE.Entries[1].Engine -eq 'codex' -and $null -eq $okE.Entries[1].Endpoint -and $e2.Model -eq 'mimo-v2.6-pro[1m]' -and $e2.Endpoint.TimeoutMs -eq 3000000 -and $e2.Plan -eq '' -and $okE.Entries[3].Auth -eq 'subscription' -and $okE.Entries[3].Plan -eq 'claude-max' -and $null -eq $okE.Entries[3].Endpoint -and $okE.Parallel['zai'] -eq 2 -and $okE.Parallel['anthropic'] -eq 1) $okE.Error
        $one = { param([string]$Item) & $rosterOf @($Item) }
        $epWith = { param([string]$Ep, [string]$Model = 'glm-5.3') '{"provider":"x","engine":"claude","model":"' + $Model + '","auth":"endpoint","endpoint":' + $Ep + '}' }
        $urlWhy = 'entry 1: endpoint.base_url must be an absolute https URL without credentials, query or fragment (e.g. "https://api.z.ai/api/anthropic"; the value is not shown)'
        $keyWhy = 'entry 1: endpoint.env_key must be the NAME of the environment variable that holds the token (capital letters, digits and _, at least 3 characters, starting with a letter - e.g. "ZAI_API_KEY"), never the token itself (the value is not shown)'
        $refuseE = [ordered]@{
            'no endpoint'             = @((& $one '{"provider":"x","engine":"claude","model":"glm-5.3","auth":"endpoint"}'), 'entry 1: auth "endpoint" needs an "endpoint" object {"base_url": "https://...", "env_key": "<VARIABLE NAME>"} - the Anthropic-compatible endpoint and the variable that holds its token')
            'endpoint, subscription'  = @((& $one '{"provider":"x","engine":"claude","model":"sonnet","endpoint":{"base_url":"https://a.example/v","env_key":"ABC"}}'), 'entry 1: endpoint applies only to engine claude with auth "endpoint" (this entry: engine claude, auth subscription)')
            'endpoint, api-key'       = @((& $one '{"provider":"x","engine":"claude","model":"sonnet","auth":"api-key","endpoint":{"base_url":"https://a.example/v","env_key":"ABC"}}'), 'entry 1: endpoint applies only to engine claude with auth "endpoint" (this entry: engine claude, auth api-key)')
            'endpoint on codex'       = @((& $one '{"provider":"x","model":"gpt-5.1","endpoint":{"base_url":"https://a.example/v","env_key":"ABC"}}'), 'entry 1: endpoint applies only to engine claude with auth "endpoint" (this entry: engine codex)')
            'endpoint not an object'  = @((& $one (& $epWith '"https://api.z.ai/api/anthropic"')), 'entry 1: endpoint must be an object {"base_url": "https://...", "env_key": "<VARIABLE NAME>", "timeout_ms": <milliseconds, optional>}')
            'an unknown endpoint key' = @((& $one (& $epWith '{"base_url":"https://a.example/v","env_key":"ABC","model":"x"}')), "entry 1: endpoint has an unknown key 'model' (allowed: base_url, env_key, timeout_ms)")
            'http'                    = @((& $one (& $epWith '{"base_url":"http://api.z.ai/api/anthropic","env_key":"ABC"}')), $urlWhy)
            'credentials in the URL'  = @((& $one (& $epWith '{"base_url":"https://user:W29BSECRETPW@api.z.ai/api/anthropic","env_key":"ABC"}')), $urlWhy)
            'a query'                 = @((& $one (& $epWith '{"base_url":"https://api.z.ai/api/anthropic?key=W29BSECRETPW","env_key":"ABC"}')), $urlWhy)
            'a relative URL'          = @((& $one (& $epWith '{"base_url":"/api/anthropic","env_key":"ABC"}')), $urlWhy)
            'a token as env_key'      = @((& $one (& $epWith '{"base_url":"https://a.example/v","env_key":"sk-W29BSECRETPW"}')), $keyWhy)
            'no env_key'              = @((& $one (& $epWith '{"base_url":"https://a.example/v"}')), $keyWhy)
            'timeout_ms 5'            = @((& $one (& $epWith '{"base_url":"https://a.example/v","env_key":"ABC","timeout_ms":5}')), 'entry 1: endpoint.timeout_ms must be an integer from 60000 to 7200000 (milliseconds - API_TIMEOUT_MS; default 3000000; got 5)')
            'timeout_ms 7200001'      = @((& $one (& $epWith '{"base_url":"https://a.example/v","env_key":"ABC","timeout_ms":7200001}')), 'got 7200001)')
            'a model with a blank'    = @((& $one (& $epWith '{"base_url":"https://a.example/v","env_key":"ABC"}' 'glm 5.3')), "entry 1: the claude model 'glm 5.3' is not a model id the endpoint route takes (the id as the provider publishes it: letters, digits, ""."", ""_"", ""-"", at most 64 characters, optionally ending with [1m])")
            'plan in upper case'      = @((& $one '{"provider":"x","model":"gpt-5.1","plan":"Zai"}'), 'entry 1: plan must be a slug of 2 to 32 characters - lowercase letters, digits and "-", starting with a letter (e.g. "zai"; got "Zai")')
            'plan not a string'       = @((& $one '{"provider":"x","model":"gpt-5.1","plan":3}'), 'entry 1: plan must be a slug of 2 to 32 characters')
            'parallel names nothing'  = @((& $rosterOf @($epEntry) ',"parallel":{"nope":2}'), "parallel names the provider label 'nope', which no entry of the roster uses (as its provider label or its plan)")
            'one label, two engines'  = @((& $rosterOf @($zaiEntry, ($epEntry -replace '"ZAI-claude"', '"ZAI"'))), "entries 1 and 2 use the provider label 'ZAI' with two engines (codex, claude); a label names one engine")
            'subscription keeps the table' = @((& $one '{"provider":"x","engine":"claude","model":"glm-5.3"}'), "entry 1: the claude model 'glm-5.3' is not in the claude engine's model table")
            'an unknown auth'         = @((& $one '{"provider":"x","engine":"claude","model":"glm-5.3","auth":"gateway"}'), 'entry 1: auth of engine claude must be "subscription" (the claude.ai login, the default) or "api-key" (ANTHROPIC_API_KEY) or "endpoint" (a third-party Anthropic-compatible endpoint named by the entry''s "endpoint")')
        }
        $badE = @()
        foreach ($n in $refuseE.Keys) { $rr = & $rdE $refuseE[$n][0]; if (-not ($rr.Error -and $rr.Error.Contains($refuseE[$n][1]) -and -not $rr.Error.Contains('W29BSECRETPW'))) { $badE += "$n -> $($rr.Error)" } }
        Check 'ENDPOINT' "E1: refused - the whole roster, fail-closed - with their texts: $(@($refuseE.Keys) -join ', '); a URL or env_key value is never echoed" ($badE.Count -eq 0) ($badE -join ' | ')

        # ---- E5: the route identity and its health key
        $iEp = Resolve-ReviewerIdentity -Config $cfgEp -Provider 'ZAI-claude' -Model 'glm-5.3' -Engine 'claude' -Launcher 'C:\fake\claude.exe' -Auth 'endpoint' -Endpoint (& $mkEp $epUrl $epVar)
        $iEpCase = Resolve-ReviewerIdentity -Config $cfgEp -Provider 'other-label' -Model 'glm-5.3[1m]' -Engine 'claude' -Auth 'endpoint' -Endpoint (& $mkEp 'https://API.Z.AI/api/anthropic/' $epVar 'another-plan')
        $iEpKey = Resolve-ReviewerIdentity -Config $cfgEp -Provider 'ZAI-claude' -Model 'glm-5.3' -Engine 'claude' -Auth 'endpoint' -Endpoint (& $mkEp $epUrl 'W29B_OTHER_TOKEN')
        $iEpPath = Resolve-ReviewerIdentity -Config $cfgEp -Provider 'ZAI-claude' -Model 'glm-5.3' -Engine 'claude' -Auth 'endpoint' -Endpoint (& $mkEp 'https://api.z.ai/api/Anthropic' $epVar)
        $iNoEp = Resolve-ReviewerIdentity -Config $cfgEp -Provider 'x' -Model 'glm-5.3' -Engine 'claude' -Auth 'endpoint'
        $pcKeys = @($iEp.ProviderConfig.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
        Check 'ENDPOINT' 'E5: the ROUTE identity - CompatString cc-engine-v1|claude|endpoint|<canonical base_url>|<env_key>, the fingerprint its SHA-256; lower-case scheme and host and a trailing slash are the same route, the label, the model, [1m] and the plan are no part of it; another env_key or another path is another route; provider_config keys exactly engine, launcher, credential_mechanism endpoint, base_url (as written), env_key (the NAME), plan zai - no auth_method; the Display names the base URL; auth endpoint without an endpoint is an identity error' ($iEp.CompatString -eq $epCanon -and $iEp.Fingerprint -eq $epFp -and $iEpCase.Fingerprint -eq $epFp -and $iEpKey.Fingerprint -ne $epFp -and $iEpPath.Fingerprint -ne $epFp -and $pcKeys -eq 'engine,launcher,credential_mechanism,base_url,env_key,plan' -and $iEp.ProviderConfig.credential_mechanism -eq 'endpoint' -and $iEp.ProviderConfig.base_url -eq $epUrl -and $iEp.ProviderConfig.env_key -eq $epVar -and $iEp.ProviderConfig.plan -eq 'zai' -and $iEp.Display -match 'endpoint https://api\.z\.ai/api/anthropic \(token from env W29B_FAKE_ZAI_TOKEN\)' -and $iNoEp.Error -match "auth endpoint is not usable: auth endpoint names no endpoint") "$($iEp.CompatString) | $pcKeys | $($iNoEp.Error)"
        $hRoute = Get-EndpointHealth -Consults @((& $seedE 1 'ZAI-claude' 'claude' $epFp 'quota' 'usage limit reached' $nowE.AddHours(3))) -Fingerprint $epFp -NoMachine
        $hOther = Get-EndpointHealth -Consults @((& $seedE 1 'ZAI-claude' 'claude' $epFp 'quota' 'usage limit reached' $nowE.AddHours(3))) -Fingerprint $iEpKey.Fingerprint -NoMachine
        Check 'ENDPOINT' 'E5: the health of an endpoint entry is keyed by its route (the fingerprint) - a usage limit recorded on the route marks it, another route of the same host (another env_key) stays clear' ([bool]$hRoute.Quota -and $hRoute.QuotaKnown -and -not $hOther.Quota) ''

        # ---- E4: the child environment, in-process
        Set-CaseEnv '' @{ $epVar = $epToken; ANTHROPIC_API_KEY = 'fake-key-0815'; ANTHROPIC_BASE_URL = 'http://127.0.0.1:9/'; ANTHROPIC_AUTH_TOKEN = 'fake-parent-token'; ANTHROPIC_MODEL = 'opus'; ANTHROPIC_DEFAULT_SONNET_MODEL = 'glm-5.3[1m]'; ANTHROPIC_SMALL_FAST_MODEL = 'x'; API_TIMEOUT_MS = '1'; CLAUDE_CODE_EFFORT_LEVEL = 'max' } ''
        $ceE = Get-ClaudeChildEnvironment -Auth 'endpoint' -Endpoint $e0.Endpoint
        Remove-Item "env:$epVar" -ErrorAction SilentlyContinue
        $ceN = Get-ClaudeChildEnvironment -Auth 'endpoint' -Endpoint $e0.Endpoint
        $ceX = Get-ClaudeChildEnvironment -Auth 'endpoint'
        Restore-Env
        $prefixed = @($ceE.Names | Where-Object { $_ -like 'ANTHROPIC_*' -or $_ -like 'API_*' -or $_ -like 'CLAUDE*' }) -join ','
        Check 'ENDPOINT' 'E4: the child environment of auth endpoint - of the ANTHROPIC_/API_/CLAUDE prefixes exactly ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, API_TIMEOUT_MS, CLAUDE_CONFIG_DIR: the base URL from the roster (not the parent''s), the token from the variable env_key names (not the parent''s ANTHROPIC_AUTH_TOKEN), API_TIMEOUT_MS 3000000 (not the parent''s 1); ANTHROPIC_API_KEY, ANTHROPIC_MODEL, ANTHROPIC_DEFAULT_SONNET_MODEL, ANTHROPIC_SMALL_FAST_MODEL, CLAUDE_CODE_EFFORT_LEVEL and the token variable itself absent; without the token variable or without an endpoint: Problem set and no ANTHROPIC_AUTH_TOKEN (the launch is refused)' ($prefixed -eq 'ANTHROPIC_AUTH_TOKEN,ANTHROPIC_BASE_URL,API_TIMEOUT_MS,CLAUDE_CONFIG_DIR' -and $ceE.Env['ANTHROPIC_BASE_URL'] -eq $epUrl -and $ceE.Env['ANTHROPIC_AUTH_TOKEN'] -eq $epToken -and $ceE.Env['API_TIMEOUT_MS'] -eq '3000000' -and -not (@($ceE.Names) -contains $epVar) -and -not $ceE.Problem -and $ceN.Problem -eq "env $epVar not set (the token of auth endpoint)" -and -not (@($ceN.Names) -contains 'ANTHROPIC_AUTH_TOKEN') -and $ceX.Problem -match 'names no endpoint' -and -not $ceX.Env.ContainsKey('ANTHROPIC_BASE_URL')) $prefixed

        # ---- E2, E3, E4: the turn rules of the route, in-process
        $uE = Uuid
        $initE = '{"type":"system","subtype":"init","cwd":"C:\\r","session_id":"' + $uE + '","tools":["Glob","Grep","Read","StructuredOutput"],"mcp_servers":[],"model":"glm-5.3","permissionMode":"dontAsk","apiKeySource":"none"}'
        $resE = '{"type":"result","subtype":"success","is_error":false,"num_turns":2,"result":"done","session_id":"' + $uE + '","usage":{"input_tokens":10,"output_tokens":5},"modelUsage":{"glm-5.3":{"outputTokens":5}},"permission_denials":[],"structured_output":{"schema_version":"1"}}'
        $errRes = { param([string]$Text) '{"type":"result","subtype":"success","is_error":true,"num_turns":1,"result":' + (ConvertTo-Json -InputObject $Text -Compress) + ',"session_id":"' + $uE + '","permission_denials":[]}' }
        $tEp = New-EngineTurnOptions -Model 'glm-5.3[1m]' -NewThread $uE -Auth 'endpoint'
        $oOk = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (EvE 'ep-ok.jsonl' @($initE, $resE))) -ExitCode 0 -StderrText '[claude-code:unrecognized_model] {"model":"glm-5.3"}' -Turn $tEp
        $oKey = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (EvE 'ep-key.jsonl' @(($initE -replace '"apiKeySource":"none"', '"apiKeySource":"ANTHROPIC_API_KEY"'), $resE))) -ExitCode 0 -Turn $tEp
        $oDrift = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (EvE 'ep-drift.jsonl' @(($initE -replace '"model":"glm-5.3"', '"model":"claude-sonnet-5-5"'), ($resE -replace 'glm-5\.3', 'claude-sonnet-5-5')))) -ExitCode 0 -Turn $tEp
        $sonInit = ($initE -replace '"model":"glm-5.3"', '"model":"claude-sonnet-5-5"')
        $sonRes = ($resE -replace 'glm-5\.3', 'claude-sonnet-5-5')
        $oAliasEp = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (EvE 'ep-alias.jsonl' @($sonInit, $sonRes))) -ExitCode 0 -Turn (New-EngineTurnOptions -Model 'sonnet' -NewThread $uE -Auth 'endpoint')
        $oAliasSub = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (EvE 'ep-alias2.jsonl' @($sonInit, $sonRes))) -ExitCode 0 -Turn (New-EngineTurnOptions -Model 'sonnet' -NewThread $uE -Auth 'subscription')
        $o401 = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (EvE 'ep-401.jsonl' @($initE, (& $errRes 'Failed to authenticate. API Error: 401 {"type":"error","error":{"type":"authentication_error","message":"token expired or incorrect"}}')))) -ExitCode 1 -Turn $tEp
        $o403 = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (EvE 'ep-403.jsonl' @($initE, (& $errRes 'API Error: 403 {"error":"forbidden"}')))) -ExitCode 1 -Turn $tEp
        $o429 = Get-ClaudeTurnOutcome -Events (Read-ClaudeEvents -Path (EvE 'ep-429.jsonl' @($initE, (& $errRes 'API Error: 429 {"error":{"message":"busy, try again"}}')))) -ExitCode 1 -Turn $tEp
        Check 'ENDPOINT' 'E2-E4, the turn rules of an endpoint turn: init model glm-5.3 for the pinned glm-5.3[1m] with apiKeySource none -> usable, ModelResolved glm-5.3[1m], the stderr notice [claude-code:unrecognized_model] no failure; apiKeySource ANTHROPIC_API_KEY -> class auth; an init naming claude-sonnet-5-5 -> model drift, class capability; the alias sonnet served as claude-sonnet-5-5 passes on the subscription but NOT on the endpoint route (equality, no alias family); "Failed to authenticate. API Error: 401" and "API Error: 403" -> class auth; "API Error: 429" with no quota wording -> class quota' ($oOk.Ok -and $oOk.ModelResolved -eq 'glm-5.3[1m]' -and -not $oKey.Ok -and $oKey.Class -eq 'auth' -and $oKey.Outcome -match 'apiKeySource ANTHROPIC_API_KEY on an endpoint route' -and -not $oDrift.Ok -and $oDrift.Class -eq 'capability' -and $oDrift.Outcome -match 'model drift: asked glm-5\.3\[1m\], served claude-sonnet-5-5' -and -not $oAliasEp.Ok -and $oAliasEp.Class -eq 'capability' -and $oAliasSub.Ok -and -not $o401.Ok -and $o401.Class -eq 'auth' -and $o401.Outcome -match '^failed: claude exit 1 - Failed to authenticate\. API Error: 401' -and $o403.Class -eq 'auth' -and $o429.Class -eq 'quota') "$($oOk.Outcome) | $($oKey.Outcome) | $($oDrift.Outcome) | $($oAliasEp.Outcome) | $($o401.Class) $($o403.Class) $($o429.Class)"

        # ---- E3, E4: the dry run (no `claude auth status`), its lines, the refusals without the token
        $rE = New-Repo 'endpoint'
        $rosterEp = Write-Roster 'endpoint' (& $rosterOf @($epEntry))
        $dE = Consult $rE $rosterEp @('-DryRun', '-Prompt', 'x') @{ $epVar = $epToken }
        $pvE = $dE.Preview
        Check 'ENDPOINT' 'E3: the dry run of an endpoint entry - preflight "ok: env W29B_FAKE_ZAI_TOKEN set" with NO `claude auth status` (no auth line in the fake''s log, the version probe only); reviewer ZAI-claude :: glm-5.3, provider_fingerprint = the route''s, provider_config {credential_mechanism endpoint, base_url, env_key, plan zai} without auth_method; --model glm-5.3 sent straight, no alias warning; engine_run.auth endpoint, child_env_allowed with ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, API_TIMEOUT_MS and without ANTHROPIC_API_KEY; the token value never printed' ($dE.Code -eq 0 -and $pvE.preflight -eq "ok: env $epVar set" -and @($dE.Log | Where-Object { $_.kind -eq 'auth' }).Count -eq 0 -and @($dE.Log | Where-Object { $_.kind -eq 'version' }).Count -eq 1 -and $pvE.reviewer.provider -eq 'ZAI-claude' -and $pvE.reviewer.model -eq 'glm-5.3' -and $pvE.reviewer.provider_fingerprint -eq $epFp -and $pvE.reviewer.provider_config.credential_mechanism -eq 'endpoint' -and $pvE.reviewer.provider_config.base_url -eq $epUrl -and $pvE.reviewer.provider_config.env_key -eq $epVar -and $pvE.reviewer.provider_config.plan -eq 'zai' -and $null -eq $pvE.reviewer.provider_config.PSObject.Properties['auth_method'] -and $pvE.command -match ' --model glm-5\.3 ' -and @(Get-RealWarnings $pvE.warnings | Where-Object { $_ -match 'alias' }).Count -eq 0 -and $pvE.engine_run.auth -eq 'endpoint' -and @($pvE.engine_run.child_env_allowed) -contains 'ANTHROPIC_AUTH_TOKEN' -and @($pvE.engine_run.child_env_allowed) -contains 'ANTHROPIC_BASE_URL' -and @($pvE.engine_run.child_env_allowed) -contains 'API_TIMEOUT_MS' -and -not (@($pvE.engine_run.child_env_allowed) -contains 'ANTHROPIC_API_KEY') -and -not $dE.Out.Contains($epToken)) "$($dE.First) | $($pvE.preflight) | $($pvE.reviewer.provider_fingerprint)"
        $epLine = [string](Line $dE.Out 'endpoint    :')
        $ceLine = [string](Line $dE.Out 'child env   :')
        Check 'ENDPOINT' 'E4: the dry run''s lines - "endpoint    : https://api.z.ai/api/anthropic (ANTHROPIC_BASE_URL); token from env W29B_FAKE_ZAI_TOKEN (ANTHROPIC_AUTH_TOKEN - the value is never shown); API_TIMEOUT_MS 3000000; plan zai; no claude auth status - the model the init event names is the proof", "child env   : an allow list (auth endpoint): ..." naming the three variables and not ANTHROPIC_API_KEY, and the reviewer line names the endpoint' ($epLine -eq "endpoint    : $epUrl (ANTHROPIC_BASE_URL); token from env $epVar (ANTHROPIC_AUTH_TOKEN - the value is never shown); API_TIMEOUT_MS 3000000; plan zai; no claude auth status - the model the init event names is the proof" -and $ceLine -match '^child env   : an allow list \(auth endpoint\): .*ANTHROPIC_AUTH_TOKEN, ANTHROPIC_BASE_URL, API_TIMEOUT_MS' -and $ceLine -notmatch 'ANTHROPIC_API_KEY' -and [string](Line $dE.Out 'reviewer    :') -match "endpoint https://api\.z\.ai/api/anthropic \(token from env $epVar\)") "$epLine || $ceLine"
        $dN = Consult $rE $rosterEp @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI-claude') @{}
        $rN = Consult $rE $rosterEp @('-Prompt', 'x') @{}
        $sN = Consult $rE $rosterEp @('-Prompt', 'x', '-SkipPreflight') @{}
        Check 'ENDPOINT' 'E3: the token variable unset - the dry run''s preflight "unavailable (env W29B_FAKE_ZAI_TOKEN not set) - a real run is refused" and its child env line says so; a real run finds no available reviewer ("missing: env W29B_FAKE_ZAI_TOKEN not set") and starts nothing; with -SkipPreflight the LAUNCH is refused ("the claude run is refused before launch: the claude engine''s child environment is not usable: env W29B_FAKE_ZAI_TOKEN not set (the token of auth endpoint); nothing was started") - no turn, no ledger entry' ($dN.Code -eq 0 -and [string](Line $dN.Out 'preflight   :') -match "^preflight   : unavailable \(env $epVar not set\) - a real run is refused" -and [string](Line $dN.Out 'child env   :') -match "a real run is refused: env $epVar not set" -and $rN.Code -eq 1 -and $rN.Out -match "missing: env $epVar not set" -and $sN.Code -eq 1 -and $sN.Out -match "the claude run is refused before launch: the claude engine's child environment is not usable: env $epVar not set \(the token of auth endpoint\); nothing was started" -and @(Turns $rN).Count -eq 0 -and @(Turns $sN).Count -eq 0 -and @(Ledger $rE).Count -eq 0) "$(Line $dN.Out 'preflight   :') | $($rN.First) | $($sN.First)"

        # ---- E2-E4 end to end: a run on the route, the model proof, a wrong token
        $envRun = @{ $epVar = $epToken; FAKE_CLAUDE_REPLY = $advise; FAKE_CLAUDE_TOKEN_EXPECT = $epToken; FAKE_CLAUDE_STDERR_NOTICE = '1'; ANTHROPIC_API_KEY = 'fake-key-0815'; ANTHROPIC_MODEL = 'opus'; ANTHROPIC_DEFAULT_SONNET_MODEL = 'glm-5.3[1m]'; ANTHROPIC_BASE_URL = 'http://127.0.0.1:9/'; API_TIMEOUT_MS = '1' }
        $xE = Consult $rE $rosterEp @('-Prompt', 'Check the words', '-ReplyName', 'ep') $envRun
        $eE = Last-Entry $rE
        $tE0 = @(Turns $xE) | Select-Object -First 1
        $sessE = Text (Td $rE 'sessions.json')
        $hoE = (@(Get-ChildItem -LiteralPath (Td $rE 'handoffs') -File | ForEach-Object { Text $_.FullName }) -join "`n")
        Check 'ENDPOINT' 'E2-E4 end to end: a structured run on the endpoint route is usable - its child got ANTHROPIC_BASE_URL = the roster''s (not the parent''s), API_TIMEOUT_MS 3000000, ANTHROPIC_AUTH_TOKEN = the token (the fake''s token_match) and neither ANTHROPIC_API_KEY, ANTHROPIC_MODEL, ANTHROPIC_DEFAULT_SONNET_MODEL nor the token variable itself; --model glm-5.3; no `claude auth status`; engine_run {auth endpoint, api_key_source none, model_resolved glm-5.3, child_env_allowed with ANTHROPIC_AUTH_TOKEN, without ANTHROPIC_API_KEY}; the route''s fingerprint; the stderr notice no failure; the token in no ledger, handoff or console text' ($xE.Code -eq 0 -and $eE.bridge_outcome -eq 'usable reply' -and $tE0 -and $tE0.base_url -eq $epUrl -and $tE0.api_timeout_ms -eq '3000000' -and $tE0.has_token -eq $true -and $tE0.token_match -eq $true -and -not (Has-Name $tE0 'ANTHROPIC_API_KEY') -and -not (Has-Name $tE0 'ANTHROPIC_MODEL') -and -not (Has-Name $tE0 'ANTHROPIC_DEFAULT_SONNET_MODEL') -and -not (Has-Name $tE0 $epVar) -and (ArgOf $tE0 '--model') -eq 'glm-5.3' -and @($xE.Log | Where-Object { $_.kind -eq 'auth' }).Count -eq 0 -and $eE.engine_run.auth -eq 'endpoint' -and $eE.engine_run.api_key_source -eq 'none' -and $eE.engine_run.model_resolved -eq 'glm-5.3' -and @($eE.engine_run.child_env_allowed) -contains 'ANTHROPIC_AUTH_TOKEN' -and -not (@($eE.engine_run.child_env_allowed) -contains 'ANTHROPIC_API_KEY') -and $eE.reviewer.provider_fingerprint -eq $epFp -and -not $sessE.Contains($epToken) -and -not $hoE.Contains($epToken) -and -not $xE.Out.Contains($epToken) -and $xE.GuardOk) "$($xE.First) | $($eE.bridge_outcome) | base_url $($tE0.base_url) token_match $($tE0.token_match)"
        $xD = Consult $rE $rosterEp @('-Prompt', 'x', '-ReplyName', 'drift') @{ $epVar = $epToken; FAKE_CLAUDE_REPLY = $advise; FAKE_CLAUDE_INIT_MODEL = 'claude-sonnet-5-5' }
        $eD = Last-Entry $rE
        Check 'ENDPOINT' 'E2: the model proof against the init event, end to end - an endpoint turn whose init names claude-sonnet-5-5 (what a subscription turn would serve) for the pinned glm-5.3 fails "model drift: asked glm-5.3, served claude-sonnet-5-5", class capability' ($xD.Code -ne 0 -and [string]$eD.bridge_outcome -match 'model drift: asked glm-5\.3, served claude-sonnet-5-5' -and $eD.provider_failure.class -eq 'capability') "$($eD.bridge_outcome)"
        $r4 = New-Repo 'endpoint-401'
        $rosterEpZ = Write-Roster 'endpoint-zai' (& $rosterOf @($epEntry, $zaiEntry))
        $x4 = Consult $r4 $rosterEpZ @('-Prompt', 'x', '-Provider', 'ZAI-claude', '-ReplyName', 'u401') @{ $epVar = $epToken; FAKE_CLAUDE_REPLY = $advise; FAKE_CLAUDE_TOKEN_EXPECT = 'another-fake-token' }
        $e4 = Last-Entry $r4
        $p4 = Providers $r4 $rosterEpZ @('-Json') @{ $epVar = $epToken }
        $c4 = & $row $p4.Json 'ZAI-claude'; $z4 = & $row $p4.Json 'ZAI'
        Check 'ENDPOINT' 'E4: a wrong token (P11: "Failed to authenticate. API Error: 401", no fallback to the local login) fails the run with class auth on the route''s fingerprint; the auth failure stays with its ROUTE - the listing shows ZAI-claude "unavailable (auth failed ...)" and the same-plan codex ZAI available (E5: only a quota failure propagates over a plan)' ($x4.Code -ne 0 -and [string]$e4.bridge_outcome -match 'Failed to authenticate\. API Error: 401' -and $e4.provider_failure.class -eq 'auth' -and $e4.reviewer.provider_fingerprint -eq $epFp -and [string]$c4.verdict -match '^unavailable \(auth failed' -and $z4.verdict -eq 'available') "$($e4.bridge_outcome) | $($c4.verdict) | $($z4.verdict)"

        # ---- E3: the listing (codex-providers.ps1)
        $r5 = New-Repo 'endpoint-listing'
        $l5 = Providers $r5 $rosterEpZ @('-Json') @{ $epVar = $epToken }
        $l5n = Providers $r5 $rosterEpZ @('-Json', '-NoNetwork') @{ $epVar = $epToken }
        $l5m = Providers $r5 $rosterEpZ @('-Json') @{}
        $c5 = & $row $l5.Json 'ZAI-claude'; $c5m = & $row $l5m.Json 'ZAI-claude'
        Check 'ENDPOINT' 'E3: codex-providers.ps1 - the endpoint row: engine claude, endpoint "claude endpoint https://api.z.ai/api/anthropic (<launcher>)", credentials "ok: env W29B_FAKE_ZAI_TOKEN set" (local: no `claude auth status` logged; -NoNetwork the same), verdict available; the variable unset -> "missing: env W29B_FAKE_ZAI_TOKEN not set" and "unavailable (env W29B_FAKE_ZAI_TOKEN not set)"' ($l5.Code -eq 0 -and $c5.engine -eq 'claude' -and [string]$c5.endpoint -match '^claude endpoint https://api\.z\.ai/api/anthropic \(' -and $c5.credentials -eq "ok: env $epVar set" -and $c5.verdict -eq 'available' -and @($l5.Log | Where-Object { $_.kind -eq 'auth' }).Count -eq 0 -and (& $row $l5n.Json 'ZAI-claude').credentials -eq "ok: env $epVar set" -and $c5m.credentials -eq "missing: env $epVar not set" -and $c5m.verdict -eq "unavailable (env $epVar not set)") "$($c5.endpoint) | $($c5.credentials) | $($c5m.verdict)"

        # ---- E5: the PLAN identity - a quota failure propagates over the plan, nothing else does
        $rosterPlan = Write-Roster 'endpoint-plan' (& $rosterOf @($zaiEntry, $epEntry, $oaiEntry))
        $r6 = New-Repo 'endpoint-plan'
        Seed-Task $r6 @((& $seedE 1 'ZAI' 'codex' $zaiFp 'quota' 'usage limit reached for the 5 hour window' $nowE.AddHours(3)))
        $l6 = Providers $r6 $rosterPlan @('-Json') @{ $epVar = $epToken }
        $l6s = Providers $r6 $rosterPlan @('-Short') @{ $epVar = $epToken }
        $l6t = Providers $r6 $rosterPlan @() @{ $epVar = $epToken }
        $c6 = & $row $l6.Json 'ZAI-claude'; $z6 = & $row $l6.Json 'ZAI'
        Check 'ENDPOINT' 'E5: a QUOTA failure recorded on the codex entry ZAI (plan zai) marks the claude entry ZAI-claude of the same plan out until the same reset - the listing row "unavailable (plan zai (usage limit on ZAI until <iso>))" (ZAI itself: its own "usage limit until"), the -Short line "ZAI-claude :: glm-5.3 (plan zai (usage limit on ZAI until ..."; the roster walk skips both ("... [claude] (plan zai (usage limit on ZAI until ...") and would select openai' ([string]$c6.verdict -match '^unavailable \(plan zai \(usage limit on ZAI until \d{4}-\d\d-\d\dT' -and [string]$z6.verdict -match '^unavailable \(usage limit until ' -and $l6s.Out -match 'ZAI-claude :: glm-5\.3 \(plan zai \(usage limit on ZAI until ' -and $l6t.Out -match 'would select openai :: gpt-5\.1 \(skipped: ZAI :: glm-5\.3 \(usage limit until [^)]*\), ZAI-claude :: glm-5\.3 \[claude\] \(plan zai \(usage limit on ZAI until ') "$($c6.verdict) | $($z6.verdict) | $($l6s.Out)"
        $x6 = Consult $r6 $rosterPlan @('-Prompt', 'x', '-Provider', 'ZAI-claude') @{ $epVar = $epToken; FAKE_CLAUDE_REPLY = $advise }
        Check 'ENDPOINT' 'E5: a direct run of the plan''s other route is refused before anything starts: "provider ZAI-claude is not usable: its plan zai hit a usage limit on ZAI at ... that lasts until ...; nothing was started (pass -SkipPreflight to launch anyway)"' ($x6.Code -eq 1 -and $x6.Out -match 'provider ZAI-claude is not usable: its plan zai hit a usage limit on ZAI at .* that lasts until .*; nothing was started \(pass -SkipPreflight to launch anyway\)' -and @(Turns $x6).Count -eq 0) $x6.First
        $r7 = New-Repo 'endpoint-plan-back'
        Seed-Task $r7 @((& $seedE 1 'ZAI-claude' 'claude' $epFp 'quota' 'usage limit reached' $nowE.AddHours(2)))
        $l7 = Providers $r7 $rosterPlan @('-Json') @{ $epVar = $epToken }
        $r8 = New-Repo 'endpoint-plan-auth'
        Seed-Task $r8 @((& $seedE 1 'ZAI' 'codex' $zaiFp 'auth' 'invalid api key (401)' $null))
        $l8 = Providers $r8 $rosterPlan @('-Json') @{ $epVar = $epToken }
        $r9 = New-Repo 'endpoint-noplan'
        Seed-Task $r9 @((& $seedE 1 'ZAI' 'codex' $zaiFp 'quota' 'usage limit reached for the 5 hour window' $nowE.AddHours(3)))
        $l9 = Providers $r9 (Write-Roster 'endpoint-noplan' (& $rosterOf @($zaiEntryNoPlan, $epEntryNoPlan, $oaiEntry))) @('-Json') @{ $epVar = $epToken }
        $r10 = New-Repo 'endpoint-plan-cleared'
        Seed-Task $r10 @((& $seedE 1 'ZAI' 'codex' $zaiFp 'quota' 'usage limit reached for the 5 hour window' $nowE.AddHours(3) 10), (& $seedE 2 'ZAI-claude' 'claude' $epFp '' '' $null 2))
        $l10 = Providers $r10 $rosterPlan @('-Json') @{ $epVar = $epToken }
        Check 'ENDPOINT' 'E5: the plan works both ways and only for quota - a usage limit on the claude route marks the codex ZAI out ("plan zai (usage limit on ZAI-claude until ..."); an AUTH failure on ZAI leaves ZAI-claude available; without a plan the codex usage limit leaves ZAI-claude available; a usable reply on ZAI-claude after the codex limit clears the plan for ZAI-claude (the plan''s routes are one record set) while ZAI keeps its own limit' ([string](& $row $l7.Json 'ZAI').verdict -match '^unavailable \(plan zai \(usage limit on ZAI-claude until ' -and [string](& $row $l8.Json 'ZAI').verdict -match '^unavailable \(auth failed' -and (& $row $l8.Json 'ZAI-claude').verdict -eq 'available' -and (& $row $l9.Json 'ZAI-claude').verdict -eq 'available' -and [string](& $row $l9.Json 'ZAI').verdict -match '^unavailable \(usage limit until ' -and (& $row $l10.Json 'ZAI-claude').verdict -eq 'available' -and [string](& $row $l10.Json 'ZAI').verdict -match '^unavailable \(usage limit until ') "$((& $row $l7.Json 'ZAI').verdict) | $((& $row $l8.Json 'ZAI-claude').verdict) | $((& $row $l9.Json 'ZAI-claude').verdict) | $((& $row $l10.Json 'ZAI-claude').verdict)"

        # ---- E6: telemetry by host, the lab by host, the coordinator rule
        $tv = { param([string]$Url, [string]$Model, [string]$Auth = 'endpoint', [string]$Engine = 'claude') $pc = [pscustomobject]@{ engine = $Engine; launcher = 'x'; credential_mechanism = $Auth }; if ($Url) { $pc | Add-Member -NotePropertyName 'base_url' -NotePropertyValue $Url }; $c = Get-TelemetryReviewerClass ([pscustomobject]@{ reviewer = [pscustomobject]@{ provider = 'LABEL-x'; model = $Model; engine = $Engine; provider_config = $pc } }); "$($c.provider)/$($c.model)" }
        $tcases = @(
            @((& $tv $epUrl 'glm-5.3'), 'zai/glm-5.3'),
            @((& $tv $epUrl 'glm-5.3[1m]'), 'zai/glm-5.3'),
            @((& $tv 'https://token-plan-ams.xiaomimimo.com/anthropic' 'mimo-v2.6-pro'), 'xiaomi/mimo-v2.6-pro'),
            @((& $tv 'https://api.kimi.ai/coding/' 'k3'), 'moonshot/k3'),
            @((& $tv 'https://api.minimax.io/anthropic' 'MiniMax-M3'), 'minimax/minimax-m3'),
            @((& $tv 'https://api.minimax.cn/anthropic' 'minimax-m3'), 'minimax/minimax-m3'),
            @((& $tv 'https://llm.example.invalid/anthropic' 'glm-5.3'), 'other/other'),
            @((& $tv $epUrl 'claude-sonnet-5-5'), 'zai/other'),
            @((& $tv '' 'sonnet' 'subscription'), 'anthropic/sonnet'),
            @((& $tv '' 'claude-opus-5-5[1m]' 'api-key'), 'anthropic/claude-opus-5-5'),
            @((& $tv 'https://api.z.ai/api/coding/paas/v4' 'glm-5.3[1m]' '' 'codex'), 'zai/glm-5.3')
        )
        $tgot = @($tcases | ForEach-Object { $_[0] })
        $twant = @($tcases | ForEach-Object { $_[1] })
        $evE = New-TelemetryEvent -Entry $eE -InstanceId ('ab' * 32)
        $evJ = ConvertTo-Json -InputObject $evE -Compress -Depth 8
        Check 'ENDPOINT' 'E6: telemetry by the base URL''s HOST first - api.z.ai -> zai/glm-5.3 ([1m] stripped for every vendor, a codex zai entry too), *.xiaomimimo.com -> xiaomi, api.kimi.ai -> moonshot/k3, api.minimax.io and .cn -> minimax/minimax-m3, an unknown host -> other/other, a model outside the vendor''s list -> other; no base URL (subscription, api-key) -> the engine row anthropic; the real run''s event: engine claude, provider zai, model glm-5.3, and neither the URL, the label nor the variable name in it' (($tgot -join ' ') -eq ($twant -join ' ') -and $evE.details.engine -eq 'claude' -and $evE.details.provider -eq 'zai' -and $evE.details.model -eq 'glm-5.3' -and $evJ -notmatch 'api\.z\.ai' -and -not $evJ.Contains('ZAI-claude') -and -not $evJ.Contains($epVar)) "got: $($tgot -join ' ') | event $($evE.details.provider)/$($evE.details.model)"
        $mkEntry = { param([string]$Url, [string]$Lab = '') [pscustomobject]@{ Provider = 'P-claude'; Model = 'm'; Engine = 'claude'; Auth = 'endpoint'; Lab = $Lab; Endpoint = (& $mkEp $Url 'ABC_KEY') } }
        $labOf = { param($Entry, [string]$M) $l = Get-EntryLab -Entry $Entry -Model $M; "$($l.Lab)/$($l.Source)" }
        $labs = @(
            (& $labOf (& $mkEntry $epUrl) 'glm-5.3'),
            (& $labOf (& $mkEntry 'https://token-plan-ams.xiaomimimo.com/anthropic') 'mimo-v2.6-pro'),
            (& $labOf (& $mkEntry 'https://api.kimi.ai/coding/') 'k3'),
            (& $labOf (& $mkEntry 'https://api.minimax.io/anthropic') 'MiniMax-M3'),
            (& $labOf (& $mkEntry 'https://llm.example.invalid/anthropic') 'glm-5.3'),
            (& $labOf (& $mkEntry $epUrl 'mylab') 'glm-5.3'),
            (& $labOf ([pscustomobject]@{ Provider = 'anthropic'; Model = 'sonnet'; Engine = 'claude'; Auth = 'subscription'; Lab = '' }) 'sonnet'))
        $co = { param([string]$P, [string]$M) [pscustomobject]@{ provider = $P; model = $M; engine = ''; source = 'explicit' } }
        $cm1 = Get-CoordinatorMatch -Coordinator (& $co 'ZAI-claude' 'glm-5.3') -Provider 'ZAI-claude' -Model 'glm-5.3' -Engine 'claude' -Auth 'endpoint'
        $cm2 = Get-CoordinatorMatch -Coordinator (& $co 'anthropic' 'glm-5.3') -Provider 'ZAI-claude' -Model 'glm-5.3' -Engine 'claude' -Auth 'endpoint'
        $cm3 = Get-CoordinatorMatch -Coordinator (& $co 'ZAI' 'glm-5.3') -Provider 'ZAI-claude' -Model 'glm-5.3' -Engine 'claude' -Auth 'endpoint'
        $cm4 = Get-CoordinatorMatch -Coordinator (& $co 'anthropic' 'claude-sonnet-5-5') -Provider 'my-label' -Model 'sonnet' -Engine 'claude' -Auth 'subscription'
        Check 'ENDPOINT' 'E5: the lab of an endpoint entry by its base URL''s HOST (api.z.ai -> zhipu, *.xiaomimimo.com -> xiaomi, api.kimi.ai -> moonshot, api.minimax.io -> minimax; an unknown host -> the model''s vendor table; a declared lab wins; a subscription entry anthropic); the coordinator rule compares an endpoint entry as a codex entry (label and model: "ZAI-claude :: glm-5.3" own, "anthropic :: glm-5.3" and "ZAI :: glm-5.3" not) and keeps the anthropic rule for the subscription' (($labs -join ' ') -eq 'zhipu/vendor xiaomi/vendor moonshot/vendor minimax/vendor zhipu/vendor mylab/roster anthropic/vendor' -and $cm1 -eq 'own' -and $cm2 -eq '' -and $cm3 -eq '' -and $cm4 -eq 'own') "$($labs -join ' ') | $cm1,$cm2,$cm3,$cm4"

        # ---- E7: the plan's scheduling group
        $pmE = { param([int]$Pos, [string]$Prov, [string]$Mod, [string]$Eng, [string]$Plan, [string]$Auth = '', $Ep = $null) $idArgs = @{ Config = $cfgEp; Provider = $Prov; Model = $Mod; Engine = $Eng }; if ($Auth) { $idArgs['Auth'] = $Auth; $idArgs['Endpoint'] = $Ep }; [pscustomobject]@{ Entry = [pscustomobject]@{ Position = $Pos; Provider = $Prov; Model = $Mod; Engine = $Eng; Plan = $Plan; Auth = $Auth; Endpoint = $Ep }; Identity = (Resolve-ReviewerIdentity @idArgs) } }
        $runP = @((& $pmE 1 'ZAI' 'glm-5.3' 'codex' 'zai'), (& $pmE 2 'ZAI-claude' 'glm-5.3' 'claude' 'zai' 'endpoint' (& $mkEp $epUrl $epVar)), (& $pmE 3 'openai' 'gpt-5.1' 'codex' ''))
        $runN = @((& $pmE 1 'ZAI' 'glm-5.3' 'codex' ''), (& $pmE 2 'ZAI-claude' 'glm-5.3' 'claude' '' 'endpoint' (& $mkEp $epUrl $epVar)), (& $pmE 3 'openai' 'gpt-5.1' 'codex' ''))
        $newPar = { $h = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal); $h }
        $parPlan = & $newPar; $parPlan['zai'] = 2
        $parLabels = & $newPar; $parLabels['ZAI'] = 2; $parLabels['ZAI-claude'] = 2
        $pl1 = Get-PanelPlan -Runners $runP -Parallel (& $newPar) -Cap 0
        $pl2 = Get-PanelPlan -Runners $runP -Parallel $parPlan -Cap 0
        $pl3 = Get-PanelPlan -Runners $runN -Parallel (& $newPar) -Cap 0
        $pl4 = Get-PanelPlan -Runners $runP -Parallel $parLabels -Cap 0
        $avP = Get-EndpointGroups -Members $runP
        Check 'ENDPOINT' 'E7: every plan is a scheduling group across engines - a codex ZAI member and a claude ZAI-claude member of plan zai share one group ("at most 2 at a time" beside an openai member); "parallel": {"zai": 2} -> "at once"; raising both labels but not the plan keeps them one after another; without the plan they run at once; the availability view does not group by plan' ($pl1.GroupOf[1] -eq $pl1.GroupOf[2] -and $pl1.GroupOf[3] -ne $pl1.GroupOf[1] -and $pl1.Text -eq 'at most 2 at a time' -and $pl2.Text -eq 'at once' -and $pl4.Text -eq 'at most 2 at a time' -and $pl3.Text -eq 'at once' -and $avP.GroupOf[1] -ne $avP.GroupOf[2]) "$($pl1.Text) / $($pl2.Text) / $($pl3.Text) / $($pl4.Text)"
        $rosterPanel = Write-Roster 'endpoint-panel' (& $rosterOf @($zaiEntry, $epEntry, $oaiEntry))
        $rosterPanelP = Write-Roster 'endpoint-panelp' (& $rosterOf @($zaiEntry, $epEntry, $oaiEntry) ',"parallel":{"zai":2}')
        $pdE = Consult $r5 $rosterPanel @('-Panel', '-PanelSize', '3', '-DryRun', '-Prompt', 'x') @{ $epVar = $epToken }
        $ppE = Consult $r5 $rosterPanelP @('-Panel', '-PanelSize', '3', '-DryRun', '-Prompt', 'x') @{ $epVar = $epToken }
        Check 'ENDPOINT' 'E7 through the bridge: a dry-run panel of ZAI (codex), ZAI-claude (endpoint) and openai plans "at most 2 at a time" (the plan zai serializes its two routes); with "parallel": {"zai": 2} "at once"' ($pdE.Code -eq 0 -and $pdE.Out -match 'at most 2 at a time' -and $ppE.Code -eq 0 -and $ppE.Out -match 'at once') "$($pdE.First) | $($ppE.First)"
    } finally {
        $codexHome = $savedCodexHome
    }
}

} finally {
    Restore-Env
    Remove-TestWork $work
}
# GUARD: every claude turn of every ledger entry these cases made has its line in the fake's argv log
# (a real CLI would have written none); the harness string above named the fake's version
Check 'GUARD' "no real claude: every claude turn in the ledgers had its argv-log line ($($script:claudeTurnsSeen) turns across the cases)" ($script:guardProblems.Count -eq 0 -and ($script:claudeTurnsSeen -gt 0 -or $Only)) ($script:guardProblems -join ' | ')
$guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
Check 'GUARD' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard ''
Write-Host ("harness-claude ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
