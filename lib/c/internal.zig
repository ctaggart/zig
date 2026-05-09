const builtin = @import("builtin");
const std = @import("std");
const c = @import("../c.zig");
const linux = std.os.linux;

const off_t = c_longlong;
const EOF = -1;
const ULLONG_MAX: c_ulonglong = std.math.maxInt(c_ulonglong);
const UINT_MAX: c_uint = std.math.maxInt(c_uint);

/// Musl internal FILE struct layout (struct _IO_FILE from stdio_impl.h).
/// Field order MUST match musl's struct _IO_FILE exactly.
const FILE = extern struct {
    flags: c_uint,
    rpos: ?[*]u8,
    rend: ?[*]u8,
    close_fn: ?*const fn (*FILE) callconv(.c) c_int,
    wend: ?[*]u8,
    wpos: ?[*]u8,
    mustbezero_1: ?[*]u8,
    wbase: ?[*]u8,
    read_fn: ?*const fn (*FILE, [*]u8, usize) callconv(.c) usize,
    write_fn: ?*const fn (*FILE, [*]const u8, usize) callconv(.c) usize,
    seek_fn: ?*const fn (*FILE, i64, c_int) callconv(.c) i64,
    buf: ?[*]u8,
    buf_size: usize,
    prev: ?*FILE,
    next: ?*FILE,
    fd: c_int,
    pipe_pid: c_int,
    lockcount: c_long,
    mode: c_int,
    lock: c_int,
    lbf: c_int,
    cookie: ?*anyopaque,
    off: i64,
    getln_buf: ?[*]u8,
    mustbezero_2: ?*anyopaque,
    shend: ?[*]u8,
    shlim: off_t,
    shcnt: off_t,
    prev_locked: ?*FILE,
    next_locked: ?*FILE,
    locale: ?*anyopaque,
};

const uflow_fn = @extern(*const fn (*FILE) callconv(.c) c_int, .{ .name = "__uflow" });

fn ptrDiff(a: [*]const u8, b: [*]const u8) off_t {
    return @as(off_t, @intCast(@as(isize, @bitCast(@intFromPtr(a) -% @intFromPtr(b)))));
}

fn ptrAdd(p: [*]u8, n: off_t) [*]u8 {
    return p + @as(usize, @intCast(n));
}

fn shcnt(f: *FILE) off_t {
    return f.shcnt + ptrDiff(f.rpos.?, f.buf.?);
}

fn shlim(f: *FILE, lim: off_t) callconv(.c) void {
    f.shlim = lim;
    f.shcnt = ptrDiff(f.buf.?, f.rpos.?);
    // If lim is nonzero, rend must be a valid pointer.
    if (lim != 0 and ptrDiff(f.rend.?, f.rpos.?) > lim) {
        f.shend = ptrAdd(f.rpos.?, lim);
    } else {
        f.shend = f.rend;
    }
}

fn shunget(f: *FILE) void {
    if (f.shlim >= 0) f.rpos = f.rpos.? - 1;
}

fn shgetc(f: *FILE) c_int {
    if (f.rpos != f.shend) {
        const ch = f.rpos.?[0];
        f.rpos = f.rpos.? + 1;
        return ch;
    }
    return shgetcSlow(f);
}

// shgetc.c — scan helper bytestream functions
fn shgetcSlow(f: *FILE) callconv(.c) c_int {
    var cnt = shcnt(f);
    const c_uflow = if (f.shlim != 0 and cnt >= f.shlim) EOF else uflow_fn(f);
    if (c_uflow < 0) {
        f.shcnt = ptrDiff(f.buf.?, f.rpos.?) + cnt;
        f.shend = f.rpos;
        f.shlim = -1;
        return EOF;
    }
    cnt += 1;
    if (f.shlim != 0 and ptrDiff(f.rend.?, f.rpos.?) > f.shlim - cnt) {
        f.shend = ptrAdd(f.rpos.?, f.shlim - cnt);
    } else {
        f.shend = f.rend;
    }
    f.shcnt = ptrDiff(f.buf.?, f.rpos.?) + cnt;
    if (@intFromPtr(f.rpos.?) <= @intFromPtr(f.buf.?)) (f.rpos.? - 1)[0] = @intCast(c_uflow);
    return c_uflow;
}

