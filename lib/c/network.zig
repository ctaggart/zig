// DNS resolver core — coordinated migration of all remaining network functions.
// All functions are guarded by link_libc since they depend on C library functions.
const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;
const errnoSize = @import("../c.zig").errnoSize;

const in_addr_t = u32;

// ============================================================
// Internal struct definitions (from lookup.h / netlink.h)
// ============================================================

const MAXNS = 3;
const MAXADDRS = 48;
const MAXSERVS = 2;

const address = extern struct {
    family: c_int,
    scopeid: c_uint,
    addr: [16]u8,
    sortkey: c_int,
};

const service = extern struct {
    port: u16,
    proto: u8,
    socktype: u8,
};

const resolvconf = extern struct {
    ns: [MAXNS]address,
    nns: c_uint,
    attempts: c_uint,
    ndots: c_uint,
    timeout: c_uint,
};

const addrinfo = extern struct {
    ai_flags: c_int,
    ai_family: c_int,
    ai_socktype: c_int,
    ai_protocol: c_int,
    ai_addrlen: linux.socklen_t,
    ai_addr: ?*linux.sockaddr,
    ai_canonname: ?[*:0]u8,
    ai_next: ?*addrinfo,
};

const aibuf = extern struct {
    ai: addrinfo,
    sa: extern union {
        sin: linux.sockaddr.in,
        sin6: linux.sockaddr.in6,
    },
    lock: [1]c_int,
    slot: c_short,
    ref: c_short,
};

const hostent = extern struct {
    h_name: ?[*:0]u8,
    h_aliases: ?[*]?[*:0]u8,
    h_addrtype: c_int,
    h_length: c_int,
    h_addr_list: ?[*]?[*]u8,
};

const servent = extern struct {
    s_name: ?[*:0]u8,
    s_aliases: ?[*]?[*:0]u8,
    s_port: c_int,
    s_proto: ?[*:0]u8,
};

const nlmsghdr = extern struct {
    nlmsg_len: u32,
    nlmsg_type: u16,
    nlmsg_flags: u16,
    nlmsg_seq: u32,
    nlmsg_pid: u32,
};

const ifaddrmsg = extern struct {
    ifa_family: u8,
    ifa_prefixlen: u8,
    ifa_flags: u8,
    ifa_scope: u8,
    ifa_index: u32,
};

const if_nameindex_t = extern struct {
    if_index: c_uint,
    if_name: ?[*:0]u8,
};

const IF_NAMESIZE = 16;
const SIOCGIFNAME = 0x8910;
const SIOCGIFINDEX = 0x8933;

const ifmap = extern struct {
    mem_start: c_ulong,
    mem_end: c_ulong,
    base_addr: c_ushort,
    irq: u8,
    dma: u8,
    port: u8,
};

const ifreq = extern struct {
    ifr_name: [IF_NAMESIZE]u8,
    ifr_ifru: extern union {
        addr: linux.sockaddr,
        dstaddr: linux.sockaddr,
        broadaddr: linux.sockaddr,
        netmask: linux.sockaddr,
        hwaddr: linux.sockaddr,
        flags: c_short,
        ivalue: c_int,
        mtu: c_int,
        map: ifmap,
        slave: [IF_NAMESIZE]u8,
        newname: [IF_NAMESIZE]u8,
        data: ?*anyopaque,
    },
};

const in_addr = extern struct {
    s_addr: in_addr_t,
};

const in6_addr = extern struct {
    __in6_union: extern union {
        __s6_addr: [16]u8,
        __s6_addr16: [8]u16,
        __s6_addr32: [4]u32,
    },
};

const res_state = extern struct {
    retrans: c_int,
    retry: c_int,
    options: c_ulong,
    nscount: c_int,
    nsaddr_list: [MAXNS]linux.sockaddr.in,
    id: c_ushort,
    dnsrch: [MAXDNSRCH + 1]?[*:0]u8,
    defdname: [256]u8,
    pfcode: c_ulong,
    bitfield: c_uint,
    sort_list: [MAXRESOLVSORT]extern struct {
        addr: in_addr,
        mask: u32,
    },
    qhook: ?*anyopaque,
    rhook: ?*anyopaque,
    res_h_errno: c_int,
    _vcsock: c_int,
    _flags: c_uint,
    _u: extern union {
        pad: [52]u8,
        _ext: extern struct {
            nscount: u16,
            nsmap: [MAXNS]u16,
            nssocks: [MAXNS]c_int,
            nscount6: u16,
            nsinit: u16,
            nsaddrs: [MAXNS]?*linux.sockaddr.in6,
            _initstamp: [2]c_uint,
        },
    },
};

const MAXDNSRCH = 6;
const MAXRESOLVSORT = 10;

// ns_parse structs (from arpa/nameser.h)
const NS_MAXDNAME = 1025;
const NS_INT16SZ = 2;
const NS_INT32SZ = 4;
const ns_s_max = 4;
const ns_s_qd = 0;

const ns_msg = extern struct {
    _msg: [*]const u8,
    _eom: [*]const u8,
    _id: u16,
    _flags: u16,
    _counts: [4]u16,
    _sections: [4]?[*]const u8,
    _sect: c_int,
    _rrnum: c_int,
    _msg_ptr: ?[*]const u8,
};

const ns_rr = extern struct {
    name: [NS_MAXDNAME]u8,
    rr_type: u16,
    rr_class: u16,
    ttl: u32,
    rdlength: u16,
    rdata: ?[*]const u8,
};

// ============================================================
// C library function externs (only resolved when link_libc)
// ============================================================

// These are declared as file-scope constants but only referenced
// from functions guarded by link_libc, so they're never resolved
// in test mode.

const c = if (builtin.link_libc) struct {
    const malloc = @extern(*const fn (usize) callconv(.c) ?[*]u8, .{ .name = "malloc" });
    const calloc = @extern(*const fn (usize, usize) callconv(.c) ?[*]u8, .{ .name = "calloc" });
    const realloc = @extern(*const fn (?*anyopaque, usize) callconv(.c) ?[*]u8, .{ .name = "realloc" });
    const free = @extern(*const fn (?*anyopaque) callconv(.c) void, .{ .name = "free" });
    const memcpy = @extern(*const fn (?*anyopaque, ?*const anyopaque, usize) callconv(.c) ?*anyopaque, .{ .name = "memcpy" });
    const memcmp = @extern(*const fn (?*const anyopaque, ?*const anyopaque, usize) callconv(.c) c_int, .{ .name = "memcmp" });
    const memset = @extern(*const fn (?*anyopaque, c_int, usize) callconv(.c) ?*anyopaque, .{ .name = "memset" });
    const strlen = @extern(*const fn ([*:0]const u8) callconv(.c) usize, .{ .name = "strlen" });
    const strnlen = @extern(*const fn ([*]const u8, usize) callconv(.c) usize, .{ .name = "strnlen" });
    const strcmp = @extern(*const fn ([*:0]const u8, [*:0]const u8) callconv(.c) c_int, .{ .name = "strcmp" });
    const strncmp = @extern(*const fn ([*]const u8, [*]const u8, usize) callconv(.c) c_int, .{ .name = "strncmp" });
    const strcpy = @extern(*const fn ([*]u8, [*:0]const u8) callconv(.c) [*]u8, .{ .name = "strcpy" });
    const strncpy = @extern(*const fn ([*]u8, [*:0]const u8, usize) callconv(.c) [*]u8, .{ .name = "strncpy" });
    const strtoul = @extern(*const fn ([*:0]const u8, *[*:0]u8, c_int) callconv(.c) c_ulong, .{ .name = "strtoul" });
    const if_nametoindex = @extern(*const fn ([*:0]const u8) callconv(.c) c_uint, .{ .name = "if_nametoindex" });
    const snprintf = @extern(*const fn ([*]u8, usize, [*:0]const u8, ...) callconv(.c) c_int, .{ .name = "snprintf" });
    const socket_fn = @extern(*const fn (c_int, c_int, c_int) callconv(.c) c_int, .{ .name = "socket" });
    const close_fn = @extern(*const fn (c_int) callconv(.c) c_int, .{ .name = "close" });
    const bind_fn = @extern(*const fn (c_int, *const anyopaque, linux.socklen_t) callconv(.c) c_int, .{ .name = "bind" });
    const connect_fn = @extern(*const fn (c_int, *const anyopaque, linux.socklen_t) callconv(.c) c_int, .{ .name = "connect" });
    const sendto_fn = @extern(*const fn (c_int, *const anyopaque, usize, c_int, ?*const anyopaque, linux.socklen_t) callconv(.c) isize, .{ .name = "sendto" });
    const recvfrom_fn = @extern(*const fn (c_int, *anyopaque, usize, c_int, ?*anyopaque, ?*linux.socklen_t) callconv(.c) isize, .{ .name = "recvfrom" });
    const send_fn = @extern(*const fn (c_int, *const anyopaque, usize, c_int) callconv(.c) isize, .{ .name = "send" });
    const recv_fn = @extern(*const fn (c_int, *anyopaque, usize, c_int) callconv(.c) isize, .{ .name = "recv" });
    const setsockopt_fn = @extern(*const fn (c_int, c_int, c_int, *const anyopaque, linux.socklen_t) callconv(.c) c_int, .{ .name = "setsockopt" });
    const getsockname_fn = @extern(*const fn (c_int, *anyopaque, *linux.socklen_t) callconv(.c) c_int, .{ .name = "getsockname" });
    const poll_fn = @extern(*const fn ([*]linux.pollfd, c_ulong, c_int) callconv(.c) c_int, .{ .name = "poll" });
    const getnameinfo_fn = @extern(*const fn (*const anyopaque, linux.socklen_t, ?[*]u8, linux.socklen_t, ?[*]u8, linux.socklen_t, c_int) callconv(.c) c_int, .{ .name = "getnameinfo" });
    const getaddrinfo_fn = @extern(*const fn ([*:0]const u8, ?[*:0]const u8, ?*const addrinfo, *?*addrinfo) callconv(.c) c_int, .{ .name = "getaddrinfo" });
    const freeaddrinfo_fn = @extern(*const fn (?*addrinfo) callconv(.c) void, .{ .name = "freeaddrinfo" });
    const gethostbyname2_r_fn = @extern(*const fn ([*:0]const u8, c_int, *hostent, [*]u8, usize, *?*hostent, *c_int) callconv(.c) c_int, .{ .name = "gethostbyname2_r" });
    const gethostbyaddr_r_fn = @extern(*const fn (*const anyopaque, linux.socklen_t, c_int, *hostent, [*]u8, usize, *?*hostent, *c_int) callconv(.c) c_int, .{ .name = "gethostbyaddr_r" });
    const getservbyname_r_fn = @extern(*const fn ([*:0]const u8, ?[*:0]const u8, *servent, [*]u8, usize, *?*servent) callconv(.c) c_int, .{ .name = "getservbyname_r" });
    const getservbyport_r_fn = @extern(*const fn (c_int, ?[*:0]const u8, *servent, [*]u8, usize, *?*servent) callconv(.c) c_int, .{ .name = "getservbyport_r" });
    const dn_expand_fn = @extern(*const fn ([*]const u8, [*]const u8, [*]const u8, [*]u8, c_int) callconv(.c) c_int, .{ .name = "__dn_expand" });
    const dn_skipname_fn = @extern(*const fn ([*]const u8, [*]const u8) callconv(.c) c_int, .{ .name = "dn_skipname" });
    const dns_parse_fn = @extern(*const fn ([*]const u8, c_int, *const fn (?*anyopaque, c_int, *const anyopaque, c_int, *const anyopaque, c_int) callconv(.c) c_int, ?*anyopaque) callconv(.c) c_int, .{ .name = "__dns_parse" });
    const clock_gettime_fn = @extern(*const fn (c_int, *linux.timespec) callconv(.c) c_int, .{ .name = "clock_gettime" });
    const pthread_setcancelstate = @extern(*const fn (c_int, ?*c_int) callconv(.c) c_int, .{ .name = "pthread_setcancelstate" });
    const qsort_fn = @extern(*const fn (*anyopaque, usize, usize, *const fn (*const anyopaque, *const anyopaque) callconv(.c) c_int) callconv(.c) void, .{ .name = "qsort" });
    const h_errno_ptr = @extern(*c_int, .{ .name = "h_errno" });
    // Internal musl functions
    const lookup_name_fn = @extern(*const fn ([*]address, [*]u8, [*:0]const u8, c_int, c_int) callconv(.c) c_int, .{ .name = "__lookup_name" });
    const lookup_serv_fn = @extern(*const fn ([*]service, [*:0]const u8, c_int, c_int, c_int) callconv(.c) c_int, .{ .name = "__lookup_serv" });
    const lookup_ipliteral_fn = @extern(*const fn ([*]address, [*:0]const u8, c_int) callconv(.c) c_int, .{ .name = "__lookup_ipliteral" });
    const get_resolv_conf_fn = @extern(*const fn (*resolvconf, [*]u8, usize) callconv(.c) c_int, .{ .name = "__get_resolv_conf" });
    const res_msend_rc_fn = @extern(*const fn (c_int, [*]const [*]const u8, [*]const c_int, [*]const [*]u8, [*]c_int, c_int, *const resolvconf) callconv(.c) c_int, .{ .name = "__res_msend_rc" });
    const res_mkquery_fn = @extern(*const fn (c_int, [*:0]const u8, c_int, c_int, ?*const anyopaque, c_int, ?*const anyopaque, [*]u8, c_int) callconv(.c) c_int, .{ .name = "__res_mkquery" });
    const res_send_fn = @extern(*const fn ([*]const u8, c_int, [*]u8, c_int) callconv(.c) c_int, .{ .name = "__res_send" });
    const rtnetlink_enumerate_fn = @extern(*const fn (c_int, c_int, *const fn (?*anyopaque, *nlmsghdr) callconv(.c) c_int, ?*anyopaque) callconv(.c) c_int, .{ .name = "__rtnetlink_enumerate" });
    // File I/O
    const fopen_rb_ca = @extern(*const fn ([*:0]const u8, *anyopaque, [*]u8, usize) callconv(.c) ?*anyopaque, .{ .name = "__fopen_rb_ca" });
    const fclose_ca = @extern(*const fn (?*anyopaque) callconv(.c) void, .{ .name = "__fclose_ca" });
    const fgets_fn = @extern(*const fn ([*]u8, c_int, ?*anyopaque) callconv(.c) ?[*]u8, .{ .name = "fgets" });
    const feof_fn = @extern(*const fn (?*anyopaque) callconv(.c) c_int, .{ .name = "feof" });
    const getc_fn = @extern(*const fn (?*anyopaque) callconv(.c) c_int, .{ .name = "getc" });
    const strchr_fn = @extern(*const fn ([*:0]const u8, c_int) callconv(.c) ?[*:0]u8, .{ .name = "strchr" });
    const strstr_fn = @extern(*const fn ([*:0]const u8, [*:0]const u8) callconv(.c) ?[*:0]u8, .{ .name = "strstr" });
} else struct {};

