const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&htonl, "htonl");
        symbol(&htons, "htons");
        symbol(&ntohl, "ntohl");
        symbol(&ntohs, "ntohs");
        symbol(&in6addr_any, "in6addr_any");
        symbol(&in6addr_loopback, "in6addr_loopback");
    }
}

fn htonl(n: u32) callconv(.c) u32 {
    return std.mem.nativeToBig(u32, n);
}

fn htons(n: u16) callconv(.c) u16 {
    return std.mem.nativeToBig(u16, n);
}

fn ntohl(n: u32) callconv(.c) u32 {
    return std.mem.bigToNative(u32, n);
}

fn ntohs(n: u16) callconv(.c) u16 {
    return std.mem.bigToNative(u16, n);
}

const in6addr_any = [1]u8{0} ** 16;
const in6addr_loopback = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 };
