# Handoff 19 - Claude: diff review of wave 14 (output contract first, format-repair turn)

Date: 2026-09-25. Base commit: `a743d81` + uncommitted waves 11-14. Panel consultation (GLM through z.ai, MiMo);
your recommendations from handoffs 17 and 18 are what this wave implements, so this consultation is also the
live test of the first-turn contract on your route: answer with the bare JSON object on the FIRST turn.

## What changed (read these)

- `plugins/codex-consult/scripts/codex-consult.ps1`: the prompt now OPENS with the paragraph `FINAL OUTPUT
  CONTRACT: ...` (structured mode only), the reply_markdown description says the Markdown lives inside the JSON
  string; `-FormatRetry 0|1` (default 1); the repair block after validation (search `format repair`):
  fires only for a usable reply that failed parsing or the schema, on a verified thread, when the prose is
  substantive (>= 120 words, or >= 40 with a numbered answer); one `codex exec ... resume <thread> -` turn at
  the route's lowest effort, no `--output-schema`, prompt = convert-verbatim instruction + schema + the same
  consultation id, never the brief; timeout min(-TimeoutSec, 300); lock held, pending record `running` pointing
  at the repair process; success -> repaired object ingested, original prose kept byte for byte as
  `handoffs/NN-codex-<slug>.original.md` and rendered after the structured section; failure -> prose kept,
  `validation_error` gets ` (format repair failed: <why>)`; the entry keeps the original `thread`; ledger
  `format_retry {attempted, reason, succeeded, thread, wall_seconds, usage, drift[], original}` after
  `validation_error`.
- `plugins/codex-consult/scripts/codex-consult-common.ps1`: `Test-SubstantiveProse`, `Get-RepairEffort`,
  `Get-FormatRepairDrift` (drift notes: RC id sets, numbered-answer counts, finding ids named in the prose but
  absent, verdict token prose vs JSON, the five longest prose sentences missing from reply_markdown, a
  different thread id from the repair). Warnings only, never a refusal.
- `tests/harness-format.ps1` (23 cases) - the fixtures are the claims.

## CURRENT invariants claimed

- A repair turn never changes provenance: same thread, same reviewer, same consultation id; the original
  prose is always kept and is the evidence of record when the drift notes disagree with the JSON.
- The repair never fires on a failed run, a timeout, a provider failure, a short reply, an unverified thread,
  `-Raw`, `chore`, or `-FormatRetry 0`.
- A valid object with a verdict that does not fit the purpose is NOT repaired (that is a semantic error, not a
  format error) and is recorded as before.

## Questions (answer by number, under 600 words)

- **Q1.** Read the repair block: name one path where the repaired object is ingested although the prose and
  the JSON disagree in a way the six drift checks cannot see (e.g. a softened severity, a remedy replaced, a
  location line changed). Is a seventh cheap check worth it, or should the rule stay "drift notes are
  warnings; the coordinator reads the original"?
- **Q2.** The pending record stays `running` during the repair with `child_pid` pointing at the repair
  process. Read `Test-PendingActive` and the recovery path: if the bridge is killed DURING the repair turn,
  what does the next run see, and is the first turn's reply (already usable prose) lost or kept?
- **Q3.** `Test-SubstantiveProse`: give one input it wrongly accepts (a long refusal or safety message that
  would waste a repair turn) and one it wrongly rejects (a short but complete answer).
- **Q4.** Verdict (ACCEPT/HOLD/REJECT) on wave 14 as a diff, with blockers, unproven scenarios and the
  first-run checklist for THIS consultation: `structured true` on the first turn with `format_retry null`
  is the observable success; `format_retry.attempted true` means the contract still failed on your route.
