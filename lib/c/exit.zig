const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&dummy, "__funcs_on_exit");
        symbol(&dummy, "__stdio_exit");
        symbol(&dummy, "_fini");
        symbol(&libc_exit_fini, "__libc_exit_fini");
        symbol(&exitImpl, "exit");
    }
}

fn dummy() callconv(.c) void {}

extern "c" fn __funcs_on_exit() void;
extern "c" fn __stdio_exit() void;
extern "c" fn _fini() void;
extern "c" fn _Exit(code: c_int) noreturn;

extern const __fini_array_start: *const fn () callconv(.c) void;
extern const __fini_array_end: *const fn () callconv(.c) void;

fn libc_exit_fini() callconv(.c) void {
    const start: usize = @intFromPtr(&__fini_array_start);
    const end: usize = @intFromPtr(&__fini_array_end);
    const ptr_size = @sizeOf(*const fn () callconv(.c) void);
    var a: usize = end;
    while (a > start) {
        a -= ptr_size;
        const func: *const *const fn () callconv(.c) void = @ptrFromInt(a);
        func.*();
    }
    _fini();
}

fn exitImpl(code: c_int) callconv(.c) noreturn {
    __funcs_on_exit();
    libc_exit_fini();
    __stdio_exit();
    _Exit(code);
}
