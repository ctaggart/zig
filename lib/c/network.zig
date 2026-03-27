const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&socketLinux, "socket");
        symbol(&bindLinux, "bind");
        symbol(&listenLinux, "listen");
        symbol(&acceptLinux, "accept");
        symbol(&accept4Linux, "accept4");
        symbol(&connectLinux, "connect");
        symbol(&sendLinux, "send");
        symbol(&sendtoLinux, "sendto");
        symbol(&recvLinux, "recv");
        symbol(&recvfromLinux, "recvfrom");
        symbol(&shutdownLinux, "shutdown");
        symbol(&getsocknameLinux, "getsockname");
        symbol(&getpeernameLinux, "getpeername");
        symbol(&socketpairLinux, "socketpair");
    }
}

fn socketLinux(domain: c_int, sock_type: c_int, protocol: c_int) callconv(.c) c_int {
    return errno(linux.socket(@bitCast(domain), @bitCast(sock_type), @bitCast(protocol)));
}

fn bindLinux(fd: c_int, addr: *const anyopaque, len: linux.socklen_t) callconv(.c) c_int {
    return errno(linux.bind(fd, @ptrCast(addr), len));
}

fn listenLinux(fd: c_int, backlog: c_int) callconv(.c) c_int {
    return errno(linux.listen(fd, @bitCast(backlog)));
}

fn acceptLinux(fd: c_int, addr: ?*anyopaque, len: ?*linux.socklen_t) callconv(.c) c_int {
    return errno(linux.accept(fd, @ptrCast(addr), len));
}

fn accept4Linux(fd: c_int, addr: ?*anyopaque, len: ?*linux.socklen_t, flg: c_int) callconv(.c) c_int {
    return errno(linux.accept4(fd, @ptrCast(addr), len, @bitCast(flg)));
}

fn connectLinux(fd: c_int, addr: *const anyopaque, len: linux.socklen_t) callconv(.c) c_int {
    return errno(linux.connect(fd, addr, len));
}

fn sendLinux(fd: c_int, buf: [*]const u8, len: usize, flags: c_int) callconv(.c) isize {
    return errnoSize(linux.sendto(fd, buf, len, @bitCast(flags), null, 0));
}

fn sendtoLinux(fd: c_int, buf: [*]const u8, len: usize, flags: c_int, addr: ?*const anyopaque, alen: linux.socklen_t) callconv(.c) isize {
    return errnoSize(linux.sendto(fd, buf, len, @bitCast(flags), @ptrCast(addr), alen));
}

fn recvLinux(fd: c_int, buf: [*]u8, len: usize, flags: c_int) callconv(.c) isize {
    return errnoSize(linux.recvfrom(fd, buf, len, @bitCast(flags), null, null));
}

fn recvfromLinux(fd: c_int, buf: [*]u8, len: usize, flags: c_int, addr: ?*anyopaque, alen: ?*linux.socklen_t) callconv(.c) isize {
    return errnoSize(linux.recvfrom(fd, buf, len, @bitCast(flags), @ptrCast(addr), alen));
}

fn shutdownLinux(fd: c_int, how: c_int) callconv(.c) c_int {
    return errno(linux.shutdown(fd, how));
}

fn getsocknameLinux(fd: c_int, addr: *anyopaque, len: *linux.socklen_t) callconv(.c) c_int {
    return errno(linux.getsockname(fd, @ptrCast(addr), len));
}

fn getpeernameLinux(fd: c_int, addr: *anyopaque, len: *linux.socklen_t) callconv(.c) c_int {
    return errno(linux.getpeername(fd, @ptrCast(addr), len));
}

fn socketpairLinux(domain: c_int, sock_type: c_int, protocol: c_int, fd: *[2]c_int) callconv(.c) c_int {
    return errno(linux.socketpair(@bitCast(domain), @bitCast(sock_type), @bitCast(protocol), @ptrCast(fd)));
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