// intscan.c — integer scanner used by scanf-family and strto*-family functions
const digit_table = [_]u8{
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    255,
    255,
    255,
    255,
    255,
    255,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
};

fn digitVal(ch: c_int) u8 {
    if (ch < 0 or ch > 255) return 255;
    return digit_table[@as(usize, @intCast(ch)) + 1];
}

fn isSpace(ch: c_int) bool {
    return ch == ' ' or @as(c_uint, @bitCast(ch - 0x09)) < 5;
}

fn intscan(f: *FILE, base_arg: c_uint, pok: c_int, lim: c_ulonglong) callconv(.c) c_ulonglong {
    var base = base_arg;
    var c_ch: c_int = undefined;
    var neg: c_ulonglong = 0;
    var x: c_uint = undefined;
    var y: c_ulonglong = undefined;

    if (base > 36 or base == 1) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return 0;
    }
    while (true) {
        c_ch = shgetc(f);
        if (!isSpace(c_ch)) break;
    }
    if (c_ch == '+' or c_ch == '-') {
        neg = if (c_ch == '-') ULLONG_MAX else 0;
        c_ch = shgetc(f);
    }
    if ((base == 0 or base == 16) and c_ch == '0') {
        c_ch = shgetc(f);
        if ((c_ch | 32) == 'x') {
            c_ch = shgetc(f);
            if (digitVal(c_ch) >= 16) {
                shunget(f);
                if (pok != 0) shunget(f) else shlim(f, 0);
                return 0;
            }
            base = 16;
        } else if (base == 0) {
            base = 8;
        }
    } else {
        if (base == 0) base = 10;
        if (digitVal(c_ch) >= base) {
            shunget(f);
            shlim(f, 0);
            std.c._errno().* = @intFromEnum(linux.E.INVAL);
            return 0;
        }
    }
    if (base == 10) {
        x = 0;
        while (@as(c_uint, @bitCast(c_ch - '0')) < 10 and x <= UINT_MAX / 10 - 1) : (c_ch = shgetc(f)) {
            x = x * 10 + @as(c_uint, @intCast(c_ch - '0'));
        }
        y = x;
        while (@as(c_uint, @bitCast(c_ch - '0')) < 10 and y <= ULLONG_MAX / 10 and 10 * y <= ULLONG_MAX - @as(c_ulonglong, @intCast(c_ch - '0'))) : (c_ch = shgetc(f)) {
            y = y * 10 + @as(c_ulonglong, @intCast(c_ch - '0'));
        }
        if (@as(c_uint, @bitCast(c_ch - '0')) >= 10) return intscanDone(f, y, neg, lim);
    } else if ((base & (base - 1)) == 0) {
        const shift_table = [_]u3{ 0, 1, 2, 4, 7, 3, 6, 5 };
        const bs = shift_table[((0x17 * base) >> 5) & 7];
        x = 0;
        while (digitVal(c_ch) < base and x <= UINT_MAX / 32) : (c_ch = shgetc(f)) {
            x = (x << bs) | digitVal(c_ch);
        }
        y = x;
        while (digitVal(c_ch) < base and y <= (ULLONG_MAX >> bs)) : (c_ch = shgetc(f)) {
            y = (y << bs) | digitVal(c_ch);
        }
    } else {
        x = 0;
        while (digitVal(c_ch) < base and x <= UINT_MAX / 36 - 1) : (c_ch = shgetc(f)) {
            x = x * base + digitVal(c_ch);
        }
        y = x;
        while (digitVal(c_ch) < base and y <= ULLONG_MAX / base and base * y <= ULLONG_MAX - digitVal(c_ch)) : (c_ch = shgetc(f)) {
            y = y * base + digitVal(c_ch);
        }
    }
    if (digitVal(c_ch) < base) {
        while (digitVal(c_ch) < base) : (c_ch = shgetc(f)) {}
        std.c._errno().* = @intFromEnum(linux.E.RANGE);
        y = lim;
        if ((lim & 1) != 0) neg = 0;
    }
    return intscanDone(f, y, neg, lim);
}

