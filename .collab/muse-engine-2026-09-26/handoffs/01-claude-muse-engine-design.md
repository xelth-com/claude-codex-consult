# Engine `muse` (ROADMAP R10, third engine): design for review (base 37b98b4)

Goal: let the roster use Meta's Muse Code subscription. That subscription works only through
Meta's own CLI signed in by browser; any API key (`META_API_KEY`, `MODEL_API_KEY`) overrides
the sign-in and bills per token. So, like agy for Gemini, the bridge drives the vendor's CLI.

## Verified facts (Muse Code 1.4.0, Windows 11, 2026-09-25/26)

- Launcher chain: `muse.cmd` (in `%LOCALAPPDATA%\Programs\muse`, on the user PATH) runs a
  PowerShell launcher `.muse-launcher.ps1`, which runs `muse-bin-<version>.exe` (434 MB); the
  launcher can update the binary.
- Headless: `muse exec --json --prompt-file P --output-schema S --model M
  --reasoning-effort E --no-foreign-personal-context --disable-web-tools --disable-write
  --disable-shell --approval-mode never --max-model-steps N [--session-id UUID]`, run in the
  repository root: exit 0 in 20-31 s on small prompts. With `--disable-shell` and
  `--disable-write` the model still reads files through its native `read_file` tool (probe:
  it read ROADMAP.md and quoted its first heading); the repository was unchanged afterwards.
- `--json` emits MSP JSONL records `{schema_version, id, stream{kind,id}, sequence,
  record_type, payload_type, payload, ...}`. Session id = `stream.id` of a record whose
  `stream.kind` is `session`. Model = `payload.model_id` of `run.model.configured`. The
  answer = `payload.text` of the `run.terminal.completed` record (`payload.kind`
  `run_terminal`, `payload.terminal` `completed`, `payload.reason` null); with
  `--output-schema` that text is JSON matching the schema. No token usage in the records.
- Exit codes (vendor doc): 0 completed; 1 failed or cancelled (max steps included); 2 usage
  error; 130/143 signals.
- Credentials: `muse login` (device code, approved in the browser). On Windows the keychain
  write failed ("keychain write failed (internal error -2147483648)"); with the User env
  `TBH_CREDENTIAL_BACKEND=file` the credential lives in `~/.config/muse/auth.json`
  (`providers.meta`, oauth). Never read or print its values.
- Effort flag: `none|minimal|low|medium|high|xhigh|max|ultra` (default high).
- Models accepted under the subscription: `muse-spark-1.3-contributor` (the CLI default; Meta
  may train on inputs) and `muse-spark-1.3`; the docs also list the 1.2 pair and 1.1.
- Plan quota: Everyday 10-50 prompts per 5 hours (one consultation = one prompt).

## Design

1. Engine table entry `muse`: label `Meta Muse (muse)`, prefix `muse` (handoffs
   `NN-muse-<slug>.*`), command `muse`, env override `CODEX_CONSULT_MUSE_EXE`; launcher names
   `muse.cmd`, `muse.exe`, `muse` on Windows, `muse` elsewhere.
2. Argv as above, in the repository root; the prompt through `--prompt-file` (the bridge
   already writes it to a file), the reply schema through `--output-schema` (caps-v1
   `engine:muse`, SchemaTransport `native`, validated locally too). `--max-model-steps` from a
   new `-MaxModelSteps` (default 80) - the bridge's timeout stays the outer bound.
3. Read-only posture: `--disable-write --disable-shell --disable-web-tools --approval-mode
   never --no-foreign-personal-context`, plus the agy tree check (repository fingerprint and
   collab snapshot, F12) - a run that changed anything fails as class `permission`.
4. Billing guard (fail-closed): refuse a muse run when `META_API_KEY` or `MODEL_API_KEY` is set
   in the bridge's environment ("would bill per token instead of the subscription"), unless the
   roster entry says `"billing": "api-key"`. `TBH_CREDENTIAL_BACKEND` is inherited unchanged.
5. Preflight: launcher resolvable; signed in = `~/.config/muse/auth.json` parses and has a
   `providers.meta` object (key names only, values never read) when
   `TBH_CREDENTIAL_BACKEND=file`; otherwise "sign-in not checkable (keychain)" as a warning.
6. Reply: exactly one `run_terminal` record expected; `completed` -> its text; anything else ->
   provider failure with the reason (the shared text classifier: quota wording -> quota with
   retry_after when a reset is named). Several terminal records or none -> malformed stream.
7. Threads: modes `new` and `resume` (`--session-id <parent session>`); `fork` refused like
   agy. The thread id is the session id; lineage `<provider> :: <model> [muse]`.
8. caps-v1: `engine:muse` = vocabulary `muse` (mapping `muse-v1`: low, medium, high, xhigh as
   is), models `muse-spark-1.3`, `muse-spark-1.3-contributor`, `muse-spark-1.2`,
   `muse-spark-1.2-contributor` (exact), SchemaTransport `native`.
9. Endpoint health: one sign-in = one endpoint (like agy): every muse entry shares a
   fingerprint, so a quota on one blocks all muse entries until its reset.
10. Fake `tests/fake-muse.ps1` + `.cmd` emitting MSP records (a sanitized real probe as the
    template) with knobs for reply, delay, failed terminal, exit codes, a file write (tree
    check), hang, two terminal records; harness cases for argv, the billing guard, preflight,
    reply extraction, failure classes, the tree check, resume, and a panel member.
11. Docs: README engine section and tables; `setup-providers` 3f (subscription, install,
    `muse login`, `TBH_CREDENTIAL_BACKEND=file` on Windows, never an API key, the contributor
    vs standard model choice - the installing user decides); CHANGELOG wave 23.

## Questions for the reviewers

Q1. Is `--disable-shell` + `--disable-write` + the tree check enough for a read-only reviewer,
    or should the run also get a separate scratch workspace?
Q2. The billing guard refuses on `META_API_KEY`/`MODEL_API_KEY`: should the bridge instead strip
    them from the child's environment (and say so), or is refusing the safer default?
Q3. The preflight reads only key names of `auth.json` - acceptable, or should sign-in be
    checked by a cheap live call (it would spend one of 10-50 prompts per 5 h)?
Q4. Anything in the MSP record handling above that is likely to break across CLI updates (the
    launcher auto-updates), and how should the bridge pin or detect the CLI version?
