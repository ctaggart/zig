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
        symbol(&gethostid, "gethostid");
        symbol(&getdomainnameLinux, "getdomainname");
        symbol(&getrlimitLinux, "getrlimit");
        symbol(&setrlimitLinux, "setrlimit");
    }
    if (builtin.target.isWasiLibC()) {
        symbol(&gethostid, "gethostid");
    }
}

fn gethostid() callconv(.c) c_long {
    return 0;
}

fn getdomainnameLinux(name: [*]u8, len: usize) callconv(.c) c_int {
    var uts: linux.utsname = undefined;
    const rc: isize = @bitCast(linux.uname(&uts));
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&login_ttyLinux, "login_tty");
    }
    if (builtin.link_libc) {
        symbol(&initgroups, "initgroups");
    }
}

fn login_ttyLinux(fd: c_int) callconv(.c) c_int {
    _ = linux.setsid();
    const rc: isize = @bitCast(linux.ioctl(@intCast(fd), linux.T.IOCSCTTY, 0));
    if (rc < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-rc);
        return -1;
    }
    const domain = std.mem.sliceTo(&uts.domainname, 0);
    if (len == 0 or domain.len >= len) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    @memcpy(name[0..domain.len], domain);
    name[domain.len] = 0;
    return 0;
}

fn getrlimitLinux(resource: c_int, rlim: *linux.rlimit) callconv(.c) c_int {
    return errno(linux.getrlimit(@enumFromInt(resource), rlim));
}

fn setrlimitLinux(resource: c_int, rlim: *const linux.rlimit) callconv(.c) c_int {
    return errno(linux.setrlimit(@enumFromInt(resource), rlim));
        symbol(&basename, "basename");
        symbol(&basename, "__xpg_basename");
        symbol(&dirname, "dirname");
        symbol(&a64l, "a64l");
        symbol(&l64a, "l64a");
    }
}

fn basename(s: ?[*:0]u8) callconv(.c) [*:0]const u8 {
    const str = s orelse return ".";
    if (str[0] == 0) return ".";

    // Find end of string.
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    i -= 1;

    // Strip trailing slashes.
    while (i > 0 and str[i] == '/') : (i -= 1) {
        str[i] = 0;
    }
    if (i == 0 and str[0] == '/') return str[0..1 :0];

    // Find last slash.
    while (i > 0 and str[i - 1] != '/') : (i -= 1) {}

    return @ptrCast(str + i);
}

fn dirname(s: ?[*:0]u8) callconv(.c) [*:0]const u8 {
    const str = s orelse return ".";
    if (str[0] == 0) return ".";

    // Find end of string.
    var i: usize = 0;
    while (str[i] != 0) : (i += 1) {}
    i -= 1;

    // Strip trailing slashes.
    while (str[i] == '/') {
        if (i == 0) return "/";
        i -= 1;
    }
    // Strip trailing component.
    while (str[i] != '/') {
        if (i == 0) return ".";
        i -= 1;
    }
    // Strip trailing slashes again.
    while (str[i] == '/') {
        if (i == 0) return "/";
        i -= 1;
    }

    str[i + 1] = 0;
    return @ptrCast(str);
}

const digits = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

fn a64l(str: [*:0]const u8) callconv(.c) c_long {
    var x: u32 = 0;
    var e: u5 = 0;
    var p = str;
    while (e < 36 and p[0] != 0) : ({
        e += 6;
        p += 1;
    }) {
        const c = p[0];
        const d: u32 = for (digits, 0..) |ch, idx| {
            if (ch == c) break @intCast(idx);
        } else break;
        x |= d << e;
    }
    return @as(c_long, @as(i32, @bitCast(x)));
}

var l64a_buf: [7]u8 = undefined;

fn l64a(x0: c_long) callconv(.c) [*:0]u8 {
    var x: u32 = @bitCast(@as(c_int, @intCast(x0)));
    var i: usize = 0;
    while (x != 0 and i < 6) : (i += 1) {
        l64a_buf[i] = digits[x & 63];
        x >>= 6;
    }
    l64a_buf[i] = 0;
    return l64a_buf[0..i :0];
}
        symbol(&getrusageLinux, "getrusage");
        symbol(&getentropyLinux, "getentropy");
    }
}

fn getrusageLinux(who: c_int, usage: *linux.rusage) callconv(.c) c_int {
    return errno(linux.getrusage(who, usage));
}

fn getentropyLinux(buffer: [*]u8, len: usize) callconv(.c) c_int {
    if (len > 256) {
        std.c._errno().* = @intFromEnum(linux.E.IO);
        return -1;
    }
    var pos: usize = 0;
    while (pos < len) {
        const rc: isize = @bitCast(linux.getrandom(buffer + pos, len - pos, 0));
        if (rc < 0) {
            @branchHint(.unlikely);
            if (-rc == @intFromEnum(linux.E.INTR)) continue;
            std.c._errno().* = @intCast(-rc);
            return -1;
        }
        pos += @intCast(rc);
    }
    return 0;
    _ = linux.dup2(fd, 0);
    _ = linux.dup2(fd, 1);
    _ = linux.dup2(fd, 2);
    if (fd > 2) _ = linux.close(fd);
    return 0;
}

const NGROUPS_MAX = 32;

extern "c" fn getgrouplist(user: [*:0]const u8, group: linux.gid_t, groups: [*]linux.gid_t, ngroups: *c_int) c_int;
extern "c" fn setgroups(size: usize, list: [*]const linux.gid_t) c_int;

fn initgroups(user: [*:0]const u8, gid: linux.gid_t) callconv(.c) c_int {
    var groups: [NGROUPS_MAX]linux.gid_t = undefined;
    var count: c_int = NGROUPS_MAX;
    if (getgrouplist(user, gid, &groups, &count) < 0) return -1;
    return setgroups(@intCast(count), &groups);
}
