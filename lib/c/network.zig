const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

const EtherAddr = extern struct {
    ether_addr_octet: [6]u8,
};

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&ether_aton_r_impl, "ether_aton_r");
        symbol(&ether_aton_impl, "ether_aton");
        symbol(&ether_ntoa_r_impl, "ether_ntoa_r");
        symbol(&ether_ntoa_impl, "ether_ntoa");
        symbol(&ether_line_impl, "ether_line");
        symbol(&ether_ntohost_impl, "ether_ntohost");
        symbol(&ether_hostton_impl, "ether_hostton");
    }
}

fn ether_aton_r_impl(x_ptr: [*:0]const u8, p_a: *EtherAddr) callconv(.c) ?*EtherAddr {
    var x: [*:0]const u8 = x_ptr;
    var a: EtherAddr = undefined;
    for (0..6) |ii| {
        if (ii != 0) {
            if (x[0] != ':') return null;
            x += 1;
        }
        var n: u32 = 0;
        var consumed: usize = 0;
        while (true) {
            const d: u32 = switch (x[consumed]) {
                '0'...'9' => |c| c - '0',
                'a'...'f' => |c| c - 'a' + 10,
                'A'...'F' => |c| c - 'A' + 10,
                else => break,
            };
            n = n * 16 + d;
            consumed += 1;
        }
        x += consumed;
        if (n > 0xFF) return null;
        a.ether_addr_octet[ii] = @intCast(n);
    }
    if (x[0] != 0) return null;
    p_a.* = a;
    return p_a;
}

fn ether_aton_impl(x: [*:0]const u8) callconv(.c) ?*EtherAddr {
    const S = struct {
        var a: EtherAddr = undefined;
    };
    return ether_aton_r_impl(x, &S.a);
}

fn ether_ntoa_r_impl(p_a: *const EtherAddr, x: [*]u8) callconv(.c) [*]u8 {
    const hex = "0123456789ABCDEF";
    var pos: usize = 0;
    for (0..6) |ii| {
        if (ii != 0) {
            x[pos] = ':';
            pos += 1;
        }
        const b = p_a.ether_addr_octet[ii];
        x[pos] = hex[b >> 4];
        pos += 1;
        x[pos] = hex[b & 0xf];
        pos += 1;
    }
    x[pos] = 0;
    return x;
}

fn ether_ntoa_impl(p_a: *const EtherAddr) callconv(.c) [*]u8 {
    const S = struct {
        var x: [18]u8 = undefined;
    };
    return ether_ntoa_r_impl(p_a, &S.x);
}

fn ether_line_impl(_: [*:0]const u8, _: *EtherAddr, _: [*]u8) callconv(.c) c_int {
    return -1;
}

fn ether_ntohost_impl(_: [*]u8, _: *const EtherAddr) callconv(.c) c_int {
    return -1;
}

fn ether_hostton_impl(_: [*:0]const u8, _: *EtherAddr) callconv(.c) c_int {
    return -1;
}

test ether_ntoa_r_impl {
    const addr = EtherAddr{ .ether_addr_octet = .{ 0xAA, 0xBB, 0xCC, 0x01, 0x02, 0x03 } };
    var buf: [18]u8 = undefined;
    const result = ether_ntoa_r_impl(&addr, &buf);
    try std.testing.expectEqualStrings("AA:BB:CC:01:02:03", std.mem.sliceTo(result, 0));
}

test ether_aton_r_impl {
    var addr: EtherAddr = undefined;
    const result = ether_aton_r_impl("AA:BB:CC:01:02:03", &addr);
    try std.testing.expect(result != null);
    try std.testing.expectEqualSlices(u8, &.{ 0xAA, 0xBB, 0xCC, 0x01, 0x02, 0x03 }, &result.?.ether_addr_octet);

    // Invalid input
    try std.testing.expect(ether_aton_r_impl("ZZ:BB:CC:01:02:03", &addr) == null);
}
