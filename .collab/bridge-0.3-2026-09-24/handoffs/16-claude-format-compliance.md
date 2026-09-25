# Handoff 16 - Claude: why one reviewer answers in prose, and how a format-repair retry should work

Date: 2026-09-24. Base commit: `a743d81` (0.3.0 candidate, pushed). This brief goes to the panel (GLM through
z.ai and MiMo); each of you answers for your own route.

## The problem

Every consultation asks for exactly one JSON object (schema `plugins/codex-consult/schemas/consult-reply.schema.json`,
schema_version "1": verdict, verdict_reason, reply_markdown, findings[], prior_findings[], unproven[],
first_run_checklist[]). The prompt is built by `plugins/codex-consult/scripts/codex-consult.ps1` (search
`Reply format:`): the ask, the brief path, the purpose paragraph, the open findings, then the "Reply format"
section with the field meanings, then - on the `prompt-only` transport - the full JSON Schema text, then
"Constraints: ...", and the very last line `Consultation id: <guid>`.

- The z.ai route (`ZAI :: glm-5.3`) answered in Markdown prose BOTH times: n=2 with `--output-schema` (the
  endpoint accepts the json_schema response format and ignores it) and n=8 with the schema in the prompt
  (`-SchemaTransport prompt-only`). The prose was excellent - it found the same four defects as MiMo - but
  the bridge could not ingest it: `structured false`, no verdict, no finding ids, no `prior_findings`.
- The MiMo route (`mimo :: mimo-v2.6-pro`) returns BARE JSON reliably on `prompt-only` (n=5, n=7, n=9), and
  its endpoint rejects `--output-schema` (`json_schema` not supported, only `text` and `json_object`).
- Codex CLI (`codex exec`) exposes no `json_object` mode; it either passes `--output-schema` (json_schema)
  or nothing. The bridge is dependency-free PowerShell around `codex exec`; it can run a second `codex exec
  resume <thread>` turn.

The operator's proposal: when the reply is not a valid JSON object, call the SAME thread again with a short
request to convert the answer into the required format, and ingest that.

## Questions (answer by number, under 600 words; return the JSON object - this consultation is itself the test)

- **Q1.** For YOUR route: what in the current prompt makes prose more likely than bare JSON? Be concrete:
  the position of the format instruction (before the schema, before the constraints), the word "Markdown"
  inside `reply_markdown`, the numbered questions in the brief, the length of the schema, the `Consultation
  id` last line, the system prompt Codex adds around it. What single change to wording or ORDER would make
  you emit the bare JSON object on the first turn, and how sure are you?
- **Q2.** The format-repair retry: `codex exec ... resume <thread> -` with a prompt like "Your previous
  message was not the JSON object required. Output the same content as exactly one JSON object satisfying
  the schema below - no fence, no text before or after; do not add, drop or change findings." Effort low.
  Risks: content drift between the prose and the JSON (findings added, softened, renumbered), the model
  summarising instead of converting, the retry itself failing. How should the bridge detect drift cheaply
  (e.g. compare the set of `RC` ids, the count of numbered answers, key sentences), and what must the ledger
  record so the coordinator can see that a reply was repaired (`format_retry {attempted, succeeded, thread,
  wall_seconds, drift_note}`), with the ORIGINAL prose kept in the handoff file verbatim?
- **Q3.** Should the retry be one attempt, on by default, for every route? Or only where the endpoint is
  declared `prompt-only`? Or only after a prose reply of at least N words (a short refusal should not be
  "repaired")? Name the rule and the one case it must never fire on.
- **Q4.** Verdict (ACCEPT/HOLD/REJECT is not applicable - use ADVISE) with the concrete wording you recommend
  for (a) the first-turn instruction and (b) the repair prompt, each under 80 words, in `reply_markdown`.
