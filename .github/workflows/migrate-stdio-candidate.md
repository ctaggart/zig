---
on:
  workflow_dispatch:
    inputs:
      c_file:
        description: "musl C filename to migrate (e.g. fputc.c, tempnam.c). Just the basename under lib/libc/musl/src/stdio/."
        required: true
        type: string
      base_branch:
        description: "Branch to base the migration on."
        required: false
        default: "libc/0.16.x"
        type: string

permissions:
  contents: read
  pull-requests: read
  issues: read

engine: copilot

tools:
  github:
    toolsets: [default]
  bash: [":*"]

network: defaults

safe-outputs:
  create-pull-request:
    title-prefix: "[aw] libzigc(stdio): migrate "
    labels: [libzigc, stdio, agentic-workflow]
    draft: true
  create-issue:
    max: 1
    title-prefix: "[aw migrate-stdio failed] "
    labels: [libzigc, agentic-workflow, needs-triage]
---

# migrate-stdio-candidate

Port a single musl stdio C source file to Zig on the `libc/0.16.x` release-track branch.

## Context

This fork (ctaggart/zig) is migrating musl C sources to Zig incrementally. The
tracking issue is #10. The current release-track branch is `libc/0.16.x`.

Key files:
- `lib/c/stdio.zig` — destination for Zig ports.
- `src/libs/musl.zig` — source list; entries here cause the C file to be compiled.
- `lib/libc/musl/src/stdio/*.c` — C sources, authoritative reference.
- `lib/c.zig` — contains `pub inline fn symbol(func, name)` which exports a
  weak hidden alias. **Use this** to register every new Zig implementation.

Fork repo: ctaggart/zig. Never push to `origin` (codeberg.org/ziglang/zig) —
the Zig project explicitly bans AI contributions. Work only on ctaggart/zig.

## Task

1. Read `lib/libc/musl/src/stdio/${{ inputs.c_file }}` in full to understand
   the semantics.
2. Skim `lib/c/stdio.zig` to identify existing Zig helpers that can be
   reused. Pay particular attention to `FILE`, `VaList`, `stdin_ext`,
   `stdout_ext`, `stderr_ext`, and the existing `*_impl` functions.
3. Write a Zig implementation following these patterns:
   - `callconv(.c)` on every exported function
   - `symbol(&name_impl, "c_name")` registration inside the
     `if (builtin.link_libc and builtin.target.isMuslLibC())` comptime block
   - For variadic entry points: `var ap = @cVaStart(); defer @cVaEnd(&ap);`
     and forward `ap` to the matching `v*_impl` or `v*_fn` extern
   - Match signatures exactly to the C declaration (check musl's header)
4. Comment out the corresponding entry in `src/libs/musl.zig` with
   `// migrated to lib/c/stdio.zig`. Do **not** delete it — the comment
   preserves the change history and makes grep-audits possible.
5. Sanity-check by reading the diff. Do not run `zig build` locally.
6. Open a **draft** pull request targeting `${{ inputs.base_branch }}` with:
   - Title: `libzigc(stdio): migrate ${{ inputs.c_file }} to Zig`
   - Body: brief explanation of what was ported, a one-line mention of any
     non-obvious design choice (e.g. "used @cVaStart+vfscanf_fn rather than
     the inline v*_impl because ..."), and a note that CI must be dispatched
     manually: `gh workflow run test-libc.yml --repo ctaggart/zig --ref ai -f "branch=<pr-branch>" -f "test-filter=stdio"`

## Common Zig API compat cheatsheet

These patterns recur across the fork. Apply them proactively if you see older
code in nearby branches.

| Old | New |
|-----|-----|
| `std.mem.page_size` | `std.heap.page_size_min` |
| `AT.SYMLINK_NOFOLLOW` enum access | `linux.AT{ .SYMLINK_NOFOLLOW = true }` packed struct |
| `ts.tv_sec` / `ts.tv_nsec` | `ts.sec` / `ts.nsec` |
| `__pthread_self` | `pthread_self` |
| `eint(.NOTSUP)` | `eint(.OPNOTSUPP)` |
| `@bitCast(std.math.maxInt(c_int))` | `@bitCast(@as(c_int, std.math.maxInt(c_int)))` |
| `symbol(&var, "name")` for non-anyopaque | `@export(&var, .{ .name = "name" })` |

## Do not

- Do not touch `master` or `origin`.
- Do not edit files outside `lib/c/stdio.zig` and `src/libs/musl.zig` unless
  absolutely required.
- Do not fix unrelated pre-existing issues.
- Do not add tests.
- Do not run `zig build`. CI on `ctaggart/zig` is the authoritative verifier.

If anything blocks the migration (compiler bug signs, non-obvious ABI
surface, missing dependency), stop, do not open a PR, and instead open an
issue describing what you found.
