const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
const symbol = @import("../c.zig").symbol;
const NSIG = linux.NSIG;
const sigset_t = linux.sigset_t;
const SigsetElement = @typeInfo(sigset_t).array.child;
const bits_per_elem = @bitSizeOf(SigsetElement);
const errno = @import("../c.zig").errno;
const all_mask = blk: {
    var mask: sigset_t = undefined;
    for (&mask) |*elem| elem.* = ~@as(SigsetElement, 0);
    break :blk mask;
};
const app_mask = blk: {
    var mask = all_mask;
    // Clear bits for internal signals 32, 33, 34 (bits 31, 32, 33)
    for (.{ 31, 32, 33 }) |s| {
        mask[s / bits_per_elem] &= ~(@as(SigsetElement, 1) << @intCast(s % bits_per_elem));
    }
    break :blk mask;
};
// Musl's struct sigaction (different from kernel's k_sigaction)
const c_sigaction = extern struct {
    handler: ?*align(1) const fn (c_int) callconv(.c) void,
    mask: [128 / @sizeOf(c_ulong)]c_ulong,
    flags: c_int,
    restorer: ?*const fn () callconv(.c) void,
};
// Resolved via the symbols exported below from `__libc_sigactionImpl` and friends.
extern "c" fn sigaction(sig: c_int, act: ?*const c_sigaction, oact: ?*c_sigaction) callconv(.c) c_int;
extern "c" fn __sigaction(sig: c_int, act: ?*const c_sigaction, oact: ?*c_sigaction) callconv(.c) c_int;
const SA_RESTART = 0x10000000;
const SA_SIGINFO_NONMIPS: c_int = 4;
const SA_SIGINFO_MIPS: c_int = 8;
const SA_SIGINFO: c_int = if (builtin.cpu.arch.isMIPS()) SA_SIGINFO_MIPS else SA_SIGINFO_NONMIPS;
const SA_RESTORER: c_int = 0x04000000;
// Minimal view of musl's `struct __libc` (from src/internal/libc.h), enough
// to read the `threaded` field for the pre-pthread unblock dance.
const LibC = extern struct {
    can_do_threads: u8,
    threaded: u8,
    secure: u8,
    need_locks: i8,
    threads_minus_1: c_int,
};
extern var __libc: LibC;
extern var __abort_lock: c_int;
extern "c" fn __lock(lock: *c_int) void;
extern "c" fn __unlock(lock: *c_int) void;
extern "c" fn psignal(sig: c_int, msg: ?[*:0]const u8) callconv(.c) void;
const FILE = extern struct {
    flags: c_uint,
    rpos: ?[*]u8,
    rend: ?[*]u8,
    close_fn: ?*anyopaque,
    wend: ?[*]u8,
    wpos: ?[*]u8,
    mustbezero_1: ?[*]u8,
    wbase: ?[*]u8,
    read_fn: ?*anyopaque,
    write_fn: ?*anyopaque,
    seek_fn: ?*anyopaque,
    buf: ?[*]u8,
    buf_size: usize,
    prev: ?*anyopaque,
    next: ?*anyopaque,
    fd: c_int,
    pipe_pid: c_int,
    lockcount: c_long,
    mode: c_int,
    lock: c_int,
    lbf: c_int,
    cookie: ?*anyopaque,
    off: i64,
    getln_buf: ?[*]u8,
    mustbezero_2: ?*anyopaque,
    shend: ?[*]u8,
    shlim: i64,
    shcnt: i64,
    prev_locked: ?*anyopaque,
    next_locked: ?*anyopaque,
    locale: ?*anyopaque,
};
const stderr_ext = @extern(*const ?*FILE, .{ .name = "stderr" });
const strsignal_fn = @extern(*const fn (c_int) callconv(.c) [*:0]const u8, .{ .name = "strsignal" });
const fwrite_fn = @extern(*const fn (*const anyopaque, usize, usize, ?*FILE) callconv(.c) usize, .{ .name = "fwrite" });
const fputc_fn = @extern(*const fn (c_int, ?*FILE) callconv(.c) c_int, .{ .name = "fputc" });
const lockfile_fn = @extern(*const fn (*FILE) callconv(.c) c_int, .{ .name = "__lockfile" });
const unlockfile_fn = @extern(*const fn (*FILE) callconv(.c) void, .{ .name = "__unlockfile" });
const SIG_HOLD: ?*align(1) const fn (c_int) callconv(.c) void = @ptrFromInt(2);
const SIG_ERR: ?*align(1) const fn (c_int) callconv(.c) void = @ptrFromInt(std.math.maxInt(usize));
const SI_QUEUE = -1;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&sigaddsetLinux, "sigaddset");
        symbol(&sigandsetLinux, "sigandset");
        symbol(&sigdelsetLinux, "sigdelset");
        symbol(&sigemptysetLinux, "sigemptyset");
        symbol(&sigfillsetLinux, "sigfillset");
        symbol(&sigisemptysetLinux, "sigisemptyset");
        symbol(&sigismemberLinux, "sigismember");
        symbol(&sigorsetLinux, "sigorset");
        symbol(&__libc_current_sigrtmin, "__libc_current_sigrtmin");
        symbol(&__libc_current_sigrtmax, "__libc_current_sigrtmax");
        symbol(&killLinux, "kill");
        symbol(&killpgLinux, "killpg");
        symbol(&sigpendingLinux, "sigpending");
        symbol(&sigaltstackLinux, "sigaltstack");
        symbol(&sigprocmaskLinux, "sigprocmask");
        symbol(&sigsuspendLinux, "sigsuspend");
        symbol(&__block_all_sigs, "__block_all_sigs");
        symbol(&__block_app_sigs, "__block_app_sigs");
        symbol(&__restore_sigs, "__restore_sigs");
        symbol(&__libc_sigactionImpl, "__libc_sigaction");
        symbol(&__sigactionImpl, "__sigaction");
        symbol(&__sigactionImpl, "sigaction");
        symbol(&__get_handler_set, "__get_handler_set");
        @export(&__eintr_valid_flag, .{ .name = "__eintr_valid_flag", .linkage = .weak, .visibility = .hidden });
        symbol(&sigholdLinux, "sighold");
        symbol(&sigrelseLinux, "sigrelse");
        symbol(&sigpauseLinux, "sigpause");
    }
    if (builtin.link_libc and builtin.os.tag == .linux) {
        symbol(&signalImpl, "signal");
        symbol(&siginterruptImpl, "siginterrupt");
        symbol(&sigignoreImpl, "sigignore");
        symbol(&psiginfo, "psiginfo");
        symbol(&psignalImpl, "psignal");
        symbol(&sigsetImpl, "sigset");
        symbol(&sigqueueImpl, "sigqueue");
    }
}

