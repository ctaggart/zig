const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

var abort_lock: c_int = 0;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&abort_lock, "__abort_lock");
    }
}
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&_ExitLinux, "_Exit");
    }
}

fn _ExitLinux(exit_code: c_int) callconv(.c) noreturn {
    linux.exit_group(exit_code);
comptime {
    if (builtin.link_libc) {
        symbol(&quick_exit, "quick_exit");
    }
}

extern "c" fn __funcs_on_quick_exit() void;
extern "c" fn _Exit(code: c_int) noreturn;

fn quick_exit(code: c_int) callconv(.c) noreturn {
    __funcs_on_quick_exit();
    _Exit(code);
}
const std = @import("std");

const symbol = @import("../c.zig").symbol;

// Internal musl lock functions (provided by the thread subsystem).
extern "c" fn __lock(lock: *c_int) void;
extern "c" fn __unlock(lock: *c_int) void;

// C library functions used by atexit.
extern "c" fn calloc(nmemb: usize, size: usize) ?*anyopaque;

const COUNT = 32;

// ── at_quick_exit ──────────────────────────────────────────────────────

var qe_funcs: [COUNT]?*const fn () callconv(.c) void = .{null} ** COUNT;
var qe_count: c_int = 0;
var qe_lock: c_int = 0;

fn __funcs_on_quick_exit() callconv(.c) void {
    __lock(&qe_lock);
    while (qe_count > 0) {
        qe_count -= 1;
        const func = qe_funcs[@intCast(qe_count)].?;
        __unlock(&qe_lock);
        func();
        __lock(&qe_lock);
    }
    __unlock(&qe_lock);
}

fn at_quick_exit(func: ?*const fn () callconv(.c) void) callconv(.c) c_int {
    __lock(&qe_lock);
    defer __unlock(&qe_lock);
    if (qe_count == COUNT) return -1;
const FiniFunc = *const fn () callconv(.c) void;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&_Exit, "_Exit");
        symbol(&__abort_lock, "__abort_lock");
        symbol(&abort_fn, "abort");
        if (builtin.link_libc) {
            symbol(&__assert_fail, "__assert_fail");
            symbol(&at_quick_exit, "at_quick_exit");
            symbol(&__funcs_on_quick_exit, "__funcs_on_quick_exit");
            symbol(@ptrCast(&__at_quick_exit_lockptr), "__at_quick_exit_lockptr");
            symbol(&atexit, "atexit");
            symbol(&__cxa_atexit, "__cxa_atexit");
            symbol(&__cxa_finalize, "__cxa_finalize");
            symbol(&__funcs_on_exit, "__funcs_on_exit");
            symbol(@ptrCast(&__atexit_lockptr), "__atexit_lockptr");
            symbol(&quick_exit_fn, "quick_exit");
            symbol(&exit_fn, "exit");
            symbol(&__libc_exit_fini, "__libc_exit_fini");
        }
    }
}

fn _Exit(ec: c_int) callconv(.c) noreturn {
    linux.exit_group(ec);
}

var __abort_lock: [1]c_int = .{0};

// --- assert ---
extern "c" fn dprintf(fd: c_int, fmt: [*:0]const u8, ...) c_int;

fn __assert_fail(expr: [*:0]const u8, file: [*:0]const u8, line: c_int, func: [*:0]const u8) callconv(.c) noreturn {
    _ = dprintf(2, "Assertion failed: %s (%s: %s: %d)\n", expr, file, func, line);
    abort_fn();
}

// --- musl __lock/__unlock ---
extern "c" fn __lock(l: *c_int) void;
extern "c" fn __unlock(l: *c_int) void;
extern "c" fn calloc(nmemb: usize, size: usize) ?*anyopaque;

// --- at_quick_exit ---
const QE_COUNT = 32;
var qe_funcs: [QE_COUNT]?*const fn () callconv(.c) void = .{null} ** QE_COUNT;
var qe_count: c_int = 0;
var qe_lock: [1]c_int = .{0};
var __at_quick_exit_lockptr: *volatile c_int = &qe_lock[0];

