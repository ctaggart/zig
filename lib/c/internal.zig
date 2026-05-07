const builtin = @import("builtin");
const std = @import("std");
const c = @import("../c.zig");
const linux = std.os.linux;

// syscall_ret.c — syscall return value to errno conversion
fn syscall_retLinux(r: c_ulong) callconv(.c) c_long {
    const signed_r: c_long = @bitCast(r);
    if (signed_r >= -4095 and signed_r < 0) {
        std.c._errno().* = @intCast(-signed_r);
        return -1;
    }
    return signed_r;
}

// procfdname.c — /proc/self/fd/N path builder
fn procfdnameLinux(buf: [*]u8, fd: c_uint) callconv(.c) void {
    const prefix = "/proc/self/fd/";
    @memcpy(buf[0..prefix.len], prefix);
    var i: usize = prefix.len;
    if (fd == 0) {
        buf[i] = '0';
        buf[i + 1] = 0;
        return;
    }
    var j: c_uint = fd;
    while (j != 0) : (j /= 10) {
        i += 1;
    }
    buf[i] = 0;
    var remaining: c_uint = fd;
    while (remaining != 0) : (remaining /= 10) {
        i -= 1;
        buf[i] = '0' + @as(u8, @intCast(remaining % 10));
    }
}

// version.c — musl version string
const libc_version: [5:0]u8 = "1.2.5".*;

// defsysinfo.c — vDSO pointer
var sysinfo: usize = 0;

// libc.c — libc struct initialization and globals
const LibcStruct = extern struct {
    can_do_threads: u8,
    threaded: u8,
    secure: u8,
    need_locks: i8,
    threads_minus_1: c_int,
    auxv: ?[*]usize,
    tls_head: ?*anyopaque,
    tls_size: usize,
    tls_align: usize,
    tls_cnt: usize,
    page_size: usize,
    global_locale: extern struct {
        cat: [6]?*const anyopaque,
    },
};

var libc_struct: LibcStruct = std.mem.zeroes(LibcStruct);
var hwcap: usize = 0;
var progname: ?[*]u8 = null;
var progname_full: ?[*]u8 = null;

const off_t = c_longlong;
const EINVAL = 22;
const ERANGE = 34;

// floatscan.c — scanner for strtod/scanf-family floating point conversion.
// This matches musl's FILE layout closely enough to interoperate with the
// existing shgetc helpers and with the string pseudo-FILEs used by strtod.
const InternalFile = extern struct {
    flags: c_uint,
    rpos: ?[*]u8,
    rend: ?[*]u8,
    close_fn: ?*anyopaque,
    wend: ?[*]u8,
    wpos: ?[*]u8,
    mustbezero_1: ?[*]u8,
    wbase: ?[*]u8,
    read_fn: ?*anyopaque,
    write_fn: ?*anyopaque,
    seek_fn: ?*anyopaque,
    buf: ?[*]u8,
    buf_size: usize,
    prev: ?*anyopaque,
    next: ?*anyopaque,
    fd: c_int,
    pipe_pid: c_int,
    lockcount: c_long,
    mode: c_int,
    lock: c_int,
    lbf: c_int,
    cookie: ?*anyopaque,
    off: off_t,
    getln_buf: ?[*]u8,
    mustbezero_2: ?*anyopaque,
    shend: ?[*]u8,
    shlim_val: off_t,
    shcnt_val: off_t,
    prev_locked: ?*anyopaque,
    next_locked: ?*anyopaque,
    locale: ?*anyopaque,
};

extern "c" fn __shgetc(f: *InternalFile) c_int;

fn shgetc(f: *InternalFile) c_int {
    if (f.rpos != f.shend) {
        const p = f.rpos.?;
        const ch: c_int = p[0];
        f.rpos = p + 1;
        return ch;
    }
    return __shgetc(f);
}

fn shunget(f: *InternalFile) void {
    if (f.shlim_val >= 0) f.rpos = f.rpos.? - 1;
}

