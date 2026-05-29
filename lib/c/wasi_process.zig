const std = @import("std");
const builtin = @import("builtin");
const wasi = std.os.wasi;
const c = @import("../c.zig");

comptime {
    if (!builtin.target.isWasiLibC()) @compileError("wasi_process.zig is only for WASI");
}

const CLOCKS_PER_SEC: u64 = 1_000_000_000;
const RUSAGE_SELF: c_int = 1;
const RUSAGE_CHILDREN: c_int = 2;

const clock_t = i64;
const pid_t = c_int;

const Timeval = extern struct {
    tv_sec: i64,
    tv_usec: i64,
};

const RUsage = extern struct {
    ru_utime: Timeval,
    ru_stime: Timeval,
};

const Tms = extern struct {
    tms_utime: clock_t,
    tms_stime: clock_t,
    tms_cutime: clock_t,
    tms_cstime: clock_t,
};

fn setErrno(e: wasi.errno_t) void {
    std.c._errno().* = @intFromEnum(e);
}

fn processTimeNanos() u64 {
    var nanos: wasi.timestamp_t = 0;
    _ = wasi.clock_time_get(.PROCESS_CPUTIME_ID, 0, &nanos);
    return nanos;
}

fn nanosToClock(nanos: u64) clock_t {
    comptime std.debug.assert(std.time.ns_per_s % CLOCKS_PER_SEC == 0);
    return @intCast(nanos / (std.time.ns_per_s / CLOCKS_PER_SEC));
}

fn nanosToTimeval(nanos: u64) Timeval {
    return .{
        .tv_sec = @intCast(nanos / std.time.ns_per_s),
        .tv_usec = @intCast((nanos % std.time.ns_per_s) / std.time.ns_per_us),
    };
}

fn clockImpl() callconv(.c) clock_t {
    return nanosToClock(processTimeNanos());
}

fn timesImpl(buffer: *Tms) callconv(.c) clock_t {
    const ticks = clockImpl();
    buffer.* = .{
        .tms_utime = ticks,
        .tms_stime = ticks,
        .tms_cutime = 0,
        .tms_cstime = 0,
    };
    return ticks;
}

fn getrusageImpl(who: c_int, usage: *RUsage) callconv(.c) c_int {
    switch (who) {
        RUSAGE_SELF => {
            const tv = nanosToTimeval(processTimeNanos());
            usage.* = .{ .ru_utime = tv, .ru_stime = tv };
            return 0;
        },
        RUSAGE_CHILDREN => {
            usage.* = std.mem.zeroes(RUsage);
            return 0;
        },
        else => {
            setErrno(.INVAL);
            return -1;
        },
    }
}

fn getpidImpl() callconv(.c) pid_t {
    return 1;
}

comptime {
    c.symbol(&clockImpl, "__clock");
    c.symbol(&clockImpl, "clock");
    c.symbol(&timesImpl, "times");
    c.symbol(&getrusageImpl, "getrusage");
    c.symbol(&getpidImpl, "getpid");
}
