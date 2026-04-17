# Zig Copilot Instructions

## NEVER create upstream pull requests

The Zig project explicitly bans AI-generated contributions (code, issues, PRs, and comments).
See: https://ziglang.org/news/migrating-from-github-to-codeberg/
See: https://codeberg.org/Codeberg/Community/issues/2458

**Do NOT:**
- Create pull requests targeting codeberg.org/ziglang/zig
- Create issues on codeberg.org/ziglang/zig
- Post comments on codeberg.org/ziglang/zig

All work must stay in the cataggar or ctaggart forks on GitHub. Any upstream
contributions must be manually submitted by a human after thorough review.

## GitHub account usage

The `ctaggart/zig` repo is owned by a different GitHub account than `cataggar/zig`.
To perform admin operations (e.g. changing default branch, dispatching workflows),
switch accounts:

```powershell
gh auth switch --user ctaggart   # for ctaggart-owned repos
gh auth switch --user cataggar   # to switch back
```

## Branches on ctaggart/zig

- `master` — mirrors upstream `codeberg.org/ziglang/zig`. Never commit fork-specific changes here.
- `ai` — **default branch**. Hosts all fork-infra workflows and Copilot instructions:
  `test-libc.yml`, `check-release.yml`, `publish.yml`, `daily-repo-status.{md,lock.yml}`.
- `libc/<version>` — release-track branches (e.g. `libc/0.16.x`) for libzigc releases.
- `combined` — CI aggregation of all active libzigc migration branches.
- `libzigc-*` — individual migration feature branches.
- `gh-release` — holds `scripts/download_assets.py` used by `publish.yml`.

The previously used `ctmain` and `ci` branches have been retired; everything
now lives on `ai`. Dispatch CI via `gh workflow run test-libc.yml --ref ai ...`
(not `--ref ci`).
