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