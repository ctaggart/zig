//! WASI thread stubs for single-threaded WASI targets.
//! Minimal pthread implementations that return no-op/error codes or trap
//! when actual threading would be required.

const std = @import("std");
const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;
const wasi = std.os.wasi;

comptime {
    if (!builtin.target.isWasiLibC()) @compileError("wasi_thread_stub is only for WASI");
}

// musl pthread types represented as int arrays matching the union layout in
// pthread_impl.h: struct { union { int __i[N]; volatile int __vi[N]; ... } __u; }
const PthreadMutex = extern struct { __i: [if (@sizeOf(c_long) == 8) 10 else 6]c_int };
const PthreadRwlock = extern struct { __i: [if (@sizeOf(c_long) == 8) 14 else 8]c_int };
const PthreadBarrier = extern struct { __i: [if (@sizeOf(c_long) == 8) 8 else 5]c_int };
const PthreadAttr = extern struct {
    __u: extern union {
        __i: [if (@sizeOf(c_long) == 8) 14 else 9]c_int,
        __s: [if (@sizeOf(c_long) == 8) 7 else 9]c_ulong,
    },
};
const PthreadMutexAttr = extern struct { __attr: c_uint };
const PthreadCondAttr = extern struct { __attr: c_uint };
const PthreadBarrierAttr = extern struct { __attr: c_uint };
const PthreadRwlockAttr = extern struct { __attr: [2]c_uint };
const SchedParam = extern struct { sched_priority: c_int };
const CClockId = extern struct { id: wasi.clockid_t };

var __default_stacksize: c_uint = 131072;
var __default_guardsize: c_uint = 8192;

// musl pthread_attr_t fields from pthread_impl.h: _a_* macros.
const su = @sizeOf(usize) / @sizeOf(c_int);
const a_stacksize_idx = 0;
const a_guardsize_idx = 1;
const a_stackaddr_idx = 2;
const a_detach_idx = 3 * su;

// WASI errno values (from __errno_values.h)
const EAGAIN: c_int = 6;
const EBUSY: c_int = 10;
const EDEADLK: c_int = 16;
const EINVAL: c_int = 28;
const ENOTSUP: c_int = 58;
const EPERM: c_int = 63;
const ETIMEDOUT: c_int = 73;
const EINTR: c_int = 27;

const PTHREAD_MUTEX_RECURSIVE: c_int = 1;
const PTHREAD_BARRIER_SERIAL_THREAD: c_int = -1;
const PTHREAD_CREATE_DETACHED: c_int = 1;
const PTHREAD_STACK_MIN: usize = 2048;
const TIMER_ABSTIME: c_int = 1;

const INT_MAX: c_uint = @as(c_uint, @bitCast(@as(c_int, std.math.maxInt(c_int))));

extern "c" const _CLOCK_REALTIME: CClockId;
extern "c" const _CLOCK_MONOTONIC: CClockId;
extern "c" fn clock_nanosleep(clock_id: *const CClockId, flags: c_int, request: *const anyopaque, remain: ?*anyopaque) c_int;

const PTHREAD_KEYS_MAX = 128;
const PTHREAD_DESTRUCTOR_ITERATIONS = 4;
const Dtor = *const fn (?*anyopaque) callconv(.c) void;

const Pthread = extern struct {
    self: ?*Pthread,
    prev: ?*Pthread,
    next: ?*Pthread,
    sysinfo: usize,
    canary: usize,
    tid: c_int,
    errno_val: c_int,
    detach_state: c_int,
    cancel: c_int,
    canceldisable: u8,
    cancelasync: u8,
    tsd_flags: u8,
    __pad: u8,
    map_base: ?[*]u8,
    map_size: usize,
    stack: ?*anyopaque,
    stack_size: usize,
    guard_size: usize,
    result: ?*anyopaque,
    cancelbuf: ?*anyopaque,
    tsd: ?[*]?*anyopaque,
    robust_list: extern struct {
        head: ?*anyopaque,
        off: c_long,
        pending: ?*anyopaque,
    },
    h_errno_val: c_int,
    timer_id: c_int,
    locale: ?*anyopaque,
    killlock: [1]c_int,
    dlerror_buf: ?[*]u8,
    stdio_locks: ?*anyopaque,
};

