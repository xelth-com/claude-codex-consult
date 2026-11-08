# PowerShell coordinator exclusions

Status: complete, tested and deployed by the parent.

Scope: reviewer `ext.exclude_coordinator_providers`, selection and direct-launch enforcement,
Codex-marker provider inference with explicit coordinator precedence, offline harness coverage.
No installed copies, user settings, live consultations or commits are part of this worker's scope.

Findings: coordinator records already persist through panel specs and detached status files;
the exclusion can use that record without downstream environment inference. No repository or
nested AGENTS.md was found. Existing unmarked entries retain selection behavior.

Runtime scripts changed (exact deployment list):
- plugins/codex-consult/scripts/codex-consult-common.ps1: policy validation and matching,
  marker-only provider inference, single/panel selection, per-reviewer availability.
- plugins/codex-consult/scripts/codex-consult.ps1: coordinator propagated to selection;
  explicit/resumed/child enforcement; required-policy conflict exits 5 before launch.
- plugins/codex-consult/scripts/codex-providers.ps1: same resolved coordinator in
  would-select and availability views. Policy records are out/kind coordinator; endpoint
  credential rows retain their existing meaning and policy does not propagate to siblings.

Other changes:
- tests/harness-host.ps1: EXCLUDE cases, including validation, marker/config inference,
  explicit precedence, case-insensitive matching, direct/required/all-excluded refusal,
  ordinary/PanelAll/detached panels, sibling isolation and provider diagnostics.
- README.md: policy schema, precedence, refusal and availability behavior.

Completed verification (fake CLI only, scratch CODEX_HOME/rosters, telemetry off):
- pwsh 7.6.5, harness-host -Only EXCLUDE: 26 passed, 0 failures (initial cases).
- pwsh 7.6.5, harness-visibility -Only AVAIL,AGREE: 14 passed, 0 failures.
- git diff --check: clean.

- PowerShell 5.1 harness-host -Only EXCLUDE,MATCHER,PATHHINT: 42 passed, 0 failures.
- pwsh 7.6.5 harness-host -Only EXCLUDE,MATCHER,PATHHINT,ENV,REFUSE: 49 passed, 0 failures.
Logs are powershell-*.log alongside this state file.

Parent verified the installed baseline still matched its backup, deployed the three
scripts to the Codex plugin cache, and compared copied hashes. Installed dry runs:
OpenAI direct and PanelAll refusals passed; explicit Anthropic coordinator allows
Astra (dry run only). Provider short JSON reports Astra out/kind coordinator with
the exclusion reason. All four installed checks passed. No live model requests.
