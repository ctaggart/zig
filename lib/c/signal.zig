const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
const symbol = @import("../c.zig").symbol;
const NSIG = linux.NSIG;
const sigset_t = linux.sigset_t;
const SigsetElement = @typeInfo(sigset_t).array.child;
const bits_per_elem = @bitSizeOf(SigsetElement);
const errno = @import("../c.zig").errno;
const has_restorer = @hasDecl(linux.SA, "RESTORER");
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
const k_sigset_t = linux.sigset_t;
const k_sigaction = linux.k_sigaction;
const handler_set_len = NSIG / (8 * @sizeOf(c_ulong));
var unmask_done: c_int = 0;
var handler_set: [handler_set_len]c_ulong = @splat(0);
var __eintr_valid_flag: c_int = 0;

const Libc = extern struct {
    can_do_threads: u8,
    threaded: u8,
    secure: u8,
    need_locks: i8,
    threads_minus_1: c_int,
    auxv: ?[*]usize,
    tls_head: ?*anyopaque,
    tls_size: usize,
    tls_align: usize,
    tls_cnt: usize,
    page_size: usize,
    global_locale: [6]?*anyopaque,
};
extern var __libc: Libc;
extern fn __restore() callconv(.c) void;
extern fn __restore_rt() callconv(.c) void;
extern fn __lock(lock: *c_int) callconv(.c) void;
extern fn __unlock(lock: *c_int) callconv(.c) void;
extern var __abort_lock: c_int;
const SA_RESTART = 0x10000000;
extern "c" fn psignal(sig: c_int, msg: ?[*:0]const u8) callconv(.c) void;
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
        symbol(&__get_handler_set, "__get_handler_set");
        symbol(&__libc_sigaction, "__libc_sigaction");
        symbol(&__sigaction, "__sigaction");
        symbol(&__sigaction, "sigaction");
        @export(&__eintr_valid_flag, .{ .name = "__eintr_valid_flag" });
        symbol(&__block_all_sigs, "__block_all_sigs");
        symbol(&__block_app_sigs, "__block_app_sigs");
        symbol(&__restore_sigs, "__restore_sigs");
        symbol(&sigholdLinux, "sighold");
        symbol(&sigrelseLinux, "sigrelse");
        symbol(&sigpauseLinux, "sigpause");
    }
    if (builtin.link_libc and builtin.os.tag == .linux) {
        symbol(&signalImpl, "signal");
        symbol(&siginterruptImpl, "siginterrupt");
        symbol(&sigignoreImpl, "sigignore");
        symbol(&psiginfo, "psiginfo");
        symbol(&sigsetImpl, "sigset");
        symbol(&sigqueueImpl, "sigqueue");
    }
}

fn sigsetSizeBytes(comptime T: type) usize {
    return if (@bitSizeOf(@typeInfo(T).array.child) == 8) @sizeOf(T) else NSIG / 8;
}

fn copyToKernelSigset(dst: *k_sigset_t, src: *const [128 / @sizeOf(c_ulong)]c_ulong) void {
    @memset(std.mem.asBytes(dst), 0);
    @memcpy(std.mem.asBytes(dst)[0..sigsetSizeBytes(k_sigset_t)], std.mem.sliceAsBytes(src)[0..sigsetSizeBytes(k_sigset_t)]);
}

fn copyFromKernelSigset(dst: *[128 / @sizeOf(c_ulong)]c_ulong, src: *const k_sigset_t) void {
    @memset(std.mem.sliceAsBytes(dst), 0);
    @memcpy(std.mem.sliceAsBytes(dst)[0..sigsetSizeBytes(k_sigset_t)], std.mem.asBytes(src)[0..sigsetSizeBytes(k_sigset_t)]);
}

fn sigactionSigValid(sig: c_int) bool {
    return @as(u32, @bitCast(sig -% 32)) >= 3 and @as(u32, @bitCast(sig -% 1)) < NSIG - 1;
}

fn __get_handler_set(set: *sigset_t) callconv(.c) void {
    @memcpy(std.mem.asBytes(set)[0..@sizeOf(@TypeOf(handler_set))], std.mem.asBytes(&handler_set));
}

