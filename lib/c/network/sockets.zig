//! Socket-related libc functions — Zig port of musl's src/network/ wrappers
//! that are thin `syscall()` / `socketcall()` adaptors. All multi-arch
//! dispatch (SYS_socketcall on 32-bit x86 etc.) is handled by
//! `std.os.linux`; this module just translates the return value into
//! `errno + -1` and handles the SOCK_CLOEXEC / SOCK_NONBLOCK fallback
//! shims that musl performs when the kernel is too old to honour those
//! flags directly in `socket(2)` / `socketpair(2)` / `accept4(2)`.

const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../../c.zig").symbol;
const errno = @import("../../c.zig").errno;
const errnoSize = @import("../../c.zig").errnoSize;

const F_SETFD = 2;
const F_SETFL = 4;
const FD_CLOEXEC = 1;
const O_NONBLOCK: u32 = 0o4000;

const SIOCATMARK: c_ulong = 0x8905;

comptime {
    if (builtin.os.tag == .linux and builtin.link_libc) {
        symbol(&socketLinux, "socket");
        symbol(&socketpairLinux, "socketpair");
        symbol(&bindLinux, "bind");
        symbol(&listenLinux, "listen");
        symbol(&connectLinux, "connect");
        symbol(&acceptLinux, "accept");
        symbol(&accept4Linux, "accept4");
        symbol(&getsocknameLinux, "getsockname");
        symbol(&getpeernameLinux, "getpeername");
        symbol(&sendLinux, "send");
        symbol(&sendtoLinux, "sendto");
        symbol(&recvLinux, "recv");
        symbol(&recvfromLinux, "recvfrom");
        symbol(&shutdownLinux, "shutdown");
        symbol(&getsockoptLinux, "getsockopt");
        symbol(&setsockoptLinux, "setsockopt");
        symbol(&sockatmarkLinux, "sockatmark");
        symbol(&htonlLinux, "htonl");
        symbol(&htonsLinux, "htons");
        symbol(&ntohlLinux, "ntohl");
        symbol(&ntohsLinux, "ntohs");
    }
}

fn fallback_cloexec_nonblock(fd: c_int, type_flags: c_int) void {
    if (type_flags & linux.SOCK.CLOEXEC != 0) {
        _ = linux.fcntl(fd, F_SETFD, FD_CLOEXEC);
    }
    if (type_flags & linux.SOCK.NONBLOCK != 0) {
        _ = linux.fcntl(fd, F_SETFL, O_NONBLOCK);
    }
}

fn socketLinux(domain: c_int, type_: c_int, protocol: c_int) callconv(.c) c_int {
    const d: u32 = @bitCast(domain);
    const t: u32 = @bitCast(type_);
    const p: u32 = @bitCast(protocol);

    const first = linux.socket(d, t, p);
    const signed_first: isize = @bitCast(first);
    const invalid_or_noproto = signed_first == -@as(isize, @intFromEnum(linux.E.INVAL)) or
        signed_first == -@as(isize, @intFromEnum(linux.E.PROTONOSUPPORT));
    const asked_for_new_flags = (type_ & (linux.SOCK.CLOEXEC | linux.SOCK.NONBLOCK)) != 0;

    if (signed_first >= 0 or !(invalid_or_noproto and asked_for_new_flags)) {
        return errno(first);
    }

    // Retry without the new flags, then apply via fcntl.
    const retried = linux.socket(d, @as(u32, @bitCast(type_ & ~@as(c_int, linux.SOCK.CLOEXEC | linux.SOCK.NONBLOCK))), p);
    const retried_signed: isize = @bitCast(retried);
    if (retried_signed < 0) return errno(retried);
    const fd_ok: c_int = @intCast(retried_signed);
    fallback_cloexec_nonblock(fd_ok, type_);
    return fd_ok;
}

fn socketpairLinux(domain: c_int, type_: c_int, protocol: c_int, fd: *[2]c_int) callconv(.c) c_int {
    const d: u32 = @bitCast(domain);
    const t: u32 = @bitCast(type_);
    const p: u32 = @bitCast(protocol);

    const first = linux.socketpair(d, t, p, @ptrCast(fd));
    const signed: isize = @bitCast(first);
    const invalid_or_noproto = signed == -@as(isize, @intFromEnum(linux.E.INVAL)) or
        signed == -@as(isize, @intFromEnum(linux.E.PROTONOSUPPORT));
    const asked_for_new_flags = (type_ & (linux.SOCK.CLOEXEC | linux.SOCK.NONBLOCK)) != 0;

    if (signed >= 0 or !(invalid_or_noproto and asked_for_new_flags)) {
        return errno(first);
    }

    const retried = linux.socketpair(d, @as(u32, @bitCast(type_ & ~@as(c_int, linux.SOCK.CLOEXEC | linux.SOCK.NONBLOCK))), p, @ptrCast(fd));
    const retried_signed: isize = @bitCast(retried);
    if (retried_signed < 0) return errno(retried);
    if (type_ & linux.SOCK.CLOEXEC != 0) {
        _ = linux.fcntl(fd[0], F_SETFD, FD_CLOEXEC);
        _ = linux.fcntl(fd[1], F_SETFD, FD_CLOEXEC);
    }
    if (type_ & linux.SOCK.NONBLOCK != 0) {
        _ = linux.fcntl(fd[0], F_SETFL, O_NONBLOCK);
        _ = linux.fcntl(fd[1], F_SETFL, O_NONBLOCK);
    }
    return 0;
}

