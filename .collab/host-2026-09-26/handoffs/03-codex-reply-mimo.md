# Handoff 03 - Codex: reply-mimo

Date: 2026-09-27 23:18 local. Author: Codex (model mimo-v2.6-pro, effort high), Codex CLI 0.155.1.
Reviewer: mimo :: mimo-v2.6-pro (provider from roster, model from roster; endpoint https://token-plan-ams.xiaomimimo.com/v1, wire_api: responses; provider fingerprint 47cd6ee7e4ff; harness codex-cli 0.155.1).
Preflight: ok: env MIMO_API_KEY set.
Roster: C:/Users/Dmytro/AppData/Local/Temp/claude/C--Users-Dmytro-claude-codex-consult/2e5096df-2bb2-46b1-8e0e-f97f37eaab90/scratchpad/roster-companions-design.json - position 1 of 3, panel cdc84a42 member 2 of 3.
Effort: high sent (requested high, mapping mimo-v1, by caps-v1: token-plan-ams.xiaomimimo.com, mimo-v2.6-pro; not confirmed by the provider). Consultation id: 945fc6ae-b1a5-41db-a0bd-e2fd51e5b18a.
Invocation: `codex-consult.ps1` (mode: new, sandbox: read-only, purpose: framing). Argv: `codex exec --sandbox read-only --color never --json -m mimo-v2.6-pro -c model_reasoning_effort="high" -c model_provider="mimo" -c model_catalog_json="C:/Users/Dmytro/.codex/model-catalogs.json" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-71fa818a3d214e3dbb2aaf3568f407f0.md -` (prompt on stdin).
Parent thread: (none - new thread). Result thread: `01a0e4bc-09b4-7a70-a231-06e9f2daa85b` (source: events).
Brief: `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md` (sha256 6862934c8caa). Reviewed: 3360cb9 + uncommitted, base 3360cb9c85daaf2d8e75c52393791a307e9f7999, tree sha256 d18c2bb48637, 1 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 792 s. Tokens: in 547072 (cached 0), out 21659, reasoning 16302.
Timeout: 1800 s (the default of purpose framing); continuation after a timeout kill: up to 900 s.
Verdict: ADVISE - The design is promising but conflates runtime packaging, identity semantics, and host-specific orchestration, so it needs reframing before implementation. Findings: 0 blocker, 5 major, 2 minor, 0 note (F03-1..F03-7, tracked in `findings.json`). Structured reply (prompt-only transport): `handoffs/03-codex-reply-mimo.reply.json`.
Raw event stream: `handoffs/03-codex-reply-mimo.events.jsonl`.
Verbatim reply follows.

---

## Framing
R13 bundles four separable concerns: runtime contract, installation/discovery, coordinator identity, and R19 coordination policy. Unlisted options are: (a) a versioned full-payload install containing `scripts/`, `schemas/`, `templates/`, and skills; (b) an AGENTS-only degraded mode against an existing payload root; (c) a host-capability profile mapping policy concepts to each host's primitives. To choose I need Codex's skill loading/indexing cost, whether copied skills may depend on sibling payload, whether agent files support stable model aliases, and whether “same model” means model family or the same endpoint/account.

## Q1
Neither option as stated. Copying only two `SKILL.md` files is not self-contained: the skills reference `scripts/`, `schemas/`, and `templates/`, while the documented fallback `<skill dir>/../..` resolves to `~/.codex` after copying. AGENTS-only is an acceptable minimum only when the runtime payload already exists at an explicit root. Prefer a full-payload install plus thin skill entries; otherwise document AGENTS-only as degraded usage.

## Q2
I found no Claude-dependent behavior in the bridge scripts: they invoke `codex`, resolve paths from `$PSScriptRoot`, and write repository-local stores. The remaining assumptions are textual, such as `codex-consult.ps1` saying “from Claude Code”, and `codex-consult-hook.ps1` assuming Claude Code injects its stdout. Make the hook an optional Claude adapter and neutralize script help.

## Q3
Keep the explicit `CODEX_CONSULT_COORDINATOR` value authoritative. Environment markers identify a host product, not a model, and nested hosts can expose several markers at once. Inference may fill a missing value but must record provenance and never override the explicit value. Also define the comparison tuple: provider, normalized model alias, engine, and endpoint/account are needed before “lineage equals” is meaningful.

## Q4
Use one separate `coordinate` skill plus a small always-on AGENTS rule pointing to it. A section inside `consult-codex` is read mainly when consulting, missing delegation-only waves. The extra cost is one indexed skill description, not necessarily the full body every session. Alternative: keep a short always-loaded policy in AGENTS and make `coordinate` the deep reference.

## Q5
Separate invariants from mechanisms. Host-neutral: one objective per worker, fresh state on disk, no re-deriving completed work, English reviewer briefs, no repository writes while agy/muse runs, ratings, and operator approval before skipping a required reviewer. Host-specific: subagents, scheduled wakes, `-Kick`, prompt-cache TTL, and auto-compaction. Phrase these as capability mappings: use a fresh isolated worker/session where supported; use `-Detach`/`-Status`/`-Wait` or an equivalent watchdog; compact or start fresh at wave boundaries before the host limit. Do not promise a universal prompt-cache TTL.

## Q6
Do not ship active worker definitions with pinned model names. Ship tier contracts: deep reasoning, default execution, cheap read-only recon. Let the host map tiers to models through a user-owned configuration generated at install time. If a host requires agent files, ship examples or generate them once, and never silently rewrite model names during upgrades. I need the target host's agent schema, mandatory model fields, alias stability, and upgrade ownership rules before choosing.

## Requested checks
- RC1 (finding #1): workdir `<repo>`; permission workspace-write; in a throwaway HOME run `install-codex-host.ps1` with `CODEX_CONSULT_ROOT` unset, then `Test-Path` the referenced `scripts`, `schemas`, and `templates`; all must resolve or installation must fail loudly; budget 5 minutes.
- RC2 (findings #2-#3): workdir `<repo>`; permission read-only; inspect host identity markers and run a same-model/different-endpoint comparison; record the comparator and inference provenance; budget 20 minutes.
- RC3 (findings #4-#7): workdir `<repo>`; permission read-only; start a fresh hookless Codex session, delegate one wave, and request a detached watchdog; observe `coordinate` discovery and the wake/compaction mechanism; budget 15 minutes.

---

### Findings

- **F03-1** [major] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md:20`, `plugins/codex-consult/skills/consult-codex/SKILL.md:37`, `plugins/codex-consult/skills/setup-providers/SKILL.md:15` - The proposed Codex install is not self-contained: copying only the two SKILL.md files leaves the documented fallback root at `~/.codex`, while the skills require scripts, schemas, and templates from the plugin payload. Trigger: A Codex host install with `CODEX_CONSULT_ROOT` unset or pointed at a skill-only directory. Evidence: read-code: Script and template paths are expressed through `${CLAUDE_PLUGIN_ROOT}`.; ran-command: `scripts`, `schemas`, `templates`, and `skills` are separate payload directories. Verify: In a throwaway HOME run the proposed installer with `CODEX_CONSULT_ROOT` unset, then `Test-Path` the three referenced payload paths. Remedy: Install or link the full runtime payload under a versioned root with a root manifest; reserve AGENTS-only for an existing payload root.
- **F03-2** [major] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md:30`, `plugins/codex-consult/scripts/codex-consult.ps1:49` - Coordinator identity is structurally incompatible with reviewer lineage: `provider :: model` omits engine, endpoint/account, and alias normalization, so “lineage equals” is undefined. Trigger: The same model name is reached through different endpoints, provider labels, or aliases. Evidence: read-code: The design defines coordinator identity as provider and model only.; read-code: Reviewer identity includes provider, model, and endpoint fingerprint semantics. Verify: Compare two reviewer records with equal provider/model but different endpoint fingerprints and observe whether the warning fires. Remedy: Define a canonical identity tuple and explicit comparator semantics, including alias normalization and endpoint/account policy.
- **F03-3** [major] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md:54` - Inferring coordinator identity from `CLAUDECODE` or `CODEX_*` markers is unreliable and must not replace an explicit identity value. Trigger: Nested hosts or shells expose multiple markers, or the coordinator model changes mid-session. Evidence: read-code: The proposal treats host environment markers as identity evidence.; inferred: Those markers identify host products, not a stable provider/model pair. Verify: Run the bridge from a nested host with both marker families set and compare inferred identity with an explicit `CODEX_CONSULT_COORDINATOR` override. Remedy: Make the explicit variable authoritative; use inference only as a labeled fallback with provenance.
- **F03-4** [minor] `plugins/codex-consult/scripts/codex-consult.ps1:3`, `plugins/codex-consult/scripts/codex-consult-hook.ps1:6` - Host-neutral wording is contradicted by Claude-specific script help and hook documentation. Trigger: A Codex or shell user reads the script help or hook description. Evidence: read-code: The synopsis says the bridge runs from Claude Code.; read-code: The hook description assumes Claude Code injects stdout and configures hooks. Verify: Run `Select-String -Path scripts/*.ps1 -Pattern Claude` and inspect the resulting help text. Remedy: Neutralize wording and document the hook as an optional Claude adapter.
- **F03-5** [major] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md:66`, `plugins/codex-consult/skills/consult-codex/SKILL.md:482` - R19 mixes portable discipline with host-specific mechanisms such as `-Kick`, prompt-cache TTL, scheduled wakes, subagents, and auto-compaction, without a host mapping, so Codex cannot implement the rules uniformly. Trigger: A Codex coordinator reads `coordinate` and tries to run a multi-wave delegated task. Evidence: read-code: The rules name Claude-style mechanisms alongside general policy.; read-code: The bridge already has portable `-Detach`, `-Status`, and `-Wait` primitives. Verify: Ask a Codex coordinator to schedule a detached watchdog and log which primitive it uses for waking and compaction. Remedy: State invariants once and provide a per-host capability mapping; remove universal prompt-cache TTL language.
- **F03-6** [major] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md:77` - Shipping worker agent definitions with concrete host model names creates silent cost and quality drift and risks upgrade conflicts. Trigger: A host renames or deprecates a model, or the plugin installer regenerates agent files. Evidence: read-code: The proposal embeds host model names in plugin-owned agent definitions.; inferred: Model identifiers change faster than plugin releases and affect cost and capability. Verify: Change the host's model alias and rerun installation; confirm no plugin-owned file silently changes the selected model. Remedy: Ship tier contracts and generate user-owned host mappings; never auto-rewrite model names on upgrades.
- **F03-7** [minor] `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md:34`, `.collab/host-2026-09-26/handoffs/01-claude-r13-design.md:81` - The coordinator-rules pointer is emitted only by the Claude SessionStart hook, so hookless Codex sessions may never discover `coordinate`. Trigger: A Codex host runs without hooks and delegates work without consulting first. Evidence: read-code: The pointer is attached to the hook output, while the hookless path documents only availability.; read-code: The hook assumes Claude Code context injection. Verify: Start a fresh hookless Codex session and ask for a delegated wave without naming the skill; observe whether `coordinate` is found. Remedy: Put the pointer and a short mandatory rule in the AGENTS snippet and README; keep the hook line optional.

### Prior findings

_(none)_

## Verdict: ADVISE

The design is promising but conflates runtime packaging, identity semantics, and host-specific orchestration, so it needs reframing before implementation.

### Blockers

_(none)_

### Unproven scenarios

- Actual Codex skill discovery and on-demand loading cost were not tested.
- Whether target hosts expose a reliable coordinator model identifier was not tested.
- No fresh install or agent-file generation was executed because this consultation was read-only.

### First-run checklist (observable)

_(none)_
