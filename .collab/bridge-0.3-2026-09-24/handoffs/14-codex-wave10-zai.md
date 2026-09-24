# Handoff 14 - Codex: wave10-zai

Date: 2026-09-24 17:09 local. Author: Codex (model glm-5.3, effort high), Codex CLI 0.155.1.
Reviewer: ZAI :: glm-5.3 (provider from roster, model from roster; endpoint https://api.z.ai/api/v1, wire_api: responses; provider fingerprint 29edbb79ed7d; harness codex-cli 0.155.1).
Preflight: ok: env ZAI_API_KEY set.
Roster: C:\Users\Dmytro\.codex\codex-consult-roster.json - position 2 of 3, panel 6710207b member 1 of 2; skipped openai :: gpt-6-astra (usage limit until 2026-09-28T20:35:00+02:00).
Effort: high sent (requested high, mapping zai-v1, by caps-v1: api.z.ai, glm-5.3; not confirmed by the provider). Consultation id: fcf48f2a-708a-4878-b6dd-da1e340e65c8.
Invocation: `codex-consult.ps1` (mode: fork, sandbox: read-only, purpose: diff-review). Argv: `codex exec --sandbox read-only --color never --json -m glm-5.3 -c model_reasoning_effort="high" -c model_provider="ZAI" -o C:\Users\Dmytro\AppData\Local\Temp\codex-consult-last-28b9d05e33ff4c92ae4640e8ef55e42b.md fork 01a0d16e-5780-73d3-b462-9d5bc8465d9e -` (prompt on stdin).
Parent thread: `01a0d16e-5780-73d3-b462-9d5bc8465d9e`. Result thread: `01a0d3f7-1cb2-71e2-8fed-29a3aa9fd408` (source: events).
Brief: `.collab/bridge-0.3-2026-09-24/handoffs/13-claude-wave10-panel-review.md` (sha256 77b703a4e500). Reviewed: 68353d7 + uncommitted, base 68353d756cbb581700a0be3d4338cd32a43a1950, tree sha256 e5a615a44a34, 27 changed files.
WARNING: working tree changed during the review (fingerprint before/after differ).
Bridge outcome: usable reply. Wall time: 546.6 s. Tokens: in 4510937 (cached 4145216), out 45862, reasoning 37622.
Structured reply (prompt-only transport): INVALID (not valid JSON: Ungültiger JSON-Primitiv: .) - raw text kept; no findings recorded. Raw last message: `handoffs/14-codex-wave10-zai.reply.json`.
Raw event stream: `handoffs/14-codex-wave10-zai.events.jsonl`.
Verbatim reply follows.

---

**Q1.** Mostly handled, with two concrete failures. Handled: no‑year dates (common.ps1:2690 adds a year only when the date lies >1 day in the past), 12 AM/PM normalization, ISO stamps that carry their own offset (2702), and stored `retry_after` values compare as instants, so a ledger read in another zone stays correct. Not handled: (a) DST between `when` and the reset — every Codex‑style wall time is built with `$Reference.Offset` (2687, 2689; offset‑less ISO 2706): a failure recorded 2026‑10‑25T01:00+02:00 (Berlin) with "try again at Oct 26th, 2026 8:35 PM" printed in post‑transition CET yields 2026‑10‑26T20:35+02:00 = 18:35Z instead of 19:35Z — `Until` expires an hour early and the walk launches a still‑limited reviewer (spring direction: an available one is skipped for an hour). The interpretation is right only if Codex formats with the failure‑moment offset; that convention is unverified (finding #1). (b) A 12‑hour time without AM/PM is read as 24‑hour by design: "try again at Sep 28th, 8:35" meaning 20:35 becomes 08:35 — up to 12 h early (same finding).

**Q2.** The walk itself is tight: per‑fingerprint health, newest‑wins with success clearing auth/quota, quota‑without‑reset skipped only ≤60 min, `-RosterWalk` closing the transient‑429 loophole. Three mis‑picks remain: (1) the DST case above; (2) pre‑wave‑10 entries re‑parsed on a pwsh host in another zone — `when` comes back as a local `[datetime]` (the harness's own comment, tests/harness-roster.ps1:155‑156) and `ConvertTo-WhenOffset` (2779) re‑labels it with the reader's offset, so "8:35 PM" recorded at −05:00 and read at +08:00 parses to 12:35Z instead of 01:35Z — 13 h early (finding #2); (3) common.ps1:2816 silently drops records dated >5 min in the future: an auth failure from a host six minutes fast is invisible and its entry is selected (finding #3). I found no wrongful refusal beyond the conservative directions of those same bugs.

**Q3.** A timeout kills member 2's codex tree from inside member 2: its ledger entry is recorded ("failed: timeout…", panel id/position), and `.consult.pending.json` is removed — or left in state `survivors` when the tree refuses to die, which refuses member 3 with the recovery message; member 3 is then recorded failed and member 4 continues. The panel loop never breaks on a member failure; `Find-PanelEntry` finds the failed entry (null if the member process itself died → row "failed: exit N", and member 3's lock/pending recovery consumes the dead member's reservation, numbering skipping past it). Exit code is 1 (`allUsable` false) even when members 1 and 3 were usable; the summary prints one row per roster entry. The harness proves only a codex exit‑1 member failure — the timeout, survivors and process‑kill mid‑panel paths are unproven.

**Q4.** **HOLD.** The roster/panel architecture is sound and the 95 fixtures genuinely cover walk order, fail‑closed roster parsing, quota semantics, prompt isolation and exit codes; but the wave's central invariant ("never call or count on a provider without tokens") rests on an unverified timezone convention (finding #1) plus two smaller mis‑pick paths (#2, #3), all cheap to settle. Prior findings: F02‑4, F06‑1..F06‑4, F12‑2 fixed; F12‑1 still open in its rotated‑credential limb (anonymous endpoints now have `"auth": "none"`).

## Requested checks

- **RC1** — In a clone of `github.com/openai/codex` at the installed CLI version (working dir: the clone; read‑only; ~20 min): locate the usage‑limit message formatter and determine which zone rule it applies to the reset instant (print‑time zone vs reset‑instant zone). Settles finding #1's direction.
- **RC2** — Working dir: repo root; read‑only; ~5 min: `pwsh -NoProfile -Command "('2026-10-25T01:00:00-05:00' | ConvertFrom-Json) | ForEach-Object { [DateTimeOffset]$_ }"` under `TZ=Asia/Shanghai` vs `TZ=America/New_York`; observation: the offset follows the reader's zone (finding #2).
- **RC3** — Working dir: repo root; workspace‑write (scratch harness fixture); ~10 min: add a walk case whose seeded failure `when` is now+6 min; observation: the entry is currently selected (finding #3).
- **RC4** — Same scratch harness; ~15 min: add a panel case whose member‑2 fake codex sleeps past `-TimeoutSec`; observation: member 3 still runs, exit 1, pending ends clean or 'survivors' refuses member 3 (Q3 path).
