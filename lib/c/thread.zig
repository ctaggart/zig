const builtin = @import("builtin");
const std = @import("std");
const symbol = @import("../c.zig").symbol;

const E = std.os.linux.E;

comptime {
    if (builtin.target.isMuslLibC()) {
        // Destroy functions (all return 0, releasing no resources)
        symbol(&pthread_attr_destroy, "pthread_attr_destroy");
        symbol(&pthread_mutexattr_destroy, "pthread_mutexattr_destroy");
        symbol(&pthread_condattr_destroy, "pthread_condattr_destroy");
        symbol(&pthread_rwlockattr_destroy, "pthread_rwlockattr_destroy");
        symbol(&pthread_barrierattr_destroy, "pthread_barrierattr_destroy");
        symbol(&pthread_spin_destroy, "pthread_spin_destroy");
        symbol(&pthread_rwlock_destroy, "pthread_rwlock_destroy");
        symbol(&sem_destroy, "sem_destroy");

        // Concurrency stubs (no-ops on Linux, which always uses 1:1 threading)
        symbol(&pthread_getconcurrency, "pthread_getconcurrency");
        symbol(&pthread_setconcurrency, "pthread_setconcurrency");

        // Priority ceiling not supported by musl
        symbol(&pthread_mutex_getprioceiling, "pthread_mutex_getprioceiling");

        // C11 thread destroy stubs (no-ops for private objects)
        symbol(&cnd_destroy, "cnd_destroy");
        symbol(&mtx_destroy, "mtx_destroy");

        // Thread comparison
        symbol(&pthread_equal, "pthread_equal");
        symbol(&pthread_equal, "thrd_equal");

        // Attribute init functions (zero-initialize)
        symbol(&pthread_mutexattr_init, "pthread_mutexattr_init");
        symbol(&pthread_condattr_init, "pthread_condattr_init");
        symbol(&pthread_rwlockattr_init, "pthread_rwlockattr_init");
        symbol(&pthread_barrierattr_init, "pthread_barrierattr_init");
        symbol(&pthread_spin_init, "pthread_spin_init");

        // Attribute set functions
        symbol(&pthread_mutexattr_settype, "pthread_mutexattr_settype");
        symbol(&pthread_mutexattr_setpshared, "pthread_mutexattr_setpshared");
        symbol(&pthread_condattr_setclock, "pthread_condattr_setclock");
        symbol(&pthread_condattr_setpshared, "pthread_condattr_setpshared");
        symbol(&pthread_rwlockattr_setpshared, "pthread_rwlockattr_setpshared");
        symbol(&pthread_barrierattr_setpshared, "pthread_barrierattr_setpshared");
        symbol(&pthread_attr_setscope, "pthread_attr_setscope");
    }
}

// All pthread/semaphore destroy functions return 0 because musl's
// implementations hold no dynamically-allocated resources.

fn pthread_attr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_mutexattr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_condattr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_rwlockattr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_barrierattr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_spin_destroy(s: ?*anyopaque) callconv(.c) c_int {
    _ = s;
    return 0;
}

fn pthread_rwlock_destroy(rw: ?*anyopaque) callconv(.c) c_int {
    _ = rw;
    return 0;
}

fn sem_destroy(sem: ?*anyopaque) callconv(.c) c_int {
    _ = sem;
    return 0;
}

// Linux always uses 1:1 threading; concurrency hints are no-ops.

fn pthread_getconcurrency() callconv(.c) c_int {
    return 0;
}

fn pthread_setconcurrency(val: c_int) callconv(.c) c_int {
    if (val < 0) return eint(.INVAL);
    if (val > 0) return eint(.AGAIN);
    return 0;
}

// Priority ceiling is not supported by musl.

fn pthread_mutex_getprioceiling(m: ?*const anyopaque, ceiling: ?*c_int) callconv(.c) c_int {
    _ = m;
    _ = ceiling;
    return eint(.INVAL);
}

// C11 thread destroy stubs.

fn cnd_destroy(c: ?*anyopaque) callconv(.c) void {
    _ = c;
}

fn mtx_destroy(mtx: ?*anyopaque) callconv(.c) void {
    _ = mtx;
}

// Thread identity comparison.

