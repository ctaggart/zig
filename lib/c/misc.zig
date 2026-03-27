const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&lockf, "lockf");
        symbol(&ptsname, "ptsname");
    }
}

// lockf command constants
const F_ULOCK = 0;
const F_LOCK = 1;
const F_TLOCK = 2;
const F_TEST = 3;

// fcntl commands
const F_GETLK = 5;
const F_SETLK = 6;
const F_SETLKW = 7;

// flock types
const F_RDLCK: c_short = 0;
const F_WRLCK: c_short = 1;
const F_UNLCK: c_short = 2;

const SEEK_CUR: c_short = 1;

const flock = extern struct {
    l_type: c_short,
    l_whence: c_short,
    l_start: i64,
    l_len: i64,
    l_pid: c_int,
};

extern "c" fn fcntl(fd: c_int, cmd: c_int, ...) c_int;
extern "c" fn getpid() c_int;

fn lockf(fd: c_int, op: c_int, size: i64) callconv(.c) c_int {
    var l = flock{
        .l_type = F_WRLCK,
        .l_whence = SEEK_CUR,
        .l_start = 0,
        .l_len = size,
        .l_pid = 0,
    };
    switch (op) {
        F_TEST => {
            l.l_type = F_RDLCK;
            if (fcntl(fd, F_GETLK, &l) < 0) return -1;
            if (l.l_type == F_UNLCK or l.l_pid == getpid()) return 0;
            std.c._errno().* = @intFromEnum(linux.E.ACCES);
            return -1;
        },
        F_ULOCK => {
            l.l_type = F_UNLCK;
            return fcntl(fd, F_SETLK, &l);
        },
        F_TLOCK => return fcntl(fd, F_SETLK, &l),
        F_LOCK => return fcntl(fd, F_SETLKW, &l),
        else => {
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
            return -1;
        },
    }
}

extern "c" fn __ptsname_r(fd: c_int, buf: [*]u8, len: usize) c_int;

var ptsname_buf: [9 + @sizeOf(c_int) * 3 + 1]u8 = undefined;

fn ptsname(fd: c_int) callconv(.c) ?[*:0]u8 {
    const err = __ptsname_r(fd, &ptsname_buf, ptsname_buf.len);
    if (err != 0) {
        std.c._errno().* = err;
        return null;
    }
    // Find the null terminator to create a sentinel-terminated pointer.
    for (&ptsname_buf, 0..) |*c, i| {
        if (c.* == 0) return ptsname_buf[0..i :0];
    }
    return null;
}
