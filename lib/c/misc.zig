const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC() or builtin.target.isWasiLibC()) {
        symbol(&getsubopt, "getsubopt");
    }
}

fn getsubopt(opt: *[*:0]u8, keys: [*:null]const ?[*:0]const u8, val: *?[*:0]u8) callconv(.c) c_int {
    const s: [*:0]u8 = opt.*;
    val.* = null;

    // Find the comma or end of string.
    var end: usize = 0;
    while (s[end] != 0 and s[end] != ',') : (end += 1) {}

    if (s[end] == ',') {
        s[end] = 0;
        opt.* = @ptrCast(s + end + 1);
    } else {
        opt.* = @ptrCast(s + end);
    }

    // Search for matching key.
    var i: c_int = 0;
    while (keys[@intCast(i)]) |key| : (i += 1) {
        var l: usize = 0;
        while (key[l] != 0) : (l += 1) {}
        if (l == 0) continue;

        // Compare key with beginning of s.
        var match = true;
        for (0..l) |j| {
            if (s[j] != key[j]) {
                match = false;
                break;
            }
        }
        if (!match) continue;

        if (s[l] == '=') {
            val.* = @ptrCast(s + l + 1);
        } else if (s[l] != 0) {
            continue;
        }
        return i;
    }
    return -1;
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&getpriorityLinux, "getpriority");
        symbol(&setpriorityLinux, "setpriority");
        symbol(&getresuidLinux, "getresuid");
        symbol(&getresgidLinux, "getresgid");
        symbol(&setdomainnameLinux, "setdomainname");
    }
}

fn getpriorityLinux(which: c_int, who: c_uint) callconv(.c) c_int {
    const rc = errno(linux.syscall2(.getpriority, @as(usize, @bitCast(@as(isize, which))), @as(usize, who)));
    if (rc < 0) return rc;
    return 20 - rc;
}

fn setpriorityLinux(which: c_int, who: c_uint, prio: c_int) callconv(.c) c_int {
    return errno(linux.syscall3(.setpriority, @as(usize, @bitCast(@as(isize, which))), @as(usize, who), @as(usize, @bitCast(@as(isize, prio)))));
}

fn getresuidLinux(ruid: *linux.uid_t, euid: *linux.uid_t, suid: *linux.uid_t) callconv(.c) c_int {
    return errno(linux.getresuid(ruid, euid, suid));
}

fn getresgidLinux(rgid: *linux.gid_t, egid: *linux.gid_t, sgid: *linux.gid_t) callconv(.c) c_int {
    return errno(linux.getresgid(rgid, egid, sgid));
}

fn setdomainnameLinux(name: [*]const u8, len: usize) callconv(.c) c_int {
    return errno(linux.syscall2(.setdomainname, @intFromPtr(name), len));
}
