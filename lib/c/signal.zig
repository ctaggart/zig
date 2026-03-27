const builtin = @import("builtin");

const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&sigaltstackLinux, "sigaltstack");
    }
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
