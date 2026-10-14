# Handoff 12 - Meta Muse (muse): browser-engine-framing-meta

Date: 2026-10-14 16:26 local. Author: Meta Muse (muse) (model muse-spark-1.3-contributor, effort high), muse-cli 1.4.7-R6101.1.
Reviewer: meta :: muse-spark-1.3-contributor [muse] (provider from -Provider, model from -Model; engine muse (C:\Users\Dmytro\AppData\Local\Programs\muse\muse.cmd); provider fingerprint 1c6f62bb040d; harness muse-cli 1.4.7-R6101.1).
Preflight: ok: signed in (~/.config/muse/auth.json: providers.meta, mechanism oauth).
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - entry 10 of 10 for -Provider meta (engine applied).
Effort: high sent (requested high, mapping muse-v1, by caps-v1: engine:muse, muse-spark-1.3-contributor; not confirmed by the provider). Consultation id: 2316779c-7bac-4faf-8cb0-84812a742ae3.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only (requested; muse --disable-write --disable-shell --disable-web-tools --approval-mode never; checked by evidence for tracked and untracked files and the collab directory, not for gitignored paths, submodules, files outside the repository or what the reviewer reads), purpose: framing). Argv: `muse exec --json --prompt-file C:\Users\Dmytro\AppData\Local\Temp\codex-consult-prompt-d73122079e0b4f5d80a95953f8f32a30.txt --output-schema C:\Users\Dmytro\.claude\plugins\cache\claude-codex-consult\codex-consult\0.6.1\schemas\consult-reply.schema.json --model muse-spark-1.3-contributor --reasoning-effort high --no-foreign-personal-context --disable-web-tools --disable-write --disable-shell --approval-mode never` (prompt from a file: --prompt-file).
Parent thread: (none - new thread; no thread of lineage meta :: muse-spark-1.3-contributor [muse] in this task's ledger; other lineage(s): gemini :: gemini-3.8-flash-high [agy], mimo :: mimo-v2.6-pro, kimi :: k3, byteplus :: dola-seed-2.0-pro, byteplus :: deepseek-v4.1-flash, openai :: gpt-6-astra, ZAI :: glm-5.3, alibaba :: qwen3.8-max). Result thread: `01a13acf-0993-71d1-b37b-a3d1d626b786` (source: events).
Brief: `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` (sha256 19fb466d7f96). Reviewed: 9422a76, base 9422a76baddb76f0d5321bdd0577a7c0d3fc73c3, tree sha256 b77ed2f27101, 0 changed files.
Bridge outcome: usable reply. Wall time: 75.4 s. Tokens: not reported by muse.
Engine turns: 1 (each one a Muse Code subscription prompt); MSP schema_version 1.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Framing needs a no-engine baseline, consent, and revocation answers before any automation shape is accepted. Findings: 0 blocker, 3 major, 0 minor, 0 note (F12-1..F12-3, tracked in `findings.json`). Structured reply: `handoffs/12-muse-browser-engine-framing-meta.reply.json`.
Raw event stream: `handoffs/12-muse-browser-engine-framing-meta.events.jsonl`.
Verbatim reply follows.

---

Challenge first: the brief asks *how* to automate web chats, not *whether*. Unlisted options: (0) no engine — user pastes pack in, pastes reply back; (a) per-site CLI/API where one exists (agy covers the Gemini case); (b) OS-level accessibility driver instead of extension/CDP; (c) single-vendor spike (grok-only) to test value before a frame. To choose I would need: consults/month needing browser-only models, agy-vs-web answer overlap, one manual-relay timing, and counsel's view on catalogue/signing exposure.

**Q1 — Boundary.** Ship: engine, host API, manifest/catalogue *format*, signing/verification and revocation, sample adapter for a fictional/test page only. Never ship: site DOM selectors, default-enabled adapters, screenshots/docs naming forbidden-site targets, hosted adapter bytes, or usefulness copy promoting them. Precedents: userscript managers (engine + no bundled scripts, takedown on notice), Greasemonkey/Tampermonkey wording ('user scripts are user responsibility; check site terms'), 1Password-style BYOS ('your session, your vault'). Catalogue lists pointers + hashes + signer + ToS-attestation, never code.

**Q2 — Shape.** Safest order: extension content-script JS adapter behind a deny-by-default host API (chat-tab origin only, no cookies, no other tabs, no network) beats CDP/Playwright (full-browser capability, credential-adjacent) and beats WASM-first (WASM still needs the same JS shim for DOM, so the shim *is* the boundary; sign JS equally). Minimal contract: `start_thread`, `send_turn(text)->turn_id`, `read_turn(turn_id)->{state: streaming|done|blocked|error, text}`, `limits()->{max_chars, turns/day}`, plus `adapter_id/version` and a failure enum. Drop `attach` (no use case named). Prove against grok + one generic textarea site; defer Gemini until agy-overlap is measured.

**Q3 — Detection/abuse.** Add: no headless, visible tab must stay foreground, inter-turn jitter, per-adapter daily caps, stop wordlist (captcha/verify/rate/login-wall/interstitial → abort + mark `blocked`), no CAPTCHA solving or DOM cloaking, consent receipt per enable, and a public abuse-contact + takedown path. Log every turn locally.

**Q4 — Quality.** Mark browser replies `weight: provisional`, route only in panels until per-(adapter,version) win-rate clears a bar; per-adapter pack budget (grok small: ~2–4k tokens, pack slicer truncates periphery first); prefer site-thread continuation, stateless re-send only as fallback, and record which was used.

**Q5 — Telemetry/distribution.** Fields: adapter_id, version, site_hash (not plaintext), outcome class (ok/refused/blocked/error/truncated), turn count, repair flag, consent flag. Catalogue = signed pointers + hashes, user-supplied bytes, explicit enable, revocation list, cache expiry. Retire by (id,version)+outcome, never by id alone.

**Q6 — Order / not-build.** Build: (1) manual-relay + consent wording + one grok spike; (2) host API + contract + revocation design; (3) telemetry/outcome fields. Do NOT build: hosted adapter bytes, WASM toolchain, Gemini adapter, attach, PowerShell parity, or auto-updates — until the spike proves value.

## Requested checks
RC1: Time one manual grok.com pack→reply round-trip from a staged file; observe wall-clock and turn cost (needs browser read-only; 30 min). Settles finding #1.
RC2: Walk the enable-flow mock and confirm a mandatory ToS-risk attestation step exists (needs design doc read-only; 15 min). Settles finding #2.
RC3: Inspect catalogue spec for signer, hash algo, revocation check, and cache expiry (needs spec read-only; 20 min). Settles finding #3.

---

### Findings

- **F12-1** [major] `ROADMAP.md`, `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` - The framing omits the lowest-risk option: no browser engine at all — manual paste-out/paste-back by the user (human-in-the-loop relay) plus the existing agy/CLI/API paths — which would serve one-off consults without building automation, distribution, or signing infrastructure. Trigger: Deciding to build the engine before pricing the manual alternative that carries zero automation-ToS exposure for the product. Evidence: read-code: Brief motivates engine from labs that 'answer only in the browser' and jumps to driving web chat UI through Chrome; no manual-relay or do-nothing alternative is scoped.; inferred: A user copy-pasting the pack into their own tab and pasting the reply back needs no extension, relay, sandbox, or catalogue, so it dominates on ToS and maintenance cost for infrequent use. Verify: Time one manual grok.com consult from a staged pack file and compare its cost against the estimated engine build plus per-site adapter maintenance. Remedy: Add an explicit Option 0 (manual relay, possibly tool-assisted staging of pack/reply files) with a decision rule for when automation volume justifies the engine.
- **F12-2** [major] `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md:21`, `ROADMAP.md:392` - Neither the brief nor the roadmap requires per-adapter informed consent to the user's own account risk (suspension, quota loss, subscription termination) before an adapter is enabled, leaving the heaviest cost on the least-informed party. Trigger: A user enables a reference or third-party adapter for a site whose terms forbid automation and loses the account or quota. Evidence: read-code: Boundary places site-terms responsibility on the adapter author/user but specifies no consent surface, risk disclosure, or per-site ToS attestation at enable time.; read-code: Enable path is described only as user enables per site at human cadence with rate limits; no warning or attestation step is listed. Verify: Walk the enable flow in the design doc and check for a mandatory risk-disclosure plus attestation step before any adapter can send text. Remedy: Require the enable flow to show the site, the automation-relevant ToS clause link as supplied by the adapter author, and an explicit 'I accept the account risk' confirmation recorded in telemetry as consent, not content.
- **F12-3** [major] `ROADMAP.md:396` - The signing and revocation model is unspecified: who may sign, how keys are distributed and rotated, and how a compromised or ToS-violating adapter is revoked and blocked from running disable the catalogue safety story. Trigger: A signed adapter is compromised or a site forbids its automation after the catalogue has listed it. Evidence: read-code: Catalogue promises signatures and opt-in updates with the xelixir lands-disabled rule, but names no signer, trust root, key distribution, or revocation mechanism.; inferred: Without revocation, a retired/bad adapter entry remains runnable from cache, so the rating/retirement loop in Q5 cannot actually retire anything in the field. Verify: Inspect the catalogue format spec for signer identity, hash algorithm, revocation endpoint, and offline/stale-cache behavior. Remedy: Specify pointers-and-hashes catalogue, named signers, a revocation list checked before each run, and cached-adapter expiry; keep all adapter bytes out of the product channel.

### Prior findings

- F03-1 - still-open - Roadmap and brief still name Gemini/grok targets alongside the neutral-frame claim; no rewording observed.
- F03-2 - not-checked - No manifest/watchdog comparison possible read-only in this repo; reuse direction unchanged.
- F03-3 - still-open - Roadmap still sketches catalogue/fetch/update/usefulness distribution of adapters.
- F03-4 - still-open - WASM host API still stated without capability mediation details.
- F03-5 - still-open - Plaintext site telemetry still proposed; no hashing/omission adopted.
- F05-1 - still-open - Runtime fetch/update through the channel still in roadmap; Store policy decision not recorded.
- F05-2 - not-checked - Relay auth needs gemini-mcp sources outside this repo; not inspected here.
- F05-3 - still-open - Contract still the five verbs with no identity/failure/completion additions.
- F05-4 - not-checked - Engine-name tables live in C3/PowerShell sources not verified in this pass.
- F05-5 - still-open - attach(file) still carried as optional without a stated needing site.
- F05-6 - still-open - Verbatim reply through findings path unchanged; prose-only outcome not documented.
- F05-7 - not-checked - Per-adapter pack budget mechanism not verified against C3 budget code here.
- F05-8 - still-open - Telemetry fields still id/version/site without outcome class or version-keyed aggregation.
- F05-9 - still-open - Gemini motivation still leads despite agy overlap question being unanswered.
- F07-1 - not-checked - IPFS/content-addressable option not checked against C3 docs in this pass.
- F07-2 - not-checked - WASM memory/gas limits not checked against extension sources here.
- F07-3 - not-checked - CONTRIBUTING.md presence/policy not verified in this pass.
- F07-4 - still-open - Adapter manifest format still unspecified in brief/roadmap as read.
- F08-1 - still-open - Distribution-as-hosting tension still present in roadmap wording.
- F08-2 - still-open - WASM-by-default still the sketched shape; JS-alternative undecided.
- F08-3 - not-checked - Relay default-token claim needs gemini-mcp sources; not inspected here.
- F08-4 - still-open - Continuation-vs-resend default still undecided; free-tier burn risk stands.

## Verdict: ADVISE

Framing needs a no-engine baseline, consent, and revocation answers before any automation shape is accepted.

### Blockers

_(none)_

### Unproven scenarios

_(none)_

### First-run checklist (observable)

_(none)_