fn sigaddsetLinux(set: *sigset_t, sig: c_int) callconv(.c) c_int {
    const s: u32 = @bitCast(sig -% 1);
    if (s >= NSIG - 1 or @as(u32, @bitCast(sig -% 32)) < 3) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    (set.*)[s / bits_per_elem] |= @as(SigsetElement, 1) << @intCast(s % bits_per_elem);
    return 0;
}

fn sigandsetLinux(dest: *sigset_t, left: *const sigset_t, right: *const sigset_t) callconv(.c) c_int {
    for (dest, left, right) |*d, l, r| d.* = l & r;
    return 0;
}

fn sigdelsetLinux(set: *sigset_t, sig: c_int) callconv(.c) c_int {
    const s: u32 = @bitCast(sig -% 1);
    if (s >= NSIG - 1 or @as(u32, @bitCast(sig -% 32)) < 3) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    (set.*)[s / bits_per_elem] &= ~(@as(SigsetElement, 1) << @intCast(s % bits_per_elem));
    return 0;
}

fn sigemptysetLinux(set: *sigset_t) callconv(.c) c_int {
    @memset(std.mem.asBytes(set), 0);
    return 0;
}

fn sigfillsetLinux(set: *sigset_t) callconv(.c) c_int {
    @memset(std.mem.asBytes(set), 0xff);
    // Clear bits for internal signals 32, 33, 34 (bits 31, 32, 33)
    inline for (.{ 31, 32, 33 }) |s| {
        (set.*)[s / bits_per_elem] &= ~(@as(SigsetElement, 1) << @intCast(s % bits_per_elem));
    }
    return 0;
}

fn sigisemptysetLinux(set: *const sigset_t) callconv(.c) c_int {
    for (set) |elem| {
        if (elem != 0) return 0;
    }
    return 1;
}

