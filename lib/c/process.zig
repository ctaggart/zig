const builtin = @import("builtin");

const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

const musl_sigset_t = [128 / @sizeOf(c_ulong)]c_ulong;

const c_sigaction = extern struct {
    handler: ?*const fn (c_int) callconv(.c) void,
    mask: musl_sigset_t,
    flags: c_int,
    restorer: ?*const fn () callconv(.c) void,
};

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

const SIG_IGN: ?*const fn (c_int) callconv(.c) void = @ptrFromInt(1);

extern "c" fn sigaction(sig: c_int, act: ?*const c_sigaction, oact: ?*c_sigaction) callconv(.c) c_int;
extern "c" fn sigprocmask(how: c_int, set: ?*const musl_sigset_t, oset: ?*musl_sigset_t) callconv(.c) c_int;
extern "c" fn sigemptyset(set: *musl_sigset_t) callconv(.c) c_int;
extern "c" fn sigaddset(set: *musl_sigset_t, sig: c_int) callconv(.c) c_int;
extern "c" fn posix_spawnattr_init(attr: *posix_spawnattr_t) callconv(.c) c_int;
extern "c" fn posix_spawnattr_setsigmask(attr: *posix_spawnattr_t, mask: *const musl_sigset_t) callconv(.c) c_int;
extern "c" fn posix_spawnattr_setsigdefault(attr: *posix_spawnattr_t, def: *const musl_sigset_t) callconv(.c) c_int;
extern "c" fn posix_spawnattr_setflags(attr: *posix_spawnattr_t, flags: c_short) callconv(.c) c_int;
extern "c" fn posix_spawnattr_destroy(attr: *posix_spawnattr_t) callconv(.c) c_int;
extern "c" fn posix_spawn(pid: *linux.pid_t, path: [*:0]const u8, fa: ?*anyopaque, attr: ?*const posix_spawnattr_t, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) callconv(.c) c_int;
extern "c" fn waitpid(pid: linux.pid_t, status: ?*c_int, options: c_int) callconv(.c) linux.pid_t;
extern "c" fn pthread_testcancel() callconv(.c) void;
extern "c" var __environ: [*:null]?[*:0]u8;

const POSIX_SPAWN_SETSIGDEF: c_short = 0x4;
const POSIX_SPAWN_SETSIGMASK: c_short = 0x8;
const SIGINT = 2;
const SIGQUIT = 3;
const SIGCHLD = 17;
const SIG_BLOCK = 0;
const SIG_SETMASK = 2;

comptime {
    if (builtin.link_libc) {
        symbol(&systemImpl, "system");
    }
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
