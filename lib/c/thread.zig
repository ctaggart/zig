const builtin = @import("builtin");
const std = @import("std");
const symbol = @import("../c.zig").symbol;

const linux = std.os.linux;
const E = linux.E;
const arch = builtin.target.cpu.arch;

comptime {
    if (builtin.target.isMuslLibC()) {
        if (builtin.link_libc) {
            // Cleanup handler management
            symbol(&do_cleanup_push_default, "__do_cleanup_push");
            symbol(&do_cleanup_pop_default, "__do_cleanup_pop");
            symbol(&_pthread_cleanup_push_fn, "_pthread_cleanup_push");
            symbol(&_pthread_cleanup_pop_fn, "_pthread_cleanup_pop");

            // Scheduling parameters
            symbol(&pthread_getschedparam_fn, "pthread_getschedparam");
            symbol(&pthread_setschedparam_fn, "pthread_setschedparam");

            // Thread name (GNU extensions)
            symbol(&pthread_getname_np_fn, "pthread_getname_np");
            symbol(&pthread_setname_np_fn, "pthread_setname_np");

            // Timed semaphore wait
            symbol(&sem_timedwait_fn, "sem_timedwait");
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

const SEM_VALUE_MAX: c_int = 0x7fffffff;
const CLOCK_REALTIME: c_int = 0;

const sem_val_len = 4 * @sizeOf(c_long) / @sizeOf(c_int);
const sem_impl = extern struct {
    __val: [sem_val_len]c_int,
};

const sched_param = extern struct {
    sched_priority: c_int,
};

/// Musl's struct __ptcb from pthread.h.
const PtCb = extern struct {
    f: ?*const fn (?*anyopaque) callconv(.c) void,
    x: ?*anyopaque,
    next: ?*PtCb,
};

fn eint(e: E) c_int {
    return @intCast(@intFromEnum(e));
}

// --- Cleanup handler management (pthread_cleanup_push.c) ---

fn do_cleanup_push_default(cb: *PtCb) callconv(.c) void {
    _ = cb;
}

fn do_cleanup_pop_default(cb: *PtCb) callconv(.c) void {
    _ = cb;
}

fn _pthread_cleanup_push_fn(cb: *PtCb, f: *const fn (?*anyopaque) callconv(.c) void, x: ?*anyopaque) callconv(.c) void {
    cb.f = f;
    cb.x = x;
    const __do_cleanup_push = @extern(*const fn (*PtCb) callconv(.c) void, .{ .name = "__do_cleanup_push" });
    __do_cleanup_push(cb);
}

fn _pthread_cleanup_pop_fn(cb: *PtCb, run: c_int) callconv(.c) void {
    const __do_cleanup_pop = @extern(*const fn (*PtCb) callconv(.c) void, .{ .name = "__do_cleanup_pop" });
    __do_cleanup_pop(cb);
    if (run != 0) {
        if (cb.f) |f| f(cb.x);
    }
}

// --- Scheduling parameters (pthread_getschedparam.c / pthread_setschedparam.c) ---

fn pthread_getschedparam_fn(t: std.c.pthread_t, policy: *c_int, param: *sched_param) callconv(.c) c_int {
    const __block_app_sigs = @extern(*const fn (*anyopaque) callconv(.c) void, .{ .name = "__block_app_sigs" });
    const __restore_sigs = @extern(*const fn (*anyopaque) callconv(.c) void, .{ .name = "__restore_sigs" });
    const __lock = @extern(*const fn (*c_int) callconv(.c) void, .{ .name = "__lock" });
    const __unlock = @extern(*const fn (*c_int) callconv(.c) void, .{ .name = "__unlock" });

    var r: c_int = undefined;
    var set: [128]u8 = undefined;
    __block_app_sigs(@ptrCast(&set));

    const t_addr = @intFromPtr(t);
    const killlock: *c_int = @ptrFromInt(t_addr + off_killlock);
    __lock(killlock);

    const tid: c_int = (@as(*const c_int, @ptrFromInt(t_addr + off_tid))).*;
    if (tid == 0) {
        r = eint(.SRCH);
    } else {
        const rc: isize = @bitCast(linux.syscall2(.sched_getparam, @as(usize, @intCast(tid)), @intFromPtr(param)));
        r = @intCast(-rc);
        if (r == 0) {
            const sched_rc: isize = @bitCast(linux.syscall1(.sched_getscheduler, @as(usize, @intCast(tid))));
            policy.* = @intCast(sched_rc);
        }
    }

    __unlock(killlock);
    __restore_sigs(@ptrCast(&set));
    return r;
}

fn pthread_setschedparam_fn(t: std.c.pthread_t, policy: c_int, param: *const sched_param) callconv(.c) c_int {
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
    const r: c_int = if (tid == 0)
        eint(.SRCH)
    else blk: {
        const rc: isize = @bitCast(linux.syscall3(.sched_setscheduler, @as(usize, @intCast(tid)), @as(usize, @bitCast(@as(isize, policy))), @intFromPtr(param)));
        break :blk @intCast(-rc);
    };

    __unlock(killlock);
    __restore_sigs(@ptrCast(&set));
    return r;
}

// --- Thread name (pthread_getname_np.c / pthread_setname_np.c) ---

const PR_SET_NAME: usize = 15;
const PR_GET_NAME: usize = 16;
const AT_FDCWD: usize = @bitCast(@as(isize, -100));
const O_CLOEXEC: usize = 0o2000000;

fn pthread_getname_np_fn(thread: std.c.pthread_t, name: [*]u8, len: usize) callconv(.c) c_int {
    if (len < 16) return eint(.RANGE);

    const pthread_self_ext = @extern(*const fn () callconv(.c) std.c.pthread_t, .{ .name = "pthread_self" });
    if (thread == pthread_self_ext()) {
        const rc: isize = @bitCast(linux.syscall5(.prctl, PR_GET_NAME, @intFromPtr(name), 0, 0, 0));
        return if (rc < 0) @intCast(-rc) else 0;
    }

    const tid: c_int = (@as(*const c_int, @ptrFromInt(@intFromPtr(thread) + off_tid))).*;
    var path_buf: [40]u8 = undefined;
    const path = std.fmt.bufPrintZ(&path_buf, "/proc/self/task/{d}/comm", .{tid}) catch unreachable;

    const pthread_setcancelstate_ext = @extern(*const fn (c_int, ?*c_int) callconv(.c) c_int, .{ .name = "pthread_setcancelstate" });
    var cs: c_int = undefined;
    _ = pthread_setcancelstate_ext(1, &cs); // PTHREAD_CANCEL_DISABLE

    var status: c_int = 0;
    const fd_raw: isize = @bitCast(linux.syscall4(.openat, AT_FDCWD, @intFromPtr(path.ptr), O_CLOEXEC, 0));
    if (fd_raw < 0) {
        status = @intCast(-fd_raw);
    } else {
        const fd: usize = @intCast(fd_raw);
        const n_raw: isize = @bitCast(linux.syscall3(.read, fd, @intFromPtr(name), len));
        if (n_raw < 0) {
            status = @intCast(-n_raw);
        } else {
            // Remove trailing newline
            name[@as(usize, @intCast(n_raw)) - 1] = 0;
        }
        _ = linux.syscall1(.close, fd);
    }

    _ = pthread_setcancelstate_ext(cs, null);
    return status;
}

fn pthread_setname_np_fn(thread: std.c.pthread_t, name: [*:0]const u8) callconv(.c) c_int {
    // strnlen(name, 16)
    var name_len: usize = 0;
    while (name_len < 16 and name[name_len] != 0) : (name_len += 1) {}
    if (name_len > 15) return eint(.RANGE);

    const pthread_self_ext = @extern(*const fn () callconv(.c) std.c.pthread_t, .{ .name = "pthread_self" });
    if (thread == pthread_self_ext()) {
        const rc: isize = @bitCast(linux.syscall5(.prctl, PR_SET_NAME, @intFromPtr(name), 0, 0, 0));
        return if (rc < 0) @intCast(-rc) else 0;
    }

    const tid: c_int = (@as(*const c_int, @ptrFromInt(@intFromPtr(thread) + off_tid))).*;
    var path_buf: [40]u8 = undefined;
    const path = std.fmt.bufPrintZ(&path_buf, "/proc/self/task/{d}/comm", .{tid}) catch unreachable;

    const pthread_setcancelstate_ext = @extern(*const fn (c_int, ?*c_int) callconv(.c) c_int, .{ .name = "pthread_setcancelstate" });
    var cs: c_int = undefined;
    _ = pthread_setcancelstate_ext(1, &cs); // PTHREAD_CANCEL_DISABLE

    var status: c_int = 0;
    const fd_raw: isize = @bitCast(linux.syscall4(.openat, AT_FDCWD, @intFromPtr(path.ptr), O_CLOEXEC | 1, 0)); // O_WRONLY=1
    if (fd_raw < 0) {
        status = @intCast(-fd_raw);
    } else {
        const fd: usize = @intCast(fd_raw);
        const n_raw: isize = @bitCast(linux.syscall3(.write, fd, @intFromPtr(name), name_len));
        if (n_raw < 0) {
            status = @intCast(-n_raw);
        }
        _ = linux.syscall1(.close, fd);
    }

    _ = pthread_setcancelstate_ext(cs, null);
    return status;
}

// --- Timed semaphore wait (sem_timedwait.c) ---

fn sem_timedwait_cleanup(p: ?*anyopaque) callconv(.c) void {
    const ptr: *c_int = @ptrCast(@alignCast(p));
    _ = @atomicRmw(c_int, ptr, .Sub, 1, .seq_cst);
}

fn sem_timedwait_fn(sem: *sem_impl, at: ?*const anyopaque) callconv(.c) c_int {
    const pthread_testcancel_ext = @extern(*const fn () callconv(.c) void, .{ .name = "pthread_testcancel" });
    const sem_trywait_ext = @extern(*const fn (*sem_impl) callconv(.c) c_int, .{ .name = "sem_trywait" });
    const __timedwait_cp = @extern(*const fn (*c_int, c_int, c_int, ?*const anyopaque, c_int) callconv(.c) c_int, .{ .name = "__timedwait_cp" });

    pthread_testcancel_ext();
    if (sem_trywait_ext(sem) == 0) return 0;

    // Spin briefly before blocking
    var spins: c_int = 100;
    while (spins > 0) : (spins -= 1) {
        if ((@atomicLoad(c_int, &sem.__val[0], .monotonic) & SEM_VALUE_MAX) != 0) break;
        if (@atomicLoad(c_int, &sem.__val[1], .monotonic) != 0) break;
        std.atomic.spinLoopHint();
    }

    while (sem_trywait_ext(sem) != 0) {
        const priv = sem.__val[2];
        _ = @atomicRmw(c_int, &sem.__val[1], .Add, 1, .seq_cst);
        const WAITER_FLAG: c_int = @bitCast(@as(c_uint, 0x80000000));
        _ = @cmpxchgStrong(c_int, &sem.__val[0], 0, WAITER_FLAG, .seq_cst, .seq_cst);

        var cb: PtCb = undefined;
        _pthread_cleanup_push_fn(&cb, sem_timedwait_cleanup, @ptrCast(&sem.__val[1]));
        const r = __timedwait_cp(&sem.__val[0], WAITER_FLAG, CLOCK_REALTIME, at, priv);
        _pthread_cleanup_pop_fn(&cb, 1);

        if (r != 0) {
            std.c._errno().* = r;
            return -1;
        }
    }
    return 0;
}
