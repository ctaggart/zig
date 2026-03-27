const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&fpathconf, "fpathconf");
        symbol(&pathconf, "pathconf");
    }
}

// POSIX pathconf values (architecture-independent)
const values = [21]c_short{
    8,    // _PC_LINK_MAX = _POSIX_LINK_MAX
    255,  // _PC_MAX_CANON = _POSIX_MAX_CANON
    255,  // _PC_MAX_INPUT = _POSIX_MAX_INPUT
    255,  // _PC_NAME_MAX = NAME_MAX
    4096, // _PC_PATH_MAX = PATH_MAX
    4096, // _PC_PIPE_BUF = PIPE_BUF
    1,    // _PC_CHOWN_RESTRICTED
    1,    // _PC_NO_TRUNC
    0,    // _PC_VDISABLE
    1,    // _PC_SYNC_IO
    -1,   // _PC_ASYNC_IO
    -1,   // _PC_PRIO_IO
    -1,   // _PC_SOCK_MAXBUF
    64,   // _PC_FILESIZEBITS = FILESIZEBITS
    4096, // _PC_REC_INCR_XFER_SIZE
    4096, // _PC_REC_MAX_XFER_SIZE
    4096, // _PC_REC_MIN_XFER_SIZE
    4096, // _PC_REC_XFER_ALIGN
    4096, // _PC_ALLOC_SIZE_MIN
    -1,   // _PC_SYMLINK_MAX
    1,    // _PC_2_SYMLINKS
};

fn fpathconf(fd: c_int, name: c_int) callconv(.c) c_long {
    _ = fd;
    if (name < 0 or name >= values.len) {
        std.c._errno().* = @intFromEnum(std.os.linux.E.INVAL);
        return -1;
    }
    return values[@intCast(name)];
}

fn pathconf(path: [*:0]const u8, name: c_int) callconv(.c) c_long {
    _ = path;
    return fpathconf(-1, name);
}
