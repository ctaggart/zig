const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&__inet_aton_impl, "__inet_aton");
        symbol(&__inet_aton_impl, "inet_aton");
        symbol(&inet_pton_impl, "inet_pton");
        symbol(&inet_ntop_impl, "inet_ntop");
    }
}

const AF_INET: c_int = 2;
const AF_INET6: c_int = 10;
const EAFNOSUPPORT: c_int = 97;
const ENOSPC: c_int = 28;

fn setErrno(val: c_int) void {
    if (builtin.link_libc) {
        std.c._errno().* = val;
    }
}

/// Parse a number with base 0 (decimal, octal with 0 prefix, hex with 0x prefix).
/// Returns the value and number of characters consumed.
fn strtoui(s: [*:0]const u8) struct { val: u32, len: usize } {
    var i: usize = 0;
    var base: u32 = 10;

    if (s[0] == '0') {
        if (s[1] == 'x' or s[1] == 'X') {
            base = 16;
            i = 2;
        } else {
            base = 8;
        }
    }
    const start = i;
    var val: u32 = 0;
    while (true) {
        const c = s[i];
        const d: u32 = switch (c) {
            '0'...'9' => |ch| ch - '0',
            'a'...'f' => |ch| if (base == 16) ch - 'a' + 10 else break,
            'A'...'F' => |ch| if (base == 16) ch - 'A' + 10 else break,
            else => break,
        };
        if (d >= base) break;
        val = val *% base +% d;
        i += 1;
    }
    // "0x" with no hex digits → consumed 0
    if (base == 16 and i == start) return .{ .val = 0, .len = 0 };
    return .{ .val = val, .len = i };
}

/// inet_aton: parse dotted-decimal IPv4 with classful format support.
/// Supports decimal, octal (0-prefix), hex (0x-prefix) per octet.
fn __inet_aton_impl(s0: [*:0]const u8, dest: *[4]u8) callconv(.c) c_int {
    var s: [*:0]const u8 = s0;
    var a: [4]u32 = .{ 0, 0, 0, 0 };
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        // Must start with a digit
        if (s[0] < '0' or s[0] > '9') return 0;
        const r = strtoui(s);
        if (r.len == 0) return 0;
        a[i] = r.val;
        if (s[r.len] == 0) break;
        if (s[r.len] != '.') return 0;
        s += r.len + 1;
    }
    if (i == 4) return 0; // too many parts

    // Redistribute bits for classful addresses (fallthrough via explicit cases)
    switch (i) {
        0 => {
            a[1] = a[0] & 0xffffff;
            a[0] >>= 24;
            a[2] = a[1] & 0xffff;
            a[1] >>= 16;
            a[3] = a[2] & 0xff;
            a[2] >>= 8;
        },
        1 => {
            a[2] = a[1] & 0xffff;
            a[1] >>= 16;
            a[3] = a[2] & 0xff;
            a[2] >>= 8;
        },
        2 => {
            a[3] = a[2] & 0xff;
            a[2] >>= 8;
        },
        3 => {},
        else => unreachable,
    }
    for (0..4) |j| {
        if (a[j] > 255) return 0;
        dest[j] = @intCast(a[j]);
    }
    return 1;
}

/// inet_pton: parse IPv4 or IPv6 address string into binary form.
fn inet_pton_impl(af: c_int, s_ptr: [*:0]const u8, a0: *anyopaque) callconv(.c) c_int {
    if (af == AF_INET) {
        return inet_pton4(s_ptr, @ptrCast(a0));
    } else if (af == AF_INET6) {
        return inet_pton6(s_ptr, @ptrCast(a0));
    } else {
        setErrno(EAFNOSUPPORT);
        return -1;
    }
}

/// Strict IPv4 parser for inet_pton (decimal only, no leading zeros except "0").
fn inet_pton4(s_init: [*:0]const u8, a: *[4]u8) c_int {
    var s = s_init;
    for (0..4) |i| {
        var v: u32 = 0;
        var j: usize = 0;
        while (j < 3 and s[j] >= '0' and s[j] <= '9') : (j += 1) {
            v = 10 * v + (s[j] - '0');
        }
        if (j == 0 or (j > 1 and s[0] == '0') or v > 255) return 0;
        a[i] = @intCast(v);
        if (s[j] == 0 and i == 3) return 1;
        if (s[j] != '.') return 0;
        s += j + 1;
    }
    return 0;
}