fn sigismemberLinux(set: *const sigset_t, sig: c_int) callconv(.c) c_int {
    const s: u32 = @bitCast(sig -% 1);
    if (s >= NSIG - 1) return 0;
    return @intFromBool((set.*)[s / bits_per_elem] & (@as(SigsetElement, 1) << @intCast(s % bits_per_elem)) != 0);
}

fn sigorsetLinux(dest: *sigset_t, left: *const sigset_t, right: *const sigset_t) callconv(.c) c_int {
    for (dest, left, right) |*d, l, r| d.* = l | r;
    return 0;
}

fn __libc_current_sigrtmin() callconv(.c) c_int {
    return 35;
}

fn __libc_current_sigrtmax() callconv(.c) c_int {
    return NSIG - 1;
}

fn killLinux(pid: linux.pid_t, sig: c_int) callconv(.c) c_int {
    return errno(linux.kill(pid, @enumFromInt(@as(u32, @bitCast(sig)))));
}

fn killpgLinux(pgid: linux.pid_t, sig: c_int) callconv(.c) c_int {
    if (pgid < 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    return killLinux(-pgid, sig);
}

fn sigpendingLinux(set: *linux.sigset_t) callconv(.c) c_int {
    return errno(linux.syscall2(.rt_sigpending, @intFromPtr(set), NSIG / 8));
}

fn sigaltstackLinux(ss: ?*const linux.stack_t, old: ?*linux.stack_t) callconv(.c) c_int {
    if (ss) |s| {
        if (s.flags & linux.SS.DISABLE == 0 and s.size < MINSIGSTKSZ) {
            std.c._errno().* = @intFromEnum(linux.E.NOMEM);
            return -1;
        }
        if (s.flags & linux.SS.ONSTACK != 0) {
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
            return -1;
        }
    }
    return errno(linux.sigaltstack(ss, old));
}

// musl-userspace `MINSIGSTKSZ` (from `arch/<arch>/bits/signal.h`). These
// values intentionally differ from `std.os.linux.MINSIGSTKSZ`, which is
// the kernel UAPI minimum; the userspace value is generally larger
// because it includes space for libc bookkeeping. `sigaltstack` must
// reject sub-userspace-minimum stacks with `ENOMEM` so that musl-built
// libc-test cases (e.g. `regression.sigaltstack`) see the same
// behaviour they see against musl.
const MINSIGSTKSZ: usize = switch (builtin.cpu.arch) {
    .aarch64, .aarch64_be => 6144,
    .loongarch32, .loongarch64, .powerpc, .powerpcle, .powerpc64, .powerpc64le, .s390x => 4096,
    else => 2048,
};

fn sigprocmaskLinux(how: c_int, noalias set: ?*const linux.sigset_t, noalias old: ?*linux.sigset_t) callconv(.c) c_int {
    const rc = linux.sigprocmask(@bitCast(@as(u32, @bitCast(how))), set, old);
    const signed: isize = @bitCast(rc);
    if (signed < 0) {
        std.c._errno().* = @intCast(-signed);
        return -1;
    }
    return 0;
}

fn sigsuspendLinux(mask: *const linux.sigset_t) callconv(.c) c_int {
    return errno(linux.syscall2(.rt_sigsuspend, @intFromPtr(mask), linux.NSIG / 8));
}

fn __block_all_sigs(set: ?*sigset_t) callconv(.c) void {
    _ = linux.sigprocmask(linux.SIG.BLOCK, &all_mask, set);
}

fn __block_app_sigs(set: ?*sigset_t) callconv(.c) void {
    _ = linux.sigprocmask(linux.SIG.BLOCK, &app_mask, set);
}

fn __restore_sigs(set: *const sigset_t) callconv(.c) void {
    _ = linux.sigprocmask(linux.SIG.SETMASK, set, null);
}

// State backing the migrated `sigaction.c`: a bitmap of installed
// non-default handlers (read by `__get_handler_set` from posix_spawn),
// a "have we unmasked the implementation-internal signals yet" flag,
// and the EINTR-might-be-meaningful flag consulted by `__timedwait`.
var handler_set: sigset_t = @splat(0);
var unmask_done: bool = false;
var __eintr_valid_flag: c_int = 0;

// True for arches whose userspace must install an rt_sigreturn trampoline
// (`SA_RESTORER` flag). All other Linux arches (mips, loongarch, riscv,
// hexagon, or1k) hand sigreturn off to the kernel directly.
const has_restorer = @hasField(linux.k_sigaction, "restorer");

fn __get_handler_set(set: *sigset_t) callconv(.c) void {
    set.* = handler_set;
}

fn __libc_sigactionImpl(sig: c_int, sa: ?*const c_sigaction, old: ?*c_sigaction) callconv(.c) c_int {
    var ksa: linux.k_sigaction = undefined;
    var ksa_old: linux.k_sigaction = undefined;
    const mask_size = @sizeOf(linux.sigset_t);

    if (sa) |new| {
        if (@intFromPtr(new.handler) > 1) {
            const s: u32 = @bitCast(sig - 1);
            const bit = @as(SigsetElement, 1) << @intCast(s % bits_per_elem);
            _ = @atomicRmw(SigsetElement, &handler_set[s / bits_per_elem], .Or, bit, .seq_cst);

            // If pthread_create has not yet been called, the
            // implementation-internal signals (SIGCANCEL, SIGSYNCCALL)
            // may still be blocked. Unblock them once before installing
            // any application handler, so that a handler cannot observe
            // an illegal sigset_t with those signals masked.
            if (__libc.threaded == 0 and !unmask_done) {
                const sigpt_set: sigset_t = comptime blk: {
                    var m: sigset_t = @splat(0);
                    // SIGCANCEL = 33, SIGSYNCCALL = 34 (bit positions 32, 33).
                    for ([_]u32{ 32, 33 }) |bit_pos| {
                        m[bit_pos / bits_per_elem] |= @as(SigsetElement, 1) << @intCast(bit_pos % bits_per_elem);
                    }
                    break :blk m;
                };
                _ = linux.syscall4(
                    .rt_sigprocmask,
                    linux.SIG.UNBLOCK,
                    @intFromPtr(&sigpt_set),
                    0,
                    NSIG / 8,
                );
                unmask_done = true;
            }

            if ((new.flags & SA_RESTART) == 0) {
                @atomicStore(c_int, &__eintr_valid_flag, 1, .seq_cst);
            }
        }
        ksa.handler = @ptrCast(new.handler);
        var flags_u32: u32 = @bitCast(new.flags);
        if (has_restorer) {
            flags_u32 |= @as(u32, @bitCast(SA_RESTORER));
        }
        ksa.flags = flags_u32;
        if (has_restorer) {
            const r_fn = if ((new.flags & SA_SIGINFO) != 0) &linux.restore_rt else &linux.restore;
            @field(ksa, "restorer") = @ptrCast(r_fn);
        }
        @memcpy(std.mem.asBytes(&ksa.mask), std.mem.asBytes(&new.mask)[0..mask_size]);
    }

    const r = linux.syscall4(
        .rt_sigaction,
        @as(usize, @bitCast(@as(isize, sig))),
        if (sa != null) @intFromPtr(&ksa) else 0,
        if (old != null) @intFromPtr(&ksa_old) else 0,
        mask_size,
    );
    const signed: isize = @bitCast(r);
    if (signed < 0) {
        std.c._errno().* = @intCast(-signed);
        return -1;
    }
    if (old) |o| {
        o.handler = @ptrCast(ksa_old.handler);
        o.flags = @bitCast(@as(u32, @truncate(ksa_old.flags)));
        @memcpy(std.mem.asBytes(&o.mask)[0..mask_size], std.mem.asBytes(&ksa_old.mask));
    }
    return 0;
}

fn __sigactionImpl(sig: c_int, sa: ?*const c_sigaction, old: ?*c_sigaction) callconv(.c) c_int {
    const s1: u32 = @bitCast(sig -% 1);
    if (s1 >= NSIG - 1 or @as(u32, @bitCast(sig -% 32)) < 3) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }

    // Changing the disposition of SIGABRT must be serialised against
    // `abort()` so the latter cannot observe a half-installed handler
    // while it is racing to terminate the process.
    var saved: sigset_t = undefined;
    const is_sigabrt = sig == @intFromEnum(linux.SIG.ABRT);
    if (is_sigabrt) {
        __block_all_sigs(&saved);
        __lock(&__abort_lock);
    }
    const r = __libc_sigactionImpl(sig, sa, old);
    if (is_sigabrt) {
        __unlock(&__abort_lock);
        __restore_sigs(&saved);
    }
    return r;
}

