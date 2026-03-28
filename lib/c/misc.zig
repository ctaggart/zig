const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&ioctlImpl, "ioctl");
    }
}

fn ioctlImpl(fd: c_int, req: c_int, ...) callconv(.c) c_int {
    var ap = @cVaStart();
    const arg = @cVaArg(&ap, usize);
    @cVaEnd(&ap);

    const rc: isize = @bitCast(linux.ioctl(@intCast(fd), @bitCast(@as(c_uint, @bitCast(req))), arg));
    if (rc >= 0) return @intCast(rc);

    // On 64-bit, time_t == long, so no ioctl compat conversion is needed.
    // On 32-bit with time64, the compat table would handle SIOCGSTAMP etc.
    // but that path is only active when SIOCGSTAMP != SIOCGSTAMP_OLD,
    // which requires the full conversion table from the C implementation.
    // For now, just return the error.
    std.c._errno().* = @intCast(-rc);
    return -1;
}
