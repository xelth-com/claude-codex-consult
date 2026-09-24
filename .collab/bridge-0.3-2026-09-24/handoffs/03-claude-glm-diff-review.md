# Handoff 03 - Claude: diff review of the 0.3.0 provider code, for the second reviewer (GLM-5.3)

Date: 2026-09-24. Base commit: `68353d7` (tag `v0.2.0`) + uncommitted 0.3.0 work. You are consulted through
the bridge itself with `-Provider ZAI -Model glm-5.3` - this consultation is the first live use of the
feature you are reviewing, in its own lineage `ZAI/glm-5.3` of this task.

## Question

An adversarial read of the R7 implementation: what breaks, what is not covered, what the harness does not
prove. The design and the Codex reviewer's design findings are in `handoffs/01-claude-design-0.3.md` and
`handoffs/02-codex-design-0.3.md` (F02-1..F02-5, F02-9 adopted; F02-6/7/8 deferred to 0.4.0 as R9).

## Delta since the last review

First review of the code (the design was reviewed by the other reviewer).

- `plugins/codex-consult/scripts/codex-consult-common.ps1`: new sections - constrained TOML scanner
  (`Read-CodexConfigSubset`, `Get-ProviderTable`), reviewer identity (`Resolve-ReviewerIdentity`,
  `ConvertTo-CanonicalBaseUrl`, fingerprint `cc-provider-v1|base_url=...|wire_api=...`), effort
  vocabularies (`Resolve-EffortPlan`: by endpoint host, then model prefix, else `-NativeEffort`), peak
  windows (`Get-PeakStatus`, `ConvertFrom-PeakSpec`, `ConvertFrom-PeakExceptions`), lineage-scoped parent
  selection; `Stop-ProcessTree` now waits up to 3 s for killed pids before judging survivors.
- `plugins/codex-consult/scripts/codex-consult.ps1`: `-Provider`, `-NativeEffort`, `-OffPeakOnly`;
  identity/effort/peak resolved before the lock; `-m` and `-c model_provider` pinned whenever known; the
  prompt ends with `Consultation id: <guid>` and the rollout fallback yields a thread only when the rollout
  file contains it (else `thread_candidate`); legacy ledger entries (0.1/0.2) are unknown provenance and
  never automatic parents; new ledger fields `consult_id`, `reviewer{...}`, `lineage`, `thread_candidate`,
  `effort_requested/effort_sent/effort_mapping/effort_confirmed`, `peak/peak_schedule/peak_source`.
- Requested checks are a prompt convention (a `## Requested checks` section at the end of `reply_markdown`,
  RC1..RCn, at most 5) - use it if you want evidence.

## CURRENT invariants claimed

- The ledger records the provider and model Codex actually uses: `-Provider`/`-Model` when given, else the
  config's `model_provider` (Codex default `openai`) and `model`; a top-level `profile` key or an unreadable
  identity records `unknown` and forbids automatic fork/resume.
- Fork/resume never crosses a lineage; a changed endpoint or protocol refuses reuse; harness version and
  secret rotation never affect reuse.
- A thread is recorded only from `thread.started` or from a rollout file that contains this run's
  consultation id.
- Everything from 0.2.0 (atomic stores, held-handle lock, pending record, validation) is unchanged.

## Evidence

- Implementer's `harness-0.3.ps1`: 127/127 on PowerShell 5.1 and on pwsh 7.6 (config resolution, scanner
  granularity, fingerprint canonicalisation, parent selection, rollout correlation, effort by host/prefix,
  peak semantics incl. overnight/exception/malformed, the requested-checks paragraph, the real config read
  unchanged); 0.2.0 harnesses green (26/26, 45/45, 10/10, 12/12); KILL 5/5 for the survivor-wait fix.
- Coordinator's dry runs against the real config: `ZAI/glm-5.3` with `-c model_provider="ZAI"` and
  `model_reasoning_effort="max"` for `-Effort xhigh`; the default resolves to `openai/gpt-6-astra`; the
  legacy design thread is refused as `-Thread`.

## Questions (answer by number, under 700 words)

- **Q1.** Read `Resolve-ReviewerIdentity`, `Read-CodexConfigSubset` and `Get-ProviderTable`. Is there a
  Codex config shape (that Codex itself accepts) for which the bridge records a WRONG identity instead of
  `unknown`? Name the shape.
- **Q2.** Read the parent-selection code in `codex-consult.ps1`. Is there a sequence of runs (mixing
  lineages, legacy entries, rollout candidates, `-Thread`) that forks or resumes across a lineage boundary?
- **Q3.** `Resolve-EffortPlan`: the z.ai vocabulary is your own. Is the mapping `medium->high, xhigh->max`
  right for GLM-5.3 through the Codex responses wire, and does anything in your integration path make
  `model_reasoning_effort` a no-op or an error?
- **Q4.** What did THIS consultation look like from your side: did you receive the output schema, the
  consultation id line, the effort setting; anything about the z.ai route the bridge should record that it
  does not?
- **Q5.** Verdict on the diff (ACCEPT/HOLD/REJECT) with blockers, unproven scenarios and the first-run
  checklist for this very consultation (what must be on disk: ledger entry with lineage `ZAI/glm-5.3`,
  `effort_mapping zai-v1`, `usage` from the z.ai route, your reply as bare or fenced JSON parsed and
  validated locally).
