const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&_Exit, "_Exit");
        symbol(&__abort_lock, "__abort_lock");
        if (builtin.link_libc) {
            symbol(&__assert_fail, "__assert_fail");
        }
    }
}

fn _Exit(ec: c_int) callconv(.c) noreturn {
    linux.exit_group(ec);
}

var __abort_lock: [1]c_int = .{0};

// --- assert ---

extern "c" fn dprintf(fd: c_int, fmt: [*:0]const u8, ...) c_int;
extern "c" fn abort() noreturn;

fn __assert_fail(
    expr: [*:0]const u8,
    file: [*:0]const u8,
    line: c_int,
    func: [*:0]const u8,
) callconv(.c) noreturn {
    _ = dprintf(2, "Assertion failed: %s (%s: %s: %d)\n", expr, file, func, line);
    abort();
}
