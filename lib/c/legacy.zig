const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&euidaccessLinux, "euidaccess");
        symbol(&euidaccessLinux, "eaccess");
        symbol(&isastreamLinux, "isastream");
        symbol(&getdtablesizeLinux, "getdtablesize");
        symbol(&getloadavgLinux, "getloadavg");
        // utmpx stubs
        symbol(&endutxent, "endutxent");
        symbol(&endutxent, "endutent");
        symbol(&setutxent, "setutxent");
        symbol(&setutxent, "setutent");
        symbol(&getutxent, "getutxent");
        symbol(&getutxent, "getutent");
        symbol(&getutxid, "getutxid");
        symbol(&getutxid, "getutid");
        symbol(&getutxline, "getutxline");
        symbol(&getutxline, "getutline");
        symbol(&pututxline, "pututxline");
        symbol(&pututxline, "pututline");
        symbol(&updwtmpx, "updwtmpx");
        symbol(&updwtmpx, "updwtmp");
        symbol(&utmpxname, "utmpxname");
        symbol(&utmpxname, "utmpname");

        if (builtin.link_libc) {
            symbol(&futimes, "futimes");
            symbol(&lutimes, "lutimes");
        }
    }
}

/// AT_EACCESS for faccessat — check using effective user/group IDs.
const AT_EACCESS: u32 = 0x200;

fn euidaccessLinux(path: [*:0]const u8, amode: c_int) callconv(.c) c_int {
    return errno(linux.faccessat(linux.AT.FDCWD, path, @bitCast(amode), AT_EACCESS));
}

fn isastreamLinux(fd: c_int) callconv(.c) c_int {
    const rc: isize = @bitCast(linux.fcntl(fd, linux.F.GETFD, 0));
    if (rc < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-rc);
        return -1;
    }
    return 0;
}

fn getdtablesizeLinux() callconv(.c) c_int {
    var rl: linux.rlimit = undefined;
    const rc: isize = @bitCast(linux.getrlimit(.NOFILE, &rl));
    if (rc < 0) return std.math.maxInt(c_int);
    return if (rl.rlim_cur < std.math.maxInt(c_int))
        @intCast(rl.rlim_cur)
    else
        std.math.maxInt(c_int);
}

const SI_LOAD_SHIFT = 16;

fn getloadavgLinux(a: [*]f64, n_arg: c_int) callconv(.c) c_int {
    if (n_arg <= 0) return if (n_arg != 0) @as(c_int, -1) else 0;
    var si: linux.Sysinfo = undefined;
    const rc: isize = @bitCast(linux.sysinfo(&si));
    if (rc < 0) return -1;
    const n: usize = @intCast(@min(n_arg, 3));
    const scale = 1.0 / @as(f64, @floatFromInt(@as(u32, 1) << SI_LOAD_SHIFT));
    for (0..n) |i| {
        a[i] = scale * @as(f64, @floatFromInt(si.loads[i]));
    }
    return @intCast(n);
}

// --- utmpx stubs ---

fn endutxent() callconv(.c) void {}
fn setutxent() callconv(.c) void {}
fn getutxent() callconv(.c) ?*anyopaque { return null; }
fn getutxid(ut: ?*const anyopaque) callconv(.c) ?*anyopaque { _ = ut; return null; }
fn getutxline(ut: ?*const anyopaque) callconv(.c) ?*anyopaque { _ = ut; return null; }
fn pututxline(ut: ?*const anyopaque) callconv(.c) ?*anyopaque { _ = ut; return null; }
fn updwtmpx(f: ?[*:0]const u8, u: ?*const anyopaque) callconv(.c) void { _ = f; _ = u; }
fn utmpxname(f: ?[*:0]const u8) callconv(.c) c_int {
    _ = f;
    std.c._errno().* = @intFromEnum(linux.E.NOTSUP);
    return -1;
}

// --- futimes/lutimes (timeval → timespec conversion) ---

const timeval = extern struct {
    tv_sec: isize,
    tv_usec: isize,
};

extern "c" fn futimens(fd: c_int, times: ?*const [2]linux.timespec) c_int;
extern "c" fn utimensat(fd: c_int, path: ?[*:0]const u8, times: ?*const [2]linux.timespec, flags: c_int) c_int;

fn futimes(fd: c_int, tv: ?*const [2]timeval) callconv(.c) c_int {
    if (tv == null) return futimens(fd, null);
    const times = [2]linux.timespec{
        .{ .sec = tv.?[0].tv_sec, .nsec = tv.?[0].tv_usec * 1000 },
        .{ .sec = tv.?[1].tv_sec, .nsec = tv.?[1].tv_usec * 1000 },
    };
    return futimens(fd, &times);
}

fn lutimes(filename: [*:0]const u8, tv: ?*const [2]timeval) callconv(.c) c_int {
    if (tv == null) return utimensat(linux.AT.FDCWD, filename, null, linux.AT.SYMLINK_NOFOLLOW);
    const times = [2]linux.timespec{
        .{ .sec = tv.?[0].tv_sec, .nsec = tv.?[0].tv_usec * 1000 },
        .{ .sec = tv.?[1].tv_sec, .nsec = tv.?[1].tv_usec * 1000 },
    };
    return utimensat(linux.AT.FDCWD, filename, &times, linux.AT.SYMLINK_NOFOLLOW);
}