fn __funcs_on_quick_exit() callconv(.c) void {
    __lock(&qe_lock[0]);
    while (qe_count > 0) {
        qe_count -= 1;
        const func = qe_funcs[@intCast(qe_count)];
        __unlock(&qe_lock[0]);
        if (func) |f| f();
        __lock(&qe_lock[0]);
    }
    __unlock(&qe_lock[0]);
}

fn at_quick_exit(func: ?*const fn () callconv(.c) void) callconv(.c) c_int {
    __lock(&qe_lock[0]);
    defer __unlock(&qe_lock[0]);
    if (qe_count == QE_COUNT) return -1;
    qe_funcs[@intCast(qe_count)] = func;
    qe_count += 1;
    return 0;
}

// ── atexit ─────────────────────────────────────────────────────────────

const FuncList = extern struct {
    next: ?*FuncList,
    f: [COUNT]?*const fn (?*anyopaque) callconv(.c) void,
    a: [COUNT]?*anyopaque,
// --- atexit / __cxa_atexit ---
const AE_COUNT = 32;
const FuncList = extern struct {
    next: ?*FuncList,
    f: [AE_COUNT]?*const fn (?*anyopaque) callconv(.c) void,
    a: [AE_COUNT]?*anyopaque,
};

var ae_builtin: FuncList = std.mem.zeroes(FuncList);
var ae_head: ?*FuncList = null;
var ae_slot: c_int = 0;
var ae_lock: c_int = 0;

fn __funcs_on_exit() callconv(.c) void {
    __lock(&ae_lock);
    var head = ae_head;
    var slot = ae_slot;
    while (head) |h| {
        while (slot > 0) {
            slot -= 1;
            const func = h.f[@intCast(slot)].?;
            const arg = h.a[@intCast(slot)];
            __unlock(&ae_lock);
            func(arg);
            __lock(&ae_lock);
        }
        head = h.next;
        slot = COUNT;
    }
    __unlock(&ae_lock);
}

fn __cxa_finalize(_: ?*anyopaque) callconv(.c) void {}

fn __cxa_atexit(
    func: ?*const fn (?*anyopaque) callconv(.c) void,
    arg: ?*anyopaque,
    _: ?*anyopaque,
) callconv(.c) c_int {
    __lock(&ae_lock);
    defer __unlock(&ae_lock);

    // Defer initialization of head so it can be in BSS.
    if (ae_head == null) ae_head = &ae_builtin;

    // If the current function list is full, add a new one.
    if (ae_slot == COUNT) {
        const new_fl: ?*FuncList = @ptrCast(@alignCast(calloc(@sizeOf(FuncList), 1)));
        if (new_fl == null) return -1;
var ae_lock: [1]c_int = .{0};
var __atexit_lockptr: *volatile c_int = &ae_lock[0];

fn __funcs_on_exit() callconv(.c) void {
    __lock(&ae_lock[0]);
    while (ae_head) |head| {
        while (ae_slot > 0) {
            ae_slot -= 1;
            const func = head.f[@intCast(ae_slot)];
            const arg = head.a[@intCast(ae_slot)];
            __unlock(&ae_lock[0]);
            if (func) |f| f(arg);
            __lock(&ae_lock[0]);
        }
        ae_head = head.next;
        ae_slot = AE_COUNT;
    }
    __unlock(&ae_lock[0]);
}

fn __cxa_finalize(dso: ?*anyopaque) callconv(.c) void { _ = dso; }

fn __cxa_atexit(func: ?*const fn (?*anyopaque) callconv(.c) void, arg: ?*anyopaque, dso: ?*anyopaque) callconv(.c) c_int {
    _ = dso;
    __lock(&ae_lock[0]);
    if (ae_head == null) ae_head = &ae_builtin;
    if (ae_slot == AE_COUNT) {
        const new_fl: ?*FuncList = @ptrCast(@alignCast(calloc(1, @sizeOf(FuncList))));
        if (new_fl == null) { __unlock(&ae_lock[0]); return -1; }
        new_fl.?.next = ae_head;
        ae_head = new_fl;
        ae_slot = 0;
    }

    ae_head.?.f[@intCast(ae_slot)] = func;
    ae_head.?.a[@intCast(ae_slot)] = arg;
    ae_slot += 1;
    ae_head.?.f[@intCast(ae_slot)] = func;
    ae_head.?.a[@intCast(ae_slot)] = arg;
    ae_slot += 1;
    __unlock(&ae_lock[0]);
    return 0;
}

fn call(p: ?*anyopaque) callconv(.c) void {
    const func: *const fn () callconv(.c) void = @ptrCast(@alignCast(p));
    func();
    const f: *const fn () callconv(.c) void = @ptrCast(@alignCast(p));
    f();
}

fn atexit(func: ?*const fn () callconv(.c) void) callconv(.c) c_int {
    return __cxa_atexit(call, @ptrCast(@constCast(func)), null);
}

comptime {
    if (builtin.link_libc) {
        symbol(&__funcs_on_quick_exit, "__funcs_on_quick_exit");
        symbol(&at_quick_exit, "at_quick_exit");
        symbol(&__funcs_on_exit, "__funcs_on_exit");
        symbol(&__cxa_finalize, "__cxa_finalize");
        symbol(&__cxa_atexit, "__cxa_atexit");
        symbol(&atexit, "atexit");
        symbol(&qe_lock, "__at_quick_exit_lockptr");
        symbol(&ae_lock, "__atexit_lockptr");
    }
    if (builtin.link_libc) {
        symbol(&abortImpl, "abort");
    }
}

extern "c" fn raise(sig: c_int) c_int;
extern "c" fn __lock(lock: *c_int) void;
extern "c" fn __block_all_sigs(set: ?*anyopaque) void;
extern "c" fn _Exit(code: c_int) noreturn;
extern "c" var __abort_lock: c_int;

fn abortImpl() callconv(.c) noreturn {
    _ = raise(@intFromEnum(linux.SIG.ABRT));

    // If we get here, SIGABRT was caught/blocked/ignored.
    // Block all signals, lock to prevent new handlers, reset SIGABRT to default,
    // then re-raise.
    __block_all_sigs(null);
    __lock(&__abort_lock);

    // Reset SIGABRT handler to SIG_DFL via rt_sigaction.
    const SIG_DFL: usize = 0;
    var sa: [4]usize = .{ SIG_DFL, 0, 0, 0 };
    _ = linux.syscall4(
        .rt_sigaction,
        @intFromEnum(linux.SIG.ABRT),
        @intFromPtr(&sa),
        0,
        linux.NSIG / 8,
    );

    // Send SIGABRT to this thread.
    _ = linux.tkill(linux.gettid(), linux.SIG.ABRT);

    // Unblock SIGABRT.
    const sigabrt_bit: usize = @as(usize, 1) << (@intFromEnum(linux.SIG.ABRT) - 1);
    const SIG_UNBLOCK: usize = 1;
    _ = linux.syscall4(
        .rt_sigprocmask,
        SIG_UNBLOCK,
        @intFromPtr(&sigabrt_bit),
        0,
        linux.NSIG / 8,
    );

    // Should be unreachable. Crash hard.
    _ = raise(@intFromEnum(linux.SIG.KILL));
    _Exit(127);
}
comptime {
    if (builtin.link_libc) {
        symbol(&dummy, "__funcs_on_exit");
        symbol(&dummy, "__stdio_exit");
        symbol(&dummy, "_fini");
        symbol(&libc_exit_fini, "__libc_exit_fini");
        symbol(&exitImpl, "exit");
    }
}

fn dummy() callconv(.c) void {}

extern "c" fn __funcs_on_exit() void;
extern "c" fn __stdio_exit() void;
extern "c" fn _fini() void;
extern "c" fn _Exit(code: c_int) noreturn;

extern const __fini_array_start: *const fn () callconv(.c) void;
extern const __fini_array_end: *const fn () callconv(.c) void;

fn libc_exit_fini() callconv(.c) void {
    const start: usize = @intFromPtr(&__fini_array_start);
    const end: usize = @intFromPtr(&__fini_array_end);
    const ptr_size = @sizeOf(*const fn () callconv(.c) void);
    var a: usize = end;
    while (a > start) {
        a -= ptr_size;
        const func: *const *const fn () callconv(.c) void = @ptrFromInt(a);
        func.*();
    }
    _fini();
}

fn exitImpl(code: c_int) callconv(.c) noreturn {
    __funcs_on_exit();
    libc_exit_fini();
    __stdio_exit();
    _Exit(code);
}
// --- quick_exit ---
fn quick_exit_fn(code: c_int) callconv(.c) noreturn {
    __funcs_on_quick_exit();
    _Exit(code);
}

// --- exit (with fini array iteration) ---

// Weak extern functions that may or may not be provided at link time
extern "c" fn __stdio_exit() void;

fn __libc_exit_fini() callconv(.c) void {
    // Iterate __fini_array in reverse order (same as musl's libc_exit_fini)
    const opt_start = @extern(?[*]const FiniFunc, .{ .name = "__fini_array_start", .linkage = .weak });
    const opt_end = @extern(?[*]const FiniFunc, .{ .name = "__fini_array_end", .linkage = .weak });
    if (opt_start) |start| {
        if (opt_end) |end| {
            const len = end - start;
            var i = len;
            while (i > 0) {
                i -= 1;
                start[i]();
            }
        }
    }
    // _fini is a weak symbol provided by CRT; call it if present.
    const opt_fini = @extern(?*const fn () callconv(.c) void, .{ .name = "_fini", .linkage = .weak });
    if (opt_fini) |f| f();
}

fn exit_fn(code: c_int) callconv(.c) noreturn {
    __funcs_on_exit();
    __libc_exit_fini();
    __stdio_exit();
    _Exit(code);
}

// --- abort ---

fn abort_fn() callconv(.c) noreturn {
    _ = linux.tkill(linux.gettid(), .ABRT);

    // If SIGABRT handler returned, block all signals and force-kill
    // Block all signals
    var set: linux.sigset_t = .{0} ** @typeInfo(linux.sigset_t).array.len;
    for (&set) |*s| s.* = ~@as(@TypeOf(s.*), 0);
    _ = linux.sigprocmask(2, &set, null); // SIG_SETMASK=2 to block all

    // Lock __abort_lock (atomic CAS to avoid extern "c" dependency on __lock)
    while (@cmpxchgWeak(c_int, &__abort_lock[0], 0, 1, .acquire, .monotonic) != null) {}

    // Reset SIGABRT to default
    const act = linux.Sigaction{
        .handler = .{ .handler = @ptrFromInt(0) }, // SIG_DFL = 0
        .mask = std.mem.zeroes(linux.sigset_t),
        .flags = 0,
    };
    _ = linux.sigaction(.ABRT, &act, null);

    // Re-send SIGABRT to self
    _ = linux.tkill(linux.gettid(), .ABRT);

    // Unblock SIGABRT
    var abrt_set: linux.sigset_t = std.mem.zeroes(linux.sigset_t);
    abrt_set[0] = 1 << (@intFromEnum(linux.SIG.ABRT) - 1);
    _ = linux.sigprocmask(1, &abrt_set, null); // SIG_UNBLOCK=1

    // Should be unreachable, but force crash
    @breakpoint();
    _ = linux.tkill(linux.gettid(), .KILL);
    _Exit(127);
comptime {
    if (builtin.link_libc) {
        symbol(&__assert_fail, "__assert_fail");
    }
}

extern "c" fn fprintf(stream: *anyopaque, fmt: [*:0]const u8, ...) c_int;
extern "c" fn abort() noreturn;
extern "c" var stderr: *anyopaque;

fn __assert_fail(
    expr: [*:0]const u8,
    file: [*:0]const u8,
    line: c_int,
    func: [*:0]const u8,
) callconv(.c) noreturn {
    _ = fprintf(stderr, "Assertion failed: %s (%s: %s: %d)\n", expr, file, func, line);
    abort();
}
