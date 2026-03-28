const builtin = @import("builtin");
const std = @import("std");

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&fpathconf, "fpathconf");
        symbol(&pathconf, "pathconf");
        symbol(&confstr, "confstr");
        if (builtin.link_libc) {
            symbol(&get_nprocs_conf, "get_nprocs_conf");
            symbol(&get_nprocs, "get_nprocs");
            symbol(&get_phys_pages, "get_phys_pages");
            symbol(&get_avphys_pages, "get_avphys_pages");
        }
    }
}

// POSIX pathconf values
const values = [21]c_short{
    8, 255, 255, 255, 4096, 4096, 1, 1, 0, 1,
    -1, -1, -1, 64, 4096, 4096, 4096, 4096, 4096, -1, 1,
};

fn fpathconf(fd: c_int, name: c_int) callconv(.c) c_long {
    _ = fd;
    if (name < 0 or name >= values.len) {
        std.c._errno().* = @intFromEnum(std.os.linux.E.INVAL);
        return -1;
    }
    return values[@intCast(name)];
}

fn pathconf(path: [*:0]const u8, name: c_int) callconv(.c) c_long {
    _ = path;
    return fpathconf(-1, name);
}

const CS_POSIX_V6_BASE: c_int = 1116;

fn confstr(name: c_int, buf: ?[*]u8, len: usize) callconv(.c) usize {
    const s: [*:0]const u8 = blk: {
        if (name == 0) break :blk "/bin:/usr/bin";
        if ((name & ~@as(c_int, 4)) == 1) break :blk "";
        if (name >= CS_POSIX_V6_BASE and name - CS_POSIX_V6_BASE <= 35) break :blk "";
        std.c._errno().* = @intFromEnum(std.os.linux.E.INVAL);
        return 0;
    };
    var slen: usize = 0;
    while (s[slen] != 0) slen += 1;
    if (buf) |b| {
        if (len > 0) {
            const copy = @min(slen, len - 1);
            @memcpy(b[0..copy], s[0..copy]);
            b[copy] = 0;
        }
    }
    return slen + 1;
}

// --- conf/legacy.c: get_nprocs etc. via sysconf ---

extern "c" fn sysconf(name: c_int) c_long;

const SC_NPROCESSORS_CONF: c_int = 83;
const SC_NPROCESSORS_ONLN: c_int = 84;
const SC_PHYS_PAGES: c_int = 85;
const SC_AVPHYS_PAGES: c_int = 86;

fn get_nprocs_conf() callconv(.c) c_int {
    return @intCast(sysconf(SC_NPROCESSORS_CONF));
}
fn get_nprocs() callconv(.c) c_int {
    return @intCast(sysconf(SC_NPROCESSORS_ONLN));
}
fn get_phys_pages() callconv(.c) c_long {
    return sysconf(SC_PHYS_PAGES);
}
fn get_avphys_pages() callconv(.c) c_long {
    return sysconf(SC_AVPHYS_PAGES);
}
