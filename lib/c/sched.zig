const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;
const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;
const c = @import("../c.zig");

const arch = builtin.target.cpu.arch;
const tls_above_tp = switch (arch) {
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb, .riscv64, .riscv32, .mips, .mipsel, .mips64, .mips64el, .powerpc, .powerpcle, .powerpc64, .powerpc64le, .loongarch64, .m68k => true,
    else => false,
};
const ptr_size = @sizeOf(usize);
const part1_size: usize = if (tls_above_tp) 4 * ptr_size else 6 * ptr_size;
const off_tid = part1_size;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&sched_yieldLinux, "sched_yield");
        symbol(&sched_get_priority_maxLinux, "sched_get_priority_max");
        symbol(&sched_get_priority_minLinux, "sched_get_priority_min");
        symbol(&sched_getparamStub, "sched_getparam");
        symbol(&sched_setparamStub, "sched_setparam");
        symbol(&sched_getschedulerStub, "sched_getscheduler");
        symbol(&sched_setschedulerStub, "sched_setscheduler");
        symbol(&sched_rr_get_intervalLinux, "sched_rr_get_interval");
        symbol(&__sched_cpucount, "__sched_cpucount");
        symbol(&sched_getaffinityLinux, "sched_getaffinity");
        symbol(&sched_setaffinityLinux, "sched_setaffinity");
        symbol(&pthread_getaffinity_npLinux, "pthread_getaffinity_np");
        symbol(&pthread_setaffinity_npLinux, "pthread_setaffinity_np");
        symbol(&sched_getcpuLinux, "sched_getcpu");
    }
}

fn sched_yieldLinux() callconv(.c) c_int {
    return errno(linux.sched_yield());
}

fn sched_get_priority_maxLinux(policy: c_int) callconv(.c) c_int {
    return errno(linux.sched_get_priority_max(@bitCast(policy)));
}

fn sched_get_priority_minLinux(policy: c_int) callconv(.c) c_int {
    return errno(linux.sched_get_priority_min(@bitCast(policy)));
}

/// musl deliberately returns -ENOSYS for these scheduling functions.
fn sched_getparamStub(pid: linux.pid_t, param: *linux.sched_param) callconv(.c) c_int {
    _ = pid;
    _ = param;
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}

fn sched_setparamStub(pid: linux.pid_t, param: *const linux.sched_param) callconv(.c) c_int {
    _ = pid;
    _ = param;
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}

fn sched_getschedulerStub(pid: linux.pid_t) callconv(.c) c_int {
    _ = pid;
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}

fn sched_setschedulerStub(pid: linux.pid_t, sched: c_int, param: *const linux.sched_param) callconv(.c) c_int {
    _ = pid;
    _ = sched;
    _ = param;
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}

fn sched_rr_get_intervalLinux(pid: linux.pid_t, ts: *linux.timespec) callconv(.c) c_int {
    return errno(linux.sched_rr_get_interval(pid, ts));
}

fn __sched_cpucount(size: usize, set: [*]const u8) callconv(.c) c_int {
    var cnt: c_int = 0;
    for (set[0..size]) |byte| {
        cnt += @intCast(@popCount(byte));
    }
    return cnt;
}

fn do_getaffinity(tid: linux.pid_t, size: usize, set: [*]u8) c_long {
    const rc: isize = @bitCast(linux.syscall3(
        .sched_getaffinity,
        @as(usize, @bitCast(@as(isize, tid))),
        size,
        @intFromPtr(set),
    ));
    if (rc < 0) return @intCast(rc);
    const ret: usize = @intCast(rc);
    if (ret < size) @memset(set[ret..size], 0);
    return 0;
}

fn sched_getaffinityLinux(tid: linux.pid_t, size: usize, set: [*]u8) callconv(.c) c_int {
    return errno(@bitCast(@as(isize, @intCast(do_getaffinity(tid, size, set)))));
}

fn sched_setaffinityLinux(tid: linux.pid_t, size: usize, set: [*]const u8) callconv(.c) c_int {
    return errno(linux.syscall3(
        .sched_setaffinity,
        @as(usize, @bitCast(@as(isize, tid))),
        size,
        @intFromPtr(set),
    ));
}

fn pthread_tid(thread: std.c.pthread_t) linux.pid_t {
    return (@as(*const linux.pid_t, @ptrFromInt(@intFromPtr(thread) + off_tid))).*;
}

fn pthread_getaffinity_npLinux(thread: std.c.pthread_t, size: usize, set: [*]u8) callconv(.c) c_int {
    return @intCast(-do_getaffinity(pthread_tid(thread), size, set));
}

fn pthread_setaffinity_npLinux(thread: std.c.pthread_t, size: usize, set: [*]const u8) callconv(.c) c_int {
    const rc: isize = @bitCast(linux.syscall3(
        .sched_setaffinity,
        @as(usize, @bitCast(@as(isize, pthread_tid(thread)))),
        size,
        @intFromPtr(set),
    ));
    return if (rc < 0) @intCast(-rc) else 0;
}

/// sched_getcpu — returns the CPU the calling thread is running on.
/// Drops musl's vdso optimization; uses raw getcpu syscall.
fn sched_getcpuLinux() callconv(.c) c_int {
    var cpu: usize = 0;
    const rc: isize = @bitCast(linux.getcpu(&cpu, null));
    if (rc < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-rc);
        return -1;
    }
    return @intCast(cpu);
}

fn sched_getparamLinux(_: linux.pid_t, _: *anyopaque) callconv(.c) c_int {
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}

fn sched_setparamLinux(_: linux.pid_t, _: *const anyopaque) callconv(.c) c_int {
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}

fn sched_getschedulerLinux(_: linux.pid_t) callconv(.c) c_int {
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}

fn sched_setschedulerLinux(_: linux.pid_t, _: c_int, _: *const anyopaque) callconv(.c) c_int {
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}
