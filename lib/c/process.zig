const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;
const NSIG = linux.NSIG;
const sigset_t = linux.sigset_t;
const SigsetElement = @typeInfo(sigset_t).array.child;
const bits_per_elem = @bitSizeOf(SigsetElement);
// app_mask: all signals set except internal signals 32, 33, 34
const app_mask = blk: {
    var mask: sigset_t = undefined;
    for (&mask) |*elem| elem.* = ~@as(SigsetElement, 0);
    for (.{ 31, 32, 33 }) |s| {
        mask[s / bits_per_elem] &= ~(@as(SigsetElement, 1) << @intCast(s % bits_per_elem));
    }
    break :blk mask;
};
const itimerval = extern struct {
    it_interval: linux.timeval,
    it_value: linux.timeval,
};
const musl_sigset_t = [128 / @sizeOf(c_ulong)]c_ulong;
const posix_spawnattr_t = extern struct {
    __flags: c_int,
    __pgrp: linux.pid_t,
    __def: musl_sigset_t,
    __mask: musl_sigset_t,
    __prio: c_int,
    __pol: c_int,
    __fn: ?*anyopaque,
    __pad: [64 - @sizeOf(?*anyopaque)]u8,
};
const posix_spawn_file_actions_t = extern struct {
    __pad0: [2]c_int,
    __actions: ?*anyopaque,
    __pad: [16]c_int,
};
const FDOP_CLOSE = 1;
const FDOP_DUP2 = 2;
const FDOP_OPEN = 3;
const FDOP_CHDIR = 4;
const FDOP_FCHDIR = 5;
const fdop = extern struct {
    next: ?*fdop,
    prev: ?*fdop,
    cmd: c_int,
    fd: c_int,
    srcfd: c_int,
    oflag: c_int,
    mode: linux.mode_t,
    // flexible array member follows; for alloc sizing only
};
extern "c" fn malloc(size: usize) callconv(.c) ?[*]u8;
extern "c" fn free(ptr: ?*anyopaque) callconv(.c) void;
extern "c" fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) callconv(.c) c_int;
extern "c" var __environ: [*:null]?[*:0]u8;
extern "c" fn getenv(name: [*:0]const u8) callconv(.c) ?[*:0]const u8;
const NAME_MAX = 255;
const PATH_MAX = 4096;
extern "c" fn execvp(file: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) callconv(.c) c_int;
const MAX_ARGS = 256;
const c_sigaction = extern struct {
    handler: ?*align(1) const fn (c_int) callconv(.c) void,
    mask: musl_sigset_t,
    flags: c_int,
    restorer: ?*const fn () callconv(.c) void,
};
const SIG_DFL: ?*align(1) const fn (c_int) callconv(.c) void = @ptrFromInt(0);
const SIG_IGN: ?*align(1) const fn (c_int) callconv(.c) void = @ptrFromInt(1);
extern "c" fn sigaction(sig: c_int, act: ?*const c_sigaction, oact: ?*c_sigaction) callconv(.c) c_int;
extern "c" fn sigprocmask(how: c_int, set: ?*const musl_sigset_t, oset: ?*musl_sigset_t) callconv(.c) c_int;
extern "c" fn sigemptyset(set: *musl_sigset_t) callconv(.c) c_int;
extern "c" fn sigaddset(set: *musl_sigset_t, sig: c_int) callconv(.c) c_int;
extern "c" fn posix_spawnattr_destroy(attr: *posix_spawnattr_t) callconv(.c) c_int;
extern "c" fn waitpid(pid: linux.pid_t, status: ?*c_int, options: c_int) callconv(.c) linux.pid_t;
extern "c" fn pthread_testcancel() callconv(.c) void;
extern "c" fn pthread_setcancelstate(state: c_int, oldstate: ?*c_int) callconv(.c) c_int;
extern "c" fn pthread_sigmask(how: c_int, set: ?*const musl_sigset_t, oldset: ?*musl_sigset_t) callconv(.c) c_int;
extern "c" fn __get_handler_set(set: *musl_sigset_t) callconv(.c) void;
extern "c" fn __libc_sigaction(sig: c_int, act: ?*const c_sigaction, oact: ?*c_sigaction) callconv(.c) c_int;
extern "c" fn __lock(lock: *c_int) callconv(.c) void;
extern "c" fn __unlock(lock: *c_int) callconv(.c) void;
extern "c" var __abort_lock: c_int;
const POSIX_SPAWN_RESETIDS: c_int = 0x1;
const POSIX_SPAWN_SETPGROUP: c_int = 0x2;
const POSIX_SPAWN_SETSIGDEF: c_int = 0x4;
const POSIX_SPAWN_SETSIGMASK: c_int = 0x8;
const POSIX_SPAWN_SETSID: c_int = 0x80;
const PTHREAD_CANCEL_DISABLE = 1;
const SIGINT = 2;
const SIGQUIT = 3;
const SIGCHLD = 17;
const SIG_BLOCK = 0;
const SIG_SETMASK = 2;
const O_CLOEXEC: u32 = 0o2000000;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&raiseLinux, "raise");
        symbol(&waitLinux, "wait");
        symbol(&waitpidLinux, "waitpid");
        symbol(&waitidLinux, "waitid");
        symbol(&__restore, "__restore");
        symbol(&__restore_rt, "__restore_rt");
        symbol(&getitimerLinux, "getitimer");
        symbol(&setitimerLinux, "setitimer");
        symbol(&vforkLinux, "vfork");
        symbol(&posix_spawnattr_init, "posix_spawnattr_init");
        symbol(&posix_spawnattr_getflags, "posix_spawnattr_getflags");
        symbol(&posix_spawnattr_setflags, "posix_spawnattr_setflags");
        symbol(&posix_spawnattr_getpgroup, "posix_spawnattr_getpgroup");
        symbol(&posix_spawnattr_setpgroup, "posix_spawnattr_setpgroup");
        symbol(&posix_spawnattr_getsigdefault, "posix_spawnattr_getsigdefault");
        symbol(&posix_spawnattr_setsigdefault, "posix_spawnattr_setsigdefault");
        symbol(&posix_spawnattr_getsigmask, "posix_spawnattr_getsigmask");
        symbol(&posix_spawnattr_setsigmask, "posix_spawnattr_setsigmask");
        symbol(&posix_spawn_file_actions_init, "posix_spawn_file_actions_init");
    }
    if (builtin.link_libc) {
        symbol(&execvImpl, "execv");
        symbol(&posix_spawn_file_actions_addclose_impl, "posix_spawn_file_actions_addclose");
        symbol(&posix_spawn_file_actions_adddup2_impl, "posix_spawn_file_actions_adddup2");
        symbol(&posix_spawn_file_actions_addopen_impl, "posix_spawn_file_actions_addopen");
        symbol(&posix_spawn_file_actions_addchdir_impl, "posix_spawn_file_actions_addchdir_np");
        symbol(&posix_spawn_file_actions_addfchdir_impl, "posix_spawn_file_actions_addfchdir_np");
        symbol(&posix_spawn_file_actions_destroy_impl, "posix_spawn_file_actions_destroy");
        symbol(&posix_spawnImpl, "posix_spawn");
        symbol(&posix_spawnpImpl, "posix_spawnp");
        symbol(&__execvpe, "__execvpe");
        symbol(&execvpImpl, "execvp");
        symbol(&execlImpl, "execl");
        symbol(&execleImpl, "execle");
        symbol(&execlpImpl, "execlp");
        symbol(&systemImpl, "system");
    }
}

