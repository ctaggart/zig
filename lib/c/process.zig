const builtin = @import("builtin");

const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

extern "c" fn execve(path: [*:0]const u8, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) callconv(.c) c_int;

comptime {
    if (builtin.link_libc) {
        symbol(&fexecveImpl, "fexecve");
    }
}

fn fexecveImpl(fd: c_int, argv: [*:null]const ?[*:0]const u8, envp: [*:null]const ?[*:0]const u8) callconv(.c) c_int {
    // Try execveat first
    const r: isize = @bitCast(linux.execveat(fd, "", argv, envp, .{ .SYMLINK_NOFOLLOW = false, .EMPTY_PATH = true }));
    if (r != -@as(isize, @intFromEnum(linux.E.NOSYS))) {
        // execveat succeeded (doesn't return) or failed with non-ENOSYS
        std.c._errno().* = @intCast(-r);
        return -1;
    }
    // Fallback: /proc/self/fd/N
    var buf: ["/proc/self/fd/".len + 11]u8 = undefined;
    const prefix = "/proc/self/fd/";
    @memcpy(buf[0..prefix.len], prefix);
    var pos: usize = prefix.len;
    var v: u32 = @intCast(@as(c_uint, @bitCast(fd)));
    if (v == 0) {
        buf[pos] = '0';
        pos += 1;
    } else {
        var tmp: [10]u8 = undefined;
        var i: usize = 0;
        while (v > 0) : (i += 1) {
            tmp[i] = '0' + @as(u8, @intCast(v % 10));
            v /= 10;
        }
        while (i > 0) {
            i -= 1;
            buf[pos] = tmp[i];
            pos += 1;
        }
    }
    buf[pos] = 0;
    _ = execve(@ptrCast(buf[0..pos :0]), argv, envp);
    if (std.c._errno().* == @intFromEnum(linux.E.NOENT))
        std.c._errno().* = @intFromEnum(linux.E.BADF);
    return -1;
}
