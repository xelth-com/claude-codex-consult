# R14 + R15 + R16 - companions: size by stakes, telemetry routing, roles (design for review, wave 25)

Goal: a panel takes as many companions as the stakes need, from as many labs as it can, chosen
by their track record with a share of exploration, and a companion can take a narrow role.
Today `-Panel` takes every available roster entry (weighty ones only on weighty purposes) in
roster order; selection is deterministic and telemetry (`-Rate`, the scoreboard) is only read
by humans.

## Code facts

- `Select-PanelMembers` (common.ps1) walks the roster: availability (preflight, endpoint health,
  peak), then `panel: weighty` vs the purpose (`$script:WeightyPurposes`), `-PanelAll`.
- Ratings live in `findings.json` `ratings[]` (`-Rate <n> -Useful yes|partly|no -Note`), joined
  to the ledger entry by n; `codex-scoreboard.ps1` aggregates per (lineage, purpose) across all
  tasks of the repository (`Read-AllTaskConsults` reads every ledger already, for endpoint
  health).
- Purposes: framing, decision, checkpoint, core-contract, acceptance, diff-review, stuck, chore
  (+ none); presets set effort and max words.

## Design

R14 - size and diversity
1. Default panel size per purpose: checkpoint 1, diff-review 2, framing 3, decision 3,
   core-contract 4, acceptance 4, stuck: all available. `-PanelSize <n>` overrides (n >= 1);
   `-PanelAll` = all available (unchanged). The size counts members that will RUN; skipped
   entries never count.
2. Lab diversity: optional roster field `lab` (free text, e.g. `deepseek`, `moonshot`, `zhipu`,
   `google`, `bytedance`, `alibaba`, `xiaomi`, `meta`, `openai`); default = the provider label.
   Filling a panel of size k: first one member per distinct lab (best-ranked of each lab), then
   the rest by rank. Validation: `lab` is a non-empty string.
3. The design floor is a rule, not code: the consult-codex skill states that framing and
   decision questions go to a panel of at least one companion (never only the author's own
   judgement), and `-Panel` on those purposes warns when fewer than 2 members will run.
4. Documented diminishing returns (README): past about five diverse members, findings repeat.

R15 - telemetry routing
5. Rank = a score per (roster entry, purpose[, topics]) from the ratings of the last 90 days
   across all tasks of the repository: score = 1 + sum(yes) + 0.5*sum(partly) - sum(no), floor
   0.25; a lineage with no ratings on this purpose scores its all-purpose score, else the
   neutral 1. Topics: `-Topic a,b` on the bridge (ledger `topics[]`, the scoreboard gains
   `-By topic`); a rating counts for the topics of its consultation; the score for a topic'd
   request = mean of the purpose score and the topic scores that exist.
6. Selection = weighted draw without replacement over the eligible entries (weights = scores),
   with exploration: with probability 0.2 per slot the slot is filled uniformly from the eligible
   rest. The RNG is seeded per panel (the panel id) and the ledger's `panel` object gains
   `routing: { seed, eligible: [{lineage, score, lab}], picked: [...], explored: [...] }`;
   the dry run prints the same. `-PanelOrder roster` restores today's deterministic order (and
   is the behaviour when no ratings exist at all: draw with equal weights = roster order? No -
   equal weights still shuffle; with no ratings the order is the roster order, documented).
7. Single runs (`-Provider` absent, no `-Panel`): today the first available roster entry. R15
   changes nothing there (the coordinator asked for one reviewer; the roster order is the
   coordinator's ranking).

R16 - roles
8. `-Role <name>`: a role block from `templates/role-<name>.md` appended to the prompt after
   the ask (edge-cases, security, tests, docs shipped; a repository may add its own under
   `.collab/roles/`), recorded as ledger `role`; `-Panel -Role x` gives the same role to every
   member; `-Roles a,b,c` (panel only) assigns roles in order to the picked members (the rest:
   none). Roles change the prompt only - members stay read-only, verdict rules unchanged.

## Tests (fakes only)

Sizes per purpose and `-PanelSize`; lab diversity (two entries of one lab, one of another:
size 2 picks one of each); the floor warning; scores from synthetic ratings (yes/partly/no,
the 90-day cut, the fallback chain); the seeded draw is reproducible (same seed -> same pick)
and exploration happens at the recorded rate over many seeds; `-PanelOrder roster`; the
ledger's routing record and the dry-run text; `-Topic` in the ledger and `-By topic`;
`-Role` block in the prompt and ledger, unknown role refused, `-Roles` assignment order.

## Questions for the reviewers

Q1. The score formula (additive, floor 0.25, 90-day window): sane, or should it be a rate (yes
    over rated) with a confidence prior (few ratings -> pull to neutral)?
Q2. Exploration 0.2 per slot: right order of magnitude for a roster of ~10 and a few panels a
    day? Any reason to make it decay with the number of ratings?
Q3. Diversity before rank: any case where it picks a clearly worse lab representative over a
    better second model of the same lab that the coordinator would regret?
Q4. Should a role change the purpose presets (effort, max words), or stay prompt-only?
