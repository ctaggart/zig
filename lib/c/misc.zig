const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&getopt_long_fn, "getopt_long");
        symbol(&getopt_long_only_fn, "getopt_long_only");
    }
}

const Option = extern struct {
    name: ?[*:0]const u8,
    has_arg: c_int,
    flag: ?*c_int,
    val: c_int,
};

const required_argument: c_int = 1;
const MB_LEN_MAX = 4;

extern "c" var optarg: ?[*:0]u8;
extern "c" var optind: c_int;
extern "c" var opterr: c_int;
extern "c" var optopt: c_int;
extern "c" var __optpos: c_int;
extern "c" var __optreset: c_int;

extern "c" fn getopt(argc: c_int, argv: [*]const ?[*:0]u8, optstring: [*:0]const u8) c_int;
extern "c" fn __getopt_msg(a: [*:0]const u8, b: [*:0]const u8, c_ptr: [*]const u8, l: usize) void;
extern "c" fn strlen(s: [*:0]const u8) usize;
extern "c" fn mblen(s: [*]const u8, n: usize) c_int;

fn permute(argv: [*]const ?[*:0]u8, dest: c_int, src: c_int) void {
    const av: [*]?[*:0]u8 = @constCast(argv);
    const tmp = av[@intCast(src)];
    var i = src;
    while (i > dest) : (i -= 1) {
        av[@intCast(i)] = av[@intCast(i - 1)];
    }
    av[@intCast(dest)] = tmp;
}

fn getopt_long_core(
    argc: c_int,
    argv: [*]const ?[*:0]u8,
    optstring: [*:0]const u8,
    longopts: ?[*]const Option,
    idx: ?*c_int,
    longonly: c_int,
) c_int {
    optarg = null;
    const cur = argv[@intCast(optind)] orelse return getopt(argc, argv, optstring);
    const cur_b: [*]const u8 = @ptrCast(cur);

    if (longopts != null and cur[0] == '-' and
        ((longonly != 0 and cur[1] != 0 and cur[1] != '-') or
        (cur[1] == '-' and cur[2] != 0)))
    {
        const opts = longopts.?;
        const os_b: [*]const u8 = @ptrCast(optstring);
        const colon: bool = os_b[if (os_b[0] == '+' or os_b[0] == '-') @as(usize, 1) else 0] == ':';

        const start: [*]const u8 = cur_b + 1;
        var cnt: c_int = 0;
        var match: usize = 0;
        var match_arg: [*]const u8 = start;
        var i: usize = 0;
        while (opts[i].name) |name_ptr| : (i += 1) {
            const name_b: [*]const u8 = @ptrCast(name_ptr);
            var opt: [*]const u8 = start;
            if (opt[0] == '-') opt += 1;
            var n: [*]const u8 = name_b;
            while (opt[0] != 0 and opt[0] != '=' and opt[0] == n[0]) {
                n += 1;
                opt += 1;
            }
            if (opt[0] != 0 and opt[0] != '=') continue;
            match_arg = opt;
            match = i;
            if (n[0] == 0) {
                cnt = 1;
                break;
            }
            cnt += 1;
        }

        if (cnt == 1 and longonly != 0) {
            const arg_len = @intFromPtr(match_arg) - @intFromPtr(start);
            if (arg_len == @as(usize, @intCast(mblen(start, MB_LEN_MAX)))) {
                const l: usize = arg_len;
                var j_outer: usize = 0;
                while (os_b[j_outer] != 0) : (j_outer += 1) {
                    var k: usize = 0;
                    while (k < l and start[k] == os_b[j_outer + k]) : (k += 1) {}
                    if (k == l) {
                        cnt += 1;
                        break;
                    }
                }
            }
        }

        if (cnt == 1) {
            i = match;
            const opt = match_arg;
            optind += 1;
            if (opt[0] == '=') {
                if (opts[i].has_arg == 0) {
                    optopt = opts[i].val;
                    if (colon or opterr == 0) return '?';
                    __getopt_msg(@ptrCast(argv[0].?), ": option does not take an argument: ", @ptrCast(opts[i].name.?), strlen(opts[i].name.?));
                    return '?';
                }
                optarg = @ptrCast(@constCast(opt + 1));
            } else if (opts[i].has_arg == required_argument) {
                optarg = @constCast(argv[@intCast(optind)]);
                if (optarg == null) {
                    optopt = opts[i].val;
                    if (colon) return ':';
                    if (opterr == 0) return '?';
                    __getopt_msg(@ptrCast(argv[0].?), ": option requires an argument: ", @ptrCast(opts[i].name.?), strlen(opts[i].name.?));
                    return '?';
                }
                optind += 1;
            }
            if (idx) |p| p.* = @intCast(i);
            if (opts[i].flag) |flag| {
                flag.* = opts[i].val;
                return 0;
            }
            return opts[i].val;
        }

        if (cur[1] == '-') {
            optopt = 0;
            if (!colon and opterr != 0) {
                __getopt_msg(@ptrCast(argv[0].?), if (cnt != 0) ": option is ambiguous: " else ": unrecognized option: ", cur_b + 2, strlen(@ptrCast(cur_b + 2)));
            }
            optind += 1;
            return '?';
        }
    }
    return getopt(argc, argv, optstring);
}

fn getopt_long_impl(
    argc: c_int,
    argv: [*]const ?[*:0]u8,
    optstring: [*:0]const u8,
    longopts: ?[*]const Option,
    idx: ?*c_int,
    longonly: c_int,
) c_int {
    if (optind == 0 or __optreset != 0) {
        __optreset = 0;
        __optpos = 0;
        optind = 1;
    }
    if (optind >= argc or argv[@intCast(optind)] == null) return -1;
    const skipped = optind;
    const os_b: [*]const u8 = @ptrCast(optstring);
    if (os_b[0] != '+' and os_b[0] != '-') {
        var ii = optind;
        while (true) : (ii += 1) {
            if (ii >= argc or argv[@intCast(ii)] == null) return -1;
            const a = argv[@intCast(ii)].?;
            if (a[0] == '-' and a[1] != 0) break;
        }
        optind = ii;
    }
    const resumed = optind;
    const ret = getopt_long_core(argc, argv, optstring, longopts, idx, longonly);
    if (resumed > skipped) {
        const cnt = optind - resumed;
        var j: c_int = 0;
        while (j < cnt) : (j += 1) {
            permute(argv, skipped, optind - 1);
        }
        optind = skipped + cnt;
    }
    return ret;
}

fn getopt_long_fn(argc: c_int, argv: [*]const ?[*:0]u8, optstring: [*:0]const u8, longopts: ?[*]const Option, idx: ?*c_int) callconv(.c) c_int {
    return getopt_long_impl(argc, argv, optstring, longopts, idx, 0);
}

fn getopt_long_only_fn(argc: c_int, argv: [*]const ?[*:0]u8, optstring: [*:0]const u8, longopts: ?[*]const Option, idx: ?*c_int) callconv(.c) c_int {
    return getopt_long_impl(argc, argv, optstring, longopts, idx, 1);
}