fn shlim(f: *InternalFile, lim: off_t) void {
    f.shlim_val = lim;
    f.shcnt_val = @as(off_t, @intCast(@intFromPtr(f.buf.?) - @intFromPtr(f.rpos.?)));
    if (lim != 0 and @as(off_t, @intCast(@intFromPtr(f.rend.?) - @intFromPtr(f.rpos.?))) > lim)
        f.shend = f.rpos.? + @as(usize, @intCast(lim))
    else
        f.shend = f.rend;
}

fn setErrno(e: c_int) void {
    std.c._errno().* = e;
}

fn asciiLower(ch: c_int) c_int {
    return ch | 32;
}

fn isDigit(ch: c_int) bool {
    return ch >= '0' and ch <= '9';
}

fn isHexDigit(ch: c_int) bool {
    const lower = asciiLower(ch);
    return isDigit(ch) or (lower >= 'a' and lower <= 'f');
}

fn isNanChar(ch: c_int) bool {
    const lower = asciiLower(ch);
    return isDigit(ch) or (lower >= 'a' and lower <= 'z') or ch == '_';
}

fn isSpace(ch: c_int) bool {
    return std.ascii.isWhitespace(@truncate(@as(c_uint, @bitCast(ch))));
}

fn appendFloatScan(buf: *[4096]u8, len: *usize, ch: c_int) void {
    if (len.* < buf.len) {
        buf[len.*] = @intCast(ch);
        len.* += 1;
    }
}

fn popFloatScan(len: *usize) void {
    if (len.* != 0) len.* -= 1;
}

fn invalidFloatScan(f: *InternalFile) c_longdouble {
    setErrno(EINVAL);
    shlim(f, 0);
    return 0;
}

fn parseScannedFloat(comptime T: type, s: []const u8, saw_nonzero: bool) c_longdouble {
    const parsed = std.fmt.parseFloat(T, s) catch {
        setErrno(EINVAL);
        return 0;
    };
    if (!std.math.isFinite(parsed)) {
        setErrno(ERANGE);
    } else if (parsed == 0 and saw_nonzero) {
        setErrno(ERANGE);
    }
    return @floatCast(parsed);
}

fn finishScannedFloat(s: []const u8, prec: c_int, saw_nonzero: bool) c_longdouble {
    return switch (prec) {
        0 => parseScannedFloat(f32, s, saw_nonzero),
        1 => parseScannedFloat(f64, s, saw_nonzero),
        2 => parseScannedFloat(c_longdouble, s, saw_nonzero),
        else => 0,
    };
}

fn scanExponentSuffix(f: *InternalFile, buf: *[4096]u8, len: *usize, marker: c_int) void {
    appendFloatScan(buf, len, marker);
    var ch = shgetc(f);
    var had_sign = false;
    if (ch == '+' or ch == '-') {
        had_sign = true;
        appendFloatScan(buf, len, ch);
        ch = shgetc(f);
    }
    if (!isDigit(ch)) {
        shunget(f);
        if (had_sign) {
            shunget(f);
            popFloatScan(len);
        }
        popFloatScan(len);
        return;
    }
    while (isDigit(ch)) : (ch = shgetc(f)) appendFloatScan(buf, len, ch);
    if (ch >= 0) shunget(f);
}

fn scanInfTail(f: *InternalFile, buf: *[4096]u8, len: *usize) void {
    const tail = "inity";
    var consumed: usize = 0;
    for (tail) |want| {
        const ch = shgetc(f);
        if (asciiLower(ch) != want) {
            if (ch >= 0) shunget(f);
            while (consumed != 0) : (consumed -= 1) {
                shunget(f);
                popFloatScan(len);
            }
            return;
        }
        appendFloatScan(buf, len, ch);
        consumed += 1;
    }
}