// ============================================================
// Symbol exports — ALL guarded by link_libc
// ============================================================

comptime {
    if (builtin.target.isWasiLibC()) {
        symbol(&htonl_impl, "htonl");
        symbol(&htons_impl, "htons");
        symbol(&ntohl_impl, "ntohl");
        symbol(&ntohs_impl, "ntohs");
        symbol(&in6addr_any, "in6addr_any");
        symbol(&in6addr_loopback, "in6addr_loopback");
        symbol(&inet_aton_impl, "__inet_aton");
        symbol(&inet_aton_impl, "inet_aton");
        symbol(&inet_ntop_impl, "inet_ntop");
        symbol(&inet_pton_impl, "inet_pton");
    }
    if (builtin.target.isMuslLibC()) {
        // socket.c / bind.c / listen.c / accept.c / accept4.c / connect.c / shutdown.c / socketpair.c
        symbol(&socket_impl, "socket");
        symbol(&bind_impl, "bind");
        symbol(&listen_impl, "listen");
        symbol(&accept_impl, "accept");
        symbol(&accept4_impl, "accept4");
        symbol(&connect_impl, "connect");
        symbol(&shutdown_impl, "shutdown");
        symbol(&socketpair_impl, "socketpair");

        // htonl.c / htons.c / ntohl.c / ntohs.c
        symbol(&htonl_impl, "htonl");
        symbol(&htons_impl, "htons");
        symbol(&ntohl_impl, "ntohl");
        symbol(&ntohs_impl, "ntohs");

        // IPv6 address constants: in6addr_any.c / in6addr_loopback.c
        symbol(&in6addr_any, "in6addr_any");
        symbol(&in6addr_loopback, "in6addr_loopback");

        // inet_addr.c / inet_aton.c / inet_legacy.c / inet_ntoa.c
        symbol(&inet_addr_impl, "inet_addr");
        symbol(&inet_aton_impl, "__inet_aton");
        symbol(&inet_aton_impl, "inet_aton");
        symbol(&inet_network_impl, "inet_network");
        symbol(&inet_makeaddr_impl, "inet_makeaddr");
        symbol(&inet_lnaof_impl, "inet_lnaof");
        symbol(&inet_netof_impl, "inet_netof");
        symbol(&inet_ntoa_impl, "inet_ntoa");

        // inet_ntop.c / inet_pton.c
        symbol(&inet_ntop_impl, "inet_ntop");
        symbol(&inet_pton_impl, "inet_pton");

        // if_freenameindex.c / if_indextoname.c / if_nametoindex.c
        symbol(&if_freenameindex_impl, "if_freenameindex");
        symbol(&if_indextoname_impl, "if_indextoname");
        symbol(&if_nametoindex_impl, "if_nametoindex");

        // getsockname.c / getpeername.c / getsockopt.c / setsockopt.c / sockatmark.c
        symbol(&getsockname_impl, "getsockname");
        symbol(&getpeername_impl, "getpeername");
        symbol(&getsockopt_impl, "getsockopt");
        symbol(&setsockopt_impl, "setsockopt");
        symbol(&sockatmark_impl, "sockatmark");

        // res_init.c / res_state.c
        symbol(&res_init_impl, "res_init");
        symbol(&res_state_impl, "__res_state");

        // gethostbyname.c / gethostbyname2.c / gethostbyname_r.c / gethostbyaddr.c
        symbol(&gethostbyname_impl, "gethostbyname");
        symbol(&gethostbyname2_impl, "gethostbyname2");
        symbol(&gethostbyname_r_impl, "gethostbyname_r");
        symbol(&gethostbyaddr_impl, "gethostbyaddr");

        // getservbyname.c / getservbyport.c / netname.c / serv.c
        symbol(&getservbyname_impl, "getservbyname");
        symbol(&getservbyport_impl, "getservbyport");
        symbol(&getnetbyaddr_impl, "getnetbyaddr");
        symbol(&getnetbyname_impl, "getnetbyname");
        symbol(&endservent_impl, "endservent");
        symbol(&setservent_impl, "setservent");
        symbol(&getservent_impl, "getservent");

        // proto.c — static protocol-number table
        symbol(&getprotoent_impl, "getprotoent");
        symbol(&getprotobyname_impl, "getprotobyname");
        symbol(&getprotobynumber_impl, "getprotobynumber");
        symbol(&setprotoent_impl, "setprotoent");
        symbol(&endprotoent_impl, "endprotoent");

        // ent.c — host/net database iteration stubs (+ weak aliases)
        symbol(&sethostent_impl, "sethostent");
        symbol(&sethostent_impl, "setnetent");
        symbol(&endhostent_impl, "endhostent");
        symbol(&endhostent_impl, "endnetent");
        symbol(&gethostent_impl, "gethostent");
        symbol(&getnetent_impl, "getnetent");

        // ether.c — ethernet address conversion
        symbol(&ether_aton_impl, "ether_aton");
        symbol(&ether_aton_r_impl, "ether_aton_r");
        symbol(&ether_ntoa_impl, "ether_ntoa");
        symbol(&ether_ntoa_r_impl, "ether_ntoa_r");
        symbol(&ether_line_impl, "ether_line");
        symbol(&ether_ntohost_impl, "ether_ntohost");
        symbol(&ether_hostton_impl, "ether_hostton");

        // h_errno.c / herror.c / hstrerror.c / gai_strerror.c
        symbol(&h_errno_storage, "h_errno");
        symbol(&__h_errno_location_impl, "__h_errno_location");
        symbol(&herror_impl, "herror");
        symbol(&hstrerror_impl, "hstrerror");
        symbol(&gai_strerror_impl, "gai_strerror");

        // dn_expand.c / dn_skipname.c / dns_parse.c
        symbol(&dn_expand_impl, "__dn_expand");
        symbol(&dn_expand_impl, "dn_expand");
        symbol(&dn_skipname_impl, "dn_skipname");
        symbol(&dns_parse_impl, "__dns_parse");

        // send.c / sendto.c / sendmsg.c / sendmmsg.c
        // recv.c / recvfrom.c / recvmsg.c / recvmmsg.c
        symbol(&send_impl, "send");
        symbol(&sendto_impl, "sendto");
        symbol(&sendmsg_impl, "sendmsg");
        symbol(&sendmmsg_impl, "sendmmsg");
        symbol(&recv_impl, "recv");
        symbol(&recvfrom_impl, "recvfrom");
        symbol(&recvmsg_impl, "recvmsg");
        // On `_REDIR_TIME64` ABIs (the LP32 musl archs in the time32 compat
        // list) <sys/socket.h> redirects user calls to `recvmmsg` so they
        // resolve against the symbol `__recvmmsg_time64`. Musl's
        // `src/network/recvmmsg.c` itself ends up emitting that exact
        // symbol because the redirect is processed when the file is
        // compiled. We mirror that behaviour here.
        if (is_redir_time64) {
            symbol(&recvmmsg_impl, "__recvmmsg_time64");
        } else {
            symbol(&recvmmsg_impl, "recvmmsg");
        }
    }

    // Subdirectory modules with real implementations
    _ = @import("network/dns.zig");
    _ = @import("network/resolver.zig");
}

fn networkEndian(comptime T: type, n: T) T {
    return switch (builtin.target.cpu.arch.endian()) {
        .little => @byteSwap(n),
        .big => n,
    };
}

const in6addr_any = in6_addr{ .__in6_union = .{ .__s6_addr = .{0} ** 16 } };

const in6addr_loopback = in6_addr{ .__in6_union = .{ .__s6_addr = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 } } };

fn htonl_impl(n: u32) callconv(.c) u32 {
    return networkEndian(u32, n);
}

fn htons_impl(n: u16) callconv(.c) u16 {
    return networkEndian(u16, n);
}

fn ntohl_impl(n: u32) callconv(.c) u32 {
    return networkEndian(u32, n);
}

fn ntohs_impl(n: u16) callconv(.c) u16 {
    return networkEndian(u16, n);
}

// ============================================================
// Socket syscall wrappers (socket, bind, listen, accept, accept4,
// connect, shutdown, socketpair). Mirrors musl/src/network/*.c —
// these are thin wrappers around the corresponding Linux syscalls
// (or `socketcall(2)` on legacy archs, handled by std.os.linux).
// ============================================================

const SOCK_CLOEXEC: c_int = linux.SOCK.CLOEXEC;
const SOCK_NONBLOCK: c_int = linux.SOCK.NONBLOCK;
const SOCK_EXTRA_FLAGS: c_int = SOCK_CLOEXEC | SOCK_NONBLOCK;
const O_NONBLOCK_U: usize = @as(u32, @bitCast(linux.O{ .NONBLOCK = true }));

