# codex-consult 0.3.0 (R7 + R8 convention): reviewer identity from the Codex config,
# constrained TOML scanner, compatibility fingerprint, lineage-scoped parents, rollout
# fallback verified by the consultation id, effort vocabularies, peak windows, requested
# checks paragraph. Covers the verification step of every design finding F02-1..5, F02-9
# and the amendments' A8 list, plus the GLM diff-review points (user-defined
# [model_providers.openai], absent wire_api, event drift nets) and the survivor wait of
# Stop-ProcessTree. Fake codex only; CODEX_HOME always points at a SCRATCH directory
# (a real config is never read by the bridge here; its hash is only compared). Runs
# under the host it is started with (powershell 5.1 or pwsh 7, Windows) and launches
# the bridge with the same host. Work files: $env:TEMP\codex-consult-tests\harness-0.3\
# <guid>, removed at the end.
param([string]$Only = '')
$ErrorActionPreference = 'Stop'
$sp = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$scripts = Join-Path $repoRoot 'plugins\codex-consult\scripts'
. (Join-Path $scripts 'codex-consult-common.ps1')
$consultPs = Join-Path $scripts 'codex-consult.ps1'
$fake = Join-Path $sp 'fake-codex3.cmd'
$psExe = (Get-Process -Id $PID).Path
$hostTag = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'ps51' }
$tmpBase = if ($env:TEMP) { $env:TEMP } else { [IO.Path]::GetTempPath() }
$work = Join-Path (Join-Path (Join-Path $tmpBase 'codex-consult-tests') 'harness-0.3') ([guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($work)
function Remove-TestWork {
    param([string]$Path)
    for ($i = 0; $i -lt 6; $i++) {
        try { if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop }; return } catch { Start-Sleep -Seconds 1 }
    }
    Write-Host "WARNING: could not remove the work directory $Path"
}
$u8 = New-Object System.Text.UTF8Encoding($false)
# The user's own config is never read by the bridge in this harness; if it exists its
# hash is compared before/after as a guard.
$realConfig = Join-Path (Join-Path $HOME '.codex') 'config.toml'
$realConfigHash = ''
if (Test-Path -LiteralPath $realConfig -PathType Leaf) { $realConfigHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash }
$savedCodexHome = $env:CODEX_HOME
# A config shaped like a real one (Codex desktop + plugins + MCP servers + a z.ai
# provider): a multi-line top-level array, literal-quoted Windows paths in table
# headers, JSON inside a literal string, arrays in MCP tables.
$realShapedConfig = @'
model = "gpt-5.1"
model_reasoning_effort = "xhigh"
notify = [
    'C:\Users\example\AppData\Local\Codex\bin\notify-helper.exe',
    "turn-ended",
]

[projects.'C:\Users\example']
trust_level = "trusted"

[projects.'\\?\C:\Users\example\work']
trust_level = "trusted"

[windows]
sandbox = "elevated"

[desktop]
followUpQueueMode = "steer"
ambient-suggestions-enabled = true

[marketplaces.example-git]
last_updated = "2026-09-22T04:58:16Z"
source_type = "git"
source = "https://example.com/plugins.git"

[plugins."browser@example-bundled"]
enabled = true

[mcp_servers.node_repl]
args = []
command = 'C:\Users\example\bin\node_repl.exe'
env_vars = ["EXAMPLE_REGISTERED_CORE"]
startup_timeout_sec = 120

[mcp_servers.node_repl.env]
NODE_REPL_TRUSTED_SERVICES = '{"browser":"C:/example/browser-service.mjs","sky":"@example/sky/service"}'
SKY_PIPE_DIRECTORY = '\\.\pipe\example-7c41df53'

[mcp_servers.other]
command = "node"
args = ['C:\Users\example\mcp.js']

[model_providers.ZAI]
name = "Z.ai GLM Coding Plan"
base_url = "https://api.z.ai/api/v1"
env_key = "ZAI_API_KEY"
wire_api = "responses"

[features]
js_repl = false
'@
$script:fails = 0
$script:passes = 0

function Check {
    param([string]$Id, [string]$What, [bool]$Ok, [string]$Evidence = '')
    if ($Ok) { $script:passes++ } else { $script:fails++ }
    $mark = if ($Ok) { 'PASS' } else { 'FAIL' }
    $ev = $Evidence
    if ($ev.Length -gt 260) { $ev = $ev.Substring(0, 260) + '...' }
    Write-Host ("{0} {1,-6} {2}{3}" -f $mark, $Id, $What, $(if ($ev) { "  | $ev" } else { '' }))
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
# A scratch CODEX_HOME with config.toml = $Toml ($null: no config file).
function New-Home {
    param([string]$Name, $Toml)
    $h = Join-Path $work "home-$Name"
    if (Test-Path $h) { Remove-Item $h -Recurse -Force }
    [void][IO.Directory]::CreateDirectory($h)
    if ($null -ne $Toml) { [IO.File]::WriteAllText((Join-Path $h 'config.toml'), $Toml, $u8) }
    return $h
}
$fakeVars = @('FAKE_CODEX_REPLY', 'FAKE_CODEX_SLEEP', 'FAKE_CODEX_LOG', 'FAKE_CODEX_NOTHREAD', 'FAKE_CODEX_ROLLOUT', 'FAKE_CODEX_ROLLOUT_LOG', 'FAKE_CODEX_PIDFILE', 'FAKE_CODEX_PRELINE', 'FAKE_CODEX_LOGIN', 'FAKE_CODEX_STDERR', 'FAKE_CODEX_EXIT')
# Credentials the preflight looks for: the scratch configs name these env_key variables.
$testKeyVars = @('ZAI_KEY_A', 'CC_TEST_KEY', 'CODEX_CONSULT_EXE', 'CODEX_CONSULT_NOW', 'CODEX_CONSULT_ROSTER')
function Clear-TestEnv {
    foreach ($k in ($fakeVars + $testKeyVars)) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    Get-ChildItem env: | Where-Object { $_.Name -like 'CODEX_CONSULT_PEAK_*' } | ForEach-Object { Remove-Item "env:$($_.Name)" -ErrorAction SilentlyContinue }
    Remove-Item env:OPENAI_BASE_URL -ErrorAction SilentlyContinue
    # no reviewer roster in these cases, whatever the machine has (none = no roster)
    $env:CODEX_CONSULT_ROSTER = 'none'
}
function Consult {
    param([string]$Repo, [string]$CodexHome, [string[]]$ArgList, [hashtable]$Env = @{})
    Clear-TestEnv
    $env:CODEX_HOME = $CodexHome
    # the ZAI tables of the scratch configs use env_key ZAI_KEY_A: present unless a case
    # removes it (a value of '' removes a variable)
    $env:ZAI_KEY_A = 'test-key-a'
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $consultPs -Task t -CodexExe $fake @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Clear-TestEnv
    $env:CODEX_HOME = $savedCodexHome
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    $preview = $null
    $mark = 'sessions.json entry preview:'
    $at = $text.IndexOf($mark)
    if ($at -ge 0) { try { $preview = $text.Substring($at + $mark.Length) | ConvertFrom-Json } catch { $preview = $null } }
    return [pscustomobject]@{ Code = $code; Out = $text; Preview = $preview; First = (($text -split "`n") | Select-Object -First 1) }
}
$providersPs = Join-Path $scripts 'codex-providers.ps1'
# codex-providers.ps1 in $Repo with a scratch CODEX_HOME; the fake codex answers `login status`.
function Providers {
    param([string]$Repo, [string]$CodexHome, [string[]]$ArgList = @(), [hashtable]$Env = @{})
    Clear-TestEnv
    $env:CODEX_HOME = $CodexHome
    $env:CODEX_CONSULT_EXE = $fake
    $env:ZAI_KEY_A = 'test-key-a'
    foreach ($k in $Env.Keys) { if ([string]$Env[$k] -eq '') { Remove-Item "env:$k" -ErrorAction SilentlyContinue } else { Set-Item "env:$k" $Env[$k] } }
    Push-Location $Repo
    $p = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $psExe -NoProfile -ExecutionPolicy Bypass -File $providersPs @ArgList 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $p
    Pop-Location
    Clear-TestEnv
    $env:CODEX_HOME = $savedCodexHome
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    $json = $null
    # PS 5.1 emits a JSON array as ONE object: unroll it
    if ($ArgList -contains '-Json') { try { $parsed = $text | ConvertFrom-Json; $json = @($parsed | ForEach-Object { $_ }) } catch { $json = $null } }
    return [pscustomobject]@{ Code = $code; Out = $text; Json = $json }
}
function Reply { param([string]$Name, [string]$Text) $p = Join-Path $work $Name; [IO.File]::WriteAllText($p, $Text, $u8); return $p }
function Ledger { param([string]$Repo) return @((Get-Content -Raw (Join-Path $Repo '.collab\t\sessions.json') | ConvertFrom-Json).codex.consults) }
function Last-Entry { param([string]$Repo) return (Ledger $Repo)[-1] }
function Line { param([string]$Out, [string]$Prefix) return (($Out -split "`n") | Where-Object { $_.StartsWith($Prefix) } | Select-Object -First 1) }
function Id { param([string]$ConfigPath, [string]$Provider = '', [string]$Model = '', [string]$OpenAi = '') return (Resolve-ReviewerIdentity -Config (Read-CodexConfigSubset -Path $ConfigPath) -Provider $Provider -Model $Model -OpenAiBaseUrl $OpenAi) }
function Toml { param([string]$Text) return ($Text -replace "`r`n", "`n") }

$advise = Reply 'advise.json' '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}'
$zaiTable = "[model_providers.ZAI]`nname = `"Z.ai GLM Coding Plan`"`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"ZAI_KEY_A`"`nwire_api = `"responses`"`n"
$baseToml = "model = `"gpt-5.1`"`nmodel_reasoning_effort = `"high`"`n`n" + $zaiTable

try {
# =============================================================== SCAN: constrained scanner on a real-shaped config + constructs
if (Want 'SCAN') {
    $h = New-Home 'real' (Toml $realShapedConfig)
    $cfg = Read-CodexConfigSubset -Path (Join-Path $h 'config.toml')
    $top = $cfg.Tables['']
    $notify = $top.Entries['notify']
    $pt = Get-ProviderTable -Config $cfg -Name 'ZAI'
    $mcp = $cfg.Tables['mcp_servers' + [char]31 + 'node_repl']
    Check 'SCAN' 'real-shaped config: file scans (Ok), top level usable, model read' ($cfg.Ok -and $top.Ok -and (Get-TomlString -Table $top -Key 'model').Value -eq 'gpt-5.1') "file ok=$($cfg.Ok) reason='$($cfg.Reason)'"
    Check 'SCAN' 'real-shaped config: multi-line top-level notify array is delimited, marked unsupported, never interpreted' ($notify -and -not $notify.Supported -and $notify.Kind -eq 'array' -and $notify.Reason -match 'line 3') $notify.Reason
    Check 'SCAN' 'real-shaped config: arrays in [mcp_servers.node_repl] reject those keys only; [model_providers.ZAI] usable' ($pt.Found -and $pt.Ok -and -not $mcp.Entries['args'].Supported -and $mcp.Entries['command'].Supported) "ZAI ok=$($pt.Ok); node_repl.args=$($mcp.Entries['args'].Kind)"
    $idReal = Id (Join-Path $h 'config.toml') 'ZAI' 'glm-5.3'
    Check 'SCAN' 'real-shaped config: -Provider ZAI -Model glm-5.3 resolves (lineage, 64-hex fingerprint, env_key not recorded)' ($idReal.Resolved -and $idReal.Lineage -eq 'ZAI :: glm-5.3' -and $idReal.Fingerprint -match '^[0-9a-f]{64}$' -and -not $idReal.ProviderConfig.PSObject.Properties['env_key']) "fp=$($idReal.Fingerprint) config=$(ConvertTo-Json -Compress $idReal.ProviderConfig)"
    $idDef = Id (Join-Path $h 'config.toml')
    Check 'SCAN' 'real-shaped config: no -Provider -> openai (Codex default, built in) / gpt-5.1 (config)' ($idDef.Resolved -and $idDef.Lineage -eq 'openai :: gpt-5.1' -and $idDef.ProviderSource -eq 'codex default' -and $idDef.ModelSource -eq 'config' -and $idDef.CompatString -eq 'cc-provider-v1|builtin:openai') $idDef.Lineage

    $constructs = Toml @"
# comment line
model = "gpt-5.1" # trailing comment
title = '''multi
line [not.a.header]
model = "evil"'''
doc = """a "quoted" \""" tail
[model_providers.FAKE]
"""
list = [ "a]", 'b[', { x = "}" }, # comment ] inside
  "c" ]

[model_providers."my prov"]
base_url = 'https://Example.COM/v1/'
wire_api = "responses"

[model_providers.HDR]
base_url = "https://api.z.ai/api/v1"
http_headers = { Authorization = "Bearer sk-SECRET123" }

[model_providers]
DOT.base_url = "https://x.example/v1"

[[model_providers.AOT]]
base_url = "https://aot.example/v1"

[model_providers.SUB]
base_url = "https://sub.example/v1"
[model_providers.SUB.extra]
k = 1

[model_providers.TWICE]
base_url = "https://a.example"
[model_providers.TWICE]
base_url = "https://b.example"

[model_providers.OK2]
base_url = "https://api.z.ai/api/v1"
enabled = true
retries = 1_000
"@
    $h2 = New-Home 'constructs' $constructs
    $c2 = Read-CodexConfigSubset -Path (Join-Path $h2 'config.toml')
    $t2 = $c2.Tables['']
    Check 'SCAN' 'multi-line strings containing a header and "model = ..." are skipped: top-level model stays gpt-5.1, no table FAKE' ($c2.Ok -and (Get-TomlString -Table $t2 -Key 'model').Value -eq 'gpt-5.1' -and -not $c2.Tables.ContainsKey('model_providers' + [char]31 + 'FAKE')) "keys=$(@($t2.Entries.Keys) -join ',')"
    Check 'SCAN' 'array with brackets inside strings and a comment spans lines exactly (next table found)' ((Get-ProviderTable -Config $c2 -Name 'my prov').Ok -and $t2.Entries['list'].Kind -eq 'array') ''
    $mp = Id (Join-Path $h2 'config.toml') 'my prov' 'm1'
    Check 'SCAN' 'quoted table key + literal string + trailing slash + host case -> canonical base_url' ($mp.Resolved -and $mp.BaseUrl -eq 'https://example.com/v1') $mp.BaseUrl
    $results = @{}
    foreach ($n in @('HDR', 'DOT', 'AOT', 'SUB', 'TWICE')) { $results[$n] = Get-ProviderTable -Config $c2 -Name $n }
    Check 'SCAN' 'inline table in a provider -> that provider unusable, reason names the line, the secret is masked' (-not $results.HDR.Ok -and $results.HDR.Reason -match 'line 18' -and $results.HDR.Reason -notmatch 'SECRET') $results.HDR.Reason
    Check 'SCAN' 'dotted key writing into a provider -> unusable (line 21)' (-not $results.DOT.Ok -and $results.DOT.Reason -match 'line 21.*dotted key') $results.DOT.Reason
    Check 'SCAN' 'array of tables -> unusable' (-not $results.AOT.Ok -and $results.AOT.Reason -match 'array of tables') $results.AOT.Reason
    Check 'SCAN' 'provider with a sub-table -> unusable' (-not $results.SUB.Ok -and $results.SUB.Reason -match 'sub-table') $results.SUB.Reason
    Check 'SCAN' 'table defined twice -> unusable' (-not $results.TWICE.Ok -and $results.TWICE.Reason -match 'defined twice') $results.TWICE.Reason
    $ok2 = Id (Join-Path $h2 'config.toml') 'OK2' 'glm-5.3'
    Check 'SCAN' 'the other tables stay usable (OK2: boolean + underscored integer recorded)' ($ok2.Resolved -and $ok2.ProviderConfig.enabled -eq $true -and $ok2.ProviderConfig.retries -eq 1000) (ConvertTo-Json -Compress $ok2.ProviderConfig)

    $h3 = New-Home 'fatal' (Toml "model = `"gpt-5.1`"`n[broken`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`n")
    $c3 = Read-CodexConfigSubset -Path (Join-Path $h3 'config.toml')
    Check 'SCAN' 'a line the scanner cannot tokenize -> whole file unusable (fatal), reason names line 2' (-not $c3.Ok -and $c3.Reason -match 'line 2') $c3.Reason
    $h4 = New-Home 'unterminated' (Toml "model = `"gpt-5.1`"`nlist = [ `"a`",`n  `"b`"`n")
    $c4 = Read-CodexConfigSubset -Path (Join-Path $h4 'config.toml')
    Check 'SCAN' 'unterminated multi-line array -> fatal' (-not $c4.Ok -and $c4.Reason -match 'unterminated array') $c4.Reason
    $h5 = New-Home 'bare-secret' (Toml "model = `"gpt-5.1`"`n[model_providers.X]`nexperimental_bearer_token = sk-proj-SECRET456`n")
    $c5 = Read-CodexConfigSubset -Path (Join-Path $h5 'config.toml')
    Check 'SCAN' 'an unquoted (invalid) value is fatal and never echoed: the key is shown, the value masked' (-not $c5.Ok -and $c5.Reason -match 'line 3: experimental_bearer_token = \.\.\.' -and $c5.Reason -notmatch 'SECRET') $c5.Reason
}

# =============================================================== F02-2: compatibility fingerprint
if (Want 'FP') {
    $variants = [ordered]@{
        'base'           = "[model_providers.P]`nname = `"A`"`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"K1`"`nwire_api = `"responses`"`n"
        'reordered'      = "[model_providers.P]`nwire_api = `"responses`"`nenv_key = `"K1`"`nbase_url = `"https://api.z.ai/api/v1`"`nname = `"A`"`n"
        'comments'       = "# providers`n[model_providers.P]   # the P one`n`nname = `"A`" # n`n  base_url   =   `"https://api.z.ai/api/v1`"   # url`nenv_key = `"K1`"`n`nwire_api = `"responses`"`n"
        'env_key rotated'= "[model_providers.P]`nname = `"A`"`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"K2_ROTATED`"`nwire_api = `"responses`"`n"
        'name changed'   = "[model_providers.P]`nname = `"Another display name`"`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"K1`"`nwire_api = `"responses`"`n"
        'quoted key'     = "[model_providers.`"P`"]`n`"name`" = `"A`"`n`"base_url`" = `"https://api.z.ai/api/v1`"`nenv_key = `"K1`"`nwire_api = `"responses`"`n"
        'literal string' = "[model_providers.P]`nname = 'A'`nbase_url = 'https://api.z.ai/api/v1'`nenv_key = 'K1'`nwire_api = 'responses'`n"
        'trailing slash' = "[model_providers.P]`nname = `"A`"`nbase_url = `"https://api.z.ai/api/v1/`"`nenv_key = `"K1`"`nwire_api = `"responses`"`n"
        'scheme/host case'= "[model_providers.P]`nname = `"A`"`nbase_url = `"HTTPS://API.Z.AI/api/v1`"`nenv_key = `"K1`"`nwire_api = `"responses`"`n"
        'escape in url'  = "[model_providers.P]`nname = `"A`"`nbase_url = `"https://api.z.ai/api\u002Fv1`"`nenv_key = `"K1`"`nwire_api = `"responses`"`n"
    }
    $fps = [ordered]@{}
    foreach ($k in $variants.Keys) { $h = New-Home ('fp-' + ($k -replace '[^a-z]', '')) $variants[$k]; $fps[$k] = (Id (Join-Path $h 'config.toml') 'P' 'glm-5.3').Fingerprint }
    $base = $fps['base']
    Check 'FP' 'fingerprint is 64 hex' ($base -match '^[0-9a-f]{64}$') $base
    foreach ($k in @($variants.Keys | Where-Object { $_ -ne 'base' })) {
        Check 'FP' "same fingerprint: $k" ($fps[$k] -eq $base) "$(Format-ShortHash $fps[$k]) vs $(Format-ShortHash $base)"
    }
    $diff = [ordered]@{
        'base_url path changed' = "[model_providers.P]`nbase_url = `"https://api.z.ai/api/v2`"`nwire_api = `"responses`"`n"
        'base_url host changed' = "[model_providers.P]`nbase_url = `"https://open.bigmodel.cn/api/v1`"`nwire_api = `"responses`"`n"
        'path case changed'     = "[model_providers.P]`nbase_url = `"https://api.z.ai/API/v1`"`nwire_api = `"responses`"`n"
        'wire_api chat'         = "[model_providers.P]`nbase_url = `"https://api.z.ai/api/v1`"`nwire_api = `"chat`"`n"
        'wire_api absent'       = "[model_providers.P]`nname = `"A`"`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"K1`"`n"
    }
    foreach ($k in $diff.Keys) {
        $h = New-Home ('fpd-' + ($k -replace '[^a-z]', '')) $diff[$k]
        $f = (Id (Join-Path $h 'config.toml') 'P' 'glm-5.3').Fingerprint
        Check 'FP' "different fingerprint: $k" ($f -match '^[0-9a-f]{64}$' -and $f -ne $base) "$(Format-ShortHash $f) vs $(Format-ShortHash $base)"
    }
    $hb = New-Home 'fp-builtin' "model = `"gpt-5.1`"`n"
    $b1 = Id (Join-Path $hb 'config.toml')
    $b2 = Id (Join-Path $hb 'config.toml') '' '' 'https://proxy.example/v1'
    Check 'FP' 'built-in openai: builtin:openai identity; OPENAI_BASE_URL (honoured by Codex) changes it' ($b1.CompatString -eq 'cc-provider-v1|builtin:openai' -and $b2.CompatString -eq 'cc-provider-v1|builtin:openai|base_url=https://proxy.example/v1' -and $b1.Fingerprint -ne $b2.Fingerprint) "$($b1.CompatString) / $($b2.CompatString)"
}

# =============================================================== F02-1: identity resolved from the config (A8.1)
if (Want 'F02-1') {
    $r = New-Repo 'id'
    $h = New-Home 'zai-default' ("model_provider = `"ZAI`"`nmodel = `"glm-5.3`"`n`n" + $zaiTable)
    $d = Consult $r $h @('-DryRun', '-Prompt', 'x')
    $p = $d.Preview
    Check 'F02-1' 'config model_provider=ZAI, no -Provider: preview records ZAI (source config), lineage ZAI :: glm-5.3' ($d.Code -eq 0 -and $p.reviewer.provider -eq 'ZAI' -and $p.reviewer.provider_source -eq 'config' -and $p.lineage -eq 'ZAI :: glm-5.3') "provider=$($p.reviewer.provider) source=$($p.reviewer.provider_source) lineage=$($p.lineage)"
    Check 'F02-1' 'planned argv pins the same routing: -m glm-5.3 and -c model_provider="ZAI" before -o' ($p.command -match ' -m glm-5\.3 .*-c model_provider="ZAI" -o ') $p.command
    $log = Join-Path $work 'id-log.txt'
    $x = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'zai') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log }
    $e = Last-Entry $r
    $args1 = ([IO.File]::ReadAllText($log) -split "`n")[0]
    Check 'F02-1' 'real run: codex received model_provider=ZAI and -m glm-5.3; ledger reviewer = ZAI :: glm-5.3 from config' ($x.Code -eq 0 -and $args1 -match 'model_provider=""ZAI""' -and $args1 -match '-m glm-5\.3' -and $e.reviewer.provider -eq 'ZAI' -and $e.lineage -eq 'ZAI :: glm-5.3' -and $e.model -eq 'glm-5.3') $args1
    $md = [IO.File]::ReadAllText((Join-Path $r ".collab\t\$($e.reply)"))
    Check 'F02-1' 'reply header carries the Reviewer line' ($md -match '(?m)^Reviewer: ZAI :: glm-5\.3 \(provider from config, model from config; endpoint https://api\.z\.ai/api/v1, wire_api: responses; provider fingerprint [0-9a-f]{12}; harness codex-cli 0\.155\.1-fake\)\.$') (($md -split "`n") | Where-Object { $_ -match '^Reviewer' })

    $h2 = New-Home 'no-provider' "model = `"gpt-5.1`"`n"
    $d2 = Consult $r $h2 @('-DryRun', '-Prompt', 'x', '-Mode', 'new')
    Check 'F02-1' 'config without model_provider -> openai :: gpt-5.1 (codex default), argv -c model_provider="openai"' ($d2.Preview.lineage -eq 'openai :: gpt-5.1' -and $d2.Preview.reviewer.provider_source -eq 'codex default' -and $d2.Preview.command -match 'model_provider="openai"') $d2.Preview.lineage

    $h3 = New-Home 'unreadable' "model = `"gpt-5.1`"`nthis is not toml`n"
    $d3 = Consult $r $h3 @('-DryRun', '-Prompt', 'x', '-Model', 'gpt-5.1', '-NativeEffort', 'high')
    Check 'F02-1' 'unreadable config (fatal line) -> provider unknown, lineage unknown :: gpt-5.1, fingerprint empty, mode new with a note' ($d3.Code -eq 0 -and $d3.Preview.reviewer.provider -eq 'unknown' -and $d3.Preview.lineage -eq 'unknown :: gpt-5.1' -and $d3.Preview.reviewer.provider_fingerprint -eq '' -and $d3.Preview.mode -eq 'new' -and $d3.Out -match 'parent      : reviewer identity unresolved') (Line $d3.Out 'parent')
    Check 'F02-1' 'unreadable config: no -c model_provider is passed (the provider is not known)' ($d3.Preview.command -notmatch 'model_provider') $d3.Preview.command
    $d3f = Consult $r $h3 @('-DryRun', '-Prompt', 'x', '-Model', 'gpt-5.1', '-NativeEffort', 'high', '-Mode', 'fork')
    Check 'F02-1' 'unreadable config: -Mode fork refused' ($d3f.Code -eq 1 -and $d3f.First -match 'provider identity could not be resolved \(unsupported TOML construct at line 2.*\); pass -Provider and -Model explicitly, or use -Mode new') $d3f.First
    $x3 = Consult $r $h3 @('-Prompt', 'x', '-Model', 'gpt-5.1', '-NativeEffort', 'high', '-Mode', 'new', '-ReplyName', 'unres', '-SkipPreflight') @{ FAKE_CODEX_REPLY = $advise }
    $e3 = Last-Entry $r
    Check 'F02-1' 'unreadable config: -Mode new runs and records unknown provenance (fingerprint "", identity_note)' ($x3.Code -eq 0 -and $e3.reviewer.provider -eq 'unknown' -and $e3.reviewer.provider_fingerprint -eq '' -and $e3.reviewer.identity_note -match 'line 2') $e3.reviewer.identity_note

    $h4 = New-Home 'dir-config' $null
    [void][IO.Directory]::CreateDirectory((Join-Path $h4 'config.toml'))
    $d4 = Consult $r $h4 @('-DryRun', '-Prompt', 'x', '-Model', 'gpt-5.1', '-NativeEffort', 'high', '-Mode', 'resume')
    Check 'F02-1' 'config that cannot be read at all (a directory) -> -Mode resume refused' ($d4.Code -eq 1 -and $d4.First -match 'could not be read: it is not a file') $d4.First

    $h5 = New-Home 'inline' ("model = `"gpt-5.1`"`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nquery_params = { api-version = `"2025`" }`n")
    $d5 = Consult $r $h5 @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3')
    Check 'F02-1' 'provider table with an inline table value -> -Provider refused with the line number' ($d5.Code -eq 1 -and $d5.First -match '\[model_providers\.ZAI\] in .* is not usable - unsupported TOML construct at line 4: query_params = \{') $d5.First

    $h6 = New-Home 'profile' ("profile = `"fast`"`nmodel = `"gpt-5.1`"`n[profiles.fast]`nmodel_provider = `"ZAI`"`n" + $zaiTable)
    $d6 = Consult $r $h6 @('-DryRun', '-Prompt', 'x')
    Check 'F02-1' 'a config that selects a profile -> identity unresolved, mode new, note names the profile' ($d6.Code -eq 0 -and $d6.Preview.mode -eq 'new' -and $d6.Preview.reviewer.provider_fingerprint -eq '' -and $d6.Preview.reviewer.identity_note -match "selects profile 'fast'") $d6.Preview.reviewer.identity_note
    $h7 = New-Home 'none' $null
    $d7 = Consult $r $h7 @('-DryRun', '-Prompt', 'x')
    Check 'F02-1' 'no config file: openai (codex default) / model unknown -> unresolved, mode new' ($d7.Code -eq 0 -and $d7.Preview.lineage -eq 'openai :: unknown' -and $d7.Preview.mode -eq 'new' -and $d7.Preview.command -notmatch ' -m ') $d7.Preview.reviewer.identity_note
    $d7b = Consult $r $h7 @('-DryRun', '-Prompt', 'x', '-Model', 'gpt-5.1')
    Check 'F02-1' 'no config file + -Model: openai :: gpt-5.1 resolved (builtin)' ($d7b.Preview.lineage -eq 'openai :: gpt-5.1' -and $d7b.Preview.reviewer.provider_fingerprint -match '^[0-9a-f]{64}$') $d7b.Preview.lineage
    $e1 = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI')
    $e2 = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'nope', '-Model', 'x')
    Check 'F02-1' '-Provider without -Model refused; unknown -Provider refused listing the providers found' ($e1.Code -eq 1 -and $e1.First -match '-Provider needs -Model' -and $e2.Code -eq 1 -and $e2.First -match "unknown provider 'nope'.*providers found: ZAI \(built in: openai\)") "$($e1.First) / $($e2.First)"
}

# =============================================================== parents: lineage-scoped selection (A8.3)
if (Want 'PARENT') {
    $r = New-Repo 'parent'
    $h = New-Home 'parent' $baseToml
    $cfgPath = Join-Path $h 'config.toml'
    $idO = Id $cfgPath
    $idZ = Id $cfgPath 'ZAI' 'glm-5.3'
    $t = @{}
    foreach ($k in @('O1', 'Z1', 'O2', 'Z2', 'L1', 'L2', 'U1', 'C1')) { $t[$k] = [guid]::NewGuid().ToString() }
    function New-Entry { param($N, $Thread, $Identity, [switch]$Legacy, [switch]$Unresolved, $Candidate = '')
        if ($Legacy) { return [pscustomobject]@{ n = $N; purpose = 'framing'; thread = $Thread; thread_source = 'events'; mode = 'new'; model = 'config default'; reply = ('handoffs/{0:D2}-codex-seed.md' -f ($N + 1)) } }
        $fp = if ($Unresolved) { '' } else { $Identity.Fingerprint }
        $prov = if ($Unresolved) { 'unknown' } else { $Identity.Provider }
        $mod = if ($Unresolved) { 'gpt-5.1' } else { $Identity.Model }
        $lin = Format-Lineage -Provider $prov -Model $mod
        return [pscustomobject]@{ n = $N; purpose = 'framing'; consult_id = [guid]::NewGuid().ToString(); reviewer = [pscustomobject]@{ provider = $prov; model = $mod; provider_fingerprint = $fp }; lineage = $lin; thread = $Thread; thread_source = $(if ($Thread) { 'events' } else { 'unknown' }); thread_candidate = $Candidate; mode = 'new'; reply = ('handoffs/{0:D2}-codex-seed.md' -f ($N + 1)) }
    }
    $consults = @(
        (New-Entry 1 $t.L1 $null -Legacy),
        (New-Entry 2 $t.O1 $idO),
        (New-Entry 3 $t.Z1 $idZ),
        (New-Entry 4 $t.O2 $idO),
        (New-Entry 5 $t.Z2 $idZ),
        (New-Entry 6 $t.L2 $null -Legacy),
        (New-Entry 7 $t.U1 $null -Unresolved),
        (New-Entry 8 '' $idO -Candidate $t.C1)
    )
    Write-JsonFile -Path (Join-Path $r '.collab\t\sessions.json') -Object ([pscustomobject]@{ task_id = 't'; cwd = $r; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$consults } })
    $a = Consult $r $h @('-DryRun', '-Prompt', 'x')
    Check 'PARENT' 'default run forks the newest openai :: gpt-5.1 thread (O2), not the newer legacy/unresolved ones' ($a.Preview.mode -eq 'fork' -and $a.Preview.parent_thread -eq $t.O2 -and $a.Preview.command -match "fork $($t.O2) -$") "parent=$($a.Preview.parent_thread) O2=$($t.O2)"
    $b = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3')
    Check 'PARENT' '-Provider ZAI -Model glm-5.3 forks the newest ZAI thread (Z2)' ($b.Preview.mode -eq 'fork' -and $b.Preview.parent_thread -eq $t.Z2) "parent=$($b.Preview.parent_thread) Z2=$($t.Z2)"
    $c = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-4.6')
    Check 'PARENT' 'no thread of lineage ZAI :: glm-4.6 -> mode new with a note naming legacy/other/unresolved/candidates' ($c.Preview.mode -eq 'new' -and $c.Out -match "parent      : no thread of lineage ZAI :: glm-4\.6 in this task's ledger; 2 thread\(s\) recorded before 0\.3\.0 have unknown provenance and are never automatic parents; other lineage\(s\): ZAI :: glm-5\.3, openai :: gpt-5\.1; 1 thread\(s\) of runs with an unresolved reviewer identity are never parents; 1 unverified rollout candidate\(s\) are never parents") (Line $c.Out 'parent')
    $d = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-Thread', $t.O1)
    Check 'PARENT' 'cross-lineage -Thread refused' ($d.Code -eq 1 -and $d.First -match "thread $($t.O1) belongs to lineage openai :: gpt-5\.1 \(consult n=2\); this run is ZAI :: glm-5\.3") $d.First
    $u = [guid]::NewGuid().ToString()
    $e = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Thread', $u)
    Check 'PARENT' 'unknown uuid as -Thread refused (unknown provenance)' ($e.Code -eq 1 -and $e.First -match "thread $u has unknown provenance: it is not in this task's ledger; use -Mode new") $e.First
    $f = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Thread', $t.L2)
    Check 'PARENT' 'legacy thread as -Thread refused' ($f.Code -eq 1 -and $f.First -match "thread $($t.L2) has unknown provenance \(recorded before 0\.3\.0\); use -Mode new") $f.First
    $g = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Thread', $t.U1)
    Check 'PARENT' 'thread of an unresolved-identity run as -Thread refused' ($g.Code -eq 1 -and $g.First -match 'ran with an unresolved reviewer identity') $g.First
    $i = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Thread', $t.C1)
    Check 'PARENT' 'unverified rollout candidate as -Thread refused' ($i.Code -eq 1 -and $i.First -match 'only an unverified rollout candidate of consult n=8') $i.First
    $j = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Thread', $t.Z1, '-Mode', 'new')
    Check 'PARENT' '-Thread with -Mode new refused' ($j.Code -eq 1 -and $j.First -match '-Thread needs -Mode fork or resume') $j.First
    $k = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-Thread', $t.Z1, '-Mode', 'resume')
    Check 'PARENT' 'an older thread of the same lineage via -Thread -Mode resume is accepted' ($k.Code -eq 0 -and $k.Preview.mode -eq 'resume' -and $k.Preview.command -match "resume $($t.Z1) -$") $k.Preview.command
    # drift: the ZAI endpoint changes in the config after the threads were recorded
    [IO.File]::WriteAllText($cfgPath, ($baseToml -replace 'api/v1', 'api/paas/v4'), $u8)
    $l = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3')
    Check 'PARENT' 'fingerprint drift (base_url edited) -> automatic fork refused' ($l.Code -eq 1 -and $l.First -match "endpoint or protocol of provider ZAI changed since thread $($t.Z2) \(consult n=5 recorded provider fingerprint [0-9a-f]{12}, now [0-9a-f]{12}\); start a new thread with -Mode new") $l.First
    $m = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-Mode', 'resume', '-Thread', $t.Z1)
    Check 'PARENT' 'fingerprint drift -> explicit resume of an older thread refused' ($m.Code -eq 1 -and $m.First -match 'endpoint or protocol of provider ZAI changed') $m.First
    $n = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-Mode', 'new')
    Check 'PARENT' 'fingerprint drift -> -Mode new allowed' ($n.Code -eq 0 -and $n.Preview.mode -eq 'new' -and $n.Preview.parent_thread -eq '') "code=$($n.Code) mode=$($n.Preview.mode)"
    [IO.File]::WriteAllText($cfgPath, ($baseToml -replace 'wire_api = "responses"', 'wire_api = "chat"'), $u8)
    $o = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3')
    Check 'PARENT' 'fingerprint drift (wire_api edited) -> fork refused' ($o.Code -eq 1 -and $o.First -match 'endpoint or protocol of provider ZAI changed') $o.First
    [IO.File]::WriteAllText($cfgPath, ($baseToml -replace 'ZAI_KEY_A', 'ZAI_KEY_ROTATED' -replace 'Z.ai GLM Coding Plan', 'renamed'), $u8)
    $q = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3')
    Check 'PARENT' 'env_key rotated + name changed -> still the same endpoint, fork Z2 allowed' ($q.Code -eq 0 -and $q.Preview.parent_thread -eq $t.Z2) "code=$($q.Code) parent=$($q.Preview.parent_thread)"

    # a real chain: run 1 new, run 2 forks run 1's thread automatically
    $r2 = New-Repo 'chain'
    $h2 = New-Home 'chain' $baseToml
    $x1 = Consult $r2 $h2 @('-Prompt', 'x', '-ReplyName', 'one') @{ FAKE_CODEX_REPLY = $advise }
    $first = Last-Entry $r2
    $log = Join-Path $work 'chain-log.txt'
    $x2 = Consult $r2 $h2 @('-Prompt', 'x', '-ReplyName', 'two') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log }
    $second = Last-Entry $r2
    $args2 = ([IO.File]::ReadAllText($log) -split "`n")[0]
    Check 'PARENT' 'real chain: run 2 forks run 1 (same lineage), codex argv ends with fork <thread1> -' ($x1.Code -eq 0 -and $x2.Code -eq 0 -and $first.mode -eq 'new' -and $second.mode -eq 'fork' -and $second.parent_thread -eq $first.thread -and $args2 -match "fork $($first.thread) -$") "parent=$($second.parent_thread) thread1=$($first.thread)"
}

# =============================================================== F02-3: rollout fallback verified by the consultation id
if (Want 'F02-3') {
    $r = New-Repo 'rollout'
    $h = New-Home 'rollout' $baseToml
    $rl = Join-Path $work 'rollout-log.txt'
    $x = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'ours') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_NOTHREAD = '1'; FAKE_CODEX_ROLLOUT = 'ours'; FAKE_CODEX_ROLLOUT_LOG = $rl }
    $e = Last-Entry $r
    $ours = ((Get-Content $rl) -split ' ')[1]
    Check 'F02-3' 'no thread.started + a rollout containing the consultation id -> thread verified' ($x.Code -eq 0 -and $e.thread -eq $ours -and $e.thread_source -eq 'rollout (verified by consultation id)' -and $e.thread_candidate -eq '') "thread=$($e.thread) source=$($e.thread_source)"
    $x2 = Consult $r $h @('-Prompt', 'x', '-Mode', 'new', '-ReplyName', 'foreign') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_NOTHREAD = '1'; FAKE_CODEX_ROLLOUT = 'foreign'; FAKE_CODEX_ROLLOUT_LOG = $rl }
    $e2 = Last-Entry $r
    $foreign = ((Get-Content $rl) -split ' ')[1]
    $md2 = [IO.File]::ReadAllText((Join-Path $r ".collab\t\$($e2.reply)"))
    Check 'F02-3' 'a newer unrelated rollout (no consultation id) -> thread "", source unknown, thread_candidate recorded' ($x2.Code -eq 0 -and $e2.thread -eq '' -and $e2.thread_source -eq 'unknown' -and $e2.thread_candidate -eq $foreign) "thread='$($e2.thread)' candidate=$($e2.thread_candidate)"
    Check 'F02-3' 'the reply header says the candidate was not used' ($md2 -match "Result thread: \(unknown\) \(source: unknown; unverified rollout candidate ``$foreign`` did not contain this run's consultation id - not used as a thread or a parent\)") (($md2 -split "`n") | Where-Object { $_ -match 'Result thread' })
    Check 'F02-3' 'console says so too' ($x2.Out -match "thread     : unknown - rollout candidate $foreign did not contain consultation id") (Line $x2.Out 'thread     :')
    # the next automatic run must not fork the candidate: its newest verified parent is run 1
    $n = Consult $r $h @('-DryRun', '-Prompt', 'x')
    Check 'F02-3' 'next run: the candidate is never chosen; the verified rollout thread of run 1 is' ($n.Preview.parent_thread -eq $ours -and $n.Preview.parent_thread -ne $foreign) "parent=$($n.Preview.parent_thread)"
    $c = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Thread', $foreign)
    Check 'F02-3' '-Thread <candidate> refused' ($c.Code -eq 1 -and $c.First -match 'only an unverified rollout candidate') $c.First
    $r2 = New-Repo 'rollout2'
    $x3 = Consult $r2 $h @('-Prompt', 'x', '-ReplyName', 'both') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_NOTHREAD = '1'; FAKE_CODEX_ROLLOUT = 'ours+foreign'; FAKE_CODEX_ROLLOUT_LOG = $rl }
    $e3 = Last-Entry $r2
    $pairs = @(Get-Content $rl)
    $ours3 = ($pairs[0] -split ' ')[1]; $foreign3 = ($pairs[1] -split ' ')[1]
    Check 'F02-3' 'ours older + unrelated newer rollout -> ours (verified) is taken, not the newest' ($e3.thread -eq $ours3 -and $e3.thread -ne $foreign3 -and $e3.thread_source -eq 'rollout (verified by consultation id)') "thread=$($e3.thread) ours=$ours3 foreign=$foreign3"
    $r3 = New-Repo 'rollout3'
    $x4 = Consult $r3 $h @('-Prompt', 'x', '-ReplyName', 'solo') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_NOTHREAD = '1'; FAKE_CODEX_ROLLOUT = 'foreign'; FAKE_CODEX_ROLLOUT_LOG = $rl }
    $n4 = Consult $r3 $h @('-DryRun', '-Prompt', 'x')
    Check 'F02-3' 'a ledger holding only a candidate -> next run is new, note counts the candidate' ($n4.Preview.mode -eq 'new' -and $n4.Out -match '1 unverified rollout candidate\(s\) are never parents') (Line $n4.Out 'parent')
}