fn raiseLinux(sig: c_int) callconv(.c) c_int {
    var set: sigset_t = undefined;
    _ = linux.sigprocmask(linux.SIG.BLOCK, &app_mask, &set);
    const ret = errno(linux.tkill(linux.gettid(), @enumFromInt(@as(u32, @bitCast(sig)))));
    _ = linux.sigprocmask(linux.SIG.SETMASK, &set, null);
    return ret;
}

fn errnoP(r: usize) linux.pid_t {
    const signed: isize = @bitCast(r);
    if (signed < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-signed);
        return -1;
    }
    return @intCast(signed);
}

fn waitLinux(status: ?*c_int) callconv(.c) linux.pid_t {
    return waitpidLinux(-1, status, 0);
}

fn waitpidLinux(pid: linux.pid_t, status: ?*c_int, options: c_int) callconv(.c) linux.pid_t {
    return errnoP(linux.syscall4(
        .wait4,
        @as(usize, @bitCast(@as(isize, pid))),
        @intFromPtr(status),
        @as(usize, @bitCast(@as(isize, options))),
        0,
    ));
}

fn waitidLinux(idtype: c_uint, id: c_uint, info: ?*linux.siginfo_t, options: c_int) callconv(.c) c_int {
    return errno(linux.syscall5(
        .waitid,
        @as(usize, idtype),
        @as(usize, id),
        @intFromPtr(info),
        @as(usize, @bitCast(@as(isize, options))),
        0,
    ));
}

