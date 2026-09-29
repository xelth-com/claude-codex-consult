<#
.SYNOPSIS
    SessionStart hook: one line saying which reviewers are out right now, and until when, and
    one line pointing the coordinator at its rules.

.DESCRIPTION
    Runs at the start of the coordinator's session in any project where the plugin is enabled
    (hooks/hooks.json - the host adds the output to the agent's context), or by hand from a host
    without hooks (the one-liner: powershell -NoProfile -ExecutionPolicy Bypass -File
    <plugin>/scripts/codex-consult-hook.ps1). Prints the AVAILABILITY line first (wave 24,
    D14-D17 - the line `codex-providers.ps1 -Short` prints):

        codex-consult: out - openai :: gpt-6-astra (until Sun 20:35, in 2d 10h), gemini :: *
        (until Sun 21:30, in 2d 11h); 9 of 11 reviewers available

    or `codex-consult: all 11 reviewers available`. Every roster entry is judged with the
    roster walk's own verdict (Select-PanelMembers -All: credentials, the launch invariant,
    the endpoint health of THIS repository's ledgers - an auth failure, a usage limit with a
    reset ahead, one without a reset for 60 minutes after it was hit, a burst 429 for 10); the entries of one
    endpoint group that share the state collapse to `<label> :: *`; reset times are LOCAL
    with a rounded relative hint; nothing is cut. An entry whose check needs the network (the
    agy engine's `agy models`) is `not checked` here - "..., 2 not checked" in the count -
    unless THIS repository's ledgers hold a usable reply on that endpoint from the last 60
    minutes (then it is available); a recorded auth failure or usage limit still shows it
    out. The muse engine's sign-in check reads ~/.config/muse/auth.json locally and runs here
    too, as does its billing guard (`meta :: <model> (refused: META_API_KEY is set)`).
    Without a roster: the providers of the Codex config ("... (no reviewer roster)").

    When the Codex CLI is not on PATH: `codex-consult: codex CLI not found on PATH - follow
    the setup-providers skill`. Everything else (an unreadable config, an unusable roster, a
    crash inside the check) is reported in the same one-line form and never fails the
    session: the exit code is always 0. No network call, no lock, nothing written: it runs
    `codex-providers.ps1 -Short -Json -NoNetwork` and prints the `line` of its object.

    (wave 25, R12) The detached consultations of the repository (codex-consult.ps1 -Detach) add
    one phrase to that line - `; 1 detached consultation running (task t)`, `; 2 detached
    consultations finished (tasks t, u)` (finished in the last 24 h), `; detached consultations:
    1 running (task t), 1 died (task u)` - read from the status files
    <CollabDir>/*/.consult.detached-*.status.json, a background's liveness judged by its pid and
    start time (Get-DetachedPhrase). Nothing when there is none.

    (wave 27, R13 D5) Then ONE pointer line, always, whatever the first line says:

        codex-consult: coordinator rules - skill codex-consult:coordinate (or codex-consult.ps1 -Explain coordinate)

    Cost: about one second (one `codex login status` for the built-in openai; wave 24b: each
    roster entry's identity and each endpoint's health are resolved once per listing - the
    walk, the availability line and the rows share them - and the ledgers are read once), once
    per session. Disable the hook with the plugin (the host's plugin switch).

    Runs on Windows PowerShell 5.1 and PowerShell 7.
#>
[CmdletBinding()]
param(
    # Where consultations are stored (endpoint health is read from every task ledger
    # under it). Relative paths resolve against the git repo root of the current directory.
    [string]$CollabDir = '.collab'
)

$ErrorActionPreference = 'Stop'
$line = ''
try {
    $providers = Join-Path $PSScriptRoot 'codex-providers.ps1'
    $psExe = (Get-Process -Id $PID).Path
    $codex = Get-Command codex -ErrorAction SilentlyContinue
    if (-not $codex) {
        $line = 'codex-consult: codex CLI not found on PATH - follow the setup-providers skill before consulting a reviewer'
    } else {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $raw = @(& $psExe -NoProfile -ExecutionPolicy Bypass -File $providers -Short -Json -NoNetwork -CollabDir $CollabDir 2>&1 | ForEach-Object { "$_" })
        $code = $LASTEXITCODE
        $ErrorActionPreference = $previous
        $jsonStart = -1
        for ($i = 0; $i -lt $raw.Count; $i++) { if ($raw[$i] -match '^\s*\{') { $jsonStart = $i; break } }
        $obj = $null
        if ($jsonStart -ge 0) {
            try { $obj = (($raw[$jsonStart..($raw.Count - 1)]) -join "`n") | ConvertFrom-Json } catch { $obj = $null }
        }
        $text = $(if ($obj) { [string]$obj.line } else { '' })
        if ($text -match '^codex-consult: ' -and $text -notmatch "[`r`n]") {
            $line = $text
        } else {
            $first = (@($raw | Where-Object { $_ -and $_.Trim() }) | Select-Object -First 1)
            if (-not $first) { $first = "codex-providers.ps1 exited $code without output" }
            $line = "codex-consult: reviewer check failed - $first"
        }
    }
} catch {
    $msg = ("$($_.Exception.Message)" -replace '\s+', ' ').Trim()
    if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 117) + '...' }
    $line = "codex-consult: reviewer check failed - $msg"
}
# (wave 25, R12) the detached consultations of this repository: one phrase, status files only;
# a failure here never changes the line. (wave 26, F07-3) Only the small readers' file is
# dot-sourced here - never the whole common script.
try {
    . (Join-Path $PSScriptRoot 'codex-consult-detached.ps1')
    $detachedPhrase = Get-DetachedPhrase -CollabRoot (Resolve-CollabRoot -RepoRoot (Resolve-RepoRoot -Cwd (Get-Location).Path) -CollabDir $CollabDir)
    if ($detachedPhrase) { $line += $detachedPhrase }
} catch { }
Write-Output $line
# (wave 27, R13 D5) the pointer to the coordinator's rules - a host without skills reads them with
# -Explain coordinate
Write-Output 'codex-consult: coordinator rules - skill codex-consult:coordinate (or codex-consult.ps1 -Explain coordinate)'
exit 0