fn __libc_sigaction(sig: c_int, noalias sa: ?*const c_sigaction, noalias old: ?*c_sigaction) callconv(.c) c_int {
    var ksa: k_sigaction = undefined;
    var ksa_old: k_sigaction = undefined;

    if (sa) |act| {
        if (@intFromPtr(act.handler) > 1) {
            const s: u32 = @intCast(sig - 1);
            _ = @atomicRmw(c_ulong, &handler_set[s / (8 * @sizeOf(c_ulong))], .Or, @as(c_ulong, 1) << @intCast(s % (8 * @sizeOf(c_ulong))), .seq_cst);

            // If pthread_create has not yet been called, implementation-internal
            // signals might not yet have been unblocked. They must be unblocked
            // before any signal handler is installed.
            if (__libc.threaded == 0 and unmask_done == 0) {
                _ = linux.syscall4(.rt_sigprocmask, linux.SIG.UNBLOCK, @intFromPtr(&app_mask), 0, NSIG / 8);
                unmask_done = 1;
            }

            if (act.flags & linux.SA.RESTART == 0) {
                @atomicStore(c_int, &__eintr_valid_flag, 1, .seq_cst);
            }
        }

        if (comptime @hasField(k_sigaction, "restorer")) {
            ksa = .{
                .handler = act.handler,
                .flags = @as(c_ulong, @intCast(act.flags)) | linux.SA.RESTORER,
                .restorer = if (act.flags & linux.SA.SIGINFO != 0) &__restore_rt else &__restore,
                .mask = undefined,
            };
        } else if (comptime @hasField(k_sigaction, "unused")) {
            ksa = .{
                .flags = @intCast(act.flags),
                .handler = act.handler,
                .mask = undefined,
                .unused = null,
            };
        } else if (comptime @typeInfo(k_sigaction).@"struct".fields[0].name[0] == 'f') {
            ksa = .{
                .flags = @intCast(act.flags),
                .handler = act.handler,
                .mask = undefined,
            };
        } else {
            ksa = .{
                .handler = act.handler,
                .flags = @intCast(act.flags),
                .mask = undefined,
            };
        }
        copyToKernelSigset(&ksa.mask, &act.mask);
    }

    const rc = if (builtin.cpu.arch == .sparc or builtin.cpu.arch == .sparc64)
        linux.syscall5(.rt_sigaction, @as(usize, @bitCast(@as(isize, sig))), if (sa != null) @intFromPtr(&ksa) else 0, if (old != null) @intFromPtr(&ksa_old) else 0, if (sa != null and @hasField(k_sigaction, "restorer")) @intFromPtr(ksa.restorer) else 0, NSIG / 8)
    else
        linux.syscall4(.rt_sigaction, @as(usize, @bitCast(@as(isize, sig))), if (sa != null) @intFromPtr(&ksa) else 0, if (old != null) @intFromPtr(&ksa_old) else 0, NSIG / 8);

    if (old) |oldact| {
        if (rc == 0) {
            oldact.handler = ksa_old.handler;
            oldact.flags = @intCast(ksa_old.flags);
            copyFromKernelSigset(&oldact.mask, &ksa_old.mask);
        }
    }
    return errno(rc);
}

fn __sigaction(sig: c_int, noalias sa: ?*const c_sigaction, noalias old: ?*c_sigaction) callconv(.c) c_int {
    if (!sigactionSigValid(sig)) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }

    if (sig == @intFromEnum(linux.SIG.ABRT)) {
        var set: sigset_t = undefined;
        __block_all_sigs(&set);
        __lock(&__abort_lock);
        const rc = __libc___sigaction(sig, sa, old);
        __unlock(&__abort_lock);
        __restore_sigs(&set);
        return rc;
    }

    return __libc___sigaction(sig, sa, old);
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
        if (s.flags & linux.SS.DISABLE == 0 and s.size < linux.MINSIGSTKSZ) {
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
    if (____sigaction(sig, &sa, &sa_old) < 0) return SIG_ERR;
    return sa_old.handler;
}

fn siginterruptImpl(sig: c_int, flag: c_int) callconv(.c) c_int {
    var sa: c_sigaction = undefined;
    _ = __sigaction(sig, null, &sa);
    if (flag != 0) {
        sa.flags &= ~@as(c_int, SA_RESTART);
    } else {
        sa.flags |= SA_RESTART;
    }
    return __sigaction(sig, &sa, null);
}

fn sigignoreImpl(sig: c_int) callconv(.c) c_int {
    const SIG_IGN: ?*align(1) const fn (c_int) callconv(.c) void = @ptrFromInt(1);
    var sa: c_sigaction = .{
        .handler = SIG_IGN,
        .mask = @splat(0),
        .flags = 0,
        .restorer = null,
    };
    return __sigaction(sig, &sa, null);
}

fn psiginfo(si: *const linux.siginfo_t, msg: ?[*:0]const u8) callconv(.c) void {
    psignal(@intCast(@intFromEnum(si.signo)), msg);
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
        if (__sigaction(sig, null, &sa_old) < 0) return SIG_ERR;
        if (errno(linux.sigprocmask(linux.SIG.BLOCK, &mask, &mask_old)) < 0) return SIG_ERR;
    } else {
        sa = .{ .handler = handler, .mask = @splat(0), .flags = 0, .restorer = null };
        if (__sigaction(sig, &sa, &sa_old) < 0) return SIG_ERR;
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
