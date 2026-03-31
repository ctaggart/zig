const builtin = @import("builtin");
const std = @import("std");
const symbol = @import("../c.zig").symbol;

const linux = std.os.linux;
const E = linux.E;
const arch = builtin.target.cpu.arch;

comptime {
    if (builtin.target.isMuslLibC()) {
        if (builtin.link_libc) {
            // C11 <threads.h> API
            symbol(&thrd_create_fn, "thrd_create");
            symbol(&thrd_exit_fn, "thrd_exit");
            symbol(&thrd_join_fn, "thrd_join");
            symbol(&thrd_sleep_fn, "thrd_sleep");

            // POSIX thread functions
            symbol(&pthread_getcpuclockid_fn, "pthread_getcpuclockid");
            symbol(&pthread_kill_fn, "pthread_kill");
            symbol(&pthread_setschedprio_fn, "pthread_setschedprio");
            symbol(&pthread_sigmask_fn, "pthread_sigmask");
        }
    }
}

// --- Musl struct pthread field offsets ---
// Computed from the musl struct pthread layout in pthread_impl.h.

const tls_above_tp = switch (arch) {
    .aarch64, .aarch64_be, .arm, .armeb, .thumb, .thumbeb,
    .riscv64, .riscv32, .mips, .mipsel, .mips64, .mips64el,
    .powerpc, .powerpcle, .powerpc64, .powerpc64le,
    .loongarch64, .m68k => true,
    else => false,
};

const ptr_size = @sizeOf(usize);
const part1_size: usize = if (tls_above_tp) 4 * ptr_size else 6 * ptr_size;
const map_base_off: usize = if (ptr_size == 8) 24 else 20;

const off_tid = part1_size;
const off_killlock = part1_size + map_base_off + 11 * ptr_size + 8 + ptr_size;

// --- Constants ---

const CLOCK_REALTIME: c_int = 0;
const thrd_success: c_int = 0;
const thrd_error: c_int = 2;
const thrd_nomem: c_int = 3;
const _NSIG: c_uint = 129;

fn eint(e: E) c_int {
    return @intCast(@intFromEnum(e));
}

// --- C11 <threads.h> API (thrd_create.c, thrd_exit.c, thrd_join.c, thrd_sleep.c) ---

fn thrd_create_fn(thr: *anyopaque, func: ?*const anyopaque, arg: ?*anyopaque) callconv(.c) c_int {
    // __ATTRP_C11_THREAD sentinel: (void*)(uintptr_t)-1
    const ATTRP_C11_THREAD: ?*const anyopaque = @ptrFromInt(std.math.maxInt(usize));
    const __pthread_create = @extern(*const fn (*anyopaque, ?*const anyopaque, ?*const anyopaque, ?*anyopaque) callconv(.c) c_int, .{ .name = "__pthread_create" });
    const ret = __pthread_create(thr, ATTRP_C11_THREAD, func, arg);
    if (ret == 0) return thrd_success;
    if (ret == eint(.AGAIN)) return thrd_nomem;
    return thrd_error;
}

fn thrd_exit_fn(result: c_int) callconv(.c) noreturn {
    const __pthread_exit = @extern(*const fn (?*anyopaque) callconv(.c) noreturn, .{ .name = "__pthread_exit" });
    // (void*)(intptr_t)result — sign-extend int to pointer
    __pthread_exit(@ptrFromInt(@as(usize, @bitCast(@as(isize, result)))));
}

fn thrd_join_fn(t: std.c.pthread_t, res: ?*c_int) callconv(.c) c_int {
    var pthread_res: usize = 0;
    const __pthread_join = @extern(*const fn (std.c.pthread_t, *usize) callconv(.c) c_int, .{ .name = "__pthread_join" });
    _ = __pthread_join(t, &pthread_res);
    if (res) |r| {
        // (int)(intptr_t)pthread_res — truncate pointer to int
        r.* = @as(c_int, @truncate(@as(isize, @bitCast(pthread_res))));
    }
    return thrd_success;
}

fn thrd_sleep_fn(req: ?*const anyopaque, rem: ?*anyopaque) callconv(.c) c_int {
    const __clock_nanosleep = @extern(*const fn (c_int, c_int, ?*const anyopaque, ?*anyopaque) callconv(.c) c_int, .{ .name = "__clock_nanosleep" });
    const ret: c_int = 0 -% __clock_nanosleep(CLOCK_REALTIME, 0, req, rem);
    if (ret == 0) return 0;
    if (ret == 0 -% eint(.INTR)) return -1;
    return -2;
}

// --- POSIX thread functions ---

