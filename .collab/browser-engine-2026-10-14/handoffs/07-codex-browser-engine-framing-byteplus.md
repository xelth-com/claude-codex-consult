# Handoff 07 - Codex: browser-engine-framing-byteplus

Date: 2026-10-14 14:56 local. Author: Codex (model dola-seed-2.0-pro, effort high), Codex CLI 0.155.1.
Reviewer: byteplus :: dola-seed-2.0-pro (provider from roster, model from roster; endpoint https://ark.ap-southeast.bytepluses.com/api/coding/v3, wire_api: responses; provider fingerprint ed61f9eb93fe; harness codex-cli 0.155.1).
Preflight: ok: env BYTEPLUS_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 7 of 10, panel 34c8b9a5 member 6 of 10.
Effort: high sent (requested high, mapping ark-v1, by caps-v1: ark.ap-southeast.bytepluses.com, dola-seed-2.0-pro; not confirmed by the provider). Consultation id: dea7e6e4-0150-4ae7-b748-bd19533f631f.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m dola-seed-2.0-pro -c model_reasoning_effort="high" -c model_provider="byteplus" -c features.multi_agent=false -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-16b8348185b9497e8bbc6b1ed24a27cb.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a13a7c-1f9e-7990-87bc-ac122c1e5079` (source: events).
Brief: `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` (sha256 19fb466d7f96). Reviewed: 49dde0c, base 49dde0cc2b7f0ba2e40fa90c0c60536ca7965b30, tree sha256 99269e8342cd, 0 changed files.
Bridge outcome: usable reply. Wall time: 245.1 s. Tokens: in 275598 (cached 158120), out 2913, reasoning 1080.
Quota (rollout): no window in the rollout; this run 275598 input tokens (158120 cached) in 5 calls, max 58025 per call of 258400; sub-agents 0; sub-agents off (features.multi_agent=false); budget 15 % of the 5-hour window.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - Framing review completed, identified unlisted options, boundary constraints, and implementation tradeoffs. Findings: 0 blocker, 1 major, 2 minor, 1 note (F07-1..F07-4, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/07-codex-browser-engine-framing-byteplus.reply.json`.
Raw event stream: `handoffs/07-codex-browser-engine-framing-byteplus.events.jsonl`.
Verbatim reply follows.

---

## Answers

### Q1. Boundary design
The product must contain **zero site-specific logic**: no selectors, no button clicks, no user-agent overrides, no default adapters, no preconfigured catalogue entries for real sites. It should ship only:
- A generic adapter contract interface
- Sandboxing primitives
- Signature validation
- An empty catalogue loader
- Documentation explicitly stating "no adapters are provided; you bring your own".

Precedents: Tampermonkey (runtime only), Selenium (driver framework only), OpenInterpreter (BYO credentials). Catalogue may list **only hashes, IDs, and metadata** - never code or DOM logic.

### Q2. Technical shape
**WASM adapters inside the extension** is the only acceptable choice:
- Safest: No credential exposure, strictly single-tab scoped
- Most robust: Runs inside the tab context, immune to CDP detection
- Sandboxable: Strong WASM isolation, easily signed

Minimal contract:
```
interface Adapter { detect(): bool; send(text): Promise<void>; await(): Promise<string>; reset(): void }
```

Reject CDP/Playwright entirely - credential and detection risk is unacceptable.

### Q3. Detection/abuse
Mandatory safeguards:
- 1.2s minimum between actions ±20% jitter
- Always-visible status badge in the tab
- 1 turn / 10s rate limit, 6 turns / hour hard cap
- Reject all headless/automated Chrome contexts
- Hard exit on any CAPTCHA, Cloudflare, or 403 antibot page
- No tab hiding - must remain foreground/visible

### Q4. Reviewer quality
- Pack budget: 12k tokens maximum (matches free web tiers)
- Default weight 0.6 until 3 positive ratings; cap at 0.9
- Always stateless re-send. Never reuse site conversation state - leaks are too common and continuity provides no quality gain.

### Q5. Telemetry/distribution
Telemetry fields (no user content ever):
- `adapter_id` (hash only)
- `adapter_version`
- `outcome`: ok/failed/antibot/timeout
- `latency_ms`

Catalogue: Only pointers + SHA-256 hashes, signed developer keys, opt-in updates. Retire adapters with <30% useful rating over 20 runs.

### Q6. Order of work
Build order (blockers first):
1. Extension relay + WebSocket protocol
2. WASM sandbox + minimal adapter contract
3. Signature validation
4. Anti-detection + rate limits
5. Catalogue loader
6. Rating telemetry

**Do NOT build:** Any site adapter, catalogue hosting, CAPTCHA solvers, headless mode, thread continuity.

## Requested checks
RC1: Run `Get-Content C:\Users\Dmytro\gemini-mcp\DESIGN.md` | Select-String "Transport" (read-only) - confirm extension relay security posture matches this design.

---

### Findings

- **F07-1** [minor] `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` - The brief does not consider IPFS or content-addressable storage for adapter distribution. Trigger: Catalogue distribution design question. Evidence: read-code: No mention of content-addressable distribution models. Verify: Check existing C3 documentation for prior use of IPFS. Remedy: Use IPFS CIDs as primary catalogue pointers instead of HTTPS URLs.
- **F07-2** [minor] `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` - The brief does not specify WASM runtime memory limits or gas metering. Trigger: WASM adapter sandbox design. Evidence: assumed: Unconstrained WASM can exhaust tab memory. Verify: Review gemini-mcp extension's WASM runtime configuration. Remedy: Enforce 16MB memory limit and 100ms execution timeout per adapter call.
- **F07-3** [major] `CONTRIBUTING.md` - The repository currently has no explicit policy rejecting site adapter PRs. Trigger: Any contribution adding site-specific automation logic. Evidence: inferred: No CONTRIBUTING.md exists prohibiting site adapters. Verify: Check for existence of CONTRIBUTING.md in the repository root. Remedy: Add an explicit policy: 'No site adapters will be merged into this repository under any circumstances.'.
- **F07-4** [note] `.collab/browser-engine-2026-10-14/handoffs/01-fable-browser-engine-framing.md` - The brief does not specify an adapter manifest format. Trigger: Adapter packaging and signing. Evidence: assumed: No manifest structure is proposed. Verify: Review xelth.rs extension manifest format. Remedy: Define a minimal signed manifest with adapter ID, version, hash, and compatibility bounds.

### Prior findings

_(none)_

## Verdict: ADVISE

Framing review completed, identified unlisted options, boundary constraints, and implementation tradeoffs.

### Blockers

_(none)_

### Unproven scenarios

- Whether WASM GC pause times will be acceptable for human cadence requirements
- Whether Chrome extension policy allows in-tab WASM adapters that interact with chat sites
- Whether vendor antibot systems can detect the extension relay pattern

### First-run checklist (observable)

_(none)_
