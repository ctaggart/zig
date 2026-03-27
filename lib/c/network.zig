const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

const in_addr_t = u32;

const InAddr = extern struct {
    s_addr: in_addr_t,
};

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&inet_makeaddr, "inet_makeaddr");
        symbol(&inet_lnaof, "inet_lnaof");
        symbol(&inet_netof, "inet_netof");
        if (builtin.link_libc) {
            symbol(&inet_network, "inet_network");
        }
    }
}

fn inet_network(p: [*:0]const u8) callconv(.c) in_addr_t {
    const inet_addr_c = @extern(*const fn ([*:0]const u8) callconv(.c) in_addr_t, .{ .name = "inet_addr" });
    return std.mem.bigToNative(u32, inet_addr_c(p));
}

fn inet_makeaddr(n: in_addr_t, h: in_addr_t) callconv(.c) InAddr {
    var host = h;
    if (n < 256) {
        host |= n << 24;
    } else if (n < 65536) {
        host |= n << 16;
    } else {
        host |= n << 8;
    }
    return .{ .s_addr = host };
}

fn inet_lnaof(in: InAddr) callconv(.c) in_addr_t {
    const h = in.s_addr;
    if (h >> 24 < 128) return h & 0xffffff;
    if (h >> 24 < 192) return h & 0xffff;
    return h & 0xff;
}

fn inet_netof(in: InAddr) callconv(.c) in_addr_t {
    const h = in.s_addr;
    if (h >> 24 < 128) return h >> 24;
    if (h >> 24 < 192) return h >> 16;
    return h >> 8;
}