# =============================================================== F02-4: effort vocabularies by endpoint
if (Want 'F02-4') {
    $r = New-Repo 'effort'
    $toml = $baseToml + "`n[model_providers.zeta]`nbase_url = `"https://api.z.ai/api/v1/`"`nwire_api = `"responses`"`nenv_key = `"ZAI_KEY_A`"`n`n[model_providers.bigmodel]`nbase_url = `"https://open.bigmodel.cn/api/paas/v4`"`n`n[model_providers.local]`nbase_url = `"http://localhost:8080/v1`"`n"
    $h = New-Home 'effort' $toml
    $cases = @(
        @{ N = 'ZAI + -Effort xhigh'; A = @('-Provider', 'ZAI', '-Model', 'glm-5.3', '-Effort', 'xhigh'); Sent = 'max'; Map = 'zai-v1'; Req = 'xhigh' },
        @{ N = 'ZAI + checkpoint preset (medium)'; A = @('-Provider', 'ZAI', '-Model', 'glm-5.3', '-Purpose', 'checkpoint'); Sent = 'high'; Map = 'zai-v1'; Req = 'medium' },
        @{ N = 'alias zeta (same z.ai endpoint) + checkpoint'; A = @('-Provider', 'zeta', '-Model', 'glm-5.3', '-Purpose', 'checkpoint'); Sent = 'high'; Map = 'zai-v1'; Req = 'medium' },
        @{ N = 'alias zeta + core-contract (xhigh)'; A = @('-Provider', 'zeta', '-Model', 'glm-5.3', '-Purpose', 'core-contract'); Sent = 'max'; Map = 'zai-v1'; Req = 'xhigh' },
        @{ N = 'open.bigmodel.cn host + low'; A = @('-Provider', 'bigmodel', '-Model', 'glm-5.3', '-Effort', 'low'); Sent = 'low'; Map = 'zai-v1'; Req = 'low' },
        @{ N = 'built-in openai + medium -> identity'; A = @('-Effort', 'medium'); Sent = 'medium'; Map = 'openai'; Req = 'medium' },
        @{ N = 'built-in openai, any model (Codex validates its own) + xhigh'; A = @('-Model', 'some-future-model', '-Effort', 'xhigh'); Sent = 'xhigh'; Map = 'openai'; Req = 'xhigh' },
        @{ N = 'api.z.ai + declared glm-4.5-air + medium'; A = @('-Provider', 'ZAI', '-Model', 'glm-4.5-air', '-Effort', 'medium'); Sent = 'high'; Map = 'zai-v1'; Req = 'medium' }
    )
    foreach ($cs in $cases) {
        $d = Consult $r $h (@('-DryRun', '-Prompt', 'x', '-Mode', 'new') + $cs.A)
        $p = $d.Preview
        Check 'F02-4' "$($cs.N) -> sent $($cs.Sent), mapping $($cs.Map)" ($d.Code -eq 0 -and $p.effort_sent -eq $cs.Sent -and $p.effort -eq $cs.Sent -and $p.effort_mapping -eq $cs.Map -and $p.effort_requested -eq $cs.Req -and $null -eq $p.effort_confirmed -and $p.command -match ('model_reasoning_effort="' + $cs.Sent + '"')) "code=$($d.Code) requested=$($p.effort_requested) sent=$($p.effort_sent) mapping=$($p.effort_mapping) $(Line $d.Out 'effort')"
    }
    $u = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'local', '-Model', 'mistral-large')
    Check 'F02-4' 'undeclared host -> refused' ($u.Code -eq 1 -and $u.First -eq 'codex-consult: no effort vocabulary declared for localhost (caps-v1 declares api.kimi.ai, api.xiaomimimo.com, api.z.ai, ark.ap-southeast.bytepluses.com, builtin:openai, open.bigmodel.cn, token-plan-ams.xiaomimimo.com, token-plan-cn.xiaomimimo.com); pass -NativeEffort <value> to send a value verbatim') $u.First
    $ug = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'local', '-Model', 'glm-unknown')
    Check 'F02-4' 'glm-unknown on an unknown host -> refused (no model-prefix inference any more)' ($ug.Code -eq 1 -and $ug.First -match 'no effort vocabulary declared for localhost') $ug.First
    $uz = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-unlisted-9')
    Check 'F02-4' 'an unlisted model on api.z.ai -> refused, the message lists the declared models' ($uz.Code -eq 1 -and $uz.First -eq "codex-consult: no effort vocabulary declared for model 'glm-unlisted-9' on api.z.ai (caps-v1 declares: glm-5.3, glm-5.3-flash, glm-5.3-flashx, glm-5.2, glm-5.1, glm-5, glm-5-turbo, glm-4.7, glm-4.6, glm-4.5, glm-4.5-air); pass -NativeEffort <value> to send a value verbatim") $uz.First
    $uc = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'GLM-5.3')
    Check 'F02-4' 'declared models match exactly (GLM-5.3 is not glm-5.3) -> refused' ($uc.Code -eq 1 -and $uc.First -match "no effort vocabulary declared for model 'GLM-5\.3' on api\.z\.ai") $uc.First
    $hm = New-Home 'effort-mimo' ("model = `"gpt-5.1`"`n[model_providers.mimo]`nname = `"Xiaomi MiMo Token Plan`"`nbase_url = `"https://token-plan-ams.xiaomimimo.com/v1`"`nenv_key = `"ZAI_KEY_A`"`nwire_api = `"responses`"`n[model_providers.mimo-cn]`nbase_url = `"https://token-plan-cn.xiaomimimo.com/v1`"`nenv_key = `"ZAI_KEY_A`"`n[model_providers.mimo-api]`nbase_url = `"https://api.xiaomimimo.com/v1`"`nenv_key = `"ZAI_KEY_A`"`n")
    $m1 = Consult $r $hm @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-Effort', 'xhigh')
    Check 'F02-4' 'MiMo: -Provider mimo -Model mimo-v2.6-pro -Effort xhigh -> sent high, mapping mimo-v1, lineage mimo :: mimo-v2.6-pro' ($m1.Code -eq 0 -and $m1.Preview.effort_sent -eq 'high' -and $m1.Preview.effort_mapping -eq 'mimo-v1' -and $m1.Preview.effort_requested -eq 'xhigh' -and $m1.Preview.lineage -eq 'mimo :: mimo-v2.6-pro' -and $m1.Preview.command -match 'model_reasoning_effort="high"') "$($m1.Preview.effort_sent) $($m1.Preview.effort_mapping) $($m1.Preview.lineage)"
    $m2 = Consult $r $hm @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v9')
    Check 'F02-4' 'MiMo: undeclared mimo-v9 -> refused, the message lists the five declared models' ($m2.Code -eq 1 -and $m2.First -eq "codex-consult: no effort vocabulary declared for model 'mimo-v9' on token-plan-ams.xiaomimimo.com (caps-v1 declares: mimo-v2.6-pro, mimo-v2.6-flash, mimo-v2.6-pro-ultraspeed, mimo-v2.5-pro, mimo-v2.5); pass -NativeEffort <value> to send a value verbatim") $m2.First
    $m3 = Consult $r $hm @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-NativeEffort', 'none')
    Check 'F02-4' 'MiMo: -NativeEffort none -> sent verbatim, mapping native' ($m3.Code -eq 0 -and $m3.Preview.effort_sent -eq 'none' -and $m3.Preview.effort_mapping -eq 'native' -and $m3.Preview.command -match 'model_reasoning_effort="none"') "$($m3.Preview.effort_sent) $($m3.Preview.effort_mapping)"
    $m4 = Consult $r $hm @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo-cn', '-Model', 'mimo-v2.5', '-Purpose', 'checkpoint')
    $m5 = Consult $r $hm @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo-api', '-Model', 'mimo-v2.6-flash', '-Effort', 'low')
    Check 'F02-4' 'MiMo: token-plan-cn and api hosts use the same vocabulary (medium stays medium, low stays low)' ($m4.Code -eq 0 -and $m4.Preview.effort_sent -eq 'medium' -and $m4.Preview.effort_mapping -eq 'mimo-v1' -and $m5.Code -eq 0 -and $m5.Preview.effort_sent -eq 'low' -and $m5.Preview.effort_mapping -eq 'mimo-v1') "$($m4.Preview.effort_sent) / $($m5.Preview.effort_sent)"
    $ugn = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'local', '-Model', 'glm-unknown', '-NativeEffort', 'high')
    Check 'F02-4' 'glm-unknown on an unknown host with -NativeEffort -> native, effort_caps caps-v1' ($ugn.Code -eq 0 -and $ugn.Preview.effort_mapping -eq 'native' -and $ugn.Preview.effort_sent -eq 'high' -and $ugn.Preview.effort_caps -eq 'caps-v1') "$($ugn.Preview.effort_mapping) $($ugn.Preview.effort_caps)"
    $nv = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'local', '-Model', 'mistral-large', '-NativeEffort', 'deep')
    Check 'F02-4' '-NativeEffort deep -> sent verbatim, mapping native' ($nv.Code -eq 0 -and $nv.Preview.effort_sent -eq 'deep' -and $nv.Preview.effort_mapping -eq 'native' -and $nv.Preview.command -match 'model_reasoning_effort="deep"') "$($nv.Preview.effort_mapping) $($nv.Preview.effort_sent)"
    $nk = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-NativeEffort', 'medium')
    Check 'F02-4' '-NativeEffort also overrides a known vocabulary (ZAI medium sent as is)' ($nk.Preview.effort_sent -eq 'medium' -and $nk.Preview.effort_mapping -eq 'native') $nk.Preview.effort_sent
    $x = Consult $r $h @('-Prompt', 'x', '-Provider', 'zeta', '-Model', 'glm-5.3', '-Purpose', 'checkpoint', '-ReplyName', 'eff') @{ FAKE_CODEX_REPLY = $advise }
    $e = Last-Entry $r
    Check 'F02-4' 'ledger: effort_requested/effort_sent/effort_mapping/effort_confirmed(null); effort = effort_sent' ($x.Code -eq 0 -and $e.effort_requested -eq 'medium' -and $e.effort_sent -eq 'high' -and $e.effort -eq 'high' -and $e.effort_caps -eq 'caps-v1' -and $e.effort_mapping -eq 'zai-v1' -and $e.PSObject.Properties['effort_confirmed'] -and $null -eq $e.effort_confirmed) "requested=$($e.effort_requested) sent=$($e.effort_sent) mapping=$($e.effort_mapping)"
}

# =============================================================== F02-9: peak windows
if (Want 'F02-9') {
    function U { param([int]$Y, [int]$Mo, [int]$D, [int]$H, [int]$Mi, [int]$S = 0) return (New-Object DateTime($Y, $Mo, $D, $H, $Mi, $S, [DateTimeKind]::Utc)) }
    $spec = 'Mon-Fri 14:00-18:00 +08:00'
    $cases = @(
        @{ N = 'Thu 14:00 local (start, inclusive)'; T = (U 2026 9 24 6 0); S = $spec; E = $true },
        @{ N = 'Thu 17:59:59 local'; T = (U 2026 9 24 9 59 59); S = $spec; E = $true },
        @{ N = 'Thu 18:00 local (end, exclusive)'; T = (U 2026 9 24 10 0); S = $spec; E = $false },
        @{ N = 'Thu 13:59 local'; T = (U 2026 9 24 5 59); S = $spec; E = $false },
        @{ N = 'Sat 15:00 local (day not listed)'; T = (U 2026 9 26 7 0); S = $spec; E = $false },
        @{ N = 'overnight Fri 23:00'; T = (U 2026 9 25 23 0); S = 'Fri 22:00-06:00 +00:00'; E = $true },
        @{ N = 'overnight Sat 05:00 (window started Fri)'; T = (U 2026 9 26 5 0); S = 'Fri 22:00-06:00 +00:00'; E = $true },
        @{ N = 'overnight Sat 06:00 (end exclusive)'; T = (U 2026 9 26 6 0); S = 'Fri 22:00-06:00 +00:00'; E = $false },
        @{ N = 'overnight Sat 23:00 (Sat not listed)'; T = (U 2026 9 26 23 0); S = 'Fri 22:00-06:00 +00:00'; E = $false },
        @{ N = 'overnight Fri 05:00 (would have started Thu)'; T = (U 2026 9 25 5 0); S = 'Fri 22:00-06:00 +00:00'; E = $false },
        @{ N = 'negative offset: 08:59 local'; T = (U 2026 9 24 13 59); S = '* 09:00-17:00 -05:00'; E = $false },
        @{ N = 'negative offset: 09:00 local'; T = (U 2026 9 24 14 0); S = '* 09:00-17:00 -05:00'; E = $true },
        @{ N = 'list Mon,Wed on a Wednesday'; T = (U 2026 9 23 12 0); S = 'Mon,Wed 10:00-24:00 +00:00'; E = $true },
        @{ N = 'wrapping range Fri-Mon on a Sunday'; T = (U 2026 9 27 12 0); S = 'Fri-Mon 00:00-24:00 +00:00'; E = $true },
        @{ N = 'wrapping range Fri-Mon on a Tuesday'; T = (U 2026 9 29 12 0); S = 'Fri-Mon 00:00-24:00 +00:00'; E = $false }
    )
    foreach ($cs in $cases) {
        $st = Get-PeakStatus -Provider 'ZAI' -UtcNow $cs.T -Spec $cs.S -Except ''
        Check 'F02-9' "$($cs.N) -> peak $($cs.E)" ($st.Peak -eq $cs.E -and -not $st.Error) "peak=$($st.Peak) local=$($st.Local) $($st.Detail)"
    }
    $ex = Get-PeakStatus -Provider 'ZAI' -UtcNow (U 2026 10 3 12 0) -Spec '* 00:00-24:00 +00:00' -Except '2026-12-25, 2026-10-01..2026-10-07'
    $ex2 = Get-PeakStatus -Provider 'ZAI' -UtcNow (U 2026 10 8 12 0) -Spec '* 00:00-24:00 +00:00' -Except '2026-12-25, 2026-10-01..2026-10-07'
    Check 'F02-9' 'exception date inside a range -> off-peak all day; the day after -> peak; schedule records the exceptions' ($ex.Peak -eq $false -and $ex.Detail -match 'exception date 2026-10-03' -and $ex2.Peak -eq $true -and $ex.Schedule -eq '* 00:00-24:00 +00:00; except 2026-12-25, 2026-10-01..2026-10-07') "$($ex.Detail) / $($ex2.Detail) / $($ex.Schedule)"
    $ex3 = Get-PeakStatus -Provider 'ZAI' -UtcNow (U 2026 12 24 23 30) -Spec '* 00:00-24:00 +01:00' -Except '2026-12-25'
    Check 'F02-9' 'exception dates are calendar dates in the schedule offset (23:30Z = 00:30 +01:00 on the 25th)' ($ex3.Peak -eq $false) $ex3.Detail
    $unset = Get-PeakStatus -Provider 'ZAI' -UtcNow (U 2026 9 24 6 0) -Spec '' -Except ''
    Check 'F02-9' 'unset -> peak null (unknown), source none' ($null -eq $unset.Peak -and $unset.Source -eq 'none' -and $unset.Schedule -eq '') "peak=$($unset.Peak)"
    $bad = @(
        @{ S = 'Mon-Fri 14:00-1800 +08:00'; Tok = "bad token '14:00-1800'" },
        @{ S = 'Mon-Fry 14:00-18:00 +08:00'; Tok = "bad token 'Mon-Fry'" },
        @{ S = 'Mon-Fri 14:00-18:00'; Tok = "bad token 'Mon-Fri 14:00-18:00' \(2 field" },
        @{ S = 'Mon-Fri 14:00-18:00 +8'; Tok = "bad token '\+8'" },
        @{ S = 'Mon-Fri 14:00-14:00 +08:00'; Tok = "bad token '14:00-14:00'" },
        @{ S = 'Mon-Fri 25:00-26:00 +08:00'; Tok = "bad token '25:00-26:00'" },
        @{ S = '* 10:00-12:00 +15:00'; Tok = "bad token '\+15:00'" }
    )
    foreach ($b in $bad) {
        $st = Get-PeakStatus -Provider 'ZAI' -Spec $b.S -Except ''
        Check 'F02-9' "malformed '$($b.S)' -> error naming the variable and the token" ($st.Error -match '^CODEX_CONSULT_PEAK_ZAI=' -and $st.Error -match $b.Tok) $st.Error
    }
    $be = Get-PeakStatus -Provider 'ZAI' -Spec '* 00:00-24:00 +00:00' -Except '2026-13-01'
    Check 'F02-9' 'malformed _EXCEPT -> error naming CODEX_CONSULT_PEAK_ZAI_EXCEPT' ($be.Error -match "^CODEX_CONSULT_PEAK_ZAI_EXCEPT=.*bad token '2026-13-01'") $be.Error
    Check 'F02-9' 'variable name: provider upper-cased, other characters -> _' ((Get-PeakVariableName 'my-prov.x') -eq 'CODEX_CONSULT_PEAK_MY_PROV_X') (Get-PeakVariableName 'my-prov.x')

    # end to end
    $r = New-Repo 'peak'
    $h = New-Home 'peak' $baseToml
    $always = '* 00:00-24:00 +00:00'
    $x = Consult $r $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'peak') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_PEAK_ZAI = $always }
    $e = Last-Entry $r
    $md = [IO.File]::ReadAllText((Join-Path $r ".collab\t\$($e.reply)"))
    Check 'F02-9' 'inside the window: console WARNING, ledger peak true + schedule + source env, header warning' ($x.Code -eq 0 -and $x.Out -match 'WARNING: ZAI peak window \(\* 00:00-24:00 \+00:00\) - this consultation runs at peak tariff\.' -and $e.peak -eq $true -and $e.peak_schedule -eq $always -and $e.peak_source -eq 'env' -and $md -match 'WARNING: ZAI peak window .* ran at peak tariff') "peak=$($e.peak) schedule=$($e.peak_schedule)"
    $entriesBefore = @(Ledger $r).Count
    $y = Consult $r $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-OffPeakOnly', '-ReplyName', 'refused') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_PEAK_ZAI = $always }
    Check 'F02-9' '-OffPeakOnly inside the window -> refused before the lock (no ledger entry, no pending record)' ($y.Code -eq 1 -and $y.First -match '-OffPeakOnly: ZAI is inside its peak window \(\* 00:00-24:00 \+00:00; now ' -and @(Ledger $r).Count -eq $entriesBefore -and -not (Test-Path (Join-Path $r '.collab\t\.consult.pending.json'))) $y.First
    $hNow = [datetime]::UtcNow.Hour
    $s1 = ($hNow + 2) % 24; $s2 = ($hNow + 3) % 24
    $endTxt = if ($s2 -eq 0) { '24:00' } else { '{0:D2}:00' -f $s2 }
    $outside = ('* {0:D2}:00-{1} +00:00' -f $s1, $endTxt)
    $z = Consult $r $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-OffPeakOnly', '-ReplyName', 'offpeak') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_PEAK_ZAI = $outside }
    $ez = Last-Entry $r
    Check 'F02-9' 'outside the window: -OffPeakOnly runs, ledger peak false' ($z.Code -eq 0 -and $ez.peak -eq $false -and $ez.peak_schedule -eq $outside) "peak=$($ez.peak) schedule=$outside"
    $w = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-OffPeakOnly')
    Check 'F02-9' '-OffPeakOnly with no schedule -> refused (unknown is not off-peak)' ($w.Code -eq 1 -and $w.First -match 'no schedule for provider ZAI; -OffPeakOnly needs CODEX_CONSULT_PEAK_ZAI') $w.First
    $hu = New-Home 'peak-unres' "this is not toml`n"
    $wu = Consult $r $hu @('-DryRun', '-Prompt', 'x', '-Model', 'gpt-5.1', '-NativeEffort', 'high', '-OffPeakOnly')
    Check 'F02-9' '-OffPeakOnly with an unresolved provider -> refused' ($wu.Code -eq 1 -and $wu.First -match 'no schedule for provider unknown') $wu.First
    $v = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3') @{ CODEX_CONSULT_PEAK_ZAI = 'Mon-Fri 14:00-1800 +08:00' }
    Check 'F02-9' 'malformed spec -> refused naming the variable and the bad token (without -OffPeakOnly too)' ($v.Code -eq 1 -and $v.First -match "CODEX_CONSULT_PEAK_ZAI='Mon-Fri 14:00-1800 \+08:00' is malformed: bad token '14:00-1800'") $v.First
    $n = Consult $r $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'unset') @{ FAKE_CODEX_REPLY = $advise }
    $en = Last-Entry $r
    Check 'F02-9' 'unset -> ledger peak null, peak_schedule "", peak_source none' ($n.Code -eq 0 -and $en.PSObject.Properties['peak'] -and $null -eq $en.peak -and $en.peak_schedule -eq '' -and $en.peak_source -eq 'none') "peak=$($en.peak)"
}

