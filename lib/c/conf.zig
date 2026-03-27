const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&confstr, "confstr");
    }
}

const _CS_POSIX_V6_ILP32_OFF32_CFLAGS = 1116;

fn confstr(name: c_int, buf: ?[*]u8, len: usize) callconv(.c) usize {
    const s: [*:0]const u8 = if (name == 0)
        "/bin:/usr/bin"
    else if ((@as(c_uint, @bitCast(name)) & ~@as(c_uint, 4)) != 1 and
        @as(c_uint, @bitCast(name -% _CS_POSIX_V6_ILP32_OFF32_CFLAGS)) > 35)
    {
        if (builtin.os.tag == .linux)
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return 0;
    } else
        "";

    // Find length of s.
    var slen: usize = 0;
    while (s[slen] != 0) : (slen += 1) {}

    // Copy with truncation.
    if (buf) |b| {
        if (len > 0) {
            const copy_len = if (slen < len - 1) slen else len - 1;
            @memcpy(b[0..copy_len], s[0..copy_len]);
            b[copy_len] = 0;
        }
    }
    return slen + 1;
}