fn socket_impl(domain: c_int, socket_type: c_int, protocol: c_int) callconv(.c) c_int {
    var raw = linux.socket(@bitCast(domain), @bitCast(socket_type), @bitCast(protocol));
    var signed: isize = @bitCast(raw);
    if ((signed == -@as(isize, @intFromEnum(linux.E.INVAL)) or
        signed == -@as(isize, @intFromEnum(linux.E.PROTONOSUPPORT))) and
        (socket_type & SOCK_EXTRA_FLAGS) != 0)
    {
        raw = linux.socket(
            @bitCast(domain),
            @bitCast(socket_type & ~SOCK_EXTRA_FLAGS),
            @bitCast(protocol),
        );
        signed = @bitCast(raw);
        if (signed < 0) return errno(raw);
        const fd: i32 = @intCast(signed);
        if ((socket_type & SOCK_CLOEXEC) != 0)
            _ = linux.fcntl(fd, linux.F.SETFD, @as(usize, linux.FD_CLOEXEC));
        if ((socket_type & SOCK_NONBLOCK) != 0)
            _ = linux.fcntl(fd, linux.F.SETFL, O_NONBLOCK_U);
    }
    return errno(raw);
}

fn bind_impl(fd: c_int, addr: *const linux.sockaddr, len: linux.socklen_t) callconv(.c) c_int {
    return errno(linux.bind(fd, addr, len));
}

fn listen_impl(fd: c_int, backlog: c_int) callconv(.c) c_int {
    return errno(linux.listen(fd, @bitCast(backlog)));
}

fn accept_impl(fd: c_int, addr: ?*linux.sockaddr, len: ?*linux.socklen_t) callconv(.c) c_int {
    return errno(linux.accept(fd, addr, len));
}

fn accept4_impl(fd: c_int, addr: ?*linux.sockaddr, len: ?*linux.socklen_t, flags: c_int) callconv(.c) c_int {
    if (flags == 0) return accept_impl(fd, addr, len);
    var ret = errno(linux.accept4(fd, addr, len, @bitCast(flags)));
    if (ret >= 0) return ret;
    const e = std.c._errno().*;
    if (e != @intFromEnum(linux.E.NOSYS) and e != @intFromEnum(linux.E.INVAL)) return ret;
    if ((flags & ~SOCK_EXTRA_FLAGS) != 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    ret = accept_impl(fd, addr, len);
    if (ret < 0) return ret;
    if ((flags & SOCK_CLOEXEC) != 0)
        _ = linux.fcntl(ret, linux.F.SETFD, @as(usize, linux.FD_CLOEXEC));
    if ((flags & SOCK_NONBLOCK) != 0)
        _ = linux.fcntl(ret, linux.F.SETFL, O_NONBLOCK_U);
    return ret;
}

fn connect_impl(fd: c_int, addr: *const linux.sockaddr, len: linux.socklen_t) callconv(.c) c_int {
    return errno(linux.connect(fd, addr, len));
}

fn shutdown_impl(fd: c_int, how: c_int) callconv(.c) c_int {
    return errno(linux.shutdown(fd, how));
}

fn socketpair_impl(domain: c_int, socket_type: c_int, protocol: c_int, fds: *[2]c_int) callconv(.c) c_int {
    var ret = errno(linux.socketpair(@bitCast(domain), @bitCast(socket_type), @bitCast(protocol), fds));
    if (ret < 0) {
        const e = std.c._errno().*;
        if ((e == @intFromEnum(linux.E.INVAL) or e == @intFromEnum(linux.E.PROTONOSUPPORT)) and
            (socket_type & SOCK_EXTRA_FLAGS) != 0)
        {
            ret = errno(linux.socketpair(
                @bitCast(domain),
                @bitCast(socket_type & ~SOCK_EXTRA_FLAGS),
                @bitCast(protocol),
                fds,
            ));
            if (ret < 0) return ret;
            if ((socket_type & SOCK_CLOEXEC) != 0) {
                _ = linux.fcntl(fds[0], linux.F.SETFD, @as(usize, linux.FD_CLOEXEC));
                _ = linux.fcntl(fds[1], linux.F.SETFD, @as(usize, linux.FD_CLOEXEC));
            }
            if ((socket_type & SOCK_NONBLOCK) != 0) {
                _ = linux.fcntl(fds[0], linux.F.SETFL, O_NONBLOCK_U);
                _ = linux.fcntl(fds[1], linux.F.SETFL, O_NONBLOCK_U);
            }
        }
    }
    return ret;
}

fn if_freenameindex_impl(idx: ?*if_nameindex_t) callconv(.c) void {
    c.free(idx);
}

fn if_indextoname_impl(index: c_uint, name: [*]u8) callconv(.c) ?[*]u8 {
    const fd = errno(linux.socket(linux.AF.UNIX, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC, 0));
    if (fd < 0) return null;

    var ifr: ifreq = undefined;
    ifr.ifr_ifru.ivalue = @bitCast(index);
    const r = errno(linux.ioctl(fd, SIOCGIFNAME, @intFromPtr(&ifr)));
    _ = linux.close(fd);
    if (r < 0) {
        if (std.c._errno().* == @intFromEnum(linux.E.NODEV)) {
            std.c._errno().* = @intFromEnum(linux.E.NXIO);
        }
        return null;
    }
    return c.strncpy(name, @ptrCast(&ifr.ifr_name), IF_NAMESIZE);
}

fn if_nametoindex_impl(name: [*:0]const u8) callconv(.c) c_uint {
    const fd = errno(linux.socket(linux.AF.UNIX, linux.SOCK.DGRAM | linux.SOCK.CLOEXEC, 0));
    if (fd < 0) return 0;

    var ifr: ifreq = undefined;
    _ = c.strncpy(&ifr.ifr_name, name, IF_NAMESIZE);
    const r = errno(linux.ioctl(fd, SIOCGIFINDEX, @intFromPtr(&ifr)));
    _ = linux.close(fd);
    if (r < 0) return 0;
    return @intCast(ifr.ifr_ifru.ivalue);
}

// ============================================================
// Socket info / option syscall wrappers
//   musl/src/network/{getsockname,getpeername,getsockopt,setsockopt,sockatmark}.c
// ============================================================

// musl's userspace `struct timeval` is always { i64 tv_sec; i64 tv_usec; }.
const timeval = extern struct {
    tv_sec: i64,
    tv_usec: i64,
};

const SOL_SOCKET: c_int = switch (builtin.cpu.arch) {
    .mips, .mipsel, .mips64, .mips64el => 65535,
    else => 1,
};

// Kernel "_OLD" option ids (used in time-bits-64 socket option syscalls).
// Mirrors musl's per-arch SO_RCVTIMEO_OLD/SO_SNDTIMEO_OLD in arch/*/syscall_arch.h
// and the defaults from src/internal/syscall.h.
const SO_RCVTIMEO_OLD: c_int = switch (builtin.cpu.arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => 18,
    .mips, .mipsel, .mips64, .mips64el => 0x1006,
    else => 20,
};
const SO_SNDTIMEO_OLD: c_int = switch (builtin.cpu.arch) {
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => 19,
    .mips, .mipsel, .mips64, .mips64el => 0x1005,
    else => 21,
};
const SO_TIMESTAMP_OLD: c_int = 29;
const SO_TIMESTAMPNS_OLD: c_int = 35;

// User-space `SO_*` values as exposed by musl's <sys/socket.h>.
// On time-bits-32 (32-bit long) targets without a bits/socket.h override,
// these are the "_NEW" ids; on time-bits-64 targets they coincide with
// the "_OLD" ids and no translation is performed.
const SO_RCVTIMEO: c_int = if (@bitSizeOf(c_long) == 32) 66 else SO_RCVTIMEO_OLD;
const SO_SNDTIMEO: c_int = if (@bitSizeOf(c_long) == 32) 67 else SO_SNDTIMEO_OLD;
const SO_TIMESTAMP: c_int = if (@bitSizeOf(c_long) == 32) 63 else SO_TIMESTAMP_OLD;
const SO_TIMESTAMPNS: c_int = if (@bitSizeOf(c_long) == 32) 64 else SO_TIMESTAMPNS_OLD;

const SIOCATMARK: u32 = switch (builtin.cpu.arch) {
    // Linux MIPS uses _IOR('s', 7, int) which evaluates to:
    //   (_IOC_READ=2)<<29 | sizeof(int)=4<<16 | 's'=0x73<<8 | 7 = 0x40047307
    .mips, .mipsel, .mips64, .mips64el => 0x40047307,
    else => 0x8905,
};

fn getsockname_impl(fd: c_int, addr: *linux.sockaddr, len: *linux.socklen_t) callconv(.c) c_int {
    return errno(linux.getsockname(fd, addr, len));
}

fn getpeername_impl(fd: c_int, addr: *linux.sockaddr, len: *linux.socklen_t) callconv(.c) c_int {
    return errno(linux.getpeername(fd, addr, len));
}

fn getsockopt_impl(
    fd: c_int,
    level: c_int,
    optname: c_int,
    optval: *anyopaque,
    optlen: *linux.socklen_t,
) callconv(.c) c_int {
    var r: isize = @bitCast(linux.getsockopt(
        fd,
        level,
        @bitCast(optname),
        @as([*]u8, @ptrCast(optval)),
        optlen,
    ));

    const enoprotoopt: isize = -@as(isize, @intFromEnum(linux.E.NOPROTOOPT));
    if (r == enoprotoopt and level == SOL_SOCKET) translate: {
        if (comptime SO_RCVTIMEO != SO_RCVTIMEO_OLD) {
            if (optname == SO_RCVTIMEO or optname == SO_SNDTIMEO) {
                if (optlen.* < @sizeOf(timeval)) {
                    std.c._errno().* = @intFromEnum(linux.E.INVAL);
                    return -1;
                }
                const new_optname: c_int = if (optname == SO_RCVTIMEO)
                    SO_RCVTIMEO_OLD
                else
                    SO_SNDTIMEO_OLD;
                var tv32: [2]c_long = undefined;
                var len32: linux.socklen_t = @sizeOf(@TypeOf(tv32));
                r = @bitCast(linux.getsockopt(
                    fd,
                    level,
                    @bitCast(new_optname),
                    @as([*]u8, @ptrCast(&tv32)),
                    &len32,
                ));
                if (r >= 0) {
                    const tv: *timeval = @ptrCast(@alignCast(optval));
                    tv.tv_sec = @intCast(tv32[0]);
                    tv.tv_usec = @intCast(tv32[1]);
                    optlen.* = @sizeOf(timeval);
                }
                break :translate;
            }
        }
        if (comptime SO_TIMESTAMP != SO_TIMESTAMP_OLD) {
            if (optname == SO_TIMESTAMP or optname == SO_TIMESTAMPNS) {
                const new_optname: c_int = if (optname == SO_TIMESTAMP)
                    SO_TIMESTAMP_OLD
                else
                    SO_TIMESTAMPNS_OLD;
                r = @bitCast(linux.getsockopt(
                    fd,
                    level,
                    @bitCast(new_optname),
                    @as([*]u8, @ptrCast(optval)),
                    optlen,
                ));
            }
        }
    }
    return errno(@bitCast(r));
}

// Mirror of musl's IS32BIT: true iff x fits in a signed 32-bit integer.
fn fitsI32(x: i64) bool {
    return x >= -0x80000000 and x <= 0x7fffffff;
}

// Mirror of musl's CLAMP: saturate to INT32_MIN/INT32_MAX, otherwise pass through.
fn clampI32(x: i64) c_long {
    if (fitsI32(x)) return @intCast(x);
    return if (x >= 0) 0x7fffffff else -0x80000000;
}

fn setsockopt_impl(
    fd: c_int,
    level: c_int,
    optname: c_int,
    optval: *const anyopaque,
    optlen: linux.socklen_t,
) callconv(.c) c_int {
    var r: isize = @bitCast(linux.setsockopt(
        fd,
        level,
        @bitCast(optname),
        @as([*]const u8, @ptrCast(optval)),
        optlen,
    ));

    const enoprotoopt: isize = -@as(isize, @intFromEnum(linux.E.NOPROTOOPT));
    if (r == enoprotoopt and level == SOL_SOCKET) translate: {
        if (comptime SO_RCVTIMEO != SO_RCVTIMEO_OLD) {
            if (optname == SO_RCVTIMEO or optname == SO_SNDTIMEO) {
                if (optlen < @sizeOf(timeval)) {
                    std.c._errno().* = @intFromEnum(linux.E.INVAL);
                    return -1;
                }
                const tv: *const timeval = @ptrCast(@alignCast(optval));
                const s = tv.tv_sec;
                const us = tv.tv_usec;
                if (!fitsI32(s)) {
                    std.c._errno().* = @intFromEnum(linux.E.OPNOTSUPP);
                    return -1;
                }
                const new_optname: c_int = if (optname == SO_RCVTIMEO)
                    SO_RCVTIMEO_OLD
                else
                    SO_SNDTIMEO_OLD;
                const args = [2]c_long{ @intCast(s), clampI32(us) };
                r = @bitCast(linux.setsockopt(
                    fd,
                    level,
                    @bitCast(new_optname),
                    @as([*]const u8, @ptrCast(&args)),
                    2 * @sizeOf(c_long),
                ));
                break :translate;
            }
        }
        if (comptime SO_TIMESTAMP != SO_TIMESTAMP_OLD) {
            if (optname == SO_TIMESTAMP or optname == SO_TIMESTAMPNS) {
                const new_optname: c_int = if (optname == SO_TIMESTAMP)
                    SO_TIMESTAMP_OLD
                else
                    SO_TIMESTAMPNS_OLD;
                r = @bitCast(linux.setsockopt(
                    fd,
                    level,
                    @bitCast(new_optname),
                    @as([*]const u8, @ptrCast(optval)),
                    optlen,
                ));
            }
        }
    }
    return errno(@bitCast(r));
}

fn sockatmark_impl(s: c_int) callconv(.c) c_int {
    var ret: c_int = undefined;
    const rc: isize = @bitCast(linux.ioctl(s, SIOCATMARK, @intFromPtr(&ret)));
    if (rc < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-rc);
        return -1;
    }
    return ret;
}

