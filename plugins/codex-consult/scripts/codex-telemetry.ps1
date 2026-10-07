<#
.SYNOPSIS
    The telemetry of the codex-consult bridge (wave 28, ROADMAP R17): the sender, the operator's
    complaint and the state - ONE anonymised event per consultation to the maintainer's intake, on
    by default, CODEX_CONSULT_TELEMETRY=off to switch it off.

.DESCRIPTION
    Five forms, one per call:

      -Flush       THE sender. The bridge starts it detached (hidden, never waited for, with a
                   minimal allow-listed environment - wave 28b, D3) after a ledger commit: under
                   the sender lock <codex home>/telemetry-spool/.flush.lock (a marker file; a
                   concurrent sender is refused, exit 2; (wave 28c, D4) a lock is taken over only
                   when its owner is gone, and a sender that lost its lock - its token - stops
                   without rewriting; D5: the 60 s cover every local step too; (wave 28d, D3) the
                   lock is born with its owner record, one without an owner counts as held for 30
                   s, one whose owner lives for 30 minutes is reported "sender stuck"; D1: every
                   spool rewrite replaces the file atomically) it reads the spool oldest first, drops lines older
                   than 7 days, POSTs the events in batches of at most 100 to <intake>/v2/events
                   and the complaint lines one by one to <intake>/v2/complaints (a 3 s connect
                   probe; ONE request is bounded as a whole by 8 s and the whole flush by 60 s -
                   wave 28b, D2; a 429 with Retry-After of at most 60 s that fits the deadline is
                   waited for and sent once more), removes what was delivered, keeps the rest and
                   writes <codex home>/telemetry-spool/.last {time, result, delivered, kept, dropped,
                   rejected, http, not_spooled_seen, not_spooled_folded, notes} - (wave 28e, E2)
                   folding the not-spooled files of gone producers into one line of its notes and
                   removing them ((E20) .last is saved BEFORE the files are deleted; a file that
                   not_spooled_folded names ((E24) {name, bytes}) is deleted without its counted
                   bytes being counted again - only the complete lines beyond them are new; (E26)
                   the legacy file is first renamed to a unique staged name
                   telemetry-not-spooled-legacy-<utc ticks>.ndjson, never counted under its own).
                   Delivered = a 2xx answer that is a JSON object with "ok": true.
                   (D8) A batch refused with 400 "events[i]: reason" drops event i (a line in
                   `rejected`) and resends the rest - at most three times per flush; 413 halves the
                   batch; 403 stops the flush and keeps the spool; any other failure (another 4xx,
                   a 5xx, an HTML page, a timeout) stops there and keeps the spool. With telemetry
                   off (-Telemetry off, else CODEX_CONSULT_TELEMETRY) it sends nothing. Exit 0 done
                   or nothing to send, 1 something not delivered (or the intake URL refused), 2
                   another sender holds the lock.
      -Complain    "<text>" [-Contact <how to reach you>] [-Task <task> [-CollabDir <dir>]]
                   [-Yes]: the payload - the text (at most 8 KiB), the context (the task's last
                   ledger entry through the event's allowlist, the plugin version, the OS), the
                   instance id - is printed in full, then `send? [y/N]` unless -Yes, then sent
                   synchronously (10 s). Delivered: the public_ref to quote. Not delivered: kept in
                   the spool as a complaint line - the sender retries it. Independent of the
                   switch (an explicit, confirmed send). Exit 0 delivered, 1 refused or not
                   confirmed, 3 not delivered (kept - exactly the JSON that was shown, wave 28b
                   D7). codex-consult.ps1 -Task <t> -Complain is the same with the task given.
      -Forget      (wave 28b, D9) delete my data: -PublicRef <ref> sends DELETE
                   <intake>/v2/instances/<instance id>?public_ref=<ref> (the ref a delivered
                   complaint printed); -Local removes the local spool, the salt and the count of
                   events not spooled (the next event makes a new instance id); both may be
                   given - (wave 28c, D2) then the intake FIRST, and the local deletion only after
                   it confirmed the DELETE: any other answer deletes nothing here either (the same
                   command can be repeated). -Local alone says that the intake still holds what was
                   sent and asks `remove locally? [y/N]` unless -Yes. (D3) The local deletion holds
                   the telemetry lock and writes the marker telemetry-forgetting (removed last,
                   (wave 28d, D2) in `finally`; one a killed -Forget left is removed by the next
                   producer or sender - (wave 28e, E3) its owner judged on pid AND its start time in
                   ticks): a consultation that commits meanwhile drops its event
                   (counted). Exit 0 done, 1 refused or not confirmed, 3 the intake did not confirm
                   the deletion.
      -Status      the switch and where it comes from, the intake URL, the spool's counts, (wave
                   28b, D6) the events not spooled since the last flush ((wave 28e, E2) summed over
                   the files telemetry-not-spooled-<pid>-<start ticks>.ndjson - one per producer
                   process, appended without contention - and the legacy single file
                   telemetry-not-spooled.ndjson; a flush folds the files of producers that are gone
                   into one line of .last `notes` and removes them), (wave 28d) the forgetting
                   marker and its owner, the sender's lock (busy, stuck for 30 minutes, stale), the
                   last flush's result and the notes of .last, the instance id (not secret: a
                   salted hash), the notice's state, and test mode when it is on. Reads only; exit 0.
      -BackfillRatings [-DryRun] [-CollabDir <dir>] (R24) sends the judge's marks given BEFORE
                   the rating event existed, once: every mark of every task of the current
                   repository (<collab>/<task>/findings.json `ratings`) without `telemetry_sent` is
                   looked up in that task's sessions.json as -Rate recorded it (consult_id, else n;
                   no entry: skipped and counted - never a guessed reviewer), its `rating` event is
                   built through the same allowlist as -Rate's (client_time = the mark's `when`,
                   age_days from its consult_when) and spooled, and `telemetry_sent` (unix seconds)
                   is written into the mark under the task's store commit - so a second run sends
                   nothing (codex-findings.ps1 -Rate sets the field itself). One line per task
                   `<task>: sent N, already M, skipped K`, then the total; the detached sender starts
                   when something was spooled. -DryRun prints per event the vendor class, the model,
                   the mark and the age - never a text - and writes nothing. Telemetry off (-Telemetry
                   off, else CODEX_CONSULT_TELEMETRY): refused, nothing written. Exit 0 done, 1
                   refused or something not spooled (run it again).

    The intake: CODEX_CONSULT_TELEMETRY_URL (an operator setting), else https://xelth.com/T; https
    only - plain http only for a loopback intake AND with CODEX_CONSULT_TEST_MODE=1 (a harness; wave
    28b, D4). The spool, the salt, the notice's marker: under the Codex home (CODEX_HOME, else
    ~/.codex). TEST HOOKS (test mode only): CODEX_CONSULT_TEST_TELEMETRY_ENV=<path> - the sender
    writes there the NAMES of every variable of its own environment (never a value);
    CODEX_CONSULT_TEST_TELEMETRY_REQUEST_MS / _FLUSH_MS - the request and flush bounds.

    Windows PowerShell 5.1 and PowerShell 7 compatible, no external dependencies.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-telemetry.ps1 -Status

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File codex-telemetry.ps1 -BackfillRatings -DryRun

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

    # With -Complain: send without asking; (wave 28c, D2) with -Forget -Local: remove without asking.
    [switch]$Yes,

    # With -Complain: the task whose last ledger entry goes into the context (optional).
    [string]$Task = '',

    # With -Complain -Task and -BackfillRatings: where consultations are stored (relative: to the
    # git repo root).
    [string]$CollabDir = '.collab',

    # With -Flush and -BackfillRatings: on | off - the bridge passes its run's switch; empty:
    # CODEX_CONSULT_TELEMETRY.
    [string]$Telemetry = '',

    # (R24) Send the marks of this repository's tasks that were never sent (findings.json `ratings`
    # without telemetry_sent) as rating events, once.
    [switch]$BackfillRatings,

    # With -BackfillRatings: print what would be sent (vendor class, model, mark, age), write nothing.
    [switch]$DryRun,

    # (wave 28b, D9) Delete my data: with -PublicRef <ref> at the intake, with -Local here.
    [switch]$Forget,

    # With -Forget: the public_ref a delivered complaint printed (the intake's proof of ownership).
    [string]$PublicRef = '',

    # With -Forget: remove the local spool, the salt and the not-spooled count.
    [switch]$Local
)