fn floatscan(f: *InternalFile, prec: c_int, pok: c_int) callconv(.c) c_longdouble {
    _ = pok;
    var buf: [4096]u8 = undefined;
    var len: usize = 0;
    var saw_nonzero = false;

    var ch = shgetc(f);
    while (isSpace(ch)) ch = shgetc(f);

    if (ch == '+' or ch == '-') {
        appendFloatScan(&buf, &len, ch);
        ch = shgetc(f);
    }

    if (asciiLower(ch) == 'i') {
        appendFloatScan(&buf, &len, ch);
        const n = shgetc(f);
        const fch = shgetc(f);
        if (asciiLower(n) != 'n' or asciiLower(fch) != 'f') {
            if (fch >= 0) shunget(f);
            if (n >= 0) shunget(f);
            return invalidFloatScan(f);
        }
        appendFloatScan(&buf, &len, n);
        appendFloatScan(&buf, &len, fch);
        scanInfTail(f, &buf, &len);
        return finishScannedFloat(buf[0..len], prec, true);
    }

    if (asciiLower(ch) == 'n') {
        appendFloatScan(&buf, &len, ch);
        const a = shgetc(f);
        const n = shgetc(f);
        if (asciiLower(a) != 'a' or asciiLower(n) != 'n') {
            if (n >= 0) shunget(f);
            if (a >= 0) shunget(f);
            return invalidFloatScan(f);
        }
        appendFloatScan(&buf, &len, a);
        appendFloatScan(&buf, &len, n);
        ch = shgetc(f);
        if (ch == '(') {
            appendFloatScan(&buf, &len, ch);
            while (true) {
                ch = shgetc(f);
                if (isNanChar(ch)) appendFloatScan(&buf, &len, ch) else break;
            }
            if (ch == ')') appendFloatScan(&buf, &len, ch) else if (ch >= 0) shunget(f);
        } else if (ch >= 0) shunget(f);
        return finishScannedFloat(buf[0..len], prec, true);
    }

    var gotdig = false;
    if (ch == '0') {
        appendFloatScan(&buf, &len, ch);
        gotdig = true;
        ch = shgetc(f);
        if (asciiLower(ch) == 'x') {
            appendFloatScan(&buf, &len, ch);
            var gothex = false;
            ch = shgetc(f);
            while (isHexDigit(ch)) : (ch = shgetc(f)) {
                gothex = true;
                if (ch != '0') saw_nonzero = true;
                appendFloatScan(&buf, &len, ch);
            }
            if (ch == '.') {
                appendFloatScan(&buf, &len, ch);
                ch = shgetc(f);
                while (isHexDigit(ch)) : (ch = shgetc(f)) {
                    gothex = true;
                    if (ch != '0') saw_nonzero = true;
                    appendFloatScan(&buf, &len, ch);
                }
            }
            if (!gothex) {
                if (ch >= 0) shunget(f);
                shunget(f);
                popFloatScan(&len);
                return finishScannedFloat(buf[0..len], prec, false);
            }
            if (asciiLower(ch) == 'p') scanExponentSuffix(f, &buf, &len, ch) else if (ch >= 0) shunget(f);
            return finishScannedFloat(buf[0..len], prec, saw_nonzero);
        }
    }

    while (isDigit(ch)) : (ch = shgetc(f)) {
        gotdig = true;
        if (ch != '0') saw_nonzero = true;
        appendFloatScan(&buf, &len, ch);
    }
    if (ch == '.') {
        appendFloatScan(&buf, &len, ch);
        ch = shgetc(f);
        while (isDigit(ch)) : (ch = shgetc(f)) {
            gotdig = true;
            if (ch != '0') saw_nonzero = true;
            appendFloatScan(&buf, &len, ch);
        }
    }

    if (!gotdig) return invalidFloatScan(f);
    if (asciiLower(ch) == 'e') scanExponentSuffix(f, &buf, &len, ch) else if (ch >= 0) shunget(f);
    return finishScannedFloat(buf[0..len], prec, saw_nonzero);
}

// emulate_wait4.c — wait4 emulation via SYS_waitid for arches lacking
// SYS_wait4 (currently riscv32, loongarch32). Mirrors musl's
// `#ifndef SYS_wait4` gate and reproduces the kernel-ABI status word that
// wait4 would have returned by translating siginfo_t fields.
const WEXITED: c_int = 4;

