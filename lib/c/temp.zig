const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&mkostempsLinux, "__mkostemps");
        symbol(&mkostempsLinux, "mkostemps");
        symbol(&mkstempLinux, "mkstemp");
        symbol(&mkostempLinux, "mkostemp");
        symbol(&mkstempsLinux, "mkstemps");
        symbol(&mkdtempLinux, "mkdtemp");
        symbol(&mktempLinux, "mktemp");
    }
}

/// Generate 6 pseudo-random characters to replace the XXXXXX template suffix.
fn randname(template: [*]u8) void {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.REALTIME, &ts);
    var r: usize = @bitCast(ts.sec +% ts.nsec +% @as(isize, linux.gettid()) *% 65537);
    for (0..6) |i| {
        template[i] = @intCast(@as(u8, 'A') + @as(u8, @truncate(r & 15)) + @as(u8, @truncate((r & 16) * 2)));
        r >>= 5;
    }
}

fn mkostempsLinux(template: [*:0]u8, len: c_int, flags: c_int) callconv(.c) c_int {
    // Find the length of the template string.
    var l: usize = 0;
    while (template[l] != 0) : (l += 1) {}

    const ulen: usize = if (len < 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    } else @intCast(len);

    if (l < 6 or ulen > l - 6 or !std.mem.eql(u8, template[l - ulen - 6 .. l - ulen], "XXXXXX")) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }

    var o: linux.O = @bitCast(@as(u32, @bitCast(flags)));
    o.ACCMODE = .RDWR;
    o.CREAT = true;
    o.EXCL = true;

    var retries: u32 = 100;
    while (retries > 0) : (retries -= 1) {
        randname(template + l - ulen - 6);
        const rc: isize = @bitCast(linux.open(template, o, 0o600));
        if (rc >= 0) return @intCast(rc);
        if (-rc != @intFromEnum(linux.E.EXIST)) {
            std.c._errno().* = @intCast(-rc);
            break;
        }
    }

    @memcpy(template[l - ulen - 6 .. l - ulen], "XXXXXX");
    return -1;
}

fn mkstempLinux(template: [*:0]u8) callconv(.c) c_int {
    return mkostempsLinux(template, 0, 0);
}

fn mkostempLinux(template: [*:0]u8, flags: c_int) callconv(.c) c_int {
    return mkostempsLinux(template, 0, flags);
}

fn mkstempsLinux(template: [*:0]u8, len: c_int) callconv(.c) c_int {
    return mkostempsLinux(template, len, 0);
}

fn mkdtempLinux(template: [*:0]u8) callconv(.c) ?[*:0]u8 {
    var l: usize = 0;
    while (template[l] != 0) : (l += 1) {}

    if (l < 6 or !std.mem.eql(u8, template[l - 6 .. l], "XXXXXX")) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return null;
    }

    var retries: u32 = 100;
    while (retries > 0) : (retries -= 1) {
        randname(template + l - 6);
        const rc: isize = @bitCast(linux.mkdir(template, 0o700));
        if (rc == 0) return template;
        if (-rc != @intFromEnum(linux.E.EXIST)) {
            std.c._errno().* = @intCast(-rc);
            break;
        }
    }

    @memcpy(template[l - 6 .. l], "XXXXXX");
    return null;
}

fn mktempLinux(template: [*:0]u8) callconv(.c) [*:0]u8 {
    var l: usize = 0;
    while (template[l] != 0) : (l += 1) {}

    if (l < 6 or !std.mem.eql(u8, template[l - 6 .. l], "XXXXXX")) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        template[0] = 0;
        return template;
    }

    var retries: u32 = 100;
    while (retries > 0) : (retries -= 1) {
        randname(template + l - 6);
        // Check if the file exists using faccessat with F_OK (mode=0).
        const rc: isize = @bitCast(linux.faccessat(linux.AT.FDCWD, template, 0, 0));
        if (rc < 0) {
            // File doesn't exist (ENOENT) — success.
            if (-rc == @intFromEnum(linux.E.NOENT)) return template;
            // Other error — fail.
            template[0] = 0;
            return template;
        }
        // File exists, retry with a different name.
    }

    template[0] = 0;
    std.c._errno().* = @intFromEnum(linux.E.EXIST);
    return template;
}
