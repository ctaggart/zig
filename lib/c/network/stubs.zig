// Small network stubs: resolver no-ops, IPv6 constants, trivial freers.
// Migrated from musl/src/network/{in6addr_any,in6addr_loopback,res_init,res_state,if_freenameindex}.c
const builtin = @import("builtin");
const std = @import("std");
const symbol = @import("../../c.zig").symbol;

const in6_addr = extern struct {
    s6_addr: [16]u8,
};

// IN6ADDR_ANY_INIT -- all zeros.
export const in6addr_any: in6_addr = .{ .s6_addr = @splat(0) };

// IN6ADDR_LOOPBACK_INIT -- ::1
export const in6addr_loopback: in6_addr = .{
    .s6_addr = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
};

fn res_init() callconv(.c) c_int {
    return 0;
}

// struct __res_state is opaque here; musl's is sizeof > 0. Musl's res_state() returns
// a static instance purely to satisfy broken apps (never reads/writes fields).
// Match musl's layout size so callers that compute offsets won't overrun. Musl's
// definition spans ~512 bytes; we don't need exact compat since no one uses fields.
// Keep a conservative 1024-byte static.
var res_state_buf: [1024]u8 align(@alignOf(usize)) = @splat(0);
fn __res_state() callconv(.c) *anyopaque {
    return @ptrCast(&res_state_buf);
}

fn if_freenameindex(idx: ?*anyopaque) callconv(.c) void {
    const free_fn = @extern(*const fn (?*anyopaque) callconv(.c) void, .{ .name = "free" });
    free_fn(idx);
}

comptime {
    if (builtin.os.tag == .linux and builtin.link_libc) {
        symbol(&res_init, "res_init");
        symbol(&__res_state, "__res_state");
        symbol(&if_freenameindex, "if_freenameindex");
    }
}