var wasilibc_pthread_self: Pthread = std.mem.zeroes(Pthread);
var pthread_tsd_size: usize = @sizeOf(?*anyopaque) * PTHREAD_KEYS_MAX;
var pthread_tsd_main: [PTHREAD_KEYS_MAX]?*anyopaque = [_]?*anyopaque{null} ** PTHREAD_KEYS_MAX;
var pthread_keys: [PTHREAD_KEYS_MAX]?Dtor = [_]?Dtor{null} ** PTHREAD_KEYS_MAX;
var next_key: c_uint = 0;

// --- Barrier ---

fn pthread_barrier_destroy(b: ?*anyopaque) callconv(.c) c_int {
    _ = b;
    return 0;
}

fn pthread_barrier_init(b: *PthreadBarrier, a: ?*const anyopaque, count: c_uint) callconv(.c) c_int {
    _ = a;
    if (count -% 1 > INT_MAX - 1) return EINVAL;
    b.* = std.mem.zeroes(PthreadBarrier);
    b.__i[2] = @intCast(count -% 1); // _b_limit
    return 0;
}

fn pthread_barrier_wait(b: *PthreadBarrier) callconv(.c) c_int {
    if (b.__i[2] == 0) return PTHREAD_BARRIER_SERIAL_THREAD; // _b_limit
    @trap();
}

fn pthread_barrierattr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_barrierattr_init(a: *PthreadBarrierAttr) callconv(.c) c_int {
    a.__attr = 0;
    return 0;
}

fn pthread_barrierattr_getpshared(a: *const PthreadBarrierAttr, pshared: *c_int) callconv(.c) c_int {
    pshared.* = @intFromBool(a.__attr != 0);
    return 0;
}

fn pthread_barrierattr_setpshared(a: *PthreadBarrierAttr, pshared: c_int) callconv(.c) c_int {
    if (@as(c_uint, @bitCast(pshared)) > 1) return EINVAL;
    a.__attr = if (pshared != 0) @bitCast(@as(c_int, std.math.minInt(c_int))) else 0;
    return 0;
}

// --- Condition variable ---

fn pthread_cond_broadcast(cv: ?*anyopaque) callconv(.c) c_int {
    _ = cv;
    return 0;
}

fn pthread_cond_destroy(cv: ?*anyopaque) callconv(.c) c_int {
    _ = cv;
    return 0;
}

fn pthread_cond_init(cv: ?*anyopaque, a: ?*const anyopaque) callconv(.c) c_int {
    _ = .{ cv, a };
    return 0;
}

fn pthread_cond_signal(cv: ?*anyopaque) callconv(.c) c_int {
    _ = cv;
    return 0;
}

fn pthread_cond_timedwait(cv: ?*anyopaque, m: *PthreadMutex, ts: *const anyopaque) callconv(.c) c_int {
    _ = cv;
    if (m.__i[5] == 0) return EPERM; // _m_count
    const ret = clock_nanosleep(&_CLOCK_REALTIME, TIMER_ABSTIME, ts, null);
    if (ret == 0) return ETIMEDOUT;
    if (ret != EINTR) return ret;
    return 0;
}

fn pthread_cond_wait(cv: ?*anyopaque, m: ?*anyopaque) callconv(.c) c_int {
    // No other thread can signal, so this is an immediate deadlock.
    _ = .{ cv, m };
    @trap();
}

fn pthread_condattr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_condattr_init(a: *PthreadCondAttr) callconv(.c) c_int {
    a.__attr = 0;
    return 0;
}