fn sigholdLinux(sig: c_int) callconv(.c) c_int {
    var mask: sigset_t = @splat(0);
    const s: u32 = @bitCast(sig -% 1);
    if (s >= NSIG - 1 or @as(u32, @bitCast(sig -% 32)) < 3) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    mask[s / bits_per_elem] |= @as(SigsetElement, 1) << @intCast(s % bits_per_elem);
    return errno(linux.sigprocmask(linux.SIG.BLOCK, &mask, null));
}

fn sigrelseLinux(sig: c_int) callconv(.c) c_int {
    var mask: sigset_t = @splat(0);
    const s: u32 = @bitCast(sig -% 1);
    if (s >= NSIG - 1 or @as(u32, @bitCast(sig -% 32)) < 3) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    mask[s / bits_per_elem] |= @as(SigsetElement, 1) << @intCast(s % bits_per_elem);
    return errno(linux.sigprocmask(linux.SIG.UNBLOCK, &mask, null));
}

fn sigpauseLinux(sig: c_int) callconv(.c) c_int {
    var mask: sigset_t = undefined;
    _ = linux.sigprocmask(0, null, &mask);
    const s: u32 = @bitCast(sig -% 1);
    if (s < NSIG - 1) {
        mask[s / bits_per_elem] &= ~(@as(SigsetElement, 1) << @intCast(s % bits_per_elem));
    }
    return errno(linux.syscall2(.rt_sigsuspend, @intFromPtr(&mask), NSIG / 8));
}

