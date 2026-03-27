const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&dn_skipname_impl, "dn_skipname");

        if (builtin.link_libc) {
            symbol(&gethostbyname_impl, "gethostbyname");
            symbol(&gethostbyname_r_impl, "gethostbyname_r");
        }
    }
}

fn dn_skipname_impl(s: [*]const u8, end: [*]const u8) callconv(.c) c_int {
    const len = @intFromPtr(end) - @intFromPtr(s);
    var i: usize = 0;
    while (i < len) {
        if (s[i] == 0) return @intCast(i + 1);
        if (s[i] >= 192) {
            if (i + 1 < len) return @intCast(i + 2);
            break;
        }
        const label_len: usize = s[i];
        if (len - i < label_len + 1) break;
        i += label_len + 1;
    }
    return -1;
}

fn gethostbyname_impl(name: [*:0]const u8) callconv(.c) ?*anyopaque {
    const f = @extern(*const fn ([*:0]const u8, c_int) callconv(.c) ?*anyopaque, .{ .name = "gethostbyname2" });
    return f(name, 2); // AF_INET
}

fn gethostbyname_r_impl(name: [*:0]const u8, h: *anyopaque, buf: [*]u8, buflen: usize, res: *?*anyopaque, err: *c_int) callconv(.c) c_int {
    const f = @extern(*const fn ([*:0]const u8, c_int, *anyopaque, [*]u8, usize, *?*anyopaque, *c_int) callconv(.c) c_int, .{ .name = "gethostbyname2_r" });
    return f(name, 2, h, buf, buflen, res, err); // AF_INET
}

test dn_skipname_impl {
    // Label: 3www7example3com0
    const dns_name = [_]u8{ 3, 'w', 'w', 'w', 7, 'e', 'x', 'a', 'm', 'p', 'l', 'e', 3, 'c', 'o', 'm', 0 };
    try std.testing.expectEqual(@as(c_int, 17), dn_skipname_impl(&dns_name, @as([*]const u8, &dns_name) + dns_name.len));

    // Compression pointer (2 bytes)
    const compressed = [_]u8{ 0xC0, 0x0C };
    try std.testing.expectEqual(@as(c_int, 2), dn_skipname_impl(&compressed, @as([*]const u8, &compressed) + compressed.len));

    // Root label (just 0)
    const root = [_]u8{0};
    try std.testing.expectEqual(@as(c_int, 1), dn_skipname_impl(&root, @as([*]const u8, &root) + root.len));
}