// Fallback signal restorer stubs. Architecture-specific .s files provide
// real implementations where the kernel sigaction struct uses sa_restorer.
fn __restore() callconv(.c) void {}

fn __restore_rt() callconv(.c) void {}

fn getitimerLinux(which: c_int, old: *itimerval) callconv(.c) c_int {
    return errno(linux.syscall2(.getitimer, @as(usize, @bitCast(@as(isize, which))), @intFromPtr(old)));
}

fn setitimerLinux(which: c_int, new: *const itimerval, old: ?*itimerval) callconv(.c) c_int {
    return errno(linux.syscall3(.setitimer, @as(usize, @bitCast(@as(isize, which))), @intFromPtr(new), @intFromPtr(old)));
}

fn vforkLinux() callconv(.c) linux.pid_t {
    // Fallback: vfork cannot be correctly implemented in C/Zig.
    // Architecture-specific .s files provide real vfork where available.
    const r: isize = @bitCast(linux.fork());
    if (r < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-r);
        return -1;
    }
    return @intCast(r);
}

fn posix_spawnattr_init(attr: *posix_spawnattr_t) callconv(.c) c_int {
    @memset(std.mem.asBytes(attr), 0);
    return 0;
}

fn posix_spawnattr_getflags(attr: *const posix_spawnattr_t, flags: *c_short) callconv(.c) c_int {
    flags.* = @intCast(attr.__flags);
    return 0;
}

fn posix_spawnattr_setflags(attr: *posix_spawnattr_t, flags: c_short) callconv(.c) c_int {
    const all_flags: c_uint = 0x1 | 0x2 | 0x4 | 0x8 | 0x10 | 0x20 | 0x40 | 0x80;
    if (@as(c_uint, @bitCast(@as(c_int, flags))) & ~all_flags != 0)
        return @intFromEnum(linux.E.INVAL);
    attr.__flags = flags;
    return 0;
}

fn posix_spawnattr_getpgroup(attr: *const posix_spawnattr_t, pgrp: *linux.pid_t) callconv(.c) c_int {
    pgrp.* = attr.__pgrp;
    return 0;
}

fn posix_spawnattr_setpgroup(attr: *posix_spawnattr_t, pgrp: linux.pid_t) callconv(.c) c_int {
    attr.__pgrp = pgrp;
    return 0;
}

fn posix_spawnattr_getsigdefault(attr: *const posix_spawnattr_t, def: *musl_sigset_t) callconv(.c) c_int {
    def.* = attr.__def;
    return 0;
}

fn posix_spawnattr_setsigdefault(attr: *posix_spawnattr_t, def: *const musl_sigset_t) callconv(.c) c_int {
    attr.__def = def.*;
    return 0;
}

fn posix_spawnattr_getsigmask(attr: *const posix_spawnattr_t, mask: *musl_sigset_t) callconv(.c) c_int {
    mask.* = attr.__mask;
    return 0;
}

