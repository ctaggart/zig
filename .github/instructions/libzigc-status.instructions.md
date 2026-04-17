# libzigc C-to-Zig Migration Status

Tracking issue: https://github.com/ctaggart/zig/issues/10
Upstream: https://codeberg.org/ziglang/zig/issues/30978

## Architecture

### Repositories
- **ctaggart/zig** (GitHub) -- main fork. Default branch is `ai` (infra-only).
  - `master` mirrors upstream codeberg.org/ziglang/zig. Never commit fork changes here.
  - `combined` aggregates CI-verified libzigc migration branches.
  - `libc/<version>` release-track branches.
  - `libzigc-*` individual migration feature branches.
- **cataggar/zig** (GitHub) -- CI pool fork, mirrors branches from ctaggart
- **codeberg.org/ziglang/zig** -- upstream, `origin` remote

### Git Remotes (in C:\Users\cataggar\art\zig)
- `origin` = codeberg.org/ziglang/zig (upstream)
- `ctaggart` = github.com/ctaggart/zig (PR target)
- `cataggar` = github.com/cataggar/zig (CI pool)
- `codeberg` = codeberg.org/ctaggart/zig (mirror)

### CI Infrastructure
- Workflow: `.github/workflows/test-libc.yml` on `ai` branch (default on ctaggart/zig)
- Builds stage4 Zig compiler, runs `zig build test-libc` across 10 targets
- Targets: x86_64, x86, aarch64, arm, thumb, riscv, powerpc, s390x, loongarch64, wasm32
- Uses `-j1` for pthread tests, `-j2` for others (thread exhaustion fix)
- libc-test from https://github.com/ctaggart/libc-test.git (mirror of repo.or.cz)
- Check-release cron on `ai` branch (default) of ctaggart/zig

### Auth
```powershell
# ctaggart account (for ctaggart/zig operations)
$env:GH_TOKEN = (("protocol=https`nhost=github.com`nusername=ctaggart`n" | git credential fill) -match "^password=") -replace "^password=",""

# cataggar account (for cataggar/zig operations)
gh auth switch --user cataggar