fn ptrDiff(a: [*]const u8, b: [*]const u8) usize {
    const aa = @intFromPtr(a);
    const bb = @intFromPtr(b);
    return if (aa >= bb) aa - bb else 0;
}

var gethostbyname2_static: ?[*]u8 = null;
var gethostbyaddr_static: ?[*]u8 = null;
var getservbyname_static: servent = std.mem.zeroes(servent);
var getservbyname_buf: [2]?[*:0]u8 = undefined;
var getservbyport_static: servent = std.mem.zeroes(servent);
var getservbyport_buf: [32]u8 align(@alignOf(c_long)) = undefined;

fn gethostbyname_impl(name: [*:0]const u8) callconv(.c) ?*hostent {
    return gethostbyname2_impl(name, linux.AF.INET);
}

fn gethostbyname2_impl(name: [*:0]const u8, af: c_int) callconv(.c) ?*hostent {
    const NO_RECOVERY: c_int = 3;
    const ERANGE: c_int = 34;

    var size: usize = 63;
    var res: ?*hostent = null;
    var err: c_int = undefined;
    while (true) {
        if (gethostbyname2_static) |h| c.free(h);
        size += size + 1;
        gethostbyname2_static = c.malloc(size);
        const h_mem = gethostbyname2_static orelse {
            c.h_errno_ptr.* = NO_RECOVERY;
            return null;
        };
        const h: *hostent = @ptrCast(@alignCast(h_mem));
        err = c.gethostbyname2_r_fn(name, af, h, h_mem + @sizeOf(hostent), size - @sizeOf(hostent), &res, c.h_errno_ptr);
        if (err != ERANGE) break;
    }
    return res;
}

fn gethostbyname_r_impl(name: [*:0]const u8, h: *hostent, buf: [*]u8, buflen: usize, res: *?*hostent, err: *c_int) callconv(.c) c_int {
    return c.gethostbyname2_r_fn(name, linux.AF.INET, h, buf, buflen, res, err);
}

fn gethostbyaddr_impl(a: *const anyopaque, l: linux.socklen_t, af: c_int) callconv(.c) ?*hostent {
    const NO_RECOVERY: c_int = 3;
    const ERANGE: c_int = 34;

    var size: usize = 63;
    var res: ?*hostent = null;
    var err: c_int = undefined;
    while (true) {
        if (gethostbyaddr_static) |h| c.free(h);
        size += size + 1;
        gethostbyaddr_static = c.malloc(size);
        const h_mem = gethostbyaddr_static orelse {
            c.h_errno_ptr.* = NO_RECOVERY;
            return null;
        };
        const h: *hostent = @ptrCast(@alignCast(h_mem));
        err = c.gethostbyaddr_r_fn(a, l, af, h, h_mem + @sizeOf(hostent), size - @sizeOf(hostent), &res, c.h_errno_ptr);
        if (err != ERANGE) break;
    }
    return res;
}

fn getservbyname_impl(name: [*:0]const u8, prots: ?[*:0]const u8) callconv(.c) ?*servent {
    var res: ?*servent = null;
    const buf: [*]u8 = @ptrCast(&getservbyname_buf);
    if (c.getservbyname_r_fn(name, prots, &getservbyname_static, buf, @sizeOf(@TypeOf(getservbyname_buf)), &res) != 0) return null;
    return &getservbyname_static;
}

fn getservbyport_impl(port: c_int, prots: ?[*:0]const u8) callconv(.c) ?*servent {
    var res: ?*servent = null;
    const buf: [*]u8 = @ptrCast(&getservbyport_buf);
    if (c.getservbyport_r_fn(port, prots, &getservbyport_static, buf, getservbyport_buf.len, &res) != 0) return null;
    return &getservbyport_static;
}

fn getnetbyaddr_impl(net: u32, type_arg: c_int) callconv(.c) ?*anyopaque {
    _ = net;
    _ = type_arg;
    return null;
}

fn getnetbyname_impl(name: [*:0]const u8) callconv(.c) ?*anyopaque {
    _ = name;
    return null;
}

fn endservent_impl() callconv(.c) void {}

fn setservent_impl(stayopen: c_int) callconv(.c) void {
    _ = stayopen;
}

fn getservent_impl() callconv(.c) ?*servent {
    return null;
}

fn dn_expand_impl(base: [*]const u8, end: [*]const u8, src: [*]const u8, dest_arg: [*]u8, space: c_int) callconv(.c) c_int {
    var p = src;
    var dest = dest_arg;
    const dbegin = dest_arg;
    var len: c_int = -1;

    if (@intFromPtr(p) == @intFromPtr(end) or space <= 0) return -1;

    const space_u: usize = @intCast(space);
    const dend = dest_arg + @min(space_u, 254);

    // Detect reference loops using the same iteration counter as musl.
    var i: usize = 0;
    const msg_len = ptrDiff(end, base);
    while (i < msg_len) : (i += 2) {
        if ((p[0] & 0xc0) != 0) {
            if (@intFromPtr(p + 1) == @intFromPtr(end)) return -1;
            const j: usize = (@as(usize, p[0] & 0x3f) << 8) | p[1];
            if (len < 0) len = @intCast(@intFromPtr(p + 2) - @intFromPtr(src));
            if (j >= msg_len) return -1;
            p = base + j;
        } else if (p[0] != 0) {
            if (@intFromPtr(dest) != @intFromPtr(dbegin)) {
                dest[0] = '.';
                dest += 1;
            }
            var j: usize = p[0];
            p += 1;
            if (j >= ptrDiff(end, p) or j >= ptrDiff(dend, dest)) return -1;
            while (j > 0) : (j -= 1) {
                dest[0] = p[0];
                dest += 1;
                p += 1;
            }
        } else {
            dest[0] = 0;
            if (len < 0) len = @intCast(@intFromPtr(p + 1) - @intFromPtr(src));
            return len;
        }
    }
    return -1;
}

fn dn_skipname_impl(s: [*]const u8, end: [*]const u8) callconv(.c) c_int {
    var p = s;
    while (@intFromPtr(p) < @intFromPtr(end)) {
        if (p[0] == 0) return @intCast(@intFromPtr(p) - @intFromPtr(s) + 1);
        if (p[0] >= 192) {
            if (@intFromPtr(p + 1) < @intFromPtr(end)) return @intCast(@intFromPtr(p) - @intFromPtr(s) + 2);
            break;
        }
        const step: usize = @as(usize, p[0]) + 1;
        if (ptrDiff(end, p) < step) break;
        p += step;
    }
    return -1;
}

const DnsParseCallback = *const fn (?*anyopaque, c_int, *const anyopaque, c_int, *const anyopaque, c_int) callconv(.c) c_int;

fn dns_parse_impl(r: [*]const u8, rlen: c_int, callback: DnsParseCallback, ctx: ?*anyopaque) callconv(.c) c_int {
    if (rlen < 12) return -1;
    if ((r[3] & 15) != 0) return 0;

    const rlen_u: usize = @intCast(rlen);
    const rend = r + rlen_u;
    var p = r + 12;
    var qdcount: c_int = @as(c_int, r[4]) * 256 + r[5];
    var ancount: c_int = @as(c_int, r[6]) * 256 + r[7];

    while (qdcount > 0) : (qdcount -= 1) {
        while (@intFromPtr(p) - @intFromPtr(r) < rlen_u and p[0] > 0 and p[0] < 128) p += 1;
        if (@intFromPtr(p) > @intFromPtr(rend) - 6) return -1;
        p += 5 + @as(usize, @intFromBool(p[0] != 0));
    }
    while (ancount > 0) : (ancount -= 1) {
        while (@intFromPtr(p) - @intFromPtr(r) < rlen_u and p[0] > 0 and p[0] < 128) p += 1;
        if (@intFromPtr(p) > @intFromPtr(rend) - 12) return -1;
        p += 1 + @as(usize, @intFromBool(p[0] != 0));
        const len: c_int = @as(c_int, p[8]) * 256 + p[9];
        if (@as(usize, @intCast(len)) + 10 > ptrDiff(rend, p)) return -1;
        if (callback(ctx, p[1], p + 10, len, r, rlen) < 0) return -1;
        p += 10 + @as(usize, @intCast(len));
    }
    return 0;
}

fn res_init_impl() callconv(.c) c_int {
    return 0;
}

var res_state_storage: res_state = std.mem.zeroes(res_state);

fn res_state_impl() callconv(.c) *res_state {
    return &res_state_storage;
}

fn asciiIsDigit(ch: u8) bool {
    return ch >= '0' and ch <= '9';
}

fn hexval(c0: u8) c_int {
    if (c0 -% '0' < 10) return c0 - '0';
    const c1 = c0 | 32;
    if (c1 -% 'a' < 6) return c1 - 'a' + 10;
    return -1;
}

fn inet_addr_impl(p: [*:0]const u8) callconv(.c) in_addr_t {
    var a: in_addr = undefined;
    if (inet_aton_impl(p, &a) == 0) return std.math.maxInt(in_addr_t);
    return a.s_addr;
}

fn parseLegacyNumber(s: [*:0]const u8, z: *[*:0]const u8) c_ulong {
    var p = s;
    var base: c_ulong = 10;
    if (p[0] == '0') {
        base = 8;
        if ((p[1] == 'x' or p[1] == 'X') and std.ascii.isHex(p[2])) {
            base = 16;
            p += 2;
        }
    }

    var n: c_ulong = 0;
    while (true) : (p += 1) {
        const digit: c_ulong = switch (p[0]) {
            '0'...'9' => p[0] - '0',
            'a'...'f' => p[0] - 'a' + 10,
            'A'...'F' => p[0] - 'A' + 10,
            else => break,
        };
        if (digit >= base) break;
        n = std.math.mul(c_ulong, n, base) catch std.math.maxInt(c_ulong);
        n = std.math.add(c_ulong, n, digit) catch std.math.maxInt(c_ulong);
    }
    z.* = p;
    return n;
}