fn posix_spawnattr_setsigmask(attr: *posix_spawnattr_t, mask: *const musl_sigset_t) callconv(.c) c_int {
    attr.__mask = mask.*;
    return 0;
}

fn posix_spawn_file_actions_init(fa: *posix_spawn_file_actions_t) callconv(.c) c_int {
    fa.__actions = null;
    return 0;
}

fn execvImpl(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) callconv(.c) c_int {
    return execve(path, argv, @ptrCast(&__environ));
}

fn allocFdop(extra: usize) ?*fdop {
    const ptr = malloc(@sizeOf(fdop) + extra) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

fn prependOp(fa: *posix_spawn_file_actions_t, op: *fdop) void {
    op.next = @ptrCast(@alignCast(fa.__actions));
    if (@as(?*fdop, @ptrCast(@alignCast(fa.__actions)))) |existing| existing.prev = op;
    op.prev = null;
    fa.__actions = @ptrCast(op);
}

fn posix_spawn_file_actions_addclose_impl(fa: *posix_spawn_file_actions_t, fd: c_int) callconv(.c) c_int {
    if (fd < 0) return @intFromEnum(linux.E.BADF);
    const op = allocFdop(0) orelse return @intFromEnum(linux.E.NOMEM);
    op.cmd = FDOP_CLOSE;
    op.fd = fd;
    prependOp(fa, op);
    return 0;
}

fn posix_spawn_file_actions_adddup2_impl(fa: *posix_spawn_file_actions_t, srcfd: c_int, fd: c_int) callconv(.c) c_int {
    if (srcfd < 0 or fd < 0) return @intFromEnum(linux.E.BADF);
    const op = allocFdop(0) orelse return @intFromEnum(linux.E.NOMEM);
    op.cmd = FDOP_DUP2;
    op.srcfd = srcfd;
    op.fd = fd;
    prependOp(fa, op);
    return 0;
}

fn posix_spawn_file_actions_addopen_impl(fa: *posix_spawn_file_actions_t, fd: c_int, path: [*:0]const u8, flags: c_int, mode: linux.mode_t) callconv(.c) c_int {
    if (fd < 0) return @intFromEnum(linux.E.BADF);
    const pathlen = std.mem.len(path) + 1;
    const op = allocFdop(pathlen) orelse return @intFromEnum(linux.E.NOMEM);
    op.cmd = FDOP_OPEN;
    op.fd = fd;
    op.oflag = flags;
    op.mode = mode;
    const dest: [*]u8 = @as([*]u8, @ptrCast(op)) + @sizeOf(fdop);
    @memcpy(dest[0..pathlen], path[0..pathlen]);
    prependOp(fa, op);
    return 0;
}

fn posix_spawn_file_actions_addchdir_impl(fa: *posix_spawn_file_actions_t, path: [*:0]const u8) callconv(.c) c_int {
    const pathlen = std.mem.len(path) + 1;
    const op = allocFdop(pathlen) orelse return @intFromEnum(linux.E.NOMEM);
    op.cmd = FDOP_CHDIR;
    op.fd = -1;
    const dest: [*]u8 = @as([*]u8, @ptrCast(op)) + @sizeOf(fdop);
    @memcpy(dest[0..pathlen], path[0..pathlen]);
    prependOp(fa, op);
    return 0;
}

fn posix_spawn_file_actions_addfchdir_impl(fa: *posix_spawn_file_actions_t, fd: c_int) callconv(.c) c_int {
    if (fd < 0) return @intFromEnum(linux.E.BADF);
    const op = allocFdop(0) orelse return @intFromEnum(linux.E.NOMEM);
    op.cmd = FDOP_FCHDIR;
    op.fd = fd;
    prependOp(fa, op);
    return 0;
}

fn posix_spawn_file_actions_destroy_impl(fa: *posix_spawn_file_actions_t) callconv(.c) c_int {
    var op: ?*fdop = @ptrCast(@alignCast(fa.__actions));
    while (op) |o| {
        const next = o.next;
        free(@ptrCast(o));
        op = next;
    }
    return 0;
}

const SpawnArgs = extern struct {
    p: [2]c_int,
    oldmask: musl_sigset_t,
    path: [*:0]const u8,
    fa: ?*const posix_spawn_file_actions_t,
    attr: *const posix_spawnattr_t,
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
};

fn syscallResult(r: usize) isize {
    return @bitCast(r);
}

fn negErrno(e: linux.E) isize {
    return -@as(isize, @intFromEnum(e));
}

fn sigismemberZig(set: *const musl_sigset_t, sig: c_int) bool {
    const s: usize = @intCast(sig - 1);
    const bits = @bitSizeOf(c_ulong);
    return (set[s / bits] & (@as(c_ulong, 1) << @intCast(s % bits))) != 0;
}

fn fdopPath(op: *const fdop) [*:0]const u8 {
    return @ptrCast(@as([*]const u8, @ptrCast(op)) + @sizeOf(fdop));
}

fn openSys(path: [*:0]const u8, flags: c_int, mode: linux.mode_t) isize {
    var o: linux.O = @bitCast(@as(u32, @bitCast(flags)));
    o.LARGEFILE = true;
    return syscallResult(linux.open(path, o, mode));
}

fn spawnChild(arg: usize) callconv(.c) u8 {
    const args: *SpawnArgs = @ptrFromInt(arg);
    var p = args.p[1];
    const attr = args.attr;
    var ret: isize = 0;

    _ = linux.close(args.p[0]);

    var sa: c_sigaction = std.mem.zeroes(c_sigaction);
    var hset: musl_sigset_t = undefined;
    __get_handler_set(&hset);
    var i: c_int = 1;
    while (i < NSIG) : (i += 1) {
        if ((attr.__flags & POSIX_SPAWN_SETSIGDEF) != 0 and sigismemberZig(&attr.__def, i)) {
            sa.handler = SIG_DFL;
        } else if (sigismemberZig(&hset, i)) {
            if (@as(c_uint, @intCast(i - 32)) < 3) {
                sa.handler = SIG_IGN;
            } else {
                _ = __libc_sigaction(i, null, &sa);
                if (sa.handler == SIG_IGN) continue;
                sa.handler = SIG_DFL;
            }
        } else {
            continue;
        }
        _ = __libc_sigaction(i, &sa, null);
    }

    if ((attr.__flags & POSIX_SPAWN_SETSID) != 0) {
        ret = syscallResult(linux.syscall0(.setsid));
        if (ret < 0) gotoFail(p, ret);
    }

    if ((attr.__flags & POSIX_SPAWN_SETPGROUP) != 0) {
        ret = syscallResult(linux.setpgid(0, attr.__pgrp));
        if (ret < 0) gotoFail(p, ret);
    }

    if ((attr.__flags & POSIX_SPAWN_RESETIDS) != 0) {
        ret = syscallResult(linux.setgid(linux.getgid()));
        if (ret < 0) gotoFail(p, ret);
        ret = syscallResult(linux.setuid(linux.getuid()));
        if (ret < 0) gotoFail(p, ret);
    }

    if (args.fa) |fa| if (fa.__actions) |actions| {
        var op: *fdop = @ptrCast(@alignCast(actions));
        while (op.next) |next| op = next;
        while (true) {
            if (op.fd == p) {
                ret = syscallResult(linux.dup(p));
                if (ret < 0) gotoFail(p, ret);
                _ = linux.close(p);
                p = @intCast(ret);
            }
            switch (op.cmd) {
                FDOP_CLOSE => _ = linux.close(op.fd),
                FDOP_DUP2 => {
                    const fd = op.srcfd;
                    if (fd == p) gotoFail(p, negErrno(.BADF));
                    if (fd != op.fd) {
                        ret = syscallResult(linux.dup2(fd, op.fd));
                        if (ret < 0) gotoFail(p, ret);
                    } else {
                        ret = syscallResult(linux.fcntl(fd, linux.F.GETFD, 0));
                        ret = syscallResult(linux.fcntl(fd, linux.F.SETFD, @as(usize, @intCast(ret)) & ~@as(usize, linux.FD_CLOEXEC)));
                        if (ret < 0) gotoFail(p, ret);
                    }
                },
                FDOP_OPEN => {
                    ret = openSys(fdopPath(op), op.oflag, op.mode);
                    if (ret < 0) gotoFail(p, ret);
                    const fd: c_int = @intCast(ret);
                    if (fd != op.fd) {
                        ret = syscallResult(linux.dup2(fd, op.fd));
                        if (ret < 0) gotoFail(p, ret);
                        _ = linux.close(fd);
                    }
                },
                FDOP_CHDIR => {
                    ret = syscallResult(linux.chdir(fdopPath(op)));
                    if (ret < 0) gotoFail(p, ret);
                },
                FDOP_FCHDIR => {
                    ret = syscallResult(linux.fchdir(op.fd));
                    if (ret < 0) gotoFail(p, ret);
                },
                else => {},
            }
            if (op.prev) |prev| op = prev else break;
        }
    };

    _ = linux.fcntl(p, linux.F.SETFD, linux.FD_CLOEXEC);

    _ = pthread_sigmask(SIG_SETMASK, if ((attr.__flags & POSIX_SPAWN_SETSIGMASK) != 0) &attr.__mask else &args.oldmask, null);

    const exec_fn: *const fn ([*:0]const u8, [*:null]const ?[*:0]const u8, [*:null]const ?[*:0]const u8) callconv(.c) c_int = if (attr.__fn) |f| @ptrCast(@alignCast(f)) else execve;
    _ = exec_fn(args.path, args.argv, args.envp);
    gotoFail(p, -@as(isize, std.c._errno().*));
}

fn gotoFail(p: c_int, child_ret: isize) noreturn {
    var ret: c_int = @intCast(-child_ret);
    if (ret != 0) {
        while (true) {
            const r = syscallResult(linux.write(p, @ptrCast(&ret), @sizeOf(c_int)));
            if (!(r < 0 and r != negErrno(.PIPE))) break;
        }
    }
    linux.exit(127);
}

fn posix_spawnImpl(
    res: ?*linux.pid_t,
    path: [*:0]const u8,
    fa: ?*const posix_spawn_file_actions_t,
    attr_opt: ?*const posix_spawnattr_t,
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
) callconv(.c) c_int {
    var stack: [1024 + PATH_MAX]u8 align(16) = undefined;
    var ec: c_int = 0;
    var cs: c_int = undefined;
    var zero_attr: posix_spawnattr_t = std.mem.zeroes(posix_spawnattr_t);
    var args: SpawnArgs = undefined;

    _ = pthread_setcancelstate(PTHREAD_CANCEL_DISABLE, &cs);

    args.path = path;
    args.fa = fa;
    args.attr = attr_opt orelse &zero_attr;
    args.argv = argv;
    args.envp = envp;
    _ = pthread_sigmask(SIG_BLOCK, &@as(musl_sigset_t, @splat(~@as(c_ulong, 0))), &args.oldmask);

    __lock(&__abort_lock);
    var pipe_flags: linux.O = @bitCast(@as(u32, O_CLOEXEC));
    if (errno(linux.pipe2(&args.p, pipe_flags)) != 0) {
        __unlock(&__abort_lock);
        ec = std.c._errno().*;
        return spawnFail(&args.oldmask, cs, ec);
    }

    const flags: u32 = linux.CLONE.VM | linux.CLONE.VFORK | @intFromEnum(linux.SIG.CHLD);
    const pid_raw = linux.clone(spawnChild, @intFromPtr(&stack) + stack.len, flags, @intFromPtr(&args), null, 0, null);
    const pid_signed = syscallResult(pid_raw);
    _ = linux.close(args.p[1]);
    __unlock(&__abort_lock);

    if (pid_signed > 0) {
        const n = syscallResult(linux.read(args.p[0], @ptrCast(&ec), @sizeOf(c_int)));
        if (n != @sizeOf(c_int)) ec = 0 else {
            var status: c_int = 0;
            _ = waitpid(@intCast(pid_signed), &status, 0);
        }
    } else {
        ec = @intCast(-pid_signed);
    }

    _ = linux.close(args.p[0]);

    if (ec == 0) {
        if (res) |r| r.* = @intCast(pid_signed);
    }

    return spawnFail(&args.oldmask, cs, ec);
}

fn spawnFail(oldmask: *const musl_sigset_t, cs: c_int, ec: c_int) c_int {
    _ = pthread_sigmask(SIG_SETMASK, oldmask, null);
    _ = pthread_setcancelstate(cs, null);
    return ec;
}

fn posix_spawnpImpl(
    res: ?*linux.pid_t,
    file: [*:0]const u8,
    fa: ?*const posix_spawn_file_actions_t,
    attr_opt: ?*const posix_spawnattr_t,
    argv: [*:null]const ?[*:0]const u8,
    envp: [*:null]const ?[*:0]const u8,
) callconv(.c) c_int {
    var spawnp_attr: posix_spawnattr_t = if (attr_opt) |a| a.* else std.mem.zeroes(posix_spawnattr_t);
    spawnp_attr.__fn = @ptrCast(@constCast(&__execvpe));
    return posix_spawnImpl(res, file, fa, &spawnp_attr, argv, envp);
}

fn strchrnul(s: [*]const u8, c: u8) [*]const u8 {
    var p = s;
    while (p[0] != 0 and p[0] != c) p += 1;
    return p;
}

fn strnlen(s: [*]const u8, max: usize) usize {
    var i: usize = 0;
    while (i < max and s[i] != 0) i += 1;
    return i;
}

fn __execvpe(file: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) callconv(.c) c_int {
    std.c._errno().* = @intFromEnum(linux.E.NOENT);
    if (file[0] == 0) return -1;

    // If file contains '/', exec directly
    if (std.mem.indexOfScalar(u8, std.mem.span(file), '/') != null)
        return execve(file, argv, envp);

    const path = getenv("PATH") orelse "/usr/local/bin:/bin:/usr/bin";
    const k = strnlen(file, NAME_MAX + 1);
    if (k > NAME_MAX) {
        std.c._errno().* = @intFromEnum(linux.E.NAMETOOLONG);
        return -1;
    }
    const l = strnlen(path, PATH_MAX - 1) + 1;

    var buf: [PATH_MAX + NAME_MAX + 2]u8 = undefined;
    var seen_eacces = false;
    var p: [*]const u8 = path;

    while (true) {
        const z = strchrnul(p, ':');
        const seg_len = @intFromPtr(z) - @intFromPtr(p);
        if (seg_len < l) {
            @memcpy(buf[0..seg_len], p[0..seg_len]);
            var pos = seg_len;
            if (seg_len > 0) {
                buf[pos] = '/';
                pos += 1;
            }
            @memcpy(buf[pos..][0 .. k + 1], file[0 .. k + 1]);
            buf[pos + k] = 0;
            _ = execve(@ptrCast(buf[0 .. pos + k :0]), argv, envp);
            switch (@as(linux.E, @enumFromInt(std.c._errno().*))) {
                .ACCES => seen_eacces = true,
                .NOENT, .NOTDIR => {},
                else => return -1,
            }
        }
        if (z[0] == 0) break;
        p = z + 1;
    }
    if (seen_eacces) std.c._errno().* = @intFromEnum(linux.E.ACCES);
    return -1;
}

fn execvpImpl(file: [*:0]const u8, argv: [*:null]const ?[*:0]const u8) callconv(.c) c_int {
    return __execvpe(file, argv, @ptrCast(&__environ));
}

fn execlImpl(path: [*:0]const u8, argv0: ?[*:0]const u8, ...) callconv(.c) c_int {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);

    var argv_buf: [MAX_ARGS + 1]?[*:0]const u8 = undefined;
    argv_buf[0] = argv0;
    var argc: usize = 1;
    while (argc < MAX_ARGS) : (argc += 1) {
        argv_buf[argc] = @cVaArg(&ap, ?[*:0]const u8);
        if (argv_buf[argc] == null) break;
    }
    argv_buf[argc] = null;

    return execve(path, @ptrCast(&argv_buf), @ptrCast(&__environ));
}