fn intscanDone(f: *FILE, y: c_ulonglong, neg: c_ulonglong, lim: c_ulonglong) c_ulonglong {
    shunget(f);
    if (y >= lim) {
        if ((lim & 1) == 0 and neg == 0) {
            std.c._errno().* = @intFromEnum(linux.E.RANGE);
            return lim - 1;
        } else if (y > lim) {
            std.c._errno().* = @intFromEnum(linux.E.RANGE);
            return lim;
        }
    }
    return (y ^ neg) -% neg;
}

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

// vdso.c — vDSO symbol lookup
const elf = std.elf;
const Ehdr = if (@sizeOf(usize) == 4) elf.Elf32_Ehdr else elf.Elf64_Ehdr;
const Phdr = if (@sizeOf(usize) == 4) elf.Elf32_Phdr else elf.Elf64_Phdr;
const Sym = if (@sizeOf(usize) == 4) elf.Elf32_Sym else elf.Elf64_Sym;
const Verdef = elf.Verdef;
const Verdaux = elf.Verdaux;

const OK_TYPES = (1 << elf.STT_NOTYPE) | (1 << elf.STT_OBJECT) | (1 << elf.STT_FUNC) | (1 << elf.STT_COMMON);
const OK_BINDS = (1 << elf.STB_GLOBAL) | (1 << elf.STB_WEAK) | (1 << elf.STB_GNU_UNIQUE);

fn vDSOUseful() bool {
    return builtin.os.tag == .linux and switch (builtin.cpu.arch) {
        .x86, .x86_64, .arm, .thumb, .aarch64, .mips, .mipsel, .mips64, .mips64el, .riscv32, .riscv64, .loongarch64 => true,
        else => false,
    };
}

fn phdrType(ph: *const Phdr) elf.Word {
    return if (@sizeOf(usize) == 4) ph.p_type else ph.p_type;
}

fn phdrOffset(ph: *const Phdr) usize {
    return @intCast(ph.p_offset);
}

fn phdrVaddr(ph: *const Phdr) usize {
    return @intCast(ph.p_vaddr);
}

fn symValue(sym: Sym) usize {
    return @intCast(sym.st_value);
}

fn checkver(def_arg: *const Verdef, vsym_arg: u16, vername: [*:0]const u8, strings: [*]const u8) bool {
    var def = def_arg;
    const vsym = vsym_arg & 0x7fff;
    while (true) {
        if ((def.flags & elf.VER_FLG_BASE) == 0 and (@intFromEnum(def.ndx) & 0x7fff) == vsym) break;
        if (def.next == 0) return false;
        def = @ptrFromInt(@intFromPtr(def) + def.next);
    }

    const aux: *const Verdaux = @ptrFromInt(@intFromPtr(def) + def.aux);
    return cstrEql(vername, @ptrCast(strings + aux.name));
}

fn cstrEql(a: [*:0]const u8, b: [*:0]const u8) bool {
    var i: usize = 0;
    while (true) : (i += 1) {
        if (a[i] != b[i]) return false;
        if (a[i] == 0) return true;
    }
}