fn inet_aton_impl(s0: [*:0]const u8, dest: *in_addr) callconv(.c) c_int {
    var s: [*:0]const u8 = s0;
    const d: *[4]u8 = @ptrCast(dest);
    var a = [4]c_ulong{ 0, 0, 0, 0 };
    var i: usize = 0;

    while (i < 4) : (i += 1) {
        var z: [*:0]const u8 = undefined;
        a[i] = parseLegacyNumber(s, &z);
        if (z == s or (z[0] != 0 and z[0] != '.') or !asciiIsDigit(s[0])) return 0;
        if (z[0] == 0) break;
        s = z + 1;
    }
    if (i == 4) return 0;

    switch (i) {
        0 => {
            a[1] = a[0] & 0xffffff;
            a[0] >>= 24;
            a[2] = a[1] & 0xffff;
            a[1] >>= 16;
            a[3] = a[2] & 0xff;
            a[2] >>= 8;
        },
        1 => {
            a[2] = a[1] & 0xffff;
            a[1] >>= 16;
            a[3] = a[2] & 0xff;
            a[2] >>= 8;
        },
        2 => {
            a[3] = a[2] & 0xff;
            a[2] >>= 8;
        },
        else => {},
    }

    i = 0;
    while (i < 4) : (i += 1) {
        if (a[i] > 255) return 0;
        d[i] = @intCast(a[i]);
    }
    return 1;
}

fn inet_pton_impl(af: c_int, s0: [*:0]const u8, a0: *anyopaque) callconv(.c) c_int {
    var s = s0;
    const a: [*]u8 = @ptrCast(a0);
    var ip: [8]u16 = undefined;
    var brk: c_int = -1;
    var need_v4 = false;

    if (af == linux.AF.INET) {
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var v: c_int = 0;
            var j: usize = 0;
            while (j < 3 and asciiIsDigit(s[j])) : (j += 1) {
                v = 10 * v + s[j] - '0';
            }
            if (j == 0 or (j > 1 and s[0] == '0') or v > 255) return 0;
            a[i] = @intCast(v);
            if (s[j] == 0 and i == 3) return 1;
            if (s[j] != '.') return 0;
            s += j + 1;
        }
        return 0;
    } else if (af != linux.AF.INET6) {
        std.c._errno().* = @intFromEnum(linux.E.AFNOSUPPORT);
        return -1;
    }

    if (s[0] == ':') {
        s += 1;
        if (s[0] != ':') return 0;
    }

    var i: c_int = 0;
    while (true) : (i += 1) {
        if (s[0] == ':' and brk < 0) {
            brk = i;
            ip[@intCast(i & 7)] = 0;
            s += 1;
            if (s[0] == 0) break;
            if (i == 7) return 0;
            continue;
        }

        var v: c_int = 0;
        var j: usize = 0;
        var d = hexval(s[j]);
        while (j < 4 and d >= 0) : ({
            j += 1;
            d = hexval(s[j]);
        }) {
            v = 16 * v + d;
        }
        if (j == 0) return 0;
        ip[@intCast(i & 7)] = @intCast(v);
        if (s[j] == 0 and (brk >= 0 or i == 7)) break;
        if (i == 7) return 0;
        if (s[j] != ':') {
            if (s[j] != '.' or (i < 6 and brk < 0)) return 0;
            need_v4 = true;
            i += 1;
            ip[@intCast(i & 7)] = 0;
            break;
        }
        s += j + 1;
    }

    if (brk >= 0) {
        const src: usize = @intCast(brk);
        const dst: usize = @intCast(brk + 7 - i);
        const count: usize = @intCast(i + 1 - brk);
        std.mem.copyBackwards(u16, ip[dst..][0..count], ip[src..][0..count]);
        var j: usize = 0;
        while (j < @as(usize, @intCast(7 - i))) : (j += 1) {
            ip[src + j] = 0;
        }
    }

    var out: [*]u8 = a;
    var j: usize = 0;
    while (j < 8) : (j += 1) {
        // musl `out[0] = ip[j]>>8; out[1] = ip[j];` — both rely on the
        // implicit C truncation from unsigned short to unsigned char.
        // `@intCast(ip[j])` is undefined behaviour whenever `ip[j] > 0xff`,
        // which LLVM exploits in optimised builds to assume `ip[j] < 256`
        // and propagate that back through the parsing loop, silently
        // dropping the high byte of every group (so `ffff` decodes as
        // `00 ff`). Use `@truncate` to make the byte truncation explicit
        // and well-defined.
        out[0] = @truncate(ip[j] >> 8);
        out[1] = @truncate(ip[j]);
        out += 2;
    }
    if (need_v4 and inet_pton_impl(linux.AF.INET, s, a + 12) <= 0) return 0;
    return 1;
}

fn inet_network_impl(p: [*:0]const u8) callconv(.c) in_addr_t {
    return ntohl_impl(inet_addr_impl(p));
}

fn inet_makeaddr_impl(n: in_addr_t, host: in_addr_t) callconv(.c) in_addr {
    var h = host;
    if (n < 256) {
        h |= n << 24;
    } else if (n < 65536) {
        h |= n << 16;
    } else {
        h |= n << 8;
    }
    return .{ .s_addr = h };
}

fn inet_lnaof_impl(in: in_addr) callconv(.c) in_addr_t {
    const h = in.s_addr;
    if (h >> 24 < 128) return h & 0xffffff;
    if (h >> 24 < 192) return h & 0xffff;
    return h & 0xff;
}

fn inet_netof_impl(in: in_addr) callconv(.c) in_addr_t {
    const h = in.s_addr;
    if (h >> 24 < 128) return h >> 24;
    if (h >> 24 < 192) return h >> 16;
    return h >> 8;
}

var inet_ntoa_buf: [16]u8 = undefined;

fn inet_ntoa_impl(in: in_addr_t) callconv(.c) [*]u8 {
    // The previous version went through `snprintf("%d.%d.%d.%d", a[0],
    // a[1], a[2], a[3])`, but Zig does not apply C's default-argument
    // promotion to variadic args: each `u8` was passed in its natural
    // 1-byte width while libc's `snprintf` read 4 bytes per `%d`,
    // producing `0.0.0.0` for every nonzero address on aarch64.
    //
    // Take the address as a plain `in_addr_t` (u32) rather than the
    // `in_addr` extern struct wrapper. A struct{u32} value parameter
    // is supposed to match the u32 ABI on aarch64, but the optimiser
    // wasn't preserving the argument bits through the struct param
    // (it folded `inet_ntoa_impl` to a constant `0.0.0.0` store).
    // The C declaration `inet_ntoa(struct in_addr)` and `inet_ntoa(uint32_t)`
    // both pass the value in the low 32 bits of x0, so the C ABI is
    // unchanged.
    // Match musl's byte-wise access through `(unsigned char *)&in`.
    // Shifting the integer value reverses the address on big-endian targets.
    const bytes: [4]u8 = @bitCast(in);
    var len: usize = 0;
    inetNtopWriteUnsigned(&inet_ntoa_buf, &len, 10, bytes[0]);
    inetNtopWriteByte(&inet_ntoa_buf, &len, '.');
    inetNtopWriteUnsigned(&inet_ntoa_buf, &len, 10, bytes[1]);
    inetNtopWriteByte(&inet_ntoa_buf, &len, '.');
    inetNtopWriteUnsigned(&inet_ntoa_buf, &len, 10, bytes[2]);
    inetNtopWriteByte(&inet_ntoa_buf, &len, '.');
    inetNtopWriteUnsigned(&inet_ntoa_buf, &len, 10, bytes[3]);
    inet_ntoa_buf[len] = 0;
    return &inet_ntoa_buf;
}

fn expectInetNtoa(bytes: [4]u8, expected: []const u8) !void {
    const in: in_addr_t = @bitCast(bytes);
    try std.testing.expectEqualStrings(expected, std.mem.sliceTo(inet_ntoa_impl(in), 0));
}

test "inet_ntoa_impl formats network-order bytes" {
    try expectInetNtoa(.{ 0, 0, 0, 0 }, "0.0.0.0");
    try expectInetNtoa(.{ 0x7f, 0x00, 0x00, 0x01 }, "127.0.0.1");
    try expectInetNtoa(.{ 0x0a, 0x00, 0x80, 0x1f }, "10.0.128.31");
    try expectInetNtoa(.{ 0xff, 0xff, 0xff, 0xff }, "255.255.255.255");
}

fn inetNtopWriteByte(dst: [*]u8, pos: *usize, byte: u8) void {
    dst[pos.*] = byte;
    pos.* += 1;
}

fn inetNtopWriteUnsigned(dst: [*]u8, pos: *usize, comptime base: u8, n0: u32) void {
    var buf: [10]u8 = undefined;
    var n = n0;
    var len: usize = 0;
    while (true) {
        const digit: u8 = @intCast(n % base);
        buf[len] = if (digit < 10) '0' + digit else 'a' + digit - 10;
        len += 1;
        n /= base;
        if (n == 0) break;
    }
    while (len > 0) {
        len -= 1;
        inetNtopWriteByte(dst, pos, buf[len]);
    }
}

fn inetNtopStrspnColonZero(s: [*]const u8) usize {
    var n: usize = 0;
    while (s[n] == ':' or s[n] == '0') : (n += 1) {}
    return n;
}

fn inet_ntop_impl(af: c_int, a0: *const anyopaque, s: [*]u8, l: linux.socklen_t) callconv(.c) ?[*]u8 {
    const a: [*]const u8 = @ptrCast(a0);
    var buf: [100]u8 = undefined;
    var len: usize = 0;

    switch (af) {
        linux.AF.INET => {
            // Write into the local buffer first; only copy into `s`
            // after a bounds check. The previous version wrote into
            // `s` directly and only validated `len < l` afterwards,
            // which let `inet_ntop(AF_INET, "xxxx", "", 0)` overrun
            // a zero-length destination (segfaulting libc-test's
            // ENOSPC error-path test). Mirrors musl's `snprintf(s, l, …)`.
            inetNtopWriteUnsigned(&buf, &len, 10, a[0]);
            inetNtopWriteByte(&buf, &len, '.');
            inetNtopWriteUnsigned(&buf, &len, 10, a[1]);
            inetNtopWriteByte(&buf, &len, '.');
            inetNtopWriteUnsigned(&buf, &len, 10, a[2]);
            inetNtopWriteByte(&buf, &len, '.');
            inetNtopWriteUnsigned(&buf, &len, 10, a[3]);
            buf[len] = 0;
            if (len < l) {
                @memcpy(s[0 .. len + 1], buf[0 .. len + 1]);
                return s;
            }
        },
        linux.AF.INET6 => {
            const v4_prefix = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff };
            const is_v4_mapped = std.mem.eql(u8, a[0..12], &v4_prefix);

            var group: usize = 0;
            while (group < 6) : (group += 1) {
                if (group != 0) inetNtopWriteByte(&buf, &len, ':');
                inetNtopWriteUnsigned(&buf, &len, 16, 256 * @as(u32, a[2 * group]) + a[2 * group + 1]);
            }
            inetNtopWriteByte(&buf, &len, ':');
            if (is_v4_mapped) {
                inetNtopWriteUnsigned(&buf, &len, 10, a[12]);
                inetNtopWriteByte(&buf, &len, '.');
                inetNtopWriteUnsigned(&buf, &len, 10, a[13]);
                inetNtopWriteByte(&buf, &len, '.');
                inetNtopWriteUnsigned(&buf, &len, 10, a[14]);
                inetNtopWriteByte(&buf, &len, '.');
                inetNtopWriteUnsigned(&buf, &len, 10, a[15]);
            } else {
                inetNtopWriteUnsigned(&buf, &len, 16, 256 * @as(u32, a[12]) + a[13]);
                inetNtopWriteByte(&buf, &len, ':');
                inetNtopWriteUnsigned(&buf, &len, 16, 256 * @as(u32, a[14]) + a[15]);
            }
            buf[len] = 0;

            var i: usize = 0;
            var best: usize = 0;
            var max: usize = 2;
            while (buf[i] != 0) : (i += 1) {
                if (i != 0 and buf[i] != ':') continue;
                const j = inetNtopStrspnColonZero(buf[i..].ptr);
                if (j > max) {
                    best = i;
                    max = j;
                }
            }
            if (max > 3) {
                buf[best] = ':';
                buf[best + 1] = ':';
                const tail_start = best + max;
                const tail_len = i - tail_start + 1;
                std.mem.copyForwards(u8, buf[best + 2 ..][0..tail_len], buf[tail_start..][0..tail_len]);
                len = best + 2 + tail_len - 1;
            }

            if (len < l) {
                @memcpy(s[0 .. len + 1], buf[0 .. len + 1]);
                return s;
            }
        },
        else => {
            std.c._errno().* = @intFromEnum(linux.E.AFNOSUPPORT);
            return null;
        },
    }

    std.c._errno().* = @intFromEnum(linux.E.NOSPC);
    return null;
}