fn __emulate_wait4Linux(
    pid: c_int,
    status: ?*c_int,
    options: c_int,
    kru: ?*linux.rusage,
    cp: c_int,
) callconv(.c) c_long {
    _ = cp; // cancellation point not implemented; same path as non-cp
    var info: linux.siginfo_t = undefined;
    info.fields.common.first.piduid.pid = 0;

    var p: c_int = pid;
    const t: linux.P = if (pid < -1) blk: {
        p = -pid;
        break :blk .PGID;
    } else if (pid == -1) .ALL else if (pid == 0) .PGID else .PID;

    const r: isize = @bitCast(linux.syscall5(
        .waitid,
        @intFromEnum(t),
        @as(usize, @bitCast(@as(isize, p))),
        @intFromPtr(&info),
        @as(usize, @bitCast(@as(isize, options | WEXITED))),
        @intFromPtr(kru),
    ));

    if (r < 0) return @intCast(r);

    const si_pid = info.fields.common.first.piduid.pid;
    if (si_pid != 0) if (status) |sp| {
        const si_status = info.fields.common.second.sigchld.status;
        const code: linux.CLD = @enumFromInt(info.code);
        var sw: c_int = 0;
        switch (code) {
            .CONTINUED => sw = 0xffff,
            .DUMPED => sw = (si_status & 0x7f) | 0x80,
            .EXITED => sw = (si_status & 0xff) << 8,
            .KILLED => sw = si_status & 0x7f,
            .STOPPED, .TRAPPED => sw = (si_status << 8) + 0x7f,
            else => {},
        }
        sp.* = sw;
    };

    return @as(c_long, si_pid);
}

comptime {
    if (builtin.target.isMuslLibC()) {
        c.symbol(&syscall_retLinux, "__syscall_ret");
        c.symbol(&procfdnameLinux, "__procfdname");
        c.symbol(&floatscan, "__floatscan");

        // Export __emulate_wait4 only on arches where musl needs it (i.e. those
        // lacking SYS_wait4). On other arches musl's `__sys_wait4` macro inlines
        // a direct SYS_wait4 syscall and never calls this helper.
        if (!@hasField(linux.SYS, "wait4")) {
            c.symbol(&__emulate_wait4Linux, "__emulate_wait4");
        }

        @export(&libc_version, .{ .name = "__libc_version", .linkage = .weak, .visibility = .hidden });
        @export(&sysinfo, .{ .name = "__sysinfo", .linkage = .weak, .visibility = .hidden });

        @export(&libc_struct, .{ .name = "__libc", .linkage = .weak, .visibility = .hidden });
        @export(&hwcap, .{ .name = "__hwcap", .linkage = .weak, .visibility = .hidden });
        @export(&progname, .{ .name = "__progname", .linkage = .weak, .visibility = .default });
        @export(&progname_full, .{ .name = "__progname_full", .linkage = .weak, .visibility = .default });
        @export(&progname, .{ .name = "program_invocation_short_name", .linkage = .weak, .visibility = .default });
        @export(&progname_full, .{ .name = "program_invocation_name", .linkage = .weak, .visibility = .default });
    }
}

test procfdnameLinux {
    var buf: [32]u8 = undefined;

    procfdnameLinux(&buf, 0);
    try std.testing.expectEqualStrings("/proc/self/fd/0", std.mem.sliceTo(&buf, 0));

    procfdnameLinux(&buf, 1);
    try std.testing.expectEqualStrings("/proc/self/fd/1", std.mem.sliceTo(&buf, 0));

    procfdnameLinux(&buf, 42);
    try std.testing.expectEqualStrings("/proc/self/fd/42", std.mem.sliceTo(&buf, 0));

    procfdnameLinux(&buf, 12345);
    try std.testing.expectEqualStrings("/proc/self/fd/12345", std.mem.sliceTo(&buf, 0));

    procfdnameLinux(&buf, 999999999);
    try std.testing.expectEqualStrings("/proc/self/fd/999999999", std.mem.sliceTo(&buf, 0));
}
