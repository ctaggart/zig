const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&abortImpl, "abort");
    }
}

extern "c" fn raise(sig: c_int) c_int;
extern "c" fn __lock(lock: *c_int) void;
extern "c" fn __block_all_sigs(set: ?*anyopaque) void;
extern "c" fn _Exit(code: c_int) noreturn;
extern "c" var __abort_lock: c_int;

fn abortImpl() callconv(.c) noreturn {
    _ = raise(@intFromEnum(linux.SIG.ABRT));

    // If we get here, SIGABRT was caught/blocked/ignored.
    // Block all signals, lock to prevent new handlers, reset SIGABRT to default,
    // then re-raise.
    __block_all_sigs(null);
    __lock(&__abort_lock);

    // Reset SIGABRT handler to SIG_DFL via rt_sigaction.
    const SIG_DFL: usize = 0;
    var sa: [4]usize = .{ SIG_DFL, 0, 0, 0 };
    _ = linux.syscall4(
        .rt_sigaction,
        @intFromEnum(linux.SIG.ABRT),
        @intFromPtr(&sa),
        0,
        linux.NSIG / 8,
    );

    // Send SIGABRT to this thread.
    _ = linux.tkill(linux.gettid(), linux.SIG.ABRT);

    // Unblock SIGABRT.
    const sigabrt_bit: usize = @as(usize, 1) << (@intFromEnum(linux.SIG.ABRT) - 1);
    const SIG_UNBLOCK: usize = 1;
    _ = linux.syscall4(
        .rt_sigprocmask,
        SIG_UNBLOCK,
        @intFromPtr(&sigabrt_bit),
        0,
        linux.NSIG / 8,
    );

    // Should be unreachable. Crash hard.
    _ = raise(@intFromEnum(linux.SIG.KILL));
    _Exit(127);
}
