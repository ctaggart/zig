const builtin = @import("builtin");
const std = @import("std");
const symbol = @import("../c.zig").symbol;

const E = std.os.linux.E;
const arch = builtin.target.cpu.arch;

comptime {
    if (builtin.target.isMuslLibC()) {
        // Thread identity
        symbol(&pthread_self_fn, "pthread_self");
        symbol(&pthread_self_fn, "thrd_current");

        // Thread-specific data
        symbol(&pthread_getspecific_fn, "pthread_getspecific");
        symbol(&pthread_getspecific_fn, "tss_get");
        symbol(&pthread_setspecific_fn, "pthread_setspecific");

        // Cancellation
        symbol(&pthread_setcancelstate_fn, "__pthread_setcancelstate");
        symbol(&pthread_setcancelstate_fn, "pthread_setcancelstate");
        symbol(&pthread_setcanceltype_fn, "pthread_setcanceltype");
        symbol(&pthread_testcancel_fn, "__pthread_testcancel");
        symbol(&pthread_testcancel_fn, "pthread_testcancel");

        // Semaphore operations
        symbol(&sem_trywait_fn, "sem_trywait");
        symbol(&sem_post_fn, "sem_post");

        // Functions that depend on other musl C symbols via @extern
        if (builtin.link_libc) {
            symbol(&pthread_detach_fn, "pthread_detach");
            symbol(&pthread_detach_fn, "thrd_detach");
            symbol(&sem_wait_fn, "sem_wait");
            symbol(&sem_unlink_fn, "sem_unlink");
        }
    }
}

// --- Musl struct pthread field offsets ---
// Computed from the musl struct pthread layout in pthread_impl.h.
// The layout varies by architecture based on TLS model and pointer size.

const tls_above_tp = switch (arch) {
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb,
    .riscv64, .riscv32, .mips, .mipsel, .mips64, .mips64el,
    .powerpc, .powerpcle, .powerpc64, .powerpc64le,
    .loongarch64, .m68k => true,
    else => false,
};

/// TP_OFFSET from musl per-arch pthread_arch.h (defaults to 0).
const tp_offset: usize = switch (arch) {
    .mips, .mipsel, .mips64, .mips64el,
    .powerpc, .powerpcle, .powerpc64, .powerpc64le,
    .m68k => 0x7000,
    else => 0,
};

const ptr_size = @sizeOf(usize);

/// Part 1 of struct pthread: ABI fields whose presence depends on TLS model.
/// Non-TLS_ABOVE_TP: self, dtv, prev, next, sysinfo, canary = 6 pointers.
/// TLS_ABOVE_TP: self, prev, next, sysinfo = 4 pointers.
const part1_size: usize = if (tls_above_tp) 4 * ptr_size else 6 * ptr_size;

/// Total sizeof(struct pthread): 200 on 64-bit, 112 on 32-bit.
const sizeof_pthread: usize = if (ptr_size == 8) 200 else 112;

/// Padding from Part 2 byte 19 to next pointer-aligned boundary.
const map_base_off: usize = if (ptr_size == 8) 24 else 20;

// Field offsets from struct pthread base.
const off_detach_state = part1_size + 8;
const off_canceldisable = part1_size + 16;
const off_cancelasync = part1_size + 17;
const off_tsd_flags = part1_size + 18;
const off_tsd = part1_size + map_base_off + 7 * ptr_size;

/// Musl detach state enum values from pthread_impl.h.
const DT_JOINABLE: c_int = 2;
const DT_DETACHED: c_int = 3;

const SEM_VALUE_MAX: c_int = 0x7fffffff;

const sem_val_len = 4 * @sizeOf(c_long) / @sizeOf(c_int);
const sem_impl = extern struct {
    __val: [sem_val_len]c_int,
};

/// Convert a Linux errno enum to a positive c_int for POSIX thread functions.
fn eint(e: E) c_int {
    return @intCast(@intFromEnum(e));
}