fn pthread_condattr_getclock(a: *const PthreadCondAttr, clk: **const CClockId) callconv(.c) c_int {
    switch (a.__attr & 0x7fffffff) {
        @intFromEnum(wasi.clockid_t.REALTIME) => clk.* = &_CLOCK_REALTIME,
        @intFromEnum(wasi.clockid_t.MONOTONIC) => clk.* = &_CLOCK_MONOTONIC,
        else => {},
    }
    return 0;
}

fn pthread_condattr_getpshared(a: *const PthreadCondAttr, pshared: *c_int) callconv(.c) c_int {
    pshared.* = @intCast(a.__attr >> 31);
    return 0;
}

fn pthread_condattr_setclock(a: *PthreadCondAttr, clk: *const CClockId) callconv(.c) c_int {
    const id: c_uint = @intFromEnum(clk.id);
    if (id == 2 or id == 3) return EINVAL;
    a.__attr = (a.__attr & 0x80000000) | id;
    return 0;
}

fn pthread_condattr_setpshared(a: *PthreadCondAttr, pshared: c_int) callconv(.c) c_int {
    if (@as(c_uint, @bitCast(pshared)) > 1) return EINVAL;
    a.__attr = (a.__attr & 0x7fffffff) | (@as(c_uint, @bitCast(pshared)) << 31);
    return 0;
}

// --- Thread lifecycle ---

fn dummy() callconv(.c) void {}

fn pthread_create(res: ?*anyopaque, attrp: ?*const anyopaque, entry: ?*const anyopaque, arg: ?*anyopaque) callconv(.c) c_int {
    _ = .{ res, attrp, entry, arg };
    return EAGAIN;
}

fn pthread_detach(t: ?*anyopaque) callconv(.c) c_int {
    _ = t;
    return 0;
}

fn pthread_cancel(t: ?*Pthread) callconv(.c) c_int {
    _ = t;
    return ENOTSUP;
}

fn pthread_self() callconv(.c) *Pthread {
    return &wasilibc_pthread_self;
}

fn nodtor(dummy_arg: ?*anyopaque) callconv(.c) void {
    _ = dummy_arg;
}

fn tlsNoop() callconv(.c) void {}

fn pthread_key_create(k: *c_uint, dtor_arg: ?Dtor) callconv(.c) c_int {
    if (wasilibc_pthread_self.tsd == null) wasilibc_pthread_self.tsd = @ptrCast(&pthread_tsd_main);

    const dtor = dtor_arg orelse nodtor;
    var j = next_key;
    while (true) {
        if (pthread_keys[j] == null) {
            next_key = j;
            k.* = j;
            pthread_keys[j] = dtor;
            return 0;
        }
        j = (j + 1) % PTHREAD_KEYS_MAX;
        if (j == next_key) break;
    }
    return EAGAIN;
}

fn pthread_key_delete(k: c_uint) callconv(.c) c_int {
    if (k >= PTHREAD_KEYS_MAX) return EINVAL;
    pthread_tsd_main[k] = null;
    pthread_keys[k] = null;
    return 0;
}

fn pthread_tsd_run_dtors() callconv(.c) void {
    var iter: usize = 0;
    while ((wasilibc_pthread_self.tsd_flags & 1) != 0 and iter < PTHREAD_DESTRUCTOR_ITERATIONS) : (iter += 1) {
        wasilibc_pthread_self.tsd_flags &= ~@as(u8, 1);
        var i: usize = 0;
        while (i < PTHREAD_KEYS_MAX) : (i += 1) {
            const value = pthread_tsd_main[i] orelse continue;
            const dtor = pthread_keys[i];
            pthread_tsd_main[i] = null;
            if (dtor) |f| if (f != nodtor) f(value);
        }
    }
}

fn pthread_getattr_np(t: ?*anyopaque, a: *PthreadAttr) callconv(.c) c_int {
    _ = t;
    a.* = std.mem.zeroes(PthreadAttr);
    a.__u.__i[a_detach_idx] = PTHREAD_CREATE_DETACHED;
    return 0;
}

fn pthread_attr_getdetachstate(a: *const PthreadAttr, state: *c_int) callconv(.c) c_int {
    state.* = a.__u.__i[a_detach_idx];
    return 0;
}