// ============================================================
// proto.c — static protocol-number table + getprotoent family
// ============================================================

const protoent = extern struct {
    p_name: ?[*:0]u8,
    p_aliases: ?[*]?[*:0]const u8,
    p_proto: c_int,
};

// Ported verbatim from musl's `protos` table in src/network/proto.c.
// Each record is encoded as <proto_byte><name bytes><\0>, concatenated
// end-to-end. Includes the implicit trailing \0 that musl's C string
// literal initializer adds, so `protos.len` matches `sizeof(protos)`.
const protos =
    "\x00ip\x00" ++
    "\x01icmp\x00" ++
    "\x02igmp\x00" ++
    "\x03ggp\x00" ++
    "\x04ipencap\x00" ++
    "\x05st\x00" ++
    "\x06tcp\x00" ++
    "\x08egp\x00" ++
    "\x0cpup\x00" ++
    "\x11udp\x00" ++
    "\x14hmp\x00" ++
    "\x16xns-idp\x00" ++
    "\x1brdp\x00" ++
    "\x1diso-tp4\x00" ++
    "\x24xtp\x00" ++
    "\x25ddp\x00" ++
    "\x26idpr-cmtp\x00" ++
    "\x29ipv6\x00" ++
    "\x2bipv6-route\x00" ++
    "\x2cipv6-frag\x00" ++
    "\x2didrp\x00" ++
    "\x2ersvp\x00" ++
    "\x2fgre\x00" ++
    "\x32esp\x00" ++
    "\x33ah\x00" ++
    "\x39skip\x00" ++
    "\x3aipv6-icmp\x00" ++
    "\x3bipv6-nonxt\x00" ++
    "\x3cipv6-opts\x00" ++
    "\x49rspf\x00" ++
    "\x51vmtp\x00" ++
    "\x59ospf\x00" ++
    "\x5eipip\x00" ++
    "\x62encap\x00" ++
    "\x67pim\x00" ++
    "\xffraw\x00";

var proto_idx: usize = 0;
var proto_aliases: ?[*:0]const u8 = null;
var proto_ent: protoent = .{ .p_name = null, .p_aliases = null, .p_proto = 0 };

fn endprotoent_impl() callconv(.c) void {
    proto_idx = 0;
}

fn setprotoent_impl(stayopen: c_int) callconv(.c) void {
    _ = stayopen;
    proto_idx = 0;
}

fn getprotoent_impl() callconv(.c) ?*protoent {
    if (proto_idx >= protos.len) return null;
    proto_ent.p_proto = protos[proto_idx];
    const name_ptr: [*:0]const u8 = @ptrCast(protos[proto_idx + 1 ..].ptr);
    proto_ent.p_name = @constCast(name_ptr);
    proto_ent.p_aliases = @ptrCast(&proto_aliases);
    proto_idx += c.strlen(name_ptr) + 2;
    return &proto_ent;
}

fn getprotobyname_impl(name: [*:0]const u8) callconv(.c) ?*protoent {
    endprotoent_impl();
    while (getprotoent_impl()) |p| {
        if (c.strcmp(name, @ptrCast(p.p_name.?)) == 0) return p;
    }
    return null;
}

fn getprotobynumber_impl(num: c_int) callconv(.c) ?*protoent {
    endprotoent_impl();
    while (getprotoent_impl()) |p| {
        if (p.p_proto == num) return p;
    }
    return null;
}

// ============================================================
// ent.c — set/end/get hostent and netent stubs (+ weak aliases)
// ============================================================

fn sethostent_impl(x: c_int) callconv(.c) void {
    _ = x;
}

fn endhostent_impl() callconv(.c) void {}

fn gethostent_impl() callconv(.c) ?*hostent {
    return null;
}

fn getnetent_impl() callconv(.c) ?*anyopaque {
    return null;
}

// ============================================================
// ether.c — ether_aton / ether_ntoa (+ _r forms) and stubs
// ============================================================

const ether_addr = extern struct {
    ether_addr_octet: [6]u8,
};

var ether_aton_static: ether_addr = .{ .ether_addr_octet = .{0} ** 6 };
var ether_ntoa_static: [18]u8 = undefined;

fn ether_aton_r_impl(x: [*:0]const u8, p_a: *ether_addr) callconv(.c) ?*ether_addr {
    var a: ether_addr = undefined;
    var xp: [*:0]const u8 = x;
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        if (i != 0) {
            if (xp[0] != ':') return null;
            xp += 1;
        }
        var y: [*:0]u8 = undefined;
        const n = c.strtoul(xp, &y, 16);
        xp = y;
        if (n > 0xff) return null;
        a.ether_addr_octet[i] = @intCast(n);
    }
    if (xp[0] != 0) return null;
    p_a.* = a;
    return p_a;
}

fn ether_aton_impl(x: [*:0]const u8) callconv(.c) ?*ether_addr {
    return ether_aton_r_impl(x, &ether_aton_static);
}

fn ether_ntoa_r_impl(p_a: *const ether_addr, x: [*]u8) callconv(.c) [*]u8 {
    const hex = "0123456789ABCDEF";
    var idx: usize = 0;
    var i: usize = 0;
    while (i < 6) : (i += 1) {
        if (i != 0) {
            x[idx] = ':';
            idx += 1;
        }
        const b = p_a.ether_addr_octet[i];
        x[idx] = hex[(b >> 4) & 0xf];
        x[idx + 1] = hex[b & 0xf];
        idx += 2;
    }
    x[idx] = 0;
    return x;
}

fn ether_ntoa_impl(p_a: *const ether_addr) callconv(.c) [*]u8 {
    return ether_ntoa_r_impl(p_a, &ether_ntoa_static);
}

fn ether_line_impl(l: [*:0]const u8, e: *ether_addr, hostname: [*]u8) callconv(.c) c_int {
    _ = l;
    _ = e;
    _ = hostname;
    return -1;
}

fn ether_ntohost_impl(hostname: [*]u8, e: *const ether_addr) callconv(.c) c_int {
    _ = hostname;
    _ = e;
    return -1;
}

fn ether_hostton_impl(hostname: [*:0]const u8, e: *ether_addr) callconv(.c) c_int {
    _ = hostname;
    _ = e;
    return -1;
}

// ============================================================
// h_errno.c — h_errno global + __h_errno_location accessor
// ============================================================

// musl's h_errno.c falls back to a process-global `h_errno` when the
// thread's pthread stack isn't set up. We use a plain global so the
// existing `@extern(*c_int, .{ .name = "h_errno" })` references inside
// network.zig / network/dns.zig / network/resolver.zig resolve to the
// same backing storage that `__h_errno_location` returns.
var h_errno_storage: c_int = 0;

fn __h_errno_location_impl() callconv(.c) *c_int {
    return &h_errno_storage;
}

// ============================================================
// hstrerror.c / herror.c / gai_strerror.c — packed message tables
// ============================================================

// Ported verbatim from musl's `msgs` table in src/network/hstrerror.c.
// `\x00Unknown error` is the catch-all suffix used when ecode is 0 or
// past the end of the known table.
const hstrerror_msgs =
    "Host not found\x00" ++
    "Try again\x00" ++
    "Non-recoverable error\x00" ++
    "Address not available\x00" ++
    "\x00Unknown error";

fn hstrerror_impl(ecode: c_int) callconv(.c) [*:0]const u8 {
    var s: [*]const u8 = hstrerror_msgs;
    var e: c_int = ecode -% 1;
    while (e != 0 and s[0] != 0) {
        while (s[0] != 0) : (s += 1) {}
        e -%= 1;
        s += 1;
    }
    if (s[0] == 0) s += 1;
    return @ptrCast(s);
}

fn herror_impl(msg: ?[*:0]const u8) callconv(.c) void {
    // musl writes to stderr via fprintf; stderr is unbuffered by default
    // so a direct write(2, ...) syscall is functionally equivalent.
    if (msg) |m| {
        const mlen = c.strlen(m);
        _ = linux.write(2, m, mlen);
        _ = linux.write(2, ": ", 2);
    }
    const h = hstrerror_impl(h_errno_storage);
    const hlen = c.strlen(h);
    _ = linux.write(2, h, hlen);
    _ = linux.write(2, "\n", 1);
}

// Ported verbatim from musl's `msgs` table in src/network/gai_strerror.c.
const gai_strerror_msgs =
    "Invalid flags\x00" ++
    "Name does not resolve\x00" ++
    "Try again\x00" ++
    "Non-recoverable error\x00" ++
    "Name has no usable address\x00" ++
    "Unrecognized address family or invalid length\x00" ++
    "Unrecognized socket type\x00" ++
    "Unrecognized service\x00" ++
    "Unknown error\x00" ++
    "Out of memory\x00" ++
    "System error\x00" ++
    "Overflow\x00" ++
    "\x00Unknown error";

fn gai_strerror_impl(ecode: c_int) callconv(.c) [*:0]const u8 {
    // EAI_* error codes are negative, so musl uses `ecode++` (mirroring
    // hstrerror's `ecode--` for positive HOST_* codes).
    var s: [*]const u8 = gai_strerror_msgs;
    var e: c_int = ecode +% 1;
    while (e != 0 and s[0] != 0) {
        while (s[0] != 0) : (s += 1) {}
        e +%= 1;
        s += 1;
    }
    if (s[0] == 0) s += 1;
    return @ptrCast(s);
}

// ============================================================
// send.c / sendto.c / sendmsg.c / sendmmsg.c
// recv.c / recvfrom.c / recvmsg.c / recvmmsg.c
// ============================================================
//
// musl exposes a user-visible `struct msghdr` whose `msg_iovlen` and
// `msg_controllen` are `int`/`socklen_t` plus matching `__pad1`/`__pad2`
// fields on LP64 ABIs (so the 8-byte slot fed to the kernel's `size_t`
// fields matches up after the pad halves are zeroed). On LP32 ABIs the
// layout matches the kernel directly and no fixup is needed. See
// `lib/libc/musl/include/sys/socket.h`.

const native_arch = builtin.cpu.arch;
const is_le = native_arch.endian() == .little;
const lp64 = @sizeOf(c_long) > @sizeOf(c_int);
const is_x32 = builtin.target.abi == .muslx32 or builtin.target.abi == .gnux32;

// `_REDIR_TIME64` is set on the LP32 Linux archs that musl includes in
// its time32 compat list. On these targets the user-visible <sys/socket.h>
// `__REDIR(recvmmsg, __recvmmsg_time64)` makes the legacy 32-bit time_t
// `recvmmsg` symbol coexist with a new 64-bit time_t `__recvmmsg_time64`
// (defined by `src/network/recvmmsg.c`, which is what we are migrating).
const is_redir_time64 = switch (native_arch) {
    .arm, .armeb, .thumb, .thumbeb => true,
    .x86 => true,
    .m68k => true,
    .mips, .mipsel => true,
    .powerpc, .powerpcle => true,
    .mips64, .mips64el => switch (builtin.target.abi) {
        .gnuabin32, .muslabin32 => true,
        else => false,
    },
    else => false,
};

