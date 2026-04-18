---
on:
  schedule:
    - cron: "23 13 * * *"  # Daily 13:23 UTC
  workflow_dispatch:

permissions:
  contents: read
  issues: read
  pull-requests: read
  actions: read

engine: copilot

tools:
  github:
    toolsets: [default, actions]
  bash: [":*"]

network: defaults

safe-outputs:
  create-issue:
    max: 1
    title-prefix: "[aw daily-status] "
    labels: [libzigc, daily-status, agentic-workflow]
---

# libzigc-daily-status

Post a daily status issue for the libzigc migration effort.

## Context

- Tracking issue: ctaggart/zig#10.
- Release-track branch: `libc/0.16.x` on `ctaggart/zig`.
- Fork infra branch: `ai` (default).
- Previously this task was handled by `.github/workflows/daily-repo-status.yml`
  which emitted a static Markdown file. This agentic version posts a fresh
  status issue each day (labelled `daily-status`) so history accumulates in
  the issue list. Close older ones manually when stale.

## Task

Gather today's status and open **one** new issue. Keep the body under
30 lines. Use this structure exactly:

```
**Open PRs**: <N> on ctaggart/zig
**libc/0.16.x HEAD**: <short-sha> — <commit subject>
**Latest release**: <tag>
**Last test-libc run**: <conclusion> (<branch>, <relative time>)

**Remaining musl C files**: <count from `src/libs/musl.zig` non-commented entries>

### Suggested next migration candidate

- <filename> — <one-line rationale>

### Open PRs needing attention (≤5)

- #<n> <title> — <blocker>
```

Use today's date in the issue title (after the `[aw daily-status] ` prefix),
e.g. `[aw daily-status] 2026-04-18`.

## Data sources

- `gh pr list --repo ctaggart/zig --state open --json number,title`
- `gh api repos/ctaggart/zig/git/ref/heads/libc%2F0.16.x`
- `gh release list --repo ctaggart/zig --limit 1`
- Last `test-libc` workflow run via the GitHub MCP actions toolset
- `src/libs/musl.zig` on `libc/0.16.x` (use `gh api contents` or
  `gh search code` if needed). Count non-comment lines matching
  `"musl/src/` to get the remaining-C-sources number.

## Next-candidate heuristic

Suggest a file from `src/libs/musl.zig` that is:
1. Small in musl (`< 80` lines in `lib/libc/musl/src/.../<name>.c`)
2. Has no upstream-specific assembly
3. Not in a subsystem already known to be problematic (skip wide-char
   I/O state machines, skip FILE lifecycle functions like `fopen`/`fclose`
   for now)

Prefer stdio → process → time → env subsystems, in that order.

## Do not

- Do not open more than one issue per run.
- Do not open PRs.
- Do not include hypothetical numbers. If a data point cannot be fetched,
  write `<unknown>` rather than guessing.
