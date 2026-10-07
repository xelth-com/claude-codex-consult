# claude-engine-2026-09-30 - state

Coordinator: Claude Code (Fable 5.1). Branch: `wip/wave29-claude-engine` (main merged 2026-10-06, dea37d8;
harness-claude first run 55/55 after test fixes 55f5c0b).

## Done
- Wave 29 (handoffs 01-05): the claude engine for `auth: subscription | api-key`, D1-D12. Findings F02/F03/F04
  marked implemented 2026-10-06 (verification = the harness run).
- 2026-10-06 panel on handoff 06 (third-party Anthropic-compatible endpoints), detach 8ea7b0af: 07 astra,
  08 glm (codex), 09 kimi, 10 mimo - all ADVISE; 11 glm via Claude Code (by hand). Decisions E1-E10 in
  handoff 12 (D10 reversed). Probes P8-P13 in handoff 12.
- A/B pair P13: Claude Code route ~0.30x z.ai credits, 0.51x wall, both structured first turn (one pair).

## Decided
- Alternative 2: `auth: endpoint` + explicit `endpoint {base_url, env_key, timeout_ms}` + optional `plan`
  (quota group across engines). Model straight, open id pattern. Preflight local (no auth status, no live
  request). Telemetry host-first. Route identity per endpoint, plan identity for quota propagation.
- Terms: z.ai, MiMo, Kimi Code documented; Alibaba not (interactive-only wording); MiniMax shape only.

## Done (continued, 2026-10-07)
- Wave 29b implemented (ee03701, 431ab31, 03ff742; harness-host fix 4c46cdf): all harnesses green, harness-claude 75/75; first live
  endpoint consultation n=8 (handoff 13). Acceptance panel on handoff 14 (detach 81540537): astra OUT (ChatGPT limit, 00:01),
  kimi/dola-seed/muse HOLD on one blocker -> E11 (d8fecd2): no Anthropic model id on the endpoint route. F16-1/F18-1
  implemented; F17-1/F17-2 superseded; F18-2 wontfix (D4).

- 2026-10-07: astra alone (20) HOLD -> E12-E17 (21; 450fcf4/93c8463/4aca34d), RC3 smokes 22/23, amendments A1-A5 (3ed1f6d);
  all harnesses green; brief 14 updated for astra's third round.

- 2026-10-07 05:00: astra's fourth round (25, n=18): **ACCEPT** - "no acceptance blockers remain". Rounds: panel 16-18
  HOLD -> E11; astra 20 HOLD -> E12-E17 (21); MiMo smoke 22 -> A1-A5; astra 24 HOLD -> A6; 25 ACCEPT. 50 findings
  verified with that evidence, 2 superseded. Code head 95eee6e.

## Open
- The operator's decisions: a full suite rerun (the memory guard killed background harnesses; several harnesses
  last ran complete before E12-E16), the merge to main + 0.6.0 + tag (with wave 28e), the operator's own roster
  entries for the endpoint route, wave 29c (the paired A/B).
- Astra's third round on brief 14 (fork) - her verdict decides the tag. Then: ROADMAP/CHANGELOG release notes, the
  operator's roster (endpoint entries are the operator's call), wave 29c (the paired A/B).
- (old) Astra alone on brief 14 (fork her thread) once her limit resets (retry after 01:01); her verdict decides the tag.
- Wave 29b implementation (worker brief: handoff 12 + the recon map of 2026-10-06).
- Wave 29c: the paired A/B run book (E8) - needs the operator's go (spends plan credits).
- Ratings of n=4..7 given; the panel's findings F07..F10 to be moved by the worker's report.
- TECH_DEBT: the Alibaba plans' "not for backend services" wording vs the codex route (operator's call).

## 2026-10-07 (day): the 0.6.0 candidate assembled
- The operator's decisions: full suite rerun (yes), merge + 0.6.0 + tag (yes), the endpoint entries in their roster (added:
  `ZAI-claude`, `mimo-claude`, plan keys zai/mimo on the codex entries; 10 of 12 available), wave 29c (go; after the tag).
- Full suite on 95d9be2 (run-all-20261007-094800): 21 harnesses, 20 green (harness-claude 87/87); harness-panel 53/54 - a
  wall-clock timing check under load, later a SPEC race (the parent killed between the record rewrite and the early parent
  check because the fake never implemented FAKE_CODEX_LOGIN_DELAY_MS); test fix: the fake's login mark + delay, the check
  kills the parent only inside the preflight.
- Wave 28e merged (119008b, opus worker; harness-fixes28e 31; F53-1, F54-1..4 implemented, e478f6b). Roster `panel: light`
  merged (563043a / 0886bd3, opus worker; harness-panel LIGHT 8, harness-roster 120) - for Kimi K2.8 Preview
  (`kimi-for-coding`, 1M window per the what's-new page; per tier unverified) beside `k3`. The operator's Kimi entry waits
  for the 0.6.0 plugin install (the 0.5.1 validator would refuse `light` and with it every run).
- 84644a7: manifests 0.6.0, CHANGELOG heading `[0.6.0] - 2026-10-07`, ROADMAP R10 shipped. Brief 26 (76076eb): astra's
  acceptance of the delta (28e + light) - her verdict decides the tag; then the second full suite, the tag, the push,
  wave 29c (driver and 12 briefs ready in the coordinator's scratchpad `ab/`).

## 2026-10-07 night: the 0.6.0 delta accepted
- Astra on brief 26: HOLD (27, F27-1..4) -> E18-E21; on brief 29: HOLD (30, F30-1/2) -> E23-E24; on brief 31: HOLD
  (32, F32-1/2) -> E25-E26; brief 33: the ChatGPT limit (34), then **ACCEPT (35, n=23)** - F35-1 (a migration recount
  from an unreleased intermediate build) wontfix. All of E18-E26 by the opus worker (119008b -> f215cdb, c74b297,
  3869bbd, 7124348), harness-fixes28e 31 -> 65. Findings F27-1..3, F30-1/2, F32-1/2 verified against 35.
- The bridge held OpenAI 60 min on "try again at 9:43 PM" (a time-only reset it cannot parse - TECH_DEBT, 0.6.1);
  launched with -SkipPreflight on the operator's word.
- Next: RC3 = the full suite on ab51d1f (22 harnesses) -> tag v0.6.0 on the code head -> merge to main -> push; then
  the operator installs 0.6.0 (marketplace update) and `~/.codex/codex-consult-roster-0.6.json` goes live (the 0.5.1
  validator refuses `plan`/`light`); then wave 29c (A/B); then the website pass (memory).

