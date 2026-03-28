const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&get_current_dir_name, "get_current_dir_name");
        symbol(&setmntent, "setmntent");
        symbol(&endmntent, "endmntent");
        symbol(&getmntent, "getmntent");
        symbol(&getmntent_r, "getmntent_r");
        symbol(&addmntent, "addmntent");
        symbol(&hasmntopt, "hasmntopt");
    }
}

// ── get_current_dir_name ───────────────────────────────────────────────

extern "c" fn getenv(name: [*:0]const u8) ?[*:0]const u8;
extern "c" fn strdup(s: [*:0]const u8) ?[*:0]u8;
extern "c" fn getcwd(buf: ?[*]u8, size: usize) ?[*:0]u8;

// Use opaque stat buffers and compare dev+ino fields.
const STAT_BUF_SIZE = 256;
extern "c" fn stat(path: [*:0]const u8, buf: *[STAT_BUF_SIZE]u8) c_int;

fn get_current_dir_name() callconv(.c) ?[*:0]u8 {
    const res = getenv("PWD") orelse return getcwd(null, 0);
    if (res[0] == 0) return getcwd(null, 0);
    var a: [STAT_BUF_SIZE]u8 = undefined;
    var b: [STAT_BUF_SIZE]u8 = undefined;
    if (stat(res, &a) != 0 or stat(".", &b) != 0) return getcwd(null, 0);
    // Compare st_dev (first field) and st_ino (second field on most archs).
    // Both are typically 8 bytes each, starting at offset 0.
    if (@as(*const u64, @ptrCast(@alignCast(&a[0]))).* == @as(*const u64, @ptrCast(@alignCast(&b[0]))).* and
        @as(*const u64, @ptrCast(@alignCast(&a[8]))).* == @as(*const u64, @ptrCast(@alignCast(&b[8]))).*) {
        return strdup(res);
    }
    return getcwd(null, 0);
}

// ── mntent ─────────────────────────────────────────────────────────────

const FILE = anyopaque;
extern "c" fn fopen(path: [*:0]const u8, mode: [*:0]const u8) ?*FILE;
extern "c" fn fclose(f: *FILE) c_int;
extern "c" fn fgets(buf: [*]u8, size: c_int, f: *FILE) ?[*]u8;
extern "c" fn feof(f: *FILE) c_int;
extern "c" fn ferror(f: *FILE) c_int;
extern "c" fn fscanf(f: *FILE, fmt: [*:0]const u8, ...) c_int;
extern "c" fn sscanf(s: [*]const u8, fmt: [*:0]const u8, ...) c_int;
extern "c" fn fprintf(f: *FILE, fmt: [*:0]const u8, ...) c_int;
extern "c" fn fseek(f: *FILE, offset: c_long, whence: c_int) c_int;
extern "c" fn strlen(s: [*:0]const u8) usize;
extern "c" fn strchr(s: [*:0]const u8, c: c_int) ?[*:0]const u8;
extern "c" fn strstr(haystack: [*:0]const u8, needle: [*:0]const u8) ?[*:0]const u8;
extern "c" fn getline(lineptr: *?[*:0]u8, n: *usize, f: *FILE) isize;

const SEEK_END = 2;

const mntent = extern struct {
    mnt_fsname: ?[*:0]u8,
    mnt_dir: ?[*:0]u8,
    mnt_type: ?[*:0]u8,
    mnt_opts: ?[*:0]u8,
    mnt_freq: c_int,
    mnt_passno: c_int,
};

fn setmntent(name: [*:0]const u8, mode: [*:0]const u8) callconv(.c) ?*FILE {
    return fopen(name, mode);
}

fn endmntent(f: ?*FILE) callconv(.c) c_int {
    if (f) |stream| _ = fclose(stream);
    return 1;
}

var internal_buf: ?[*:0]u8 = null;
var internal_bufsize: usize = 0;
var static_mnt: mntent = undefined;

