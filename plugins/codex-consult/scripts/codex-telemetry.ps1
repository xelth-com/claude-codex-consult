<#
.SYNOPSIS
    The telemetry of the codex-consult bridge (wave 28, ROADMAP R17): the sender, the operator's
    complaint and the state - ONE anonymised event per consultation to the maintainer's intake, on
    by default, CODEX_CONSULT_TELEMETRY=off to switch it off.

.DESCRIPTION
    Three forms, one per call:

      -Flush       THE sender. The bridge starts it detached (hidden, never waited for) after a
                   ledger commit: under the sender lock <codex home>/telemetry-spool/.flush.lock (a
                   concurrent sender is refused, exit 2) it reads the spool oldest first, drops
                   lines older than 7 days, POSTs the events in batches of at most 100 to
                   <intake>/v2/events and the complaint lines one by one to <intake>/v2/complaints
                   (a 3 s connect probe, 5 s in all per request; a 429 with Retry-After of at most
                   60 s is waited for and sent once more - no other retry), removes what was
                   delivered, keeps the rest, stops at the first failure and writes
                   <codex home>/telemetry-spool/.last {time, result, delivered, kept, dropped,
                   http}. Delivered = a 2xx answer that is a JSON object with "ok": true; anything
                   else (an HTML page, a 4xx/5xx, a timeout) keeps the spool. With telemetry off
                   (-Telemetry off, else CODEX_CONSULT_TELEMETRY) it sends nothing. Exit 0 done or
                   nothing to send, 1 something not delivered (or the intake URL refused), 2 another
                   sender holds the lock.
      -Complain    "<text>" [-Contact <how to reach you>] [-Task <task> [-CollabDir <dir>]]
                   [-Yes]: the payload - the text (at most 8 KiB), the context (the task's last
                   ledger entry through the event's allowlist, the plugin version, the OS), the
                   instance id - is printed in full, then `send? [y/N]` unless -Yes, then sent
                   synchronously (10 s). Delivered: the public_ref to quote. Not delivered: kept in
                   the spool as a complaint line - the sender retries it. Independent of the
                   switch (an explicit, confirmed send). Exit 0 delivered, 1 refused or not
                   confirmed, 3 not delivered (kept). codex-consult.ps1 -Task <t> -Complain is the
                   same with the task given.
      -Status      the switch and where it comes from, the intake URL, the spool's counts, the last
                   flush's result, the instance id (not secret: a salted hash), the notice's state.
                   Reads only; exit 0.

    The intake: CODEX_CONSULT_TELEMETRY_URL, else https://xelth.com/T; https only (plain http only
    for a loopback test intake). The spool, the salt, the notice's marker: under the Codex home
    (CODEX_HOME, else ~/.codex). TEST HOOK: CODEX_CONSULT_TEST_TELEMETRY_ENV=<path> - the sender
    writes there the NAMES of the coordinator's host markers in its own environment (none: an empty
    file).

    Windows PowerShell 5.1 and PowerShell 7 compatible, no external dependencies.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-telemetry.ps1 -Status

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-telemetry.ps1 -Complain "The panel summary hides which member timed out." -Task cache-rewrite
#>
[CmdletBinding()]
param(
    # THE sender: deliver the spool (the bridge starts it detached after a ledger commit).
    [switch]$Flush,

    # The switch, the spool, the last flush, the instance id, the notice. Reads only.
    [switch]$Status,

    # A complaint or a suggestion to the maintainer (at most 8 KiB): printed, confirmed, sent.
    [string]$Complain = '',

    # With -Complain: how the maintainer can reach you (optional; null when not given).
    [string]$Contact = '',

    # With -Complain: send without asking.
    [switch]$Yes,

    # With -Complain: the task whose last ledger entry goes into the context (optional).
    [string]$Task = '',

    # With -Complain -Task: where consultations are stored (relative: to the git repo root).
    [string]$CollabDir = '.collab',

    # With -Flush: on | off - the bridge passes its run's switch; empty: CODEX_CONSULT_TELEMETRY.
    [string]$Telemetry = ''
)

$ErrorActionPreference = 'Stop'
$script:ToolName = 'codex-telemetry'
. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

$forms = @(@('Flush', 'Status', 'Complain') | Where-Object { $PSBoundParameters.ContainsKey($_) })
if ($forms.Count -ne 1) {
    Stop-WithError "give exactly one of -Flush, -Status, -Complain ""<text>"" (got $(if ($forms.Count -eq 0) { 'none' } else { '-' + ($forms -join ', -') }))."
}
$Telemetry = ([string]$Telemetry).Trim().ToLowerInvariant()
if ($Telemetry -and @('on', 'off') -notcontains $Telemetry) { Stop-WithError "-Telemetry must be on or off (got '$Telemetry')." }
$commonNames = @([System.Management.Automation.Cmdlet]::CommonParameters) + @([System.Management.Automation.Cmdlet]::OptionalCommonParameters)
$given = @($PSBoundParameters.Keys | Where-Object { $commonNames -notcontains $_ })

