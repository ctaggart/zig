const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

// C library dependencies.
extern "c" fn mbtowc(pwc: ?*c_uint, s: [*]const u8, n: usize) c_int;
extern "c" fn fputs(s: [*:0]const u8, f: *anyopaque) c_int;
extern "c" fn fwrite(ptr: *const anyopaque, size: usize, nmemb: usize, f: *anyopaque) usize;
extern "c" fn putc(c: c_int, f: *anyopaque) c_int;
extern "c" fn strlen(s: [*:0]const u8) usize;
extern "c" fn flockfile(f: *anyopaque) void;
extern "c" fn funlockfile(f: *anyopaque) void;
extern "c" var stderr: *anyopaque;

const MB_LEN_MAX = 4;

// ── Global state ───────────────────────────────────────────────────────

var optarg_val: ?[*:0]u8 = null;
var optind_val: c_int = 1;
var opterr_val: c_int = 1;
var optopt_val: c_int = 0;
var optpos_val: c_int = 0;
var optreset_val: c_int = 0;

comptime {
    if (builtin.link_libc) {
        @export(&optarg_val, .{ .name = "optarg" });
        symbol(&optind_val, "optind");
        symbol(&opterr_val, "opterr");
        symbol(&optopt_val, "optopt");
        symbol(&optpos_val, "__optpos");
        symbol(&optreset_val, "__optreset");
        symbol(&optreset_val, "optreset");
        symbol(&__getopt_msg, "__getopt_msg");
        symbol(&getopt_fn, "getopt");
        symbol(&getopt_fn, "__posix_getopt");
    }
}

fn __getopt_msg(a: [*:0]const u8, b: [*:0]const u8, c_ptr: [*]const u8, l: usize) callconv(.c) void {
    const f = stderr;
    flockfile(f);
    _ = fputs(a, f);
    _ = fwrite(b, strlen(b), 1, f);
    _ = fwrite(c_ptr, 1, l, f);
    _ = putc('\n', f);
    funlockfile(f);
}

fn getopt_fn(
    argc: c_int,
    argv: [*]const ?[*:0]u8,
    optstring_arg: [*:0]const u8,
) callconv(.c) c_int {
    if (optind_val == 0 or optreset_val != 0) {
        optreset_val = 0;
        optpos_val = 0;
        optind_val = 1;
    }

    if (optind_val >= argc) return -1;
    const cur = argv[@intCast(optind_val)] orelse return -1;
    if (cur[0] != '-') {
        if (optstring_arg[0] == '-') {
            optarg_val = @constCast(cur);
            optind_val += 1;
            return 1;
        }
        return -1;
    }
    if (cur[1] == 0) return -1;
    if (cur[1] == '-' and cur[2] == 0) {
        optind_val += 1;
        return -1;
    }

    if (optpos_val == 0) optpos_val = 1;

    var c: c_uint = undefined;
    const cur_bytes: [*]const u8 = @ptrCast(cur);
    var k = mbtowc(&c, cur_bytes + @as(usize, @intCast(optpos_val)), MB_LEN_MAX);
    if (k < 0) {
        k = 1;
        c = 0xfffd;
    }
    const optchar: [*]const u8 = cur_bytes + @as(usize, @intCast(optpos_val));
    optpos_val += k;

    if (cur[@intCast(optpos_val)] == 0) {
        optind_val += 1;
        optpos_val = 0;
    }

    var optstring = optstring_arg;
    if (optstring[0] == '-' or optstring[0] == '+') optstring = @ptrCast(@as([*]const u8, @ptrCast(optstring)) + 1);

    var i: usize = 0;
    var d: c_uint = 0;
    while (true) {
        const os_bytes: [*]const u8 = @ptrCast(optstring);
        const l = mbtowc(&d, os_bytes + i, MB_LEN_MAX);
        if (l > 0) {
            i += @intCast(l);
        } else {
            i += 1;
        }
        if (l == 0 or d == c) break;
    }

    if (d != c or c == ':') {
        optopt_val = @intCast(c);
        if (optstring_arg[0] != ':' and opterr_val != 0)
            __getopt_msg(@ptrCast(argv[0].?), ": unrecognized option: ", optchar, @intCast(k));
        return '?';
    }

    const os_bytes: [*]const u8 = @ptrCast(optstring);
    if (os_bytes[i] == ':') {
        optarg_val = null;
        if (os_bytes[i + 1] != ':' or optpos_val != 0) {
            if (optind_val >= argc) {
                optopt_val = @intCast(c);
                if (optstring_arg[0] == ':') return ':';
                if (opterr_val != 0)
                    __getopt_msg(@ptrCast(argv[0].?), ": option requires an argument: ", optchar, @intCast(k));
                return '?';
            }
            const next = argv[@intCast(optind_val)] orelse null;
            optind_val += 1;
            if (optpos_val != 0) {
                if (next) |n| {
                    optarg_val = @ptrCast(@constCast(@as([*]const u8, @ptrCast(n)) + @as(usize, @intCast(optpos_val))));
                }
            } else {
                optarg_val = @constCast(next);
            }
            optpos_val = 0;
        }
    }
    return @intCast(c);
}
