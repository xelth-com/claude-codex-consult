# tests

Scripted harnesses for the bridge scripts in `plugins/codex-consult/scripts/`. They
never call a model: every consultation runs against a FAKE codex (`fake-codex.cmd` /
`fake-codex.ps1`, and `fake-codex3.cmd` / `fake-codex3.ps1` for the 0.3.0 cases), which
prints a scripted JSONL event stream and copies a prepared reply, or - for the `agy`
engine (0.4.0) - a FAKE agy (`fake-agy.cmd` / `fake-agy.ps1`, pointed at by
`CODEX_CONSULT_AGY_EXE`), which reads the prompt as one NDJSON line on stdin and prints
agy's init / step_update / result events (its `FAKE_AGY_*` switches are listed at the top of
`fake-agy.ps1`), or - for the `muse` engine (wave 23) - a FAKE muse (`fake-muse.cmd` /
`fake-muse.ps1`, pointed at by `CODEX_CONSULT_MUSE_EXE`), which reads the prompt from
`--prompt-file`, rejects any flag the real CLI does not have (exit 2) and prints MSP JSONL
records shaped like a sanitized real probe (its `FAKE_MUSE_*` switches are listed at the top of
`fake-muse.ps1`). The real `agy` and `muse` CLIs are never started, and no real credential is
read: `harness-muse.ps1` gives every child a scratch USERPROFILE/HOME with a fake
`~/.config/muse/auth.json`, a scratch LOCALAPPDATA and a PATH without any muse launcher, and
refuses to run when a real muse would still resolve. The real `codex` CLI
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
| `harness-engines.ps1` | 0.4.0 engines (the `agy` engine): roster `engine` validation, the dry-run argv and the engine refusals (fork, workspace-write, output-schema, -CodexConfig), a full run's ledger (engine, fingerprint, thread, usage mapping, native transport, NN-agy-* handoffs, findings), the prompt on stdin byte for byte (`"`, `\`, `%APPDATA%`, a newline, non-ASCII), resume and the conversation-id rules, the denial retry (F11), every failure rule and class with Google's wordings and reset times, the format repair through `--conversation` (wave 23b: a prompt-only run's repair and denial retry pass no `--json-schema`; ledger `format_retry.schema_transport`), the read-only tree check (the tree and the WHOLE collab directory - another task, a task store - with the new "changed during the run (by the reviewer or anyone else)" wording, and the documented blind spot of a gitignored path), the retry turns' event streams in the ledger (`denial_retry.events`, `format_retry.events`), trailing garbage after the result (malformed on exit 0, a partial line after a kill), the warning for a `-Provider` label that names several roster entries, the timeout kill and the recovery record naming the event stream, a mixed codex + agy panel, `codex-providers.ps1` engine rows and `-NoNetwork`, the SessionStart hook line, the sign-in check (45 s, shortened by the test hook `CODEX_CONSULT_TEST_LOGIN_TIMEOUT`; no `agy models` call after a usable agy reply within 60 minutes, the endpoint health still in front), the scoreboards |
| `harness-muse.ps1` | wave 23, the `muse` engine (Meta's Muse Code CLI; decisions D1-D16): the engine row and the adapter contract (one turn-options object, every turn's own prompt file), a static check that `codex-consult.ps1` calls no engine function by name (D2, every engine), argv against the real flag spellings, the MSP parser and the turn rules (schema_version, one session, one terminal on the session stream, the served model, exit 2 / 130 / 143, the step cap, Meta's quota wording verbatim with its reset time), caps-v1 `muse-v1` and the loud plan error for an undeclared vocabulary, the three sign-in states and the credential values never leaking, the billing guard (META_API_KEY / MODEL_API_KEY, `-SkipPreflight`, the roster walk, a panel member, a non-oauth mechanism, the listing), `-EngineExe` bound to the selected engine and the launcher chain down to `%LOCALAPPDATA%\Programs\muse\muse.cmd`, the harness string from `.muse-version` / `.muse-release-info.json` / `--version`, a full run (empty stdin, the prompt file, the ledger's `engine_run`, the field order, the handoff), prompt and launcher paths with spaces through the `.cmd` chain and the `%` refusal, every failure rule end to end, one Meta sign-in = one endpoint (a quota blocks the other muse label), the tree check and D12's forced class `permission` for muse AND agy, resume and a session mismatch, the format repair served through the muse adapter (its own prompt file, `--session-id`, effort low, two prompts), no denial retry, `-MaxModelSteps` in the dry run / the panel spec / the ledger, `codex-providers.ps1` muse rows; wave 23b (the acceptance panel's F09-1..3): the billing guard fail-closed (no ESTABLISHED oauth sign-in - the keychain backend, no `auth.json`, no mechanism - is refused under `-SkipPreflight`, in the dry run, the roster walk, a real panel and the listing; nothing started), a prompt-only run's format repair without `--output-schema` (ledger `format_retry.schema_transport`), the MSP evidence bound to the session stream and the run it links (`ambiguous provenance` for a nested or sub-stream record, in-process and end to end through the fake's `FAKE_MUSE_LINK` / `FAKE_MUSE_MODEL_STREAM` / `FAKE_MUSE_MODEL_RUN` / `FAKE_MUSE_TERMINAL_RUN`); the scratch home carries an `AppData\Local` (without it Windows PowerShell 5.1 writes its ModuleAnalysisCache into the test repository) |
| `harness-panel.ps1` | 0.4.x wave 21, the parallel panel (ROADMAP R11, decisions D1-D13): the plan (endpoint groups, the roster's `"parallel"`, `-PanelConcurrency`), members overlapping in time and the panel's wall clock below the members' sum, the ledger sorted by n and findings in id order when the slowest member is first in roster order, no lost update under the commit write lock (three members' reviewer checks on one prior finding, commits contending), the task lock held for the whole panel and one recovery record per member rewritten by its member, a single run and `-Status` refused meanwhile, a member's plain timeout kill leaving no orphan fake codex and no recovery record (wave 23b), a member's timeout survivors keeping its record while the others run, `-PanelConcurrency 1` strictly sequential, one endpoint one after another, an agy member beside committing siblings (and still failing on another collab write), the panel run killed mid-panel, the member's proof of its parent (checked after its record names it: a new run is refused while the parent dies in between) and its re-check before launching, a commit blocked by a held write lock (panel, single run, `-Status`), a kill inside the commit (ORPHAN; a single run and a panel member), the commits' write-lock waits (`commit_wait_ms`) under contention, `-Rate` refused by an active record, the kill guard, the dry-run plan, and units: `Get-PanelPlan`, `Get-PanelIgnorePrefixes`, `Get-NextNumbers` over several records, `Add-LedgerEntry`, `Get-EndpointHealth` by completion, `Test-PendingActive` (writer liveness, no name rule for member records), `Get-PendingPaths`, `Enter-WriteLock`, the roster `"parallel"` validation. Fake variables: `FAKE_CODEX_DELAY_MS` / `FAKE_CODEX_REPLY_MAP` (keyed by the `-m` model), `FAKE_CODEX_PIDDIR` (one pid file per fake process), `FAKE_CODEX_LOGIN_DELAY_MS`, `FAKE_AGY_DELAY_MS`; test hooks `CODEX_CONSULT_TEST_WRITE_LOCK_SEC`, `CODEX_CONSULT_TEST_COMMIT_PAUSE_MS` (a bare number, or `<model>=<ms>|...`), `CODEX_CONSULT_TEST_PANEL_GUARD_SEC`, `CODEX_CONSULT_TEST_MEMBER_PAUSE_MS` |
| `harness-format.ps1` | the first-turn output contract (the prompt opens with the FINAL OUTPUT CONTRACT paragraph) and the format repair (`-FormatRetry`; ledger `format_retry.schema_transport` `prompt-only` for codex, wave 23b): prose then JSON on `resume`, prose twice, drift notes, a different thread, the cases that must not repair, panel members (the fake answers the repair turn from `FAKE_CODEX_RESUME_REPLY`); wave 15: the prose gate (refusals, short replies, every numbered-answer style), drift check 5 over every long sentence, the recovery record naming the orphaned original when the bridge dies during the repair turn |
| `harness-pending.ps1` | 0.2.0 recovery record (`.consult.pending.json`): reservations, survivors, injected registration failure, crash at lock acquisition |
| `harness-fixes.ps1` | 0.2.0 review findings F04-1..F04-11: atomic stores, lock contention, numbering, prior blockers, validation, fingerprints, timeout kill |
| `harness-lock2.ps1` | the held-handle task lock, including a consultation in flight |
| `harness-3b.ps1` | survivor / launching-record judgement (`Test-PendingActive`) |

`harness-fixes.ps1` F04-1 hard-kills a store rewrite 12 times and judges each kill on its own (a damaged or missing store is re-seeded before the next kill; any damage fails it): stores are replaced by one atomic rename - MoveFileExW(REPLACE_EXISTING | WRITE_THROUGH) on Windows PowerShell 5.1, `File.Move` with overwrite on PowerShell 7.

## Requirements

* Windows (the fake codex is a `.cmd` shim; several cases use Win32 process APIs).
* Windows PowerShell 5.1 runs everything. `harness-0.3.ps1`, `harness-roster.ps1`,
  `harness-format.ps1`, `harness-engines.ps1`, `harness-muse.ps1` and `harness-panel.ps1` also
  run under PowerShell 7 (`pwsh`); the 0.2.0 harnesses start their child processes with
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
