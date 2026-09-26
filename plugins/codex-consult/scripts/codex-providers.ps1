<#
.SYNOPSIS
    List the Codex model providers and whether each one is usable right now.

.DESCRIPTION
    Reads the Codex config (<codex home>/config.toml, the constrained scanner of
    codex-consult-common.ps1) and reports the built-in openai plus every
    [model_providers.<name>] table - and (0.4.0) one row per provider label that the
    reviewer roster declares with another engine than codex (e.g. "engine": "agy" or, wave
    23, "engine": "muse"):

      verdict      available               credentials present and the table usable
                   unavailable (<reason>)  credentials missing, the table unusable, an
                                           auth failure on this endpoint <= 24 h ago, a
                                           usage limit whose reset time lies ahead
                                           ("usage limit until <iso>"), or (wave 24) one
                                           without a reset time, for 60 minutes ("usage
                                           limit hit <iso>, reset unknown; retry after
                                           <iso>")
                   unknown (<reason>)      `codex login status` could not run, or the
                                           config cannot be scanned
                   (wave 24, D14) the roster walk's own verdict (Get-PreflightVerdict
                   -RosterWalk): a row never reads available for an endpoint the walk skips
      kind         builtin | custom | engine <name> (JSON `engine`: codex for the first two)
      endpoint     canonical base_url, or builtin:openai[+OPENAI_BASE_URL <url>], or
                   "<engine> (<launcher>)" for an engine row
      table        built in | usable | unusable: <scanner reason> | n/a (an engine row)
      credentials  openai (and tables with requires_openai_auth = true): the output of
                   `codex login status` (timeout 15 s) - "ok: Logged in ..." or
                   "missing: <first line or exit N>"; other tables: "ok: env NAME set",
                   "ok: bearer token in config", "missing: env NAME not set" or
                   "missing: no env_key/bearer token in the table"; an agy row: `agy models`
                   (a network round-trip, usually ~2 s, timeout 45 s, once per listing) -
                   "ok: signed in (N models)", "missing: ..." (sign-in wording, or "agy CLI
                   not found on PATH"), "unknown: ..."; no call when THIS repository's
                   ledgers hold a usable reply on the agy endpoint from the last 60 minutes:
                   "ok: signed in (usable reply <m> min ago)" (with -NoNetwork too; a
                   recorded auth failure or usage limit still makes the verdict
                   unavailable); otherwise with -NoNetwork "not checked (launcher present;
                   run codex-providers.ps1)" and the verdict "unknown (sign-in not checked)";
                   a muse row (wave 23): ~/.config/muse/auth.json with TBH_CREDENTIAL_BACKEND=file
                   (local, also with -NoNetwork; key names and providers.meta.mechanism only) -
                   "ok: signed in (...mechanism oauth)", "missing: not signed in: ...",
                   "unknown: sign-in not checkable: ..." (the keychain backend). A muse row
                   whose launch the billing guard refuses (META_API_KEY or MODEL_API_KEY set,
                   a mechanism other than oauth, or - wave 23b - no oauth sign-in established:
                   the keychain backend, no auth.json, no mechanism) is "unavailable (refused:
                   ...)"
      effort       the effort vocabulary DECLARED for the endpoint (capability table
                   caps-v1): openai (built-in openai, any model), zai (api.z.ai /
                   open.bigmodel.cn), mimo (*.xiaomimimo.com token-plan / api hosts) -
                   those two for their declared models only (JSON effort_models) - or
                   "unknown (needs -NativeEffort)"; an agy row: "agy (tier in the model id)";
                   a muse row: "muse (2 declared models)" (JSON effort_models)
      transport    (JSON schema_transport) how the reply schema reaches the endpoint:
                   output-schema (--output-schema) or prompt-only (MiMo, undeclared hosts);
                   native for an engine row (agy --json-schema, muse --output-schema)
      last failure the newest failed consultation of this provider's ENDPOINT
                   (provider_fingerprint, whatever alias ran it) in THIS repository's
                   <CollabDir>/*/sessions.json within the last 24 h - or, older, the
                   usage limit that still makes the endpoint unavailable (wave 24, T2: a
                   weekly limit hit days ago) - with its class (auth | quota |
                   capability | transport | unknown; "quota until <iso>" when the
                   provider named its reset time; JSON last_failure and last_limit =
                   the newest quota failure, each with retry_after). An auth failure not
                   followed by a successful run, a usage limit until a reset time still
                   ahead and one without a reset time hit less than 60 minutes ago make
                   the verdict unavailable. Entries recorded before 0.3.0 count as the
                   built-in openai endpoint. Health is read at the consult clock
                   (CODEX_CONSULT_NOW, a test hook) from the ledgers the line
                   "endpoint health: <collab dir> (<k> task ledgers, <m>
                   consultations)" names (JSON health_source) - THIS repository's: run
                   the listing in the repository whose consultations you mean.
      roster       with a reviewer roster (CODEX_CONSULT_ROSTER - it must exist, "none"
                   = no roster - else <codex home>/codex-consult-roster.json when it
                   exists): the ROSTER column (the
                   provider's entry positions, or -; JSON roster_position = the first,
                   or null; roster_selected = the entry a consultation without -Provider
                   and -Thread would use now) and a final line
                   "roster: <path> -> would select <provider> :: <model> (skipped: ...)"
                   or "roster: <path> -> no entry is available (skipped: ...)". An
                   unusable roster file, or a CODEX_CONSULT_ROSTER file that does not
                   exist, is refused (exit 1). "auth": "none" in the
                   roster makes a table without env_key/bearer token "ok: declared
                   anonymous in the roster". The "would select" entry is the single-run
                   walk's own choice (Select-RosterReviewer), then a line
                   "availability: <the -Short line>".
      -Short       (wave 24, D15-D17) ONE line over EVERY roster entry, each judged
                   with the roster walk's verdict (Select-PanelMembers -All): what is
                   OUT per entry (the entries of one endpoint group that share the
                   state collapse to "<label> :: *"), the reset in LOCAL time with a
                   rounded relative hint, then the count, e.g.
                     codex-consult: out - openai :: gpt-6-astra (until Sun 20:35, in 2d
                     10h), gemini :: * (until Sun 21:30, in 2d 11h); 9 of 11 reviewers
                     available
                     codex-consult: all 11 reviewers available
                   ("... available, <o> out, <c> not checked" when an entry was not
                   checked; nothing is cut). Without a roster: the providers ("... (no
                   reviewer roster)"). -Short -Json: an object {line, health_source,
                   total, available, out, not_checked, roster, entries[{position,
                   provider, model, engine, lineage, group, state, kind, reason, short,
                   hit, until}]} - the SessionStart hook reads it (with -NoNetwork).

    No network call for codex providers; at most one `agy models` call per agy engine (none
    after a usable agy reply within the last 60 minutes, none with -NoNetwork, which the
    SessionStart hook uses); nothing is written; no task lock is taken.
    Exit codes: with -Provider <name>: 0 available, 2 unavailable, 3 unknown, 1 usage
    error (e.g. no such provider). Without -Provider: 0.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-providers.ps1

.EXAMPLE
    pwsh -NoProfile -File codex-providers.ps1 -Provider ZAI -Json
#>
[CmdletBinding()]
param(
    # Report this provider only (case-sensitive, as in the config); sets the exit code.
    [string]$Provider = '',

    # Where consultations are stored (for the last usage-limit failure). Relative paths
    # resolve against the git repo root.
    [string]$CollabDir = '.collab',

    # An array of objects instead of the table.
    [switch]$Json,

    # Explicit path to the codex launcher (for `codex login status`). Env override:
    # CODEX_CONSULT_EXE.
    [string]$CodexExe = '',

    # Explicit path to the launcher of an engine other than codex (for `agy models`, the muse
    # rows' launcher): the engine of the -Provider row, else the only such engine of the roster
    # (several: pass -Provider). Env overrides: CODEX_CONSULT_AGY_EXE, CODEX_CONSULT_MUSE_EXE.
    [string]$EngineExe = '',

    # No network call at all: an agy row's sign-in is "not checked" (the SessionStart hook); a
    # muse row's check is local and still runs.
    [switch]$NoNetwork,

    # (wave 24) ONE line: what is OUT, per roster entry, and how many reviewers are available
    # (with -Json: that line and every entry's record as one object - the SessionStart hook).
    [switch]$Short
)

$ErrorActionPreference = 'Stop'
$script:ToolName = 'codex-providers'
. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

$launcher = Resolve-CodexLauncher -Explicit $CodexExe
$configPath = Get-CodexConfigPath
$config = Read-CodexConfigSubset -Path $configPath
$where = if ($configPath) { $configPath } else { '(no Codex home)' }
$fileReason = ''
if ($config.Exists -and -not $config.Ok) { $fileReason = $config.Reason }

$names = New-Object System.Collections.Generic.List[string]
$names.Add('openai')
foreach ($n in (Get-ProviderNames -Config $config)) { if ($n -cne 'openai') { $names.Add($n) } }

# Every task ledger of this repository (health is read per ENDPOINT across all of them, at
# the consult clock: CODEX_CONSULT_NOW freezes it in tests).
$repoRoot = Resolve-RepoRoot -Cwd (Get-Location).Path
$collabRoot = Resolve-CollabRoot -RepoRoot $repoRoot -CollabDir $CollabDir
$consults = Read-AllTaskConsults -CollabRoot $collabRoot
$clock = Get-ConsultClock -Peek
if ($clock.Error) { Stop-WithError $clock.Error }
$utcNow = $clock.Now.UtcDateTime

# The reviewer roster (as codex-consult.ps1 reads it): which entry a consultation without
# -Provider and -Thread would select now.
$roster = Read-ReviewerRoster
if ($roster.Error) { Stop-WithError $roster.Error }
# The provider labels of the other engines (0.4.0): one row each, in roster order.
$engineLaunchers = @{}
if ($EngineExe) {
    # (wave 23, D3) -EngineExe names the launcher of the SELECTED engine other than codex
    $exeBinding = Resolve-EngineExeBinding -Roster $roster -Provider $Provider
    if ($exeBinding.Error) { Stop-WithError "$($exeBinding.Error)." }
    $engineLaunchers[$exeBinding.Engine] = [string](Resolve-EngineLauncher -Engine $exeBinding.Engine -Explicit $EngineExe)
}
$engineLabels = New-Object System.Collections.Generic.List[object]
foreach ($e in @($roster.Entries)) {
    if ($e.Engine -eq 'codex') { continue }
    if (@($engineLabels | Where-Object { $_.Name -ceq $e.Provider }).Count -eq 0) { $engineLabels.Add([pscustomobject]@{ Name = $e.Provider; Engine = $e.Engine }) }
}
if ($Provider) {
    $known = @($names.ToArray()) + @($engineLabels | ForEach-Object { $_.Name })
    if ($known -cnotcontains $Provider) {
        Stop-WithError "no provider '$Provider' in $where (providers: $($known -join ', '))."
    }
    $keep = $names.Contains($Provider) -and @($engineLabels | Where-Object { $_.Name -ceq $Provider }).Count -eq 0
    $names = New-Object System.Collections.Generic.List[string]
    if ($keep) { $names.Add($Provider) }
    $engineLabels = New-Object System.Collections.Generic.List[object]
    foreach ($e in @($roster.Entries)) {
        if ($e.Engine -ne 'codex' -and $e.Provider -ceq $Provider -and $engineLabels.Count -eq 0) { $engineLabels.Add([pscustomobject]@{ Name = $e.Provider; Engine = $e.Engine }) }
    }
}
if ($Short -and $Provider) { Stop-WithError "-Short summarizes every reviewer of the roster; drop -Provider (or drop -Short for one provider's row)." }
# (wave 24, T2) where the endpoint health comes from: the ledgers of THIS repository only
$ledgerCount = 0
if (Test-Path -LiteralPath $collabRoot -PathType Container) {
    $ledgerCount = @(Get-ChildItem -LiteralPath $collabRoot -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'sessions.json') -PathType Leaf }).Count
}
$consultCount = @($consults).Count
$healthSource = "$collabRoot ($ledgerCount task ledger$(if ($ledgerCount -ne 1) { 's' }), $consultCount consultation$(if ($consultCount -ne 1) { 's' }))"
$loginCache = @{}
$walk = $null
$avail = $null
if ($roster.Exists) {
    # the single-run walk itself ("would select") and every entry judged with the same verdict
    # (Select-PanelMembers -All: the -Short line, the availability line) - one login cache, so
    # `agy models` runs at most once
    $walk = Select-RosterReviewer -Roster $roster -Config $config -Consults $consults -Launcher ([string]$launcher) -LoginCache $loginCache -UtcNow $utcNow -OpenAiBaseUrl ([string]$env:OPENAI_BASE_URL) -EngineLaunchers $engineLaunchers -NoNetwork:$NoNetwork
    $avail = Get-RosterAvailability -Roster $roster -Config $config -Consults $consults -Launcher ([string]$launcher) -LoginCache $loginCache -UtcNow $utcNow -OpenAiBaseUrl ([string]$env:OPENAI_BASE_URL) -EngineLaunchers $engineLaunchers -NoNetwork:$NoNetwork
}

# A row's verdict text from the shared verdict (Get-PreflightVerdict -RosterWalk, wave 24 D14):
# available | unavailable (<reason>) | unknown (<reason>) - the wording of the rows before.
function Format-RowVerdict {
    param($V, [string]$Engine)
    if ($V.State -eq 'available') { return 'available' }
    if ($V.State -eq 'unavailable') {
        if ($V.Kind -eq 'credentials' -and $Engine -ne 'codex' -and $V.Credential) { return "unavailable ($($V.Credential.Reason))" }
        return "unavailable ($($V.Reason))"
    }
    if ($V.Kind -eq 'unknown' -and $V.Credential -and $V.Credential.Reason) { return "unknown ($($V.Credential.Reason))" }
    return "unknown ($($V.Reason -replace '^unknown:\s*', ''))"
}

$rows = New-Object System.Collections.Generic.List[object]
# the verdict behind each row, in row order (the -Short line without a roster)
$rowVerdicts = New-Object System.Collections.Generic.List[object]
foreach ($name in $names) {
    $tableName = '[' + (Format-TomlPath @('model_providers', $name)) + ']'
    $pt = $null
    $setProblem = ''
    if ($config.Exists -and $config.Ok) {
        $pt = Get-ProviderTable -Config $config -Name $name
        $setProblem = Get-ProviderSetProblem -Config $config -Name $name
    }
    $kind = if ($name -ceq 'openai') { 'builtin' } else { 'custom' }
    $endpoint = ''
    $wire = ''
    $tableState = 'built in'
    $tableOk = $true
    $vocab = ''
    $hostName = ''
    if ($pt -and $pt.Found) {
        if ($pt.Ok) {
            $ep = Get-ProviderEndpoint -Table $pt.Table -TableName $tableName -Where $where
            if ($ep.Error) { $tableOk = $false; $tableState = "unusable: $($ep.Error)" }
            else {
                $tableState = 'usable'
                $endpoint = if ($ep.BaseUrl) { ($ep.BaseUrl -replace '\?.*$', '?...') } else { '(default)' }
                if ($name -ceq 'openai') { $endpoint += ' (user-defined table)' }
                $wire = $ep.WireApi
                $hostName = $ep.HostName
            }
        } else { $tableOk = $false; $tableState = "unusable: $($pt.Reason)" }
    } elseif ($name -ceq 'openai') {
        $endpoint = 'builtin:openai'
        $hostName = 'builtin:openai'
        $wire = '(built in)'
        if ($env:OPENAI_BASE_URL -and $env:OPENAI_BASE_URL.Trim()) {
            $cu = ConvertTo-CanonicalBaseUrl $env:OPENAI_BASE_URL
            $endpoint += "+OPENAI_BASE_URL $($cu.Url -replace '\?.*$', '?...')"
            $hostName = $cu.HostName
        }
    } else {
        $tableOk = $false
        $tableState = 'unusable: the config cannot be scanned'
    }
    $effortModels = $null
    $transport = 'prompt-only'
    if ($hostName -and $script:EffortCaps.ContainsKey($hostName)) { $transport = $script:EffortCaps[$hostName].SchemaTransport }
    if ($hostName -and $script:EffortCaps.ContainsKey($hostName)) {
        $vocab = $script:EffortCaps[$hostName].Vocabulary
        $effortModels = if ($null -eq $script:EffortCaps[$hostName].Models) { 'any' } else { [object[]]$script:EffortCaps[$hostName].Models }
    } else { $vocab = 'unknown (needs -NativeEffort)' }

    # Recorded health of this provider's ENDPOINT (fingerprint), whatever alias ran it.
    $health = $null
    $probe = $null
    if (-not $fileReason -and -not $setProblem -and $tableOk) {
        $probe = Resolve-ReviewerIdentity -Config $config -Provider $name -Model 'health-probe' -OpenAiBaseUrl ([string]$env:OPENAI_BASE_URL)
        if ($probe.Resolved) { $health = Get-EndpointHealth -Consults $consults -Fingerprint $probe.Fingerprint -UtcNow $utcNow }
    }
    $credText = 'not checked (table unusable)'
    $verdict = ''
    $rowVerdict = $null
    if ($fileReason) {
        $credText = 'not checked (config unreadable)'
        $verdict = "unknown (config unreadable: $fileReason)"
    } elseif ($setProblem) {
        $credText = 'not checked (providers could not be established)'
        $verdict = "unknown (the providers could not be established: $setProblem)"
    } elseif (-not $tableOk) {
        $verdict = "unavailable (table $tableState)"
    } else {
        # (wave 24, D14) the roster walk's verdict: credentials, then the recorded health - an
        # auth failure, a usage limit with a reset ahead or without one for 60 minutes
        $anonymous = [bool](@($roster.Entries | Where-Object { $_.Provider -ceq $name -and $_.Auth -eq 'none' }).Count -gt 0)
        $rowVerdict = Get-PreflightVerdict -Identity $probe -Config $config -Launcher ([string]$launcher) -Health $health -LoginCache $loginCache -Anonymous:$anonymous -RosterWalk -NoNetwork:$NoNetwork
        $credText = $(if ($rowVerdict.Credential) { [string]$rowVerdict.Credential.Detail } else { 'not checked (identity unresolved)' })
        $verdict = Format-RowVerdict $rowVerdict 'codex'
    }
    if (-not $rowVerdict) { $rowVerdict = [pscustomobject]@{ State = $(if ($verdict.StartsWith('unknown')) { 'unknown' } else { 'unavailable' }); Kind = 'config'; Reason = ($verdict -replace '^\w+ \((.*)\)$', '$1'); Credential = $null; Hit = $null; Until = $null } }
    $rowVerdicts.Add([pscustomobject]@{ Verdict = $rowVerdict; Block = ''; Engine = 'codex' })
    $limit = $null
    $lastFailure = $null
    if ($health) { $limit = $health.LastLimit; $lastFailure = $health.LastFailure }
    $rosterPositions = @(@($roster.Entries) | Where-Object { $_.Provider -ceq $name -and $_.Engine -eq 'codex' } | ForEach-Object { [int]$_.Position })
    $rows.Add([pscustomobject]@{
            name              = $name
            engine            = 'codex'
            kind              = $kind
            endpoint          = $endpoint
            wire_api          = $wire
            table             = $tableState
            credentials       = $credText
            effort_vocabulary = $vocab
            effort_models     = $effortModels
            schema_transport  = $transport
            last_limit        = $(if ($limit) { [pscustomobject]@{ when = $limit.When; message = $limit.Message; retry_after = $(if ($limit.RetryAfterIso) { $limit.RetryAfterIso } else { $null }) } } else { $null })
            last_failure      = $(if ($lastFailure) { [pscustomobject]@{ class = $lastFailure.Class; code = $lastFailure.Code; when = $lastFailure.When; message = $lastFailure.Message; retry_after = $(if ($lastFailure.RetryAfterIso) { $lastFailure.RetryAfterIso } else { $null }) } } else { $null })
            roster_position   = $(if ($rosterPositions.Count -gt 0) { [int]$rosterPositions[0] } else { $null })
            roster_selected   = [bool]($walk -and $walk.Entry -and $walk.Entry.Provider -ceq $name -and $walk.Entry.Engine -eq 'codex')
            verdict           = $verdict
            health_source     = $healthSource
        })
}

# ----------------------------------------------------------------------------- engine rows
# One row per provider label of another engine (roster entries only): the launcher, the sign-in
# (`agy models`, or "not checked" with -NoNetwork), the recorded health of the engine's
# endpoint (its fingerprint: every label of one engine shares it), the roster columns - the
# verdict is the roster walk's (wave 24, D14), the engine's launch invariant outranks it.
foreach ($el in $engineLabels) {
    $spec = Get-EngineSpec -Name $el.Engine
    $engineLauncher = Get-EngineLauncher -Engine $el.Engine -Launchers $engineLaunchers
    $model = [string](@($roster.Entries | Where-Object { $_.Provider -ceq $el.Name } | Select-Object -First 1).Model)
    $probe = Resolve-ReviewerIdentity -Config $config -Provider $el.Name -Model $model -Engine $el.Engine -Launcher $engineLauncher
    $health = $null
    if ($probe.Resolved) { $health = Get-EndpointHealth -Consults $consults -Fingerprint $probe.Fingerprint -UtcNow $utcNow }
    # (a usable reply on this endpoint within the last 60 minutes evidences the sign-in: no
    # `agy models` call; the auth / quota rules still apply)
    $rowVerdict = Get-PreflightVerdict -Identity $probe -Config $config -Launcher $engineLauncher -Health $health -LoginCache $loginCache -RosterWalk -NoNetwork:$NoNetwork
    $credText = $(if ($rowVerdict.Credential) { [string]$rowVerdict.Credential.Detail } else { 'not checked (identity unresolved)' })
    $verdict = Format-RowVerdict $rowVerdict $el.Engine
    # (wave 23, D4) the engine's launch invariant (muse: billing) outranks everything above
    $launchBlock = Get-EngineLaunchBlock -Engine $el.Engine
    if ($launchBlock) { $verdict = "unavailable (refused: $launchBlock)" }
    $rowVerdicts.Add([pscustomobject]@{ Verdict = $rowVerdict; Block = [string]$launchBlock; Engine = $el.Engine })
    # caps-v1 of the engine: its effort vocabulary, declared models and schema transport
    $engineCap = $null
    if ($script:EffortCaps.ContainsKey("engine:$($el.Engine)")) { $engineCap = $script:EffortCaps["engine:$($el.Engine)"] }
    $engineVocab = "$($el.Engine) (tier in the model id)"
    $engineModels = 'any'
    $engineTransport = 'native'
    if ($engineCap) {
        if ($engineCap.Vocabulary -ne 'model-tier') { $engineVocab = [string]$engineCap.Vocabulary }
        if ($null -ne $engineCap.Models) { $engineModels = [object[]]$engineCap.Models }
        $engineTransport = [string]$engineCap.SchemaTransport
    }
    $limit = $null
    $lastFailure = $null
    if ($health) { $limit = $health.LastLimit; $lastFailure = $health.LastFailure }
    $rosterPositions = @(@($roster.Entries) | Where-Object { $_.Provider -ceq $el.Name -and $_.Engine -eq $el.Engine } | ForEach-Object { [int]$_.Position })
    $rows.Add([pscustomobject]@{
            name              = $el.Name
            engine            = $el.Engine
            kind              = "engine $($el.Engine)"
            endpoint          = "$($el.Engine) ($(if ($engineLauncher) { $engineLauncher } else { 'launcher not found' }))"
            wire_api          = ''
            table             = 'n/a'
            credentials       = $credText
            effort_vocabulary = $engineVocab
            effort_models     = $engineModels
            schema_transport  = $engineTransport
            last_limit        = $(if ($limit) { [pscustomobject]@{ when = $limit.When; message = $limit.Message; retry_after = $(if ($limit.RetryAfterIso) { $limit.RetryAfterIso } else { $null }) } } else { $null })
            last_failure      = $(if ($lastFailure) { [pscustomobject]@{ class = $lastFailure.Class; code = $lastFailure.Code; when = $lastFailure.When; message = $lastFailure.Message; retry_after = $(if ($lastFailure.RetryAfterIso) { $lastFailure.RetryAfterIso } else { $null }) } } else { $null })
            roster_position   = $(if ($rosterPositions.Count -gt 0) { [int]$rosterPositions[0] } else { $null })
            roster_selected   = [bool]($walk -and $walk.Entry -and $walk.Entry.Provider -ceq $el.Name -and $walk.Entry.Engine -eq $el.Engine)
            verdict           = $verdict
            health_source     = $healthSource
        })
}

# ----------------------------------------------------------------------------- the availability line
# (wave 24, D15-D17) ONE line: with a roster, every entry judged by the roster walk's verdict
# (Get-RosterAvailability); without one, the provider rows above.
$availability = $avail
$noun = 'reviewers'
$suffix = ''
if (-not $roster.Exists) {
    $recs = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $rv = $rowVerdicts[$i]
        $recs.Add((ConvertTo-AvailabilityRecord -Position ($i + 1) -Provider ([string]$rows[$i].name) -Engine $rv.Engine -Group $i -Verdict $rv.Verdict -Block $rv.Block -UtcNow $utcNow))
    }
    $availability = [pscustomobject]@{ Records = [object[]]$recs.ToArray() }
    $noun = 'providers'
    $suffix = ' (no reviewer roster)'
}
$availabilityLine = Format-AvailabilityLine -Availability $availability -Noun $noun -Suffix $suffix

if ($Short) {
    if ($Json) {
        $recsOut = @(@($availability.Records) | Where-Object { $_ } | ForEach-Object {
                [pscustomobject]@{ position = $_.Position; provider = $_.Provider; model = $_.Model; engine = $_.Engine; lineage = $_.Lineage; group = $_.Group; state = $_.State; kind = $_.Kind; reason = $_.Reason; short = $_.Short; hit = $(if ($null -ne $_.Hit) { Format-OffsetIso $_.Hit } else { $null }); until = $(if ($null -ne $_.Until) { Format-OffsetIso $_.Until } else { $null }) }
            })
        $obj = [pscustomobject]@{
            line          = $availabilityLine
            health_source = $healthSource
            total         = @($recsOut).Count
            available     = @($recsOut | Where-Object { $_.state -eq 'available' }).Count
            out           = @($recsOut | Where-Object { $_.state -eq 'out' }).Count
            not_checked   = @($recsOut | Where-Object { $_.state -eq 'not checked' }).Count
            roster        = $(if ($roster.Exists) { $roster.Path } else { $null })
            entries       = [object[]]$recsOut
        }
        Write-Output (ConvertTo-Json -InputObject $obj -Depth 6)
    } else {
        Write-Output $availabilityLine
    }
    exit 0
}

if ($Json) {
    Write-Output (ConvertTo-Json -InputObject ([object[]]$rows.ToArray()) -Depth 5)
} else {
    Write-Host "codex config: $where$(if (-not $config.Exists) { ' (not found - Codex runs on its built-in defaults)' })"
    Write-Host "endpoint health: $healthSource, read at $($clock.Now.ToLocalTime().ToString('yyyy-MM-dd HH:mm', $script:Invariant)) - the ledgers of THIS repository"
    $header = [pscustomobject]@{ verdict = 'VERDICT'; name = 'PROVIDER'; roster = 'ROSTER'; kind = 'KIND'; endpoint = 'ENDPOINT'; credentials = 'CREDENTIALS'; effort = 'EFFORT'; limit = 'LAST FAILURE' }
    $lines = @($header) + @($rows | ForEach-Object {
            $rowName = $_.name
            $rowEngine = [string]$_.engine
            $positions = @(@($roster.Entries) | Where-Object { $_.Provider -ceq $rowName -and $_.Engine -eq $rowEngine } | ForEach-Object { [string]$_.Position })
            $failureLabel = ''
            if ($_.last_failure) {
                $failureLabel = [string]$_.last_failure.class
                if ($_.last_failure.class -eq 'quota' -and $_.last_failure.retry_after) { $failureLabel = "quota until $($_.last_failure.retry_after)" }
            }
            [pscustomobject]@{
                verdict     = $_.verdict
                name        = $_.name
                roster      = $(if ($positions.Count -gt 0) { $positions -join ',' } else { '-' })
                kind        = $_.kind
                endpoint    = $(if ($_.endpoint) { $_.endpoint } else { '-' })
                credentials = $_.credentials
                effort      = $(if ($_.engine -ne 'codex' -and $_.effort_models -ne 'any' -and $null -ne $_.effort_models) { "$($_.effort_vocabulary) ($(@($_.effort_models).Count) declared models)" } elseif ($_.engine -ne 'codex') { $_.effort_vocabulary } elseif ($_.effort_models -eq 'any') { "$($_.effort_vocabulary) (any model)" } elseif ($null -ne $_.effort_models) { "$($_.effort_vocabulary) ($(@($_.effort_models).Count) declared models)" } else { $_.effort_vocabulary })
                limit       = $(if ($_.last_failure) { "$($failureLabel): $($_.last_failure.when) - $($_.last_failure.message)" } else { '-' })
            }
        })
    $cols = @('verdict', 'name', 'kind', 'endpoint', 'credentials', 'effort', 'limit')
    if ($roster.Exists) { $cols = @('verdict', 'name', 'roster', 'kind', 'endpoint', 'credentials', 'effort', 'limit') }
    $width = @{}
    foreach ($col in $cols) { $width[$col] = (@($lines | ForEach-Object { ([string]$_.$col).Length }) | Measure-Object -Maximum).Maximum }
    foreach ($l in $lines) {
        $parts = foreach ($col in $cols) { ([string]$l.$col).PadRight($width[$col]) }
        Write-Host (($parts -join '  ').TrimEnd())
    }
    if ($roster.Exists) {
        if ($walk.Entry) {
            $line = "roster: $($roster.Path) -> would select $(Format-ReviewerLineage -Provider $walk.Identity.Provider -Model $walk.Identity.Model -Engine ([string]$walk.Identity.Engine))"
            if (@($walk.Skipped).Count -gt 0) { $line += " (skipped: $(Format-RosterSkips @($walk.Skipped)))" }
            Write-Host $line
        } else {
            Write-Host "roster: $($roster.Path) -> no entry is available (skipped: $(Format-RosterSkips @($walk.Skipped)))"
        }
    }
    # (wave 24) the one-line view of every entry (the -Short line)
    Write-Host "availability: $($availabilityLine -replace '^codex-consult: ', '')"
}

if ($Provider) {
    $v = [string]$rows[0].verdict
    if ($v -eq 'available') { exit 0 }
    if ($v.StartsWith('unavailable')) { exit 2 }
    exit 3
}
exit 0
