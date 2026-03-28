const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&if_nametoindex_impl, "if_nametoindex");
        symbol(&if_indextoname_impl, "if_indextoname");
    }
}

fn if_nametoindex_impl(name: [*:0]const u8) callconv(.c) c_uint {
    const fd = openDgramSocket() orelse return 0;
    defer _ = linux.close(fd);

    var ifr: linux.ifreq = std.mem.zeroes(linux.ifreq);
    copyName(&ifr.ifrn.name, name);

    const r: isize = @bitCast(linux.ioctl(fd, linux.SIOCGIFINDEX, @intFromPtr(&ifr)));
    if (r < 0) return 0;
    return @intCast(ifr.ifru.ivalue);
}

fn if_indextoname_impl(index: c_uint, name: [*]u8) callconv(.c) ?[*]u8 {
    const fd = openDgramSocket() orelse return null;
    defer _ = linux.close(fd);

    var ifr: linux.ifreq = std.mem.zeroes(linux.ifreq);
    ifr.ifru = .{ .ivalue = @intCast(index) };

    const r: isize = @bitCast(linux.ioctl(fd, linux.SIOCGIFNAME, @intFromPtr(&ifr)));
    if (r < 0) {
        const err: c_int = @intCast(-r);
        // Map ENODEV to ENXIO per POSIX
        setErrno(if (err == @intFromEnum(linux.E.NODEV)) @intFromEnum(linux.E.NXIO) else err);
        return null;
    }

    // Copy the name from ifreq to caller's buffer
    const src = &ifr.ifrn.name;
    const len = std.mem.indexOfScalar(u8, src, 0) orelse linux.IFNAMESIZE;
    @memcpy(name[0..len], src[0..len]);
    if (len < linux.IFNAMESIZE) name[len] = 0;
    return name;
}

fn openDgramSocket() ?i32 {
    const r: isize = @bitCast(linux.socket(linux.AF.UNIX, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC, 0));
    if (r < 0) return null;
    return @intCast(r);
}

fn copyName(dest: *[linux.IFNAMESIZE]u8, src: [*:0]const u8) void {
    var i: usize = 0;
    while (i < linux.IFNAMESIZE - 1 and src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }
    dest[i] = 0;
}

fn setErrno(val: c_int) void {
    if (builtin.link_libc) {
        std.c._errno().* = val;
    }
}
