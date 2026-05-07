// DNS resolver functions — faithful Zig translations of musl libc C sources.
// Covers: freeaddrinfo, res_send, res_querydomain, res_query, res_mkquery,
//         lookup_ipliteral, dn_comp, dn_expand, dn_skipname, dns_parse,
//         ns_parse (multiple), netlink.
const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../../c.zig").symbol;

// ============================================================
// Internal struct definitions (from lookup.h / netlink.h)
// ============================================================

const address = extern struct {
    family: c_int,
    scopeid: c_uint,
    addr: [16]u8,
    sortkey: c_int,
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

const nlmsghdr = extern struct {
    nlmsg_len: u32,
    nlmsg_type: u16,
    nlmsg_flags: u16,
    nlmsg_seq: u32,
    nlmsg_pid: u32,
};

const rtgenmsg = extern struct {
    rtgen_family: u8,
};

const nl_req = extern struct {
    nlh: nlmsghdr,
    g: rtgenmsg,
};

const nl_union = extern union {
    buf: [8192]u8,
    req: nl_req,
    reply: nlmsghdr,
};

// ns_parse types
const NS_INT16SZ: usize = 2;
const NS_INT32SZ: usize = 4;
const NS_MAXDNAME: usize = 1025;
const ns_s_qd: c_int = 0;
const ns_s_max: usize = 4;

const NsMsg = extern struct {
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

const NsRr = extern struct {
    name: [NS_MAXDNAME]u8,
    rr_type: u16,
    rr_class: u16,
    ttl: u32,
    rdlength: u16,
    rdata: ?[*]const u8,
};

// ============================================================
// Constants
// ============================================================

const AF_INET: c_int = 2;
const AF_INET6: c_int = 10;
const EAI_NODATA: c_int = -5;
const EAI_NONAME: c_int = -2;
const TRY_AGAIN: c_int = 2;
const HOST_NOT_FOUND: c_int = 1;
const NO_DATA: c_int = 4;
const CLOCK_REALTIME: c_int = 0;
const NLMSG_DONE: u16 = 3;
const NLMSG_ERROR: u16 = 2;
const NLM_F_REQUEST: u16 = 1;
const NLM_F_ROOT: u16 = 0x100;
const NLM_F_MATCH: u16 = 0x200;
const NLM_F_DUMP: u16 = NLM_F_ROOT | NLM_F_MATCH;
const RTM_GETLINK: c_int = 18;
const RTM_GETADDR: c_int = 22;
const PF_NETLINK: c_int = 16;
const SOCK_RAW: c_int = 3;
const SOCK_CLOEXEC: c_int = 0x80000;
const NETLINK_ROUTE: c_int = 0;
const MSG_DONTWAIT: c_int = 0x40;

// ============================================================
// C library function externs (only resolved when link_libc)
// ============================================================

const c = if (builtin.link_libc) struct {
    const free = @extern(*const fn (?*anyopaque) callconv(.c) void, .{ .name = "free" });
    const memcmp = @extern(*const fn (?*const anyopaque, ?*const anyopaque, usize) callconv(.c) c_int, .{ .name = "memcmp" });
    const strnlen = @extern(*const fn ([*]const u8, usize) callconv(.c) usize, .{ .name = "strnlen" });
    const strchr = @extern(*const fn ([*:0]const u8, c_int) callconv(.c) ?[*]u8, .{ .name = "strchr" });
    const strtoull = @extern(*const fn ([*:0]const u8, *[*]u8, c_int) callconv(.c) c_ulonglong, .{ .name = "strtoull" });
    const inet_aton = @extern(*const fn ([*:0]const u8, *anyopaque) callconv(.c) c_int, .{ .name = "__inet_aton" });
    const inet_pton = @extern(*const fn (c_int, [*:0]const u8, *anyopaque) callconv(.c) c_int, .{ .name = "inet_pton" });
    const if_nametoindex = @extern(*const fn ([*:0]const u8) callconv(.c) c_uint, .{ .name = "if_nametoindex" });
    const clock_gettime_fn = @extern(*const fn (c_int, *linux.timespec) callconv(.c) c_int, .{ .name = "clock_gettime" });
    const socket_fn = @extern(*const fn (c_int, c_int, c_int) callconv(.c) c_int, .{ .name = "socket" });
    const send_fn = @extern(*const fn (c_int, *const anyopaque, usize, c_int) callconv(.c) isize, .{ .name = "send" });
    const recv_fn = @extern(*const fn (c_int, *anyopaque, usize, c_int) callconv(.c) isize, .{ .name = "recv" });
    const __res_msend = @extern(*const fn (c_int, [*]const [*]const u8, [*]const c_int, [*]const [*]u8, [*]c_int, c_int) callconv(.c) c_int, .{ .name = "__res_msend" });
    const __lock = @extern(*const fn ([*]c_int) callconv(.c) void, .{ .name = "__lock" });
    const __unlock = @extern(*const fn ([*]c_int) callconv(.c) void, .{ .name = "__unlock" });
    const h_errno_ptr = @extern(*c_int, .{ .name = "h_errno" });
} else struct {};

// ============================================================
// Symbol exports
// ============================================================

comptime {
    if (builtin.target.isMuslLibC()) {
        if (builtin.link_libc) {
            // freeaddrinfo.c
            symbol(&freeaddrinfo_impl, "freeaddrinfo");
            // res_send.c
            symbol(&res_send_impl, "__res_send");
            symbol(&res_send_impl, "res_send");
            // res_querydomain.c
            symbol(&res_querydomain_impl, "res_querydomain");
            // res_query.c
            symbol(&res_query_impl, "res_query");
            symbol(&res_query_impl, "res_search");
            // res_mkquery.c
            symbol(&res_mkquery_impl, "__res_mkquery");
            symbol(&res_mkquery_impl, "res_mkquery");
            // lookup_ipliteral.c
            symbol(&lookup_ipliteral_impl, "__lookup_ipliteral");
            // dn_comp.c
            symbol(&dn_comp_impl, "dn_comp");
            // dn_expand.c / dn_skipname.c / dns_parse.c
            symbol(&dn_expand_impl, "__dn_expand");
            symbol(&dn_expand_impl, "dn_expand");
            symbol(&dn_skipname_impl, "dn_skipname");
            symbol(&dns_parse_impl, "__dns_parse");
            // ns_parse.c
            symbol(&ns_get16_impl, "ns_get16");
            symbol(&ns_get32_impl, "ns_get32");
            symbol(&ns_put16_impl, "ns_put16");
            symbol(&ns_put32_impl, "ns_put32");
            symbol(&ns_initparse_impl, "ns_initparse");
            symbol(&ns_skiprr_impl, "ns_skiprr");
            symbol(&ns_parserr_impl, "ns_parserr");
            symbol(&ns_name_uncompress_impl, "ns_name_uncompress");
            symbol(&_ns_flagdata_sym, "_ns_flagdata");
            // netlink.c
            symbol(&rtnetlink_enumerate_impl, "__rtnetlink_enumerate");
        }
    }
}

// ============================================================
// Helper functions
// ============================================================

/// Read big-endian u16 and advance pointer.
fn nsGet16(cp: *[*]const u8) u16 {
    const p = cp.*;
    const val: u16 = @as(u16, p[0]) << 8 | p[1];
    cp.* = p + NS_INT16SZ;
    return val;
}

/// Read big-endian u32 and advance pointer.
fn nsGet32(cp: *[*]const u8) u32 {
    const p = cp.*;
    const val: u32 = @as(u32, p[0]) << 24 | @as(u32, p[1]) << 16 | @as(u32, p[2]) << 8 | p[3];
    cp.* = p + NS_INT32SZ;
    return val;
}

/// Safe pointer difference: returns 0 if b > a.
fn ptrDiff(a: [*]const u8, b: [*]const u8) usize {
    const aa = @intFromPtr(a);
    const bb = @intFromPtr(b);
    return if (aa >= bb) aa - bb else 0;
}

fn setEMSGSIZE() c_int {
    std.c._errno().* = @intFromEnum(std.c.E.MSGSIZE);
    return -1;
}

fn isIn6AddrLinkLocal(a: *const [16]u8) bool {
    return a[0] == 0xfe and (a[1] & 0xc0) == 0x80;
}

fn isIn6AddrMcLinkLocal(a: *const [16]u8) bool {
    return a[0] == 0xff and (a[1] & 0x0f) == 0x02;
}

/// NLMSG_OK: check if there's room for a nlmsghdr between h and end.
fn nlmsgOk(h: *const nlmsghdr, end: [*]const u8) bool {
    return @intFromPtr(end) >= @intFromPtr(h) + @sizeOf(nlmsghdr);
}

/// NLMSG_NEXT: advance to next aligned nlmsghdr.
fn nlmsgNext(h: *nlmsghdr) *nlmsghdr {
    const aligned = (h.nlmsg_len + 3) & ~@as(u32, 3);
    return @ptrFromInt(@intFromPtr(h) + aligned);
}

// ============================================================
// freeaddrinfo.c
// ============================================================

fn freeaddrinfo_impl(p_arg: *addrinfo) callconv(.c) void {
    var p = p_arg;
    var cnt: c_short = 1;
    while (p.ai_next) |next| {
        cnt += 1;
        p = @ptrCast(@alignCast(next));
    }
    // offsetof(aibuf, ai) == 0, so aibuf* == addrinfo*
    const b_many: [*]aibuf = @ptrCast(@alignCast(p));
    const slot: usize = @intCast(b_many[0].slot);
    const b: *aibuf = @ptrCast(b_many - slot);
    c.__lock(&b.lock);
    b.ref -= cnt;
    if (b.ref == 0) {
        c.free(@ptrCast(b));
    } else {
        c.__unlock(&b.lock);
    }
}

// ============================================================
// res_send.c
// ============================================================

fn res_send_impl(msg: [*]const u8, msglen: c_int, answer: [*]u8, anslen: c_int) callconv(.c) c_int {
    if (anslen < 512) {
        var buf: [512]u8 = undefined;
        const r = res_send_impl(msg, msglen, &buf, 512);
        if (r >= 0) {
            const copy_len: usize = if (r < anslen) @intCast(r) else @intCast(anslen);
            @memcpy(answer[0..copy_len], buf[0..copy_len]);
        }
        return r;
    }
    var msg_ptr = msg;
    var msglen_val = msglen;
    var answer_ptr = answer;
    var anslen_val = anslen;
    const r = c.__res_msend(1, @ptrCast(&msg_ptr), @ptrCast(&msglen_val), @ptrCast(&answer_ptr), @ptrCast(&anslen_val), anslen);
    return if (r < 0 or anslen_val == 0) -1 else anslen_val;
}

// ============================================================
// res_querydomain.c
// ============================================================

fn res_querydomain_impl(name: [*:0]const u8, domain: [*:0]const u8, class: c_int, typ: c_int, dest: [*]u8, len: c_int) callconv(.c) c_int {
    var tmp: [255]u8 = undefined;
    const nl = c.strnlen(name, 255);
    const dl = c.strnlen(@ptrCast(domain), 255);
    if (nl + dl + 1 > 254) return -1;
    @memcpy(tmp[0..nl], name[0..nl]);
    tmp[nl] = '.';
    @memcpy(tmp[nl + 1 ..][0 .. dl + 1], @as([*]const u8, @ptrCast(domain))[0 .. dl + 1]);
    return res_query_impl(@ptrCast(&tmp), class, typ, dest, len);
}

// ============================================================
// res_query.c
// ============================================================

fn res_query_impl(name: [*:0]const u8, class: c_int, typ: c_int, dest: [*]u8, len: c_int) callconv(.c) c_int {
    var q: [280]u8 = undefined;
    const ql = res_mkquery_impl(0, name, class, typ, null, 0, null, &q, 280);
    if (ql < 0) return ql;
    const r = res_send_impl(&q, ql, dest, len);
    if (r < 12) {
        c.h_errno_ptr.* = TRY_AGAIN;
        return -1;
    }
    if ((dest[3] & 15) == 3) {
        c.h_errno_ptr.* = HOST_NOT_FOUND;
        return -1;
    }
    if ((dest[3] & 15) == 0 and dest[6] == 0 and dest[7] == 0) {
        c.h_errno_ptr.* = NO_DATA;
        return -1;
    }
    return r;
}

// ============================================================
// res_mkquery.c
// ============================================================

fn res_mkquery_impl(
    op: c_int,
    dname: [*:0]const u8,
    class: c_int,
    typ: c_int,
    _data: ?*const anyopaque,
    _datalen: c_int,
    _newrr: ?*const anyopaque,
    buf: [*]u8,
    buflen: c_int,
) callconv(.c) c_int {
    _ = _data;
    _ = _datalen;
    _ = _newrr;

    var q: [280]u8 = undefined;
    var l = c.strnlen(dname, 255);

    if (l > 0 and dname[l - 1] == '.') l -= 1;
    if (l > 0 and dname[l - 1] == '.') return -1;
    const n_usize: usize = 17 + l + @as(usize, if (l > 0) 1 else 0);
    const n: c_int = @intCast(n_usize);
    if (l > 253 or buflen < n or @as(c_uint, @bitCast(op)) > 15 or
        @as(c_uint, @bitCast(class)) > 255 or @as(c_uint, @bitCast(typ)) > 255)
        return -1;

    @memset(q[0..n_usize], 0);
    q[2] = @intCast(@as(c_uint, @intCast(op)) * 8 + 1);
    q[3] = 32; // AD
    q[5] = 1;
    @memcpy(q[13..][0..l], dname[0..l]);

    // Convert dots to label lengths
    var i: usize = 13;
    while (q[i] != 0) {
        var j: usize = i;
        while (q[j] != 0 and q[j] != '.') : (j += 1) {}
        if (@as(c_uint, @intCast(j - i)) -% 1 > 62) return -1;
        q[i - 1] = @intCast(j - i);
        i = j + 1;
    }
    q[i + 1] = @intCast(@as(c_uint, @bitCast(typ)) & 0xff);
    q[i + 3] = @intCast(@as(c_uint, @bitCast(class)) & 0xff);

    // Generate reasonably unpredictable id
    var ts: linux.timespec = undefined;
    _ = c.clock_gettime_fn(CLOCK_REALTIME, &ts);
    const nsec: u64 = @bitCast(@as(i64, ts.nsec));
    const id: u16 = @truncate((nsec +% nsec / 65536) & 0xffff);
    q[0] = @intCast(id >> 8);
    q[1] = @intCast(id & 0xff);

    @memcpy(buf[0..n_usize], q[0..n_usize]);
    return n;
}

// ============================================================
// lookup_ipliteral.c
// ============================================================

fn lookup_ipliteral_impl(buf: [*]address, name_arg: [*:0]const u8, family: c_int) callconv(.c) c_int {
    var a4: [4]u8 = undefined;
    if (c.inet_aton(name_arg, @ptrCast(&a4)) > 0) {
        if (family == AF_INET6) return EAI_NODATA;
        @memcpy(buf[0].addr[0..4], &a4);
        @memset(buf[0].addr[4..16], 0);
        buf[0].family = AF_INET;
        buf[0].scopeid = 0;
        return 1;
    }

    var tmp: [64]u8 = undefined;
    const p_opt: ?[*]u8 = c.strchr(name_arg, '%');
    var scopeid: c_ulonglong = 0;
    var name: [*:0]const u8 = name_arg;

    if (p_opt) |p| {
        const diff = @intFromPtr(p) - @intFromPtr(@as([*]const u8, name_arg));
        if (diff < 64) {
            @memcpy(tmp[0..diff], @as([*]const u8, name_arg)[0..diff]);
            tmp[diff] = 0;
            name = @ptrCast(&tmp);
        }
    }

    var a6: [16]u8 = undefined;
    if (c.inet_pton(AF_INET6, name, @ptrCast(&a6)) <= 0) return 0;
    if (family == AF_INET) return EAI_NODATA;

    @memcpy(&buf[0].addr, &a6);
    buf[0].family = AF_INET6;

    if (p_opt) |p_raw| {
        const p: [*:0]const u8 = @ptrCast(p_raw + 1); // skip '%'
        var try_name: bool = true;
        if (p[0] >= '0' and p[0] <= '9') {
            var z: [*]u8 = undefined;
            scopeid = c.strtoull(p, &z, 10);
            if (z[0] == 0) try_name = false; // all digits consumed
        }
        if (try_name) {
            if (!isIn6AddrLinkLocal(&a6) and !isIn6AddrMcLinkLocal(&a6))
                return EAI_NONAME;
            scopeid = c.if_nametoindex(p);
            if (scopeid == 0) return EAI_NONAME;
        }
        if (scopeid > 0xFFFFFFFF) return EAI_NONAME;
    }
    buf[0].scopeid = @intCast(scopeid);
    return 1;
}

// ============================================================
// dn_comp.c — RFC 1035 message compression
// ============================================================

/// Label start offsets of a compressed domain name.
fn getoffs(offs: [*]c_short, base: [*]const u8, s_arg: [*]const u8) c_int {
    var s = s_arg;
    var i: c_int = 0;
    while (true) {
        while ((s[0] & 0xc0) != 0) {
            if ((s[0] & 0xc0) != 0xc0) return 0;
            s = base + (@as(usize, s[0] & 0x3f) << 8 | s[1]);
        }
        if (s[0] == 0) return i;
        if (@intFromPtr(s) - @intFromPtr(base) >= 0x4000) return 0;
        offs[@intCast(i)] = @intCast(@intFromPtr(s) - @intFromPtr(base));
        i += 1;
        s += @as(usize, s[0]) + 1;
    }
}

/// Label lengths of an ascii domain name.
fn getlens(lens: [*]u8, s: [*]const u8, l: c_int) c_int {
    var i: c_int = 0;
    var j: c_int = 0;
    var k: c_int = 0;
    while (true) {
        while (j < l and s[@intCast(j)] != '.') : (j += 1) {}
        if (@as(c_uint, @bitCast(j - k)) -% 1 > 62) return 0;
        lens[@intCast(i)] = @intCast(j - k);
        i += 1;
        if (j == l) return i;
        j += 1;
        k = j;
    }
}

/// Longest suffix match of an ascii domain with a compressed domain name.
fn matchDn(offset: *c_int, base: [*]const u8, dn: [*]const u8, end_arg: [*]const u8, lens: [*]const u8, nlen_arg: c_int) c_int {
    var offs: [128]c_short = undefined;
    const noff_init = getoffs(&offs, base, dn);
    if (noff_init == 0) return 0;
    var noff = noff_init;
    var nlen = nlen_arg;
    var end = end_arg;
    var m: c_int = 0;
    while (true) {
        nlen -= 1;
        const l: usize = lens[@intCast(nlen)];
        noff -= 1;
        const o: usize = @intCast(offs[@intCast(noff)]);
        end = @ptrFromInt(@intFromPtr(end) - l);
        if (l != base[o] or c.memcmp(@ptrCast(base + o + 1), @ptrCast(end), l) != 0)
            return m;
        offset.* = @intCast(o);
        m += @as(c_int, @intCast(l));
        if (nlen != 0) m += 1;
        if (nlen == 0 or noff == 0) return m;
        end = @ptrFromInt(@intFromPtr(end) - 1);
    }
}

fn dn_comp_impl(
    src: [*:0]const u8,
    dst: [*]u8,
    space: c_int,
    dnptrs: ?[*]?[*]u8,
    lastdnptr: ?[*]?[*]u8,
) callconv(.c) c_int {
    var lens: [127]u8 = undefined;
    var offset: c_int = undefined;
    var bestlen: c_int = 0;
    var bestoff: c_int = undefined;
    var l = c.strnlen(src, 255);
    if (l > 0 and src[l - 1] == '.') l -= 1;
    if (l > 253 or space <= 0) return -1;
    if (l == 0) {
        dst[0] = 0;
        return 1;
    }
    const end: [*]const u8 = src + l;
    const n = getlens(&lens, src, @intCast(l));
    if (n == 0) return -1;

    var m: c_int = 0;
    var p: [*]?[*]u8 = undefined;
    if (dnptrs) |ptrs| {
        if (ptrs[0]) |base| {
            p = ptrs + 1;
            while (p[0]) |entry| {
                m = matchDn(&offset, @ptrCast(base), @ptrCast(entry), end, &lens, n);
                if (m > bestlen) {
                    bestlen = m;
                    bestoff = offset;
                    if (m == @as(c_int, @intCast(l))) break;
                }
                p += 1;
            }
        }
    }

    // Encode unmatched part
    const bestlen_u: usize = @intCast(bestlen);
    const unmatched = l - bestlen_u;
    const extra: usize = if (bestlen > 0 and bestlen_u < l) 1 else 0;
    if (@as(usize, @intCast(space)) < unmatched + 2 + extra) return -1;
    @memcpy((dst + 1)[0..unmatched], src[0..unmatched]);
    var ii: usize = 0;
    var jj: usize = 0;
    while (ii < unmatched) {
        dst[ii] = lens[jj];
        ii += @as(usize, lens[jj]) + 1;
        jj += 1;
    }

    // Add tail
    if (bestlen > 0) {
        dst[ii] = @intCast(0xc0 | (@as(c_uint, @intCast(bestoff)) >> 8));
        ii += 1;
        dst[ii] = @truncate(@as(c_uint, @intCast(bestoff)));
        ii += 1;
    } else {
        dst[ii] = 0;
        ii += 1;
    }

    // Save dst pointer in dnptrs array if room
    if (ii > 2) {
        if (lastdnptr) |last| {
            if (dnptrs) |ptrs| {
                if (ptrs[0] != null) {
                    while (p[0] != null) : (p += 1) {}
                    if (@intFromPtr(p + 1) < @intFromPtr(last)) {
                        p[0] = dst;
                        (p + 1)[0] = null;
                    }
                }
            }
        }
    }
    return @intCast(ii);
}

// ============================================================
// dn_expand.c / dn_skipname.c / dns_parse.c
// ============================================================

fn dn_expand_impl(base: [*]const u8, end: [*]const u8, src: [*]const u8, dest_arg: [*]u8, space: c_int) callconv(.c) c_int {
    var p = src;
    var dest = dest_arg;
    const dbegin = dest_arg;
    var len: c_int = -1;
    if (p == end or space <= 0) return -1;
    const dend = dest_arg + @min(@as(usize, @intCast(space)), 254);

    // Detect reference loops using an iteration counter.
    var i: usize = 0;
    while (i < ptrDiff(end, base)) : (i += 2) {
        // Loop invariants from musl: p < end, dest < dend.
        if ((p[0] & 0xc0) != 0) {
            if (p + 1 == end) return -1;
            const j: usize = (@as(usize, p[0] & 0x3f) << 8) | p[1];
            if (len < 0) len = @intCast(@intFromPtr(p + 2) - @intFromPtr(src));
            if (j >= ptrDiff(end, base)) return -1;
            p = base + j;
        } else if (p[0] != 0) {
            if (dest != dbegin) {
                dest[0] = '.';
                dest += 1;
            }
            const j: usize = p[0];
            p += 1;
            if (j >= ptrDiff(end, p) or j >= ptrDiff(dend, dest)) return -1;
            var remaining = j;
            while (remaining > 0) : (remaining -= 1) {
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
        if (ptrDiff(end, p) < @as(usize, p[0]) + 1) break;
        p += @as(usize, p[0]) + 1;
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
        while (@intFromPtr(p) - @intFromPtr(r) < rlen_u and @as(c_uint, p[0]) -% 1 < 127) p += 1;
        if (@intFromPtr(p) > @intFromPtr(rend - 6)) return -1;
        p += 5 + @intFromBool(p[0] != 0);
    }

    while (ancount > 0) : (ancount -= 1) {
        while (@intFromPtr(p) - @intFromPtr(r) < rlen_u and @as(c_uint, p[0]) -% 1 < 127) p += 1;
        if (@intFromPtr(p) > @intFromPtr(rend - 12)) return -1;
        p += 1 + @intFromBool(p[0] != 0);
        const len: c_int = @as(c_int, p[8]) * 256 + p[9];
        if (len + 10 > @as(c_int, @intCast(ptrDiff(rend, p)))) return -1;
        if (callback(ctx, p[1], p + 10, len, r, rlen) < 0) return -1;
        p += @as(usize, @intCast(len + 10));
    }
    return 0;
}

// ============================================================
// ns_parse.c
// ============================================================

fn ns_get16_impl(cp: [*]const u8) callconv(.c) c_uint {
    return @as(c_uint, cp[0]) << 8 | cp[1];
}

fn ns_get32_impl(cp: [*]const u8) callconv(.c) c_ulong {
    return @as(c_ulong, cp[0]) << 24 | @as(c_ulong, cp[1]) << 16 | @as(c_ulong, cp[2]) << 8 | cp[3];
}

fn ns_put16_impl(s: c_uint, cp: [*]u8) callconv(.c) void {
    cp[0] = @intCast(s >> 8);
    cp[1] = @intCast(s & 0xff);
}

fn ns_put32_impl(l: c_ulong, cp: [*]u8) callconv(.c) void {
    cp[0] = @intCast(l >> 24);
    cp[1] = @intCast((l >> 16) & 0xff);
    cp[2] = @intCast((l >> 8) & 0xff);
    cp[3] = @intCast(l & 0xff);
}

const _ns_flagdata_sym = [16][2]c_int{
    .{ 0x8000, 15 }, .{ 0x7800, 11 }, .{ 0x0400, 10 }, .{ 0x0200, 9 },
    .{ 0x0100, 8 },  .{ 0x0080, 7 },  .{ 0x0040, 6 },  .{ 0x0020, 5 },
    .{ 0x0010, 4 },  .{ 0x000f, 0 },  .{ 0x0000, 0 },  .{ 0x0000, 0 },
    .{ 0x0000, 0 },  .{ 0x0000, 0 },  .{ 0x0000, 0 },  .{ 0x0000, 0 },
};

fn ns_initparse_impl(msg_arg: [*]const u8, msglen: c_int, handle: *NsMsg) callconv(.c) c_int {
    handle._msg = msg_arg;
    handle._eom = msg_arg + @as(usize, @intCast(msglen));
    if (msglen < @as(c_int, @intCast((2 + ns_s_max) * NS_INT16SZ))) return setEMSGSIZE();

    var msg = msg_arg;
    handle._id = nsGet16(&msg);
    handle._flags = nsGet16(&msg);
    var i: usize = 0;
    while (i < ns_s_max) : (i += 1) {
        handle._counts[i] = nsGet16(&msg);
    }
    i = 0;
    while (i < ns_s_max) : (i += 1) {
        if (handle._counts[i] != 0) {
            handle._sections[i] = msg;
            const r = ns_skiprr_impl(msg, handle._eom, @intCast(i), @intCast(handle._counts[i]));
            if (r < 0) return -1;
            msg += @as(usize, @intCast(r));
        } else {
            handle._sections[i] = null;
        }
    }
    if (msg != handle._eom) return setEMSGSIZE();
    handle._sect = @intCast(ns_s_max);
    handle._rrnum = -1;
    handle._msg_ptr = null;
    return 0;
}

fn ns_skiprr_impl(ptr: [*]const u8, eom: [*]const u8, section: c_int, count_arg: c_int) callconv(.c) c_int {
    var p = ptr;
    var count: c_uint = @intCast(count_arg);
    while (count > 0) {
        count -= 1;
        const r = dn_skipname_impl(p, eom);
        if (r < 0) return setEMSGSIZE();
        const r_u: usize = @intCast(r);
        if (r_u + 2 * NS_INT16SZ > ptrDiff(eom, p)) return setEMSGSIZE();
        p += r_u + 2 * NS_INT16SZ;
        if (section != ns_s_qd) {
            if (NS_INT32SZ + NS_INT16SZ > ptrDiff(eom, p)) return setEMSGSIZE();
            p += NS_INT32SZ;
            const rdlen: usize = nsGet16(&p);
            if (rdlen > ptrDiff(eom, p)) return setEMSGSIZE();
            p += rdlen;
        }
    }
    return @intCast(@intFromPtr(p) - @intFromPtr(ptr));
}

fn ns_parserr_impl(handle: *NsMsg, section: c_int, rrnum_arg: c_int, rr: *NsRr) callconv(.c) c_int {
    if (section < 0 or section >= @as(c_int, @intCast(ns_s_max))) {
        std.c._errno().* = @intFromEnum(std.c.E.NODEV);
        return -1;
    }
    const sect: usize = @intCast(section);

    if (section != handle._sect) {
        handle._sect = section;
        handle._rrnum = 0;
        handle._msg_ptr = handle._sections[sect];
    }
    var rrnum = rrnum_arg;
    if (rrnum == -1) rrnum = handle._rrnum;
    if (rrnum < 0 or rrnum >= @as(c_int, @intCast(handle._counts[sect]))) {
        std.c._errno().* = @intFromEnum(std.c.E.NODEV);
        return -1;
    }
    if (rrnum < handle._rrnum) {
        handle._rrnum = 0;
        handle._msg_ptr = handle._sections[sect];
    }
    if (rrnum > handle._rrnum) {
        const r = ns_skiprr_impl(handle._msg_ptr.?, handle._eom, section, rrnum - handle._rrnum);
        if (r < 0) return -1;
        handle._msg_ptr = handle._msg_ptr.? + @as(usize, @intCast(r));
        handle._rrnum = rrnum;
    }

    const r = ns_name_uncompress_impl(handle._msg, handle._eom, handle._msg_ptr.?, &rr.name, NS_MAXDNAME);
    if (r < 0) return -1;
    var msg_ptr = handle._msg_ptr.? + @as(usize, @intCast(r));
    if (2 * NS_INT16SZ > ptrDiff(handle._eom, msg_ptr)) return setEMSGSIZE();
    rr.rr_type = nsGet16(&msg_ptr);
    rr.rr_class = nsGet16(&msg_ptr);
    if (section != ns_s_qd) {
        if (NS_INT32SZ + NS_INT16SZ > ptrDiff(handle._eom, msg_ptr)) return setEMSGSIZE();
        rr.ttl = nsGet32(&msg_ptr);
        rr.rdlength = nsGet16(&msg_ptr);
        if (rr.rdlength > ptrDiff(handle._eom, msg_ptr)) return setEMSGSIZE();
        rr.rdata = msg_ptr;
        msg_ptr += rr.rdlength;
    } else {
        rr.ttl = 0;
        rr.rdlength = 0;
        rr.rdata = null;
    }
    handle._msg_ptr = msg_ptr;

    handle._rrnum += 1;
    if (handle._rrnum > @as(c_int, @intCast(handle._counts[sect]))) {
        handle._sect = section + 1;
        if (handle._sect == @as(c_int, @intCast(ns_s_max))) {
            handle._rrnum = -1;
            handle._msg_ptr = null;
        } else {
            handle._rrnum = 0;
        }
    }
    return 0;
}

fn ns_name_uncompress_impl(msg: [*]const u8, eom: [*]const u8, src: [*]const u8, dst: [*]u8, dstsiz: usize) callconv(.c) c_int {
    const r = dn_expand_impl(msg, eom, src, dst, @intCast(dstsiz));
    if (r < 0) std.c._errno().* = @intFromEnum(std.c.E.MSGSIZE);
    return r;
}

// ============================================================
// netlink.c
// ============================================================

fn netlink_enumerate(
    fd: c_int,
    seq: c_uint,
    msg_type: c_int,
    af: c_int,
    cb: *const fn (?*anyopaque, *nlmsghdr) callconv(.c) c_int,
    ctx: ?*anyopaque,
) c_int {
    var u: nl_union = undefined;

    const req_bytes: [*]u8 = @ptrCast(&u.req);
    @memset(req_bytes[0..@sizeOf(nl_req)], 0);
    u.req.nlh.nlmsg_len = @sizeOf(nl_req);
    u.req.nlh.nlmsg_type = @intCast(@as(c_uint, @bitCast(msg_type)));
    u.req.nlh.nlmsg_flags = NLM_F_DUMP | NLM_F_REQUEST;
    u.req.nlh.nlmsg_seq = seq;
    u.req.g.rtgen_family = @intCast(@as(c_uint, @bitCast(af)));

    const send_r = c.send_fn(fd, @ptrCast(&u.req), @sizeOf(nl_req), 0);
    if (send_r < 0) return @intCast(send_r);

    while (true) {
        const recv_r = c.recv_fn(fd, @ptrCast(&u.buf), 8192, MSG_DONTWAIT);
        if (recv_r <= 0) return -1;
        const recv_len: usize = @intCast(recv_r);
        const end: [*]const u8 = @as([*]const u8, @ptrCast(&u.buf)) + recv_len;
        var h: *nlmsghdr = &u.reply;
        while (nlmsgOk(h, end)) {
            if (h.nlmsg_type == NLMSG_DONE) return 0;
            if (h.nlmsg_type == NLMSG_ERROR) return -1;
            const ret = cb(ctx, h);
            if (ret != 0) return ret;
            h = nlmsgNext(h);
        }
    }
}

fn rtnetlink_enumerate_impl(
    link_af: c_int,
    addr_af: c_int,
    cb: *const fn (?*anyopaque, *nlmsghdr) callconv(.c) c_int,
    ctx: ?*anyopaque,
) callconv(.c) c_int {
    const fd = c.socket_fn(PF_NETLINK, SOCK_RAW | SOCK_CLOEXEC, NETLINK_ROUTE);
    if (fd < 0) return -1;
    var r = netlink_enumerate(fd, 1, RTM_GETLINK, link_af, cb, ctx);
    if (r == 0) r = netlink_enumerate(fd, 2, RTM_GETADDR, addr_af, cb, ctx);
    _ = linux.close(fd);
    return r;
}
