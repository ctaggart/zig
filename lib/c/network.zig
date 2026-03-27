const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;
const errno = @import("../c.zig").errno;

comptime {
    if (builtin.target.isMuslLibC()) {
        // ent.c
        symbol(&sethostent, "sethostent");
        symbol(&sethostent, "setnetent");
        symbol(&gethostent, "gethostent");
        symbol(&getnetent, "getnetent");
        symbol(&endhostent, "endhostent");
        symbol(&endhostent, "endnetent");

        // serv.c
        symbol(&endservent, "endservent");
        symbol(&setservent, "setservent");
        symbol(&getservent, "getservent");

        // netname.c
        symbol(&getnetbyaddr, "getnetbyaddr");
        symbol(&getnetbyname, "getnetbyname");

        // res_init.c
        symbol(&res_init, "res_init");

        // sockatmark.c
        symbol(&sockatmarkLinux, "sockatmark");
    }
}

fn sethostent(_: c_int) callconv(.c) void {}

fn gethostent() callconv(.c) ?*anyopaque {
    return null;
}

fn getnetent() callconv(.c) ?*anyopaque {
    return null;
}

fn endhostent() callconv(.c) void {}

fn endservent() callconv(.c) void {}

fn setservent(_: c_int) callconv(.c) void {}

fn getservent() callconv(.c) ?*anyopaque {
    return null;
}

fn getnetbyaddr(_: u32, _: c_int) callconv(.c) ?*anyopaque {
    return null;
}

fn getnetbyname(_: [*:0]const u8) callconv(.c) ?*anyopaque {
    return null;
}

fn res_init() callconv(.c) c_int {
    return 0;
}

const SIOCATMARK: u32 = 0x8905;

fn sockatmarkLinux(s: c_int) callconv(.c) c_int {
    var ret: c_int = undefined;
    if (errno(linux.ioctl(s, SIOCATMARK, @intFromPtr(&ret))) < 0) return -1;
    return ret;
}
