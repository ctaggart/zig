const builtin = @import("builtin");

const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&sigprocmaskLinux, "sigprocmask");
        symbol(&sigsuspendLinux, "sigsuspend");
    }
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