fn unescape_ent(beg: [*:0]u8) [*:0]u8 {
    var dest: [*]u8 = @ptrCast(beg);
    var src: [*]const u8 = @ptrCast(beg);
    while (src[0] != 0) {
        if (src[0] != '\\') {
            dest[0] = src[0];
            dest += 1;
            src += 1;
            continue;
        }
        if (src[1] == '\\') {
            src += 1;
            dest[0] = src[0];
            dest += 1;
            src += 1;
            continue;
        }
        var cval: u8 = 0;
        var val: [*]const u8 = src + 1;
        for (0..3) |_| {
            if (val[0] >= '0' and val[0] <= '7') {
                cval = (cval << 3) + (val[0] - '0');
                val += 1;
            } else break;
        }
        if (cval != 0) {
            dest[0] = cval;
            dest += 1;
            src = val;
        } else {
            dest[0] = src[0];
            dest += 1;
            src += 1;
        }
    }
    dest[0] = 0;
    return beg;
}

const SENTINEL: [*]u8 = @ptrCast(&internal_buf);

fn getmntent_r(f: *FILE, mnt_out: *mntent, linebuf_arg: [*]u8, buflen: c_int) callconv(.c) ?*mntent {
    const use_internal = (linebuf_arg == SENTINEL);
    var n: [8]c_int = undefined;

    mnt_out.mnt_freq = 0;
    mnt_out.mnt_passno = 0;

    while (true) {
        var linebuf: [*:0]u8 = undefined;
        if (use_internal) {
            _ = getline(&internal_buf, &internal_bufsize, f);
            linebuf = internal_buf orelse return null;
        } else {
            if (fgets(linebuf_arg, buflen, f) == null) return null;
            linebuf = @ptrCast(linebuf_arg);
        }
        if (feof(f) != 0 or ferror(f) != 0) return null;

        const len: c_int = @intCast(strlen(linebuf));
        for (&n) |*p| p.* = len;
        _ = sscanf(linebuf, " %n%*[^ \t]%n %n%*[^ \t]%n %n%*[^ \t]%n %n%*[^ \t]%n %d %d",
            &n[0], &n[1], &n[2], &n[3], &n[4], &n[5], &n[6], &n[7],
            &mnt_out.mnt_freq, &mnt_out.mnt_passno);

        const lb: [*]u8 = @ptrCast(linebuf);
        if (lb[@intCast(n[0])] == '#' or n[1] == len) continue;

        lb[@intCast(n[1])] = 0;
        lb[@intCast(n[3])] = 0;
        lb[@intCast(n[5])] = 0;
        lb[@intCast(n[7])] = 0;

        mnt_out.mnt_fsname = unescape_ent(@ptrCast(lb + @as(usize, @intCast(n[0]))));
        mnt_out.mnt_dir = unescape_ent(@ptrCast(lb + @as(usize, @intCast(n[2]))));
        mnt_out.mnt_type = unescape_ent(@ptrCast(lb + @as(usize, @intCast(n[4]))));
        mnt_out.mnt_opts = unescape_ent(@ptrCast(lb + @as(usize, @intCast(n[6]))));

        return mnt_out;
    }
}

fn getmntent(f: *FILE) callconv(.c) ?*mntent {
    return getmntent_r(f, &static_mnt, SENTINEL, 0);
}

fn addmntent(f: *FILE, mnt_in: *const mntent) callconv(.c) c_int {
    if (fseek(f, 0, SEEK_END) != 0) return 1;
    return if (fprintf(f, "%s\t%s\t%s\t%s\t%d\t%d\n",
        mnt_in.mnt_fsname, mnt_in.mnt_dir, mnt_in.mnt_type, mnt_in.mnt_opts,
        mnt_in.mnt_freq, mnt_in.mnt_passno) < 0) @as(c_int, 1) else 0;
}

fn hasmntopt(mnt_in: *const mntent, opt: [*:0]const u8) callconv(.c) ?[*:0]const u8 {
    return strstr(mnt_in.mnt_opts orelse return null, opt);
}