fn pthread_attr_getguardsize(a: *const PthreadAttr, size: *usize) callconv(.c) c_int {
    size.* = @intCast(a.__u.__s[a_guardsize_idx]);
    return 0;
}

fn pthread_attr_getschedparam(a: *const PthreadAttr, param: *SchedParam) callconv(.c) c_int {
    _ = a;
    param.sched_priority = 0;
    return 0;
}

fn pthread_attr_getstack(a: *const PthreadAttr, addr: *?*anyopaque, size: *usize) callconv(.c) c_int {
    const stackaddr = a.__u.__s[a_stackaddr_idx];
    if (stackaddr == 0) return EINVAL;
    size.* = @intCast(a.__u.__s[a_stacksize_idx]);
    addr.* = @ptrFromInt(@as(usize, @intCast(stackaddr)) - size.*);
    return 0;
}

fn pthread_attr_getstacksize(a: *const PthreadAttr, size: *usize) callconv(.c) c_int {
    size.* = @intCast(a.__u.__s[a_stacksize_idx]);
    return 0;
}

fn pthread_attr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_attr_init(a: *PthreadAttr) callconv(.c) c_int {
    a.* = std.mem.zeroes(PthreadAttr);
    a.__u.__s[a_stacksize_idx] = @intCast(__default_stacksize);
    a.__u.__s[a_guardsize_idx] = @intCast(__default_guardsize);
    return 0;
}

fn pthread_attr_setdetachstate(a: *PthreadAttr, state: c_int) callconv(.c) c_int {
    if (@as(c_uint, @bitCast(state)) > 1) return EINVAL;
    a.__u.__i[a_detach_idx] = state;
    return 0;
}

fn pthread_attr_setguardsize(a: *PthreadAttr, size: usize) callconv(.c) c_int {
    if (size > 0) return EINVAL;
    a.__u.__s[a_guardsize_idx] = @intCast(size);
    return 0;
}

fn pthread_attr_setschedparam(a: *PthreadAttr, param: *const SchedParam) callconv(.c) c_int {
    _ = a;
    if (param.sched_priority != 0) return ENOTSUP;
    return 0;
}

fn pthread_attr_setstack(a: *PthreadAttr, addr: usize, size: usize) callconv(.c) c_int {
    if (size -% PTHREAD_STACK_MIN > std.math.maxInt(usize) / 4) return EINVAL;
    a.__u.__s[a_stackaddr_idx] = @intCast(addr +% size);
    a.__u.__s[a_stacksize_idx] = @intCast(size);
    return 0;
}

fn pthread_attr_setstacksize(a: *PthreadAttr, size: usize) callconv(.c) c_int {
    if (size -% PTHREAD_STACK_MIN > std.math.maxInt(usize) / 4) return EINVAL;
    a.__u.__s[a_stackaddr_idx] = 0;
    a.__u.__s[a_stacksize_idx] = @intCast(size);
    return 0;
}

fn pthread_tryjoin_np(t: ?*anyopaque, res: ?*?*anyopaque) callconv(.c) c_int {
    _ = .{ t, res };
    return 0;
}

fn pthread_timedjoin_np(t: ?*anyopaque, res: ?*?*anyopaque, at: ?*const anyopaque) callconv(.c) c_int {
    _ = .{ t, res, at };
    return 0;
}

fn pthread_join(t: ?*anyopaque, res: ?*?*anyopaque) callconv(.c) c_int {
    _ = .{ t, res };
    return 0;
}

// --- Mutex ---

fn pthread_mutex_consistent(m: ?*anyopaque) callconv(.c) c_int {
    _ = m;
    return EINVAL;
}

fn pthread_equal(a: usize, b: usize) callconv(.c) c_int {
    return @intFromBool(a == b);
}

fn pthread_mutexattr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_mutexattr_getprotocol(a: *const PthreadMutexAttr, protocol: *c_int) callconv(.c) c_int {
    protocol.* = @intCast(a.__attr / 8 % 2);
    return 0;
}