# ----------------------------------------------------------------------------- -Flush
if ($Flush) {
    $extra = @($given | Where-Object { @('Flush', 'Telemetry') -notcontains $_ })
    if ($extra.Count -gt 0) { Stop-WithError "-Flush takes only -Telemetry; not -$($extra -join ', -')." }
    # TEST HOOK: the host markers this process inherited (names only) - the bridge starts the
    # sender without them
    $envDump = (Get-TestHookValue 'CODEX_CONSULT_TEST_TELEMETRY_ENV')
    if ($envDump) {
        # (Get-HostMarkerNames hands back the array itself: assigned, never @()-wrapped)
        $markerNames = Get-HostMarkerNames
        try { Write-Utf8NoBom -Path $envDump -Text (($markerNames -join "`n") + $(if ($markerNames.Count -gt 0) { "`n" } else { '' })) } catch { }
    }
    $sw = Get-TelemetrySwitch -Override $Telemetry
    if (-not $sw.On) {
        Write-Host "codex-telemetry: telemetry is off ($($sw.Source)): nothing is sent; the spool stays as it is."
        exit 0
    }
    $r = Invoke-TelemetryFlush
    Write-Host "codex-telemetry: $($r.Result)"
    exit $r.Exit
}

# ----------------------------------------------------------------------------- -Complain
if ($PSBoundParameters.ContainsKey('Complain')) {
    $extra = @($given | Where-Object { @('Complain', 'Contact', 'Yes', 'Task', 'CollabDir') -notcontains $_ })
    if ($extra.Count -gt 0) { Stop-WithError "-Complain takes only -Contact, -Yes, -Task and -CollabDir; not -$($extra -join ', -')." }
    if ($PSBoundParameters.ContainsKey('CollabDir') -and -not $Task) { Stop-WithError "-CollabDir goes with -Task (the task whose last ledger entry goes into the context)." }
    $entry = $null
    if ($Task) {
        if ($Task -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Stop-WithError "-Task must be a slug (letters, digits, dot, dash, underscore)." }
        $sessions = Join-Path (Join-Path (Resolve-CollabRoot -RepoRoot (Resolve-RepoRoot -Cwd (Get-Location).Path) -CollabDir $CollabDir) $Task) 'sessions.json'
        if (-not (Test-Path -LiteralPath $sessions -PathType Leaf)) { Stop-WithError "task '$Task' has no ledger ($sessions); leave -Task out for a complaint without a consultation's context." }
        try { $entry = @(Get-PropertyValue (Get-PropertyValue (ConvertFrom-Json -InputObject (Read-SharedText -Path $sessions)) 'codex' $null) 'consults' @() | Where-Object { $_ }) | Select-Object -Last 1 } catch {
            Stop-WithError "the ledger '$sessions' could not be read ($(ConvertTo-OneLine $_.Exception.Message))."
        }
    }
    exit (Invoke-TelemetryComplaint -Text $Complain -Contact $Contact -Entry $entry -Yes:$Yes)
}

# ----------------------------------------------------------------------------- -Status
$extra = @($given | Where-Object { @('Status') -notcontains $_ })
if ($extra.Count -gt 0) { Stop-WithError "-Status takes no other parameter; not -$($extra -join ', -')." }
$sw = Get-TelemetrySwitch
$p = Get-TelemetryPaths
$u = Get-TelemetryUrl
Write-Host "codex-telemetry: telemetry $($sw.Text) ($($sw.Source)) - CODEX_CONSULT_TELEMETRY=off switches it off, -Telemetry off for one run; README ""Telemetry (on by default)"""
Write-Host "intake     : $(if ($u.Error) { "REFUSED - $($u.Error)" } elseif ($u.Source -eq 'the default') { "$($u.Base) (the default; CODEX_CONSULT_TELEMETRY_URL overrides)" } else { "$($u.Base) (CODEX_CONSULT_TELEMETRY_URL)" })"
if (-not $p) {
    Write-Host 'spool      : none - no codex home (CODEX_HOME, else ~/.codex)'
    exit 0
}
$c = Get-TelemetrySpoolCounts
$oldest = $(if ($null -ne $c.Oldest) { '; oldest queued ' + [DateTimeOffset]::FromUnixTimeSeconds([long]$c.Oldest).ToLocalTime().ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant) } else { '' })
Write-Host "spool      : $($p.Spool) - $($c.Events) event(s), $($c.Complaints) complaint(s)$(if ($c.Invalid -gt 0) { ", $($c.Invalid) unreadable line(s)" }) in $($c.Files) file(s)$oldest"
$last = Read-TelemetryLast
Write-Host "last flush : $(if ($last) { "$([string](ConvertTo-JsonText (Get-PropertyValue $last 'time' ''))) - $([string](Get-PropertyValue $last 'result' ''))" } else { 'never' })"
$iid = Get-TelemetryInstanceId
Write-Host "instance id: $(if ($iid) { "$iid (SHA-256 of the salt $($p.Salt) and the machine name; a new salt makes a new instance)" } else { '(none yet - the first event creates the salt)' })"
Write-Host "notice     : $(if ([IO.File]::Exists($p.Notice)) { "shown for $(Get-BridgeVersion) ($($p.Notice))" } else { "not shown yet for $(Get-BridgeVersion) - the next consultation with telemetry on prints it" })"
exit 0