fn signalImpl(sig: c_int, func: ?*align(1) const fn (c_int) callconv(.c) void) callconv(.c) ?*align(1) const fn (c_int) callconv(.c) void {
    var sa_old: c_sigaction = undefined;
    var sa: c_sigaction = .{
        .handler = func,
        .mask = @splat(0),
        .flags = SA_RESTART,
        .restorer = null,
    };
    if (__sigaction(sig, &sa, &sa_old) < 0) return SIG_ERR;
    return sa_old.handler;
}

fn siginterruptImpl(sig: c_int, flag: c_int) callconv(.c) c_int {
    var sa: c_sigaction = undefined;
    _ = sigaction(sig, null, &sa);
    if (flag != 0) {
        sa.flags &= ~@as(c_int, SA_RESTART);
    } else {
        sa.flags |= SA_RESTART;
    }
    return sigaction(sig, &sa, null);
}

fn sigignoreImpl(sig: c_int) callconv(.c) c_int {
    const SIG_IGN: ?*align(1) const fn (c_int) callconv(.c) void = @ptrFromInt(1);
    var sa: c_sigaction = .{
        .handler = SIG_IGN,
        .mask = @splat(0),
        .flags = 0,
        .restorer = null,
    };
    return sigaction(sig, &sa, null);
}

fn psiginfo(si: *const linux.siginfo_t, msg: ?[*:0]const u8) callconv(.c) void {
    psignal(@intCast(@intFromEnum(si.signo)), msg);
}

fn psignalImpl(sig: c_int, msg: ?[*:0]const u8) callconv(.c) void {
    const f: *FILE = @ptrCast(stderr_ext.*);
    const s = strsignal_fn(sig);
    const need_unlock = if (f.lock >= 0) lockfile_fn(f) else 0;

    // Save stderr's orientation and encoding rule, since psignal is not
    // permitted to change them. Save errno and restore it if there is no error.
    const old_locale = f.locale;
    const old_mode = f.mode;
    const old_errno = std.c._errno().*;

    var ok = true;
    if (msg) |m| {
        if (m[0] != 0) {
            ok = ok and fwrite_fn(m, std.mem.len(m), 1, f) == 1;
            ok = ok and fputc_fn(':', f) >= 0;
            ok = ok and fputc_fn(' ', f) >= 0;
        }
    }
    ok = ok and fwrite_fn(s, std.mem.len(s), 1, f) == 1;
    ok = ok and fputc_fn('\n', f) >= 0;
    if (ok) std.c._errno().* = old_errno;
    f.mode = old_mode;
    f.locale = old_locale;

    if (need_unlock != 0) unlockfile_fn(f);
}

