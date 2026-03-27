const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&ulimitLinux, "ulimit");
    }
    if (builtin.link_libc) {
        symbol(&ftw, "ftw");
    }
}

const UL_SETFSIZE = 2;

fn ulimitLinux(cmd: c_int, ...) callconv(.c) c_long {
    var rl: linux.rlimit = undefined;
    _ = linux.getrlimit(.FSIZE, &rl);
    if (cmd == UL_SETFSIZE) {
        var ap = @cVaStart();
        const val = @cVaArg(&ap, c_long);
        @cVaEnd(&ap);
        rl.cur = @as(u64, 512) * @as(u64, @intCast(val));
        if (errno(linux.setrlimit(.FSIZE, &rl)) < 0) return -1;
    }
    return if (rl.cur / 512 > std.math.maxInt(c_long)) std.math.maxInt(c_long) else @intCast(rl.cur / 512);
}

const FTW_PHYS = 1;

extern "c" fn nftw(
    path: [*:0]const u8,
    func: *const anyopaque,
    fd_limit: c_int,
    flags: c_int,
) c_int;

fn ftw(
    path: [*:0]const u8,
    func: *const anyopaque,
    fd_limit: c_int,
) callconv(.c) c_int {
    return nftw(path, func, fd_limit, FTW_PHYS);
}