# =============================================================== F02-5: requested checks convention (prompt + verbatim rendering)
if (Want 'F02-5') {
    $r = New-Repo 'rc'
    $h = New-Home 'rc' $baseToml
    $paragraph = '  If you want evidence you cannot obtain read-only, end reply_markdown with a section `## Requested checks` listing at most 5 items `RC1`..`RCn`, each ONE runnable command or procedure with its working directory, the permission it needs (read-only / workspace-write), the observation that would settle it, and a budget (time or scope); refer to a finding by its position in your findings array (`finding #2`), by an earlier id (`F04-1`) or by the invariant name. "Investigate X" is not a check. Omit the section if you need nothing.'
    $log = Join-Path $work 'rc-log.txt'
    $rcMd = "Answer.`n`n## Requested checks`n`n- **RC1** (finding #1) ``git status --porcelain`` in repo root [read-only] - expect: empty output; budget: 1 min`n- **RC2** (F04-1) ``cargo test cache`` in ``crates/cache`` [workspace-write] - expect: 14 passed; budget: 5 min"
    $reply = [pscustomobject]@{ schema_version = '1'; verdict = 'ADVISE'; verdict_reason = 'r'; reply_markdown = $rcMd; findings = @(); prior_findings = @(); unproven = @(); first_run_checklist = @() }
    $rp = Reply 'rc.json' (ConvertTo-Json -InputObject $reply -Depth 5 -Compress)
    $x = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'rc') @{ FAKE_CODEX_REPLY = $rp; FAKE_CODEX_LOG = $log }
    $prompt = ([IO.File]::ReadAllText($log) -split "PROMPT:`n", 2)[1]
    $e = Last-Entry $r
    $md = [IO.File]::ReadAllText((Join-Path $r ".collab\t\$($e.reply)"))
    Check 'F02-5' 'the prompt carries the requested-checks paragraph inside the reply_markdown instructions' ($prompt.Contains($paragraph) -and $prompt.IndexOf($paragraph) -gt $prompt.IndexOf('- reply_markdown:') -and $prompt.IndexOf($paragraph) -lt $prompt.IndexOf('- findings:')) ''
    Check 'F02-5' 'the prompt ends with "Consultation id: <consult_id>" (= ledger consult_id)' ($prompt.TrimEnd() -match "Consultation id: $([regex]::Escape($e.consult_id))$" -and $e.consult_id -match '^[0-9a-f-]{36}$') $e.consult_id
    Check 'F02-5' 'a reply ending with ## Requested checks renders verbatim; still a valid v1 reply' ($x.Code -eq 0 -and $e.structured -eq $true -and $md.Contains(($rcMd -replace "`r`n", "`n")) -and $e.schema -eq 'consult-reply v1') ''
    Check 'F02-5' 'nothing else changes: no requested_checks field in the ledger, no findings.json entries' (-not $e.PSObject.Properties['requested_checks'] -and -not (Test-Path (Join-Path $r '.collab\t\findings.json'))) ''
    $raw = Consult $r $h @('-DryRun', '-Raw', '-Prompt', 'x')
    Check 'F02-5' '-Raw prompt: no requested-checks paragraph, but the consultation id line is there' ($raw.Out -notmatch 'Requested checks' -and $raw.Out -match 'Consultation id: [0-9a-f-]{36}') ''
}