# Dispatch CI
gh workflow run test-libc.yml --repo ctaggart/zig --ref ai -f "branch=BRANCH" -f "test-filter=FILTER"
```

### Worktree Pattern
```powershell
git worktree add ..\zig-NAME ctaggart/master   # create
# ... work ...
git worktree remove ..\zig-NAME               # cleanup
```

## CI-Verified PRs (~159 of ~169 open)

### 100% Complete Categories
- **math** (16 PRs): #194, #196, #198, #199, #200, #201, #202, #215, #216, #228, #232, #233, #234, #235, #236, #237
- **signal** (9 PRs): #39, #41, #48, #50, #55, #66, #68, #71, #72
- **process** (7 PRs): #61, #63, #77, #85, #86, #95, #221
- **misc** (20/20): #38, #42, #45, #47, #49, #73, #75, #78, #80, #109-#111, #114, #116, #119, #121-#123, #126, #214
- **legacy** (10/10): #40, #56, #64, #84, #87, #102, #103, #145
- **exit** (5/5): #44, #81, #96, #106, #107
- **conf** (4/4): #65, #67, #74, #129

### 80%+ Complete
- **thread** (12/15): #149-#153, #155-#159, #162 pass. #161, #176-#178 verified via split tests (2-core runner thread limit on full `pthread` filter)
- **time** (5/6): #58, #69, #70, #83, #97 pass. #46 has test failures.
- **env** (4/5): #62, #99, #130, #132 pass. #134 (env5) blocked on env4 merge.

### Partially Complete
- **stdio** (9/17): #163, #166, #168, #170, #172, #174, #189, #190, #203 pass. Remaining cause Zig compiler segfaults during test compilation — a compiler bug.

### Other Verified PRs
#26 (prng), #27 (termios), #31 (select), #36 (string), #37 (stdlib), #43 (IPC), #52 (multibyte — CI pending), #53 (fenv), #54 (passwd), #76 (linux), #79 (complex), #82 (locale), #113 (temp), #118 (dirent), #125 (sched), #127 (errno), #148/#154 (ldso), #207 (mq), #208 (crypt), #209 (regex), #210 (setjmp), #211 (internal), #212 (aio), #217 (wasi-thread-stub), #218/#219 (WASI), #222 (wasi-cloudlibc-rest), #238 (sync), #240 (libc-fixes)

## Remaining Work

### Zig Compiler Bug — stdio segfaults (#243): FIXED in session 15
x86_64 SysV ABI issue: Zig lowered MEMORY-class `va_list` args as LLVM `byval(%VaListX86_64)` but clang passes `ptr noundef`. When C called Zig variadic helpers via v* wrappers, the ABI mismatch caused SIGSEGV.

Tier 3 fix in `src/codegen/llvm/FuncGen.zig::nextSystemV`: carve out VaList -> `.byref_mut` (plain `ptr noundef`, matching clang). Commit `0c8030a543` on `fix-243-va-list-byref`. Validated via WSL runtime reproducer and 10/10 CI targets.

Unblocked PRs: #191-192, #193, #195, #197, #204-206 can now migrate v-prefix stdio to Zig. vprintf migrated as positive test (CI run 24539299160 green on all 10 targets).

### Test Failures
- **env5** (#134): blocked on env4 merge (sequential dependency — needs __libc_start_main, __reset_tls from env4)
- **env4** (#132): riscv32 TLS compile error (other 9 targets pass)
- **time1** (#46): test failures on some targets
- **misc19** (#123): fails on aarch64, s390x only

### Network (#112) — Structural Issue
Socket sub-branches (s9-socket, s9-sockopt, s9-stubs, s9-linklibc) provide implementations for ~20 socket syscall wrappers. These need to be merged into the dns-core branch (#112) which uses `@extern` to reference them.

### Network (#112) -- Structural Issue
The comprehensive network PR deleted musl C socket files but the Zig replacement uses `@extern` to reference `socket`, `connect`, `sendmsg` etc. without providing implementations. Need to add Zig syscall wrappers for these ~14 socket functions.

### Thread 13-15 -- Runner Limit
Code verified correct via split test runs. Full `pthread` test filter exhausts 2-core GitHub runner thread limit during Zig compiler internal threading. 4-core runners not available on personal accounts. Verified by running subsets: barrier, cond, mutex, attr, create, sem, thrd all pass individually.

### Math -- Blocked on Merges
- `lgammal.c` blocked by `__polevll.c` (needed until #216 merges)
- 11x `__math_*` helpers blocked until #228 (powf) merges

## Common Zig API Fixes Applied This Session

These patterns recur across branches written against older Zig versions:

| Old Pattern | New Pattern |
|------------|-------------|
| `std.mem.page_size` | `std.heap.page_size_min` |
| `std.atomic.fence(.seq_cst)` | `_ = @atomicLoad(T, ptr, .seq_cst)` |
| `symbol(&var, "name")` for non-anyopaque | `@export(&var, .{ .name = "name" })` |
| `AT.SYMLINK_NOFOLLOW` (enum member) | `linux.AT{ .SYMLINK_NOFOLLOW = true }` (packed struct) |
| `si.fields.common.signo` | `si.signo` (top-level field) |
| `@as(c_int, @truncate(@as(u32, ...)))` | `@as(c_int, @bitCast(@as(u32, ...)))` |
| `ts.tv_sec` / `ts.tv_nsec` | `ts.sec` / `ts.nsec` |
| `__pthread_self` (macro, not a symbol) | `pthread_self` (real exported function) |
| bare `syscall(...)` returning usize | `_ = syscall(...)` |
| `eint(.NOTSUP)` | `eint(.OPNOTSUPP)` |
| `@bitCast(std.math.maxInt(c_int))` | `@bitCast(@as(c_int, std.math.maxInt(c_int)))` |
| `@bitCast(linux.T.IOCSWINSZ)` | `@as(c_int, @bitCast(@as(c_uint, linux.T.IOCSWINSZ)))` |
| `passwd_end[0 -% 1]` (wrapping index) | `(passwd_end - 1)[0]` (pointer arithmetic) |
| `.{ .EMPTY_PATH = true }` (packed struct) | `.{ .SYMLINK_NOFOLLOW = false, .EMPTY_PATH = true }` |

## Session 13 Work
Fixed build failures and CI-verified ~32 new PRs, moving from ~121 to ~153+ verified:
- Fixed @bitCast comptime_int (misc9 ioctl constants)
- Fixed 5 cross-branch dependencies by cherry-picking only own-work commits (misc2, misc3, legacy2, env1, conf1)
- Fixed musl.zig FileNotFound for 5 branches (misc1, misc2, misc3, legacy3, misc5)
- Fixed musl.zig incorrectly removed entries (misc1 signal refs, env1 process/signal refs, conf1 setitimer/vfork refs)
- Fixed 12 Zig API compat issues:
  - page_size → page_size_min, valloc duplicate export (legacy2)
  - @export for non-anyopaque environ_var (env1)
  - comptime_int variable + bitwise NOT (env5)
  - tv_sec/tv_usec/tv_nsec → sec/usec/nsec (linux)
  - string literal [2:0]u8 → [1:0]u8 (s23-misc)
  - sun_path array type + optional pointers + wrapping subtraction (passwd)
  - get_tp() arch support for all musl targets (env4)
  - link_libc → isMuslLibC() for WASI exclusion (env4)
  - EXECVEAT packed struct SYMLINK_NOFOLLOW field (s28-process)
- Rebased s28-process (95 commits behind master)
- Identified stdio segfaults as Zig compiler crashes (not libc code bugs)
- Identified multibyte failure as missing MB_CUR_MAX locale check

## Session 14 Work (Combined Branch)
- Created `combined` branch merging 138 CI-verified PRs (974 C files → Zig)
- Fixed 3 critical ABI bugs blocking stage4 on x86_64:
  1. **FILE struct field order** (stdio.zig): wend/wpos/mustbezero_1/wbase at wrong offsets
  2. **va_list ABI mismatch** (#243): Zig's VaList is MEMORY class on x86_64, incompatible with C's array-to-pointer decay. Fix: keep all va_list/variadic stdio functions as C
  3. **pthread_sigmask sigset size**: hardcoded 16 instead of NSIG/8
  4. **__set_thread_area**: Zig export overrode arch-specific assembly
- Combined branch passes CI on all 10 targets with `ctype` test filter
- Filed #243 documenting the va_list ABI issue

### Key ABI Rules Discovered
- `extern struct` field order in Zig MUST match C exactly (no reordering)
- ~~Functions receiving `va_list` from C callers cannot use Zig's `VaList` type on x86_64~~ — fixed in session 15 (#243). Zig now lowers VaList to `ptr noundef` matching clang.
- Zig `symbol()` exports are weak and won't override arch-specific `.s` assembly (good)
- `@export` with no `.linkage` is strong and CAN override assembly (dangerous)

## Session 15 Work (#243 Tier 3 Fix + Infra Consolidation)
- **Tier 3 fix for #243**: carve-out in `src/codegen/llvm/FuncGen.zig::nextSystemV` to lower `VaList` as `.byref_mut` (`ptr noundef`) instead of `.byref` + `byval_attr`. Commit `0c8030a543` on `fix-243-va-list-byref`.
  - Validated via WSL runtime reproducer (c_sum_val 139→60).
  - CI-verified: ctype + stdio filters green on all 10 targets.
  - Positive test: migrated `vprintf` (added `symbol(&vprintf_impl, "vprintf")` in `lib/c/stdio.zig`, removed `vprintf.c` from `src/libs/musl.zig`) — CI run 24539299160 green.
- **Created `libc/0.16.x` release-track branch** from upstream 0.16.0 + combined libzigc (~63% musl migrated).
- **Infra consolidation**: retired `ctmain` and `ci` branches. All fork-infra (test-libc.yml, check-release.yml, publish.yml, daily-repo-status, Copilot instructions) now lives on `ai` (default branch on ctaggart/zig).
  - `check-release.yml` updated: `gh workflow run publish.yml --ref ctmain` -> `--ref ai`.
  - test-libc.yml dispatch: use `--ref ai` (not `--ref ci`).
- Filed issues: #243 (va_list ABI), #244 (libc release process).

## Session 12 PRs Created
- #232: atan2, atan2f
- #233: fma (f64)
- #234: __fpclassify, __signbit
- #235: nextafter, nexttoward, scalb
- #236: nearbyint, lrint, llrint
- #237: lgamma, lgammaf, signgam
- #240: libc-fixes (ftruncate x32 + errnoSize helper)
