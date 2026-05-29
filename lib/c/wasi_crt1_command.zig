const std = @import("std");
const builtin = @import("builtin");
const wasi = std.os.wasi;

comptime {
    if (!builtin.target.isWasiLibC()) @compileError("wasi_crt1_command.zig is only for WASI");
}

extern fn __wasi_init_tp() void;
extern fn __wasm_call_ctors() void;
extern fn __main_void() c_int;
extern fn __wasm_call_dtors() void;

var started: c_int = 0;

export fn _start() callconv(.c) void {
    if (started != 0) @trap();
    started = 1;

    if (!builtin.single_threaded) __wasi_init_tp();

    __wasm_call_ctors();
    const result = __main_void();
    __wasm_call_dtors();
    if (result != 0) wasi.proc_exit(@intCast(result));
}
