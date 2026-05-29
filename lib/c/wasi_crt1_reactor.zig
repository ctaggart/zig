const std = @import("std");
const builtin = @import("builtin");
const wasi = std.os.wasi;

comptime {
    if (!builtin.target.isWasiLibC()) @compileError("wasi_crt1_reactor.zig is only for WASI");
}

extern fn __wasi_init_tp() void;
extern fn __wasm_call_ctors() void;

var initialized: c_int = 0;

export fn _initialize() callconv(.c) void {
    if (initialized != 0) @trap();
    initialized = 1;

    if (!builtin.single_threaded) __wasi_init_tp();

    __wasm_call_ctors();
}
