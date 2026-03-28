const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        if (builtin.link_libc) {
            // gethostbyname2.c: wrapper with malloc/free retry loop
            symbol(&gethostbyname2_impl, "gethostbyname2");
            // gethostbyaddr.c: wrapper with malloc/free retry loop
            symbol(&gethostbyaddr_impl, "gethostbyaddr");
            // getservbyname.c: wrapper around getservbyname_r
            symbol(&getservbyname_impl, "getservbyname");
            // getservbyport.c: wrapper around getservbyport_r
            symbol(&getservbyport_impl, "getservbyport");
            // h_errno.c
            symbol(&h_errno_val, "h_errno");
            symbol(&__h_errno_location_impl, "__h_errno_location");
            // herror.c
            symbol(&herror_impl, "herror");
            // hstrerror.c
            symbol(&hstrerror_impl, "hstrerror");
            // gai_strerror.c
            symbol(&gai_strerror_impl, "gai_strerror");
            // res_state.c
            symbol(&__res_state_impl, "__res_state");
        }
    }
}

const ERANGE: c_int = 34;
const NO_RECOVERY: c_int = 3;

// --- gethostbyname2: retry gethostbyname2_r with growing buffer ---

fn gethostbyname2_impl(name: [*:0]const u8, af: c_int) callconv(.c) ?*anyopaque {
    const S = struct {
        var h: ?*anyopaque = null;
    };
    const gethostbyname2_r = @extern(*const fn ([*:0]const u8, c_int, *anyopaque, [*]u8, usize, *?*anyopaque, *c_int) callconv(.c) c_int, .{ .name = "gethostbyname2_r" });
    const c_malloc = @extern(*const fn (usize) callconv(.c) ?[*]u8, .{ .name = "malloc" });
    const c_free = @extern(*const fn (?*anyopaque) callconv(.c) void, .{ .name = "free" });
    const h_errno_ptr = @extern(*c_int, .{ .name = "h_errno" });

    var size: usize = 63;
    var res: ?*anyopaque = null;
    var err: c_int = undefined;
    while (true) {
        c_free(S.h);
        size = size +% size +% 1;
        const buf = c_malloc(size) orelse {
            h_errno_ptr.* = NO_RECOVERY;
            return null;
        };
        S.h = @ptrCast(buf);
        // hostent is at start of buffer, string data follows
        const hostent_size = 32; // conservative sizeof(struct hostent)
        err = gethostbyname2_r(name, af, @ptrCast(buf), buf + hostent_size, size - hostent_size, &res, h_errno_ptr);
        if (err != ERANGE) break;
    }
    return res;
}

// --- gethostbyaddr: retry gethostbyaddr_r with growing buffer ---

fn gethostbyaddr_impl(a: *const anyopaque, l: u32, af: c_int) callconv(.c) ?*anyopaque {
    const S = struct {
        var h: ?*anyopaque = null;
    };
    const gethostbyaddr_r = @extern(*const fn (*const anyopaque, u32, c_int, *anyopaque, [*]u8, usize, *?*anyopaque, *c_int) callconv(.c) c_int, .{ .name = "gethostbyaddr_r" });
    const c_malloc = @extern(*const fn (usize) callconv(.c) ?[*]u8, .{ .name = "malloc" });
    const c_free = @extern(*const fn (?*anyopaque) callconv(.c) void, .{ .name = "free" });
    const h_errno_ptr = @extern(*c_int, .{ .name = "h_errno" });

    var size: usize = 63;
    var res: ?*anyopaque = null;
    var err: c_int = undefined;
    while (true) {
        c_free(S.h);
        size = size +% size +% 1;
        const buf = c_malloc(size) orelse {
            h_errno_ptr.* = NO_RECOVERY;
            return null;
        };
        S.h = @ptrCast(buf);
        const hostent_size = 32;
        err = gethostbyaddr_r(a, l, af, @ptrCast(buf), buf + hostent_size, size - hostent_size, &res, h_errno_ptr);
        if (err != ERANGE) break;
    }
    return res;
}