fn __vdsosymLinux(vername: [*:0]const u8, name: [*:0]const u8) callconv(.c) ?*anyopaque {
    if (!vDSOUseful()) return null;

    const auxv = libc_struct.auxv orelse return null;
    var i: usize = 0;
    while (auxv[i] != elf.AT_SYSINFO_EHDR) : (i += 2) {
        if (auxv[i] == 0) return null;
    }
    if (auxv[i + 1] == 0) return null;

    const eh: *const Ehdr = @ptrFromInt(auxv[i + 1]);
    var ph: *const Phdr = @ptrFromInt(@intFromPtr(eh) + eh.e_phoff);
    var dynv: ?[*]const usize = null;
    var base: usize = std.math.maxInt(usize);
    i = 0;
    while (i < eh.e_phnum) : ({
        i += 1;
        ph = @ptrFromInt(@intFromPtr(ph) + eh.e_phentsize);
    }) {
        switch (phdrType(ph)) {
            elf.PT_LOAD => base = @intFromPtr(eh) + phdrOffset(ph) - phdrVaddr(ph),
            elf.PT_DYNAMIC => dynv = @ptrFromInt(@intFromPtr(eh) + phdrOffset(ph)),
            else => {},
        }
    }
    const dyn = dynv orelse return null;
    if (base == std.math.maxInt(usize)) return null;

    var strings: ?[*]const u8 = null;
    var syms: ?[*]const Sym = null;
    var hashtab: ?[*]const u32 = null;
    var versym: ?[*]const u16 = null;
    var verdef: ?*const Verdef = null;

    i = 0;
    while (dyn[i] != 0) : (i += 2) {
        const p = base + dyn[i + 1];
        switch (dyn[i]) {
            elf.DT_STRTAB => strings = @ptrFromInt(p),
            elf.DT_SYMTAB => syms = @ptrFromInt(p),
            elf.DT_HASH => hashtab = @ptrFromInt(p),
            elf.DT_VERSYM => versym = @ptrFromInt(p),
            elf.DT_VERDEF => verdef = @ptrFromInt(p),
            else => {},
        }
    }

    const string_table = strings orelse return null;
    const sym_table = syms orelse return null;
    const hash_table = hashtab orelse return null;
    if (verdef == null) versym = null;

    i = 0;
    while (i < hash_table[1]) : (i += 1) {
        const info = sym_table[i].st_info;
        if (((@as(usize, 1) << @as(u4, @truncate(info))) & OK_TYPES) == 0) continue;
        if (((@as(usize, 1) << @as(u4, @truncate(info >> 4))) & OK_BINDS) == 0) continue;
        if (sym_table[i].st_shndx == 0) continue;
        if (!cstrEql(name, @ptrCast(string_table + sym_table[i].st_name))) continue;
        if (versym) |vs| {
            if (!checkver(verdef.?, vs[i], vername, string_table)) continue;
        }
        return @ptrFromInt(base + symValue(sym_table[i]));
    }

    return null;
}

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

const EINVAL = 22;
const ERANGE = 34;

// floatscan.c — scanner for strtod/scanf-family floating point conversion.
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

fn appendFloatScan(buf: *[4096]u8, len: *usize, ch: c_int) void {
    if (len.* < buf.len) {
        buf[len.*] = @intCast(ch);
        len.* += 1;
    }
}

fn popFloatScan(len: *usize) void {
    if (len.* != 0) len.* -= 1;
}

fn invalidFloatScan(f: *FILE) c_longdouble {
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

const longdouble_float: type = switch (@bitSizeOf(c_longdouble)) {
    64 => f64,
    80 => f80,
    128 => f128,
    else => @compileError("unsupported c_longdouble bit size"),
};

fn finishScannedFloat(s: []const u8, prec: c_int, saw_nonzero: bool) c_longdouble {
    return switch (prec) {
        0 => parseScannedFloat(f32, s, saw_nonzero),
        1 => parseScannedFloat(f64, s, saw_nonzero),
        2 => parseScannedFloat(longdouble_float, s, saw_nonzero),
        else => 0,
    };
}

fn scanExponentSuffix(f: *FILE, buf: *[4096]u8, len: *usize, marker: c_int) void {
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

fn scanInfTail(f: *FILE, buf: *[4096]u8, len: *usize) void {
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

fn floatscan(f: *FILE, prec: c_int, pok: c_int) callconv(.c) c_longdouble {
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
        c.symbol(&__vdsosymLinux, "__vdsosym");
        c.symbol(&shlim, "__shlim");
        c.symbol(&shgetcSlow, "__shgetc");
        c.symbol(&intscan, "__intscan");
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