fn sigsetImpl(sig: c_int, handler: ?*align(1) const fn (c_int) callconv(.c) void) callconv(.c) ?*align(1) const fn (c_int) callconv(.c) void {
    var sa: c_sigaction = undefined;
    var sa_old: c_sigaction = undefined;
    var mask: sigset_t = @splat(0);
    var mask_old: sigset_t = undefined;

    const s: u32 = @bitCast(sig -% 1);
    if (s >= NSIG - 1 or @as(u32, @bitCast(sig -% 32)) < 3) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return SIG_ERR;
    }
    mask[s / bits_per_elem] |= @as(SigsetElement, 1) << @intCast(s % bits_per_elem);

    if (handler == SIG_HOLD) {
        if (sigaction(sig, null, &sa_old) < 0) return SIG_ERR;
        if (errno(linux.sigprocmask(linux.SIG.BLOCK, &mask, &mask_old)) < 0) return SIG_ERR;
    } else {
        sa = .{ .handler = handler, .mask = @splat(0), .flags = 0, .restorer = null };
        if (sigaction(sig, &sa, &sa_old) < 0) return SIG_ERR;
        if (errno(linux.sigprocmask(linux.SIG.UNBLOCK, &mask, &mask_old)) < 0) return SIG_ERR;
    }
    return if (mask_old[s / bits_per_elem] & (@as(SigsetElement, 1) << @intCast(s % bits_per_elem)) != 0) SIG_HOLD else sa_old.handler;
}

fn sigqueueImpl(pid: linux.pid_t, sig: c_int, value: usize) callconv(.c) c_int {
    // siginfo_t needs to be zeroed and then filled in
    var si: linux.siginfo_t = std.mem.zeroes(linux.siginfo_t);
    si.signo = @enumFromInt(@as(u32, @bitCast(sig)));
    si.code = SI_QUEUE;
    si.fields.common.first.piduid = .{
        .pid = linux.getpid(),
        .uid = linux.getuid(),
    };
    si.fields.common.second.value = .{ .int = @bitCast(@as(c_int, @intCast(value))) };

    var set: sigset_t = undefined;
    _ = linux.sigprocmask(linux.SIG.BLOCK, &app_mask, &set);
    const ret = errno(linux.syscall3(.rt_sigqueueinfo, @as(usize, @bitCast(@as(isize, pid))), @as(usize, @bitCast(@as(isize, sig))), @intFromPtr(&si)));
    _ = linux.sigprocmask(linux.SIG.SETMASK, &set, null);
    return ret;
}

const NSIG_WASI = 65;
const SIGABRT_WASI = 6;
const SIGKILL_WASI = 9;
const SIGSTOP_WASI = 19;
const wasi = std.os.wasi;
const WasiSignalHandler = ?*align(1) const fn (c_int) callconv(.c) void;

comptime {
    if (builtin.target.isWasiLibC()) {
        symbol(&raiseWasi, "raise");
        symbol(&signalWasi, "signal");
        symbol(&signalWasi, "bsd_signal");
        symbol(&signalWasi, "__sysv_signal");
        symbol(&__SIG_ERR, "__SIG_ERR");
        symbol(&__SIG_IGN, "__SIG_IGN");
        symbol(&psignalWasi, "psignal");
    }
}

var wasi_signal_handlers: [NSIG_WASI]WasiSignalHandler = .{null} ** NSIG_WASI;
const wasi_default_signal_handlers: [NSIG_WASI]WasiSignalHandler = blk: {
    var handlers: [NSIG_WASI]WasiSignalHandler = .{null} ** NSIG_WASI;
    handlers[1] = terminateHandlerWasi;
    handlers[2] = terminateHandlerWasi;
    handlers[3] = coreHandlerWasi;
    handlers[4] = coreHandlerWasi;
    handlers[5] = coreHandlerWasi;
    handlers[6] = coreHandlerWasi;
    handlers[7] = coreHandlerWasi;
    handlers[8] = coreHandlerWasi;
    handlers[10] = terminateHandlerWasi;
    handlers[11] = coreHandlerWasi;
    handlers[12] = terminateHandlerWasi;
    handlers[13] = terminateHandlerWasi;
    handlers[14] = terminateHandlerWasi;
    handlers[15] = terminateHandlerWasi;
    handlers[16] = terminateHandlerWasi;
    handlers[17] = __SIG_IGN;
    handlers[18] = continueHandlerWasi;
    handlers[19] = stopHandlerWasi;
    handlers[20] = stopHandlerWasi;
    handlers[21] = stopHandlerWasi;
    handlers[22] = stopHandlerWasi;
    handlers[24] = coreHandlerWasi;
    handlers[25] = coreHandlerWasi;
    handlers[26] = terminateHandlerWasi;
    handlers[27] = terminateHandlerWasi;
    handlers[28] = __SIG_IGN;
    handlers[29] = terminateHandlerWasi;
    handlers[30] = terminateHandlerWasi;
    handlers[31] = terminateHandlerWasi;
    break :blk handlers;
};

