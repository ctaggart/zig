//! Zig implementations of musl ldso (dynamic linker stub) functions.
//!
//! These are stub implementations for statically-linked executables.
//! The real dynamic linker overrides these weak symbols when present.
//!
//! Migrated from:
//!   - musl/src/ldso/dladdr.c
//!   - musl/src/ldso/dlclose.c
//!   - musl/src/ldso/dlerror.c
//!   - musl/src/ldso/dlinfo.c
//!   - musl/src/ldso/dl_iterate_phdr.c
//!   - musl/src/ldso/dlopen.c
//!   - musl/src/ldso/__dlsym.c
//!   - musl/src/ldso/dlsym.c
//!   - musl/src/ldso/tlsdesc.c
//!   - musl/src/ldso/arm/find_exidx.c

const std = @import("std");
const builtin = @import("builtin");
const elf = std.elf;
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        // Self-contained stubs (no C library dependencies).
        symbol(&dladdr, "dladdr");
        symbol(&__tlsdesc_static, "__tlsdesc_static");
        symbol(&__tlsdesc_static, "__tlsdesc_dynamic");

        // Functions with C library dependencies.
        if (builtin.link_libc) {
            // dlerror family (replaces dlerror.c)
            symbol(&dlerror_impl, "dlerror");
            symbol(&dl_seterr_impl, "__dl_seterr");
            symbol(&dl_thread_cleanup_impl, "__dl_thread_cleanup");
            symbol(&stub_invalid_handle, "__dl_invalid_handle");

            // dl stubs (replaces dlclose.c, dlinfo.c, dlopen.c, dlsym.c, __dlsym.c)
            symbol(&dlclose, "dlclose");
            symbol(&dlinfo, "dlinfo");
            symbol(&dlopen, "dlopen");
            symbol(&dlsym_impl, "dlsym");
            symbol(&__dlsym_stub, "__dlsym");
            if (@sizeOf(c_long) < 8) {
                symbol(&__dlsym_stub, "__dlsym_redir_time64");
            }

            // dl_iterate_phdr (replaces dl_iterate_phdr.c)
            symbol(&dl_iterate_phdr_impl, "dl_iterate_phdr");

            // ARM exception index lookup (replaces arm/find_exidx.c)
            switch (builtin.cpu.arch) {
                .arm, .armeb, .thumb, .thumbeb => {
                    symbol(&gnu_Unwind_Find_exidx, "__gnu_Unwind_Find_exidx");
                },
                else => {},
            }
        }
    }
}

const RTLD_DI_LINKMAP = 2;

// ============================================================
// Self-contained stubs (no C library dependencies)
// ============================================================

fn dladdr(addr: ?*const anyopaque, info: ?*anyopaque) callconv(.c) c_int {
    _ = addr;
    _ = info;
    return 0;
}

fn __tlsdesc_static() callconv(.c) isize {
    return 0;
}

// ============================================================
// dlerror implementation (replaces musl/src/ldso/dlerror.c)
//
// Uses Zig threadlocal storage instead of musl's pthread struct fields.
// Uses a fixed-size buffer instead of malloc, eliminating the need for
// the atomic free-list in the original C code.
// ============================================================

threadlocal var tl_errbuf: [256]u8 = .{0} ** 256;
threadlocal var tl_errflag: bool = false;

fn dlerror_impl() callconv(.c) ?[*:0]const u8 {
    if (!tl_errflag) return null;
    tl_errflag = false;
    const ptr: [*]const u8 = &tl_errbuf;
    return @ptrCast(ptr);
}

/// Set the dlerror message using Zig formatting.
fn setDlError(comptime fmt: []const u8, args: anytype) void {
    const result = std.fmt.bufPrint(tl_errbuf[0 .. tl_errbuf.len - 1], fmt, args) catch {
        tl_errbuf[tl_errbuf.len - 1] = 0;
        tl_errflag = true;
        return;
    };
    tl_errbuf[result.len] = 0;
    tl_errflag = true;
}

/// Exported __dl_seterr for C ABI compatibility.
/// Copies the format string as the error message. Our Zig stubs use
/// setDlError directly for proper formatting; this export exists for
/// any external C code that references the symbol.
fn dl_seterr_impl(fmt: [*:0]const u8, ...) callconv(.c) void {
    const s = std.mem.span(fmt);
    const len = @min(s.len, tl_errbuf.len - 1);
    @memcpy(tl_errbuf[0..len], s[0..len]);
    tl_errbuf[len] = 0;
    tl_errflag = true;
}

fn dl_thread_cleanup_impl() callconv(.c) void {
    // No dynamic allocation to clean up with fixed buffer.
}

fn stub_invalid_handle(h: ?*anyopaque) callconv(.c) c_int {
    const addr: usize = if (h) |p| @intFromPtr(p) else 0;
    setDlError("Invalid library handle 0x{x}", .{addr});
    return 1;
}

// ============================================================
// Stub functions depending on dlerror
// ============================================================

fn dlclose(p: ?*anyopaque) callconv(.c) c_int {
    return stub_invalid_handle(p);
}

fn dlinfo(dso: ?*anyopaque, req: c_int, res: ?*anyopaque) callconv(.c) c_int {
    if (stub_invalid_handle(dso) != 0) return -1;
    if (req != RTLD_DI_LINKMAP) {
        setDlError("Unsupported request {d}", .{req});
        return -1;
    }
    const ptr: *?*anyopaque = @ptrCast(@alignCast(res));
    ptr.* = dso;
    return 0;
}

