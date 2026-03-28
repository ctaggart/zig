const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

/// The global environ pointer, set by __libc_start_main.
/// Exported under four names matching musl's weak_alias chain.
var __environ_val: ?[*]?[*:0]c_char = null;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&__environ_val, "__environ");
        symbol(&__environ_val, "___environ");
        symbol(&__environ_val, "_environ");
        symbol(&__environ_val, "environ");

        if (builtin.link_libc) {
            symbol(&getenv, "getenv");
            symbol(&setenv, "setenv");
            symbol(&__putenv, "__putenv");
            symbol(&putenv, "putenv");
            symbol(&unsetenv, "unsetenv");
            symbol(&clearenv, "clearenv");
            symbol(&__env_rm_add, "__env_rm_add");
        }
    }
}

// --- Extern libc functions ---
extern "c" fn malloc(size: usize) ?[*]c_char;
extern "c" fn realloc(ptr: ?*anyopaque, size: usize) ?[*]c_char;
extern "c" fn free(ptr: ?*anyopaque) void;
extern "c" fn strlen(s: [*:0]const c_char) usize;
extern "c" fn strncmp(a: [*]const c_char, b: [*]const c_char, n: usize) c_int;
extern "c" fn memcpy(dest: ?[*]c_char, src: [*]const c_char, n: usize) ?[*]c_char;

fn strchrnul(s: [*:0]const c_char, c: c_char) [*:0]const c_char {
    var p: [*:0]const c_char = s;
    while (p[0] != 0 and p[0] != c) p += 1;
    return p;
}

// --- __env_rm_add: track allocated env strings ---

var env_alloced: ?[*]?[*]c_char = null;
var env_alloced_n: usize = 0;

fn __env_rm_add(old: ?[*]c_char, new_arg: ?[*]c_char) callconv(.c) void {
    var new = new_arg;
    for (0..env_alloced_n) |i| {
        if (env_alloced.?[i] == old) {
            env_alloced.?[i] = new;
            free(old);
            return;
        } else if (env_alloced.?[i] == null and new != null) {
            env_alloced.?[i] = new;
            new = null;
        }
    }
    if (new == null) return;
    const t: ?[*]?[*]c_char = @ptrCast(@alignCast(realloc(
        @ptrCast(env_alloced),
        @sizeOf(?[*]c_char) * (env_alloced_n + 1),
    )));
    if (t == null) return;
    env_alloced = t;
    t.?[env_alloced_n] = new;
    env_alloced_n += 1;
}

// --- getenv ---

fn getenv(name: [*:0]const c_char) callconv(.c) ?[*:0]c_char {
    const l = @intFromPtr(strchrnul(name, '=')) - @intFromPtr(name);
    if (l == 0 or name[l] != 0) return null;
    const env = __environ_val orelse return null;
    var i: usize = 0;
    while (env[i]) |e| : (i += 1) {
        if (strncmp(name, e, l) == 0 and e[l] == '=')
            return @ptrCast(e + l + 1);
    }
    return null;
}

// --- __putenv (core implementation) ---

var oldenv: ?[*]?[*:0]c_char = null;

fn __putenv(s: [*:0]c_char, l: usize, r: ?[*]c_char) callconv(.c) c_int {
    var i: usize = 0;
    if (__environ_val) |env| {
        while (env[i]) |e| : (i += 1) {
            if (strncmp(s, e, l + 1) == 0) {
                const tmp = e;
                env[i] = s;
                __env_rm_add(@ptrCast(tmp), r);
                return 0;
            }
        }
    }
    var newenv: ?[*]?[*:0]c_char = undefined;
    if (__environ_val == oldenv) {
        newenv = @ptrCast(@alignCast(realloc(
            @ptrCast(oldenv),
            @sizeOf(?[*:0]c_char) * (i + 2),
        )));
        if (newenv == null) {
            free(r);
            return -1;
        }
    } else {
        newenv = @ptrCast(@alignCast(malloc(@sizeOf(?[*:0]c_char) * (i + 2))));
        if (newenv == null) {
            free(r);
            return -1;
        }
        if (i > 0) _ = memcpy(
            @ptrCast(newenv.?),
            @ptrCast(__environ_val.?),
            @sizeOf(?[*:0]c_char) * i,
        );
        free(@ptrCast(oldenv));
    }
    newenv.?[i] = s;
    newenv.?[i + 1] = null;
    oldenv = newenv;
    __environ_val = newenv;
    if (r != null) __env_rm_add(null, r);
    return 0;
}

// --- putenv ---

fn putenv(s: [*:0]c_char) callconv(.c) c_int {
    const l = @intFromPtr(strchrnul(s, '=')) - @intFromPtr(s);
    if (l == 0 or s[l] == 0) return unsetenv(s);
    return __putenv(s, l, null);
}

// --- setenv ---

fn setenv(name: [*:0]const c_char, value: [*:0]const c_char, overwrite: c_int) callconv(.c) c_int {
    const l1 = @intFromPtr(strchrnul(name, '=')) - @intFromPtr(name);
    if (l1 == 0 or name[l1] != 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    if (overwrite == 0 and getenv(name) != null) return 0;
    const l2 = strlen(value);
    const s = malloc(l1 + l2 + 2) orelse return -1;
    _ = memcpy(s, name, l1);
    s[l1] = '=';
    _ = memcpy(s + l1 + 1, value, l2 + 1);
    return __putenv(@ptrCast(s), l1, s);
}

// --- unsetenv ---

fn unsetenv(name: [*:0]const c_char) callconv(.c) c_int {
    const l = @intFromPtr(strchrnul(name, '=')) - @intFromPtr(name);
    if (l == 0 or name[l] != 0) {
        std.c._errno().* = @intFromEnum(linux.E.INVAL);
        return -1;
    }
    const env = __environ_val orelse return 0;
    var e = env;
    var eo = env;
    while (e[0]) |entry| {
        if (strncmp(name, entry, l) == 0 and entry[l] == '=') {
            __env_rm_add(@ptrCast(entry), null);
        } else {
            if (eo != e) eo[0] = entry;
            eo += 1;
        }
        e += 1;
    }
    if (eo != e) eo[0] = null;
    return 0;
}

// --- clearenv ---

fn clearenv() callconv(.c) c_int {
    const env = __environ_val orelse return 0;
    __environ_val = null;
    var e = env;
    while (e[0]) |entry| : (e += 1) {
        __env_rm_add(@ptrCast(entry), null);
    }
    return 0;
}