/// Parse an IPv6 address string.
fn inet_pton6(s_init: [*:0]const u8, a: *[16]u8) c_int {
    var s = s_init;
    var ip: [8]u16 = .{0} ** 8;
    var i: usize = 0;
    var brk: i32 = -1;
    var need_v4: bool = false;

    if (s[0] == ':') {
        s += 1;
        if (s[0] != ':') return 0;
    }

    while (true) {
        if (s[0] == ':' and brk < 0) {
            brk = @intCast(i);
            ip[i & 7] = 0;
            s += 1;
            if (s[0] == 0) break;
            if (i == 7) return 0;
            i += 1;
            continue;
        }
        var v: u32 = 0;
        var j: usize = 0;
        while (j < 4) : (j += 1) {
            const d = hexval(s[j]);
            if (d < 0) break;
            v = 16 * v + @as(u32, @intCast(d));
        }
        if (j == 0) return 0;
        ip[i & 7] = @intCast(v);
        if (s[j] == 0 and (brk >= 0 or i == 7)) break;
        if (i == 7) return 0;
        if (s[j] != ':') {
            if (s[j] != '.' or (i < 6 and brk < 0)) return 0;
            need_v4 = true;
            i += 1;
            ip[i & 7] = 0;
            break;
        }
        s += j + 1;
        i += 1;
    }

    if (brk >= 0) {
        const brku = @as(usize, @intCast(brk));
        // Move entries after brk to end
        const count = i + 1 - brku;
        var k: usize = 0;
        while (k < count) : (k += 1) {
            ip[brku + 7 - i + (count - 1 - k)] = ip[brku + (count - 1 - k)];
        }
        const gap = 7 - i;
        for (0..gap) |g| {
            ip[brku + g] = 0;
        }
    }

    for (0..8) |idx| {
        a[idx * 2] = @intCast(ip[idx] >> 8);
        a[idx * 2 + 1] = @intCast(ip[idx] & 0xff);
    }

    if (need_v4) {
        if (inet_pton4(@ptrCast(s), a[12..16]) <= 0) return 0;
    }
    return 1;
}

fn hexval(c: u8) i32 {
    if (c -% '0' < 10) return @intCast(c - '0');
    const cl = c | 32;
    if (cl -% 'a' < 6) return @intCast(cl - 'a' + 10);
    return -1;
}

/// inet_ntop: format binary address as string.
fn inet_ntop_impl(af: c_int, a0: *const anyopaque, s: [*]u8, l: u32) callconv(.c) ?[*]u8 {
    if (af == AF_INET) {
        return ntop4(@ptrCast(a0), s, l);
    } else if (af == AF_INET6) {
        return ntop6(@ptrCast(a0), s, l);
    } else {
        setErrno(EAFNOSUPPORT);
        return null;
    }
}

fn ntop4(a: *const [4]u8, s: [*]u8, l: u32) ?[*]u8 {
    var buf: [16]u8 = undefined;
    var pos: usize = 0;
    for (0..4) |i| {
        if (i > 0) {
            buf[pos] = '.';
            pos += 1;
        }
        pos += writeDecU8(buf[pos..], a[i]);
    }
    if (pos >= l) {
        setErrno(ENOSPC);
        return null;
    }
    @memcpy(s, buf[0..pos]);
    s[pos] = 0;
    return s;
}

fn ntop6(a: *const [16]u8, s: [*]u8, l: u32) ?[*]u8 {
    var buf: [100]u8 = undefined;
    var pos: usize = 0;

    // Check for IPv4-mapped address (::ffff:x.x.x.x)
    const is_v4mapped = !notEqual(a[0..12], "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff");

    if (!is_v4mapped) {
        // Standard IPv6 format
        for (0..8) |i| {
            if (i > 0) {
                buf[pos] = ':';
                pos += 1;
            }
            const val: u16 = @as(u16, a[i * 2]) << 8 | a[i * 2 + 1];
            pos += writeHexU16(buf[pos..], val);
        }
    } else {
        // Mixed notation for IPv4-mapped
        for (0..6) |i| {
            if (i > 0) {
                buf[pos] = ':';
                pos += 1;
            }
            const val: u16 = @as(u16, a[i * 2]) << 8 | a[i * 2 + 1];
            pos += writeHexU16(buf[pos..], val);
        }
        buf[pos] = ':';
        pos += 1;
        for (0..4) |i| {
            if (i > 0) {
                buf[pos] = '.';
                pos += 1;
            }
            pos += writeDecU8(buf[pos..], a[12 + i]);
        }
    }

    // Find longest run of ":0" or initial "0:" to replace with "::"
    var best: usize = 0;
    var max: usize = 2;
    {
        var i: usize = 0;
        while (i < pos) : (i += 1) {
            if (i != 0 and buf[i] != ':') continue;
            // Count consecutive ":0" chars
            var j: usize = 0;
            while (i + j < pos and (buf[i + j] == ':' or buf[i + j] == '0')) : (j += 1) {}
            if (j > max) {
                best = i;
                max = j;
            }
        }
    }
    if (max > 3) {
        buf[best] = ':';
        buf[best + 1] = ':';
        const tail_start = best + max;
        const tail_len = pos - tail_start;
        var k: usize = 0;
        while (k < tail_len + 1) : (k += 1) {
            buf[best + 2 + k] = buf[tail_start + k];
        }
        pos = best + 2 + tail_len;
    }

    if (pos >= l) {
        setErrno(ENOSPC);
        return null;
    }
    @memcpy(s, buf[0..pos]);
    s[pos] = 0;
    return s;
}

