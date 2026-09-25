<#
.SYNOPSIS
    SessionStart hook: one line saying which reviewers are usable right now.

.DESCRIPTION
    Runs at the start of a Claude Code session in any project where the plugin is
    enabled (hooks/hooks.json). Prints ONE line to stdout, which Claude Code adds to the
    agent's context:

        codex-consult: reviewers - openai available | ZAI available | mimo unavailable
        (missing: env MIMO_API_KEY not set); roster -> would select ZAI

    or, when the Codex CLI is not on PATH, `codex-consult: codex CLI not found on PATH -
    follow the setup-providers skill`. Everything else (an unreadable config, an unusable
    roster, a crash inside the check) is reported in the same one-line form and never
    fails the session: the exit code is always 0. No network call, no lock, nothing
    written. The check is the same local one codex-providers.ps1 makes (credentials,
    table usability, endpoint health from THIS repository's ledgers, the roster walk).

    Cost: about one second (`codex login status` for the built-in openai), once per
    session. Disable the hook by disabling the plugin's hooks in Claude Code settings.

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
        $raw = & $psExe -NoProfile -ExecutionPolicy Bypass -File $providers -Json -CollabDir $CollabDir 2>&1 | ForEach-Object { "$_" }
        $code = $LASTEXITCODE
        $ErrorActionPreference = $previous
        $jsonStart = -1
        for ($i = 0; $i -lt $raw.Count; $i++) { if ($raw[$i] -match '^\s*\[') { $jsonStart = $i; break } }
        if ($jsonStart -lt 0) {
            $first = (@($raw | Where-Object { $_ -and $_.Trim() }) | Select-Object -First 1)
            if (-not $first) { $first = "codex-providers.ps1 exited $code without output" }
            $line = "codex-consult: reviewer check failed - $first"
        } else {
            # Pipeline form on purpose: on Windows PowerShell 5.1 `ConvertFrom-Json -InputObject`
            # hands a JSON array back as ONE object, which @() would not unroll.
            $jsonText = ($raw[$jsonStart..($raw.Count - 1)]) -join "`n"
            $rows = @()
            foreach ($item in ($jsonText | ConvertFrom-Json)) { $rows += $item }
            $parts = New-Object System.Collections.Generic.List[string]
            $selected = ''
            foreach ($r in $rows) {
                $verdict = [string]$r.verdict
                $short = $verdict
                if ($verdict -match '^(available|unavailable|unknown)\s*(\((.*)\))?$') {
                    $short = $Matches[1]
                    if ($Matches[3]) {
                        $reason = $Matches[3]
                        if ($reason.Length -gt 60) { $reason = $reason.Substring(0, 57) + '...' }
                        $short += " ($reason)"
                    }
                }
                $parts.Add("$($r.name) $short")
                if ($r.roster_selected -eq $true) { $selected = [string]$r.name }
            }
            $line = 'codex-consult: reviewers - ' + ($parts.ToArray() -join ' | ')
            if ($selected) { $line += "; roster -> would select $selected" }
            elseif (@($rows | Where-Object { $null -ne $_.roster_position }).Count -gt 0) { $line += '; roster -> no entry is available' }
        }
    }
} catch {
    $msg = ("$($_.Exception.Message)" -replace '\s+', ' ').Trim()
    if ($msg.Length -gt 120) { $msg = $msg.Substring(0, 117) + '...' }
    $line = "codex-consult: reviewer check failed - $msg"
}
Write-Output $line
exit 0
