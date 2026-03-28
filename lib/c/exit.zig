const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&_Exit, "_Exit");
    }
}

fn _Exit(ec: c_int) callconv(.c) noreturn {
    linux.exit_group(ec);
}
