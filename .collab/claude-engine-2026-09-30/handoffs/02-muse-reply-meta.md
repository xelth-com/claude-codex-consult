# Handoff 02 - Meta Muse (muse): reply-meta

Date: 2026-09-30 10:48 local. Author: Meta Muse (muse) (model muse-spark-1.3-contributor, effort high), muse-cli 1.4.0-R4161.1.
Reviewer: meta :: muse-spark-1.3-contributor [muse] (provider from roster, model from roster; engine muse (C:\Users\Dmytro\AppData\Local\Programs\muse\muse.cmd); provider fingerprint 1c6f62bb040d; harness muse-cli 1.4.0-R4161.1).
Preflight: ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth).
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 10 of 10, panel fc56e82c member 1 of 3.
Effort: high sent (requested high, mapping muse-v1, by caps-v1: engine:muse, muse-spark-1.3-contributor; not confirmed by the provider). Consultation id: 6410f28b-a27d-441a-8ace-2d040733292e.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads), purpose: framing). Argv: `muse exec --json --prompt-file C:\Users\Dmytro\AppData\Local\Temp\codex-consult-prompt-6802713e1c5c4b9bb99f4c0627589edd.txt --output-schema C:\Users\Dmytro\claude-codex-consult\plugins\codex-consult\schemas\consult-reply.schema.json --model muse-spark-1.3-contributor --reasoning-effort high --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never` (prompt from a file: --prompt-file).
Parent thread: (none - new thread). Result thread: `01a0f180-3c3a-74f2-b444-5eef2f3d4337` (source: events).
Brief: `.collab/claude-engine-2026-09-30/handoffs/01-claude-claude-engine-design.md` (sha256 22fa27469c34). Reviewed: 09b944d, base 09b944d57b6496fb80b68b38e92335035f518df9, tree sha256 9beda7096b9d, 0 changed files.
Bridge outcome: usable reply. Wall time: 218.6 s. Tokens: not reported by muse.
Engine turns: 1 (each one a Muse Code subscription prompt); MSP schema_version 1.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Framing review with load-bearing read-only, concurrency, and classifier unknowns still open. Findings: 0 blocker, 4 major, 1 minor, 0 note (F02-1..F02-5, tracked in `findings.json`). Structured reply: `handoffs/02-muse-reply-meta.reply.json`.
Raw event stream: `handoffs/02-muse-reply-meta.events.jsonl`.
Verbatim reply follows.

---

## Framing challenge

The brief argues *how* to add `claude` but not *whether*. Unlisted options: (a) no fourth engine — route Anthropic reviews through existing `muse`/`agy` adapters; (b) one-shot ephemeral reviewer with no `--resume` at all, deleting thread state; (c) OS sandbox/container instead of trusting `--restricted`; (d) coordinator-exclusion rule instead of a new roster/panel path. To choose I need: expected claude consultations/day, subscription quota and cost tolerance, whether home-config leakage (Q8) and concurrent-state corruption (Q12) are acceptable residuals, and whether native `structured_output` measurably beats format-repair prose.

## Answers by number

**Q1.** Accept 52KB as proven; treat upper bound as open. Cap stdin (e.g. warn over ~100KB) and chunk until a 200KB probe passes.

**Q2.** Assume fail-closed is unproven. Probe denied Read; keep `dontAsk`; add `--permission-prompts none` only if the probe shows a prompt-shaped stall. Never treat empty success as usable.

**Q3.** Unknown. Matrix-test `--effort` on Haiku/Opus/Sonnet; until then send no `--effort` for Haiku (or `low` only) and record `effort_confirmed: null`.

**Q4.** Favour `new` default: cheaper reasoning, no grown-context leakage. Automatic fork is only justified with evidence that resumed context improves reviews without carrying verdicts.

