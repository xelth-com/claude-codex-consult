# Handoff 18 - Codex: format-compliance-mimo

Date: 2026-09-24 21:32 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 3 of 3, panel 9e96bc8f member 2 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 74d18ee5-baf7-438f-a99d-5ccf32fd9541.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: checkpoint). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-28b7618b18ea46d59ad18cf124c1a410.md fork 01a0d3ff-7dd5-7b92-be1f-b4220c3e59d2 -` (prompt on stdin).
Parent thread: `01a0d3ff-7dd5-7b92-be1f-b4220c3e59d2`. Result thread: `01a0d4e7-5341-7111-96f1-c477b2b11ba6` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/16-claude-format-compliance.md` (sha256 d7be7ff3ecf2). Reviewed: a743d81, base a743d81627efefa7201eef2af68734c95db6d5cc, tree sha256 0e0f47f40965, 0 changed files.
Bridge outcome: usable reply. Wall time: 301.9 s. Tokens: in 4085017 (cached 1859712), out 40294, reasoning 21599.
Verdict: ADVISE - The prompt and lenient parser match the current contract, but prose compliance is still model-dependent and format-repair is only a proposal; two prior invariant claims remain narrowed or partial. Findings: 0 blocker, 0 major, 3 minor, 0 note (F18-1..F18-3, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/18-codex-format-compliance-mimo.reply.json`.
Raw event stream: `handoffs/18-codex-format-compliance-mimo.events.jsonl`.
Verbatim reply follows.

---

**Q1.** For MiMo, bare JSON is already likely on `prompt-only`: the schema is appended near the end and previous MiMo runs returned bare JSON. Prose is encouraged by the brief's numbered questions and the instruction that `reply_markdown` contains a Markdown answer; the format block appears only after the brief, purpose, and open findings, and the final `Consultation id` can look like ordinary metadata. The single change I recommend is to prepend one hard contract before the brief: “FINAL OUTPUT: exactly one JSON object and no other text; `reply_markdown` is a JSON string containing Markdown.” I estimate 80-90% confidence that this improves first-turn compliance.

**Q2.** Retry only after a non-empty substantive reply that fails `ConvertFrom-StructuredReply`, on the same verified thread, once, at low effort. Keep the first message byte-for-byte in the handoff and as the original raw artifact; save the repaired object separately and ingest only that object. Record `format_retry {attempted, succeeded, thread, wall_seconds, drift_note}` plus original/repaired paths and hashes. Cheap drift checks: identical `Qn` set and order, identical `RCn` set, finding `path:line` sets and count, prior-finding IDs, verdict token, and normalized sentence/token overlap. Any mismatch must set `drift_note` and prevent silent replacement of the original evidence.

**Q3.** One attempt, on by default for every structured route, because z.ai can ignore `--output-schema` too. Fire only when the raw response is substantive prose or invalid JSON after a usable run. Never fire for `-Raw`, `chore`, empty output, provider failure/timeout, a short refusal or safety response, or an already-valid JSON object. If the thread is not verified, do not retry.

**Q4.** **ADVISE.** Recommended first-turn wording: “FINAL OUTPUT CONTRACT: Return exactly one JSON object and no other text. No Markdown or code fence outside it. `reply_markdown` is a JSON string containing Markdown. Do not answer in prose.”

Repair wording: “Your previous answer was not valid JSON. Convert the same answer verbatim into exactly one schema-valid JSON object. Preserve every question answer, finding, RC id, prior id and verdict; add or omit nothing. Return only JSON.”

Current-code check: prompt order and lenient bare/fenced parsing are present; `format_retry` is absent. F15-1, F15-2 and F15-4 are implemented. F15-3 is narrowed: persistent timeout survivors intentionally stop later panel members. F12-1 remains partial: `auth: none` exists, but rotated credentials still need broad `-SkipPreflight`.

---

### Findings

- **F18-1** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:1334`, `plugins/codex-consult/scripts/codex-consult.ps1:1364` - The outer JSON-only contract is buried after the brief, purpose and findings, while `reply_markdown` is explicitly described as Markdown, leaving prose a plausible first-turn output. Trigger: A route receives the current long prompt and answers the numbered brief questions as a normal Markdown reply. Evidence: read-code: The format block is assembled after the brief and findings; the schema is appended later on prompt-only routes. Verify: Compare first-turn bare-JSON rates before and after prepending the hard output contract to the prompt. Remedy: Put the exact JSON-only contract first and repeat it immediately before the schema.
- **F18-2** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:711`, `plugins/codex-consult/scripts/codex-consult.ps1:715` - The claimed invariant that one panel member's failure does not stop later members is only conditionally true: a timeout with surviving processes blocks all later members through the shared pending reservation. Trigger: Member 2 times out and `Stop-ProcessTree` leaves survivors, leaving `.consult.pending.json` active. Evidence: read-code: The panel explicitly refuses to start later members when a previous member left a pending reservation. Verify: Run the timeout-survivor panel fixture and check whether member 3 is marked skipped/refused rather than run. Remedy: Either recover the reservation before continuing or document the invariant as stopping the panel on persistent survivors. Supersedes: F15-3.
- **F18-3** [minor] `plugins/codex-consult/scripts/codex-consult-common.ps1:3091`, `README.md:665` - F12-1 is only partially resolved: anonymous endpoints now have `auth: none`, but retrying with a rotated credential still requires the broad `-SkipPreflight` escape hatch. Trigger: A provider fails authentication and the operator replaces its key before the 24-hour health window expires. Evidence: read-code: The auth-health refusal still instructs the operator to pass `-SkipPreflight` once after rotating the credential. Verify: Rotate the key after a recorded auth failure and search for a one-shot retry or credential identity update path. Remedy: Add a narrow rotated-credential retry that records the credential change while retaining other preflight checks. Supersedes: F12-1.

### Prior findings

- F02-4 - fixed - Effort mapping remains endpoint-host and exact-model based.
- F06-1 - fixed - Unsupported provider-set declarations still prevent resolved builtin provenance.
- F06-2 - fixed - Provider and model remain compared separately with endpoint fingerprint.
- F06-3 - fixed - Peak status remains checked immediately before launch.
- F06-4 - fixed - Long exception ranges remain interval-based.
- F12-1 - still-open - Anonymous access is now declared with `auth: none`; rotated-credential retry remains broad.
- F15-1 - fixed - Wall-clock reset parsing now applies the zone's daylight-saving rules.
- F15-2 - fixed - Legacy reset parsing uses the recorded failure reference offset.
- F15-3 - still-open - The implementation safely stops later panel members on persistent survivors, narrowing the original continue-on-failure claim.
- F15-4 - fixed - Future-stamped failures are clamped to age zero and no longer skipped.

## Verdict: ADVISE

The prompt and lenient parser match the current contract, but prose compliance is still model-dependent and format-repair is only a proposal; two prior invariant claims remain narrowed or partial.

### Blockers

_(none)_

### Unproven scenarios

- Whether prepending the output contract changes z.ai or MiMo first-turn JSON rates.
- Whether Codex CLI exposes any hidden json_object mode.
- Whether semantic drift checks detect paraphrased or reordered findings reliably.
- Whether a resume-based repair preserves the exact original thread and evidence boundaries.

### First-run checklist (observable)

_(none)_
