const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&fpathconf, "fpathconf");
        symbol(&pathconf, "pathconf");
        symbol(&confstr, "confstr");
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

/// _CS_POSIX_V6_ILP32_OFF32_CFLAGS value in musl
const CS_POSIX_V6_BASE: c_int = 1116;

fn confstr(name: c_int, buf: ?[*]u8, len: usize) callconv(.c) usize {
    const s: [*:0]const u8 = blk: {
        if (name == 0) break :blk "/bin:/usr/bin";
        if ((name & ~@as(c_int, 4)) == 1) break :blk "";
        if (name >= CS_POSIX_V6_BASE and name - CS_POSIX_V6_BASE <= 35) break :blk "";
        std.c._errno().* = @intFromEnum(std.os.linux.E.INVAL);
        return 0;
    };
    // Replicate snprintf(buf, len, "%s", s) + 1 behavior
    var slen: usize = 0;
    while (s[slen] != 0) slen += 1;
    if (buf) |b| {
        if (len > 0) {
            const copy = @min(slen, len - 1);
            @memcpy(b[0..copy], s[0..copy]);
            b[copy] = 0;
        }
    }
    return slen + 1;
}