# =============================================================== LEDGER: field order + consult id in the recovery record
if (Want 'LEDGER') {
    $r = New-Repo 'ledger'
    $h = New-Home 'ledger' $baseToml
    $order = 'n,when,purpose,consult_id,reviewer,lineage,preflight,preflight_warning,roster,panel,parent_thread,thread,thread_source,thread_candidate,mode,command,brief,prompt_chars,reply,reply_json,events,model,effort,effort_requested,effort_sent,effort_mapping,effort_caps,effort_confirmed,max_words,sandbox,extra_config,extra_config_source,peak,peak_schedule,peak_source,peak_evaluated_at,structured,schema,schema_transport,schema_transport_source,validation_error,format_retry,denial_retry,base_commit,reviewed_revision,tree_sha256,tree_sha256_after,tree_changed_during_review,changed_files,brief_sha256,brief_sha256_after,brief_changed_during_review,fingerprint_note,artifacts,artifacts_changed_during_review,bridge_outcome,provider_failure,warnings,verdict,verdict_reason,findings,finding_ids,prior_findings,unchecked_prior_blockers,usage,wall_seconds,finished_at'
    $log = Join-Path $work 'ledger-log.txt'
    Clear-TestEnv
    $env:CODEX_HOME = $h; $env:FAKE_CODEX_SLEEP = '5'; $env:FAKE_CODEX_REPLY = $advise; $env:FAKE_CODEX_LOG = $log
    $bg = Start-Process -FilePath $psExe -WorkingDirectory $r -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $consultPs, '-Task', 't', '-CodexExe', $fake, '-Prompt', 'x', '-ReplyName', 'order')
    Clear-TestEnv
    $env:CODEX_HOME = $savedCodexHome
    $pend = Join-Path $r '.collab\t\.consult.pending.json'
    $midId = ''
    for ($i = 0; $i -lt 80; $i++) { $pr = Read-PendingFile -Path $pend; if ($pr.Record -and $pr.Record.state -eq 'running') { $midId = [string]$pr.Record.consult_id; break }; Start-Sleep -Milliseconds 250 }
    $bg.WaitForExit()
    $e = Last-Entry $r
    $names = ($e.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
    $revNames = ($e.reviewer.PSObject.Properties | ForEach-Object { $_.Name }) -join ','
    Check 'LEDGER' 'entry fields in the documented order' ($names -eq $order) $names
    Check 'LEDGER' 'reviewer fields: provider, provider_source, model, model_source, engine (0.4.0: codex), harness, provider_fingerprint, provider_config, identity_note' ($revNames -eq 'provider,provider_source,model,model_source,engine,harness,provider_fingerprint,provider_config,identity_note' -and $e.reviewer.engine -eq 'codex' -and @($e.warnings).Count -eq 0 -and $null -eq $e.denial_retry) $revNames
    Check 'LEDGER' 'the recovery record carries the consultation id while the run is in flight (= ledger consult_id)' ($midId -and $midId -eq $e.consult_id -and -not (Test-Path $pend)) "pending consult_id=$midId ledger=$($e.consult_id)"
    $guard = (-not $realConfigHash) -or ((Get-FileHash -Algorithm SHA256 -LiteralPath $realConfig).Hash -eq $realConfigHash)
    Check 'LEDGER' 'the user''s own Codex config was never modified (hash compared when it exists)' $guard $(if ($realConfigHash) { 'hash unchanged' } else { 'no user config on this machine' })
}
# =============================================================== KILL: Stop-ProcessTree waits for killed pids before judging survivors
if (Want 'KILL') {
    $r = New-Repo 'kill'
    $h = New-Home 'kill' $baseToml
    $pidFile = Join-Path $work 'kill-fake.pid'
    $pend = Join-Path $r '.collab\t\.consult.pending.json'
    for ($k = 1; $k -le 5; $k++) {
        if (Test-Path $pidFile) { Remove-Item $pidFile }
        $x = Consult $r $h @('-Prompt', 'x', '-Mode', 'new', '-ReplyName', "kill$k", '-TimeoutSec', '3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_SLEEP = '40'; FAKE_CODEX_PIDFILE = $pidFile }
        $e = Last-Entry $r
        $gpid = 0
        if (Test-Path $pidFile) { $gpid = [int](Get-Content $pidFile) }
        $lockHeld = $false
        try { $f = [IO.File]::Open((Join-Path $r '.collab\t\.consult.lock'), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None); $f.Dispose() } catch { $lockHeld = $true }
        Check 'KILL' "timeout run $k/5: tree killed, 0 survivors recorded, fake grandchild gone, no pending record, lock free" ($x.Code -eq 1 -and $e.bridge_outcome -eq 'failed: timeout after 3 s (process tree killed)' -and $gpid -gt 0 -and -not (Get-Process -Id $gpid -ErrorAction SilentlyContinue) -and -not (Test-Path $pend) -and -not $lockHeld) "outcome='$($e.bridge_outcome)' grandchild=$gpid"
    }
}
# =============================================================== OPENAI: user-defined [model_providers.openai] (GLM review point 1)
if (Want 'OPENAI') {
    $r = New-Repo 'openai'
    $builtinFp = Get-Sha256Hex ($u8.GetBytes('cc-provider-v1|builtin:openai'))
    $proxyFp = Get-Sha256Hex ($u8.GetBytes('cc-provider-v1|base_url=https://proxy.example/v1|wire_api=responses'))
    $tableA = "model = `"gpt-5.1`"`n[model_providers.openai]`nname = `"OpenAI via proxy`"`nbase_url = `"https://proxy.example/v1`"`nenv_key = `"OPENAI_PROXY_KEY`"`nwire_api = `"responses`"`n"
    $hA = New-Home 'openai-table' $tableA
    $idA = Id (Join-Path $hA 'config.toml')
    Check 'OPENAI' 'usable [model_providers.openai] table -> identity from the table (fingerprint of its base_url/wire_api), provider_source stays codex default, noted' ($idA.Resolved -and $idA.Provider -eq 'openai' -and $idA.ProviderSource -eq 'codex default' -and $idA.Fingerprint -eq $proxyFp -and $idA.Fingerprint -ne $builtinFp -and $idA.Note -eq 'user-defined [model_providers.openai] table used for the identity' -and $idA.ProviderConfig.base_url -eq 'https://proxy.example/v1' -and -not $idA.ProviderConfig.PSObject.Properties['builtin'] -and -not $idA.ProviderConfig.PSObject.Properties['env_key']) "fp=$(Format-ShortHash $idA.Fingerprint) note='$($idA.Note)' config=$(ConvertTo-Json -Compress $idA.ProviderConfig)"
    $hA2 = New-Home 'openai-table2' ($tableA -replace 'proxy\.example', 'proxy-two.example')
    $idA2 = Id (Join-Path $hA2 'config.toml')
    Check 'OPENAI' 'two different openai override tables -> two different fingerprints (no longer collapsed to builtin:openai)' ($idA2.Resolved -and $idA2.Fingerprint -ne $idA.Fingerprint) "$(Format-ShortHash $idA.Fingerprint) vs $(Format-ShortHash $idA2.Fingerprint)"
    $idAenv = Id (Join-Path $hA 'config.toml') '' '' 'https://elsewhere.example/v1'
    Check 'OPENAI' 'with a usable table OPENAI_BASE_URL is not part of the identity (the table is)' ($idAenv.Fingerprint -eq $idA.Fingerprint) (Format-ShortHash $idAenv.Fingerprint)
    $dA = Consult $r $hA @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high')
    Check 'OPENAI' 'dry run: ledger preview carries the table fingerprint + identity_note; console names the endpoint' ($dA.Code -eq 0 -and $dA.Preview.reviewer.provider_fingerprint -eq $proxyFp -and $dA.Preview.reviewer.identity_note -eq 'user-defined [model_providers.openai] table used for the identity' -and $dA.Out -match 'reviewer    : openai :: gpt-5\.1 \(provider from codex default, model from config; endpoint https://proxy\.example/v1, wire_api: responses; provider fingerprint [0-9a-f]{12}; user-defined \[model_providers\.openai\] table used for the identity; harness ') (Line $dA.Out 'reviewer')

    $hB = New-Home 'openai-bad' "model = `"gpt-5.1`"`n[model_providers.openai]`nbase_url = `"https://proxy.example/v1`"`nhttp_headers = { X-Route = `"b`" }`n"
    $dB = Consult $r $hB @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high')
    Check 'OPENAI' 'unusable [model_providers.openai] table -> identity unresolved with the scanner reason (line 4), fingerprint "", mode new' ($dB.Code -eq 0 -and $dB.Preview.reviewer.provider_fingerprint -eq '' -and $dB.Preview.mode -eq 'new' -and $dB.Preview.reviewer.identity_note -match "^Codex's default provider openai: \[model_providers\.openai\] in .* is not usable - unsupported TOML construct at line 4: http_headers = \{") $dB.Preview.reviewer.identity_note
    $dBf = Consult $r $hB @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high', '-Mode', 'fork')
    Check 'OPENAI' 'unusable openai table: -Mode fork refused (identity unresolved)' ($dBf.Code -eq 1 -and $dBf.First -match 'provider identity could not be resolved \(Codex''s default provider openai: ') $dBf.First
    $dBp = Consult $r $hB @('-DryRun', '-Prompt', 'x', '-Provider', 'openai', '-Model', 'gpt-5.1')
    Check 'OPENAI' 'unusable openai table + explicit -Provider openai -> refused like any explicit unusable provider' ($dBp.Code -eq 1 -and $dBp.First -match '\[model_providers\.openai\] in .* is not usable - unsupported TOML construct at line 4') $dBp.First

    $hC = New-Home 'openai-none' "model = `"gpt-5.1`"`n"
    $idC = Id (Join-Path $hC 'config.toml')
    $idCenv = Id (Join-Path $hC 'config.toml') '' '' 'https://proxy.example/v1/'
    Check 'OPENAI' 'no table: built in; OPENAI_BASE_URL stays part of the identity' ($idC.Fingerprint -eq $builtinFp -and $idCenv.CompatString -eq 'cc-provider-v1|builtin:openai|base_url=https://proxy.example/v1' -and $idCenv.Fingerprint -ne $builtinFp) "$($idC.CompatString) / $($idCenv.CompatString)"
    $dC = Consult $r $hC @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high') @{ OPENAI_BASE_URL = 'https://proxy.example/v1' }
    Check 'OPENAI' 'no table + OPENAI_BASE_URL in the environment: preview records it, console names it' ($dC.Code -eq 0 -and $dC.Preview.reviewer.provider_config.base_url_source -eq 'OPENAI_BASE_URL' -and $dC.Preview.reviewer.provider_fingerprint -eq $idCenv.Fingerprint -and $dC.Out -match 'endpoint builtin:openai via OPENAI_BASE_URL https://proxy\.example/v1') (Line $dC.Out 'reviewer')
}

# =============================================================== WIRE: absent wire_api asserts no protocol (GLM review point 2)
if (Want 'WIRE') {
    $absent1 = "[model_providers.P]`nbase_url = `"https://api.z.ai/api/v1`"`n"
    $absent2 = "# same, written differently`n[model_providers.P]   # p`nname = `"another name`"`n  base_url = 'HTTPS://api.z.ai/api/v1/'`n"
    $explicit = "[model_providers.P]`nbase_url = `"https://api.z.ai/api/v1`"`nwire_api = `"responses`"`n"
    $ids = @{}
    foreach ($k in @('absent1', 'absent2', 'explicit')) { $hh = New-Home "wire-$k" (Get-Variable -Name $k -ValueOnly); $ids[$k] = Id (Join-Path $hh 'config.toml') 'P' 'glm-5.3' }
    Check 'WIRE' 'absent wire_api vs explicit "responses" -> DIFFERENT fingerprints' ($ids.absent1.Fingerprint -match '^[0-9a-f]{64}$' -and $ids.absent1.Fingerprint -ne $ids.explicit.Fingerprint) "$(Format-ShortHash $ids.absent1.Fingerprint) vs $(Format-ShortHash $ids.explicit.Fingerprint)"
    Check 'WIRE' 'absent twice (formatting, name, slash, case differ) -> the SAME fingerprint; canonical string says wire_api=default' ($ids.absent1.Fingerprint -eq $ids.absent2.Fingerprint -and $ids.absent1.CompatString -eq 'cc-provider-v1|base_url=https://api.z.ai/api/v1|wire_api=default') $ids.absent1.CompatString
    Check 'WIRE' 'absent wire_api -> provider_config has no wire_api key; explicit -> it has' (-not $ids.absent1.ProviderConfig.PSObject.Properties['wire_api'] -and $ids.explicit.ProviderConfig.wire_api -eq 'responses') (ConvertTo-Json -Compress $ids.absent1.ProviderConfig)
    $r = New-Repo 'wire'
    $hw = New-Home 'wire-e2e' ("model = `"gpt-5.1`"`n" + $absent1 + "env_key = `"ZAI_KEY_A`"`n")
    $d = Consult $r $hw @('-DryRun', '-Prompt', 'x', '-Provider', 'P', '-Model', 'glm-5.3')
    Check 'WIRE' 'console reviewer line says "wire_api: (default)"' ($d.Code -eq 0 -and $d.Out -match 'reviewer    : P :: glm-5\.3 \(provider from -Provider, model from -Model; endpoint https://api\.z\.ai/api/v1, wire_api: \(default\); provider fingerprint ') (Line $d.Out 'reviewer')
    $x = Consult $r $hw @('-Prompt', 'x', '-Provider', 'P', '-Model', 'glm-5.3', '-ReplyName', 'wire') @{ FAKE_CODEX_REPLY = $advise }
    $e = Last-Entry $r
    $md = [IO.File]::ReadAllText((Join-Path $r ".collab\t\$($e.reply)"))
    Check 'WIRE' 'reply header says "wire_api: (default)"; ledger provider_config has no wire_api' ($x.Code -eq 0 -and $md -match '(?m)^Reviewer: P :: glm-5\.3 .*endpoint https://api\.z\.ai/api/v1, wire_api: \(default\);' -and -not $e.reviewer.provider_config.PSObject.Properties['wire_api']) (($md -split "`n") | Where-Object { $_ -match '^Reviewer' })
}

# =============================================================== EVENTS: drift nets only on session-start events (GLM review point 3)
if (Want 'EVENTS') {
    $r = New-Repo 'events'
    $h = New-Home 'events' $baseToml
    $foreign = [guid]::NewGuid().ToString()
    $pre = '{"type":"turn.started","session_id":"' + $foreign + '"}'
    $x = Consult $r $h @('-Prompt', 'x', '-Mode', 'new', '-ReplyName', 'ev1') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PRELINE = $pre }
    $e = Last-Entry $r
    $evLines = @(Get-Content (Join-Path $r ".collab\t\$($e.events)"))
    $started = ''
    foreach ($l in $evLines) { if ($l -match '"type":"thread.started","thread_id":"([0-9a-f-]{36})"') { $started = $Matches[1]; break } }
    Check 'EVENTS' 'foreign session_id on a turn.started line BEFORE thread.started -> the thread.started id is recorded' ($x.Code -eq 0 -and $evLines[0] -eq $pre -and $started -and $e.thread -eq $started -and $e.thread -ne $foreign -and $e.thread_source -eq 'events') "thread=$($e.thread) foreign=$foreign"
    $x2 = Consult $r $h @('-Prompt', 'x', '-Mode', 'new', '-ReplyName', 'ev2') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PRELINE = $pre; FAKE_CODEX_NOTHREAD = '1' }
    $e2 = Last-Entry $r
    Check 'EVENTS' 'foreign session_id and no thread.started (no rollout) -> thread "" (source unknown), never the foreign id' ($x2.Code -eq 0 -and $e2.thread -eq '' -and $e2.thread_source -eq 'unknown') "thread='$($e2.thread)' source=$($e2.thread_source)"
    $rl = Join-Path $work 'events-rollout.txt'
    $x3 = Consult $r $h @('-Prompt', 'x', '-Mode', 'new', '-ReplyName', 'ev3') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PRELINE = $pre; FAKE_CODEX_NOTHREAD = '1'; FAKE_CODEX_ROLLOUT = 'ours'; FAKE_CODEX_ROLLOUT_LOG = $rl }
    $e3 = Last-Entry $r
    $ours = ((Get-Content $rl) -split ' ')[1]
    Check 'EVENTS' '... then the rollout rule applies: the rollout holding the consultation id wins, not the foreign id' ($x3.Code -eq 0 -and $e3.thread -eq $ours -and $e3.thread -ne $foreign -and $e3.thread_source -eq 'rollout (verified by consultation id)') "thread=$($e3.thread) source=$($e3.thread_source)"
    $sid = [guid]::NewGuid().ToString()
    $x4 = Consult $r $h @('-Prompt', 'x', '-Mode', 'new', '-ReplyName', 'ev4') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_NOTHREAD = '1'; FAKE_CODEX_PRELINE = ('{"id":"0","msg":{"type":"session_configured","session_id":"' + $sid + '"}}') }
    $e4 = Last-Entry $r
    Check 'EVENTS' 'older msg-wrapped session_configured still names the thread (drift net 2)' ($x4.Code -eq 0 -and $e4.thread -eq $sid -and $e4.thread_source -eq 'events') "thread=$($e4.thread)"
    $sid2 = [guid]::NewGuid().ToString()
    $x5 = Consult $r $h @('-Prompt', 'x', '-Mode', 'new', '-ReplyName', 'ev5') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_NOTHREAD = '1'; FAKE_CODEX_PRELINE = ('{"type":"session.started","session_id":"' + $sid2 + '"}') }
    $e5 = Last-Entry $r
    Check 'EVENTS' 'top-level session.started with a session_id still names the thread (drift net 1)' ($x5.Code -eq 0 -and $e5.thread -eq $sid2 -and $e5.thread_source -eq 'events') "thread=$($e5.thread)"
    $x6 = Consult $r $h @('-Prompt', 'x', '-Mode', 'new', '-ReplyName', 'ev6') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_NOTHREAD = '1'; FAKE_CODEX_PRELINE = ('{"type":"item.completed","thread_id":"' + $foreign + '"}') }
    $e6 = Last-Entry $r
    Check 'EVENTS' 'a thread_id on any other event (item.completed) is ignored' ($x6.Code -eq 0 -and $e6.thread -eq '') "thread='$($e6.thread)'"
}
# =============================================================== F06-1: an override the scanner cannot read is not "no override"
if (Want 'F06-1') {
    $r = New-Repo 'f061'
    $fixtures = [ordered]@{
        'inline table at model_providers' = "model = `"gpt-6-astra`"`nmodel_providers = { openai = { base_url = `"https://proxy.example/v1`", wire_api = `"responses`" } }`n"
        'dotted key model_providers.openai' = "model = `"gpt-6-astra`"`nmodel_providers.openai = { base_url = `"https://proxy.example/v1`", wire_api = `"responses`" }`n"
        '[model_providers] openai = multi-line string' = "model = `"gpt-6-astra`"`n[model_providers]`nopenai = `"`"`"x`"`"`"`n"
        'dotted key four levels deep (model_providers.openai.http_headers.X)' = "model = `"gpt-6-astra`"`nmodel_providers.openai.http_headers.X = `"y`"`n"
    }
    $i = 0
    foreach ($k in $fixtures.Keys) {
        $i++
        $hh = New-Home "f061-$i" $fixtures[$k]
        $id = Id (Join-Path $hh 'config.toml')
        $d = Consult $r $hh @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high')
        $df = Consult $r $hh @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high', '-Mode', 'fork')
        $dr = Consult $r $hh @('-DryRun', '-Prompt', 'x', '-NativeEffort', 'high', '-Mode', 'resume')
        Check 'F06-1' "$k -> unresolved, empty fingerprint, mode new; fork and resume refused" (-not $id.Resolved -and $id.Fingerprint -eq '' -and $id.CompatString -eq '' -and $d.Code -eq 0 -and $d.Preview.mode -eq 'new' -and $d.Preview.reviewer.provider_fingerprint -eq '' -and $df.Code -eq 1 -and $df.First -match '^codex-consult: provider identity could not be resolved \(' -and $dr.Code -eq 1) $id.Note
    }
    $hOther = New-Home 'f061-other' "model = `"gpt-6-astra`"`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nhttp_headers = { A = `"b`" }`n"
    $idOther = Id (Join-Path $hOther 'config.toml')
    $hDot = New-Home 'f061-dot' "model = `"gpt-6-astra`"`nmodel_providers.ZAI.env_key = `"X`"`n"
    $idDot = Id (Join-Path $hDot 'config.toml')
    Check 'F06-1' 'constructs under ANOTHER provider (model_providers.ZAI.*) cannot declare openai: built-in openai still resolves' ($idOther.Resolved -and $idOther.CompatString -eq 'cc-provider-v1|builtin:openai' -and $idDot.Resolved -and $idDot.CompatString -eq 'cc-provider-v1|builtin:openai') "$($idOther.CompatString) / $($idDot.CompatString)"
    $hInl = New-Home 'f061-prov' $fixtures['inline table at model_providers']
    $pv = Providers $r $hInl @('-Provider', 'openai')
    Check 'F06-1' 'codex-providers: openai under an unreadable provider set -> unknown, exit 3' ($pv.Code -eq 3 -and $pv.Out -match 'unknown \(the providers could not be established: unsupported TOML construct at line 2: model_providers = ') (($pv.Out -split "`n") | Where-Object { $_ -match '^unknown' })
}

# =============================================================== F06-2: provider and model compared separately
if (Want 'F06-2') {
    $r = New-Repo 'f062'
    $hh = New-Home 'f062' "model = `"x`"`n[model_providers.`"a/b`"]`nbase_url = `"https://h.example/v1`"`nenv_key = `"ZAI_KEY_A`"`n[model_providers.a]`nbase_url = `"https://h.example/v1`"`nenv_key = `"ZAI_KEY_A`"`n"
    $cfgPath = Join-Path $hh 'config.toml'
    $i1 = Id $cfgPath 'a/b' 'c'
    $i2 = Id $cfgPath 'a' 'b/c'
    Check 'F06-2' 'identities a/b + c and a + b/c: same endpoint fingerprint, distinct unambiguous lineages' ($i1.Resolved -and $i2.Resolved -and $i1.Fingerprint -eq $i2.Fingerprint -and $i1.Lineage -eq 'a/b :: c' -and $i2.Lineage -eq 'a :: b/c') "$($i1.Lineage) | $($i2.Lineage)"
    $t1 = [guid]::NewGuid().ToString()
    $seed = [pscustomobject]@{ n = 1; purpose = 'framing'; consult_id = [guid]::NewGuid().ToString(); reviewer = [pscustomobject]@{ provider = 'a/b'; model = 'c'; provider_fingerprint = $i1.Fingerprint }; lineage = $i1.Lineage; thread = $t1; thread_source = 'events'; thread_candidate = ''; mode = 'new'; reply = 'handoffs/02-codex-seed.md' }
    Write-JsonFile -Path (Join-Path $r '.collab\t\sessions.json') -Object ([pscustomobject]@{ task_id = 't'; cwd = $r; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]@($seed) } })
    $auto = Consult $r $hh @('-DryRun', '-Prompt', 'x', '-Provider', 'a', '-Model', 'b/c', '-NativeEffort', 'high')
    Check 'F06-2' 'automatic: a + b/c does not fork the a/b + c thread (mode new)' ($auto.Code -eq 0 -and $auto.Preview.mode -eq 'new' -and $auto.Preview.parent_thread -eq '') "mode=$($auto.Preview.mode) parent='$($auto.Preview.parent_thread)'"
    $expl = Consult $r $hh @('-DryRun', '-Prompt', 'x', '-Provider', 'a', '-Model', 'b/c', '-NativeEffort', 'high', '-Mode', 'resume', '-Thread', $t1)
    Check 'F06-2' 'explicit -Mode resume -Thread of the other identity -> refused' ($expl.Code -eq 1 -and $expl.First -eq "codex-consult: thread $t1 belongs to lineage a/b :: c (consult n=1); this run is a :: b/c. A thread never changes provider or model: use -Mode new, or run as a/b :: c") $expl.First
    $same = Consult $r $hh @('-DryRun', '-Prompt', 'x', '-Provider', 'a/b', '-Model', 'c', '-NativeEffort', 'high')
    Check 'F06-2' 'the identity itself (a/b + c) still forks its own thread' ($same.Code -eq 0 -and $same.Preview.mode -eq 'fork' -and $same.Preview.parent_thread -eq $t1) "parent=$($same.Preview.parent_thread)"
}

# =============================================================== F06-3: peak evaluated again right before launch
if (Want 'F06-3') {
    $r = New-Repo 'f063'
    $h = New-Home 'f063' $baseToml
    $td = Join-Path $r '.collab\t'
    $pidFile = Join-Path $work 'f063.pid'
    $spec = '* 14:00-18:00 +08:00'
    $crossing = '2026-09-24T13:59:59+08:00,2026-09-24T14:00:00+08:00'
    if (Test-Path $pidFile) { Remove-Item $pidFile }
    $x = Consult $r $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-OffPeakOnly', '-ReplyName', 'crossing') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_PIDFILE = $pidFile; CODEX_CONSULT_PEAK_ZAI = $spec; CODEX_CONSULT_NOW = $crossing }
    $lockHeld = $false
    try { $f = [IO.File]::Open((Join-Path $td '.consult.lock'), [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None); $f.Dispose() } catch { $lockHeld = $true }
    $entries = @()
    if (Test-Path (Join-Path $td 'sessions.json')) { $entries = @(Ledger $r) }
    Check 'F06-3' 'early check off-peak (13:59:59), launch-time check at 14:00 -> -OffPeakOnly aborts before launch: no child, no ledger entry, no pending record, lock free' ($x.Code -eq 1 -and $x.First -eq 'codex-consult: -OffPeakOnly: ZAI entered its peak window before launch (* 14:00-18:00 +08:00; now 2026-09-24 14:00 Thu +08:00); nothing was started.' -and -not (Test-Path $pidFile) -and $entries.Count -eq 0 -and -not (Test-Path (Join-Path $td '.consult.pending.json')) -and -not $lockHeld) $x.First
    $y = Consult $r $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'crossing-no-gate') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_PEAK_ZAI = $spec; CODEX_CONSULT_NOW = $crossing }
    $ey = Last-Entry $r
    Check 'F06-3' 'same clock without -OffPeakOnly: runs; the ledger records the LAUNCH evaluation (peak true, 14:00:00, source env (CODEX_CONSULT_NOW)); the withdrawn reservation is reused (n=1)' ($y.Code -eq 0 -and $ey.peak -eq $true -and $ey.peak_evaluated_at -eq '2026-09-24T14:00:00+08:00' -and $ey.peak_source -eq 'env (CODEX_CONSULT_NOW)' -and $ey.n -eq 1 -and $ey.reply -eq 'handoffs/01-codex-crossing-no-gate.md' -and $y.Out -match 'WARNING: ZAI peak window') "peak=$($ey.peak) at=$($ey.peak_evaluated_at) source=$($ey.peak_source) n=$($ey.n)"
    $z = Consult $r $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-OffPeakOnly', '-ReplyName', 'offpeak') @{ FAKE_CODEX_REPLY = $advise; CODEX_CONSULT_PEAK_ZAI = $spec; CODEX_CONSULT_NOW = '2026-09-24T19:30:00+08:00' }
    $ez = Last-Entry $r
    Check 'F06-3' 'off-peak at both checks: -OffPeakOnly runs; peak false, peak_evaluated_at recorded' ($z.Code -eq 0 -and $ez.peak -eq $false -and $ez.peak_evaluated_at -eq '2026-09-24T19:30:00+08:00') "peak=$($ez.peak) at=$($ez.peak_evaluated_at)"
    $w = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3') @{ CODEX_CONSULT_PEAK_ZAI = $spec; CODEX_CONSULT_NOW = '2026-09-24 14:00' }
    Check 'F06-3' 'malformed CODEX_CONSULT_NOW -> refused naming it' ($w.Code -eq 1 -and $w.First -match "^codex-consult: CODEX_CONSULT_NOW='2026-09-24 14:00' is malformed: bad token '2026-09-24 14:00'") $w.First
    $v = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'realclock') @{ FAKE_CODEX_REPLY = $advise }
    $ev = Last-Entry $r
    $rawStamps = @([regex]::Matches((Get-Content -Raw (Join-Path $td 'sessions.json')), '"peak_evaluated_at":\s*"([^"]*)"') | ForEach-Object { $_.Groups[1].Value })
    $lastStamp = if ($rawStamps.Count -gt 0) { $rawStamps[-1] } else { '' }
    Check 'F06-3' 'real clock: peak_evaluated_at is the launch time (ISO with offset in the ledger), peak_source none without a schedule' ($v.Code -eq 0 -and $lastStamp -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$' -and $ev.peak_source -eq 'none' -and $null -eq $ev.peak) $lastStamp
}

# =============================================================== F06-4: exception intervals of any length
if (Want 'F06-4') {
    $in = Get-PeakStatus -Provider 'ZAI' -UtcNow (New-Object DateTime(2037, 1, 1, 12, 0, 0, [DateTimeKind]::Utc)) -Spec '* 00:00-24:00 +00:00' -Except '2026-01-01..2037-12-31'
    $after = Get-PeakStatus -Provider 'ZAI' -UtcNow (New-Object DateTime(2038, 1, 1, 12, 0, 0, [DateTimeKind]::Utc)) -Spec '* 00:00-24:00 +00:00' -Except '2026-01-01..2037-12-31'
    Check 'F06-4' '2037-01-01 inside 2026-01-01..2037-12-31 (12 years, beyond the old 3700-day guard) -> peak false; 2038-01-01 -> peak true' ($in.Peak -eq $false -and -not $in.Error -and $after.Peak -eq $true) "$($in.Detail) / $($after.Detail)"
    $huge = Get-PeakStatus -Provider 'ZAI' -UtcNow (New-Object DateTime(2999, 6, 1, 12, 0, 0, [DateTimeKind]::Utc)) -Spec '* 00:00-24:00 +00:00' -Except '1900-01-01..9999-12-31'
    $back = Get-PeakStatus -Provider 'ZAI' -Spec '* 00:00-24:00 +00:00' -Except '2026-02-01..2026-01-01'
    Check 'F06-4' 'an 8000-year range is fine; only end < start is refused' ($huge.Peak -eq $false -and $back.Error -match 'a range must not run backwards') $back.Error
}

# =============================================================== CODEXCFG: per-run Codex config overrides (-CodexConfig)
if (Want 'CODEXCFG') {
    $r = New-Repo 'codexcfg'
    $h = New-Home 'codexcfg' $baseToml
    # Codex does not expand ~: the bridge does (home directory, forward slashes)
    $homeFwd = ($(if ($HOME) { $HOME } else { $env:USERPROFILE })).TrimEnd([char]'\', [char]'/') -replace '\\', '/'
    $a = Consult $r $h @('-DryRun', '-Prompt', 'x', '-CodexConfig', 'model_catalog_json=~/.codex/x.json')
    $expA = 'model_catalog_json="' + $homeFwd + '/.codex/x.json"'
    Check 'CFG' '~/ is expanded (home, forward slashes, no tilde), quoted, passed as -c after the bridge''s own -c options, before -o; ledger extra_config' ($a.Code -eq 0 -and $a.Preview.command.Contains('-c model_provider="openai" -c ' + $expA + ' -o ') -and $a.Preview.command -notmatch '~' -and @($a.Preview.extra_config).Count -eq 1 -and @($a.Preview.extra_config)[0] -eq $expA) @($a.Preview.extra_config)[0]
    $a2 = Consult $r $h @('-DryRun', '-Prompt', 'x', '-CodexConfig', 'model_catalog_json=~\.codex\sub\x.json')
    Check 'CFG' '~\ with backslashes -> the same expansion with forward slashes throughout' ($a2.Code -eq 0 -and @($a2.Preview.extra_config)[0] -eq ('model_catalog_json="' + $homeFwd + '/.codex/sub/x.json"')) @($a2.Preview.extra_config)[0]
    $b = Consult $r $h @('-DryRun', '-Prompt', 'x', '-CodexConfig', 'model_catalog_json=~/a.json,tools.web_search=[1,2],model_reasoning_summary="detailed",hide_agent_reasoning=true')
    $bx = @($b.Preview.extra_config)
    Check 'CFG' 'one comma-separated string: split only where the next key= starts ([1,2] stays whole); literals stay verbatim' ($b.Code -eq 0 -and $bx.Count -eq 4 -and $bx[0] -eq ('model_catalog_json="' + $homeFwd + '/a.json"') -and $bx[1] -eq 'tools.web_search=[1,2]' -and $bx[2] -eq 'model_reasoning_summary="detailed"' -and $bx[3] -eq 'hide_agent_reasoning=true') ($bx -join ' | ')
    $c = Consult $r $h @('-DryRun', '-Prompt', 'x', '-CodexConfig', 'model=x')
    Check 'CFG' 'model=x refused' ($c.Code -eq 1 -and $c.First -eq "codex-consult: -CodexConfig 'model=x' is refused: model is part of the reviewer identity and effort the bridge records (use -Model / -Provider / -Effort; providers belong in the Codex config).") $c.First
    $refused = @()
    foreach ($k in @('model_provider=ZAI', 'profile=fast', 'model_reasoning_effort=high', 'model_providers.ZAI.base_url=https://x.example')) {
        $o = Consult $r $h @('-DryRun', '-Prompt', 'x', '-CodexConfig', $k)
        if ($o.Code -eq 1 -and $o.First -match 'is refused: .* is part of the reviewer identity') { $refused += $k }
    }
    Check 'CFG' 'model_provider, profile, model_reasoning_effort and model_providers.* are refused too' ($refused.Count -eq 4) ($refused -join ', ')
    $d = Consult $r $h @('-DryRun', '-Prompt', 'x', '-CodexConfig', 'no-equals-sign')
    Check 'CFG' 'a malformed item is refused' ($d.Code -eq 1 -and $d.First -eq "codex-consult: -CodexConfig 'no-equals-sign' is malformed: expected key=value (key: letters, digits, _ and .; a non-empty value).") $d.First
    $log = Join-Path $work 'codexcfg-log.txt'
    $x = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'cfg', '-CodexConfig', 'model_catalog_json=~/.codex/model-catalogs.json') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOG = $log }
    $args1 = ([IO.File]::ReadAllText($log) -split "`n")[0]
    $e = Last-Entry $r
    $expectArg = '-c "model_catalog_json=""' + $homeFwd + '/.codex/model-catalogs.json""" -o '
    Check 'CFG' 'real run: codex receives the expanded override before -o; the ledger records the expanded item' ($x.Code -eq 0 -and $args1.Contains($expectArg) -and @($e.extra_config)[0] -eq ('model_catalog_json="' + $homeFwd + '/.codex/model-catalogs.json"')) $args1
}

# =============================================================== TRANSPORT: how the reply schema reaches the endpoint
if (Want 'TRANSPORT') {
    $r = New-Repo 'transport'
    $h = New-Home 'transport' ($baseToml + "`n[model_providers.mimo]`nbase_url = `"https://token-plan-ams.xiaomimimo.com/v1`"`nenv_key = `"ZAI_KEY_A`"`nwire_api = `"responses`"`n`n[model_providers.local]`nbase_url = `"http://localhost:8080/v1`"`nenv_key = `"ZAI_KEY_A`"`n")
    function Get-DryPrompt { param([string]$Out) $m = [regex]::Match($Out, "(?s)prompt \(stdin, \d+ chars\):\n----\n(.*?)\n----\n"); if ($m.Success) { return $m.Groups[1].Value } else { return '' } }
    $m = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro')
    $mp = Get-DryPrompt $m.Out
    Check 'TRANSP' 'MiMo host -> no --output-schema; the prompt still carries the JSON instructions AND the schema itself; ledger prompt-only' ($m.Code -eq 0 -and $m.Preview.command -notmatch '--output-schema' -and $mp.Contains('Reply format: your final message must be exactly one JSON object - no code fence') -and $mp.Contains('JSON Schema of the reply:') -and $mp.Contains('"schema_version"') -and $m.Preview.schema_transport -eq 'prompt-only') (Line $m.Out 'transport')
    Check 'TRANSP' 'dry-run transport line for MiMo' ($m.Out -match 'transport   : prompt-only \(caps-v1: token-plan-ams\.xiaomimimo\.com\): --output-schema is NOT passed; the schema travels in the prompt, the reply is validated locally') (Line $m.Out 'transport')
    $z = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3')
    $b = Consult $r $h @('-DryRun', '-Prompt', 'x')
    Check 'TRANSP' 'z.ai host and built-in openai -> --output-schema passed, prompt unchanged (no embedded schema); ledger output-schema' ($z.Code -eq 0 -and $z.Preview.command -match '--output-schema ' -and $z.Preview.schema_transport -eq 'output-schema' -and -not (Get-DryPrompt $z.Out).Contains('JSON Schema of the reply:') -and $b.Code -eq 0 -and $b.Preview.command -match '--output-schema ' -and $b.Preview.schema_transport -eq 'output-schema' -and $b.Out -match 'transport   : output-schema \(caps-v1: builtin:openai\): passed as --output-schema') "$(Line $z.Out 'transport') | $(Line $b.Out 'transport')"
    $u = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'local', '-Model', 'some-model', '-NativeEffort', 'high')
    Check 'TRANSP' 'undeclared host -> prompt-only by default, and the dry run says so' ($u.Code -eq 0 -and $u.Preview.command -notmatch '--output-schema' -and $u.Preview.schema_transport -eq 'prompt-only' -and $u.Out -match 'transport   : prompt-only \(default for an endpoint caps-v1 does not declare: localhost\)') (Line $u.Out 'transport')
    $w = Consult $r $h @('-DryRun', '-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-Raw')
    Check 'TRANSP' '-Raw unchanged: no --output-schema, no schema block, schema_transport ""' ($w.Code -eq 0 -and $w.Preview.command -notmatch '--output-schema' -and -not (Get-DryPrompt $w.Out).Contains('JSON Schema of the reply:') -and $w.Preview.schema_transport -eq '') ''
    # a real MiMo-shaped run: the reply comes back fenced; parsed leniently, validated locally
    $fenced = Reply 'fenced.json' ("``````json`n" + '{"schema_version":"1","verdict":"ADVISE","verdict_reason":"r","reply_markdown":"m","findings":[],"prior_findings":[],"unproven":[],"first_run_checklist":[]}' + "`n``````")
    $log = Join-Path $work 'transport-log.txt'
    $x = Consult $r $h @('-Prompt', 'x', '-Provider', 'mimo', '-Model', 'mimo-v2.6-pro', '-ReplyName', 'mimo') @{ FAKE_CODEX_REPLY = $fenced; FAKE_CODEX_LOG = $log }
    $e = Last-Entry $r
    $md = [IO.File]::ReadAllText((Join-Path $r ".collab\t\$($e.reply)"))
    $args1 = ([IO.File]::ReadAllText($log) -split "`n")[0]
    Check 'TRANSP' 'real run: codex gets no --output-schema; a fenced reply validates locally; header says (prompt-only transport); ledger schema_transport' ($x.Code -eq 0 -and $args1 -notmatch '--output-schema' -and $e.structured -eq $true -and $e.schema_transport -eq 'prompt-only' -and $md -match 'Structured reply \(prompt-only transport\): `handoffs/') (($md -split "`n") | Where-Object { $_ -match 'Structured reply' })
}

# =============================================================== F09: fail-closed preflight, failure classes, endpoint health
if (Want 'F09') {
    $h = New-Home 'w9' ($baseToml + "`n[model_providers.zai-alias]`nbase_url = `"https://API.z.ai/api/v1/`"`nwire_api = `"responses`"`nenv_key = `"ZAI_KEY_A`"`n")
    $cfgPath = Join-Path $h 'config.toml'
    $zfp = (Id $cfgPath 'ZAI' 'glm-5.3').Fingerprint
    Check 'F09' 'the alias zai-alias is the same ENDPOINT as ZAI (same fingerprint)' ($zfp -and (Id $cfgPath 'zai-alias' 'glm-5.3').Fingerprint -eq $zfp) (Format-ShortHash $zfp)

    # ---- F09-1: unknown availability refuses unless -SkipPreflight
    $r = New-Repo 'w9-closed'
    $td = Join-Path $r '.collab\t'
    $pidFile = Join-Path $work 'w9-hang.pid'
    if (Test-Path $pidFile) { Remove-Item $pidFile }
    $a = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'hang') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOGIN = 'hang'; FAKE_CODEX_PIDFILE = $pidFile }
    Check 'F09-1' '`codex login status` hanging past 15 s -> refused, no codex child started, no ledger entry, no pending record' ($a.Code -eq 1 -and $a.First -eq 'codex-consult: provider openai: availability could not be established (`codex login status` did not finish within 15 s); pass -SkipPreflight to launch anyway, or fix the check' -and -not (Test-Path $pidFile) -and -not (Test-Path (Join-Path $td 'sessions.json')) -and -not (Test-Path (Join-Path $td '.consult.pending.json'))) $a.First
    $b = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'hang-skip', '-SkipPreflight') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOGIN = 'hang' }
    Check 'F09-1' '... launches with -SkipPreflight (no login check at all); ledger preflight "skipped"' ($b.Code -eq 0 -and (Last-Entry $r).preflight -eq 'skipped') (Last-Entry $r).preflight
    $hu = New-Home 'w9-unres' "model = `"gpt-5.1`"`nthis is not toml`n"
    $c = Consult $r $hu @('-Prompt', 'x', '-Model', 'gpt-5.1', '-NativeEffort', 'high', '-ReplyName', 'unres') @{ FAKE_CODEX_REPLY = $advise }
    Check 'F09-1' 'unresolved identity -> refused' ($c.Code -eq 1 -and $c.First -eq 'codex-consult: provider unknown: availability could not be established (reviewer identity unresolved: unsupported TOML construct at line 2: <not a key = value line; content not shown>); pass -SkipPreflight to launch anyway, or fix the check') $c.First
    $cd = Consult $r $hu @('-DryRun', '-Prompt', 'x', '-Model', 'gpt-5.1', '-NativeEffort', 'high')
    Check 'F09-1' '-DryRun still prints the verdict (exit 0)' ($cd.Code -eq 0 -and $cd.Out -match 'preflight   : unknown \(reviewer identity unresolved: .*\) - a real run is refused: provider unknown: availability could not be established') (Line $cd.Out 'preflight')
    $cs = Consult $r $hu @('-Prompt', 'x', '-Model', 'gpt-5.1', '-NativeEffort', 'high', '-ReplyName', 'unres-skip', '-SkipPreflight') @{ FAKE_CODEX_REPLY = $advise }
    Check 'F09-1' 'unresolved identity launches with -SkipPreflight' ($cs.Code -eq 0 -and (Last-Entry $r).preflight -eq 'skipped' -and (Last-Entry $r).reviewer.provider -eq 'unknown') ''

    # ---- F09-3: failure classes and the SSE payload
    $samples = [ordered]@{
        '401 Unauthorized: invalid API key' = 'auth'
        'Error: credits exhausted for this token plan' = 'quota'
        "text.format type 'json_schema' is not supported, only 'text' and 'json_object' are allowed." = 'capability'
        'stream error: connection reset by peer' = 'transport'
        'the model produced nothing' = 'unknown'
    }
    $bad = @($samples.Keys | Where-Object { (Get-ProviderFailureClass $_) -ne $samples[$_] })
    Check 'F09-3' 'Get-ProviderFailureClass: auth / quota / capability / transport / unknown samples' ($bad.Count -eq 0) ($bad -join ' | ')
    $mimoSse = 'data:{"error":{"code":"responses_feature_not_supported","message":"text.format type ''json_schema'' is not supported, only ''text'' and ''json_object'' are allowed.","param":"","type":"unsupported_feature"}}'
    $pf = New-ProviderFailure -Texts @($mimoSse)
    Check 'F09-3' 'the real MiMo SSE rejection -> capability, code responses_feature_not_supported, the message itself' ($pf.class -eq 'capability' -and $pf.code -eq 'responses_feature_not_supported' -and $pf.message -eq "text.format type 'json_schema' is not supported, only 'text' and 'json_object' are allowed.") "$($pf.class) $($pf.code) $($pf.message)"
    $r3 = New-Repo 'w9-failure'
    $x = Consult $r3 $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'auth-fail') @{ FAKE_CODEX_STDERR = 'data:{"error":{"code":"invalid_api_key","message":"401 Unauthorized: invalid API key"}}'; FAKE_CODEX_EXIT = '1' }
    $ex = Last-Entry $r3
    $mdx = [IO.File]::ReadAllText((Join-Path $r3 ".collab\t\$($ex.reply)"))
    Check 'F09-3' 'a failed run with an SSE error on stderr -> ledger provider_failure {auth, invalid_api_key, message, when}; header line' ($x.Code -eq 1 -and $ex.provider_failure.class -eq 'auth' -and $ex.provider_failure.code -eq 'invalid_api_key' -and $ex.provider_failure.message -eq '401 Unauthorized: invalid API key' -and $ex.provider_failure.when -and $mdx -match '(?m)^Provider failure: auth \(invalid_api_key\) - 401 Unauthorized: invalid API key\.$') (($mdx -split "`n") | Where-Object { $_ -match '^Provider failure' })
    $y = Consult $r3 $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'quota-fail') @{ FAKE_CODEX_STDERR = 'Error: credits exhausted for this token plan'; FAKE_CODEX_EXIT = '1'; }
    $n1 = @(Ledger $r3).Count
    Check 'F09-3' '... and the next run on that endpoint is refused by that auth failure (it is the newest of success/auth)' ($y.Code -eq 1 -and $y.First -match '^codex-consult: provider ZAI is not usable: the last run on this endpoint was rejected as unauthenticated at ' -and $n1 -eq 1) $y.First
    $z = Consult $r3 $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'quota-fail', '-SkipPreflight') @{ FAKE_CODEX_STDERR = 'Error: credits exhausted for this token plan'; FAKE_CODEX_EXIT = '1' }
    Check 'F09-3' 'a plain stderr credit failure -> provider_failure class quota' ($z.Code -eq 1 -and (Last-Entry $r3).provider_failure.class -eq 'quota') (Last-Entry $r3).provider_failure.message
    $ok = Consult $r3 $h @('-Prompt', 'x', '-ReplyName', 'ok') @{ FAKE_CODEX_REPLY = $advise }
    Check 'F09-3' 'a successful run -> provider_failure null' ($ok.Code -eq 0 -and (Last-Entry $r3).PSObject.Properties['provider_failure'] -and $null -eq (Last-Entry $r3).provider_failure) ''

    # ---- F09-2 / F09-4: health per ENDPOINT across all task ledgers
    function New-HealthEntry {
        param([int]$N, [string]$Alias, [string]$Fp, [int]$MinutesAgo, [string]$Outcome, $Failure)
        $when = (Get-Date).AddMinutes(-$MinutesAgo).ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture)
        return [pscustomobject]@{ n = $N; when = $when; purpose = ''; reviewer = [pscustomobject]@{ provider = $Alias; model = 'glm-5.3'; provider_fingerprint = $Fp }; lineage = "$Alias :: glm-5.3"; thread = ''; thread_source = 'unknown'; mode = 'new'; reply = ('handoffs/{0:D2}-codex-seed.md' -f ($N + 1)); bridge_outcome = $Outcome; provider_failure = $Failure }
    }
    function Seed-Task {
        param([string]$Repo, [string]$Task, [object[]]$Entries)
        $dir = Join-Path $Repo ".collab\$Task"
        [void][IO.Directory]::CreateDirectory((Join-Path $dir 'handoffs'))
        Write-JsonFile -Path (Join-Path $dir 'sessions.json') -Object ([pscustomobject]@{ task_id = $Task; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]$Entries } })
    }
    $authFail = [pscustomobject]@{ class = 'auth'; code = 'invalid_api_key'; message = '401 Unauthorized: invalid API key'; when = '' }
    $r4 = New-Repo 'w9-health'
    $seedAuth = New-HealthEntry 1 'zai-alias' $zfp 10 'failed: codex exit 1 - 401 Unauthorized: invalid API key' $authFail
    Seed-Task $r4 'other-task' @($seedAuth)
    $pv = Providers $r4 $h @('-Provider', 'ZAI')
    Check 'F09-2/4' 'auth failure 10 min ago under ANOTHER alias in ANOTHER task -> codex-providers -Provider ZAI: unavailable, exit 2' ($pv.Code -eq 2 -and $pv.Out -match "unavailable \(auth failed $([regex]::Escape($seedAuth.when)): 401 Unauthorized: invalid API key\)") (($pv.Out -split "`n") | Where-Object { $_ -match '^unavailable' })
    $cr = Consult $r4 $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'blocked') @{ FAKE_CODEX_REPLY = $advise }
    Check 'F09-2/4' '... and a consult on that endpoint is refused (exact message), nothing recorded in its task' ($cr.Code -eq 1 -and $cr.First -eq "codex-consult: provider ZAI is not usable: the last run on this endpoint was rejected as unauthenticated at $($seedAuth.when) (401 Unauthorized: invalid API key); if you rotated the credential, pass -SkipPreflight once" -and -not (Test-Path (Join-Path $r4 '.collab\t\sessions.json'))) $cr.First
    $co = Consult $r4 $h @('-DryRun', '-Prompt', 'x')
    Check 'F09-2/4' 'another endpoint (built-in openai) is not affected' ($co.Code -eq 0 -and $co.Out -match 'preflight   : available') (Line $co.Out 'preflight')
    Seed-Task $r4 'third-task' @((New-HealthEntry 1 'ZAI' $zfp 5 'usable reply' $null))
    $pv2 = Providers $r4 $h @('-Provider', 'ZAI')
    $cr2 = Consult $r4 $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'cleared') @{ FAKE_CODEX_REPLY = $advise }
    Check 'F09-2/4' 'a LATER successful run on that endpoint clears it: available (exit 0), the consult runs' ($pv2.Code -eq 0 -and $cr2.Code -eq 0) "providers exit=$($pv2.Code) consult exit=$($cr2.Code)"
    $r5 = New-Repo 'w9-quota'
    Seed-Task $r5 'other-task' @((New-HealthEntry 1 'zai-alias' $zfp 10 'failed: codex exit 1 - credits exhausted' ([pscustomobject]@{ class = 'quota'; code = ''; message = 'credits exhausted'; when = '' })))
    $q = Consult $r5 $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'quota') @{ FAKE_CODEX_REPLY = $advise }
    Check 'F09-2/4' 'quota failure 10 min ago on the endpoint (other alias, other task) -> WARNING + preflight_warning, the run proceeds' ($q.Code -eq 0 -and $q.Out -match 'WARNING: provider ZAI hit a usage limit 1[01] min ago: credits exhausted' -and (Last-Entry $r5).preflight_warning -match '^provider ZAI hit a usage limit 1[01] min ago: credits exhausted$') (Last-Entry $r5).preflight_warning
    $r6 = New-Repo 'w9-capability'
    Seed-Task $r6 'other-task' @((New-HealthEntry 1 'zai-alias' $zfp 10 'failed: codex exit 1 - json_schema not supported' ([pscustomobject]@{ class = 'capability'; code = 'responses_feature_not_supported'; message = 'json_schema not supported'; when = '' })))
    $cc = Consult $r6 $h @('-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3', '-ReplyName', 'cap') @{ FAKE_CODEX_REPLY = $advise }
    $pc = Providers $r6 $h @('-Provider', 'ZAI')
    Check 'F09-2/4' 'capability failure -> no effect (no warning, runs, available) but shown in the table' ($cc.Code -eq 0 -and $cc.Out -notmatch 'WARNING: provider' -and $pc.Code -eq 0 -and $pc.Out -match 'capability: .* - json_schema not supported') (($pc.Out -split "`n") | Where-Object { $_ -match '^available' })
}