fn pthread_mutexattr_getpshared(a: *const PthreadMutexAttr, pshared: *c_int) callconv(.c) c_int {
    pshared.* = @intCast(a.__attr / 128 % 2);
    return 0;
}

fn pthread_mutexattr_getrobust(a: *const PthreadMutexAttr, robust: *c_int) callconv(.c) c_int {
    robust.* = @intCast(a.__attr / 4 % 2);
    return 0;
}

fn pthread_mutexattr_gettype(a: *const PthreadMutexAttr, typ: *c_int) callconv(.c) c_int {
    typ.* = @intCast(a.__attr & 3);
    return 0;
}

fn pthread_mutexattr_init(a: *PthreadMutexAttr) callconv(.c) c_int {
    a.__attr = 0;
    return 0;
}

fn pthread_mutexattr_setprotocol(a: *PthreadMutexAttr, protocol: c_int) callconv(.c) c_int {
    switch (protocol) {
        0 => {
            a.__attr &= ~@as(c_uint, 8);
            return 0;
        },
        1, 2 => return ENOTSUP,
        else => return EINVAL,
    }
}

fn pthread_mutexattr_setpshared(a: *PthreadMutexAttr, pshared: c_int) callconv(.c) c_int {
    if (@as(c_uint, @bitCast(pshared)) > 1) return EINVAL;
    a.__attr = (a.__attr & ~@as(c_uint, 128)) | (@as(c_uint, @bitCast(pshared)) << 7);
    return 0;
}

fn pthread_mutexattr_setrobust(a: *PthreadMutexAttr, robust: c_int) callconv(.c) c_int {
    _ = a;
    if (robust != 0) return EINVAL;
    return 0;
}

fn pthread_mutexattr_settype(a: *PthreadMutexAttr, t: c_int) callconv(.c) c_int {
    if (@as(c_uint, @bitCast(t)) > 2) return EINVAL;
    a.__attr = (a.__attr & ~@as(c_uint, 3)) | @as(c_uint, @bitCast(t));
    return 0;
}

fn pthread_mutex_init(m: *PthreadMutex, a: ?*const PthreadMutexAttr) callconv(.c) c_int {
    m.* = std.mem.zeroes(PthreadMutex);
    if (a) |attr| m.__i[0] = @bitCast(attr.__attr);
    return 0;
}

fn pthread_mutex_destroy(m: ?*anyopaque) callconv(.c) c_int {
    _ = m;
    return 0;
}

fn pthread_mutex_getprioceiling(m: ?*const anyopaque, ceiling: ?*c_int) callconv(.c) c_int {
    _ = .{ m, ceiling };
    return EINVAL;
}

fn pthread_mutex_lock(m: *PthreadMutex) callconv(.c) c_int {
    if (m.__i[0] & 3 != PTHREAD_MUTEX_RECURSIVE) { // _m_type
        if (m.__i[5] != 0) return EDEADLK; // _m_count
        m.__i[5] = 1;
    } else {
        if (@as(c_uint, @bitCast(m.__i[5])) >= INT_MAX) return EAGAIN;
        m.__i[5] += 1;
    }
    return 0;
}

fn pthread_mutex_timedlock(m: *PthreadMutex, at: ?*const anyopaque) callconv(.c) c_int {
    _ = at;
    return pthread_mutex_lock(m);
}

fn pthread_mutex_trylock(m: *PthreadMutex) callconv(.c) c_int {
    if (m.__i[0] & 3 != PTHREAD_MUTEX_RECURSIVE) { // _m_type
        if (m.__i[5] != 0) return EBUSY; // _m_count
        m.__i[5] = 1;
    } else {
        if (@as(c_uint, @bitCast(m.__i[5])) >= INT_MAX) return EAGAIN;
        m.__i[5] += 1;
    }
    return 0;
}

