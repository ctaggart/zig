const builtin = @import("builtin");
const std = @import("std");
const symbol = @import("../c.zig").symbol;

const linux = std.os.linux;
const E = linux.E;

comptime {
    if (builtin.target.isMuslLibC()) {
        if (builtin.link_libc) {
            // Futex wait primitive
            symbol(&__wait_fn, "__wait");

            // VM lock (used by mmap/munmap/mprotect to synchronize with thread creation)
            symbol(&vm_wait_fn, "__vm_wait");
            symbol(&vm_lock_fn, "__vm_lock");
            symbol(&vm_unlock_fn, "__vm_unlock");
        }
    }
}

// --- Futex helpers (static inline in musl) ---

const FUTEX_WAIT: usize = 0;
const FUTEX_WAKE: usize = 1;
const FUTEX_PRIVATE: usize = 128;

fn wake(addr: *anyopaque, cnt: c_int, priv_val: c_int) void {
    const p: usize = if (priv_val != 0) FUTEX_PRIVATE else 0;
    const n: usize = if (cnt < 0) @as(usize, @intCast(std.math.maxInt(c_int))) else @as(usize, @intCast(cnt));
    _ = linux.syscall3(.futex, @intFromPtr(addr), FUTEX_WAKE | p, n);
}

// --- __wait (__wait.c) ---

fn __wait_fn(addr: *anyopaque, waiters_opt: ?*anyopaque, val: c_int, priv_arg: c_int) callconv(.c) void {
    const priv: usize = if (priv_arg != 0) FUTEX_PRIVATE else 0;
    const addr_ptr: *c_int = @ptrCast(@alignCast(addr));
    const waiters_ptr: ?*c_int = if (waiters_opt) |w| @as(*c_int, @ptrCast(@alignCast(w))) else null;

    // Spin phase: spin briefly before blocking
    var spins: c_int = 100;
    while (spins > 0) : (spins -= 1) {
        if (waiters_ptr) |w| {
            if (@atomicLoad(c_int, w, .monotonic) != 0) break;
        }
        if (@atomicLoad(c_int, addr_ptr, .monotonic) == val) {
            std.atomic.spinLoopHint();
        } else {
            return;
        }
    }

    // Register as waiter
    if (waiters_ptr) |w| {
        _ = @atomicRmw(c_int, w, .Add, 1, .seq_cst);
    }

    // Futex wait loop
    while (@atomicLoad(c_int, addr_ptr, .monotonic) == val) {
        const val_u: usize = @as(usize, @bitCast(@as(isize, val)));
        const rc: isize = @bitCast(linux.syscall4(.futex, @intFromPtr(addr), FUTEX_WAIT | priv, val_u, 0));
        // Fall back to shared futex if private not supported
        if (rc == -@as(isize, @intCast(@intFromEnum(E.NOSYS)))) {
            _ = linux.syscall4(.futex, @intFromPtr(addr), FUTEX_WAIT, val_u, 0);
        }
    }

    // Deregister as waiter
    if (waiters_ptr) |w| {
        _ = @atomicRmw(c_int, w, .Add, -1, .seq_cst);
    }
}

// --- vmlock (vmlock.c) ---
// Coordinates VM operations (mmap/munmap) with thread creation.
// vmlock[0] = lock count, vmlock[1] = waiter count.

var vmlock: [2]c_int = .{ 0, 0 };
comptime {
    @export(&vmlock, .{ .name = "__vmlock_lockptr" });
}

fn vm_wait_fn() callconv(.c) void {
    while (true) {
        const tmp = @atomicLoad(c_int, &vmlock[0], .monotonic);
        if (tmp == 0) break;
        __wait_fn(@ptrCast(&vmlock[0]), @ptrCast(&vmlock[1]), tmp, 1);
    }
}

fn vm_lock_fn() callconv(.c) void {
    _ = @atomicRmw(c_int, &vmlock[0], .Add, 1, .seq_cst);
}

fn vm_unlock_fn() callconv(.c) void {
    if (@atomicRmw(c_int, &vmlock[0], .Add, -1, .seq_cst) == 1 and
        @atomicLoad(c_int, &vmlock[1], .monotonic) != 0)
    {
        wake(@ptrCast(&vmlock[0]), -1, 1);
    }
}