// --- getservbyname: wrapper with static servent ---

fn getservbyname_impl(name: [*:0]const u8, prots: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    const S = struct {
        var se: [64]u8 align(8) = undefined;
        var buf: [2]?*anyopaque = .{ null, null };
    };
    const getservbyname_r = @extern(*const fn ([*:0]const u8, ?[*:0]const u8, *anyopaque, [*]u8, usize, *?*anyopaque) callconv(.c) c_int, .{ .name = "getservbyname_r" });
    var res: ?*anyopaque = null;
    if (getservbyname_r(name, prots, &S.se, @ptrCast(&S.buf), @sizeOf(@TypeOf(S.buf)), &res) != 0)
        return null;
    return @ptrCast(&S.se);
}

// --- getservbyport: wrapper with static servent ---

fn getservbyport_impl(port: c_int, prots: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    const S = struct {
        var se: [64]u8 align(8) = undefined;
        var buf: [32]u8 align(8) = undefined;
    };
    const getservbyport_r = @extern(*const fn (c_int, ?[*:0]const u8, *anyopaque, [*]u8, usize, *?*anyopaque) callconv(.c) c_int, .{ .name = "getservbyport_r" });
    var res: ?*anyopaque = null;
    if (getservbyport_r(port, prots, &S.se, &S.buf, @sizeOf(@TypeOf(S.buf)), &res) != 0)
        return null;
    return @ptrCast(&S.se);
}

// --- h_errno ---

var h_errno_val: c_int = 0;

fn __h_errno_location_impl() callconv(.c) *c_int {
    return &h_errno_val;
}

// --- herror ---

fn herror_impl(msg: ?[*:0]const u8) callconv(.c) void {
    const c_fprintf = @extern(*const fn (*anyopaque, [*:0]const u8, ...) callconv(.c) c_int, .{ .name = "fprintf" });
    const stderr_ptr = @extern(**anyopaque, .{ .name = "stderr" });
    const h_errno_ptr = @extern(*c_int, .{ .name = "h_errno" });
    const hstrerror_c = @extern(*const fn (c_int) callconv(.c) [*:0]const u8, .{ .name = "hstrerror" });
    if (msg) |m| {
        _ = c_fprintf(stderr_ptr.*, "%s: %s\n", m, hstrerror_c(h_errno_ptr.*));
    } else {
        _ = c_fprintf(stderr_ptr.*, "%s\n", hstrerror_c(h_errno_ptr.*));
    }
}

// --- hstrerror ---

const hstrerror_msgs =
    "Host not found\x00" ++
    "Try again\x00" ++
    "Non-recoverable error\x00" ++
    "Address not available\x00" ++
    "\x00Unknown error";

fn hstrerror_impl(ecode: c_int) callconv(.c) [*:0]const u8 {
    var s: [*]const u8 = hstrerror_msgs.ptr;
    var e = ecode - 1;
    while (e > 0 and s[0] != 0) {
        while (s[0] != 0) s += 1;
        s += 1;
        e -= 1;
    }
    if (s[0] == 0) s += 1;
    return @ptrCast(s);
}

// --- gai_strerror ---

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
    var s: [*]const u8 = gai_strerror_msgs.ptr;
    var e = ecode + 1;
    while (e > 0 and s[0] != 0) {
        while (s[0] != 0) s += 1;
        s += 1;
        e -= 1;
    }
    // In musl, ecode counts up (ecode++) and starts negative, so here
    // we handle the same logic: skip forward by (ecode+1) entries
    while (e < 0 and s[0] != 0) {
        while (s[0] != 0) s += 1;
        s += 1;
        e += 1;
    }
    if (s[0] == 0) s += 1;
    return @ptrCast(s);
}

// --- res_state ---

fn __res_state_impl() callconv(.c) *anyopaque {
    const S = struct {
        var res: [600]u8 = [1]u8{0} ** 600;
    };
    return @ptrCast(&S.res);
}
