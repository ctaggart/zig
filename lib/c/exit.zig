const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&__assert_fail, "__assert_fail");
    }
}

extern "c" fn fprintf(stream: *anyopaque, fmt: [*:0]const u8, ...) c_int;
extern "c" fn abort() noreturn;
extern "c" var stderr: *anyopaque;

fn __assert_fail(
    expr: [*:0]const u8,
    file: [*:0]const u8,
    line: c_int,
    func: [*:0]const u8,
) callconv(.c) noreturn {
    _ = fprintf(stderr, "Assertion failed: %s (%s: %s: %d)\n", expr, file, func, line);
    abort();
}
