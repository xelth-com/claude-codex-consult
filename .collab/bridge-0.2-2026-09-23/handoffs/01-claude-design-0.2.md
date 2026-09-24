# Handoff 01 - Claude: design of codex-consult 0.2.0 (R1-R6, T1-T4)

Date: 2026-09-23. Base commit: `6483ec4` (clean tree). Repository: `xelth-com/claude-codex-consult`.

## Question

I am about to implement the whole agreed list - ROADMAP R1-R6 and TECH_DEBT T1-T4 - in one release
of the bridge (0.2.0). Below is the concrete design. Judge it BEFORE I build: what is wrong, what is
missing, what should be cut. Read `ROADMAP.md`, `TECH_DEBT.md` and
`plugins/codex-consult/scripts/codex-consult.ps1` (the current bridge, 709 lines) for the baseline.

## Design

**1. Structured reply (R3 + R4, substrate for T1/T3).** `codex exec --output-schema <plugin>/schemas/consult-reply.schema.json`
(exec-level option, placed before `fork|resume` like the others; present in Codex CLI 0.155.1).
Strict-compatible schema (all fields required, `additionalProperties:false`):

```
verdict: ACCEPT | HOLD | REJECT | ADVISE        verdict_reason: string (one sentence)
reply_markdown: string   - the full prose answer, by question number; this is what people read
findings[]: { severity: blocker|major|minor|note, location: "path:line" or "",
              claim, trigger, evidence: read-code|ran-command|inferred|assumed,
              verification, remedy }            - one item per concrete defect/risk asserted
prior_findings[]: { id, status: fixed|still-open|not-checked|unknown-id, note }
unproven[]: string        first_run_checklist[]: string
```
The prompt explains the field meanings (the schema constrains shape, not meaning). Per consultation
the bridge writes three files: `NN-codex-<slug>.md` = header + `reply_markdown` verbatim + a rendered
section (Verdict / Blockers = findings with severity blocker / Unproven / First-run checklist /
Findings with ids / Prior findings); `NN-codex-<slug>.reply.json` = the raw JSON verbatim;
`NN-codex-<slug>.events.jsonl` as today. If the final message is not parseable JSON, the raw text
becomes the reply body, `structured=false` is recorded, and the run still counts as delivered.
Structured mode is ON by default; `-Raw` switches back to the 0.1 plain-text prompt (escape hatch
for a Codex version without `--output-schema`).

**2. Findings tracked by identity (T1).** `<CollabDir>/<task>/findings.json`, cumulative. The bridge
assigns ids `F<NN>-<k>` (NN = the reply's handoff number, k = position) and appends every new finding
with `status: proposed`, the seven fields above verbatim, `source {consult n, reply, thread,
base_commit, diff_sha256}`, `history[]` and `reviewer_checks[]`. Before each structured consult the
prompt lists the task's open findings (status proposed/implemented) as `id - status - location -
claim` and asks the reviewer to report each in `prior_findings` and NOT to re-file a still-open one
unless the claim changed; the answers land in that finding's `reviewer_checks[]` (with consult n).
Status is moved ONLY by the coordinator, through a second script
`codex-findings.ps1 -Task t -Id F04-1 -Status implemented|verified|rejected|wontfix -Note "..." [-Evidence "..."]`
(`verified` and `rejected` refuse an empty -Note; every status change records when, note, evidence,
base_commit, diff_sha256). `codex-findings.ps1 -Task t -List [-All]` prints the open (or all)
findings. A reviewer's "fixed" is evidence, never a status change.

**3. Revision binding (T2).** Every ledger entry and every status change record `base_commit` (full
sha), `reviewed_revision` (short sha + " + uncommitted", kept for humans), `diff_sha256` = SHA-256 of
`git diff HEAD --binary` concatenated with the blob hashes of untracked non-ignored files
(`git ls-files --others --exclude-standard` + `git hash-object --stdin-paths`), `changed_files` count,
and optional `-Artifact <path>[,<path>]` -> `artifacts[{path, sha256}]` for built binaries. The reply
header shows base commit, the first 12 hex of the diff hash and the file count.

**4. Ledger separation + guard (T3).** `outcome` is renamed `bridge_outcome` (`usable reply` /
`failed: ...`); new fields `verdict`, `verdict_reason`, `findings {blocker,major,minor,note}`,
`finding_ids[]`, `prior_findings[{id,status}]`, `purpose`, `structured`, `reply_json`, `usage` (from
the `turn.completed` event: input/cached/output/reasoning tokens - the R5 measurement together with
effort and wall_seconds). Active-session guard: `<task>/.consult.lock` holding `{pid, host, started}`;
a live pid on the same host refuses the run; a dead pid, or another host's lock older than
-TimeoutSec, is treated as stale and replaced; removed in `finally`. Parentage is already recorded
(`parent_thread`, `thread`).

**5. Presets (R1 + R5).** `-Purpose framing|decision|checkpoint|core-contract|acceptance|diff-review|stuck`
sets default effort and word cap and adds a purpose paragraph to the prompt; explicit -Effort /
-MaxWords still win. Defaults: framing high/700, decision high/700, checkpoint medium/500,
core-contract xhigh/900, acceptance high/900, diff-review high/700, stuck xhigh/700, none high/700.
`core-contract` asks for: every interface, recovery and persistence path and every state machine
(states, transitions, the failure at each transition), and what the evidence does not show, BEFORE
dependent work is built. `acceptance` makes the four R4 blocks mandatory (unproven and the first-run
checklist may be empty arrays for other purposes). The verdict is ACCEPT/HOLD/REJECT for acceptance
and diff-review, ADVISE otherwise.

**6. Brief templates (R2, T4) and role split (R6).** `templates/brief-review.md` (checkpoint /
core-contract / acceptance / diff-review: delta since the last review, CURRENT invariants claimed,
changed files with revision, open finding ids, evidence paths, small critical executables inline,
decision requested) and `templates/brief-framing.md`. The skill tells the coordinator to run `-List`
before writing a review brief, to reconcile task state, and documents the primary-not-exclusive
split (fresh-context verifier of the same family for mechanics; Codex for protocol, state machines,
"what the evidence does not show"). Out of scope for 0.2.0: the bash port, hooks, MCP, reverse
direction.

## Questions (answer by number, under 700 words)

- **Q1.** The schema field set: anything missing, redundant, or mis-typed for the way you actually
  write findings? Is `evidence` as a 4-value enum the right granularity?
- **Q2.** Finding identity: bridge-assigned `F<NN>-<k>`, open ids fed back to you by id, your
  `prior_findings` verdicts stored as evidence, status moved only by the coordinator. Right split, or
  does it lose something (e.g. a finding you would split or merge on re-review)?
- **Q3.** Is base_commit + that diff hash + optional artifact hashes enough for T2, or is there a
  case it still cannot distinguish?
- **Q4.** Presets and their default efforts; structured ON by default with `-Raw` as the opt-out.
  Would you change any default?
- **Q5.** The lock design. Any failure mode you see (crash, timeout kill, shared repo on two machines)?
- **Q6.** What would make you HOLD the acceptance of 0.2.0 - i.e. what must the first-run checklist
  of this release contain before I believe a green dry-run and one live structured consultation?