$ErrorActionPreference = 'Stop'
$script:ToolName = 'codex-telemetry'
. (Join-Path $PSScriptRoot 'codex-consult-common.ps1')

$forms = @(@('Flush', 'Status', 'Complain', 'Forget', 'BackfillRatings') | Where-Object { $PSBoundParameters.ContainsKey($_) })
if ($forms.Count -ne 1) {
    Stop-WithError "give exactly one of -Flush, -Status, -Complain ""<text>"", -Forget, -BackfillRatings (got $(if ($forms.Count -eq 0) { 'none' } else { '-' + ($forms -join ', -') }))."
}
$Telemetry = ([string]$Telemetry).Trim().ToLowerInvariant()
if ($Telemetry -and @('on', 'off') -notcontains $Telemetry) { Stop-WithError "-Telemetry must be on or off (got '$Telemetry')." }
$commonNames = @([System.Management.Automation.Cmdlet]::CommonParameters) + @([System.Management.Automation.Cmdlet]::OptionalCommonParameters)
$given = @($PSBoundParameters.Keys | Where-Object { $commonNames -notcontains $_ })

# ----------------------------------------------------------------------------- -Flush
if ($Flush) {
    $extra = @($given | Where-Object { @('Flush', 'Telemetry') -notcontains $_ })
    if ($extra.Count -gt 0) { Stop-WithError "-Flush takes only -Telemetry; not -$($extra -join ', -')." }
    # TEST HOOK (test mode only): the NAMES of every variable this process inherited (never a value)
    # - (wave 28b, D3) the bridge starts the sender with the allow-listed environment only
    $envDump = (Get-TestHookValue 'CODEX_CONSULT_TEST_TELEMETRY_ENV')
    if ($envDump) {
        $envNames = [string[]]@([Environment]::GetEnvironmentVariables().Keys | ForEach-Object { [string]$_ })
        [Array]::Sort($envNames, [StringComparer]::OrdinalIgnoreCase)
        try { Write-Utf8NoBom -Path $envDump -Text (($envNames -join "`n") + $(if ($envNames.Count -gt 0) { "`n" } else { '' })) } catch { }
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

# ----------------------------------------------------------------------------- -BackfillRatings (R24)
if ($BackfillRatings) {
    $extra = @($given | Where-Object { @('BackfillRatings', 'DryRun', 'CollabDir', 'Telemetry') -notcontains $_ })
    if ($extra.Count -gt 0) { Stop-WithError "-BackfillRatings takes only -DryRun, -CollabDir and -Telemetry; not -$($extra -join ', -')." }
    $collabRoot = Resolve-CollabRoot -RepoRoot (Resolve-RepoRoot -Cwd (Get-Location).Path) -CollabDir $CollabDir
    exit (Invoke-TelemetryBackfillRatings -CollabRoot $collabRoot -Switch (Get-TelemetrySwitch -Override $Telemetry) -DryRun:$DryRun)
}
if ($DryRun) { Stop-WithError "-DryRun goes with -BackfillRatings." }

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

# ----------------------------------------------------------------------------- -Forget (wave 28b, D9)
if ($Forget) {
    $extra = @($given | Where-Object { @('Forget', 'PublicRef', 'Local', 'Yes') -notcontains $_ })
    if ($extra.Count -gt 0) { Stop-WithError "-Forget takes only -PublicRef <ref>, -Local and -Yes; not -$($extra -join ', -')." }
    exit (Invoke-TelemetryForget -PublicRef $PublicRef -Local:$Local -Yes:$Yes)
}
foreach ($only in @('PublicRef', 'Local')) { if ($PSBoundParameters.ContainsKey($only)) { Stop-WithError "-$only goes with -Forget." } }

# ----------------------------------------------------------------------------- -Status
$extra = @($given | Where-Object { @('Status') -notcontains $_ })
if ($extra.Count -gt 0) { Stop-WithError "-Status takes no other parameter; not -$($extra -join ', -')." }
$sw = Get-TelemetrySwitch
$p = Get-TelemetryPaths
$u = Get-TelemetryUrl
Write-Host "codex-telemetry: telemetry $($sw.Text) ($($sw.Source)) - CODEX_CONSULT_TELEMETRY=off switches it off, -Telemetry off for one run; README ""Telemetry (on by default)"""
if (Test-TestMode) { Write-Host 'test mode  : ON - CODEX_CONSULT_TEST_MODE=1: test hooks are honoured and plain http to a loopback intake is accepted' -ForegroundColor Yellow }
Write-Host "intake     : $(if ($u.Error) { "REFUSED - $($u.Error)" } elseif ($u.Source -eq 'the default') { "$($u.Base) (the default; CODEX_CONSULT_TELEMETRY_URL overrides)" } else { "$($u.Base) (CODEX_CONSULT_TELEMETRY_URL)" })"
if (-not $p) {
    Write-Host 'spool      : none - no codex home (CODEX_HOME, else ~/.codex)'
    exit 0
}
$c = Get-TelemetrySpoolCounts
$oldest = $(if ($null -ne $c.Oldest) { '; oldest queued ' + [DateTimeOffset]::FromUnixTimeSeconds([long]$c.Oldest).ToLocalTime().ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant) } else { '' })
Write-Host "spool      : $($p.Spool) - $($c.Events) event(s), $($c.Complaints) complaint(s)$(if ($c.Invalid -gt 0) { ", $($c.Invalid) unreadable line(s)" }) in $($c.Files) file(s)$oldest"
# (wave 28b, D6) the events that could not be spooled since the last flush - (wave 28e, E2) summed over
# the files of every producer (and the legacy single file)
$ns = Get-TelemetryNotSpooled
$nsFilesText = $(if ($ns.Files -gt 0) { " ($($ns.Total) line(s) in $($ns.Files) file(s), one per producer - a flush folds those of gone producers into .last)" } else { '' })
Write-Host "not spooled: $(if ($ns.Count -gt 0) { "$($ns.Count) event(s) since the last flush - the latest $($ns.When): $($ns.Last)" } else { 'none since the last flush' })$nsFilesText"
# (wave 28c, D3) a -Forget -Local that runs, or that died halfway; (wave 28d, D2) its owner named
$fm = Get-TelemetryForgettingOwner -Path $p.Forgetting
if ($fm.There) {
    if ($fm.Alive) { Write-Host "forgetting : the marker $($p.Forgetting) is there - its owner pid $($fm.Pid) lives (a -Forget -Local runs now$(if ($fm.Since) { ", since $($fm.Since)" })): events are dropped until it finishes" -ForegroundColor Yellow }
    else { Write-Host "forgetting : the marker $($p.Forgetting) is there - its owner $(if ($fm.Pid -gt 0) { "pid $($fm.Pid) is gone" } else { 'is not named' }) (a -Forget -Local that did not finish): the next event or sender removes it; run codex-telemetry.ps1 -Forget -Local again to finish the deletion" -ForegroundColor Yellow }
}
# (wave 28d, D3) the sender's lock as it is (read only): busy, stuck (30 minutes), or stale
if ([IO.File]::Exists($p.Lock)) {
    $lo = Get-TelemetryFlushLockOwner -Text (Read-SharedText -Path $p.Lock)
    $lAge = 0
    try { $lAge = [int]([DateTime]::UtcNow - [IO.File]::GetLastWriteTimeUtc($p.Lock)).TotalSeconds } catch { }
    $lSince = $(if ($lo.Since) { $lo.Since } else { try { [IO.File]::GetLastWriteTimeUtc($p.Lock).ToLocalTime().ToString('yyyy-MM-ddTHH:mm:sszzz', $script:Invariant) } catch { '?' } })
    if ($lo.Owner -eq 'alive' -and $lAge -ge $script:TelemetryStuckLockSec) { Write-Host "sender     : sender stuck since $lSince (pid $($lo.Pid)) - its lock $($p.Lock) is $([int]($lAge / 60)) min old and its owner lives: it is never taken over; stop pid $($lo.Pid) if it hangs, or delete the lock when no such process runs" -ForegroundColor Yellow }
    elseif ($lo.Owner -eq 'alive') { Write-Host "sender     : busy since $lSince (pid $($lo.Pid) holds its lock, $lAge s old)" }
    elseif ($lo.Owner -eq 'gone') { Write-Host "sender     : a lock whose owner pid $($lo.Pid) is gone - the next sender removes it" }
    else { Write-Host "sender     : a lock that names no owner ($lAge s old) - held while younger than $($script:TelemetryOwnerlessLockSec) s, then removed by the next sender" }
}
$last = Read-TelemetryLast
$lastResult = [string](Get-PropertyValue $last 'result' '')
Write-Host "last flush : $(if ($lastResult) { "$([string](ConvertTo-JsonText (Get-PropertyValue $last 'time' ''))) - $lastResult" } else { 'never' })"
# (wave 28d, D2, D3) what the telemetry client did or saw on its own (.last notes)
foreach ($nt in @(Get-PropertyValue $last 'notes' @())) { if ($nt) { Write-Host "note       : $nt" } }
$iid = Get-TelemetryInstanceId
Write-Host "instance id: $(if ($iid) { "$iid (SHA-256 of the salt $($p.Salt) and the machine name; a new salt makes a new instance)" } else { '(none yet - the first event creates the salt)' })"
Write-Host "notice     : $(if ([IO.File]::Exists($p.Notice)) { "shown for $(Get-BridgeVersion) ($($p.Notice))" } else { "not shown yet for $(Get-BridgeVersion) - the next consultation with telemetry on prints it" })"
exit 0
