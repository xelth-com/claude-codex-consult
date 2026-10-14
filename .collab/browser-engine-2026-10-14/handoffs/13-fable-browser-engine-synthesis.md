# 13 - Fable synthesis: browser engine framing panel (2026-10-14)

Inputs: brief 01; usable replies 03 (GLM), 05 (deepseek), 07 (dola), 08 (kimi), 11 (gemini via agy), 12 (muse). No findings from: 02 qwen (429), 04 Astra (quota-killed partial), 10 mimo (tool type unsupported); first-attempt gemini/muse seats failed (T18).

## Per reviewer, one line
- **GLM (03):** ADVISE, 4 major: generic docs (no vendor names), Native Messaging instead of a WS, WASM only behind a mediated host API, local-import catalogue (no fetch/recommend); draft-only mode; NO human-mimicking jitter.
- **deepseek (05):** manual relay as step 0, then a one-site spike as go/no-go; declarative JSON adapters first, WASM last; token + Origin check on the loopback WS; MV3 remote-code question; aggregate per (adapter, contract_version).
- **dola (07):** WASM "the only choice", 1.2 s +-20 % jitter, hard rate caps, stateless re-send; thin on evidence (findings assumed).
- **kimi (08):** JS adapters behind a strict host API, WASM v2; catalogue = pointers + hashes; official xAI API through `http` for grok; clipboard mode as v0; WS token required.
- **gemini (11):** isolated browser profile; agy already covers Gemini; JS in an isolated world; MV3 bans runtime-fetched code; hashed site; token-authenticated WS; thread continuation by default.
- **muse (12):** challenges "whether", not "how"; manual relay v0; deny-by-default JS host API; consent receipt + ToS attestation per enable; revocation list; single-vendor spike, Gemini deferred until agy overlap is measured.

## Merged answers
- **Q1 Boundary** (all): ship engine, host API, manifest/catalogue FORMAT, signing, revocation, a test-page fixture adapter only. Never ship selectors, site names, default adapters, hosted adapter bytes, cookie access, headless/CDP, CAPTCHA code. Precedent: userscript managers (GLM: not immunity). Catalogue = signed pointers + hashes + signer, never code (GLM, deepseek, kimi, gemini, muse). Vendor names also out of our own docs/ROADMAP (GLM F03-1, gemini).
- **Q2 Shape:** CDP/Playwright rejected by all. The real sandbox is the host API, not the bytecode (deepseek, kimi, gemini, muse). Contract adds failure classes and a completion flag: `probe`/`detect_block`, `await_answer -> {text, complete|truncated}`, `limits()`. `attach` dropped in v1 (deepseek, gemini, muse).
- **Q3 Detection:** hard stop on any gate signal and quarantine the adapter version, concurrency 1, visible foreground tab, no headless/CAPTCHA/scheduling, daily caps, status badge (all); repair retries off for `browser` (deepseek).
- **Q4 Quality:** per-adapter budget from `limits()`, enforced by C3: 2-8 k tokens (GLM 6 k, deepseek 4-8 k, muse 2-4 k, dola 12 k). Provisional weight 0.5-0.6, no deciding quorum until rated (GLM, dola, gemini, muse); lowest router band and `findings_unavailable` on prose-only (deepseek).
- **Q5 Telemetry:** adapter_id/version/(digest), contract_version, outcome class (answered|prose_only|gate|rate_limited|dom_changed|login_required|timeout), turns, repair flag, duration. Site hashed or opt-in (GLM, gemini, muse); aggregate per (adapter, contract_version) (deepseek, muse). Updates opt-in, hash-verified, landing disabled with a capability diff; retirement = signed status change.
- **Q6 Order:** manual relay + boundary/refusal policy -> one-site spike -> host API/contract/authenticated relay -> telemetry -> out-of-repo reference adapter -> WASM last. Not building: any adapter, hosted bytes, runtime-fetched code, stealth, CAPTCHA, attach, scheduling, fan-out.

## Disagreements
1. **WASM vs JS vs declarative:** dola/GLM WASM (GLM: in a worker with a mediated API); kimi/gemini/muse JS first, WASM v2; deepseek declarative JSON first, WASM last (GLM also lists declarative). Majority: JS in an isolated world.
2. **Cadence:** dola 1.2 s +-20 % jitter, gemini 50-150 ms typing jitter, deepseek "jittered delays", muse/kimi "human cadence"; GLM: NO jitter designed to mimic humans (evasion by another name).
3. **Threads:** stateless re-send (GLM, dola, deepseek default) vs continuation by default (kimi, gemini, muse). Candidate: stateless first; continue only when `limits().thread_continuable`, recorded in the ledger.
4. **Site in catalogue:** plaintext `site` (deepseek, kimi, brief) vs hashed/opt-in (GLM, gemini, muse).

## Unlisted options raised
- Manual paste relay as step 0 (muse, deepseek, kimi).
- Isolated browser profile for automation (gemini).
- Official per-site API instead, e.g. xAI API for grok through `http` (kimi); `agy` already covers Gemini (deepseek, gemini, muse).
- Draft-only assist, declarative adapters, Native Messaging (GLM); read-only extraction (deepseek); OS accessibility driver (muse).

## Blockers / gates named
- Token-authenticated loopback WS with Origin check, or Native Messaging (deepseek, kimi, gemini, GLM).
- Chrome Web Store MV3 remote-code policy vs runtime-fetched/WASM adapters; WASM needs an explicit extension CSP (deepseek, gemini, GLM).
- Informed per-adapter consent + ToS attestation + revocation (muse); legal review of the boundary and catalogue exposure (GLM, muse).
- Closed engine vocabulary: `browser` added to ENGINE_NAMES/engine_spec (deepseek, gemini).

## DECISIONS (proposals for the operator; nothing confirmed)
- **(a)** No human-mimicking jitter (GLM: it is evasion); fixed conservative rate floors instead. Draft-only mode (extension fills, the human clicks Send) is the DEFAULT; one-click send is an explicit per-adapter opt-in. RECOMMENDED.
- **(b)** Step 0 = manual paste relay + consent wording + a one-site spike as a go/no-go gate (a week without a gate; else build nothing more). (deepseek, muse)
- **(c)** grok via the official xAI API through the existing `http` engine instead of browser automation; the browser engine then has no named target. (kimi)
- **(d)** JS adapter in an isolated extension world behind a deny-by-default host API (selected tab/origin only, no network, no `chrome.*`, quotas); WASM deferred. (kimi/gemini/deepseek majority)
- **(e)** Catalogue = signed pointers + hashes + per-(adapter, contract_version) ratings; the product hosts/fetches no adapter bytes (user supplies URL + digest); site hashed in telemetry; revocation = signed status change.
- **(f)** Remove vendor names from the ROADMAP section and shipped docs (F03-1), vendors only in non-shipped records.
