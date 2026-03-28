const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&__dn_expand_impl, "__dn_expand");
        symbol(&__dn_expand_impl, "dn_expand");
        symbol(&__dns_parse_impl, "__dns_parse");
    }
}

/// Decompress a DNS domain name from a packet.
fn __dn_expand_impl(base: [*]const u8, end: [*]const u8, src: [*]const u8, dest: [*]u8, space: c_int) callconv(.c) c_int {
    if (@intFromPtr(src) >= @intFromPtr(end) or space <= 0) return -1;

    var p = src;
    var dpos: usize = 0;
    const dmax: usize = if (space > 254) 254 else @intCast(space);
    var len: c_int = -1;
    const total = @intFromPtr(end) - @intFromPtr(base);

    var i: usize = 0;
    while (i < total) : (i += 2) {
        if ((p[0] & 0xc0) != 0) {
            // Compression pointer
            if (@intFromPtr(p) + 1 >= @intFromPtr(end)) return -1;
            const j: usize = (@as(usize, p[0] & 0x3f) << 8) | p[1];
            if (len < 0) len = @intCast(@intFromPtr(p) + 2 - @intFromPtr(src));
            if (j >= total) return -1;
            p = base + j;
        } else if (p[0] != 0) {
            // Label
            if (dpos > 0) {
                if (dpos >= dmax) return -1;
                dest[dpos] = '.';
                dpos += 1;
            }
            const label_len: usize = p[0];
            p += 1;
            if (label_len > @intFromPtr(end) - @intFromPtr(p)) return -1;
            if (label_len > dmax - dpos) return -1;
            @memcpy(dest[dpos..][0..label_len], p[0..label_len]);
            dpos += label_len;
            p += label_len;
        } else {
            // Root terminator
            dest[dpos] = 0;
            if (len < 0) len = @intCast(@intFromPtr(p) + 1 - @intFromPtr(src));
            return len;
        }
    }
    return -1;
}

/// Parse DNS answer records, calling callback for each.
fn __dns_parse_impl(
    r: [*]const u8,
    rlen: c_int,
    callback: *const fn (?*anyopaque, c_int, *const anyopaque, c_int, *const anyopaque, c_int) callconv(.c) c_int,
    ctx: ?*anyopaque,
) callconv(.c) c_int {
    if (rlen < 12) return -1;
    if ((r[3] & 15) != 0) return 0;

    const len: usize = @intCast(rlen);
    var pos: usize = 12;
    var qdcount: usize = @as(usize, r[4]) * 256 + r[5];
    var ancount: usize = @as(usize, r[6]) * 256 + r[7];

    // Skip question section
    while (qdcount > 0) : (qdcount -= 1) {
        while (pos < len and r[pos] -% 1 < 127) pos += 1;
        if (pos + 6 > len) return -1;
        pos += 5 + @as(usize, @intFromBool(r[pos] != 0));
    }

    // Process answer section
    while (ancount > 0) : (ancount -= 1) {
        while (pos < len and r[pos] -% 1 < 127) pos += 1;
        if (pos + 12 > len) return -1;
        pos += 1 + @as(usize, @intFromBool(r[pos] != 0));
        const rdlen: usize = @as(usize, r[pos + 8]) * 256 + r[pos + 9];
        if (rdlen + 10 > len - pos) return -1;
        if (callback(ctx, @intCast(r[pos + 1]), @ptrCast(r + pos + 10), @intCast(rdlen), @ptrCast(r), rlen) < 0) return -1;
        pos += 10 + rdlen;
    }
    return 0;
}

test __dn_expand_impl {
    // Simple uncompressed name: \x03www\x07example\x03com\x00
    const pkt = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ++ // 12-byte header
        "\x03www\x07example\x03com\x00";
    var buf: [256]u8 = undefined;
    const r = __dn_expand_impl(pkt, pkt.ptr + pkt.len, pkt.ptr + 12, &buf, 256);
    try std.testing.expect(r > 0);
    try std.testing.expectEqualStrings("www.example.com", std.mem.sliceTo(&buf, 0));

    // Compressed name: pointer at offset 0 back to header+12
    const pkt2 = "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00" ++
        "\x03www\x07example\x03com\x00" ++
        "\xc0\x0c"; // pointer to offset 12
    var buf2: [256]u8 = undefined;
    const r2 = __dn_expand_impl(pkt2, pkt2.ptr + pkt2.len, pkt2.ptr + pkt2.len - 2, &buf2, 256);
    try std.testing.expect(r2 == 2); // consumed 2 bytes (the pointer)
    try std.testing.expectEqualStrings("www.example.com", std.mem.sliceTo(&buf2, 0));
}
