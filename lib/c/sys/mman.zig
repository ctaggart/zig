const builtin = @import("builtin");

const std = @import("std");

const symbol = @import("../../c.zig").symbol;
const errno = @import("../../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&madviseLinux, "madvise");
        symbol(&madviseLinux, "__madvise");

        symbol(&mincoreLinux, "mincore");

        symbol(&mlockLinux, "mlock");
        symbol(&mlockallLinux, "mlockall");

        symbol(&mprotectLinux, "mprotect");
        symbol(&mprotectLinux, "__mprotect");

        symbol(&munlockLinux, "munlock");
        symbol(&munlockallLinux, "munlockall");

        symbol(&posix_madviseLinux, "posix_madvise");

        symbol(&mmapLinux, "mmap");
        symbol(&mmapLinux, "__mmap");
        symbol(&mremapLinux, "mremap");
        symbol(&mremapLinux, "__mremap");
    }
}

fn madviseLinux(addr: *anyopaque, len: usize, advice: c_int) callconv(.c) c_int {
    return errno(std.os.linux.madvise(@ptrCast(addr), len, @bitCast(advice)));
}

fn mincoreLinux(addr: *anyopaque, len: usize, vec: [*]u8) callconv(.c) c_int {
    return errno(std.os.linux.mincore(@ptrCast(addr), len, vec));
}

fn mlockLinux(addr: *const anyopaque, len: usize) callconv(.c) c_int {
    return errno(std.os.linux.mlock(@ptrCast(addr), len));
}

fn mlockallLinux(flags: c_int) callconv(.c) c_int {
    return errno(std.os.linux.mlockall(@bitCast(flags)));
}

fn mprotectLinux(addr: *anyopaque, len: usize, prot: c_int) callconv(.c) c_int {
    const page_size = std.heap.pageSize();
    const start = std.mem.alignBackward(usize, @intFromPtr(addr), page_size);
    const aligned_len = std.mem.alignForward(usize, len, page_size);
    return errno(std.os.linux.mprotect(@ptrFromInt(start), aligned_len, @bitCast(prot)));
}

fn munlockLinux(addr: *const anyopaque, len: usize) callconv(.c) c_int {
    return errno(std.os.linux.munlock(@ptrCast(addr), len));
}

fn munlockallLinux() callconv(.c) c_int {
    return errno(std.os.linux.munlockall());
}

fn posix_madviseLinux(addr: *anyopaque, len: usize, advice: c_int) callconv(.c) c_int {
    if (advice == std.os.linux.MADV.DONTNEED) return 0;
    return @intCast(-@as(isize, @bitCast(std.os.linux.madvise(@ptrCast(addr), len, @bitCast(advice)))));
}

const linux = std.os.linux;
const MAP_FAILED: usize = @bitCast(@as(isize, -1));

fn mmapLinux(addr: ?*anyopaque, len: usize, prot: c_int, flags: c_int, fd: c_int, offset: i64) callconv(.c) ?*anyopaque {
    if (len >= std.math.maxInt(isize)) {
        std.c._errno().* = @intFromEnum(linux.E.NOMEM);
        return @ptrFromInt(MAP_FAILED);
    }
    const rc = linux.mmap(
        @ptrCast(addr),
        len,
        @bitCast(prot),
        @bitCast(flags),
        fd,
        offset,
    );
    const signed: isize = @bitCast(rc);
    if (signed < 0) {
        @branchHint(.unlikely);
        var e: c_int = @intCast(-signed);
        // Match musl: EPERM on anonymous mapping without MAP_FIXED → ENOMEM
        if (e == @intFromEnum(linux.E.PERM) and addr == null and
            (flags & @as(c_int, @bitCast(linux.MAP{ .ANONYMOUS = true }))) != 0 and
            (flags & @as(c_int, @bitCast(linux.MAP{ .FIXED = true }))) == 0)
            e = @intFromEnum(linux.E.NOMEM);
        std.c._errno().* = e;
        return @ptrFromInt(MAP_FAILED);
    }
    return @ptrFromInt(rc);
}

fn mremapLinux(old_addr: ?*anyopaque, old_len: usize, new_len: usize, flags: c_int, new_addr: ?*anyopaque) callconv(.c) ?*anyopaque {
    if (new_len >= std.math.maxInt(isize)) {
        std.c._errno().* = @intFromEnum(linux.E.NOMEM);
        return @ptrFromInt(MAP_FAILED);
    }
    const rc = linux.mremap(
        @ptrCast(old_addr),
        old_len,
        new_len,
        @bitCast(flags),
        @ptrCast(new_addr),
    );
    const signed: isize = @bitCast(rc);
    if (signed < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-signed);
        return @ptrFromInt(MAP_FAILED);
    }
    return @ptrFromInt(rc);
}
