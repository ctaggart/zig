const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&_ExitLinux, "_Exit");
    }
}

fn _ExitLinux(exit_code: c_int) callconv(.c) noreturn {
    linux.exit_group(exit_code);
}
