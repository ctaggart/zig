const std = @import("std");
const builtin = @import("builtin");
const wasi = std.os.wasi;
const c = @import("../c.zig");

comptime {
    if (!builtin.target.isWasiLibC()) @compileError("wasi_dl.zig is only for WASI");
}

const dl_error = "dynamic loading not supported";

fn dlopenImpl(name: ?[*:0]const u8, flags: c_int) callconv(.c) ?*anyopaque {
    _ = .{ name, flags };
    return null;
}

fn dlsymImpl(library: ?*anyopaque, name: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    _ = .{ library, name };
    return null;
}

fn dladdrImpl(addr: ?*const anyopaque, info: ?*anyopaque) callconv(.c) c_int {
    _ = .{ addr, info };
    return 0;
}

fn dlcloseImpl(library: ?*anyopaque) callconv(.c) c_int {
    _ = library;
    return 0;
}

fn dlerrorImpl() callconv(.c) [*:0]u8 {
    return @constCast(dl_error);
}

comptime {
    _ = wasi;
    c.symbol(&dlopenImpl, "dlopen");
    c.symbol(&dlsymImpl, "dlsym");
    c.symbol(&dladdrImpl, "dladdr");
    c.symbol(&dlcloseImpl, "dlclose");
    c.symbol(&dlerrorImpl, "dlerror");
}
