const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&mkdirLinux, "mkdir");
        symbol(&mkdiratLinux, "mkdirat");
        symbol(&mknodLinux, "mknod");
        symbol(&mknodatLinux, "mknodat");
        symbol(&mkfifoLinux, "mkfifo");
        symbol(&mkfifoatLinux, "mkfifoat");
        symbol(&umaskLinux, "umask");
        symbol(&chmodLinux, "chmod");
        if (builtin.link_libc) {
            symbol(&statLinux, "stat");
            symbol(&lstatLinux, "lstat");
            symbol(&fstatLinux, "__fstat");
            symbol(&fstatLinux, "fstat");
            symbol(&futimensLinux, "futimens");
            symbol(&lchmodLinux, "lchmod");
            symbol(&__futimesat, "__futimesat");
            symbol(&__futimesat, "futimesat");
            symbol(&__fxstat, "__fxstat");
            symbol(&__fxstatat, "__fxstatat");
            symbol(&__lxstat, "__lxstat");
            symbol(&__xstat_fn, "__xstat");
            symbol(&__xmknod, "__xmknod");
            symbol(&__xmknodat, "__xmknodat");
        }
    }
}

fn mkdirLinux(path: [*:0]const u8, mode: linux.mode_t) callconv(.c) c_int {
    return errno(linux.mkdirat(linux.AT.FDCWD, path, mode));
}
fn mkdiratLinux(fd: c_int, path: [*:0]const u8, mode: linux.mode_t) callconv(.c) c_int {
    return errno(linux.mkdirat(fd, path, mode));
}
fn mknodLinux(path: [*:0]const u8, mode: linux.mode_t, dev: linux.dev_t) callconv(.c) c_int {
    return errno(linux.mknodat(linux.AT.FDCWD, path, mode, @truncate(dev)));
}
fn mknodatLinux(fd: c_int, path: [*:0]const u8, mode: linux.mode_t, dev: linux.dev_t) callconv(.c) c_int {
    return errno(linux.mknodat(fd, path, mode, @truncate(dev)));
}
fn mkfifoLinux(path: [*:0]const u8, mode: linux.mode_t) callconv(.c) c_int {
    return errno(linux.mknodat(linux.AT.FDCWD, path, mode | linux.S.IFIFO, 0));
}
fn mkfifoatLinux(fd: c_int, path: [*:0]const u8, mode: linux.mode_t) callconv(.c) c_int {
    return errno(linux.mknodat(fd, path, mode | linux.S.IFIFO, 0));
}
fn umaskLinux(mode: linux.mode_t) callconv(.c) linux.mode_t {
    return @truncate(linux.syscall1(.umask, mode));
}
fn chmodLinux(path: [*:0]const u8, mode: linux.mode_t) callconv(.c) c_int {
    return errno(linux.fchmodat(linux.AT.FDCWD, path, mode));
}

extern "c" fn fstatat(fd: c_int, path: [*:0]const u8, buf: *anyopaque, flag: c_int) c_int;
extern "c" fn utimensat(fd: c_int, path: ?[*:0]const u8, times: ?*const [2]linux.timespec, flags: c_int) c_int;
extern "c" fn fchmodat(fd: c_int, path: [*:0]const u8, mode: linux.mode_t, flag: c_int) c_int;

fn statLinux(noalias path: [*:0]const u8, noalias buf: *anyopaque) callconv(.c) c_int {
    return fstatat(linux.AT.FDCWD, path, buf, 0);
}
fn lstatLinux(noalias path: [*:0]const u8, noalias buf: *anyopaque) callconv(.c) c_int {
    return fstatat(linux.AT.FDCWD, path, buf, linux.AT.SYMLINK_NOFOLLOW);
}
fn fstatLinux(fd: c_int, buf: *anyopaque) callconv(.c) c_int {
    if (fd < 0) { std.c._errno().* = @intFromEnum(linux.E.BADF); return -1; }
    return fstatat(fd, "", buf, linux.AT.EMPTY_PATH);
}
fn futimensLinux(fd: c_int, times: ?*const [2]linux.timespec) callconv(.c) c_int {
    return utimensat(fd, null, times, 0);
}
fn lchmodLinux(path: [*:0]const u8, mode: linux.mode_t) callconv(.c) c_int {
    return fchmodat(linux.AT.FDCWD, path, mode, linux.AT.SYMLINK_NOFOLLOW);
}

const timeval = extern struct { tv_sec: isize, tv_usec: isize };

fn __futimesat(dirfd: c_int, pathname: ?[*:0]const u8, times: ?*const [2]timeval) callconv(.c) c_int {
    if (times) |tv| {
        if (tv[0].tv_usec >= 1000000 or tv[1].tv_usec >= 1000000) {
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
            return -1;
        }
        const ts = [2]linux.timespec{
            .{ .sec = tv[0].tv_sec, .nsec = tv[0].tv_usec * 1000 },
            .{ .sec = tv[1].tv_sec, .nsec = tv[1].tv_usec * 1000 },
        };
        return utimensat(dirfd, pathname, &ts, 0);
    }
    return utimensat(dirfd, pathname, null, 0);
}

fn __fxstat(ver: c_int, fd: c_int, buf: *anyopaque) callconv(.c) c_int {
    _ = ver;
    if (fd < 0) { std.c._errno().* = @intFromEnum(linux.E.BADF); return -1; }
    return fstatat(fd, "", buf, linux.AT.EMPTY_PATH);
}
fn __fxstatat(ver: c_int, fd: c_int, path: [*:0]const u8, buf: *anyopaque, flag: c_int) callconv(.c) c_int {
    _ = ver; return fstatat(fd, path, buf, flag);
}
fn __lxstat(ver: c_int, path: [*:0]const u8, buf: *anyopaque) callconv(.c) c_int {
    _ = ver; return fstatat(linux.AT.FDCWD, path, buf, linux.AT.SYMLINK_NOFOLLOW);
}
fn __xstat_fn(ver: c_int, path: [*:0]const u8, buf: *anyopaque) callconv(.c) c_int {
    _ = ver; return fstatat(linux.AT.FDCWD, path, buf, 0);
}
fn __xmknod(ver: c_int, path: [*:0]const u8, mode: linux.mode_t, dev: *const linux.dev_t) callconv(.c) c_int {
    _ = ver; return mknodLinux(path, mode, dev.*);
}
fn __xmknodat(ver: c_int, fd: c_int, path: [*:0]const u8, mode: linux.mode_t, dev: *const linux.dev_t) callconv(.c) c_int {
    _ = ver; return mknodatLinux(fd, path, mode, dev.*);
}
