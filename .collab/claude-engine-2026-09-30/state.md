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

## Open
- Astra's third round on brief 14 (fork) - her verdict decides the tag. Then: ROADMAP/CHANGELOG release notes, the
  operator's roster (endpoint entries are the operator's call), wave 29c (the paired A/B).
- (old) Astra alone on brief 14 (fork her thread) once her limit resets (retry after 01:01); her verdict decides the tag.
- Wave 29b implementation (worker brief: handoff 12 + the recon map of 2026-10-06).
- Wave 29c: the paired A/B run book (E8) - needs the operator's go (spends plan credits).
- Ratings of n=4..7 given; the panel's findings F07..F10 to be moved by the worker's report.
- TECH_DEBT: the Alibaba plans' "not for backend services" wording vs the codex route (operator's call).
