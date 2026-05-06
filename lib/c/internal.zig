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