/// Read the architecture-specific thread pointer register.
fn get_tp() usize {
    return switch (arch) {
        .x86_64 => asm ("mov %%fs:0, %[ret]"
            : [ret] "=r" (-> usize),
        ),
        .x86 => asm ("movl %%gs:0, %[ret]"
            : [ret] "=r" (-> usize),
        ),
        .aarch64, .aarch64_be => asm ("mrs %[ret], tpidr_el0"
            : [ret] "=r" (-> usize),
        ),
        .arm, .armeb, .thumb, .thumbeb => asm ("mrc p15, 0, %[ret], c13, c0, 3"
            : [ret] "=r" (-> usize),
        ),
        .riscv64, .riscv32 => asm ("mv %[ret], tp"
            : [ret] "=r" (-> usize),
        ),
        .s390x => asm (
            \\ear  %[ret], %%a0
            \\sllg %[ret], %[ret], 32
            \\ear  %[ret], %%a1
            : [ret] "=r" (-> usize),
        ),
        .mips, .mipsel => asm (
            \\.set push
            \\.set mips32r2
            \\rdhwr %[ret], $29
            \\.set pop
            : [ret] "=r" (-> usize),
        ),
        .mips64, .mips64el => asm (
            \\rdhwr %[ret], $29
            : [ret] "=r" (-> usize),
        ),
        .powerpc, .powerpcle => asm ("mr %[ret], 2"
            : [ret] "=r" (-> usize),
        ),
        .powerpc64, .powerpc64le => asm ("mr %[ret], 13"
            : [ret] "=r" (-> usize),
        ),
        .loongarch64 => asm ("move %[ret], $tp"
            : [ret] "=r" (-> usize),
        ),
        .m68k => std.os.linux.syscall0(.get_thread_area),
        else => @compileError("unsupported architecture for __pthread_self"),
    };
}

/// Equivalent to musl's __pthread_self() macro: returns the struct pthread address.
fn pthread_self_ptr() usize {
    const tp = get_tp();
    return if (tls_above_tp) tp - sizeof_pthread - tp_offset else tp;
}

// --- Thread identity ---

fn pthread_self_fn() callconv(.c) std.c.pthread_t {
    return @ptrFromInt(pthread_self_ptr());
}

// --- Thread-specific data ---

fn pthread_getspecific_fn(k: c_uint) callconv(.c) ?*anyopaque {
    const self = pthread_self_ptr();
    const tsd: *[*]?*anyopaque = @ptrFromInt(self + off_tsd);
    return tsd.*[k];
}

fn pthread_setspecific_fn(k: c_uint, x: ?*const anyopaque) callconv(.c) c_int {
    const self = pthread_self_ptr();
    const tsd: *[*]?*anyopaque = @ptrFromInt(self + off_tsd);
    const val: ?*anyopaque = @constCast(x);
    if (tsd.*[k] != val) {
        tsd.*[k] = val;
        const flags: *u8 = @ptrFromInt(self + off_tsd_flags);
        // C bitfield tsd_used:1 — bit 0 on LE, bit 7 on BE
        const tsd_used_bit: u8 = if (arch.endian() == .big) 0x80 else 1;
        flags.* |= tsd_used_bit;
    }
    return 0;
}

// --- Cancellation ---

fn pthread_setcancelstate_fn(new: c_int, old: ?*c_int) callconv(.c) c_int {
    if (@as(c_uint, @bitCast(new)) > 2) return eint(.INVAL);
    const self = pthread_self_ptr();
    const cd: *u8 = @ptrFromInt(self + off_canceldisable);
    if (old) |o| o.* = cd.*;
    cd.* = @intCast(@as(c_uint, @bitCast(new)));
    return 0;
}

fn pthread_setcanceltype_fn(new: c_int, old: ?*c_int) callconv(.c) c_int {
    const self = pthread_self_ptr();
    if (@as(c_uint, @bitCast(new)) > 1) return eint(.INVAL);
    const ca: *u8 = @ptrFromInt(self + off_cancelasync);
    if (old) |o| o.* = ca.*;
    ca.* = @intCast(@as(c_uint, @bitCast(new)));
    if (new != 0) pthread_testcancel_fn();
    return 0;
}