fn notEqual(a: []const u8, b: []const u8) bool {
    for (a, b) |x, y| {
        if (x != y) return true;
    }
    return false;
}

fn writeDecU8(buf: []u8, val: u8) usize {
    var pos: usize = 0;
    if (val >= 100) {
        buf[pos] = '0' + val / 100;
        pos += 1;
    }
    if (val >= 10) {
        buf[pos] = '0' + (val / 10) % 10;
        pos += 1;
    }
    buf[pos] = '0' + val % 10;
    return pos + 1;
}

fn writeHexU16(buf: []u8, val: u16) usize {
    const hex = "0123456789abcdef";
    if (val >= 0x1000) {
        buf[0] = hex[(val >> 12) & 0xf];
        buf[1] = hex[(val >> 8) & 0xf];
        buf[2] = hex[(val >> 4) & 0xf];
        buf[3] = hex[val & 0xf];
        return 4;
    } else if (val >= 0x100) {
        buf[0] = hex[(val >> 8) & 0xf];
        buf[1] = hex[(val >> 4) & 0xf];
        buf[2] = hex[val & 0xf];
        return 3;
    } else if (val >= 0x10) {
        buf[0] = hex[(val >> 4) & 0xf];
        buf[1] = hex[val & 0xf];
        return 2;
    } else {
        buf[0] = hex[val & 0xf];
        return 1;
    }
}

test __inet_aton_impl {
    var addr: [4]u8 = undefined;
    try std.testing.expectEqual(@as(c_int, 1), __inet_aton_impl("1.2.3.4", &addr));
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, &addr);

    try std.testing.expectEqual(@as(c_int, 1), __inet_aton_impl("127.0.0.1", &addr));
    try std.testing.expectEqualSlices(u8, &.{ 127, 0, 0, 1 }, &addr);

    try std.testing.expectEqual(@as(c_int, 0), __inet_aton_impl("", &addr));
    try std.testing.expectEqual(@as(c_int, 0), __inet_aton_impl("256.0.0.1", &addr));
}

test inet_pton_impl {
    var addr4: [4]u8 = undefined;
    try std.testing.expectEqual(@as(c_int, 1), inet_pton_impl(AF_INET, "192.168.1.1", &addr4));
    try std.testing.expectEqualSlices(u8, &.{ 192, 168, 1, 1 }, &addr4);

    // Leading zeros rejected
    try std.testing.expectEqual(@as(c_int, 0), inet_pton_impl(AF_INET, "01.2.3.4", &addr4));

    var addr6: [16]u8 = undefined;
    try std.testing.expectEqual(@as(c_int, 1), inet_pton_impl(AF_INET6, "::1", &addr6));
    try std.testing.expectEqualSlices(u8, &(.{0} ** 15 ++ .{1}), &addr6);

    try std.testing.expectEqual(@as(c_int, 1), inet_pton_impl(AF_INET6, "2001:db8::1", &addr6));
    try std.testing.expectEqual(@as(u8, 0x20), addr6[0]);
    try std.testing.expectEqual(@as(u8, 0x01), addr6[1]);
    try std.testing.expectEqual(@as(u8, 1), addr6[15]);
}

test inet_ntop_impl {
    var buf: [64]u8 = undefined;
    const a4 = [4]u8{ 192, 168, 1, 1 };
    const r4 = inet_ntop_impl(AF_INET, &a4, &buf, 64);
    try std.testing.expect(r4 != null);
    try std.testing.expectEqualStrings("192.168.1.1", std.mem.sliceTo(r4.?, 0));

    // IPv6 loopback
    const a6 = [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 };
    const r6 = inet_ntop_impl(AF_INET6, &a6, &buf, 64);
    try std.testing.expect(r6 != null);
    try std.testing.expectEqualStrings("::1", std.mem.sliceTo(r6.?, 0));

    // Buffer too small
    try std.testing.expect(inet_ntop_impl(AF_INET, &a4, &buf, 5) == null);
}
