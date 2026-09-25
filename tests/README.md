# tests

Scripted harnesses for the bridge scripts in `plugins/codex-consult/scripts/`. They
never call a model: every consultation runs against a FAKE codex (`fake-codex.cmd` /
`fake-codex.ps1`, and `fake-codex3.cmd` / `fake-codex3.ps1` for the 0.3.0 cases), which
prints a scripted JSONL event stream and copies a prepared reply. The real `codex` CLI
and your own `~/.codex/config.toml` are not used (the 0.3.0 harness points `CODEX_HOME`
at scratch directories and only compares your config's hash before and after). `harness-roster.ps1` also points
`CODEX_CONSULT_ROSTER` at scratch roster files; the other harnesses set it to `none` (no
roster, the default file is ignored too), so a real roster never changes what they test.

Every assertion prints one line starting with `PASS` or `FAIL` and its evidence; each
harness ends with `<harness>...: N failure(s).` and exits 1 when anything failed.

| harness | covers |
|---|---|
| `harness-0.3.ps1` | 0.3.0: constrained TOML scanner, reviewer identity and provider fingerprint, user-defined `[model_providers.openai]`, absent `wire_api`, lineage-scoped parent threads, rollout fallback verified by the consultation id, event drift nets, effort vocabularies, peak windows, requested-checks prompt, ledger field order, timeout kill without false survivors |
| `harness-roster.ps1` | reviewer roster: file validation (fail-closed), the selection rules (`-Provider` defaults, `-Thread` fixes the reviewer, the roster walk, `-Model` filter, `auth: none`), usage limits with a known reset time (`Get-RetryAfter`, `provider_failure.retry_after`, the frozen consult clock), the F12-2 classifier order, UTF-8 capture of codex's stderr and `login status`, `-SchemaTransport`, the roster view of `codex-providers.ps1`, the review panel (`-Panel`, `-PanelAll`, `"panel": "weighty"`), the `chore` purpose, the per-reviewer scoreboard of `codex-findings.ps1 -Stats`, the judge's marks (`codex-findings.ps1 -Rate`), `codex-scoreboard.ps1`, reset times across daylight-saving changes, timestamps keeping their offset on pwsh, future-stamped failures, a panel stopped by a member's surviving processes |
| `harness-format.ps1` | the first-turn output contract (the prompt opens with the FINAL OUTPUT CONTRACT paragraph) and the format repair (`-FormatRetry`): prose then JSON on `resume`, prose twice, drift notes, a different thread, the cases that must not repair, panel members (the fake answers the repair turn from `FAKE_CODEX_RESUME_REPLY`); wave 15: the prose gate (refusals, short replies, every numbered-answer style), drift check 5 over every long sentence, the recovery record naming the orphaned original when the bridge dies during the repair turn |
| `harness-pending.ps1` | 0.2.0 recovery record (`.consult.pending.json`): reservations, survivors, injected registration failure, crash at lock acquisition |
| `harness-fixes.ps1` | 0.2.0 review findings F04-1..F04-11: atomic stores, lock contention, numbering, prior blockers, validation, fingerprints, timeout kill |
| `harness-lock2.ps1` | the held-handle task lock, including a consultation in flight |
| `harness-3b.ps1` | survivor / launching-record judgement (`Test-PendingActive`) |

`harness-fixes.ps1` F04-1 hard-kills a store rewrite 12 times and judges each kill on its own (a damaged or missing store is re-seeded before the next kill; any damage fails it): stores are replaced by one atomic rename - MoveFileExW(REPLACE_EXISTING | WRITE_THROUGH) on Windows PowerShell 5.1, `File.Move` with overwrite on PowerShell 7.

## Requirements

* Windows (the fake codex is a `.cmd` shim; several cases use Win32 process APIs).
* Windows PowerShell 5.1 runs everything. `harness-0.3.ps1`, `harness-roster.ps1` and
  `harness-format.ps1` also run under PowerShell 7 (`pwsh`); the 0.2.0 harnesses start their child processes with
  `powershell.exe` whichever host runs them.
* `git` on PATH.

## Running

Run the harnesses ONE AT A TIME - never two in parallel: the recovery checks look for
codex-like processes and would see each other's fake codex. `run-all.ps1` does that,
from any current directory:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1
pwsh -NoProfile -File tests/run-all.ps1 -Only harness-roster,harness-0.3
```

It prints one summary line per harness (`PASS=` / `FAIL=` counts, exit code, time,
the harness's own summary line) and exits 1 if any harness failed. A single harness
can be run directly, and most take `-Only <section>[,<section>]`:

```
powershell -NoProfile -ExecutionPolicy Bypass -File tests/harness-0.3.ps1 -Only OPENAI,WIRE
```

Each run works in `$env:TEMP\codex-consult-tests\<harness>\<guid>` and removes it at the
end; `run-all.ps1` keeps each harness's full output in
`$env:TEMP\codex-consult-tests\run-all-<timestamp>\`. A full run takes about ten minutes
(the process and lock cases wait on real timeouts).
