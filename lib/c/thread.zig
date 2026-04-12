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
