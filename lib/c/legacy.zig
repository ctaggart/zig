const builtin = @import("builtin");
const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.link_libc) {
        symbol(&cuserid, "cuserid");
    }
}

const L_cuserid = 20;

const passwd = extern struct {
    pw_name: ?[*:0]const u8,
    pw_passwd: ?[*:0]const u8,
    pw_uid: c_uint,
    pw_gid: c_uint,
    pw_gecos: ?[*:0]const u8,
    pw_dir: ?[*:0]const u8,
    pw_shell: ?[*:0]const u8,
};

extern "c" fn getpwuid_r(uid: c_uint, pwd: *passwd, buf: [*]u8, buflen: usize, result: *?*passwd) c_int;
extern "c" fn geteuid() c_uint;
extern "c" fn strnlen(s: [*]const u8, maxlen: usize) usize;
extern "c" fn memcpy(dst: *anyopaque, src: *const anyopaque, n: usize) *anyopaque;

var usridbuf: [L_cuserid]u8 = undefined;

fn cuserid(buf: ?[*]u8) callconv(.c) ?[*:0]u8 {
    if (buf) |b| b[0] = 0;

    var pw: passwd = undefined;
    var ppw: ?*passwd = null;
    var pwb: [256 * @sizeOf(c_long)]u8 = undefined;
    _ = getpwuid_r(geteuid(), &pw, &pwb, pwb.len, &ppw);
    if (ppw == null) return if (buf) |b| @ptrCast(b) else null;

    const name = pw.pw_name orelse return if (buf) |b| @ptrCast(b) else null;
    const len = strnlen(name, L_cuserid);
    if (len == L_cuserid) return if (buf) |b| @ptrCast(b) else null;

    const dest: [*]u8 = buf orelse &usridbuf;
    _ = memcpy(dest, name, len + 1);
    return @ptrCast(dest);
}