// pthread_getcpuclockid.c
fn pthread_getcpuclockid_fn(t: std.c.pthread_t, clockid: *c_int) callconv(.c) c_int {
    const tid: c_int = (@as(*const c_int, @ptrFromInt(@intFromPtr(t) + off_tid))).*;
    // (-t->tid - 1) * 8U + 6
    const neg_tid_m1: c_uint = @bitCast((0 -% tid) -% @as(c_int, 1));
    clockid.* = @bitCast(neg_tid_m1 *% 8 +% 6);
    return 0;
}

// pthread_kill.c
fn pthread_kill_fn(t: std.c.pthread_t, sig: c_int) callconv(.c) c_int {
    const __block_all_sigs = @extern(*const fn (*anyopaque) callconv(.c) void, .{ .name = "__block_all_sigs" });
    const __restore_sigs = @extern(*const fn (*anyopaque) callconv(.c) void, .{ .name = "__restore_sigs" });
    const __lock = @extern(*const fn (*c_int) callconv(.c) void, .{ .name = "__lock" });
    const __unlock = @extern(*const fn (*c_int) callconv(.c) void, .{ .name = "__unlock" });

    var set: [128]u8 = undefined;
    __block_all_sigs(@ptrCast(&set));

    const t_addr = @intFromPtr(t);
    const killlock: *c_int = @ptrFromInt(t_addr + off_killlock);
    __lock(killlock);

    const tid: c_int = (@as(*const c_int, @ptrFromInt(t_addr + off_tid))).*;
    const r: c_int = if (tid != 0) blk: {
        const rc: isize = @bitCast(linux.syscall2(.tkill, @as(usize, @intCast(tid)), @as(usize, @bitCast(@as(isize, sig)))));
        break :blk @as(c_int, @intCast(-rc));
    } else if (@as(c_uint, @bitCast(sig)) >= _NSIG) eint(.INVAL) else 0;

    __unlock(killlock);
    __restore_sigs(@ptrCast(&set));
    return r;
}

// pthread_setschedprio.c
fn pthread_setschedprio_fn(t: std.c.pthread_t, prio: c_int) callconv(.c) c_int {
    const __block_app_sigs = @extern(*const fn (*anyopaque) callconv(.c) void, .{ .name = "__block_app_sigs" });
    const __restore_sigs = @extern(*const fn (*anyopaque) callconv(.c) void, .{ .name = "__restore_sigs" });
    const __lock = @extern(*const fn (*c_int) callconv(.c) void, .{ .name = "__lock" });
    const __unlock = @extern(*const fn (*c_int) callconv(.c) void, .{ .name = "__unlock" });

    var set: [128]u8 = undefined;
    __block_app_sigs(@ptrCast(&set));

    const t_addr = @intFromPtr(t);
    const killlock: *c_int = @ptrFromInt(t_addr + off_killlock);
    __lock(killlock);

    const tid: c_int = (@as(*const c_int, @ptrFromInt(t_addr + off_tid))).*;
    var prio_val = prio;
    const r: c_int = if (tid == 0)
        eint(.SRCH)
    else blk: {
        const rc: isize = @bitCast(linux.syscall2(.sched_setparam, @as(usize, @intCast(tid)), @intFromPtr(&prio_val)));
        break :blk @as(c_int, @intCast(-rc));
    };

    __unlock(killlock);
    __restore_sigs(@ptrCast(&set));
    return r;
}

// pthread_sigmask.c
fn pthread_sigmask_fn(how: c_int, set: ?*const anyopaque, old: ?*anyopaque) callconv(.c) c_int {
    if (set != null and @as(c_uint, @bitCast(how)) > 2) return eint(.INVAL);
    const sig_set_size: usize = 128 / 8;
    const set_addr: usize = if (set) |s| @intFromPtr(s) else 0;
    const old_addr: usize = if (old) |o| @intFromPtr(o) else 0;
    const ret: c_int = blk: {
        const rc: isize = @bitCast(linux.syscall4(.rt_sigprocmask, @as(usize, @bitCast(@as(isize, how))), set_addr, old_addr, sig_set_size));
        break :blk @as(c_int, @intCast(-rc));
    };
    if (ret == 0) {
        if (old) |o| {
            // Clear internal signal bits (SIGTIMER=32, SIGCANCEL=33, SIGSYNCCALL=34)
            if (@sizeOf(c_ulong) == 8) {
                const p: *u64 = @ptrCast(@alignCast(o));
                p.* &= ~@as(u64, 0x380000000);
            } else {
                const p: [*]u32 = @ptrCast(@alignCast(o));
                p[0] &= ~@as(u32, 0x80000000);
                p[1] &= ~@as(u32, 0x3);
            }
        }
    }
    return ret;
}
