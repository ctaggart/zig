const std = @import("std");
const builtin = @import("builtin");
const wasi = std.os.wasi;
const c = @import("../c.zig");

comptime {
    if (!builtin.target.isWasiLibC()) @compileError("wasi_setjmp.zig is only for WASI");
}

const have_exception_handling = builtin.cpu.has(.wasm, .exception_handling);

const JumpBuf = extern struct {
    func_invocation_id: ?*anyopaque,
    label: u32,
    arg: extern struct {
        env: ?*anyopaque,
        val: c_int,
    },
};

extern fn @"llvm.wasm.throw"(tag: u32, arg: *anyopaque) void;

fn wasmThrow(tag: u32, arg: *anyopaque) noreturn {
    @"llvm.wasm.throw"(tag, arg);
    unreachable;
}

fn wasmSetjmp(env: *anyopaque, label: u32, func_invocation_id: ?*anyopaque) callconv(.c) void {
    const jb: *JumpBuf = @ptrCast(@alignCast(env));
    if (label == 0 or func_invocation_id == null) @trap();
    jb.func_invocation_id = func_invocation_id;
    jb.label = label;
}

fn wasmSetjmpTest(env: *anyopaque, func_invocation_id: ?*anyopaque) callconv(.c) u32 {
    const jb: *JumpBuf = @ptrCast(@alignCast(env));
    if (jb.label == 0 or func_invocation_id == null) @trap();
    if (jb.func_invocation_id == func_invocation_id) return jb.label;
    return 0;
}

fn wasmLongjmp(env: *anyopaque, val_in: c_int) callconv(.c) noreturn {
    const jb: *JumpBuf = @ptrCast(@alignCast(env));
    var val = val_in;
    if (val == 0) val = 1;
    jb.arg.env = env;
    jb.arg.val = val;
    wasmThrow(1, &jb.arg);
}

comptime {
    _ = .{ std, wasi };
    if (have_exception_handling) {
        c.symbol(&wasmSetjmp, "__wasm_setjmp");
        c.symbol(&wasmSetjmpTest, "__wasm_setjmp_test");
        c.symbol(&wasmLongjmp, "__wasm_longjmp");
    }
}