**Q5.** Do not pin `--session-id` on fork until proven; require result `session_id != parent` and re-verify tool list per turn (finding #5).

**Q6.** Assume nothing streams inside one thinking block. Enable stall heartbeat or `--include-partial-messages` only if the probe shows silence; otherwise shorten stall timeout.

**Q7.** Ship a closed table first: unknown exit/subtype/wording → transient/investigate, never usable. Fill quota/overload/structured-output-failure rows from live captures.

**Q8.** Repository files proven; home `~/.claude/CLAUDE.md`, parent `AGENTS.md`, auto-memory still open. Assume they leak; require the home-code-word probe before claiming hygiene (finding #1).

**Q9.** Agreed: `auth status` is local and free — suitable for preflight.

**Q10.** Block on capturing the real `rate_limit_event` payload, limit-reached stream, and exit code; map reset time to health only from observed field names.

**Q11.** Assume kill-during-tool_use does *not* resume cleanly. Require id-equality check; failed resume is a continuation failure, never a silent new thread.

**Q12.** Assume unsafe together. Serialize claude members (max one concurrent claude per host) until a stress run proves `~/.claude.json` safety (finding #4).

## Requested checks

- RC1 (finding #4): run two concurrent `claude -p --restricted` turns in repo root (read-only); observe transcripts, exit codes, `~/.claude.json` integrity; budget 30 min.
- RC2 (finding #5): denied Read outside workdir with full stream; observe `subtype`, `permission_denials`, exit code; read-only; 15 min.
- RC3: kill `claude -p --session-id <u>` mid-tool_use and mid-thinking, then `--resume <u>`; observe result `session_id` and repair need; workspace-write (scratch dir only); 30 min.
- RC4: home code-word in `~/.claude/CLAUDE.md`, `claude -p --restricted` elsewhere; observe leaked vs none; read-only; 15 min.
- RC5: 200KB stdin prompt; observe truncation, usage tokens, exit code; read-only; 15 min.

---

### Findings

- **F02-1** [major] `.collab/claude-engine-2026-09-30/handoffs/01-claude-claude-engine-design.md:94` - Read-only guarantee is overstated: managed settings and --settings hooks can still write, so WriteDisabled=true on init evidence alone is unsound. Trigger: Machine with a managed Claude Code hook that writes on session start reviews a consultation. Evidence: read-code: Design admits managed settings and --settings still apply under --restricted, so a managed hook could write.; inferred: Init tool list cannot prove hooks absent; tree-check plus init check is detection, not prevention. Verify: Install a managed write-hook in scratch CLAUDE_CONFIG_DIR and run a restricted turn; check tree and hook log. Remedy: Downgrade invariant to detected-not-prevented; add --settings /dev/null equivalent if CLI supports it, document managed-hook residual risk, keep tree-check warn path.
- **F02-2** [major] `.collab/claude-engine-2026-09-30/handoffs/01-claude-claude-engine-design.md:112` - Child environment scrub list is assumed and incomplete; ANTHROPIC_* wildcard plus named Bedrock/Vertex/Foundry vars may miss model/base-url overrides and leaks subscription identity. Trigger: Operator exports a new ANTHROPIC_MODEL or CLAUDE_CODE_* override not on the list. Evidence: read-code: Brief marks the variable names assumed and keeps CLAUDE_CONFIG_DIR for login.; inferred: Allowlist-keep of config dir plus denylist-remove of env is fail-open to new variable names. Verify: Dump child env names in fake-claude ARGV_LOG run and diff against scrub list. Remedy: Enumerate env from a live probe, switch to denylist generated from `claude --help`/docs plus fail-closed test that child env names are logged and diffed.
- **F02-3** [minor] `.collab/claude-engine-2026-09-30/handoffs/01-claude-claude-engine-design.md:143` - Roster validator and telemetry patterns are inconsistent and the context-token table is assumed; alias-float plus [1m] suffix handling risks mismatch between sent, resolved, and logged models. Trigger: Roster uses claude-opus-5-5[1m] or a future alias; telemetry buckets it as other or guard misroutes. Evidence: read-code: Validator regex contains a literal [1m] alternative and open claude-* suffix; context tokens marked assumed per model. Verify: Unit-test validator/telemetry against alias, full id, [1m], and unknown claude-* inputs. Remedy: Normalize-then-validate (strip [1m] first), pin validator to tested id list, source context tokens from observed init or mark unknown instead of assumed values.
- **F02-4** [major] `.collab/claude-engine-2026-09-30/handoffs/01-claude-claude-engine-design.md:203` - Concurrent claude panel members plus coordinator share ~/.claude state with no serialization; Q12 is load-bearing and verification covers only one reviewer. Trigger: Panel runs two claude children concurrently on one host. Evidence: read-code: Q12 explicitly open; transcripts share projectsDirectory beside operator sessions; verification is a single reviewer plus one resume. Verify: Run two concurrent claude turns plus coordinator load and check transcripts, exit codes, and ~/.claude.json integrity. Remedy: Default panel to serial claude members (or one claude per panel) until a two-child stress run proves ~/.claude.json safety; record the gate in Get-PanelPlan.
- **F02-5** [major] `.collab/claude-engine-2026-09-30/handoffs/01-claude-claude-engine-design.md:83` - Denial, quota, and resume semantics are undefined: dontAsk denial shape, rate_limit_event payload, exit/subtype taxonomy, stdin upper bound, and resume-after-kill id are all assumed, so classifiers may mislabel empty success as usable. Trigger: Read outside workdir, quota hit, 200KB brief, or taskkill mid-tool_use on a live turn. Evidence: read-code: Q2,Q5,Q6,Q7,Q10,Q11 and Q1-upper-bound all open; DeniedEmpty fires only on evidence and repair resumes the minted thread unconditionally. Verify: Execute Requested checks 1-4 in the brief and capture full stream, subtype, denials, exit code, and resumed session_id. Remedy: Ship with fail-closed mapping table (unknown subtype/exit -> transient, unknown denial shape -> permission investigation), require thread-id equality on resume, cap stdin with chunking until 200KB probe passes.

### Prior findings

_(none)_

## Verdict: ADVISE

Framing review with load-bearing read-only, concurrency, and classifier unknowns still open.

### Blockers

_(none)_

### Unproven scenarios

- Stdin upper bound above 52KB
- dontAsk denial stream shape and --permission-prompts none delta
- --effort behaviour on Haiku
- Fork --session-id pinning and tool inheritance
- Streaming inside a single thinking block
- Full exit/subtype/wording taxonomy for quota, overload, structured-output failure
- Home CLAUDE.md / parent AGENTS.md / auto-memory under --restricted
- rate_limit_event payload and limit-reached stream
- Resume-after-taskkill identity
- Concurrent claude children safety

### First-run checklist (observable)

_(none)_
