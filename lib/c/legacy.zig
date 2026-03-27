const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&getpagesize, "getpagesize");
        symbol(&getdtablesizeLinux, "getdtablesize");
        symbol(&isastreamLinux, "isastream");
        symbol(&euidaccessLinux, "euidaccess");
        symbol(&euidaccessLinux, "eaccess");
    }
    if (builtin.target.isWasiLibC()) {
        symbol(&getpagesize, "getpagesize");
    }
}

fn getpagesize() callconv(.c) c_int {
    return std.heap.page_size_min;
}

fn getdtablesizeLinux() callconv(.c) c_int {
    var rl: linux.rlimit = undefined;
    _ = linux.getrlimit(.NOFILE, &rl);
    return if (rl.cur < std.math.maxInt(c_int)) @intCast(rl.cur) else std.math.maxInt(c_int);
}

fn isastreamLinux(fd: c_int) callconv(.c) c_int {
    const F_GETFD = 1;
    const rc: isize = @bitCast(linux.fcntl(fd, F_GETFD, 0));
    return if (rc < 0) -1 else 0;
}

fn euidaccessLinux(path: [*:0]const u8, amode: c_uint) callconv(.c) c_int {
    const AT_EACCESS = 0x200;
    return errno(linux.faccessat(linux.AT.FDCWD, path, amode, AT_EACCESS));
}