fn dlopen(file: ?[*:0]const u8, mode: c_int) callconv(.c) ?*anyopaque {
    _ = file;
    _ = mode;
    setDlError("Dynamic loading not supported", .{});
    return null;
}

fn dlsym_impl(p: ?*anyopaque, s: ?[*:0]const u8) callconv(.c) ?*anyopaque {
    return __dlsym_stub(p, s, null);
}

fn __dlsym_stub(p: ?*anyopaque, s: ?[*:0]const u8, ra: ?*anyopaque) callconv(.c) ?*anyopaque {
    _ = p;
    _ = ra;
    setDlError("Symbol not found: {s}", .{if (s) |name| std.mem.span(name) else "(null)"});
    return null;
}

// ============================================================
// dl_iterate_phdr implementation (replaces musl/src/ldso/dl_iterate_phdr.c)
//
// Static executable stub that iterates over the program's own
// ELF headers via the auxiliary vector. The dynamic linker
// overrides this weak symbol with its own full implementation.
// ============================================================

/// Extended dl_phdr_info matching musl's struct layout including
/// the TLS fields beyond the minimal POSIX definition.
const DlPhdrInfo = extern struct {
    addr: usize,
    name: ?[*:0]const u8,
    phdr: [*]const elf.ElfN.Phdr,
    phnum: u16,
    adds: c_ulonglong,
    subs: c_ulonglong,
    tls_modid: usize,
    tls_data: ?*anyopaque,
};

const DlPhdrCallback = *const fn (*DlPhdrInfo, usize, ?*anyopaque) callconv(.c) c_int;

extern fn __tls_get_addr(v: *const [2]usize) callconv(.c) ?*anyopaque;

fn get_DYNAMIC() ?[*]const elf.Dyn {
    return @extern([*]const elf.Dyn, .{
        .name = "_DYNAMIC",
        .linkage = .weak,
        .visibility = .hidden,
    });
}

fn dl_iterate_phdr_impl(callback: DlPhdrCallback, data: ?*anyopaque) callconv(.c) c_int {
    const linux = std.os.linux;

    const at_phdr = linux.getauxval(elf.AT_PHDR);
    const at_phnum = linux.getauxval(elf.AT_PHNUM);
    const at_phent = linux.getauxval(elf.AT_PHENT);

    if (at_phdr == 0 or at_phnum == 0 or at_phent == 0) return 0;

    var base: usize = 0;
    var tls_phdr: ?*const elf.ElfN.Phdr = null;
    const dynamic = get_DYNAMIC();

    var i: usize = 0;
    while (i < at_phnum) : (i += 1) {
        const phdr: *const elf.ElfN.Phdr = @ptrFromInt(at_phdr + i * at_phent);
        if (phdr.type == .PHDR)
            base = at_phdr -% phdr.vaddr;
        if (phdr.type == .DYNAMIC and dynamic != null)
            base = @intFromPtr(dynamic.?) -% phdr.vaddr;
        if (phdr.type == .TLS)
            tls_phdr = phdr;
    }

    const tls_arg = [2]usize{ 1, 0 };

    var info = DlPhdrInfo{
        .addr = base,
        .name = "/proc/self/exe",
        .phdr = @ptrFromInt(at_phdr),
        .phnum = @intCast(at_phnum),
        .adds = 0,
        .subs = 0,
        .tls_modid = if (tls_phdr != null) 1 else 0,
        .tls_data = if (tls_phdr != null) __tls_get_addr(&tls_arg) else null,
    };

    return callback(&info, @sizeOf(DlPhdrInfo), data);
}

// ============================================================
// ARM exception index table lookup (replaces musl/src/ldso/arm/find_exidx.c)
//
// Called by the C++ runtime to find exception handling tables.
// Uses dl_iterate_phdr to search loaded program headers.
// ============================================================

const PT_ARM_EXIDX: elf.Word = 0x70000001;

const FindExidxData = struct {
    pc: usize,
    exidx_start: usize,
    exidx_len: c_int,
};

fn find_exidx_callback(info_ptr: *DlPhdrInfo, size: usize, ptr: ?*anyopaque) callconv(.c) c_int {
    _ = size;
    const fdata: *FindExidxData = @ptrCast(@alignCast(ptr));
    var exidx_start: usize = 0;
    var exidx_len: c_int = 0;
    var match: bool = false;

    var n: usize = info_ptr.phnum;
    var phdr_p: [*]const elf.ElfN.Phdr = info_ptr.phdr;
    while (n > 0) : ({
        n -= 1;
        phdr_p += 1;
    }) {
        const phdr = phdr_p[0];
        const addr = info_ptr.addr +% phdr.vaddr;
        if (phdr.type == .LOAD) {
            if (fdata.pc >= addr and fdata.pc < addr +% phdr.memsz)
                match = true;
        }
        if (@intFromEnum(phdr.type) == PT_ARM_EXIDX) {
            exidx_start = addr;
            exidx_len = @intCast(phdr.memsz);
        }
    }

    fdata.exidx_start = exidx_start;
    fdata.exidx_len = exidx_len;
    return if (match) @as(c_int, 1) else @as(c_int, 0);
}

fn gnu_Unwind_Find_exidx(pc: usize, pcount: *c_int) callconv(.c) usize {
    var fdata = FindExidxData{
        .pc = pc,
        .exidx_start = 0,
        .exidx_len = 0,
    };
    if (dl_iterate_phdr_impl(find_exidx_callback, @ptrCast(&fdata)) <= 0)
        return 0;
    pcount.* = @divTrunc(fdata.exidx_len, 8);
    return fdata.exidx_start;
}
