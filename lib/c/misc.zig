const builtin = @import("builtin");
const std = @import("std");
const linux = std.os.linux;

const symbol = @import("../c.zig").symbol;

comptime {
    if (builtin.target.isMuslLibC()) {
        symbol(&login_ttyLinux, "login_tty");
    }
    if (builtin.link_libc) {
        symbol(&initgroups, "initgroups");
    }
}

fn login_ttyLinux(fd: c_int) callconv(.c) c_int {
    _ = linux.setsid();
    const rc: isize = @bitCast(linux.ioctl(@intCast(fd), linux.T.IOCSCTTY, 0));
    if (rc < 0) {
        @branchHint(.unlikely);
        std.c._errno().* = @intCast(-rc);
        return -1;
    }
    _ = linux.dup2(fd, 0);
    _ = linux.dup2(fd, 1);
    _ = linux.dup2(fd, 2);
    if (fd > 2) _ = linux.close(fd);
    return 0;
}

const NGROUPS_MAX = 32;

extern "c" fn getgrouplist(user: [*:0]const u8, group: linux.gid_t, groups: [*]linux.gid_t, ngroups: *c_int) c_int;
extern "c" fn setgroups(size: usize, list: [*]const linux.gid_t) c_int;

fn initgroups(user: [*:0]const u8, gid: linux.gid_t) callconv(.c) c_int {
    var groups: [NGROUPS_MAX]linux.gid_t = undefined;
    var count: c_int = NGROUPS_MAX;
    if (getgrouplist(user, gid, &groups, &count) < 0) return -1;
    return setgroups(@intCast(count), &groups);
}
