const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&_Exit, "_Exit");
        symbol(&__abort_lock, "__abort_lock");
    }
}

fn _Exit(ec: c_int) callconv(.c) noreturn {
    linux.exit_group(ec);
}

var __abort_lock: [1]c_int = .{0};