// musl's user-visible `struct timespec` post time64 conversion. On LP64
// (and x32) `tv_sec`/`tv_nsec` are both `long` (8 bytes). On LP32 archs
// the kernel-time64 transition kept `time_t` 64-bit while `long` stayed
// 32-bit, so `tv_nsec` is packed against a 32-bit pad. Either way the
// struct is 16 bytes and `tv_sec` is the leading i64.
const musl_timespec = extern struct {
    sec: i64,
    nsec_raw: i64,
};

fn muslTsNsec(ts: musl_timespec) i64 {
    if (lp64) return ts.nsec_raw;
    // LP32: tv_nsec is the natively-aligned `long` slot, which is the
    // low 32 bits of `nsec_raw` on both little and big endian (BE stores
    // the 4-byte pad first, so the long is still at the low bits when
    // we view the 8-byte slot as an i64).
    const lo: i32 = @truncate(ts.nsec_raw);
    return lo;
}

// musl `struct msghdr` exact layout (matches <sys/socket.h>). On LP64 the
// pad fields make the 8-byte slots line up with the kernel's `size_t`
// `msg_iovlen`/`msg_controllen`; on LP32 there are no pads.
const c_msghdr = if (lp64 and is_le) extern struct {
    msg_name: ?*anyopaque,
    msg_namelen: linux.socklen_t,
    msg_iov: ?*anyopaque,
    msg_iovlen: c_int,
    __pad1: c_int,
    msg_control: ?*anyopaque,
    msg_controllen: linux.socklen_t,
    __pad2: linux.socklen_t,
    msg_flags: c_int,
} else if (lp64) extern struct {
    msg_name: ?*anyopaque,
    msg_namelen: linux.socklen_t,
    msg_iov: ?*anyopaque,
    __pad1: c_int,
    msg_iovlen: c_int,
    msg_control: ?*anyopaque,
    __pad2: linux.socklen_t,
    msg_controllen: linux.socklen_t,
    msg_flags: c_int,
} else extern struct {
    msg_name: ?*anyopaque,
    msg_namelen: linux.socklen_t,
    msg_iov: ?*anyopaque,
    msg_iovlen: c_int,
    msg_control: ?*anyopaque,
    msg_controllen: linux.socklen_t,
    msg_flags: c_int,
};

const c_cmsghdr = if (lp64 and is_le) extern struct {
    cmsg_len: linux.socklen_t,
    __pad1: c_int,
    cmsg_level: c_int,
    cmsg_type: c_int,
} else if (lp64) extern struct {
    __pad1: c_int,
    cmsg_len: linux.socklen_t,
    cmsg_level: c_int,
    cmsg_type: c_int,
} else extern struct {
    cmsg_len: linux.socklen_t,
    cmsg_level: c_int,
    cmsg_type: c_int,
};

const c_mmsghdr = extern struct {
    msg_hdr: c_msghdr,
    msg_len: c_uint,
};

// SCM_TIMESTAMP / SCM_TIMESTAMPNS values per musl <sys/socket.h>.
// On LP64 (and on x32, which overrides via bits/socket.h) SCM_TIMESTAMP
// already equals SCM_TIMESTAMP_OLD, so musl's `__convert_scm_timestamps`
// returns immediately. Only non-x32 LP32 builds need the conversion.
// SOL_SOCKET / SO_TIMESTAMP* are defined earlier in this file (see
// the getsockopt/setsockopt block).
const SCM_TIMESTAMP = SO_TIMESTAMP;
const SCM_TIMESTAMP_OLD = SO_TIMESTAMP_OLD;
const SCM_TIMESTAMPNS = SO_TIMESTAMPNS;
const SCM_TIMESTAMPNS_OLD = SO_TIMESTAMPNS_OLD;
const need_convert_scm_timestamps = SCM_TIMESTAMP != SCM_TIMESTAMP_OLD;
const MSG_CTRUNC: u32 = 0x0008;

// musl <sys/socket.h> CMSG macros expressed against the kernel-style
// `struct cmsghdr` view (`cmsg_len` field is 8 bytes on LP64 once the
// pad bits are zeroed, 4 bytes on LP32).
fn cmsgAlign(len: usize) usize {
    return (len + @sizeOf(usize) - 1) & ~@as(usize, @sizeOf(usize) - 1);
}

fn cmsgLenAlign(len: usize) usize {
    return (len + @sizeOf(c_long) - 1) & ~@as(usize, @sizeOf(c_long) - 1);
}

fn cmsgFirstHdr(msg: *linux.msghdr) ?*linux.cmsghdr {
    if (msg.controllen < @sizeOf(linux.cmsghdr)) return null;
    return @ptrCast(@alignCast(msg.control));
}

fn cmsgNxtHdr(msg: *linux.msghdr, cmsg: *linux.cmsghdr) ?*linux.cmsghdr {
    if (cmsg.len < @sizeOf(linux.cmsghdr)) return null;
    const aligned = cmsgLenAlign(cmsg.len);
    const cmsg_addr = @intFromPtr(cmsg);
    const mhdr_end = @intFromPtr(msg.control) + msg.controllen;
    if (aligned + @sizeOf(linux.cmsghdr) >= mhdr_end - cmsg_addr) return null;
    return @ptrFromInt(cmsg_addr + aligned);
}

// Translate `recvmsg` results coming from a kernel that reports
// SCM_TIMESTAMP_OLD/SCM_TIMESTAMPNS_OLD (long-based) timestamps into the
// SCM_TIMESTAMP/SCM_TIMESTAMPNS (long-long-based) layout that LP32 musl
// userspace expects. No-op on every ABI where the two constants coincide.
fn convertScmTimestamps(msg: *linux.msghdr, csize: linux.socklen_t) void {
    if (!need_convert_scm_timestamps) return;
    if (msg.control == null or msg.controllen == 0) return;

    var last: ?*linux.cmsghdr = null;
    var tvts: [2]i64 = .{ 0, 0 };
    var ttype: c_int = 0;

    var cur: ?*linux.cmsghdr = cmsgFirstHdr(msg);
    while (cur) |cmsg| : (cur = cmsgNxtHdr(msg, cmsg)) {
        if (cmsg.level == SOL_SOCKET) {
            switch (cmsg.type) {
                SO_TIMESTAMP_OLD => {
                    if (ttype == 0) {
                        ttype = SCM_TIMESTAMP;
                        const data: [*]const u8 = @ptrFromInt(@intFromPtr(cmsg) + @sizeOf(linux.cmsghdr));
                        var tmp: c_long = 0;
                        @memcpy(@as([*]u8, @ptrCast(&tmp))[0..@sizeOf(c_long)], data[0..@sizeOf(c_long)]);
                        tvts[0] = tmp;
                        @memcpy(@as([*]u8, @ptrCast(&tmp))[0..@sizeOf(c_long)], data[@sizeOf(c_long) .. 2 * @sizeOf(c_long)]);
                        tvts[1] = tmp;
                    }
                },
                SO_TIMESTAMPNS_OLD => {
                    ttype = SCM_TIMESTAMPNS;
                    const data: [*]const u8 = @ptrFromInt(@intFromPtr(cmsg) + @sizeOf(linux.cmsghdr));
                    var tmp: c_long = 0;
                    @memcpy(@as([*]u8, @ptrCast(&tmp))[0..@sizeOf(c_long)], data[0..@sizeOf(c_long)]);
                    tvts[0] = tmp;
                    @memcpy(@as([*]u8, @ptrCast(&tmp))[0..@sizeOf(c_long)], data[@sizeOf(c_long) .. 2 * @sizeOf(c_long)]);
                    tvts[1] = tmp;
                },
                else => {},
            }
        }
        last = cmsg;
    }

    const last_cmsg = last orelse return;
    if (ttype == 0) return;

    const cmsg_len = cmsgAlign(@sizeOf(linux.cmsghdr)) + @sizeOf(@TypeOf(tvts));
    const cmsg_space = cmsgAlign(@sizeOf(linux.cmsghdr)) + cmsgAlign(@sizeOf(@TypeOf(tvts)));
    if (cmsg_space > csize - msg.controllen) {
        msg.flags |= MSG_CTRUNC;
        return;
    }
    msg.controllen += cmsg_space;
    const new_cmsg = cmsgNxtHdr(msg, last_cmsg) orelse return;
    new_cmsg.level = SOL_SOCKET;
    new_cmsg.type = ttype;
    new_cmsg.len = cmsg_len;
    const dst: [*]u8 = @ptrFromInt(@intFromPtr(new_cmsg) + @sizeOf(linux.cmsghdr));
    @memcpy(dst[0..@sizeOf(@TypeOf(tvts))], @as([*]const u8, @ptrCast(&tvts))[0..@sizeOf(@TypeOf(tvts))]);
}

inline fn fdAsUsize(fd: c_int) usize {
    return @bitCast(@as(isize, fd));
}

inline fn intAsUsize(x: c_int) usize {
    return @bitCast(@as(isize, x));
}

// sendto.c
fn sendto_impl(
    fd: c_int,
    buf: ?*const anyopaque,
    len: usize,
    flags: c_int,
    addr: ?*const linux.sockaddr,
    alen: linux.socklen_t,
) callconv(.c) isize {
    const fd_u = fdAsUsize(fd);
    const flags_u = intAsUsize(flags);
    const buf_u = @intFromPtr(buf);
    const addr_u = @intFromPtr(addr);
    const alen_u: usize = @intCast(alen);
    const r = if (native_arch == .x86)
        linux.socketcall(linux.SC.sendto, @ptrCast(&[6]usize{ fd_u, buf_u, len, flags_u, addr_u, alen_u }))
    else
        linux.syscall6(.sendto, fd_u, buf_u, len, flags_u, addr_u, alen_u);
    return errnoSize(r);
}

// send.c
fn send_impl(fd: c_int, buf: ?*const anyopaque, len: usize, flags: c_int) callconv(.c) isize {
    return sendto_impl(fd, buf, len, flags, null, 0);
}

// recvfrom.c
fn recvfrom_impl(
    fd: c_int,
    buf: ?*anyopaque,
    len: usize,
    flags: c_int,
    addr: ?*linux.sockaddr,
    alen: ?*linux.socklen_t,
) callconv(.c) isize {
    const fd_u = fdAsUsize(fd);
    const flags_u = intAsUsize(flags);
    const buf_u = @intFromPtr(buf);
    const addr_u = @intFromPtr(addr);
    const alen_u = @intFromPtr(alen);
    const r = if (native_arch == .x86)
        linux.socketcall(linux.SC.recvfrom, @ptrCast(&[6]usize{ fd_u, buf_u, len, flags_u, addr_u, alen_u }))
    else
        linux.syscall6(.recvfrom, fd_u, buf_u, len, flags_u, addr_u, alen_u);
    return errnoSize(r);
}

// recv.c
fn recv_impl(fd: c_int, buf: ?*anyopaque, len: usize, flags: c_int) callconv(.c) isize {
    return recvfrom_impl(fd, buf, len, flags, null, null);
}

// Maximum cmsg-buffer size used by sendmsg's local copy. Mirrors musl:
// 255 SCM_RIGHTS file descriptors plus the cmsghdr itself.
const CHBUF_BYTES = cmsgAlign(255 * @sizeOf(c_int)) + cmsgAlign(@sizeOf(linux.cmsghdr));

fn sendmsgSyscall(fd: c_int, msg_ptr: usize, flags: c_int) usize {
    const fd_u = fdAsUsize(fd);
    const flags_u = intAsUsize(flags);
    if (native_arch == .x86) {
        return linux.socketcall(linux.SC.sendmsg, @ptrCast(&[3]usize{ fd_u, msg_ptr, flags_u }));
    }
    return linux.syscall3(.sendmsg, fd_u, msg_ptr, flags_u);
}

