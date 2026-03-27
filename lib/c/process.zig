const builtin = @import("builtin");

const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

const NSIG = linux.NSIG;
const sigset_t = linux.sigset_t;
const SigsetElement = @typeInfo(sigset_t).array.child;
const bits_per_elem = @bitSizeOf(SigsetElement);

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&raiseLinux, "raise");
        symbol(&waitLinux, "wait");
        symbol(&waitpidLinux, "waitpid");
        symbol(&waitidLinux, "waitid");
        symbol(&__restore, "__restore");
        symbol(&__restore_rt, "__restore_rt");
    }
}

// app_mask: all signals set except internal signals 32, 33, 34
const app_mask = blk: {
    var mask: sigset_t = undefined;
    for (&mask) |*elem| elem.* = ~@as(SigsetElement, 0);
    for (.{ 31, 32, 33 }) |s| {
        mask[s / bits_per_elem] &= ~(@as(SigsetElement, 1) << @intCast(s % bits_per_elem));
    }
    break :blk mask;
};

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
