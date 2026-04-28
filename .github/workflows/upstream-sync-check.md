---
on:
  schedule:
    - cron: "17 6 * * 1"  # Mondays 06:17 UTC
  workflow_dispatch:

permissions:
  contents: read
  issues: read
  pull-requests: read

engine: copilot

tools:
  github:
    toolsets: [default]
  bash: [":*"]

network:
  allowed:
    - defaults
    - "codeberg.org"

safe-outputs:
  create-issue:
    max: 1
    title-prefix: "[aw upstream-sync] "
    labels: [libzigc, upstream-sync, agentic-workflow]
---

# upstream-sync-check

Weekly probe: does upstream Zig (codeberg.org/ziglang/zig) have new commits,
and if so, do any of them touch files the fork has already migrated to Zig
on `libc/0.16.x`?

## Context

- Upstream: codeberg.org/ziglang/zig — **read-only to us**. Never push or
  open PRs there (AI contributions are banned by the Zig project).
- Fork: ctaggart/zig. Release-track branch: `libc/0.16.x`.
- Tracking issue: #10.
- Migrated Zig ports live in `lib/c/` on `libc/0.16.x`.
- C sources removed from build live as `// migrated to lib/c/...` comments
  in `src/libs/musl.zig`.

## Task

1. Fetch the upstream repo state. Since GitHub MCP only knows about
   github.com, use bash with `git ls-remote https://codeberg.org/ziglang/zig.git master`
   to get the latest upstream master SHA.
2. Fetch the last-known mirrored SHA from github.com/ctaggart/zig on branch
   `master` (this is the fork's upstream mirror).
3. If they match, exit quietly — no issue needed.
4. If they differ, fetch the list of changed files between the two SHAs
   (use the GitHub MCP `get_commit` / compare tooling on github.com since
   the fork mirrors upstream master).
5. Cross-reference with the file list from `libc/0.16.x`:
   - For each changed upstream file under `lib/libc/musl/src/`, check
     whether the corresponding `src/libs/musl.zig` entry is already
     commented out (migrated) on `libc/0.16.x`.
   - List any migrated files that upstream touched. Those are potential
     re-apply targets when we next rebase.
6. Open **one** issue summarizing:
   - How many upstream commits since last check
   - Range of changed musl files (total count, and which subsystems)
   - List of already-migrated files that upstream changed (the interesting
     list) — with a one-line diff summary per file
   - Recommended action: "no action", "rebase libc/0.16.x", or
     "re-audit migrated Zig ports against <N> upstream changes"

## Deduplication

If an open issue with label `upstream-sync` already exists for the same
upstream head SHA, update it via a comment instead of opening a new one.
(If you cannot comment on issues — no `add-comment` safe-output configured
here — then just skip filing and let the existing issue stand.)

## Do not

- Do not push anything anywhere.
- Do not open PRs.
- Do not file an issue when upstream has not moved.
- Do not fetch from codeberg with anything other than `git ls-remote` —
  we do not want to clone the full upstream repo in this workflow.