fn execleImpl(path: [*:0]const u8, argv0: ?[*:0]const u8, ...) callconv(.c) c_int {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);

    var argv_buf: [MAX_ARGS + 1]?[*:0]const u8 = undefined;
    argv_buf[0] = argv0;
    var argc: usize = 1;
    while (argc < MAX_ARGS) : (argc += 1) {
        argv_buf[argc] = @cVaArg(&ap, ?[*:0]const u8);
        if (argv_buf[argc] == null) break;
    }
    argv_buf[argc] = null;
    // envp follows the null terminator
    const envp = @cVaArg(&ap, [*:null]const ?[*:0]const u8);

    return execve(path, @ptrCast(&argv_buf), envp);
}

fn execlpImpl(file: [*:0]const u8, argv0: ?[*:0]const u8, ...) callconv(.c) c_int {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);

    var argv_buf: [MAX_ARGS + 1]?[*:0]const u8 = undefined;
    argv_buf[0] = argv0;
    var argc: usize = 1;
    while (argc < MAX_ARGS) : (argc += 1) {
        argv_buf[argc] = @cVaArg(&ap, ?[*:0]const u8);
        if (argv_buf[argc] == null) break;
    }
    argv_buf[argc] = null;

    return execvp(file, @ptrCast(&argv_buf));
}

