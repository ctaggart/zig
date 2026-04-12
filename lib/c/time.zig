const builtin = @import("builtin");

const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&timesLinux, "times");
    }
}

fn timesLinux(tms_ptr: ?*anyopaque) callconv(.c) c_long {
    return @bitCast(linux.syscall1(.times, @intFromPtr(tms_ptr)));
}
