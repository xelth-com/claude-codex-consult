# OpenAI coordinator / Astra exclusion

Status: PowerShell implementation retained; C3 implementation rolled back at the
user's request, 2026-10-17. Rollback and retained bridge checks passed.

Current scope: enforce the policy only in the PowerShell bridge. C3 tracked
sources are restored to HEAD and the added test and task logs are archived.
The original binary backup was 0.2.1; after the user pointed out the version
downgrade, clean C3 0.2.2 was rebuilt and installed from the unchanged sources
with cargo install --offline --locked. Installed/build hashes and Cargo's
package registration now agree on 0.2.2. Global roster policy and coordinator
instructions remain; the Astra skill now names only the PowerShell bridge.
Rollback archive:
`C:/Users/Dmytro/.codex/backups/2026-10-16-openai-self-review/c3-rollback-20261017-230543`.

Final rollback verification: C3 tracked diff is empty; installed binary SHA256
matches the clean release build and reports 0.2.2; added test/task logs archived.
The version correction took 6m 17s and is recorded in restore-clean-0.2.2.log
and clean-0.2.2-verification.json in the rollback archive.
All 10 preserved PowerShell source/runtime/config file hashes are unchanged.
Installed PowerShell dry runs passed: OpenAI direct refusal, OpenAI PanelAll
refusal, explicit Anthropic eligibility. No live model calls were made.
Astra skill frontmatter is byte-for-byte unchanged. quick_validate still rejects
the pre-existing argument-hint and disable-model-invocation fields, as before;
only the body wording was changed from both bridges to the PowerShell bridge.

The implementation and deployment notes below are historical; their C3
deployment statements no longer describe the active installation.

User request: automatically exclude Astra from consultations when the coordinator
uses OpenAI; keep Astra available from other providers. Applies to C3 and the
PowerShell bridge already installed on this machine.

Policy contract: per-reviewer `ext.exclude_coordinator_providers: ["openai"]`.
Case-insensitive provider comparison; explicit coordinator identity takes priority.
Without an explicit identity, infer only the provider from Codex runtime markers
and its config default. Never infer from an installation directory or invent a model.
Panel-all, required reviewers, direct calls and detached children obey the policy.

Completed local configuration:
- Added the policy only to Astra in `C:/Users/Dmytro/.codex/codex-consult-roster.json`.
- Added consultation independence to `C:/Users/Dmytro/.codex/AGENTS.md`.
- Updated `C:/Users/Dmytro/.agents/skills/astra/SKILL.md`.
- Verified all other roster records unchanged; skill YAML parses with original fields.
  Bundled quick_validate rejects pre-existing `argument-hint` and
  `disable-model-invocation` fields, which were preserved.
- Backed up original config, skill, AGENTS, installed executable and relevant scripts
  in `C:/Users/Dmytro/.codex/backups/2026-10-16-openai-self-review`.

Resumed 2026-10-17. Prior workers were interrupted before verification/build.
Fresh workers are finishing the saved changes in these repositories:
- PowerShell: this repo; report `powershell-STATE.md` beside this file.
- Rust: `C:/Users/Dmytro/C3`; report `.collab/openai-self-review/rust-STATE.md`.

Parent reviewed the implementation diff and requested two remaining corrections:
PowerShell provider diagnostics must include policy; Rust required-policy conflicts
must return exit 5 (direct reviewer refusal remains exit 1).

Both workers hit usage limits; parent completed the remaining work directly.
PowerShell checks: PS5.1 42/42, pwsh 49/49, visibility 14/14. Three runtime scripts
were deployed with backup and hash checks; installed direct/panel-all exclusion,
non-OpenAI eligibility, and availability diagnostics all passed.
Rust checks: core 8/8, runtime 2/2, fake-CLI integration 2/2 (including detach).
Parent fixed the missing C3 availability projection and added a sibling-isolation
regression test. The initial release was already compiling when that final fix was
written: its installed direct/panel-all/non-OpenAI checks passed, but availability
still showed Astra available. The final rebuild is running as exec session 75022,
log `C:/Users/Dmytro/C3/.collab/openai-self-review/rust-release-final.log`.
Current installed C3 hash is saved to backup directory `c3-interim.sha256`; compare
it before replacing with the final release. Original executable backup remains.

Final release completed successfully (5m 58s) and was installed with a guarded
replacement; installed and built executable hashes match. All three installed
C3 dry runs passed: OpenAI direct refusal, OpenAI PanelAll refusal, Anthropic
eligibility. C3 provider diagnostics now report Astra out/kind coordinator with
the exclusion reason. Both installed bridges and global instructions are active.
No implementation or verification work remains.
Runtime check script: `C:/Users/Dmytro/.codex/backups/2026-10-16-openai-self-review/verify-runtime.ps1`.
No live model consultation has been run. No commits.