fn systemImpl(cmd: ?[*:0]const u8) callconv(.c) c_int {
    pthread_testcancel();

    if (cmd == null) return 1;

    var sa: c_sigaction = .{ .handler = SIG_IGN, .mask = @splat(0), .flags = 0, .restorer = null };
    var oldint: c_sigaction = undefined;
    var oldquit: c_sigaction = undefined;
    _ = sigaction(SIGINT, &sa, &oldint);
    _ = sigaction(SIGQUIT, &sa, &oldquit);
    _ = sigaddset(&sa.mask, SIGCHLD);

    var old: musl_sigset_t = undefined;
    _ = sigprocmask(SIG_BLOCK, &sa.mask, &old);

    var reset: musl_sigset_t = undefined;
    _ = sigemptyset(&reset);
    if (oldint.handler != SIG_IGN) _ = sigaddset(&reset, SIGINT);
    if (oldquit.handler != SIG_IGN) _ = sigaddset(&reset, SIGQUIT);

    var attr: posix_spawnattr_t = undefined;
    _ = posix_spawnattr_init(&attr);
    _ = posix_spawnattr_setsigmask(&attr, &old);
    _ = posix_spawnattr_setsigdefault(&attr, &reset);
    _ = posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_SETSIGMASK);

    var pid: linux.pid_t = undefined;
    var argv = [4:null]?[*:0]const u8{ "sh", "-c", cmd, null };
    const ret = posix_spawn(&pid, "/bin/sh", null, &attr, @ptrCast(&argv), @ptrCast(&__environ));
    _ = posix_spawnattr_destroy(&attr);

    var status: c_int = -1;
    if (ret == 0) {
        while (waitpid(pid, &status, 0) < 0) {
            if (std.c._errno().* != @intFromEnum(linux.E.INTR)) break;
        }
    }

    _ = sigaction(SIGINT, &oldint, null);
    _ = sigaction(SIGQUIT, &oldquit, null);
    _ = sigprocmask(SIG_SETMASK, &old, null);

    if (ret != 0) std.c._errno().* = ret;
    return status;
}
