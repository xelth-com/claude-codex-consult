---
type: regex
weight: 2
target: last_message
match: contains
pattern: "codex-consult\\.ps1[^\\n]*-Task\\s+eval-smoke[^\\n]*-DryRun|codex-consult\\.ps1[^\\n]*-DryRun[^\\n]*-Task\\s+eval-smoke"
flags: i
---

The final message must contain the bridge command with `-Task eval-smoke` and `-DryRun`.