# =============================================================== PREFLIGHT: credentials present before anything starts
if (Want 'PREFLIGHT') {
    $r = New-Repo 'preflight'
    $td = Join-Path $r '.collab\t'
    $sess = Join-Path $td 'sessions.json'
    $pend = Join-Path $td '.consult.pending.json'
    $h = New-Home 'preflight' ($baseToml + "`n[model_providers.CUST]`nbase_url = `"https://api.z.ai/api/v1`"`nwire_api = `"responses`"`nenv_key = `"CC_TEST_KEY`"`n`n[model_providers.BEARER]`nbase_url = `"https://api.z.ai/api/v1`"`nwire_api = `"responses`"`nexperimental_bearer_token = `"sk-test-bearer`"`n")
    $a = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'out') @{ FAKE_CODEX_REPLY = $advise; FAKE_CODEX_LOGIN = 'out' }
    Check 'PREFL' 'openai not logged in -> refused with the message, no ledger, no pending record' ($a.Code -eq 1 -and $a.First -eq 'codex-consult: provider openai is not usable: Not logged in; nothing was started (run codex-providers.ps1 for the full picture)' -and -not (Test-Path $sess) -and -not (Test-Path $pend)) $a.First
    $b = Consult $r $h @('-Prompt', 'x', '-ReplyName', 'in') @{ FAKE_CODEX_REPLY = $advise }
    $eb = Last-Entry $r
    $mdb = [IO.File]::ReadAllText((Join-Path $td $eb.reply))
    Check 'PREFL' 'logged in -> runs; ledger preflight "ok: Logged in using ChatGPT", preflight_warning ""; header line' ($b.Code -eq 0 -and $eb.preflight -eq 'ok: Logged in using ChatGPT' -and $eb.preflight_warning -eq '' -and $mdb -match '(?m)^Preflight: ok: Logged in using ChatGPT\.$') "preflight='$($eb.preflight)'"
    $n0 = @(Ledger $r).Count
    $c = Consult $r $h @('-Prompt', 'x', '-Provider', 'CUST', '-Model', 'glm-5.3', '-ReplyName', 'cust-unset')
    Check 'PREFL' 'custom provider, env_key variable unset -> refused, no new ledger entry, no pending record' ($c.Code -eq 1 -and $c.First -eq 'codex-consult: provider CUST is not usable: env CC_TEST_KEY not set; nothing was started (run codex-providers.ps1 for the full picture)' -and @(Ledger $r).Count -eq $n0 -and -not (Test-Path $pend)) $c.First
    $d = Consult $r $h @('-Prompt', 'x', '-Provider', 'CUST', '-Model', 'glm-5.3', '-ReplyName', 'cust-set') @{ FAKE_CODEX_REPLY = $advise; CC_TEST_KEY = 'k' }
    Check 'PREFL' 'custom provider, variable set -> runs; ledger preflight "ok: env CC_TEST_KEY set"' ($d.Code -eq 0 -and (Last-Entry $r).preflight -eq 'ok: env CC_TEST_KEY set') (Last-Entry $r).preflight
    $e = Consult $r $h @('-Prompt', 'x', '-Provider', 'BEARER', '-Model', 'glm-5.3', '-ReplyName', 'bearer') @{ FAKE_CODEX_REPLY = $advise }
    $ee = Last-Entry $r
    Check 'PREFL' 'bearer token in the table -> runs; preflight "ok: bearer token in config"; the token is not recorded' ($e.Code -eq 0 -and $ee.preflight -eq 'ok: bearer token in config' -and -not $ee.reviewer.provider_config.PSObject.Properties['experimental_bearer_token']) $ee.preflight
    $f = Consult $r $h @('-Prompt', 'x', '-Provider', 'CUST', '-Model', 'glm-5.3', '-SkipPreflight', '-ReplyName', 'skip') @{ FAKE_CODEX_REPLY = $advise }
    Check 'PREFL' '-SkipPreflight with the variable unset -> runs; ledger preflight "skipped"' ($f.Code -eq 0 -and (Last-Entry $r).preflight -eq 'skipped') (Last-Entry $r).preflight
    $r2 = New-Repo 'preflight-dry'
    $g = Consult $r2 $h @('-DryRun', '-Prompt', 'x', '-Provider', 'CUST', '-Model', 'glm-5.3')
    Check 'PREFL' '-DryRun with the variable unset -> prints unavailable, exit 0, writes nothing' ($g.Code -eq 0 -and $g.Out -match 'preflight   : unavailable \(env CC_TEST_KEY not set\) - a real run is refused: provider CUST is not usable' -and -not (Test-Path (Join-Path $r2 '.collab\t\sessions.json')) -and -not (Test-Path (Join-Path $r2 '.collab\t\.consult.pending.json'))) (Line $g.Out 'preflight')

    # usage-limit warnings from this task's ledger
    # $Tail: the rest of the usage-limit message. The default names NO reset time (the
    # 60-minute warning rule); a duration or a date there makes a known reset time.
    function Seed-Limit {
        param([string]$Repo, [int]$MinutesAgo, [switch]$Legacy, [string]$Tail = 'Upgrade to Pro or try again later.', [string]$When = '')
        $when = $When
        if (-not $when) { $when = (Get-Date).AddMinutes(-$MinutesAgo).ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture) }
        $entry = [ordered]@{ n = 1; when = $when; purpose = ''; thread = ''; thread_source = 'unknown'; mode = 'new'; reply = 'handoffs/01-codex-limit.md'; bridge_outcome = "failed: codex exit 1 - You've hit your usage limit. $Tail" }
        if (-not $Legacy) { $entry['reviewer'] = [pscustomobject]@{ provider = 'openai'; model = 'gpt-5.1'; provider_fingerprint = $script:BuiltinOpenAiFingerprint } }
        Write-JsonFile -Path (Join-Path $Repo '.collab\t\sessions.json') -Object ([pscustomobject]@{ task_id = 't'; cwd = $Repo; codex = [pscustomobject]@{ tool = 'x'; consults = [object[]]@((New-Object PSObject -Property $entry)) } })
    }
    $r3 = New-Repo 'limit-recent'
    Seed-Limit $r3 10
    $x3 = Consult $r3 $h @('-Prompt', 'x', '-ReplyName', 'after-limit') @{ FAKE_CODEX_REPLY = $advise }
    $e3 = Last-Entry $r3
    Check 'PREFL' 'usage-limit failure 10 min ago -> WARNING (not a refusal) + ledger preflight_warning' ($x3.Code -eq 0 -and $x3.Out -match "WARNING: provider openai hit a usage limit 1[01] min ago: failed: codex exit 1 - You've hit your usage limit\." -and $e3.preflight_warning -match "^provider openai hit a usage limit 1[01] min ago: failed: codex exit 1 - You've hit your usage limit\." -and $e3.preflight_warning.Length -le 160) $e3.preflight_warning
    $r4 = New-Repo 'limit-old'
    Seed-Limit $r4 120
    $x4 = Consult $r4 $h @('-Prompt', 'x', '-ReplyName', 'after-old') @{ FAKE_CODEX_REPLY = $advise }
    Check 'PREFL' 'usage-limit failure 2 h ago -> no warning' ($x4.Code -eq 0 -and $x4.Out -notmatch 'hit a usage limit' -and (Last-Entry $r4).preflight_warning -eq '') "preflight_warning='$((Last-Entry $r4).preflight_warning)'"
    $r5 = New-Repo 'limit-legacy'
    Seed-Limit $r5 10 -Legacy
    $x5 = Consult $r5 $h @('-DryRun', '-Prompt', 'x')
    Check 'PREFL' 'a legacy entry (no reviewer) counts as openai; -DryRun shows the warning too' ($x5.Code -eq 0 -and $x5.Out -match 'WARNING: provider openai hit a usage limit' -and $x5.Preview.preflight_warning -match '^provider openai hit a usage limit') (Line $x5.Out 'WARNING')
    $x6 = Consult $r3 $h @('-DryRun', '-Prompt', 'x', '-Provider', 'ZAI', '-Model', 'glm-5.3')
    Check 'PREFL' 'the warning is per provider: ZAI is not warned about openai''s limit' ($x6.Code -eq 0 -and $x6.Out -notmatch 'hit a usage limit') ''
    # a message that names its reset as a duration in days: a KNOWN reset time -> refused
    # until then, even 2 h after the failure (the 60-minute rule is only for no reset time)
    $r7 = New-Repo 'limit-days'
    $w7 = (Get-Date).AddMinutes(-120).ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture)
    Seed-Limit $r7 120 -Tail 'Upgrade to Pro or try again in 3 days 1 hour 7 minutes.' -When $w7
    $until7 = [DateTimeOffset]::Parse($w7, [Globalization.CultureInfo]::InvariantCulture).AddDays(3).AddHours(1).AddMinutes(7).ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture)
    $x7 = Consult $r7 $h @('-Prompt', 'x', '-ReplyName', 'after-days') @{ FAKE_CODEX_REPLY = $advise }
    $d7 = Consult $r7 $h @('-DryRun', '-Prompt', 'x')
    Check 'PREFL' '"try again in 3 days 1 hour 7 minutes" 2 h ago -> refused until when + 3 d 1 h 7 min (no ledger entry added); dry run: unavailable (usage limit until <iso>), no warning' ($x7.Code -eq 1 -and $x7.First -match ('^codex-consult: provider openai is not usable: its usage limit \(hit at .*\) lasts until ' + [regex]::Escape($until7) + '; nothing was started') -and @(Ledger $r7).Count -eq 1 -and $d7.Code -eq 0 -and $d7.Preview.preflight -eq "unavailable: usage limit until $until7" -and $d7.Preview.preflight_warning -eq '') $x7.First

    # codex-providers.ps1
    $hp = New-Home 'providers' "model = `"gpt-5.1`"`n[model_providers.ZAI]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"ZAI_KEY_A`"`nwire_api = `"responses`"`n[model_providers.zeta]`nbase_url = `"https://api.z.ai/api/v1`"`nenv_key = `"CC_TEST_KEY`"`n[model_providers.broken]`nbase_url = `"https://x.example/v1`"`nhttp_headers = { A = `"b`" }`n"
    function Snapshot { param([string]$Dir) return ((@(Get-ChildItem -LiteralPath $Dir -Recurse -Force -File | ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTimeUtc.Ticks)" }) | Sort-Object) -join "`n") }
    $before = Snapshot (Join-Path $r3 '.collab')
    $pj = Providers $r3 $hp @('-Json')
    $byName = @{}
    foreach ($row in @($pj.Json)) { $byName[$row.name] = $row }
    Check 'PREFL' 'codex-providers -Json parses: openai, ZAI, zeta, broken' ($pj.Code -eq 0 -and $byName.Count -eq 4) "names=$(@($pj.Json | ForEach-Object { $_.name }) -join ',')"
    Check 'PREFL' 'verdicts: openai available, ZAI available, zeta unavailable (env unset), broken unavailable (table)' ($byName.openai.verdict -eq 'available' -and $byName.ZAI.verdict -eq 'available' -and $byName.zeta.verdict -eq 'unavailable (missing: env CC_TEST_KEY not set)' -and $byName.broken.verdict -match '^unavailable \(table unusable: unsupported TOML construct at line 11: http_headers = \{') "$($byName.openai.verdict) / $($byName.ZAI.verdict) / $($byName.zeta.verdict) / $($byName.broken.verdict)"
    Check 'PREFL' 'fields: credentials, endpoint, effort vocabulary, last limit from this repo (openai, 10 min ago)' ($byName.openai.credentials -eq 'ok: Logged in using ChatGPT' -and $byName.ZAI.credentials -eq 'ok: env ZAI_KEY_A set' -and $byName.ZAI.endpoint -eq 'https://api.z.ai/api/v1' -and $byName.ZAI.effort_vocabulary -eq 'zai' -and $byName.openai.last_limit.message -match "usage limit" -and $null -eq $byName.ZAI.last_limit) "openai.last_limit=$($byName.openai.last_limit.when)"
    $codes = @{}
    foreach ($n in @('openai', 'ZAI', 'zeta', 'broken')) { $codes[$n] = (Providers $r3 $hp @('-Provider', $n)).Code }
    Check 'PREFL' 'exit codes with -Provider: openai 0, ZAI 0, zeta 2, broken 2' ($codes.openai -eq 0 -and $codes.ZAI -eq 0 -and $codes.zeta -eq 2 -and $codes.broken -eq 2) "openai=$($codes.openai) ZAI=$($codes.ZAI) zeta=$($codes.zeta) broken=$($codes.broken)"
    $pu = Providers $r3 $hp @('-Provider', 'nope')
    $po = Providers $r3 $hp @('-Provider', 'openai') @{ FAKE_CODEX_LOGIN = 'out' }
    $hf = New-Home 'providers-fatal' "model = `"gpt-5.1`"`nthis is not toml`n"
    $pf = Providers $r3 $hf @('-Provider', 'openai')
    Check 'PREFL' 'exit codes: unknown provider 1 (usage), logged out 2, config unreadable 3 (unknown)' ($pu.Code -eq 1 -and $pu.Out -match "no provider 'nope'" -and $po.Code -eq 2 -and $po.Out -match 'unavailable \(missing: Not logged in\)' -and $pf.Code -eq 3 -and $pf.Out -match 'unknown \(config unreadable: ') "nope=$($pu.Code) out=$($po.Code) fatal=$($pf.Code)"
    $pt = Providers $r3 $hp @()
    $tableLines = @($pt.Out -split "`n" | Where-Object { $_ -match '^(VERDICT|available|unavailable|unknown) ' })
    $col = if ($tableLines.Count -gt 0) { $tableLines[0].IndexOf('PROVIDER') } else { -1 }
    $aligned = ($col -gt 0 -and @($tableLines | Select-Object -Skip 1 | Where-Object { $_.Length -gt $col -and $_.Substring($col) -match '^(openai|ZAI|zeta|broken) ' }).Count -eq 4)
    Check 'PREFL' 'console: an aligned table, one line per provider, verdict first' ($pt.Code -eq 0 -and $tableLines.Count -eq 5 -and $tableLines[0] -match '^VERDICT\s+PROVIDER\s+KIND\s+ENDPOINT\s+CREDENTIALS\s+EFFORT\s+LAST FAILURE' -and $aligned) ($tableLines -join ' | ')
    Check 'PREFL' 'codex-providers wrote nothing (the task directory is byte-identical, no lock or pending file created)' ((Snapshot (Join-Path $r3 '.collab')) -eq $before) ''
}
} finally {
    Clear-TestEnv
    $env:CODEX_HOME = $savedCodexHome
    Remove-TestWork $work
}
Write-Host ("harness-0.3 ({0} {1}): {2} passed, {3} failure(s)." -f $hostTag, $PSVersionTable.PSVersion, $script:passes, $script:fails)
if ($script:fails -gt 0) { exit 1 }
exit 0
