const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        // Direct syscall wrappers (no libc deps)
        symbol(&mkdirLinux, "mkdir");
        symbol(&mkdiratLinux, "mkdirat");
        symbol(&mknodLinux, "mknod");
        symbol(&mknodatLinux, "mknodat");
        symbol(&mkfifoLinux, "mkfifo");
        symbol(&mkfifoatLinux, "mkfifoat");
        symbol(&umaskLinux, "umask");
        symbol(&chmodLinux, "chmod");

        // Thin wrappers that call other libc functions at link time
        if (builtin.link_libc) {
            symbol(&statLinux, "stat");
            symbol(&lstatLinux, "lstat");
            symbol(&fstatLinux, "__fstat");
            symbol(&fstatLinux, "fstat");
            symbol(&futimensLinux, "futimens");
            symbol(&lchmodLinux, "lchmod");
        }
    }
}

// --- Direct syscall wrappers ---

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

// --- Thin wrappers that call libc functions at link time ---
// These delegate to fstatat/utimensat/fchmodat which are still
// provided by the remaining C source files.

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
    if (fd < 0) {
        std.c._errno().* = @intFromEnum(linux.E.BADF);
        return -1;
    }
    return fstatat(fd, "", buf, linux.AT.EMPTY_PATH);
}

fn futimensLinux(fd: c_int, times: ?*const [2]linux.timespec) callconv(.c) c_int {
    return utimensat(fd, null, times, 0);
}

fn lchmodLinux(path: [*:0]const u8, mode: linux.mode_t) callconv(.c) c_int {
    return fchmodat(linux.AT.FDCWD, path, mode, linux.AT.SYMLINK_NOFOLLOW);
}