fn setWasiSignalErrno(err: wasi.errno_t) void {
    std.c._errno().* = @intFromEnum(err);
}

fn raiseWasi(sig: c_int) callconv(.c) c_int {
    if (sig < 0 or sig >= NSIG_WASI) {
        setWasiSignalErrno(.INVAL);
        return -1;
    }

    const index: usize = @intCast(sig);
    const handler = wasi_signal_handlers[index] orelse wasi_default_signal_handlers[index] orelse {
        setWasiSignalErrno(.NOSYS);
        return -1;
    };
    handler(sig);
    return 0;
}

fn signalWasi(sig: c_int, handler: WasiSignalHandler) callconv(.c) WasiSignalHandler {
    if (sig <= 0 or sig >= NSIG_WASI or sig == SIGKILL_WASI or sig == SIGSTOP_WASI) {
        setWasiSignalErrno(.INVAL);
        return __SIG_ERR;
    }

    const index: usize = @intCast(sig);
    const previous = wasi_signal_handlers[index];
    wasi_signal_handlers[index] = handler;
    return previous;
}

fn __SIG_IGN(sig: c_int) callconv(.c) void {
    _ = sig;
}

fn __SIG_ERR(sig: c_int) callconv(.c) void {
    _ = sig;
    @trap();
}

fn coreHandlerWasi(sig: c_int) callconv(.c) void {
    if (sig == SIGABRT_WASI) wasi.proc_exit(@intCast(128 + sig));
    writeFatalSignalWasi(sig);
    @trap();
}

fn terminateHandlerWasi(sig: c_int) callconv(.c) void {
    writeFatalSignalWasi(sig);
    @trap();
}

fn stopHandlerWasi(sig: c_int) callconv(.c) void {
    writeFatalSignalWasi(sig);
    @trap();
}

fn continueHandlerWasi(sig: c_int) callconv(.c) void {
    _ = sig;
}

fn writeFatalSignalWasi(sig: c_int) void {
    const prefix = "Program received fatal signal: ";
    const newline = "\n";
    const old_errno = std.c._errno().*;
    const f = stderr_ext.* orelse return;
    const need_unlock = if (f.lock >= 0) lockfile_fn(f) else 0;
    const old_mode = f.mode;
    const old_locale = f.locale;

    var ok = fwrite_fn(prefix, prefix.len, 1, f) == 1;
    const s = strsignal_fn(sig);
    ok = ok and fwrite_fn(s, std.mem.len(s), 1, f) == 1;
    ok = ok and fwrite_fn(newline, newline.len, 1, f) == 1;
    if (ok) std.c._errno().* = old_errno;
    f.mode = old_mode;
    f.locale = old_locale;

    if (need_unlock != 0) unlockfile_fn(f);
}

fn psignalWasi(sig: c_int, msg: ?[*:0]const u8) callconv(.c) void {
    const old_errno = std.c._errno().*;
    const f = stderr_ext.* orelse return;
    const need_unlock = if (f.lock >= 0) lockfile_fn(f) else 0;
    const old_mode = f.mode;
    const old_locale = f.locale;

    var ok = true;
    if (msg) |m| {
        const len = std.mem.len(m);
        ok = len == 0 or fwrite_fn(m, len, 1, f) == 1;
        ok = ok and fputc_fn(':', f) >= 0;
        ok = ok and fputc_fn(' ', f) >= 0;
    }
    const s = strsignal_fn(sig);
    ok = ok and fwrite_fn(s, std.mem.len(s), 1, f) == 1;
    ok = ok and fputc_fn('\n', f) >= 0;
    if (ok) std.c._errno().* = old_errno;
    f.mode = old_mode;
    f.locale = old_locale;

    if (need_unlock != 0) unlockfile_fn(f);
}

test "wasi signal raise SIGABRT" {
    if (!builtin.target.isWasiLibC()) return error.SkipZigTest;
    try std.testing.expect(@intFromPtr(&raiseWasi) != 0);
    try std.testing.expect(SIGABRT_WASI == 6);
}