fn pthread_equal(a: std.c.pthread_t, b: std.c.pthread_t) callconv(.c) c_int {
    return @intCast(@intFromBool(a == b));
}

/// Convert a Linux errno enum value to a positive c_int for direct return
/// from POSIX thread functions (which return error numbers, not -1).
fn eint(e: E) c_int {
    return @intCast(@intFromEnum(e));
}

// --- Musl internal type definitions ---
// These match the musl libc type layouts exactly.

/// `typedef struct { unsigned __attr; } pthread_mutexattr_t;`
const pthread_mutexattr_t = extern struct { __attr: c_uint = 0 };

/// `typedef struct { unsigned __attr; } pthread_condattr_t;`
const pthread_condattr_t = extern struct { __attr: c_uint = 0 };

/// `typedef struct { unsigned __attr; } pthread_barrierattr_t;`
const pthread_barrierattr_t = extern struct { __attr: c_uint = 0 };

/// `typedef struct { unsigned __attr[2]; } pthread_rwlockattr_t;`
const pthread_rwlockattr_t = extern struct { __attr: [2]c_uint = .{ 0, 0 } };

// --- Attribute init functions ---

fn pthread_mutexattr_init(a: *pthread_mutexattr_t) callconv(.c) c_int {
    a.* = .{};
    return 0;
}

fn pthread_condattr_init(a: *pthread_condattr_t) callconv(.c) c_int {
    a.* = .{};
    return 0;
}

fn pthread_rwlockattr_init(a: *pthread_rwlockattr_t) callconv(.c) c_int {
    a.* = .{};
    return 0;
}

fn pthread_barrierattr_init(a: *pthread_barrierattr_t) callconv(.c) c_int {
    a.* = .{};
    return 0;
}

fn pthread_spin_init(s: *c_int, shared: c_int) callconv(.c) c_int {
    _ = shared;
    s.* = 0;
    return 0;
}

// --- Attribute set functions ---

fn pthread_mutexattr_settype(a: *pthread_mutexattr_t, @"type": c_int) callconv(.c) c_int {
    const t: c_uint = @bitCast(@"type");
    if (t > 2) return eint(.INVAL);
    a.__attr = (a.__attr & ~@as(c_uint, 3)) | t;
    return 0;
}

fn pthread_mutexattr_setpshared(a: *pthread_mutexattr_t, pshared: c_int) callconv(.c) c_int {
    const ps: c_uint = @bitCast(pshared);
    if (ps > 1) return eint(.INVAL);
    a.__attr &= ~@as(c_uint, 128);
    a.__attr |= ps << 7;
    return 0;
}

fn pthread_condattr_setclock(a: *pthread_condattr_t, clk: c_int) callconv(.c) c_int {
    if (clk < 0) return eint(.INVAL);
    const clk_u: c_uint = @intCast(clk);
    if (clk_u -% 2 < 2) return eint(.INVAL);
    a.__attr &= 0x80000000;
    a.__attr |= clk_u;
    return 0;
}

fn pthread_condattr_setpshared(a: *pthread_condattr_t, pshared: c_int) callconv(.c) c_int {
    const ps: c_uint = @bitCast(pshared);
    if (ps > 1) return eint(.INVAL);
    a.__attr &= 0x7fffffff;
    a.__attr |= ps << 31;
    return 0;
}

fn pthread_rwlockattr_setpshared(a: *pthread_rwlockattr_t, pshared: c_int) callconv(.c) c_int {
    const ps: c_uint = @bitCast(pshared);
    if (ps > 1) return eint(.INVAL);
    a.__attr[0] = ps;
    return 0;
}

fn pthread_barrierattr_setpshared(a: *pthread_barrierattr_t, pshared: c_int) callconv(.c) c_int {
    const ps: c_uint = @bitCast(pshared);
    if (ps > 1) return eint(.INVAL);
    a.__attr = if (pshared != 0) 0x80000000 else 0;
    return 0;
}

fn pthread_attr_setscope(a: ?*anyopaque, scope: c_int) callconv(.c) c_int {
    _ = a;
    return switch (scope) {
        0 => 0, // PTHREAD_SCOPE_SYSTEM
        1 => eint(.OPNOTSUPP), // PTHREAD_SCOPE_PROCESS
        else => eint(.INVAL),
    };
}