fn bindLinux(fd: c_int, addr: *const anyopaque, len: linux.socklen_t) callconv(.c) c_int {
    return errno(linux.bind(fd, @ptrCast(@alignCast(addr)), len));
}

fn listenLinux(fd: c_int, backlog: c_int) callconv(.c) c_int {
    return errno(linux.listen(fd, @bitCast(backlog)));
}

fn connectLinux(fd: c_int, addr: *const anyopaque, len: linux.socklen_t) callconv(.c) c_int {
    return errno(linux.connect(fd, addr, len));
}

fn acceptLinux(fd: c_int, addr: ?*anyopaque, len: ?*linux.socklen_t) callconv(.c) c_int {
    return errno(linux.accept(fd, @ptrCast(@alignCast(addr)), len));
}

fn accept4Linux(fd: c_int, addr: ?*anyopaque, len: ?*linux.socklen_t, flg: c_int) callconv(.c) c_int {
    if (flg == 0) return acceptLinux(fd, addr, len);
    const r = linux.accept4(fd, @ptrCast(@alignCast(addr)), len, @bitCast(flg));
    const signed: isize = @bitCast(r);
    if (signed >= 0) return @intCast(signed);
    const err = -signed;
    if (err != @intFromEnum(linux.E.NOSYS) and err != @intFromEnum(linux.E.INVAL))
        return errno(r);
    // fallback via plain accept() + fcntl
    if (flg & ~@as(c_int, linux.SOCK.CLOEXEC | linux.SOCK.NONBLOCK) != 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    const fd2 = acceptLinux(fd, addr, len);
    if (fd2 < 0) return fd2;
    fallback_cloexec_nonblock(fd2, flg);
    return fd2;
}

fn getsocknameLinux(fd: c_int, addr: *anyopaque, len: *linux.socklen_t) callconv(.c) c_int {
    return errno(linux.getsockname(fd, @ptrCast(@alignCast(addr)), len));
}

fn getpeernameLinux(fd: c_int, addr: *anyopaque, len: *linux.socklen_t) callconv(.c) c_int {
    return errno(linux.getpeername(fd, @ptrCast(@alignCast(addr)), len));
}

fn sendLinux(fd: c_int, buf: *const anyopaque, len: usize, flags: c_int) callconv(.c) isize {
    return sendtoLinux(fd, buf, len, flags, null, 0);
}

fn sendtoLinux(
    fd: c_int,
    buf: *const anyopaque,
    len: usize,
    flags: c_int,
    addr: ?*const anyopaque,
    alen: linux.socklen_t,
) callconv(.c) isize {
    return errnoSize(linux.sendto(
        fd,
        @ptrCast(buf),
        len,
        @bitCast(flags),
        @ptrCast(@alignCast(addr)),
        alen,
    ));
}

fn recvLinux(fd: c_int, buf: *anyopaque, len: usize, flags: c_int) callconv(.c) isize {
    return recvfromLinux(fd, buf, len, flags, null, null);
}

fn recvfromLinux(
    fd: c_int,
    buf: *anyopaque,
    len: usize,
    flags: c_int,
    addr: ?*anyopaque,
    alen: ?*linux.socklen_t,
) callconv(.c) isize {
    return errnoSize(linux.recvfrom(
        fd,
        @ptrCast(buf),
        len,
        @bitCast(flags),
        @ptrCast(@alignCast(addr)),
        alen,
    ));
}

fn shutdownLinux(fd: c_int, how: c_int) callconv(.c) c_int {
    return errno(linux.shutdown(fd, how));
}

fn getsockoptLinux(
    fd: c_int,
    level: c_int,
    optname: c_int,
    optval: *anyopaque,
    optlen: *linux.socklen_t,
) callconv(.c) c_int {
    return errno(linux.getsockopt(fd, level, @bitCast(optname), @ptrCast(optval), optlen));
}

fn setsockoptLinux(
    fd: c_int,
    level: c_int,
    optname: c_int,
    optval: *const anyopaque,
    optlen: linux.socklen_t,
) callconv(.c) c_int {
    return errno(linux.setsockopt(fd, level, @bitCast(optname), @ptrCast(optval), optlen));
}

fn sockatmarkLinux(fd: c_int) callconv(.c) c_int {
    var ret: c_int = undefined;
    const r = linux.ioctl(fd, SIOCATMARK, @intFromPtr(&ret));
    const signed: isize = @bitCast(r);
    if (signed < 0) {
        std.c._errno().* = @intCast(-signed);
        return -1;
    }
    return ret;
}

fn htonlLinux(n: u32) callconv(.c) u32 {
    return if (builtin.cpu.arch.endian() == .little) @byteSwap(n) else n;
}

fn htonsLinux(n: u16) callconv(.c) u16 {
    return if (builtin.cpu.arch.endian() == .little) @byteSwap(n) else n;
}

fn ntohlLinux(n: u32) callconv(.c) u32 {
    return if (builtin.cpu.arch.endian() == .little) @byteSwap(n) else n;
}

fn ntohsLinux(n: u16) callconv(.c) u16 {
    return if (builtin.cpu.arch.endian() == .little) @byteSwap(n) else n;
}