// sendmsg.c
fn sendmsg_impl(fd: c_int, msg: ?*const c_msghdr, flags: c_int) callconv(.c) isize {
    if (!lp64 or msg == null) {
        return errnoSize(sendmsgSyscall(fd, @intFromPtr(msg), flags));
    }

    // LP64: clone the caller's msghdr with the pad halves zeroed so the
    // kernel reads the right size_t for msg_iovlen/msg_controllen, then
    // do the same for each cmsghdr in a private stack-allocated buffer.
    var h: linux.msghdr = undefined;
    const src_bytes: [*]const u8 = @ptrCast(msg.?);
    const dst_bytes: [*]u8 = @ptrCast(&h);
    @memcpy(dst_bytes[0..@sizeOf(linux.msghdr)], src_bytes[0..@sizeOf(linux.msghdr)]);
    h.iovlen &= 0xFFFFFFFF;
    h.controllen &= 0xFFFFFFFF;

    var chbuf: [CHBUF_BYTES]u8 align(@alignOf(linux.cmsghdr)) = undefined;
    if (h.controllen != 0) {
        if (h.controllen > chbuf.len) {
            std.c._errno().* = @intFromEnum(linux.E.NOMEM);
            return -1;
        }
        const src: [*]const u8 = @ptrCast(h.control);
        @memcpy(chbuf[0..h.controllen], src[0..h.controllen]);
        h.control = @ptrCast(&chbuf);
        var cur: ?*linux.cmsghdr = cmsgFirstHdr(&h);
        while (cur) |cmsg| : (cur = cmsgNxtHdr(&h, cmsg)) {
            // Zero the cmsg_len's pad half (high 32 bits of the
            // size_t-shaped slot) without disturbing the user's
            // socklen_t portion.
            cmsg.len &= 0xFFFFFFFF;
        }
    }

    return errnoSize(sendmsgSyscall(fd, @intFromPtr(&h), flags));
}

fn recvmsgSyscall(fd: c_int, msg_ptr: usize, flags: c_int) usize {
    const fd_u = fdAsUsize(fd);
    const flags_u = intAsUsize(flags);
    if (native_arch == .x86) {
        return linux.socketcall(linux.SC.recvmsg, @ptrCast(&[3]usize{ fd_u, msg_ptr, flags_u }));
    }
    return linux.syscall3(.recvmsg, fd_u, msg_ptr, flags_u);
}

// recvmsg.c
fn recvmsg_impl(fd: c_int, msg: ?*c_msghdr, flags: c_int) callconv(.c) isize {
    const m = msg orelse {
        // Match musl: dereferences `msg->msg_controllen` unconditionally;
        // a NULL pointer would already segfault inside the C version.
        // Skip the deref and just hand the NULL to the kernel which
        // returns -EFAULT.
        return errnoSize(recvmsgSyscall(fd, 0, flags));
    };

    // `orig_controllen` is the user's pre-syscall socklen_t (low 32 bits).
    const orig_controllen: linux.socklen_t = blk: {
        const raw: usize = @as(*const linux.msghdr, @ptrCast(@alignCast(m))).controllen;
        break :blk @intCast(raw & 0xFFFFFFFF);
    };

    if (!lp64) {
        const r_raw = recvmsgSyscall(fd, @intFromPtr(m), flags);
        const signed: isize = @bitCast(r_raw);
        if (signed >= 0) {
            convertScmTimestamps(@ptrCast(@alignCast(m)), orig_controllen);
        }
        return errnoSize(r_raw);
    }

    var h: linux.msghdr = undefined;
    const src_bytes: [*]const u8 = @ptrCast(m);
    const dst_bytes: [*]u8 = @ptrCast(&h);
    @memcpy(dst_bytes[0..@sizeOf(linux.msghdr)], src_bytes[0..@sizeOf(linux.msghdr)]);
    h.iovlen &= 0xFFFFFFFF;
    h.controllen &= 0xFFFFFFFF;

    const r_raw = recvmsgSyscall(fd, @intFromPtr(&h), flags);
    const signed: isize = @bitCast(r_raw);
    if (signed >= 0) convertScmTimestamps(&h, orig_controllen);

    // Copy the (possibly mutated) kernel-side msghdr back into the user's
    // struct. The user's pad halves are restored to zero by the bytewise
    // copy because `h` had them zeroed before the syscall.
    @memcpy(src_bytes_mut(m)[0..@sizeOf(linux.msghdr)], dst_bytes[0..@sizeOf(linux.msghdr)]);

    return errnoSize(r_raw);
}

inline fn src_bytes_mut(p: *c_msghdr) [*]u8 {
    return @ptrCast(p);
}

// sendmmsg.c
fn sendmmsg_impl(fd: c_int, msgvec: ?[*]c_mmsghdr, vlen_in: c_uint, flags: c_uint) callconv(.c) c_int {
    if (!lp64) {
        const fd_u = fdAsUsize(fd);
        const r = linux.syscall4(.sendmmsg, fd_u, @intFromPtr(msgvec), vlen_in, flags);
        return errno(r);
    }

    // LP64: the kernel's mmsghdr has size_t iovlen/controllen while musl's
    // user-facing layout uses int/socklen_t plus pad halves, and the cmsg
    // chain cannot be patched in place. Walk the array and call sendmsg
    // individually (matching musl's behaviour).
    var vlen = vlen_in;
    if (vlen > linux.IOV_MAX) vlen = linux.IOV_MAX;
    if (vlen == 0) return 0;
    const mv = msgvec orelse {
        std.c._errno().* = @intFromEnum(linux.E.FAULT);
        return -1;
    };

    var i: c_uint = 0;
    while (i < vlen) : (i += 1) {
        const r = sendmsg_impl(fd, &mv[i].msg_hdr, @bitCast(flags));
        if (r < 0) break;
        mv[i].msg_len = @intCast(r);
    }
    return if (i != 0) @intCast(i) else -1;
}

// recvmmsg.c
fn recvmmsg_impl(
    fd: c_int,
    msgvec: ?[*]c_mmsghdr,
    vlen_in: c_uint,
    flags: c_uint,
    timeout: ?*musl_timespec,
) callconv(.c) c_int {
    var vlen = vlen_in;

    // Zero the per-msghdr pad fields up-front on LP64 so the kernel sees
    // valid size_t fields for every msghdr in the vector.
    if (lp64) {
        if (msgvec) |mv| {
            var i: c_uint = 0;
            while (i < vlen) : (i += 1) {
                const h: *linux.msghdr = @ptrCast(@alignCast(&mv[i].msg_hdr));
                h.iovlen &= 0xFFFFFFFF;
                h.controllen &= 0xFFFFFFFF;
            }
        }
    }

    const fd_u = fdAsUsize(fd);

    if (comptime @hasField(linux.SYS, "recvmmsg_time64")) {
        // Two-step path used by musl on archs that have both
        // `recvmmsg` and `recvmmsg_time64`: try the time64 syscall
        // first (with the 64-bit timespec it expects), and fall back
        // to the legacy `recvmmsg` with a CLAMP'd long-sized timespec
        // if the kernel doesn't know `recvmmsg_time64`.
        const has_legacy = comptime @hasField(linux.SYS, "recvmmsg");
        var ts64: [2]i64 = .{ 0, 0 };
        if (timeout) |t| {
            ts64[0] = t.sec;
            ts64[1] = muslTsNsec(t.*);
        }
        const ts64_arg: usize = if (timeout != null) @intFromPtr(&ts64) else 0;
        const r_time64 = linux.syscall5(
            .recvmmsg_time64,
            fd_u,
            @intFromPtr(msgvec),
            vlen,
            flags,
            ts64_arg,
        );

        const same_syscall = comptime blk: {
            if (!has_legacy) break :blk true;
            const a: usize = @intFromEnum(@field(linux.SYS, "recvmmsg"));
            const b: usize = @intFromEnum(@field(linux.SYS, "recvmmsg_time64"));
            break :blk a == b;
        };

        const signed_r: isize = @bitCast(r_time64);
        if (same_syscall or -signed_r != @intFromEnum(linux.E.NOSYS)) {
            if (signed_r >= 0) convertScmTimestampsFromVec(msgvec, signed_r);
            return errno(r_time64);
        }

        if (!has_legacy) return errno(r_time64);

        // Legacy path: needs `(long[]){CLAMP(s), ns}` timespec and the
        // per-msghdr cmsg-timestamp fixup after the syscall returns.
        if (vlen > linux.IOV_MAX) vlen = linux.IOV_MAX;
        var csize_buf: [linux.IOV_MAX]linux.socklen_t = undefined;
        if (msgvec) |mv| {
            var i: c_uint = 0;
            while (i < vlen) : (i += 1) {
                const cl: usize = @as(*const linux.msghdr, @ptrCast(@alignCast(&mv[i].msg_hdr))).controllen;
                csize_buf[i] = @intCast(cl & 0xFFFFFFFF);
            }
        }
        var tslong: [2]c_long = .{ 0, 0 };
        if (timeout) |t| {
            // CLAMP(x): if x fits in i32 use it, else saturate to INT_MAX
            // (or INT_MIN if negative). Mirrors musl's `IS32BIT`.
            const s = t.sec;
            const ns = muslTsNsec(t.*);
            const lo: i64 = std.math.minInt(i32);
            const hi: i64 = std.math.maxInt(i32);
            tslong[0] = @intCast(if (s < lo) lo else if (s > hi) hi else s);
            tslong[1] = @intCast(ns);
        }
        const tslong_arg: usize = if (timeout != null) @intFromPtr(&tslong) else 0;
        if (comptime @hasField(linux.SYS, "recvmmsg")) {
            const r_legacy = linux.syscall5(
                .recvmmsg,
                fd_u,
                @intFromPtr(msgvec),
                vlen,
                flags,
                tslong_arg,
            );
            const r_legacy_signed: isize = @bitCast(r_legacy);
            if (r_legacy_signed > 0) convertScmTimestampsFromVecLegacy(msgvec, r_legacy_signed, &csize_buf);
            return errno(r_legacy);
        }
        unreachable;
    }

    if (comptime @hasField(linux.SYS, "recvmmsg")) {
        // No time64 variant: pass the timespec straight through. On LP64
        // archs `musl_timespec` already matches the kernel struct
        // (`{long sec; long nsec;}`); on LP32 archs without a time64
        // syscall the kernel takes a `__kernel_old_timespec`-style struct
        // we don't support here.
        const r = linux.syscall5(
            .recvmmsg,
            fd_u,
            @intFromPtr(msgvec),
            vlen,
            flags,
            @intFromPtr(timeout),
        );
        return errno(r);
    }
    std.c._errno().* = @intFromEnum(linux.E.NOSYS);
    return -1;
}

fn convertScmTimestampsFromVec(msgvec: ?[*]c_mmsghdr, count: isize) void {
    if (!need_convert_scm_timestamps) return;
    const mv = msgvec orelse return;
    var i: isize = 0;
    while (i < count) : (i += 1) {
        const h: *linux.msghdr = @ptrCast(@alignCast(&mv[@intCast(i)].msg_hdr));
        const cl: linux.socklen_t = @intCast(h.controllen & 0xFFFFFFFF);
        convertScmTimestamps(h, cl);
    }
}

fn convertScmTimestampsFromVecLegacy(
    msgvec: ?[*]c_mmsghdr,
    count: isize,
    csize: *const [linux.IOV_MAX]linux.socklen_t,
) void {
    if (!need_convert_scm_timestamps) return;
    const mv = msgvec orelse return;
    var i: isize = 0;
    while (i < count) : (i += 1) {
        const h: *linux.msghdr = @ptrCast(@alignCast(&mv[@intCast(i)].msg_hdr));
        convertScmTimestamps(h, csize[@intCast(i)]);
    }
}