fn pthread_mutex_unlock(m: *PthreadMutex) callconv(.c) c_int {
    if (m.__i[5] == 0) return EPERM; // _m_count
    m.__i[5] -= 1;
    return 0;
}

// --- Once ---

fn pthread_once(control: *c_int, init: *const fn () callconv(.c) void) callconv(.c) c_int {
    if (control.* == 0) {
        init();
        control.* = 1;
    }
    return 0;
}

// --- Read-write lock ---

fn pthread_rwlock_rdlock(rw: *PthreadRwlock) callconv(.c) c_int {
    if (rw.__i[0] == 0x7fffffff) return EDEADLK; // _rw_lock
    if (rw.__i[0] == 0x7ffffffe) return EAGAIN;
    rw.__i[0] += 1;
    return 0;
}

fn pthread_rwlock_timedrdlock(rw: *PthreadRwlock, at: ?*const anyopaque) callconv(.c) c_int {
    _ = at;
    return pthread_rwlock_rdlock(rw);
}

fn pthread_rwlock_timedwrlock(rw: *PthreadRwlock, at: ?*const anyopaque) callconv(.c) c_int {
    _ = at;
    return pthread_rwlock_wrlock(rw);
}

fn pthread_rwlock_tryrdlock(rw: *PthreadRwlock) callconv(.c) c_int {
    if (rw.__i[0] == 0x7fffffff) return EBUSY; // _rw_lock
    if (rw.__i[0] == 0x7ffffffe) return EAGAIN;
    rw.__i[0] += 1;
    return 0;
}

fn pthread_rwlock_trywrlock(rw: *PthreadRwlock) callconv(.c) c_int {
    if (rw.__i[0] != 0) return EBUSY; // _rw_lock
    rw.__i[0] = 0x7fffffff;
    return 0;
}

fn pthread_rwlock_unlock(rw: *PthreadRwlock) callconv(.c) c_int {
    if (rw.__i[0] == 0x7fffffff) { // _rw_lock
        rw.__i[0] = 0;
    } else {
        rw.__i[0] -= 1;
    }
    return 0;
}

fn pthread_rwlock_wrlock(rw: *PthreadRwlock) callconv(.c) c_int {
    if (rw.__i[0] != 0) return EDEADLK; // _rw_lock
    rw.__i[0] = 0x7fffffff;
    return 0;
}

fn pthread_rwlock_destroy(rw: ?*anyopaque) callconv(.c) c_int {
    _ = rw;
    return 0;
}

fn pthread_rwlock_init(rw: *PthreadRwlock, a: ?*const anyopaque) callconv(.c) c_int {
    _ = a;
    rw.* = std.mem.zeroes(PthreadRwlock);
    return 0;
}

fn pthread_rwlockattr_destroy(a: ?*anyopaque) callconv(.c) c_int {
    _ = a;
    return 0;
}

fn pthread_rwlockattr_init(a: *PthreadRwlockAttr) callconv(.c) c_int {
    a.__attr = .{ 0, 0 };
    return 0;
}

fn pthread_rwlockattr_getpshared(a: *const PthreadRwlockAttr, pshared: *c_int) callconv(.c) c_int {
    pshared.* = @intCast(a.__attr[0]);
    return 0;
}

fn pthread_rwlockattr_setpshared(a: *PthreadRwlockAttr, pshared: c_int) callconv(.c) c_int {
    if (@as(c_uint, @bitCast(pshared)) > 1) return EINVAL;
    a.__attr[0] = @intCast(pshared);
    return 0;
}

// --- Spinlock ---

fn pthread_spin_lock(s: *c_int) callconv(.c) c_int {
    if (s.* != 0) return EDEADLK;
    s.* = 1;
    return 0;
}

fn pthread_spin_trylock(s: *c_int) callconv(.c) c_int {
    if (s.* != 0) return EBUSY;
    s.* = 1;
    return 0;
}

fn pthread_spin_unlock(s: *c_int) callconv(.c) c_int {
    s.* = 0;
    return 0;
}

