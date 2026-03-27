const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

const InAddr = extern struct {
    s_addr: u32,
};

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&inet_ntoa_impl, "inet_ntoa");
    }
    if (builtin.target.isMuslLibC()) {
        if (builtin.link_libc) {
            symbol(&if_freenameindex_impl, "if_freenameindex");
            symbol(&inet_addr_impl, "inet_addr");
        }
    }
}

fn inet_ntoa_impl(in: InAddr) callconv(.c) [*]u8 {
    const S = struct {
        var buf: [16]u8 = [1]u8{0} ** 16;
    };
    const a: *const [4]u8 = @ptrCast(&in.s_addr);
    var pos: usize = 0;
    for (0..4) |i| {
        if (i > 0) {
            S.buf[pos] = '.';
            pos += 1;
        }
        const val = a[i];
        if (val >= 100) {
            S.buf[pos] = '0' + val / 100;
            pos += 1;
        }
        if (val >= 10) {
            S.buf[pos] = '0' + (val / 10) % 10;
            pos += 1;
        }
        S.buf[pos] = '0' + val % 10;
        pos += 1;
    }
    S.buf[pos] = 0;
    return &S.buf;
}

fn if_freenameindex_impl(idx: ?*anyopaque) callconv(.c) void {
    const c_free = @extern(*const fn (?*anyopaque) callconv(.c) void, .{ .name = "free" });
    c_free(idx);
}

fn inet_addr_impl(p: [*:0]const u8) callconv(.c) u32 {
    const c_inet_aton = @extern(*const fn ([*:0]const u8, *InAddr) callconv(.c) c_int, .{ .name = "__inet_aton" });
    var a: InAddr = undefined;
    if (c_inet_aton(p, &a) == 0) return 0xFFFFFFFF;
    return a.s_addr;
}

test inet_ntoa_impl {
    const result = inet_ntoa_impl(.{ .s_addr = std.mem.nativeToBig(u32, (127 << 24) | 1) });
    try std.testing.expectEqualStrings("127.0.0.1", std.mem.sliceTo(result, 0));
}
