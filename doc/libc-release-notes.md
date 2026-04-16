# libc Release Notes — 0.16.0-libc

This file tracks libzigc C→Zig migration releases that track upstream Zig
release tags. See ctaggart/zig#244 for the release workflow spec, and #10
for the overall migration tracking issue.

## 0.16.0-libc.308565e (candidate)

- **Upstream base**: 0.16.0 (commit `24fdd5b7a4`)
- **Branch**: `libc/0.16.x`
- **Head**: `308565e` — `Merge combined libzigc migrations onto 0.16.0 release`
- **Status**: partial qualification (see matrix below)

### Relationship to combined

`combined` (`04170cbe0d`) is rebased on post-0.16.0 master
(`edfc4727e2`). Since `edfc4727e2` is an ancestor of the `0.16.0` release
commit, and the 33 upstream commits between the two touch no libzigc
files, the libc/0.16.x branch is a straight merge of `combined` into
`0.16.0`, with no conflicts and no dropped migrations.

Full content inherited from `combined`; see that branch's history for
per-PR details (#26–#240, ~150 PRs of libzigc work).

### CI qualification matrix

| Filter  | Run ID      | Primary targets | Notes |
|---------|-------------|-----------------|-------|
| ctype   | 24527534528 | 10/10 ✅        | clean |
| stdio   | 24527535599 | 10/10 ✅        | clean |
| string  | 24527536648 | 0/10 ❌         | thread-exhaustion during libzigc sub-compilation; upstream compiler issue on 2-core runners, not libc/0.16.x regression |
| math    | 24527537666 | 0/? ❌          | same thread-exhaustion pattern as string |
| env     | pending     |                 |       |
| thread  | pending     |                 |       |
| time    | pending     |                 |       |
| conf    | pending     |                 |       |
| exit    | pending     |                 |       |
| legacy  | pending     |                 |       |
| misc    | pending     |                 |       |
| process | pending     |                 |       |
| signal  | pending     |                 |       |
| stdlib  | pending     |                 |       |

Sub-targets (x32, `*_be`) tracked separately; upstream stdlib x32 issues
(aio.zig referencing undefined `std.c.pthread_mutex_t`, `lib/std/os/linux.zig`
syscall arg mismatches, `lib/std/c.zig:7914` unsupported ABI) are
non-blocking per ctaggart/zig#244.

### Known issues

- **Thread exhaustion on 2-core runners**: affects filters that compile a
  large number of C sub-compilations (string, math). `-j1` at the top
  level doesn't help because stage4's internal LLVM ThreadPool spawns
  its own threads. Not specific to libc/0.16.x — same pattern occurs on
  `combined`.
- **x32 sub-target**: upstream stdlib issues prevent compilation. Not
  blocking.

### Tagging

Not yet tagged. To tag once more filters are green:

```
git tag 0.16.0-libc.$(git rev-parse --short=7 libc/0.16.x) libc/0.16.x
git push ctaggart 0.16.0-libc.<sha>
gh release create 0.16.0-libc.<sha> --repo ctaggart/zig \
    --target libc/0.16.x \
    --notes-file doc/libc-release-notes.md
```
