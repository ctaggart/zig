const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&getsockoptLinux, "getsockopt");
        symbol(&setsockoptLinux, "setsockopt");
        symbol(&sendmsgLinux, "sendmsg");
        symbol(&recvmsgLinux, "recvmsg");
        symbol(&sendmmsgLinux, "sendmmsg");
        symbol(&recvmmsgLinux, "recvmmsg");
    }
}

fn getsockoptLinux(fd: c_int, level: c_int, optname: c_int, optval: ?*anyopaque, optlen: ?*linux.socklen_t) callconv(.c) c_int {
    return errno(linux.getsockopt(fd, level, @bitCast(optname), @ptrCast(optval), @ptrCast(optlen)));
}

fn setsockoptLinux(fd: c_int, level: c_int, optname: c_int, optval: ?*const anyopaque, optlen: linux.socklen_t) callconv(.c) c_int {
    return errno(linux.setsockopt(fd, level, @bitCast(optname), @ptrCast(optval), optlen));
}

fn sendmsgLinux(fd: c_int, msg: *const linux.msghdr_const, flags: c_int) callconv(.c) isize {
    return errnoSize(linux.sendmsg(fd, msg, @bitCast(flags)));
}

fn recvmsgLinux(fd: c_int, msg: *linux.msghdr, flags: c_int) callconv(.c) isize {
    return errnoSize(linux.recvmsg(fd, msg, @bitCast(flags)));
}

fn sendmmsgLinux(fd: c_int, msgvec: [*]linux.mmsghdr, vlen: c_uint, flags: c_uint) callconv(.c) c_int {
    return errno(linux.sendmmsg(fd, msgvec, vlen, flags));
}

fn recvmmsgLinux(fd: c_int, msgvec: ?[*]linux.mmsghdr, vlen: c_uint, flags: c_uint, timeout: ?*linux.timespec) callconv(.c) c_int {
    return errno(linux.recvmmsg(fd, msgvec, vlen, flags, timeout));
}

fn errnoSize(r: usize) isize {
    const signed: isize = @bitCast(r);
    if (signed < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-signed);
        return -1;
    }
    return signed;
}