fn thrd_sleep(req: ?*const anyopaque, rem: ?*anyopaque) callconv(.c) c_int {
    const request = req orelse return -2;
    const ret = clock_nanosleep(&_CLOCK_REALTIME, 0, request, rem);
    if (ret == 0) return 0;
    if (ret == EINTR) return -1;
    return -2;
}

// --- Symbol exports ---

comptime {
    @export(&__default_stacksize, .{ .name = "__default_stacksize", .linkage = .weak, .visibility = .hidden });
    @export(&__default_guardsize, .{ .name = "__default_guardsize", .linkage = .weak, .visibility = .hidden });

    // Attribute objects
    symbol(&pthread_attr_destroy, "pthread_attr_destroy");
    symbol(&pthread_attr_getdetachstate, "pthread_attr_getdetachstate");
    symbol(&pthread_attr_getguardsize, "pthread_attr_getguardsize");
    symbol(&pthread_attr_getschedparam, "pthread_attr_getschedparam");
    symbol(&pthread_attr_getstack, "pthread_attr_getstack");
    symbol(&pthread_attr_getstacksize, "pthread_attr_getstacksize");
    symbol(&pthread_attr_init, "pthread_attr_init");
    symbol(&pthread_attr_setdetachstate, "pthread_attr_setdetachstate");
    symbol(&pthread_attr_setguardsize, "pthread_attr_setguardsize");
    symbol(&pthread_attr_setschedparam, "pthread_attr_setschedparam");
    symbol(&pthread_attr_setstack, "pthread_attr_setstack");
    symbol(&pthread_attr_setstacksize, "pthread_attr_setstacksize");
    symbol(&pthread_barrierattr_destroy, "pthread_barrierattr_destroy");
    symbol(&pthread_barrierattr_getpshared, "pthread_barrierattr_getpshared");
    symbol(&pthread_barrierattr_init, "pthread_barrierattr_init");
    symbol(&pthread_barrierattr_setpshared, "pthread_barrierattr_setpshared");
    symbol(&pthread_condattr_destroy, "pthread_condattr_destroy");
    symbol(&pthread_condattr_getclock, "pthread_condattr_getclock");
    symbol(&pthread_condattr_getpshared, "pthread_condattr_getpshared");
    symbol(&pthread_condattr_init, "pthread_condattr_init");
    symbol(&pthread_condattr_setclock, "pthread_condattr_setclock");
    symbol(&pthread_condattr_setpshared, "pthread_condattr_setpshared");
    symbol(&pthread_mutexattr_destroy, "pthread_mutexattr_destroy");
    symbol(&pthread_mutexattr_getprotocol, "pthread_mutexattr_getprotocol");
    symbol(&pthread_mutexattr_getpshared, "pthread_mutexattr_getpshared");
    symbol(&pthread_mutexattr_getrobust, "pthread_mutexattr_getrobust");
    symbol(&pthread_mutexattr_gettype, "pthread_mutexattr_gettype");
    symbol(&pthread_mutexattr_init, "pthread_mutexattr_init");
    symbol(&pthread_mutexattr_setprotocol, "pthread_mutexattr_setprotocol");
    symbol(&pthread_mutexattr_setpshared, "pthread_mutexattr_setpshared");
    symbol(&pthread_mutexattr_setrobust, "pthread_mutexattr_setrobust");
    symbol(&pthread_mutexattr_settype, "pthread_mutexattr_settype");
    symbol(&pthread_rwlockattr_destroy, "pthread_rwlockattr_destroy");
    symbol(&pthread_rwlockattr_getpshared, "pthread_rwlockattr_getpshared");
    symbol(&pthread_rwlockattr_init, "pthread_rwlockattr_init");
    symbol(&pthread_rwlockattr_setpshared, "pthread_rwlockattr_setpshared");

    // Barrier
    symbol(&pthread_barrier_destroy, "pthread_barrier_destroy");
    symbol(&pthread_barrier_init, "pthread_barrier_init");
    symbol(&pthread_barrier_wait, "pthread_barrier_wait");

    // Condition variable
    symbol(&pthread_cond_broadcast, "pthread_cond_broadcast");
    symbol(&pthread_cond_destroy, "pthread_cond_destroy");
    symbol(&pthread_cond_init, "pthread_cond_init");
    symbol(&pthread_cond_signal, "pthread_cond_signal");
    symbol(&pthread_cond_timedwait, "__pthread_cond_timedwait");
    symbol(&pthread_cond_wait, "pthread_cond_wait");

    // Thread lifecycle
    symbol(&dummy, "__acquire_ptc");
    symbol(&pthread_create, "__pthread_create");
    symbol(&pthread_detach, "__pthread_detach");
    symbol(&pthread_cancel, "pthread_cancel");
    symbol(&pthread_self, "pthread_self");
    symbol(&pthread_self, "thrd_current");
    symbol(&pthread_key_create, "__pthread_key_create");
    symbol(&pthread_key_create, "pthread_key_create");
    symbol(&pthread_key_delete, "__pthread_key_delete");
    symbol(&pthread_key_delete, "pthread_key_delete");
    symbol(&pthread_tsd_run_dtors, "__pthread_tsd_run_dtors");
    symbol(&tlsNoop, "__tl_lock");
    symbol(&tlsNoop, "__tl_unlock");
    symbol(&pthread_getattr_np, "pthread_getattr_np");
    symbol(&pthread_tryjoin_np, "__pthread_tryjoin_np");
    symbol(&pthread_timedjoin_np, "__pthread_timedjoin_np");
    symbol(&pthread_join, "__pthread_join");

    // Mutex
    symbol(&pthread_equal, "pthread_equal");
    symbol(&pthread_mutex_init, "pthread_mutex_init");
    symbol(&pthread_mutex_destroy, "pthread_mutex_destroy");
    symbol(&pthread_mutex_consistent, "pthread_mutex_consistent");
    symbol(&pthread_mutex_getprioceiling, "pthread_mutex_getprioceiling");
    symbol(&pthread_mutex_lock, "__pthread_mutex_lock");
    symbol(&pthread_mutex_timedlock, "__pthread_mutex_timedlock");
    symbol(&pthread_mutex_trylock, "__pthread_mutex_trylock");
    symbol(&pthread_mutex_unlock, "__pthread_mutex_unlock");

    // Once
    symbol(&pthread_once, "__pthread_once");

    // Read-write lock
    symbol(&pthread_rwlock_destroy, "pthread_rwlock_destroy");
    symbol(&pthread_rwlock_init, "pthread_rwlock_init");
    symbol(&pthread_rwlock_rdlock, "__pthread_rwlock_rdlock");
    symbol(&pthread_rwlock_timedrdlock, "__pthread_rwlock_timedrdlock");
    symbol(&pthread_rwlock_timedwrlock, "__pthread_rwlock_timedwrlock");
    symbol(&pthread_rwlock_tryrdlock, "__pthread_rwlock_tryrdlock");
    symbol(&pthread_rwlock_trywrlock, "__pthread_rwlock_trywrlock");
    symbol(&pthread_rwlock_unlock, "__pthread_rwlock_unlock");
    symbol(&pthread_rwlock_wrlock, "__pthread_rwlock_wrlock");

    // C11 threads
    symbol(&thrd_sleep, "thrd_sleep");

    @export(&wasilibc_pthread_self, .{ .name = "__wasilibc_pthread_self", .linkage = .weak, .visibility = .hidden });
    @export(&pthread_tsd_size, .{ .name = "__pthread_tsd_size", .linkage = .weak, .visibility = .hidden });
    @export(&pthread_tsd_main, .{ .name = "__pthread_tsd_main", .linkage = .weak, .visibility = .hidden });

    // Spinlock
    symbol(&pthread_spin_lock, "pthread_spin_lock");
    symbol(&pthread_spin_trylock, "pthread_spin_trylock");
    symbol(&pthread_spin_unlock, "pthread_spin_unlock");
}