fn pthread_testcancel_fn() callconv(.c) void {
    if (builtin.link_libc) {
        const __testcancel = @extern(*const fn () callconv(.c) void, .{ .name = "__testcancel" });
        __testcancel();
    }
}

// --- Thread detach ---

fn pthread_detach_fn(t: std.c.pthread_t) callconv(.c) c_int {
    const t_addr = @intFromPtr(t);
    const ds: *c_int = @ptrFromInt(t_addr + off_detach_state);
    if (@cmpxchgStrong(c_int, ds, DT_JOINABLE, DT_DETACHED, .seq_cst, .seq_cst) != null) {
        var cs: c_int = undefined;
        _ = pthread_setcancelstate_fn(1, &cs);
        const __pthread_join = @extern(*const fn (std.c.pthread_t, ?*?*anyopaque) callconv(.c) c_int, .{ .name = "__pthread_join" });
        _ = __pthread_join(t, null);
        _ = pthread_setcancelstate_fn(cs, null);
    }
    return 0;
}

// --- Semaphore operations ---

fn sem_trywait_fn(sem: *sem_impl) callconv(.c) c_int {
    while (true) {
        const val = @atomicLoad(c_int, &sem.__val[0], .monotonic);
        if ((val & SEM_VALUE_MAX) == 0) break;
        if (@cmpxchgStrong(c_int, &sem.__val[0], val, val - 1, .seq_cst, .seq_cst) == null) return 0;
    }
    std.c._errno().* = eint(.AGAIN);
    return -1;
}

fn sem_post_fn(sem: *sem_impl) callconv(.c) c_int {
    const priv = sem.__val[2];
    while (true) {
        const val = @atomicLoad(c_int, &sem.__val[0], .monotonic);
        const waiters = @atomicLoad(c_int, &sem.__val[1], .monotonic);
        if ((val & SEM_VALUE_MAX) == SEM_VALUE_MAX) {
            std.c._errno().* = eint(.OVERFLOW);
            return -1;
        }
        var new_val = val + 1;
        if (waiters <= 1) new_val &= SEM_VALUE_MAX;
        if (@cmpxchgStrong(c_int, &sem.__val[0], val, new_val, .seq_cst, .seq_cst) == null) {
            if (val < 0) futex_wake(&sem.__val[0], if (waiters > 1) @as(c_int, 1) else -1, priv);
            return 0;
        }
    }
}

fn sem_wait_fn(sem: *sem_impl) callconv(.c) c_int {
    const ext = @extern(*const fn (*sem_impl, ?*const anyopaque) callconv(.c) c_int, .{ .name = "sem_timedwait" });
    return ext(sem, null);
}

fn sem_unlink_fn(name: [*:0]const u8) callconv(.c) c_int {
    const shm_unlink = @extern(*const fn ([*:0]const u8) callconv(.c) c_int, .{ .name = "shm_unlink" });
    return shm_unlink(name);
}

// --- Futex helper ---

fn futex_wake(addr: *const c_int, cnt: c_int, priv: c_int) void {
    const FUTEX_WAKE: usize = 1;
    const FUTEX_PRIVATE: usize = 128;
    const p: usize = if (priv != 0) FUTEX_PRIVATE else 0;
    const max_int: c_int = std.math.maxInt(c_int);
    const c: usize = @intCast(if (cnt < 0) max_int else cnt);
    const rc: isize = @bitCast(std.os.linux.syscall4(.futex, @intFromPtr(addr), FUTEX_WAKE | p, c, 0));
    if (rc == -@as(isize, @intFromEnum(E.NOSYS))) {
        _ = std.os.linux.syscall4(.futex, @intFromPtr(addr), FUTEX_WAKE, c, 0);
    }
}
